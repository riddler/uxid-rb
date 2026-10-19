### Upcoming

* (Nothing yet)


### 1.0.0 / 2026-10-19

A rewrite of the gem under its existing name, and a breaking release: the
0.2.x API is gone. The gem now implements the wire format of the Elixir
reference implementation, [uxid-ex](https://github.com/riddler/uxid-ex), and
passes every case of that implementation's conformance corpus at the tag
`v2.10.0`, vendored under `conformance/` (`conformance/SOURCE.json` records the
tag, its commit and the corpus hash). An ID written by 0.2 with a symbol size
has the layout of the same size in 1.0 apart from its case: 0.2 wrote upper
case and 1.0 writes lowercase by default (`case: :upper` keeps upper case), and
`UXID.decode` reads either case. To stay on 0.2, pin `gem "uxid", "~> 0.2"`;
the README's "Upgrading from 0.2" lists what changes for a caller.

**Added**

* `UXID.generate(from: "...")` builds a deterministic id: the marker `z` (`Z` in an upper-case id) and then the first bits of the SHA-256 of the prefix, the `from` string and the size, as uxid-ex's wire format defines it, so the same arguments always give the same id and it sorts after every time-based id with its prefix and case. `from` (and the prefix) are hashed as their bytes: valid text in an encoding other than UTF-8 is transcoded to UTF-8 first, and a binary String, one not valid in its own encoding, or one Ruby cannot transcode is hashed as its own bytes, so a raw-byte key such as a 16-byte UUID works. `rand:` with `from:` raises `UXID::Error` with code `:rand_with_from`; the time and random-field options do not apply to a deterministic id and are not read.
* `UXID.decode(id, delimiter: "_", now: nil)` reads an id back as uxid-ex's wire format defines it and never raises on malformed input. A well-formed id gives a frozen `UXID::Decoded` with `prefix` (nil when there is no delimiter), `size` (`:xs` to `:xl`), `compact?`, `deterministic?` and `time` (milliseconds, nil for a deterministic id); the random field is not read back. Anything else gives a frozen `UXID::Invalid` whose `reason` is `:empty`, `:invalid_length` or `:invalid_character`, the first rule the body fails in that order, with lengths counted in bytes; a value that is not a String is `:invalid_character`. Both answer `valid?`. Body lengths 10 and 18 are read as standard xs and standard m, so a compact xs or compact m id decodes to its size but not its time. A compact time takes its high bits from `now:` (default the system clock), less 2**40 ms when that puts it more than a day ahead.
* `UXID.valid?(id, prefix: nil, delimiter: "_")` is whether the id decodes and, when `prefix:` is given, has exactly that prefix; `UXID.deterministic?(id, delimiter: "_")` is whether it decodes to a deterministic body. Neither raises on the id.
* `UXID::Monotonic.new(prefix: nil, size: :xl, draws: nil, **options)` is a monotonic generator, and its `#generate(time: nil, **options)` gives ids that increase strictly for each prefix and random width, within one millisecond and when the clock moves back, by the monotonic rule of uxid-ex's wire format: a later time takes a fresh random value, an equal or earlier one keeps the last time and adds a step drawn uniformly from 1 to 2**(4w), and a step that overflows the field moves to the next millisecond with a fresh value. The options are `UXID.generate`'s; those given to `new` are the defaults of every call. Size `:xs` uses compact time unless `compact_time:` is given, and a request with no random field is refused. The state belongs to the instance, guarded by a Mutex inside it, so one generator may be shared across threads; nothing is kept at class level or globally. Random values come from the byte source (default `SecureRandom`), or from `draws:`, an object answering `seed(width)` and `step(width)`, for replaying recorded draws. `from:` raises `UXID::Error` with code `:from_with_monotonic`, and `rand:` with `:rand_with_monotonic`.

**Changed**

* Breaking: `UXID.generate` now builds the id uxid-ex's wire format defines, from the keyword options prefix, size, rand_size, compact_time, case, delimiter and time; 0.2.x ids are not reproduced, so callers re-read the option list in the method's doc. Random bytes come from an injectable `byte_source` (default `SecureRandom.random_bytes`), and `rand:` fixes the random field for test vectors only. A refused request raises `UXID::Error`, an `ArgumentError` whose `#code` names the refusal.
* Breaking: Ruby 3.2 or later is required, where 0.2 asked for 2.3; stay on 0.2 on an older Ruby.

**Removed**

* Breaking: `UXID.new`, `UXID::Model` and the 0.2 encoder class and constants are removed, and `UXID.generate` no longer takes a Hash; call `UXID.generate` with keyword options, or pin `~> 0.2`.


### 0.2.3 / 2020-11-29

* Updates project URL


### 0.2.2 / 2020-11-25

* Uses Ruby path for Gemspec homepage
* Adds more tests around generation using size option


### 0.2.1 / 2020-11-25

* Removes extra chars from generation
* Adds tests around generation of sizes


## 0.2.0 / 2020-11-24

* Deprecates :size option with integers
* Adds T-Shirt sizes (:size option)
* Adds :rand_size option (:rand_size option)


## 0.1.0 / 2020-11-08

* Adds basic UXID generation


## 0.0.1 / 2020-06-17

* Birthday!
