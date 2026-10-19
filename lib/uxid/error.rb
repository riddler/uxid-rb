# frozen_string_literal: true

module UXID
  # A generation request the wire format refuses: options that contradict each
  # other or the format. {#code} names the refusal with the name the wire-format
  # spec and its conformance corpus give it; the message is for people and may
  # change.
  #
  # It is an ArgumentError, so a caller that rescues ArgumentError also catches
  # the options UXID.generate refuses for other reasons (an unknown size, a
  # time out of range), which carry no code.
  #
  # @example
  #   begin
  #     UXID.generate(prefix: "usr", rand_size: 11)
  #   rescue UXID::Error => e
  #     e.code # => :rand_size_too_large
  #   end
  class Error < ArgumentError
    # The refusal's name, one of :compact_time_out_of_range,
    # :rand_width_mismatch, :rand_size_too_large, :rand_with_from,
    # :from_with_monotonic and :rand_with_monotonic (the last two from
    # UXID::Monotonic).
    #
    # @return [Symbol]
    attr_reader :code

    # @param code [Symbol] the refusal's name
    # @param message [String] a description for people
    def initialize(code, message)
      @code = code
      super(message)
    end
  end
end
