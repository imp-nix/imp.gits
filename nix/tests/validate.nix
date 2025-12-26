/**
  Tests for validation functions: isValidPath, isValidRemote,
  validateMixin, validateMixins.
*/
{
  lib,
  gitbits,
}:
let
  validMixin = {
    remote = "git@github.com:test/repo.git";
    branch = "main";
    mappings = {
      "src/lib" = "lib/external";
      "README.md" = "docs/external-readme.md";
    };
  };

in
{
  isValidPath."test accepts relative paths" = {
    expr = gitbits.isValidPath "foo/bar/baz";
    expected = true;
  };

  isValidPath."test rejects absolute and traversal" = {
    expr =
      !(gitbits.isValidPath "/absolute")
      && !(gitbits.isValidPath "../escape")
      && !(gitbits.isValidPath "foo/../bar");
    expected = true;
  };

  isValidRemote."test accepts valid protocols" = {
    expr =
      gitbits.isValidRemote "git@github.com:user/repo.git"
      && gitbits.isValidRemote "https://github.com/user/repo.git"
      && gitbits.isValidRemote "ssh://git@github.com/user/repo.git";
    expected = true;
  };

  isValidRemote."test rejects invalid urls" = {
    expr = !(gitbits.isValidRemote "not-a-url") && !(gitbits.isValidRemote "/path/to/repo");
    expected = true;
  };

  validateMixin."test accepts valid mixin" = {
    expr = (gitbits.validateMixin "test" validMixin).valid;
    expected = true;
  };

  validateMixin."test rejects missing required fields" = {
    expr =
      !(gitbits.validateMixin "test" {
        mappings = {
          "a" = "b";
        };
      }).valid
      && !(gitbits.validateMixin "test" { remote = "git@github.com:a/b.git"; }).valid;
    expected = true;
  };

  validateMixin."test rejects invalid paths" = {
    expr =
      (gitbits.validateMixin "test" {
        remote = "git@github.com:test/repo.git";
        mappings = {
          "../escape" = "dest";
        };
      }).valid;
    expected = false;
  };

  validateMixins."test validates multiple mixins" = {
    expr =
      (gitbits.validateMixins { a = validMixin; }).valid
      && !(gitbits.validateMixins {
        good = validMixin;
        bad = {
          remote = "invalid";
          mappings = { };
        };
      }).valid;
    expected = true;
  };
}
