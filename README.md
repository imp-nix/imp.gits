# git-bits

Multi-repo workspace composition. Mix files from multiple git repositories into a single directory, with each repo maintaining its own history.

## Installation

```bash
nix profile install github:imp-nix/imp.gitbits
```

Or in a flake:

```nix
{
  inputs.gitbits.url = "github:imp-nix/imp.gitbits";
}
```

## Quick Start

1. Create `.gitbits/config.nix` in your repo:

```nix
{
  injections = [
    {
      name = "my-lib";
      remote = "https://github.com/org/lib.git";
      use = [ "lib" "tools" ];
    }
  ];
}
```

2. Initialize:

```bash
git bits init
```

3. Switch contexts:

```bash
# bash/zsh
eval "$(git bits use my-lib)"
git log                          # sees my-lib history
eval "$(git bits use main)"      # switch back

# fish
eval (git bits use my-lib)
```

## Commands

| Command               | Description                              |
| --------------------- | ---------------------------------------- |
| `git bits init`       | Clone injections and configure workspace |
| `git bits status`     | Show status of all repos                 |
| `git bits pull`       | Pull updates for all injections          |
| `git bits push`       | Push changes to injection remotes        |
| `git bits use <name>` | Output shell commands to switch context  |
| `git bits list`       | List available contexts                  |

## How It Works

Each injection's `.git` is stored in `.gitbits/<name>.git`. The `.gitbits/` directory is self-ignoring (via internal `.gitignore`) except for `config.nix`. Injections use sparse-checkout to track only their used paths.

```
workspace/
├── .git/                    # Main repo
├── .gitbits/
│   ├── config.nix           # Config (tracked)
│   └── my-lib.git/          # Injection git dir (ignored)
├── src/                     # Main repo
├── lib/                     # From my-lib
└── tools/                   # From my-lib
```

## Config Options

```nix
{
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

Injections are applied in order - later entries override earlier ones for conflicting paths.

## Nix Library

For programmatic use:

```nix
let
  gitbits = import ./path/to/imp.gitbits { inherit lib; };
  config = gitbits.build {
    injections = [ /* ... */ ];
  };
in {
  inherit (config.scripts) init pull push status use;
  inherit (config) usedPaths validation;
}
```

## Limitations

- Files tracked by main repo must be untracked before injection can claim them
