///|
fn peek(tokens : Array[Token], pos : Int32) -> Token {
  if pos < tokens.length() {
    tokens[pos]
  } else {
    End
  }
}

///|
fn parse_or(tokens : Array[Token], pos : Int32) -> (Condition?, Int32) {
  let first = parse_and(tokens, pos)
  let mut acc = first.0
  let mut next = first.1
  while next < tokens.length() {
    match peek(tokens, next) {
      Or => {
        let rhs = parse_and(tokens, next + 1)
        match acc {
          Some(left) =>
            match rhs.0 {
              Some(right) => {
                acc = Some(Or(left, right))
                next = rhs.1
              }
              None => return (None, pos)
            }
          None => return (None, pos)
        }
      }
      _ => break
    }
  }
  (acc, next)
}

///|
fn parse_and(tokens : Array[Token], pos : Int32) -> (Condition?, Int32) {
  let first = parse_relation(tokens, pos)
  let mut acc = first.0
  let mut next = first.1
  while next < tokens.length() {
    match peek(tokens, next) {
      And => {
        let rhs = parse_relation(tokens, next + 1)
        match acc {
          Some(left) =>
            match rhs.0 {
              Some(right) => {
                acc = Some(And(left, right))
                next = rhs.1
              }
              None => return (None, pos)
            }
          None => return (None, pos)
        }
      }
      _ => break
    }
  }
  (acc, next)
}

///|
fn parse_relation(tokens : Array[Token], pos : Int32) -> (Condition?, Int32) {
  let operand = match peek(tokens, pos) {
    OperandTok(value) => value
    _ => return (None, pos)
  }
  let mut next = pos + 1
  let mut modulus : Int32? = None
  match peek(tokens, next) {
    Percent => {
      next = next + 1
      match peek(tokens, next) {
        Number(value) => {
          modulus = Some(value.to_int())
          next = next + 1
        }
        _ => return (None, pos)
      }
    }
    _ => ()
  }
  let mut relation = Relation::Eq
  match peek(tokens, next) {
    Eq => {
      relation = Eq
      next = next + 1
    }
    NotEq => {
      relation = NotEq
      next = next + 1
    }
    In => {
      relation = In
      next = next + 1
    }
    Within => {
      relation = Within
      next = next + 1
    }
    Not => {
      next = next + 1
      match peek(tokens, next) {
        In => {
          relation = NotIn
          next = next + 1
        }
        Within => {
          relation = NotWithin
          next = next + 1
        }
        _ => return (None, pos)
      }
    }
    _ => return (None, pos)
  }
  let ranges : Array[Range] = []
  let mut parsing = true
  while parsing {
    let low = match peek(tokens, next) {
      Number(value) => value
      _ => return (None, pos)
    }
    next = next + 1
    let mut high = low
    match peek(tokens, next) {
      DotDot => {
        next = next + 1
        match peek(tokens, next) {
          Number(value) => {
            high = value
            next = next + 1
          }
          _ => return (None, pos)
        }
      }
      _ => ()
    }
    ranges.push({ low, high, })
    match peek(tokens, next) {
      Comma => next = next + 1
      _ => parsing = false
    }
  }
  if ranges.length() == 0 {
    return (None, pos)
  }
  (Some(Relation(operand, modulus, relation, ranges)), next)
}

///|
fn parse_rule(text : String) -> Condition {
  let tokens = tokenize(text)
  let parsed = parse_or(tokens, 0)
  match parsed.0 {
    Some(condition) => condition
    None => Never
  }
}

///|
fn compile_rules(
  source : Array[(String, String)],
) -> Array[(String, Condition)] {
  let order : Array[String] = ["zero", "one", "two", "few", "many", "other"]
  let result : Array[(String, Condition)] = []
  for wanted in order {
    for entry in source {
      if entry.0 == wanted {
        let text = entry.1.trim().to_owned()
        let condition = if text.length() == 0 {
          Always
        } else {
          parse_rule(text)
        }
        result.push((wanted, condition))
      }
    }
  }
  result
}

///|
fn resolve_plural_data(language : String) -> @data.PluralData {
  match @data.plural_data(language) {
    Some(data) => data
    None => @data.plural_data("en").unwrap()
  }
}

///|
/// Build a reusable plural rule set for a language.
pub fn PluralRules::new(language : String, ordinal? : Bool) -> PluralRules {
  let use_ordinal = ordinal.unwrap_or(false)
  let data = resolve_plural_data(language)
  let source = if use_ordinal { data.ordinal } else { data.cardinal }
  { ordinal: use_ordinal, rules: compile_rules(source), }
}
