/**
  Shell script generation for multi-repo workspace operations.
*/
{
  lib,
  manifest,
  gitignore,
  git,
}:
let
  inherit (builtins) concatStringsSep map;

  inherit (manifest) validateManifest;
  inherit (gitignore) sparseCheckoutPatterns injectionExcludes;
  inherit (git)
    gitbitsDir
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
    Generate initialization script.

    Sets up .gitbits directory, clones all injections with sparse checkout.
    Injections are processed in order - later ones override earlier ones.

    # Arguments

    - `injections` (list): List of injection configs

    # Returns

    Shell script string.
  */
  initScript =
    injections:
    let
      validation = validateManifest injections;

      setupDir = ''
        echo "Setting up imp.gitbits workspace..."
        mkdir -p ${gitbitsDir}/tmp
        cat > ${gitbitsDir}/.gitignore << 'EOF'
        *
        !.gitignore
        !config.nix
        EOF
      '';

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

          if [ -d "${gitbitsDir}/${name}.git" ]; then
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

      body = concatStringsSep "\n" (map perInjection injections);

      footer = ''

        echo ""
        echo "Workspace initialized"
      '';
    in
    if !validation.valid then
      throw "Invalid injection configuration:\n${concatStringsSep "\n" validation.errors}"
    else
      scriptHeader + setupDir + body + footer;

  /**
    Generate pull script to update all injections from remotes.

    # Arguments

    - `injections` (list): List of injection configs

    # Returns

    Shell script string.
  */
  pullScript =
    injections:
    let
      perInjection = injection:
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

    - `injections` (list): List of injection configs

    # Returns

    Shell script string.
  */
  pullForceScript =
    injections:
    let
      perInjection = injection:
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

    - `injections` (list): List of injection configs

    # Returns

    Shell script string.
  */
  pushScript =
    injections:
    let
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
    Generate status script showing state of all repos.

    # Arguments

    - `injections` (list): List of injection configs

    # Returns

    Shell script string.
  */
  statusScript =
    injections:
    let
      perInjection = injection: ''
        echo "${injection.name}:"
        echo "  remote: ${injection.remote}"
        echo "  use: ${concatStringsSep ", " (injection.use or [ ])}"
        ${statusCmd injection.name} 2>/dev/null | sed 's/^/  /' || echo "  (not initialized)"
        echo ""
      '';

      body = concatStringsSep "\n" (map perInjection injections);
    in
    scriptHeader
    + ''
      echo "main:"
      git status | sed 's/^/  /'
      echo ""
      ${body}
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

    - `injections` (list): List of injection configs

    # Returns

    Shell script string.
  */
  useScript =
    injections:
    let
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
        echo "Usage: eval \"\\\$(git bits use [context])\""
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
