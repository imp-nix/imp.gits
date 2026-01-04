/**
  Nushell script generation for sparse checkout and multi-repo workspace operations.
*/
{
  lib,
  manifest,
  gitignore,
  git,
}:
let
  inherit (builtins)
    concatStringsSep
    map
    length
    hasAttr
    isList
    isAttrs
    isString
    attrNames
    ;

  inherit (manifest) validateConfig allBoilerplatePaths;
  inherit (gitignore) sparseCheckoutPatterns injectionExcludes;
  inherit (git)
    gitsDir
    escapeNuStr
    nuList
    sparseCheckoutInit
    sparseCheckoutStatus
    cloneCmd
    sparseCheckoutSetup
    fetchCmd
    pullCmd
    pushCmd
    statusCmd
    gitEnvRecord
    injectionGitDir
    ;

  # Common script header with helper functions
  scriptHeader = ''
    # Helper: run git command with error handling
    def --wrapped run-git [...args: string] {
        let result = (git ...$args | complete)
        if $result.exit_code != 0 {
            if ($result.stderr | is-not-empty) {
                print -e ($result.stderr | str trim)
            }
            error make {msg: $"git ($args | str join ' ') failed"}
        }
        $result.stdout
    }
  '';

  /**
    Generate sed substitution for template variables (Nushell version).

    Uses @var@ syntax for template substitution.

    # Arguments

    - `vars` (attrset): Template variables { name = "value"; }

    # Returns

    Nushell command string that transforms $in.
  */
  templateSubstitutions =
    vars:
    let
      varNames = attrNames vars;
      replacements = map (name: ''str replace -a "@${name}@" ${escapeNuStr vars.${name}}'') varNames;
    in
    if varNames == [ ] then "$in" else "$in | ${concatStringsSep " | " replacements}";

  /**
    Generate boilerplate spawn script for an injection (Nushell).

    # Arguments

    - `name` (string): Injection name
    - `boilerplate` (list or attrset): Boilerplate config
    - `vars` (attrset): Template variables

    # Returns

    Nushell script fragment.
  */
  boilerplateSpawnScript =
    name: boilerplate: vars:
    let
      hasVars = vars != { };
      transform = templateSubstitutions vars;

      # Script for spawning a single file (src -> dest)
      spawnFile = src: dest: ''
        if (${escapeNuStr dest} | path exists) {
            print $"    skip: ${dest} \(exists\)"
        } else {
            let dest_dir = (${escapeNuStr dest} | path dirname)
            if $dest_dir != "." { mkdir $dest_dir }
            with-env ${gitEnvRecord name} {
                let content = (git show $"HEAD:${src}")
                ${
                  if hasVars then "${transform} | save ${escapeNuStr dest}" else "$content | save ${escapeNuStr dest}"
                }
            }
            print $"    created: ${dest}"
        }
      '';

      # Handle list format
      listScript =
        let
          normalizeEntry =
            entry:
            if isString entry then
              {
                src = entry;
                dest = entry;
              }
            else
              {
                inherit (entry) src;
                dest = entry.dest or entry.src;
              };
          entries = map normalizeEntry boilerplate;
        in
        concatStringsSep "\n" (map (e: spawnFile e.src e.dest) entries);

      # Handle dir format: { dir = "boilerplate"; exclude = [...]; }
      dirScript =
        let
          dir = boilerplate.dir;
          excludes = boilerplate.exclude or [ ];
          excludeFilter =
            if excludes == [ ] then "" else " | where {|f| not (${nuList excludes} | any {|ex| $f =~ $ex})}";
        in
        ''
          with-env ${gitEnvRecord name} {
              git ls-tree -r --name-only HEAD ${escapeNuStr dir}
                  | lines${excludeFilter}
                  | each {|src|
                      let dest = ($src | str replace ${escapeNuStr "${dir}/"} "")
                      if ($dest | path exists) {
                          print $"    skip: ($dest) \(exists\)"
                      } else {
                          let dest_dir = ($dest | path dirname)
                          if $dest_dir != "." { mkdir $dest_dir }
                          let content = (git show $"HEAD:($src)")
                          ${if hasVars then "${transform} | save $dest" else "$content | save $dest"}
                          print $"    created: ($dest)"
                      }
                  }
          }
        '';

      script = if isList boilerplate then listScript else dirScript;
    in
    if (isList boilerplate && boilerplate == [ ]) then
      ""
    else
      ''
        print "  Spawning boilerplate files..."
        ${script}
      '';

  /**
    Generate initialization script for sparse checkout and/or injections (Nushell).

    # Arguments

    - `config` (attrset): Config with optional `sparse`, `injections`, and `vars`

    # Returns

    Nushell script string.
  */
  initScript =
    config:
    let
      validation = validateConfig config;
      sparseConfig = config.sparse or null;
      target = config.target or null;
      injections = config.injections or [ ];
      vars = config.vars or { };

      # Normalize sparse config for display
      sparseInfo =
        if sparseConfig == null then
          null
        else if isList sparseConfig then
          {
            mode = "cone";
            items = sparseConfig;
          }
        else
          {
            mode = sparseConfig.mode or "cone";
            items =
              if (sparseConfig.mode or "cone") == "cone" then
                sparseConfig.paths or [ ]
              else
                sparseConfig.patterns or [ ];
          };

      hasSparse = sparseInfo != null && length sparseInfo.items > 0;
      hasInjections = hasAttr "injections" config && length injections > 0;
      targetLabel = if target != null then " for ${target}" else "";

      sparseSetup =
        if hasSparse then
          ''
            print $"Setting up sparse checkout${targetLabel} [${sparseInfo.mode} mode]..."
            print $"  ${
              if sparseInfo.mode == "cone" then "paths" else "patterns"
            }: ${concatStringsSep ", " sparseInfo.items}"
            ${sparseCheckoutInit sparseConfig target}
            print "  Done"
          ''
        else
          "";

      setupDir =
        if hasInjections then
          ''
            print ""
            print "Setting up injections..."
            mkdir "${gitsDir}/tmp"
            "*\n!.gitignore\n!config.nix" | save -f "${gitsDir}/.gitignore"
          ''
        else
          "";

      perInjection =
        injection:
        let
          injName = injection.name;
          sparseContent = sparseCheckoutPatterns injection;
          excludeContent = injectionExcludes injection;
          useList = injection.use or [ ];
          boilerplate = injection.boilerplate or null;
          hasUse = useList != [ ];
          hasBoilerplate = boilerplate != null;

          useChecks = ''
            mut conflicts = []
            for path in ${nuList useList} {
                let tracked = (git ls-files $path | complete)
                if $tracked.exit_code == 0 and ($tracked.stdout | str trim | is-not-empty) {
                    $conflicts = ($conflicts | append $path)
                }
            }
            if ($conflicts | is-not-empty) {
                print -e $"  ERROR: Paths tracked by main repo but used by ${injName}:"
                for c in $conflicts { print -e $"    ($c)" }
                print -e "  Fix with: git rm --cached <path>"
                exit 1
            }
          '';

          useSummary = if hasUse then "\\n  Use: ${concatStringsSep ", " useList}" else "";
          boilerplateSummary =
            if !hasBoilerplate then
              ""
            else if isList boilerplate then
              "\\n  Boilerplate: ${toString (length boilerplate)} file(s)"
            else
              "\\n  Boilerplate: ${boilerplate.dir}/";
        in
        ''
          print ""
          print "Initializing: ${injName}"
          print $"  Remote: ${injection.remote}${useSummary}${boilerplateSummary}"

          if (${escapeNuStr "${gitsDir}/${injName}.git"} | path exists) {
              print "  Updating sparse-checkout..."
              ${if hasUse then sparseCheckoutSetup injName sparseContent excludeContent useList else ""}
              ${if hasBoilerplate then boilerplateSpawnScript injName boilerplate vars else ""}
              print "  Done"
          } else {
              ${if hasUse then useChecks else ""}
              ${cloneCmd injName injection}
              ${if hasUse then sparseCheckoutSetup injName sparseContent excludeContent useList else ""}
              ${if hasBoilerplate then boilerplateSpawnScript injName boilerplate vars else ""}
              print "  Done"
          }
        '';

      injectionsBody = if hasInjections then concatStringsSep "\n" (map perInjection injections) else "";

      footer = ''

        print ""
        print "Initialized"
      '';
    in
    if !validation.valid then
      throw "Invalid configuration:\n${concatStringsSep "\n" validation.errors}"
    else
      scriptHeader + sparseSetup + setupDir + injectionsBody + footer;

  /**
    Generate pull script to update all injections from remotes (Nushell).

    # Arguments

    - `config` (attrset): Config with optional `injections`

    # Returns

    Nushell script string.
  */
  pullScript =
    config:
    let
      injections = config.injections or [ ];

      perInjection =
        injection:
        let
          injName = injection.name;
          sparseContent = sparseCheckoutPatterns injection;
          excludeContent = injectionExcludes injection;
          useList = injection.use or [ ];
        in
        ''
          print $"Pulling: ${injName}"
          let success = (do {
              ${pullCmd injName injection}
          })
          if $success {
              ${sparseCheckoutSetup injName sparseContent excludeContent useList}
          }
        '';

      body = concatStringsSep "\n" (map perInjection injections);
    in
    scriptHeader + body;

  /**
    Generate force pull script (fetch + checkout specific paths) (Nushell).

    # Arguments

    - `config` (attrset): Config with optional `injections`

    # Returns

    Nushell script string.
  */
  pullForceScript =
    config:
    let
      injections = config.injections or [ ];

      perInjection =
        injection:
        let
          injName = injection.name;
          branch = injection.branch or "main";
          sparseContent = sparseCheckoutPatterns injection;
          excludeContent = injectionExcludes injection;
          useList = injection.use or [ ];
        in
        ''
          print $"Force pulling: ${injName}"
          ${fetchCmd injName injection}
          ${sparseCheckoutSetup injName sparseContent excludeContent useList}
          with-env ${gitEnvRecord injName} {
              run-git checkout -f $"origin/${branch}" "--" ...${nuList useList}
          }
          print $"  Updated: ${concatStringsSep ", " useList}"
        '';

      body = concatStringsSep "\n" (map perInjection injections);
    in
    scriptHeader + body;

  /**
    Generate push script to push changes back to injection remotes (Nushell).

    # Arguments

    - `config` (attrset): Config with optional `injections`

    # Returns

    Nushell script string.
  */
  pushScript =
    config:
    let
      injections = config.injections or [ ];

      perInjection = injection: ''
        print $"Pushing: ${injection.name}"
        ${pushCmd injection.name injection}
      '';

      body = concatStringsSep "\n" (map perInjection injections);
    in
    scriptHeader
    + ''
      print "This will push to upstream repositories. Press Enter to continue..."
      input
      ${body}
    '';

  /**
    Generate status script showing state of sparse checkout and injections (Nushell).

    # Arguments

    - `config` (attrset): Config with optional `sparse` and `injections`

    # Returns

    Nushell script string.
  */
  statusScript =
    config:
    let
      sparseConfig = config.sparse or null;
      target = config.target or null;
      injections = config.injections or [ ];

      # Check if sparse is configured (list or attrset with items)
      hasSparse =
        if sparseConfig == null then
          false
        else if isList sparseConfig then
          length sparseConfig > 0
        else
          length (sparseConfig.paths or sparseConfig.patterns or [ ]) > 0;

      sparseStatus =
        if hasSparse then
          ''
            ${sparseCheckoutStatus target}
            print ""
          ''
        else
          "";

      perInjection = injection: ''
        print $"${injection.name}:"
        print $"  remote: ${injection.remote}"
        print $"  use: ${concatStringsSep ", " (injection.use or [ ])}"
        let status_result = (do {
            with-env ${gitEnvRecord injection.name} {
                git status | complete
            }
        })
        if $status_result.exit_code == 0 {
            $status_result.stdout | lines | each {|line| print $"  ($line)" }
        } else {
            print "  (not initialized)"
        }
        print ""
      '';

      injectionsBody = concatStringsSep "\n" (map perInjection injections);
    in
    scriptHeader
    + ''
      print "main:"
      let main_status = (git status --short | complete)
      if $main_status.exit_code == 0 {
          $main_status.stdout | lines | each {|line| print $"  ($line)" }
      }
      ${sparseStatus}
      ${injectionsBody}
    '';

  /**
    Generate a helper script that wraps git commands for a specific injection (Nushell).

    # Arguments

    - `name` (string): Injection name

    # Returns

    Nushell script string.
  */
  injectionGitWrapper = name: ''
    def main [...args: string] {
        with-env ${gitEnvRecord name} {
            git ...$args
        }
    }
  '';

  /**
    Generate context-switching script (Nushell).

    Outputs shell commands to switch git context.

    # Arguments

    - `config` (attrset): Config with optional `injections`

    # Returns

    Nushell script string.
  */
  useScript =
    config:
    let
      injections = config.injections or [ ];
      injectionNames = map (inj: inj.name) injections;
      namesStr = concatStringsSep ", " injectionNames;

      # Detect parent shell by walking process tree
      detectShell = ''
        def detect-parent-shell []: nothing -> string {
            let processes = (try { ps } catch { return "unknown" })
            let my_pid = $nu.pid
            let my_proc = (try { $processes | where pid == $my_pid | first } catch { return "unknown" })

            mut current_ppid = $my_proc.ppid?
            mut depth = 0
            let max_depth = 10

            while $current_ppid != null and $depth < $max_depth {
                let parent = (try { $processes | where pid == $current_ppid | first } catch { break })
                let name = ($parent.name? | default "")

                if $name in ["fish", "nu", "bash", "zsh"] {
                    return $name
                }

                $current_ppid = $parent.ppid?
                $depth = $depth + 1
            }

            "unknown"
        }
      '';

      perInjectionCase = name: ''
        "${name}" => {
            let abs_git_dir = $"(pwd)/${injectionGitDir name}"
            match $parent_shell {
                "fish" => { print $"set -gx GIT_DIR '($abs_git_dir)'; set -gx GIT_WORK_TREE '(pwd)'" }
                "nu" => { {GIT_DIR: $abs_git_dir, GIT_WORK_TREE: (pwd)} }
                _ => { print $"export GIT_DIR='($abs_git_dir)'; export GIT_WORK_TREE='(pwd)'" }
            }
        }
      '';

      cases = concatStringsSep "\n        " (map perInjectionCase injectionNames);
    in
    ''
      ${detectShell}

      def main [context?: string] {
          let parent_shell = detect-parent-shell
          let ctx = ($context | default "main")

          match $ctx {
              "-h" | "--help" | "help" => {
                  print 'Usage: eval "$(imp-gits use [context])"'
                  print ""
                  print "Contexts: main (default), ${namesStr}"
                  print ""
                  print "Commands: list, help"
              }
              "list" => {
                  print "main (default)"
                  ${concatStringsSep "\n            " (map (n: ''print "${n}"'') injectionNames)}
              }
              "main" => {
                  match $parent_shell {
                      "fish" => { print "set -e GIT_DIR; set -e GIT_WORK_TREE" }
                      "nu" => { {GIT_DIR: null, GIT_WORK_TREE: null} }
                      _ => { print "unset GIT_DIR GIT_WORK_TREE" }
                  }
              }
              ${cases}
              _ => {
                  print -e $"Unknown: ($ctx). Available: main, ${namesStr}"
                  exit 1
              }
          }
      }
    '';

in
{
  inherit
    initScript
    pullScript
    pullForceScript
    pushScript
    statusScript
    injectionGitWrapper
    useScript
    ;
}
