import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const locales = ["en", "zh", "de", "ja", "ar", "fr"];
const base =
  "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json";
const cache = join("tools", "cldr-cache");

const jobs = [];
for (const locale of locales) {
  jobs.push([
    `${base}/cldr-numbers-full/main/${locale}/numbers.json`,
    join(cache, locale, "numbers.json"),
  ]);
  jobs.push([
    `${base}/cldr-numbers-full/main/${locale}/currencies.json`,
    join(cache, locale, "currencies.json"),
  ]);
  jobs.push([
    `${base}/cldr-dates-full/main/${locale}/ca-gregorian.json`,
    join(cache, locale, "ca-gregorian.json"),
  ]);
  jobs.push([
    `${base}/cldr-dates-full/main/${locale}/dateFields.json`,
    join(cache, locale, "dateFields.json"),
  ]);
}
jobs.push([
  `${base}/cldr-core/supplemental/plurals.json`,
  join(cache, "supplemental", "plurals.json"),
]);
jobs.push([
  `${base}/cldr-core/supplemental/ordinals.json`,
  join(cache, "supplemental", "ordinals.json"),
]);
jobs.push([
  `${base}/cldr-core/supplemental/currencyData.json`,
  join(cache, "supplemental", "currencyData.json"),
]);

let count = 0;
for (const [url, path] of jobs) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${url}`);
  }
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, await response.text(), "utf8");
  count = count + 1;
  console.log(`[${count}/${jobs.length}] ${path}`);
}
console.log("CLDR cache refreshed.");