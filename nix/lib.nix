/**
  imp.gitbits - Multi-repo workspace composition.

  Mix files from multiple git repositories into a single workspace,
  with each repo maintaining its own history and remote sync capability.

  # Core Concepts

  - **workspace**: A directory containing files from multiple git repos
  - **injection**: A repo whose files are "injected" into the workspace
  - **owns**: Paths that an injection is responsible for tracking

  # How It Works

  Each injected repo has its .git directory stored in `.gitbits/<name>.git`
  with `GIT_DIR` and `GIT_WORK_TREE` used to operate on it. The main repo's
  .gitignore excludes paths owned by injections, and each injection uses
  sparse-checkout to only track its owned paths.

  # Example

  ```nix
  let
    gitbits = import ./. { inherit lib; };
    config = gitbits.build {
      injections = {
        "galagit-lint" = {
          remote = "git@github.com:Alb-O/galagit-lint.git";
          branch = "main";
          owns = [ "lint" "nix" "sgconfig.yml" ];
        };
      };
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
