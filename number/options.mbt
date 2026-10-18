///|
/// Per-call overrides for number formatting.
pub(all) struct NumberOptions {
  min_fraction : Int32?
  max_fraction : Int32?
  grouping : Bool
}

///|
pub fn NumberOptions::default() -> NumberOptions {
  { min_fraction: None, max_fraction: None, grouping: true, }
}

///|
/// Fix the number of fraction digits, e.g. `with_fraction_digits(2, 2)` for money.
pub fn NumberOptions::with_fraction_digits(
  min : Int32,
  max : Int32,
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

///|
/// How the currency is rendered in a number pattern.
pub(all) enum CurrencyDisplay {
  Symbol
  Code
  Name
  NarrowSymbol
}

///|
/// Currency-specific rendering options.
pub(all) struct CurrencyOptions {
  display : CurrencyDisplay
  accounting : Bool
}

///|
pub fn CurrencyOptions::default() -> CurrencyOptions {
  { display: Symbol, accounting: false, }
}

///|
pub fn CurrencyOptions::with_display(
  display : CurrencyDisplay,
) -> CurrencyOptions {
  { display, accounting: false, }
}

///|
/// Use the locale accounting pattern for negative amounts.
pub fn CurrencyOptions::with_accounting(
  self : CurrencyOptions,
) -> CurrencyOptions {
  { display: self.display, accounting: true, }
}
