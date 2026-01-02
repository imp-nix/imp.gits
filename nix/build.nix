/**
  High-level build API for imp.gits configuration.
*/
{
  manifest,
  gitignore,
  scripts,
}:
let
  inherit (builtins) listToAttrs map hasAttr;

  inherit (manifest) validateConfig allUsedPaths allBoilerplatePaths;
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
    Build a complete imp.gits configuration.

    # Arguments

    - `config` (attrset): Configuration with optional `sparse`, `injections`, and `vars`

    # Returns

    Attrset with scripts, metadata, and validation results.

    # Example

    ```nix
    gits.build {
      # Sparse checkout for the main repo
      sparse = [ "src" "lib" ];

      # Optional injections
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
      sparse = config.sparse or [ ];
      injections = config.injections or [ ];
      validation = validateConfig config;
    in
    {
      inherit validation;

      scripts = {
        init = initScript config;
        pull = pullScript config;
        pull-force = pullForceScript config;
        push = pushScript config;
        status = statusScript config;
        use = useScript config;
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

      # Main repo sparse checkout paths
      inherit sparse;

      # Injection metadata
      usedPaths = allUsedPaths injections;
      boilerplatePaths = allBoilerplatePaths injections;
      injectionNames = map (inj: inj.name) injections;
      inherit injections;
    };

in
{
  inherit build;
}
