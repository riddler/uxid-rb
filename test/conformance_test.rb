# frozen_string_literal: true

require "test_helper"
require "json"

# Every case of the conformance corpus vendored under conformance/ (uxid-ex
# at the tag conformance/SOURCE.json names), one test per case, run by its
# kind as the corpus README's "Running the cases" says. The case files are
# read through the manifest, so a file or a case the manifest lists is run;
# nothing is skipped. `rake corpus:check` checks the files' hash and line
# counts; this file runs what they hold.
class ConformanceTest < Minitest::Test
  CORPUS = File.expand_path("../conformance", __dir__)
  MANIFEST = JSON.parse(File.read(File.join(CORPUS, "manifest.json")))

  # A decoder clock inside the window every compact decode case holds for
  # (the corpus README, "Compact times and the decoder's clock").
  NOW = 1_700_000_000_000

  def self.cases(file)
    File.readlines(File.join(CORPUS, file), chomp: true).map { |line| JSON.parse(line) }
  end

  # Every case id in the corpus, in manifest order.
  def self.case_ids
    MANIFEST["files"].flat_map { |entry| cases(entry["file"]).map { |kase| kase["id"] } }
  end

  # Builds UXID.generate's keywords from a case's input, spelt as the corpus
  # spells it: an absent option takes its default, rand is lowercase hex, and
  # a prefix written null is no prefix.
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

  # Makes an invalid case's generate request: with "monotonic" true, a call
  # to a monotonic generator holding the request's options.
  def self.refused_request(request)
    options = options(request)
    return UXID.generate(**options) unless request["monotonic"]

    UXID::Monotonic.new.generate(**options)
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

  # Sabotage: swapping the lower- and upper-case alphabets turns every encode case whose body holds a letter red.
  def run_encode(kase)
    assert_equal kase["expected"], UXID.generate(**self.class.options(kase["input"])), kase["id"]
  end

  # Sabotage: leaving the size out of the hash input turns every deterministic case red.
  def run_deterministic(kase)
    assert_equal kase["expected"], UXID.generate(**self.class.options(kase["input"])), kase["id"]
  end

  # Sabotage: reading the first time character's 5 bits, not its low 3, turns the reads-as-standard cases red.
  def run_decode(kase)
    decoded = UXID.decode(kase["input"], now: NOW)
    actual = decoded.valid? &&
             { "prefix" => decoded.prefix, "size" => decoded.size.to_s, "compact" => decoded.compact?,
               "deterministic" => decoded.deterministic?, "time" => decoded.time }

    assert_equal kase["expected"], actual, kase["id"]
  end

  # An invalid case refuses either a string to decode or a generate request.
  def run_invalid(kase)
    input = kase["input"]
    error = kase["expected_error"].to_sym
    return refuses_decode(input["decode"], error, kase["id"]) if input.key?("decode")

    refuses_generate(input, error, kase["id"])
  end

  # Sabotage: checking the characters before the length turns invalid/decode-length-and-character red.
  def refuses_decode(string, reason, id)
    assert_equal UXID::Invalid.new(reason: reason), UXID.decode(string, now: NOW), id
  end

  # Sabotage: mapping every generation refusal to :rand_width_mismatch turns the other generate cases red.
  def refuses_generate(input, code, id)
    error = assert_raises(UXID::Error, id) { self.class.refused_request(input.fetch("generate")) }
    assert_equal code, error.code, id
  end

  # Sabotage: moving a kept time to the next millisecond turns every monotonic case with a step red.
  def run_monotonic(kase)
    input = kase["input"]
    draws = Replay.new(input)
    generator = UXID::Monotonic.new(prefix: input["prefix"], size: input["size"], compact_time: input["compact"],
                                    draws: draws)

    assert_equal kase["expected"], input["times"].map { |time| generator.generate(time: time) }, kase["id"]
    assert_predicate draws, :spent?, kase["id"]
  end

  MANIFEST["files"].each do |entry|
    cases(entry["file"]).each do |kase|
      define_method("test_#{kase["id"]}") { send(:"run_#{entry["kind"]}", kase) }
    end
  end

  # A case id seen twice would define its test twice, the second replacing the first.
  # Sabotage: defining the tests from the first four files only turns this red.
  def test_one_test_per_case
    ids = self.class.case_ids
    tests = self.class.public_instance_methods(false).grep(%r{\Atest_[a-z]+/})

    assert_equal ids.size, ids.uniq.size
    assert_equal ids.map { |id| :"test_#{id}" }.sort, tests.sort
  end
end
