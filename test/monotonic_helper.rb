# frozen_string_literal: true

require "test_helper"

# What the UXID::Monotonic tests share: a fixed time, a draw source and a
# byte source with fixed answers.
module MonotonicHelper
  TIME = 1_700_000_000_000

  # A draw source with fixed answers: every seed is `seed` and every step is
  # `step`. It records each call as [kind, width].
  class Fixed
    attr_reader :calls
    attr_writer :step

    def initialize(seed: 0, step: 1)
      @seed = seed
      @step = step
      @calls = []
    end

    def seed(width)
      @calls << [:seed, width]
      @seed
    end

    def step(width)
      @calls << [:step, width]
      @step
    end
  end

  # A byte source that returns its chunks in turn and records each count.
  class Bytes
    attr_reader :counts

    def initialize(*chunks)
      @chunks = chunks.map(&:b)
      @counts = []
    end

    def call(count)
      @counts << count
      @chunks.shift
    end
  end

  # What the block returns, or the ArgumentError it raises, so that a test
  # comparing outcomes fails on its assertion either way.
  def outcome
    yield
  rescue ArgumentError => e
    e
  end

  def hex(string)
    [string].pack("H*")
  end
end
