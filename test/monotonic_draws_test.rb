# frozen_string_literal: true

require_relative "monotonic_helper"

# UXID::Monotonic: where the seeds and steps come from.
class MonotonicDrawsTest < Minitest::Test
  include MonotonicHelper

  # Sabotage: drawing the seed from SecureRandom instead of byte_source turns this red.
  def test_with_no_draw_source_the_byte_source_supplies_the_seed_and_the_masked_step
    # w = 2: the seed is 2 bytes; the step is 4w = 8 bits from 1 byte, plus 1.
    bytes = Bytes.new(hex("0100"), hex("ff"))
    generator = UXID::Monotonic.new(size: :s, byte_source: bytes)

    expected = [UXID.generate(size: :s, time: TIME, rand: hex("0100")),
                UXID.generate(size: :s, time: TIME, rand: hex("0200"))]

    assert_equal(expected, outcome { [generator.generate(time: TIME), generator.generate(time: TIME)] })
    assert_equal [2, 1], bytes.counts
  end

  # Sabotage: masking the step to 4w - 1 bits instead of 4w turns this red.
  def test_the_default_step_is_masked_to_half_the_field_width
    # w = 1: the step is 4 bits of 1 byte, so 0xff masks to 15 and the step is 16.
    bytes = Bytes.new(hex("00"), hex("ff"))
    generator = UXID::Monotonic.new(size: :xs, byte_source: bytes)
    generator.generate(time: TIME)

    assert_equal UXID.generate(size: :xs, compact_time: true, time: TIME, rand: hex("10")),
                 generator.generate(time: TIME)
  end

  # Sabotage: subtracting the step instead of adding it turns this red.
  def test_with_no_draw_or_byte_source_ids_are_still_strictly_increasing
    generator = UXID::Monotonic.new(prefix: "usr", size: :m)
    ids = Array.new(20) { generator.generate(time: TIME) }

    assert_equal ids.sort.uniq, ids
  end

  # Sabotage: when draws is given, calling the byte source anyway turns this red.
  def test_with_a_draw_source_the_byte_source_is_not_called
    bytes = Bytes.new
    generator = UXID::Monotonic.new(size: :s, byte_source: bytes, draws: Fixed.new(seed: 0, step: 1))
    2.times { generator.generate(time: TIME) }

    assert_empty bytes.counts
  end

  def two_calls(draws)
    generator = UXID::Monotonic.new(size: :s, draws: draws)
    2.times { generator.generate(time: TIME) }
  end

  # Sabotage: accepting a step of 0 from the draw source turns this red.
  def test_a_draw_outside_its_range_is_refused
    assert_raises(ArgumentError) { two_calls(Fixed.new(seed: 0, step: 0)) }
    assert_raises(ArgumentError) { two_calls(Fixed.new(seed: 0, step: 257)) }
    assert_raises(ArgumentError) { two_calls(Fixed.new(seed: 65_536, step: 1)) }
    assert_raises(ArgumentError) { two_calls(Fixed.new(seed: -1, step: 1)) }
    assert_raises(ArgumentError) { two_calls(Fixed.new(seed: "0", step: 1)) }
  end

  # Sabotage: refusing the largest step (2**(4w)) turns this red.
  def test_the_largest_step_is_accepted
    generator = UXID::Monotonic.new(size: :s, draws: Fixed.new(seed: 0, step: 256))
    generator.generate(time: TIME)

    assert_equal(UXID.generate(size: :s, time: TIME, rand: hex("0100")), outcome { generator.generate(time: TIME) })
  end

  # The first compact time whose first character would be the marker.
  GUARD = 1_065_151_889_408

  # Sabotage: writing the state before the id is built turns this red.
  def test_a_refused_call_leaves_the_state_unchanged
    generator = UXID::Monotonic.new(size: :s, compact_time: true, draws: Fixed.new(seed: 5, step: 1))
    error = assert_raises(UXID::Error) { generator.generate(time: GUARD) }

    assert_equal :compact_time_out_of_range, error.code
    assert_equal(UXID.generate(size: :s, compact_time: true, time: GUARD - 1, rand: hex("000005")),
                 outcome { generator.generate(time: GUARD - 1) })
  end
end
