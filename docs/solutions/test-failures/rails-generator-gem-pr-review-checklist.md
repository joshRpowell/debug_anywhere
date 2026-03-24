---
title: "Rails generator gem PR review checklist: test authoring, option contracts, and dependency hygiene"
category: test-failures
date: 2026-03-24
tags:
  - rails-generators
  - thor
  - test-coverage
  - security
  - dependency-pinning
  - code-review
  - rdbg
components:
  - install_generator
  - uninstall_generator
  - debug_anywhere.gemspec
  - README
symptoms:
  - "Security assertions hardcoded to a default value pass silently when other valid values produce the dangerous pattern"
  - "class_option desc omits validation rule; callers cannot discover valid input ranges without reading source"
  - "Test passes space-split CLI arg hitting Thor's argument parser instead of the validator under test"
  - "Redundant assert_no_file pre-conditions that prepare_destination already guarantees"
  - "Dev dependency added without version floor despite known CVE history in older releases"
  - "Generator help text and README options table don't reflect full option set"
---

# Rails Generator Gem PR Review Checklist

Patterns identified while reviewing PR #2 of the debug_anywhere gem — a test coverage expansion
that added structural validation, edge case testing, and a new `rexml` development dependency.
Eight issues were found across security, test authoring, option documentation, and dependency
hygiene. All were resolved before merge.

---

## Root Cause

Three categories of gaps introduced during feature expansion:

**1. Test pattern fragility** — security tests written against specific default values rather than
structural patterns; a related test hit the wrong failure path because a space in a CLI argument
caused Thor to parse it as two separate tokens.

**2. Dependency declaration gaps** — a development dependency (`rexml`) added without a version
floor, leaving the gemspec exposed to known CVEs in older releases.

**3. Option contract under-specification** — `class_option` `desc` strings documented *what* an
option was, not *what values it accepts*. This hides constraints from callers (human or automated)
who cannot discover valid ranges or formats without reading source code.

---

## Working Solutions

### Fix 1: Security test — use structural pattern, not default value

Security assertions must use patterns that work for all valid option values, not just the default.

```ruby
# ❌ Before — fragile, tied to default port 12345
assert_no_match /0\.0\.0\.0.*12345/, content

# ✅ After — validates the dangerous binding format for any valid port
assert_no_match /0\.0\.0\.0:\d+:\d+/, content
assert_no_match /\d+:0\.0\.0\.0:\d+/, content
```

**Rule:** Any `assert_no_match` testing a security property must not embed a default value in the
pattern. Use `\d+` or a structural anchor that is port-agnostic.

---

### Fix 2: Version floor on development dependency with CVE history

```ruby
# ❌ Before — no version constraint
spec.add_development_dependency "rexml"

# ✅ After — excludes versions with known DoS CVEs
spec.add_development_dependency "rexml", ">= 3.4.1"
```

**CVEs addressed:** CVE-2024-41123 (3.3.2), CVE-2024-41946 (3.3.6), CVE-2024-49761 (3.3.9),
CVE-2025-27221 (3.4.1). Even though `rexml` is used only in tests (not at runtime), an
unpinned gemspec allows `bundle install` to resolve a vulnerable version on a fresh machine.

---

### Fix 3: Declare constraints in class_option desc strings

```ruby
# ❌ Before — describes the option, omits its contract
class_option :port,    desc: "rdbg TCP port"
class_option :service, desc: "docker-compose service name"

# ✅ After — callers can discover valid values without reading source
class_option :port,    desc: "rdbg TCP port (1024–65535)"
class_option :service, desc: "docker-compose service name (alphanumeric, dots, underscores, hyphens; max 63 chars)"
```

This matters for both human users running `--help` and for agents constructing generator
invocations programmatically. The constraint in `:desc` must stay in sync with the validator.

---

### Fix 4: CLI arg in test — space causes wrong failure path

```ruby
# ❌ Before — space causes Thor to treat "service!" as a separate unrecognised argument;
# the regex validator under test is never reached
run_generator ["--service=invalid service!"]

# ✅ After — single token, hits the intended validation path
run_generator ["--service=invalid!"]
```

**Rule:** Never embed a space inside a single `"--option=value"` array element when the intent
is to test the option's validator. Use a value that is invalid per the validator's own rules.

---

### Fix 5: Remove redundant pre-condition assertions

```ruby
# ❌ Before — assert_no_file before run_generator is a no-op;
# prepare_destination already guarantees a clean state
assert_no_file ".dockerignore"
run_generator [...]
assert_no_file ".dockerignore"

# ✅ After — remove the pre-condition
run_generator [...]
assert_no_file ".dockerignore"
```

`Rails::Generators::TestCase#prepare_destination` wipes the destination root before every test.
Any `assert_no_file` call placed before `run_generator` with no intervening file creation is
guaranteed to pass and provides zero coverage signal.

---

## Prevention Checklists

### Writing tests for generators with validated options

- [ ] Every option under test is passed explicitly — never rely on a default value to stand in for the value being asserted
- [ ] CLI string arguments are split into discrete array elements (`["--flag", "value"]`), not embedded with spaces in a single element
- [ ] `assert_no_file` before `run_generator` is removed unless the test itself created the file earlier
- [ ] Negative-path tests assert the behavior produced by the *intended* validator, not a side-effect that could pass for unrelated reasons
- [ ] Security-sensitive assertions use structural patterns (`\d+`, `\w+`) not hardcoded defaults

### Adding new gem dependencies

- [ ] Check the gem's CVE history on [rubysec/ruby-advisory-db](https://github.com/rubysec/ruby-advisory-db) before adding
- [ ] If any CVEs exist, pin a minimum version post-dating the most recent one
- [ ] Run `bundle audit` after adding and confirm clean output
- [ ] If the API is unstable across major versions, add an upper-bound constraint and comment the reason

### Documenting Thor options

- [ ] Every `class_option` `:desc` states the full valid range, format, or allowlist
- [ ] The `:desc` allowlist matches the runtime validator exactly — treat them as a single source of truth
- [ ] Run `thor help <generator>` after any option change and confirm output matches behavior
- [ ] Generator's top-level `desc` string reflects all supported values for each option

### Code review triggers for these patterns

| Pattern | What to look for |
|---|---|
| Security assertion | Does the pattern contain a hardcoded default value? |
| New dev dependency | Does the gemspec line have a version constraint? |
| Thor class_option | Does `:desc` include valid range/format/allowlist? |
| Invalid-value test | Does the CLI arg contain a space inside `"--opt=value"`? |
| Pre-condition assertion | Is `assert_no_file` called before `run_generator` with no setup? |
| Generator help text | Does the top-level `desc` list all supported option values? |

---

## Related Files

- `lib/generators/debug_anywhere/install_generator.rb` — class_option declarations and validators
- `test/generators/debug_anywhere/install_generator_test.rb` — all fixes applied here
- `debug_anywhere.gemspec` — rexml version floor
- `README.md` — --editor=manual documentation, port range in options table
