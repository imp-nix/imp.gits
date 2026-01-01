/**
  Tests for high-level build API.
*/
{
  gitbits,
  ...
}:
let
  injection = {
    name = "test";
    remote = "git@github.com:test/repo.git";
    branch = "main";
    use = [
      "lint"
      "nix"
    ];
  };
in
{
  build."returns complete config" = {
    expr =
      let
        result = gitbits.build { injections = [ injection ]; };
      in
      builtins.attrNames result.scripts == [
        "init"
        "pull"
        "pull-force"
        "push"
        "status"
        "use"
      ]
      && result.validation.valid
      && builtins.hasAttr "test" result.sparseCheckouts
      && builtins.length result.usedPaths == 2;
    expected = true;
  };

  build."handles empty config" = {
    expr = (gitbits.build { }).usedPaths;
    expected = [ ];
  };

  build."collects injection names" = {
    expr =
      (gitbits.build {
        injections = [
          {
            name = "a";
            remote = "x";
            use = [ "a" ];
          }
          {
            name = "b";
            remote = "y";
            use = [ "b" ];
          }
        ];
      }).injectionNames;
    expected = [
      "a"
      "b"
    ];
  };

  build."generates wrappers for each injection" = {
    expr =
      let
        result = gitbits.build { injections = [ injection ]; };
      in
      builtins.hasAttr "test" result.wrappers;
    expected = true;
  };
}
