/**
  High-level build API for gits configuration.
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
    pullForceScript
    pushScript
    statusScript
    injectionGitWrapper
    useScript
    ;

  /**
    Build a complete gits workspace configuration.

    # Arguments

    - `config` (attrset): Configuration with `injections` list

    # Returns

    Attrset with scripts, metadata, and validation results.

    # Example

    ```nix
    gits.build {
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

      scripts = {
        init = initScript injections;
        pull = pullScript injections;
        pull-force = pullForceScript injections;
        push = pushScript injections;
        status = statusScript injections;
        use = useScript injections;
      };

      wrappers = listToAttrs (
        map (inj: {
          name = inj.name;
          value = injectionGitWrapper inj.name;
        }) injections
      );

      sparseCheckouts = listToAttrs (
        map (inj: {
          name = inj.name;
          value = sparseCheckoutPatterns inj;
        }) injections
      );

      usedPaths = allUsedPaths injections;
      injectionNames = map (inj: inj.name) injections;
      inherit injections;
    };

in
{
  inherit build;
}
