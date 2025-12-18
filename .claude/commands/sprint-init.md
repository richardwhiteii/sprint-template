# Sprint Init Command

Initialize a sprint configuration from a punchlist for automated development workflow.

## Usage

```
/sprint init                    # Initialize from PUNCHLIST.md in current directory
/sprint init path=./docs        # Initialize from PUNCHLIST.md in specified directory
```

## Overview

The sprint init command creates the necessary configuration and infrastructure for running automated sprints by:
1. Reading PUNCHLIST.md files to extract phase metadata
2. Generating .sprint-config.json with complete phase definitions
3. Creating GitHub milestones for each phase
4. Verifying git repository setup and dev branch
5. Reporting initialization status and readiness

## Configuration Source

Sprint initialization reads from the punchlist files in the dev worktree:

**Repository Structure:**
Project root at `~/project/` contains:
```
.
├── .bare/          # Bare repo (shared git data)
├── .claude/        # Agent and command definitions
├── main/           # Stable releases worktree (on main branch)
├── dev/            # Active development worktree (on dev branch, PUNCHLIST files here)
└── feat-XXX/       # Feature worktrees (temporary)

Branches:
- main           # Stable releases (checked out in main/)
- test           # QA/integration (BRANCH ONLY, no worktree)
- dev            # Active development (checked out in dev/)
- feature/*      # Feature branches (checked out in feat-XXX/)
```

**Expected Files in dev/ worktree:**
- `PUNCHLIST.md` - Index file with overall progress and phase metadata
- `PUNCHLIST_001.md` - Phases 1-2 details (optional)
- `PUNCHLIST_002.md` - Phases 3-4 details (optional)
- `PUNCHLIST_003.md` - Phases 5-6 details (optional)

**Required Metadata from PUNCHLIST.md:**

The main punchlist file MUST contain a phase summary table with the following structure:

```markdown
## Overall Progress Summary

| Phase | Name | Status | Hours | Tickets |
|-------|------|--------|-------|---------|
| 1 | MVP Core Printing | [ ] | 4h | PREFIX-001 to 004 |
| 2 | Enhanced Formatting | [ ] | 4h | PREFIX-005 to 008 |
| 3 | Output Options | [ ] | 5h | PREFIX-009 to 012 |
...
```

**Parsing Rules:**
- Phase number: First column (integer)
- Phase name: Second column (string)
- Ticket range: Fifth column (format: "PREFIX-XXX to YYY")
- Ticket prefix: Extracted from ticket range
- Parallel tickets: Read from "Parallel Ticket Pairs" section (optional)

**Parallel Execution Metadata:**

If present, read parallel execution configuration:

```markdown
## Parallel Execution Opportunities

### Parallel Ticket Pairs

| Phase | Parallel Tickets | Reason | Estimated Savings |
|-------|------------------|--------|-------------------|
| 2 | PREFIX-006 + PREFIX-007 | ... | ~1 hour |
| 3 | PREFIX-009 + PREFIX-010 | ... | ~1.5 hours |
```

## Generated Configuration Structure

Creates `.sprint-config.json` in project root:

```json
{
  "project": "<from git repo name or prompt>",
  "repo": "<github-user/repo-name>",
  "project_root": "<absolute path to project>",
  "dev_worktree": "dev",
  "base_branch": "dev",
  "ticket_prefix": "<extracted from punchlist>",
  "auto_merge": true,
  "max_test_retries": 3,
  "phases": {
    "1": {
      "name": "MVP Core Printing",
      "punchlist_file": "PUNCHLIST_001.md",
      "ticket_range": "001-004",
      "milestone": "Phase 1: MVP Core Printing",
      "parallel_tickets": [],
      "status": "not_started"
    },
    "2": {
      "name": "Enhanced Formatting",
      "punchlist_file": "PUNCHLIST_001.md",
      "ticket_range": "005-008",
      "milestone": "Phase 2: Enhanced Formatting",
      "parallel_tickets": ["006", "007"],
      "status": "not_started"
    }
  }
}
```

**Config Fields:**
- `project`: Project name (from git repo or user prompt)
- `repo`: GitHub repository in format "owner/name"
- `project_root`: Absolute path to project root directory
- `dev_worktree`: Name of development worktree (default: "dev")
- `base_branch`: Base branch for feature branches (default: "dev")
- `ticket_prefix`: Prefix for ticket IDs (e.g., "PREFIX")
- `auto_merge`: Whether to auto-merge PRs after CI passes
- `max_test_retries`: Maximum test retry attempts before failing

**Phase Fields:**
- `name`: Human-readable phase name
- `punchlist_file`: Source punchlist file (relative to dev worktree)
- `ticket_range`: Ticket number range (e.g., "001-004")
- `milestone`: GitHub milestone name (format: "Phase N: Name")
- `parallel_tickets`: Array of ticket numbers that can run in parallel (optional)
- `status`: Phase status ("not_started" | "in_progress" | "complete")

## Initialization Workflow

```
/sprint init
    │
    ▼
VALIDATION
  - Check for PUNCHLIST.md in dev worktree
  - Verify git repository exists
  - Check dev branch is set up
    │
    ▼
PARSE PUNCHLIST
  - Read phase metadata from Overall Progress Summary table
  - Extract ticket prefix from ticket range
  - Identify parallel execution pairs from Parallel Ticket Pairs table
  - Map phases to punchlist files (001.md, 002.md, 003.md)
    │
    ▼
DETECT/PROMPT PROJECT INFO
  - Extract repo name from git remote (if exists)
  - Prompt user for GitHub repo if not detected: "owner/repo-name"
  - Get project root (current directory)
  - Confirm dev worktree name (default: "dev")
    │
    ▼
GENERATE CONFIG
  - Create .sprint-config.json in project root
  - Initialize all phases with "not_started" status
  - Include parallel_tickets arrays for phases that support it
    │
    ▼
CREATE GITHUB MILESTONES
  - For each phase, create GitHub milestone using gh api
  - Set milestone title: "Phase N: Name"
  - Leave milestone due date empty
  - Handle errors if milestones already exist (skip with warning)
    │
    ▼
VERIFY SETUP
  - Check .sprint-config.json is valid JSON
  - Verify git remote is accessible
  - Confirm dev branch exists
  - Test GitHub API access with gh cli
    │
    ▼
REPORT COMPLETE
  - Display initialization summary
  - List created milestones
  - Show next steps (run /sprint 1 to start)
```

## Implementation Steps

### Step 1: Validate Environment

```bash
# Check for punchlist
if [ ! -f "dev/PUNCHLIST.md" ]; then
  ERROR: "PUNCHLIST.md not found in dev worktree"
  EXIT
fi

# Verify git repo
if [ ! -d ".git" ] && [ ! -d ".bare" ]; then
  ERROR: "Not a git repository"
  EXIT
fi

# Check dev branch exists
git -C .bare show-ref --verify --quiet refs/heads/dev
if [ $? -ne 0 ]; then
  ERROR: "dev branch does not exist"
  EXIT
fi
```

### Step 2: Parse Punchlist Metadata

Read and parse `dev/PUNCHLIST.md`:

**Extract Phase Information:**
1. Locate "Overall Progress Summary" table
2. For each row, extract:
   - Phase number (column 1)
   - Phase name (column 2)
   - Ticket range (column 5) → parse to get start/end numbers
3. Extract ticket prefix from first ticket range (e.g., "PREFIX-001" → "PREFIX")

**Extract Parallel Tickets:**
1. Locate "Parallel Ticket Pairs" table (if exists)
2. For each row, extract:
   - Phase number (column 1)
   - Parallel tickets (column 2) → parse "XXX-NNN + XXX-MMM" to get ["NNN", "MMM"]

**Map Phases to Punchlist Files:**
- Phases 1-2 → PUNCHLIST_001.md
- Phases 3-4 → PUNCHLIST_002.md
- Phases 5-6 → PUNCHLIST_003.md
- (or read from punchlist index if specified)

### Step 3: Detect/Prompt for Project Information

```bash
# Get project root
PROJECT_ROOT=$(pwd)

# Try to detect GitHub repo
REMOTE_URL=$(git -C .bare config --get remote.origin.url)
if [ -n "$REMOTE_URL" ]; then
  # Parse from git@github.com:owner/repo.git or https://github.com/owner/repo
  REPO=$(echo "$REMOTE_URL" | sed -E 's/.*[:/]([^/]+\/[^/]+)(\.git)?$/\1/')
else
  # Prompt user
  echo "GitHub repository not detected."
  read -p "Enter GitHub repo (owner/repo-name): " REPO
fi

# Get project name (from repo or directory)
PROJECT=$(basename "$PROJECT_ROOT")

# Confirm dev worktree
read -p "Dev worktree name [dev]: " DEV_WORKTREE
DEV_WORKTREE=${DEV_WORKTREE:-dev}
```

### Step 4: Generate .sprint-config.json

Create JSON structure with:
- Detected/prompted project information
- Parsed phase metadata
- Default settings (auto_merge: true, max_test_retries: 3)
- All phases initialized to "not_started"

Example generation (using jq or direct JSON construction):

```bash
cat > .sprint-config.json <<EOF
{
  "project": "$PROJECT",
  "repo": "$REPO",
  "project_root": "$PROJECT_ROOT",
  "dev_worktree": "$DEV_WORKTREE",
  "base_branch": "dev",
  "ticket_prefix": "$TICKET_PREFIX",
  "auto_merge": true,
  "max_test_retries": 3,
  "phases": {
    $(generate_phases_json)
  }
}
EOF
```

### Step 5: Create GitHub Milestones

For each phase in the configuration:

```bash
# Using gh api to create milestones
for phase in "${PHASES[@]}"; do
  MILESTONE_TITLE="Phase $phase: $PHASE_NAME"

  gh api repos/$REPO/milestones \
    -f title="$MILESTONE_TITLE" \
    -f state="open" \
    2>/dev/null || echo "Warning: Milestone '$MILESTONE_TITLE' may already exist"
done
```

**Error Handling:**
- If milestone already exists: Log warning and continue
- If gh cli not authenticated: Error and exit with instructions
- If API rate limited: Error and suggest retry later

### Step 6: Verify Git Setup

```bash
# Check git remote accessibility
git -C .bare ls-remote origin dev >/dev/null 2>&1
if [ $? -ne 0 ]; then
  WARNING: "Cannot access git remote. PRs may fail."
fi

# Verify dev worktree exists
if [ ! -d "$DEV_WORKTREE" ]; then
  WARNING: "Dev worktree '$DEV_WORKTREE' not found at expected location"
fi

# Test gh cli access
gh auth status >/dev/null 2>&1
if [ $? -ne 0 ]; then
  ERROR: "GitHub CLI not authenticated. Run: gh auth login"
  EXIT
fi
```

### Step 7: Report Initialization Complete

Generate summary report:

```
✓ Sprint initialized successfully

Configuration:
  Project: project-name
  Repository: owner/repo
  Root: $PROJECT_ROOT
  Dev Worktree: dev
  Ticket Prefix: PREFIX

Phases Configured:
  Phase 1: MVP Core Printing (PREFIX-001 to 004)
  Phase 2: Enhanced Formatting (PREFIX-005 to 008) [Parallel: 006, 007]
  Phase 3: Output Options (PREFIX-009 to 012) [Parallel: 009, 010]
  Phase 4: Customization (PREFIX-013 to 015)
  Phase 5: Advanced Features (PREFIX-016 to 019) [Parallel: 016, 018]
  Phase 6: Polish & Integration (PREFIX-020 to 022)

GitHub Milestones Created:
  ✓ Phase 1: MVP Core Printing
  ✓ Phase 2: Enhanced Formatting
  ✓ Phase 3: Output Options
  ✓ Phase 4: Customization
  ✓ Phase 5: Advanced Features
  ✓ Phase 6: Polish & Integration

Git Verification:
  ✓ Repository: $PROJECT_ROOT
  ✓ Dev branch: dev
  ✓ Remote: origin (accessible)
  ✓ GitHub CLI: authenticated

Next Steps:
  1. Review .sprint-config.json configuration
  2. Start first phase: /sprint 1
  3. Or continue current work: /sprint
```

## Punchlist Parsing Examples

### Example 1: Basic Phase Table

```markdown
| Phase | Name | Status | Hours | Tickets |
|-------|------|--------|-------|---------|
| 1 | MVP Core | [ ] | 4h | PREFIX-001 to 004 |
| 2 | Enhanced | [ ] | 4h | PREFIX-005 to 008 |
```

**Parsed Result:**
```json
{
  "1": {
    "name": "MVP Core",
    "ticket_range": "001-004",
    "milestone": "Phase 1: MVP Core",
    "status": "not_started"
  },
  "2": {
    "name": "Enhanced",
    "ticket_range": "005-008",
    "milestone": "Phase 2: Enhanced",
    "status": "not_started"
  }
}
```

### Example 2: With Parallel Tickets

```markdown
## Parallel Ticket Pairs

| Phase | Parallel Tickets | Reason | Estimated Savings |
|-------|------------------|--------|-------------------|
| 2 | PREFIX-006 + PREFIX-007 | Independent features | ~1 hour |
```

**Parsed Result:**
```json
{
  "2": {
    "name": "Enhanced",
    "ticket_range": "005-008",
    "milestone": "Phase 2: Enhanced",
    "parallel_tickets": ["006", "007"],
    "status": "not_started"
  }
}
```

## Error Handling

### Missing Punchlist
```
ERROR: PUNCHLIST.md not found in dev worktree
Expected location: $PROJECT_ROOT/dev/PUNCHLIST.md

Create a punchlist first using the punchlist-builder agent.
```

### Invalid Punchlist Format
```
ERROR: Could not parse phase metadata from PUNCHLIST.md

Expected table format:
| Phase | Name | Status | Hours | Tickets |
|-------|------|--------|-------|---------|
| 1 | Phase Name | [ ] | 4h | PREFIX-001 to 004 |

Please ensure PUNCHLIST.md contains the "Overall Progress Summary" table.
```

### Git Repository Not Found
```
ERROR: Not a git repository
Run: git init
```

### Dev Branch Missing
```
ERROR: dev branch does not exist
Create dev branch: git checkout -b dev
```

### GitHub Authentication Failed
```
ERROR: GitHub CLI not authenticated
Run: gh auth login

Then retry: /sprint init
```

### Milestone Creation Failed
```
WARNING: Could not create milestone "Phase 1: MVP Core"
Reason: Milestone already exists or API error

This is non-fatal. You can create milestones manually:
  gh api repos/OWNER/REPO/milestones -f title="Phase 1: MVP Core"

Continuing initialization...
```

## Configuration Validation

After generating `.sprint-config.json`, validate:

1. **JSON Syntax**: Valid JSON format
2. **Required Fields**: All required fields present
3. **Phase Numbers**: Sequential (1, 2, 3, ...)
4. **Ticket Ranges**: Valid format (NNN-MMM where NNN < MMM)
5. **Parallel Tickets**: All referenced tickets exist in phase range
6. **Punchlist Files**: Referenced files exist in dev worktree

**Validation Errors:**

```
ERROR: Invalid configuration generated

Issues found:
  - Missing required field: "repo"
  - Phase 2 ticket range invalid: "005-003" (start > end)
  - Phase 3 parallel ticket "015" not in range "009-012"
  - Punchlist file not found: PUNCHLIST_004.md

Fix these issues in .sprint-config.json before running /sprint
```

## Advanced Options

### Custom Punchlist Path

```
/sprint init path=/path/to/punchlist/directory
```

Looks for `PUNCHLIST.md` in specified directory instead of `dev/`.

### Dry Run

```
/sprint init --dry-run
```

Parses punchlist and shows what would be created without:
- Writing .sprint-config.json
- Creating GitHub milestones
- Making any changes to repository

### Force Recreate

```
/sprint init --force
```

Overwrites existing `.sprint-config.json` if present.
Default behavior is to error if config already exists.

## Integration with /sprint Command

After successful initialization:

1. `.sprint-config.json` is ready for `/sprint` command
2. GitHub milestones are created and ready for issue assignment
3. Dev branch is verified and accessible
4. Run `/sprint 1` to start Phase 1 workflow

The `/sprint` command reads `.sprint-config.json` to:
- Determine which phase to execute
- Find punchlist file for each phase
- Create issues with correct milestone
- Track parallel execution opportunities
- Update phase status after completion

## Example Execution

```
User: /sprint init

Reading punchlist: $PROJECT_ROOT/dev/PUNCHLIST.md
  ✓ Found 6 phases
  ✓ Parsed ticket prefix: PREFIX
  ✓ Identified 3 parallel execution opportunities

Detecting project information:
  ✓ Repository: owner/repo (from git remote)
  ✓ Project root: $PROJECT_ROOT
  ✓ Dev worktree: dev

Generating configuration:
  ✓ Created .sprint-config.json
  ✓ Configured 6 phases
  ✓ Mapped to 3 punchlist files

Creating GitHub milestones:
  ✓ Phase 1: MVP Core Printing
  ✓ Phase 2: Enhanced Formatting
  ✓ Phase 3: Output Options
  ✓ Phase 4: Customization
  ✓ Phase 5: Advanced Features
  ✓ Phase 6: Polish & Integration

Verifying setup:
  ✓ Git repository accessible
  ✓ Dev branch exists
  ✓ GitHub CLI authenticated
  ✓ Configuration valid

✓ Sprint initialized successfully

Next steps:
  1. Review .sprint-config.json
  2. Start Phase 1: /sprint 1
  3. Or continue work: /sprint
```

## Troubleshooting

### "Cannot parse phase table"

**Solution:** Ensure PUNCHLIST.md has a table with this exact header:
```markdown
| Phase | Name | Status | Hours | Tickets |
```

### "Ticket prefix not detected"

**Solution:** Ensure ticket ranges follow format: "PREFIX-NNN to MMM"
Example: "PREFIX-001 to 004"

### "GitHub milestones already exist"

**Solution:** This is just a warning. The command continues.
If you want fresh milestones, delete them first:
```bash
gh api repos/OWNER/REPO/milestones --jq '.[].number' | xargs -I {} gh api -X DELETE repos/OWNER/REPO/milestones/{}
```

### "Dev worktree not found"

**Solution:** Ensure you're running from project root and dev worktree exists:
```bash
cd $PROJECT_ROOT
ls -d dev/  # Should exist
```

## Related Commands

- `/sprint` - Execute sprint phases (requires init first)
- `/sprint [N]` - Start specific phase
- `/punchlist` - Build punchlist (run before init)

## Dependencies

- `gh` (GitHub CLI) - for milestone creation and API access
- `git` - for repository operations
- `jq` - for JSON manipulation (optional but recommended)

## Notes

- Always run from project root directory
- Requires GitHub authentication: `gh auth login`
- Punchlist must be approved and complete before initialization
- Configuration can be manually edited after generation
- Milestones are created in "open" state
- Phase status starts as "not_started" for all phases
