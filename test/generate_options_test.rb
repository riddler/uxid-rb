# frozen_string_literal: true

require "test_helper"

# UXID.generate: where the random field comes from, and the options it refuses.
class GenerateOptionsTest < Minitest::Test
  TIME = 1_700_000_000_000

  # A byte source that hands back fixed bytes and records each request.
  class RecordingSource
    attr_reader :requests

    def initialize(bytes)
      @bytes = bytes
      @requests = []
    end

    def call(count)
      @requests << count
      @bytes.byteslice(0, count)
    end
  end

  def hex(string)
    [string].pack("H*")
  end

  # Sabotage: calling SecureRandom directly instead of the byte source turns this red.
  def test_random_bytes_come_from_the_byte_source
    source = RecordingSource.new(hex("0123456789abcdef0123"))

    assert_equal "usr_01hf7yat0004hmasw9", UXID.generate(prefix: "usr", size: :m, time: TIME, byte_source: source)
    assert_equal [5], source.requests
  end

  # Sabotage: calling the byte source even when rand: is given turns this red.
  def test_rand_fixes_the_random_field_without_calling_the_byte_source
    source = RecordingSource.new(hex("ffffffffff"))

    assert_equal "01hf7yat0004hmasw9", UXID.generate(size: :m, time: TIME, rand: hex("0123456789"), byte_source: source)
    assert_empty source.requests
  end

  # Sabotage: replacing the SecureRandom default with zero bytes turns this red.
  def test_the_default_byte_source_fills_the_random_field
    ids = Array.new(8) { UXID.generate(time: TIME) }

    assert_equal 8, ids.uniq.size
  end

  # Sabotage: accepting a byte source's answer without checking its width turns this red.
  def test_a_byte_source_that_returns_the_wrong_width_is_refused
    error = assert_raises(ArgumentError) do
      UXID.generate(size: :m, time: TIME, byte_source: ->(_count) { "\x00".b })
    end
    assert_match(/byte_source/, error.message)
  end

  # Sabotage: skipping the compact guard turns this red.
  def test_a_compact_time_whose_first_character_would_be_the_marker_is_refused
    [2_164_663_517_184, 1_065_151_889_408].each do |time|
      error = assert_raises(UXID::Error) do
        UXID.generate(prefix: "usr", size: :s, compact_time: true, time: time, rand: hex("010203"))
      end
      assert_equal :compact_time_out_of_range, error.code
    end
  end

  # Sabotage: guarding the value 30 as well as 31 turns this red.
  def test_the_last_compact_time_before_the_marker_is_encoded
    id = begin
      UXID.generate(prefix: "usr", size: :s, compact_time: true, time: 1_065_151_889_407, rand: hex("012345"))
    rescue UXID::Error => e
      e.code
    end

    assert_equal "usr_yzzzzzzz04hm5", id
  end

  # Sabotage: dropping the width check on rand: turns this red.
  def test_a_rand_of_the_wrong_width_is_refused
    [[:s, "010203"], [:xl, "010203040506070809"], [:xs, "01"]].each do |size, bytes|
      error = assert_raises(UXID::Error) do
        UXID.generate(prefix: "usr", size: size, time: TIME, rand: hex(bytes))
      end
      assert_equal :rand_width_mismatch, error.code, "size #{size}"
    end
  end

  # Sabotage: raising the random field cap above 10 bytes turns this red.
  def test_a_rand_size_above_ten_is_refused
    error = assert_raises(UXID::Error) do
      UXID.generate(prefix: "usr", rand_size: 11, size: :xl, time: TIME)
    end
    assert_equal :rand_size_too_large, error.code
  end

  # Sabotage: making UXID::Error a plain StandardError turns this red.
  def test_a_generation_error_is_an_argument_error
    assert_operator UXID::Error, :<, ArgumentError
  end

  # Sabotage: dropping the unknown-keyword check turns this red.
  def test_an_unknown_option_is_refused
    error = assert_raises(ArgumentError) { UXID.generate(from: "x", monotonic: true) }

    assert_equal "unknown keywords: :from, :monotonic", error.message
    assert_equal "unknown keyword: :from", assert_raises(ArgumentError) { UXID.generate(from: "x") }.message
  end

  # Sabotage: removing any one check below turns its row red.
  def test_options_outside_the_spec_raise_argument_error
    [
      { size: :huge }, { size: nil }, { case: :title }, { delimiter: "" }, { delimiter: nil },
      { prefix: :usr }, { rand_size: -1 }, { rand_size: 2.0 }, { time: -1 }, { time: 2**48 },
      { time: 1.5 }, { rand: [1, 2] }, { compact_time: nil }, { byte_source: Object.new }
    ].each do |options|
      error = assert_raises(ArgumentError, options.inspect) { UXID.generate(**options) }

      refute_kind_of UXID::Error, error, options.inspect
    end
  end
end
