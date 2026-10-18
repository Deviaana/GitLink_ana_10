///|
/// A parsed BCP 47 locale identifier.
///
/// Only the parts that affect CLDR data lookup are kept: language, script and
/// region. Variants and extensions are accepted but ignored in this version.
pub(all) struct Locale {
  language : String
  script : String
  region : String
} derive(Debug, Eq, Hash)

///|
/// Parse a BCP 47 tag such as `zh-Hant-TW`, `en_US` or `de`.
pub fn Locale::parse(tag : String) -> Locale {
  let normalized = tag.replace_all(old="_", new="-")
  let parts : Array[StringView] = []
  for part in normalized.split("-") {
    if part.length() > 0 {
      parts.push(part)
    }
  }
  let mut language = "en"
  if parts.length() > 0 {
    language = parts[0].to_owned().to_lower()
  }
  let mut script = ""
  let mut region = ""
  let mut index = 1
  if index < parts.length() {
    let candidate = parts[index]
    if candidate.char_length() == 4 {
      let raw = candidate.to_owned()
      script = raw[0:1].to_owned().to_upper() + raw[1:4].to_owned().to_lower()
      index = index + 1
    }
  }
  if index < parts.length() {
    let candidate = parts[index]
    if candidate.char_length() == 2 || candidate.char_length() == 3 {
      region = candidate.to_owned().to_upper()
    }
  }
  { language, script, region }
}

///|
/// Build a locale from already separated parts.
pub fn Locale::new(
  language : String,
  script? : String,
  region? : String,
) -> Locale {
  {
    language: language.to_lower(),
    script: script.unwrap_or(""),
    region: region.unwrap_or("").to_upper(),
  }
}

///|
/// Canonical tag in `language-script-region` order.
pub fn Locale::to_tag(self : Locale) -> String {
  let mut tag = self.language
  if self.script.length() > 0 {
    tag = tag + "-" + self.script
  }
  if self.region.length() > 0 {
    tag = tag + "-" + self.region
  }
  tag
}

///|
/// Return the fallback chain used for data lookup, from most specific to the
/// last-resort default. Unknown parts are skipped.
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
/// True when two locales resolve to the same language/script/region triple.
pub fn Locale::same(self : Locale, other : Locale) -> Bool {
  self.language == other.language &&
  self.script == other.script &&
  self.region == other.region
}
