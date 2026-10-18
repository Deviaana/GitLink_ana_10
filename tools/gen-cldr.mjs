import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const locales = ["en", "zh", "de", "ja", "ar", "fr"];
const currencyCodes = [
  "USD", "EUR", "CNY", "JPY", "GBP", "KRW", "INR", "RUB", "BRL", "AUD",
  "CAD", "CHF", "HKD", "TWD", "SGD", "THB", "VND", "IDR", "MYR", "PHP",
  "SEK", "NOK", "DKK", "PLN", "TRY", "ZAR", "MXN", "AED", "SAR",
];

const cache = join("tools", "cldr-cache");
const outDir = join("data");

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
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

function numberData(locale) {
  const json = readJson(join(cache, locale, "numbers.json"));
  const numbers = json.main[locale].numbers;
  const symbols = numbers["symbols-numberSystem-latn"] || {};
  const decimal = numbers["decimalFormats-numberSystem-latn"]?.standard ?? "#,##0.###";
  const percent = numbers["percentFormats-numberSystem-latn"]?.standard ?? "#,##0%";
  const currency = numbers["currencyFormats-numberSystem-latn"] ?? {};
  let currencies = {};
  try {
    const cur = readJson(join(cache, locale, "currencies.json"));
    currencies = cur.main[locale].numbers.currencies ?? {};
  } catch {
    currencies = {};
  }
  const symbolsList = currencyCodes.map((code) => {
    const entry = currencies[code] ?? {};
    return [code, entry.symbol ?? entry["symbol-alt-narrow"] ?? code];
  });
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
    currency_symbols: symbolsList,
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
    `  currency_symbols: ${tupleArr(d.currency_symbols)},`,
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
  "// Data source: Unicode CLDR JSON (unicode-org/cldr-json), latn numbering system.",
  "",
].join("\n");

const parts = [header];
for (const locale of locales) parts.push(emitNumber(locale, numberData(locale)));
for (const locale of locales) parts.push(emitPlural(locale, pluralData(locale)));
for (const locale of locales) parts.push(emitDate(locale, dateData(locale)));
for (const locale of locales) parts.push(emitRelative(locale, relativeData(locale)));
parts.push(emitLookup("number_data", "NumberData", "numbers"));
parts.push(emitLookup("date_data", "DateData", "dates"));
parts.push(emitLookup("plural_data", "PluralData", "plurals"));
parts.push(emitLookup("relative_data", "RelativeData", "relative"));
parts.push(emitCurrencyDigits());

mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, "generated.mbt"), parts.join("\n"), "utf8");
console.log("wrote data/generated.mbt", parts.join("\n").length, "bytes");