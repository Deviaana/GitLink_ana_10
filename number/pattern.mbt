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
        if !only_zeros || field == '0' {
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
fn parse_section(tokens : Array[@pattern.PatternToken]) -> NumberSection {
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
  if start < 0 {
    return {
      prefix: tokens_text(tokens, 0, tokens.length()),
      suffix: "",
      min_integer: 1,
      min_fraction: 0,
      max_fraction: 0,
      group_primary: 0,
      group_secondary: 0,
      scientific: false,
      exponent_min_digits: 1,
      exponent_plus: false,
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
  let mut min_integer = count_placeholders(tokens, start, integer_end, true)
  if min_integer == 0 {
    min_integer = 1
  }
  let min_fraction = count_placeholders(
    tokens, fraction_start, number_end, true,
  )
  let max_fraction = count_placeholders(
    tokens, fraction_start, number_end, false,
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
  {
    prefix: tokens_text(tokens, 0, start),
    suffix: tokens_text(tokens, end + 1, tokens.length()),
    min_integer,
    min_fraction,
    max_fraction,
    group_primary,
    group_secondary,
    scientific,
    exponent_min_digits,
    exponent_plus,
  }
}

///|
fn split_sections(pattern : String) -> Array[Array[@pattern.PatternToken]] {
  let sections : Array[Array[@pattern.PatternToken]] = []
  let current : Array[@pattern.PatternToken] = []
  for token in @pattern.tokenize_pattern(pattern) {
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
fn parse_pattern(pattern : String) -> NumberPattern {
  let sections = split_sections(pattern)
  let positive = parse_section(sections[0])
  if sections.length() > 1 {
    let negative = parse_section(sections[1])
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
    }
  }
}
