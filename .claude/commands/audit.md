# Audit Command

Run a codebase audit against closed GitHub issues and optionally build a remediation sprint.

## Usage

```
/audit                    # Audit all completed phases, generate report only
/audit build              # Audit + create Phase 4.5 sidecar sprint
/audit phases=1,2         # Audit specific phases only
/audit build phases=3,4   # Audit phases 3-4 and build sidecar sprint
```

## Overview

This command orchestrates two agents:
1. **codebase-auditor**: Verifies closed issues against actual codebase
2. **sidecar-sprint-builder**: Creates remediation sprint from gaps (if `build` specified)

## Workflow

```
/audit [build] [phases=X,Y,Z]
    │
    ▼
STEP 1: Run codebase-auditor
  - Query GitHub for closed issues in target phases
  - Extract acceptance criteria from each issue
  - Verify each AC against actual codebase
  - Generate gap report with file:line citations
  - Output: .audit-report.json, .audit-summary.md
    │
    ▼
STEP 2: Review Results
  - Display summary statistics
  - Show gap count by severity
  - List top critical/high gaps
    │
    ▼
IF "build" specified:
    │
    ▼
STEP 3: Run sidecar-sprint-builder
  - Read .audit-report.json
  - Create docs/punchlist-sidecar.md
  - Create GitHub issues with milestone
  - Update .sprint-config.json with Phase 4.5
  - Output: Ready for /sprint 4.5
```

## Configuration

Reads from `.sprint-config.json`:
- Phase definitions and milestone names
- Project root and repo settings
- Existing ticket ranges (to determine next ticket number)

## Agent Invocations

### Step 1: Codebase Auditor

```
Task(subagent_type="codebase-auditor", prompt="
  repo=owner/repo
  project_root=$PROJECT_ROOT/main
  phases={target_phases}
  output_file=$PROJECT_ROOT/main/.audit-report.json
")
```

**Expected Output:**
- `.audit-report.json` - Full structured gap report
- `.audit-summary.md` - Human-readable summary

### Step 2: Sidecar Sprint Builder (if build)

```
Task(subagent_type="sidecar-sprint-builder", prompt="
  repo=owner/repo
  project_root=$PROJECT_ROOT/main
  audit_report=$PROJECT_ROOT/main/.audit-report.json
  phase=4.5
  milestone=Sprint Sidecar: Remediation
")
```

**Expected Output:**
- `docs/punchlist-sidecar.md` - Remediation punchlist
- GitHub issues created with milestone
- `.sprint-config.json` updated with Phase 4.5

## Default Phases

When no `phases=` argument provided, audit all completed phases from config:
- Phase 1: Sprint Alpha: Foundation
- Phase 2: Sprint Beta: Backend Core
- Phase 3: Sprint Gamma: Frontend MVP
- Phase 3.1: Sprint Gamma.1: Full Pass Complete
- Phase 4: Sprint Delta: Integration

## Output Locations

| File | Description |
|------|-------------|
| `.audit-report.json` | Full structured audit results |
| `.audit-summary.md` | Human-readable summary |
| `docs/punchlist-sidecar.md` | Remediation punchlist (if build) |

## Example Session

```
User: /audit

Claude: Running codebase audit on phases 1, 2, 3, 3.1, 4...

[Dispatches codebase-auditor agent]

## Audit Complete

| Metric | Value |
|--------|-------|
| Issues Audited | 22 |
| Total ACs | 88 |
| Verified | 75 (85.2%) |
| Gaps Found | 13 |

### Gaps by Severity
- Critical: 2
- High: 4
- Medium: 5
- Low: 2

### Top Critical Gaps

1. **GAP-001**: Global error handler missing (Issue #12)
2. **GAP-002**: Rate limiting not implemented (Issue #14)

Full report: `.audit-report.json`
Summary: `.audit-summary.md`

To create remediation sprint, run: `/audit build`
```

```
User: /audit build

Claude: Building Phase 4.5 remediation sprint from audit...

[Dispatches sidecar-sprint-builder agent]

## Sidecar Sprint Created

**Phase:** 4.5 - Sprint Sidecar: Remediation
**Issues Created:** PREFIX-056 through PREFIX-068

### Ready for Execution

```bash
# Review punchlist
cat docs/punchlist-sidecar.md

# View issues
gh issue list --milestone "Sprint Sidecar: Remediation"

# Start sprint
/sprint 4.5
```
```

## Error Handling

### No Gaps Found
```
Audit complete. No gaps found - all acceptance criteria verified!
Skipping sidecar sprint creation (nothing to remediate).
```

### GitHub API Errors
```
Error fetching issues for milestone "Sprint Alpha: Foundation"
Check: gh auth status
Retry: /audit
```

### Missing Config
```
Error: .sprint-config.json not found
Expected at: $PROJECT_ROOT/.sprint-config.json
```

## Post-Audit Workflow

After `/audit build` completes:

1. **Review** the punchlist: `cat docs/punchlist-sidecar.md`
2. **Review** issues: `gh issue list --milestone "Sprint Sidecar: Remediation"`
3. **Prioritize** if needed (reorder tickets)
4. **Execute**: `/sprint 4.5`
5. **Re-audit** after completion: `/audit phases=4.5`

## Integration with Sprint Workflow

Phase 4.5 follows the standard sprint workflow:
- git-agent creates worktrees
- focused-code-writer implements fixes
- test-runner-agent validates
- qa-agent verifies with citations (enforced)
- Issues closed with proper audit trail

## Constraints

- **MUST** complete audit before building sprint
- **MUST** verify audit report exists before sidecar build
- **MUST NOT** overwrite existing audit report without confirmation
- **SHOULD** display summary before building sprint
- **MAY** allow filtering by severity in future versions
