# imp.gitbits

Multi-repo workspace composition via shared working directory with separate GIT_DIRs.

## Code Style

### Nix Docstrings

Keep RFC-style docstrings with `# Arguments`, `# Returns`, `# Example` sections. These are parsed for documentation generation.

```nix
/**
  Brief description of function.

  # Arguments

  - `name` (string): What it is
  - `config` (attrset): What it contains

  # Returns

  What the function returns.
*/
```

### Shell Output

- No decorative banners (`===`, `---`, ascii art)
- No trivial status messages ("Done!", "Starting...", "Finished!")
- Error messages: terse, actionable
- Progress output: `name:` followed by indented details

### Comments

- No comments restating obvious code
- No section dividers
- Keep comments explaining non-obvious behavior or gotchas
