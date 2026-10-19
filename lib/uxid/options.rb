# frozen_string_literal: true

module UXID
  # Checks UXID.generate's options and resolves them to what the encoder
  # needs. Internal: UXID.generate documents every option.
  module Options
    DEFAULTS = {
      prefix: nil, size: :xl, rand_size: nil, compact_time: false, case: :lower,
      delimiter: "_", time: nil, rand: nil, byte_source: nil
    }.freeze

    SIZES = {
      xs: :xs, xsmall: :xs, s: :s, small: :s, m: :m, medium: :m,
      l: :l, large: :l, xl: :xl, xlarge: :xl
    }.freeze

    # Random field bytes per size, standard time then compact time.
    RAND_BYTES = {
      xs: [0, 1], s: [2, 3], m: [5, 6], l: [7, 8], xl: [10, 10]
    }.freeze

    MAX_RAND_BYTES = 10
    TIME_MAX = (2**48) - 1

    # What the encoder reads: the checked options, the time in milliseconds
    # and the random field's width in bytes.
    Resolved = Data.define(:prefix, :delimiter, :upper, :compact_time, :millis, :width, :rand, :byte_source)

    module_function

    # @return [Resolved]
    def resolve(options)
      check_keys(options)
      options = DEFAULTS.merge(options)
      check_types(options)
      Resolved.new(
        prefix: options[:prefix], delimiter: options[:delimiter], upper: upper?(options[:case]),
        compact_time: options[:compact_time], millis: millis_for(options[:time]), width: width(options),
        rand: options[:rand], byte_source: options[:byte_source]
      )
    end

    def width(options)
      width_for(size_for(options[:size]), options[:compact_time], options[:rand_size])
    end

    def check_keys(options)
      unknown = options.keys - DEFAULTS.keys
      return if unknown.empty?

      raise ArgumentError, "unknown keyword#{"s" if unknown.size > 1}: #{unknown.map(&:inspect).join(", ")}"
    end

    def check_types(options)
      check(options, :prefix, "a String or nil") { |value| value.nil? || value.is_a?(String) }
      check(options, :delimiter, "a non-empty String") { |value| value.is_a?(String) && !value.empty? }
      check(options, :compact_time, "true or false") { |value| [true, false].include?(value) }
      check(options, :rand, "a String of bytes or nil") { |value| value.nil? || value.is_a?(String) }
      check(options, :byte_source, "an object responding to call(count), or nil") do |value|
        value.nil? || value.respond_to?(:call)
      end
    end

    def check(options, key, expected)
      return if yield(options[key])

      raise ArgumentError, "#{key}: must be #{expected}, got: #{options[key].inspect}"
    end

    def upper?(letter_case)
      case letter_case.to_s
      when "lower" then false
      when "upper" then true
      else raise ArgumentError, "case: must be :lower or :upper, got: #{letter_case.inspect}"
      end
    end

    def size_for(size)
      SIZES.fetch(size.to_s.to_sym) do
        raise ArgumentError, "size: must be one of #{SIZES.keys.join(", ")}, got: #{size.inspect}"
      end
    end

    def millis_for(time)
      millis =
        case time
        when nil then Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
        when Time then (time.to_r * 1000).floor
        when Integer then time
        else raise ArgumentError, "time: must be an Integer of milliseconds or a Time, got: #{time.inspect}"
        end
      return millis if millis.between?(0, TIME_MAX)

      raise ArgumentError, "time: must be from 0 to 2**48 - 1 milliseconds, got: #{millis}"
    end

    def width_for(size, compact_time, rand_size)
      return RAND_BYTES.fetch(size)[compact_time ? 1 : 0] if rand_size.nil?

      unless rand_size.is_a?(Integer) && rand_size >= 0
        raise ArgumentError, "rand_size: must be a non-negative Integer, got: #{rand_size.inspect}"
      end
      return rand_size if rand_size <= MAX_RAND_BYTES

      raise Error.new(:rand_size_too_large, "rand_size: must be at most #{MAX_RAND_BYTES} bytes, got: #{rand_size}")
    end
  end

  private_constant :Options
end
