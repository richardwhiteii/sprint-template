# Project Init Command

Initialize the current directory with bare repo + worktrees + sprint workflow.

## Usage

```
/project-init                # Uses current directory name
/project-init owner/repo     # Also creates GitHub repo (private)
```

**Examples:**
```bash
mkdir my-app && cd my-app
/project-init                     # Infers "my-app" from directory
/project-init owner/my-app        # Also creates GitHub remote
```

## What This Command Does

Handles three scenarios:

**A) Cloned sprint-template** (has `.git` + `.claude`):
- Converts existing `.git` to `.bare`
- Creates main/dev worktrees (empty, for project code)
- Keeps template files at root (not in worktrees)

**B) Fresh empty directory**:
- Fetches sprint template from GitHub
- Creates bare repo with main/dev/test branches
- Creates main and dev worktrees (empty)
- Keeps template files at root

**C) Existing non-template repo** (has `.git` only):
- Exits with error - use Option C from README instead

Optionally configures GitHub remote and pushes (private by default).

## Template Repository

Fetches from: `https://github.com/richardwhiteii/sprint-template`

## Execution

When invoked, execute the following script:

```bash
#!/bin/bash
set -e

PROJECT_ROOT="$(pwd)"
ARG="$1"
TEMPLATE_TMP="/tmp/hyphae-template-$$"
TEMPLATE_REPO="https://github.com/richardwhiteii/sprint-template.git"

# Parse argument: "owner/repo" or use current directory name
if [[ "$ARG" == *"/"* ]]; then
  GITHUB_REPO="$ARG"
  PROJECT_NAME=$(basename "$ARG")
elif [ -n "$ARG" ]; then
  GITHUB_REPO=""
  PROJECT_NAME="$ARG"
else
  GITHUB_REPO=""
  PROJECT_NAME=$(basename "$PROJECT_ROOT")
fi

# Check if already has worktree structure
if [ -d ".bare" ]; then
  echo "Already initialized with worktree structure."
  echo "Structure: .bare/, main/, dev/"
  exit 0
fi

# Check if cloned sprint-template (has .git and .claude)
if [ -d ".git" ] && [ -d ".claude" ]; then
  echo "Converting cloned sprint-template to worktree structure..."

  # Template files already exist at root - keep them there
  # We'll create NEW orphan branches for worktrees (not from existing main)

  # Convert .git to .bare
  mv .git .bare
  git -C .bare config core.bare true

  # Delete old branches (we'll recreate them empty)
  git -C .bare branch -D main 2>/dev/null || true
  git -C .bare branch -D dev 2>/dev/null || true
  git -C .bare branch -D test 2>/dev/null || true

  # Create empty orphan main branch with just .gitkeep
  git -C .bare worktree add "$PROJECT_ROOT/main" --orphan -b main
  touch "$PROJECT_ROOT/main/.gitkeep"
  git -C "$PROJECT_ROOT/main" add .gitkeep
  git -C "$PROJECT_ROOT/main" commit -m "Initialize main worktree"

  # Create dev branch from main (also just .gitkeep)
  git -C .bare branch dev main
  git -C .bare worktree add "$PROJECT_ROOT/dev" dev

  # Create test branch
  git -C .bare branch test main

  # Create .git pointer at root
  echo "gitdir: ./.bare" > .git

elif [ -d ".git" ]; then
  echo "Error: Existing git repository (not sprint-template)"
  echo "Use Option C from README: copy .claude/ into your project"
  exit 1

else
  # Fresh directory - fetch template and create from scratch
  echo "Fetching sprint template..."
  git clone --depth 1 "$TEMPLATE_REPO" "$TEMPLATE_TMP"
  rm -rf "$TEMPLATE_TMP/.git"

  # Copy template files to project root
  echo "Copying template files to root..."
  cp -r "$TEMPLATE_TMP/.claude" "$PROJECT_ROOT/"
  cp "$TEMPLATE_TMP/CLAUDE.md" "$PROJECT_ROOT/"
  cp "$TEMPLATE_TMP/README-GIT.md" "$PROJECT_ROOT/"
  cp "$TEMPLATE_TMP/README.md" "$PROJECT_ROOT/" 2>/dev/null || true

  # Create bare repo and set default branch
  echo "Creating bare repo..."
  git init --bare "$PROJECT_ROOT/.bare"
  echo "ref: refs/heads/main" > "$PROJECT_ROOT/.bare/HEAD"

  # Create main worktree with orphan branch (empty)
  git -C "$PROJECT_ROOT/.bare" worktree add "$PROJECT_ROOT/main" --orphan -b main
  touch "$PROJECT_ROOT/main/.gitkeep"
  git -C "$PROJECT_ROOT/main" add .gitkeep
  git -C "$PROJECT_ROOT/main" commit -m "Initialize main worktree"

  # Create dev branch and worktree (empty)
  git -C "$PROJECT_ROOT/.bare" branch dev main
  git -C "$PROJECT_ROOT/.bare" worktree add "$PROJECT_ROOT/dev" dev

  # Create test branch (no worktree)
  git -C "$PROJECT_ROOT/.bare" branch test main

  # Cleanup temp
  rm -rf "$TEMPLATE_TMP"
fi

# Configure remote if provided
if [ -n "$GITHUB_REPO" ]; then
  echo "Creating private GitHub repo..."
  gh repo create "$GITHUB_REPO" --private --source="$PROJECT_ROOT/main" --push
  git -C "$PROJECT_ROOT/.bare" remote add origin "https://github.com/$GITHUB_REPO.git"
  git -C "$PROJECT_ROOT/dev" push -u origin dev
  git -C "$PROJECT_ROOT/.bare" push origin test
fi

# Report
echo ""
echo "Project initialized: $PROJECT_NAME"
echo ""
echo "Structure:"
echo "  $PROJECT_ROOT/"
echo "  ├── .bare/           # Bare repo (shared git data)"
echo "  ├── .claude/         # Sprint agents & commands (AT ROOT)"
echo "  ├── .git             # Pointer to .bare"
echo "  ├── CLAUDE.md        # Project instructions (AT ROOT)"
echo "  ├── README-GIT.md    # Git workflow docs (AT ROOT)"
echo "  ├── main/            # Worktree -> main (PROJECT CODE ONLY)"
echo "  └── dev/             # Worktree -> dev (PROJECT CODE ONLY)"
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md with project details"
echo "  2. cd dev"
echo "  3. Create PUNCHLIST.md (or use punchlist-builder)"
echo "  4. /sprint init"
echo "  5. /sprint 1"
```

## Result Structure

```
./                      # Current directory (launch Claude from HERE)
├── .bare/              # Bare git repo
├── .claude/            # AT ROOT (not in worktrees)
│   ├── agents/         # Sprint agents
│   └── commands/       # /sprint, /sprint-init, etc.
├── .git                # Pointer to .bare
├── CLAUDE.md           # AT ROOT (edit this)
├── README-GIT.md       # AT ROOT
├── main/               # Worktree -> main (PROJECT CODE ONLY)
│   └── .gitkeep        # Empty initially
└── dev/                # Worktree -> dev (PROJECT CODE ONLY)
    └── .gitkeep        # Empty initially
```

## After Init

1. **Edit CLAUDE.md** - Add your tech stack and project rules
2. **Work in dev/** - All development happens here
3. **Create PUNCHLIST.md** - Use punchlist-builder agent or manually
4. **Run /sprint init** - Creates .sprint-config.json and GitHub milestones
5. **Run /sprint 1** - Starts automated development
