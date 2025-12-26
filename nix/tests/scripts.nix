/**
  Tests for script generation: initScript, pullScript, pushScript, statusScript.
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
    };
  };

in
{
  initScript."test generates valid bash script" = {
    expr =
      let
        script = gitbits.initScript { test = mixin; };
      in
      lib.hasPrefix "#!/usr/bin/env bash" script
      && lib.hasInfix "set -euo pipefail" script
      && lib.hasInfix "git remote add" script
      && lib.hasInfix "subtree add" script;
    expected = true;
  };

  pullScript."test includes fetch and pull" = {
    expr =
      let
        script = gitbits.pullScript { test = mixin; };
      in
      lib.hasInfix "git fetch" script && lib.hasInfix "subtree pull" script;
    expected = true;
  };

  pushScript."test includes warning and push" = {
    expr =
      let
        script = gitbits.pushScript { test = mixin; };
      in
      lib.hasInfix "WARNING" script && lib.hasInfix "subtree push" script;
    expected = true;
  };

  statusScript."test shows diff and remote info" = {
    expr =
      let
        script = gitbits.statusScript { test = mixin; };
      in
      lib.hasInfix "git diff" script && lib.hasInfix "Remote:" script;
    expected = true;
  };
}
