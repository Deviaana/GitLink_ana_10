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

const fixtureCount = (fixtures.match(/^test "/gm) ?? []).length;
if (fixtureCount !== baseline.intlFixtures) {
  throw new Error(
    `expected ${baseline.intlFixtures} Intl fixtures, found ${fixtureCount}`,
  );
}

requireText("docs/proposal.md", [
  `CLDR ${baseline.cldrVersion}`,
  `UTS #35 revision ${baseline.uts35Revision}`,
  "docs/conformance.md",
]);

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
