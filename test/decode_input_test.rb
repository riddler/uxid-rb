# frozen_string_literal: true

require "test_helper"

# UXID.decode on input outside the alphabet strings a producer emits: values
# that are not Strings, and Strings in any encoding, read as their bytes.
class DecodeInputTest < Minitest::Test
  TIME = 1_700_000_000_000

  def decode(id, **)
    UXID.decode(id, now: TIME, **)
  end

  # What UXID.decode returns, or the class of what it raises, so that a
  # raise reads as an assertion failure.
  def read(id, **)
    decode(id, **)
  rescue StandardError => e
    e.class
  end

  # Sabotage: dropping the String check (each value then raises) turns this red.
  def test_a_value_that_is_not_a_string_is_refused_never_raised
    [nil, 42, :usr_01hf7yat00, ["usr_01hf7yat00"]].each do |value|
      assert_equal UXID::Invalid.new(reason: :invalid_character), read(value), value.inspect
    end
  end

  # Sabotage: splitting the id and delimiter themselves, not their binary copies, raises and turns this red.
  def test_a_binary_or_broken_string_is_read_as_its_bytes
    assert_equal :invalid_character, decode("usr_01hf7yat0\xFF".b).reason
    assert_equal :invalid_character, decode("u\xFFr_01hf7yat0\xC3".dup.force_encoding(Encoding::UTF_8)).reason
    assert_equal :invalid_length, decode("usr_01hf7yat0\xC3\xA9").reason
    assert_equal UXID::Decoded.new(prefix: "\xFF".b, size: :xs, compact: false, deterministic: false, time: TIME),
                 read("\xFF\xC3\xA901hf7yat00".b, delimiter: "é")
  end

  # Sabotage: returning the prefix as a binary String turns this red.
  def test_the_prefix_keeps_the_ids_encoding
    decoded = decode("caf\xE9_01hf7yat00".dup.force_encoding(Encoding::ISO_8859_1))

    assert_equal TIME, decoded.time
    assert_equal "caf\xE9".dup.force_encoding(Encoding::ISO_8859_1), decoded.prefix
    assert_equal Encoding::ISO_8859_1, decoded.prefix.encoding
  end

  # Sabotage: keeping the body in the id's encoding and refusing by its character length turns this red.
  def test_refusals_count_bytes
    assert_equal :invalid_character, decode("01hf7yaté").reason
    assert_equal :invalid_length, decode("01hf7yat0é").reason
  end
end
