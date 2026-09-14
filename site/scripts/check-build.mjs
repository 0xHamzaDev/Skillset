import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const catalog = JSON.parse(readFileSync(new URL("../../catalog/catalog.json", import.meta.url), "utf8"));
const paths = ["/", ...catalog.skills.map(({ id }) => `/skills/${id}/`), ...catalog.bundles.map(({ id }) => `/bundles/${id}/`)];
for (const path of paths) {
  for (const prefix of ["", "/en"]) {
    const html = readFileSync(new URL(`../dist${prefix}${path}index.html`, import.meta.url), "utf8");
    assert.match(html, /<html lang="en"/);
    assert.ok(html.includes(`href="https://skillset.app${path}"`), `${prefix}${path}: wrong canonical`);
    assert.doesNotMatch(html, /[\u0600-\u06ff]/);
    assert.ok(html.includes("data-theme-toggle"), `${prefix}${path}: missing theme control`);
  }
}
const home = readFileSync(new URL("../dist/index.html", import.meta.url), "utf8");
for (const { id } of catalog.skills) assert.ok(home.includes(`href="/skills/${id}/"`), `missing catalog link ${id}`);
assert.match(home, /data-demo-select="pdf"/);
console.log(`site checks: ${paths.length * 2} English routes, canonical URLs, appearance controls, and catalog links pass`);
