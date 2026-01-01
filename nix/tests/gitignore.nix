/**
  Tests for gitignore pattern generation.
*/
{
  lib,
  gitbits,
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
    expr = lib.hasPrefix "*" (gitbits.injectionExcludes injection);
    expected = true;
  };

  gitignore."injectionExcludes has negated patterns" = {
    expr =
      let
        content = gitbits.injectionExcludes injection;
      in
      lib.hasInfix "!/lint" content && lib.hasInfix "!/nix" content;
    expected = true;
  };

  gitignore."sparseCheckoutPatterns has use paths" = {
    expr =
      let
        content = gitbits.sparseCheckoutPatterns injection;
      in
      lib.hasInfix "/lint" content && lib.hasInfix "/nix" content;
    expected = true;
  };
}
