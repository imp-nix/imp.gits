/**
  Tests for script generation (Nushell).
*/
{
  lib,
  gits,
}:
let
  config = {
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
  };

  sparseConfig = {
    sparse = [
      "src"
      "lib"
    ];
  };

  combinedConfig = {
    sparse = [ "src" ];
    injections = config.injections;
  };
in
{
  scripts."initScript includes run-git helper" = {
    expr =
      let
        script = gits.initScript config;
      in
      lib.hasInfix "def run-git" script;
    expected = true;
  };

  scripts."initScript includes clone for injections" = {
    expr =
      let
        script = gits.initScript config;
      in
      lib.hasInfix "git clone" script;
    expected = true;
  };

  scripts."initScript creates .imp/gits dir for injections" = {
    expr =
      let
        script = gits.initScript config;
      in
      lib.hasInfix "mkdir .imp/gits" script;
    expected = true;
  };

  scripts."initScript includes sparse-checkout for sparse config" = {
    expr =
      let
        script = gits.initScript sparseConfig;
      in
      lib.hasInfix "sparse-checkout" script;
    expected = true;
  };

  scripts."initScript handles combined config" = {
    expr =
      let
        script = gits.initScript combinedConfig;
      in
      lib.hasInfix "sparse-checkout" script && lib.hasInfix "git clone" script;
    expected = true;
  };

  scripts."initScript uses complete for error handling" = {
    expr =
      let
        script = gits.initScript config;
      in
      lib.hasInfix "| complete" script;
    expected = true;
  };

  scripts."initScript reports clone errors" = {
    expr =
      let
        script = gits.initScript config;
      in
      lib.hasInfix "ERROR: Failed to clone injection" script;
    expected = true;
  };

  scripts."pullScript includes git pull" = {
    expr =
      let
        script = gits.pullScript config;
      in
      lib.hasInfix "git pull" script;
    expected = true;
  };

  scripts."pushScript includes prompt" = {
    expr =
      let
        script = gits.pushScript config;
      in
      lib.hasInfix "Press Enter to continue" script;
    expected = true;
  };

  scripts."pushScript includes git push" = {
    expr =
      let
        script = gits.pushScript config;
      in
      lib.hasInfix "git push" script;
    expected = true;
  };

  scripts."statusScript shows remote info" = {
    expr =
      let
        script = gits.statusScript config;
      in
      lib.hasInfix "remote:" script;
    expected = true;
  };

  scripts."statusScript shows sparse-checkout for sparse config" = {
    expr =
      let
        script = gits.statusScript sparseConfig;
      in
      lib.hasInfix "sparse-checkout" script;
    expected = true;
  };

  scripts."injectionGitWrapper uses with-env for GIT_DIR" = {
    expr =
      let
        wrapper = gits.injectionGitWrapper "test";
      in
      lib.hasInfix "with-env" wrapper && lib.hasInfix "GIT_DIR" wrapper;
    expected = true;
  };

  scripts."useScript outputs JSON for nushell" = {
    expr =
      let
        script = gits.useScript config;
      in
      lib.hasInfix ''print $'{"GIT_DIR":'' script;
    expected = true;
  };
}
