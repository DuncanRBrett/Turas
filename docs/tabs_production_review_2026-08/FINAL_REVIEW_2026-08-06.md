# Final Production Review: Turas tabs module

**Date:** 2026-08-06
**Branch/Version:** local `main` @ 957b08fc (all prior review batches merged)
**Reviewer:** Claude (Fable 5) — independent final pass, six fresh-context review
agents (statistical core, config/ingestion, qual+tracking, output layer,
test quality, cold-start docs) plus coordinator verification of every accepted
finding. Run after the 2026-08 production review + fix programme was believed
complete.
**Question asked:** is this production-ready with no bugs or blind spots, and
can a new project be run from the documentation alone?

## Verification gates

| Gate | Command | Result |
|------|---------|--------|
| Tabs R suite (at start) | `testthat::test_dir("modules/tabs/tests/testthat")` | PASS — 3,716 / 0 fail / 0 warn / 0 skip |
| Tabs R suite (after this review's fixes) | same | PASS — 3,733 / 0 fail / 0 warn / 0 skip |
| v2 JS suites (26) | `node <suite>.mjs` each | PASS — all green |
| Standalone JS suites (2) | `node modules/tabs/tests/js/*.mjs` | PASS — 10 + 11 |
| Project-root suite | `testthat::test_dir("tests/testthat")` | 3 pre-existing non-tabs failures, identical to the documented baseline (launcher registry expects 14 modules, 16 exist; two ADR-directory checks) |
| Hygiene | grep sweeps | 0 TODO/FIXME/HACK, 0 `browser()`, no hardcoded paths in lib/ |
| Cold-start | docs-only walkthrough by a fresh agent | Demo ran PASS end-to-end from the documented steps (~10s); template generation works; v2 report builds |

Every CONFIRMED finding below was either reproduced by executing code this
session (probe scripts under the session scratchpad) or verified by the
coordinator reading the cited lines. PLAUSIBLE items are code-traced but not
executed.

---

## FIXED IN THIS REVIEW (three CRITICALs, each proved failing-first)

### F1. Significance letters shifted onto the wrong column when any banner column had no data — FIXED
**File:** `lib/run_crosstabs.R` (`add_significance_row`)
`banner_structure` was built with the *subset* of columns that carry test data
but the *full-length* letters vector; the logical index in
`run_significance_tests_for_row` recycled, so every letter after a dropped
(empty) column pointed one column too early. Mean/index/numeric/allocation rows
were all exposed (their processors drop empty columns before dispatch;
the proportion path never drops and was immune). Reproduced by execution:
4-column banner, empty column B, A significantly above C → the deliverable
printed "B" (the empty column) instead of "C". Ordinary trigger: a routed
question that skips a whole banner segment.
**Fix:** subset the letters with `match(names(banner_test_data), banner_cols)`
at the single construction site. Regression tests (single and dual alpha) in
`test_sig_row_dispatch.R`, both proved to fail pre-fix.

### F2. Allocation weighted means paired answers with the wrong respondents' weights — FIXED
**File:** `lib/allocation_processor.R`
`collect_allocation_values()` strips NA answers, but weights were "aligned" by
**truncation** (`weights[seq_along(values)]`) instead of masking at the same
NA positions — every weighted allocation run with mid-segment item
non-response computed means (and t-tests) from wrong value/weight pairs.
Reproduced by execution: weights (1,10,1,1,1) with the weight-10 respondent
not answering → Turas said 2.154, truth 2.5.
**Fix:** `collect_allocation_weights()` now takes the data column and drops
weights at exactly the non-NA value positions (absent column mirrors the
values collector's `numeric(0)`); both row builders now refuse
(`BUG_ALLOC_WEIGHTS_MISALIGNED`, boxed console output) on any length mismatch
instead of silently truncating. Three regression tests in
`test_allocation_processor.R`, all proved to fail pre-fix.

### F3. The standalone comment report ignored the confidential ship — FIXED
**File:** `lib/qual_report.R` (`build_qual_report_v2`)
`html_report_v2_microdata = FALSE` (the C3 "confidential ship") was enforced
only in `run_crosstabs.R`; the standalone `*_qual_report.html` passed
`micro_json` unconditionally, shipping `banner_vars` — every respondent's
demographic group memberships, joinable to each comment via `idx` in
View-Source — precisely on anonymity-sensitive projects, while
`qual_warn_source_disclosure()` told the operator the ship was source-safe.
**Fix:** the standalone report now gates `micro_json` on the same flag, with
the same console OMITTED notice as the main report. Regression tests (flag off
→ island is the `null` placeholder; default → island present) in
`test_qual_report.R`, proved to fail pre-fix.

---

## CRITICAL — still open (fix before the next new-project run that touches them)

### C1. Counts-only and row-%-only configs ship numbers labelled as percentages
**Files:** `lib/data_layer_writer.R:567-571,691-697`; `assets/js/23_render.js:108-110`
`build_dl_question` falls through Column % → Row % → Frequency into the
island's `pct` field, and the island carries no field naming the quantity; the
renderer hard-labels `pct` as a percentage. Executed repro: a
`show_percent_column = N` config rendered **"142%", "80% B", "62%"** — raw
counts with percent signs and significance letters attached; flows into TSV,
XLSX/PPTX exports, data bars, wave chips, and Patterns/KeyShare scans. The
same fall-through substitutes per-row (a Frequency-only row renders as "37%"
beside real percentages). Row-%-only configs additionally get Wilson intervals
and filter recomputes that silently mean *column* percent.
(This generalises the counts-only side finding recorded at Job B; it is worse
than recorded — it also covers row-% and per-row mixing.)
**Fix:** carry `primary_stat` per question (and per row when substituted) on
the island; renderer refuses the "%" label for anything that is not a column
percentage. Until fixed: **do not ship a v2 report from a counts-only or
row-%-only config.** Excel is unaffected.

### C2. A sub-k column's exact base prints in the v2 report while Excel masks it
**Files:** `assets/js/22_model.js:541-565`, `23_render.js:208-209,357`
`applyDisclosureSuppression` blanks cells and strips letters but never masks
`col.base`. Executed repro: `min_reporting_base = 10`, a 4-person column →
cells "–" but the base row prints "4 ⚠" on screen, in TSV and in the PPTX
matrix. The Excel writer deliberately withholds the same count as "n<10".
Two deliverables of one run enforce different disclosure standards; the HTML
leaks the headcount of an identifiable subgroup.
**Fix:** mask `col.base` for suppressed columns in `tableHtml`/`matrix` the way
`write_base_rows` does.

### C3. Case-sensitive `"Y"` gates silently drop questions, banners and index rows — and preflight validates them case-insensitively
**Files:** `lib/crosstabs/data_setup.R:252`, `lib/banner.R:55,194,207`,
`lib/standard_processor.R:75,661` vs `lib/validation/preflight_validators.R:107,433-434,367`
Executed repros: Selection `Include = "y"` or `"Yes"` → question silently
missing from the workbook, zero preflight issues; `UseBanner = "y"` → passes
validation, banner never appears; `CreateIndex = "y"` → preflight treats it as
an index question, engine never builds the row; `ShowInOutput = "y"` → option
hidden. The validators check `toupper(...)`, the engine checks exact `"Y"` —
the gap is exactly where silence lives. In a 60-question config one lowercase
cell means one table quietly missing from the client deliverable.
**Fix:** one normalisation (`toupper(trimws(...))`) applied to these flag
columns at `load_question_selection`, so engine and validators read the same
value. Contained; needs failing-first tests per column.

---

## IMPORTANT — open

**I1. NPS significance letters test the wrong statistic (Excel engine).**
`cell_calculator.R:512-518` stores raw 0–10 scores; the Sig row t-tests those,
while the printed row is promoters−detractors and the v2 JS engine tests ±100
bucket scores (whose mean IS the NPS). Executed: two columns with identical
NPS 0 got a significance letter (p=0.001) from the raw-scale test. Excel and
HTML can disagree on NPS letters; the Excel letter answers "is the mean rating
different", not "is the NPS different". Fix: store ±100 bucket values as the
test values for NPS rows.

**I2. `population_size` junk silently disables the FPC.** `crosstabs_config.R:268-272`
turns any unparseable value (e.g. `"5,000"` with a comma) into NULL with no
message — on a census project every interval widens and letters can change.
The Population *sheet* path refuses loudly; the Settings cell doesn't. Fix: add
`population_size` to the raw-cell validation family (I11 pattern).

**I3. Junk `apply_weighting` silently runs unweighted.** `safe_logical` warns one
scrollback line and defaults FALSE; all weight preflight checks then skip
(`preflight_validators.R:532`). Every number in the deliverable is
wrong-by-weighting. Same class: `generate_stats_pack = "TRUE"` (Y/N setting)
silently switches the contractual stats pack off; junk `alpha_secondary`
silently disables dual-sig; `ranking_*`/`decimal_places` junk silently defaults
(the M9 fix covered the ten dashboard cells only).

**I4. Qual confidentiality dials fail open on a case slip.** `demographic_cuts
= "Block"` (capital) means *allow*; `qual_verbatim_scope = "Noteworthy"` means
*all* (`qual_quant_layer.R:37-39`, `qual_island_builder.R:95-99`). Executed.
And `qual_demographic_cuts = "safe"` is a silent no-op at the default
`min_reporting_base = 1` (k>1 never triggers) — raw demographic tag combos ship
believing they're k-protected. Fix: validate these enums at load (refuse
unknown tokens, the sampling_method pattern) and warn when safe-mode has k=1.

**I5. FPC missing from two paths that sit beside corrected rows.** NET POSITIVE
(`standard_processor.R:1054-1091`) and composites (`composite_processor.R:871`)
never pass `fpc_mul` — on a census project category rows correctly lose
letters, NET POSITIVE and composite rows keep them. (Extends the known
I1-residual list, which named composites/ranking but not NET POSITIVE.)
Related, deliberate-looking but undocumented: NET POSITIVE letters test the
top box only, not the printed top-minus-bottom (header calls it "Option A").

**I6. Chi-square row: display-rounded weighted counts, no design correction,
not weight-scale invariant.** `standard_processor.R:1308-1314` reads counts
back out of formatted display rows — the one place display rounding feeds a
statistical decision; population-projected weights manufacture significance
(executed: ×10 weights flip p 0.315→0.0015). Also the single significance path
with no known-answer test anywhere in the suite.

**I7. Union workbooks: one ResponseID in two member sheets = duplicate records
sharing one idx/rid.** The per-sheet integrity gate can't see cross-sheet
duplicates (`qual_unions.R:129-160`); executed: base inflated, same reader
token on both records. Fix: extend the dup check across union members.

**I8. Docs describe the retired classic report as current.**
`04_USER_MANUAL.md:481-511`, `02_TABS_OVERVIEW.md:93-107`,
`07_EXAMPLE_WORKFLOWS.md:744-750` describe Summary/Crosstabs/Added
Slides/Pinned Views tabs and an "Add Slide" button; the shipping v2 report has
Dashboard/Group overview/Story/Crosstabs/Differences/Report. A new user hunts
for UI that doesn't exist.

**I9. AddedSlides documented with wrong column names.** Docs say
`slide_id/title/content`; the loader requires `slide_title/content`
(`crosstabs_config.R:844-855`) and silently skips otherwise — slides built
from the docs never appear.

**I10. Template Reference drift.** Three weighting settings documented as
"Required: Yes" were removed from the template as never-read — but
`weight_validators.R:178-180` *does* read them (removal comment and validator
contradict; reconcile). ~25 shipped settings undocumented in the core docs
(incl. `population_size`, `patterns_banner`); Comments-sheet columns
Banner/Headline and the `_BACKGROUND`/`_EXECUTIVE_SUMMARY` convention
undocumented; four ranking settings documented but absent from the template;
documented `AreaSummary` column absent from the template.

**I11. Dead-but-whitelisted settings defeat the typo warning.** `heatmap_colour`
(re-whitelisted in 2026-08 specifically to cure its silent no-op — still a
no-op), `output_folder`/`output_file` (read nowhere; an operator misspelling
`output_subfolder` gets no warning and output lands in the default folder),
plus the classic-report leftovers (`embed_frequencies`, `show_charts`,
`dashboard_metrics`, `dashboard_sort_gauges`, `*_descriptor`,
`include_summary`, `dashboard_green_net/amber_net/green_custom/amber_custom`).
Remove from the whitelist or wire to consumers.

**I12. Test blind spots (where a real bug would ship green).**
(a) The main qual JS suite tests a pre-I20 island shape — 86 fixtures, zero
`rid`; the rekey suite has rid but no band/suppressed/demos; the shape
production actually emits is exercised by no JS test.
(b) Index_Summary values are never asserted (only "sheet exists");
`build_index_summary_table` and four sibling functions have zero direct tests.
(c) `27d_diffs.js` (Differences view) and `ai_insights_step.R` (freshly
refactored, degrades to console warnings by design) have no behavioural tests.
(d) Chi-square: no known-answer test (see I6).

---

## MINOR — open

- **M-A.** SD row prints 0.0 for empty/single-respondent columns
  (`standard_processor.R:553,564`); numeric processor NA-initialises the same
  stat — the two disagree. Executed.
- **M-B.** Two zero-variance groups with different means: p=1, silently "not
  significant" (`weighting.R:988-996`). All-5s vs all-3s gets no letter. Executed.
- **M-C.** Excel Guide sheet documents "*"/"**" small-base markers no writer
  produces, while "**" does appear meaning significant chi-square
  (`excel_writer.R:1682-1683` vs `standard_processor.R:1359`) — the Guide's
  definition inverts its meaning.
- **M-D.** `examples/tabs/basic/` still refuses to load (known; self-declared
  POC). Repo-root CLAUDE.md references its `survey_data.csv`; actual file is
  `data.csv`. Delete the folder or fix the config.
- **M-E.** Demo config carries the retired `html_report` setting → every demo
  run prints the retirement box. Delete the row from
  `Demo_Crosstab_Config.xlsx`.
- **M-F.** Version signals disagree: docs say 10.8; start banner prints 10.2
  (`run_crosstabs.R:25`), closing banner 10.8.1 (`:1182`); README history stops
  at 10.2. One constant.
- **M-G.** `minimum_base` named in troubleshooting doesn't exist
  (`significance_min_base` is the real name); two-argument
  `run_tabs_analysis(project, config)` calls survive in 07's Pattern 1;
  module README's structure diagram puts templates under docs/.
- **M-H.** Year-less wave labels order the trend axis by sidecar build time,
  newest first (PLAUSIBLE, `tracking_island.R:493-497`); blank wave labels
  bypass both stale-wave protections (PLAUSIBLE, `:475,598`).
- **M-I.** Host response-id auto-detection takes the first `^(response ?)?id$`
  match with no ambiguity warning (`qual_assemble.R:168-170`) — a row-counter
  `ID` column can silently win over the real ResponseID (PLAUSIBLE; the
  overlapping-values case joins comments to wrong respondents while diagnostics
  look healthy). `qual_join_id_column` exists; nothing prompts its use.
- **M-J.** A filter retaining 0 rows warns instead of refusing per-question
  (`filter_utils.R:113-118`); NAs in filters silently become FALSE.
- **M-K.** Composite disclosure gate borrows the first source question's bases
  (`summary_builder.R:341-354`) — wrong-column judgment possible when sources
  have different routed bases (PLAUSIBLE).
- **M-L.** Prior review's still-open MINORs reconfirmed on main: M1, M2, M5,
  M6 (`extract_composite_rows` comp_def outside NULL guard — crash-shaped,
  loud), M7, M10, M13, M15 (dead `weighting_variable` fallback;
  `ai_provider` read). M3 (dual `format_output_value`) remains deliberate.
  M-R1 (sprintf warning) verified FIXED on main.

## OBSERVATIONS

- Bonferroni divisors differ by row type for the same table (proportions: all
  columns incl. untestable; means: only columns with data; composites: full
  group). Letters at the boundary can differ between a % row and its mean row.
- Min-base gates on the FPC-*inflated* base (intentional per comments; worth a
  line in the stats-pack Declaration).
- The `tabs_refuse` prefix whitelist lacks `CALC_` — the advertised
  `CALC_UNKNOWN_SIG_ROW_TYPE` actually ships as `CFG_CALC_UNKNOWN_SIG_ROW_TYPE`.
- `badgeHas` (`27e_takeout_engine.js:429`) is the only genuinely dead Patterns
  function; `oddRow`/`bimodalRow` are live (engine still emits those kinds) —
  settles the O6 question.
- `\x01`/`\x02` raw control bytes as k-anon cache separators
  (`qual_island_builder.R`) — correct today, invisible in diffs; use `""`
  escapes. A NUL byte in `tests/js/test_qual_highlight_chip.mjs:44` makes grep
  treat the file as binary, hiding it from text sweeps.
- Partial qual join loss is a count, not a warning ("Joined 400 of 460") —
  only the 0-match case is loud.
- Rounded aggregate history feeds wave significance at stored precision (the
  known CCPB 1dp trap); the engine is honest to its inputs but nothing warns
  that borderline verdicts are fragile.
- `test_tracking_unmatched.mjs` reads fixtures from `prototypes/…` — cleaning
  that directory quietly de-realises the one JS wave-matching gate.
- ~30 preflight tests are wired to skip silently if their source file moves
  (`skip_if(!exists(...))` after conditional source) — currently 0 skips.
- Project-root launcher test expects 14 modules, 16 exist — stale, non-tabs.
- Docs directory: 26 of 39 files are unlinked plans/handovers, several with
  stale status lines ("not built", "no code yet") for shipped features —
  actively misleading to a future reader. Suggest an `archive/` folder or
  STATUS banners.

## What held up under attack (verified clean this session)

Proportion z-test path end-to-end (pooled SE, effective-n, guards), mean
t-test path (Welch + fractional Kish), weighted/unweighted consistency, the
FPC single-definition threading (except I5), display rounding never feeding a
test (except chi-square), wave pairing/dedupe/`built`-stamp honesty, the I22
fixes, `tested_prev` honesty in the tracker UI, ResponseID normalisation
(1e5/12-digit cases), hide-marker grammar, append-only reader-keys sidecar
(corrupt file never re-minted, byte-identical after the call), k-anonymiser
correctness incl. within-band, verbatims absent from Excel and Reader outputs,
island injection defence, poison-key null-prototype maps, JS↔R stat parity,
export paths rendering post-suppression, the cross-engine parity harness
(the best artifact in the suite), config front door for typos/merged
rows/case-mismatched names, preflight cross-checks, template/whitelist
agreement (all 76 settings), and the documented happy path executing
end-to-end from the docs alone.

---

## Verdict

**DEPLOY WITH CONDITIONS — the CCPB-shaped path is solid; three sharp edges
were fixed in this review; three specific ships remain unsafe until their
open CRITICALs land.**

The statistical core's ordinary path is genuinely trustworthy: 3,733 R + 28 JS
gate assertions, hand-derived known answers, a cross-engine parity fixture,
and six adversarial fresh-context reviews that confirmed the letter/test
machinery, weighting, FPC threading, tracking honesty and qual privacy gates
hold under attack. The three wrong-number/wrong-ship CRITICALs found this
session (letters shifting past an empty column, allocation weight
misalignment, the comment report's microdata bypass) are fixed with
failing-first regression tests.

Conditions: (1) do not ship a v2 report from a counts-only or row-%-only
config until C1 lands; (2) do not treat the v2 HTML as disclosure-safe for
sub-k audiences until C2 lands; (3) normalise the Y-flag columns (C3) before
the next hand-built config, or lowercase `y` cells will silently drop
questions/banners with preflight approving. For anonymity-critical work also
take I4 (confidentiality dials fail open) and note the F3 fix means
regenerated comment reports now honour the confidential ship.

The documentation answer to Duncan's question is **yes, with one afternoon of
corrections**: a new project can be run from the docs alone (verified by
execution), but I8/I9/I10 will each cost a future operator real time, and two
of them (AddedSlides columns, report-tab descriptions) describe things that
are simply false.
