import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const baseline = JSON.parse(
  readFileSync(join("tools", "cldr-baseline.json"), "utf8"),
);
const locales = ["en", "zh", "de", "ja", "ar", "fr"];
const baselineLocales = [...baseline.locales].sort().join(",");
if (baselineLocales !== [...locales].sort().join(",")) {
  throw new Error("tools/cldr-baseline.json locales do not match the generator");
}
if (baseline.numberingSystem !== "latn") {
  throw new Error("this generator currently supports the latn numbering system");
}
const currencyCodes = [
  "USD", "EUR", "CNY", "JPY", "GBP", "KRW", "INR", "RUB", "BRL", "AUD",
  "CAD", "CHF", "HKD", "TWD", "SGD", "THB", "VND", "IDR", "MYR", "PHP",
  "SEK", "NOK", "DKK", "PLN", "TRY", "ZAR", "MXN", "AED", "SAR",
];

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

const cache = join("tools", "cldr-cache");
const outDir = join("data");

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function assertSupplementalVersion(name) {
  const data = readJson(join(cache, "supplemental", name));
  const version = data.supplemental.version?._cldrVersion;
  if (version !== baseline.cldrVersion) {
    throw new Error(
      `${name} is CLDR ${version ?? "unknown"}, expected ${baseline.cldrVersion}`,
    );
  }
}

for (const name of ["plurals.json", "ordinals.json", "currencyData.json"]) {
  assertSupplementalVersion(name);
}

function esc(value) {
  if (value === undefined || value === null) return '""';
  const text = String(value)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r")
    .replace(/\t/g, "\\t");
  return '"' + text + '"';
}

function arr(values) {
  return "[" + values.map(esc).join(", ") + "]";
}

function tupleArr(pairs) {
  return "[" + pairs.map(([k, v]) => "(" + esc(k) + ", " + esc(v) + ")").join(", ") + "]";
}

function tripleArr(triples) {
  return "[" + triples.map(([a, b, c]) =>
    "(" + esc(a) + ", " + esc(b) + ", " + esc(c) + ")"
  ).join(", ") + "]";
}

function indexedTextArr(entries) {
  return "[" + entries.map(([index, value]) =>
    "(" + index + ", " + esc(value) + ")"
  ).join(", ") + "]";
}

function compactArr(entries) {
  return "[" + entries.map(([magnitude, category, pattern]) =>
    "(" + magnitude + ", " + esc(category) + ", " + esc(pattern) + ")"
  ).join(", ") + "]";
}
function textPairArr(pairs) {
  return "[" + pairs.map(([a, b]) =>
    "(" + esc(a) + ", " + esc(b) + ")"
  ).join(", ") + "]";
}

function currencySymbolOverrides(entries, baseEntries) {
  const base = new Map(baseEntries);
  return entries.flatMap(([code, value], index) =>
    value === base.get(code) ? [] : [[index, value]]
  );
}

function currencyNarrowOverrides(symbols, narrowSymbols) {
  const regular = new Map(symbols);
  return narrowSymbols.flatMap(([code, value], index) =>
    value === regular.get(code) ? [] : [[index, value]]
  );
}

function emitCurrencyTables(base) {
  return [
    `///|`,
    `let currency_codes : Array[String] = ${arr(currencyCodes)}`,
    `///|`,
    `let currency_base_symbols : Array[String] = ${arr(base.currency_symbols.map(([, value]) => value))}`,
    ``,
  ].join("\n");
}

function emitProvenance() {
  return [
    `///|`,
    `pub fn cldr_version() -> String {`,
    `  ${esc(baseline.cldrVersion)}`,
    `}`,
    `///|`,
    `pub fn cldr_uts35_revision() -> String {`,
    `  ${esc(baseline.uts35Revision)}`,
    `}`,
    `///|`,
    `pub fn cldr_numbering_system() -> String {`,
    `  ${esc(baseline.numberingSystem)}`,
    `}`,
    `///|`,
    `pub fn cldr_calendar() -> String {`,
    `  ${esc(baseline.calendar)}`,
    `}`,
    ``,
  ].join("\n");
}

function numberData(locale) {
  const json = readJson(join(cache, locale, "numbers.json"));
  const numbers = json.main[locale].numbers;
  const symbols = numbers["symbols-numberSystem-latn"] || {};
  const decimal = numbers["decimalFormats-numberSystem-latn"]?.standard ?? "#,##0.###";
  const percent = numbers["percentFormats-numberSystem-latn"]?.standard ?? "#,##0%";
  const currency = numbers["currencyFormats-numberSystem-latn"] ?? {};
  const scientificPattern =
    numbers["scientificFormats-numberSystem-latn"]?.standard ?? "#E0";
  const compactFormat =
    numbers["decimalFormats-numberSystem-latn"]?.short?.decimalFormat ?? {};
  const compactByMagnitude = new Map();
  for (const [key, pattern] of Object.entries(compactFormat)) {
    const match = key.match(/^(\d+)-count-(.+)$/);
    if (!match) continue;
    const magnitude = match[1].length - 1;
    const category = match[2];
    const categories = compactByMagnitude.get(magnitude) ?? {};
    categories[category] = pattern;
    compactByMagnitude.set(magnitude, categories);
  }
  const compactPatterns = [];
  const compactPluralPatterns = [];
  for (const magnitude of [...compactByMagnitude.keys()].sort((a, b) => a - b)) {
    const categories = compactByMagnitude.get(magnitude);
    const fallback =
      categories.other ?? Object.values(categories)[0];
    compactPatterns.push([magnitude, fallback]);
    for (const [category, pattern] of Object.entries(categories)) {
      if (category !== "other" && pattern !== fallback) {
        compactPluralPatterns.push([magnitude, category, pattern]);
      }
    }
  }
  let currencies = {};
  try {
    const cur = readJson(join(cache, locale, "currencies.json"));
    currencies = cur.main[locale].numbers.currencies ?? {};
  } catch {
    currencies = {};
  }
  const currencyEntries = currencyCodes.map((code) => [code, currencies[code] ?? {}]);
  const symbolsList = currencyEntries.map(([code, entry]) => [
    code,
    entry.symbol ?? entry["symbol-alt-narrow"] ?? code,
  ]);
  const narrowSymbolsList = currencyEntries.map(([code, entry]) => [
    code,
    entry["symbol-alt-narrow"] ?? entry.symbol ?? code,
  ]);
  const namesList = currencyEntries.map(([code, entry]) => [
    code,
    entry["displayName-count-one"] ?? entry.displayName ?? entry["displayName-count-other"] ?? code,
    entry["displayName-count-other"] ?? entry.displayName ?? entry["displayName-count-one"] ?? code,
  ]);
  return {
    decimal: symbols.decimal ?? ".",
    group: symbols.group ?? ",",
    percent_sign: symbols.percentSign ?? "%",
    minus_sign: symbols.minusSign ?? "-",
    plus_sign: symbols.plusSign ?? "+",
    nan: symbols.nan ?? "NaN",
    infinity: symbols.infinity ?? "∞",
    decimal_pattern: decimal,
    percent_pattern: percent,
    currency_pattern: currency.standard ?? "¤#,##0.00",
    accounting_pattern: currency.accounting ?? "¤#,##0.00;(¤#,##0.00)",
    currency_unit_pattern_one:
      currency["unitPattern-count-one"] ??
      currency["unitPattern-count-other"] ??
      "{0} {1}",
    currency_unit_pattern_other:
      currency["unitPattern-count-other"] ??
      currency["unitPattern-count-one"] ??
      "{0} {1}",
    currency_spacing:
      currency.currencySpacing?.beforeCurrency?.insertBetween ??
      currency.currencySpacing?.afterCurrency?.insertBetween ??
      "\u00A0",
    currency_symbols: symbolsList,
    currency_narrow_symbols: narrowSymbolsList,
    currency_names: namesList,
    scientific_pattern: scientificPattern,
    compact_patterns: compactPatterns,
    compact_plural_patterns: compactPluralPatterns,
  };
}

function pluralData(locale) {
  const cardinal = readJson(join(cache, "supplemental", "plurals.json"))
    .supplemental["plurals-type-cardinal"][locale] ?? {};
  let ordinal = {};
  try {
    ordinal = readJson(join(cache, "supplemental", "ordinals.json"))
      .supplemental["plurals-type-ordinal"][locale] ?? {};
  } catch {
    ordinal = {};
  }
  const toPairs = (obj) =>
    Object.entries(obj).map(([key, rule]) => [
      key.replace("pluralRule-count-", ""),
      String(rule).split("@")[0].trim(),
    ]);
  return { cardinal: toPairs(cardinal), ordinal: toPairs(ordinal) };
}

function dateData(locale) {
  const json = readJson(join(cache, locale, "ca-gregorian.json"));
  const greg = json.main[locale].dates.calendars.gregorian;
  const months = greg.months.format;
  const days = greg.days.format;
  const periods = greg.dayPeriods.format.wide;
  const monthsWide = [];
  const monthsAbbr = [];
  for (let i = 1; i <= 12; i++) {
    monthsWide.push(months.wide[String(i)] ?? "");
    monthsAbbr.push(months.abbreviated[String(i)] ?? months.wide[String(i)] ?? "");
  }
  const dayKeys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
  const daysWide = dayKeys.map((k) => days.wide[k] ?? "");
  const daysAbbr = dayKeys.map((k) => days.abbreviated[k] ?? days.wide[k] ?? "");
  return {
    full_date: greg.dateFormats.full ?? "",
    long_date: greg.dateFormats.long ?? "",
    medium_date: greg.dateFormats.medium ?? "",
    short_date: greg.dateFormats.short ?? "",
    full_time: greg.timeFormats.full ?? "",
    long_time: greg.timeFormats.long ?? "",
    medium_time: greg.timeFormats.medium ?? "",
    short_time: greg.timeFormats.short ?? "",
    interval_fallback:
      greg.dateTimeFormats.intervalFormats?.intervalFormatFallback ??
      "{0} \u2013 {1}",
    months_wide: monthsWide,
    months_abbr: monthsAbbr,
    days_wide: daysWide,
    days_abbr: daysAbbr,
    am: periods.am ?? "AM",
    pm: periods.pm ?? "PM",
  };
}

function emitNumber(locale, d) {
  return [
    `///|`,
    `let ${locale}_numbers : NumberData = {`,
    `  decimal: ${esc(d.decimal)},`,
    `  group: ${esc(d.group)},`,
    `  percent_sign: ${esc(d.percent_sign)},`,
    `  minus_sign: ${esc(d.minus_sign)},`,
    `  plus_sign: ${esc(d.plus_sign)},`,
    `  nan: ${esc(d.nan)},`,
    `  infinity: ${esc(d.infinity)},`,
    `  decimal_pattern: ${esc(d.decimal_pattern)},`,
    `  percent_pattern: ${esc(d.percent_pattern)},`,
    `  currency_pattern: ${esc(d.currency_pattern)},`,
    `  accounting_pattern: ${esc(d.accounting_pattern)},`,
    `  currency_unit_pattern_one: ${esc(d.currency_unit_pattern_one)},`,
    `  currency_unit_pattern_other: ${esc(d.currency_unit_pattern_other)},`,
    `  currency_spacing: ${esc(d.currency_spacing)},`,
    `  currency_symbol_overrides: ${indexedTextArr(d.currency_symbol_overrides)},`,
    `  currency_narrow_symbol_overrides: ${indexedTextArr(d.currency_narrow_symbol_overrides)},`,
    `  currency_names: ${textPairArr(d.currency_names)},`,
    `  scientific_pattern: ${esc(d.scientific_pattern)},`,
    `  compact_patterns: ${indexedTextArr(d.compact_patterns)},`,
    `  compact_plural_patterns: ${compactArr(d.compact_plural_patterns)},`,
    `}`,
    ``,
  ].join("\n");
}

function emitPlural(locale, d) {
  return [
    `///|`,
    `let ${locale}_plurals : PluralData = {`,
    `  cardinal: ${tupleArr(d.cardinal)},`,
    `  ordinal: ${tupleArr(d.ordinal)},`,
    `}`,
    ``,
  ].join("\n");
}

function emitDate(locale, d) {
  return [
    `///|`,
    `let ${locale}_dates : DateData = {`,
    `  full_date: ${esc(d.full_date)},`,
    `  long_date: ${esc(d.long_date)},`,
    `  medium_date: ${esc(d.medium_date)},`,
    `  short_date: ${esc(d.short_date)},`,
    `  full_time: ${esc(d.full_time)},`,
    `  long_time: ${esc(d.long_time)},`,
    `  medium_time: ${esc(d.medium_time)},`,
    `  short_time: ${esc(d.short_time)},`,
    `  interval_fallback: ${esc(d.interval_fallback)},`,
    `  months_wide: ${arr(d.months_wide)},`,
    `  months_abbr: ${arr(d.months_abbr)},`,
    `  days_wide: ${arr(d.days_wide)},`,
    `  days_abbr: ${arr(d.days_abbr)},`,
    `  am: ${esc(d.am)},`,
    `  pm: ${esc(d.pm)},`,
    `}`,
    ``,
  ].join("\n");
}

function emitLookup(name, typeName, suffix) {
  const lines = [
    `///|`,
    `pub fn ${name}(anchor : String) -> ${typeName}? {`,
    `  match anchor {`,
  ];
  for (const locale of locales) {
    lines.push(`    ${esc(locale)} => Some(${locale}_${suffix})`);
  }
  lines.push(`    _ => None`);
  lines.push(`  }`);
  lines.push(`}`);
  lines.push(``);
  return lines.join("\n");
}

function optStr(value) {
  return value === undefined || value === null ? "None" : "Some(" + esc(value) + ")";
}

const relativeUnits = ["year", "month", "week", "day", "hour", "minute", "second"];

function relativeData(locale) {
  const fields = readJson(join(cache, locale, "dateFields.json")).main[locale]
    .dates.fields;
  const out = {};
  for (const unit of relativeUnits) {
    const field = fields[unit] ?? {};
    const toPairs = (obj) =>
      Object.entries(obj ?? {}).map(([key, pattern]) => [
        key.replace("relativeTimePattern-count-", ""),
        pattern,
      ]);
    out[unit] = {
      future: toPairs(field["relativeTime-type-future"]),
      past: toPairs(field["relativeTime-type-past"]),
      zero: field["relative-type-0"] ?? null,
      one_future: field["relative-type-1"] ?? null,
      one_past: field["relative-type--1"] ?? null,
    };
  }
  return out;
}

function emitUnit(unit, d) {
  return [
    `  ${unit}: {`,
    `    future: ${tupleArr(d.future)},`,
    `    past: ${tupleArr(d.past)},`,
    `    zero: ${optStr(d.zero)},`,
    `    one_future: ${optStr(d.one_future)},`,
    `    one_past: ${optStr(d.one_past)},`,
    `  },`,
  ].join("\n");
}

function emitRelative(locale, d) {
  const lines = [`///|`, `let ${locale}_relative : RelativeData = {`];
  for (const unit of relativeUnits) lines.push(emitUnit(unit, d[unit]));
  lines.push(`}`);
  lines.push(``);
  return lines.join("\n");
}
function currencyDigits() {
  const fractions = readJson(
    join(cache, "supplemental", "currencyData.json"),
  ).supplemental.currencyData.fractions;
  const fallback = Number(fractions.DEFAULT?._digits ?? 2);
  const entries = Object.entries(fractions)
    .filter(([code]) => code !== "DEFAULT")
    .map(([code, value]) => [code, Number(value?._digits ?? fallback)]);
  return { fallback, entries };
}

function emitCurrencyDigits() {
  const { fallback, entries } = currencyDigits();
  const lines = [
    `///|`,
    `pub fn currency_digits(code : String) -> Int {`,
    `  match code.to_upper() {`,
  ];
  for (const [code, digits] of entries) {
    lines.push(`    ${esc(code)} => ${digits}`);
  }
  lines.push(`    _ => ${fallback}`);
  lines.push(`  }`);
  lines.push(`}`);
  lines.push(``);
  return lines.join("\n");
}
const header = [
  "// Generated by tools/gen-cldr.mjs. Do not edit by hand.",
  `// CLDR version: ${baseline.cldrVersion}; UTS #35 revision ${baseline.uts35Revision}; numbering system: ${baseline.numberingSystem}.`,
  `// Data source: unicode-org/cldr-json ${baseline.cldrJsonRef}.`,
  "",
].join("\n");

const numbersByLocale = new Map(locales.map((locale) => [locale, numberData(locale)]));
const currencyBase = numbersByLocale.get(locales[0]);
for (const d of numbersByLocale.values()) {
  d.currency_symbol_overrides = currencySymbolOverrides(
    d.currency_symbols,
    currencyBase.currency_symbols,
  );
  d.currency_narrow_symbol_overrides = currencyNarrowOverrides(
    d.currency_symbols,
    d.currency_narrow_symbols,
  );
  d.currency_names = d.currency_names.map(([, one, other]) => [one, other]);
}

const parts = [header, emitProvenance(), emitCurrencyTables(currencyBase)];
for (const locale of locales) parts.push(emitNumber(locale, numbersByLocale.get(locale)));
for (const locale of locales) parts.push(emitPlural(locale, pluralData(locale)));
for (const locale of locales) parts.push(emitDate(locale, dateData(locale)));
for (const locale of locales) parts.push(emitRelative(locale, relativeData(locale)));
parts.push(emitLookup("number_data", "NumberData", "numbers"));
parts.push(emitLookup("date_data", "DateData", "dates"));
parts.push(emitLookup("plural_data", "PluralData", "plurals"));
parts.push(emitLookup("relative_data", "RelativeData", "relative"));
parts.push(emitCurrencyDigits());

mkdirSync(outDir, { recursive: true });
const outPath = join(outDir, "generated.mbt");
writeFileSync(outPath, parts.join("\n"), "utf8");
formatMoonBit(outPath);
const formatted = readFileSync(outPath, "utf8");
console.log("wrote", outPath, formatted.length, "characters");
