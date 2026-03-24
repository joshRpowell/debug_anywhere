require "test_helper"
require "json"
require "yaml"
require "rexml/document"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests DebugAnywhere::Generators::InstallGenerator
  destination File.expand_path("../../../tmp/test_app", __dir__)

  setup do
    prepare_destination

    # Minimal Rails app skeleton in destination
    FileUtils.mkdir_p "#{destination_root}/config"
    FileUtils.mkdir_p "#{destination_root}/app/controllers"
    FileUtils.mkdir_p "#{destination_root}/bin"

    File.write "#{destination_root}/config/routes.rb", <<~RUBY
      Rails.application.routes.draw do
      end
    RUBY

    File.write "#{destination_root}/Gemfile", <<~RUBY
      source "https://rubygems.org"
      gem "rails", "~> 8.1"
      gem "debug", platforms: %i[mri windows], require: "debug/prelude"
    RUBY

    File.write "#{destination_root}/.ruby-version", "3.4.7"
  end

  # ─── Fresh install ──────────────────────────────────────────────────────────

  test "creates .vscode/launch.json with default port" do
    run_generator
    assert_file ".vscode/launch.json" do |content|
      assert_match %("debugPort": "localhost:12345"), content
      assert_match %("localfsMap": "/rails:${workspaceFolder}"), content
      assert_match %("request": "attach"), content
    end
  end

  test "creates bin/debug with default port" do
    run_generator
    assert_file "bin/debug" do |content|
      assert_match "wait_for_port 12345", content
      assert_match "vscode://ruby.vscode-rdbg/attach?port=12345", content
      assert_match "set -euo pipefail", content
    end
  end

  test "bin/debug is executable" do
    run_generator
    assert File.executable?("#{destination_root}/bin/debug"),
      "bin/debug should be executable"
  end

  test "creates Dockerfile.dev with ruby version from .ruby-version" do
    run_generator
    assert_file "Dockerfile.dev" do |content|
      assert_match "FROM ruby:3.4.7-slim", content
      assert_match "WORKDIR /rails", content
      assert_match "COPY Gemfile Gemfile.lock ./", content
      assert_match "COPY .ruby-version ./", content
      assert_match "groupadd --system --gid 1000 rails", content
      assert_match "chown -R rails:rails /rails /usr/local/bundle", content
      assert_no_match(/BUNDLE_PATH=\/rails/, content)
      assert_match "USER rails", content
    end
  end

  test "creates Dockerfile.dev when .ruby-version uses rbenv ruby- prefix" do
    File.write "#{destination_root}/.ruby-version", "ruby-3.4.7"
    run_generator
    assert_file "Dockerfile.dev" do |content|
      assert_match "FROM ruby:3.4.7-slim", content
    end
  end

  test "creates Dockerfile.dev using RUBY_VERSION fallback when .ruby-version absent" do
    File.delete "#{destination_root}/.ruby-version"
    run_generator
    assert_file "Dockerfile.dev" do |content|
      assert_match(/FROM ruby:\d+\.\d+\.\d+-slim/, content)
    end
  end

  test "injects debug route into config/routes.rb" do
    run_generator
    assert_file "config/routes.rb" do |content|
      assert_match 'if Rails.env.development?', content
      assert_match 'get "debug", to: "debug#trigger"', content
    end
  end

  test "creates debug controller" do
    run_generator
    assert_file "app/controllers/debug_controller.rb" do |content|
      assert_match "binding.break", content
      assert_match 'render plain: "Resumed from breakpoint"', content
    end
  end

  test "creates debug controller with development environment guard" do
    run_generator
    assert_file "app/controllers/debug_controller.rb" do |content|
      assert_match "before_action :development_only!", content
      assert_match "head :forbidden unless Rails.env.development?", content
      assert_match "binding.break", content
    end
  end

  test "creates docker-compose.yml when absent" do
    run_generator
    assert_file "docker-compose.yml" do |content|
      assert_no_match(/RUBY_DEBUG_OPEN/, content)
      assert_match "127.0.0.1:3000:3000", content
      assert_match "RAILS_ENV: development", content
    end
  end

  test "creates docker-compose.debug.yml" do
    run_generator
    assert_file "docker-compose.debug.yml" do |content|
      assert_match 'RUBY_DEBUG_OPEN: "true"', content
      assert_match 'RUBY_DEBUG_HOST: "127.0.0.1"', content
      assert_match 'RUBY_DEBUG_PORT: "12345"', content
      assert_match 'RUBY_DEBUG_NONSTOP: "1"', content
      assert_match 'WEB_CONCURRENCY: "0"', content
      assert_match "127.0.0.1:12345:12345", content
      assert_no_match(/0\.0\.0\.0.*12345/, content)
    end
  end

  # ─── --port option ──────────────────────────────────────────────────────────

  test "--port option propagates to all generated files" do
    run_generator ["--port=19999"]
    assert_file ".vscode/launch.json" do |content|
      assert_match %("debugPort": "localhost:19999"), content
    end
    assert_file "bin/debug" do |content|
      assert_match "wait_for_port 19999", content
      assert_match "vscode://ruby.vscode-rdbg/attach?port=19999", content
    end
    assert_file "docker-compose.debug.yml" do |content|
      assert_match "127.0.0.1:19999:19999", content
      assert_match 'RUBY_DEBUG_PORT: "19999"', content
    end
  end

  # ─── Idempotency ────────────────────────────────────────────────────────────

  test "running generator twice does not duplicate routes" do
    run_generator
    run_generator ["--skip"]  # skip file conflicts
    content = File.read("#{destination_root}/config/routes.rb")
    occurrences = content.scan('get "debug", to: "debug#trigger"').size
    assert_equal 1, occurrences, "Route should appear exactly once after two generator runs"
  end

  test "skips docker-compose.debug.yml when already exists" do
    File.write "#{destination_root}/docker-compose.debug.yml", "# existing\n"
    run_generator
    content = File.read("#{destination_root}/docker-compose.debug.yml")
    assert_equal "# existing\n", content
  end

  test "running generator twice skips existing docker-compose.debug.yml" do
    run_generator
    original = File.read("#{destination_root}/docker-compose.debug.yml")
    run_generator ["--skip"]
    assert_equal original, File.read("#{destination_root}/docker-compose.debug.yml"),
      "docker-compose.debug.yml should not be modified on second run"
  end

  # ─── Conflict handling ──────────────────────────────────────────────────────

  test "skips Dockerfile.dev creation when file already exists" do
    original_content = "FROM ruby:3.2.0-slim\n# custom existing dockerfile\n"
    File.write "#{destination_root}/Dockerfile.dev", original_content
    run_generator ["--skip"]
    assert_file "Dockerfile.dev" do |content|
      assert_equal original_content, content, "Existing Dockerfile.dev should not be overwritten"
    end
  end

  test "appends .vscode/ to .dockerignore when it exists without the entry" do
    File.write "#{destination_root}/.dockerignore", ".git\n.bundle\n"
    run_generator
    assert_file ".dockerignore" do |content|
      assert_match "/.vscode/", content
    end
  end

  test "does not duplicate .vscode/ in .dockerignore" do
    File.write "#{destination_root}/.dockerignore", ".git\n/.vscode/\n"
    run_generator
    content = File.read("#{destination_root}/.dockerignore")
    assert_equal 1, content.scan("/.vscode/").size
  end

  test "does not modify .dockerignore when file is absent" do
    assert_no_file ".dockerignore"
    run_generator
    assert_no_file ".dockerignore"
  end

  # ─── Security ────────────────────────────────────────────────────────────────

  test "docker-compose.debug.yml never binds debug port to 0.0.0.0" do
    run_generator
    assert_file "docker-compose.debug.yml" do |content|
      assert_no_match(/0\.0\.0\.0.*12345/, content)
      assert_no_match(/12345.*0\.0\.0\.0/, content)
    end
  end

  test "debug route is guarded by Rails.env.development?" do
    run_generator
    assert_file "config/routes.rb" do |content|
      assert_match "Rails.env.development?", content
    end
  end

  # ─── --service option ───────────────────────────────────────────────────────

  test "--service option generates docker-compose.debug.yml targeting named service" do
    run_generator ["--service=app"]
    assert_file "docker-compose.debug.yml" do |content|
      assert_match "app:", content
      assert_match "RUBY_DEBUG_OPEN", content
    end
  end

  # ─── Validation ─────────────────────────────────────────────────────────────

  test "raises error for port below 1024" do
    assert_raises(Thor::Error) { run_generator ["--port=80"], debug: true }
  end

  test "raises error for port above 65535" do
    assert_raises(Thor::Error) { run_generator ["--port=99999"], debug: true }
  end

  test "raises error for invalid service name" do
    assert_raises(Thor::Error) { run_generator ["--service=invalid service!"], debug: true }
  end

  test "raises error when debug gem is not in Gemfile" do
    File.write "#{destination_root}/Gemfile", <<~RUBY
      source "https://rubygems.org"
      gem "rails", "~> 8.1"
    RUBY
    assert_raises(Thor::Error) { run_generator [], debug: true }
  end

  test "raises error for invalid .ruby-version format" do
    File.write "#{destination_root}/.ruby-version", "jruby-9.4"
    assert_raises(Thor::Error) { run_generator [], debug: true }
  end

  test "skips route injection when config/routes.rb is absent" do
    File.delete "#{destination_root}/config/routes.rb"
    run_generator
    assert_no_file "config/routes.rb"
  end

  # ─── --editor option ────────────────────────────────────────────────────────

  test "--editor=vscode creates .vscode/launch.json (default)" do
    run_generator ["--editor=vscode"]
    assert_file ".vscode/launch.json"
    assert_no_file ".idea/runConfigurations/debug_anywhere.xml"
  end

  test "--editor=zed creates .vscode/launch.json (Zed reads VS Code format)" do
    run_generator ["--editor=zed"]
    assert_file ".vscode/launch.json"
    assert_no_file ".idea/runConfigurations/debug_anywhere.xml"
  end

  test "--editor=rubymine creates RubyMine run configuration" do
    run_generator ["--editor=rubymine"]
    assert_file ".idea/runConfigurations/debug_anywhere.xml" do |content|
      assert_match "Attach to Rails in Docker", content
      assert_match "REMOTE_PORT", content
      assert_match "12345", content
      assert_match "/rails", content
    end
    assert_no_file ".vscode/launch.json"
  end

  test "--editor=rubymine with custom port sets correct port in XML" do
    run_generator ["--editor=rubymine", "--port=19999"]
    assert_file ".idea/runConfigurations/debug_anywhere.xml" do |content|
      assert_match "19999", content
    end
  end

  test "--editor=manual skips IDE config creation" do
    run_generator ["--editor=manual"]
    assert_no_file ".vscode/launch.json"
    assert_no_file ".idea/runConfigurations/debug_anywhere.xml"
  end

  test "raises error for unsupported --editor value" do
    assert_raises(Thor::Error) { run_generator ["--editor=vim"], debug: true }
  end

  # ─── --runtime option ───────────────────────────────────────────────────────

  test "--runtime=docker uses docker in bin/debug (default)" do
    run_generator ["--runtime=docker"]
    assert_file "bin/debug" do |content|
      assert_match "docker compose", content
    end
  end

  test "--runtime=podman uses podman in bin/debug" do
    run_generator ["--runtime=podman"]
    assert_file "bin/debug" do |content|
      assert_match "podman compose", content
    end
  end

  test "raises error for unsupported --runtime value" do
    assert_raises(Thor::Error) { run_generator ["--runtime=lima"], debug: true }
  end

  test "no files created when --runtime is invalid" do
    assert_raises(Thor::Error) { run_generator ["--runtime=lima"], debug: true }
    assert_no_file ".vscode/launch.json"
    assert_no_file "bin/debug"
  end

  test "no files created when --editor is invalid" do
    assert_raises(Thor::Error) { run_generator ["--editor=vim"], debug: true }
    assert_no_file ".vscode/launch.json"
    assert_no_file "bin/debug"
  end

  # ─── --status flag in generated bin/debug ───────────────────────────────────

  test "bin/debug contains --status flag handler" do
    run_generator
    assert_file "bin/debug" do |content|
      assert_match '--status', content
      assert_match "debug_anywhere status:", content
      assert_match "debug port 12345 is open", content
      assert_match "web server is responding", content
    end
  end

  test "--status flag uses correct port when custom port set" do
    run_generator ["--port=19999"]
    assert_file "bin/debug" do |content|
      assert_match "debug port 19999 is open", content
    end
  end

  # ─── Template structural validation ─────────────────────────────────────────

  test "launch.json is valid JSON with required structure" do
    run_generator
    assert_file ".vscode/launch.json" do |content|
      parsed = JSON.parse(content)
      assert_equal "0.2.0", parsed["version"]
      configs = parsed["configurations"]
      assert_equal 1, configs.length
      config = configs.first
      assert_equal "rdbg", config["type"]
      assert_equal "attach", config["request"]
      assert_equal "localhost:12345", config["debugPort"]
      assert_equal "/rails:${workspaceFolder}", config["localfsMap"]
    end
  end

  test "launch.json debugPort reflects custom --port" do
    run_generator ["--port=19999"]
    assert_file ".vscode/launch.json" do |content|
      parsed = JSON.parse(content)
      assert_equal "localhost:19999", parsed["configurations"].first["debugPort"]
    end
  end

  test "rubymine XML is well-formed with required elements" do
    run_generator ["--editor=rubymine"]
    assert_file ".idea/runConfigurations/debug_anywhere.xml" do |content|
      doc = REXML::Document.new(content)
      assert_not_nil doc.root, "XML should have a root element"
      assert_equal "component", doc.root.name
      assert_equal "ProjectRunConfigurationManager", doc.root.attributes["name"]
      config = doc.root.elements["configuration"]
      assert_not_nil config, "XML should have a <configuration> element"
      assert_equal "Attach to Rails in Docker", config.attributes["name"]
      port_opt = config.elements["option[@name='REMOTE_PORT']"]
      assert_not_nil port_opt, "XML should have REMOTE_PORT option"
      assert_equal "12345", port_opt.attributes["value"]
      host_opt = config.elements["option[@name='REMOTE_HOST']"]
      assert_not_nil host_opt, "XML should have REMOTE_HOST option"
      assert_equal "localhost", host_opt.attributes["value"]
    end
  end

  test "rubymine XML reflects custom --port" do
    run_generator ["--editor=rubymine", "--port=19999"]
    assert_file ".idea/runConfigurations/debug_anywhere.xml" do |content|
      doc = REXML::Document.new(content)
      port_opt = doc.root.elements["configuration/option[@name='REMOTE_PORT']"]
      assert_equal "19999", port_opt.attributes["value"]
    end
  end

  test "docker-compose.debug.yml is valid YAML with required structure" do
    run_generator
    assert_file "docker-compose.debug.yml" do |content|
      parsed = YAML.safe_load(content)
      assert parsed.key?("services"), "YAML should have a services key"
      service_config = parsed["services"]["web"]
      assert_not_nil service_config, "YAML should have a 'web' service"
      env = service_config["environment"]
      assert_equal "true", env["RUBY_DEBUG_OPEN"]
      assert_equal "127.0.0.1", env["RUBY_DEBUG_HOST"]
      assert_equal "12345", env["RUBY_DEBUG_PORT"]
      assert_equal "1", env["RUBY_DEBUG_NONSTOP"]
      assert_equal "0", env["WEB_CONCURRENCY"]
      ports = service_config["ports"]
      assert_includes ports, "127.0.0.1:12345:12345"
    end
  end

  test "docker-compose.debug.yml YAML reflects custom --port and --service" do
    run_generator ["--port=19999", "--service=app"]
    assert_file "docker-compose.debug.yml" do |content|
      parsed = YAML.safe_load(content)
      assert parsed["services"].key?("app"), "Service 'app' should be present"
      refute parsed["services"].key?("web"), "Default 'web' service should not appear"
      assert_equal "19999", parsed["services"]["app"]["environment"]["RUBY_DEBUG_PORT"]
      assert_includes parsed["services"]["app"]["ports"], "127.0.0.1:19999:19999"
    end
  end

  # ─── editor × runtime combination matrix ─────────────────────────────────────

  test "--editor=vscode --runtime=podman creates launch.json and uses podman" do
    run_generator ["--editor=vscode", "--runtime=podman"]
    assert_file ".vscode/launch.json"
    assert_no_file ".idea/runConfigurations/debug_anywhere.xml"
    assert_file "bin/debug" do |content|
      assert_match "podman compose", content
      assert_no_match(/docker compose/, content)
    end
  end

  test "--editor=rubymine --runtime=docker creates XML and uses docker" do
    run_generator ["--editor=rubymine", "--runtime=docker"]
    assert_file ".idea/runConfigurations/debug_anywhere.xml"
    assert_no_file ".vscode/launch.json"
    assert_file "bin/debug" do |content|
      assert_match "docker compose", content
    end
  end

  test "--editor=rubymine --runtime=podman creates XML and uses podman" do
    run_generator ["--editor=rubymine", "--runtime=podman"]
    assert_file ".idea/runConfigurations/debug_anywhere.xml"
    assert_no_file ".vscode/launch.json"
    assert_file "bin/debug" do |content|
      assert_match "podman compose", content
      assert_no_match(/docker compose/, content)
    end
  end

  test "--editor=zed --runtime=docker creates launch.json and uses docker" do
    run_generator ["--editor=zed", "--runtime=docker"]
    assert_file ".vscode/launch.json"
    assert_no_file ".idea/runConfigurations/debug_anywhere.xml"
    assert_file "bin/debug" do |content|
      assert_match "docker compose", content
    end
  end

  test "--editor=zed --runtime=podman creates launch.json and uses podman" do
    run_generator ["--editor=zed", "--runtime=podman"]
    assert_file ".vscode/launch.json"
    assert_no_file ".idea/runConfigurations/debug_anywhere.xml"
    assert_file "bin/debug" do |content|
      assert_match "podman compose", content
      assert_no_match(/docker compose/, content)
    end
  end

  test "--editor=manual --runtime=docker creates no IDE config and uses docker" do
    run_generator ["--editor=manual", "--runtime=docker"]
    assert_no_file ".vscode/launch.json"
    assert_no_file ".idea/runConfigurations/debug_anywhere.xml"
    assert_file "bin/debug" do |content|
      assert_match "docker compose", content
    end
  end

  test "--editor=manual --runtime=podman creates no IDE config and uses podman" do
    run_generator ["--editor=manual", "--runtime=podman"]
    assert_no_file ".vscode/launch.json"
    assert_no_file ".idea/runConfigurations/debug_anywhere.xml"
    assert_file "bin/debug" do |content|
      assert_match "podman compose", content
      assert_no_match(/docker compose/, content)
    end
  end

  # ─── Port boundary values ────────────────────────────────────────────────────

  test "port 1024 is valid (lower boundary)" do
    run_generator ["--port=1024"]
    assert_file "bin/debug" do |content|
      assert_match "wait_for_port 1024", content
    end
  end

  test "port 65535 is valid (upper boundary)" do
    run_generator ["--port=65535"]
    assert_file "bin/debug" do |content|
      assert_match "wait_for_port 65535", content
    end
  end

  test "port 1023 is invalid (just below lower boundary)" do
    assert_raises(Thor::Error) { run_generator ["--port=1023"], debug: true }
  end

  test "port 65536 is invalid (just above upper boundary)" do
    assert_raises(Thor::Error) { run_generator ["--port=65536"], debug: true }
  end

  test "port 0 is invalid" do
    assert_raises(Thor::Error) { run_generator ["--port=0"], debug: true }
  end

  test "port -1 is invalid" do
    assert_raises(Thor::Error) { run_generator ["--port=-1"], debug: true }
  end

  # ─── Gemfile edge cases ──────────────────────────────────────────────────────

  test "accepts Gemfile with debug gem in single quotes" do
    File.write "#{destination_root}/Gemfile", <<~RUBY
      source "https://rubygems.org"
      gem 'debug', platforms: %i[mri windows]
    RUBY
    run_generator
    assert_file "bin/debug"
  end

  test "accepts Gemfile with debug gem followed by inline options" do
    File.write "#{destination_root}/Gemfile", <<~RUBY
      source "https://rubygems.org"
      gem "debug", platforms: %i[mri windows], require: "debug/prelude"
    RUBY
    run_generator
    assert_file "bin/debug"
  end

  # ─── .ruby-version edge cases ───────────────────────────────────────────────

  test "raises error for pre-release .ruby-version (e.g. 3.4.7-preview1)" do
    File.write "#{destination_root}/.ruby-version", "3.4.7-preview1"
    assert_raises(Thor::Error) { run_generator [], debug: true }
  end

  test "raises error for truncated .ruby-version missing patch level (e.g. 3.4)" do
    File.write "#{destination_root}/.ruby-version", "3.4"
    assert_raises(Thor::Error) { run_generator [], debug: true }
  end

  test "raises error for truffleruby .ruby-version" do
    File.write "#{destination_root}/.ruby-version", "truffleruby-23.0.0"
    assert_raises(Thor::Error) { run_generator [], debug: true }
  end

  test "raises error for empty .ruby-version file" do
    File.write "#{destination_root}/.ruby-version", ""
    assert_raises(Thor::Error) { run_generator [], debug: true }
  end

  test "raises error for whitespace-only .ruby-version file" do
    File.write "#{destination_root}/.ruby-version", "   \n"
    assert_raises(Thor::Error) { run_generator [], debug: true }
  end
end
