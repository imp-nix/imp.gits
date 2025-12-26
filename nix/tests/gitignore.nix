/**
  Tests for gitignore pattern generation.
*/
{
  lib,
  gitbits,
}:
let
  injection = {
    remote = "git@github.com:test/repo.git";
    owns = [
      "lint"
      "nix"
    ];
  };
in
{
  gitignore."mainRepoIgnores includes .gitbits" = {
    expr = lib.hasInfix ".gitbits/" (gitbits.mainRepoIgnores { test = injection; });
    expected = true;
  };

  gitignore."mainRepoIgnores includes owned paths" = {
    expr =
      let
        content = gitbits.mainRepoIgnores { test = injection; };
      in
      lib.hasInfix "/lint" content && lib.hasInfix "/nix" content;
    expected = true;
  };

  gitignore."injectionExcludes starts with wildcard" = {
    expr = lib.hasPrefix "# imp.gitbits" (gitbits.injectionExcludes injection);
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

  gitignore."sparseCheckoutPatterns has owned paths" = {
    expr =
      let
        content = gitbits.sparseCheckoutPatterns injection;
      in
      lib.hasInfix "/lint" content && lib.hasInfix "/nix" content;
    expected = true;
  };
}
