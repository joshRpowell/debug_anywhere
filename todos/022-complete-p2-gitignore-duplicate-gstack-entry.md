---
status: pending
priority: p2
issue_id: "022"
tags: [code-review, quality]
dependencies: []
---

# 022 — .gitignore Has Duplicate Inconsistent .gstack/ Entry

## Problem Statement

PR #2 adds `.gstack/` (unrooted) to `.gitignore` when `/.gstack/` (rooted) was already added in commit `658ae7a`. The two forms are not equivalent — the unrooted form would match `.gstack/` directories anywhere in the subtree.

## Findings

File: `.gitignore`

```
/.gstack/     ← already present (commit 658ae7a)
.gstack/      ← added by PR #2 (unrooted — matches anywhere in tree)
```

The intent is clearly to exclude the local tooling directory at the repo root. The rooted form `/.gstack/` is correct and sufficient. The new unrooted entry is redundant and potentially too broad.

## Proposed Solutions

### Option A: Remove the duplicate (Recommended)
Delete the `.gstack/` line added in PR #2. The existing `/.gstack/` is correct and sufficient.

**Effort:** Trivial | **Risk:** None

## Recommended Action

Option A — remove the duplicate line.

## Technical Details

- **Affected files:** `.gitignore`

## Acceptance Criteria

- [ ] `.gitignore` contains only `/.gstack/` (rooted form), not both forms

## Work Log

- 2026-03-24: Identified by kieran-rails-reviewer agent during PR #2 review
