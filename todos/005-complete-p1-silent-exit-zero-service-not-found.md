---
status: pending
priority: p1
issue_id: "005"
tags: [code-review, reliability, agent-native, error-handling]
dependencies: []
---

# 005 — Generator Exits 0 When Service Not Found in docker-compose.yml

## Problem Statement

When the `--service` name is not found in an existing `docker-compose.yml`, the generator prints an error via `say_status :error` and returns `nil` from `inject_into_docker_compose`. The outer `patch_docker_compose` method does not inspect this return value. The generator exits with code 0. Automated callers (CI, agents) see success when the critical docker-compose mutation was silently skipped.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, lines 148–153

```ruby
unless content.include?("#{service}:")
  say_status :error, "Service '#{service}' not found in #{compose_file}.", :red
  say "  Run with --service=<name> to specify the correct service."
  say "  Example: rails g debug_anywhere:install --service=app"
  return  # returns nil, but caller ignores return value
end
```

The outer `patch_docker_compose` method calls `inject_into_docker_compose` without checking its return value. `Rails::Generators::Base` does not propagate `return` as a non-zero exit. After this, all remaining generator steps continue executing — VS Code config is created, Dockerfile is generated, the route is injected — creating a partial install with no debug capability.

## Proposed Solutions

### Option A: Raise Thor::Error to produce non-zero exit (Recommended)
```ruby
raise Thor::Error, "Service '#{service}' not found in #{compose_file}. Run with --service=<name>."
```

- **Pros:** Non-zero exit code; CI and agents detect failure via `$?`; stops the generator before creating a partial install
- **Cons:** Aborts the entire generator — some files won't be created
- **Effort:** Small
- **Risk:** Low

### Option B: Track failure state and exit non-zero after all steps
Use an instance variable to track errors and raise at the end.
- **Pros:** All non-dependent files still created
- **Cons:** Leaves a partial install; more complex
- **Effort:** Medium

## Recommended Action

Option A — raise `Thor::Error`. A missing service makes the whole install non-functional; stopping early with a clear message is the right behavior.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb`, lines 148–153

## Acceptance Criteria

- [ ] `rails g debug_anywhere:install --service=nonexistent` exits with non-zero status
- [ ] Error message clearly tells the user which service was not found and how to fix it
- [ ] Test added for this case asserting non-zero exit or exception

## Work Log

- 2026-03-17: Identified by agent-native-reviewer as P1
