---
status: pending
priority: p1
issue_id: "021"
tags: [code-review, security, testing]
dependencies: []
---

# 021 — Security Test for 0.0.0.0 Binding Hardcodes Port 12345

## Problem Statement

The tests that verify the debug port is never bound to `0.0.0.0` use hardcoded port `12345` in their regex patterns. A regression where the template produced `0.0.0.0:19999:19999` would not be caught by either security test.

**Why it matters:** Binding the debug port to `0.0.0.0` instead of `127.0.0.1` is the most critical security property the gem advertises. The test that validates this has a coverage gap that silently passes on a port-specific regression.

## Findings

File: `test/generators/debug_anywhere/install_generator_test.rb`, lines 211–217

```ruby
assert_no_match(/0\.0\.0\.0.*12345/, content)
assert_no_match(/12345.*0\.0\.0\.0/, content)
```

Both patterns match only port `12345`. The `--port` propagation test at lines 146–149 confirms `127.0.0.1:19999:19999` appears, but does not assert the absence of `0.0.0.0:19999:19999`. If the template were changed to `"0.0.0.0:<%= port %>:<%= port %>"`, these tests would still pass for the default port.

## Proposed Solutions

### Option A: Port-agnostic regex (Recommended)
Replace hardcoded port in security assertions with a pattern matching any port:

```ruby
assert_no_match(/0\.0\.0\.0:\d+:\d+/, content)
assert_no_match(/\d+:0\.0\.0\.0:\d+/, content)
```

**Pros:** Catches any port regression, minimal code change
**Effort:** Small | **Risk:** None

### Option B: Add custom-port variant of security test
Keep existing test, add a new test that runs with `--port=19999` and asserts no `0.0.0.0` binding:

```ruby
test "docker-compose.debug.yml never binds debug port to 0.0.0.0 with custom port" do
  run_generator ["--port=19999"]
  assert_file "docker-compose.debug.yml" do |content|
    assert_no_match(/0\.0\.0\.0/, content)
  end
end
```

**Pros:** Explicit, readable
**Effort:** Small | **Risk:** None

## Recommended Action

Option A — one-line fix, no test bloat.

## Technical Details

- **Affected files:** `test/generators/debug_anywhere/install_generator_test.rb` lines 211–217
- **Source of issue:** Tests written for the default port only

## Acceptance Criteria

- [ ] Security assertion regex does not contain a literal port number
- [ ] A run with `--port=19999` would be caught by the security test if `0.0.0.0` appears

## Work Log

- 2026-03-24: Identified by security-sentinel agent during PR #2 review
