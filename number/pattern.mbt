///|
/// A parsed section of a CLDR number pattern.
priv struct NumberSection {
  prefix : String
  suffix : String
  min_integer : Int32
  min_fraction : Int32
  max_fraction : Int32
  group_primary : Int32
  group_secondary : Int32
  scientific : Bool
  exponent_min_digits : Int32
  exponent_plus : Bool
  significant : Bool
  min_significant : Int32
  max_significant : Int32
  rounding_increment : Int32
  scale : Int32
  pad_char : Char?
  pad_width : Int32
}

///|
/// A complete number pattern with an optional negative subpattern.
priv struct NumberPattern {
  positive_prefix : String
  positive_suffix : String
  negative_prefix : String
  negative_suffix : String
  has_negative : Bool
  min_integer : Int32
  min_fraction : Int32
  max_fraction : Int32
  group_primary : Int32
  group_secondary : Int32
  scientific : Bool
  exponent_min_digits : Int32
  exponent_plus : Bool
  significant : Bool
  min_significant : Int32
  max_significant : Int32
  rounding_increment : Int32
  scale : Int32
  pad_char : Char?
  pad_width : Int32
}

///|
fn repeat_char(field : Char, count : Int32) -> String {
  let builder = StringBuilder::new()
  let mut index = 0
  while index < count {
    builder.write_object(field)
    index = index + 1
  }
  builder.to_string()
}

///|
fn token_text(token : @pattern.PatternToken) -> String {
  match token {
    @pattern.Literal(text) => text
    @pattern.Quoted(text) => text
    @pattern.Pad(_) => ""
    @pattern.Field(field, count) => repeat_char(field, count)
    @pattern.Placeholder(field, count) => repeat_char(field, count)
    @pattern.Currency(count) => repeat_char('¤', count)
    @pattern.Separator => ";"
  }
}

///|
fn tokens_text(
  tokens : Array[@pattern.PatternToken],
  start : Int32,
  end : Int32,
) -> String {
  let builder = StringBuilder::new()
  let mut index = start
  while index < end {
    builder.write_stringview(token_text(tokens[index]))
    index = index + 1
  }
  builder.to_string()
}

///|
fn text_without_pad(
  tokens : Array[@pattern.PatternToken],
  start : Int32,
  end : Int32,
  percent_sign : String,
  currency : CurrencyReplacement?,
  before_number : Bool,
) -> (String, Char?) {
  let builder = StringBuilder::new()
  let mut pad_char : Char? = None
  let mut index = start
  while index < end {
    match tokens[index] {
      @pattern.Literal(text) =>
        builder.write_stringview(text.replace_all(old="%", new=percent_sign))
      @pattern.Quoted(text) =>
        builder.write_stringview(text.replace_all(old="¤", new="\u{E000}"))
      @pattern.Pad(pad) => pad_char = Some(pad)
      @pattern.Field(field, count) =>
        builder.write_stringview(repeat_char(field, count))
      @pattern.Placeholder(field, count) =>
        builder.write_stringview(repeat_char(field, count))
      @pattern.Currency(count) =>
        builder.write_stringview(repeat_char('¤', count))
      @pattern.Separator => builder.write_stringview(";")
    }
    index = index + 1
  }
  let raw = builder.to_string()
  let localized = match currency {
    Some(info) => replace_currency(raw, info, before_number)
    None => raw
  }
  (localized.replace_all(old="\u{E000}", new="¤"), pad_char)
}

///|
fn is_dot(token : @pattern.PatternToken) -> Bool {
  match token {
    @pattern.Literal(text) => text == "."
    _ => false
  }
}

///|
fn is_comma(token : @pattern.PatternToken) -> Bool {
  match token {
    @pattern.Literal(text) => text == ","
    _ => false
  }
}

///|
fn is_required_digit(field : Char) -> Bool {
  let code = field.to_int()
  field == '0' || (code >= 49 && code <= 57)
}

///|
fn is_number_placeholder(field : Char) -> Bool {
  field == '#' || field == '@' || is_required_digit(field)
}

///|
fn is_increment_digit(field : Char) -> Bool {
  let code = field.to_int()
  code >= 49 && code <= 57
}

///|
fn limited_power_of_ten(exponent : Int32) -> Int32 {
  let mut value = 1
  let mut index = 0
  while index < exponent && value <= 214748364 {
    value = value * 10
    index = index + 1
  }
  value
}

///|
fn count_placeholders(
  tokens : Array[@pattern.PatternToken],
  start : Int32,
  end : Int32,
  only_zeros : Bool,
) -> Int32 {
  let mut count = 0
  let mut index = start
  while index < end {
    match tokens[index] {
      @pattern.Placeholder(field, amount) =>
        if is_number_placeholder(field) &&
          (!only_zeros || is_required_digit(field)) {
          count = count + amount
        }
      _ => ()
    }
    index = index + 1
  }
  count
}

///|
fn parse_integer_grouping(
  tokens : Array[@pattern.PatternToken],
  start : Int32,
  end : Int32,
) -> (Int32, Int32) {
  let segments : Array[Int32] = []
  let mut segment_length = 0
  let mut saw_comma = false
  let mut index = start
  while index < end {
    match tokens[index] {
      @pattern.Placeholder(_, amount) =>
        segment_length = segment_length + amount
      @pattern.Literal(_) =>
        if is_comma(tokens[index]) {
          segments.push(segment_length)
          segment_length = 0
          saw_comma = true
        }
      _ => ()
    }
    index = index + 1
  }
  segments.push(segment_length)
  if !saw_comma || segments.length() < 2 {
    return (0, 0)
  }
  let primary = segments[segments.length() - 1]
  let secondary = if segments.length() > 2 {
    segments[segments.length() - 2]
  } else {
    primary
  }
  (primary, if secondary == 0 { primary } else { secondary })
}

///|
fn parse_rounding_increment(
  tokens : Array[@pattern.PatternToken],
  start : Int32,
  end : Int32,
  integer_count : Int32,
  fraction_count : Int32,
) -> Int32 {
  let mut increment = 0
  let mut saw_increment_digit = false
  let mut position = 0
  let mut index = start
  while index < end {
    match tokens[index] {
      @pattern.Placeholder(field, amount) => {
        let mut offset = 0
        while offset < amount {
          if is_increment_digit(field) {
            let place = position + offset
            let digit = field.to_int() - 48
            let power = if place < integer_count {
              integer_count - place - 1
            } else {
              fraction_count - (place - integer_count) - 1
            }
            if power >= 0 {
              increment = increment + digit * limited_power_of_ten(power)
              saw_increment_digit = true
            }
          }
          offset = offset + 1
        }
        position = position + amount
      }
      _ => ()
    }
    index = index + 1
  }
  if saw_increment_digit {
    increment
  } else {
    1
  }
}

///|
fn parse_pattern_scale(tokens : Array[@pattern.PatternToken]) -> Int32 {
  let mut scale = 1
  for token in tokens {
    match token {
      @pattern.Literal(text) =>
        if text.contains("‰") {
          scale = 1000
        } else if text.contains("%") {
          scale = 100
        }
      _ => ()
    }
  }
  scale
}

///|
fn parse_section(
  tokens : Array[@pattern.PatternToken],
  percent_sign : String,
  currency : CurrencyReplacement?,
) -> NumberSection {
  let mut start = -1
  let mut end = -1
  let mut exponent = -1
  for index, token in tokens.iter2() {
    match token {
      @pattern.Placeholder(_, _) => {
        if start < 0 {
          start = index
        }
        end = index
      }
      @pattern.Field(field, _) =>
        if field == 'E' && exponent < 0 && start >= 0 {
          exponent = index
        }
      _ => ()
    }
  }
  if start > 0 && is_dot(tokens[start - 1]) {
    start = start - 1
  }
  if start < 0 {
    let text = text_without_pad(
      tokens,
      0,
      tokens.length(),
      percent_sign,
      currency,
      true,
    )
    return {
      prefix: text.0,
      suffix: "",
      min_integer: 1,
      min_fraction: 0,
      max_fraction: 0,
      group_primary: 0,
      group_secondary: 0,
      scientific: false,
      exponent_min_digits: 1,
      exponent_plus: false,
      significant: false,
      min_significant: 0,
      max_significant: 0,
      rounding_increment: 1,
      scale: parse_pattern_scale(tokens),
      pad_char: text.1,
      pad_width: 0,
    }
  }
  let scientific = exponent >= 0
  let number_end = if scientific { exponent } else { end + 1 }
  let decimal = {
    let mut found = -1
    let mut index = start
    while index < number_end && found < 0 {
      if is_dot(tokens[index]) {
        found = index
      }
      index = index + 1
    }
    found
  }
  let integer_end = if decimal >= 0 { decimal } else { number_end }
  let fraction_start = if decimal >= 0 { decimal + 1 } else { number_end }
  let integer_count = count_placeholders(tokens, start, integer_end, false)
  let fraction_count = count_placeholders(
    tokens, fraction_start, number_end, false,
  )
  let significant = {
    let mut found = false
    let mut index = start
    while index < number_end && !found {
      match tokens[index] {
        @pattern.Placeholder('@', _) => found = true
        _ => ()
      }
      index = index + 1
    }
    found
  }
  let min_integer = count_placeholders(tokens, start, integer_end, true)
  let min_fraction = count_placeholders(
    tokens, fraction_start, number_end, true,
  )
  let max_fraction = fraction_count
  let (min_significant, max_significant) = if significant {
    let mut minimum = 0
    let mut optional = 0
    let mut index = start
    while index < number_end {
      match tokens[index] {
        @pattern.Placeholder('@', amount) => minimum = minimum + amount
        @pattern.Placeholder('#', amount) => optional = optional + amount
        _ => ()
      }
      index = index + 1
    }
    (minimum, minimum + optional)
  } else {
    (0, 0)
  }
  let rounding_increment = parse_rounding_increment(
    tokens, start, number_end, integer_count, fraction_count,
  )
  let (group_primary, group_secondary) = parse_integer_grouping(
    tokens, start, integer_end,
  )
  let exponent_start = if scientific { exponent + 1 } else { end + 1 }
  let exponent_min_digits = if scientific {
    let count = count_placeholders(tokens, exponent_start, end + 1, true)
    if count == 0 {
      1
    } else {
      count
    }
  } else {
    1
  }
  let exponent_plus = if scientific {
    let mut plus = false
    let mut index = exponent_start
    while index <= end {
      match tokens[index] {
        @pattern.Literal(text) => if text.contains("+") { plus = true }
        @pattern.Placeholder(_, _) => index = end + 1
        _ => ()
      }
      index = index + 1
    }
    plus
  } else {
    false
  }
  let prefix = text_without_pad(tokens, 0, start, percent_sign, currency, true)
  let suffix = text_without_pad(
    tokens,
    end + 1,
    tokens.length(),
    percent_sign,
    currency,
    false,
  )
  let pad_char = match prefix.1 {
    Some(pad) => Some(pad)
    None => suffix.1
  }
  let pad_width = if pad_char is Some(_) {
    tokens_text(tokens, 0, tokens.length()).length()
  } else {
    0
  }
  {
    prefix: prefix.0,
    suffix: suffix.0,
    min_integer,
    min_fraction,
    max_fraction,
    group_primary,
    group_secondary,
    scientific,
    exponent_min_digits,
    exponent_plus,
    significant,
    min_significant,
    max_significant,
    rounding_increment,
    scale: parse_pattern_scale(tokens),
    pad_char,
    pad_width,
  }
}

///|
fn split_sections(pattern : String) -> Array[Array[@pattern.PatternToken]] {
  let sections : Array[Array[@pattern.PatternToken]] = []
  let current : Array[@pattern.PatternToken] = []
  for token in @pattern.tokenize_number_pattern(pattern) {
    match token {
      @pattern.Separator => {
        sections.push(current.copy())
        current.clear()
      }
      _ => current.push(token)
    }
  }
  sections.push(current)
  sections
}

///|
/// Parse a complete pattern, including an optional negative subpattern.
fn parse_pattern(
  pattern : String,
  percent_sign : String,
  currency : CurrencyReplacement?,
) -> NumberPattern {
  let sections = split_sections(pattern)
  let positive = parse_section(sections[0], percent_sign, currency)
  if sections.length() > 1 {
    let negative = parse_section(sections[1], percent_sign, currency)
    {
      positive_prefix: positive.prefix,
      positive_suffix: positive.suffix,
      negative_prefix: negative.prefix,
      negative_suffix: negative.suffix,
      has_negative: true,
      min_integer: positive.min_integer,
      min_fraction: positive.min_fraction,
      max_fraction: positive.max_fraction,
      group_primary: positive.group_primary,
      group_secondary: positive.group_secondary,
      scientific: positive.scientific,
      exponent_min_digits: positive.exponent_min_digits,
      exponent_plus: positive.exponent_plus,
      significant: positive.significant,
      min_significant: positive.min_significant,
      max_significant: positive.max_significant,
      rounding_increment: positive.rounding_increment,
      scale: positive.scale,
      pad_char: positive.pad_char,
      pad_width: positive.pad_width,
    }
  } else {
    {
      positive_prefix: positive.prefix,
      positive_suffix: positive.suffix,
      negative_prefix: "",
      negative_suffix: "",
      has_negative: false,
      min_integer: positive.min_integer,
      min_fraction: positive.min_fraction,
      max_fraction: positive.max_fraction,
      group_primary: positive.group_primary,
      group_secondary: positive.group_secondary,
      scientific: positive.scientific,
      exponent_min_digits: positive.exponent_min_digits,
      exponent_plus: positive.exponent_plus,
      significant: positive.significant,
      min_significant: positive.min_significant,
      max_significant: positive.max_significant,
      rounding_increment: positive.rounding_increment,
      scale: positive.scale,
      pad_char: positive.pad_char,
      pad_width: positive.pad_width,
    }
  }
}
