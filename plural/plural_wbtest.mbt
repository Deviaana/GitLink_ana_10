///|
test "english cardinal rules" {
  let rules = PluralRules::new("en")
  assert_eq(rules.select(1.0), "one")
  assert_eq(rules.select(2.0), "other")
  assert_eq(rules.select(0.0), "other")
  assert_eq(rules.select(1.0, visible_fraction_digits=1), "other")
}

///|
test "chinese has only other" {
  let rules = PluralRules::new("zh")
  assert_eq(rules.select(0.0), "other")
  assert_eq(rules.select(1.0), "other")
  assert_eq(rules.select(2.0), "other")
}

///|
test "arabic cardinal rules" {
  let rules = PluralRules::new("ar")
  assert_eq(rules.select(0.0), "zero")
  assert_eq(rules.select(1.0), "one")
  assert_eq(rules.select(2.0), "two")
  assert_eq(rules.select(3.0), "few")
  assert_eq(rules.select(10.0), "few")
  assert_eq(rules.select(11.0), "many")
  assert_eq(rules.select(99.0), "many")
  assert_eq(rules.select(100.0), "other")
}

///|
test "english ordinal rules" {
  let rules = PluralRules::new("en", ordinal=true)
  assert_eq(rules.select(1.0), "one")
  assert_eq(rules.select(2.0), "two")
  assert_eq(rules.select(3.0), "few")
  assert_eq(rules.select(4.0), "other")
  assert_eq(rules.select(11.0), "other")
  assert_eq(rules.select(21.0), "one")
  assert_eq(rules.select(103.0), "few")
}

///|
test "german cardinal rules" {
  let rules = PluralRules::new("de")
  assert_eq(rules.select(1.0), "one")
  assert_eq(rules.select(2.0), "other")
}

///|
test "cached rules match freshly parsed rules" {
  let fresh = PluralRules::new("ar")
  let cached = PluralRules::cached("ar")
  let values : Array[Double] = [0.0, 1.0, 2.0, 3.0, 11.0, 100.0]
  for value in values {
    assert_eq(cached.select(value), fresh.select(value))
  }
  let ordinal_fresh = PluralRules::new("en", ordinal=true)
  let ordinal_cached = PluralRules::cached("en", ordinal=true)
  assert_eq(ordinal_cached.select(21.0), ordinal_fresh.select(21.0))
  assert_eq(ordinal_cached.select(4.0), ordinal_fresh.select(4.0))
}

///|
test "cached rules fall back for unknown languages" {
  let rules = PluralRules::cached("xx")
  assert_eq(rules.select(1.0), "one")
}

///|
test "formatted digits drive v w f and t" {
  let rules : PluralRules = {
    ordinal: false,
    rules: compile_rules([
      ("one", "v = 2 and w = 2 and f = 1 and t = 1"),
      ("other", ""),
    ]),
  }
  assert_eq(rules.select_with_digits("1", "01"), "one")
  assert_eq(rules.select_with_digits("1", "00"), "other")
  assert_eq(rules.select_with_digits("1", ""), "other")
}

///|
test "one and one point zero zero select differently" {
  let rules = PluralRules::new("en")
  assert_eq(rules.select_with_digits("1", ""), "one")
  assert_eq(rules.select_with_digits("1", "00"), "other")
}

///|
test "visible fraction digits use formatter rounding" {
  let rounded : PluralRules = {
    ordinal: false,
    rules: compile_rules([
      ("one", "v = 2 and w = 2 and f = 1 and t = 1"),
      ("other", ""),
    ]),
  }
  assert_eq(rounded.select(1.005, visible_fraction_digits=2), "one")
  assert_eq(rounded.select(1.0049, visible_fraction_digits=2), "other")
  let tiny : PluralRules = {
    ordinal: false,
    rules: compile_rules([
      ("one", "v = 7 and w = 7 and f = 1 and t = 1"),
      ("other", ""),
    ]),
  }
  assert_eq(tiny.select(1.0e-7, visible_fraction_digits=7), "one")
}

///|
test "leading fraction zeros are preserved" {
  let rules : PluralRules = {
    ordinal: false,
    rules: compile_rules([
      ("one", "v = 2 and w = 1 and f = 50 and t = 5"),
      ("other", ""),
    ]),
  }
  assert_eq(rules.select(1.5, visible_fraction_digits=2), "one")
}
