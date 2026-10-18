///|
/// Per-call overrides for number formatting.
pub(all) struct NumberOptions {
  min_fraction : Int?
  max_fraction : Int?
  grouping : Bool
}

///|
pub fn NumberOptions::default() -> NumberOptions {
  { min_fraction: None, max_fraction: None, grouping: true }
}

///|
/// Fix the number of fraction digits, e.g. `with_fraction_digits(2, 2)` for money.
pub fn NumberOptions::with_fraction_digits(
  min : Int,
  max : Int,
) -> NumberOptions {
  {
    min_fraction: Some(if min < 0 { 0 } else { min }),
    max_fraction: Some(if max < 0 { 0 } else { max }),
    grouping: true,
  }
}

///|
/// Disable digit grouping (useful for machine-readable output).
pub fn NumberOptions::without_grouping(self : NumberOptions) -> NumberOptions {
  {
    min_fraction: self.min_fraction,
    max_fraction: self.max_fraction,
    grouping: false,
  }
}
