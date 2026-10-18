///|
/// Operands defined by the CLDR plural rule grammar (UTS #35, part 3).
pub enum Operand {
  N
  I
  V
  W
  F
  T
  C
  E
}

///|
pub enum Relation {
  Eq
  NotEq
  In
  NotIn
  Within
  NotWithin
}

///|
pub struct Range {
  low : Double
  high : Double
}

///|
pub enum Condition {
  Always
  Never
  And(Condition, Condition)
  Or(Condition, Condition)
  Relation(Operand, Int32?, Relation, Array[Range])
}

///|
priv enum Token {
  OperandTok(Operand)
  Number(Double)
  Percent
  Eq
  NotEq
  In
  Within
  Not
  And
  Or
  Comma
  DotDot
  End
}

///|
pub struct PluralRules {
  ordinal : Bool
  rules : Array[(String, Condition)]
}
