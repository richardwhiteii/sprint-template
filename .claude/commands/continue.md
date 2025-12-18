---
description: Generate a compressed continuation prompt for a new session
---

Generate a continuation prompt for starting a fresh Claude Code session. Target: <500 tokens unless complexity demands more.

Structure:
1. **Objective**: Current goal and constraints
2. **Decisions**: Key architectural/technical choices made and why
3. **State**: What's implemented, what's in progress
4. **Next**: Immediate next steps or open questions
5. **Artifacts**: Critical file paths, schemas, variable names, or snippets needed for continuity

Context to capture: $ARGUMENTS

Format as dense prose, no preamble. Optimize for a reader (Claude) who has zero prior context but needs to resume work immediately.
