# UXID

[![MIT License][badge_license_url]](LICENSE)
[![CI][badge_ci_url]](https://github.com/riddler/uxid-rb/actions/workflows/ci.yml)
[![Gem Version][badge_version_url]](https://rubygems.org/gems/uxid)

User eXperience focused IDentifiers for Ruby: prefixed, K-sortable,
Stripe-style IDs a person can read, copy and route back to their resource. An
ID looks like `usr_01m5ahke2t2v9sczzafsbf0y2e`: the prefix names the resource,
and the body carries a timestamp and randomness in lowercase Crockford Base32.
The IDs are wire-compatible with the Elixir reference implementation,
[uxid-ex](https://github.com/riddler/uxid-ex), and the gem is checked against
that implementation's conformance corpus.

## Why UXID

An auto-increment key leaks how many rows a table holds and invites
enumeration; a random UUID fixes both but is long, unordered and anonymous, so
in a log line, a URL or a support thread nobody can tell what it points at, and
a double-click selects only part of it. A UXID names its resource in its
prefix, selects whole on a double-click, reads aloud without ambiguity, sorts
by creation time so it indexes well, and is generated in the application with
no coordination between nodes. Its size is tunable for low-cardinality
resources, a monotonic generator keeps a burst within one millisecond unique
and ordered, and a deterministic mode maps the same input to the same ID.

## Install

Add `uxid` to your Gemfile:

```ruby
gem "uxid"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install uxid

## Basic usage

```ruby
require "uxid"

# No options generates a plain ID: a time field and a random field
UXID.generate                                       # "01m5ahke2tebfrqcks88r0d5ta"

# A prefix names the resource
UXID.generate(prefix: "usr")                        # "usr_01m5ahke2t2v9sczzafsbf0y2e"

# Shrink the random part for low-cardinality resources
# Sizes: :xs :s :m :l :xl (or :xsmall :small :medium :large :xlarge)
UXID.generate(prefix: "cus", size: :small)          # "cus_01m5ahke2t2e40"

# Deterministic: the same input gives the same ID, with the prefix as namespace
UXID.generate(prefix: "usr", from: "alice@example.com")
# => "usr_zcvt7epac0t1ebcsjfyf7cwz25"

# Read an ID back, or check it
UXID.decode("usr_01hf7yat00")
# => #<data UXID::Decoded prefix="usr", size=:xs, compact=false, deterministic=false, time=1700000000000>
UXID.valid?("usr_01hf7yat00", prefix: "usr")        # => true
UXID.valid?("usr_01hf7yat00", prefix: "cus")        # => false
UXID.deterministic?("usr_zcvt7epac0t1ebcsjfyf7cwz25") # => true

# Monotonic: IDs from one generator increase strictly, also within one
# millisecond. You hold the generator; the gem keeps no global state.
generator = UXID::Monotonic.new(prefix: "usr", size: :s)
generator.generate                                  # "usr_01m5ahke2te6h0"
generator.generate                                  # a larger one
```

`UXID.decode` never raises on malformed input: it answers a `UXID::Invalid`
whose `reason` is `:empty`, `:invalid_length` or `:invalid_character`. A request
the wire format refuses, such as `rand_size: 11`, raises `UXID::Error`, an
`ArgumentError` whose `code` names the refusal.

## Upgrading from 0.2

Version 1.0.0 is a different format and API under the same gem name. It is a
breaking release, not an upgrade path for 0.2 code. To stay on 0.2, pin it:

```ruby
gem "uxid", "~> 0.2"
```

To move to 1.0:

- **The API is replaced.** `UXID.generate` takes keyword options (`prefix`,
  `size`, `rand_size`, `compact_time`, `case`, `delimiter`, `time`, `rand`,
  `byte_source`, `from`) and no longer takes a Hash. `UXID.new`, `UXID::Model`
  and the 0.2 encoder class and constants are gone. `UXID.decode`,
  `UXID.valid?`, `UXID.deterministic?` and `UXID::Monotonic` are new.
- **Sizes are symbols or their names.** An Integer `size` is refused with an
  `ArgumentError`; use `rand_size` for a specific number of random bytes, from
  0 to 10. A String `size` such as `"small"` was read by 0.2 as the largest
  size, with a warning; in 1.0 it means what the name says, so such a call
  gives a shorter ID and no error.
- **IDs are written in lowercase by default.** 0.2 wrote upper case. Pass
  `case: :upper` to keep writing it. `UXID.decode` reads either case.
- **Errors are `UXID::Error`.** It is an `ArgumentError`, where 0.2's was a
  `StandardError`, and its `code` names the refusal.
- **Ruby 3.2 or later** is required, where 0.2 asked for 2.3.
- **Stored IDs.** An ID written by 0.2 with a symbol size has the layout of the
  same size in 1.0, apart from its case, and `UXID.decode` reads it. Compare IDs
  in one case, or normalize them, if you mix the two.

## Compatibility

Ruby 3.2 or later (`required_ruby_version` in the gemspec). CI runs the test
suite on every Ruby minor from 3.2 up to the version `mise.toml` pins, and the
full quality gate on that pinned version. There are no runtime dependencies;
random bytes come from `SecureRandom` unless you give a `byte_source`. One
`UXID::Monotonic` instance may be shared across threads: its state is guarded
by a Mutex inside the instance, and nothing is kept at class level or globally.
IDs from different generators carry no order between them.

## Documentation

- Look up
  - Every public method and class carries a YARD doc comment in `lib/`:
    `UXID.generate`, `UXID.decode`, `UXID.valid?`, `UXID.deterministic?`,
    `UXID::Monotonic`, `UXID::Decoded`, `UXID::Invalid` and `UXID::Error`.
  - [UXID wire format][guide_wire_format_url]: the normative layout of an ID -
    alphabet, bit packing, sizes, prefix grammar, deterministic and monotonic
    bodies, and decoding - which this gem implements.
  - [The changelog](CHANGELOG.md): what changed in each version.
  - [The conformance corpus](conformance/README.md): the cases every
    implementation of the wire format passes, vendored here from uxid-ex.
- Understand
  - [Why a UXID has a prefix, a time and randomness][guide_why_url]: what each
    part of an ID is for, and what you trade when you tune it.
  - [Why monotonic mode exists and what it costs][guide_monotonic_url]:
    same-millisecond uniqueness and ordering, and the security tradeoff.
  - [_Designing APIs for humans: object IDs_][stripe_ids_url]: the Stripe ID
    design many of UXID's choices follow.

## Development

After checking out the repo, run `mise install` for the Ruby `mise.toml` pins
and `mise exec -- bundle install` for the development tools. Then
`mise exec -- bundle exec rake test` runs the tests, and
`mise exec -- bundle exec rake` runs the full gate: RuboCop, the corpus
integrity check and the tests under a coverage minimum.

A release is published by CI, never from a checkout: pushing a tag `vX.Y.Z`
that names `UXID::VERSION` runs `.github/workflows/release.yml`, which builds
and pushes the gem to [rubygems.org](https://rubygems.org). `rake release`
refuses to run anywhere else.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/riddler/uxid-rb.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

<!-- LINKS -->
[guide_wire_format_url]: https://hexdocs.pm/uxid/wire-format.html
[guide_why_url]: https://hexdocs.pm/uxid/why-prefix-time-randomness.html
[guide_monotonic_url]: https://hexdocs.pm/uxid/monotonic.html
[stripe_ids_url]: https://dev.to/stripe/designing-apis-for-humans-object-ids-3o5a

<!-- BADGES -->
[badge_license_url]: https://img.shields.io/badge/license-MIT-brightgreen.svg?cacheSeconds=3600?style=flat-square
[badge_ci_url]: https://github.com/riddler/uxid-rb/actions/workflows/ci.yml/badge.svg
[badge_version_url]: https://badge.fury.io/rb/uxid.svg
