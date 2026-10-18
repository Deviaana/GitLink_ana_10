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
fn parse_exponent_digits(text : String) -> Int {
  let mut value = 0
  for c in text.iter() {
    if c.is_ascii_digit() {
      value = value * 10 + (c.to_int() - 48)
    }
  }
  value
}

///|
fn zero_string(count : Int) -> String {
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
/// Add one to the decimal formed by `int_part` and `frac_part`.
fn increment_decimal(int_part : String, frac_part : String) -> (String, String) {
  let digits = (int_part + frac_part).to_array()
  let mut index = digits.length() - 1
  let mut carry = true
  while index >= 0 && carry {
    let value = digits[index].to_int() - 48
    if value == 9 {
      digits[index] = '0'
      index = index - 1
    } else {
      digits[index] = Int::unsafe_to_char(value + 49)
      carry = false
    }
  }
  let text = String::from_array(digits)
  let int_length = int_part.length()
  if carry {
    let shifted = "1" + text
    (
      shifted[0:int_length + 1].to_owned(),
      shifted[int_length + 1:shifted.length()].to_owned(),
    )
  } else {
    (text[0:int_length].to_owned(), text[int_length:text.length()].to_owned())
  }
}

///|
/// Round a non-negative decimal string to `max_fraction` digits using
/// round-half-away-from-zero, matching the default `Intl` behavior.
pub fn round_to_fraction(raw : String, max_fraction : Int) -> (String, String) {
  let parts = expand_decimal(raw)
  let int_part = parts.0
  let frac_part = parts.1
  if frac_part.length() <= max_fraction {
    return (int_part, frac_part)
  }
  let kept = frac_part[0:max_fraction].to_owned()
  let next = frac_part.get_char(max_fraction).unwrap()
  if next.to_int() >= 53 {
    increment_decimal(int_part, kept)
  } else {
    (int_part, kept)
  }
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
