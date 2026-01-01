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
    ;

  inherit (manifest) validateConfig;
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
    Generate initialization script for sparse checkout and/or injections.

    # Arguments

    - `config` (attrset): Config with optional `sparse` and `injections`

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
          useChecks = concatStringsSep "\n" (
            map (p: ''
              tracked=$(git ls-files ${lib.escapeShellArg p} 2>/dev/null || true)
              if [ -n "$tracked" ]; then
                conflicts="$conflicts ${lib.escapeShellArg p}"
              fi
            '') useList
          );
        in
        ''
          echo ""
          echo "Initializing: ${name}"
          echo "  Remote: ${injection.remote}"
          echo "  Use: ${concatStringsSep ", " useList}"

          if [ -d "${gitsDir}/${name}.git" ]; then
            echo "  Updating sparse-checkout..."
            ${sparseCheckoutSetup name sparseContent excludeContent useList}
            echo "  Done"
          else
            conflicts=""
            ${useChecks}
            if [ -n "$conflicts" ]; then
              echo "  ERROR: Paths tracked by main repo but used by ${name}:$conflicts"
              echo "  Fix with: git rm --cached <path>"
              exit 1
            fi

            ${cloneCmd name injection}
            ${sparseCheckoutSetup name sparseContent excludeContent useList}
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
    Generate force pull script (fetch + reset --hard).

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
        in
        ''
          echo "Force pulling: ${name}"
          ${fetchCmd name injection}

          # Checkout all files from origin to clear any local modifications
          # This is needed before sparse-checkout can properly exclude files
          ${gitEnv name} git checkout origin/${lib.escapeShellArg branch} -- . 2>/dev/null || true

          # Update sparse-checkout to new paths
          ${sparseCheckoutSetup name sparseContent excludeContent useList}

          # Now reset to origin (should be clean now)
          ${gitEnv name} git reset --hard origin/${lib.escapeShellArg branch}
          echo "  Reset to origin/${branch}"
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
