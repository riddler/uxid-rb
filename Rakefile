# frozen_string_literal: true

require "digest"
require "json"
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

namespace :corpus do
  # The integrity check of the corpus vendored under conformance/, by the
  # rule of its README ("Running the cases", steps 1 and 2): the SHA-256 of
  # the case files' bytes concatenated in the order of the manifest's
  # `files`, written `sha256:` and lowercase hex, must equal the manifest's
  # `corpus_hash` and the one SOURCE.json records for the tag it was copied
  # from, and each case file must hold `case_count` lines.
  desc "Check the vendored conformance corpus against its manifest and SOURCE.json"
  task :check do
    dir = File.join(__dir__, "conformance")
    manifest = JSON.parse(File.read(File.join(dir, "manifest.json")))
    source = JSON.parse(File.read(File.join(dir, "SOURCE.json")))
    failures = []

    failures << "corpus_version is #{manifest["corpus_version"].inspect}, not 1" unless manifest["corpus_version"] == 1

    bytes = manifest["files"].map { |entry| File.binread(File.join(dir, entry["file"])) }
    hash = "sha256:#{Digest::SHA256.hexdigest(bytes.join)}"
    { "manifest.json" => manifest, "SOURCE.json" => source }.each do |name, record|
      next if record["corpus_hash"] == hash

      failures << "#{name} corpus_hash is #{record["corpus_hash"]}, the files hash to #{hash}"
    end

    manifest["files"].zip(bytes) do |entry, content|
      lines = content.count("\n")
      complete = content.empty? || content.end_with?("\n")
      next if complete && lines == entry["case_count"]

      failures << "#{entry["file"]} holds #{lines} lines#{" and an unended one" unless complete}, " \
                  "case_count is #{entry["case_count"]}"
    end

    abort "corpus:check failed:\n  #{failures.join("\n  ")}" unless failures.empty?
    puts "corpus:check: #{manifest["files"].sum { |entry| entry["case_count"] }} cases, #{hash}"
  end
end

# The full gate.
task default: %i[rubocop corpus:check test]
