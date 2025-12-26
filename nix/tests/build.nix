/**
  Tests for high-level build API.
*/
{
  gitbits,
  ...
}:
let
  injection = {
    remote = "git@github.com:test/repo.git";
    branch = "main";
    owns = [
      "lint"
      "nix"
    ];
  };
in
{
  build."returns complete config" = {
    expr =
      let
        result = gitbits.build { injections.test = injection; };
      in
      builtins.attrNames result.scripts == [
        "init"
        "pull"
        "push"
        "status"
      ]
      && result.validation.valid
      && builtins.hasAttr "test" result.sparseCheckouts
      && builtins.length result.ownedPaths == 2;
    expected = true;
  };

  build."handles empty config" = {
    expr = (gitbits.build { }).ownedPaths;
    expected = [ ];
  };

  build."collects injection names" = {
    expr =
      (gitbits.build {
        injections = {
          a = {
            remote = "x";
            owns = [ "a" ];
          };
          b = {
            remote = "y";
            owns = [ "b" ];
          };
        };
      }).injectionNames;
    expected = [
      "a"
      "b"
    ];
  };

  build."generates wrappers for each injection" = {
    expr =
      let
        result = gitbits.build { injections.test = injection; };
      in
      builtins.hasAttr "test" result.wrappers;
    expected = true;
  };

  build."detects conflicts" = {
    expr =
      let
        result = gitbits.build {
          injections = {
            a = {
              remote = "x";
              owns = [ "lib" ];
            };
            b = {
              remote = "y";
              owns = [ "lib/sub" ];
            };
          };
        };
      in
      result.validation.valid;
    expected = false;
  };
}
