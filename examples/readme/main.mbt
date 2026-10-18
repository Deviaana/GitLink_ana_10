///|
fn show(label : String, value : String) -> Unit {
  println(label + ": " + value)
}

///|
fn main {
  let en = @core.Locale::parse("en")
  let de = @core.Locale::parse("de")

  show("decimal", @number.format_decimal(1234567.891, de))
  show("currency", @number.format_currency(1234.5, "EUR", de))
  show("percent", @number.format_percent(0.125, de))
  show("compact", @number.format_compact(1234567.0, de))
  show("scientific", @number.format_scientific(1234567.0, de))
  show("pattern", @number.format_with_pattern(12.5, en, "0.0 'kg'"))

  let date = @datetime.DateTime::new(2026, 10, 18, hour=17, minute=42)
  show("date", @datetime.format_date(date, de))
  let end = @datetime.DateTime::new(2026, 10, 20)
  show("date range", @datetime.format_date_range(date, end, en))
  show(
    "date policy",
    @datetime.format_pattern_with_policy(
      date,
      en,
      "yyyy-MM-dd z",
      @datetime.Skip,
    ).unwrap(),
  )

  let rules = @plural.PluralRules::cached("ar")
  show("plural", rules.select(3.0))
  show("relative", @relative.format_relative(-3.0, @relative.Day, de))

  println("README examples passed")
}
