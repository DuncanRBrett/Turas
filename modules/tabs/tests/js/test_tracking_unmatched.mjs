#!/usr/bin/env node
/**
 * Gate: the Tracking Summary must never render an UNMATCHED tracker as zeros.
 *
 * The cross-wave key changes shape with the R-side config — the canonical
 * question code when a Question_Mapping is loaded, the normalised title when
 * one is not (tracking_island.R: tracking_metrics). History built under one
 * regime and a wave built under the other can never pair, and every metric then
 * has no previous value. Left alone the pulse bar renders "0 significant
 * increases · 0 significant decreases · 0 stable", which a reader takes as
 * "nothing moved this wave" when the truth is "nothing was compared". That is
 * the CCPB W2026 failure, and it is the one this gate reproduces.
 *
 * Runs against the SHIPPED module JS (modules/tabs/lib/html_report_v2/assets/js)
 * — not the prototype copy, which has drifted behind it.
 *
 * Run with:  node modules/tabs/tests/js/test_tracking_unmatched.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { installText, TXT, blockOf }
  from "../../lib/html_report_v2/tests/_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const JS = path.join(ROOT, "modules/tabs/lib/html_report_v2/assets/js");
const DATA = path.join(ROOT, "prototypes/report-redesign/fable/v2/data");

function makeEl() {
  return {
    _html: "",
    set innerHTML(v) { this._html = v; },
    get innerHTML() { return this._html; },
    addEventListener() {}, appendChild() {}, replaceChildren() {},
    classList: { toggle() {}, add() {}, remove() {} },
    closest() { return { classList: { toggle() {} } }; },
    getAttribute() { return null; },
    querySelector() { return null; }, querySelectorAll() { return []; },
  };
}

/** A fresh sandbox per scenario — TR caches metric lists and wave indexes. */
function load(prev) {
  const sandbox = {
    console, TextEncoder, URL,
    document: { createElement: makeEl, getElementById: makeEl, addEventListener() {} },
  };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  for (const f of readdirSync(JS).filter((x) => x.endsWith(".js")).sort()) {
    vm.runInContext(readFileSync(path.join(JS, f), "utf8"), sandbox, { filename: f });
  }
  // The card's explanatory prose is AUTHORED text, inlined into a real report
  // from the callout registry at build time. Booting the module JS alone leaves
  // TR.txt with an empty catalogue, so every authored block renders as nothing —
  // which is not what a reader sees, and made this suite assert against a card
  // stripped of the two sentences that give it its point.
  installText(sandbox);
  const TR = sandbox.TR;
  TR.AGG = JSON.parse(readFileSync(path.join(DATA, "sacap_2025.json"), "utf8"));
  TR.MICRO = JSON.parse(readFileSync(path.join(DATA, "sacap_microdata.json"), "utf8"));
  TR.PREV = prev;
  TR.VERIFY = {};
  TR.userState = null;
  TR.d2.state = TR.d2.state || {};
  TR.d2.state.sigMode = "95";
  TR.d2.state.banner = TR.AGG.banner_groups.length ? TR.AGG.banner_groups[0].id : "";
  TR.render.currentYear = TR.render.currentYear || function () { return 2025; };
  return TR;
}

function render(TR) {
  const host = makeEl();
  TR.trkSummary.render(host);
  return host._html;
}

const waves = () => JSON.parse(readFileSync(path.join(DATA, "sacap_waves.json"), "utf8"));

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log("  ✓ " + m); } else { fail++; console.log("  ✗ " + m); } };

// ---- 1. history that DOES pair still renders the scorecard ----
const good = load(waves());
const hGood = render(good);
ok(good.trkSummary.unmatchedHistory() === null, "matched history: not flagged as unmatched");
ok(/Key metric scorecard/.test(hGood), "matched history: scorecard renders");
ok(/significant increases/.test(hGood), "matched history: pulse bar renders");

// ---- 2. history keyed by code against a wave keyed by title: the CCPB case ----
const broken = waves();
broken.waves.forEach((w, wi) => {
  (w.questions || []).forEach((q, qi) => {
    q.match_key = "q" + String(wi) + "_" + String(qi);   // code-shaped, unmatchable
    delete q.title_norm;
  });
});
const bad = load(broken);
const info = bad.trkSummary.unmatchedHistory();
const hBad = render(bad);

ok(info !== null, "unmatched history: detected");
ok(info && info.priors === broken.waves.filter((w) => !w.current).length,
  "unmatched history: counts every prior wave");
ok(/Tracking could not be compared/.test(hBad), "unmatched history: says it could not compare");
ok(!/significant increases/.test(hBad), "unmatched history: the 0/0/0 pulse bar is NOT rendered");
ok(!/Key metric scorecard/.test(hBad), "unmatched history: the empty scorecard is NOT rendered");
// The two sentences that carry the card's point — one saying this is a
// configuration problem rather than a finding, one naming the setting that
// fixes it. The author owns those words (see _text.mjs), so the test compares
// the rendered block against the catalogue rather than against a phrase: it
// stays true when the sentence is rewritten, and fails the moment the block
// goes missing, renders empty, or leaves a placeholder unsubstituted.
const flat = (t) => t.replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim();
const nPriors = broken.waves.filter((w) => !w.current).length;
const labels = broken.waves.filter((w) => !w.current).map((w) => String(w.wave));
const span = labels.length > 1 ? labels[0] + "\u2013" + labels[labels.length - 1] : labels[0];

const lead = blockOf(hBad, "tracking.unmatched.lead");
ok(lead !== "" && !/\{[a-z_]+\}/.test(lead) &&
   flat(lead) === flat(TXT("tracking.unmatched.lead",
     { priors: nPriors, waves_word: nPriors === 1 ? "wave" : "waves", span: span })),
  "unmatched history: says plainly this is not a result");

const cause = blockOf(hBad, "tracking.unmatched.cause");
ok(cause !== "" && flat(cause) === flat(TXT("tracking.unmatched.cause")),
  "unmatched history: names the config setting that fixes it");

// ---- 3. a first wave (no history at all) is not this state ----
const first = load({ schema_version: 1, waves: [] });
ok(first.trkSummary.unmatchedHistory() === null, "no history at all: not flagged as unmatched");

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
