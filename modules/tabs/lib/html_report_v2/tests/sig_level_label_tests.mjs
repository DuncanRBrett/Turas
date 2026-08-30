#!/usr/bin/env node
/**
 * SIGNIFICANCE LEVEL LABELLING — the report must call the level it tested at.
 *
 * Defect 2026-08-30: alpha_secondary became configurable, but the prose that
 * describes it did not follow. The engines (R and the in-browser recompute)
 * honoured alpha_secondary correctly; the HTML report told the reader the
 * lowercase letters meant 80% whatever the config said. ASSA "Unlocking the
 * Annuity Puzzle" runs at alpha_secondary = 0.1 — its letters were computed at
 * 90% and labelled 80%. The Excel crosstab labelled the same letters "Sig.
 * (90%)" correctly, so the two deliverables disagreed in wording only.
 *
 * WHAT THIS SUITE GUARDS
 *   L1  TR.stats level wording derives from the configured alphas, including
 *       the odds form ("one in 20"), and falls back to 0.05 / 0.20.
 *   L2  Every authored sentence about significance takes its levels as tokens,
 *       and the manifest declares them (the R build refuses otherwise).
 *   L3  The rendered surfaces — legend, crosstab footer, the three mode
 *       selectors, the tracking summary — say the configured level and nothing
 *       else. On a 0.1 project that means "90%" and NO user-visible "80%".
 *   L4  THE NO-OP GUARANTEE. On alpha_secondary = 0.2, and on a config that
 *       sets it at all, every one of those surfaces still reads exactly "80%".
 *       CCPB, VAS and SACS are 0.2-or-unset projects: if this section goes red,
 *       the fix has changed what a live report displays.
 *   L5  Option VALUES ("95" / "dual") are persisted state and must NOT move
 *       with the wording, or saved copies lose their setting.
 *
 * Confidence INTERVALS are a separate, deliberately fixed 95% convention
 * (21c_confidence.js, Z95_EXACT) and are out of scope here — a "95% SI" string
 * is correct at any alpha.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/sig_level_label_tests.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { CATALOGUE } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const MANIFEST = JSON.parse(
  readFileSync(path.join(HERE, "..", "assets", "text_manifest.json"), "utf8"));

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); console.log("  ✓ " + name); passed++; }
  catch (e) { console.log("  ✗ " + name + "\n    " + e.message); failed++; }
}
function assert(c, m) { if (!c) throw new Error(m); }
function eq(a, b, m) {
  if (a !== b) throw new Error(m + ": expected " + JSON.stringify(b) +
                              ", got " + JSON.stringify(a));
}

/** The keys whose authored text describes a significance LEVEL. */
const LEVEL_KEYS = [
  "reader.legend.sig_letters",
  "reader.legend.arrows",
  "tracking.heatmap.legend",
  "tracking.heatmap.soft_clause",
  "tracking.soft.intro",
  "visualise.legend.significance",
  "diffs.intro",
  "cards.sig.explainer",
  "cards.reading.list"
];

/** A sandbox carrying the real 02_text + 21_stats over a given project. */
function statsBox(project, extraFiles) {
  const box = { console };
  box.globalThis = box; box.window = box;
  vm.createContext(box);
  for (const f of ["00_namespace.js", "01_format.js", "02_text.js", "21_stats.js"]
       .concat(extraFiles || [])) {
    vm.runInContext(readFileSync(path.join(JS_DIR, f), "utf8"), box, { filename: f });
  }
  box.TR.txt.load(CATALOGUE);
  box.TR.AGG = { project: project, questions: [], banner_groups: [] };
  return box.TR;
}

/* ==========================================================================
   L1. The wording comes from the configured alphas
   ========================================================================== */
console.log("L1 — level wording derives from the config:");

run("levelText turns an alpha into the words a reader sees", () => {
  const S = statsBox({}).stats;
  eq(S.levelText(0.05), "95%", "0.05");
  eq(S.levelText(0.10), "90%", "0.10");
  eq(S.levelText(0.20), "80%", "0.20");
  eq(S.levelText(0.01), "99%", "0.01");
});

run("levelOdds turns it into the odds form the explainer needs", () => {
  const S = statsBox({}).stats;
  eq(S.levelOdds(0.05), "20", "one in 20");
  eq(S.levelOdds(0.20), "5", "one in 5");
  eq(S.levelOdds(0.10), "10", "one in 10");
});

run("ASSA's config (alpha_secondary = 0.1) words the secondary level as 90%", () => {
  const S = statsBox({ alpha: 0.05, alpha_secondary: 0.1 }).stats;
  eq(S.levelPrimary(), "95%", "primary");
  eq(S.levelSecondary(), "90%", "secondary — the level the engine actually tests at");
  eq(S.oddsSecondary(), "10", "and the odds move with it");
});

run("the 0.2 projects (CCPB / VAS / SACS) still word it 80%", () => {
  const S = statsBox({ alpha: 0.05, alpha_secondary: 0.2 }).stats;
  eq(S.levelPrimary(), "95%", "primary");
  eq(S.levelSecondary(), "80%", "secondary");
});

run("a config with no alphas falls back to the 0.05 / 0.20 convention", () => {
  const S = statsBox({}).stats;
  eq(S.levelPrimary(), "95%", "primary default");
  eq(S.levelSecondary(), "80%", "secondary default");
  eq(S.oddsPrimary(), "20", "odds default");
});

run("a nonsense alpha_secondary falls back rather than printing nonsense", () => {
  // Mirrors projAlpha2's guard: it must exceed the primary level and be < 1.
  eq(statsBox({ alpha_secondary: 0.01 }).stats.levelSecondary(), "80%",
     "below the primary level → default");
  eq(statsBox({ alpha_secondary: "NA" }).stats.levelSecondary(), "80%",
     "the config loader's 'NA' string → default");
});

run("levelVars supplies all four tokens together, never half of them", () => {
  const v = statsBox({ alpha: 0.05, alpha_secondary: 0.1 }).stats.levelVars();
  eq(Object.keys(v).sort().join(","),
     "alpha2_odds,alpha2_pct,alpha_odds,alpha_pct", "the four token names");
  eq(v.alpha_pct, "95%", "alpha_pct");
  eq(v.alpha2_pct, "90%", "alpha2_pct");
  eq(v.alpha_odds, "20", "alpha_odds");
  eq(v.alpha2_odds, "10", "alpha2_odds");
});

/* ==========================================================================
   L2. The authored text is tokenised and the manifest declares the tokens
   ========================================================================== */
console.log("\nL2 — authored text carries tokens, not typed numbers:");

run("no significance callout hard-codes a level", () => {
  // The real catalogue, not the mutated one — this asserts the SHAPE of the
  // authored text (no bare percentage), never its wording.
  const reg = JSON.parse(readFileSync(
    path.join(HERE, "..", "..", "..", "..", "shared", "lib", "callouts",
              "callouts.json"), "utf8")).tabs;
  for (const k of LEVEL_KEYS) {
    const t = reg[k].text;
    assert(!/\b(80|90|95|99)%/.test(t),
           k + " types a level instead of taking {alpha_pct}/{alpha2_pct}: " +
           (t.match(/.{0,40}\b(?:80|90|95|99)%.{0,40}/) || [""])[0]);
  }
});

run("every alpha token used is declared in text_manifest.json", () => {
  // report_text.R REFUSES the build on an undeclared token, so an author who
  // adds {alpha2_pct} to a tenth entry would break the report, not this test —
  // but catching it here names the file to fix.
  const reg = JSON.parse(readFileSync(
    path.join(HERE, "..", "..", "..", "..", "shared", "lib", "callouts",
              "callouts.json"), "utf8")).tabs;
  for (const k of Object.keys(reg)) {
    if (!MANIFEST[k]) continue;
    const used = (String(reg[k].text || "").match(/\{(alpha2?_(?:pct|odds))\}/g) || [])
      .map((x) => x.slice(1, -1));
    const declared = MANIFEST[k].tokens || [];
    for (const t of new Set(used)) {
      assert(declared.indexOf(t) !== -1,
             k + ' uses {' + t + '} but text_manifest.json does not declare it');
    }
  }
});

run("the explainer takes the odds form too, so 'one in 5' cannot outlive 80%", () => {
  const reg = JSON.parse(readFileSync(
    path.join(HERE, "..", "..", "..", "..", "shared", "lib", "callouts",
              "callouts.json"), "utf8")).tabs;
  const t = reg["cards.sig.explainer"].text;
  assert(t.indexOf("{alpha_odds}") !== -1, "primary odds tokenised");
  assert(t.indexOf("{alpha2_odds}") !== -1, "secondary odds tokenised");
  assert(!/one in \d/.test(t), "no typed odds left behind");
});

run("substituting the ASSA levels puts 90% into every sentence that names one", () => {
  const TR = statsBox({ alpha: 0.05, alpha_secondary: 0.1 });
  const v = TR.stats.levelVars();
  for (const k of LEVEL_KEYS) {
    const out = TR.txt(k, v);
    assert(out.indexOf("{alpha") === -1, k + " left a token unsubstituted: " + out);
    assert(out.indexOf("80%") === -1, k + " still says 80% on a 90% project");
  }
  // The nine between them must actually name the secondary level somewhere.
  const all = LEVEL_KEYS.map((k) => TR.txt(k, v)).join(" ");
  assert(all.indexOf("90%") !== -1, "the secondary level is named");
  assert(all.indexOf("95%") !== -1, "and so is the primary");
});

/* ==========================================================================
   L3 / L4. The rendered surfaces
   ========================================================================== */

/** Every level-bearing surface this suite can render, as one string. */
function surfaces(project) {
  const TR = statsBox(project,
    ["20_data.js", "26_filter.js", "24a_reader.js", "25_cards.js",
     "27_views.js", "27d_diffs.js", "27u_summary.js"]);
  TR.charts = { clip: (s, n) => String(s).slice(0, n) };
  TR.d2 = {
    state: { tab: "crosstabs", banner: "", filters: [], sigMode: "dual",
             heatmap: "bars" },
    rowScope: () => "all",
    storeKey: (b) => b + ":proj",
    hasMicrodata: () => false,
    filterDescription: () => "",
    bannerDescription: () => ""
  };
  TR.stats.mask = () => [1, 1];
  TR.stats.maskCount = (m) => m.reduce((a, b) => a + b, 0);
  TR.MICRO = { n: 2, answers: {} };
  TR.disclosure = { audienceBase: () => 2 };
  TR.conf = {
    labels: () => ({ moe_name: "Precision Estimate", moe_abbrev: "PE",
                     interval_abbrev: "SI", interval_name: "stability interval" }),
    maxMoePct: (n) => 98 / Math.sqrt(n),
    calloutHtml: () => ""
  };
  TR.views = TR.views || {};

  // The tracking summary renders through its own entry point over a DOM-free
  // host, the way tracking_nav_tests drives it.
  const M = { key: "Q1::1", code: "Q1", title: "A metric", label: "Index",
              isMean: true, diff: false };
  TR.waves = { segments: () => [] };
  TR.trk = {
    state: {},
    publishedModel: () => ({ prevWave: { wave: "2025" } }),
    metricList: () => [M],
    metricByKey: () => null,
    points: () => [{ year: 2025, value: 10, base: 100, change_prev: null },
                   { year: 2026, value: 12, base: 100, change_prev: 2,
                     sig_prev: false, soft_prev: true, tested_prev: true }],
    kpiType: () => "mean", band: () => "mid",
    fmtVal: (v) => String(v), yLabel: (y) => String(y),
    changeText: (c) => String(c), metricShort: (m) => m.title,
    sdAt: () => null
  };
  const host = { innerHTML: "", querySelectorAll: () => [], querySelector: () => null };
  TR.trkSummary.render(host);

  return {
    // The crosstab footer panels are the only surface that also carries the
    // ODDS form ("one in 20"), so they are kept separate: a bare 5 or 10 cannot
    // be swapped safely in a byte-comparison.
    explainers: TR.cards2._explainersHtml(),
    rest: [
      TR.reader.legendHtml(),
      TR.cards2._sigModeSelectHtml("dual"),
      TR.views._diffSigOptions(true),
      TR.views._diffLineHtml({
        soft: true, column: "Male", isMean: false, direction: "ahead",
        beaten: ["Female"], value: 60, rest: 40, overall: 50, gap: 20,
        row: "Yes", question: "Q1", title: "A question", code: "Q1", cells: []
      }),
      host.innerHTML,
      TR.txt("tracking.heatmap.soft_clause", TR.stats.levelVars())
    ].join("\n\n")
  };
}

/** Every surface as one string. */
function allSurfaces(project) {
  const s = surfaces(project);
  return s.explainers + "\n\n" + s.rest;
}

console.log("\nL3 — an alpha_secondary = 0.1 report (ASSA) never says 80%:");

run("every rendered surface names 90%, and none of them says 80%", () => {
  const html = allSurfaces({ alpha: 0.05, alpha_secondary: 0.1,
                             low_base_threshold: 30, wave: "2026" });
  assert(html.indexOf("90%") !== -1, "the configured secondary level is shown");
  const stray = html.match(/.{0,60}80%.{0,60}/);
  assert(stray === null, "no surface still says 80%: " + (stray || [""])[0]);
  assert(html.indexOf("{alpha") === -1, "no token shipped unsubstituted");
});

console.log("\nL4 — the no-op guarantee for CCPB / VAS / SACS:");

run("alpha_secondary = 0.2 still reads 80% everywhere", () => {
  const html = allSurfaces({ alpha: 0.05, alpha_secondary: 0.2,
                             low_base_threshold: 30, wave: "2026" });
  assert(html.indexOf("80%") !== -1, "the 80% wording is unchanged");
  assert(html.indexOf("90%") === -1, "and nothing has drifted to 90%");
  assert(html.indexOf("{alpha") === -1, "no token shipped unsubstituted");
});

run("a config with no alpha_secondary behaves exactly as before", () => {
  const html = allSurfaces({ low_base_threshold: 30, wave: "2026" });
  assert(html.indexOf("80%") !== -1, "the default secondary level still reads 80%");
  assert(html.indexOf("95%") !== -1, "and the primary still reads 95%");
  assert(html.indexOf("{alpha") === -1, "no token shipped unsubstituted");
});

run("the two configs differ ONLY where a level is named", () => {
  // Byte-for-byte apart from the level words: proof the change is cosmetic and
  // scoped, not a rewrite of the surfaces.
  const unset = allSurfaces({ low_base_threshold: 30, wave: "2026" });
  const two = allSurfaces({ alpha: 0.05, alpha_secondary: 0.2,
                            low_base_threshold: 30, wave: "2026" });
  eq(two, unset, "0.2 and unset render identically");
  // The percentage-bearing surfaces normalise cleanly; the explainer also
  // carries the odds form, checked on its own below.
  const tenRest = surfaces({ alpha: 0.05, alpha_secondary: 0.1,
                             low_base_threshold: 30, wave: "2026" }).rest;
  eq(tenRest.split("90%").join("80%"),
     surfaces({ low_base_threshold: 30, wave: "2026" }).rest,
     "and 0.1 differs only in the level words");
});

run("the explainer's odds move with the level, not just the percentage", () => {
  // "At 90% it is less than one in 10", never "... one in 5". Anchored on the
  // literal the AUTHOR wrote immediately before {alpha2_odds}, whatever that
  // is, so this asserts the substitution and not the sentence.
  // From the SAME catalogue the render uses, so this holds under the mutation
  // check too (mutate_text_check.mjs keeps every token in place).
  const raw = CATALOGUE["cards.sig.explainer"];
  const at2 = raw.indexOf("{alpha2_odds}");
  assert(at2 !== -1, "{alpha2_odds} is in the authored text");
  // The author's own lead-in, back to the previous token so the anchor is
  // literal text and nothing that itself gets substituted.
  const before = raw.slice(0, at2);
  const lead = before.slice(Math.max(before.lastIndexOf("}") + 1,
                                     before.length - 10));
  assert(lead.length > 0, "there is literal text before the odds token");
  const ten = surfaces({ alpha: 0.05, alpha_secondary: 0.1,
                         low_base_threshold: 30, wave: "2026" }).explainers;
  const dflt = surfaces({ low_base_threshold: 30, wave: "2026" }).explainers;
  assert(ten.indexOf(lead + "10") !== -1,
         "a 0.1 project states odds of 10 where {alpha2_odds} sits");
  assert(ten.indexOf(lead + "5") === -1,
         "and never the default's odds of 5");
  assert(dflt.indexOf(lead + "5") !== -1,
         "while a default project still states odds of 5 — the no-op guarantee");
});

/* ==========================================================================
   L5. Persisted state must not move with the wording
   ========================================================================== */
console.log("\nL5 — the option VALUES are state, not wording:");

run("the crosstab and Differences selectors keep value=\"95\" / \"dual\"", () => {
  const TR = statsBox({ alpha: 0.05, alpha_secondary: 0.1 },
                      ["20_data.js", "25_cards.js", "27_views.js", "27d_diffs.js"]);
  for (const html of [TR.cards2._sigModeSelectHtml("dual"),
                      TR.views._diffSigOptions(true)]) {
    assert(/value="95"/.test(html), 'value="95" survives a 90% project');
    assert(/value="dual"/.test(html), 'value="dual" survives a 90% project');
    assert(/>95%</.test(html), "and the primary level is what the reader reads");
    assert(/90%/.test(html), "as is the configured secondary level");
  }
});

/* ==========================================================================
   L6. No renderer may type a significance level again
   ========================================================================== */
console.log("\nL6 — the source itself carries no typed significance level:");

// Confidence INTERVALS are a separate, deliberately fixed 95% convention
// (21c_confidence.js, Z95_EXACT): those strings are correct at any alpha and
// are listed here so the scan below can fail closed on everything else. Each
// entry is the exact source fragment that is allowed to say 95%.
const CI_ALLOWED = [
  '"Show the 95% interval as a range below each number"',
  'if (kind === "means") return "95% " + abbrev + " (z\u00b7SD/\u221an)";',
  'return "95% " + abbrev + " (Wilson; means z\u00b7SD/\u221an)";',
  'return "95% " + abbrev + " (Wilson)";',
  '? \'<div class="civ" title="Worst-case 95% \' +',
  'body += \'<div class="civ" title="95% \' + ivLabels.interval_name +',
  'return " \u00b7 95% " + TR.conf.labels().interval_abbrev + " " +',
  'return \'<p class="moechip" title="Worst-case 95% \' +',
  'parts.push("95% " + (rel.sigNote || "confidence"));',
  '? " \u2014 95% " + TR.conf.labels().interval_abbrev + " " +',
  '"> 95% " + TR.conf.labels().interval_abbrev + " bands</label>" +',
  'rows.push([sr.label + " \u00b7 95% " + abbrev + " lo"].concat(boundRow("lo")));',
  'rows.push([sr.label + " \u00b7 95% " + abbrev + " hi"].concat(boundRow("hi")));',
  '\'<th class="cj-num">95% CI</th>\' +',
  // The two defensive fallbacks in the reader, used only when TR.stats is
  // absent — they reproduce the platform defaults, they do not assert a level.
  'return TR.stats && TR.stats.levelPrimary ? TR.stats.levelPrimary() : "95%";',
  'return TR.stats && TR.stats.levelSecondary ? TR.stats.levelSecondary() : "80%";',
  'var hi = S && S.levelPrimary ? S.levelPrimary() : "95%";',
  'var lo = S && S.levelSecondary ? S.levelSecondary() : "80%";'
];

run("no JS module types a level outside the confidence-interval convention", () => {
  const files = readdirSync(JS_DIR).filter((f) => f.endsWith(".js")).sort();
  const offenders = [];
  for (const f of files) {
    const lines = readFileSync(path.join(JS_DIR, f), "utf8").split("\n");
    lines.forEach((line, i) => {
      const t = line.trim();
      if (t.startsWith("//") || t.startsWith("*") || t.startsWith("/*")) return;
      // A trailing // comment is prose about the code, not something a reader
      // ever sees — cut it before looking for a typed level.
      const code = line.split("//")[0];
      if (!/\b(?:80|90|95|99)%/.test(code)) return;
      if (CI_ALLOWED.some((ok) => line.indexOf(ok) !== -1)) return;
      offenders.push(f + ":" + (i + 1) + "  " + t);
    });
  }
  assert(offenders.length === 0,
         "a level is typed into the renderer instead of read from TR.stats:\n    " +
         offenders.join("\n    "));
});

run("the sig-letter tooltip names the level the letters were tested at", () => {
  const TR = statsBox({ alpha: 0.05, alpha_secondary: 0.1 });
  assert(/at 95% confidence/.test(TR.fmt.sigSup("B")), "uppercase = primary");
  assert(/at 90% confidence/.test(TR.fmt.sigSup("b")), "lowercase = secondary");
  const both = TR.fmt.sigSup("Bc");
  assert(/95% \(uppercase\)/.test(both) && /90% \(lowercase\)/.test(both),
         "a mixed string names both levels: " + both);
  eq(TR.fmt.sigSup(""), "", "nothing in, nothing out");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
