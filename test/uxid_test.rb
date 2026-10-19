# frozen_string_literal: true

require "test_helper"

class UXIDTest < Minitest::Test
  # Sabotage: deleting the require of uxid/version from lib/uxid.rb turns this red.
  def test_requiring_the_gem_loads_its_version
    assert defined?(UXID::VERSION), "require \"uxid\" should define UXID::VERSION"
  end

  # Sabotage: setting VERSION to "1.0" in lib/uxid/version.rb turns this red.
  def test_version_is_a_semantic_version
    assert_match(/\A\d+\.\d+\.\d+\z/, UXID::VERSION)
  end
end
