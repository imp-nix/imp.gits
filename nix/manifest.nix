/**
  Manifest validation and ownership declarations.

  A manifest declares which paths are owned by which injected repos.
  The main repo implicitly owns everything not claimed by an injection.
*/
{
  lib,
}:
let
  inherit (builtins)
    all
    any
    attrNames
    filter
    hasAttr
    isList
    isString
    ;

  inherit (lib)
    flatten
    hasPrefix
    mapAttrsToList
    ;

  /**
    Validate an injection configuration.

    # Arguments

    - `name` (string): Injection name for error messages
    - `injection` (attrset): Injection configuration

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateInjection =
    name: injection:
    let
      errors =
        (if !(hasAttr "remote" injection) then [ "${name}: missing 'remote'" ] else [ ])
        ++ (
          if hasAttr "remote" injection && !isString injection.remote then
            [ "${name}: 'remote' must be a string" ]
          else
            [ ]
        )
        ++ (if !(hasAttr "owns" injection) then [ "${name}: missing 'owns'" ] else [ ])
        ++ (
          if hasAttr "owns" injection && !isList injection.owns then
            [ "${name}: 'owns' must be a list of paths" ]
          else
            [ ]
        )
        ++ (
          if hasAttr "owns" injection && isList injection.owns && !all isString injection.owns then
            [ "${name}: all entries in 'owns' must be strings" ]
          else
            [ ]
        )
        ++ (
          if hasAttr "owns" injection && isList injection.owns && injection.owns == [ ] then
            [ "${name}: 'owns' cannot be empty" ]
          else
            [ ]
        );
    in
    {
      valid = errors == [ ];
      inherit errors;
    };

  /**
    Check if two paths conflict (one contains the other or they're equal).

    # Arguments

    - `a` (string): First path
    - `b` (string): Second path

    # Returns

    Boolean indicating conflict.
  */
  pathsConflict = a: b: a == b || hasPrefix "${a}/" b || hasPrefix "${b}/" a;

  /**
    Detect ownership conflicts across all injections.

    Two injections cannot own the same path or nested paths.

    # Arguments

    - `injections` (attrset): Map of injection name -> config

    # Returns

    List of conflict descriptions (empty if no conflicts).
  */
  detectConflicts =
    injections:
    let
      # Collect all (injectionName, path) pairs
      allOwned = flatten (
        mapAttrsToList (
          name: inj:
          map (path: {
            inherit name path;
          }) (inj.owns or [ ])
        ) injections
      );

      # Check each pair
      checkPair =
        a: b:
        if a.name != b.name && pathsConflict a.path b.path then
          [ "Conflict: '${a.path}' (${a.name}) vs '${b.path}' (${b.name})" ]
        else
          [ ];

      conflicts = flatten (
        lib.imap0 (i: a: flatten (lib.imap0 (j: b: if j > i then checkPair a b else [ ]) allOwned)) allOwned
      );
    in
    conflicts;

  /**
    Validate all injections in a manifest.

    # Arguments

    - `injections` (attrset): Map of injection name -> config

    # Returns

    Attrset with `valid` boolean and `errors` list.
  */
  validateManifest =
    injections:
    let
      validationResults = mapAttrsToList validateInjection injections;
      validationErrors = flatten (map (r: r.errors) validationResults);
      conflicts = detectConflicts injections;
      allErrors = validationErrors ++ conflicts;
    in
    {
      valid = allErrors == [ ];
      errors = allErrors;
    };

  /**
    Get all paths owned by injections.

    # Arguments

    - `injections` (attrset): Map of injection name -> config

    # Returns

    List of all owned paths.
  */
  allOwnedPaths = injections: flatten (mapAttrsToList (_: inj: inj.owns or [ ]) injections);

  /**
    Find which injection owns a given path.

    # Arguments

    - `injections` (attrset): Map of injection name -> config
    - `path` (string): Path to look up

    # Returns

    Injection name or null if owned by main repo.
  */
  pathOwner =
    injections: targetPath:
    let
      matches = filter (
        name:
        let
          inj = injections.${name};
        in
        any (owned: targetPath == owned || hasPrefix "${owned}/" targetPath) (inj.owns or [ ])
      ) (attrNames injections);
    in
    if matches == [ ] then null else builtins.head matches;

in
{
  inherit
    validateInjection
    validateManifest
    pathsConflict
    detectConflicts
    allOwnedPaths
    pathOwner
    ;
}
