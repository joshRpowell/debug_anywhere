---
status: pending
priority: p2
issue_id: "025"
tags: [code-review, security, dependencies]
dependencies: []
---

# 025 — rexml Dev Dependency Has No Lower-Bound Version Constraint

## Problem Statement

`rexml` is added as a dev dependency with no version constraint. REXML has a documented history of DoS CVEs fixed in recent minor versions. Without a floor, `bundle install` on a fresh machine could resolve to a vulnerable version.

## Findings

File: `debug_anywhere.gemspec` line 37

```ruby
spec.add_development_dependency "rexml"
```

Known CVEs in older REXML versions:
- CVE-2024-41123 (fixed in 3.3.2) — entity expansion DoS
- CVE-2024-41946 (fixed in 3.3.6) — entity expansion DoS
- CVE-2024-49761 (fixed in 3.3.9) — regex DoS via XPath engine
- CVE-2025-27221 (fixed in 3.4.1) — string manipulation in URI handling

The locked version in `Gemfile.lock` (3.4.4) is safe, but the gemspec provides no floor for consumers.

**Risk is test-only:** REXML is used only to parse the generator's own output in tests — never to process untrusted input at runtime. This limits blast radius to the development environment.

## Proposed Solutions

### Option A: Add minimum version covering all known CVEs
```ruby
spec.add_development_dependency "rexml", ">= 3.4.1"
```

**Effort:** Trivial | **Risk:** None

### Option B: Pin to current series
```ruby
spec.add_development_dependency "rexml", "~> 3.3"
```

Allows 3.3.x and 3.4.x but not 4.x. Combined with `>= 3.3.9` as a floor:
```ruby
spec.add_development_dependency "rexml", "~> 3.3", ">= 3.3.9"
```

**Effort:** Trivial | **Risk:** None

## Recommended Action

Option A — `">= 3.4.1"` covers all known CVEs and is the simplest floor.

## Technical Details

- **Affected files:** `debug_anywhere.gemspec` line 37

## Acceptance Criteria

- [ ] `rexml` dev dependency has an explicit minimum version `>= 3.4.1`
- [ ] `bundle install` on a fresh clone resolves to a version post-dating all known CVEs

## Work Log

- 2026-03-24: Identified by security-sentinel and agent-native-reviewer during PR #2 review
