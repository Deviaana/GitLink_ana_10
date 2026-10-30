///|
fn main {
  let tags : Array[String] = ["en", "zh", "de", "ja", "ar", "fr"]
  let date = @datetime.DateTime::new(2026, 10, 18, hour=17, minute=42, second=5)
  println("moonl10n demo")
  println("")
  println("-- decimal 1234567.891 --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @number.format_decimal(1234567.891, locale))
  }
  println("")
  println("-- currency 1234.5 USD --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @number.format_currency(1234.5, "USD", locale))
  }
  println("")
  println("-- currency display modes --")
  let en = @core.Locale::parse("en")
  let code = @number.CurrencyOptions::with_display(@number.Code)
  let name = @number.CurrencyOptions::with_display(@number.Name)
  let accounting = @number.CurrencyOptions::default().with_accounting()
  println(
    "code        " +
    @number.format_currency(1234.5, "USD", en, currency_options=code),
  )
  println(
    "name        " +
    @number.format_currency(1234.5, "USD", en, currency_options=name),
  )
  println(
    "accounting  " +
    @number.format_currency(-1234.5, "USD", en, currency_options=accounting),
  )
  println(
    "pattern     " +
    @number.format_currency_with_pattern(1234.5, "USD", en, "¤¤#,##0.00"),
  )
  println("")
  println("-- percent 0.125 --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @number.format_percent(0.125, locale))
  }
  println("")
  println("-- compact 1234567 --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @number.format_compact(1234567.0, locale))
  }
  println("")
  println("-- scientific 1234567 --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @number.format_scientific(1234567.0, locale))
  }
  println("")
  println("-- quoted number pattern --")
  println(@number.format_with_pattern(12.5, en, "0.0 'kg'"))
  println("")
  println("-- significant digits and rounding increments --")
  println("@@@      " + @number.format_with_pattern(1234.56, en, "@@@"))
  println("@@##     " + @number.format_with_pattern(0.12345, en, "@@##"))
  println("0.05     " + @number.format_with_pattern(1.23, en, "0.05"))
  println("#,##0.05 " + @number.format_with_pattern(1234.56, en, "#,##0.05"))
  println("0.005    " + @number.format_with_pattern(1.23456, en, "0.005"))
  println("0.05E0   " + @number.format_with_pattern(1234.56, en, "0.05E0"))
  println("*_0.00   " + @number.format_with_pattern(1.2, en, "*_0.00"))
  println("")
  println("-- date medium, 2026-10-18 --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @datetime.format_date(date, locale))
  }
  println("")
  println("-- date range, 2026-10-18 to 2026-10-20 --")
  let range_end = @datetime.DateTime::new(2026, 10, 20)
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @datetime.format_date_range(date, range_end, locale))
  }
  println("")
  println("-- time short, 17:42:05 --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(
      tag + "  " + @datetime.format_time(date, locale, style=@datetime.Short),
    )
  }
  println("")
  println("-- relative -3 days --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @relative.format_relative(-3.0, @relative.Day, locale))
  }
  println("")
  println("-- plural select 3 --")
  for tag in tags {
    let rules = @plural.PluralRules::cached(tag)
    println(tag + "  " + rules.select(3.0))
  }
}
