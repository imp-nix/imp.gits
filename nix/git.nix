/**
  Git command generation for subtree and sparse-checkout operations.
*/
{
  lib,
  paths,
}:
let
  inherit (builtins)
    attrNames
    concatStringsSep
    ;

  inherit (lib)
    escapeShellArg
    flatten
    ;

  inherit (paths) normalizePath;

  /**
    Generate sparse-checkout patterns for a mixin.

    # Arguments

    - `mixin` (attrset): Mixin configuration

    # Returns

    List of sparse-checkout pattern strings.
  */
  sparsePatterns =
    mixin:
    let
      sources = attrNames (mixin.mappings or { });
      # For directories, we need to include the directory and all contents
      toPatterns =
        src:
        let
          normalized = normalizePath src;
        in
        [
          "/${normalized}"
          "/${normalized}/**"
        ];
    in
    flatten (map toPatterns sources);

  /**
    Generate sparse-checkout file content for a mixin.

    # Arguments

    - `mixin` (attrset): Mixin configuration

    # Returns

    String content for sparse-checkout file.
  */
  sparseCheckoutContent = mixin: concatStringsSep "\n" (sparsePatterns mixin) + "\n";

  /**
    Generate git remote add command.

    # Arguments

    - `name` (string): Remote name
    - `url` (string): Remote URL

    # Returns

    Shell command string.
  */
  gitRemoteAdd = name: url: "git remote add ${escapeShellArg name} ${escapeShellArg url}";

  /**
    Generate git fetch command for a mixin.

    # Arguments

    - `name` (string): Remote/mixin name
    - `mixin` (attrset): Mixin configuration

    # Returns

    Shell command string.
  */
  gitFetch =
    name: mixin:
    let
      branch = mixin.branch or "main";
    in
    "git fetch ${escapeShellArg name} ${escapeShellArg branch}";

  /**
    Generate git subtree add command.

    # Arguments

    - `name` (string): Remote name
    - `mixin` (attrset): Mixin configuration
    - `prefix` (string): Subtree prefix path

    # Returns

    Shell command string.
  */
  gitSubtreeAdd =
    name: mixin: prefix:
    let
      branch = mixin.branch or "main";
      squash = if mixin.squash or true then "--squash " else "";
    in
    "git subtree add --prefix=${escapeShellArg prefix} ${squash}${escapeShellArg name} ${escapeShellArg branch}";

  /**
    Generate git subtree pull command.

    # Arguments

    - `name` (string): Remote name
    - `mixin` (attrset): Mixin configuration
    - `prefix` (string): Subtree prefix path

    # Returns

    Shell command string.
  */
  gitSubtreePull =
    name: mixin: prefix:
    let
      branch = mixin.branch or "main";
      squash = if mixin.squash or true then "--squash " else "";
    in
    "git subtree pull --prefix=${escapeShellArg prefix} ${squash}${escapeShellArg name} ${escapeShellArg branch}";

  /**
    Generate git subtree push command.

    # Arguments

    - `name` (string): Remote name
    - `mixin` (attrset): Mixin configuration
    - `prefix` (string): Subtree prefix path

    # Returns

    Shell command string.
  */
  gitSubtreePush =
    name: mixin: prefix:
    let
      branch = mixin.branch or "main";
    in
    "git subtree push --prefix=${escapeShellArg prefix} ${escapeShellArg name} ${escapeShellArg branch}";

in
{
  inherit
    sparsePatterns
    sparseCheckoutContent
    gitRemoteAdd
    gitFetch
    gitSubtreeAdd
    gitSubtreePull
    gitSubtreePush
    ;
}
