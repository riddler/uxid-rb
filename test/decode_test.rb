# frozen_string_literal: true

require "test_helper"

# UXID.decode: the reading the wire-format spec defines, beyond the corpus
# cases in corpus_subset_test.rb.
class DecodeTest < Minitest::Test
  TIME = 1_700_000_000_000
  DAY = 86_400_000
  WINDOW = 2**40
  COMPACT = UXID.generate(size: :s, compact_time: true, time: TIME, rand: "\x00\x00\x00".b)

  def decode(id, **)
    UXID.decode(id, now: TIME, **)
  end

  # Sabotage: answering Invalid for every input turns this red.
  def test_a_decoded_id_is_a_frozen_value_that_answers_valid
    decoded = decode("usr_01hf7yat00")

    assert_equal UXID::Decoded.new(prefix: "usr", size: :xs, compact: false, deterministic: false, time: TIME), decoded
    assert_predicate decoded, :valid?
    assert_predicate decoded, :frozen?
    refute_predicate decoded, :compact?
    refute_predicate decoded, :deterministic?
  end

  # Sabotage: answering valid? true on an Invalid turns this red.
  def test_a_refused_id_is_a_frozen_value_that_answers_not_valid
    invalid = decode("usr_01hf7yat0")

    assert_equal UXID::Invalid.new(reason: :invalid_length), invalid
    refute_predicate invalid, :valid?
    assert_predicate invalid, :frozen?
  end

  # Sabotage: swapping the compact flags of lengths 13 and 14 turns this red.
  def test_every_generated_size_and_form_decodes_back
    %i[s l xl].product([false, true], %i[lower upper]).each do |size, compact, letter_case|
      id = UXID.generate(prefix: "cus", size: size, compact_time: compact, case: letter_case, time: TIME)
      expected = UXID::Decoded.new(prefix: "cus", size: size, compact: compact, deterministic: false, time: TIME)

      assert_equal expected, decode(id), id
    end
  end

  # Sabotage: reading the compact form for length 18 turns this red.
  def test_lengths_10_and_18_read_as_standard
    { xs: 1, m: 6 }.each do |size, width|
      id = UXID.generate(prefix: "usr", size: size, compact_time: true, time: TIME, rand: "\x01".b * width)
      decoded = decode(id)

      assert_equal size, decoded.size, id
      refute_predicate decoded, :compact?, id
      refute_equal TIME, decoded.time, id
    end
  end

  # Sabotage: decoding a deterministic body's characters as a time turns this red.
  def test_a_deterministic_id_decodes_with_no_time_at_every_size
    %i[xs s m l xl].each do |size|
      id = UXID.generate(prefix: "usr", from: "alice@example.com", size: size, case: :upper)
      expected = UXID::Decoded.new(prefix: "usr", size: size, compact: false, deterministic: true, time: nil)

      assert_equal expected, decode(id), id
    end
  end

  # Sabotage: splitting on the first delimiter instead of the last turns this red.
  def test_the_prefix_is_everything_before_the_last_delimiter
    assert_equal standard_xs("a_b"), decode("a_b_01hf7yat00")
    assert_equal standard_xs(nil), decode("01hf7yat00")
    assert_equal standard_xs(""), decode("_01hf7yat00")
  end

  # Sabotage: ignoring the delimiter option and splitting on "_" turns this red.
  def test_the_delimiter_is_the_one_given
    id = UXID.generate(prefix: "usr_x", delimiter: "--", size: :xs, time: TIME)

    assert_equal "usr_x--01hf7yat00", id
    assert_equal standard_xs("usr_x"), decode(id, delimiter: "--")
    assert_equal UXID::Invalid.new(reason: :invalid_character), decode(id)
  end

  # The decoding of a standard xs id at TIME with this prefix.
  def standard_xs(prefix)
    UXID::Decoded.new(prefix: prefix, size: :xs, compact: false, deterministic: false, time: TIME)
  end

  # Sabotage: dropping the one-day guard (always taking the clock's window) turns this red.
  def test_a_compact_time_takes_the_clocks_window_unless_more_than_a_day_ahead
    { TIME - DAY => TIME, TIME - DAY - 1 => TIME - WINDOW, TIME + WINDOW => TIME + WINDOW }.each do |now, time|
      assert_equal time, UXID.decode(COMPACT, now: now).time, now
    end
  end

  # Sabotage: reading a Time's seconds as milliseconds turns this red.
  def test_now_takes_a_time
    assert_equal TIME, UXID.decode(COMPACT, now: Time.at(TIME / 1000)).time
  end

  # Sabotage: reading the system clock as zero turns this red.
  def test_now_defaults_to_the_system_clock
    now = Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
    id = UXID.generate(size: :s, compact_time: true, time: now, rand: "\x00\x00\x00".b)

    assert_equal now, UXID.decode(id).time
  end

  # Sabotage: accepting a non-String delimiter turns this red.
  def test_options_outside_their_types_raise
    assert_raises(ArgumentError) { UXID.decode("usr_01hf7yat00", delimiter: "") }
    assert_raises(ArgumentError) { UXID.decode("usr_01hf7yat00", delimiter: :_) }
    assert_raises(ArgumentError) { UXID.decode("usr_01hf7yat00", now: "1700000000000") }
    assert_raises(ArgumentError) { UXID.valid?("usr_01hf7yat00", delimiter: nil) }
  end
end
