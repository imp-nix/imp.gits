/**
  Manifest validation for injection configurations.

  Injections are processed in list order - later injections override earlier ones
  for conflicting paths.
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
      listCheck =
        if !isList injections then
          [ "injections must be a list" ]
        else
          [ ];
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

in
{
  inherit
    validateInjection
    validateManifest
    allUsedPaths
    ;
}
