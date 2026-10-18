///|
/// Precompiled cardinal rules. Parsing happens once when the module loads.
let cached_cardinal : Array[(String, PluralRules)] = [
  ("en", PluralRules::new("en")),
  ("zh", PluralRules::new("zh")),
  ("de", PluralRules::new("de")),
  ("ja", PluralRules::new("ja")),
  ("fr", PluralRules::new("fr")),
  ("ar", PluralRules::new("ar")),
]

///|
/// Precompiled ordinal rules.
let cached_ordinal : Array[(String, PluralRules)] = [
  ("en", PluralRules::new("en", ordinal=true)),
  ("zh", PluralRules::new("zh", ordinal=true)),
  ("de", PluralRules::new("de", ordinal=true)),
  ("ja", PluralRules::new("ja", ordinal=true)),
  ("fr", PluralRules::new("fr", ordinal=true)),
  ("ar", PluralRules::new("ar", ordinal=true)),
]

///|
/// Return a shared, already parsed rule set.
///
/// Prefer this over `PluralRules::new` in hot paths. Languages outside the
/// bundled set fall back to a freshly parsed rule set.
pub fn PluralRules::cached(language : String, ordinal? : Bool) -> PluralRules {
  let use_ordinal = ordinal.unwrap_or(false)
  let table = if use_ordinal { cached_ordinal } else { cached_cardinal }
  for entry in table {
    if entry.0 == language {
      return entry.1
    }
  }
  PluralRules::new(language, ordinal=use_ordinal)
}
