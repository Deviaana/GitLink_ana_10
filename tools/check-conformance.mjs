import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const baseline = JSON.parse(
  readFileSync(join(root, "tools", "cldr-baseline.json"), "utf8"),
);

function read(relativePath) {
  return readFileSync(join(root, relativePath), "utf8");
}

function requireText(relativePath, needles) {
  const text = read(relativePath);
  for (const needle of needles) {
    if (!text.includes(needle)) {
      throw new Error(`${relativePath} is missing required text: ${needle}`);
    }
  }
  return text;
}

requireText("data/generated.mbt", [
  `CLDR version: ${baseline.cldrVersion}`,
  `UTS #35 revision ${baseline.uts35Revision}`,
  `pub fn cldr_version() -> String`,
  `pub fn cldr_numbering_system() -> String`,
  `"${baseline.cldrVersion}"`,
  `"${baseline.numberingSystem}"`,
]);

const fixtures = requireText("conformance/intl_conformance_wbtest.mbt", [
  `// Node v${baseline.nodeVersion}; ICU ${baseline.icuVersion}.`,
  `// CLDR data baseline: ${baseline.cldrVersion} (UTS #35 revision ${baseline.uts35Revision}).`,
]);

requireText("number/format_wbtest.mbt", [
  `test "significant digit patterns follow CLDR @"`,
  `test "rounding increments come from 1-9 pattern digits"`,
  `test "quoted pattern literals and currency markers"`,
  `test "pad escape uses the following character and pattern width"`,
  `format_with_pattern(0.12345, en, "@@##")`,
  `format_with_pattern(1.23456, en, "0.005")`,
  `format_with_pattern(1.15, en, "0.25")`,
  `format_with_pattern(1.0, en, "0''")`,
  `format_currency_with_pattern(1234.5, "USD", en, "'\\u{00A4}'#,##0.00")`,
  `format_with_pattern(1.2, en, "*_#,##0.00")`,
]);

requireText("docs/resubmission-note.md", [
  `## 2. 有效位验收案例`,
  `## 3. 增量舍入验收案例`,
  "| `0.25` + `1.15` |",
  `moon test --target js`,
  `moon test --target native`,
]);

const fixtureCount = (fixtures.match(/^test "/gm) ?? []).length;
if (fixtureCount !== baseline.intlFixtures) {
  throw new Error(
    `expected ${baseline.intlFixtures} Intl fixtures, found ${fixtureCount}`,
  );
}

requireText("README.md", [
  `CLDR ${baseline.cldrVersion}`,
  `UTS #35 revision ${baseline.uts35Revision}`,
  "docs/conformance.md",
]);

const conformance = requireText("docs/conformance.md", [
  `CLDR ${baseline.cldrVersion}`,
  `UTS #35 revision ${baseline.uts35Revision}`,
  `Node ${baseline.nodeVersion}`,
  `ICU ${baseline.icuVersion}`,
  `#### 3.3.1 数字模式验收范围`,
  `有效位验收案例`,
  `增量舍入验收案例`,
  `填充验收案例`,
  `format_with_pattern(1.15, en, "0.25")`,
  "引号内货币占位符保持字面量",
]);

for (const locale of baseline.locales) {
  if (!conformance.includes(`\`${locale}\``)) {
    throw new Error(`docs/conformance.md is missing locale: ${locale}`);
  }
}

console.log(
  `Conformance metadata OK: CLDR ${baseline.cldrVersion}, ` +
    `UTS #35 revision ${baseline.uts35Revision}, ` +
    `${fixtureCount} Intl fixtures, ` +
    `Node ${baseline.nodeVersion}/ICU ${baseline.icuVersion}.`,
);
