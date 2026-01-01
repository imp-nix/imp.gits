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
  manifest."validateSparse accepts valid list" = {
    expr =
      (gits.validateSparse [
        "src"
        "lib"
      ]).valid;
    expected = true;
  };

  manifest."validateSparse rejects non-list" = {
    expr = (gits.validateSparse "src").valid;
    expected = false;
  };

  manifest."validateSparse rejects non-string entries" = {
    expr =
      (gits.validateSparse [
        "src"
        123
      ]).valid;
    expected = false;
  };

  manifest."validateConfig accepts sparse-only config" = {
    expr = (gits.validateConfig { sparse = [ "src" ]; }).valid;
    expected = true;
  };

  manifest."validateConfig accepts injections-only config" = {
    expr = (gits.validateConfig { injections = [ validInjection ]; }).valid;
    expected = true;
  };

  manifest."validateConfig accepts combined config" = {
    expr =
      (gits.validateConfig {
        sparse = [ "src" ];
        injections = [ validInjection ];
      }).valid;
    expected = true;
  };

  manifest."validateConfig accepts empty config" = {
    expr = (gits.validateConfig { }).valid;
    expected = true;
  };

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
