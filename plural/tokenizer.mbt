///|
fn char_to_digit(c : Char) -> Double {
  (c.to_int() - 48).to_double()
}

///|
fn parse_decimal_text(text : String) -> Double {
  let mut value = 0.0
  let mut scale = 0.1
  let mut after_dot = false
  for c in text.iter() {
    if c == '.' {
      after_dot = true
    } else {
      let digit = char_to_digit(c)
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

///|
fn is_space(c : Char) -> Bool {
  let code = c.to_int()
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn tokenize(rule : String) -> Array[Token] {
  let chars = rule.to_array()
  let tokens : Array[Token] = []
  let length = chars.length()
  let mut index = 0
  while index < length {
    let c = chars[index]
    if is_space(c) {
      index = index + 1
      continue
    }
    if c == '@' {
      tokens.push(End)
      break
    }
    if c.is_ascii_alphabetic() {
      let start = index
      while index < length && chars[index].is_ascii_alphabetic() {
        index = index + 1
      }
      let word = String::from_array(chars[start:index]).to_lower()
      match word {
        "n" => tokens.push(OperandTok(N))
        "i" => tokens.push(OperandTok(I))
        "v" => tokens.push(OperandTok(V))
        "w" => tokens.push(OperandTok(W))
        "f" => tokens.push(OperandTok(F))
        "t" => tokens.push(OperandTok(T))
        "c" => tokens.push(OperandTok(C))
        "e" => tokens.push(OperandTok(E))
        "and" => tokens.push(And)
        "or" => tokens.push(Or)
        "in" => tokens.push(In)
        "within" => tokens.push(Within)
        "is" => tokens.push(Eq)
        "mod" => tokens.push(Percent)
        "not" => tokens.push(Not)
        _ => ()
      }
      continue
    }
    if c.is_ascii_digit() {
      let start = index
      while index < length && chars[index].is_ascii_digit() {
        index = index + 1
      }
      if index + 1 < length && chars[index] == '.' && chars[index + 1] != '.' {
        index = index + 1
        while index < length && chars[index].is_ascii_digit() {
          index = index + 1
        }
      }
      let text = String::from_array(chars[start:index])
      tokens.push(Number(parse_decimal_text(text)))
      continue
    }
    if c == '=' {
      tokens.push(Eq)
      index = index + 1
      continue
    }
    if c == '!' && index + 1 < length && chars[index + 1] == '=' {
      tokens.push(NotEq)
      index = index + 2
      continue
    }
    if c == '%' {
      tokens.push(Percent)
      index = index + 1
      continue
    }
    if c == ',' {
      tokens.push(Comma)
      index = index + 1
      continue
    }
    if c == '.' && index + 1 < length && chars[index + 1] == '.' {
      tokens.push(DotDot)
      index = index + 2
      continue
    }
    index = index + 1
  }
  tokens.push(End)
  tokens
}
