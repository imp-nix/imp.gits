/**
  Manifest validation for config.nix.

  Supports:
  - `sparse`: sparse checkout config (list for cone mode, attrset for no-cone)
  - `injections`: list of injection configs for multi-repo composition
*/
{
  lib,
}:
let
  inherit (builtins)
    all
    hasAttr
    isAttrs
    isList
    isString
    length
    elem
    ;

  inherit (lib)
    flatten
    imap0
    ;

  /**
    Validate sparse checkout configuration.

    Accepts either:
    - List of paths (cone mode)
    - Attrset with mode and paths/patterns (explicit mode)

    # Arguments

    - `sparse` (list or attrset): Sparse checkout configuration

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateSparse =
    sparse:
    let
      # List format = cone mode shorthand
      listErrors =
        if isList sparse then
          if !all isString sparse then [ "all entries in sparse list must be strings" ] else [ ]
        else
          [ ];

      # Attrset format = explicit mode
      attrsetErrors =
        if isAttrs sparse then
          let
            mode = sparse.mode or "cone";
            hasValidMode = elem mode [
              "cone"
              "no-cone"
            ];
            isCone = mode == "cone";

            # Cone mode uses 'paths', no-cone uses 'patterns'
            pathsKey = if isCone then "paths" else "patterns";
            hasItems = hasAttr pathsKey sparse;
            items = sparse.${pathsKey} or [ ];
            itemsValid = isList items && all isString items;
          in
          (if !hasValidMode then [ "sparse.mode must be 'cone' or 'no-cone'" ] else [ ])
          ++ (if !hasItems then [ "sparse.${pathsKey} is required for ${mode} mode" ] else [ ])
          ++ (if hasItems && !itemsValid then [ "sparse.${pathsKey} must be a list of strings" ] else [ ])
        else
          [ ];

      # Must be list or attrset
      typeErrors =
        if !isList sparse && !isAttrs sparse then
          [ "sparse must be a list (cone mode) or attrset (explicit mode)" ]
        else
          [ ];

      errors = typeErrors ++ listErrors ++ attrsetErrors;
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
