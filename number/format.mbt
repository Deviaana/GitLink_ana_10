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
        scientific_pattern: "#E0",
        compact_patterns: [],
        compact_plural_patterns: [],
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
fn trim_fraction(frac_digits : String, min_fraction : Int) -> String {
  let mut result = frac_digits
  while result.length() > min_fraction && result.has_suffix("0") {
    result = result[0:result.length() - 1].to_owned()
  }
  if result.length() < min_fraction {
    result = result.pad_end(min_fraction, '0')
  }
  result
}

///|
fn format_digits_text(
  raw : String,
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
  let rounded = @decimal.round_to_fraction(raw, max_clamped)
  (rounded.0, trim_fraction(rounded.1, min_clamped))
}

///|
fn format_digits(
  value : Double,
  max_fraction : Int,
  min_fraction : Int,
) -> (String, String) {
  format_digits_text(value.to_string(), max_fraction, min_fraction)
}

///|
fn format_exponent(
  exponent : Int,
  min_digits : Int,
  always_plus : Bool,
  data : @data.NumberData,
) -> String {
  let digits = exponent.abs().to_string().pad_start(min_digits, '0')
  if exponent < 0 {
    data.minus_sign + digits
  } else if always_plus {
    data.plus_sign + digits
  } else {
    digits
  }
}

///|
fn scientific_digits(
  value : Double,
  data : @data.NumberData,
  max_fraction : Int,
  min_fraction : Int,
  exponent_min_digits : Int,
  exponent_plus : Bool,
) -> (String, String, String) {
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
  if value == 0.0 {
    let fraction = trim_fraction("", min_clamped)
    return (
      "0",
      fraction,
      "E" + format_exponent(0, exponent_min_digits, exponent_plus, data),
    )
  }
  let expanded = @decimal.expand_decimal(value.to_string())
  let digits = expanded.0 + expanded.1
  let mut first = 0
  while first < digits.length() && digits[first] == '0' {
    first = first + 1
  }
  if first >= digits.length() {
    return (
      "0",
      trim_fraction("", min_clamped),
      "E" + format_exponent(0, exponent_min_digits, exponent_plus, data),
    )
  }
  let mut exponent = expanded.0.length() - first - 1
  let significant = digits[first:digits.length()]
  let mantissa = if significant.length() > 1 {
    significant[0:1] + "." + significant[1:significant.length()]
  } else {
    significant
  }
  let rounded = format_digits_text(
    mantissa.to_owned(),
    max_clamped,
    min_clamped,
  )
  let mut mantissa_integer = rounded.0
  let mut mantissa_fraction = rounded.1
  if mantissa_integer.length() > 1 {
    exponent = exponent + 1
    let combined = mantissa_integer + mantissa_fraction
    let wanted = 1 + max_clamped
    let normalized = if combined.length() >= wanted {
      combined[0:wanted]
    } else {
      combined.pad_end(wanted, '0')
    }
    mantissa_integer = normalized[0:1].to_owned()
    mantissa_fraction = trim_fraction(
      normalized[1:wanted].to_owned(),
      min_clamped,
    )
  }
  (
    mantissa_integer,
    mantissa_fraction,
    "E" + format_exponent(exponent, exponent_min_digits, exponent_plus, data),
  )
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
  let max_fraction = options.max_fraction.unwrap_or(parsed.max_fraction)
  let min_fraction = options.min_fraction.unwrap_or(parsed.min_fraction)
  let mut exponent_text = ""
  let parts = if parsed.scientific {
    let scientific = scientific_digits(
      absolute,
      data,
      max_fraction,
      min_fraction,
      parsed.exponent_min_digits,
      parsed.exponent_plus,
    )
    exponent_text = scientific.2
    (scientific.0, scientific.1)
  } else {
    format_digits(absolute, max_fraction, min_fraction)
  }
  let int_digits = parts.0.pad_start(parsed.min_integer, '0')
  let frac_digits = parts.1
  let grouped = if options.grouping && !parsed.scientific {
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
  text = text + exponent_text + suffix
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
fn decimal_order(value : Double) -> Int {
  let expanded = @decimal.expand_decimal(value.to_string())
  let digits = expanded.0 + expanded.1
  let mut first = 0
  while first < digits.length() && digits[first] == '0' {
    first = first + 1
  }
  if first >= digits.length() {
    0
  } else {
    expanded.0.length() - first - 1
  }
}

///|
fn compact_magnitude(data : @data.NumberData, value_order : Int) -> Int? {
  let mut selected : Int? = None
  for entry in data.compact_patterns {
    let order = entry.0
    if order <= value_order {
      match selected {
        None => selected = Some(order)
        Some(current) => if order > current { selected = Some(order) }
      }
    }
  }
  selected
}

///|
fn compact_pattern(
  data : @data.NumberData,
  magnitude : Int,
  category : String,
) -> String? {
  for entry in data.compact_plural_patterns {
    if entry.0 == magnitude && entry.1 == category {
      return Some(entry.2)
    }
  }
  for entry in data.compact_patterns {
    if entry.0 == magnitude {
      return Some(entry.1)
    }
  }
  None
}

///|
fn shift_decimal_text(raw : String, shift : Int) -> String {
  let parts = @decimal.expand_decimal(raw)
  let digits = parts.0 + parts.1
  let point = parts.0.length() + shift
  if point <= 0 {
    "0." + repeat_char('0', -point) + digits
  } else if point >= digits.length() {
    digits + repeat_char('0', point - digits.length())
  } else {
    digits[0:point].to_owned() + "." + digits[point:digits.length()].to_owned()
  }
}

///|
fn compact_max_fraction(section : NumberPattern) -> Int {
  if section.max_fraction > 0 {
    section.max_fraction
  } else if section.min_integer == 1 {
    1
  } else {
    0
  }
}

///|
fn format_compact_plain(
  value : Double,
  data : @data.NumberData,
  options : NumberOptions,
) -> String {
  let negative = value < 0.0
  let absolute = if negative { -value } else { value }
  let parsed = parse_pattern(data.decimal_pattern)
  let max_fraction = options.max_fraction.unwrap_or(parsed.max_fraction)
  let min_fraction = options.min_fraction.unwrap_or(parsed.min_fraction)
  let digits = format_digits(absolute, max_fraction, min_fraction)
  let int_digits = digits.0
  let grouped = if options.grouping && int_digits.length() >= 5 {
    group_digits(
      int_digits,
      parsed.group_primary,
      parsed.group_secondary,
      data.group,
    )
  } else {
    int_digits
  }
  let prefix = if negative {
    data.minus_sign + parsed.positive_prefix
  } else {
    parsed.positive_prefix
  }
  let mut text = prefix + grouped
  if digits.1.length() > 0 {
    text = text + data.decimal + digits.1
  }
  text + parsed.positive_suffix
}

///|
/// Format a number with the locale's short compact notation.
pub fn format_compact(
  value : Double,
  locale : @core.Locale,
  options? : NumberOptions,
) -> String {
  let data = resolve_number_data(locale)
  let opts = options.unwrap_or(NumberOptions::default())
  if value.is_nan() || value.is_inf() {
    return format_decimal(value, locale, options=opts)
  }
  let absolute = value.abs()
  let magnitude = match compact_magnitude(data, decimal_order(absolute)) {
    Some(order) => order
    None => return format_compact_plain(value, data, opts)
  }
  let base_pattern = match compact_pattern(data, magnitude, "other") {
    Some(pattern) => pattern
    None => return format_compact_plain(value, data, opts)
  }
  let base = parse_pattern(base_pattern)
  if base.positive_prefix.length() == 0 && base.positive_suffix.length() == 0 {
    return format_compact_plain(value, data, opts)
  }
  let base_shift = magnitude - (base.min_integer - 1)
  let base_scaled = shift_decimal_text(absolute.to_string(), -base_shift)
  let base_digits = format_digits_text(
    base_scaled,
    opts.max_fraction.unwrap_or(compact_max_fraction(base)),
    opts.min_fraction.unwrap_or(base.min_fraction),
  )
  let category = @plural.PluralRules::cached(locale.language).select_with_digits(
    base_digits.0,
    base_digits.1,
  )
  let pattern = compact_pattern(data, magnitude, category).unwrap_or(
    base_pattern,
  )
  let section = parse_pattern(pattern)
  if section.positive_prefix.length() == 0 &&
    section.positive_suffix.length() == 0 {
    return format_compact_plain(value, data, opts)
  }
  let shift = magnitude - (section.min_integer - 1)
  let scaled = shift_decimal_text(absolute.to_string(), -shift)
  let digits = format_digits_text(
    scaled,
    opts.max_fraction.unwrap_or(compact_max_fraction(section)),
    opts.min_fraction.unwrap_or(section.min_fraction),
  )
  let negative = value < 0.0
  let prefix = if negative && section.has_negative {
    section.negative_prefix
  } else if negative {
    data.minus_sign + section.positive_prefix
  } else {
    section.positive_prefix
  }
  let suffix = if negative && section.has_negative {
    section.negative_suffix
  } else {
    section.positive_suffix
  }
  let mut text = prefix + digits.0.pad_start(section.min_integer, '0')
  if digits.1.length() > 0 {
    text = text + data.decimal + digits.1
  }
  text + suffix
}

///|
/// Format a number using the locale's scientific notation pattern.
pub fn format_scientific(
  value : Double,
  locale : @core.Locale,
  options? : NumberOptions,
) -> String {
  let data = resolve_number_data(locale)
  let resolved = match options {
    Some(value) => value
    None => { min_fraction: None, max_fraction: Some(3), grouping: true }
  }
  format_core(value, locale, data.scientific_pattern, resolved, None)
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
