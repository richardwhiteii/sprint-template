# Project Init Command

Initialize the current directory with bare repo + worktrees + sprint workflow.

## Usage

```
/project-init <project-name>
/project-init <owner/repo>
```

**Examples:**
```bash
mkdir my-app && cd my-app
/project-init my-app              # Local only
/project-init owner/my-app        # With GitHub remote
```

## What This Command Does

1. Fetches sprint template from GitHub
2. Creates bare repo with main/dev/test branches
3. Creates main and dev worktrees
4. Copies agents, commands, and config files
5. Commits template files to main, merges to dev
6. Optionally configures GitHub remote and pushes

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

# Parse argument: "owner/repo" or just "project-name"
if [[ "$ARG" == *"/"* ]]; then
  GITHUB_REPO="$ARG"
  PROJECT_NAME=$(basename "$ARG")
else
  GITHUB_REPO=""
  PROJECT_NAME="$ARG"
fi

# Validate
if [ -z "$PROJECT_NAME" ]; then
  echo "Error: Project name required"
  echo "Usage: /project-init <project-name> or /project-init <owner/repo>"
  exit 1
fi

if [ -d ".git" ] || [ -d ".bare" ]; then
  echo "Error: Already a git repository"
  exit 1
fi

# Fetch template
echo "Fetching sprint template..."
git clone --depth 1 "$TEMPLATE_REPO" "$TEMPLATE_TMP"
rm -rf "$TEMPLATE_TMP/.git"

# Create bare repo and set default branch
echo "Creating bare repo..."
git init --bare "$PROJECT_ROOT/.bare"
echo "ref: refs/heads/main" > "$PROJECT_ROOT/.bare/HEAD"

# Create main worktree with orphan branch
git -C "$PROJECT_ROOT/.bare" worktree add "$PROJECT_ROOT/main" --orphan -b main

# Create initial commit
git -C "$PROJECT_ROOT/main" commit --allow-empty -m "Initial commit"

# Create dev branch and worktree
git -C "$PROJECT_ROOT/.bare" branch dev main
git -C "$PROJECT_ROOT/.bare" worktree add "$PROJECT_ROOT/dev" dev

# Create test branch (no worktree)
git -C "$PROJECT_ROOT/.bare" branch test main

# Copy template files to project root
echo "Copying template files..."
cp -r "$TEMPLATE_TMP/.claude" "$PROJECT_ROOT/"
cp "$TEMPLATE_TMP/CLAUDE.md" "$PROJECT_ROOT/"
cp "$TEMPLATE_TMP/README-GIT.md" "$PROJECT_ROOT/"

# Copy into main worktree and commit
cp -r "$TEMPLATE_TMP/.claude" "$PROJECT_ROOT/main/"
cp "$TEMPLATE_TMP/CLAUDE.md" "$PROJECT_ROOT/main/"
cp "$TEMPLATE_TMP/README-GIT.md" "$PROJECT_ROOT/main/"

git -C "$PROJECT_ROOT/main" add .claude CLAUDE.md README-GIT.md
git -C "$PROJECT_ROOT/main" commit -m "Add sprint workflow and project config"

# Sync dev with main
git -C "$PROJECT_ROOT/dev" merge main --no-edit

# Cleanup temp
rm -rf "$TEMPLATE_TMP"

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
echo "  .bare/           # Bare repo"
echo "  .claude/         # Sprint agents & commands"
echo "  main/            # Worktree -> main"
echo "  dev/             # Worktree -> dev"
echo "  CLAUDE.md        # Project instructions"
echo "  README-GIT.md    # Git workflow"
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
./                      # Current directory
├── .bare/              # Bare git repo
├── .claude/
│   ├── agents/         # Sprint agents
│   └── commands/       # /sprint, /sprint-init, etc.
├── main/               # Worktree -> main branch
├── dev/                # Worktree -> dev branch
├── CLAUDE.md           # Project instructions (edit this)
└── README-GIT.md       # Git workflow docs
```

## After Init

1. **Edit CLAUDE.md** - Add your tech stack and project rules
2. **Work in dev/** - All development happens here
3. **Create PUNCHLIST.md** - Use punchlist-builder agent or manually
4. **Run /sprint init** - Creates .sprint-config.json and GitHub milestones
5. **Run /sprint 1** - Starts automated development
