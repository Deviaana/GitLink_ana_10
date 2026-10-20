import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const baseline = JSON.parse(
  readFileSync(join("tools", "cldr-baseline.json"), "utf8"),
);
const locales = baseline.locales;
const repo = "https://raw.githubusercontent.com/unicode-org/cldr-json";
const cache = join("tools", "cldr-cache");
const refs = [
  process.env.CLDR_JSON_REF,
  baseline.cldrJsonRef,
  baseline.cldrJsonRefFallback,
].filter(Boolean);

const jobs = [];
for (const locale of locales) {
  jobs.push([
    `cldr-numbers-full/main/${locale}/numbers.json`,
    join(cache, locale, "numbers.json"),
  ]);
  jobs.push([
    `cldr-numbers-full/main/${locale}/currencies.json`,
    join(cache, locale, "currencies.json"),
  ]);
  jobs.push([
    `cldr-dates-full/main/${locale}/ca-gregorian.json`,
    join(cache, locale, "ca-gregorian.json"),
  ]);
  jobs.push([
    `cldr-dates-full/main/${locale}/dateFields.json`,
    join(cache, locale, "dateFields.json"),
  ]);
}
jobs.push([
  "cldr-core/supplemental/plurals.json",
  join(cache, "supplemental", "plurals.json"),
]);
jobs.push([
  "cldr-core/supplemental/ordinals.json",
  join(cache, "supplemental", "ordinals.json"),
]);
jobs.push([
  "cldr-core/supplemental/currencyData.json",
  join(cache, "supplemental", "currencyData.json"),
]);

async function fetchText(url) {
  const response = await fetch(url);
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${url}`);
  }
  return response.text();
}

async function resolveSource() {
  for (const ref of refs) {
    const probe = await fetchText(
      `${repo}/${ref}/cldr-json/cldr-numbers-full/main/en/numbers.json`,
    );
    if (probe !== null) return ref;
  }
  throw new Error(
    `could not find CLDR JSON ref; tried ${refs.join(", ")}. ` +
      "Set CLDR_JSON_REF to a published cldr-json tag or branch.",
  );
}

const ref = await resolveSource();
const base = `${repo}/${ref}/cldr-json`;

let count = 0;
for (const [relativePath, path] of jobs) {
  const url = `${base}/${relativePath}`;
  const text = await fetchText(url);
  if (text === null) {
    throw new Error(`missing CLDR JSON file at ${url}`);
  }
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text, "utf8");
  count = count + 1;
  console.log(`[${count}/${jobs.length}] ${path}`);
}

for (const name of ["plurals.json", "ordinals.json", "currencyData.json"]) {
  const data = JSON.parse(
    readFileSync(join(cache, "supplemental", name), "utf8"),
  );
  const version = data.supplemental.version?._cldrVersion;
  if (version !== baseline.cldrVersion) {
    throw new Error(
      `${name} is CLDR ${version ?? "unknown"}, expected ${baseline.cldrVersion}`,
    );
  }
}

console.log(`CLDR cache refreshed from ${ref} (CLDR ${baseline.cldrVersion}).`);
