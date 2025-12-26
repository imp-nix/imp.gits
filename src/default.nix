/**
  Entry point for imp.gitbits.

  Declarative repository composition - mix files from multiple
  git repositories with fine-grained path control.

  # Example

  ```nix
  let
    gitbits = import ./. { inherit lib; };
    config = gitbits.build {
      mixins = {
        "my-lib" = {
          remote = "git@github.com:org/lib.git";
          mappings = { "src" = "lib/external"; };
        };
      };
    };
  in
  config.scripts.init
  ```
*/
{ lib }: import ../nix/lib.nix { inherit lib; }
