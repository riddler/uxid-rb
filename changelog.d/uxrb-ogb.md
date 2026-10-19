### Changed

* Breaking: `UXID.generate` now builds the id uxid-ex's wire format defines, from the keyword options prefix, size, rand_size, compact_time, case, delimiter and time; 0.2.x ids are not reproduced, so callers re-read the option list in the method's doc. Random bytes come from an injectable `byte_source` (default `SecureRandom.random_bytes`), and `rand:` fixes the random field for test vectors only. A refused request raises `UXID::Error`, an `ArgumentError` whose `#code` names the refusal.
