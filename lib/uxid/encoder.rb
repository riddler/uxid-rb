# frozen_string_literal: true

require "digest"
require "securerandom"

module UXID
  # Builds a time body and its id from resolved options. Internal: the public
  # entry point is UXID.generate, which documents every option.
  module Encoder
    LOWER = "0123456789abcdefghjkmnpqrstvwxyz"
    UPPER = LOWER.upcase.freeze

    COMPACT_BITS = 40
    COMPACT_MASK = (2**COMPACT_BITS) - 1
    MARKER = 31

    module_function

    # @param request [Options::Resolved, Options::Deterministic]
    # @return [String] the id
    def generate(request)
      body = request.is_a?(Options::Deterministic) ? deterministic_body(request) : body(request)
      prefix = request.prefix
      prefix.nil? || prefix.empty? ? body : "#{prefix}#{request.delimiter}#{body}"
    end

    # The marker, then the first count x 5 bits of the SHA-256 of
    # prefix || 0x00 || from || 0x00 || count, as count characters. The
    # prefix and count are in the hash so that the same string under another
    # prefix or at another size gives an unrelated body; case is not.
    def deterministic_body(request)
      alphabet = request.upper ? UPPER : LOWER
      alphabet[MARKER] + encode_groups(hash_bits(request), request.count, alphabet)
    end

    # The digest's first count x 5 bits, as an Integer.
    def hash_bits(request)
      input = [hashed_bytes(request.prefix.to_s), hashed_bytes(request.from), request.count]
      digest = Digest::SHA256.digest(input.pack("a*xa*xC"))
      digest.unpack1("H*").to_i(16) >> ((digest.bytesize * 8) - (request.count * 5))
    end

    def body(request)
      alphabet = request.upper ? UPPER : LOWER
      bytes = request.rand.nil? ? draw(request.byte_source, request.width) : fixed(request.rand, request.width)
      encode_time(request.millis, request.compact_time, alphabet) + encode_rand(bytes, alphabet)
    end

    def draw(byte_source, width)
      bytes = byte_source.nil? ? SecureRandom.random_bytes(width) : byte_source.call(width)
      return bytes.b if bytes.is_a?(String) && bytes.bytesize == width

      raise ArgumentError, "byte_source: must return a String of #{width} bytes, got: #{bytes.inspect}"
    end

    def fixed(rand, width)
      return rand.b if rand.bytesize == width

      raise Error.new(:rand_width_mismatch,
                      "rand: must be exactly #{width} bytes for this call (the random field's width), " \
                      "got: #{rand.bytesize}")
    end

    # The bytes hashed for a string. Valid text in an encoding other than
    # UTF-8 is transcoded to UTF-8 first, so the same text gives the same
    # bytes whatever its encoding. A binary (ASCII-8BIT) string, a string
    # that is not valid in its own encoding, and one Ruby cannot transcode
    # are hashed as their own bytes, as the wire format's "the input
    # string's bytes" reads.
    def hashed_bytes(string)
      # A UTF-8 string, invalid or not, is returned unchanged; binary bytes
      # above 0x7f, invalid bytes in another encoding and an encoding with
      # no converter raise, and the string's own bytes are hashed.
      string.encode(Encoding::UTF_8).b
    rescue EncodingError
      string.b
    end

    # Standard time: 48 bits in 10 characters, the first holding 3 bits.
    # Compact time: the low 40 bits in 8 characters.
    def encode_time(millis, compact_time, alphabet)
      return encode_groups(millis, 10, alphabet) unless compact_time

      compact = millis & COMPACT_MASK
      if compact >> (COMPACT_BITS - 5) == MARKER
        raise Error.new(:compact_time_out_of_range,
                        "compact_time: cannot encode #{millis}: its first character would be the " \
                        "deterministic marker; use standard time")
      end
      encode_groups(compact, 8, alphabet)
    end

    # The random field, most significant bit first in 5-bit groups; the short
    # group is the last one and is written as its raw value, never padded.
    def encode_rand(bytes, alphabet)
      bits = bytes.bytesize * 8
      value = bytes.empty? ? 0 : bytes.unpack1("H*").to_i(16)
      short = bits % 5
      encoded = encode_groups(value >> short, bits / 5, alphabet)
      short.zero? ? encoded : encoded << alphabet[value & ((1 << short) - 1)]
    end

    def encode_groups(value, count, alphabet)
      (count - 1).downto(0).each_with_object(String.new(capacity: count, encoding: Encoding::UTF_8)) do |index, out|
        out << alphabet[(value >> (5 * index)) & 31]
      end
    end
  end

  private_constant :Encoder
end
