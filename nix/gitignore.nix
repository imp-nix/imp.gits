/**
  Gitignore pattern generation for multi-repo workspace.

  Each repo needs different ignore patterns:
  - Main repo: ignores all paths owned by injections
  - Injected repos: ignores everything EXCEPT their owned paths
*/
{
  lib,
}:
let
  inherit (builtins)
    concatStringsSep
    ;

  inherit (lib)
    flatten
    mapAttrsToList
    ;

  /**
    Generate exclude entries for the main repo's .git/info/exclude.

    We use .git/info/exclude instead of .gitignore because .gitignore
    files in the working tree affect ALL git operations, including
    injected repos. The exclude file only affects the repo it belongs to.

    # Arguments

    - `injections` (attrset): Map of injection name -> config

    # Returns

    String content for .git/info/exclude additions.
  */
  mainRepoExcludes =
    injections:
    let
      header = ''
        # imp.gitbits managed
        .gitbits/
      '';
      ownedPaths = flatten (mapAttrsToList (_: inj: inj.owns or [ ]) injections);
      pathLines = map (p: "/${p}") ownedPaths;
    in
    header + concatStringsSep "\n" pathLines + "\n";

  # Keep old name as alias for compatibility
  mainRepoIgnores = mainRepoExcludes;

  /**
    Generate exclude patterns for an injected repo.

    Injected repos use git's exclude mechanism (not .gitignore) to
    ignore everything except their owned paths. This avoids polluting
    the workspace with multiple .gitignore files.

    # Arguments

    - `injection` (attrset): Injection configuration

    # Returns

    String content for .git/info/exclude or sparse-checkout.
  */
  injectionExcludes =
    injection:
    let
      owns = injection.owns or [ ];
      header = "*\n";
      unignoreLines = flatten (
        map (p: [
          "!/${p}"
          "!/${p}/**"
        ]) owns
      );
    in
    header + concatStringsSep "\n" unignoreLines + "\n";

  /**
    Generate sparse-checkout patterns for an injected repo.

    Used during clone to only checkout owned paths.

    # Arguments

    - `injection` (attrset): Injection configuration

    # Returns

    String content for sparse-checkout file.
  */
  sparseCheckoutPatterns =
    injection:
    let
      owns = injection.owns or [ ];
      lines = flatten (
        map (p: [
          "/${p}"
          "/${p}/**"
        ]) owns
      );
    in
    concatStringsSep "\n" lines + "\n";

in
{
  inherit
    mainRepoExcludes
    mainRepoIgnores
    injectionExcludes
    sparseCheckoutPatterns
    ;
}
