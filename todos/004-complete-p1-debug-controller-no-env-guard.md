---
status: pending
priority: p1
issue_id: "004"
tags: [code-review, security, rails]
dependencies: []
---

# 004 — DebugController Has No Controller-Level Environment Guard

## Problem Statement

The generated `DebugController` relies solely on a routing-layer `if Rails.env.development?` guard. The controller itself has no environment check. This creates defense-in-depth failure: if the route guard is bypassed (merge conflict, manual route addition, routes.rb override), `binding.break` is reachable in any environment where the `debug` gem is loaded.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, lines 65–76

Generated controller:
```ruby
class DebugController < ApplicationController
  def trigger
    binding.break
    render plain: "Resumed from breakpoint"
  end
end
```

Generated route (routes.rb injection):
```ruby
if Rails.env.development?
  get "debug", to: "debug#trigger"
end
```

Three failure modes identified by security-sentinel:
1. A staging environment using `RAILS_ENV=development` (common Docker misconfiguration) bypasses the route guard entirely
2. A routes.rb merge conflict that loses the `if` block leaves the route permanently accessible
3. The controller file is committed to source control and shipped in production containers; there's no generated `.gitignore` or deploy-exclusion

## Proposed Solutions

### Option A: Add before_action to controller (Recommended)
```ruby
class DebugController < ApplicationController
  before_action :development_only!

  def trigger
    binding.break
    render plain: "Resumed from breakpoint — debugger detached"
  end

  private

  def development_only!
    head :forbidden unless Rails.env.development?
  end
end
```

- **Pros:** Defense in depth; explicit; survives route file corruption
- **Cons:** Slight duplication with the route guard (acceptable for security)
- **Effort:** Small
- **Risk:** Low

### Option B: Use a template file for the controller and add a comment warning
Extract to `debug_controller.rb.tt` (resolves kieran-rails-reviewer finding too) and add a prominent warning comment.
- **Effort:** Small
- **Risk:** Low

## Recommended Action

Option A — add `before_action` with environment guard. Combine with Option B by extracting to a template (see todo 008).

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb`, lines 65–76 (`create_debug_controller` method)

## Acceptance Criteria

- [ ] Generated controller has `before_action` that returns 403 outside development
- [ ] Test asserts that the before_action is present in generated controller
- [ ] Existing test that checks `binding.break` presence still passes

## Work Log

- 2026-03-17: Identified by security-sentinel as P1-02
