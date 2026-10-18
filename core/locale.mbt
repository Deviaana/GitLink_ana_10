///|
/// A parsed BCP 47 locale identifier.
///
/// Only language, script and region participate in CLDR data lookup. Variants
/// and extensions are retained in canonical lowercase form so tags round-trip
/// through `to_tag`. A private-use section is stored at the end of `extensions`.
pub(all) struct Locale {
  language : String
  script : String
  region : String
  variants : String
  extensions : String
} derive(Debug, Eq, Hash)

///|
priv struct LanguageRange {
  tag : String
  locale : Locale?
  quality : Int
  order : Int
}

///|
fn is_ascii_alphanumeric(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit()
}

///|
fn all_ascii_alphabetic(text : StringView) -> Bool {
  for c in text.iter() {
    if !c.is_ascii_alphabetic() {
      return false
    }
  }
  true
}

///|
fn all_ascii_digits(text : StringView) -> Bool {
  for c in text.iter() {
    if !c.is_ascii_digit() {
      return false
    }
  }
  true
}

///|
fn all_ascii_alphanumeric(text : StringView) -> Bool {
  for c in text.iter() {
    if !is_ascii_alphanumeric(c) {
      return false
    }
  }
  true
}

///|
fn starts_with_digit(text : StringView) -> Bool {
  for c in text.iter() {
    return c.is_ascii_digit()
  }
  false
}

///|
fn is_language_subtag(text : StringView) -> Bool {
  let length = text.char_length()
  length >= 2 && length <= 8 && all_ascii_alphabetic(text)
}

///|
fn is_script_subtag(text : StringView) -> Bool {
  text.char_length() == 4 && all_ascii_alphabetic(text)
}

///|
fn is_region_subtag(text : StringView) -> Bool {
  let length = text.char_length()
  if length == 2 {
    all_ascii_alphabetic(text)
  } else if length == 3 {
    all_ascii_digits(text)
  } else {
    false
  }
}

///|
fn is_variant_subtag(text : StringView) -> Bool {
  let length = text.char_length()
  if length >= 5 && length <= 8 {
    all_ascii_alphanumeric(text)
  } else if length == 4 && starts_with_digit(text) {
    all_ascii_alphanumeric(text)
  } else {
    false
  }
}

///|
fn is_single_alphanumeric(text : StringView) -> Bool {
  if text.char_length() != 1 {
    return false
  }
  for c in text.iter() {
    return is_ascii_alphanumeric(c)
  }
  false
}

///|
fn is_extension_singleton(text : StringView) -> Bool {
  if text.char_length() != 1 {
    return false
  }
  for c in text.iter() {
    return is_ascii_alphanumeric(c) && c != 'x' && c != 'X'
  }
  false
}

///|
fn is_extension_subtag(text : StringView) -> Bool {
  let length = text.char_length()
  length >= 2 && length <= 8 && all_ascii_alphanumeric(text)
}

///|
fn is_private_use_subtag(text : StringView) -> Bool {
  let length = text.char_length()
  length >= 1 && length <= 8 && all_ascii_alphanumeric(text)
}

///|
fn join_subtags(parts : Array[String]) -> String {
  let builder = StringBuilder::new()
  let mut index = 0
  while index < parts.length() {
    if index > 0 {
      builder.write_stringview("-")
    }
    builder.write_stringview(parts[index])
    index = index + 1
  }
  builder.to_string()
}

///|
fn canonical_script(text : String) -> String {
  text[0:1].to_owned().to_upper() + text[1:text.length()].to_owned().to_lower()
}

///|
fn normalize_tag(tag : String) -> String {
  tag.trim().to_owned().replace_all(old="_", new="-")
}

///|
fn parse_strict(normalized : String) -> Locale? {
  if normalized.length() == 0 {
    return None
  }
  let tokens : Array[String] = []
  for token in normalized.split("-") {
    if token.length() == 0 {
      return None
    }
    tokens.push(token.to_owned())
  }
  if !is_language_subtag(tokens[0]) {
    return None
  }
  let language = tokens[0].to_lower()
  let mut index = 1
  let mut script = ""
  let mut region = ""
  if index < tokens.length() && is_script_subtag(tokens[index]) {
    script = canonical_script(tokens[index])
    index = index + 1
  }
  if index < tokens.length() && is_region_subtag(tokens[index]) {
    region = tokens[index].to_upper()
    index = index + 1
  }
  let variants : Array[String] = []
  while index < tokens.length() && is_variant_subtag(tokens[index]) {
    let variant = tokens[index].to_lower()
    if variants.contains(variant) {
      return None
    }
    variants.push(variant)
    index = index + 1
  }
  let extension_parts : Array[String] = []
  let singletons : Array[String] = []
  while index < tokens.length() {
    let token = tokens[index]
    if is_single_alphanumeric(token) {
      let singleton = token.to_lower()
      if singleton == "x" {
        if singletons.contains("x") {
          return None
        }
        singletons.push("x")
        extension_parts.push("x")
        index = index + 1
        let mut private_count = 0
        while index < tokens.length() {
          if !is_private_use_subtag(tokens[index]) {
            return None
          }
          extension_parts.push(tokens[index].to_lower())
          private_count = private_count + 1
          index = index + 1
        }
        if private_count == 0 {
          return None
        }
      } else if is_extension_singleton(token) {
        if singletons.contains(singleton) {
          return None
        }
        singletons.push(singleton)
        extension_parts.push(singleton)
        index = index + 1
        let mut extension_count = 0
        while index < tokens.length() && is_extension_subtag(tokens[index]) {
          extension_parts.push(tokens[index].to_lower())
          extension_count = extension_count + 1
          index = index + 1
        }
        if extension_count == 0 {
          return None
        }
      } else {
        return None
      }
    } else {
      return None
    }
  }
  Some({
    language,
    script,
    region,
    variants: join_subtags(variants),
    extensions: join_subtags(extension_parts),
  })
}

///|
/// Strictly parse a BCP 47 subset.
///
/// Supports language, script, region, variants, extensions and private-use
/// sections. Underscores are accepted as a compatibility alias for hyphens.
/// Extlang and grandfathered tags are rejected rather than guessed.
pub fn Locale::try_parse(tag : String) -> Locale? {
  parse_strict(normalize_tag(tag))
}

///|
/// Parse a locale tag with best-effort recovery.
///
/// Use `try_parse` when malformed input must be rejected. This function keeps
/// the leading language when possible and falls back to `en` otherwise.
pub fn Locale::parse(tag : String) -> Locale {
  let normalized = normalize_tag(tag)
  match parse_strict(normalized) {
    Some(locale) => locale
    None => {
      let mut language = "en"
      for part in normalized.split("-") {
        if part.length() == 0 {
          continue
        }
        if is_language_subtag(part) {
          language = part.to_owned().to_lower()
        }
        break
      }
      Locale::new(language)
    }
  }
}

///|
/// Build a locale from already separated parts.
pub fn Locale::new(
  language : String,
  script? : String,
  region? : String,
  variants? : String,
  extensions? : String,
) -> Locale {
  let raw_script = script.unwrap_or("")
  let normalized_script = if raw_script.char_length() == 4 {
    canonical_script(raw_script)
  } else {
    raw_script
  }
  {
    language: language.to_lower(),
    script: normalized_script,
    region: region.unwrap_or("").to_upper(),
    variants: variants.unwrap_or("").to_lower().trim(chars="-").to_owned(),
    extensions: extensions.unwrap_or("").to_lower().trim(chars="-").to_owned(),
  }
}

///|
/// Canonical tag in language-script-region-variant-extension order.
pub fn Locale::to_tag(self : Locale) -> String {
  let mut tag = self.language
  if self.script.length() > 0 {
    tag = tag + "-" + self.script
  }
  if self.region.length() > 0 {
    tag = tag + "-" + self.region
  }
  if self.variants.length() > 0 {
    tag = tag + "-" + self.variants
  }
  if self.extensions.length() > 0 {
    tag = tag + "-" + self.extensions
  }
  tag
}

///|
/// Return the fallback chain used for data lookup, from most specific to the
/// last-resort default. Variants and extensions do not affect data lookup.
pub fn Locale::fallbacks(self : Locale) -> Array[String] {
  let chain : Array[String] = []
  if self.region.length() > 0 && self.script.length() > 0 {
    chain.push(self.language + "-" + self.script + "-" + self.region)
  }
  if self.script.length() > 0 {
    chain.push(self.language + "-" + self.script)
  }
  if self.region.length() > 0 {
    chain.push(self.language + "-" + self.region)
  }
  chain.push(self.language)
  if self.language != "en" {
    chain.push("en")
  }
  chain
}

///|
/// True when two locales have the same canonical language/script/region,
/// variants and extensions.
pub fn Locale::same(self : Locale, other : Locale) -> Bool {
  self.language == other.language &&
  self.script == other.script &&
  self.region == other.region &&
  self.variants == other.variants &&
  self.extensions == other.extensions
}

///|
fn likely_script_for(language : String, region : String) -> String {
  match language {
    "zh" =>
      if region == "TW" || region == "HK" || region == "MO" {
        "Hant"
      } else {
        "Hans"
      }
    "sr" => if region == "ME" { "Latn" } else { "Cyrl" }
    "en"
    | "de"
    | "fr"
    | "es"
    | "it"
    | "pt"
    | "nl"
    | "pl"
    | "cs"
    | "sv"
    | "da"
    | "fi"
    | "no"
    | "nb"
    | "tr"
    | "vi"
    | "id"
    | "ms"
    | "sw"
    | "et"
    | "lv"
    | "lt"
    | "hr"
    | "sl"
    | "sk"
    | "ro"
    | "hu"
    | "ca"
    | "eu"
    | "gl"
    | "af"
    | "is"
    | "ga"
    | "cy"
    | "mt"
    | "sq"
    | "az"
    | "uz" => "Latn"
    "ja" => "Jpan"
    "ko" => "Kore"
    "ar" | "fa" | "ur" => "Arab"
    "ru" | "uk" | "bg" | "be" | "mk" | "kk" => "Cyrl"
    "el" => "Grek"
    "he" => "Hebr"
    "hi" | "mr" | "ne" => "Deva"
    "th" => "Thai"
    "ka" => "Geor"
    "hy" => "Armn"
    _ => ""
  }
}

///|
fn likely_region_for(language : String, script : String) -> String {
  match language {
    "zh" => if script == "Hant" { "TW" } else { "CN" }
    "en" => "US"
    "de" => "DE"
    "fr" => "FR"
    "ja" => "JP"
    "ar" => "EG"
    "es" => "ES"
    "it" => "IT"
    "pt" => "BR"
    "ru" => "RU"
    "ko" => "KR"
    "hi" => "IN"
    "th" => "TH"
    "vi" => "VN"
    "tr" => "TR"
    "nl" => "NL"
    "pl" => "PL"
    "sv" => "SE"
    "da" => "DK"
    "fi" => "FI"
    "no" | "nb" => "NO"
    "cs" => "CZ"
    "el" => "GR"
    "he" => "IL"
    "fa" => "IR"
    "ur" => "PK"
    "uk" => "UA"
    "id" => "ID"
    "ms" => "MY"
    "bg" => "BG"
    "be" => "BY"
    "ro" => "RO"
    "hu" => "HU"
    "sk" => "SK"
    "sl" => "SI"
    "hr" => "HR"
    "sr" => "RS"
    "ca" => "ES"
    "et" => "EE"
    "lv" => "LV"
    "lt" => "LT"
    "is" => "IS"
    "ga" => "IE"
    "cy" => "GB"
    "mt" => "MT"
    "mk" => "MK"
    "sq" => "AL"
    "hy" => "AM"
    "ka" => "GE"
    "kk" => "KZ"
    "uz" => "UZ"
    "az" => "AZ"
    _ => ""
  }
}

///|
/// Fill missing script and region using a built-in subset of CLDR likely
/// subtags. Existing values are preserved, as are variants and extensions.
///
/// The table covers the bundled locales and common languages; unknown languages
/// keep their missing fields unchanged.
pub fn Locale::maximize(self : Locale) -> Locale {
  let script = if self.script.length() > 0 {
    self.script
  } else {
    likely_script_for(self.language, self.region)
  }
  let region = if self.region.length() > 0 {
    self.region
  } else {
    likely_region_for(self.language, script)
  }
  {
    language: self.language,
    script,
    region,
    variants: self.variants,
    extensions: self.extensions,
  }
}

///|
fn parse_quality(value : StringView) -> Int? {
  let text = value.trim()
  if text.length() == 0 {
    return None
  }
  let mut whole = 0
  let mut fraction = 0
  let mut fraction_digits = 0
  let mut digit_count = 0
  let mut seen_dot = false
  for c in text.iter() {
    if c == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
      continue
    }
    if !c.is_ascii_digit() {
      return None
    }
    let digit = c.to_int() - 48
    digit_count = digit_count + 1
    if seen_dot {
      if fraction_digits >= 3 {
        return None
      }
      fraction = fraction * 10 + digit
      fraction_digits = fraction_digits + 1
    } else {
      whole = whole * 10 + digit
      if whole > 1 {
        return None
      }
    }
  }
  if digit_count == 0 {
    return None
  }
  while fraction_digits < 3 {
    fraction = fraction * 10
    fraction_digits = fraction_digits + 1
  }
  if whole == 1 && fraction > 0 {
    return None
  }
  Some(whole * 1000 + fraction)
}

///|
fn parse_accept_language(header : String) -> Array[LanguageRange] {
  let ranges : Array[LanguageRange] = []
  let mut order = 0
  for entry in header.split(",") {
    let trimmed = entry.trim()
    if trimmed.length() == 0 {
      continue
    }
    let pieces : Array[String] = []
    for piece in trimmed.split(";") {
      pieces.push(piece.trim().to_owned())
    }
    if pieces.length() == 0 {
      continue
    }
    let tag = pieces[0]
    let mut quality = 1000
    let mut valid = true
    let mut index = 1
    while index < pieces.length() {
      let parameter = pieces[index].to_lower()
      if parameter.has_prefix("q=") {
        match parse_quality(parameter[2:parameter.length()]) {
          Some(value) => quality = value
          None => valid = false
        }
      }
      index = index + 1
    }
    if valid && quality > 0 {
      if tag == "*" {
        ranges.push({ tag, locale: None, quality, order })
      } else {
        match Locale::try_parse(tag) {
          Some(locale) =>
            ranges.push({ tag, locale: Some(locale), quality, order })
          None => ()
        }
      }
    }
    order = order + 1
  }
  ranges.sort_by(fn(a, b) {
    if a.quality != b.quality {
      return b.quality - a.quality
    }
    a.order - b.order
  })
  ranges
}

///|
/// Rank how well an available locale matches a requested range. Lower is
/// better. `None` means the language does not match.
fn locale_match_rank(requested : Locale, candidate : Locale) -> Int? {
  if requested.language != candidate.language {
    return None
  }
  if requested.script == candidate.script &&
    requested.region == candidate.region &&
    requested.variants == candidate.variants &&
    requested.extensions == candidate.extensions {
    return Some(0)
  }
  if requested.script == candidate.script &&
    requested.region == candidate.region {
    return Some(1)
  }
  let requested_max = requested.maximize()
  let candidate_max = candidate.maximize()
  if requested_max.script == candidate_max.script &&
    requested_max.region == candidate_max.region {
    return Some(2)
  }
  let requested_region = requested.region
  if requested_max.script.length() > 0 &&
    requested_max.script == candidate_max.script {
    if requested_region.length() > 0 && requested_region == candidate.region {
      return Some(3)
    }
    if requested_region.length() > 0 &&
      candidate.script.length() > 0 &&
      candidate.region.length() == 0 {
      return Some(4)
    }
    if requested_region.length() == 0 {
      return Some(3)
    }
  }
  if requested_region.length() > 0 && requested_region == candidate.region {
    return Some(4)
  }
  if candidate.script.length() == 0 && candidate.region.length() == 0 {
    return Some(5)
  }
  if requested_region.length() == 0 && candidate.script.length() > 0 {
    return Some(5)
  }
  Some(6)
}

///|
/// Negotiate an `Accept-Language` header against available locales.
///
/// Ranges are ordered by q-value with stable header order for ties. Exact and
/// likely-subtag matches are preferred, followed by language/script/region
/// fallbacks and wildcard `*`. Returns `None` when nothing matches.
pub fn Locale::negotiate(
  accept_language : String,
  available : Array[Locale],
) -> Locale? {
  if available.length() == 0 {
    return None
  }
  for range in parse_accept_language(accept_language) {
    if range.tag == "*" {
      return Some(available[0])
    }
    match range.locale {
      Some(requested) => {
        let mut best_index = -1
        let mut best_rank = 1000
        let mut index = 0
        while index < available.length() {
          match locale_match_rank(requested, available[index]) {
            Some(rank) =>
              if rank < best_rank {
                best_rank = rank
                best_index = index
              }
            None => ()
          }
          index = index + 1
        }
        if best_index >= 0 {
          return Some(available[best_index])
        }
      }
      None => ()
    }
  }
  None
}
