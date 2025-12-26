/**
  Path manipulation and conflict detection utilities.
*/
{
  lib,
}:
let
  inherit (builtins)
    attrValues
    concatStringsSep
    filter
    length
    ;

  inherit (lib)
    flatten
    hasPrefix
    hasSuffix
    mapAttrsToList
    removeSuffix
    splitString
    ;

  /**
    Normalize a path by removing trailing slashes and duplicate slashes.

    # Arguments

    - `path` (string): Path to normalize

    # Returns

    Normalized path string.
  */
  normalizePath =
    path:
    let
      # Remove trailing slash
      noTrailing = if hasSuffix "/" path then removeSuffix "/" path else path;
      # Split and rejoin to handle duplicate slashes
      parts = filter (p: p != "") (splitString "/" noTrailing);
    in
    concatStringsSep "/" parts;

  /**
    Get parent directory of a path.

    # Arguments

    - `path` (string): Path to get parent of

    # Returns

    Parent directory path, or "" for root-level paths.
  */
  parentDir =
    path:
    let
      parts = splitString "/" (normalizePath path);
      init = if length parts > 1 then lib.init parts else [ ];
    in
    concatStringsSep "/" init;

  /**
    Get the basename (last component) of a path.

    # Arguments

    - `path` (string): Path to get basename of

    # Returns

    Basename string.
  */
  baseName =
    path:
    let
      parts = splitString "/" (normalizePath path);
    in
    if parts == [ ] then "" else lib.last parts;

  /**
    Check if two paths would conflict (one is prefix of another).

    # Arguments

    - `a` (string): First path
    - `b` (string): Second path

    # Returns

    Boolean indicating conflict.
  */
  pathsConflict =
    a: b:
    let
      na = normalizePath a;
      nb = normalizePath b;
    in
    na == nb || hasPrefix "${na}/" nb || hasPrefix "${nb}/" na;

  /**
    Detect conflicts in destination paths across all mixins.

    # Arguments

    - `mixins` (attrset): Map of mixin name -> mixin config

    # Returns

    List of conflict descriptions (empty if no conflicts).
  */
  detectPathConflicts =
    mixins:
    let
      # Collect all (mixinName, destPath) pairs
      allDests = flatten (
        mapAttrsToList (
          name: mixin: map (dst: { inherit name dst; }) (attrValues (mixin.mappings or { }))
        ) mixins
      );

      # Check each pair for conflicts
      checkPair =
        a: b:
        if a.name != b.name || a.dst != b.dst then
          if pathsConflict a.dst b.dst then [ "Conflict: ${a.name}:${a.dst} vs ${b.name}:${b.dst}" ] else [ ]
        else
          [ ];

      # Generate all pairs and check
      conflicts = flatten (
        lib.imap0 (i: a: flatten (lib.imap0 (j: b: if j > i then checkPair a b else [ ]) allDests)) allDests
      );
    in
    conflicts;

in
{
  inherit
    normalizePath
    parentDir
    baseName
    pathsConflict
    detectPathConflicts
    ;
}
