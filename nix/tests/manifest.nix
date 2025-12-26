/**
  Tests for manifest validation and ownership.
*/
{
  gitbits,
  ...
}:
let
  validInjection = {
    remote = "git@github.com:test/repo.git";
    branch = "main";
    owns = [
      "lib"
      "src/utils"
    ];
  };
in
{
  manifest."validates correct injection" = {
    expr = (gitbits.validateInjection "test" validInjection).valid;
    expected = true;
  };

  manifest."rejects missing remote" = {
    expr =
      (gitbits.validateInjection "test" {
        owns = [ "lib" ];
      }).valid;
    expected = false;
  };

  manifest."rejects missing owns" = {
    expr =
      (gitbits.validateInjection "test" {
        remote = "git@github.com:test/repo.git";
      }).valid;
    expected = false;
  };

  manifest."rejects empty owns" = {
    expr =
      (gitbits.validateInjection "test" {
        remote = "git@github.com:test/repo.git";
        owns = [ ];
      }).valid;
    expected = false;
  };

  manifest."detects path conflicts" = {
    expr =
      gitbits.detectConflicts {
        a = {
          remote = "git@github.com:test/a.git";
          owns = [ "lib" ];
        };
        b = {
          remote = "git@github.com:test/b.git";
          owns = [ "lib/sub" ];
        };
      } != [ ];
    expected = true;
  };

  manifest."allows non-conflicting paths" = {
    expr = gitbits.detectConflicts {
      a = {
        remote = "git@github.com:test/a.git";
        owns = [ "lib" ];
      };
      b = {
        remote = "git@github.com:test/b.git";
        owns = [ "src" ];
      };
    };
    expected = [ ];
  };

  manifest."pathsConflict detects nested" = {
    expr = gitbits.pathsConflict "lib" "lib/sub";
    expected = true;
  };

  manifest."pathsConflict detects equal" = {
    expr = gitbits.pathsConflict "lib" "lib";
    expected = true;
  };

  manifest."pathsConflict allows siblings" = {
    expr = gitbits.pathsConflict "lib" "src";
    expected = false;
  };

  manifest."allOwnedPaths collects all" = {
    expr = builtins.sort (a: b: a < b) (
      gitbits.allOwnedPaths {
        a = {
          remote = "x";
          owns = [
            "lib"
            "docs"
          ];
        };
        b = {
          remote = "y";
          owns = [ "src" ];
        };
      }
    );
    expected = [
      "docs"
      "lib"
      "src"
    ];
  };

  manifest."pathOwner finds correct owner" = {
    expr = gitbits.pathOwner {
      lint = {
        remote = "x";
        owns = [ "lint" ];
      };
    } "lint/foo.nix";
    expected = "lint";
  };

  manifest."pathOwner returns null for unowned" = {
    expr = gitbits.pathOwner {
      lint = {
        remote = "x";
        owns = [ "lint" ];
      };
    } "src/main.py";
    expected = null;
  };
}
