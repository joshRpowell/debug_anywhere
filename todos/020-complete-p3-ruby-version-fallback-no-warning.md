---
status: pending
priority: p3
issue_id: "020"
tags: [code-review, quality, ux]
dependencies: []
---

# 020 — ruby_version Fallback to Host RUBY_VERSION Has No Warning

## Problem Statement

When `.ruby-version` is absent, the `ruby_version` helper returns `RUBY_VERSION` (the Ruby version running the generator). In a CI or development environment where the generator runs under a different Ruby version than the app's target, the generated `Dockerfile.dev` will silently use the wrong base image. The generator provides no indication that a fallback occurred.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, lines 136–143

```ruby
def ruby_version
  ruby_version_path = File.join(destination_root, ".ruby-version")
  if File.exist?(ruby_version_path)
    File.read(ruby_version_path).strip
  else
    RUBY_VERSION  # silently uses host Ruby version
  end
end
```

Also: the `.ruby-version` content is not validated — it is interpolated directly into `FROM ruby:<value>-slim`. A `.ruby-version` file containing a newline or non-version string would produce a malformed Dockerfile (security-sentinel P3-02).

## Proposed Solutions

### Option A: Add warning when falling back + validate version format
```ruby
def ruby_version
  ruby_version_path = File.join(destination_root, ".ruby-version")
  if File.exist?(ruby_version_path)
    version = File.read(ruby_version_path).strip
    unless version.match?(/\A\d+\.\d+\.\d+\z/)
      raise Thor::Error, ".ruby-version contains an unexpected value: #{version.inspect}"
    end
    version
  else
    say_status :warning, ".ruby-version not found — using host Ruby #{RUBY_VERSION} for Dockerfile.dev", :yellow
    RUBY_VERSION
  end
end
```

- **Effort:** Small
- **Risk:** Low

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb`, lines 136–143

## Acceptance Criteria

- [ ] Warning is printed when `.ruby-version` is absent
- [ ] `.ruby-version` with non-semver content produces a clear error
- [ ] Existing test for RUBY_VERSION fallback passes (may need to expect warning output)

## Work Log

- 2026-03-17: Identified by security-sentinel (P3-02) and agent-native-reviewer (P3-08)
