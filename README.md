# imp-gits

Declarative sparse checkout and multi-repo workspace composition for Git.

## Installation

```bash
nix profile install github:imp-nix/imp.gits
```

Or in a flake:

```nix
{
  inputs.gits.url = "github:imp-nix/imp.gits";
}
```

## Quick Start

Create `.imp/gits/config.nix` in your repo:

```nix
{
  # Sparse checkout for the main repo (cone mode - directories only)
  sparse = [ "src" "lib" "docs" ];

  # Optional: inject files from other repos
  injections = [
    {
      name = "my-lib";
      remote = "https://github.com/org/lib.git";
      use = [ "lib" "tools" ];
    }
  ];
}
```

Initialize:

```bash
imp-gits init
```

## Commands

| Command                   | Description                                   |
| ------------------------- | --------------------------------------------- |
| `imp-gits init`           | Set up sparse checkout and/or injections      |
| `imp-gits status`         | Show status of sparse checkout and injections |
| `imp-gits pull [--force]` | Pull updates for all injections               |
| `imp-gits push`           | Push changes to injection remotes             |
| `imp-gits use <name>`     | Switch git context to an injection            |
| `imp-gits exit`           | Exit injection context                        |
| `imp-gits list`           | List available contexts                       |

## Config Options

```nix
{
  # Sparse checkout paths for main repo (cone mode)
  sparse = [ "src" "lib" ];

  # Template variables for boilerplate substitution
  vars = {
    project_name = "my-project";
    description = "My awesome project";
  };

  # Inject files from other repositories
  injections = [
    {
      name = "...";          # required: injection identifier
      remote = "...";        # required: git remote URL
      branch = "main";       # optional: branch to track (default: main)
      use = [ "path" ... ];  # paths continuously synced from injection

      # Boilerplate: files spawned once, then owned by you
      # Option 1: dir mapping (spawns all files from dir, stripping prefix)
      boilerplate = {
        dir = "boilerplate";     # boilerplate/* -> *
        exclude = [ "README.md" ]; # optional exclusions
      };
      # Option 2: explicit list
      # boilerplate = [
      #   "Cargo.toml"
      #   { src = "tmpl/flake.nix"; dest = "flake.nix"; }
      # ];
    }
  ];
}
```

## Sparse Checkout

The `sparse` option enables Git's sparse checkout for the main repository.

### Cone Mode (default)

Cone mode checks out entire directories. Root-level files are always included:

```nix
{
  sparse = [ "src" "docs" "nix" ];
}
```

### No-Cone Mode

No-cone mode uses gitignore-style patterns for precise control. No root files are included unless explicitly specified:

```nix
{
  sparse = {
    mode = "no-cone";
    patterns = [
      "/src/"
      "/docs/"
      "/README.md"  # explicitly include a root file
    ];
  };
}
```

After `imp-gits init`, only matching paths will be present in your working tree.

### External Target (for submodules)

To configure sparse checkout for a submodule or external repo without modifying it, use the `target` field. Place the config in the parent directory:

```
parent-repo/
├── .imp/
│   └── gits/
│       └── config.nix   # Config for the submodule
└── submodule/           # Clean submodule, no local commits
```

```nix
# .imp/gits/config.nix
{
  target = "submodule";  # Relative path to target repo
  sparse = {
    mode = "no-cone";
    patterns = [
      "/docs/"
      "/src/"
    ];
  };
}
```

This keeps the submodule pristine (no local commits needed) while the sparse checkout config lives in your parent repo.

## Injections

Injections allow mixing files from multiple repositories. Each injection's `.git` is stored in `.imp/gits/<name>.git`:

```
workspace/
├── .git/                    # Main repo
├── .imp/
│   └── gits/
│       ├── config.nix       # Config (tracked)
│       └── my-lib.git/      # Injection git dir (ignored)
├── src/                     # Main repo
├── lib/                     # From my-lib
└── tools/                   # From my-lib
```

Switch contexts to work with injection history:

```bash
# bash/zsh
eval "$(imp-gits use my-lib)"
git log                          # sees my-lib history
eval "$(imp-gits use main)"      # switch back

# fish
eval (imp-gits use my-lib)
eval (imp-gits exit)

# nushell
imp-gits use my-lib | from json | load-env
```

## Nix Library

For programmatic use:

```nix
let
  gits = import ./path/to/imp.gits { inherit lib; };
  config = gits.build {
    sparse = [ "src" ];
    injections = [ /* ... */ ];
  };
in {
  inherit (config.scripts) init pull push status use;
  inherit (config) sparse usedPaths validation;
}
```

## Boilerplate Files

Boilerplate files are spawned once during `imp-gits init` and then owned by your repository. Unlike `use` paths which are continuously synced, boilerplate files are only created if they don't already exist.

### Template Substitution

Use `@var@` syntax for variable substitution (nix-style, like substituteAll). This syntax is valid inside string literals in both nix and toml, so template files can keep their native extensions and be formatted normally.

```nix
# flake.nix (in boilerplate repo)
{
  description = "@project_name@";
}
```

```toml
# Cargo.toml (in boilerplate repo)
[package]
name = "@crate_name@"
```

Define variables in your config:

```nix
{
  vars = {
    project_name = "my-app";
    crate_name = "my-app";
  };
  injections = [{
    name = "rust-boilerplate";
    remote = "...";
    boilerplate.dir = "boilerplate";  # spawns boilerplate/* as *
  }];
}
```

### Use vs Boilerplate

| Aspect     | `use`          | `boilerplate`            |
| ---------- | -------------- | ------------------------ |
| Ownership  | Source repo    | Your repo                |
| Updates    | Synced on pull | Never overwritten        |
| Templating | No             | Yes (via `@var@` syntax) |
| Purpose    | Shared tooling | Project scaffolding      |

## Limitations

- Files tracked by main repo must be untracked before injection can claim them
