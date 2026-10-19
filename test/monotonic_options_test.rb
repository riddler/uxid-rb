# frozen_string_literal: true

require_relative "monotonic_helper"

# UXID::Monotonic: the options new and generate take, and the ones refused.
class MonotonicOptionsTest < Minitest::Test
  include MonotonicHelper

  # Sabotage: dropping the instance options under the call options turns this red.
  def test_options_given_to_new_are_the_defaults_of_every_call
    generator = UXID::Monotonic.new(prefix: "usr", size: :s, case: :upper, delimiter: "-",
                                    draws: Fixed.new(seed: 31, step: 1))
    options = { size: :s, case: :upper, delimiter: "-", time: TIME, rand: hex("001f") }

    assert_equal UXID.generate(prefix: "usr", **options), generator.generate(time: TIME)
    assert_equal UXID.generate(prefix: "cus", **options), generator.generate(prefix: "cus", time: TIME)
  end

  # Sabotage: ignoring time: (always reading the clock) turns this red.
  def test_time_takes_milliseconds_or_a_time_and_defaults_to_the_clock
    before = Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)

    assert_operator UXID.decode(UXID::Monotonic.new(prefix: "usr").generate).time, :>=, before
    assert_equal TIME, UXID.decode(UXID::Monotonic.new.generate(time: Time.at(Rational(TIME, 1000)))).time
  end

  # Sabotage: dropping the zero-width check turns this red.
  def test_a_request_with_no_random_field_is_refused
    error = assert_raises(ArgumentError) { UXID::Monotonic.new(size: :xs, compact_time: false).generate }
    refute_kind_of UXID::Error, error
    assert_raises(ArgumentError) { UXID::Monotonic.new(rand_size: 0).generate(time: TIME) }
  end

  def code(&)
    assert_raises(UXID::Error, &).code
  end

  # Sabotage: checking rand: before from: turns the from-and-rand case red.
  def test_from_and_rand_are_refused_by_generate_with_their_codes
    generator = UXID::Monotonic.new(prefix: "usr")

    assert_equal(:from_with_monotonic, code { generator.generate(from: "a@example.com") })
    assert_equal(:rand_with_monotonic, code { generator.generate(rand: hex("00")) })
    assert_equal(:from_with_monotonic, code { generator.generate(from: "a@example.com", rand: hex("00")) })
  end

  # Sabotage: refusing from: only in generate turns this red.
  def test_from_and_rand_are_refused_by_new_with_their_codes
    assert_equal(:from_with_monotonic, code { UXID::Monotonic.new(from: "a@example.com") })
    assert_equal(:rand_with_monotonic, code { UXID::Monotonic.new(rand: hex("00")) })
  end

  # Sabotage: dropping the nil check before refusing from: turns this red.
  def test_from_nil_and_rand_nil_are_the_same_as_leaving_them_out
    generator = UXID::Monotonic.new(size: :s, draws: Fixed.new(seed: 1, step: 1))

    assert_equal(UXID.generate(size: :s, time: TIME, rand: hex("0001")),
                 outcome { generator.generate(time: TIME, from: nil, rand: nil) })
  end

  # Sabotage: accepting time: in new turns this red.
  def test_options_outside_the_generators_are_refused
    assert_raises(ArgumentError) { UXID::Monotonic.new(time: TIME) }
    assert_raises(ArgumentError) { UXID::Monotonic.new(color: :red) }
    assert_raises(ArgumentError) { UXID::Monotonic.new(size: :huge) }
    assert_raises(ArgumentError) { UXID::Monotonic.new(draws: Object.new) }
    assert_raises(ArgumentError) { UXID::Monotonic.new.generate(color: :red) }
    assert_raises(ArgumentError) { UXID::Monotonic.new.generate(draws: Fixed.new) }
  end

  # Sabotage: naming only the first unknown keyword turns this red.
  def test_every_unknown_keyword_is_named
    error = assert_raises(ArgumentError) { UXID::Monotonic.new(color: 1, shape: 2) }

    assert_equal "unknown keywords: :color, :shape", error.message
  end
end
