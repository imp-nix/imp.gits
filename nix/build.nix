/**
  High-level build API for gitbits configuration.
*/
{
  manifest,
  gitignore,
  scripts,
}:
let
  inherit (builtins) listToAttrs map;

  inherit (manifest) validateManifest allUsedPaths;
  inherit (gitignore) sparseCheckoutPatterns;
  inherit (scripts)
    initScript
    pullScript
    pushScript
    statusScript
    injectionGitWrapper
    useScript
    ;

  /**
    Build a complete gitbits workspace configuration.

    # Arguments

    - `config` (attrset): Configuration with `injections` list

    # Returns

    Attrset with scripts, metadata, and validation results.

    # Example

    ```nix
    gitbits.build {
      injections = [
        {
          name = "lintfra";
          remote = "git@github.com:org/lintfra.git";
          use = [ "lint/ast-rules" "nix/scripts" ];
        }
      ];
    }
    ```
  */
  build =
    config:
    let
      injections = config.injections or [ ];
      validation = validateManifest injections;
    in
    {
      inherit validation;

      # Generated shell scripts
      scripts = {
        init = initScript injections;
        pull = pullScript injections;
        push = pushScript injections;
        status = statusScript injections;
        use = useScript injections;
      };

      # Per-injection git wrappers (gitbits-<name>)
      wrappers = listToAttrs (
        map (inj: {
          name = inj.name;
          value = injectionGitWrapper inj.name;
        }) injections
      );

      # Sparse checkout patterns per injection
      sparseCheckouts = listToAttrs (
        map (inj: {
          name = inj.name;
          value = sparseCheckoutPatterns inj;
        }) injections
      );

      # All paths used by injections
      usedPaths = allUsedPaths injections;

      # List of injection names
      injectionNames = map (inj: inj.name) injections;

      # Raw config for inspection
      inherit injections;
    };

in
{
  inherit build;
}
