///|
/// A parsed CLDR number pattern.
///
/// Only the pieces needed for decimal, percent and currency rendering are kept.
priv struct NumberPattern {
  positive_prefix : String
  positive_suffix : String
  negative_prefix : String
  negative_suffix : String
  has_negative : Bool
  min_integer : Int
  min_fraction : Int
  max_fraction : Int
  group_primary : Int
  group_secondary : Int
}

///|
fn is_placeholder(c : Char) -> Bool {
  c == '#' || c == '0'
}

///|
fn count_char(text : String, target : Char) -> Int {
  let mut count = 0
  for c in text.iter() {
    if c == target {
      count = count + 1
    }
  }
  count
}

///|
/// Parse one section such as `#,##0.00` or `0%`.
fn parse_section(section : String) -> (String, String, Int, Int, Int, Int, Int) {
  let mut start = -1
  let mut end = -1
  for i, c in section.iter2() {
    if is_placeholder(c) {
      if start < 0 {
        start = i
      }
      end = i
    }
  }
  if start < 0 {
    return ("", section, 1, 0, 0, 0, 0)
  }
  let prefix = section[0:start].to_owned()
  let suffix = section[end + 1:section.length()].to_owned()
  let numeric = section[start:end + 1].to_owned()
  let dot = numeric.find(".")
  let int_part = match dot {
    Some(index) => numeric[0:index].to_owned()
    None => numeric
  }
  let frac_part = match dot {
    Some(index) => numeric[index + 1:numeric.length()].to_owned()
    None => ""
  }
  let segments : Array[String] = []
  for segment in int_part.split(",") {
    segments.push(segment.to_owned())
  }
  let mut group_primary = 0
  let mut group_secondary = 0
  if segments.length() > 1 {
    group_primary = segments[segments.length() - 1].length()
    if segments.length() > 2 {
      group_secondary = segments[segments.length() - 2].length()
    } else {
      group_secondary = group_primary
    }
    if group_secondary == 0 {
      group_secondary = group_primary
    }
  }
  let mut min_integer = count_char(int_part, '0')
  if min_integer == 0 {
    min_integer = 1
  }
  let min_fraction = count_char(frac_part, '0')
  let max_fraction = count_char(frac_part, '0') + count_char(frac_part, '#')
  (
    prefix, suffix, min_integer, min_fraction, max_fraction, group_primary, group_secondary,
  )
}

///|
/// Parse a complete pattern, including an optional negative subpattern.
fn parse_pattern(pattern : String) -> NumberPattern {
  let sections : Array[String] = []
  for section in pattern.split(";") {
    sections.push(section.to_owned())
  }
  let positive = if sections.length() > 0 { sections[0] } else { "#,##0.###" }
  let (pp, ps, min_int, min_frac, max_frac, gp, gs) = parse_section(positive)
  if sections.length() > 1 {
    let (np, ns, _, _, _, _, _) = parse_section(sections[1])
    {
      positive_prefix: pp,
      positive_suffix: ps,
      negative_prefix: np,
      negative_suffix: ns,
      has_negative: true,
      min_integer: min_int,
      min_fraction: min_frac,
      max_fraction: max_frac,
      group_primary: gp,
      group_secondary: gs,
    }
  } else {
    {
      positive_prefix: pp,
      positive_suffix: ps,
      negative_prefix: "",
      negative_suffix: "",
      has_negative: false,
      min_integer: min_int,
      min_fraction: min_frac,
      max_fraction: max_frac,
      group_primary: gp,
      group_secondary: gs,
    }
  }
}
