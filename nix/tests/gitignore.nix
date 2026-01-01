/**
  Tests for gitignore pattern generation.
*/
{
  lib,
  gits,
}:
let
  injection = {
    name = "test";
    remote = "git@github.com:test/repo.git";
    use = [
      "lint"
      "nix"
    ];
  };
in
{
  gitignore."injectionExcludes starts with wildcard" = {
    expr = lib.hasPrefix "*" (gits.injectionExcludes injection);
    expected = true;
  };

  gitignore."injectionExcludes has negated patterns" = {
    expr =
      let
        content = gits.injectionExcludes injection;
      in
      lib.hasInfix "!/lint" content && lib.hasInfix "!/nix" content;
    expected = true;
  };

  gitignore."sparseCheckoutPatterns has use paths" = {
    expr =
      let
        content = gits.sparseCheckoutPatterns injection;
      in
      lib.hasInfix "/lint" content && lib.hasInfix "/nix" content;
    expected = true;
  };
}
