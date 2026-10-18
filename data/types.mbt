///|
/// Locale-specific data needed to render numbers and currencies.
pub(all) struct NumberData {
  decimal : String
  group : String
  percent_sign : String
  minus_sign : String
  plus_sign : String
  nan : String
  infinity : String
  decimal_pattern : String
  percent_pattern : String
  currency_pattern : String
  accounting_pattern : String
  currency_unit_pattern_one : String
  currency_unit_pattern_other : String
  currency_spacing : String
  currency_symbols : Array[(String, String)]
  currency_narrow_symbols : Array[(String, String)]
  currency_names : Array[(String, String, String)]
}

///|
/// Look up a currency symbol, falling back to the ISO code itself.
pub fn NumberData::currency_symbol(self : NumberData, code : String) -> String {
  let upper = code.to_upper()
  for entry in self.currency_symbols {
    if entry.0 == upper {
      return entry.1
    }
  }
  upper
}

///|
/// Look up a narrow currency symbol, falling back to the regular symbol.
pub fn NumberData::currency_narrow_symbol(
  self : NumberData,
  code : String,
) -> String {
  let upper = code.to_upper()
  for entry in self.currency_narrow_symbols {
    if entry.0 == upper {
      return entry.1
    }
  }
  self.currency_symbol(upper)
}

///|
/// Look up a currency display name for a CLDR plural category.
pub fn NumberData::currency_name(
  self : NumberData,
  code : String,
  category : String,
) -> String {
  let upper = code.to_upper()
  for entry in self.currency_names {
    if entry.0 == upper {
      return if category == "one" { entry.1 } else { entry.2 }
    }
  }
  upper
}

///|
/// Locale-specific Gregorian calendar data.
pub(all) struct DateData {
  full_date : String
  long_date : String
  medium_date : String
  short_date : String
  full_time : String
  long_time : String
  medium_time : String
  short_time : String
  months_wide : Array[String]
  months_abbr : Array[String]
  days_wide : Array[String]
  days_abbr : Array[String]
  am : String
  pm : String
}

///|
/// CLDR plural rules, stored as raw rule strings.
pub(all) struct PluralData {
  cardinal : Array[(String, String)]
  ordinal : Array[(String, String)]
}

///|
/// Relative-time patterns for one unit (year, month, day, ...).
pub(all) struct RelativeUnitData {
  future : Array[(String, String)]
  past : Array[(String, String)]
  zero : String?
  one_future : String?
  one_past : String?
}

///|
/// Relative-time patterns for every supported unit.
pub(all) struct RelativeData {
  year : RelativeUnitData
  month : RelativeUnitData
  week : RelativeUnitData
  day : RelativeUnitData
  hour : RelativeUnitData
  minute : RelativeUnitData
  second : RelativeUnitData
}
