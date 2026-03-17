---
status: pending
priority: p1
issue_id: "001"
tags: [code-review, reliability, architecture]
dependencies: []
---

# 001 — Multiline Regex in inject_into_docker_compose Silently Corrupts YAML

## Problem Statement

The `inject_into_docker_compose` method uses multiline regex patterns that will match the wrong service block in any real-world docker-compose file with multiple services, comments, or non-standard ordering. The generator exits 0 and appears to succeed while injecting env vars and port bindings into the wrong service — or producing invalid YAML.

**Why it matters:** This is the highest-risk code path in the gem. The only reason users install it is to get a working debug setup. Silent corruption means they get a broken compose file and no indication anything went wrong.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, lines 169 and 178

```ruby
after: /#{Regexp.escape(service)}:.*?\n(?:.*?\n)*?.*?environment:\n/m
after: /#{Regexp.escape(service)}:.*?\n(?:.*?\n)*?.*?ports:\n/m
```

- The `m` flag makes `.` match newlines; the `.*?` spans unbounded lines
- With a multi-service file, the regex overshoots the first service block and matches `environment:` in a different service
- Hardcoded 4-space and 6-space indentation assumptions break compose files using 2-space indent
- The existing test only checks that `RUBY_DEBUG_OPEN` appears somewhere in the file — not that it's in the correct service

Confirmed independently by: kieran-rails-reviewer, architecture-strategist, security-sentinel (ReDoS concern), code-simplicity-reviewer.

## Proposed Solutions

### Option A: Replace injection with docker-compose.debug.yml override (Recommended)
Generate a separate `docker-compose.debug.yml` file that Docker Compose merges via `-f` flag. Update `bin/debug` to pass both files. This is YAML-aware, idempotent by file existence, and never touches the user's main compose file.

- **Pros:** Eliminates all regex fragility; compose merge semantics are well-specified; main compose file stays clean; easier to document and reason about
- **Cons:** Requires users to understand Docker Compose file merging; `bin/debug` must pass `-f docker-compose.yml -f docker-compose.debug.yml`
- **Effort:** Medium
- **Risk:** Low (new file, no mutation)

### Option B: Replace regex with YAML-aware injection using Psych
Parse the compose file with `require "psych"`, mutate the Ruby hash, and write it back.

- **Pros:** Correct for any valid YAML structure; no indentation assumptions
- **Cons:** Loses comments; Psych round-trips may reformat user's file; adds complexity
- **Effort:** Medium
- **Risk:** Medium (reformats existing YAML)

### Option C: Replace multiline regex with line-by-line scan
Scan the file line by line, track service block boundaries by indentation, and inject at the correct offset.

- **Pros:** Preserves comments and formatting; no Psych dependency
- **Cons:** Fragile to edge cases; still custom YAML parsing
- **Effort:** Large
- **Risk:** Medium

## Recommended Action

Option A — docker-compose.debug.yml override. Eliminates the entire injection problem class.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb` (lines 145–183), `lib/generators/debug_anywhere/templates/bin_debug.tt`
- **New files needed:** `lib/generators/debug_anywhere/templates/docker-compose.debug.yml.tt`

## Acceptance Criteria

- [ ] Multi-service compose file: generator correctly targets only the specified service
- [ ] Compose file with non-standard indentation: generator produces valid YAML
- [ ] Generator is idempotent: running twice produces the same output
- [ ] `bin/debug` successfully starts containers using the new approach
- [ ] Existing tests pass; new multi-service fixture test added

## Work Log

- 2026-03-17: Identified by kieran-rails-reviewer, confirmed by architecture-strategist and security-sentinel
