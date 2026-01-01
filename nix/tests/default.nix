/**
  Unit tests for imp.gits.

  Run with: nix flake check
*/
{ lib }:
let
  gits = import ../lib.nix { inherit lib; };
  args = {
    inherit lib gits;
  };
in
(import ./manifest.nix args)
// (import ./gitignore.nix args)
// (import ./git.nix args)
// (import ./scripts.nix args)
// (import ./build.nix args)
