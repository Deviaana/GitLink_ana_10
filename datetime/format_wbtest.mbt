///|
test "english date styles" {
  let date = DateTime::new(2026, 10, 18)
  let en = @core.Locale::parse("en")
  assert_eq(format_date(date, en, style=Short), "10/18/26")
  assert_eq(format_date(date, en, style=Medium), "Oct 18, 2026")
  assert_eq(format_date(date, en, style=Long), "October 18, 2026")
  assert_eq(format_date(date, en, style=Full), "Sunday, October 18, 2026")
}

///|
test "locale specific date orders" {
  let date = DateTime::new(2026, 10, 18)
  assert_eq(format_date(date, @core.Locale::parse("de")), "18.10.2026")
  assert_eq(format_date(date, @core.Locale::parse("zh")), "2026年10月18日")
  assert_eq(format_date(date, @core.Locale::parse("ja")), "2026/10/18")
}

///|
test "time styles" {
  let time = DateTime::new(2026, 10, 18, hour=17, minute=42, second=5)
  let en = @core.Locale::parse("en")
  assert_eq(format_time(time, en, style=Short), "5:42\u{202F}PM")
  assert_eq(format_time(time, en, style=Medium), "5:42:05\u{202F}PM")
  let de = @core.Locale::parse("de")
  assert_eq(format_time(time, de, style=Short), "17:42")
}

///|
test "weekday calculation" {
  assert_eq(DateTime::new(2026, 10, 18).weekday(), 0)
  assert_eq(DateTime::new(2026, 10, 19).weekday(), 1)
  assert_eq(DateTime::new(1970, 1, 1).weekday(), 4)
}

///|
test "explicit pattern with quoted literal" {
  let date = DateTime::new(2026, 10, 18, hour=17, minute=42)
  let en = @core.Locale::parse("en")
  assert_eq(format_pattern(date, en, "h 'o''clock' a"), "5 o'clock PM")
}
