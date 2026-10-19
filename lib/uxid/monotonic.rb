# frozen_string_literal: true

module UXID
  # A monotonic generator: ids from one generator, for one prefix and random
  # width, increase strictly, also within one millisecond and when the clock
  # moves back. It follows the "Monotonic generation" rule of uxid-ex's
  # wire-format spec. A monotonic id is an ordinary time-based id of its size;
  # nothing in it says how it was made, and UXID.decode reads it as any other.
  #
  # The generator keeps, for each prefix and random width it has generated
  # for, the last time T and the last random value R (the random field read
  # as one big-endian unsigned integer of w bytes). For a call at the current
  # time:
  #
  # 1. with no state for its prefix and width, or a time later than T, the
  #    random field is a fresh random value (a seed) and the id carries the
  #    current time;
  # 2. with a time equal to or earlier than T, the id carries T and R + step,
  #    the step drawn uniformly from 1 to 2**(4w);
  # 3. when R + step is 2**(8w) or more, the id carries T + 1 and a fresh
  #    seed instead.
  #
  # The step is not a plus-one counter: it spreads consecutive ids over a
  # window of 2**(4w) values, which stops trivial enumeration but is not
  # unpredictability. Low-entropy sizes stay low-entropy.
  #
  # The state belongs to the instance: two generators never share it, and
  # nothing is kept at class level or globally. A Mutex inside the instance
  # guards it, so one generator may be shared across threads and its ids
  # still increase strictly for each prefix and width. Ids from different
  # generators (one per thread, say) carry no such order between them.
  #
  # @example
  #   generator = UXID::Monotonic.new(prefix: "usr", size: :s)
  #   generator.generate(time: 1_700_000_000_000)  # => "usr_01hf7yat00...."
  #   generator.generate(time: 1_700_000_000_000)  # => a larger "usr_01hf7yat00...."
  #   generator.generate(prefix: "cus")            # => "cus_01..." (its own state)
  class Monotonic
    # The options of UXID.generate a monotonic generator takes. time is given
    # per call; from and rand are refused.
    STREAM_OPTIONS = %i[prefix size rand_size compact_time case delimiter byte_source].freeze
    private_constant :STREAM_OPTIONS

    # The sizes whose standard time leaves no random field: compact time is
    # their default here, so there is a field to step.
    XS_NAMES = %w[xs xsmall].freeze
    private_constant :XS_NAMES

    State = Data.define(:millis, :value)
    private_constant :State

    # Makes a generator. Every option is one of UXID.generate's, with its
    # meaning and its default there, and is the default of every call to
    # {#generate}, which may give any of them again.
    #
    # One default differs: size :xs (or :xsmall) uses compact time unless
    # :compact_time is given, because a standard xs has no random field to
    # step. {#generate} refuses an xs with compact_time: false, and any other
    # request whose random width is 0.
    #
    # @param prefix [String, nil] (nil) the prefix; nil and "" are both no
    #   prefix and share their state
    # @param size [Symbol, String] (:xl) the size, as UXID.generate takes it
    # @param draws [#seed, #step, nil] (nil) where the random values come
    #   from: any object whose seed(width) returns an Integer from 0 to
    #   2**(8 * width) - 1, the fresh value of a width-byte field, and whose
    #   step(width) returns an Integer from 1 to 2**(4 * width), drawn
    #   uniformly. For replaying recorded draws, such as the conformance
    #   corpus's, never as a source of randomness. A value outside its range
    #   raises ArgumentError and the state is left as it was. nil draws from
    #   the byte source: a seed is width bytes read big-endian, a step is the
    #   low 4 * width bits of ceil(4 * width / 8) bytes plus 1, so neither is
    #   biased. When draws is given the byte source is not called
    # @param options [Hash] the other options of UXID.generate except :time:
    #   :rand_size, :compact_time, :case, :delimiter and :byte_source
    # @raise [UXID::Error] :from_with_monotonic for a :from, and
    #   :rand_with_monotonic for a :rand, that is not nil: a monotonic
    #   generator makes neither a deterministic id nor one with a fixed random
    #   field
    # @raise [ArgumentError] for an unknown option, an option UXID.generate
    #   refuses, or a draws that does not respond to seed and step
    def initialize(prefix: nil, size: :xl, draws: nil, **options)
      refuse_body_sources(options)
      unless draws.nil? || (draws.respond_to?(:seed) && draws.respond_to?(:step))
        raise ArgumentError, "draws: must respond to seed(width) and step(width), or be nil, got: #{draws.inspect}"
      end

      @options = { prefix: prefix, size: size }.merge(options)
      check_keys(@options)
      Options.resolve(apply_xs_default(@options).merge(time: 0))
      @draws = draws
      @states = {}
      @mutex = Mutex.new
    end

    # Generates the next id: its time and random field follow the monotonic
    # rule above for the call's prefix and random width. Safe to call from
    # several threads at once on one generator.
    #
    # @param time [Integer, Time, nil] (nil) the current time, as UXID.generate
    #   takes it; nil reads the system clock. The id carries an earlier or
    #   later time when the rule says so
    # @param options [Hash] any option {#initialize} takes except :draws, in
    #   place of the generator's own for this call
    # @return [String] the id
    # @raise [UXID::Error] :from_with_monotonic and :rand_with_monotonic as
    #   for {#initialize}; :compact_time_out_of_range as for UXID.generate,
    #   for the time the id would carry
    # @raise [ArgumentError] for an option UXID.generate refuses, a request
    #   with no random field, a draw outside its range, or a step that would
    #   carry the time past 2**48 - 1. A call that raises leaves the state as
    #   it was
    #
    # @example
    #   generator = UXID::Monotonic.new(prefix: "usr")
    #   generator.generate                            # the system clock
    #   generator.generate(time: 1_700_000_000_000)   # a fixed time
    #   generator.generate(prefix: "cus", size: :m)   # another prefix and size
    def generate(time: nil, **options)
      refuse_body_sources(options)
      check_keys(options)
      request = Options.resolve(apply_xs_default(@options.merge(options)).merge(time: time))
      width = request.width
      raise ArgumentError, "a monotonic id needs a random field, but this request's random width is 0" if width.zero?

      @mutex.synchronize { next_id(request, width) }
    end

    private

    def refuse_body_sources(options)
      unless options[:from].nil?
        raise Error.new(:from_with_monotonic,
                        "from: cannot be used with monotonic generation: a deterministic id has no time or " \
                        "random field to order")
      end
      return if options[:rand].nil?

      raise Error.new(:rand_with_monotonic,
                      "rand: cannot be used with monotonic generation: the generator fills the random field")
    end

    def check_keys(options)
      unknown = options.keys - STREAM_OPTIONS - %i[from rand]
      return if unknown.empty?

      raise ArgumentError, "unknown keyword#{"s" if unknown.size > 1}: #{unknown.map(&:inspect).join(", ")}"
    end

    # Compact time for xs unless the caller set compact_time; nil from and
    # rand are dropped, as UXID.generate drops them.
    def apply_xs_default(options)
      options = options.except(:from, :rand)
      return options if options.key?(:compact_time) || !XS_NAMES.include?(options[:size].to_s)

      options.merge(compact_time: true)
    end

    # Runs under the mutex. The state is written only once the id is built,
    # so a call that raises leaves it as it was.
    def next_id(request, width)
      key = [request.prefix.to_s, width]
      state = advance(@states[key], request.millis, width, request.byte_source)
      unless state.millis <= Options::TIME_MAX
        raise ArgumentError, "time: a step past #{Options::TIME_MAX} ms would carry the id beyond the largest time"
      end

      id = Encoder.generate(request.with(millis: state.millis, rand: bytes(state.value, width)))
      @states[key] = state
      id
    end

    def advance(last, millis, width, byte_source)
      return State.new(millis: millis, value: seed(width, byte_source)) if last.nil? || millis > last.millis

      value = last.value + step(width, byte_source)
      return State.new(millis: last.millis, value: value) if value < (1 << (8 * width))

      State.new(millis: last.millis + 1, value: seed(width, byte_source))
    end

    def seed(width, byte_source)
      value = @draws.nil? ? integer(Encoder.draw(byte_source, width)) : @draws.seed(width)
      checked(value, 0, (1 << (8 * width)) - 1, "seed")
    end

    def step(width, byte_source)
      bits = 4 * width
      value =
        if @draws.nil?
          (integer(Encoder.draw(byte_source, (bits + 7) / 8)) & ((1 << bits) - 1)) + 1
        else
          @draws.step(width)
        end
      checked(value, 1, 1 << bits, "step")
    end

    # The value as width bytes, big-endian.
    def bytes(value, width)
      [value.to_s(16).rjust(width * 2, "0")].pack("H*")
    end

    def integer(bytes)
      bytes.unpack1("H*").to_i(16)
    end

    def checked(value, low, high, name)
      return value if value.is_a?(Integer) && value.between?(low, high)

      raise ArgumentError, "draws: #{name} must be an Integer from #{low} to #{high}, got: #{value.inspect}"
    end
  end
end
