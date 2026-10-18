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
  println("-- percent 0.125 --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @number.format_percent(0.125, locale))
  }
  println("")
  println("-- date medium, 2026-10-18 --")
  for tag in tags {
    let locale = @core.Locale::parse(tag)
    println(tag + "  " + @datetime.format_date(date, locale))
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
    let rules = @plural.PluralRules::new(tag)
    println(tag + "  " + rules.select(3.0))
  }
}
