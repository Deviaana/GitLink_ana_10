# moonl10n

Pure MoonBit localization formatting kernel backed by Unicode CLDR data.

`moonl10n` turns `(locale, value, options)` into a locale-correct string without
depending on a JavaScript host. It is designed for WASM-GC, JS and Native
targets, with formatting rules independent of the host runtime.

```text
en  1,234,567.891        $1,234.50        Oct 18, 2026        3 days ago
zh  1,234,567.891        US$1,234.50      2026年10月18日       3天前
de  1.234.567,891        1.234,50 $       18.10.2026          vor 3 Tagen
ja  1,234,567.891        $1,234.50        2026/10/18          3 日前
fr  1 234 567,891        1 234,50 $US     18 oct. 2026        il y a 3 jours
ar  1,234,567.891        ‏1,234.50 US$     18‏/10‏/2026        قبل 3 أيام
```

## Why

MoonBit's existing i18n work focuses on message catalogs (MF2) and delegates
number/date rendering to the host `Intl`. That fallback disappears on Native and
on pure WASM targets. `moonl10n` fills that layer: pure functions, no IO, no FFI,
CLDR conformance data as the source of truth.

## Status

Early alpha, but the core pipeline is implemented and tested.

| Area | Implemented | Notes |
| --- | --- | --- |
| Locale parsing | BCP 47 subset | language / script / region + fallback chain |
| Decimal | Yes | CLDR patterns, grouping, min/max fraction digits |
| Currency | Yes | CLDR symbol placement + ISO 4217 fraction digits |
| Percent | Yes | CLDR percent pattern |
| Plural rules | Yes | cardinal + ordinal, parser for the CLDR rule grammar |
| Date / time | Yes | CLDR styles and explicit patterns, Gregorian only |
| Relative time | Yes | future / past / zero, plural-aware |
| Locales bundled | `en`, `zh`, `de`, `ja`, `fr`, `ar` | `latn` numbering system |
| Compact notation | Not yet | `1.2万` / `1.2M` |
| Time zones | Not yet | `z` fields are skipped |
| Non-Gregorian calendars | Not yet | |

## Usage

```moonbit
let locale = @core.Locale::parse("de")

@number.format_decimal(1234567.891, locale)          // 1.234.567,891
@number.format_currency(1234.5, "EUR", locale)       // 1.234,50 €
@number.format_percent(0.125, locale)                // 13 %

let date = @datetime.DateTime::new(2026, 10, 18, hour=17, minute=42)
@datetime.format_date(date, locale)                  // 18.10.2026
@datetime.format_time(date, locale)                  // 17:42
@datetime.format_pattern(date, locale, "EEEE, d. MMMM y")

let rules = @plural.PluralRules::cached("ar")
rules.select(3.0)                                    // few

@relative.format_relative(-3.0, @relative.Day, locale) // vor 3 Tagen
// `format_relative` also accepts `rules=...` to reuse a precompiled rule set.
```

With options:

```moonbit
let money = @number.NumberOptions::with_fraction_digits(2, 2)
@number.format_decimal(1.0, locale, options=money)    // 1,00
let plain = @number.NumberOptions::default().without_grouping()
@number.format_decimal(1234567.0, locale, options=plain)
```

Plural selection can use the exact digits that were rendered, so `1` and `1.00`
select different categories:

```moonbit
let en = @core.Locale::parse("en")
let rendered = @number.format_decimal_result(1.0, en, options=money)
rendered.text                                        // 1.00
let rules = @plural.PluralRules::cached("en")
rules.select_with_digits(
  rendered.integer_digits,
  rendered.fraction_digits,
)                                                    // other (v = 2)
```

## Packages

| Package | Responsibility |
| --- | --- |
| `core` | Locale parsing, canonical tags, fallback chain |
| `data` | Generated CLDR tables (numbers, dates, plurals, relative time) |
| `decimal` | Shared decimal string expansion, rounding and parsing |
| `number` | Pattern parser and decimal / currency / percent rendering |
| `plural` | CLDR plural rule tokenizer, parser and evaluator |
| `datetime` | Civil date-time, weekday, CLDR date/time patterns |
| `relative` | Relative time, composed from the number and plural packages |

## Demo

```bash
moon run cmd/main
```

## Data pipeline

Generated code is committed, so consumers do not need Node.js. To refresh it:

```bash
node tools/fetch-cldr.mjs   # downloads the pinned CLDR JSON subset
node tools/gen-cldr.mjs     # rewrites data/generated.mbt
moon test
```

Source: [unicode-org/cldr-json](https://github.com/unicode-org/cldr-json).

## Tests

```bash
moon test
moon check
```

Coverage currently includes locale fallback, grouping and fraction rules,
negative subpatterns, ISO 4217 digits, cardinal and ordinal plural selection,
date/time styles across locales, quoted pattern literals and relative time.

## Roadmap

1. Compact notation and unit formatting.
2. CLDR conformance suites for numbers, dates and plurals.
3. Differential testing against `Intl` and ICU4X.
4. IANA timezone data and non-Gregorian calendars.
5. Non-`latn` numbering systems (Arabic-Indic, Devanagari, ...).
6. WASM playground and an npm-consumable bundle.

## Project proposal

The competition proposal and ecosystem survey live in
[`docs/proposal.md`](docs/proposal.md).

## License

Apache-2.0.