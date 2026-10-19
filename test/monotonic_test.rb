# frozen_string_literal: true

require_relative "monotonic_helper"

# UXID::Monotonic: the monotonic rule of the wire-format spec, per instance.
class MonotonicTest < Minitest::Test
  include MonotonicHelper

  # Sabotage: reseeding on every call (ignoring the stored time) turns this red.
  def test_a_call_at_the_same_time_keeps_the_time_and_adds_the_step
    generator = UXID::Monotonic.new(prefix: "usr", size: :s, draws: Fixed.new(seed: 100, step: 7))

    assert_equal [UXID.generate(prefix: "usr", size: :s, time: TIME, rand: hex("0064")),
                  UXID.generate(prefix: "usr", size: :s, time: TIME, rand: hex("006b"))],
                 [generator.generate(time: TIME), generator.generate(time: TIME)]
  end

  # Sabotage: taking the current time on a clock that moved back turns this red.
  def test_an_earlier_time_keeps_the_last_time
    generator = UXID::Monotonic.new(size: :s, draws: Fixed.new(seed: 100, step: 7))
    generator.generate(time: TIME)

    assert_equal UXID.generate(size: :s, time: TIME, rand: hex("006b")), generator.generate(time: TIME - 5)
  end

  # Sabotage: stepping on a later time instead of reseeding turns this red.
  def test_a_later_time_takes_a_fresh_seed_and_the_new_time
    draws = Fixed.new(seed: 100, step: 7)
    generator = UXID::Monotonic.new(size: :s, draws: draws)
    generator.generate(time: TIME)

    assert_equal UXID.generate(size: :s, time: TIME + 1, rand: hex("0064")), generator.generate(time: TIME + 1)
    assert_equal [[:seed, 2], [:seed, 2]], draws.calls
  end

  # Sabotage: overflowing at 2**(8w) + 1 instead of 2**(8w) turns this red.
  def test_a_step_that_reaches_the_field_size_moves_to_the_next_millisecond_with_a_fresh_seed
    draws = Fixed.new(seed: 65_535, step: 1)
    generator = UXID::Monotonic.new(size: :s, draws: draws)
    generator.generate(time: TIME)

    assert_equal(UXID.generate(size: :s, time: TIME + 1, rand: hex("ffff")), outcome { generator.generate(time: TIME) })
    assert_equal [[:seed, 2], [:step, 2], [:seed, 2]], draws.calls
  end

  # Sabotage: moving to T + 1 past the largest standard time turns this red.
  def test_an_overflow_past_the_largest_time_is_refused
    generator = UXID::Monotonic.new(size: :s, draws: Fixed.new(seed: 65_535, step: 1))
    generator.generate(time: (2**48) - 1)

    assert_raises(ArgumentError) { generator.generate(time: (2**48) - 1) }
  end

  # Sabotage: keying the state by prefix alone turns this red.
  def test_state_is_kept_per_prefix_and_per_random_width
    generator = UXID::Monotonic.new(draws: Fixed.new(seed: 0, step: 1))
    generator.generate(prefix: "usr", size: :s, time: TIME)

    assert_equal UXID.generate(prefix: "cus", size: :s, time: TIME, rand: hex("0000")),
                 generator.generate(prefix: "cus", size: :s, time: TIME)
    assert_equal UXID.generate(prefix: "usr", size: :m, time: TIME, rand: hex("0000000000")),
                 generator.generate(prefix: "usr", size: :m, time: TIME)
    assert_equal UXID.generate(prefix: "usr", size: :s, time: TIME, rand: hex("0001")),
                 generator.generate(prefix: "usr", size: :s, time: TIME)
  end

  # Sabotage: keying the state by the prefix as given (so nil and "" differ) turns this red.
  def test_no_prefix_and_an_empty_prefix_share_their_state
    generator = UXID::Monotonic.new(size: :s, draws: Fixed.new(seed: 0, step: 1))
    generator.generate(time: TIME)

    assert_equal UXID.generate(size: :s, time: TIME, rand: hex("0001")), generator.generate(prefix: "", time: TIME)
  end

  # Sabotage: keeping the state in a class-level Hash turns this red.
  def test_each_generator_keeps_its_own_state
    first = UXID::Monotonic.new(size: :s, draws: Fixed.new(seed: 0, step: 1))
    second = UXID::Monotonic.new(size: :s, draws: Fixed.new(seed: 0, step: 1))
    first.generate(time: TIME)

    assert_equal UXID.generate(size: :s, time: TIME, rand: hex("0000")), second.generate(time: TIME)
    assert_empty UXID::Monotonic.instance_variables
    assert_empty UXID::Monotonic.class_variables
  end

  # Sabotage: leaving compact time off for xs (a standard xs has no random field) turns this red.
  def test_xs_is_compact_unless_told_otherwise
    generator = UXID::Monotonic.new(prefix: "usr", size: :xs, draws: Fixed.new(seed: 2, step: 5))

    assert_equal([UXID.generate(prefix: "usr", size: :xs, compact_time: true, time: TIME, rand: hex("02")),
                  UXID.generate(prefix: "usr", size: :xs, compact_time: true, time: TIME, rand: hex("07"))],
                 outcome { [generator.generate(time: TIME), generator.generate(time: TIME)] })
  end
end
