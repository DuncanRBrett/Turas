// Shared test access to the report's authored text.
//
// The prose in the v2 report is authored in the shared callout registry and
// edited in the Callout Editor, so NO TEST MAY ASSERT ON ITS WORDING — the
// author is entitled to change any sentence without turning the suite red.
// Tests assert either on the catalogue value (via TXT below) or on the
// data-txt-key attribute the renderer tags each authored block with.
//
// The catalogue-mutation check (tools/mutate_text.mjs) exists to enforce that:
// it reruns the suite with every value replaced, and anything still pinned to
// real wording fails there.
//
// installText(sandbox) loads 02_text.js into a vm sandbox and installs the real
// catalogue, so a booted module renders the same words a real report would.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const REGISTRY = path.join(HERE, "..", "..", "..", "..", "shared", "lib",
                           "callouts", "callouts.json");

/**
 * key -> authored text, exactly as a report build would inline it.
 *
 * Under TURAS_TEXT_MUTATE the words are replaced with a per-key marker that
 * keeps every placeholder intact (so substitution still exercises) but shares
 * no phrase with the real text. That is how mutate_text_check.mjs proves no
 * test is pinned to wording the author owns.
 */
export const MUTATED = process.env.TURAS_TEXT_MUTATE === "1";

export const CATALOGUE = (() => {
  const reg = JSON.parse(readFileSync(REGISTRY, "utf8"));
  const tabs = reg.tabs || {};
  const out = {};
  Object.keys(tabs).forEach((k) => {
    const real = tabs[k].text || "";
    if (!MUTATED || !real) { out[k] = real; return; }
    const tokens = (real.match(/\{[a-z][a-z0-9_]*\}/g) || []).join(" ");
    out[k] = ("MUTATED_TEXT_" + k.replace(/[^a-z0-9]+/gi, "_") +
              (tokens ? " " + tokens : "")).trim();
  });
  return out;
})();

/**
 * The authored text for a key, with placeholders filled — what the renderer
 * should have produced. Throws on an unknown key so a renamed entry fails
 * loudly here rather than quietly matching "" against anything.
 */
export function TXT(key, vars) {
  if (!(key in CATALOGUE)) throw new Error("no such text key: " + key);
  return String(CATALOGUE[key]).replace(/\{([a-z][a-z0-9_]*)\}/g, (whole, name) =>
    (vars && Object.prototype.hasOwnProperty.call(vars, name)) ? String(vars[name]) : whole);
}

/** Load 02_text.js into a prepared sandbox and install the real catalogue. */
export function installText(sandbox) {
  vm.runInContext(readFileSync(path.join(JS_DIR, "02_text.js"), "utf8"),
                  sandbox, { filename: "02_text.js" });
  sandbox.TR.txt.load(CATALOGUE);
  return sandbox.TR;
}
