/**
  Tests for high-level build API and integration tests.
*/
{
  lib,
  gitbits,
}:
let
  mixin = {
    remote = "git@github.com:test/repo.git";
    branch = "main";
    mappings = {
      "src/lib" = "lib/external";
      "README.md" = "docs/readme.md";
    };
  };

in
{
  build."test returns complete config" = {
    expr =
      let
        result = gitbits.build { mixins.test = mixin; };
      in
      builtins.attrNames result.scripts == [
        "init"
        "pull"
        "push"
        "status"
      ]
      && result.validation.valid
      && builtins.hasAttr "test" result.sparseCheckouts
      && builtins.length result.allDestinations == 2
      && result.destinationMap."lib/external".mixin == "test";
    expected = true;
  };

  build."test handles empty config" = {
    expr = (gitbits.build { }).allDestinations;
    expected = [ ];
  };

  integration."test multiple mixins" = {
    expr =
      let
        result = gitbits.build {
          mixins = {
            fmt = {
              remote = "git@github.com:imp-nix/imp.fmt.git";
              mappings."src/formatters" = "lib/formatters";
            };
            docgen = {
              remote = "git@github.com:imp-nix/imp.docgen.git";
              mappings."nix/lib.nix" = "lib/docgen.nix";
            };
          };
        };
      in
      result.validation.valid && builtins.length result.allDestinations == 2;
    expected = true;
  };

  integration."test detects path conflicts" = {
    expr =
      let
        result = gitbits.build {
          mixins = {
            a = {
              remote = "git@github.com:test/a.git";
              mappings."src" = "lib/shared";
            };
            b = {
              remote = "git@github.com:test/b.git";
              mappings."src" = "lib/shared/nested";
            };
          };
        };
      in
      builtins.length result.conflicts > 0;
    expected = true;
  };
}
