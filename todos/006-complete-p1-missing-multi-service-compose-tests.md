---
status: pending
priority: p1
issue_id: "006"
tags: [code-review, testing, reliability]
dependencies: ["001"]
---

# 006 — No Tests for Multi-Service docker-compose.yml Injection

## Problem Statement

The `inject_into_docker_compose` method is the most failure-prone code in the generator, but the test suite only covers single-service compose files. The one existing service test (`--service option injects into named service`) creates a compose file where the target service is the only service and only asserts that `RUBY_DEBUG_OPEN` appears somewhere in the file — not that it appears under the correct service.

## Findings

File: `test/generators/debug_anywhere/install_generator_test.rb`, lines 204–216

The test fixture:
```yaml
services:
  app:
    image: myapp
    ports:
      - "3000:3000"
```

Only one service, no `environment:` block. This never exercises the multiline regex's multi-service failure mode.

Missing test cases (identified by architecture-strategist):
1. Multi-service file where target service is second (after another service with `environment:`)
2. Multi-service file where another service has `environment:` but the target does not
3. Multi-service file with non-standard (2-space) indentation
4. File where target service already has `ports:` — verify injection goes to correct service, not first ports: block in file

## Proposed Solutions

### Option A: Add missing fixture tests (Do immediately)
Add test cases with multi-service fixtures before or alongside fixing the injection regex. This documents the failure mode clearly and provides regression coverage.

### Option B: Add tests as part of Option A from todo 001
If the injection approach is replaced with docker-compose.debug.yml override (todo 001), these tests become unnecessary. Add them as part of the same PR to document the old behavior before removing the code.

## Recommended Action

Option A — add tests now. They document the existing bug and provide regression coverage regardless of which injection fix approach is chosen.

## Technical Details

- **Affected files:** `test/generators/debug_anywhere/install_generator_test.rb`

## Acceptance Criteria

- [ ] Test fixture with 2 services where target is second
- [ ] Test asserts injection goes into the CORRECT service block (not just anywhere in file)
- [ ] Test with existing `ports:` in target service
- [ ] All new tests pass (or are marked pending if documenting a known failure)

## Work Log

- 2026-03-17: Identified by architecture-strategist as P1 test gap
