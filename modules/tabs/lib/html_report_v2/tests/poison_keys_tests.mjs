#!/usr/bin/env node
/**
 * M11 (production review 2026-08) — survey text is not safe as an object key.
 *
 * The v2 data layer indexes questions by code and groups them by Selection
 * Category using plain `{}` objects as maps. A category or code that collides
 * with something on Object.prototype — "constructor", "toString", "valueOf",
 * "hasOwnProperty" — reads back as an inherited function instead of "absent",
 * and the report either crashes on boot or silently treats a function as a
 * question. Neither is a value the analyst typed; both come free with `{}`.
 *
 * P1 d2.categories(): a category named "constructor" groups like any other
 *    name, and does not crash the boot.
 * P2 d2.categories(): every Object.prototype name survives, in Selection
 *    order, with its questions attached and none duplicated.
 * P3 d2.questionByCode(): an absent poison code returns null, not a function.
 * P4 A real question code that happens to be a poison name still resolves.
 * P5 Ordinary categories and codes are untouched (no behaviour traded away).
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/poison_keys_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const load = (sandbox, file) =>
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(actual, expected, msg) {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a !== e) throw new Error(msg + ": expected " + e + ", got " + a);
}

/** The names that come free with every `{}`. */
const POISON = ["constructor", "toString", "valueOf", "hasOwnProperty",
                "__proto__", "isPrototypeOf", "propertyIsEnumerable"];

/** Sandbox with the real d2 (20_data.js) over a given AGG. */
function dataSandbox(questions) {
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  load(sb, "00_namespace.js");
  load(sb, "01_format.js");
  load(sb, "20_data.js");
  sb.TR.AGG = { questions: questions, columns: [], banner_groups: [] };
  return sb.TR.d2;
}

const q = (code, category) => ({ code: code, category: category, rows: [] });

console.log("Poison object keys in the v2 data layer (M11) — suite:");

run("P1 a Selection Category named 'constructor' groups instead of crashing", () => {
  const d2 = dataSandbox([
    q("Q1", "Service"), q("Q2", "constructor"), q("Q3", "Service"),
  ]);
  const cats = d2.categories();
  eq(cats.map(function (c) { return c.title; }), ["Service", "constructor"],
     "category order");
  eq(cats[0].codes, ["Q1", "Q3"], "ordinary category keeps both questions");
  eq(cats[1].codes, ["Q2"], "poison category carries its question");
});

run("P2 every Object.prototype name survives as a category", () => {
  const d2 = dataSandbox(POISON.map(function (name, i) {
    return q("Q" + i, name);
  }));
  const cats = d2.categories();
  eq(cats.length, POISON.length, "one group per category");
  eq(cats.map(function (c) { return c.title; }), POISON, "titles, in order");
  cats.forEach(function (c, i) {
    eq(c.codes, ["Q" + i], "codes under " + POISON[i]);
  });
});

run("P2b a poison category repeated groups once, not twice", () => {
  const d2 = dataSandbox([
    q("Q1", "toString"), q("Q2", "Service"), q("Q3", "toString"),
  ]);
  const cats = d2.categories();
  eq(cats.length, 2, "two groups");
  eq(cats[0].title, "toString", "first group");
  eq(cats[0].codes, ["Q1", "Q3"], "both questions under the one group");
});

run("P3 questionByCode returns null for an absent poison code", () => {
  const d2 = dataSandbox([q("Q1", "Service")]);
  POISON.forEach(function (name) {
    const hit = d2.questionByCode(name);
    assert(hit === null,
           "questionByCode('" + name + "') returned " + typeof hit + ", not null");
  });
});

run("P4 a question whose code IS a poison name still resolves", () => {
  const d2 = dataSandbox([q("Q1", "Service"), q("valueOf", "Service")]);
  const hit = d2.questionByCode("valueOf");
  assert(hit && hit.code === "valueOf",
         "a real question coded 'valueOf' must come back, got " + JSON.stringify(hit));
  eq(d2.questionByCode("Q1").code, "Q1", "ordinary lookup still works");
  assert(d2.questionByCode("Q404") === null, "a genuinely absent code is null");
});

run("P5 ordinary categories and codes are unchanged", () => {
  const d2 = dataSandbox([
    q("Q1", "Service"), q("Q2", "Value"), q("Q3", "Service"),
  ]);
  const cats = d2.categories();
  eq(cats.map(function (c) { return c.title; }), ["Service", "Value"], "titles");
  eq(cats[0].codes, ["Q1", "Q3"], "Service codes");
  eq(cats[1].codes, ["Q2"], "Value codes");
  eq(d2.questionByCode("Q2").category, "Value", "lookup by code");
});

console.log("\n  " + passed + " passed, " + failed + " failed");
process.exit(failed === 0 ? 0 : 1);
