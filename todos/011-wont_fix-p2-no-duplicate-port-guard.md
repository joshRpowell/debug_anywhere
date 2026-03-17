---
status: pending
priority: p2
issue_id: "011"
tags: [code-review, reliability]
dependencies: ["001"]
---

# 011 — No Idempotency Guard on Port Entry Injection in docker-compose.yml

## Problem Statement

The environment block injection in `inject_into_docker_compose` has an idempotency guard (checks for `RUBY_DEBUG_OPEN`), but the port entry injection has no equivalent guard. Running the generator twice — or having a port entry in another service — can produce duplicate port bindings that make Docker Compose fail to start with `address already in use`.

## Findings

File: `lib/generators/debug_anywhere/install_generator.rb`, lines 176–183

```ruby
if content.include?("ports:")
  inject_into_file compose_file, port_entry,
    after: /#{Regexp.escape(service)}:.*?\n(?:.*?\n)*?.*?ports:\n/m
else
  inject_into_file compose_file,
    "    ports:\n#{port_entry}",
    after: "  #{service}:\n"
end
```

No check equivalent to the `RUBY_DEBUG_OPEN` check on line 27:
```ruby
return if File.read(compose_path).include?("RUBY_DEBUG_OPEN")  # skips everything
```

The idempotency guard skips the entire method — but if somehow reached past that guard (e.g., env vars added manually), the port injection would duplicate.

Note: This finding is dependent on todo 001 (replace injection approach). If docker-compose.debug.yml override is adopted, this issue disappears.

## Proposed Solutions

### Option A: Add port idempotency check (if injection approach is kept)
```ruby
port_binding = "127.0.0.1:#{port}:#{port}"
unless content.include?(port_binding)
  # inject port entry
end
```

### Option B: Resolve via todo 001
If injection is replaced with a separate docker-compose.debug.yml, this entire method is deleted.

## Recommended Action

Option B — depend on todo 001 resolution. If docker-compose.debug.yml is adopted, close this todo. If injection approach is kept, implement Option A.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/install_generator.rb`, lines 176–183

## Acceptance Criteria

- [ ] Running the generator twice does not produce duplicate port entries
- [ ] Existing idempotency tests pass
- [ ] `docker compose up` succeeds after second generator run

## Work Log

- 2026-03-17: Identified by kieran-rails-reviewer as P2
