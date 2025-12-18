# Project Instructions

## Project Overview

<!-- Describe your project in 1-2 sentences. What does it do? Who is it for? -->

## Technology Stack

<!-- List your primary technologies -->
- **Language**:
- **Database**:
- **Framework**:
- **Testing**:

---

## Git Workflow

This project uses a **bare repository with worktrees**.

### Repository Structure

```
~/project/
├── .bare/          # Bare repo (all branches live here)
├── .claude/        # Agents and commands
├── main/           # Worktree -> main branch (stable releases)
├── dev/            # Worktree -> dev branch (active development)
└── feat-XXX/       # Feature worktrees (temporary, per-ticket)
```

### Branch Strategy

| Branch | Purpose | Worktree |
|--------|---------|----------|
| `main` | Production-ready releases | `main/` |
| `test` | QA/integration testing | None (branch only) |
| `dev` | Active development | `dev/` |
| `feature/*` | Individual tickets | `feat-XXX/` (temporary) |

### Workflow Rules

1. **All work happens in `dev/`** - Never commit directly to main
2. **Feature branches** - Create from dev for each ticket: `feature/PREFIX-XXX-short-desc`
3. **PRs target dev** - Not main. Main only receives merged, tested code.
4. **Promote through branches** - dev -> test -> main

### Common Git Commands

```bash
# Create feature worktree
git -C .bare worktree add feat-123 -b feature/PREFIX-123-add-auth dev

# After PR merges, cleanup
git -C .bare worktree remove feat-123

# Promote dev to test
git -C dev push origin dev:test

# Promote test to main (after QA)
git -C main pull origin main
git -C main merge origin/test
git -C main push origin main
```

---

## Sprint Agents

Available in `.claude/agents/`:

| Agent | Purpose |
|-------|---------|
| `punchlist-builder` | Converts ideas into structured task lists with phases |
| `github-issue-writer` | Creates GitHub issues from punchlist phases |
| `git-agent` | Handles commits, branches, PRs, and worktree management |
| `test-runner-agent` | Runs tests, captures failures, coordinates fixes |
| `qa-agent` | Verifies acceptance criteria, closes issues when complete |
| `orchestrator-agent` | Drives the full pipeline from issue to merged PR |
| `codebase-auditor` | Audits closed issues against actual code for gaps |
| `sidecar-sprint-builder` | Creates remediation sprints for audit findings |

---

## Sprint Commands

Available in `.claude/commands/`:

| Command | Usage | Purpose |
|---------|-------|---------|
| `/sprint init` | Run once | Creates `.sprint-config.json` and GitHub milestones |
| `/sprint 1` | Per phase | Executes phase 1 of the punchlist |
| `/sprint 2` | Per phase | Executes phase 2, and so on |
| `/sprint status` | Anytime | Shows current sprint progress |
| `/sprint help` | Anytime | Full documentation and examples |
| `/audit` | After sprint | Compares closed issues against actual codebase |

### Sprint Workflow

1. **Plan** - Create `PUNCHLIST.md` in `dev/` (manually or via punchlist-builder)
2. **Initialize** - Run `/sprint init` to configure the sprint
3. **Execute** - Run `/sprint 1`, `/sprint 2`, etc. for each phase
4. **Verify** - Run `/audit` to catch any gaps between issues and code
5. **Release** - Promote dev -> test -> main

---

## Sprint Configuration

Update these values after running `/sprint init`:

- **Ticket Prefix**: `PREFIX`
- **Repository**: `owner/repo`

---

## Architecture

This project follows **Hexagonal Architecture** (Ports and Adapters).

### Layer Structure

```
src/
├── domain/           # Pure business logic (no external deps)
├── ports/            # Interface definitions (traits/interfaces)
├── adapters/         # External integrations (DB, API, etc.)
├── application/      # Use-case orchestration
└── main/             # Composition root (wires everything)
```

### Code Placement Guide

| If you're writing... | Put it in... |
|---------------------|--------------|
| Business rules / validation | `domain/` |
| Data structures / entities | `domain/models/` |
| Interface / trait | `ports/` |
| Database code | `adapters/` |
| API integrations | `adapters/` |
| Service orchestration | `application/` |
| Dependency injection | `main/` |

---

## Project-Specific Rules

<!-- Add any project-specific coding standards, conventions, or requirements -->

---

## Anti-Patterns to Avoid

### Architecture
- Domain importing infrastructure dependencies
- Business logic in adapters
- Adapters imported by application layer
- Direct external calls outside adapters

### Git Workflow
- Committing directly to main
- Skipping the dev -> test -> main promotion
- Leaving stale feature worktrees around
- Force pushing to shared branches

### Sprint Process
- Skipping `/sprint init` before running phases
- Modifying `.sprint-config.json` manually mid-sprint
- Closing issues before acceptance criteria are verified
- Ignoring audit findings
