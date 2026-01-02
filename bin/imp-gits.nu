#!/usr/bin/env nu
# imp-gits: Declarative sparse checkout and multi-repo workspace composition

const GITS_DIR = ".imp/gits"
const CONFIG_FILE = ".imp/gits/config.nix"

def gits-lib []: nothing -> string {
    $env.GITS_LIB? | default "@gitsLib@"
}

def require-config [] {
    if not ($CONFIG_FILE | path exists) {
        error make {msg: $"Error: ($CONFIG_FILE) not found"}
    }
}

def require-git [] {
    let result = git rev-parse --git-dir | complete
    if $result.exit_code != 0 {
        error make {msg: "Error: not a git repository"}
    }
}

def eval-script [script_name: string]: nothing -> string {
    let lib_path = gits-lib
    let expr = $"
        let
          lib = import <nixpkgs/lib>;
          gits = import ($lib_path) { inherit lib; };
          config = import ./($CONFIG_FILE);
        in \(gits.build config\).scripts.($script_name)
    "
    
    let result = nix-instantiate --eval --strict --json -E $expr | complete
    
    if $result.exit_code != 0 {
        error make {msg: $"Error: failed to evaluate ($script_name) script"}
    }
    
    $result.stdout | str trim | from json
}

def run-script [script_name: string, ...args: string] {
    let script = eval-script $script_name
    if ($script | is-empty) {
        error make {msg: $"Error: failed to generate ($script_name) script"}
    }
    nu -c $script ...$args
}

# Initialize sparse checkout and/or injections from config
@category git
@example "Initialize workspace" { imp-gits init }
def "main init" []: nothing -> nothing {
    require-config
    require-git
    run-script "init"
}

# Show status of sparse checkout and injections
@category git
@example "Show text status" { imp-gits status }
@example "Show structured status" { imp-gits status -s }
def "main status" [
    --structured (-s)  # Output as structured data (requires gstat plugin)
] {
    require-config
    require-git
    
    if $structured {
        let gstat_available = (which gstat | is-not-empty)
        
        if not $gstat_available {
            error make {msg: "Error: --structured requires the gstat plugin. Install with: plugin add nu_plugin_gstat"}
        }
        
        let main_status = gstat
        let config_info = get-config-info
        
        {
            main: $main_status
            injections: ($config_info.injections | each {|inj|
                let git_dir = $"($GITS_DIR)/($inj.name).git"
                let exists = ($git_dir | path exists)
                {
                    name: $inj.name
                    remote: $inj.remote
                    use: ($inj.use? | default [])
                    initialized: $exists
                    status: (if $exists {
                        with-env {GIT_DIR: $git_dir, GIT_WORK_TREE: "."} {
                            try { gstat } catch { null }
                        }
                    } else { null })
                }
            })
        }
    } else {
        run-script "status"
    }
}

def get-config-info [] {
    let lib_path = gits-lib
    let expr = $"
        let
          lib = import <nixpkgs/lib>;
          gits = import ($lib_path) { inherit lib; };
          config = import ./($CONFIG_FILE);
          result = gits.build config;
        in {
          sparse = result.sparse;
          injections = builtins.map \(inj: {
            name = inj.name;
            remote = inj.remote;
            branch = inj.branch or \"main\";
            use = inj.use or [];
          }\) \(config.injections or []\);
        }
    "
    
    let result = nix-instantiate --eval --strict --json -E $expr | complete
    
    if $result.exit_code != 0 {
        error make {msg: "Error: failed to read configuration"}
    }
    
    $result.stdout | str trim | from json
}

# Pull updates for all injections
@category git
@example "Pull updates" { imp-gits pull }
@example "Force pull (reset to remote)" { imp-gits pull -f }
def "main pull" [
    --force (-f)  # Reset to remote state
]: nothing -> nothing {
    require-config
    require-git
    if $force {
        run-script "pull-force"
    } else {
        run-script "pull"
    }
}

# Push changes to injection remotes
@category git
@example "Push all injections" { imp-gits push }
def "main push" []: nothing -> nothing {
    require-config
    require-git
    run-script "push"
}

# Switch git context to an injection
#
# Outputs shell commands to eval.
@category git
@example "Switch to injection (bash)" { eval "$(imp-gits use mylib)" }
@example "Switch to injection (nu)" { imp-gits use mylib | from json | load-env }
@example "Switch back to main" { imp-gits use main }
def "main use" [
    context?: string  # Injection name or 'main' (default: main)
]: nothing -> string {
    require-config
    let ctx = $context | default "main"
    let script = eval-script "use"
    nu -c $script $ctx
}

# Exit injection context
#
# Outputs shell commands to unset GIT_DIR and GIT_WORK_TREE.
@category git
@example "Exit context (bash)" { eval "$(imp-gits exit)" }
@example "Exit context (nu)" { imp-gits exit | from json | load-env }
def "main exit" []: nothing -> string {
    let parent_shell = detect-parent-shell
    
    match $parent_shell {
        "fish" => { print "set -e GIT_DIR; set -e GIT_WORK_TREE" }
        "nu" => { print '{"GIT_DIR": null, "GIT_WORK_TREE": null}' }
        _ => { print "unset GIT_DIR GIT_WORK_TREE" }
    }
}

# List available contexts
@category git
@example "List contexts" { imp-gits list }
def "main list" []: nothing -> nothing {
    require-config
    let script = eval-script "use"
    nu -c $script list
}

# Declarative sparse checkout and multi-repo workspace composition
#
# Config: .imp/gits/config.nix
@category git
def main [] {
    help main
}

def detect-parent-shell []: nothing -> string {
    let processes = try { ps } catch { return "unknown" }
    
    let my_pid = $nu.pid
    let my_proc = try {
        $processes | where pid == $my_pid | first
    } catch {
        return "unknown"
    }
    
    mut current_ppid = $my_proc.ppid?
    mut depth = 0
    let max_depth = 10
    
    while $current_ppid != null and $depth < $max_depth {
        let parent = try {
            $processes | where pid == $current_ppid | first
        } catch {
            break
        }
        
        let name = $parent.name? | default ""
        
        if $name in ["fish", "nu", "bash", "zsh"] {
            return $name
        }
        
        $current_ppid = $parent.ppid?
        $depth = $depth + 1
    }
    
    "unknown"
}
