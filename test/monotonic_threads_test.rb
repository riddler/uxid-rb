# frozen_string_literal: true

require_relative "monotonic_helper"

# UXID::Monotonic: one generator shared across threads.
class MonotonicThreadsTest < Minitest::Test
  include MonotonicHelper

  THREADS = 8
  CALLS = 50

  # Every seed is 0, every step is 1, and every step yields to another
  # thread first, so two calls that both read the state before either writes
  # it would give the same id.
  def yielding_draws
    draws = Fixed.new(seed: 0, step: 1)
    draws.define_singleton_method(:step) do |_width|
      Thread.pass
      1
    end
    draws
  end

  # The ids an unshared generator gives for the same draws: the random
  # values 0 to count - 1 in order.
  def in_order(count)
    Array.new(count) { |value| UXID.generate(prefix: "usr", time: TIME, rand: [value].pack("Q>").rjust(10, "\0")) }
  end

  # Sabotage: removing the synchronize around a call turns this red.
  def test_threads_sharing_one_generator_get_strictly_increasing_distinct_ids
    generator = UXID::Monotonic.new(prefix: "usr", draws: yielding_draws)
    threads = Array.new(THREADS) { Thread.new { Array.new(CALLS) { generator.generate(time: TIME) } } }
    per_thread = threads.map(&:value)

    per_thread.each { |ids| assert_equal ids.sort.uniq, ids }
    assert_equal in_order(THREADS * CALLS), per_thread.flatten.sort
  end
end
