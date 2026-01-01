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

  # Inject files from other repositories
  injections = [
    {
      name = "...";          # required: injection identifier
      remote = "...";        # required: git remote URL
      branch = "main";       # optional: branch to track (default: main)
      use = [ "path" ... ];  # required: paths to take from this injection
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

## Limitations

- Files tracked by main repo must be untracked before injection can claim them
