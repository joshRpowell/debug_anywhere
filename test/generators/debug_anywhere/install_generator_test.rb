require "test_helper"

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
      assert_match "USER rails", content
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
end
