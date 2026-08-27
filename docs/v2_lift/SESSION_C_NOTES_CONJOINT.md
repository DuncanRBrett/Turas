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
| Simulator extracted to standalone | **NOT DONE** |
| Conjoint's classic report deleted | **NOT DONE** — blocked on the simulator extraction |

**Suites:** tabs 0 fail / 1 skip / 5144 pass; conjoint 0 / 0 / 1133;
shared 0 / 1 / 903.

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

## What remains for a complete module

1. **Extract the simulator to a standalone HTML tool.** It is currently
   embedded in the classic report, so "delete the classic report" and "keep the
   simulator" conflict until it is pulled out. The JS engine, UI and charts are
   already self-contained; the island carries no per-respondent betas.
2. **Delete `modules/conjoint/lib/html_report/`**, following the loud-retirement
   pattern of `2fdcb38f`: retire `generate_html_report` and
   `generate_html_simulator` through `CONJOINT_RETIRED_SETTINGS` so live configs
   are answered rather than ignored. Expect it to take `test_html_report.R`,
   `test_html_simulator.R` and parts of A2's GUI plumbing with it.
3. Documentation for the island and the Conjoint tab in the user manual.
