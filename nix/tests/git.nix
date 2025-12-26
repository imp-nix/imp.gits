/**
  Tests for git command generation.
*/
{
  lib,
  gitbits,
}:
let
  injection = {
    remote = "git@github.com:test/repo.git";
    branch = "main";
    owns = [ "lint" ];
  };
in
{
  git."injectionGitDir returns correct path" = {
    expr = gitbits.injectionGitDir "test";
    expected = ".gitbits/test.git";
  };

  git."gitEnv sets GIT_DIR and GIT_WORK_TREE" = {
    expr =
      let
        env = gitbits.gitEnv "test";
      in
      lib.hasInfix "GIT_DIR=" env && lib.hasInfix "GIT_WORK_TREE=" env;
    expected = true;
  };

  git."cloneCmd includes separate-git-dir" = {
    expr = lib.hasInfix "--separate-git-dir=" (gitbits.cloneCmd "test" injection);
    expected = true;
  };

  git."cloneCmd includes remote" = {
    expr = lib.hasInfix "git@github.com:test/repo.git" (gitbits.cloneCmd "test" injection);
    expected = true;
  };

  git."fetchCmd uses gitEnv" = {
    expr = lib.hasInfix "GIT_DIR=" (gitbits.fetchCmd "test" injection);
    expected = true;
  };

  git."pullCmd includes branch" = {
    expr = lib.hasInfix "main" (gitbits.pullCmd "test" injection);
    expected = true;
  };

  git."pushCmd includes branch" = {
    expr = lib.hasInfix "main" (gitbits.pushCmd "test" injection);
    expected = true;
  };

  git."statusCmd uses gitEnv" = {
    expr = lib.hasPrefix "GIT_DIR=" (gitbits.statusCmd "test");
    expected = true;
  };
}
