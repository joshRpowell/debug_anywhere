---
status: pending
priority: p3
issue_id: "016"
tags: [code-review, reliability, docker]
dependencies: []
---

# 016 — Dockerfile.dev COPY Hardcodes .ruby-version; Fails Without It

## Problem Statement

The generated `Dockerfile.dev` always includes `.ruby-version` in the `COPY` instruction. If the project uses `.tool-versions` (asdf) or a global rbenv version instead, `docker build` fails with a cryptic `file not found` error. The generator already handles this gracefully with a `RUBY_VERSION` fallback — but the Dockerfile template doesn't.

## Findings

File: `lib/generators/debug_anywhere/templates/Dockerfile.dev.tt`, line 14

```dockerfile
COPY .ruby-version Gemfile Gemfile.lock ./
```

The `ruby_version` helper in the generator falls back to `RUBY_VERSION` when `.ruby-version` is absent (lines 137–143), so the `FROM ruby:X.Y.Z-slim` line is handled correctly. But the COPY instruction is static and will fail the build.

Note: The reference implementation docs (docs/solutions/devops-setup/rails-docker-rdbg-tcp-debug.md) document this as a known bug — `.ruby-version` is required for Rails 8 Gemfiles that use `ruby file: ".ruby-version"`.

## Proposed Solutions

### Option A: Conditional COPY in Dockerfile.dev.tt (Recommended)
```dockerfile
<% if File.exist?(File.join(destination_root, ".ruby-version")) %>
COPY .ruby-version Gemfile Gemfile.lock ./
<% else %>
COPY Gemfile Gemfile.lock ./
<% end %>
```

### Option B: Add a post-install warning when .ruby-version is absent
Keep the COPY as-is but warn the user in `create_dockerfile_dev` if `.ruby-version` is not found.

### Option C: Generate a .ruby-version file if absent
Create `.ruby-version` with the detected `RUBY_VERSION` content.
- **Pros:** Fully automated
- **Cons:** Creates a file the user didn't ask for

## Recommended Action

Option A — conditional COPY. The template already uses ERB via Thor so this is natural.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/templates/Dockerfile.dev.tt`

## Acceptance Criteria

- [ ] Generator with no `.ruby-version` produces a Dockerfile that builds successfully
- [ ] Generator with `.ruby-version` produces a Dockerfile that copies it before bundle install
- [ ] Existing test for `ruby version fallback when .ruby-version absent` passes
- [ ] New test for Dockerfile content when `.ruby-version` absent

## Work Log

- 2026-03-17: Identified by kieran-rails-reviewer (P3) and learnings-researcher (known bug from reference implementation)
