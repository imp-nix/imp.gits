/**
  Unit tests for imp.gitbits.

  Run with: nix flake check
*/
{ lib }:
let
  gitbits = import ../lib.nix { inherit lib; };
  args = {
    inherit lib gitbits;
  };
in
(import ./validate.nix args)
// (import ./paths.nix args)
// (import ./git.nix args)
// (import ./scripts.nix args)
// (import ./build.nix args)
