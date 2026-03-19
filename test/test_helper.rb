require "minitest/autorun"
require "rails/generators/testing/behavior"
require "rails/generators/testing/assertions"
require "rails/generators/test_case"
require "fileutils"

# Load the gem
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "debug_anywhere"
require "generators/debug_anywhere/install_generator"
require "generators/debug_anywhere/uninstall_generator"
