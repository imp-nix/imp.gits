/**
  Entry point for imp.gits.

  Multi-repo workspace composition - mix files from multiple
  git repositories with each maintaining its own history.

  # Example

  ```nix
  let
    gits = import ./. { inherit lib; };
    config = gits.build {
      injections = {
        "galagit-lint" = {
          remote = "git@github.com:Alb-O/galagit-lint.git";
          owns = [ "lint" "nix" "sgconfig.yml" ];
        };
      };
    };
  in
  config.scripts.init
  ```
*/
{ lib }: import ../nix/lib.nix { inherit lib; }
