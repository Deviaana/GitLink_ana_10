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
        currency_symbols: [],
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
fn replace_currency(text : String, symbol : String) -> String {
  text.replace_all(old="¤", new=symbol)
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
fn format_core(
  value : Double,
  locale : @core.Locale,
  pattern : String,
  options : NumberOptions,
  currency_symbol : String?,
) -> String {
  let data = resolve_number_data(locale)
  if value.is_nan() {
    return data.nan
  }
  if value.is_inf() {
    return if value < 0.0 {
      data.minus_sign + data.infinity
    } else {
      data.infinity
    }
  }
  let negative = value < 0.0
  let absolute = if negative { -value } else { value }
  let parsed = parse_pattern(pattern)
  let max_fraction = options.max_fraction.unwrap_or(parsed.max_fraction)
  let min_fraction = options.min_fraction.unwrap_or(parsed.min_fraction)
  let max_fraction_clamped = if max_fraction > 15 {
    15
  } else if max_fraction < 0 {
    0
  } else {
    max_fraction
  }
  let min_fraction_clamped = if min_fraction > max_fraction_clamped {
    max_fraction_clamped
  } else if min_fraction < 0 {
    0
  } else {
    min_fraction
  }
  let mut factor = 1.0
  for _ in 0..<max_fraction_clamped {
    factor = factor * 10.0
  }
  let rounded = (absolute * factor).round() / factor
  let raw = rounded.to_string()
  let pieces : Array[String] = []
  for piece in raw.split(".") {
    pieces.push(piece.to_owned())
  }
  let mut int_digits = if pieces.length() > 0 && pieces[0].length() > 0 {
    pieces[0]
  } else {
    "0"
  }
  let mut frac_digits = if pieces.length() > 1 { pieces[1] } else { "" }
  while frac_digits.length() > min_fraction_clamped &&
        frac_digits.has_suffix("0") {
    frac_digits = frac_digits[0:frac_digits.length() - 1].to_owned()
  }
  if frac_digits.length() < min_fraction_clamped {
    frac_digits = frac_digits.pad_end(min_fraction_clamped, '0')
  }
  int_digits = int_digits.pad_start(parsed.min_integer, '0')
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
  match currency_symbol {
    Some(symbol) => {
      prefix = replace_currency(prefix, symbol)
      suffix = replace_currency(suffix, symbol)
    }
    None => ()
  }
  let mut result = prefix + grouped
  if frac_digits.length() > 0 {
    result = result + data.decimal + frac_digits
  }
  result + suffix
}

///|
/// Format a plain decimal number for the given locale.
pub fn format_decimal(
  value : Double,
  locale : @core.Locale,
  options? : NumberOptions,
) -> String {
  let data = resolve_number_data(locale)
  format_core(
    value,
    locale,
    data.decimal_pattern,
    options.unwrap_or(NumberOptions::default()),
    None,
  )
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
    data.percent_pattern,
    options.unwrap_or(NumberOptions::default()),
    None,
  )
}

///|
/// Format an amount in the given ISO 4217 currency code.
pub fn format_currency(
  amount : Double,
  code : String,
  locale : @core.Locale,
  options? : NumberOptions,
) -> String {
  let data = resolve_number_data(locale)
  let symbol = data.currency_symbol(code)
  let resolved = options.unwrap_or(NumberOptions::default())
  let digits = @data.currency_digits(code)
  let with_money_digits : NumberOptions = {
    min_fraction: Some(resolved.min_fraction.unwrap_or(digits)),
    max_fraction: Some(resolved.max_fraction.unwrap_or(digits)),
    grouping: resolved.grouping,
  }
  format_core(
    amount,
    locale,
    data.currency_pattern,
    with_money_digits,
    Some(symbol),
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
