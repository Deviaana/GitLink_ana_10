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
| Locale parsing | BCP 47 subset | strict parser, variants/extensions, likely subtags, Accept-Language negotiation |
| Decimal | Yes | CLDR patterns, grouping, min/max fraction digits |
| Currency | Yes | symbol/code/name/narrow display, accounting patterns, ISO 4217 digits |
| Percent | Yes | CLDR percent pattern and localized percent sign |
| Plural rules | Yes | cardinal + ordinal, parser for the CLDR rule grammar |
| Date / time | Yes | CLDR styles and explicit patterns, Gregorian only |
| Relative time | Yes | future / past / zero, plural-aware |
| Intl differential | Yes | 166 static fixtures across six locales |
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

Locale parsing is strict when requested, while `parse` remains best-effort:

```moonbit
@core.Locale::try_parse("de-abc")                       // None
@core.Locale::parse("de-abc").to_tag()                  // de
@core.Locale::parse("sl-rozaj-biske-1994").to_tag()     // sl-rozaj-biske-1994
@core.Locale::parse("zh-HK").maximize().to_tag()        // zh-Hant-HK

let available = [
  @core.Locale::parse("en"),
  @core.Locale::parse("zh-Hans"),
  @core.Locale::parse("zh-Hant"),
]
@core.Locale::negotiate("zh-HK, en;q=0.8", available)   // Some(zh-Hant)
```

The strict parser covers language, script, region, variants, extensions and
private-use sections. Extlang and grandfathered tags are rejected rather than
guessed. The built-in likely-subtag table covers the bundled locales and common
languages.

With options:

```moonbit
let money = @number.NumberOptions::with_fraction_digits(2, 2)
@number.format_decimal(1.0, locale, options=money)    // 1,00
let plain = @number.NumberOptions::default().without_grouping()
@number.format_decimal(1234567.0, locale, options=plain)
```

Currency display and accounting options:

```moonbit
let en = @core.Locale::parse("en")
let code = @number.CurrencyOptions::with_display(@number.Code)
@number.format_currency(1234.5, "USD", en, currency_options=code)
// USD 1,234.50 (with CLDR currency spacing)

let accounting = @number.CurrencyOptions::default().with_accounting()
@number.format_currency(-1234.5, "USD", en, currency_options=accounting)
// ($1,234.50)

@number.format_currency_with_pattern(1234.5, "USD", en, "¤¤#,##0.00")
// USD 1,234.50
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
| `core` | Strict locale parsing, likely subtags, negotiation, fallback chain |
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

Coverage currently includes strict locale parsing, likely subtags,
Accept-Language negotiation, locale fallback, grouping and fraction rules,
negative subpatterns, ISO 4217 digits, cardinal and ordinal plural selection,
date/time styles across locales, quoted pattern literals and relative time.

## Conformance

`conformance/intl_conformance_wbtest.mbt` contains 166 static white-box
assertions generated from Node.js `Intl`, so CI only needs `moon test` and does
not need Node.js at runtime. The suite covers six locales and the supported
surface area: decimals and negative values, percent signs, currency
symbol/code/name/narrow displays, accounting, medium dates, short times,
relative day/hour output, cardinal plurals and visible fraction digits.

Regenerate or verify the committed fixtures with:

```bash
node tools/gen-intl-fixtures.mjs
node tools/gen-intl-fixtures.mjs --check
```

The generator records the Node and ICU versions in the fixture header. Date and
time comparisons treat U+202F (the CLDR narrow no-break space) and U+0020 (the
space emitted by Node ICU in these patterns) as equivalent; all other spacing,
including currency spacing, is compared exactly.

Known exclusions are time zones, non-Gregorian calendars, compact notation and
non-`latn` numbering systems. These are either outside the currently supported
surface or tracked in the roadmap below.

## Roadmap

1. Compact notation and unit formatting.
2. Official CLDR conformance suites for numbers, dates and plurals.
3. ICU4X differential testing alongside the current Node `Intl` suite.
4. IANA timezone data and non-Gregorian calendars.
5. Non-`latn` numbering systems (Arabic-Indic, Devanagari, ...).
6. WASM playground and an npm-consumable bundle.

## Project proposal

The competition proposal and ecosystem survey live in
[`docs/proposal.md`](docs/proposal.md).

## License

Apache-2.0.