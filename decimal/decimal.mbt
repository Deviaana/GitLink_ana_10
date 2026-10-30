///|
/// Split `123.45` into `("123", "45")`.
pub fn split_decimal(text : String) -> (String, String) {
  match text.find(".") {
    Some(index) => {
      let int_part = text[0:index].to_owned()
      (
        if int_part.length() == 0 {
          "0"
        } else {
          int_part
        },
        text[index + 1:text.length()].to_owned(),
      )
    }
    None => (if text.length() == 0 { "0" } else { text }, "")
  }
}

///|
fn parse_exponent_digits(text : String) -> Int32 {
  let mut value = 0
  for c in text.iter() {
    if c.is_ascii_digit() {
      value = value * 10 + (c.to_int() - 48)
    }
  }
  value
}

///|
fn zero_string(count : Int32) -> String {
  let builder = StringBuilder::new()
  for _ in 0..<count {
    builder.write_stringview("0")
  }
  builder.to_string()
}

///|
/// Expand scientific notation into a plain integer/fraction pair.
pub fn expand_decimal(raw : String) -> (String, String) {
  let lower = raw.to_lower()
  match lower.find("e") {
    None => split_decimal(raw)
    Some(index) => {
      let mantissa = raw[0:index].to_owned()
      let exponent_text = raw[index + 1:raw.length()].to_owned()
      let mut exponent = parse_exponent_digits(exponent_text)
      if exponent_text.has_prefix("-") {
        exponent = -exponent
      }
      let parts = split_decimal(mantissa)
      let digits = parts.0 + parts.1
      let point = parts.0.length() + exponent
      if point <= 0 {
        ("0", zero_string(-point) + digits)
      } else if point >= digits.length() {
        (digits + zero_string(point - digits.length()), "")
      } else {
        (digits[0:point].to_owned(), digits[point:digits.length()].to_owned())
      }
    }
  }
}

///|
fn strip_leading_zeroes(text : String) -> String {
  let mut first = 0
  while first + 1 < text.length() && text.get_char(first).unwrap() == '0' {
    first = first + 1
  }
  text[first:text.length()].to_owned()
}

///|
fn add_small_unsigned(text : String, amount : Int32) -> String {
  let digits = text.to_array()
  let mut index = digits.length() - 1
  let mut carry = amount
  while index >= 0 && carry > 0 {
    let sum = digits[index].to_int() - 48 + carry
    digits[index] = Int32::unsafe_to_char(48 + sum % 10)
    carry = sum / 10
    index = index - 1
  }
  let result = String::from_array(digits)
  if carry > 0 {
    carry.to_string() + result
  } else {
    result
  }
}

///|
fn subtract_small_unsigned(text : String, amount : Int32) -> String {
  let digits = text.to_array()
  let mut index = digits.length() - 1
  let mut borrow = amount
  let mut borrowed = 0
  while index >= 0 && (borrow > 0 || borrowed > 0) {
    let part = borrow % 10 + borrowed
    borrow = borrow / 10
    let value = digits[index].to_int() - 48
    if value < part {
      digits[index] = Int32::unsafe_to_char(48 + value + 10 - part)
      borrowed = 1
    } else {
      digits[index] = Int32::unsafe_to_char(48 + value - part)
      borrowed = 0
    }
    index = index - 1
  }
  String::from_array(digits)
}

///|
fn decimal_mod(text : String, divisor : Int32) -> Int32 {
  let mut remainder = 0
  for c in text.iter() {
    remainder = (remainder * 10 + c.to_int() - 48) % divisor
  }
  remainder
}

///|
fn digit_at(text : String, index : Int32) -> Int32 {
  match text.get_char(index) {
    Some(c) => c.to_int() - 48
    None => 0
  }
}

///|
fn place_scaled_digits(scaled : String, scale : Int32) -> (String, String) {
  let normalized = strip_leading_zeroes(scaled)
  if scale >= 0 {
    let min_length = scale + 1
    let text = normalized.pad_start(min_length, '0')
    let split = text.length() - scale
    (text[0:split].to_owned(), text[split:text.length()].to_owned())
  } else {
    (normalized + zero_string(-scale), "")
  }
}

///|
/// Round a non-negative decimal string to `scale` decimal places using a
/// decimal `increment` (1-9 in a CLDR fraction pattern) and round-half-away-
/// from-zero. A negative scale rounds to a power of ten in the integer part.
pub fn round_to_scale(
  raw : String,
  scale : Int32,
  increment : Int32,
) -> (String, String) {
  let bounded_scale = if scale > 15 {
    15
  } else if scale < -15 {
    -15
  } else {
    scale
  }
  let unit = if increment < 1 { 1 } else { increment }
  let parts = expand_decimal(raw)
  let digits = parts.0 + parts.1
  let point = parts.0.length()
  let keep = point + bounded_scale
  let padded_digits = if keep > digits.length() {
    digits.pad_end(keep, '0')
  } else {
    digits
  }
  let kept = if keep <= 0 {
    "0"
  } else if keep >= padded_digits.length() {
    padded_digits
  } else {
    padded_digits[0:keep].to_owned()
  }
  let tail = digit_at(padded_digits, keep)
  let remainder = decimal_mod(kept, unit)
  let rounded = if remainder * 10 + tail >= unit * 5 {
    add_small_unsigned(kept, unit - remainder)
  } else {
    subtract_small_unsigned(kept, remainder)
  }
  place_scaled_digits(rounded, bounded_scale)
}

///|
/// Round a non-negative decimal string to `max_fraction` digits using
/// round-half-away-from-zero, matching the default `Intl` behavior.
pub fn round_to_fraction(
  raw : String,
  max_fraction : Int32,
) -> (String, String) {
  round_to_scale(raw, max_fraction, 1)
}

///|
/// Parse an unsigned decimal string such as `123.45`.
pub fn parse_decimal_text(text : String) -> Double {
  let mut value = 0.0
  let mut scale = 0.1
  let mut after_dot = false
  for c in text.iter() {
    if c == '.' {
      after_dot = true
    } else {
      let digit = (c.to_int() - 48).to_double()
      if after_dot {
        value = value + digit * scale
        scale = scale / 10.0
      } else {
        value = value * 10.0 + digit
      }
    }
  }
  value
}
