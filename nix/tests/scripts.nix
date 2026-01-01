/**
  Tests for script generation.
*/
{
  lib,
  gitbits,
}:
let
  injections = [
    {
      name = "test";
      remote = "git@github.com:test/repo.git";
      branch = "main";
      use = [
        "lint"
        "nix"
      ];
    }
  ];
in
{
  scripts."initScript generates valid bash" = {
    expr =
      let
        script = gitbits.initScript injections;
      in
      lib.hasPrefix "#!/usr/bin/env bash" script && lib.hasInfix "set -euo pipefail" script;
    expected = true;
  };

  scripts."initScript includes clone" = {
    expr =
      let
        script = gitbits.initScript injections;
      in
      lib.hasInfix "git clone" script;
    expected = true;
  };

  scripts."initScript creates .gitbits dir" = {
    expr =
      let
        script = gitbits.initScript injections;
      in
      lib.hasInfix "mkdir -p .gitbits" script;
    expected = true;
  };

  scripts."pullScript includes git pull" = {
    expr =
      let
        script = gitbits.pullScript injections;
      in
      lib.hasInfix "git pull" script;
    expected = true;
  };

  scripts."pushScript includes prompt" = {
    expr =
      let
        script = gitbits.pushScript injections;
      in
      lib.hasInfix "Press Enter to continue" script;
    expected = true;
  };

  scripts."pushScript includes git push" = {
    expr =
      let
        script = gitbits.pushScript injections;
      in
      lib.hasInfix "git push" script;
    expected = true;
  };

  scripts."statusScript shows remote info" = {
    expr =
      let
        script = gitbits.statusScript injections;
      in
      lib.hasInfix "remote:" script;
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
