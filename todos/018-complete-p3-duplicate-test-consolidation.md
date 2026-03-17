---
status: pending
priority: p3
issue_id: "018"
tags: [code-review, testing, quality]
dependencies: []
---

# 018 — Duplicate and Over-Split Tests Waste Generator Runs

## Problem Statement

The test suite has two instances of test redundancy that each invoke `run_generator` unnecessarily:

1. The security test at line 187 (`docker-compose.yml never binds debug port to 0.0.0.0`) duplicates an assertion already in the docker-compose creation test at line 101
2. The `--port` option tests (lines 107–128) run `run_generator ["--port=19999"]` three separate times to verify the port propagates to three different files

Each `run_generator` call is a full generator run. Consolidation reduces test time and maintenance surface.

## Findings

File: `test/generators/debug_anywhere/install_generator_test.rb`

**Duplication 1:** Lines 187–193 — `assert_no_match(/0\.0\.0\.0.*12345/, content)` already appears at line 101 inside "creates docker-compose.yml when absent"

**Duplication 2:** Lines 107–128 — three separate tests, each calling `run_generator ["--port=19999"]`:
- `--port option propagates to launch.json` (line 107)
- `--port option propagates to bin/debug` (line 114)
- `--port option propagates to docker-compose.yml` (line 122)

These could be one test with three assertions.

## Proposed Solutions

### Option A: Consolidate duplicates
- Delete the standalone security test; move its `assert_no_match` into the docker-compose creation test
- Combine the three `--port` tests into one test with three file assertions

- **Effort:** Small
- **Risk:** Low

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `test/generators/debug_anywhere/install_generator_test.rb`, lines 107–128, 187–193

## Acceptance Criteria

- [ ] Test count reduced by 3 (2 port tests merged, 1 security test merged)
- [ ] All assertions from merged tests are preserved
- [ ] `rails test` passes with no failures

## Work Log

- 2026-03-17: Identified by code-simplicity-reviewer as P2/P3
