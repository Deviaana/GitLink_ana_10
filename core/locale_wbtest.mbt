///|
test "parse simple language" {
  let locale = Locale::parse("de")
  assert_eq(locale.language, "de")
  assert_eq(locale.script, "")
  assert_eq(locale.region, "")
  assert_eq(locale.to_tag(), "de")
}

///|
test "parse language with script and region" {
  let locale = Locale::parse("zh-Hant-TW")
  assert_eq(locale.language, "zh")
  assert_eq(locale.script, "Hant")
  assert_eq(locale.region, "TW")
  assert_eq(locale.to_tag(), "zh-Hant-TW")
}

///|
test "parse underscores and case" {
  let locale = Locale::parse("EN_us")
  assert_eq(locale.language, "en")
  assert_eq(locale.region, "US")
  assert_eq(locale.to_tag(), "en-US")
}

///|
test "fallback chain is ordered from specific to general" {
  let chain = Locale::parse("zh-Hant-TW").fallbacks()
  assert_eq(chain.length(), 5)
  assert_eq(chain[0], "zh-Hant-TW")
  assert_eq(chain[1], "zh-Hant")
  assert_eq(chain[2], "zh-TW")
  assert_eq(chain[3], "zh")
  assert_eq(chain[4], "en")
}

///|
test "fallback chain ends at language only" {
  let chain = Locale::parse("en").fallbacks()
  assert_eq(chain.length(), 1)
  assert_eq(chain[0], "en")
}
