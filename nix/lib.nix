/**
  imp.gitbits - Declarative repository composition.

  Mix files from multiple git repositories into a single project
  with fine-grained path control, while maintaining sync capability
  with source remotes.

  # Core Concepts

  - **mixin**: A declaration of files to inject from a remote repo
  - **mapping**: Source path -> destination path transformation
  - **sparse set**: Files to checkout from a remote

  # Example

  ```nix
  {
    mixins = {
      "imp-fmt" = {
        remote = "git@github.com:imp-nix/imp.fmt.git";
        branch = "main";
        mappings = {
          "src/formatters" = "lib/formatters";  # directory
          "README.md" = "docs/imp-fmt.md";      # single file
        };
      };
    };
  }
  ```
*/
{
  lib,
}:
let
  validate = import ./validate.nix { inherit lib; };
  paths = import ./paths.nix { inherit lib; };
  git = import ./git.nix { inherit lib paths; };
  scripts = import ./scripts.nix {
    inherit
      lib
      paths
      git
      validate
      ;
  };
  build = import ./build.nix {
    inherit
      lib
      paths
      git
      scripts
      validate
      ;
  };
in
validate // paths // git // scripts // build
