/**
  imp.gits - Declarative sparse checkout and multi-repo workspace composition.

  Configure sparse checkout for your main repo and/or inject files from
  multiple git repositories into a single workspace.

  # Core Concepts

  - **sparse**: Cone-mode sparse checkout paths for the main repo
  - **injection**: A repo whose files are "injected" into the workspace
  - **use**: Paths to take from an injection

  # How It Works

  Sparse checkout uses Git's cone mode for efficient directory-based filtering.
  Each injected repo has its .git directory stored in `.imp/gits/<name>.git`
  with `GIT_DIR` and `GIT_WORK_TREE` used to operate on it.

  # Example

  ```nix
  let
    gits = import ./. { inherit lib; };
    config = gits.build {
      sparse = [ "src" "lib" ];
      injections = [
        {
          name = "lintfra";
          remote = "git@github.com:org/lintfra.git";
          use = [ "lint/ast-rules" "nix/scripts" ];
        }
      ];
    };
  in
  {
    inherit (config.scripts) init pull push status;
  }
  ```
*/
{
  lib,
}:
let
  manifest = import ./manifest.nix { inherit lib; };
  gitignore = import ./gitignore.nix { inherit lib; };
  git = import ./git.nix { inherit lib; };
  scripts = import ./scripts.nix {
    inherit
      lib
      manifest
      gitignore
      git
      ;
  };
  build = import ./build.nix {
    inherit
      manifest
      gitignore
      scripts
      ;
  };
in
manifest // gitignore // git // scripts // build
