require "rails/generators"

module DebugAnywhere
  module Generators
    class UninstallGenerator < Rails::Generators::Base
      desc "Remove debug_anywhere scaffolding from this Rails application"

      def remove_ide_configs
        # VS Code / Zed
        remove_file ".vscode/launch.json" if File.exist?(File.join(destination_root, ".vscode/launch.json"))
        # RubyMine
        remove_file ".idea/runConfigurations/debug_anywhere.xml" if File.exist?(File.join(destination_root, ".idea/runConfigurations/debug_anywhere.xml"))
      end

      def remove_bin_debug
        remove_file "bin/debug" if File.exist?(File.join(destination_root, "bin/debug"))
      end

      def remove_docker_compose_debug
        remove_file "docker-compose.debug.yml" if File.exist?(File.join(destination_root, "docker-compose.debug.yml"))
      end

      def remove_debug_controller
        remove_file "app/controllers/debug_controller.rb" if File.exist?(File.join(destination_root, "app/controllers/debug_controller.rb"))
      end

      def remove_debug_route
        routes_path = File.join(destination_root, "config/routes.rb")
        unless File.exist?(routes_path)
          say_status :skip, "config/routes.rb not found", :yellow
          return
        end

        unless File.read(routes_path).include?("debug#trigger")
          say_status :skip, "Debug route not present in config/routes.rb", :yellow
          return
        end

        gsub_file "config/routes.rb",
          /\n\s+if Rails\.env\.development\?\n\s+get ["']debug["'], to: ["']debug#trigger["']\n\s+end\n/,
          ""
      end

      def remove_dockerignore_entry
        dockerignore_path = File.join(destination_root, ".dockerignore")
        return unless File.exist?(dockerignore_path)

        entry = "/.vscode/"
        return unless File.read(dockerignore_path).include?(entry)

        gsub_file ".dockerignore", /\n?\/\.vscode\/\n?/, ""
      end

      def warn_about_remaining_files
        remaining = []
        remaining << "docker-compose.yml" if File.exist?(File.join(destination_root, "docker-compose.yml"))
        remaining << "Dockerfile.dev" if File.exist?(File.join(destination_root, "Dockerfile.dev"))

        return if remaining.empty?

        say ""
        say "  The following files were NOT removed (you may have customized them):"
        remaining.each { |f| say "    #{f}" }
        say "  Remove them manually if you no longer need them."
        say ""
      end
    end
  end
end
