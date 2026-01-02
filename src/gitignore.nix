/**
  Gitignore and sparse-checkout pattern generation for multi-repo workspace.
*/
{
  lib,
}:
let
  inherit (builtins) concatStringsSep;

  inherit (lib) flatten;

  /**
    Generate exclude patterns for an injected repo.

    Ignores everything except paths the injection uses.

    # Arguments

    - `injection` (attrset): Injection configuration

    # Returns

    String content for .git/info/exclude.
  */
  injectionExcludes =
    injection:
    let
      uses = injection.use or [ ];
      header = "*\n";
      unignoreLines = flatten (
        map (p: [
          "!/${p}"
          "!/${p}/**"
        ]) uses
      );
    in
    header + concatStringsSep "\n" unignoreLines + "\n";

  /**
    Generate sparse-checkout patterns for an injected repo.

    Used during clone to only checkout paths the injection uses.

    # Arguments

    - `injection` (attrset): Injection configuration

    # Returns

    String content for sparse-checkout file.
  */
  sparseCheckoutPatterns =
    injection:
    let
      uses = injection.use or [ ];
      lines = flatten (
        map (p: [
          "/${p}"
          "/${p}/**"
        ]) uses
      );
    in
    concatStringsSep "\n" lines + "\n";

in
{
  inherit
    injectionExcludes
    sparseCheckoutPatterns
    ;
}
