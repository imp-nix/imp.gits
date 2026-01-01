/**
  Tests for git command generation.
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

  git."gitEnv sets GIT_DIR and GIT_WORK_TREE" = {
    expr =
      let
        env = gits.gitEnv "test";
      in
      lib.hasInfix "GIT_DIR=" env && lib.hasInfix "GIT_WORK_TREE=" env;
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

  git."fetchCmd uses gitEnv" = {
    expr = lib.hasInfix "GIT_DIR=" (gits.fetchCmd "test" injection);
    expected = true;
  };

  git."pullCmd includes branch" = {
    expr = lib.hasInfix "main" (gits.pullCmd "test" injection);
    expected = true;
  };

  git."pushCmd includes branch" = {
    expr = lib.hasInfix "main" (gits.pushCmd "test" injection);
    expected = true;
  };

  git."statusCmd uses gitEnv" = {
    expr = lib.hasPrefix "GIT_DIR=" (gits.statusCmd "test");
    expected = true;
  };
}
