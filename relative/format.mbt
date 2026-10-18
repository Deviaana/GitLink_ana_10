///|
/// Units supported by relative time formatting.
pub(all) enum RelativeUnit {
  Year
  Month
  Week
  Day
  Hour
  Minute
  Second
}

///|
fn unit_data(
  data : @data.RelativeData,
  unit : RelativeUnit,
) -> @data.RelativeUnitData {
  match unit {
    Year => data.year
    Month => data.month
    Week => data.week
    Day => data.day
    Hour => data.hour
    Minute => data.minute
    Second => data.second
  }
}

///|
fn resolve_relative_data(locale : @core.Locale) -> @data.RelativeData {
  for anchor in locale.fallbacks() {
    match @data.relative_data(anchor) {
      Some(data) => return data
      None => ()
    }
  }
  match @data.relative_data("en") {
    Some(data) => data
    None =>
      {
        year: empty_unit(),
        month: empty_unit(),
        week: empty_unit(),
        day: empty_unit(),
        hour: empty_unit(),
        minute: empty_unit(),
        second: empty_unit(),
      }
  }
}

///|
fn empty_unit() -> @data.RelativeUnitData {
  { future: [], past: [], zero: None, one_future: None, one_past: None }
}

///|
fn pattern_for(table : Array[(String, String)], category : String) -> String {
  let mut fallback = ""
  for entry in table {
    if entry.0 == category {
      return entry.1
    }
    if entry.0 == "other" {
      fallback = entry.1
    }
  }
  fallback
}

///|
/// Format a relative offset such as `3 days ago` or `in 2 hours`.
///
/// Positive values are in the future, negative values in the past.
pub fn format_relative(
  value : Double,
  unit : RelativeUnit,
  locale : @core.Locale,
) -> String {
  let data = resolve_relative_data(locale)
  let unit_patterns = unit_data(data, unit)
  if value == 0.0 {
    match unit_patterns.zero {
      Some(text) => return text
      None => ()
    }
  }
  if value == 1.0 {
    match unit_patterns.one_future {
      Some(text) => return text
      None => ()
    }
  }
  if value == -1.0 {
    match unit_patterns.one_past {
      Some(text) => return text
      None => ()
    }
  }
  let magnitude = value.abs()
  let category = @plural.PluralRules::new(locale.language).select(magnitude)
  let table = if value > 0.0 {
    unit_patterns.future
  } else {
    unit_patterns.past
  }
  let mut pattern = pattern_for(table, category)
  if pattern.length() == 0 {
    pattern = "{0}"
  }
  let number = @number.format_decimal(magnitude, locale)
  pattern.replace_all(old="{0}", new=number)
}
