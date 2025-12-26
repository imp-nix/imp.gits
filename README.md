# imp.gitbits

Declarative repository composition for Nix projects.

Mix files from multiple git repositories into a single project with fine-grained path control, while maintaining the ability to sync (push/pull) with source remotes.

## The Problem

Git submodules require self-contained nested directories. You can't:

- Place files from repo A at `lib/formatters/` and repo B at `lib/validators/`
- Freely mix files from multiple repos within the same directory tree
- Easily keep changes in sync with upstream when files are reorganized

## The Solution

`imp.gitbits` uses git subtree under the hood but provides:

- Declarative Nix configuration
- Arbitrary source→destination path mappings
- Conflict detection before operations
- Generated shell scripts for init/pull/push/status

## Usage

```nix
let
  gitbits = import ./path/to/imp.gitbits { inherit lib; };
  
  config = gitbits.build {
    mixins = {
      "imp-fmt" = {
        remote = "git@github.com:imp-nix/imp.fmt.git";
        branch = "main";
        squash = true;  # default
        mappings = {
          # source (in remote) = destination (in this repo)
          "src/formatters" = "lib/formatters";
          "README.md" = "docs/imp-fmt-readme.md";
        };
      };
      
      "imp-docgen" = {
        remote = "git@github.com:imp-nix/imp.docgen.git";
        branch = "main";
        mappings = {
          "nix/lib.nix" = "lib/docgen.nix";
          "nix/schema.nix" = "lib/docgen-schema.nix";
        };
      };
    };
  };
in
{
  # Generated shell scripts
  initScript = config.scripts.init;    # Set up remotes and initial subtrees
  pullScript = config.scripts.pull;    # Pull updates from all remotes
  pushScript = config.scripts.push;    # Push changes back to remotes
  statusScript = config.scripts.status; # Show status of all mixins
  
  # Metadata
  allPaths = config.allDestinations;   # [ "lib/formatters" "docs/imp-fmt-readme.md" ... ]
  pathInfo = config.destinationMap;    # { "lib/formatters" = { mixin = "imp-fmt"; ... }; }
  
  # Validation
  isValid = config.validation.valid;
  errors = config.validation.errors;
  conflicts = config.conflicts;
}
```

## Generated Scripts

### init

Sets up remotes and performs initial `git subtree add` for each mapping:

```bash
./result/init.sh
```

### pull

Fetches and pulls updates from all mixin remotes:

```bash
./result/pull.sh
```

### push

Pushes local changes back to mixin remotes (use with caution):

```bash
./result/push.sh
```

### status

Shows the current state of all mixins:

```bash
./result/status.sh
```

## API Reference

### Validation

- `isValidPath path` - Check if path is valid (no `..`, not absolute)
- `isValidRemote url` - Check if URL is a valid git remote
- `validateMixin name mixin` - Validate a single mixin config
- `validateMixins mixins` - Validate all mixins
- `detectPathConflicts mixins` - Find destination path conflicts

### Path Utilities

- `normalizePath path` - Remove trailing/duplicate slashes
- `parentDir path` - Get parent directory
- `baseName path` - Get last path component
- `pathsConflict a b` - Check if paths would conflict

### Git Commands

- `gitRemoteAdd name url` - Generate `git remote add` command
- `gitFetch name mixin` - Generate `git fetch` command
- `gitSubtreeAdd name mixin prefix` - Generate `git subtree add` command
- `gitSubtreePull name mixin prefix` - Generate `git subtree pull` command
- `gitSubtreePush name mixin prefix` - Generate `git subtree push` command

### Scripts

- `initScript mixins` - Generate initialization script
- `pullScript mixins` - Generate pull script
- `pushScript mixins` - Generate push script
- `statusScript mixins` - Generate status script

### High-Level

- `build config` - Build complete configuration with scripts and metadata

## Mixin Options

| Option     | Type    | Default  | Description                          |
| ---------- | ------- | -------- | ------------------------------------ |
| `remote`   | string  | required | Git remote URL                       |
| `branch`   | string  | `"main"` | Branch to track                      |
| `squash`   | bool    | `true`   | Squash commits on subtree operations |
| `mappings` | attrset | required | Source path → destination path       |

## Limitations

- Each destination path can only come from one mixin (conflicts are detected)
- Nested destination conflicts (e.g., `lib` and `lib/sub`) are detected and rejected
- Pushing requires write access to the remote repository
