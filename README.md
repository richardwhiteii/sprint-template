# Sprint Template

Let me share what actually worked after months of trying to get Claude Code to run full development sprints autonomously.

## The Problem

You know the drill: You've got a feature to build, a punchlist of tasks, and you're context-switching between writing code, running tests, creating GitHub issues, and trying to remember what you were doing before Slack interrupted you. I spent years doing this dance—tweaking, running, rolling back, tweaking, running, rolling back. You get the idea.

Then Claude Code came along, and I thought, "Wait, could this handle my entire sprint workflow?"

After breaking this a few times, I learned that Claude needs structure. Not just prompts—actual agents with specific responsibilities, commands that orchestrate them, and a git workflow that keeps everything clean. This template is the result of that experimentation.

## What's Inside

```
.claude/
├── agents/           # 14 specialized agents
│   │
│   │ # Product → Code Pipeline
│   ├── product-manager.md       # Extracts ideas into detailed product docs (start here)
│   ├── punchlist-builder.md     # Turns product docs into structured task lists
│   ├── github-issue-writer.md   # Creates AI-ready GitHub issues from punchlist
│   ├── ticket-writer.md         # Creates local tickets for one-off work
│   │
│   │ # Development Agents
│   ├── git-agent.md             # Handles commits, branches, PRs, worktrees
│   ├── test-runner-agent.md     # Runs tests, captures failures, coordinates fixes
│   ├── qa-agent.md              # Verifies acceptance criteria, closes issues
│   ├── orchestrator-agent.md    # Drives the full pipeline
│   │
│   │ # Quality & Architecture
│   ├── hex-check.md             # Audits hexagonal architecture compliance
│   ├── hex-fix.md               # Fixes architecture violations
│   ├── codescan.md              # Analyzes codebase before implementation
│   ├── codebase-auditor.md      # Audits issues against actual code
│   └── sidecar-sprint-builder.md # Creates remediation sprints

└── commands/         # Slash commands
    ├── project-init.md    # Initialize new project with worktree structure
    ├── sprint.md          # Main sprint runner (/sprint 1, /sprint 2, etc.)
    ├── sprint-init.md     # Initialize sprint config and milestones
    ├── sprint-help.md     # Documentation and examples
    ├── audit.md           # Run codebase audits
    └── continue.md        # Resume work across sessions
```

### The Full Pipeline

```
You have an idea
       ↓
product-manager ──→ Detailed Product Doc
       ↓
punchlist-builder ──→ PUNCHLIST.md (phases, tasks, estimates)
       ↓
github-issue-writer ──→ GitHub Issues (AI-ready, parallel creation)
       ↓
orchestrator ──→ Code, Tests, PRs (automated sprint execution)
       ↓
qa-agent ──→ Verify & Close Issues
```

Plus project scaffolding:
- `CLAUDE.md` - Project instructions template (you'll customize this)
- `README-GIT.md` - Git workflow documentation for the bare repo + worktree setup

## The 80/20 Reality

Here's what hit me after using this for a few projects: the agents handle about 80% of the work. They'll create your issues, write your code, run your tests, and push your PRs. But you're still in charge of the 20%—the architecture decisions, the "does this actually make sense" reviews, and the occasional "no, that's not what I meant" corrections.

Full disclosure: Claude is still prone to gaslighting occasionally. It'll tell you the tests pass when they don't, or claim it fixed a bug it didn't touch. The QA agent helps catch this, but you'll want to verify critical paths yourself.

## Getting Started

### Prerequisites

1. **Claude Code CLI** - Install from [Anthropic](https://docs.anthropic.com/en/docs/claude-code)
2. **GitHub CLI** - `gh auth login` configured
3. **Git 2.36+** - For worktree orphan branch support

### Installation

**Option 1: New Project**

Start fresh with the full worktree structure:

```bash
mkdir my-project && cd my-project
git clone https://github.com/richardwhiteii/sprint-template.git .
claude
/project-init my-project
```

That's it. The `/project-init` command detects you cloned the sprint-template and automatically converts it to a bare repo with worktrees:

```
my-project/
├── .bare/      # Bare git repository (shared data)
├── main/       # Production worktree (stable releases)
├── dev/        # Development worktree (work here)
└── .git        # Pointer to .bare
```

Start working:
```bash
cd dev
claude
```

**Option 2: Existing Project**

Already have a project? Just copy the `.claude/` folder:

```bash
cd your-project
git clone --depth 1 https://github.com/richardwhiteii/sprint-template.git /tmp/sprint-template
cp -r /tmp/sprint-template/.claude .
cp /tmp/sprint-template/CLAUDE.md .
rm -rf /tmp/sprint-template
```

Then open Claude in your project root:
```bash
claude
```

### First Sprint

1. **Edit CLAUDE.md** - Add your tech stack, project rules, and any anti-patterns to avoid. This is where you tell Claude how your project works.

2. **Start with an idea** - If you have a vague idea that needs fleshing out, use the product-manager agent:
   ```
   I want to build a CLI tool that helps developers manage their dotfiles
   ```
   The agent will ask probing questions and produce a detailed product document.

3. **Create a punchlist** - Use the punchlist-builder agent on your product doc (or describe the feature directly):
   ```
   Create a punchlist from ./docs/product/dotfiles-manager-product-doc.md
   ```
   Or if you already know what you want:
   ```
   I need a user authentication system with email/password login,
   session management, and password reset flow.
   ```
   The agent will structure this into phases with specific tasks.

4. **Initialize the sprint**:
   ```
   /sprint init
   ```
   This creates `.sprint-config.json` and sets up GitHub milestones.

5. **Run your first phase**:
   ```
   /sprint 1
   ```
   Sit back (mostly). The orchestrator will create issues, implement code, run tests, and open PRs.

## The Git Workflow

Here's where I got stuck initially, and you might too: the bare repo + worktree setup.

Why this structure? After accidentally pushing broken code to main more times than I'd like to admit, I needed guardrails. The worktree setup means:

- `.bare/` - The actual git repo (all branches live here)
- `main/` - Worktree pointing to main branch (production-ready only)
- `dev/` - Worktree pointing to dev branch (where work happens)

You work in `dev/`, merge to `main/` when stable. The agents understand this flow and will create feature branches off dev, merge PRs back to dev, and only touch main when you explicitly promote.

The `/project-init` command handles all of this setup automatically. See `README-GIT.md` for the full workflow details.

## Sprint Commands

| Command | What It Does |
|---------|--------------|
| `/project-init` | Convert clone to worktree structure |
| `/sprint init` | Creates config, GitHub milestones |
| `/sprint 1` | Runs phase 1 of your punchlist |
| `/sprint 2` | Runs phase 2, and so on |
| `/sprint status` | Shows current progress |
| `/sprint help` | Full documentation |
| `/audit` | Compares closed issues against actual code |

## When Things Go Wrong

The breakthrough came when I realized Claude needs explicit error recovery paths. The agents are built with this in mind:

- **Test failures**: The test-runner will attempt fixes up to 3 times before escalating
- **Merge conflicts**: The git-agent will pause and ask for guidance
- **Missing dependencies**: Agents will check for required tools before starting

But sometimes you'll need to intervene. Common fixes:

```bash
# Reset a stuck sprint
rm .sprint-config.json
/sprint init

# Force re-run a phase
/sprint 1 --force

# Check what the orchestrator thinks is happening
/sprint status --verbose
```

## Customizing Agents

Each agent is a markdown file with a system prompt. Tweak them for your workflow:

- **Change test commands**: Edit `test-runner-agent.md` to use your test framework
- **Modify PR templates**: Update `git-agent.md` with your PR format
- **Add review steps**: Extend `qa-agent.md` with custom verification logic

The agents are designed to be forked and modified. That's the point.

## What I'm Still Figuring Out

- **Large monorepos**: The agents work best with focused projects. I'm still working on patterns for massive codebases.
- **Multiple languages**: Currently optimized for single-language projects. Polyglot support is on my list.
- **CI/CD integration**: The agents create PRs but don't yet wait for CI checks. Coming soon.

## Contributing

Found a bug? Have a better pattern? PRs welcome.

Just remember: we aren't curing cancer here. Make sure you back it up before you change it. (If you are working on cancer, that's great—AI can help with that too.)

## License

MIT - Use it, fork it, make it yours.

---

*Built by someone who's been in the trenches for 25 years and finally found a way to make the machines do more of the work. Now if I could just get Claude to attend my standups...*
