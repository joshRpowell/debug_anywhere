---
status: pending
priority: p2
issue_id: "007"
tags: [code-review, quality, dead-code]
dependencies: []
---

# 007 — Dead Template routes_fragment.rb.tt Ships in Gem but Is Never Used

## Problem Statement

`lib/generators/debug_anywhere/templates/routes_fragment.rb.tt` exists on disk and is included in the gem's `spec.files` via `Dir["lib/**/*"]`, but is never referenced anywhere in the generator. The route injection uses an inline heredoc string instead. The dead template ships unused bytes to every consumer and creates a maintenance hazard where the two representations of the same content diverge.

## Findings

File: `lib/generators/debug_anywhere/templates/routes_fragment.rb.tt` — content matches the inline string in `inject_into_file` at line 61 of `install_generator.rb`.

The inline approach at line 61:
```ruby
inject_into_file "config/routes.rb",
  after: "Rails.application.routes.draw do" do
  "\n\n  if Rails.env.development?\n    get \"debug\", to: \"debug#trigger\"\n  end"
end
```

Confirmed by: kieran-rails-reviewer, code-simplicity-reviewer, architecture-strategist.

## Proposed Solutions

### Option A: Delete routes_fragment.rb.tt (Recommended)
The inline string is the current implementation. Delete the dead template.

- **Effort:** Small
- **Risk:** Low

### Option B: Use the template and delete the inline string
Switch `inject_debug_route` to use `template` or read the `.tt` file. More consistent with the pattern used for other files.
- **Effort:** Small
- **Risk:** Low

## Recommended Action

Option A — delete `routes_fragment.rb.tt`. The inline injection is simpler for a string this short.

## Acceptance Criteria

- [ ] `routes_fragment.rb.tt` is deleted
- [ ] Generator behavior is unchanged
- [ ] No test references the deleted file

## Work Log

- 2026-03-17: Identified by kieran-rails-reviewer, confirmed by architecture-strategist and code-simplicity-reviewer
