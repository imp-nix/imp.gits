/**
  Manifest validation for config.nix.

  Supports:
  - `sparse`: list of directories for cone-mode sparse checkout of main repo
  - `injections`: list of injection configs for multi-repo composition
*/
{
  lib,
}:
let
  inherit (builtins)
    all
    hasAttr
    isList
    isString
    length
    ;

  inherit (lib)
    flatten
    imap0
    ;

  /**
    Validate sparse checkout configuration.

    # Arguments

    - `sparse` (list): List of directory paths

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateSparse =
    sparse:
    let
      errors =
        (if !isList sparse then [ "sparse must be a list of directory paths" ] else [ ])
        ++ (
          if isList sparse && !all isString sparse then [ "all entries in sparse must be strings" ] else [ ]
        );
    in
    {
      valid = errors == [ ];
      inherit errors;
    };

  /**
    Validate an injection configuration.

    # Arguments

    - `idx` (int): Index in the injections list
    - `injection` (attrset): Injection configuration

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateInjection =
    idx: injection:
    let
      prefix = "injections[${toString idx}]";
      name = injection.name or "<unnamed>";
      errors =
        (if !(hasAttr "name" injection) then [ "${prefix}: missing 'name'" ] else [ ])
        ++ (
          if hasAttr "name" injection && !isString injection.name then
            [ "${prefix}: 'name' must be a string" ]
          else
            [ ]
        )
        ++ (if !(hasAttr "remote" injection) then [ "${prefix} (${name}): missing 'remote'" ] else [ ])
        ++ (
          if hasAttr "remote" injection && !isString injection.remote then
            [ "${prefix} (${name}): 'remote' must be a string" ]
          else
            [ ]
        )
        ++ (if !(hasAttr "use" injection) then [ "${prefix} (${name}): missing 'use'" ] else [ ])
        ++ (
          if hasAttr "use" injection && !isList injection.use then
            [ "${prefix} (${name}): 'use' must be a list of paths" ]
          else
            [ ]
        )
        ++ (
          if hasAttr "use" injection && isList injection.use && !all isString injection.use then
            [ "${prefix} (${name}): all entries in 'use' must be strings" ]
          else
            [ ]
        )
        ++ (
          if hasAttr "use" injection && isList injection.use && injection.use == [ ] then
            [ "${prefix} (${name}): 'use' cannot be empty" ]
          else
            [ ]
        );
    in
    {
      valid = errors == [ ];
      inherit errors;
    };

  /**
    Validate all injections in a manifest.

    # Arguments

    - `injections` (list): List of injection configs

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateManifest =
    injections:
    let
      listCheck = if !isList injections then [ "injections must be a list" ] else [ ];
      validationResults = if isList injections then imap0 validateInjection injections else [ ];
      validationErrors = flatten (map (r: r.errors) validationResults);
      allErrors = listCheck ++ validationErrors;
    in
    {
      valid = allErrors == [ ];
      errors = allErrors;
    };

  /**
    Get all paths used by injections.

    # Arguments

    - `injections` (list): List of injection configs

    # Returns

    List of all used paths.
  */
  allUsedPaths = injections: flatten (map (inj: inj.use or [ ]) injections);

  /**
    Validate a complete config.

    # Arguments

    - `config` (attrset): Config with optional `sparse` and `injections`

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateConfig =
    config:
    let
      sparseErrors = if hasAttr "sparse" config then (validateSparse config.sparse).errors else [ ];
      injectionErrors =
        if hasAttr "injections" config then (validateManifest config.injections).errors else [ ];
      allErrors = sparseErrors ++ injectionErrors;
    in
    {
      valid = allErrors == [ ];
      errors = allErrors;
    };

in
{
  inherit
    validateSparse
    validateInjection
    validateManifest
    validateConfig
    allUsedPaths
    ;
}
