/**
  Tests for path utilities: normalizePath, parentDir, baseName,
  pathsConflict, detectPathConflicts.
*/
{
  lib,
  gitbits,
}:
{
  normalizePath."test cleans paths" = {
    expr =
      gitbits.normalizePath "foo/bar/" == "foo/bar"
      && gitbits.normalizePath "foo//bar///baz" == "foo/bar/baz";
    expected = true;
  };

  parentDir."test extracts parent" = {
    expr = gitbits.parentDir "foo/bar/baz" == "foo/bar" && gitbits.parentDir "foo" == "";
    expected = true;
  };

  baseName."test extracts basename" = {
    expr = gitbits.baseName "foo/bar/baz" == "baz" && gitbits.baseName "foo/bar/" == "bar";
    expected = true;
  };

  pathsConflict."test detects conflicts" = {
    expr =
      gitbits.pathsConflict "foo" "foo/bar"
      && gitbits.pathsConflict "foo/bar" "foo"
      && !(gitbits.pathsConflict "foo/bar" "foo/baz")
      && !(gitbits.pathsConflict "foo" "foobar");
    expected = true;
  };

  detectPathConflicts."test finds cross-mixin conflicts" = {
    expr =
      builtins.length (
        gitbits.detectPathConflicts {
          a.mappings."x" = "lib";
          b.mappings."y" = "lib/nested";
        }
      ) > 0;
    expected = true;
  };

  detectPathConflicts."test allows non-conflicting paths" = {
    expr = gitbits.detectPathConflicts {
      a.mappings."x" = "lib/a";
      b.mappings."y" = "lib/b";
    };
    expected = [ ];
  };
}
