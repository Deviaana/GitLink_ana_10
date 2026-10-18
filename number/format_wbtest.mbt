///|
test "en decimal grouping and fraction" {
  let locale = @core.Locale::parse("en")
  assert_eq(format_decimal(1234567.891, locale), "1,234,567.891")
  assert_eq(format_decimal(-1234.5, locale), "-1,234.5")
  assert_eq(format_decimal(0.5, locale), "0.5")
  assert_eq(format_decimal(12.0, locale), "12")
}

///|
test "explicit fraction digits" {
  let locale = @core.Locale::parse("en")
  let options = NumberOptions::with_fraction_digits(2, 2)
  assert_eq(format_decimal(1.2345, locale, options~), "1.23")
  assert_eq(format_decimal(1.0, locale, options~), "1.00")
}

///|
test "german separators" {
  let locale = @core.Locale::parse("de")
  assert_eq(format_decimal(1234567.891, locale), "1.234.567,891")
  assert_eq(format_decimal(-1234.5, locale), "-1.234,5")
}

///|
test "japanese and chinese grouping" {
  let ja = @core.Locale::parse("ja")
  let zh = @core.Locale::parse("zh")
  assert_eq(format_decimal(1234567.891, ja), "1,234,567.891")
  assert_eq(format_decimal(1234567.891, zh), "1,234,567.891")
}

///|
test "french uses narrow no-break space" {
  let locale = @core.Locale::parse("fr")
  let result = format_decimal(1234567.891, locale)
  assert_eq(result, "1\u{202F}234\u{202F}567,891")
}

///|
test "currency respects ISO 4217 digits" {
  let en = @core.Locale::parse("en")
  let de = @core.Locale::parse("de")
  let ja = @core.Locale::parse("ja")
  assert_eq(format_currency(1234.5, "USD", en), "$1,234.50")
  assert_eq(format_currency(1234.5, "EUR", de), "1.234,50\u{00A0}€")
  assert_eq(format_currency(1234.5, "JPY", ja), "￥1,235")
}

///|
test "percent formatting" {
  let en = @core.Locale::parse("en")
  let de = @core.Locale::parse("de")
  assert_eq(format_percent(0.12, en), "12%")
  assert_eq(format_percent(0.12, de), "12\u{00A0}%")
}

///|
test "grouping can be disabled" {
  let locale = @core.Locale::parse("en")
  let options = NumberOptions::default().without_grouping()
  assert_eq(format_decimal(1234567.0, locale, options~), "1234567")
}

///|
test "negative subpattern is honored" {
  let locale = @core.Locale::parse("en")
  let result = format_with_pattern(-12.5, locale, "#,##0.00;(#,##0.00)")
  assert_eq(result, "(12.50)")
}

///|
test "indian grouping pattern" {
  let locale = @core.Locale::parse("en")
  assert_eq(format_with_pattern(12345678.0, locale, "#,##,##0"), "1,23,45,678")
}

///|
test "zero and very small values" {
  let locale = @core.Locale::parse("en")
  assert_eq(format_decimal(0.0, locale), "0")
  assert_eq(format_decimal(0.0001, locale), "0")
}

///|
test "rounding avoids binary floating point drift" {
  let en = @core.Locale::parse("en")
  let money = NumberOptions::with_fraction_digits(2, 2)
  assert_eq(format_decimal(1.005, en, options=money), "1.01")
  assert_eq(format_decimal(2.675, en, options=money), "2.68")
  assert_eq(format_decimal(1.0049, en, options=money), "1.00")
  assert_eq(format_decimal(999.995, en, options=money), "1,000.00")
  assert_eq(format_currency(1.005, "USD", en), "$1.01")
  assert_eq(format_currency(-1.005, "USD", en), "-$1.01")
}

///|
test "scientific notation input expands" {
  let en = @core.Locale::parse("en")
  let wide = NumberOptions::with_fraction_digits(7, 7)
  assert_eq(format_decimal(1.0e-7, en, options=wide), "0.0000001")
  assert_eq(format_decimal(1.0e21, en), "1,000,000,000,000,000,000,000")
}

///|
test "decimal result exposes rendered digits" {
  let en = @core.Locale::parse("en")
  let money = NumberOptions::with_fraction_digits(2, 2)
  let one = format_decimal_result(1.005, en, options=money)
  assert_eq(one.text, "1.01")
  assert_eq(one.integer_digits, "1")
  assert_eq(one.fraction_digits, "01")
  let carried = format_decimal_result(999.995, en, options=money)
  assert_eq(carried.text, "1,000.00")
  assert_eq(carried.integer_digits, "1000")
  assert_eq(carried.fraction_digits, "00")
  let padded = format_decimal_result(1.0, en, options=money)
  assert_eq(padded.text, "1.00")
  assert_eq(padded.integer_digits, "1")
  assert_eq(padded.fraction_digits, "00")
}
