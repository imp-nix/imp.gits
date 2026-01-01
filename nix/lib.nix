/**
  imp.gits - Multi-repo workspace composition.

  Mix files from multiple git repositories into a single workspace,
  with each repo maintaining its own history and remote sync capability.

  # Core Concepts

  - **workspace**: A directory containing files from multiple git repos
  - **injection**: A repo whose files are "injected" into the workspace
  - **use**: Paths to take from an injection

  # How It Works

  Each injected repo has its .git directory stored in `.gits/<name>.git`
  with `GIT_DIR` and `GIT_WORK_TREE` used to operate on it. Injections use
  sparse-checkout to only track their used paths.

  Injections are processed in list order - later ones override earlier ones.

  # Example

  ```nix
  let
    gits = import ./. { inherit lib; };
    config = gits.build {
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
