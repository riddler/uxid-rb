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

# The publish step of .github/workflows/release.yml, which publishes through
# rubygems/release-gem: that action runs `bundle exec rake release` once it
# has exchanged the run's OIDC identity for a short-lived rubygems.org
# credential (trusted publishing), and afterwards waits for the gem it finds
# under pkg/ to appear on rubygems.org. The task builds the gem into pkg/ and
# pushes it. Unlike Bundler's own release task it never creates or pushes a
# git tag: the workflow runs on the push of the version tag, so the tag
# already exists.
#
# Anywhere but that workflow, on the push of the tag naming UXID::VERSION, it
# refuses before building anything: a person or an agent never publishes
# from a checkout (CLAUDE.md, "Release preps").
module ReleaseTask
  # Why the release task must not run under env (the process environment)
  # for the gem at version, or nil when it may: only GitHub Actions, on the
  # push of the tag vVERSION, in this repository's release.yml.
  def self.refusal(env, version)
    tag = "v#{version}"
    workflow = "#{env["GITHUB_REPOSITORY"]}/.github/workflows/release.yml@refs/tags/#{tag}"
    return if env["GITHUB_ACTIONS"] == "true" && env["GITHUB_REF"] == "refs/tags/#{tag}" &&
              env["GITHUB_WORKFLOW_REF"] == workflow

    "release: runs only in .github/workflows/release.yml on the push of #{tag}; nothing was built or pushed"
  end
end

desc "Build and push the gem (only inside .github/workflows/release.yml on its version tag)"
task :release do
  require "bundler/gem_helper"

  helper = Bundler::GemHelper.new(__dir__, "uxid")
  refusal = ReleaseTask.refusal(ENV, helper.gemspec.version)
  abort refusal if refusal

  dirty = !system("git", "diff", "--quiet") || !system("git", "diff", "--cached", "--quiet")
  abort "release: the checkout has uncommitted changes; nothing was built or pushed" if dirty

  sh "gem", "push", helper.build_gem
end

# The full gate.
task default: %i[rubocop corpus:check test]
