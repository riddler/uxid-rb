### Added

* `UXID.generate(from: "...")` builds a deterministic id: the marker `z` (`Z` in an upper-case id) and then the first bits of the SHA-256 of the prefix, the `from` string and the size, as uxid-ex's wire format defines it, so the same arguments always give the same id and it sorts after every time-based id with its prefix and case. `from` is hashed as its UTF-8 bytes; a String with no UTF-8 form is refused with `ArgumentError`. `rand:` with `from:` raises `UXID::Error` with code `:rand_with_from`; the time and random-field options do not apply to a deterministic id and are not read.
