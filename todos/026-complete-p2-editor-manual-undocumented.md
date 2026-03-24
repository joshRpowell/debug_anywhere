---
status: pending
priority: p2
issue_id: "026"
tags: [code-review, agent-native, documentation]
dependencies: []
---

# 026 — --editor=manual Behavior Undocumented in README

## Problem Statement

The README options table lists `manual` as a valid `--editor` value but provides no description of what it does. An agent or developer choosing `--editor=manual` has no documented guarantee of the outcome.

## Findings

File: `README.md`, Options table

```markdown
| `--editor` | `vscode` | IDE config to generate: `vscode`, `rubymine`, `zed`, `manual` |
```

The `manual` value skips all IDE config generation entirely and instructs `bin/debug` to print manual attach instructions. This is documented nowhere. Tests at lines 301–305 confirm the behavior but there is no README coverage.

## Proposed Solutions

### Option A: Update README options table description
Change the `--editor` table row description to:

```markdown
| `--editor` | `vscode` | IDE config to generate: `vscode`, `rubymine`, `zed`, `manual` (skips IDE config; attach manually to localhost:{port}) |
```

**Effort:** Trivial | **Risk:** None

### Option B: Add a dedicated section for manual attach workflow
Add a "Manual attach" subsection under Usage explaining what `--editor=manual` produces and how to use rdbg directly.

**Effort:** Small | **Risk:** None

## Recommended Action

Option A — minimal table update is sufficient; the existing Usage section implies the rest.

## Technical Details

- **Affected files:** `README.md` Options table

## Acceptance Criteria

- [ ] README options table describes what `manual` does (skips IDE config)
- [ ] A developer reading only the README understands what `--editor=manual` produces

## Work Log

- 2026-03-24: Identified by agent-native-reviewer during PR #2 review
