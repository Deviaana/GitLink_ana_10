///|
test "README examples produce expected output" {
  let en = @core.Locale::parse("en")
  let de = @core.Locale::parse("de")

  assert_eq(@number.format_decimal(1234567.891, de), "1.234.567,891")
  assert_eq(
    @number.format_currency(1234.5, "EUR", de),
    "1.234,50\u{00A0}\u{20AC}",
  )
  assert_eq(@number.format_percent(0.125, de), "13\u{00A0}%")
  assert_eq(@number.format_compact(1234567.0, de), "1,2\u{00A0}Mio.")
  assert_eq(@number.format_scientific(1234567.0, de), "1,235E6")
  assert_eq(@number.format_with_pattern(12.5, en, "0.0 'kg'"), "12.5 kg")
  assert_eq(@number.format_with_pattern(1.0, en, "@@@"), "1.00")
  assert_eq(@number.format_with_pattern(0.12345, en, "@@##"), "0.1235")
  assert_eq(@number.format_with_pattern(1.22, en, "0.05"), "1.20")
  assert_eq(@number.format_with_pattern(1.23, en, "0.05"), "1.25")
  assert_eq(@number.format_with_pattern(1234.56, en, "#,##0.05"), "1,234.55")
  assert_eq(@number.format_with_pattern(0.125, en, "0‰"), "125‰")
  assert_eq(@number.format_with_pattern(1.2, en, "*_#,##0.00"), "____1.20")

  let date = @datetime.DateTime::new(2026, 10, 18, hour=17, minute=42)
  assert_eq(@datetime.format_date(date, de), "18.10.2026")
  let end = @datetime.DateTime::new(2026, 10, 20)
  assert_eq(
    @datetime.format_date_range(date, end, en),
    "Oct 18, 2026\u{2009}\u{2013}\u{2009}Oct 20, 2026",
  )
  assert_eq(
    @datetime.format_pattern_with_policy(
      date,
      en,
      "yyyy-MM-dd z",
      @datetime.Skip,
    ).unwrap(),
    "2026-10-18 ",
  )

  let rules = @plural.PluralRules::cached("ar")
  assert_eq(rules.select(3.0), "few")
  assert_eq(@relative.format_relative(-3.0, @relative.Day, de), "vor 3 Tagen")
}
