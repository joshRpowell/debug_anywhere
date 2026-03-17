---
status: pending
priority: p2
issue_id: "013"
tags: [code-review, security, validation]
dependencies: []
---

# 013 — --service Name Not Validated Against Docker Compose Identifier Rules

## Problem Statement

The `--service` option value is used in a regex pattern and injected as a YAML key without validation. While `Regexp.escape` prevents classic regex injection, an invalid service name (containing Unicode, spaces, or special characters) can cause catastrophic backtracking on large compose files or produce malformed YAML.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, lines 148, 169, 173

```ruby
unless content.include?("#{service}:")           # string interpolation
  after: /#{Regexp.escape(service)}:.*?\n/m       # into regex
  after: "  #{service}:\n"                        # into YAML key position
```

Docker Compose service names must match: `[a-zA-Z0-9][a-zA-Z0-9_.-]*` (max 63 chars).

Concerns (security-sentinel):
1. Very long service names with complex characters may cause ReDoS on the `(?:.*?\n)*?` regex
2. Service names with Unicode characters may confuse byte-level string matching
3. No feedback to the user if the service name is invalid Docker Compose syntax

## Proposed Solutions

### Option A: Validate --service at the start of patch_docker_compose (Recommended)
```ruby
def patch_docker_compose
  unless service.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_.\-]{0,62}\z/)
    raise Thor::Error, "--service '#{service}' is not a valid Docker Compose service name"
  end
  # ...
end
```

- **Effort:** Small
- **Risk:** Low

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb`, `patch_docker_compose` method

## Acceptance Criteria

- [ ] Service name with spaces produces a clear error
- [ ] Service name with special characters produces a clear error
- [ ] Default "web" and common names like "app", "web-1" pass validation
- [ ] Test added for invalid service names

## Work Log

- 2026-03-17: Identified by security-sentinel as P2-02
