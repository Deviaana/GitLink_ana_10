///|
fn fallback_date_data() -> @data.DateData {
  match @data.date_data("en") {
    Some(data) => data
    None =>
      {
        full_date: "EEEE, MMMM d, y",
        long_date: "MMMM d, y",
        medium_date: "MMM d, y",
        short_date: "M/d/yy",
        full_time: "h:mm:ss a",
        long_time: "h:mm:ss a",
        medium_time: "h:mm:ss a",
        short_time: "h:mm a",
        months_wide: [],
        months_abbr: [],
        days_wide: [],
        days_abbr: [],
        am: "AM",
        pm: "PM",
        interval_fallback: "{0} \u{2013} {1}",
      }
  }
}

///|
fn resolve_date_data(locale : @core.Locale) -> @data.DateData {
  for anchor in locale.fallbacks() {
    match @data.date_data(anchor) {
      Some(data) => return data
      None => ()
    }
  }
  fallback_date_data()
}

///|
fn pad_number(value : Int, digits : Int) -> String {
  value.to_string().pad_start(digits, '0')
}

///|
fn month_name(data : @data.DateData, month : Int, count : Int) -> String {
  if month < 1 || month > 12 {
    return ""
  }
  if count >= 4 {
    data.months_wide[month - 1]
  } else {
    data.months_abbr[month - 1]
  }
}

///|
fn append_field(
  builder : StringBuilder,
  field : Char,
  count : Int,
  date : DateTime,
  data : @data.DateData,
) -> Unit {
  match field {
    'y' =>
      if count == 2 {
        builder.write_object(pad_number(date.year % 100, 2))
      } else {
        builder.write_object(date.year.to_string())
      }
    'M' =>
      if count <= 2 {
        builder.write_object(
          pad_number(date.month, if count == 2 { 2 } else { 1 }),
        )
      } else {
        builder.write_object(month_name(data, date.month, count))
      }
    'd' =>
      builder.write_object(pad_number(date.day, if count >= 2 { 2 } else { 1 }))
    'H' =>
      builder.write_object(
        pad_number(date.hour, if count >= 2 { 2 } else { 1 }),
      )
    'h' => {
      let hour = if date.hour % 12 == 0 { 12 } else { date.hour % 12 }
      builder.write_object(pad_number(hour, if count >= 2 { 2 } else { 1 }))
    }
    'm' => builder.write_object(pad_number(date.minute, 2))
    's' => builder.write_object(pad_number(date.second, 2))
    'a' => builder.write_object(if date.hour < 12 { data.am } else { data.pm })
    'E' => {
      let weekday = date.weekday()
      if count >= 4 {
        builder.write_object(data.days_wide[weekday])
      } else {
        builder.write_object(data.days_abbr[weekday])
      }
    }
    _ => ()
  }
}

///|
fn is_supported_field(field : Char) -> Bool {
  field == 'y' ||
  field == 'M' ||
  field == 'd' ||
  field == 'H' ||
  field == 'h' ||
  field == 'm' ||
  field == 's' ||
  field == 'a' ||
  field == 'E'
}

///|
fn write_repeated(builder : StringBuilder, field : Char, count : Int) -> Unit {
  let mut index = 0
  while index < count {
    builder.write_object(field)
    index = index + 1
  }
}

///|
fn format_pattern_core(
  date : DateTime,
  locale : @core.Locale,
  pattern : String,
  unsupported : UnsupportedFieldPolicy,
) -> Result[String, DateFormatError] {
  let data = resolve_date_data(locale)
  let builder = StringBuilder::new()
  for token in @pattern.tokenize_pattern(pattern) {
    match token {
      @pattern.Literal(text) => builder.write_stringview(text)
      @pattern.Field(field, count) =>
        if is_supported_field(field) {
          append_field(builder, field, count, date, data)
        } else {
          match unsupported {
            Skip => ()
            Preserve => write_repeated(builder, field, count)
            Reject => return Err(UnsupportedField(field))
          }
        }
      @pattern.Placeholder(field, count) =>
        write_repeated(builder, field, count)
      @pattern.Currency(count) => write_repeated(builder, '¤', count)
      @pattern.Separator => builder.write_stringview(";")
    }
  }
  Ok(builder.to_string())
}

///|
/// Render a civil date-time with an explicit CLDR pattern.
///
/// Literal characters, including intentional leading and trailing spaces, are
/// preserved. Unsupported fields such as `z` are skipped by default; use
/// `format_pattern_with_policy` to preserve or reject them explicitly.
pub fn format_pattern(
  date : DateTime,
  locale : @core.Locale,
  pattern : String,
) -> String {
  match format_pattern_core(date, locale, pattern, Skip) {
    Ok(text) => text
    Err(_) => ""
  }
}

///|
/// Render an explicit CLDR pattern with an explicit unsupported-field policy.
///
/// `Reject` returns `UnsupportedField(field)` for fields such as `z` that this
/// civil date-time implementation cannot render.
pub fn format_pattern_with_policy(
  date : DateTime,
  locale : @core.Locale,
  pattern : String,
  unsupported : UnsupportedFieldPolicy,
) -> Result[String, DateFormatError] {
  format_pattern_core(date, locale, pattern, unsupported)
}

///|
fn date_pattern(data : @data.DateData, style : DateStyle) -> String {
  match style {
    Short => data.short_date
    Medium => data.medium_date
    Long => data.long_date
    Full => data.full_date
  }
}

///|
fn time_pattern(data : @data.DateData, style : TimeStyle) -> String {
  match style {
    Short => data.short_time
    Medium => data.medium_time
    Long => data.long_time
    Full => data.full_time
  }
}

///|
pub fn format_date(
  date : DateTime,
  locale : @core.Locale,
  style? : DateStyle,
) -> String {
  let data = resolve_date_data(locale)
  format_pattern(date, locale, date_pattern(data, style.unwrap_or(Medium)))
}

///|
pub fn format_time(
  date : DateTime,
  locale : @core.Locale,
  style? : TimeStyle,
) -> String {
  let data = resolve_date_data(locale)
  format_pattern(date, locale, time_pattern(data, style.unwrap_or(Medium)))
}

///|
/// Format a time style with an explicit unsupported-field policy. This is
/// useful for CLDR long/full time patterns, which contain timezone fields.
pub fn format_time_with_policy(
  date : DateTime,
  locale : @core.Locale,
  unsupported : UnsupportedFieldPolicy,
  style? : TimeStyle,
) -> Result[String, DateFormatError] {
  let data = resolve_date_data(locale)
  format_pattern_core(
    date,
    locale,
    time_pattern(data, style.unwrap_or(Medium)),
    unsupported,
  )
}

///|
fn same_date(left : DateTime, right : DateTime) -> Bool {
  left.year == right.year && left.month == right.month && left.day == right.day
}

///|
fn join_date_range(
  data : @data.DateData,
  start : String,
  end : String,
) -> String {
  let fallback = if data.interval_fallback.length() == 0 {
    "{0} \u{2013} {1}"
  } else {
    data.interval_fallback
  }
  fallback.replace_all(old="{0}", new=start).replace_all(old="{1}", new=end)
}

///|
/// Format a date range using the locale's CLDR interval fallback pattern.
/// A range whose endpoints fall on the same date is rendered once.
pub fn format_date_range(
  start : DateTime,
  end : DateTime,
  locale : @core.Locale,
  style? : DateStyle,
) -> String {
  if same_date(start, end) {
    return format_date(start, locale, style=style.unwrap_or(Medium))
  }
  let data = resolve_date_data(locale)
  let pattern = date_pattern(data, style.unwrap_or(Medium))
  let start_text = format_pattern(start, locale, pattern)
  let end_text = format_pattern(end, locale, pattern)
  join_date_range(data, start_text, end_text)
}

///|
/// Date and time joined by a space. Locale-specific connectors are not applied
/// yet; use `format_pattern` when exact control is needed.
pub fn format_datetime(
  date : DateTime,
  locale : @core.Locale,
  date_style? : DateStyle,
  time_style? : TimeStyle,
) -> String {
  format_date(date, locale, style=date_style.unwrap_or(Medium)) +
  " " +
  format_time(date, locale, style=time_style.unwrap_or(Medium))
}
