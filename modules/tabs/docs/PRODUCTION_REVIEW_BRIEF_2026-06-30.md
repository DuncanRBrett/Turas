# Production Review Brief — the integrated v2 reporting system (tabs + tracker)

**For a NEW, INDEPENDENT session (or a fan-out of sessions). Use the `duncan-production-review` skill.**
**Goal: prove the v2 report — which now integrates tabs + tracker and is about to REPLACE the classic
reports — is rock-solid and bug-free *throughout*, then merge `feature/tabs-qualitative-tab` to `main`.**

---

## 0. Why the scope is bigger than the branch

The original pre-merge pass covered only the 42-commit branch delta (the Qualitative subsystem +
disclosure + theme crosstab + tracker Summary-card). Duncan has **widened the mandate**: the v2 report
is replacing the classic reports, so the whole integrated system has to be trustworthy — not just the
newest layer.

Most of that system is **already merged into `main`** (the branch base `0093d7b0` already contains the
Pattern Recognition/Story rebuild, the tracker integration, composite banners, the Differences tab,
FPC, segment-wave-trends, etc.). A `main..HEAD` diff **does not show it**. So this review is a
**whole-system audit**, with the branch delta as its highest-priority (newest, never-reviewed) layer.

Rough size of what's in scope:
- v2 JS report bundle: **~13,900 lines / ~40 modules** (`modules/tabs/lib/html_report_v2/assets/js/`)
- tabs R lib: **~24,800 lines** (`modules/tabs/lib/` + `lib/crosstabs/`)
- tracker R lib: **~14,400 lines** (`modules/tracker/lib/`) — feeds the integrated report
- **~70 test files** (43 tabs testthat, 21 tracker testthat, 6 JS `.mjs` suites, 1 in-browser harness)

This is too large for one linear pass. Work the **areas** below; within each, run the full
production-review process. Treat areas A–C (the unreviewed delta) as the priority and the deepest
dive; treat D–K as "verify the integration + regress the engine," noting where a prior review already
ran (don't redo a clean prior review — confirm it still holds and focus on the seams).

## 1. Independence — read this first

Per Duncan's standing rule ([[feedback_independent_review]]): **you are independent of the sessions
that built this.** Do NOT take build notes / commit messages / memory / this brief's own claims as
evidence anything works — **verify each claim yourself** (read the code, run the tests, trace the
logic). Run the **full** process per area; do not skip phases because the work "looks done" (past
reviews have drifted by skipping required phases). The building sessions believed it was correct —
your job is to find where that belief is wrong. The author's "it's safe" is not evidence; the test
suite passing is necessary but not sufficient (look for what the tests *don't* cover).

## 2. Review areas

### Priority tier — the unreviewed branch delta (deepest dive)

**A. Qualitative subsystem (NEW — the bulk of the branch).**
Ingests pre-coded comment workbooks → themes-as-quant + a verbatim island.
R: `qual_workbook_reader.R`, `qual_workbook_io.R`, `qual_assemble.R`, `qual_island_builder.R`,
`qual_quant_layer.R`, `qual_report.R` (+ wiring in `run_crosstabs.R`, `build_report_v2.R`,
`template.html`). JS: `27q_qualitative.js` (917). Features: ResponseID join into the main report,
closed↔open 💬 jump, shortlist + Excel export, salience reframe, sentiment filter, select-to-highlight,
diverging sentiment chart, theme×banner crosstab.
Be skeptical of: the **additive principle** (a qual failure must NEVER touch the main Crosstabs/Excel —
the `run_crosstabs.R` hook is tryCatch-wrapped; confirm it truly swallows and logs, never propagates);
TRS compliance in the 7 new R files (any `stop()` / silent failure / non-structured return? console
visibility for Shiny — [[feedback_launch_turas_verification]]); the ResponseID join (mismatched/missing/
duplicate IDs, case/whitespace, IDs present in comments but absent in the survey and vice-versa).

**B. Disclosure / re-identification control (NEW — SECURITY-SENSITIVE, the one true merge blocker).**
`21d_disclosure.js` + config `min_reporting_base` (`crosstabs_config.R`, serialized in
`data_layer_writer.R` only when >1 so existing reports stay byte-identical). Below the threshold:
comment demo tags hidden, filter-bar warning, Excel export blanks tags, crosstab columns below k
suppressed. The SACS staff survey (n=167) ships with `min_reporting_base: 10`.
Be skeptical of: **every path identity can leak** — a cut that slips under k but still renders tags;
the Excel/shortlist export; the theme crosstab columns; the closed↔open jump landing on a tiny cut;
a Save/print copy; highlight persistence; a composite filter that narrows to <k. Is the threshold
applied **consistently everywhere**, or only on the paths the author remembered? Is "below k" computed
on the right base (unweighted respondent count, not a weighted/rounded number)? If ANY path leaks
sub-threshold identity, that blocks the merge.

**C. Theme×banner crosstab (NEW).**
Client-side from the joined records. Column base = commenters; salience + net sentiment;
Salience/Sentiment-skew + Counts toggles; vs-the-rest sig via `stats.propZ`; inline insight + pin.
Be skeptical of: the salience/net/sig math and the **column-base vs mentioner-base** toggle —
hand-check against `qual_quant_layer.R` and a small fixture; the sig denominator under vs-the-rest;
interaction with disclosure (Area B) when a column falls below k.

### Integrated system now in scope (verify integration + regress the engine)

**D. The data bridge: R analysis → JS model (the spine — if this is wrong, every tab is wrong).**
`data_layer_writer.R` (894), `microdata_writer.R` (489), `20_data.js` (315), `22_model.js` (572).
Everything downstream trusts this contract. Known gotchas to probe: the config loader stringifies
empty cells to the literal `"NA"`; `NET POSITIVE` OptionText handling; weighted vs unweighted bases
crossing the boundary; how empty/zero/suppressed cells serialize. Confirm the in-browser `#selftest`
(`31_selftest.js`) golden spot-checks still match the published tables.

**E. Crosstab statistical engine (highest correctness stakes — the actual numbers).**
`cell_calculator.R` (742), `standard_processor.R` (1388), `numeric_processor.R` (600),
`composite_processor.R` (830), `ranking.R` (1014), `banner_indices.R` (556), `banner.R` (605),
`weighting.R` (1608); JS `21_stats.js` (429), `21c_confidence.js` (384). Significance (95/80 dual),
weighting (Kish n_eff), finite population correction, NPS, indices, means, base-zero handling.
Cross-check the JS stats against the R engine on a shared fixture — the report recomputes on filter, so
both engines must agree. Suites: `test_dual_significance`, `test_calculations`, `test_numeric_processor`,
`test_composite_processor`, `test_ranking_processor`, `test_banner`, `test_standard_processor`,
`test_numeric_base_zero`. Prior FPC work was committed but may not be independently reviewed — verify.

**F. Pattern Recognition / Story (the "patterns" — recently rebuilt, reader-first/tension-led).**
`30_story.js` (713), `27e_takeout_engine.js` (567), `27f_takeout_data.js` (419),
`27g_takeout_components.js`, `27h_takeout_read.js`, `27da_takeout_stats.js`, `27k_takeout.js`,
`30x_exhibit.js` (515). storyScore = character + tension; group portraits ranked, traceable,
commensurable, balanced; nulls → rigor footer. Be skeptical of: a "pattern" that asserts a
relationship the underlying cells don't support (false signal), divide-by-zero / tiny-base portraits,
and whether every claim is traceable back to a real cut. Suites: `tests/takeout_tests.mjs` (385),
`tests/portrait_tests.mjs` (144). Spec: `PATTERN_RECOGNITION_REBUILD_SPEC.md`.

**G. Tracker integration into the v2 report (tabs + tracker glue).**
JS: `27t_tracking.js` (367), `27u_summary.js` (341 — Summary-card jump-to-metric+cut, the delta),
`22w_waves.js` (480), `23za_trend.js` (352). R: `tracking_island.R` (296),
`tracking_segment_compute.R`, `tracking_segment_bridge.R`, `build_report_v2.R` (tracker read).
Plus the tracker engine it draws on (`tracker/lib/`, esp. `trend_calculator.R`,
`tracking_crosstab_engine.R`, `trend_significance.R`, `wave_loader.R`). The tracker module had a
production review on 2026-05-24 (`modules/tracker/docs/PRODUCTION_REVIEW_2026-05-24.md`) — confirm
those fixes are present and regress the seams, don't re-audit the whole engine from scratch unless the
integration exposes it. Be skeptical of: wave alignment, weighted trend deltas (n_eff), the
Summary-card navigation target, and the config loader "NA"-stringify gotcha at the wave boundary.
Suites: `tracking_nav_tests.mjs`, `test_tracking_island`, `test_tracking_segment_*`,
tracker testthat dir.

**H. Filtering, composite audience & banners.**
JS: `26_filter.js` (368), `28c_composite.js`, `28b_banners.js`, `24_shell.js`, `25_cards.js` (916).
R: `composite_processor.R`, `banner_indices.R`. The branch **retired the per-tab "Filter comments"
facet** in favour of the single global composite filter (ANDs across conditions, ORs within) — confirm
the removal is clean (no dead code/CSS/state) and filtering still recomputes every tab correctly,
including the qual tab and the theme crosstab. Suite: `composite_tests.mjs` (201). Watch the documented
COMPOSITE/profile-banner overlap-safety design ([[project_tabs_v2_enhancement_batch]]).

**I. Export — Excel / PPTX / PNG / ZIP + pins.**
`29_export.js` (992), `14_pptx_parts.js`, `13_zip.js`, `23y_xlsx.js`, `30x_exhibit.js`. Memory flags
**two pin/export systems to reconcile** ([[project_next_pin_ppt_other_modules]]) — check they don't
collide. Be skeptical of: the pin inliner dropping default CSS values ([[feedback_turas_pins_inliner_defaults]]),
disclosure leakage through exports (ties to Area B), and PPTX/Excel structural validity. High
user-visible-breakage risk.

**J. AI insights (optional feature — graceful degradation is the bar).**
`28_insights.js`, `28a_ai.js`; R `test_ai_*` (7 suites). A missing/failed AI key or a malformed model
response must **never** block or corrupt the report. Confirm failure is silent-but-logged and the
report renders fully without AI. ([[project_tabs_ai_model_config]])

### Cross-cutting (apply to every area)

- **Render/shell layer:** `23_render.js` (525), `23z_charts.js`, `27v_visualise.js` (905),
  `03_svg.js`, `27_views.js`, `32_report.js` — a render throw must not blank the whole report.
- **Build/bundle/orchestration:** `build_report_v2.R`, `run_crosstabs.R` (1084), `00_guard.R` (879),
  `generate_config_templates.R`, the bundler. After any JS change, bundle and `node --check`.
- **TRS everywhere:** no `stop()` / silent failure; structured returns; console-visible for Shiny.
- **Additive / byte-identical:** features off → existing reports unchanged (disclosure off, no qual
  workbook, no AI). Spot-check a config with none of the new features set.

## 3. How to verify (the suites)

JS (node, from `modules/tabs/lib/html_report_v2/`):
`node tests/qual_tests.mjs` · `tests/disclosure_tests.mjs` · `tests/tracking_nav_tests.mjs` ·
`tests/composite_tests.mjs` · `tests/portrait_tests.mjs` · `tests/takeout_tests.mjs`.
In-browser golden harness: append `#selftest` to a generated report URL (Duncan runs this via
`launch_turas`).

R (from repo root): `Rscript -e 'testthat::test_dir("modules/tabs/tests")'` (43 files) and
`testthat::test_dir("modules/tracker/tests")` (21 files); or per-file for the high-value suites named
under each area above (`test_qual_*`, `test_data_layer_writer` (186), `test_report_v2_bundler` (25),
`test_dual_significance`, `test_composite_processor`, `test_tracking_*`, …).

**Generated HTML is verified by Duncan via `launch_turas` — never `preview_start` the tabs report,
never headless-run the pipeline on OneDrive data.** ([[feedback_tabs_v2_regen_via_launch_turas]])

## 4. Deliberate boundaries — do NOT re-flag these as defects

- Theme questions are **deliberately not merged** into the main client-facing Crosstabs list (would
  pollute it + fight the salience reframe). The crosstab lives in the Qualitative tab on purpose.
- Theme bars are **sized by salience, never by raw volume** — that is the intended reframe, not a bug.
- Cell-level click-through (read one column×theme's comments) is a **noted follow-up**; v1 is row-level.
- **Complementary cell suppression** for the MAIN crosstab/dashboard/differences tables is the **next
  increment** — `disc.cellOk()` is built but not yet wired into those renderers. The qual identity side
  + the theme-crosstab column suppression are done. (Flag a real *leak* through them; don't flag the
  not-yet-wired main-table suppression as missing.)
- Theme×banner sig is **vs-the-rest** (not pairwise letters) — intentional, robust for overlapping banners.
- Export-to-Excel for the theme crosstab is a noted follow-up.
- The module file-layout split (`lib/` vs `R/` vs root) is a known historical convention, not a bug.

## 5. Outcome

Report findings most-severe first, by area, each with: the failing input/state, the wrong output, and
why. Fix what's real (with a regression test), confirm green, **then merge to `main`** (Duncan's call on
push). **Any disclosure (Area B) leak is a hard blocker.** A correctness bug in the stats engine (Area
E) or the data bridge (Area D) is the next most serious — those poison every report silently. If the
audit can't reach all areas in one session, say so explicitly and list what was NOT covered (no silent
"looks done").
