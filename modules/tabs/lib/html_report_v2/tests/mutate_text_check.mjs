// Catalogue mutation check.
//
// The report's prose is authored in the Callout Editor, so the report author
// may rewrite any sentence at any time. A test that asserts on those words
// would go red on their next edit and, worse, would read as a code failure.
//
// This check makes that rule enforceable rather than aspirational: it reruns
// the whole node suite against a MUTATED catalogue. Every authored value
// replaced with a marker string, and requires it to pass exactly as it does
// against the real one. Anything still pinned to real wording fails here.
//
// Run it after every stage of the text extraction:
//   node tests/mutate_text_check.mjs
//
// It works by pointing TURAS_TEXT_MUTATE at the suite; _text.mjs honours the
// variable when it builds its catalogue, so both the sandboxed renderer and the
// tests' own expectations move together. A test comparing rendered output to
// TXT(key) therefore still passes; one comparing it to a literal does not.

import { readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { spawnSync } from "node:child_process";

const HERE = path.dirname(fileURLToPath(import.meta.url));

const files = readdirSync(HERE)
  .filter((f) => f.endsWith("_tests.mjs"))
  .sort();

let failedFiles = [];
for (const f of files) {
  const r = spawnSync(process.execPath, [path.join(HERE, f)], {
    encoding: "utf8",
    env: Object.assign({}, process.env, { TURAS_TEXT_MUTATE: "1" })
  });
  const out = (r.stdout || "") + (r.stderr || "");
  const bad = r.status !== 0 || /✗/.test(out);
  if (bad) {
    failedFiles.push(f);
    console.log("✗ " + f);
    out.split("\n").filter((l) => /✗/.test(l)).forEach((l) => console.log("   " + l.trim()));
  } else {
    console.log("✓ " + f);
  }
}

console.log("");
if (failedFiles.length) {
  console.log("MUTATION CHECK FAILED in " + failedFiles.length + " file(s).");
  console.log("Each failure is a test asserting on wording the report author owns.");
  console.log("Assert on TXT(key) from _text.mjs, or on the data-txt-key attribute, instead.");
  process.exit(1);
}
console.log("MUTATION CHECK PASSED. No test depends on authored wording.");
