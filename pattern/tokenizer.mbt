///|
/// One lexical token from a CLDR date or number pattern.
pub(all) enum PatternToken {
  Literal(String)
  Field(Char, Int)
  Placeholder(Char, Int)
  Currency(Int)
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
/// Tokenize dates and number patterns with the CLDR quoting rules.
///
/// Single quotes delimit literals, `''` represents a literal quote, repeated
/// pattern letters form one field token, and an unquoted `;` separates number
/// subpatterns.
pub fn tokenize_pattern(pattern : String) -> Array[PatternToken] {
  let chars = pattern.to_array()
  let tokens : Array[PatternToken] = []
  let length = chars.length()
  let mut index = 0
  while index < length {
    let c = chars[index]
    if c.to_int() == 39 {
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
      push_literal(tokens, quoted.to_string())
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
    if c.is_ascii_alphabetic() {
      let start = index
      while index < length && chars[index] == c {
        index = index + 1
      }
      tokens.push(Field(c, index - start))
      continue
    }
    if c == '#' || c == '0' {
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
