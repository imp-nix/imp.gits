/**
  Tests for script generation: initScript, pullScript, pushScript, statusScript.
*/
{
  lib,
  gitbits,
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
  scripts."initScript generates valid bash" = {
    expr =
      let
        script = gitbits.initScript { test = injection; };
      in
      lib.hasPrefix "#!/usr/bin/env bash" script && lib.hasInfix "set -euo pipefail" script;
    expected = true;
  };

  scripts."initScript includes clone" = {
    expr =
      let
        script = gitbits.initScript { test = injection; };
      in
      lib.hasInfix "git clone" script;
    expected = true;
  };

  scripts."initScript creates .gitbits dir" = {
    expr =
      let
        script = gitbits.initScript { test = injection; };
      in
      lib.hasInfix "mkdir -p .gitbits" script;
    expected = true;
  };

  scripts."pullScript includes git pull" = {
    expr =
      let
        script = gitbits.pullScript { test = injection; };
      in
      lib.hasInfix "git pull" script;
    expected = true;
  };

  scripts."pushScript includes warning" = {
    expr =
      let
        script = gitbits.pushScript { test = injection; };
      in
      lib.hasInfix "WARNING" script;
    expected = true;
  };

  scripts."pushScript includes git push" = {
    expr =
      let
        script = gitbits.pushScript { test = injection; };
      in
      lib.hasInfix "git push" script;
    expected = true;
  };

  scripts."statusScript shows remote info" = {
    expr =
      let
        script = gitbits.statusScript { test = injection; };
      in
      lib.hasInfix "Remote:" script;
    expected = true;
  };

  scripts."injectionGitWrapper uses GIT_DIR" = {
    expr =
      let
        wrapper = gitbits.injectionGitWrapper "test";
      in
      lib.hasInfix "GIT_DIR=" wrapper;
    expected = true;
  };
}
