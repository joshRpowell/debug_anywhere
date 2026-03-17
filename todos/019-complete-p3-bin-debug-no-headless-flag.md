---
status: pending
priority: p3
issue_id: "019"
tags: [code-review, agent-native, ci]
dependencies: []
---

# 019 — bin/debug Has No Headless Mode for CI or Agent Use

## Problem Statement

The generated `bin/debug` script unconditionally attempts to open VS Code via the `code` URI scheme and a desktop browser. In CI or headless environments, these steps fail silently or cause a 30-second timeout. There is no way to run only the container startup and readiness check steps without the desktop integration.

## Findings

File: `lib/generators/debug_anywhere/templates/bin_debug.tt`, lines 30–43

```bash
if command -v code &>/dev/null; then
  code --open-url "vscode://ruby.vscode-rdbg/attach?port=<%= port %>"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  open "http://localhost:3000/debug"
elif command -v xdg-open &>/dev/null; then
  xdg-open "http://localhost:3000/debug"
fi
```

Agent-native-reviewer score: 1/5 for the generated `bin/debug` artifact. An agent cannot verify the debug session end-to-end without a desktop environment.

## Proposed Solutions

### Option A: Add --headless / --no-open flag (Recommended)
```bash
HEADLESS=${HEADLESS:-false}

if [[ "$HEADLESS" != "true" ]]; then
  if command -v code &>/dev/null; then
    code --open-url "vscode://ruby.vscode-rdbg/attach?port=<%= port %>"
  fi
  # browser open...
fi
```

Usage: `HEADLESS=true bin/debug` or `bin/debug --headless`

- **Effort:** Small
- **Risk:** Low

### Option B: Document CI usage in README
Add a section showing `docker compose up -d` as the minimal headless alternative.
- **Effort:** Small
- **Risk:** None (documentation only)

## Recommended Action

Both — add `HEADLESS` env var support to the template and document CI usage in README.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/templates/bin_debug.tt`

## Acceptance Criteria

- [ ] `HEADLESS=true bin/debug` runs without attempting to open VS Code or browser
- [ ] Script still waits for port and web server readiness in headless mode
- [ ] README documents the headless mode
- [ ] Existing test for bin/debug content passes

## Work Log

- 2026-03-17: Identified by agent-native-reviewer as P1, reclassified to P3 (nice-to-have for v0.1)
