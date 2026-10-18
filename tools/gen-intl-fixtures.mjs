import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const locales = ["en", "zh", "de", "ja", "fr", "ar"];
const outPath = join("conformance", "intl_conformance_wbtest.mbt");

function mbtString(value) {
  return '"' + Array.from(String(value)).map((char) => {
    if (char === '"') return '\\"';
    if (char === '\\') return '\\\\';
    if (char === '\n') return '\\n';
    if (char === '\r') return '\\r';
    if (char === '\t') return '\\t';
    const code = char.codePointAt(0);
    if (code >= 0x20 && code <= 0x7e) return char;
    return '\\u{' + code.toString(16).toUpperCase() + '}';
  }).join("") + '"';
}

const tests = [];
function addTest(name, body) {
  tests.push(`test ${mbtString(name)} {\n${body}\n}\n`);
}

const decimalValues = [
  ["1234567.891", 1234567.891],
  ["-1234.5", -1234.5],
  ["0.5", 0.5],
  ["12.0", 12.0],
  ["1.005", 1.005],
  ["0.0000001", 0.0000001],
];
const pluralValues = [
  ["0.0", 0.0],
  ["1.0", 1.0],
  ["2.0", 2.0],
  ["3.0", 3.0],
  ["11.0", 11.0],
  ["21.0", 21.0],
  ["1.5", 1.5],
  ["1.005", 1.005],
];

for (const locale of locales) {
  const number = new Intl.NumberFormat(locale);
  for (const [expr, value] of decimalValues) {
    addTest(`intl decimal ${locale} ${expr}`, [
      `  let locale = @core.Locale::parse(${mbtString(locale)})`,
      `  assert_eq(@number.format_decimal(${expr}, locale), ${mbtString(number.format(value))})`,
    ].join("\n"));
  }

  addTest(`intl percent ${locale}`, [
    `  let locale = @core.Locale::parse(${mbtString(locale)})`,
    `  assert_eq(@number.format_percent(0.125, locale), ${mbtString(new Intl.NumberFormat(locale, { style: "percent" }).format(0.125))})`,
  ].join("\n"));

  const compact = new Intl.NumberFormat(locale, { notation: "compact" });
  addTest(`intl compact ${locale}`, [
    `  let locale = @core.Locale::parse(${mbtString(locale)})`,
    `  assert_eq(@number.format_compact(12345.0, locale), ${mbtString(compact.format(12345))})`,
  ].join("\n"));

  const scientific = new Intl.NumberFormat(locale, { notation: "scientific" });
  addTest(`intl scientific ${locale}`, [
    `  let locale = @core.Locale::parse(${mbtString(locale)})`,
    `  assert_eq(@number.format_scientific(1234567.0, locale), ${mbtString(scientific.format(1234567))})`,
  ].join("\n"));
  const symbol = new Intl.NumberFormat(locale, { style: "currency", currency: "USD" });
  addTest(`intl currency symbol ${locale}`, [
    `  let locale = @core.Locale::parse(${mbtString(locale)})`,
    `  assert_eq(@number.format_currency(1234.5, "USD", locale), ${mbtString(symbol.format(1234.5))})`,
  ].join("\n"));

  const code = new Intl.NumberFormat(locale, { style: "currency", currency: "USD", currencyDisplay: "code" });
  addTest(`intl currency code ${locale}`, [
    `  let locale = @core.Locale::parse(${mbtString(locale)})`,
    `  let opts = @number.CurrencyOptions::with_display(@number.Code)`,
    `  assert_eq(@number.format_currency(1234.5, "USD", locale, currency_options=opts), ${mbtString(code.format(1234.5))})`,
  ].join("\n"));

  const name = new Intl.NumberFormat(locale, { style: "currency", currency: "USD", currencyDisplay: "name" });
  addTest(`intl currency name ${locale}`, [
    `  let locale = @core.Locale::parse(${mbtString(locale)})`,
    `  let opts = @number.CurrencyOptions::with_display(@number.Name)`,
    `  assert_eq(@number.format_currency(1234.5, "USD", locale, currency_options=opts), ${mbtString(name.format(1234.5))})`,
  ].join("\n"));

  const narrow = new Intl.NumberFormat(locale, { style: "currency", currency: "CAD", currencyDisplay: "narrowSymbol" });
  addTest(`intl currency narrow ${locale}`, [
    `  let locale = @core.Locale::parse(${mbtString(locale)})`,
    `  let opts = @number.CurrencyOptions::with_display(@number.NarrowSymbol)`,
    `  assert_eq(@number.format_currency(1234.5, "CAD", locale, currency_options=opts), ${mbtString(narrow.format(1234.5))})`,
  ].join("\n"));

  if (locale === "en" || locale === "de" || locale === "fr") {
    const accounting = new Intl.NumberFormat(locale, { style: "currency", currency: "USD", currencySign: "accounting" });
    addTest(`intl currency accounting ${locale}`, [
      `  let locale = @core.Locale::parse(${mbtString(locale)})`,
      `  let opts = @number.CurrencyOptions::default().with_accounting()`,
      `  assert_eq(@number.format_currency(-1234.5, "USD", locale, currency_options=opts), ${mbtString(accounting.format(-1234.5))})`,
    ].join("\n"));
  }

  const date = new Date(Date.UTC(2026, 9, 18, 17, 42, 5));
  addTest(`intl date medium ${locale}`, [
    `  let locale = @core.Locale::parse(${mbtString(locale)})`,
    `  let date = @datetime.DateTime::new(2026, 10, 18, hour=17, minute=42, second=5)`,
    `  assert_eq(`,
    `    normalize_intl_date_time(@datetime.format_date(date, locale)),`,
    `    normalize_intl_date_time(${mbtString(new Intl.DateTimeFormat(locale, { dateStyle: "medium", timeZone: "UTC" }).format(date))}),`,
    `  )`,
  ].join("\n"));

  addTest(`intl time short ${locale}`, [
    `  let locale = @core.Locale::parse(${mbtString(locale)})`,
    `  let date = @datetime.DateTime::new(2026, 10, 18, hour=17, minute=42, second=5)`,
    `  assert_eq(`,
    `    normalize_intl_date_time(@datetime.format_time(date, locale, style=@datetime.Short)),`,
    `    normalize_intl_date_time(${mbtString(new Intl.DateTimeFormat(locale, { timeStyle: "short", timeZone: "UTC" }).format(date))}),`,
    `  )`,
  ].join("\n"));

  const rtfAuto = new Intl.RelativeTimeFormat(locale, { numeric: "auto" });
  const rtfAlways = new Intl.RelativeTimeFormat(locale, { numeric: "always" });
  const relativeCases = [
    ["day", "-3.0", -3, rtfAuto.format(-3, "day")],
    ["day", "0.0", 0, rtfAuto.format(0, "day")],
    ["day", "1.0", 1, rtfAuto.format(1, "day")],
    ["day", "-1.0", -1, rtfAuto.format(-1, "day")],
    ["hour", "1.5", 1.5, rtfAuto.format(1.5, "hour")],
    ["hour", "1.0001", 1.0001, rtfAlways.format(1.0001, "hour")],
  ];
  for (const [unit, expr, , expected] of relativeCases) {
    const unitEnum = unit === "day" ? "Day" : "Hour";
    addTest(`intl relative ${locale} ${unit} ${expr}`, [
      `  let locale = @core.Locale::parse(${mbtString(locale)})`,
      `  assert_eq(@relative.format_relative(${expr}, @relative.${unitEnum}, locale), ${mbtString(expected)})`,
    ].join("\n"));
  }

  const plural = new Intl.PluralRules(locale);
  for (const [expr, value] of pluralValues) {
    addTest(`intl plural ${locale} ${expr}`, [
      `  let rules = @plural.PluralRules::cached(${mbtString(locale)})`,
      `  assert_eq(rules.select(${expr}), ${mbtString(plural.select(value))})`,
    ].join("\n"));
  }
}

addTest("intl plural visible fraction digits en", [
  `  let options = "en"`,
  `  let rules = @plural.PluralRules::cached(options)`,
  `  assert_eq(rules.select(1.0), "one")`,
  `  assert_eq(rules.select(1.0, visible_fraction_digits=2), "other")`,
].join("\n"));

const header = [
  "// Generated by tools/gen-intl-fixtures.mjs. Do not edit by hand.",
  `// Node ${process.version}; ICU ${process.versions.icu ?? "unknown"}.`,
  "// These assertions are generated from Node Intl and cover supported CLDR surface area.",
  "",
].join("\n");
const helpers = [
  "///|",
  "// CLDR uses U+202F between a time and AM/PM in some locales, while Node ICU",
  "// renders U+0020. Compare date/time text modulo that equivalent spacing only.",
  "fn normalize_intl_date_time(text : String) -> String {",
  '  text.replace_all(old="\\u{202F}", new=" ")',
  "}",
  "",
].join("\n");
const output = header + "\n" + helpers + "\n" + tests.join("\n");

function formatMoonBit(path) {
  const moon = process.platform === "win32" ? "moon.exe" : "moon";
  const result = spawnSync(moon, ["fmt", path], { encoding: "utf8" });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    process.stderr.write(result.stdout ?? "");
    process.stderr.write(result.stderr ?? "");
    throw new Error(`moon fmt failed for ${path}`);
  }
}

mkdirSync("conformance", { recursive: true });
if (process.argv.includes("--check")) {
  const checkPath = join("conformance", "intl_conformance_generated_check.mbt");
  try {
    writeFileSync(checkPath, output, "utf8");
    formatMoonBit(checkPath);
    const formatted = readFileSync(checkPath, "utf8");
    let current = "";
    try {
      current = readFileSync(outPath, "utf8");
    } catch {
      console.error(`missing ${outPath}; run node tools/gen-intl-fixtures.mjs`);
      process.exit(1);
    }
    if (current !== formatted) {
      console.error(`${outPath} is out of date; run node tools/gen-intl-fixtures.mjs`);
      process.exit(1);
    }
  } finally {
    rmSync(checkPath, { force: true });
  }
  console.log(`${outPath} is up to date (${tests.length} tests).`);
} else {
  writeFileSync(outPath, output, "utf8");
  formatMoonBit(outPath);
  const formatted = readFileSync(outPath, "utf8");
  console.log(`wrote ${outPath} (${tests.length} tests, ${formatted.length} bytes).`);
}