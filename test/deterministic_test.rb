# frozen_string_literal: true

require "test_helper"
require "digest"

# UXID.generate with from: the deterministic body the wire-format spec
# defines, the hash of prefix || 0x00 || from || 0x00 || count.
class DeterministicTest < Minitest::Test
  TIME = 1_700_000_000_000

  # Sabotage: dropping the zero byte between the prefix and from turns this red.
  def test_the_three_ids_that_lock_the_format
    assert_equal "usr_zcvt7epac0t1ebcsjfyf7cwz25", UXID.generate(prefix: "usr", from: "alice@example.com", size: :xl)
    assert_equal "cus_zt9vnyfd85bff0", UXID.generate(prefix: "cus", from: "acme-corp", size: :s)
    assert_equal "zqz4cwzgyw8ks97869", UXID.generate(from: "alice@example.com", size: :m)
  end

  # The hash input built here, field by field, as the spec lays it out.
  def spec_body(prefix, from, count)
    input = "#{prefix}\x00#{from}\x00".b + count.chr.b
    bits = Digest::SHA256.digest(input).unpack1("B*")[0, count * 5]
    "z#{bits.scan(/.{5}/).map { |group| "0123456789abcdefghjkmnpqrstvwxyz"[group.to_i(2)] }.join}"
  end

  # Sabotage: hashing the count as the body length (count + 1) turns this red.
  def test_each_size_hashes_its_own_character_count
    { xs: 9, s: 13, m: 17, l: 21, xl: 25 }.each do |size, count|
      assert_equal "usr_#{spec_body("usr", "a", count)}", UXID.generate(prefix: "usr", from: "a", size: size), size
    end
  end

  # Sabotage: leaving the prefix out of the hash input turns this red.
  def test_the_prefix_is_part_of_the_hash
    usr = UXID.generate(prefix: "usr", from: "alice@example.com")
    cus = UXID.generate(prefix: "cus", from: "alice@example.com")

    refute_equal usr.delete_prefix("usr_"), cus.delete_prefix("cus_")
    assert_equal UXID.generate(from: "alice@example.com"), UXID.generate(prefix: "", from: "alice@example.com")
  end

  # Sabotage: hashing the upper-cased from (or case) turns this red.
  def test_case_sets_the_marker_and_the_letters_but_not_the_hash
    lower = UXID.generate(prefix: "usr", from: "alice@example.com", size: :m)
    upper = UXID.generate(prefix: "usr", from: "alice@example.com", size: :m, case: :upper)

    assert_equal "usr_#{lower.delete_prefix("usr_").upcase}", upper
    assert upper.start_with?("usr_Z")
  end

  # Sabotage: hashing the from string's own bytes instead of its UTF-8 bytes turns this red.
  def test_from_is_hashed_as_its_utf8_bytes
    utf8 = UXID.generate(prefix: "cus", from: "café", size: :m)

    assert_equal "cus_zfsx9se75671f9kdjv", utf8
    assert_equal utf8, UXID.generate(prefix: "cus", from: "café".encode(Encoding::ISO_8859_1), size: :m)
    assert_equal UXID.generate(from: "abc"), UXID.generate(from: "abc".b)
  end

  # Sabotage: hashing invalid or binary bytes as given turns this red.
  def test_a_from_with_no_utf8_form_is_refused
    ["caf\xC3".dup.force_encoding(Encoding::UTF_8), "caf\xE9".b].each do |from|
      error = assert_raises(ArgumentError, from.inspect) { UXID.generate(prefix: "cus", from: from) }

      refute_kind_of UXID::Error, error
      assert_match(/\Afrom: /, error.message)
    end
  end

  # Sabotage: returning a time body when rand: is given turns this red.
  def test_rand_with_from_is_refused
    [hex("00010203040506070809"), "".b].each do |rand|
      error = assert_raises(UXID::Error) { UXID.generate(prefix: "usr", from: "alice@example.com", rand: rand) }

      assert_equal :rand_with_from, error.code
    end
    assert_equal "usr_zcvt7epac0t1ebcsjfyf7cwz25", UXID.generate(prefix: "usr", from: "alice@example.com", rand: nil)
  end

  # Sabotage: building a time body (the time and compact options read) turns this red.
  def test_the_time_and_random_options_do_not_shape_the_body
    expected = UXID.generate(prefix: "usr", from: "alice@example.com", size: :s)
    never = ->(_count) { flunk "the byte source was called" }

    assert_equal expected, UXID.generate(prefix: "usr", from: "alice@example.com", size: :s, time: TIME,
                                         compact_time: true, rand_size: 4, byte_source: never)
  end

  # Sabotage: using the marker value 30 turns this red.
  def test_a_deterministic_id_sorts_after_every_time_based_id
    ids = [UXID.generate(prefix: "usr", from: "", size: :xs),
           UXID.generate(prefix: "usr", size: :xs, time: (2**48) - 1),
           UXID.generate(prefix: "usr", size: :xs, compact_time: true, time: 1_065_151_889_407, rand: hex("ff"))]

    assert_equal ids[0], ids.max
    assert_equal 14, ids[0].length
  end

  def hex(string)
    [string].pack("H*")
  end
end
