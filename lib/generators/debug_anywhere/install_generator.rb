require "rails/generators"

module DebugAnywhere
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Scaffold rdbg remote debugging for Rails + Docker + VS Code"

      class_option :port,    type: :numeric, default: 12345,    desc: "rdbg TCP port"
      class_option :service, type: :string,  default: "web",    desc: "docker-compose service name"
      class_option :editor,  type: :string,  default: "vscode", desc: "IDE to configure (vscode, rubymine, zed, manual)"
      class_option :runtime, type: :string,  default: "docker", desc: "Container runtime (docker, podman)"

      def check_debug_gem
        # Eagerly validate all options before touching the filesystem.
        port; service; editor; runtime

        gemfile_path = File.join(destination_root, "Gemfile")
        unless File.exist?(gemfile_path)
          say_status :warning, "Gemfile not found — skipping debug gem check", :yellow
          return
        end
        return if File.read(gemfile_path).match?(/\bgem\s+["']debug["']/)

        raise Thor::Error, <<~MSG
          The 'debug' gem was not found in your Gemfile.
          Add it before running this generator:

              gem "debug", platforms: %i[mri windows], require: "debug/prelude"

          Without it, binding.break will raise NoMethodError at runtime.
        MSG
      end

      def create_ide_config
        case editor
        when "vscode", "zed"
          template "launch.json.tt", ".vscode/launch.json"
        when "rubymine"
          template "rubymine_debug.xml.tt", ".idea/runConfigurations/debug_anywhere.xml"
        when "manual"
          say_status :skip, "Skipping IDE config (--editor=manual)", :yellow
        end
      end

      def create_bin_debug
        template "bin_debug.tt", "bin/debug"
        chmod "bin/debug", 0o755
      end

      def create_docker_compose_debug
        debug_compose = "docker-compose.debug.yml"
        if File.exist?(File.join(destination_root, debug_compose))
          say_status :skip, "#{debug_compose} already exists", :yellow
          return
        end
        template "docker-compose.debug.yml.tt", debug_compose
      end

      def create_docker_compose
        compose_file = "docker-compose.yml"
        compose_path = File.join(destination_root, compose_file)
        return if File.exist?(compose_path)

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
                environment:
                  RAILS_ENV: development

            # Fixed subnet: matches config.web_console.permissions = "172.28.0.0/16"
            networks:
              default:
                driver: bridge
                ipam:
                  config:
                    - subnet: 172.28.0.0/16
          YAML
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
        unless File.exist?(routes_path)
          say_status :error, "config/routes.rb not found — skipping route injection", :red
          return
        end

        routes_content = File.read(routes_path)

        if routes_content.include?("debug#trigger")
          say_status :skip, "Debug route already present in config/routes.rb", :yellow
          return
        end

        inject_into_file "config/routes.rb",
          after: /Rails\.application\.routes\.draw do[^\n]*\n/ do
          "\n  if Rails.env.development?\n    get \"debug\", to: \"debug#trigger\"\n  end\n"
        end
      end

      def create_debug_controller
        template "debug_controller.rb.tt", "app/controllers/debug_controller.rb"
      end

      def update_dockerignore
        dockerignore = ".dockerignore"
        dockerignore_path = File.join(destination_root, dockerignore)
        entry = "/.vscode/"

        return unless File.exist?(dockerignore_path)
        return if File.read(dockerignore_path).include?(entry)

        append_to_file dockerignore, "\n#{entry}\n"
      end

      def print_post_install_notice
        compose_cmd = "#{runtime} compose -f docker-compose.yml -f docker-compose.debug.yml up -d"

        say ""
        say "=" * 60
        say "  debug_anywhere installed!"
        say "=" * 60
        say ""
        say "  Prerequisites:"
        say "    ✓ #{runtime} + #{runtime} compose CLI"
        say "    ✓ nc (netcat) — used by bin/debug readiness check"
        case editor
        when "vscode"
          say "    ✓ VS Code extension: ruby.vscode-rdbg"
          say "      Install: code --install-extension KoichiSasada.vscode-rdbg"
        when "zed"
          say "    ✓ Zed with rdbg debug adapter support"
        when "rubymine"
          say "    ✓ RubyMine 2023.1+ with Ruby plugin"
          say "      Run config: .idea/runConfigurations/debug_anywhere.xml"
        when "manual"
          say "    ✓ Your debugger, attached to localhost:#{port} (rdbg TCP)"
        end
        say ""
        say "  web_console note:"
        say "    If web_console shows 'not allowed' from Docker, add to"
        say "    config/environments/development.rb:"
        say "      config.web_console.permissions = \"172.28.0.0/16\""
        say "    (Matches the pinned subnet in docker-compose.yml)"
        say ""
        say "  Start debugging:"
        say "    bin/debug"
        say "    bin/debug --status   # check if session is running"
        say "    (or manually: #{compose_cmd})"
        say ""
        say "  Then open http://localhost:3000/debug in your browser."
        say "  Execution will pause at binding.break in DebugController#trigger."
        say ""
      end

      private

      def port
        p = options[:port].to_i
        unless (1024..65535).include?(p)
          raise Thor::Error, "--port must be between 1024 and 65535 (got #{options[:port].inspect})"
        end
        p
      end

      def service
        s = options[:service]
        unless s.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_.\-]{0,62}\z/)
          raise Thor::Error, "--service '#{s}' is not a valid Docker Compose service name"
        end
        s
      end

      def editor
        e = options[:editor]
        valid_editors = %w[vscode rubymine zed manual]
        unless valid_editors.include?(e)
          raise Thor::Error, "--editor '#{e}' is not supported. Valid options: #{valid_editors.join(", ")}"
        end
        e
      end

      def runtime
        r = options[:runtime]
        valid_runtimes = %w[docker podman]
        unless valid_runtimes.include?(r)
          raise Thor::Error, "--runtime '#{r}' is not supported. Valid options: #{valid_runtimes.join(", ")}"
        end
        r
      end

      def ruby_version
        ruby_version_path = File.join(destination_root, ".ruby-version")
        if File.exist?(ruby_version_path)
          version = File.read(ruby_version_path).strip
          # Strip "ruby-" prefix written by rbenv (e.g. "ruby-3.4.7" → "3.4.7")
          version = version.sub(/\Aruby-/, "")
          unless version.match?(/\A\d+\.\d+\.\d+\z/)
            raise Thor::Error, ".ruby-version contains an unexpected value: #{version.inspect}. Expected format: X.Y.Z or ruby-X.Y.Z"
          end
          version
        else
          say_status :warning, ".ruby-version not found — using host Ruby #{RUBY_VERSION} for Dockerfile.dev", :yellow
          RUBY_VERSION
        end
      end
    end
  end
end
