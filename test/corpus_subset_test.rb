# frozen_string_literal: true

require "test_helper"
require "json"

# A hand-picked subset of the conformance corpus at uxid-ex v2.10.0, its lines
# copied byte for byte from conformance/encode.json and conformance/invalid.json
# into test/fixtures/. The corpus runner, once the corpus is vendored under
# conformance/, runs every case; these hold the generator to the cases until then.
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
      rand: input["rand"] && [input["rand"]].pack("H*")
    }.compact
  end

  # Sabotage: swapping the lower- and upper-case alphabets turns every case red.
  cases("corpus_encode_subset.jsonl").each do |kase|
    define_method("test_#{kase["id"]}") do
      assert_equal kase["expected"], UXID.generate(**self.class.options(kase["input"])), kase["id"]
    end
  end

  # Sabotage: mapping every refusal to :rand_width_mismatch turns the others red.
  cases("corpus_generate_refusal_subset.jsonl").each do |kase|
    define_method("test_#{kase["id"]}") do
      error = assert_raises(UXID::Error, kase["id"]) do
        UXID.generate(**self.class.options(kase["input"]["generate"]))
      end
      assert_equal kase["expected_error"].to_sym, error.code, kase["id"]
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

  # Sabotage: dropping the rand_size line from the refusal fixture turns this red.
  def test_the_refusal_subset_covers_every_refusal_this_generator_raises
    errors = self.class.cases("corpus_generate_refusal_subset.jsonl").to_set { |kase| kase["expected_error"] }

    assert_equal %w[compact_time_out_of_range rand_size_too_large rand_width_mismatch].to_set, errors
  end
end
