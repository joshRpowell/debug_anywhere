require_relative "lib/debug_anywhere/version"

Gem::Specification.new do |spec|
  spec.name    = "debug_anywhere"
  spec.version = DebugAnywhere::VERSION
  spec.authors = ["Joshua Powell"]
  spec.email   = []

  spec.summary     = "One-command rdbg remote debugging setup for Rails apps in Docker with VS Code"
  spec.description = <<~DESC
    Scaffolds a battle-tested, security-hardened rdbg debugging stack for Rails
    applications running in Docker. Generates .vscode/launch.json, docker-compose.yml
    configuration, Dockerfile.dev, a debug controller/route, and a bin/debug
    orchestration script — all correctly configured out of the box.
  DESC
  spec.homepage = "https://github.com/joshrpowell/debug_anywhere"
  spec.license  = "MIT"

  spec.metadata = {
    "source_code_uri"        => spec.homepage,
    "changelog_uri"          => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required"  => "true"
  }

  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir[
    "lib/**/*",
    "LICENSE",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_development_dependency "railties", ">= 7.0"
  spec.add_development_dependency "rexml", ">= 3.4.1"
end
