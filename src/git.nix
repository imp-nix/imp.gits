/**
  Git command generation for sparse checkout and multi-repo workspace.
  Generates Nushell commands with proper error handling.
*/
{
  lib,
}:
let
  inherit (lib) escapeShellArg concatStringsSep;

  # Escape a string for use in Nushell (double-quoted string)
  escapeNuStr = s: ''"${builtins.replaceStrings [ ''"'' "\\" ] [ ''\"'' "\\\\" ] s}"'';

  # Format a list as a Nushell list literal
  nuList = items: "[${concatStringsSep ", " (map escapeNuStr items)}]";

  /**
    Directory where injection git dirs are stored.
  */
  gitsDir = ".imp/gits";

  /**
    Generate sparse checkout init commands (Nushell).

    # Arguments

    - `sparseConfig` (attrset or list): Sparse checkout configuration
      - If list: cone mode with directory paths
      - If attrset: { mode = "cone"|"no-cone"; paths|patterns = [...]; }
    - `target` (string or null): Target directory (for external configs), or null for current repo

    # Returns

    Nushell command string.
  */
  sparseCheckoutInit =
    sparseConfig: target:
    let
      # Normalize config to attrset form
      normalized =
        if builtins.isList sparseConfig then
          {
            mode = "cone";
            paths = sparseConfig;
          }
        else
          sparseConfig;

      mode = normalized.mode or "cone";
      isCone = mode == "cone";
      hasTarget = target != null;

      # For cone mode, use paths; for no-cone, use patterns
      # Only include .imp/ if not targeting external repo (external repos don't have our config)
      userItems = if isCone then normalized.paths or [ ] else normalized.patterns or [ ];
      items =
        if hasTarget then
          userItems
        else if isCone then
          userItems ++ [ ".imp" ]
        else
          userItems ++ [ "/.imp/" ];

      gitArgs = if hasTarget then "-C ${escapeNuStr target}" else "";
      modeFlag = if isCone then "--cone" else "--no-cone";
      setFlags = if isCone then "" else "--no-cone";
    in
    ''
      run-git ${gitArgs} sparse-checkout init ${modeFlag}
      run-git ${gitArgs} sparse-checkout set ${setFlags} ...${nuList items}
    '';

  /**
    Generate sparse checkout status command (Nushell).

    # Arguments

    - `target` (string or null): Target directory, or null for current repo

    # Returns

    Nushell command string.
  */
  sparseCheckoutStatus =
    target:
    let
      gitArgs = if target != null then "-C ${escapeNuStr target}" else "";
      label = if target != null then " (${target})" else "";
    in
    ''
      let result = (git ${gitArgs} sparse-checkout list | complete)
      if $result.exit_code == 0 {
          print $"sparse-checkout${label}:"
          $result.stdout | lines | each {|line| print $"  ($line)" }
      }
    '';

  /**
    Get the git directory path for an injection.

    # Arguments

    - `name` (string): Injection name

    # Returns

    Path string like ".imp/gits/foo.git"
  */
  injectionGitDir = name: "${gitsDir}/${name}.git";

  /**
    Generate with-env block for injection git operations (Nushell).

    # Arguments

    - `name` (string): Injection name

    # Returns

    Nushell with-env record string.
  */
  gitEnvRecord = name: ''{GIT_DIR: ${escapeNuStr (injectionGitDir name)}, GIT_WORK_TREE: "."}'';

  /**
    Generate clone command for an injection (Nushell).
    Uses `complete` for proper error capture.

    # Arguments

    - `name` (string): Injection name
    - `injection` (attrset): Injection configuration

    # Returns

    Nushell command string.
  */
  cloneCmd =
    name: injection:
    let
      remote = injection.remote;
      branch = injection.branch or "main";
      gitDir = injectionGitDir name;
      tmpDir = "${gitsDir}/tmp/${name}";
    in
    ''
      let clone_result = (
          git clone
              --separate-git-dir=${escapeNuStr gitDir}
              --branch=${escapeNuStr branch}
              --single-branch
              --no-checkout
              ${escapeNuStr remote}
              ${escapeNuStr tmpDir}
          | complete
      )
      if $clone_result.exit_code != 0 {
          print -e $"  ERROR: Failed to clone injection '${name}'"
          print -e $"    remote: ${remote}"
          print -e $"    branch: ${branch}"
          if ($clone_result.stderr | is-not-empty) {
              print -e $"    git: ($clone_result.stderr | str trim)"
          }
          exit 1
      }
      rm -rf ${escapeNuStr tmpDir}
      with-env ${gitEnvRecord name} {
          run-git config core.worktree (pwd | str trim)
          run-git config core.excludesFile /dev/null
          run-git config advice.addIgnoredFile "false"
          run-git config advice.updateSparsePath "false"
      }
    '';

  /**
    Generate sparse-checkout setup commands (Nushell).

    # Arguments

    - `name` (string): Injection name
    - `sparseContent` (string): Sparse checkout file content
    - `excludeContent` (string): Exclude file content for ignoring non-used paths
    - `usePaths` (list): Paths the injection uses

    # Returns

    Nushell command string.
  */
  sparseCheckoutSetup =
    name: sparseContent: excludeContent: usePaths:
    let
      gitDir = injectionGitDir name;
    in
    ''
      with-env ${gitEnvRecord name} {
          run-git config core.sparseCheckout "true"
      }
      mkdir ${escapeNuStr "${gitDir}/info"}
      ${escapeNuStr sparseContent} | save -f ${escapeNuStr "${gitDir}/info/sparse-checkout"}
      ${escapeNuStr excludeContent} | save -f ${escapeNuStr "${gitDir}/info/exclude"}

      # Checkout only the specific use paths
      with-env ${gitEnvRecord name} {
          run-git checkout HEAD "--" ...${nuList usePaths}
      }

      # Mark files outside of use paths as assume-unchanged
      let use_paths = ${nuList usePaths}
      with-env ${gitEnvRecord name} {
          git ls-files | lines | where {|file|
              not ($use_paths | any {|p| $file == $p or ($file | str starts-with $"($p)/")})
          } | each {|file|
              git update-index --assume-unchanged $file | complete
          }
      }
    '';

  /**
    Generate fetch command for an injection (Nushell).

    # Arguments

    - `name` (string): Injection name
    - `injection` (attrset): Injection configuration

    # Returns

    Nushell command string.
  */
  fetchCmd =
    name: injection:
    let
      branch = injection.branch or "main";
    in
    ''
      with-env ${gitEnvRecord name} {
          run-git fetch origin ${escapeNuStr branch}
      }
    '';

  /**
    Generate pull command for an injection (Nushell).

    # Arguments

    - `name` (string): Injection name
    - `injection` (attrset): Injection configuration

    # Returns

    Nushell command string.
  */
  pullCmd =
    name: injection:
    let
      branch = injection.branch or "main";
    in
    ''
      with-env ${gitEnvRecord name} {
          let result = (git pull origin ${escapeNuStr branch} | complete)
          if $result.exit_code != 0 {
              print -e $"  Warning: pull failed for ${name}"
              if ($result.stderr | is-not-empty) {
                  print -e $"    ($result.stderr | str trim)"
              }
              return false
          }
          true
      }
    '';

  /**
    Generate push command for an injection (Nushell).

    # Arguments

    - `name` (string): Injection name
    - `injection` (attrset): Injection configuration

    # Returns

    Nushell command string.
  */
  pushCmd =
    name: injection:
    let
      branch = injection.branch or "main";
    in
    ''
      with-env ${gitEnvRecord name} {
          let result = (git push origin ${escapeNuStr branch} | complete)
          if $result.exit_code != 0 {
              print -e $"  Warning: push failed for ${name}"
              if ($result.stderr | is-not-empty) {
                  print -e $"    ($result.stderr | str trim)"
              }
          }
      }
    '';

  /**
    Generate status command for an injection (Nushell).

    # Arguments

    - `name` (string): Injection name

    # Returns

    Nushell command string.
  */
  statusCmd = name: ''
    with-env ${gitEnvRecord name} {
        git status
    }
  '';

  /**
    Generate diff command for an injection (Nushell).

    # Arguments

    - `name` (string): Injection name

    # Returns

    Nushell command string.
  */
  diffCmd = name: ''
    with-env ${gitEnvRecord name} {
        git diff
    }
  '';

  /**
    Generate add command for an injection (Nushell).

    # Arguments

    - `name` (string): Injection name
    - `paths` (list): Paths to add

    # Returns

    Nushell command string.
  */
  addCmd = name: paths: ''
    with-env ${gitEnvRecord name} {
        run-git add ...${nuList paths}
    }
  '';

  /**
    Generate commit command for an injection (Nushell).

    # Arguments

    - `name` (string): Injection name
    - `message` (string): Commit message

    # Returns

    Nushell command string.
  */
  commitCmd = name: message: ''
    with-env ${gitEnvRecord name} {
        run-git commit -m ${escapeNuStr message}
    }
  '';

  /**
    Generate log command for an injection (Nushell).

    # Arguments

    - `name` (string): Injection name
    - `args` (string): Additional git log arguments

    # Returns

    Nushell command string.
  */
  logCmd = name: args: ''
    with-env ${gitEnvRecord name} {
        git log ${args}
    }
  '';

in
{
  inherit
    gitsDir
    escapeNuStr
    nuList
    sparseCheckoutInit
    sparseCheckoutStatus
    injectionGitDir
    gitEnvRecord
    cloneCmd
    sparseCheckoutSetup
    fetchCmd
    pullCmd
    pushCmd
    statusCmd
    diffCmd
    addCmd
    commitCmd
    logCmd
    ;
}
