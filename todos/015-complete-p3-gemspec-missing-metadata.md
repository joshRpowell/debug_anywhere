---
status: pending
priority: p3
issue_id: "015"
tags: [code-review, quality, gemspec]
dependencies: []
---

# 015 — Gemspec Missing metadata, MFA Requirement, and railties Dependency Type

## Problem Statement

The gemspec lacks `spec.metadata` (source_code_uri, changelog_uri, rubygems_mfa_required), which is now expected for new gems publishing to RubyGems.org. Additionally, `railties` is declared as a runtime dependency when it should be a development dependency for a generator-only gem.

## Findings

File: `debug_anywhere.gemspec`

Missing:
```ruby
spec.metadata = {
  "source_code_uri"       => spec.homepage,
  "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
  "rubygems_mfa_required" => "true"
}
```

Current dependency:
```ruby
spec.add_dependency "railties", ">= 7.0"
```

`railties` is always present in Rails apps (the generator's only valid target), but declaring it as a runtime dependency means installing `debug_anywhere` in a non-Rails project pulls in all of railties. Change to `add_development_dependency`.

Also: `spec.email = []` — empty email is fine, but unusual. Consider adding or removing the field.

## Proposed Solutions

### Option A: Add metadata and fix dependency type
Add `spec.metadata` hash with the three keys. Change `add_dependency "railties"` to `add_development_dependency "railties"`.

- **Effort:** Small
- **Risk:** Low

## Recommended Action

Option A.

## Acceptance Criteria

- [ ] `spec.metadata["rubygems_mfa_required"] = "true"` present
- [ ] `spec.metadata["source_code_uri"]` and `changelog_uri` present
- [ ] `railties` declared as `add_development_dependency`
- [ ] `gem build debug_anywhere.gemspec` succeeds with no warnings

## Work Log

- 2026-03-17: Identified by kieran-rails-reviewer (P3) and security-sentinel (P3-06)
