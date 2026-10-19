# frozen_string_literal: true

require "test_helper"

# UXID.generate: the layout of the time body the wire-format spec defines.
class GenerateTest < Minitest::Test
  TIME = 1_700_000_000_000

  def hex(string)
    [string].pack("H*")
  end

  # Sabotage: emitting standard time in 11 characters (a 5-bit first group
  # over a 55-bit field) turns this red.
  def test_standard_time_is_ten_characters_with_a_three_bit_first_group
    assert_equal "01hf7yat00", UXID.generate(size: :xs, time: TIME)
    assert_equal "0000000000", UXID.generate(size: :xs, time: 0)
    assert_equal "7zzzzzzzzz", UXID.generate(size: :xs, time: (2**48) - 1)
  end

  # Sabotage: dropping the 40-bit mask in the compact time encoder turns this red.
  def test_compact_time_is_the_low_forty_bits
    assert_equal "hf7yat0001", UXID.generate(size: :xs, compact_time: true, time: TIME, rand: hex("01"))
    assert_equal UXID.generate(size: :s, compact_time: true, time: TIME, rand: hex("012345")),
                 UXID.generate(size: :s, compact_time: true, time: TIME + (2**40), rand: hex("012345"))
  end

  # Sabotage: padding the random field's last group (shifting it left to 5
  # bits) instead of writing its raw value turns this red.
  def test_the_random_fields_short_group_is_last_and_holds_its_raw_value
    assert_equal "01hf7yat00zzz1", UXID.generate(size: :s, time: TIME, rand: hex("ffff"))
    assert_equal "hf7yat00z7", UXID.generate(size: :xs, compact_time: true, time: TIME, rand: hex("ff"))
  end

  # Sabotage: giving compact s the standard width (2 bytes) turns this red.
  def test_each_size_and_mode_has_the_specs_body_length
    {
      [:xs, false] => 10, [:s, false] => 14, [:m, false] => 18, [:l, false] => 22, [:xl, false] => 26,
      [:xs, true] => 10, [:s, true] => 13, [:m, true] => 18, [:l, true] => 21, [:xl, true] => 24
    }.each do |(size, compact), length|
      assert_equal length, UXID.generate(size: size, compact_time: compact, time: TIME).bytesize,
                   "size #{size}, compact_time #{compact}"
    end
  end

  # Sabotage: changing the default size to :m turns this red.
  def test_the_default_is_xl_standard_lower_with_no_prefix
    assert_equal 26, UXID.generate(time: TIME).bytesize
    assert_equal "01hf7yat0004hmasw9nf6yy093", UXID.generate(time: TIME, rand: hex("0123456789abcdef0123"))
  end

  # Sabotage: mapping :small to :xs in the size table turns this red.
  def test_size_takes_short_and_long_names_as_symbols_or_strings
    [:s, :small, "s", "small"].each do |size|
      assert_equal 14, UXID.generate(size: size, time: TIME).bytesize, "size #{size.inspect}"
      assert_equal "01hf7yat0004h1", UXID.generate(size: size, time: TIME, rand: hex("0123")), "size #{size.inspect}"
    end
  end

  # Sabotage: mapping :large to :m turns this red.
  def test_every_long_size_name_has_its_short_names_width
    { "xsmall" => 10, medium: 18, "large" => 22, xlarge: 26 }.each do |size, length|
      assert_equal length, UXID.generate(size: size, time: TIME).bytesize, "size #{size.inspect}"
    end
  end

  # Sabotage: ignoring case: in the encoder turns this red.
  def test_case_upper_emits_every_body_character_upper_case_and_leaves_the_prefix_alone
    assert_equal "usr_01HF7YAT0004HMASW9NF6YY093",
                 UXID.generate(prefix: "usr", case: :upper, time: TIME, rand: hex("0123456789abcdef0123"))
    assert_equal "usr_HF7YAT0001",
                 UXID.generate(prefix: "usr", size: :xs, compact_time: true, case: "upper", time: TIME,
                               rand: hex("01"))
  end

  # Sabotage: building the body in a String.new with no encoding (binary) turns this red.
  def test_an_id_is_a_utf8_string_with_or_without_a_prefix
    assert_equal Encoding::UTF_8, UXID.generate(time: TIME).encoding
    assert_equal Encoding::UTF_8, UXID.generate(prefix: "usr", time: TIME).encoding
  end

  # Sabotage: emitting the delimiter for an empty prefix turns this red.
  def test_an_empty_prefix_is_no_prefix
    rand = hex("0123456789abcdef0123")

    assert_equal "01hf7yat0004hmasw9nf6yy093", UXID.generate(prefix: "", time: TIME, rand: rand)
    assert_equal "01hf7yat0004hmasw9nf6yy093", UXID.generate(prefix: nil, time: TIME, rand: rand)
  end

  # Sabotage: hard-coding "_" in place of the delimiter option turns this red.
  def test_the_delimiter_joins_prefix_and_body
    assert_equal "usr-01hf7yat00", UXID.generate(prefix: "usr", delimiter: "-", size: :xs, time: TIME)
    assert_equal "a_b_01hf7yat0004h1", UXID.generate(prefix: "a_b", size: :s, time: TIME, rand: hex("0123"))
  end

  # Sabotage: ignoring rand_size: and always using the size's width turns this red.
  def test_an_explicit_rand_size_sets_the_random_width
    assert_equal 17, UXID.generate(size: :s, rand_size: 4, time: TIME).bytesize
    assert_equal "01hf7yat00zzzzzz3", UXID.generate(size: :s, rand_size: 4, time: TIME, rand: hex("ffffffff"))
    assert_equal "01hf7yat00", UXID.generate(size: :xl, rand_size: 0, time: TIME)
    assert_equal 26, UXID.generate(size: :xs, rand_size: 10, time: TIME).bytesize
  end

  # Sabotage: reading a Time's whole seconds only (dropping the milliseconds)
  # turns this red.
  def test_time_takes_a_time_object_at_millisecond_precision
    time = Time.at(TIME / 1000, 999_999, :usec)

    assert_equal UXID.generate(size: :xs, time: TIME + 999), UXID.generate(size: :xs, time: time)
  end

  # Sabotage: reading the clock in seconds instead of milliseconds turns this red.
  def test_time_defaults_to_the_current_clock
    before = (Time.now.to_r * 1000).floor
    id = UXID.generate(size: :xs)
    after = (Time.now.to_r * 1000).floor

    assert_operator id, :>=, UXID.generate(size: :xs, time: before)
    assert_operator id, :<=, UXID.generate(size: :xs, time: after)
  end
end
