///|
test "number patterns tokenize by lexical role" {
  let tokens = tokenize_pattern("¤¤#,##0.00 'kg'")
  assert_eq(tokens.length(), 8)
  match tokens[0] {
    Currency(count) => assert_eq(count, 2)
    _ => assert_eq("expected currency token", "other")
  }
  match tokens[3] {
    Placeholder(field, count) => {
      assert_eq(field, '#')
      assert_eq(count, 2)
    }
    _ => assert_eq("expected placeholder token", "other")
  }
  match tokens[7] {
    Literal(text) => assert_eq(text, " kg")
    _ => assert_eq("expected literal token", "other")
  }
}

///|
test "quoted separators stay literal" {
  let tokens = tokenize_pattern("0';'0")
  assert_eq(tokens.length(), 3)
  match tokens[1] {
    Literal(text) => assert_eq(text, ";")
    _ => assert_eq("expected quoted separator", "other")
  }
}

///|
test "quoted quotes are unescaped" {
  let tokens = tokenize_pattern("0 'o''clock'")
  assert_eq(tokens.length(), 2)
  match tokens[1] {
    Literal(text) => assert_eq(text, " o'clock")
    _ => assert_eq("expected quoted literal", "other")
  }
}
