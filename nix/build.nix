/**
  High-level build API for gitbits configuration.
*/
{
  manifest,
  gitignore,
  scripts,
}:
let
  inherit (builtins) attrNames mapAttrs;

  inherit (manifest) validateManifest allOwnedPaths;
  inherit (gitignore) mainRepoExcludes sparseCheckoutPatterns;
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

    - `config` (attrset): Configuration with `injections` attribute

    # Returns

    Attrset with scripts, metadata, and validation results.

    # Example

    ```nix
    gitbits.build {
      injections = {
        galagit-lint = {
          remote = "git@github.com:Alb-O/galagit-lint.git";
          branch = "main";
          owns = [ "lint" "nix" "sgconfig.yml" ];
        };
      };
    }
    ```
  */
  build =
    config:
    let
      injections = config.injections or { };
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
      wrappers = mapAttrs (name: _: injectionGitWrapper name) injections;

      # Exclude content for main repo's .git/info/exclude
      mainExcludes = mainRepoExcludes injections;

      # Sparse checkout patterns per injection
      sparseCheckouts = mapAttrs (_: sparseCheckoutPatterns) injections;

      # All paths owned by injections (main repo should ignore these)
      ownedPaths = allOwnedPaths injections;

      # List of injection names
      injectionNames = attrNames injections;

      # Raw config for inspection
      inherit injections;
    };

in
{
  inherit build;
}
