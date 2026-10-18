///|
/// Result of formatting a number, including the exact digits used for type
/// selection. `integer_digits` and `fraction_digits` are ungrouped and unsigned.
pub(all) struct NumberFormatResult {
  text : String
  integer_digits : String
  fraction_digits : String
}

///|
fn fallback_number_data() -> @data.NumberData {
  match @data.number_data("en") {
    Some(data) => data
    None =>
      {
        decimal: ".",
        group: ",",
        percent_sign: "%",
        minus_sign: "-",
        plus_sign: "+",
        nan: "NaN",
        infinity: "∞",
        decimal_pattern: "#,##0.###",
        percent_pattern: "#,##0%",
        currency_pattern: "¤#,##0.00",
        accounting_pattern: "¤#,##0.00;(¤#,##0.00)",
        currency_unit_pattern_one: "{0} {1}",
        currency_unit_pattern_other: "{0} {1}",
        currency_spacing: "\u{00A0}",
        currency_symbol_overrides: [],
        currency_narrow_symbol_overrides: [],
        currency_names: [],
      }
  }
}

///|
fn resolve_number_data(locale : @core.Locale) -> @data.NumberData {
  for anchor in locale.fallbacks() {
    match @data.number_data(anchor) {
      Some(data) => return data
      None => ()
    }
  }
  fallback_number_data()
}

///|
priv struct CurrencyReplacement {
  display : String
  narrow : String
  code : String
  name : String
  spacing : String
  alpha_display : Bool
  alpha_narrow : Bool
}

///|
fn CurrencyReplacement::text_for_markers(
  self : CurrencyReplacement,
  count : Int,
) -> String {
  match count {
    1 => self.display
    2 => self.code
    3 => self.name
    _ => self.narrow
  }
}

///|
fn CurrencyReplacement::needs_spacing(
  self : CurrencyReplacement,
  count : Int,
) -> Bool {
  match count {
    1 => self.alpha_display
    2 | 3 => true
    _ => self.alpha_narrow
  }
}

///|
fn is_alpha_currency_text(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  for c in text.iter() {
    if !c.is_ascii_alphabetic() {
      return false
    }
  }
  true
}

///|
fn is_digit_placeholder(c : Char) -> Bool {
  c == '0' || c == '#'
}

///|
fn replace_currency(
  text : String,
  currency : CurrencyReplacement,
  before_number : Bool,
) -> String {
  let chars = text.to_array()
  let builder = StringBuilder::new()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '¤' {
      let start = index
      while index < chars.length() && chars[index] == '¤' {
        index = index + 1
      }
      let count = index - start
      let alpha = currency.needs_spacing(count)
      if alpha &&
        (
          (start > 0 && is_digit_placeholder(chars[start - 1])) ||
          (!before_number && start == 0)
        ) {
        builder.write_stringview(currency.spacing)
      }
      builder.write_stringview(currency.text_for_markers(count))
      if alpha &&
        (
          (index < chars.length() && is_digit_placeholder(chars[index])) ||
          (before_number && index == chars.length())
        ) {
        builder.write_stringview(currency.spacing)
      }
    } else {
      builder.write_object(chars[index])
      index = index + 1
    }
  }
  builder.to_string()
}

///|
fn format_digits(
  value : Double,
  max_fraction : Int,
  min_fraction : Int,
) -> (String, String) {
  let max_clamped = if max_fraction > 15 {
    15
  } else if max_fraction < 0 {
    0
  } else {
    max_fraction
  }
  let min_clamped = if min_fraction > max_clamped {
    max_clamped
  } else if min_fraction < 0 {
    0
  } else {
    min_fraction
  }
  let rounded = @decimal.round_to_fraction(value.to_string(), max_clamped)
  let int_digits = rounded.0
  let mut frac_digits = rounded.1
  while frac_digits.length() > min_clamped && frac_digits.has_suffix("0") {
    frac_digits = frac_digits[0:frac_digits.length() - 1].to_owned()
  }
  if frac_digits.length() < min_clamped {
    frac_digits = frac_digits.pad_end(min_clamped, '0')
  }
  (int_digits, frac_digits)
}

///|
fn group_digits(
  digits : String,
  primary : Int,
  secondary : Int,
  separator : String,
) -> String {
  let length = digits.length()
  if primary <= 0 || length <= primary {
    return digits
  }
  let breaks : Array[Int] = []
  let step = if secondary > 0 { secondary } else { primary }
  let mut position = length - primary
  while position > 0 {
    breaks.push(position)
    position = position - step
  }
  let builder = StringBuilder::new()
  for i, c in digits.iter2() {
    if breaks.contains(i) {
      builder.write_stringview(separator)
    }
    builder.write_object(c)
  }
  builder.to_string()
}

///|
fn format_core_result(
  value : Double,
  locale : @core.Locale,
  pattern : String,
  options : NumberOptions,
  currency : CurrencyReplacement?,
) -> NumberFormatResult {
  let data = resolve_number_data(locale)
  if value.is_nan() {
    return { text: data.nan, integer_digits: "", fraction_digits: "" }
  }
  if value.is_inf() {
    let text = if value < 0.0 {
      data.minus_sign + data.infinity
    } else {
      data.infinity
    }
    return { text, integer_digits: "", fraction_digits: "" }
  }
  let negative = value < 0.0
  let absolute = if negative { -value } else { value }
  let parsed = parse_pattern(pattern)
  let parts = format_digits(
    absolute,
    options.max_fraction.unwrap_or(parsed.max_fraction),
    options.min_fraction.unwrap_or(parsed.min_fraction),
  )
  let int_digits = parts.0.pad_start(parsed.min_integer, '0')
  let frac_digits = parts.1
  let grouped = if options.grouping {
    group_digits(
      int_digits,
      parsed.group_primary,
      parsed.group_secondary,
      data.group,
    )
  } else {
    int_digits
  }
  let mut prefix = if negative && parsed.has_negative {
    parsed.negative_prefix
  } else if negative {
    data.minus_sign + parsed.positive_prefix
  } else {
    parsed.positive_prefix
  }
  let mut suffix = if negative && parsed.has_negative {
    parsed.negative_suffix
  } else {
    parsed.positive_suffix
  }
  match currency {
    Some(info) => {
      prefix = replace_currency(prefix, info, true)
      suffix = replace_currency(suffix, info, false)
    }
    None => ()
  }
  let mut text = prefix + grouped
  if frac_digits.length() > 0 {
    text = text + data.decimal + frac_digits
  }
  text = text + suffix
  { text, integer_digits: int_digits, fraction_digits: frac_digits }
}

///|
fn format_core(
  value : Double,
  locale : @core.Locale,
  pattern : String,
  options : NumberOptions,
  currency : CurrencyReplacement?,
) -> String {
  format_core_result(value, locale, pattern, options, currency).text
}

///|
/// Format a decimal and return both the text and the digits used to render it.
pub fn format_decimal_result(
  value : Double,
  locale : @core.Locale,
  options? : NumberOptions,
) -> NumberFormatResult {
  let data = resolve_number_data(locale)
  format_core_result(
    value,
    locale,
    data.decimal_pattern,
    options.unwrap_or(NumberOptions::default()),
    None,
  )
}

///|
/// Format a plain decimal number for the given locale.
pub fn format_decimal(
  value : Double,
  locale : @core.Locale,
  options? : NumberOptions,
) -> String {
  format_decimal_result(value, locale, options?).text
}

///|
/// Format a ratio as a percentage (`0.125` becomes `12.5%`).
pub fn format_percent(
  ratio : Double,
  locale : @core.Locale,
  options? : NumberOptions,
) -> String {
  let data = resolve_number_data(locale)
  format_core(
    ratio * 100.0,
    locale,
    data.percent_pattern.replace_all(old="%", new=data.percent_sign),
    options.unwrap_or(NumberOptions::default()),
    None,
  )
}

///|
fn make_currency_replacement(
  data : @data.NumberData,
  code : String,
  amount : Double,
  locale : @core.Locale,
  display : CurrencyDisplay,
  min_fraction : Int,
  max_fraction : Int,
) -> CurrencyReplacement {
  let upper = code.to_upper()
  let digits = format_digits(amount.abs(), max_fraction, min_fraction)
  let category = @plural.PluralRules::cached(locale.language).select_with_digits(
    digits.0,
    digits.1,
  )
  let symbol = data.currency_symbol(upper)
  let narrow = data.currency_narrow_symbol(upper)
  let name = data.currency_name(upper, category)
  let shown = match display {
    Symbol => symbol
    Code => upper
    Name => name
    NarrowSymbol => narrow
  }
  let alpha_display = match display {
    Symbol => is_alpha_currency_text(shown)
    NarrowSymbol => is_alpha_currency_text(shown)
    Code | Name => true
  }
  {
    display: shown,
    narrow,
    code: upper,
    name,
    spacing: data.currency_spacing,
    alpha_display,
    alpha_narrow: is_alpha_currency_text(narrow),
  }
}

///|
fn format_currency_name(
  amount : Double,
  code : String,
  locale : @core.Locale,
  data : @data.NumberData,
  options : NumberOptions,
  min_fraction : Int,
  max_fraction : Int,
) -> String {
  let upper = code.to_upper()
  let digits = format_digits(amount.abs(), max_fraction, min_fraction)
  let category = @plural.PluralRules::cached(locale.language).select_with_digits(
    digits.0,
    digits.1,
  )
  let name = data.currency_name(upper, category)
  let number_options : NumberOptions = {
    min_fraction: Some(min_fraction),
    max_fraction: Some(max_fraction),
    grouping: options.grouping,
  }
  let number = format_decimal(amount, locale, options=number_options)
  let raw_pattern = if category == "one" {
    data.currency_unit_pattern_one
  } else {
    data.currency_unit_pattern_other
  }
  let pattern = if raw_pattern.length() == 0 { "{0} {1}" } else { raw_pattern }
  pattern.replace_all(old="{0}", new=number).replace_all(old="{1}", new=name)
}

///|
fn format_currency_impl(
  amount : Double,
  code : String,
  locale : @core.Locale,
  pattern : String,
  options : NumberOptions,
  currency_options : CurrencyOptions,
) -> String {
  let data = resolve_number_data(locale)
  let digits = @data.currency_digits(code)
  let min_fraction = options.min_fraction.unwrap_or(digits)
  let max_fraction = options.max_fraction.unwrap_or(digits)
  let with_money_digits : NumberOptions = {
    min_fraction: Some(min_fraction),
    max_fraction: Some(max_fraction),
    grouping: options.grouping,
  }
  let currency = make_currency_replacement(
    data,
    code,
    amount,
    locale,
    currency_options.display,
    min_fraction,
    max_fraction,
  )
  format_core(amount, locale, pattern, with_money_digits, Some(currency))
}

///|
/// Format an amount in the given ISO 4217 currency code.
///
/// `currency_options` controls symbol/code/name display and accounting
/// formatting for negative amounts.
pub fn format_currency(
  amount : Double,
  code : String,
  locale : @core.Locale,
  options? : NumberOptions,
  currency_options? : CurrencyOptions,
) -> String {
  let data = resolve_number_data(locale)
  let currency_opts = currency_options.unwrap_or(CurrencyOptions::default())
  let resolved = options.unwrap_or(NumberOptions::default())
  let digits = @data.currency_digits(code)
  let min_fraction = resolved.min_fraction.unwrap_or(digits)
  let max_fraction = resolved.max_fraction.unwrap_or(digits)
  let is_name = match currency_opts.display {
    Name => true
    _ => false
  }
  if is_name {
    return format_currency_name(
      amount, code, locale, data, resolved, min_fraction, max_fraction,
    )
  }
  let pattern = if currency_opts.accounting && amount < 0.0 {
    data.accounting_pattern
  } else {
    data.currency_pattern
  }
  format_currency_impl(amount, code, locale, pattern, resolved, currency_opts)
}

///|
/// Format a currency amount with an explicit pattern, including `¤`, `¤¤`,
/// `¤¤¤` and `¤¤¤¤` currency markers.
pub fn format_currency_with_pattern(
  amount : Double,
  code : String,
  locale : @core.Locale,
  pattern : String,
  options? : NumberOptions,
  currency_options? : CurrencyOptions,
) -> String {
  format_currency_impl(
    amount,
    code,
    locale,
    pattern,
    options.unwrap_or(NumberOptions::default()),
    currency_options.unwrap_or(CurrencyOptions::default()),
  )
}

///|
/// Format with an explicit CLDR pattern, mainly useful for tests and extensions.
pub fn format_with_pattern(
  value : Double,
  locale : @core.Locale,
  pattern : String,
  options? : NumberOptions,
) -> String {
  format_core(
    value,
    locale,
    pattern,
    options.unwrap_or(NumberOptions::default()),
    None,
  )
}
