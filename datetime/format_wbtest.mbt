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

///|
test "explicit patterns preserve intentional whitespace" {
  let date = DateTime::new(2026, 10, 18)
  let en = @core.Locale::parse("en")
  assert_eq(format_pattern(date, en, " yyyy-MM-dd "), " 2026-10-18 ")
  assert_eq(format_pattern(date, en, "yyyy 'at' HH:mm"), "2026 at 00:00")
  assert_eq(format_pattern(date, en, "*_"), "*_")
}

///|
test "unsupported fields can be skipped preserved or rejected" {
  let date = DateTime::new(2026, 10, 18)
  let en = @core.Locale::parse("en")
  let skipped = format_pattern_with_policy(date, en, "yyyy-MM-dd z", Skip)
  assert_eq(skipped.unwrap(), "2026-10-18 ")
  let preserved = format_pattern_with_policy(
    date,
    en,
    "yyyy-MM-dd zzzz",
    Preserve,
  )
  assert_eq(preserved.unwrap(), "2026-10-18 zzzz")
  let rejected = format_pattern_with_policy(date, en, "yyyy-MM-dd z", Reject)
  match rejected {
    Ok(_) => assert_eq("expected an unsupported field error", "ok")
    Err(UnsupportedField(field)) => assert_eq(field, 'z')
  }
  let star_rejected = format_pattern_with_policy(date, en, "*z", Reject)
  match star_rejected {
    Ok(_) => assert_eq("expected an unsupported field after literal star", "ok")
    Err(UnsupportedField(field)) => assert_eq(field, 'z')
  }
}

///|
test "quoted pattern letters are literals under the reject policy" {
  let date = DateTime::new(2026, 10, 18)
  let en = @core.Locale::parse("en")
  let result = format_pattern_with_policy(date, en, "yyyy 'z'", Reject)
  assert_eq(result.unwrap(), "2026 z")
}

///|
test "long time patterns report timezone fields explicitly" {
  let time = DateTime::new(2026, 10, 18, hour=17, minute=42, second=5)
  let en = @core.Locale::parse("en")
  let result = format_time_with_policy(time, en, Reject, style=Full)
  match result {
    Ok(_) => assert_eq("expected an unsupported timezone field", "ok")
    Err(UnsupportedField(field)) => assert_eq(field, 'z')
  }
}

///|
test "date ranges use locale interval fallbacks" {
  let start = DateTime::new(2026, 10, 18)
  let end = DateTime::new(2026, 10, 20)
  let en = @core.Locale::parse("en")
  let ja = @core.Locale::parse("ja")
  assert_eq(
    format_date_range(start, end, en),
    "Oct 18, 2026\u{2009}\u{2013}\u{2009}Oct 20, 2026",
  )
  assert_eq(format_date_range(start, end, ja), "2026/10/18\u{FF5E}2026/10/20")
  assert_eq(format_date_range(start, start, en), "Oct 18, 2026")
}
