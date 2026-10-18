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

///|
fn parse_ok(tag : String) -> Locale raise {
  match Locale::try_parse(tag) {
    Some(locale) => locale
    None => {
      assert_eq("expected a valid locale", tag)
      Locale::parse("en")
    }
  }
}

///|
fn assert_negotiated(
  header : String,
  available : Array[Locale],
  expected : String,
) -> Unit raise {
  match Locale::negotiate(header, available) {
    Some(locale) => assert_eq(locale.to_tag(), expected)
    None => assert_eq("expected a negotiated locale", expected)
  }
}

///|
test "strict parsing rejects malformed subtags" {
  assert_eq(Locale::try_parse("de-abc"), None)
  assert_eq(Locale::try_parse("en--US"), None)
  assert_eq(Locale::try_parse("en-"), None)
  assert_eq(Locale::try_parse("not a locale"), None)
  let recovered = Locale::parse("de-abc")
  assert_eq(recovered.language, "de")
  assert_eq(recovered.region, "")
  assert_eq(recovered.to_tag(), "de")
}

///|
test "three digit regions are distinct from language subtags" {
  let locale = parse_ok("es-419")
  assert_eq(locale.language, "es")
  assert_eq(locale.region, "419")
  assert_eq(locale.to_tag(), "es-419")
}

///|
test "variants are preserved and normalized" {
  let locale = parse_ok("sl-ROZAJ-biske-1994")
  assert_eq(locale.language, "sl")
  assert_eq(locale.variants, "rozaj-biske-1994")
  assert_eq(locale.to_tag(), "sl-rozaj-biske-1994")
}

///|
test "extensions and private use round trip" {
  let locale = parse_ok("EN-us-U-CA-gregory-X-private")
  assert_eq(locale.language, "en")
  assert_eq(locale.region, "US")
  assert_eq(locale.extensions, "u-ca-gregory-x-private")
  assert_eq(locale.to_tag(), "en-US-u-ca-gregory-x-private")
}

///|
test "malformed extensions are rejected" {
  assert_eq(Locale::try_parse("en-u"), None)
  assert_eq(Locale::try_parse("en-x"), None)
  assert_eq(Locale::try_parse("en-u-ca-gregory-u-nu-latn"), None)
  assert_eq(Locale::try_parse("en-a-1"), None)
}

///|
test "likely subtags fill missing script and region" {
  assert_eq(parse_ok("en").maximize().to_tag(), "en-Latn-US")
  assert_eq(parse_ok("zh-TW").maximize().to_tag(), "zh-Hant-TW")
  assert_eq(parse_ok("zh-Hant").maximize().to_tag(), "zh-Hant-TW")
  assert_eq(parse_ok("fr-CA").maximize().to_tag(), "fr-Latn-CA")
  assert_eq(parse_ok("sr-ME").maximize().to_tag(), "sr-Latn-ME")
  assert_eq(
    parse_ok("zh-CN-u-ca-chinese").maximize().to_tag(),
    "zh-Hans-CN-u-ca-chinese",
  )
}

///|
test "accept language respects q values" {
  let available : Array[Locale] = [
    Locale::parse("en"),
    Locale::parse("fr"),
    Locale::parse("de"),
  ]
  assert_negotiated("fr;q=0.5, de;q=0.9, en;q=0.8", available, "de")
  assert_negotiated("de;q=0, en;q=0.5", available, "en")
  assert_eq(Locale::negotiate("de;q=0", available), None)
}

///|
test "accept language uses likely subtags" {
  let available : Array[Locale] = [
    Locale::parse("en"),
    Locale::parse("zh-Hans"),
    Locale::parse("zh-Hant"),
  ]
  assert_negotiated("zh-HK, en;q=0.8", available, "zh-Hant")
  assert_negotiated("zh-CN, en;q=0.8", available, "zh-Hans")
}

///|
test "generic locale beats a mismatched region" {
  let available : Array[Locale] = [Locale::parse("fr-FR"), Locale::parse("fr")]
  assert_negotiated("fr-CA", available, "fr")
}

///|
test "accept language wildcard and malformed ranges" {
  let available : Array[Locale] = [Locale::parse("en"), Locale::parse("fr")]
  assert_negotiated("xx-YY, *;q=0.2", available, "en")
  assert_negotiated("not a tag, en;q=0.8", available, "en")
  assert_eq(Locale::negotiate("*;q=0", available), None)
}

///|
test "equal q values keep header order" {
  let available : Array[Locale] = [Locale::parse("de"), Locale::parse("fr")]
  assert_negotiated("fr;q=0.8, de;q=0.8", available, "fr")
}

///|
test "locale identity includes variants and extensions" {
  let plain = parse_ok("en-US")
  let extended = parse_ok("en-US-u-ca-gregory")
  assert_eq(plain.same(extended), false)
  assert_eq(plain.to_tag(), "en-US")
  assert_eq(extended.to_tag(), "en-US-u-ca-gregory")
}

///|
test "data lookup fallbacks ignore variants and extensions" {
  let chain = parse_ok("en-US-u-ca-gregory").fallbacks()
  assert_eq(chain.length(), 2)
  assert_eq(chain[0], "en-US")
  assert_eq(chain[1], "en")
}
