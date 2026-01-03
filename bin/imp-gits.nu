#!/usr/bin/env nu
# imp-gits: Declarative sparse checkout and multi-repo workspace composition
#
# For Nushell users who want structured output (e.g., for `use | load-env`),
# load this module in your config.nu:
#
#   use /path/to/imp-gits.nu *
#   imp gits use rust-boilerplate | load-env

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
    let expr_template = [
        'let'
        '  lib = import <nixpkgs/lib>;'
        '  gits = import (builtins.toPath "__LIB__") { inherit lib; };'
        '  config = import ./__CONFIG__;'
        'in (gits.build config).scripts.__SCRIPT__'
    ] | str join "\n"
    let expr = ($expr_template
        | str replace "__LIB__" $lib_path
        | str replace "__CONFIG__" $CONFIG_FILE
        | str replace "__SCRIPT__" $script_name
    )
    
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
    let expr_template = [
        'let'
        '  lib = import <nixpkgs/lib>;'
        '  gits = import (builtins.toPath "__LIB__") { inherit lib; };'
        '  config = import ./__CONFIG__;'
        '  result = gits.build config;'
        'in {'
        '  sparse = result.sparse;'
        '  injections = builtins.map (inj: {'
        '    name = inj.name;'
        '    remote = inj.remote;'
        '    branch = inj.branch or "main";'
        '    use = inj.use or [];'
        '  }) (config.injections or []);'
        '}'
    ] | str join "\n"
    let expr = ($expr_template
        | str replace "__LIB__" $lib_path
        | str replace "__CONFIG__" $CONFIG_FILE
    )
    
    let result = nix-instantiate --eval --strict --json -E $expr | complete
    
    if $result.exit_code != 0 {
        error make {msg: "Error: failed to read configuration"}
    }
    
    $result.stdout | str trim | from json
}

def gits-use [
    context?: string  # Injection name or 'main' (default: main)
    --list (-l)       # List available contexts
] {
    require-config
    let config_info = get-config-info
    let injection_names = ($config_info.injections | get name)

    if $list {
        ["main" ...$injection_names]
    } else {
        let ctx = $context | default "main"
        let cwd = pwd

        if $ctx == "main" {
            {GIT_DIR: null, GIT_WORK_TREE: null}
        } else if $ctx in $injection_names {
            let abs_git_dir = [$cwd ".imp" "gits" $"($ctx).git"] | path join
            {GIT_DIR: $abs_git_dir, GIT_WORK_TREE: $cwd}
        } else {
            error make {msg: $"Unknown context: ($ctx). Available: main, ($injection_names | str join ', ')"}
        }
    }
}

def gits-exit [] {
    {GIT_DIR: null, GIT_WORK_TREE: null}
}

def gits-list [] {
    require-config
    let config_info = get-config-info
    let injection_names = ($config_info.injections | get name)
    ["main (default)" ...$injection_names]
}

export def "imp gits init" [] {
    main init
}

export def "imp gits status" [
    --structured (-s)  # Output as structured data (requires gstat plugin)
] {
    main status --structured=$structured
}

export def "imp gits pull" [
    --force (-f)  # Reset to remote state
] {
    main pull --force=$force
}

export def "imp gits push" [] {
    main push
}

export def "imp gits use" [
    context?: string  # Injection name or 'main' (default: main)
    --list (-l)       # List available contexts
] {
    gits-use $context --list=$list
}

export def "imp gits exit" [] {
    gits-exit
}

export def "imp gits list" [] {
    gits-list
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
# Returns a record for load-env.
@category git
@example "Switch to injection" { imp-gits use mylib | load-env }
@example "Switch back to main" { imp-gits use main | load-env }
@example "List contexts" { imp-gits use --list }
def "main use" [
    context?: string  # Injection name or 'main' (default: main)
    --list (-l)       # List available contexts
] {
    gits-use $context --list=$list | to nuon
}

# Exit injection context (alias for `use main`)
#
# Returns a record that unsets GIT_DIR and GIT_WORK_TREE.
@category git
@example "Exit context" { imp-gits exit | load-env }
def "main exit" [] {
    gits-exit | to nuon
}

# List available contexts
@category git
@example "List contexts" { imp-gits list }
def "main list" [] {
    gits-list | to nuon
}

# Declarative sparse checkout and multi-repo workspace composition
#
# Config: .imp/gits/config.nix
@category git
def main [] {
    help main
}


