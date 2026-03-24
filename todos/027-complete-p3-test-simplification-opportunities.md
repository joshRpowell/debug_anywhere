---
status: pending
priority: p3
issue_id: "027"
tags: [code-review, quality, testing]
dependencies: []
---

# 027 — ~119 LOC of Redundant or Over-Engineered Tests

## Problem Statement

The new tests in PR #2 contain meaningful duplication and over-specification that creates maintenance friction without adding coverage value. The simplicity reviewer estimated ~27% of the PR's additions could be removed.

## Findings

File: `test/generators/debug_anywhere/install_generator_test.rb`

Specific redundancies:

1. **Security section (lines 209–224)** — both assertions already exist in earlier tests (`0.0.0.0` at line 131, dev route at line 91). The section label adds no coverage.

2. **Structural "custom port" variants** — three tests (JSON 379–385, XML 406–413, YAML 433–441) parse the full document just to re-assert one value already confirmed by string-match tests in the basic section.

3. **Editor × runtime combination matrix (446–511)** — 6 tests covering all permutations of 3 editors × 2 runtimes. Individual option tests already establish each option works; only 2 representative cross-option tests are needed to verify orthogonality.

4. **Port 0 and -1 tests (537–543)** — subsumed by the port-below-1024 boundary test at line 238.

5. **"Gemfile with inline options" test (556–563)** — identical to the default fixture Gemfile already in `setup`.

6. **Pre-condition `assert_no_file` before `run_generator` (line 204)** — `prepare_destination` guarantees a clean state; the assertion is meaningless.

7. **Redundant idempotency test (lines 162–167)** — covered by the second-run test at lines 169–175.

File: `test/generators/debug_anywhere/uninstall_generator_test.rb`

8. **"skips route removal when route not present" (lines 104–110)** — subsumed by the full-absent-state test at lines 96–102.

## Proposed Solutions

### Option A: Targeted cleanup (Recommended)
Remove or merge the 8 specific redundancies listed above. Estimated reduction: ~119 LOC.

**Effort:** Medium | **Risk:** Low (no coverage lost)

### Option B: Leave as-is
The redundancy is harmless and the tests still pass. The extra coverage of "same thing from two angles" has mild value as documentation.

**Effort:** None | **Risk:** None

## Recommended Action

Option A — do the cleanup in a follow-up PR. No need to block PR #2 for this.

## Technical Details

- **Affected files:** `test/generators/debug_anywhere/install_generator_test.rb`, `test/generators/debug_anywhere/uninstall_generator_test.rb`

## Acceptance Criteria

- [ ] All 8 specific redundancies addressed
- [ ] Test count reduced by ~10–15 tests
- [ ] All remaining tests still pass

## Work Log

- 2026-03-24: Identified by code-simplicity-reviewer and kieran-rails-reviewer during PR #2 review
