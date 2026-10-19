# frozen_string_literal: true

require "minitest/test_task"
require "rubocop/rake_task"

RuboCop::RakeTask.new

# The suite runs under SimpleCov (configured in .simplecov), which fails the
# run below the coverage minimum. SimpleCov is required in the prelude, ahead
# of minitest/autorun, so that it reports after the suite has run rather than
# before it.
Minitest::TestTask.create(:test) do |t|
  t.test_prelude = %(require "simplecov")
  t.test_globs = ["test/**/*_test.rb"]
end

# The full gate. The conformance corpus check joins this list when the corpus
# is vendored under conformance/.
task default: %i[rubocop test]
