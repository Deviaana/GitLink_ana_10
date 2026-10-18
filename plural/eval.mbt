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
fn operands_of(value : Double, visible : Int?) -> Operands {
  let n = value.abs()
  let i = n.floor()
  let raw = n.to_string()
  let pieces : Array[String] = []
  for piece in raw.split(".") {
    pieces.push(piece.to_owned())
  }
  let fraction = if pieces.length() > 1 { pieces[1] } else { "" }
  let digits = visible.unwrap_or(fraction.length())
  let mut shown = fraction
  if shown.length() > digits {
    shown = shown[0:digits].to_owned()
  }
  if shown.length() < digits {
    shown = shown.pad_end(digits, '0')
  }
  let v = digits
  let f = if shown.length() > 0 { parse_decimal_text(shown) } else { 0.0 }
  let mut trimmed = shown
  while trimmed.length() > 0 && trimmed.has_suffix("0") {
    trimmed = trimmed[0:trimmed.length() - 1].to_owned()
  }
  let w = trimmed.length()
  let t = if trimmed.length() > 0 { parse_decimal_text(trimmed) } else { 0.0 }
  { n, i, v: v.to_double(), w: w.to_double(), f, t, c: 0.0, e: 0.0 }
}

///|
/// Select the CLDR plural category for a numeric value.
pub fn PluralRules::select(
  self : PluralRules,
  value : Double,
  visible_fraction_digits? : Int,
) -> String {
  let ops = operands_of(value, visible_fraction_digits)
  for entry in self.rules {
    if eval_condition(entry.1, ops) {
      return entry.0
    }
  }
  "other"
}
