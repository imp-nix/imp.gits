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

1. Create `.gitbits.nix` in your repo:

```nix
{
  injections = {
    my-lib = {
      remote = "https://github.com/org/lib.git";
      owns = [ "lib" "tools" ];
    };
  };
}
```

2. Initialize:

```bash
git bits init
```

3. Switch contexts:

```bash
eval "$(git bits use my-lib)"   # switch to injection
git log                          # sees my-lib history
eval "$(git bits use main)"      # switch back
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

Each injection's `.git` is stored in `.gitbits/<name>.git`. The main repo's `.git/info/exclude` hides injection paths, and injections use sparse-checkout to track only their owned paths.

```
workspace/
├── .git/                    # Main repo
├── .gitbits/
│   └── my-lib.git/          # Injection git dir
├── .gitbits.nix             # Config
├── src/                     # Main repo
├── lib/                     # From my-lib
└── tools/                   # From my-lib
```

## Config Options

```nix
{
  injections = {
    <name> = {
      remote = "...";        # required: git remote URL
      branch = "main";       # optional: branch to track (default: main)
      owns = [ "path" ... ]; # required: paths this injection owns
    };
  };
}
```

## Nix Library

For programmatic use:

```nix
let
  gitbits = import ./path/to/imp.gitbits { inherit lib; };
  config = gitbits.build {
    injections = { /* ... */ };
  };
in {
  inherit (config.scripts) init pull push status use;
  inherit (config) ownedPaths validation;
}
```

## Limitations

- Each path can only be owned by one injection
- Nested ownership (e.g., `lib` and `lib/sub`) not allowed
- Files tracked by main repo must be untracked before injection can claim them
