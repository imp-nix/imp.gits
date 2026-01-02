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

  manifest."validateSparse accepts no-cone attrset" = {
    expr =
      (gits.validateSparse {
        mode = "no-cone";
        patterns = [
          "/book/"
          "/docs/"
        ];
      }).valid;
    expected = true;
  };

  manifest."validateSparse accepts cone attrset" = {
    expr =
      (gits.validateSparse {
        mode = "cone";
        paths = [
          "src"
          "lib"
        ];
      }).valid;
    expected = true;
  };

  manifest."validateSparse rejects invalid mode" = {
    expr =
      (gits.validateSparse {
        mode = "invalid";
        paths = [ "src" ];
      }).valid;
    expected = false;
  };

  manifest."validateSparse rejects no-cone without patterns" = {
    expr =
      (gits.validateSparse {
        mode = "no-cone";
        paths = [ "src" ];
      }).valid;
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

  manifest."accepts injection with only boilerplate" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
        boilerplate = [ "Cargo.toml" ];
      }).valid;
    expected = true;
  };

  manifest."accepts injection with use and boilerplate" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
        use = [ "lib" ];
        boilerplate = [ "Cargo.toml" ];
      }).valid;
    expected = true;
  };

  manifest."rejects injection without use or boilerplate" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
      }).valid;
    expected = false;
  };

  manifest."accepts boilerplate string entry" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
        boilerplate = [
          "Cargo.toml"
          "README.md"
        ];
      }).valid;
    expected = true;
  };

  manifest."accepts boilerplate attrset entry" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
        boilerplate = [
          {
            src = "template.toml.tmpl";
            dest = "config.toml";
          }
        ];
      }).valid;
    expected = true;
  };

  manifest."rejects boilerplate entry without src" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
        boilerplate = [
          { dest = "config.toml"; }
        ];
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

  manifest."allBoilerplatePaths collects string entries" = {
    expr = gits.allBoilerplatePaths [
      {
        name = "test";
        remote = "x";
        boilerplate = [
          "Cargo.toml"
          "README.md"
        ];
      }
    ];
    expected = [
      {
        injection = "test";
        src = "Cargo.toml";
        dest = "Cargo.toml";
      }
      {
        injection = "test";
        src = "README.md";
        dest = "README.md";
      }
    ];
  };

  manifest."allBoilerplatePaths respects custom dest" = {
    expr = gits.allBoilerplatePaths [
      {
        name = "test";
        remote = "x";
        boilerplate = [
          {
            src = "boilerplate/Cargo.toml";
            dest = "Cargo.toml";
          }
        ];
      }
    ];
    expected = [
      {
        injection = "test";
        src = "boilerplate/Cargo.toml";
        dest = "Cargo.toml";
      }
    ];
  };

  manifest."validates boilerplate dir format" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
        boilerplate.dir = "boilerplate";
      }).valid;
    expected = true;
  };

  manifest."validates boilerplate dir with exclude" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
        boilerplate = {
          dir = "boilerplate";
          exclude = [ "README.md" ];
        };
      }).valid;
    expected = true;
  };

  manifest."rejects boilerplate dir without dir field" = {
    expr =
      (gits.validateInjection 0 {
        name = "test";
        remote = "git@github.com:test/repo.git";
        boilerplate = {
          exclude = [ "README.md" ];
        };
      }).valid;
    expected = false;
  };

  manifest."validateVars accepts valid vars" = {
    expr =
      (gits.validateVars {
        project_name = "test";
        version = "1.0";
      }).valid;
    expected = true;
  };

  manifest."validateVars rejects non-string values" = {
    expr = (gits.validateVars { count = 42; }).valid;
    expected = false;
  };

  manifest."validateConfig accepts config with vars" = {
    expr =
      (gits.validateConfig {
        vars = {
          project_name = "test";
        };
        injections = [
          {
            name = "test";
            remote = "x";
            boilerplate = [ "Cargo.toml" ];
          }
        ];
      }).valid;
    expected = true;
  };
}
