# Changelog

## [Unreleased]

## [0.2.0] - 2026-03-19

### Added
- `rails g debug_anywhere:uninstall` generator — cleanly removes all generated files and reverts patches to `config/routes.rb` and `.dockerignore`
- `--editor` option (vscode, rubymine, zed, manual) — generates IDE-appropriate debug config; vscode/zed share `.vscode/launch.json`, rubymine generates `.idea/runConfigurations/debug_anywhere.xml`, manual skips IDE config
- `--runtime` option (docker, podman) — propagates to `bin/debug` compose command and post-install notes
- `--status` flag in generated `bin/debug` — checks debug port and web server without launching containers
- RubyMine run configuration template (`.idea/runConfigurations/debug_anywhere.xml`)
- GitHub Actions CI workflow testing Ruby 3.2, 3.3, 3.4, and 4.0

### Changed
- `required_ruby_version` bumped to `>= 3.2.0` (Ruby 3.1 reached end-of-life March 2025)
- Eager option validation in `check_debug_gem` — all options validated before any filesystem writes, preventing partial installs on invalid input

### Fixed
- Generator validation now fires before file creation, ensuring atomicity when invalid `--editor` or `--runtime` values are provided

## [0.1.0] - 2026-03-17

- Initial release
- `rails g debug_anywhere:install` generator
- Generates `.vscode/launch.json`, `bin/debug`, `docker-compose.yml`, `Dockerfile.dev`, debug controller, and route
- `--port` option (default: 12345)
- `--service` option (default: web)
- Idempotent: safe to run multiple times
- Security defaults: loopback-only port binding, single Puma worker, non-root Docker user, development-only route guard
