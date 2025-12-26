/**
  Tests for git command generation: sparsePatterns, gitRemoteAdd,
  gitFetch, gitSubtreeAdd.
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
  sparsePatterns."test generates directory patterns" = {
    expr = builtins.sort builtins.lessThan (gitbits.sparsePatterns { mappings."src/lib" = "dest"; });
    expected = [
      "/src/lib"
      "/src/lib/**"
    ];
  };

  gitRemoteAdd."test generates command" = {
    expr = gitbits.gitRemoteAdd "origin" "git@github.com:test/repo.git";
    expected = "git remote add origin git@github.com:test/repo.git";
  };

  gitRemoteAdd."test escapes special characters" = {
    expr = gitbits.gitRemoteAdd "remote" "https://example.com/repo's.git";
    expected = "git remote add remote 'https://example.com/repo'\\''s.git'";
  };

  gitFetch."test uses branch" = {
    expr = gitbits.gitFetch "origin" { branch = "develop"; };
    expected = "git fetch origin develop";
  };

  gitSubtreeAdd."test includes squash by default" = {
    expr = lib.hasInfix "--squash" (gitbits.gitSubtreeAdd "origin" mixin "lib/dest");
    expected = true;
  };

  gitSubtreeAdd."test respects squash=false" = {
    expr = lib.hasInfix "--squash" (
      gitbits.gitSubtreeAdd "origin" (mixin // { squash = false; }) "lib"
    );
    expected = false;
  };
}
