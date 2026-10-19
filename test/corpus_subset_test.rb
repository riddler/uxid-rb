# frozen_string_literal: true

require "test_helper"
require "json"

# A hand-picked subset of the conformance corpus at uxid-ex v2.10.0, its lines
# copied byte for byte from conformance/encode.json, conformance/invalid.json
# and (every line of each) conformance/deterministic.json,
# conformance/decode.json and conformance/monotonic.json into test/fixtures/.
# The corpus runner, once the corpus is vendored under conformance/, runs
# every case; these hold the generator to the cases until then.
class CorpusSubsetTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures", __dir__)

  def self.cases(file)
    File.readlines(File.join(FIXTURES, file), chomp: true).map { |line| JSON.parse(line) }
  end

  # Builds UXID.generate's keywords from a case's input, spelt as the corpus
  # spells it: an absent option takes its default, rand is lowercase hex.
  def self.options(input)
    {
      prefix: input["prefix"],
      size: input["size"],
      compact_time: input["compact"],
      case: input["case"],
      time: input["time"],
      rand_size: input["rand_size"],
      rand: input["rand"] && [input["rand"]].pack("H*"),
      from: input["from"]
    }.compact
  end

  # Sabotage: swapping the lower- and upper-case alphabets turns every case red.
  cases("corpus_encode_subset.jsonl").each do |kase|
    define_method("test_#{kase["id"]}") do
      assert_equal kase["expected"], UXID.generate(**self.class.options(kase["input"])), kase["id"]
    end
  end

  # Sabotage: leaving the size out of the hash input turns every case red.
  cases("corpus_deterministic_subset.jsonl").each do |kase|
    define_method("test_#{kase["id"]}") do
      assert_equal kase["expected"], UXID.generate(**self.class.options(kase["input"])), kase["id"]
    end
  end

  # Makes a case's generate request: with "monotonic" true, a call to a
  # monotonic generator holding the request's options.
  def self.refused_request(request)
    options = options(request)
    return UXID.generate(**options) unless request["monotonic"]

    UXID::Monotonic.new.generate(**options)
  end

  # Sabotage: mapping every refusal to :rand_width_mismatch turns the others red.
  cases("corpus_generate_refusal_subset.jsonl").each do |kase|
    define_method("test_#{kase["id"]}") do
      error = assert_raises(UXID::Error, kase["id"]) { self.class.refused_request(kase["input"]["generate"]) }
      assert_equal kase["expected_error"].to_sym, error.code, kase["id"]
    end
  end

  # The draws a monotonic case carries, replayed as a draw source: the first
  # seed is initial_seed and the next (on the one overflow) overflow_seed;
  # each step is the next of steps (the corpus README, "Running the cases").
  class Replay
    def initialize(input)
      @seeds = [input["initial_seed"], input["overflow_seed"]].compact
      @steps = input["steps"].dup
    end

    def seed(_width) = @seeds.shift || raise("a seed drawn past the case's draws")
    def step(_width) = @steps.shift || raise("a step drawn past the case's draws")
    def spent? = @seeds.empty? && @steps.empty?
  end

  # Sabotage: adding the step to the time instead of keeping T turns every case with a step red.
  cases("corpus_monotonic_subset.jsonl").each do |kase|
    define_method("test_#{kase["id"]}") do
      input = kase["input"]
      draws = Replay.new(input)
      generator = UXID::Monotonic.new(prefix: input["prefix"], size: input["size"], compact_time: input["compact"],
                                      draws: draws)

      assert_equal kase["expected"], input["times"].map { |time| generator.generate(time: time) }, kase["id"]
      assert_predicate draws, :spent?, kase["id"]
    end
  end

  # A decoder clock inside the window every compact decode case holds for
  # (the corpus README, "Compact times and the decoder's clock").
  NOW = 1_700_000_000_000

  # Sabotage: reading the first time character's 5 bits, not its low 3, turns the reads-as-standard cases red.
  cases("corpus_decode_subset.jsonl").each do |kase|
    define_method("test_#{kase["id"]}") do
      decoded = UXID.decode(kase["input"], now: NOW)
      actual = decoded.valid? &&
               { "prefix" => decoded.prefix, "size" => decoded.size.to_s, "compact" => decoded.compact?,
                 "deterministic" => decoded.deterministic?, "time" => decoded.time }

      assert_equal kase["expected"], actual, kase["id"]
    end
  end

  # Sabotage: checking the characters before the length turns invalid/decode-length-and-character red.
  cases("corpus_decode_refusal_subset.jsonl").each do |kase|
    define_method("test_#{kase["id"]}") do
      assert_equal UXID::Invalid.new(reason: kase["expected_error"].to_sym), UXID.decode(kase["input"]["decode"]),
                   kase["id"]
    end
  end

  def encode_inputs(key)
    self.class.cases("corpus_encode_subset.jsonl").to_set { |kase| kase["input"][key] }
  end

  # Sabotage: dropping the upper-case lines from the encode fixture turns this red.
  def test_the_encode_subset_covers_every_size_mode_case_and_prefix_form
    assert_equal %w[xs s m l xl].to_set, encode_inputs("size")
    assert_equal [false, true].to_set, encode_inputs("compact")
    assert_equal %w[lower upper].to_set, encode_inputs("case")
    assert_equal ["", "a_b", "cus", "usr", nil].to_set, encode_inputs("prefix")
  end

  # Sabotage: dropping the four empty-body lines from the decode refusal fixture turns this red.
  def test_the_decode_refusal_subset_covers_every_reason
    reasons = self.class.cases("corpus_decode_refusal_subset.jsonl").to_set { |kase| kase["expected_error"] }

    assert_equal %w[empty invalid_character invalid_length].to_set, reasons
  end

  # Sabotage: dropping the rand_size line from the refusal fixture turns this red.
  def test_the_refusal_subset_covers_every_refusal_this_generator_raises
    errors = self.class.cases("corpus_generate_refusal_subset.jsonl").to_set { |kase| kase["expected_error"] }

    expected = %w[compact_time_out_of_range from_with_monotonic rand_size_too_large rand_width_mismatch rand_with_from
                  rand_with_monotonic]

    assert_equal expected.to_set, errors
  end
end
