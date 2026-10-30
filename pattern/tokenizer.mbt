///|
/// One lexical token from a CLDR date or number pattern.
pub(all) enum PatternToken {
  Literal(String)
  Quoted(String)
  Pad(Char)
  Field(Char, Int32)
  Placeholder(Char, Int32)
  Currency(Int32)
  Separator
}

///|
fn push_literal(tokens : Array[PatternToken], text : String) -> Unit {
  if text.length() == 0 {
    return
  }
  if tokens.length() > 0 {
    let last = tokens.length() - 1
    match tokens[last] {
      Literal(existing) => {
        tokens[last] = Literal(existing + text)
        return
      }
      _ => ()
    }
  }
  tokens.push(Literal(text))
}

///|
/// Tokenize a date pattern with the CLDR quoting rules.
pub fn tokenize_pattern(pattern : String) -> Array[PatternToken] {
  tokenize_pattern_impl(pattern, false)
}

///|
/// Tokenize a number pattern, including the `*` padding escape.
pub fn tokenize_number_pattern(pattern : String) -> Array[PatternToken] {
  tokenize_pattern_impl(pattern, true)
}

///|
fn tokenize_pattern_impl(
  pattern : String,
  number_mode : Bool,
) -> Array[PatternToken] {
  let chars = pattern.to_array()
  let tokens : Array[PatternToken] = []
  let length = chars.length()
  let mut index = 0
  while index < length {
    let c = chars[index]
    if c.to_int() == 39 {
      if index + 1 < length && chars[index + 1].to_int() == 39 {
        push_literal(tokens, "'")
        index = index + 2
        continue
      }
      index = index + 1
      let quoted = StringBuilder::new()
      let mut closed = false
      while index < length && !closed {
        if chars[index].to_int() == 39 {
          if index + 1 < length && chars[index + 1].to_int() == 39 {
            quoted.write_stringview("'")
            index = index + 2
          } else {
            index = index + 1
            closed = true
          }
        } else {
          quoted.write_object(chars[index])
          index = index + 1
        }
      }
      let text = quoted.to_string()
      if text.length() > 0 {
        tokens.push(Quoted(text))
      }
      continue
    }
    if c == ';' {
      tokens.push(Separator)
      index = index + 1
      continue
    }
    if c == '¤' {
      let start = index
      while index < length && chars[index] == '¤' {
        index = index + 1
      }
      tokens.push(Currency(index - start))
      continue
    }
    if number_mode && c == '*' {
      if index + 1 < length {
        tokens.push(Pad(chars[index + 1]))
        index = index + 2
      } else {
        push_literal(tokens, "*")
        index = index + 1
      }
      continue
    }
    if c.is_ascii_alphabetic() {
      let start = index
      while index < length && chars[index] == c {
        index = index + 1
      }
      tokens.push(Field(c, index - start))
      continue
    }
    let placeholder_code = c.to_int()
    if c == '#' ||
      c == '0' ||
      c == '@' ||
      (placeholder_code >= 49 && placeholder_code <= 57) {
      let start = index
      while index < length && chars[index] == c {
        index = index + 1
      }
      tokens.push(Placeholder(c, index - start))
      continue
    }
    push_literal(tokens, c.to_string())
    index = index + 1
  }
  tokens
}
