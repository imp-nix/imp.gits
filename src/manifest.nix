/**
  Manifest validation for config.nix.

  Supports:
  - `target`: optional target directory (for external sparse checkout configs)
  - `sparse`: sparse checkout config (list for cone mode, attrset for no-cone)
  - `injections`: list of injection configs for multi-repo composition
  - `vars`: template variables for boilerplate substitution
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
    Validate a boilerplate entry.

    # Arguments

    - `prefix` (string): Error message prefix
    - `idx` (int): Index in the boilerplate list
    - `entry` (attrset or string): Boilerplate entry

    # Returns

    List of error strings.
  */
  validateBoilerplateEntry =
    prefix: idx: entry:
    let
      entryPrefix = "${prefix}.boilerplate[${toString idx}]";
    in
    if isString entry then
      [ ]
    else if isAttrs entry then
      (if !(hasAttr "src" entry) then [ "${entryPrefix}: missing 'src'" ] else [ ])
      ++ (
        if hasAttr "src" entry && !isString entry.src then
          [ "${entryPrefix}: 'src' must be a string" ]
        else
          [ ]
      )
      ++ (
        if hasAttr "dest" entry && !isString entry.dest then
          [ "${entryPrefix}: 'dest' must be a string" ]
        else
          [ ]
      )
    else
      [ "${entryPrefix}: must be a string or attrset with 'src'" ];

  /**
    Validate boilerplate configuration.

    Accepts either:
    - List of entries (string or {src, dest?})
    - Attrset with { dir, exclude? } for directory mapping

    # Arguments

    - `errPrefix` (string): Error message prefix
    - `boilerplate` (list or attrset): Boilerplate configuration

    # Returns

    List of error strings.
  */
  validateBoilerplate =
    errPrefix: boilerplate:
    if isList boilerplate then
      flatten (imap0 (i: e: validateBoilerplateEntry errPrefix i e) boilerplate)
    else if isAttrs boilerplate then
      let
        hasDir = hasAttr "dir" boilerplate;
      in
      (if !hasDir then [ "${errPrefix}.boilerplate: missing 'dir'" ] else [ ])
      ++ (
        if hasDir && !isString boilerplate.dir then
          [ "${errPrefix}.boilerplate.dir: must be a string" ]
        else
          [ ]
      )
      ++ (
        if hasAttr "exclude" boilerplate && !isList boilerplate.exclude then
          [ "${errPrefix}.boilerplate.exclude: must be a list" ]
        else
          [ ]
      )
      ++ (
        if
          hasAttr "exclude" boilerplate && isList boilerplate.exclude && !all isString boilerplate.exclude
        then
          [ "${errPrefix}.boilerplate.exclude: all entries must be strings" ]
        else
          [ ]
      )
    else
      [ "${errPrefix}.boilerplate: must be a list or attrset with 'dir'" ];

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
      hasUse = hasAttr "use" injection;
      hasBoilerplate = hasAttr "boilerplate" injection;
      boilerplate = injection.boilerplate or [ ];
      boilerplateErrors =
        if hasBoilerplate then validateBoilerplate "${prefix} (${name})" boilerplate else [ ];
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
        ++ (
          if !hasUse && !hasBoilerplate then
            [ "${prefix} (${name}): must have 'use' and/or 'boilerplate'" ]
          else
            [ ]
        )
        ++ (
          if hasUse && !isList injection.use then
            [ "${prefix} (${name}): 'use' must be a list of paths" ]
          else
            [ ]
        )
        ++ (
          if hasUse && isList injection.use && !all isString injection.use then
            [ "${prefix} (${name}): all entries in 'use' must be strings" ]
          else
            [ ]
        )
        ++ boilerplateErrors;
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
    Validate vars (template variables) configuration.

    # Arguments

    - `vars` (attrset): Template variables

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateVars =
    vars:
    let
      errors =
        if !isAttrs vars then
          [ "vars must be an attrset" ]
        else if !all isString (builtins.attrValues vars) then
          [ "all values in vars must be strings" ]
        else
          [ ];
    in
    {
      valid = errors == [ ];
      inherit errors;
    };

  /**
    Validate a complete config.

    # Arguments

    - `config` (attrset): Config with optional `target`, `sparse`, `injections`, and `vars`

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateConfig =
    config:
    let
      targetErrors =
        if hasAttr "target" config && !isString config.target then
          [ "target must be a string (relative path to target repo)" ]
        else
          [ ];
      sparseErrors = if hasAttr "sparse" config then (validateSparse config.sparse).errors else [ ];
      injectionErrors =
        if hasAttr "injections" config then (validateManifest config.injections).errors else [ ];
      varsErrors = if hasAttr "vars" config then (validateVars config.vars).errors else [ ];
      allErrors = targetErrors ++ sparseErrors ++ injectionErrors ++ varsErrors;
    in
    {
      valid = allErrors == [ ];
      errors = allErrors;
    };

  /**
    Get all boilerplate paths from injections.

    # Arguments

    - `injections` (list): List of injection configs

    # Returns

    List of { injection, src, dest } records.
  */
  allBoilerplatePaths =
    injections:
    flatten (
      map (
        inj:
        map (
          entry:
          let
            # Normalize string to attrset form
            normalized = if isString entry then { src = entry; } else entry;
            src = normalized.src;
            dest = normalized.dest or src;
          in
          {
            injection = inj.name;
            inherit src dest;
          }
        ) (inj.boilerplate or [ ])
      ) injections
    );

in
{
  inherit
    validateSparse
    validateBoilerplateEntry
    validateInjection
    validateManifest
    validateVars
    validateConfig
    allUsedPaths
    allBoilerplatePaths
    ;
}
