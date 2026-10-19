# frozen_string_literal: true

require_relative "uxid/version"
require_relative "uxid/error"
require_relative "uxid/options"
require_relative "uxid/encoder"

# Prefixed, K-sortable identifiers, wire-compatible with the Elixir
# reference implementation of uxid.
module UXID
  # Generates a time-based id: an optional prefix and delimiter, then a body
  # of a time field and a random field in Crockford Base32, laid out as
  # uxid-ex's wire-format spec defines it.
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
  # @return [String] the id
  # @raise [UXID::Error] a refusal the wire format names, with its
  #   {UXID::Error#code}: :rand_size_too_large for a :rand_size above 10,
  #   :rand_width_mismatch for a :rand whose byte size is not the random
  #   width, :compact_time_out_of_range for a compact time whose first
  #   character would be the deterministic marker
  # @raise [ArgumentError] any other option outside the ones above
  #
  # @example
  #   UXID.generate(prefix: "usr")             # => "usr_01..." (26 body characters)
  #   UXID.generate(prefix: "cus", size: :s)   # => "cus_01..." (14 body characters)
  #   UXID.generate(prefix: "usr", size: :xs, time: 1_700_000_000_000)
  #   # => "usr_01hf7yat00"
  def self.generate(**options)
    Encoder.generate(Options.resolve(options))
  end
end
