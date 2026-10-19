# frozen_string_literal: true

require_relative "uxid/version"
require_relative "uxid/error"
require_relative "uxid/options"
require_relative "uxid/encoder"
require_relative "uxid/decoded"
require_relative "uxid/decoder"
require_relative "uxid/monotonic"

# Prefixed, K-sortable identifiers, wire-compatible with the Elixir
# reference implementation of uxid.
module UXID
  # Generates an id: an optional prefix and delimiter, then a body in
  # Crockford Base32, laid out as uxid-ex's wire-format spec defines it. The
  # body is time-based (a time field and a random field) unless :from is
  # given, when it is deterministic: the marker character (z, or Z in an
  # upper-case id) and then a SHA-256 hash of the prefix, the from string
  # and the size, so the same arguments always give the same id. A
  # deterministic id sorts after every time-based id with its prefix and
  # case.
  #
  # Every option is a keyword argument; an option left out takes its default,
  # and an unknown one raises ArgumentError. The options whose default is nil
  # take nil; the others refuse it.
  #
  # @param options [Hash] the keyword arguments below
  # @option options [String, nil] :prefix (nil) the prefix, emitted as given;
  #   nil and an empty string are both no prefix, and the id is then the bare
  #   body
  # @option options [Symbol, String] :size (:xl) :xs, :s, :m, :l or :xl, or
  #   their long names :xsmall, :small, :medium, :large and :xlarge, as
  #   Symbols or Strings
  # @option options [Integer, nil] :rand_size (nil) the random field's width
  #   in bytes, 0 to 10, in place of the size's; a body whose width is not the
  #   size table's has a length a decoder refuses
  # @option options [Boolean] :compact_time (false) true for compact time (the
  #   low 40 bits of the time in 8 characters), false for standard time (48
  #   bits in 10)
  # @option options [Symbol, String] :case (:lower) :lower or :upper, the case
  #   of every body character; the prefix keeps its own
  # @option options [String] :delimiter ("_") the non-empty string between
  #   prefix and body
  # @option options [Integer, Time, nil] :time (nil) the time, as milliseconds
  #   since the Unix epoch (0 to 2**48 - 1) or a Time (read to the
  #   millisecond); nil reads the system clock
  # @option options [String, nil] :rand (nil) the random field's bytes, used
  #   verbatim. For reproducible ids such as test vectors only, never as a
  #   source of randomness: the id is exactly as guessable as these bytes.
  #   Its byte size must be the call's random width
  # @option options [#call, nil] :byte_source (nil) where the random field's
  #   bytes come from: any object whose call(count) returns a String of count
  #   bytes; nil is SecureRandom.random_bytes. Not called when :rand is given
  # @option options [String, nil] :from (nil) the string a deterministic body
  #   is the hash of, read as its bytes: valid text in an encoding other
  #   than UTF-8 is transcoded to UTF-8 first; a binary (ASCII-8BIT) String,
  #   one not valid in its own encoding, and one Ruby cannot transcode are
  #   hashed as their own bytes, so a raw-byte key such as a 16-byte UUID
  #   works. The prefix is hashed the same way. The body has the size's
  #   standard length; :time, :compact_time, :rand_size and :byte_source do
  #   not apply to it and are not read
  # @return [String] the id
  # @raise [UXID::Error] a refusal the wire format names, with its
  #   {UXID::Error#code}: :rand_size_too_large for a :rand_size above 10,
  #   :rand_width_mismatch for a :rand whose byte size is not the random
  #   width, :compact_time_out_of_range for a compact time whose first
  #   character would be the deterministic marker, :rand_with_from for a
  #   :rand given with :from
  # @raise [ArgumentError] any other option outside the ones above
  #
  # @example
  #   UXID.generate(prefix: "usr")             # => "usr_01..." (26 body characters)
  #   UXID.generate(prefix: "cus", size: :s)   # => "cus_01..." (14 body characters)
  #   UXID.generate(prefix: "usr", size: :xs, time: 1_700_000_000_000)
  #   # => "usr_01hf7yat00"
  #   UXID.generate(prefix: "cus", from: "acme-corp", size: :s)
  #   # => "cus_zt9vnyfd85bff0"
  def self.generate(**options)
    Encoder.generate(Options.resolve(options))
  end

  # Decodes an id: its prefix, its size and time form, whether it is
  # deterministic, and its time, as uxid-ex's wire-format spec reads them.
  # The random field is not read back.
  #
  # The body is everything after the last delimiter and the prefix
  # everything before it; an id with no delimiter is a body with no prefix.
  # The body length in bytes gives the size and the time form. The lengths
  # 10 and 18 are read as standard xs and standard m: a compact xs or compact
  # m id decodes to its size but not its time. A body starting with z or Z
  # is deterministic and has no time. A compact body carries the low 40 bits
  # of its time; the rest come from the decoder's clock, and a result more
  # than one day ahead of the clock is taken from the 2**40 ms window before.
  #
  # Malformed input never raises: a String the format refuses gives an
  # Invalid whose reason is the first rule it fails, in this order: :empty
  # (an empty body: an empty string, or one ending in the delimiter),
  # :invalid_length (a body length in bytes not in the length table),
  # :invalid_character (a body byte outside the alphabet in either case).
  # A value that is not a String has no alphabet characters and gives
  # :invalid_character. A String in any encoding, binary or not valid in its
  # own encoding included, is read as its bytes.
  #
  # @param id [Object] the id to read
  # @param delimiter [String] ("_") the non-empty string between prefix and
  #   body; it must be the one the id was generated with
  # @param now [Integer, Time, nil] (nil) the decoder's clock, as
  #   milliseconds since the Unix epoch or a Time, read only for a compact
  #   time; nil reads the system clock
  # @return [UXID::Decoded, UXID::Invalid] both answer valid?, true for a
  #   Decoded and false for an Invalid
  # @raise [ArgumentError] for a delimiter that is not a non-empty String,
  #   or a now that is not an Integer, a Time or nil
  #
  # @example
  #   UXID.decode("usr_01hf7yat00")
  #   # => #<data UXID::Decoded prefix="usr", size=:xs, compact=false, deterministic=false, time=1700000000000>
  #   UXID.decode("cus_zt9vnyfd85bff0").deterministic? # => true
  #   UXID.decode("usr_01hf7yat0").reason              # => :invalid_length
  def self.decode(id, delimiter: "_", now: nil)
    Decoder.decode(id, delimiter, now)
  end

  # Whether an id decodes (see UXID.decode) and, when :prefix is given, has
  # exactly that prefix. Never raises on the id: anything UXID.decode
  # refuses, a value that is not a String included, is false.
  #
  # @param id [Object] the id to check
  # @param prefix [String, nil] (nil) the prefix the id must have; nil and
  #   the empty string accept any prefix or none
  # @param delimiter [String] ("_") the non-empty string between prefix and
  #   body
  # @return [Boolean]
  # @raise [ArgumentError] for a delimiter that is not a non-empty String
  #
  # @example
  #   UXID.valid?("cus_zt9vnyfd85bff0")                 # => true
  #   UXID.valid?("cus_zt9vnyfd85bff0", prefix: "usr")  # => false
  #   UXID.valid?("usr_01hu7yat00")                     # => false
  def self.valid?(id, prefix: nil, delimiter: "_")
    decoded = Decoder.decode(id, delimiter, nil)
    decoded.valid? && (prefix.nil? || prefix.empty? || decoded.prefix == prefix)
  end

  # Whether an id decodes (see UXID.decode) to a deterministic body, one
  # generated with :from. Never raises on the id: anything UXID.decode
  # refuses, a value that is not a String included, is false.
  #
  # @param id [Object] the id to check
  # @param delimiter [String] ("_") the non-empty string between prefix and
  #   body
  # @return [Boolean]
  # @raise [ArgumentError] for a delimiter that is not a non-empty String
  #
  # @example
  #   UXID.deterministic?("cus_zt9vnyfd85bff0") # => true
  #   UXID.deterministic?("usr_01hf7yat00")     # => false
  def self.deterministic?(id, delimiter: "_")
    decoded = Decoder.decode(id, delimiter, nil)
    decoded.valid? && decoded.deterministic?
  end
end
