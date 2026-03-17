---
status: pending
priority: p2
issue_id: "009"
tags: [code-review, security, validation]
dependencies: ["003"]
---

# 009 — --port Option Not Validated for Safe Range or Shell-Safe Characters

## Problem Statement

The `--port` option uses Thor's `type: :numeric` which coerces to a number but does not enforce valid TCP port range (1024–65535). Invalid values like `0`, `-1`, or `99999` are interpolated into generated files silently. Additionally, port validation is necessary as a defense-in-depth measure against the `eval` injection issue in `bin_debug.tt` (todo 003).

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, lines 10, 128–130

```ruby
class_option :port, type: :numeric, default: 12345, desc: "rdbg TCP port"

def port
  options[:port]
end
```

Problems:
- Port `0` causes nc to spin indefinitely (Linux) or fail immediately (macOS)
- Port `-1` produces `127.0.0.1:-1:-1` in docker-compose — invalid
- Port `99999` is > 65535 — undefined behavior in Docker
- Privileged ports (< 1024) require root inside the container
- `type: :numeric` in Thor accepts floats — `12345.5` becomes `12345.5` in the template (identified by security-sentinel)

## Proposed Solutions

### Option A: Add validation in the port private method (Recommended)
```ruby
def port
  p = options[:port].to_i
  unless (1024..65535).include?(p)
    raise Thor::Error, "--port must be between 1024 and 65535 (got #{options[:port]})"
  end
  p
end
```

- **Effort:** Small
- **Risk:** Low

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb`, lines 128–130

## Acceptance Criteria

- [ ] Port 0 produces a clear error message and non-zero exit
- [ ] Port 99999 produces a clear error message and non-zero exit
- [ ] Port 12345 (default) works unchanged
- [ ] Port 19999 (used in existing tests) works unchanged
- [ ] Test added for invalid port range

## Work Log

- 2026-03-17: Identified by security-sentinel as P3-01, elevated to P2 because it is prerequisite for eval injection fix (todo 003)
