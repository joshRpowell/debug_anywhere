require "test_helper"
require "generators/debug_anywhere/uninstall_generator"

class UninstallGeneratorTest < Rails::Generators::TestCase
  tests DebugAnywhere::Generators::UninstallGenerator
  destination File.expand_path("../../../tmp/test_app_uninstall", __dir__)

  setup do
    prepare_destination

    FileUtils.mkdir_p "#{destination_root}/config"
    FileUtils.mkdir_p "#{destination_root}/app/controllers"
    FileUtils.mkdir_p "#{destination_root}/bin"
    FileUtils.mkdir_p "#{destination_root}/.vscode"

    # Pre-populate files as if install ran
    File.write "#{destination_root}/.vscode/launch.json", '{"version":"0.2.0"}'
    File.write "#{destination_root}/bin/debug", "#!/usr/bin/env bash\necho hi"
    FileUtils.chmod 0o755, "#{destination_root}/bin/debug"
    File.write "#{destination_root}/docker-compose.debug.yml", "services:\n  web:\n"
    File.write "#{destination_root}/app/controllers/debug_controller.rb", "class DebugController; end"
    File.write "#{destination_root}/config/routes.rb", <<~RUBY
      Rails.application.routes.draw do

        if Rails.env.development?
          get "debug", to: "debug#trigger"
        end
      end
    RUBY
    File.write "#{destination_root}/.dockerignore", ".git\n/.vscode/\n"
    File.write "#{destination_root}/docker-compose.yml", "services:\n  web:\n"
    File.write "#{destination_root}/Dockerfile.dev", "FROM ruby:3.4.0-slim\n"
  end

  # ─── File removal ───────────────────────────────────────────────────────────

  test "removes .vscode/launch.json" do
    run_generator
    assert_no_file ".vscode/launch.json"
  end

  test "removes bin/debug" do
    run_generator
    assert_no_file "bin/debug"
  end

  test "removes docker-compose.debug.yml" do
    run_generator
    assert_no_file "docker-compose.debug.yml"
  end

  test "removes debug_controller.rb" do
    run_generator
    assert_no_file "app/controllers/debug_controller.rb"
  end

  test "removes rubymine config if present" do
    FileUtils.mkdir_p "#{destination_root}/.idea/runConfigurations"
    File.write "#{destination_root}/.idea/runConfigurations/debug_anywhere.xml", "<component/>"
    run_generator
    assert_no_file ".idea/runConfigurations/debug_anywhere.xml"
  end

  # ─── Patch reversion ────────────────────────────────────────────────────────

  test "removes debug route from config/routes.rb" do
    run_generator
    assert_file "config/routes.rb" do |content|
      assert_no_match(/debug#trigger/, content)
      assert_no_match(/Rails\.env\.development\?/, content)
      assert_match "Rails.application.routes.draw do", content
    end
  end

  test "removes /.vscode/ from .dockerignore" do
    run_generator
    assert_file ".dockerignore" do |content|
      assert_no_match(%r{/\.vscode/}, content)
    end
  end

  # ─── Files NOT removed ──────────────────────────────────────────────────────

  test "does not remove docker-compose.yml" do
    run_generator
    assert_file "docker-compose.yml"
  end

  test "does not remove Dockerfile.dev" do
    run_generator
    assert_file "Dockerfile.dev"
  end

  # ─── Idempotency ────────────────────────────────────────────────────────────

  test "runs cleanly when files are already absent" do
    prepare_destination
    FileUtils.mkdir_p "#{destination_root}/config"
    File.write "#{destination_root}/config/routes.rb", "Rails.application.routes.draw do\nend\n"
    run_generator  # no files to remove — should not raise
    assert_file "config/routes.rb"  # routes.rb should be untouched
  end

  test "skips route removal when route not present" do
    File.write "#{destination_root}/config/routes.rb", "Rails.application.routes.draw do\nend\n"
    run_generator
    assert_file "config/routes.rb" do |content|
      assert_match "Rails.application.routes.draw do", content
    end
  end

  test "skips dockerignore update when entry not present" do
    File.write "#{destination_root}/.dockerignore", ".git\n"
    run_generator
    assert_file ".dockerignore" do |content|
      assert_equal ".git\n", content
    end
  end
end
