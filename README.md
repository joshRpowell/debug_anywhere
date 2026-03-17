# debug_anywhere

One-command rdbg remote debugging setup for Rails apps running in Docker with VS Code.

```bash
bundle add debug_anywhere --group development
rails g debug_anywhere:install
bin/debug
```

That's it. VS Code attaches to the debugger and pauses at the next `binding.break`.

## Installation

Add to your Gemfile:

```ruby
gem "debug_anywhere", group: :development
```

Run the generator:

```bash
rails g debug_anywhere:install
```

## What Gets Generated

```
create  .vscode/launch.json       VS Code rdbg attach configuration
create  bin/debug                 Orchestration script (chmod +x)
create  docker-compose.yml        Debug-ready compose config (if absent)
create  Dockerfile.dev            Development image (if absent)
insert  config/routes.rb          GET /debug route (development only)
create  app/controllers/debug_controller.rb
append  .dockerignore             Excludes .vscode/ from Docker build
```

## Usage

### Start a debug session

```bash
bin/debug
```

This starts Docker Compose, waits for the debugger socket and web server to be ready, triggers VS Code to attach, and opens the debug trigger URL in your browser.

### Trigger a breakpoint

Hit `GET /debug` in your browser (or let `bin/debug` open it for you). Execution pauses at `binding.break` in `DebugController#trigger`. VS Code shows the call stack, locals, and instance variables.

### Add breakpoints to your own code

```ruby
def my_action
  binding.break  # execution pauses here
  # ...
end
```

## Prerequisites

- Docker and `docker compose` CLI
- `nc` (netcat) — used by `bin/debug` for port readiness checks
- VS Code with the [ruby.vscode-rdbg](https://marketplace.visualstudio.com/items?itemName=KoichiSasada.vscode-rdbg) extension

  ```bash
  code --install-extension KoichiSasada.vscode-rdbg
  ```

- The `debug` gem in your Gemfile (included by default in Rails 7.1+):

  ```ruby
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  ```

## Options

| Option | Default | Description |
|---|---|---|
| `--port` | `12345` | rdbg TCP port |
| `--service` | `web` | docker-compose service name to target |

```bash
rails g debug_anywhere:install --port=19999 --service=app
```

## Security

All generated configuration is hardened by default:

- Debug port bound to `127.0.0.1` only — never exposed to external networks
- Web port bound to `127.0.0.1:3000:3000`
- `WEB_CONCURRENCY: "0"` — single Puma worker (required for reliable breakpoints)
- Non-root user in `Dockerfile.dev` (`rails`, uid 1000)
- Debug route guarded by `Rails.env.development?` — inaccessible in staging/production

**Never deploy `docker-compose.yml` with `RUBY_DEBUG_OPEN: "true"` to production.** The generated file includes a comment warning.

## web_console Integration

If the web console shows "not allowed at this IP" when accessed from Docker, add to `config/environments/development.rb`:

```ruby
config.web_console.permissions = "172.28.0.0/16"
```

This matches the pinned Docker subnet in the generated `docker-compose.yml`.

## How It Works

1. `docker-compose.yml` sets `RUBY_DEBUG_OPEN: "true"` — Rails boots with an rdbg TCP socket on port 12345
2. `RUBY_DEBUG_NONSTOP: "1"` prevents the process from blocking before VS Code attaches
3. `WEB_CONCURRENCY: "0"` forces a single Puma process — otherwise breakpoints could trigger on a different worker than the one VS Code attached to
4. `bin/debug` waits for the socket and `/up` health check, then fires `vscode://ruby.vscode-rdbg/attach` to connect VS Code
5. `binding.break` in `DebugController#trigger` pauses the request — VS Code shows the full call stack

## License

MIT
