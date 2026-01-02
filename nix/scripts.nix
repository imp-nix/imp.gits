/**
  Shell script generation for sparse checkout and multi-repo workspace operations.
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
    sparseCheckoutInit
    sparseCheckoutStatus
    cloneCmd
    sparseCheckoutSetup
    fetchCmd
    pullCmd
    pushCmd
    statusCmd
    gitEnv
    ;

  scriptHeader = ''
    #!/usr/bin/env bash
    set -euo pipefail
  '';

  /**
    Generate sed substitution commands for template variables.

    Uses @var@ syntax (nix-style substituteAll convention) which is valid
    inside string literals in both nix and toml, allowing template files
    to keep their native extensions and be formatted normally.

    # Arguments

    - `vars` (attrset): Template variables { name = "value"; }

    # Returns

    Shell command string with sed expressions.
  */
  templateSubstitutions =
    vars:
    let
      varNames = attrNames vars;
      sedExprs = map (name: "-e 's|@${name}@|${lib.escapeShellArg vars.${name}}|g'") varNames;
    in
    if varNames == [ ] then "cat" else "sed ${concatStringsSep " " sedExprs}";

  /**
    Generate boilerplate spawn script for an injection.

    Supports two formats:
    - List of entries: [ "file.nix" { src = "a"; dest = "b"; } ]
    - Dir mapping: { dir = "boilerplate"; exclude = [ "README.md" ]; }

    # Arguments

    - `name` (string): Injection name
    - `boilerplate` (list or attrset): Boilerplate config
    - `vars` (attrset): Template variables

    # Returns

    Shell script fragment.
  */
  boilerplateSpawnScript =
    name: boilerplate: vars:
    let
      sedCmd = templateSubstitutions vars;
      hasVars = vars != { };

      # Script for spawning a single file (src -> dest)
      spawnFile = src: dest: ''
        destDir="$(dirname ${lib.escapeShellArg dest})"
        if [ -e ${lib.escapeShellArg dest} ]; then
          echo "    skip: ${dest} (exists)"
        else
          [ "$destDir" != "." ] && mkdir -p "$destDir"
          ${gitEnv name} git show HEAD:${lib.escapeShellArg src} ${
            if hasVars then "| ${sedCmd} " else ""
          }> ${lib.escapeShellArg dest}
          echo "    created: ${dest}"
        fi
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
          excludePattern =
            if excludes == [ ] then
              ""
            else
              " | grep -v " + concatStringsSep " | grep -v " (map (e: "-E ${lib.escapeShellArg e}") excludes);
        in
        ''
          ${gitEnv name} git ls-tree -r --name-only HEAD ${lib.escapeShellArg dir} ${excludePattern} | while read -r src; do
            dest="''${src#${lib.escapeShellArg dir}/}"
            destDir="$(dirname "$dest")"
            if [ -e "$dest" ]; then
              echo "    skip: $dest (exists)"
            else
              [ "$destDir" != "." ] && mkdir -p "$destDir"
              ${gitEnv name} git show "HEAD:$src" ${if hasVars then "| ${sedCmd} " else ""}> "$dest"
              echo "    created: $dest"
            fi
          done
        '';

      script = if isList boilerplate then listScript else dirScript;
    in
    if (isList boilerplate && boilerplate == [ ]) then
      ""
    else
      ''
        echo "  Spawning boilerplate files..."
        ${script}
      '';

  /**
    Generate initialization script for sparse checkout and/or injections.

    # Arguments

    - `config` (attrset): Config with optional `sparse`, `injections`, and `vars`

    # Returns

    Shell script string.
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
            echo "Setting up sparse checkout${targetLabel} (${sparseInfo.mode} mode)..."
            echo "  ${
              if sparseInfo.mode == "cone" then "paths" else "patterns"
            }: ${concatStringsSep ", " sparseInfo.items}"
            ${sparseCheckoutInit sparseConfig target}
            echo "  Done"
          ''
        else
          "";

      setupDir =
        if hasInjections then
          ''
            echo ""
            echo "Setting up injections..."
            mkdir -p ${gitsDir}/tmp
            cat > ${gitsDir}/.gitignore << 'EOF'
            *
            !.gitignore
            !config.nix
            EOF
          ''
        else
          "";

      perInjection =
        injection:
        let
          name = injection.name;
          sparseContent = sparseCheckoutPatterns injection;
          excludeContent = injectionExcludes injection;
          useList = injection.use or [ ];
          boilerplate = injection.boilerplate or null;
          hasUse = useList != [ ];
          hasBoilerplate = boilerplate != null;
          useChecks = concatStringsSep "\n" (
            map (p: ''
              tracked=$(git ls-files ${lib.escapeShellArg p} 2>/dev/null || true)
              if [ -n "$tracked" ]; then
                conflicts="$conflicts ${lib.escapeShellArg p}"
              fi
            '') useList
          );
          useSummary = if hasUse then "\n  Use: ${concatStringsSep ", " useList}" else "";
          boilerplateSummary =
            if !hasBoilerplate then
              ""
            else if isList boilerplate then
              "\n  Boilerplate: ${toString (length boilerplate)} file(s)"
            else
              "\n  Boilerplate: ${boilerplate.dir}/";
        in
        ''
          echo ""
          echo "Initializing: ${name}"
          echo "  Remote: ${injection.remote}${useSummary}${boilerplateSummary}"

          if [ -d "${gitsDir}/${name}.git" ]; then
            echo "  Updating sparse-checkout..."
            ${if hasUse then sparseCheckoutSetup name sparseContent excludeContent useList else ""}
            ${if hasBoilerplate then boilerplateSpawnScript name boilerplate vars else ""}
            echo "  Done"
          else
            ${
              if hasUse then
                ''
                  conflicts=""
                  ${useChecks}
                  if [ -n "$conflicts" ]; then
                    echo "  ERROR: Paths tracked by main repo but used by ${name}:$conflicts"
                    echo "  Fix with: git rm --cached <path>"
                    exit 1
                  fi
                ''
              else
                ""
            }

            ${cloneCmd name injection}
            ${if hasUse then sparseCheckoutSetup name sparseContent excludeContent useList else ""}
            ${if hasBoilerplate then boilerplateSpawnScript name boilerplate vars else ""}
            echo "  Done"
          fi
        '';

      injectionsBody = if hasInjections then concatStringsSep "\n" (map perInjection injections) else "";

      footer = ''

        echo ""
        echo "Initialized"
      '';
    in
    if !validation.valid then
      throw "Invalid configuration:\n${concatStringsSep "\n" validation.errors}"
    else
      scriptHeader + sparseSetup + setupDir + injectionsBody + footer;

  /**
    Generate pull script to update all injections from remotes.

    # Arguments

    - `config` (attrset): Config with optional `injections`

    # Returns

    Shell script string.
  */
  pullScript =
    config:
    let
      injections = config.injections or [ ];

      perInjection =
        injection:
        let
          name = injection.name;
          sparseContent = sparseCheckoutPatterns injection;
          excludeContent = injectionExcludes injection;
          useList = injection.use or [ ];
        in
        ''
          echo "Pulling: ${name}"
          if ${pullCmd name injection}; then
            ${sparseCheckoutSetup name sparseContent excludeContent useList}
          else
            echo "  Warning: pull failed for ${name}"
          fi
        '';

      body = concatStringsSep "\n" (map perInjection injections);
    in
    scriptHeader
    + ''
      ${body}
    '';

  /**
    Generate force pull script (fetch + checkout specific paths).

    Only updates the paths specified in the injection's `use` list,
    preserving any local files that aren't part of the injection.

    # Arguments

    - `config` (attrset): Config with optional `injections`

    # Returns

    Shell script string.
  */
  pullForceScript =
    config:
    let
      injections = config.injections or [ ];

      perInjection =
        injection:
        let
          name = injection.name;
          branch = injection.branch or "main";
          sparseContent = sparseCheckoutPatterns injection;
          excludeContent = injectionExcludes injection;
          useList = injection.use or [ ];
          # Escape each path for shell
          usePaths = concatStringsSep " " (map lib.escapeShellArg useList);
        in
        ''
          echo "Force pulling: ${name}"
          ${fetchCmd name injection}

          # Update sparse-checkout config first
          ${sparseCheckoutSetup name sparseContent excludeContent useList}

          # Force checkout only the specific paths from the injection
          # This preserves local files that aren't part of the injection
          ${gitEnv name} git checkout -f origin/${lib.escapeShellArg branch} -- ${usePaths}
          echo "  Updated: ${concatStringsSep ", " useList}"
        '';

      body = concatStringsSep "\n" (map perInjection injections);
    in
    scriptHeader
    + ''
      ${body}
    '';

  /**
    Generate push script to push changes back to injection remotes.

    # Arguments

    - `config` (attrset): Config with optional `injections`

    # Returns

    Shell script string.
  */
  pushScript =
    config:
    let
      injections = config.injections or [ ];

      perInjection = injection: ''
        echo "Pushing: ${injection.name}"
        ${pushCmd injection.name injection} || echo "  Warning: push failed for ${injection.name}"
      '';

      body = concatStringsSep "\n" (map perInjection injections);
    in
    scriptHeader
    + ''
      echo "This will push to upstream repositories. Press Enter to continue..."
      read -r
      ${body}
    '';

  /**
    Generate status script showing state of sparse checkout and injections.

    # Arguments

    - `config` (attrset): Config with optional `sparse` and `injections`

    # Returns

    Shell script string.
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
            echo ""
          ''
        else
          "";

      perInjection = injection: ''
        echo "${injection.name}:"
        echo "  remote: ${injection.remote}"
        echo "  use: ${concatStringsSep ", " (injection.use or [ ])}"
        ${statusCmd injection.name} 2>/dev/null | sed 's/^/  /' || echo "  (not initialized)"
        echo ""
      '';

      injectionsBody = concatStringsSep "\n" (map perInjection injections);
    in
    scriptHeader
    + ''
      echo "main:"
      git status --short | sed 's/^/  /' || true
      ${sparseStatus}
      ${injectionsBody}
    '';

  /**
    Generate a helper script that wraps git commands for a specific injection.

    # Arguments

    - `name` (string): Injection name

    # Returns

    Shell script string.
  */
  injectionGitWrapper =
    name:
    scriptHeader
    + ''
      ${gitEnv name} git "$@"
    '';

  /**
    Generate context-switching script.

    Outputs shell commands to switch git context. Wrap in eval to apply.

    # Arguments

    - `config` (attrset): Config with optional `injections`

    # Returns

    Shell script string.
  */
  useScript =
    config:
    let
      injections = config.injections or [ ];
      injectionNames = map (inj: inj.name) injections;
      namesStr = concatStringsSep ", " injectionNames;

      perInjectionCase = name: ''
        ${name})
            ABS_GIT_DIR="$PWD/${git.injectionGitDir name}"
            case "$PARENT_SHELL" in
              fish)
                echo "set -gx GIT_DIR '$ABS_GIT_DIR'; set -gx GIT_WORK_TREE '$PWD'"
                ;;
              nu)
                printf '{"GIT_DIR": "%s", "GIT_WORK_TREE": "%s"}\n' "$ABS_GIT_DIR" "$PWD"
                ;;
              *)
                echo "export GIT_DIR='$ABS_GIT_DIR'; export GIT_WORK_TREE='$PWD'"
                ;;
            esac
            ;;
      '';

      cases = concatStringsSep "\n    " (map perInjectionCase injectionNames);
    in
    scriptHeader
    + ''
      # Detect parent shell by walking up process tree
      detect_shell() {
        local pid=$PPID
        while [ "$pid" != "1" ] && [ -n "$pid" ]; do
          local comm=$(cat /proc/$pid/comm 2>/dev/null || echo "")
          case "$comm" in
            fish|nu|bash|zsh) echo "$comm"; return ;;
          esac
          pid=$(cut -d' ' -f4 /proc/$pid/stat 2>/dev/null || echo "1")
        done
        echo "unknown"
      }
      PARENT_SHELL=$(detect_shell)

      show_help() {
        echo "Usage: eval \"\\\$(imp-gits use [context])\""
        echo ""
        echo "Contexts: main (default), ${namesStr}"
        echo ""
        echo "Commands: list, help"
      }

      case "''${1:-main}" in
        -h|--help|help)
          show_help
          ;;
        list)
          echo "main (default)"
          ${concatStringsSep "\n      " (map (n: ''echo "${n}"'') injectionNames)}
          ;;
        main)
          case "$PARENT_SHELL" in
            fish)
              echo "set -e GIT_DIR; set -e GIT_WORK_TREE"
              ;;
            nu)
              echo '{"GIT_DIR": null, "GIT_WORK_TREE": null}'
              ;;
            *)
              echo "unset GIT_DIR GIT_WORK_TREE"
              ;;
          esac
          ;;
        ${cases}
        *)
          echo "echo 'Unknown: $1. Available: main, ${namesStr}' >&2"
          echo "false"
          ;;
      esac
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
