///|
test "currency symbols use shared base and locale overrides" {
  let en = number_data("en").unwrap()
  let zh = number_data("zh").unwrap()
  let de = number_data("de").unwrap()
  assert_eq(en.currency_symbol("USD"), "$")
  assert_eq(de.currency_symbol("usd"), "$")
  assert_eq(zh.currency_symbol("USD"), "US$")
  assert_eq(zh.currency_narrow_symbol("USD"), "$")
}

///|
test "narrow symbols fall back to the locale regular symbol" {
  let zh = number_data("zh").unwrap()
  assert_eq(zh.currency_narrow_symbol("CNY"), zh.currency_symbol("CNY"))
}

///|
test "unknown currency codes keep their uppercase ISO form" {
  let en = number_data("en").unwrap()
  assert_eq(en.currency_symbol("xyz"), "XYZ")
  assert_eq(en.currency_narrow_symbol("xyz"), "XYZ")
  assert_eq(en.currency_name("xyz", "one"), "XYZ")
}

///|
test "currency name indexes follow the shared code table" {
  let en = number_data("en").unwrap()
  let zh = number_data("zh").unwrap()
  let de = number_data("de").unwrap()
  assert_eq(en.currency_name("USD", "one"), "US dollar")
  assert_eq(en.currency_name("USD", "other"), "US dollars")
  assert_eq(zh.currency_name("USD", "one"), "\u{7F8E}\u{5143}")
  assert_eq(de.currency_name("CNY", "one"), "Chinesischer Yuan")
  assert_eq(de.currency_name("CNY", "other"), "Renminbi Yuan")
}

///|
test "currency table lengths and override indexes stay aligned" {
  assert_eq(currency_base_symbols.length(), currency_codes.length())
  let locales : Array[String] = ["en", "zh", "de", "ja", "ar", "fr"]
  for locale in locales {
    let data = number_data(locale).unwrap()
    assert_eq(data.currency_names.length(), currency_codes.length())
    assert_eq(
      data.currency_symbol_overrides.length() <= currency_codes.length(),
      true,
    )
    assert_eq(
      data.currency_narrow_symbol_overrides.length() <= currency_codes.length(),
      true,
    )
    for entry in data.currency_symbol_overrides {
      assert_eq(entry.0 >= 0 && entry.0 < currency_codes.length(), true)
    }
    for entry in data.currency_narrow_symbol_overrides {
      assert_eq(entry.0 >= 0 && entry.0 < currency_codes.length(), true)
    }
  }
}
