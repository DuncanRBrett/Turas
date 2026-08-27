# Conjoint Session C — implementation notes

Branch: `feature/conjoint-v2-report`, off `feature/conjoint-correctness` with
`feature/opus0-socket-consolidation` merged in — so the branch encodes its own
dependencies. **Not merged. Built on an unreviewed OPUS-0**, which Duncan
accepted when he asked for the work to be finished; the Fable reviews should be
taken in order (Session A and OPUS-0 first, they are the parents, then this
delta).

---

## The premise that had to be superseded

Both the V2 migration plan (§4) and the conjoint review (§6) specify new row
kinds — `cj_utility`, `cj_importance`, `cj_fit` — added to
`build_dl_question()` / `classify_row_labels()` (R) and `forQuestion()` /
`d2.validate()` (JS).

**That premise does not hold, and this session took the other route.** Read
this session: `build_dl_question()` and `classify_row_labels()` serialise
*crosstabs* — rows keyed by `(RowLabel, RowSource)`, `pct[]` / `n[]` / `sig[]`
arrays indexed by banner column, `bases[]` carrying `n` / `nWeighted` / `nEff`,
and a classification into option / NET / base / mean. A part-worth utility has
no banner, no base and no percentage. Putting one through that socket means
inventing all three.

This is not a new discovery so much as an unapplied one. The keydriver,
catdriver and segment reviews — all written 2026-07-11, the same day as
conjoint's — each independently falsified the same premise for their own module
and converged on **a frozen island plus the module's own view, zero new row
kinds**. The programme tracker already records the plan's per-module premises
failing contact with code four times over. Conjoint's §4 is the fifth instance
of the same vintage assumption; nobody re-checked it after the others fell.

**Route taken:** a frozen `data-cj` island + `27x_conjoint.js` view + a
Conjoint tab. Zero new row kinds.

---

## The other thing that changed under the plan

The classic **tabs** report was retired on 2026-08-05 (`2fdcb38f`) — 14 R files,
9 JS files, ~14,000 lines, deleted outright. The conjoint handover was written
2026-07-12, three weeks earlier, and its Session B scopes P1-P8 bug fixes to
conjoint's own `lib/html_report/`, which is the same generation of architecture
(`00_html_guard.R`, `01_data_transformer.R`, `02_table_builder.R`,
`03_page_builder.R`, chart builder, `99_main`).

The migration plan already says what follows: "**Migrate a module = make it emit
V2 data islands, NOT port its HTML report. The classic per-module HTML reports
are throwaway**" (§2). So Session B's report half is largely obsolete — repairs
to something scheduled for deletion. It was not done, deliberately. What
carried forward from it was P5 (island hardening, which became OPUS-0 W3) and
B2 (the tabs exporter, which is not report work at all).

---

## What landed

| Piece | State |
|---|---|
| Tabs importance export (B2) | done — `modules/conjoint/R/16_tabs_export.R`, 54 tests incl. an integration proof through tabs' own Allocation processor |
| Conjoint island (R) | done — `modules/conjoint/R/17_v2_island.R` |
| `data-cj` island + `cj_json` parameter | done — template, `build_report_v2.R`, `run_crosstabs.R`, config whitelist, tabs template |
| `27x_conjoint.js` view + Conjoint tab | done — 19 + 11 tests, browser-verified |
| Simulator extracted to standalone | done — `lib/html_simulator/`, 90 KB self-contained, browser-verified |
| Conjoint's classic report deleted | done — `lib/html_report/` removed entire, 7 R + 7 JS files |

**Suites:** tabs 0 fail / 1 skip / 5144 pass; conjoint 0 / 0 / 971
(down from 1133 because `test_html_report.R` and `test_html_simulator.R` went
with what they tested); shared 0 / 1 / 903.

---

## The review's open item, settled

The review asked (§6, "chase before Phase 4") whether the live simulator JS
consumes the embedded individual betas, since the methods page claims
aggregate-only (`03_page_builder.R:1177`).

**It does not, and they were never embedded.** Checked this session: no JS file
under `lib/html_report/js/` references individual betas at all, and
`01_data_transformer.R:216-220` sets only `individual = list(has_data = TRUE)`,
with a comment saying the betas are omitted for file size. The §6 file-size
hazard (`n × params` betas in the island) was about the **dead**
`lib/html_simulator/` twin, not the live path. The methods page's claim is
accurate.

Consequence: the extracted standalone simulator carries no beta payload, and
the extraction is smaller than the review anticipated.

---

## Findings

### A baseline level was printing a zero-width confidence interval
Found by rendering the tab, not by reading the diff. `extract_hb_utilities`
stores a baseline's `CI_Lower` and `CI_Upper` equal to its own utility, which
displayed as "1.41 to 1.41" — an interval of zero width, which reads like an
impossibly precise estimate rather than the absence of one. The view now shows
em-dashes for a baseline's SE, interval and heterogeneity. The underlying table
is unchanged; this is a display decision, and the Excel deliverable shows the
same rows.

---

## The retirement

`modules/conjoint/lib/html_report/` is gone — 7 R files, 7 JS files. The
simulator was extracted first, whole, into `lib/html_simulator/`: the CSS
builder, the panel markup, the data transformer and the JSON island, unchanged
in behaviour, plus the same three JS files. What did not come across is the
report around them — no pins, no insight editor, no tab shell. 90 KB,
self-contained, verified in a browser computing shares.

Retired loudly, following `2fdcb38f`: `generate_html_report` is in
`CONJOINT_RETIRED_SETTINGS`, so a live config carrying it is answered by name
rather than told it looks like a typo. `generate_html_simulator` stays live and
now writes `{output}_simulator.html`; the island carries its filename so the
Conjoint tab links to it.

**One deliberate imprecision, logged:** the simulator ships the retired report's
whole stylesheet, including rules for elements it never renders. Trimming it
means deciding, rule by rule, what the simulator's runtime-generated markup
needs, and getting that wrong shows up as a broken layout in a client's hands.
90 KB total; the risk is not worth the kilobytes. Noted in
`01_simulator_parts.R`.

## What a complete module now produces

| Deliverable | Setting |
|---|---|
| Excel workbook | always |
| Stats pack | `generate_stats_pack` (default Y) |
| Conjoint tab in the interactive report | always writes `{output}_cj_island.json`; the tabs config's `conjoint_island` points at it |
| Crosstabbable attribute importance | `generate_tabs_export` |
| Standalone market simulator | `generate_html_simulator` |
