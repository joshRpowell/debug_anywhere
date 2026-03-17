---
status: pending
priority: p2
issue_id: "012"
tags: [code-review, security, docker]
dependencies: []
---

# 012 — Dockerfile.dev Runs bundle install as Root; Gems Are Root-Owned

## Problem Statement

The generated `Dockerfile.dev` runs `bundle install` as root (the default), then creates a non-root `rails` user and `chown -R rails:rails /rails`. This leaves gems installed to the system gem path (typically `/usr/local/bundle`) as root-owned. The `rails` user can read and execute gems but not modify them. This creates inconsistency with the non-root security intent and may cause issues with gems that write to their own directory at runtime.

## Findings

File: `lib/generators/debug_anywhere/templates/Dockerfile.dev.tt`

```dockerfile
RUN bundle install          # runs as root, gems → /usr/local/bundle (root-owned)
COPY . .

RUN groupadd --system --gid 1000 rails \
    && useradd --uid 1000 --gid 1000 --create-home rails \
    && chown -R rails:rails /rails  # only fixes /rails, not gem path
USER rails
```

The `chown -R rails:rails /rails` does not cover `/usr/local/bundle` where gems are installed.

## Proposed Solutions

### Option A: Set BUNDLE_PATH to /rails/vendor/bundle before bundle install (Recommended)
```dockerfile
ENV BUNDLE_PATH=/rails/vendor/bundle

COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN groupadd --system --gid 1000 rails \
    && useradd --uid 1000 --gid 1000 --create-home rails \
    && chown -R rails:rails /rails
USER rails
```

With `BUNDLE_PATH` pointing inside `/rails`, the `chown -R rails:rails /rails` covers gems too.

- **Pros:** Consistent ownership; aligns with Rails official image convention; vendor/bundle is gitignored by default
- **Cons:** Slightly larger Docker layer if bundle is not cached
- **Effort:** Small
- **Risk:** Low

### Option B: Add explicit chown for gem directory
```dockerfile
&& chown -R rails:rails /rails $(gem environment gemdir)
```
- **Pros:** Minimal change
- **Cons:** Fragile — depends on gem environment path not changing
- **Effort:** Small

## Recommended Action

Option A — use `BUNDLE_PATH=/rails/vendor/bundle`.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/templates/Dockerfile.dev.tt`

## Acceptance Criteria

- [ ] Generated Dockerfile sets BUNDLE_PATH
- [ ] `rails` user can read and execute all gems
- [ ] Docker build succeeds with updated Dockerfile
- [ ] Existing Dockerfile.dev test passes

## Work Log

- 2026-03-17: Identified by security-sentinel as P2-03
