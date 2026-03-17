---
status: pending
priority: p2
issue_id: "008"
tags: [code-review, quality, consistency]
dependencies: ["004"]
---

# 008 — DebugController Generated via Heredoc Instead of Template

## Problem Statement

`create_debug_controller` uses `create_file` with a Ruby heredoc to generate the debug controller. Every other generated Ruby/config file uses a `.tt` template. This breaks the established pattern, makes the controller harder to maintain, and prevents ERB variable use in the controller body.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, lines 65–76

```ruby
def create_debug_controller
  create_file "app/controllers/debug_controller.rb" do
    <<~RUBY
      class DebugController < ApplicationController
        def trigger
          binding.break
          render plain: "Resumed from breakpoint"
        end
      end
    RUBY
  end
end
```

Issues:
- Inconsistent with `create_bin_debug`, `create_vscode_launch_json`, `create_dockerfile_dev` which all use `template`
- Controller content can't be syntax-highlighted in editors that recognize `.tt` files
- Future changes to the controller require editing the generator class itself
- No ERB variable access (e.g., port in a comment, or a future `--controller` option)

## Proposed Solutions

### Option A: Extract to debug_controller.rb.tt template (Recommended)
Create `lib/generators/debug_anywhere/templates/debug_controller.rb.tt`:
```ruby
class DebugController < ApplicationController
  before_action :development_only!

  def trigger
    binding.break
    render plain: "Resumed from breakpoint"
  end

  private

  def development_only!
    head :forbidden unless Rails.env.development?
  end
end
```

Replace `create_file` with `template "debug_controller.rb.tt", "app/controllers/debug_controller.rb"`.

- **Effort:** Small
- **Risk:** Low

## Recommended Action

Option A. Combine with the `before_action` guard from todo 004 — do both in the same change.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb` lines 65–76; new file `lib/generators/debug_anywhere/templates/debug_controller.rb.tt`

## Acceptance Criteria

- [ ] `debug_controller.rb.tt` template exists and contains the controller source
- [ ] `create_debug_controller` uses `template` not `create_file`
- [ ] Existing test for controller content passes

## Work Log

- 2026-03-17: Identified by kieran-rails-reviewer as P2, confirmed by architecture-strategist
