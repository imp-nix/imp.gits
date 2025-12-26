/**
  Git command generation for multi-repo workspace.
*/
{
  lib,
}:
let
  inherit (lib) escapeShellArg;

  /**
    Directory where injection git dirs are stored.
  */
  gitbitsDir = ".gitbits";

  /**
    Get the git directory path for an injection.

    # Arguments

    - `name` (string): Injection name

    # Returns

    Path string like ".gitbits/foo.git"
  */
  injectionGitDir = name: "${gitbitsDir}/${name}.git";

  /**
    Generate environment prefix for injection git operations.

    # Arguments

    - `name` (string): Injection name

    # Returns

    Shell string like "GIT_DIR=.gitbits/foo.git GIT_WORK_TREE=."
  */
  gitEnv = name: "GIT_DIR=${escapeShellArg (injectionGitDir name)} GIT_WORK_TREE=.";

  /**
    Generate clone command for an injection.

    # Arguments

    - `name` (string): Injection name
    - `injection` (attrset): Injection configuration

    # Returns

    Shell command string.
  */
  cloneCmd =
    name: injection:
    let
      remote = injection.remote;
      branch = injection.branch or "main";
      gitDir = injectionGitDir name;
      tmpDir = "${gitbitsDir}/tmp/${name}";
    in
    ''
      git clone \
        --separate-git-dir=${escapeShellArg gitDir} \
        --branch=${escapeShellArg branch} \
        --single-branch \
        --no-checkout \
        ${escapeShellArg remote} \
        ${escapeShellArg tmpDir}
      rm -rf ${escapeShellArg tmpDir}
      ${gitEnv name} git config core.worktree "$(pwd)"
      ${gitEnv name} git config core.excludesFile /dev/null
    '';

  /**
    Generate sparse-checkout setup commands.

    # Arguments

    - `name` (string): Injection name
    - `sparseContent` (string): Sparse checkout file content

    # Returns

    Shell command string.
  */
  sparseCheckoutSetup =
    name: sparseContent:
    let
      gitDir = injectionGitDir name;
    in
    ''
      ${gitEnv name} git config core.sparseCheckout true
      mkdir -p ${escapeShellArg gitDir}/info
      cat > ${escapeShellArg gitDir}/info/sparse-checkout << 'SPARSE_EOF'
      ${sparseContent}
      SPARSE_EOF
      ${gitEnv name} git checkout
    '';

  /**
    Generate fetch command for an injection.

    # Arguments

    - `name` (string): Injection name
    - `injection` (attrset): Injection configuration

    # Returns

    Shell command string.
  */
  fetchCmd =
    name: injection: "${gitEnv name} git fetch origin ${escapeShellArg (injection.branch or "main")}";

  /**
    Generate pull command for an injection.

    # Arguments

    - `name` (string): Injection name
    - `injection` (attrset): Injection configuration

    # Returns

    Shell command string.
  */
  pullCmd =
    name: injection: "${gitEnv name} git pull origin ${escapeShellArg (injection.branch or "main")}";

  /**
    Generate push command for an injection.

    # Arguments

    - `name` (string): Injection name
    - `injection` (attrset): Injection configuration

    # Returns

    Shell command string.
  */
  pushCmd =
    name: injection: "${gitEnv name} git push origin ${escapeShellArg (injection.branch or "main")}";

  /**
    Generate status command for an injection.

    # Arguments

    - `name` (string): Injection name

    # Returns

    Shell command string.
  */
  statusCmd = name: "${gitEnv name} git status";

  /**
    Generate diff command for an injection.

    # Arguments

    - `name` (string): Injection name

    # Returns

    Shell command string.
  */
  diffCmd = name: "${gitEnv name} git diff";

  /**
    Generate add command for an injection.

    # Arguments

    - `name` (string): Injection name
    - `paths` (list): Paths to add

    # Returns

    Shell command string.
  */
  addCmd =
    name: paths: "${gitEnv name} git add ${builtins.concatStringsSep " " (map escapeShellArg paths)}";

  /**
    Generate commit command for an injection.

    # Arguments

    - `name` (string): Injection name
    - `message` (string): Commit message

    # Returns

    Shell command string.
  */
  commitCmd = name: message: "${gitEnv name} git commit -m ${escapeShellArg message}";

  /**
    Generate log command for an injection.

    # Arguments

    - `name` (string): Injection name
    - `args` (string): Additional git log arguments

    # Returns

    Shell command string.
  */
  logCmd = name: args: "${gitEnv name} git log ${args}";

in
{
  inherit
    gitbitsDir
    injectionGitDir
    gitEnv
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
