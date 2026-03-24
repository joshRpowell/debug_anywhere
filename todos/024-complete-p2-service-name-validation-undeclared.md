---
status: pending
priority: p2
issue_id: "024"
tags: [code-review, agent-native, documentation]
dependencies: []
---

# 024 — Service Name Validation Rule Not Declared in Interface

## Problem Statement

The generator enforces `/\A[a-zA-Z0-9][a-zA-Z0-9_.\-]{0,62}\z/` for `--service`, but nothing in the `class_option` desc, generator help, or README mentions this constraint. An agent passing a service name derived from user input (e.g., parsed from an existing `docker-compose.yml`) gets a `Thor::Error` with no prior indication the value was invalid.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`

```ruby
class_option :service, type: :string, default: "web", desc: "docker-compose service name"
# ...
def service
  s = options[:service]
  unless s.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_.\-]{0,62}\z/)
    raise Thor::Error, "--service '#{s}' is not a valid Docker Compose service name"
  end
  s
end
```

Also: the invalid service test in the PR (line 246) passes `"--service=invalid service!"` as one element, which splits on the space and may test a different failure path (unrecognised argument) rather than the regex validation.

## Proposed Solutions

### Option A: Update class_option desc
```ruby
class_option :service, type: :string, default: "web",
  desc: "docker-compose service name (alphanumeric, dots, underscores, hyphens; max 63 chars)"
```

**Effort:** Trivial | **Risk:** None

### Option B: Fix the test AND update the desc
Fix the test to use `"--service=invalid!"` (no space) to actually hit the regex path, and update the desc.

**Effort:** Small | **Risk:** None

## Recommended Action

Option B — fix both the undeclared constraint and the test that doesn't test what it claims.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb` line 11, `test/generators/debug_anywhere/install_generator_test.rb` line 246

## Acceptance Criteria

- [ ] `class_option :service` desc describes valid characters and max length
- [ ] Invalid service name test uses a value without spaces (e.g. `invalid!`) to hit the regex path
- [ ] `rails g debug_anywhere:install --help` shows the constraint

## Work Log

- 2026-03-24: Identified by kieran-rails-reviewer and agent-native-reviewer during PR #2 review
