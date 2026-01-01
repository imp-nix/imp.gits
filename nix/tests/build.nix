/**
  Tests for high-level build API.
*/
{
  lib,
  gits,
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
  build."returns complete config with injections" = {
    expr =
      let
        result = gits.build { injections = [ injection ]; };
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
    expr = (gits.build { }).usedPaths;
    expected = [ ];
  };

  build."handles sparse-only config" = {
    expr =
      let
        result = gits.build {
          sparse = [
            "src"
            "lib"
          ];
        };
      in
      result.validation.valid
      &&
        result.sparse == [
          "src"
          "lib"
        ];
    expected = true;
  };

  build."handles combined sparse and injections" = {
    expr =
      let
        result = gits.build {
          sparse = [ "src" ];
          injections = [ injection ];
        };
      in
      result.validation.valid && result.sparse == [ "src" ] && builtins.length result.injections == 1;
    expected = true;
  };

  build."collects injection names" = {
    expr =
      (gits.build {
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
        result = gits.build { injections = [ injection ]; };
      in
      builtins.hasAttr "test" result.wrappers;
    expected = true;
  };

  build."init script includes sparse checkout when configured" = {
    expr =
      let
        result = gits.build {
          sparse = [
            "src"
            "docs"
          ];
        };
      in
      lib.hasInfix "sparse-checkout" result.scripts.init;
    expected = true;
  };

  build."init script uses cone mode for list sparse" = {
    expr =
      let
        result = gits.build { sparse = [ "src" ]; };
      in
      lib.hasInfix "--cone" result.scripts.init;
    expected = true;
  };

  build."init script uses no-cone mode when specified" = {
    expr =
      let
        result = gits.build {
          sparse = {
            mode = "no-cone";
            patterns = [ "/book/" ];
          };
        };
      in
      lib.hasInfix "--no-cone" result.scripts.init;
    expected = true;
  };
}
