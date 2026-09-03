# Pricing v2 lift. Refreshed handover, 3 September 2026

Written by the Fable session that ran the pricing blindspot pass on 3 Sep 2026.
It replaces `HANDOVER_PRICING_FOR_OPUS.md` (11 Jul 2026) as the brief for the
pricing sessions. The July document stays in the folder for its Session A work
orders, which are still the spec for the correctness work; everything about
reporting in it is superseded here. For Opus 5 at high effort. Load the
`fable-method` skill. Project CLAUDE.md rules apply throughout.

Read in this order: (1) this document; (2) `PRICING_PRODUCTION_REVIEW_2026-07-11.md`
for the findings (IDs C1 to C3, H1 to H8, M1 to M14, P1 to P3); (3) the July
handover section 2 for the Session A work orders A1 to A9, which this document
does not repeat; (4) for the v2 session, `SESSION_BC_NOTES_MAXDIFF.md` and
`modules/maxdiff/R/13_v2_island.R`, `12_tabs_export.R`, and
`modules/tabs/lib/html_report_v2/assets/js/27y_maxdiff.js`, which are the
pattern to copy.

## 0. What changed since July, and why the old handover would mislead

Verified on main at `3f85abb3` on 3 Sep 2026:

- Nothing from the July review has been built. `feature/pricing-correctness`
  was never started. All three CRITICALs are live in the code: only
  `psm_analysis()` is ever called (C1), the per-rung NA drop in
  `calculate_demand_curve()` is unchanged (C2), the bootstrap still runs
  `validate = FALSE` against a `validate = TRUE` headline (C3). The template
  still cannot run VW or GG (H1). The suite is 0 fail / 0 skip / 63 warnings,
  exactly the July baseline, and still structurally green.
- The classic tabs HTML report was retired on 5 Aug 2026 (`2fdcb38f`). The
  migration plan's rule now governs: migrate a module by making it emit a v2
  island, do not port its classic report. Conjoint (merged 27 Aug) and maxdiff
  (merged 3 Sep) both went that way: a frozen island, the module's own view
  and tab in the tabs v2 report, a per-respondent tabs export, a standalone
  simulator linked from the tab, and the classic report deleted or retired.
- The July handover's locked decision 4 ("no v2 view for pricing") rested on
  the row-kind route fighting the banner-axis row contract. Conjoint and
  maxdiff proved the island route needs zero new row kinds, which removes the
  objection. Its decision 5 ("simulator stays embedded, delete the standalone
  fork") is the opposite of what both peers shipped and of standing decision
  D2. Its Session B patches the classic pricing report, which is the same
  architectural generation as the two reports already deleted.
- OPUS-0 landed: `modules/shared/lib/effective_n.R` (`calculate_effective_n`)
  and `disclosure_gate.R` (`meets_min_base`). H7's local Kish copy is no
  longer needed; use the shared helper.
- There is no client pricing project to eyeball on. The maxdiff Karoo example
  and the integrated demo are how conjoint and maxdiff were verified.

## 1. Decisions, superseding the July section 0

1. VW goes weighted through `psm_analysis_weighted()` with a `survey::svydesign`
   built from the weight column; a runtime failure on that path refuses
   (`MODEL_VW_WEIGHTED_FAILED`), never falls back. Unchanged from July.
2. Sequential GG refuses by default on unequal per-rung bases;
   `GG_Stop_Early_Imputation = NO_AFTER_STOP` is the explicit opt-in. Unchanged.
3. Monotonicity: `flag_only` means `validate = FALSE`, `drop` means
   `validate = TRUE`, default `drop`; the bootstrap uses the same flag and the
   same weighting as the headline. Unchanged.
4. **Pricing gets a v2 island and a Pricing tab**, on the maxdiff template.
   Frozen island, own view, zero new row kinds, filter bar hidden on the tab.
   Replaces July decision 4.
5. **The simulator is extracted to a standalone HTML file** linked from the
   Pricing tab (D2). `lib/simulator/` (the dead fork) is deleted; the live
   engine in `lib/html_report/js/pricing_simulator.js` is the one that moves.
   Replaces July decision 5.
6. **The classic pricing report is retired loudly.** `Generate_HTML_Report`
   goes into a `PRICING_RETIRED_SETTINGS` list on the conjoint pattern, and
   `lib/html_report/` is deleted once the simulator is out of it. Nothing in
   the July Session B (P1, P2, P3a, P3b, P3d, P3e) is done: it repairs what is
   being deleted. P1c and P3a apply to the simulator engine and travel with it.
7. Tabs export as July B4 specified: GG acceptance grid as 0/1 `Multi_Mention`
   columns, `pricing_valid` flag, optional WTP, all stamped on a METHOD sheet;
   VW and monadic questions declared tabs-side through QuestionMap rows only.
8. **A Karoo pricing example is Session A's first deliverable**, not an
   afterthought. It is the harness, the demo and Duncan's eyeball.
9. Generated recommendation prose (`12_recommendation_synthesis.R`) does not
   enter the tab. The numbers do (recommended price, range). Prose is the
   analyst's, in the Insights box.
10. The pricing module's own segmentation (`10_segmentation.R`) stays in the
    Excel deliverable and does not enter the tab. Under D1 segment cuts are
    the crosstab's job via the tabs export.
11. Live recompute of VW under the audience filter is NOT in scope for either
    session. See section 5.
12. Session split: Session A = correctness plus the Karoo example; Session B
    = the v2 lift (`feature/pricing-v2-report`, off main). **Session A is
    built and merged to local main (`299355dc`, 3 Sep 2026); Duncan ran the
    Karoo example from the launcher and it completed.** Its independent
    review (`REVIEW_BRIEF_PRICING_SESSION_A.md`) is owed and can run in
    parallel with Session B; anything the review finds lands as a small
    branch off main. Duncan merges B after his eyeball.

## 2. Ground rules

- Work in a worktree off main. Two other sessions may be live in the main
  checkout. `git branch --show-current` and `git rev-parse --show-toplevel`
  before the first edit.
- Fix code and run suites. Duncan regenerates through `launch_turas()`. Never
  run the pipeline against a real project folder or write into OneDrive. The
  Karoo example may be run into `examples/pricing/Output` (it is synthetic)
  and into the scratchpad.
- Suite: `Rscript -e 'testthat::test_dir("modules/pricing/tests/testthat", reporter = "summary")'`
  from the repo root. Baseline 3 Sep 2026: 0 fail / 0 skip / 63 warnings.
  The suite's green is structural: `setup.R` tryCatch-sources every file and
  tests `skip_if(!exists(...))`. After any change to a sourced file, confirm
  the test count did not drop. Session B also runs the tabs R suite and every
  `modules/tabs/lib/html_report_v2/tests/*_tests.mjs` file.
- Every fix ships with a test that fails on the old code.
- TRS refusals only. `pricing_refuse()` prefixes anything outside
  `CFG_ DATA_ IO_ MODEL_ MAPPER_ PKG_ FEATURE_ BUG_` with `CFG_`, so the July
  handover's `CALC_*` codes must be written as `MODEL_*` (the maxdiff lesson).
- No em dashes in any string that reaches Duncan or a client: labels, console
  lines, sheet text, commit messages. The stats pack currently writes
  `VW — PMC`; fix the ones you touch.
- Keep an implementation-notes log (`SESSION_A_NOTES_PRICING.md`,
  `SESSION_B_NOTES_PRICING.md` in this folder). Conservative option plus a
  Deviations entry when an edge case forces a change.

## 3. Session A. Correctness, and the Karoo example (`feature/pricing-correctness`)

### A0. The Karoo pricing example, first

`examples/pricing/create_pricing_example.R`, on the maxdiff example's pattern
(`examples/maxdiff/create_maxdiff_example.R`): functions that take a
respondent frame so the integrated demo can reuse them, plus a default frame
via `karoo_default_respondents()` sourced from the maxdiff file. The product is
a 250 g bag of Karoo Coffee. It writes:

- `Karoo_Pricing_Data.xlsx`: one row per respondent with `RespID`, the four
  demographics, a `Weight` column (mean 1, range about 0.5 to 2, built from
  Region so the weighted and unweighted VW points differ visibly), the four
  VW columns (`VW_TooCheap`, `VW_Cheap`, `VW_Expensive`, `VW_TooExpensive`,
  rands, drawn from known distributions with about 8% intransitive
  respondents), a GG ladder `GG_R60 .. GG_R140` in five rungs as 0/1 columns
  under full presentation, a second stop-early copy of the same ladder
  `GGS_R60 .. GGS_R140` with NA after the first No, and a monadic cell
  `MON_Price` with `MON_Intent` on a 1 to 5 scale.
- `Karoo_Pricing_Config.xlsx` (method `both`, weighted, id `RespID`, currency
  `R`), `Karoo_Pricing_Config_Monadic.xlsx`, and
  `Karoo_Pricing_Config_StopEarly.xlsx` pointing at the `GGS_` columns. Built
  from scratch with openxlsx and saved through `turas_saveWorkbook`, never by
  patching the shipped template (dimension collapse).
- Known truths, returned by the generator, that tests assert against: the
  population OPP within a stated band, GG demand at each rung, the monadic
  slope sign, and that the stop-early config refuses by default.
- `examples/pricing/README.md`: what it is, how to run it, what to expect.

Run it before touching any engine code. On main it will fail at the loader
(H1), which is the point: that failure is the first test.

### A1 to A9

As the July handover section 2 specifies, with these amendments:

- A2: `psm_analysis_weighted()` takes `design`, a `survey::svydesign` on a data
  frame carrying the four columns and the weight, with the four arguments
  given as column names. Refusal code `MODEL_VW_WEIGHTED_FAILED`. The stats
  pack, the Excel summary and the island all state which path ran.
- A4: refusal code `DATA_GG_UNEQUAL_BASES`; imputation stamped in the summary,
  the stats pack and the island meta.
- A6 (H7): use `calculate_effective_n()` from `modules/shared/lib/effective_n.R`.
  Source it the way `00_main.R` sources the other shared files. Do not write
  a local Kish.
- A8 (M6): unknown-setting warning and duplicate refusal, and a
  `PRICING_RETIRED_SETTINGS` list on the conjoint pattern, empty for now.
  Session B fills it.
- A8 (M13): the dead tier stays dead. Delete the never-rendering output
  blocks in `06_output.R` that read WTP, competitive and optimisation results
  the pipeline never produces, or gate them so they cannot fire. Do not wire
  07, 08 or 09.
- A9: the golden-value tests use the Karoo generator's known truths where a
  hand-computed five-respondent fixture is not clearer.
- The em-dash sweep applies to every string Session A touches.

Definition of done for A: the three Karoo configs run end to end from
`run_pricing_analysis()` (the stop-early one refusing as designed, then
passing with the opt-in), suite green with the new tests in, every review ID
fixed with a test or logged as deferred, notes written, nothing merged.

## 4. Session B. The v2 lift (`feature/pricing-v2-report`)

Branch off main at or after `299355dc`. Session A's notes
(`SESSION_A_NOTES_PRICING.md`) record the result-object fields Session A added
(`diagnostics$estimator`, `n_analysed`, `monotonicity_behavior`, `validate_flag`,
`weighted`; GG `rung_bases`, `diagnostics$response_coding`, `imputation`,
`smoothing`, `purchase_intent_raw`; monadic `weighted_n`, `p_value_caveat`; the
`policy` attribute on both bootstrap tables). The island's `meta` and
`estimationNote` come from those, not from new computation. The three settings
`Generate_Tabs_Export`, `Tabs_Question_Code` and `Export_WTP` are already in
the template and refuse on Y (`FEATURE_TABS_EXPORT_PENDING` in
`apply_pricing_defaults()`); B3 removes that refusal when the exporter lands.

### B1. Island writer, `modules/pricing/R/14_v2_island.R`

`serialize_pricing_layer(results, config)` and `write_pricing_island()`,
writing `{output}_pr_island.json` every run, `meta.kind = "pricing"`,
schema 1. Blocks, each ABSENT when the run did not produce it (never `{}`;
wrap per-row vectors in `I()` as `.maxdiff_island_keep_arrays()` does):

- `meta`: projectName, currency, methods run, nRespondents, analysed n per
  method, weighted flag, effectiveN, `weightingNote` naming which estimates
  are weighted and how, `estimationNote` per method (VW: pricesensitivitymeter
  intersections, validate flag and analysed n; GG: observed acceptance with
  the coding rule, smoothing method, imputation if any; monadic: glm form,
  the weight caveat from H4), `frozen = TRUE`, `filterNote`, `simulatorFile`.
- `vw`: the four price points with the bootstrap interval for each (from the
  A3-coherent bootstrap), the acceptable and optimal ranges, and the curve
  arrays (price, tooCheap, cheap, expensive, tooExpensive) at the
  interpolation grid, capped to a sensible length.
- `gg`: per rung price, base n, weighted n, acceptance pct, smoothed pct,
  revenue index, arc elasticity, CI bounds; optimal price for revenue and, if
  a unit cost exists, profit.
- `monadic`: observed cells (price, n, weighted intent), the fitted curve on
  its grid, optimal price, pseudo R2, the p-value with its caveat text.
- `recommendation`: the numbers only (recommended price, range, the method
  agreement figure). No generated prose.

Wire it in `00_main.R` after the Excel write, like maxdiff's `00_main.R:1310`.

### B2. Tabs side

Copy the maxdiff hook exactly, with pricing names, in every one of these
places (the two-place whitelist trap is real):

- `crosstabs_config.R`: `pricing_island` in `build_config_object()` next to
  `maxdiff_island` (line 345) AND in `TABS_KNOWN_SETTINGS` (line 1694).
- `generate_config_templates.R`: the `pricing_island` setting row.
- `run_crosstabs.R`: `.read_pricing_contribution()` checking
  `meta$kind == "pricing"`, and `pr_json` passed through at the build call.
- `build_report_v2.R`: `pr_json = NULL` on both signatures, `pr_inlined`
  through `escape_island()`, `{{DATA_PR}}` substitution.
- `template.html`: `<script type="application/json" id="data-pr">`.
- `24_shell.js`: `TR.PR = parseIsland("data-pr")`, the tab pushed into the
  Read group when `TR.pricing.available()`, render dispatch, and the
  filter-hidden list.
- `27z_pricing.js`: the view. Provenance panel first (methods, n, weighting,
  estimator notes, the frozen note). VW: the four points with intervals and
  an SVG of the four curves with the points marked. GG: rung table and a
  demand-and-revenue chart with the optimum marked. Monadic: cells and the
  fitted curve. Recommendation numbers. Link to the simulator. Every label
  through `esc()`. En dash for missing, no em dash anywhere.
- `tests/pricing_view_tests.mjs` on the maxdiff gate's pattern, and
  `modules/tabs/tests/testthat/test_pricing_island.R` on
  `test_maxdiff_island.R`'s pattern (template carries the island, builder
  inlines it, a report without pricing is byte-identical to before).

### B3. Tabs export, `modules/pricing/R/15_tabs_export.R`

July B4 as written, on the maxdiff export's DATA / QUESTIONMAP_SNIPPET /
METHOD layout. `Generate_Tabs_Export` default NO. `id_var` mandatory when on.
GG grid as `{QCode}_1..{QCode}_k`, `Variable_Type = Multi_Mention`, options
rows carrying the rung prices with currency. `pricing_valid` column.
`Export_WTP` optional, wiring `extract_wtp_vw` / `extract_wtp_gg` narrowly.
Integration proof: feed the export through tabs' own processor in a test.

### B4. Simulator out, classic report retired

Extract the simulator to `lib/html_simulator/` as conjoint did
(`SESSION_C_NOTES_CONJOINT.md`, "The retirement"): the panel markup, the
data transformer for `PRICING_DATA` / `PRICING_CONFIG`, the CSS it needs,
`pricing_simulator.js`, and shared TurasPins only if the standalone keeps
pins. Fix P1c (segment chart on the segment's own price axis) and P3a (one
Revenue Index scale) in the engine as it moves; harden the islands (P2a).
`Generate_Simulator` writes `{output}_simulator.html`; the island's
`simulatorFile` names it. Then delete `lib/html_report/` and
`lib/simulator/`, their tests, and the report's R glue in `00_main.R` step 9.
`Generate_HTML_Report` into `PRICING_RETIRED_SETTINGS` with a message that
names the Pricing tab. Docs: README, USER_MANUAL, TECHNIQUE_GUIDE stop
describing the classic report and the dead sheets.

### B5. The integrated demo gains pricing

`examples/integrated_demo/build_integrated_demo.R`: source the pricing
example's functions, simulate the pricing questions on the same respondent
frame, run the module, and point the tabs config's `pricing_island` at the
island. The demo README lists the Pricing tab. The tabs run must still pass
without a pricing island (test).

Definition of done for B: Karoo integrated demo builds with a Pricing tab
rendered in a browser (headless Chrome is fine), tabs R suite and every node
gate file green, pricing suite green, notes written, nothing merged.

## 5. After both sessions: live VW under the filter (design note, not a build)

Pricing differs from conjoint and maxdiff in one way the frozen template
hides. The VW points are a pure function of four numbers per respondent plus
a weight, and GG acceptance per rung is a weighted mean of a 0/1 column. If
the four VW columns are declared as tabs Numeric questions, their values are
already in `TR.MICRO.scores`; a view could recompute OPP, IPP, PMC and PME
live under any audience filter, which no other module tab can do. The cost
is a JavaScript ECDF-intersection that must match `psm_analysis_weighted()`
to the decimal, gated by a parity fixture on the pattern of
`parity_stats_tests.mjs`. It waits for the allocation live-recompute work
(`HANDOVER_ALLOCATION_LIVE_RECOMPUTE_FOR_OPUS.md`) to land and for the
weighted R path to have been reviewed. A Fable design session decides the
shape; nobody builds it from this paragraph.

## 6. What not to do

- Do not patch the classic pricing report. It is being deleted.
- Do not wire 07, 08 or 09 into the pipeline beyond B3's narrow WTP use.
- Do not add row kinds to `build_dl_question()` or `forQuestion()`.
- Do not write a local Kish; use the shared helper.
- Do not tidy the 266 KB of docs. Cut what describes deleted things; leave the
  rest.
- Do not claim the weighted VW path verified without having executed
  `psm_analysis_weighted()` in a test.
- Do not merge or push. Duncan merges after the Fable review and his eyeball.

## 7. Rulings for Duncan

Proceed on the recommendation unless he says otherwise at the start of a
session, and say so in the commit.

- R1. Monotonicity default: `drop` (recommended, the honest version of today's
  behaviour) or `flag_only`.
- R2. Monadic in the tab: include (recommended, it is one of three methods
  the module sells) or Excel only.
- R3. Docs: delete `MARKETING.md` and `METHODOLOGY_COMPARISON.md` from the
  module folder (recommended; they are not operator documentation) or leave.
