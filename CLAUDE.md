# Project Instructions

## Project Overview

<!-- Describe your project in 1-2 sentences -->

## Technology Stack

<!-- List your primary technologies -->
- **Language**:
- **Database**:
- **Framework**:

## Architecture

This project follows **Hexagonal Architecture** (defined in `~/.claude/CLAUDE.md`).

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

## Sprint Configuration

- **Ticket Prefix**: `PREFIX`
- **Repository**: `owner/repo`

## Project-Specific Rules

<!-- Add any project-specific coding standards -->

## Anti-Patterns to Avoid

- Domain importing infrastructure dependencies
- Business logic in adapters
- Adapters imported by application layer
- Direct external calls outside adapters
