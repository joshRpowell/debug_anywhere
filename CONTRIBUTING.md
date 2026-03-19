# Contributing to debug_anywhere

## Setup

```bash
git clone https://github.com/joshrpowell/debug_anywhere
cd debug_anywhere
bundle install
```

## Running tests

```bash
bundle exec ruby -Itest test/generators/debug_anywhere/install_generator_test.rb
```

## Adding a feature or fix

1. Fork the repo and create a branch from `main`.
2. Add tests — the test file is `test/generators/debug_anywhere/install_generator_test.rb`.
3. Make sure all tests pass before opening a PR.
4. Keep PRs focused — one feature or fix per PR.

## Reporting a bug

Open an issue describing:

- What you ran (`rails g debug_anywhere:install ...`)
- What you expected to happen
- What actually happened (include any error output)
- Ruby version, Rails version, Docker version

## Code style

- Follow the patterns already in `lib/generators/debug_anywhere/install_generator.rb`.
- Explicit over clever.
- New generator actions go in their own `def` — keep methods short and single-purpose.
- Validation belongs in private accessors, not in action methods.

## License

By contributing, you agree your code will be released under the [MIT License](LICENSE).
