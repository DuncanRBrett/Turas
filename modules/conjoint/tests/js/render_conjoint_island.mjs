#!/usr/bin/env node
/**
 * Render a Conjoint island through the SHIPPED tab JS and print the HTML.
 *
 * A helper, not a gate. It exists so an R test can prove the seam between the
 * two languages: modules/conjoint/R/17_v2_island.R writes the JSON, this feeds that exact file to
 * 27x_conjoint.js, and the R test asserts on what came out. Both sides have
 * their own tests; only this proves they agree about the shape.
 *
 * Usage:  node modules/conjoint/tests/js/render_conjoint_island.mjs <island.json>
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));  // modules/conjoint/tests/js
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const JS = path.join(ROOT, "modules/tabs/lib/html_report_v2/assets/js");

function makeTarget() {
  const listeners = {};
  return {
    addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
    removeEventListener() {},
    dispatch(type, ev) { (listeners[type] || []).forEach((f) => f(ev || {})); },
  };
}
const elStub = () => ({
  className: "", style: {}, innerHTML: "", textContent: "", children: [],
  appendChild() {}, remove() {}, closest: () => null, addEventListener() {},
  querySelector: () => null, querySelectorAll: () => [],
});
const documentStub = Object.assign(makeTarget(), {
  body: Object.assign(elStub(), { appendChild() {} }),
  createElement: elStub, getElementById: () => null,
  querySelector: () => null, querySelectorAll: () => [],
});
const sandbox = Object.assign(makeTarget(), {
  console, TextEncoder, URL, document: documentStub,
  getSelection: () => ({ isCollapsed: true, rangeCount: 0 }),
});
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const f of readdirSync(JS).filter((x) => x.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(JS, f), "utf8"), sandbox, { filename: f });
}

const file = process.argv[2];
if (!file) { console.error("usage: render_conjoint_island.mjs <island.json>"); process.exit(2); }
sandbox.TR.CJ = JSON.parse(readFileSync(file, "utf8"));
const host = { innerHTML: "" };
sandbox.TR.conjoint.render(host);
process.stdout.write(host.innerHTML);
