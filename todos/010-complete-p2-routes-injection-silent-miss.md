---
status: pending
priority: p2
issue_id: "010"
tags: [code-review, reliability]
dependencies: []
---

# 010 — inject_debug_route Silently Misses Non-Standard routes.rb Format

## Problem Statement

`inject_into_file` uses a literal string `after: "Rails.application.routes.draw do"` that will silently fail to inject on any routes.rb that has a comment, whitespace variant, or frozen_string_literal header after the `do`. When `inject_into_file` finds no match, it produces no error — the route simply does not get added.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, line 60

```ruby
inject_into_file "config/routes.rb",
  after: "Rails.application.routes.draw do" do
```

Patterns that would cause a silent miss:
- `Rails.application.routes.draw do # some comment`
- File with `# frozen_string_literal: true` header creating different spacing
- Any whitespace variation around `do`

The test setup always uses verbatim `"Rails.application.routes.draw do\nend\n"`, so the test always passes but doesn't cover real Rails app route files.

## Proposed Solutions

### Option A: Use regex after: (Recommended)
```ruby
inject_into_file "config/routes.rb",
  after: /Rails\.application\.routes\.draw do[^\n]*\n/ do
```

- **Effort:** Small
- **Risk:** Low

### Option B: Verify injection succeeded and warn if not
After `inject_into_file`, re-read the file and check if the route was added.
- **Effort:** Small
- **Risk:** Low (belt-and-suspenders)

## Recommended Action

Option A, optionally combined with Option B.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb`, line 60

## Acceptance Criteria

- [ ] Route is correctly injected when routes.rb has a comment after `do`
- [ ] Route is correctly injected in a standard Rails 8 app routes.rb
- [ ] Existing idempotency test still passes

## Work Log

- 2026-03-17: Identified by kieran-rails-reviewer as P2
