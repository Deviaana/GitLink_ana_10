///|
priv struct Operands {
  n : Double
  i : Double
  v : Double
  w : Double
  f : Double
  t : Double
  c : Double
  e : Double
}

///|
fn operand_value(operand : Operand, ops : Operands) -> Double {
  match operand {
    N => ops.n
    I => ops.i
    V => ops.v
    W => ops.w
    F => ops.f
    T => ops.t
    C => ops.c
    E => ops.e
  }
}

///|
fn is_integer(value : Double) -> Bool {
  value == value.floor()
}

///|
fn eval_relation(
  value : Double,
  relation : Relation,
  ranges : Array[Range],
) -> Bool {
  let matches = fn(r : Range) -> Bool {
    if r.low == r.high {
      value == r.low
    } else {
      is_integer(value) && value >= r.low && value <= r.high
    }
  }
  let within = fn(r : Range) -> Bool { value >= r.low && value <= r.high }
  match relation {
    Eq => ranges.any(matches)
    NotEq => !ranges.any(matches)
    In => is_integer(value) && ranges.any(within)
    NotIn => !(is_integer(value) && ranges.any(within))
    Within => ranges.any(within)
    NotWithin => !ranges.any(within)
  }
}

///|
fn eval_condition(condition : Condition, ops : Operands) -> Bool {
  match condition {
    Always => true
    Never => false
    And(left, right) => eval_condition(left, ops) && eval_condition(right, ops)
    Or(left, right) => eval_condition(left, ops) || eval_condition(right, ops)
    Relation(operand, modulus, relation, ranges) => {
      let mut value = operand_value(operand, ops)
      match modulus {
        Some(divisor) => {
          let d = divisor.to_double()
          if d != 0.0 {
            value = value - (value / d).floor() * d
          }
        }
        None => ()
      }
      eval_relation(value, relation, ranges)
    }
  }
}

///|
/// Build operands from the exact unsigned digits that were rendered.
fn operands_from_digits(
  integer_digits : String,
  fraction_digits : String,
) -> Operands {
  let int_text = if integer_digits.length() == 0 { "0" } else { integer_digits }
  let i = @decimal.parse_decimal_text(int_text)
  let n = if fraction_digits.length() == 0 {
    i
  } else {
    @decimal.parse_decimal_text(int_text + "." + fraction_digits)
  }
  let v = fraction_digits.length()
  let f = if v == 0 {
    0.0
  } else {
    @decimal.parse_decimal_text(fraction_digits)
  }
  let mut trimmed = fraction_digits
  while trimmed.length() > 0 && trimmed.has_suffix("0") {
    trimmed = trimmed[0:trimmed.length() - 1].to_owned()
  }
  let w = trimmed.length()
  let t = if w == 0 { 0.0 } else { @decimal.parse_decimal_text(trimmed) }
  { n, i, v: v.to_double(), w: w.to_double(), f, t, c: 0.0, e: 0.0, }
}

///|
fn operands_of(value : Double, visible : Int32?) -> Operands {
  let n = value.abs()
  let raw = n.to_string()
  let expanded = @decimal.expand_decimal(raw)
  let digits = match visible {
    Some(count) => if count < 0 { 0 } else { count }
    None => expanded.1.length()
  }
  let rounded = @decimal.round_to_fraction(raw, digits)
  let mut shown = rounded.1
  if shown.length() < digits {
    shown = shown.pad_end(digits, '0')
  }
  operands_from_digits(rounded.0, shown)
}

///|
fn select_operands(rules : PluralRules, ops : Operands) -> String {
  for entry in rules.rules {
    if eval_condition(entry.1, ops) {
      return entry.0
    }
  }
  "other"
}

///|
/// Select the CLDR plural category for a numeric value.
///
/// When `visible_fraction_digits` is supplied, the value is rounded to that
/// many digits before `n`, `i`, `v`, `w`, `f` and `t` are derived.
pub fn PluralRules::select(
  self : PluralRules,
  value : Double,
  visible_fraction_digits? : Int32,
) -> String {
  select_operands(self, operands_of(value, visible_fraction_digits))
}

///|
/// Select using the exact unsigned digits produced by a number formatter.
///
/// `fraction_digits` includes trailing zeros, so `("1", "00")` means the
/// rendered value is `1.00` and produces `v = 2`, `f = 0`, `w = 0`, `t = 0`.
pub fn PluralRules::select_with_digits(
  self : PluralRules,
  integer_digits : String,
  fraction_digits : String,
) -> String {
  select_operands(self, operands_from_digits(integer_digits, fraction_digits))
}
