#!/bin/bash
# Sprint Template Setup Script
# Converts cloned repo to bare + worktree structure

set -e

echo "🔧 Setting up bare repository with worktrees..."

# Check if already set up
if [ -d ".bare" ]; then
    echo "✅ Already configured (found .bare/)"
    exit 0
fi

# Must have .git directory
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository (no .git directory)"
    exit 1
fi

# Step 1: Convert to bare repo
echo "→ Converting to bare repository..."
mv .git .bare

# Step 2: Create .git file pointing to bare
echo "gitdir: ./.bare" > .git

# Step 3: Configure bare repo
cd .bare
git config core.bare false
git config core.worktree ..
cd ..

# Step 4: Create main worktree (current directory becomes main)
echo "→ Setting up main worktree..."
mkdir -p main
git worktree add main main 2>/dev/null || git worktree add main -b main

# Step 5: Create dev branch and worktree
echo "→ Setting up dev worktree..."
git branch dev main 2>/dev/null || true
git worktree add dev dev

# Step 6: Create test branch (no worktree - promotes from dev)
echo "→ Creating test branch..."
git branch test main 2>/dev/null || true

# Step 7: Move template files to main worktree
echo "→ Moving files to main worktree..."
for item in .claude CLAUDE.md README.md README-GIT.md setup.sh; do
    if [ -e "$item" ] && [ "$item" != "main" ] && [ "$item" != "dev" ] && [ "$item" != ".bare" ] && [ "$item" != ".git" ]; then
        mv "$item" main/ 2>/dev/null || true
    fi
done

# Step 8: Copy to dev for development
echo "→ Syncing to dev worktree..."
cp -r main/.claude dev/
cp main/CLAUDE.md dev/
cp main/README.md dev/
cp main/README-GIT.md dev/

# Step 9: Commit initial state in dev
cd dev
git add -A
git commit -m "chore: initialize sprint template" 2>/dev/null || true
cd ..

echo ""
echo "✅ Setup complete!"
echo ""
echo "Structure created:"
echo "  .bare/     - Bare git repository (shared data)"
echo "  main/      - Production worktree (stable releases)"
echo "  dev/       - Development worktree (active work)"
echo ""
echo "Quick start:"
echo "  cd dev"
echo "  # Start coding!"
echo ""
echo "Create feature branch:"
echo "  git -C .bare worktree add feat-001 -b feature/my-feature dev"
echo ""
