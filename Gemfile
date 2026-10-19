# frozen_string_literal: true

source "https://rubygems.org"

# The gem itself (it has no runtime dependencies).
gemspec

# Development tools: the gate (the Rakefile's default task) runs these.
gem "minitest", "~> 5.25"
gem "rake", "~> 13.0"
gem "rubocop", "~> 1.0", require: false
gem "simplecov", "~> 0.22", require: false

# rubocop's own dependency, held to the 1.x line: parallel 2.x needs Ruby 3.3,
# and the lock must install on every Ruby the gem supports, from 3.2 up.
gem "parallel", "~> 1.27", require: false
