---
status: pending
priority: p3
issue_id: "017"
tags: [code-review, quality, repo-hygiene]
dependencies: []
---

# 017 — ctags tags File Is Committed to Repo and Will Be Shipped in Gem

## Problem Statement

A `tags` file (ctags/etags index) is committed at the repository root. It is included in `spec.files` via `Dir["lib/**/*"]`... wait, it's at the root, not under lib. Check: `spec.files = Dir["lib/**/*", "LICENSE", "README.md", "CHANGELOG.md"]` — the root `tags` file is NOT in the gem package. But it is tracked in git and will appear in the repository, causing noise and diff churn every time symbols change.

## Findings

File: `~/src/tries/2026-03-17-debug-anywhere-gem/tags` — tracked in git, not in gemspec files glob

The ctags file regenerates every time a new symbol is added. Tracking it in git creates meaningless diffs on every commit. It should be gitignored.

## Proposed Solutions

### Option A: Add tags to .gitignore (Recommended)
Create or append `.gitignore`:
```
/tags
*.tags
```

Then `git rm --cached tags` to untrack the file.

- **Effort:** Small
- **Risk:** None

## Recommended Action

Option A.

## Acceptance Criteria

- [ ] `tags` is listed in `.gitignore`
- [ ] `tags` is removed from git tracking (`git rm --cached tags`)
- [ ] `git status` shows no modified tags file after ctags runs

## Work Log

- 2026-03-17: Identified by code-simplicity-reviewer
