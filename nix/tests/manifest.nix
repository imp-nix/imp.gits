/**
  Tests for manifest validation.
*/
{
  gits,
  ...
}:
let
  validInjection = {
    name = "test";
    remote = "git@github.com:test/repo.git";
    branch = "main";
    use = [
      "lib"
      "src/utils"
    ];
  };
in
{
  manifest."validates correct injection" = {
    expr = (gits.validateInjection 0 validInjection).valid;
    expected = true;
  };

  manifest."rejects missing name" = {
    expr =
      (gits.validateInjection 0 {
        remote = "git@github.com:test/repo.git";
        use = [ "lib" ];
      }).valid;
    expected = false;
  };

  manifest."rejects missing remote" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        use = [ "lib" ];
      }).valid;
    expected = false;
  };

  manifest."rejects missing use" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
      }).valid;
    expected = false;
  };

  manifest."rejects empty use" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
        use = [ ];
      }).valid;
    expected = false;
  };

  manifest."validateManifest accepts valid list" = {
    expr =
      (gits.validateManifest [
        validInjection
      ]).valid;
    expected = true;
  };

  manifest."validateManifest rejects non-list" = {
    expr =
      (gits.validateManifest {
        test = validInjection;
      }).valid;
    expected = false;
  };

  manifest."allUsedPaths collects all" = {
    expr = builtins.sort (a: b: a < b) (
      gits.allUsedPaths [
        {
          name = "a";
          remote = "x";
          use = [
            "lib"
            "docs"
          ];
        }
        {
          name = "b";
          remote = "y";
          use = [ "src" ];
        }
      ]
    );
    expected = [
      "docs"
      "lib"
      "src"
    ];
  };
}
