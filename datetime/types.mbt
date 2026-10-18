///|
/// CLDR date format widths.
pub(all) enum DateStyle {
  Short
  Medium
  Long
  Full
}

///|
/// CLDR time format widths.
pub(all) enum TimeStyle {
  Short
  Medium
  Long
  Full
}

///|
/// A civil date-time without timezone information.
pub(all) struct DateTime {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
}

///|
pub fn DateTime::new(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int,
  minute? : Int,
  second? : Int,
) -> DateTime {
  {
    year,
    month,
    day,
    hour: hour.unwrap_or(0),
    minute: minute.unwrap_or(0),
    second: second.unwrap_or(0),
  }
}

///|
/// Days since 1970-01-01 (Howard Hinnant's civil-from-days algorithm).
fn days_from_civil(year : Int, month : Int, day : Int) -> Int {
  let adjusted_year = if month <= 2 { year - 1 } else { year }
  let era = if adjusted_year >= 0 {
    adjusted_year / 400
  } else {
    (adjusted_year - 399) / 400
  }
  let year_of_era = adjusted_year - era * 400
  let month_prime = (month + 9) % 12
  let day_of_year = (153 * month_prime + 2) / 5 + day - 1
  let day_of_era = year_of_era * 365 +
    year_of_era / 4 -
    year_of_era / 100 +
    day_of_year
  era * 146097 + day_of_era - 719468
}

///|
/// Weekday index, 0 = Sunday and 6 = Saturday.
pub fn DateTime::weekday(self : DateTime) -> Int {
  let days = days_from_civil(self.year, self.month, self.day)
  let remainder = days % 7
  let normalized = if remainder < 0 { remainder + 7 } else { remainder }
  (normalized + 4) % 7
}
