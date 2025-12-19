#!/bin/bash
# Sprint Template Setup Script
# Converts cloned template to bare repo + worktree structure
# Run from project root after cloning

set -e

PROJECT_ROOT="$(pwd)"
PROJECT_NAME=$(basename "$PROJECT_ROOT")

echo "Setting up sprint template for: $PROJECT_NAME"
echo ""

# Check if already initialized
if [ -d ".bare" ]; then
  echo "Already initialized with worktree structure."
  echo "Structure: .bare/, main/, dev/"
  exit 0
fi

# Must be cloned sprint-template
if [ ! -d ".git" ] || [ ! -d ".claude" ]; then
  echo "Error: This script must be run from a cloned sprint-template directory."
  echo ""
  echo "Usage:"
  echo "  git clone https://github.com/richardwhiteii/sprint-template.git my-project"
  echo "  cd my-project"
  echo "  ./setup.sh"
  exit 1
fi

echo "Converting to worktree structure..."

# Convert .git to .bare
mv .git .bare
git -C .bare config core.bare true

# Remove origin to prevent pushing to template repo
git --git-dir=.bare remote remove origin 2>/dev/null || true

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

echo ""
echo "Setup complete!"
echo ""
echo "Structure:"
echo "  $PROJECT_ROOT/"
echo "  ├── .bare/           # Bare repo (shared git data)"
echo "  ├── .claude/         # Sprint agents & commands"
echo "  ├── .git             # Pointer to .bare"
echo "  ├── CLAUDE.md        # Project instructions (edit this)"
echo "  ├── README-GIT.md    # Git workflow docs"
echo "  ├── main/            # Worktree -> main (production)"
echo "  └── dev/             # Worktree -> dev (development)"
echo ""
echo "To connect to your own repository:"
echo "  git -C .bare remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git"
echo "  git push -u origin main"
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md with project details"
echo "  2. cd dev"
echo "  3. Create PUNCHLIST.md (or use punchlist-builder)"
echo "  4. /sprint init"
echo "  5. /sprint 1"
