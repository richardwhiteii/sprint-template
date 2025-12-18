#!/bin/bash
# Sprint Template Setup Script
# Converts cloned repo to bare + worktree structure

set -e

echo "🔧 Setting up bare repository with worktrees..."

# Check if already set up
if [ -d ".bare" ]; then
    echo "✅ Already configured (found .bare/)"
    echo ""
    echo "Structure:"
    ls -la | grep -E "^d" | grep -v "^\."
    exit 0
fi

# Must have .git directory
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository (no .git directory)"
    exit 1
fi

# Save the current directory
ROOT_DIR="$(pwd)"

# Step 1: Save template files to temp location
echo "→ Saving template files..."
TEMP_DIR=$(mktemp -d)
for item in .claude CLAUDE.md README.md README-GIT.md setup.sh; do
    if [ -e "$item" ]; then
        cp -r "$item" "$TEMP_DIR/"
    fi
done

# Step 2: Convert .git to .bare
echo "→ Converting to bare repository..."
mv .git .bare

# Step 3: Update bare repo to not expect a worktree at root
cd .bare
git config core.bare true
cd "$ROOT_DIR"

# Step 4: Create dev branch if it doesn't exist
echo "→ Creating branches..."
git --git-dir=.bare branch dev main 2>/dev/null || true
git --git-dir=.bare branch test main 2>/dev/null || true

# Step 5: Create main worktree
echo "→ Creating main worktree..."
git --git-dir=.bare worktree add main main

# Step 6: Create dev worktree
echo "→ Creating dev worktree..."
git --git-dir=.bare worktree add dev dev

# Step 7: Copy template files to both worktrees
echo "→ Populating worktrees with template files..."
for item in .claude CLAUDE.md README.md README-GIT.md; do
    if [ -e "$TEMP_DIR/$item" ]; then
        cp -r "$TEMP_DIR/$item" main/
        cp -r "$TEMP_DIR/$item" dev/
    fi
done

# Copy setup.sh to main for reference
cp "$TEMP_DIR/setup.sh" main/ 2>/dev/null || true

# Step 8: Commit the template files in dev
echo "→ Committing template files..."
cd dev
git add -A
git commit -m "chore: initialize sprint template" 2>/dev/null || echo "   (nothing to commit)"
cd "$ROOT_DIR"

# Step 9: Create .git file at root pointing to bare (for convenience)
echo "gitdir: ./.bare" > .git

# Step 10: Clean up temp files
rm -rf "$TEMP_DIR"

# Remove any leftover files from root (except structure)
for item in .claude CLAUDE.md README.md README-GIT.md; do
    rm -rf "$ROOT_DIR/$item" 2>/dev/null || true
done

echo ""
echo "✅ Setup complete!"
echo ""
echo "Structure created:"
echo "  .bare/     - Bare git repository (shared data)"
echo "  main/      - Production worktree (stable releases)"
echo "  dev/       - Development worktree (active work)"
echo "  test       - Branch (no worktree, promotes from dev)"
echo ""
echo "Quick start:"
echo "  cd dev"
echo "  claude"
echo ""
echo "Create feature branch:"
echo "  git -C .bare worktree add feat-001 -b feature/my-feature dev"
echo ""
