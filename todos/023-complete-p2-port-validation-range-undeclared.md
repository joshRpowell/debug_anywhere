---
status: pending
priority: p2
issue_id: "023"
tags: [code-review, agent-native, documentation]
dependencies: []
---

# 023 — Port Validation Range Not Declared in Machine-Readable Interface

## Problem Statement

The generator validates `--port` must be 1024–65535, but this constraint is invisible to callers — it lives only in the private `port` method. The `class_option` desc says only "rdbg TCP port". An agent or CI tool constructing the generator invocation cannot pre-validate the port and receives an opaque `Thor::Error` if the value is out of range.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`

```ruby
class_option :port, type: :numeric, default: 12345, desc: "rdbg TCP port"
# ...
def port
  p = options[:port].to_i
  unless (1024..65535).include?(p)
    raise Thor::Error, "--port must be between 1024 and 65535 (got #{options[:port].inspect})"
  end
  p
end
```

The range is tested (6 boundary tests in PR #2) but not surfaced in the declared interface.

## Proposed Solutions

### Option A: Update class_option desc (Recommended)
```ruby
class_option :port, type: :numeric, default: 12345,
  desc: "rdbg TCP port (1024–65535)"
```

**Effort:** Trivial | **Risk:** None

### Option B: Update class_option desc + README options table
Also update the README table to show the valid range.

**Effort:** Small | **Risk:** None

## Recommended Action

Option B — update both the option desc and README for full coverage.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb` line 10, `README.md` options table

## Acceptance Criteria

- [ ] `class_option :port` desc includes the valid range
- [ ] README options table shows the valid range for `--port`
- [ ] `rails g debug_anywhere:install --help` output shows the range

## Work Log

- 2026-03-24: Identified by agent-native-reviewer during PR #2 review
