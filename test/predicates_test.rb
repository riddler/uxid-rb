# frozen_string_literal: true

require "test_helper"

# UXID.valid? and UXID.deterministic?, the readings of UXID.decode a caller
# branches on.
class PredicatesTest < Minitest::Test
  # Sabotage: answering true for an Invalid turns this red.
  def test_valid_is_whether_the_id_decodes
    assert UXID.valid?("cus_zt9vnyfd85bff0")
    assert UXID.valid?("usr--01hf7yat00", delimiter: "--")
    refute UXID.valid?("usr_01hu7yat00")
    refute UXID.valid?("usr_")
    refute UXID.valid?(nil)
  end

  # Sabotage: ignoring the prefix option turns this red.
  def test_valid_with_a_prefix_checks_it
    assert UXID.valid?("cus_zt9vnyfd85bff0", prefix: "cus")
    assert UXID.valid?("cus_zt9vnyfd85bff0", prefix: "")
    refute UXID.valid?("cus_zt9vnyfd85bff0", prefix: "usr")
    refute UXID.valid?("01hf7yat00", prefix: "usr")
    assert UXID.valid?("usr--01hf7yat00", prefix: "usr", delimiter: "--")
  end

  # Sabotage: answering from the first character alone (no decode) turns this red.
  def test_deterministic_is_true_only_for_a_well_formed_deterministic_id
    assert UXID.deterministic?("cus_zt9vnyfd85bff0")
    assert UXID.deterministic?("CUS_ZT9VNYFD85BFF0")
    assert UXID.deterministic?("cus--zt9vnyfd85bff0", delimiter: "--")
    refute UXID.deterministic?("usr_01hf7yat00")
    refute UXID.deterministic?("usr_zcvt7epac0t1ebcsjfyf7cwzi5")
    refute UXID.deterministic?("usr_z")
    refute UXID.deterministic?(42)
  end
end
