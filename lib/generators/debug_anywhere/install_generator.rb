require "rails/generators"

module DebugAnywhere
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Scaffold rdbg remote debugging for Rails + Docker + VS Code"

      class_option :port,    type: :numeric, default: 12345, desc: "rdbg TCP port"
      class_option :service, type: :string,  default: "web",  desc: "docker-compose service name"

      def create_vscode_launch_json
        template "launch.json.tt", ".vscode/launch.json"
      end

      def create_bin_debug
        template "bin_debug.tt", "bin/debug"
        chmod "bin/debug", 0o755
      end

      def patch_docker_compose
        compose_file = "docker-compose.yml"
        compose_path = File.join(destination_root, compose_file)

        if File.exist?(compose_path)
          if File.read(compose_path).include?("RUBY_DEBUG_OPEN")
            say_status :skip, "#{compose_file} already contains RUBY_DEBUG_OPEN — skipping injection", :yellow
            return
          end
          inject_into_docker_compose(compose_file)
        else
          create_minimal_docker_compose(compose_file)
        end
      end

      def create_dockerfile_dev
        if File.exist?(File.join(destination_root, "Dockerfile.dev"))
          say_status :skip, "Dockerfile.dev already exists", :yellow
          say "  Verify it contains:"
          say "    WORKDIR /rails"
          say "    COPY .ruby-version Gemfile Gemfile.lock ./ (before bundle install)"
          say "    Non-root user (rails, uid 1000)"
          say "    EXPOSE 3000"
        else
          template "Dockerfile.dev.tt", "Dockerfile.dev"
        end
      end

      def inject_debug_route
        routes_path = File.join(destination_root, "config/routes.rb")
        routes_content = File.read(routes_path)

        if routes_content.include?("debug#trigger")
          say_status :skip, "Debug route already present in config/routes.rb", :yellow
          return
        end

        inject_into_file "config/routes.rb",
          after: "Rails.application.routes.draw do" do
          "\n\n  if Rails.env.development?\n    get \"debug\", to: \"debug#trigger\"\n  end"
        end
      end

      def create_debug_controller
        create_file "app/controllers/debug_controller.rb" do
          <<~RUBY
            class DebugController < ApplicationController
              def trigger
                binding.break
                render plain: "Resumed from breakpoint"
              end
            end
          RUBY
        end
      end

      def update_dockerignore
        dockerignore = ".dockerignore"
        dockerignore_path = File.join(destination_root, dockerignore)
        entry = "/.vscode/"

        return unless File.exist?(dockerignore_path)
        return if File.read(dockerignore_path).include?(entry)

        append_to_file dockerignore, "\n#{entry}\n"
      end

      def check_debug_gem
        return if File.read(File.join(destination_root, "Gemfile")).match?(/gem\s+["']debug["']/)

        say ""
        say_status :warning, "The 'debug' gem was not found in your Gemfile.", :red
        say "  Add it to your Gemfile:"
        say '    gem "debug", platforms: %i[mri windows], require: "debug/prelude"'
        say "  Without it, binding.break will raise NoMethodError at runtime."
        say ""
      end

      def print_post_install_notice
        say ""
        say "=" * 60
        say "  debug_anywhere installed!"
        say "=" * 60
        say ""
        say "  Prerequisites:"
        say "    ✓ docker + docker compose CLI"
        say "    ✓ nc (netcat) — used by bin/debug readiness check"
        say "    ✓ VS Code extension: ruby.vscode-rdbg"
        say "      Install: code --install-extension KoichiSasada.vscode-rdbg"
        say ""
        say "  web_console note:"
        say "    If web_console shows 'not allowed' from Docker, add to"
        say "    config/environments/development.rb:"
        say "      config.web_console.permissions = \"172.28.0.0/16\""
        say "    (Matches the pinned subnet in docker-compose.yml)"
        say ""
        say "  Start debugging:"
        say "    bin/debug"
        say ""
        say "  Then open http://localhost:3000/debug in your browser."
        say "  VS Code will pause at binding.break in DebugController#trigger."
        say ""
      end

      private

      def port
        options[:port]
      end

      def service
        options[:service]
      end

      def ruby_version
        ruby_version_path = File.join(destination_root, ".ruby-version")
        if File.exist?(ruby_version_path)
          File.read(ruby_version_path).strip
        else
          RUBY_VERSION
        end
      end

      def inject_into_docker_compose(compose_file)
        content = File.read(File.join(destination_root, compose_file))

        unless content.include?("#{service}:")
          say_status :error, "Service '#{service}' not found in #{compose_file}.", :red
          say "  Run with --service=<name> to specify the correct service."
          say "  Example: rails g debug_anywhere:install --service=app"
          return
        end

        env_block = <<~YAML

                # debug_anywhere: rdbg remote debug — do not deploy to production
                RUBY_DEBUG_OPEN: "true"
                RUBY_DEBUG_HOST: "127.0.0.1"
                RUBY_DEBUG_PORT: "#{port}"
                RUBY_DEBUG_NONSTOP: "1"
                WEB_CONCURRENCY: "0"
        YAML

        port_entry = "      - \"127.0.0.1:#{port}:#{port}\"\n"

        if content.include?("environment:")
          inject_into_file compose_file, env_block,
            after: /#{Regexp.escape(service)}:.*?\n(?:.*?\n)*?.*?environment:\n/m
        else
          inject_into_file compose_file,
            "    environment:\n#{env_block}",
            after: "  #{service}:\n"
        end

        if content.include?("ports:")
          inject_into_file compose_file, port_entry,
            after: /#{Regexp.escape(service)}:.*?\n(?:.*?\n)*?.*?ports:\n/m
        else
          inject_into_file compose_file,
            "    ports:\n#{port_entry}",
            after: "  #{service}:\n"
        end
      end

      def create_minimal_docker_compose(compose_file)
        create_file compose_file do
          <<~YAML
            # WARNING: LOCAL DEVELOPMENT ONLY — remove RUBY_DEBUG_* before any deployment.
            services:
              web:
                build:
                  context: .
                  dockerfile: Dockerfile.dev
                command: bundle exec rails server -b 0.0.0.0
                volumes:
                  - .:/rails
                ports:
                  - "127.0.0.1:3000:3000"
                  - "127.0.0.1:#{port}:#{port}"
                environment:
                  RUBY_DEBUG_OPEN: "true"
                  RUBY_DEBUG_HOST: "127.0.0.1"
                  RUBY_DEBUG_PORT: "#{port}"
                  RUBY_DEBUG_NONSTOP: "1"
                  WEB_CONCURRENCY: "0"
                  RAILS_ENV: development

            # Fixed subnet: matches config.web_console.permissions = "172.28.0.0/16"
            # in config/environments/development.rb. Do not change without updating that setting.
            networks:
              default:
                driver: bridge
                ipam:
                  config:
                    - subnet: 172.28.0.0/16
          YAML
        end
      end
    end
  end
end
