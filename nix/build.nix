/**
  High-level build API for gitbits configuration.
*/
{
  lib,
  paths,
  git,
  scripts,
  validate,
}:
let
  inherit (builtins)
    attrValues
    foldl'
    mapAttrs
    ;

  inherit (lib)
    flatten
    mapAttrsToList
    ;

  inherit (paths) detectPathConflicts;
  inherit (git) sparseCheckoutContent;
  inherit (scripts)
    initScript
    pullScript
    pushScript
    statusScript
    ;
  inherit (validate) validateMixins;

  /**
    Build a complete gitbits configuration.

    # Arguments

    - `config` (attrset): Configuration with `mixins` attribute

    # Returns

    Attrset with scripts and metadata.
  */
  build =
    config:
    let
      mixins = config.mixins or { };
      validation = validateMixins mixins;
      conflicts = detectPathConflicts mixins;
    in
    {
      inherit validation conflicts;

      scripts = {
        init = initScript mixins;
        pull = pullScript mixins;
        push = pushScript mixins;
        status = statusScript mixins;
      };

      # Per-mixin sparse checkout content
      sparseCheckouts = mapAttrs (_: sparseCheckoutContent) mixins;

      # Flat list of all destination paths
      allDestinations = flatten (mapAttrsToList (_: mixin: attrValues (mixin.mappings or { })) mixins);

      # Mapping from dest -> source info
      destinationMap =
        foldl'
          (
            acc: item:
            acc
            // {
              ${item.dst} = {
                mixin = item.name;
                source = item.src;
                remote = item.remote;
              };
            }
          )
          { }
          (
            flatten (
              mapAttrsToList (
                name: mixin:
                mapAttrsToList (src: dst: {
                  inherit name src dst;
                  remote = mixin.remote;
                }) (mixin.mappings or { })
              ) mixins
            )
          );
    };

in
{
  inherit build;
}
