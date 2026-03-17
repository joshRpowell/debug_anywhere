---
status: pending
priority: p2
issue_id: "014"
tags: [code-review, reliability, agent-native]
dependencies: []
---

# 014 — check_debug_gem Warning Exits 0; Generated Code Will Fail at Runtime

## Problem Statement

`check_debug_gem` detects that the `debug` gem is missing from the Gemfile, prints a red warning, and continues with exit code 0. The generator then creates `DebugController` with `binding.break` — which will raise `NoMethodError` at runtime without the `debug` gem. The warning is swallowed into a successful exit code, making it undetectable by automated tools.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, lines 89–98

```ruby
def check_debug_gem
  return if File.read(File.join(destination_root, "Gemfile")).match?(/gem\s+["']debug["']/)

  say ""
  say_status :warning, "The 'debug' gem was not found in your Gemfile.", :red
  say '    gem "debug", platforms: %i[mri windows], require: "debug/prelude"'
  say "  Without it, binding.break will raise NoMethodError at runtime."
end
# Returns nil regardless; generator exits 0
```

Also identified: the regex `/gem\s+["']debug["']/` will false-positive match `gem "debugger"` or `gem "debug_inspector"` because it has no word boundary after `debug`.

## Proposed Solutions

### Option A: Exit non-zero when debug gem is missing (Recommended)
```ruby
raise Thor::Error, "The 'debug' gem is not in your Gemfile. Add: gem \"debug\", require: \"debug/prelude\""
```
Stop the generator with a clear message — the install is non-functional without it.

### Option B: Auto-add the gem to the Gemfile using Rails generator action
```ruby
gem "debug", group: :development, require: "debug/prelude"
```
- **Pros:** Fully automated
- **Cons:** Modifies Gemfile without explicit consent; may add a second `debug` entry if present with different syntax

### Option C: Fix the regex and keep warning-only behavior
Fix the false-positive regex but continue with the warning approach. Document that exit code alone is insufficient.

## Recommended Action

Option A for now (fail fast with clear message). Option B can be added as a follow-up with a `--add-debug-gem` flag.

Also fix the regex: `/\bgem\s+["']debug["']\s*(?:,|$)/`

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb`, lines 89–98

## Acceptance Criteria

- [ ] Generator exits non-zero when `debug` gem is absent from Gemfile
- [ ] Error message includes the exact gem line to add
- [ ] False-positive: `gem "debugger"` does not trigger the warning
- [ ] True positive: `gem "debug", require: "debug/prelude"` is correctly detected
- [ ] Test added for missing debug gem scenario

## Work Log

- 2026-03-17: Identified by agent-native-reviewer as P2, code-simplicity-reviewer noted regex false-positive
