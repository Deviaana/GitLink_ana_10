///|
test "english relative time" {
  let en = @core.Locale::parse("en")
  assert_eq(format_relative(3.0, Day, en), "in 3 days")
  assert_eq(format_relative(-3.0, Day, en), "3 days ago")
  assert_eq(format_relative(0.0, Day, en), "today")
  assert_eq(format_relative(1.0, Day, en), "tomorrow")
  assert_eq(format_relative(-1.0, Day, en), "yesterday")
  assert_eq(format_relative(2.0, Hour, en), "in 2 hours")
  assert_eq(format_relative(1.5, Hour, en), "in 1.5 hours")
}

///|
test "chinese relative time" {
  let zh = @core.Locale::parse("zh")
  assert_eq(format_relative(-3.0, Day, zh), "3天前")
  assert_eq(format_relative(0.0, Day, zh), "今天")
  assert_eq(format_relative(1.0, Day, zh), "明天")
}

///|
test "german relative time" {
  let de = @core.Locale::parse("de")
  assert_eq(format_relative(-3.0, Day, de), "vor 3 Tagen")
  assert_eq(format_relative(3.0, Day, de), "in 3 Tagen")
}

///|
test "japanese relative time" {
  let ja = @core.Locale::parse("ja")
  assert_eq(format_relative(-3.0, Day, ja), "3 日前")
  assert_eq(format_relative(1.0, Day, ja), "明日")
}
