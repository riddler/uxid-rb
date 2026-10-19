# frozen_string_literal: true

module UXID
  # What UXID.decode reads from a well-formed id: its prefix, its size and
  # time form, whether it is deterministic, and its time. The random field is
  # not read back. A frozen value: two decodings of the same id are equal.
  #
  # @!attribute [r] prefix
  #   @return [String, nil] everything before the last delimiter, nil when the
  #     id has no delimiter; an id that starts with the delimiter (not one a
  #     producer emits) has the empty string, which reads as no prefix
  # @!attribute [r] size
  #   @return [Symbol] the size the body length gives: :xs, :s, :m, :l or :xl
  # @!attribute [r] compact
  #   @return [Boolean] whether the body length is a compact one; see
  #     {#compact?}
  # @!attribute [r] deterministic
  #   @return [Boolean] whether the body starts with the marker z or Z; see
  #     {#deterministic?}
  # @!attribute [r] time
  #   @return [Integer, nil] the time in milliseconds since the Unix epoch, nil
  #     for a deterministic body. A compact time's high bits come from the
  #     decoder's clock (UXID.decode's :now)
  Decoded = Data.define(:prefix, :size, :compact, :deterministic, :time) do
    # @return [true] a decoded id is always valid; {Invalid#valid?} is false,
    #   so a caller can branch on the result without a type check
    def valid?
      true
    end

    # @return [Boolean] whether the body length is a compact one
    def compact?
      compact
    end

    # @return [Boolean] whether the body is deterministic (no time)
    def deterministic?
      deterministic
    end
  end

  # What UXID.decode answers for a string it refuses: the reason, named as
  # the wire-format spec and its conformance corpus name it. A frozen value.
  #
  # @!attribute [r] reason
  #   @return [Symbol] :empty, :invalid_length or :invalid_character
  Invalid = Data.define(:reason) do
    # @return [false] a refused id is never valid; {Decoded#valid?} is true
    def valid?
      false
    end
  end
end
