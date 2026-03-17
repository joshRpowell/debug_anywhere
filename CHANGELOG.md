# Changelog

## [Unreleased]

## [0.1.0] - 2026-03-17

- Initial release
- `rails g debug_anywhere:install` generator
- Generates `.vscode/launch.json`, `bin/debug`, `docker-compose.yml`, `Dockerfile.dev`, debug controller, and route
- `--port` option (default: 12345)
- `--service` option (default: web)
- Idempotent: safe to run multiple times
- Security defaults: loopback-only port binding, single Puma worker, non-root Docker user, development-only route guard
