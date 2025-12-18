# Git Worktree Structure

## Project Layout

```
$PROJECT_ROOT/
├── .bare/           # Bare repo (shared git data)
├── .claude/         # Claude Code agents and commands
│   ├── agents/      # Specialized agents for sprint workflow
│   └── commands/    # Slash commands (/sprint, /sprint-init, etc.)
├── main/            # Worktree: stable releases (main branch)
├── dev/             # Worktree: active development (dev branch)
├── feat-XXX/        # Worktree: temporary feature branches
├── CLAUDE.md        # Project-specific rules (optional)
└── README-GIT.md    # This file
```

## Branches

| Branch | Purpose | Worktree |
|--------|---------|----------|
| `main` | Stable releases | `main/` |
| `test` | QA/integration | BRANCH ONLY (no worktree) |
| `dev` | Active development | `dev/` |
| `feature/*` | Individual tickets | `feat-XXX/` (temporary) |

## Branch Flow

```
feature/TICKET-ID → dev → test (branch) → main
```

## Worktree Commands

### Navigate Worktrees
```bash
cd $PROJECT_ROOT/dev    # Active development
cd $PROJECT_ROOT/main   # Stable releases
```

### Create Feature Worktree
```bash
git -C .bare worktree add feat-XXX -b feature/TICKET-ID-desc dev
```

### List Worktrees
```bash
git -C .bare worktree list
```

### Remove Feature Worktree (after merge)
```bash
git -C .bare worktree remove feat-XXX
```

## Branch Promotion

### dev → test (push from dev worktree)
```bash
cd dev
git push origin dev:test
```

### test → main (merge in main worktree)
```bash
cd main
git pull origin main
git fetch origin test
git merge origin/test
git tag vX.Y.Z
git push origin main --tags
```

## Sprint Workflow

1. **Initialize**: `/sprint init` - Creates config and GitHub milestones
2. **Execute**: `/sprint 1` - Runs Phase 1 (creates issues, implements, tests, merges)
3. **Continue**: `/sprint` - Resumes current phase
4. **Repeat**: `/sprint 2`, `/sprint 3`, etc.

## Setup from Scratch

```bash
# Create project directory
mkdir my-project && cd my-project

# Initialize bare repo
git init --bare .bare

# Create main worktree and branch
git -C .bare worktree add main -b main
cd main && git commit --allow-empty -m "Initial commit" && cd ..

# Create dev branch and worktree
git -C .bare branch dev main
git -C .bare worktree add dev dev

# Create test branch (no worktree)
git -C .bare branch test main

# Add remote
git -C .bare remote add origin https://github.com/owner/repo.git
git -C .bare push -u origin main dev test
```
