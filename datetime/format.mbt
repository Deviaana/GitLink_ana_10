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
/// Render a civil date-time with an explicit CLDR pattern.
///
/// Unsupported fields (notably timezone fields such as `z`) are skipped.
pub fn format_pattern(
  date : DateTime,
  locale : @core.Locale,
  pattern : String,
) -> String {
  let data = resolve_date_data(locale)
  let chars = pattern.to_array()
  let builder = StringBuilder::new()
  let length = chars.length()
  let mut index = 0
  while index < length {
    let c = chars[index]
    if c.to_int() == 39 {
      index = index + 1
      let mut closed = false
      while index < length && !closed {
        if chars[index].to_int() == 39 {
          if index + 1 < length && chars[index + 1].to_int() == 39 {
            builder.write_stringview("'")
            index = index + 2
          } else {
            index = index + 1
            closed = true
          }
        } else {
          builder.write_object(chars[index])
          index = index + 1
        }
      }
      continue
    }
    if c.is_ascii_alphabetic() {
      let start = index
      while index < length && chars[index] == c {
        index = index + 1
      }
      append_field(builder, c, index - start, date, data)
      continue
    }
    builder.write_object(c)
    index = index + 1
  }
  builder.to_string().trim().to_owned()
}

///|
pub fn format_date(
  date : DateTime,
  locale : @core.Locale,
  style? : DateStyle,
) -> String {
  let data = resolve_date_data(locale)
  let pattern = match style.unwrap_or(Medium) {
    Short => data.short_date
    Medium => data.medium_date
    Long => data.long_date
    Full => data.full_date
  }
  format_pattern(date, locale, pattern)
}

///|
pub fn format_time(
  date : DateTime,
  locale : @core.Locale,
  style? : TimeStyle,
) -> String {
  let data = resolve_date_data(locale)
  let pattern = match style.unwrap_or(Medium) {
    Short => data.short_time
    Medium => data.medium_time
    Long => data.long_time
    Full => data.full_time
  }
  format_pattern(date, locale, pattern)
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
