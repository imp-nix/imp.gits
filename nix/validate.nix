/**
  Validation functions for mixin configurations.
*/
{
  lib,
}:
let
  inherit (builtins)
    hasAttr
    isAttrs
    isString
    ;

  inherit (lib)
    flatten
    hasPrefix
    hasSuffix
    mapAttrsToList
    ;

  /**
    Check if a path is valid (no .. traversal, no absolute paths).

    # Arguments

    - `path` (string): Path to validate

    # Returns

    Boolean indicating validity.
  */
  isValidPath =
    path:
    isString path
    && path != ""
    && !(hasPrefix "/" path)
    && !(hasPrefix ".." path)
    && !(lib.hasInfix "/../" path)
    && !(hasSuffix "/.." path);

  /**
    Check if a remote URL looks valid.

    # Arguments

    - `url` (string): Remote URL to validate

    # Returns

    Boolean indicating validity.
  */
  isValidRemote =
    url:
    isString url
    && (
      hasPrefix "git@" url
      || hasPrefix "https://" url
      || hasPrefix "http://" url
      || hasPrefix "ssh://" url
      || hasPrefix "git://" url
    );

  /**
    Validate a mixin configuration.

    # Arguments

    - `name` (string): Mixin name for error messages
    - `mixin` (attrset): Mixin configuration

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateMixin =
    name: mixin:
    let
      errors =
        (if !(hasAttr "remote" mixin) then [ "${name}: missing 'remote'" ] else [ ])
        ++ (
          if hasAttr "remote" mixin && !isValidRemote mixin.remote then
            [ "${name}: invalid remote URL '${mixin.remote}'" ]
          else
            [ ]
        )
        ++ (if !(hasAttr "mappings" mixin) then [ "${name}: missing 'mappings'" ] else [ ])
        ++ (
          if hasAttr "mappings" mixin && !isAttrs mixin.mappings then
            [ "${name}: 'mappings' must be an attrset" ]
          else
            [ ]
        )
        ++ (
          if hasAttr "mappings" mixin && isAttrs mixin.mappings then
            flatten (
              mapAttrsToList (
                src: dst:
                (if !isValidPath src then [ "${name}: invalid source path '${src}'" ] else [ ])
                ++ (if !isValidPath dst then [ "${name}: invalid destination path '${dst}'" ] else [ ])
              ) mixin.mappings
            )
          else
            [ ]
        );
    in
    {
      valid = errors == [ ];
      inherit errors;
    };

  /**
    Validate all mixins in a configuration.

    # Arguments

    - `mixins` (attrset): Map of mixin name -> mixin config

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateMixins =
    mixins:
    let
      results = mapAttrsToList validateMixin mixins;
      allErrors = flatten (map (r: r.errors) results);
    in
    {
      valid = allErrors == [ ];
      errors = allErrors;
    };

in
{
  inherit
    isValidPath
    isValidRemote
    validateMixin
    validateMixins
    ;
}
