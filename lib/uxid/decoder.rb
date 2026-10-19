# frozen_string_literal: true

module UXID
  # Reads an id back to a Decoded, or refuses it with an Invalid. Internal:
  # the public entry point is UXID.decode, which documents the reading.
  module Decoder
    # Body length in bytes to the size and whether the time is compact. The
    # lengths 10 and 18 are also those of compact xs and compact m; the wire
    # format reads both as standard.
    LENGTHS = {
      10 => [:xs, false], 13 => [:s, true], 14 => [:s, false], 18 => [:m, false],
      21 => [:l, true], 22 => [:l, false], 24 => [:xl, true], 26 => [:xl, false]
    }.freeze

    # Each byte of the alphabet, in either case, to its 5-bit value.
    VALUES = (Encoder::LOWER.bytes.each_with_index.to_a + Encoder::UPPER.bytes.each_with_index.to_a).to_h.freeze

    MARKERS = ["z".ord, "Z".ord].freeze
    COMPACT_WINDOW = 2**40
    ONE_DAY = 86_400_000

    module_function

    # @param id [Object] the id; anything other than a String is refused
    # @param delimiter [String] the non-empty string between prefix and body
    # @param now [Integer, Time, nil] the decoder's clock for a compact time
    # @return [Decoded, Invalid]
    def decode(id, delimiter, now)
      check_options(delimiter, now)
      return Invalid.new(reason: :invalid_character) unless id.is_a?(String)

      prefix, body = split(id, delimiter)
      reason = refusal(body)
      reason ? Invalid.new(reason: reason) : decoded(prefix, body, now)
    end

    def check_options(delimiter, now)
      unless delimiter.is_a?(String) && !delimiter.empty?
        raise ArgumentError, "delimiter: must be a non-empty String, got: #{delimiter.inspect}"
      end
      return if now.nil? || now.is_a?(Integer) || now.is_a?(Time)

      raise ArgumentError, "now: must be an Integer of milliseconds, a Time or nil, got: #{now.inspect}"
    end

    # The body is everything after the last delimiter and the prefix
    # everything before it; with no delimiter the whole id is the body. The
    # split is on bytes, so an id that is not valid in its encoding splits
    # without raising; the prefix keeps the id's encoding.
    def split(id, delimiter)
      bytes = id.b
      at = bytes.rindex(delimiter.b)
      return [nil, bytes] if at.nil?

      prefix = bytes.byteslice(0, at).force_encoding(id.encoding).freeze
      [prefix, bytes.byteslice(at + delimiter.bytesize, bytes.bytesize)]
    end

    # The first rule the body fails, in the spec's order, or nil when it is
    # well formed. Lengths are in bytes.
    def refusal(body)
      return :empty if body.empty?
      return :invalid_length unless LENGTHS.key?(body.bytesize)

      :invalid_character unless body.each_byte.all? { |byte| VALUES.key?(byte) }
    end

    def decoded(prefix, body, now)
      size, compact = LENGTHS.fetch(body.bytesize)
      deterministic = MARKERS.include?(body.getbyte(0))
      time =
        if deterministic then nil
        elsif compact then compact_time(value(body, 8), now)
        else standard_time(body)
        end
      Decoded.new(prefix: prefix, size: size, compact: compact, deterministic: deterministic, time: time)
    end

    # The first 10 characters, the first holding the time's top 3 bits; the
    # first character's higher bits are not read.
    def standard_time(body)
      ((VALUES.fetch(body.getbyte(0)) & 7) << 45) | value(body.byteslice(1, 9), 9)
    end

    # The low 40 bits from the id and the rest from the clock; a result more
    # than a day ahead of the clock is from the window before.
    def compact_time(low, now)
      clock = millis(now)
      time = ((clock >> 40) << 40) | low
      time - clock > ONE_DAY ? time - COMPACT_WINDOW : time
    end

    def value(body, count)
      body.each_byte.first(count).reduce(0) { |acc, byte| (acc << 5) | VALUES.fetch(byte) }
    end

    def millis(now)
      case now
      when nil then Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
      when Time then (now.to_r * 1000).floor
      else now
      end
    end
  end

  private_constant :Decoder
end
