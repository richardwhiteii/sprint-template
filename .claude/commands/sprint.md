# Sprint Command

Execute a fully automated development sprint using specialized agents.

## Usage

```
/sprint              # Continue current phase (default)
/sprint 2            # Start Phase 2
/sprint phase=3      # Start Phase 3
```

## Overview

The sprint command orchestrates a multi-phase development workflow by:
1. Dispatching work to specialized agents
2. Receiving structured reports
3. Routing to next step based on status
4. Managing phase state and progress

Main context is **orchestration only** - no inline git commands, no direct implementation.

## Configuration

### Sprint Config (`.sprint-config.json`)
Sprint configuration is read from `.sprint-config.json` in project root:

```json
{
  "phases": {
    "1": {
      "punchlist_file": "PUNCHLIST_001.md",
      "ticket_range": "001-004",
      "milestone": "Phase 1: Core Foundation",
      "status": "complete"
    },
    "2": {
      "punchlist_file": "PUNCHLIST_001.md",
      "ticket_range": "005-008",
      "milestone": "Phase 2: Enhanced Formatting",
      "status": "not_started",
      "parallel_tickets": ["006", "007"]
    }
  },
  "repo": "owner/repo",
  "project_root": "$PROJECT_ROOT"
}
```

**Config Fields:**
- `punchlist_file`: Source punchlist in dev/ directory
- `ticket_range`: Issue number range (e.g., "005-008")
- `milestone`: GitHub milestone name
- `status`: "not_started" | "in_progress" | "complete"
- `parallel_tickets`: Optional array of ticket numbers that can run in parallel

### Sprint State (`.sprint-state.json`)
Runtime state tracking for QA verification. Created/updated during sprint execution:

```json
{
  "current_phase": 4,
  "started_at": "2025-12-16T10:00:00Z",
  "issues": {
    "20": {
      "issue_number": 20,
      "title": "PREFIX-020: Local dev environment",
      "pr_number": 47,
      "pr_merged": true,
      "pr_merged_at": "2025-12-16T12:30:00Z",
      "qa_verified": true,
      "verified_at": "2025-12-16T12:35:00Z",
      "verification_comment_url": "https://github.com/owner/repo/issues/20#issuecomment-123456",
      "ac_results": [
        {"ac": "AC1: Docker compose works", "verified": true, "citation": "docker-compose.yml:1-45"},
        {"ac": "AC2: Scripts documented", "verified": true, "citation": "docs/dev-environment.md:10-50"}
      ],
      "labels_applied": ["completed", "qa-verified"],
      "issue_closed": true,
      "worktree_cleaned": true
    },
    "21": {
      "issue_number": 21,
      "title": "PREFIX-021: E2E tests",
      "pr_number": 48,
      "pr_merged": true,
      "qa_verified": false,
      "verification_comment_url": null,
      "issue_closed": false,
      "worktree_cleaned": false
    }
  }
}
```

**State Fields:**
- `qa_verified`: **MUST be true** before cleanup can proceed
- `verification_comment_url`: Proof of audit trail (required)
- `ac_results`: File:line citations for each acceptance criterion
- `issue_closed`: Confirms explicit close (not auto-close from PR)

**Pre-Close Validation:**
Before marking phase complete, verify ALL issues have:
1. `qa_verified == true`
2. `verification_comment_url` is not null
3. `issue_closed == true`

## Workflow Architecture

```
/sprint [phase]
    │
    ▼
PHASE SETUP
  - Read .sprint-config.json
  - Check phase status
  - Check for open issues
    │
    ▼
ISSUE CREATION (if phase not started)
  - github-issue-writer agent
  - Reads punchlist directly (no intermediate ticket files)
  - Creates rich GitHub Issues with milestone
    │
    ▼
IMPLEMENTATION LOOP (for each issue)
  A. git-agent(create-worktree)     → Create isolated worktree (git -C .bare worktree add)
  B. focused-code-writer            → Implement from GitHub Issue
  C. test-runner-agent              → Run tests, fix failures
  D. git-agent(commit)              → Commit changes
  E. git-agent(push-and-pr)         → Push and create PR
  F. git-agent(merge-pr)            → Merge to main (squash)
  G. qa-agent [BLOCKING]            → Verify AC with codebase citations, close issue
  H. git-agent(cleanup)             → Remove worktree (git -C .bare worktree remove)
  [Repeat or run parallel if flagged]

  ⚠️ CRITICAL: Step H MUST NOT execute until Step G returns verification_passed=true.
     Issues auto-closed by "Closes #N" in PRs bypass QA - this is the gap we prevent.
    │
    ▼
PHASE COMPLETE
  - Update config status to "complete"
  - Report completion summary
  - Prompt for next phase
```

## Specialized Agents

### github-issue-writer
**Purpose:** Convert punchlist items to GitHub Issues

**Input:**
```
Task(subagent_type="github-issue-writer", prompt="
  punchlist=$PROJECT_ROOT/dev/PUNCHLIST_001.md
  phase=2
  ticket_range=005-008
  milestone=Phase 2: Enhanced Formatting
  repo=owner/repo
")
```

**Output:** Structured report with created issue numbers

### git-agent
**Purpose:** All git operations (7 modes)

**Modes:**
1. `create-worktree` - Create isolated branch for feature
2. `commit` - Commit changes with message
3. `push-and-pr` - Push branch and create PR
4. `merge-pr` - Merge PR to dev branch
5. `cleanup` - Remove worktree
6. `sync` - Sync worktree with dev
7. `resolve-conflicts` - Handle merge conflicts

**Example Invocations:**

```
# Create worktree
Task(subagent_type="git-agent", prompt="
  mode=create-worktree
  branch=feat-PREFIX-005
  base=dev
")

# Commit changes
Task(subagent_type="git-agent", prompt="
  mode=commit
  message=feat: implement markdown formatting
  branch=feat-PREFIX-005
")

# Push and create PR
Task(subagent_type="git-agent", prompt="
  mode=push-and-pr
  branch=feat-PREFIX-005
  base=dev
  title=PREFIX-005: Markdown Formatting
  issue=5
")

# Merge PR
Task(subagent_type="git-agent", prompt="
  mode=merge-pr
  pr_number=42
  method=squash
")

# Cleanup worktree
Task(subagent_type="git-agent", prompt="
  mode=cleanup
  branch=feat-PREFIX-005
")
```

**Output:** Structured status report (success/failure, details)

### focused-code-writer
**Purpose:** Implement feature from GitHub Issue

**Input:**
```
Task(subagent_type="focused-code-writer", prompt="
  Implement PREFIX-005 from GitHub issue #5
  Repo: owner/repo
  Branch: feat-PREFIX-005
  Read the issue for full requirements
")
```

**Output:** Implementation complete report

### test-runner-agent
**Purpose:** Run tests, fix failures (up to 3 attempts)

**Input:**
```
Task(subagent_type="test-runner-agent", prompt="
  Run all tests in $PROJECT_ROOT
  Fix any failures (max 3 attempts)
  Branch: feat-PREFIX-005
")
```

**Output:** Test results (pass/fail, coverage, attempts)

### qa-agent
**Purpose:** Verify implementation against acceptance criteria with codebase citations

**Input:**
```
Task(subagent_type="qa-agent", prompt="
  action=verify
  issue=5
  pr=42
  repo=owner/repo

  REQUIREMENTS:
  1. Extract acceptance criteria from issue body
  2. Verify EACH AC against actual codebase with file:line citations
  3. Add verification comment to issue (NOT just rely on PR merge)
  4. Add labels: completed, qa-verified
  5. Close issue with audit trail
  6. Return verification_passed=true/false
")
```

**Output:**
```json
{
  "verification_passed": true,
  "issue": 5,
  "pr": 42,
  "ac_results": [
    {"ac": "AC1: API endpoint created", "verified": true, "citation": "src/api/routes.ts:45-67"},
    {"ac": "AC2: Tests pass", "verified": true, "citation": "tests/api.test.ts:12-34"}
  ],
  "verification_comment_url": "https://github.com/owner/repo/issues/5#issuecomment-123456",
  "labels_applied": ["completed", "qa-verified"],
  "issue_closed": true
}
```

**CRITICAL:** If `verification_passed=false`, workflow HALTS. Do not proceed to cleanup.

## State Machine Logic

### Phase Determination

```
IF user provides phase argument (e.g., "2" or "phase=2"):
  TARGET_PHASE = argument
  ACTION = "start_phase"
ELSE:
  READ open_issues = gh issue list --state open
  IF open_issues exists:
    ACTION = "continue_implementation"
  ELSE IF all_phases_complete:
    ACTION = "report_complete"
  ELSE:
    ACTION = "prompt_next_phase"
```

### Phase Startup

```
1. Read phase config from .sprint-config.json
2. Check phase status
   IF status == "complete":
     ERROR: "Phase already complete"
   IF status == "in_progress":
     CHECK for open issues → continue implementation
   IF status == "not_started":
     PROCEED to issue creation

3. Dispatch github-issue-writer:
   - punchlist = dev/{punchlist_file}
   - phase = {phase_number}
   - range = {ticket_range}
   - milestone = {milestone}
   - repo = {repo}

4. Receive report with created issue numbers

5. Update .sprint-config.json:
   phases[{phase}].status = "in_progress"

6. Proceed to implementation loop
```

### Implementation Loop

```
1. Get all open issues for current milestone
2. Identify parallel vs sequential tickets from config

FOR EACH issue (or parallel batch):

  STEP A: Create Worktree
    Dispatch: git-agent(create-worktree)
    Input: branch=feat-PREFIX-{num}, base=dev
    Receive: success/failure report

  STEP B: Implement
    Dispatch: focused-code-writer
    Input: GitHub issue number, branch
    Receive: implementation complete report

  STEP C: Test
    Dispatch: test-runner-agent
    Input: branch, max_attempts=3
    Receive: test results
    IF failure after 3 attempts:
      DISPATCH error handler
      CONTINUE to next issue

  STEP D: Commit
    Dispatch: git-agent(commit)
    Input: branch, commit message
    Receive: commit confirmation

  STEP E: Push and PR
    Dispatch: git-agent(push-and-pr)
    Input: branch, base=dev, title, issue number
    Receive: PR number

  STEP F: Merge PR
    Dispatch: git-agent(merge-pr)
    Input: PR number, method=squash
    Receive: merge confirmation

  STEP G: Verify and Close [BLOCKING - MANDATORY]
    Dispatch: qa-agent
    Input: action=verify issue=N repo={repo} pr=M
    Receive: QA report with verification_passed boolean

    BLOCKING GATE:
      IF verification_passed == false:
        LOG failure details
        MARK issue with "qa-failed" label
        HALT workflow for this issue
        ESCALATE to user
        DO NOT proceed to Step H

      IF verification_passed == true:
        VERIFY qa-agent added:
          - Verification comment with file:line citations
          - "completed" and "qa-verified" labels
          - Issue is CLOSED (not just auto-closed by PR)

        UPDATE .sprint-state.json:
          issues[N].qa_verified = true
          issues[N].verified_at = timestamp
          issues[N].verification_comment_url = comment_url

        PROCEED to Step H

  STEP H: Cleanup (CONDITIONAL)
    PRE-CONDITION: Step G must return verification_passed=true

    Dispatch: git-agent(cleanup)
    Input: branch name
    Receive: cleanup confirmation

    UPDATE .sprint-state.json:
      issues[N].worktree_cleaned = true

3. Check for remaining open issues
   IF none: PROCEED to phase complete
   ELSE: CONTINUE loop
```

### Parallel Execution

```
IF config.parallel_tickets includes current batch:

  FOR EACH ticket in parallel batch:
    DISPATCH all agents asynchronously
    COLLECT reports

  WAIT for all to complete

  CHECK for conflicts:
    IF conflicts detected:
      DISPATCH git-agent(resolve-conflicts)
      RETRY merge

  PROCEED to next batch

ELSE:
  Execute sequentially (standard loop)
```

### Phase Completion

```
1. Verify all issues closed:
   gh issue list --milestone "{milestone}" --state open

   IF any open:
     ERROR: "Phase has open issues"
     RETURN incomplete report

2. Update .sprint-config.json:
   phases[{phase}].status = "complete"

3. Generate completion report:
   - Issues completed
   - PRs merged
   - Test results
   - Duration

4. Check for next phase:
   IF phases[{next}] exists:
     PROMPT: "Phase {current} complete. Start Phase {next}? (/sprint {next})"
   ELSE:
     REPORT: "All phases complete. Project finished."
```

## Error Handling

### Git Conflicts
```
IF git-agent returns conflict error:
  DISPATCH git-agent(resolve-conflicts)
  INPUT: conflicting files, branch
  RECEIVE: resolution report
  IF resolved:
    CONTINUE workflow
  ELSE:
    ESCALATE to user
```

### Test Failures
```
IF test-runner-agent fails after max attempts:
  LOG failure details
  MARK issue as "needs-attention" label
  CONTINUE to next issue
  REPORT failures at end of phase
```

### PR Merge Failures
```
IF git-agent(merge-pr) fails:
  CHECK CI status
  IF CI failing:
    DISPATCH test-runner-agent for fixes
    RETRY merge
  ELSE:
    ESCALATE to user
```

## Main Context Responsibilities

**DO:**
- Read configuration files
- Dispatch to agents with structured inputs
- Receive and parse agent reports
- Route to next step based on status
- Update phase state in config (simple status flags)
- Handle high-level errors by dispatching to appropriate agent
- Track progress across workflow
- Generate completion reports

**DO NOT:**
- Execute inline git commands (use git-agent)
- Implement features directly (use focused-code-writer)
- Run tests directly (use test-runner-agent)
- Create issues manually (use github-issue-writer)
- Perform QA manually (use qa-agent)
- Make assumptions about agent internals
- Expand scope beyond orchestration

## Config Updates (Main Context)

Status updates are simple state changes, handled directly by main context (not delegated to agents). This is acceptable because it's state tracking, not implementation work.

### After Issue Creation (Phase Started)

Update phase status from `not_started` to `in_progress`:

```python
# Using Edit tool on .sprint-config.json
# Change: "status": "not_started"
# To:     "status": "in_progress"
```

Or via bash:
```bash
cd $PROJECT_ROOT
sed -i 's/"status": "not_started"/"status": "in_progress"/' .sprint-config.json
```

### After Phase Complete

Update phase status from `in_progress` to `complete`:

```python
# Using Edit tool on .sprint-config.json
# Change: "status": "in_progress"
# To:     "status": "complete"
```

Or via bash:
```bash
cd $PROJECT_ROOT
sed -i 's/"status": "in_progress"/"status": "complete"/' .sprint-config.json
```

### When to Update

| Event | Status Change | Trigger |
|-------|---------------|---------|
| Issues created | `not_started` → `in_progress` | After github-issue-writer completes |
| All issues closed | `in_progress` → `complete` | After last qa-agent confirms closure |

## Example Execution

### Starting Phase 2

```
User: /sprint 2

Main Context:
1. Read .sprint-config.json
2. Extract Phase 2 config:
   - punchlist: PUNCHLIST_001.md
   - range: 005-008
   - milestone: "Phase 2: Enhanced Formatting"
   - parallel: [006, 007]

3. Dispatch github-issue-writer:
   Task(subagent_type="github-issue-writer", prompt="
     punchlist=$PROJECT_ROOT/dev/PUNCHLIST_001.md
     phase=2
     ticket_range=005-008
     milestone=Phase 2: Enhanced Formatting
     repo=owner/repo
   ")

4. Receive report:
   Created issues: #5, #6, #7, #8

5. Update config:
   phases.2.status = "in_progress"

6. Begin implementation loop for issue #5...
```

### Continuing Current Phase

```
User: /sprint

Main Context:
1. Read .sprint-config.json
2. Check for open issues:
   gh issue list --state open --json number,milestone

3. Found open issues: #6, #7 (both Phase 2)
   Config shows parallel_tickets: [006, 007]

4. Execute parallel implementation:

   PARALLEL:
     Branch A: feat-PREFIX-006
       - Create worktree
       - Implement
       - Test
       - Commit
       - Push/PR

     Branch B: feat-PREFIX-007
       - Create worktree
       - Implement
       - Test
       - Commit
       - Push/PR

   SEQUENTIAL:
     - Merge PR #43 (006)
     - Merge PR #44 (007)
     - QA and close #6
     - QA and close #7
     - Cleanup both worktrees

5. Check for remaining issues → none
6. Complete Phase 2
7. Prompt: "Start Phase 3? (/sprint 3)"
```

## Execution Start

When this command is invoked:

1. **Parse arguments** from user input
   - `/sprint` → continue current
   - `/sprint 2` → start phase 2
   - `/sprint phase=3` → start phase 3

2. **Read configuration**
   ```bash
   cat $PROJECT_ROOT/.sprint-config.json
   ```

3. **Check state**
   ```bash
   gh issue list --repo owner/repo --state open --json number,title,milestone
   ```

4. **Determine action** based on state machine logic

5. **Execute workflow** by dispatching to agents

6. **Report results** and next steps
