# imp.gitbits

Multi-repo workspace composition for Nix projects.

Mix files from multiple git repositories into a single workspace directory, with each repo maintaining its own history and the ability to push/pull independently.

## The Problem

Git submodules and subtrees require files from external repos to live in dedicated subdirectories. You can't:

- Mix files from repo A and repo B at the same directory level
- Have `lint/` from one repo and `src/` from another both at the workspace root
- Easily sync changes bidirectionally while files are interleaved

## The Solution

`imp.gitbits` uses multiple git repositories sharing a single working directory:

- Each "injected" repo has its `.git` stored in `.gitbits/<name>.git`
- Uses `GIT_DIR` + `GIT_WORK_TREE` for operations on each repo
- Main repo's `.gitignore` excludes paths owned by injections
- Each injection uses sparse-checkout to only track its owned paths
- Full git history preserved in each repo

## Usage

```nix
let
  gitbits = import ./path/to/imp.gitbits { inherit lib; };
  
  config = gitbits.build {
    injections = {
      # Inject galagit-lint repo - its files appear at workspace root
      "galagit-lint" = {
        remote = "git@github.com:Alb-O/galagit-lint.git";
        branch = "main";
        owns = [ "lint" "nix" "sgconfig.yml" ];  # paths this repo owns
      };
      
      # Another injection
      "my-tools" = {
        remote = "git@github.com:org/tools.git";
        owns = [ "tools" ".editorconfig" ];
      };
    };
  };
in
{
  # Generated shell scripts
  inherit (config.scripts) init pull push status use;
  
  # Per-injection git wrappers
  inherit (config.wrappers) galagit-lint my-tools;
  
  # Metadata
  ownedPaths = config.ownedPaths;     # [ "lint" "nix" "sgconfig.yml" "tools" ... ]
  injectionNames = config.injectionNames;
  
  # Validation
  isValid = config.validation.valid;
  errors = config.validation.errors;
}
```

## How It Works

After running `init`, your workspace looks like:

```
workspace/
├── .git/                    # Main repo
├── .gitbits/
│   ├── galagit-lint.git/    # Injection git dir
│   └── my-tools.git/        # Another injection
├── .gitignore               # Auto-updated to ignore injection paths
├── README.md                # Main repo file
├── src/                     # Main repo
├── lint/                    # From galagit-lint
├── nix/                     # From galagit-lint  
├── sgconfig.yml             # From galagit-lint
├── tools/                   # From my-tools
└── .editorconfig            # From my-tools
```

Each repo only "sees" its own files:

```bash
# Main repo status - ignores injection paths
git status

# Injection status - only sees owned paths
GIT_DIR=.gitbits/galagit-lint.git GIT_WORK_TREE=. git status
```

## Generated Scripts

### init

Clones injections with sparse-checkout and sets up `.gitignore`:

```bash
./result/init
```

### pull

Pulls updates from all injection remotes:

```bash
./result/pull
```

### push

Pushes local changes back to injection remotes:

```bash
./result/push
```

### status

Shows status of main repo and all injections:

```bash
./result/status
```

## Switching Git Context

Use the `use` script to switch between repos in your current shell:

```bash
# Switch to an injection
eval "$(./result/use galagit-lint)"
git log          # shows galagit-lint history
git status       # shows galagit-lint status
git add . && git commit -m "fix"  # commits to galagit-lint

# Switch back to main repo
eval "$(./result/use main)"
git log          # shows main repo history
```

For convenience, add a shell function to your config:

```bash
# Add to ~/.bashrc or ~/.zshrc
gbu() { eval "$(./result/use "$1")" && echo "Switched to $1"; }

# Then just:
gbu galagit-lint   # switch to injection
gbu main           # switch back
```

### Per-Injection Git Wrapper

For one-off commands without switching context, use the generated wrappers:

```bash
# Single command to injection
./result/galagit-lint log --oneline
./result/galagit-lint diff

# Or manually
GIT_DIR=.gitbits/galagit-lint.git GIT_WORK_TREE=. git log --oneline
```

## API Reference

### Manifest

- `validateInjection name injection` - Validate a single injection config
- `validateManifest injections` - Validate all injections
- `detectConflicts injections` - Find ownership conflicts
- `allOwnedPaths injections` - Get all paths owned by injections
- `pathOwner injections path` - Find which injection owns a path

### Gitignore

- `mainRepoIgnores injections` - Generate `.gitignore` content for main repo
- `injectionExcludes injection` - Generate exclude patterns for an injection
- `sparseCheckoutPatterns injection` - Generate sparse-checkout patterns

### Git Commands

- `injectionGitDir name` - Get git dir path for injection
- `gitEnv name` - Get `GIT_DIR=... GIT_WORK_TREE=...` prefix
- `cloneCmd name injection` - Generate clone command
- `pullCmd name injection` - Generate pull command
- `pushCmd name injection` - Generate push command
- `statusCmd name` - Generate status command

### Scripts

- `initScript injections` - Generate initialization script
- `pullScript injections` - Generate pull script
- `pushScript injections` - Generate push script
- `statusScript injections` - Generate status script
- `useScript injections` - Generate context-switching script
- `injectionGitWrapper name` - Generate git wrapper for an injection

### High-Level

- `build config` - Build complete configuration with scripts and metadata

## Injection Options

| Option   | Type   | Default  | Description               |
| -------- | ------ | -------- | ------------------------- |
| `remote` | string | required | Git remote URL            |
| `branch` | string | `"main"` | Branch to track           |
| `owns`   | list   | required | Paths this injection owns |

## Limitations

- Each path can only be owned by one injection (conflicts detected)
- Nested ownership (e.g., `lib` and `lib/sub`) is not allowed
- New files must be manually assigned to an injection or main repo
- IDE git integration may need configuration to handle multiple repos
