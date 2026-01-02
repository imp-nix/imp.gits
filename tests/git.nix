/**
  Tests for git command generation (Nushell).
*/
{
  lib,
  gits,
}:
let
  injection = {
    name = "test";
    remote = "git@github.com:test/repo.git";
    branch = "main";
    use = [ "lint" ];
  };
in
{
  git."injectionGitDir returns correct path" = {
    expr = gits.injectionGitDir "test";
    expected = ".imp/gits/test.git";
  };

  git."gitEnvRecord returns Nushell record" = {
    expr =
      let
        env = gits.gitEnvRecord "test";
      in
      lib.hasInfix "GIT_DIR:" env && lib.hasInfix "GIT_WORK_TREE:" env;
    expected = true;
  };

  git."cloneCmd includes separate-git-dir" = {
    expr = lib.hasInfix "--separate-git-dir=" (gits.cloneCmd "test" injection);
    expected = true;
  };

  git."cloneCmd includes remote" = {
    expr = lib.hasInfix "git@github.com:test/repo.git" (gits.cloneCmd "test" injection);
    expected = true;
  };

  git."cloneCmd uses complete for error handling" = {
    expr = lib.hasInfix "| complete" (gits.cloneCmd "test" injection);
    expected = true;
  };

  git."cloneCmd reports errors with context" = {
    expr =
      let
        cmd = gits.cloneCmd "test" injection;
      in
      lib.hasInfix "ERROR: Failed to clone injection" cmd && lib.hasInfix "remote:" cmd;
    expected = true;
  };

  git."fetchCmd uses with-env" = {
    expr = lib.hasInfix "with-env" (gits.fetchCmd "test" injection);
    expected = true;
  };

  git."pullCmd includes branch" = {
    expr = lib.hasInfix "main" (gits.pullCmd "test" injection);
    expected = true;
  };

  git."pullCmd uses complete for error handling" = {
    expr = lib.hasInfix "| complete" (gits.pullCmd "test" injection);
    expected = true;
  };

  git."pushCmd includes branch" = {
    expr = lib.hasInfix "main" (gits.pushCmd "test" injection);
    expected = true;
  };

  git."pushCmd uses complete for error handling" = {
    expr = lib.hasInfix "| complete" (gits.pushCmd "test" injection);
    expected = true;
  };

  git."statusCmd uses with-env" = {
    expr = lib.hasInfix "with-env" (gits.statusCmd "test");
    expected = true;
  };

  git."escapeNuStr escapes quotes" = {
    expr = gits.escapeNuStr ''hello "world"'';
    expected = ''"hello \"world\""'';
  };

  git."nuList formats list correctly" = {
    expr = gits.nuList [
      "a"
      "b"
    ];
    expected = ''["a", "b"]'';
  };
}
