---
status: pending
priority: p3
issue_id: "028"
tags: [code-review, agent-native, documentation]
dependencies: []
---

# 028 — Generator desc References Only VS Code

## Problem Statement

The generator's top-level `desc` string says "Scaffold rdbg remote debugging for Rails + Docker + VS Code" — but the gem now supports RubyMine, Zed, and manual attach. The description shown by `rails g debug_anywhere:install --help` implies VS Code is the only IDE.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb` line 8

```ruby
desc "Scaffold rdbg remote debugging for Rails + Docker + VS Code"
```

## Proposed Solutions

### Option A: Update desc to reflect all supported editors
```ruby
desc "Scaffold rdbg remote debugging for Rails + Docker (VS Code, RubyMine, Zed, or manual)"
```

**Effort:** Trivial | **Risk:** None

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb` line 8

## Acceptance Criteria

- [ ] Generator `desc` mentions all supported editor values
- [ ] `rails g debug_anywhere:install --help` output does not imply VS Code exclusivity

## Work Log

- 2026-03-24: Identified by agent-native-reviewer during PR #2 review
