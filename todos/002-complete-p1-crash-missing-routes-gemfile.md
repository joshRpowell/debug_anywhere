---
status: pending
priority: p1
issue_id: "002"
tags: [code-review, reliability, error-handling]
dependencies: []
---

# 002 — Generator Crashes with Errno::ENOENT on Missing routes.rb or Gemfile

## Problem Statement

Two generator methods call `File.read` without first checking file existence, causing an unrescued `Errno::ENOENT` crash with no helpful message. Every other file access in the generator correctly guards with `File.exist?` first.

## Findings

**Location 1:** `lib/generators/debug_anywhere/install_generator.rb`, line 52 (inject_debug_route)
```ruby
routes_content = File.read(routes_path)  # no existence check
```
No existence check before reading `config/routes.rb`. API-only apps, engines, or non-standard project layouts may not have this file.

**Location 2:** `lib/generators/debug_anywhere/install_generator.rb`, line 90 (check_debug_gem)
```ruby
File.read(File.join(destination_root, "Gemfile")).match?(...)  # no existence check
```
No existence check before reading `Gemfile`.

## Proposed Solutions

### Option A: Add existence guards with graceful error messages (Recommended)
```ruby
# inject_debug_route
unless File.exist?(routes_path)
  say_status :error, "config/routes.rb not found — skipping route injection", :red
  return
end

# check_debug_gem
gemfile_path = File.join(destination_root, "Gemfile")
unless File.exist?(gemfile_path)
  say_status :warning, "Gemfile not found — cannot check for debug gem", :yellow
  return
end
```
- **Effort:** Small
- **Risk:** Low

### Option B: Wrap in rescue and re-raise with a helpful message
Less idiomatic for generators; Option A is preferred.

## Recommended Action

Option A — add `File.exist?` guards matching the pattern used in `create_dockerfile_dev` and `update_dockerignore`.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb`, lines 51–52 and 90

## Acceptance Criteria

- [ ] Running generator against a project without `config/routes.rb` prints a `say_status :error` and exits cleanly
- [ ] Running generator against a project without `Gemfile` prints a warning and continues
- [ ] No `Errno::ENOENT` raised in either case

## Work Log

- 2026-03-17: Identified by kieran-rails-reviewer
