# frozen_string_literal: true

require "test_helper"
require "rake"

# The Rakefile's `release` task is the publish step of
# .github/workflows/release.yml, and it must refuse everywhere but that
# workflow on the push of the tag naming UXID::VERSION. The Rakefile is
# loaded into a throwaway Rake application and its guard, ReleaseTask.refusal,
# is asked about each environment; the task itself is never run here.
class ReleaseTaskTest < Minitest::Test
  RAKEFILE = File.expand_path("../Rakefile", __dir__)
  Rake.with_application(Rake::Application.new) { load RAKEFILE }

  VERSION = UXID::VERSION
  TAG = "v#{VERSION}".freeze
  REPOSITORY = "riddler/uxid-rb"

  # The variables GitHub Actions sets for release.yml on the push of tag.
  def release_workflow(tag)
    {
      "GITHUB_ACTIONS" => "true",
      "GITHUB_REF" => "refs/tags/#{tag}",
      "GITHUB_REPOSITORY" => REPOSITORY,
      "GITHUB_WORKFLOW_REF" => "#{REPOSITORY}/.github/workflows/release.yml@refs/tags/#{tag}"
    }
  end

  def assert_refused(env)
    refusal = ReleaseTask.refusal(env, VERSION)

    assert_equal "release: runs only in .github/workflows/release.yml on the push of #{TAG}; " \
                 "nothing was built or pushed", refusal
  end

  # Mutation: make the guard return nil whatever the environment.
  def test_refuses_outside_github_actions
    assert_refused({})
  end

  # Mutation: drop the GITHUB_ACTIONS comparison from the guard.
  def test_refuses_without_github_actions_set_even_with_the_workflow_refs
    env = release_workflow(TAG)
    env.delete("GITHUB_ACTIONS")

    assert_refused(env)
  end

  # Mutation: drop the GITHUB_WORKFLOW_REF comparison from the guard.
  def test_refuses_another_workflow_on_the_version_tag
    env = release_workflow(TAG)
    env["GITHUB_WORKFLOW_REF"] = "#{REPOSITORY}/.github/workflows/ci.yml@refs/tags/#{TAG}"

    assert_refused(env)
  end

  # Mutation: drop the GITHUB_REF comparison from the guard.
  def test_refuses_a_tag_that_does_not_name_the_version
    env = release_workflow(TAG)
    env["GITHUB_REF"] = "refs/tags/v#{VERSION}9"

    assert_refused(env)
  end

  # Mutation: drop both the GITHUB_REF and the GITHUB_WORKFLOW_REF
  # comparisons from the guard.
  def test_refuses_release_yml_on_a_branch
    env = release_workflow(TAG)
    env["GITHUB_REF"] = "refs/heads/main"
    env["GITHUB_WORKFLOW_REF"] = "#{REPOSITORY}/.github/workflows/release.yml@refs/heads/main"

    assert_refused(env)
  end

  # Mutation: build the expected GITHUB_WORKFLOW_REF from the environment's
  # own GITHUB_REPOSITORY, and drop the GITHUB_REPOSITORY comparison.
  def test_refuses_release_yml_in_another_repository
    env = release_workflow(TAG)
    env["GITHUB_REPOSITORY"] = "example/uxid-rb"
    env["GITHUB_WORKFLOW_REF"] = "example/uxid-rb/.github/workflows/release.yml@refs/tags/#{TAG}"

    assert_refused(env)
  end

  # Mutation: drop the GITHUB_REPOSITORY comparison from the guard.
  def test_refuses_with_github_repository_unset
    env = release_workflow(TAG)
    env.delete("GITHUB_REPOSITORY")

    assert_refused(env)
  end

  # Mutation: compare GITHUB_ACTIONS against "1" rather than "true".
  def test_allows_release_yml_on_the_version_tag
    assert_nil ReleaseTask.refusal(release_workflow(TAG), VERSION)
  end
end
