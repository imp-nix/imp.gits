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
  inherit (builtins) concatStringsSep;

  inherit (lib) mapAttrsToList;

  inherit (manifest) validateManifest;
  inherit (gitignore) mainRepoExcludes sparseCheckoutPatterns;
  inherit (git)
    gitbitsDir
    cloneCmd
    sparseCheckoutSetup
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

    Sets up .gitbits directory, clones all injections with sparse checkout,
    and configures main repo gitignore.

    # Arguments

    - `injections` (attrset): Map of injection name -> config

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
        mkdir -p .git/info
        if ! grep -q "imp.gitbits managed" .git/info/exclude 2>/dev/null; then
          cat >> .git/info/exclude << 'EXCLUDE_EOF'
        ${mainRepoExcludes injections}
        EXCLUDE_EOF
          echo "Updated .git/info/exclude"
        fi
      '';

      perInjection =
        name: injection:
        let
          sparseContent = sparseCheckoutPatterns injection;
          ownsList = injection.owns or [ ];
          ownsChecks = concatStringsSep "\n" (
            map (p: ''
              if git ls-files --error-unmatch ${lib.escapeShellArg p} >/dev/null 2>&1; then
                conflicts="$conflicts ${lib.escapeShellArg p}"
              fi
            '') ownsList
          );
        in
        ''
          echo ""
          echo "Initializing: ${name}"
          echo "  Remote: ${injection.remote}"
          echo "  Owns: ${concatStringsSep ", " ownsList}"

          if [ -d "${gitbitsDir}/${name}.git" ]; then
            echo "  Already initialized"
          else
            conflicts=""
            ${ownsChecks}
            if [ -n "$conflicts" ]; then
              echo "  ERROR: Paths tracked by main repo but claimed by ${name}:$conflicts"
              echo "  Fix with: git rm --cached <path>"
              exit 1
            fi

            ${cloneCmd name injection}
            ${sparseCheckoutSetup name sparseContent}
            echo "  Done"
          fi
        '';

      body = concatStringsSep "\n" (mapAttrsToList perInjection injections);

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

    - `injections` (attrset): Map of injection name -> config

    # Returns

    Shell script string.
  */
  pullScript =
    injections:
    let
      perInjection = name: injection: ''
        echo "Pulling: ${name}"
        ${pullCmd name injection} || echo "  Warning: pull failed for ${name}"
      '';

      body = concatStringsSep "\n" (mapAttrsToList perInjection injections);
    in
    scriptHeader
    + ''
      ${body}
    '';

  /**
    Generate push script to push changes back to injection remotes.

    # Arguments

    - `injections` (attrset): Map of injection name -> config

    # Returns

    Shell script string.
  */
  pushScript =
    injections:
    let
      perInjection = name: injection: ''
        echo "Pushing: ${name}"
        ${pushCmd name injection} || echo "  Warning: push failed for ${name}"
      '';

      body = concatStringsSep "\n" (mapAttrsToList perInjection injections);
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

    - `injections` (attrset): Map of injection name -> config

    # Returns

    Shell script string.
  */
  statusScript =
    injections:
    let
      perInjection = name: injection: ''
        echo "${name}:"
        echo "  remote: ${injection.remote}"
        echo "  owns: ${concatStringsSep ", " (injection.owns or [ ])}"
        ${statusCmd name} 2>/dev/null | sed 's/^/  /' || echo "  (not initialized)"
        echo ""
      '';

      body = concatStringsSep "\n" (mapAttrsToList perInjection injections);
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

    - `injections` (attrset): Map of injection name -> config

    # Returns

    Shell script string.
  */
  useScript =
    injections:
    let
      injectionNames = builtins.attrNames injections;
      namesStr = concatStringsSep ", " injectionNames;

      perInjectionCase = name: ''
        ${name})
            echo "export GIT_DIR='${git.injectionGitDir name}'"
            echo "export GIT_WORK_TREE='.'"
            ;;
      '';

      cases = concatStringsSep "\n    " (map perInjectionCase injectionNames);
    in
    scriptHeader
    + ''
      show_help() {
        echo "Usage: eval \"\\\$(gitbits-use [context])\""
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
          echo "unset GIT_DIR GIT_WORK_TREE"
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
    pushScript
    statusScript
    injectionGitWrapper
    useScript
    ;
}
