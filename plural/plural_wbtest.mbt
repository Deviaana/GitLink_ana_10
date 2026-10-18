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
