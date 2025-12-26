/**
  Entry point for imp.gitbits.

  Multi-repo workspace composition - mix files from multiple
  git repositories with each maintaining its own history.

  # Example

  ```nix
  let
    gitbits = import ./. { inherit lib; };
    config = gitbits.build {
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
