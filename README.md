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
| Decimal | Yes | CLDR patterns, grouping, fraction digits, scientific notation |
| Currency | Yes | symbol/code/name/narrow display, accounting patterns, ISO 4217 digits |
| Percent | Yes | CLDR percent pattern and localized percent sign |
| Plural rules | Yes | cardinal + ordinal, parser for the CLDR rule grammar |
| Date / time | Yes | CLDR styles, explicit patterns, date ranges, spacing-preserving output |
| Relative time | Yes | future / past / zero, plural-aware |
| Intl differential | Yes | 178 static fixtures across six locales |
| Engineering | Yes | CI matrix across wasm-gc/js/native, coverage, executable examples and tagged MoonCakes releases |
| Locales bundled | `en`, `zh`, `de`, `ja`, `fr`, `ar` | `latn` numbering system |
| Compact notation | Yes | short CLDR patterns with plural-aware suffixes |
| Time zones | Not yet | `z` fields use explicit skip/preserve/reject policies |
| Non-Gregorian calendars | Not yet | |

## Usage

```moonbit
let locale = @core.Locale::parse("de")

@number.format_decimal(1234567.891, locale)          // 1.234.567,891
@number.format_currency(1234.5, "EUR", locale)       // 1.234,50 €
@number.format_percent(0.125, locale)                // 13 %
@number.format_compact(1234567.0, locale)            // 1,2 Mio.
@number.format_scientific(1234567.0, locale)         // 1,235E6
@number.format_with_pattern(12.5, locale, "0.0 'kg'") // 12,5 kg

let date = @datetime.DateTime::new(2026, 10, 18, hour=17, minute=42)
@datetime.format_date(date, locale)                  // 18.10.2026
@datetime.format_time(date, locale)                  // 17:42
@datetime.format_pattern(date, locale, "EEEE, d. MMMM y")
let end = @datetime.DateTime::new(2026, 10, 20)
@datetime.format_date_range(date, end, locale)       // 18.10.2026 - 20.10.2026
@datetime.format_pattern_with_policy(
  date, locale, "yyyy-MM-dd z", @datetime.Reject,
)                                                   // Err(UnsupportedField('z'))

let rules = @plural.PluralRules::cached("ar")
rules.select(3.0)                                    // few

@relative.format_relative(-3.0, @relative.Day, locale) // vor 3 Tagen
// `format_relative` also accepts `rules=...` to reuse a precompiled rule set.
```

Explicit patterns preserve literal whitespace, including leading and trailing
spaces. Unsupported fields are skipped by default; `format_pattern_with_policy`
and `format_time_with_policy` expose `Skip`, `Preserve` and `Reject`.

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
| `pattern` | Shared CLDR tokenizer for quoted literals and pattern fields |
| `number` | Decimal, currency, percent, scientific and compact rendering |
| `plural` | CLDR plural rule tokenizer, parser and evaluator |
| `datetime` | Civil date-time, weekday, CLDR date/time patterns |
| `relative` | Relative time, composed from the number and plural packages |

## Demos

`cmd/main` prints a full cross-locale tour of the formatting APIs:

```bash
moon run cmd/main
```

`examples/readme` is an executable version of the README snippets. It compiles
and runs the documented calls, and its companion test pins their expected
output:

```bash
moon run examples/readme
moon test examples/readme
```

## Data pipeline

Generated code is committed, so consumers do not need Node.js. To refresh it:

```bash
node tools/fetch-cldr.mjs   # downloads the pinned CLDR JSON subset
node tools/gen-cldr.mjs     # rewrites and formats data/generated.mbt
moon test
```

Source: [unicode-org/cldr-json](https://github.com/unicode-org/cldr-json).

Generated currency data is deduplicated: one shared ISO code table and one
English-based symbol table are emitted once, while each locale stores only its
symbol and narrow-symbol overrides plus localized names in currency-code order.
The compact tables use one default pattern per magnitude plus plural overrides,
keeping `data/generated.mbt` at 37,021 bytes versus 40,088 before the data
refactor (7.7% smaller) even after scientific and compact data were added. The
generator runs `moon fmt` on the generated file so regeneration stays
formatter-clean.

## Tests

```bash
moon check
moon test
moon test --target js
moon test --target native
moon coverage analyze -- -f summary
node tools/gen-intl-fixtures.mjs --check
```

Test coverage currently includes strict locale parsing, likely subtags,
Accept-Language negotiation, locale fallback, grouping and fraction rules,
negative subpatterns, ISO 4217 digits, cardinal and ordinal plural selection,
date/time styles across locales, quoted number and date patterns,
relative time, scientific and compact notation, and shared currency table
overrides.

## Continuous integration

`.github/workflows/ci.yml` runs the same test suite and the executable examples
on `wasm-gc`, JavaScript and native backends. A separate quality job checks
formatting, verifies the committed conformance fixtures and prints the
`moon coverage` summary.

`.github/workflows/publish.yml` publishes the module to MoonCakes when a `v*`
tag is pushed. Configure the `MOONCAKES_USERNAME` and `MOONCAKES_TOKEN`
repository secrets before creating the first release tag.

## Conformance

`conformance/intl_conformance_wbtest.mbt` contains 178 static white-box
assertions generated from Node.js `Intl`, so CI only needs `moon test` and does
not need Node.js at runtime. The suite covers six locales and the supported
surface area: decimals and negative values, percent signs, currency
symbol/code/name/narrow displays, accounting, medium dates, short times,
relative day/hour output, scientific and compact notation, cardinal plurals and
visible fraction digits.

Regenerate or verify the committed fixtures with:

```bash
node tools/gen-intl-fixtures.mjs
node tools/gen-intl-fixtures.mjs --check
```

The generator records the Node and ICU versions in the fixture header. Date and
time comparisons treat U+202F (the CLDR narrow no-break space) and U+0020 (the
space emitted by Node ICU in these patterns) as equivalent; all other spacing,
including currency spacing, is compared exactly.

Known exclusions are timezone rendering, non-Gregorian calendars and non-`latn`
numbering systems. Timezone fields can be detected with `Reject` instead of
being silently discarded. These exclusions are tracked in the roadmap below.

## Roadmap

1. Unit formatting and compact long forms.
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