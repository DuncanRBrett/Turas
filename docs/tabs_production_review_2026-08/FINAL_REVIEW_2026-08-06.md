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

### C1. Counts-only and row-%-only configs ship numbers labelled as percentages — FIXED 2026-08-06 (Job C1)
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

**FIXED 2026-08-06.** `build_dl_question` now emits `stat` on the question
(`"Column %"` | `"Row %"` | `"Frequency"` | `"Average"`) and `stat` on any row
whose value the fall-through substituted — **only when it is not `"Column %"`**,
so every ordinary island is byte-identical and an absent field reads as the
column percentage. The vocabulary lives in `TR.fmt` (`statOf` / `isPctStat` /
`isColPctStat` / `statName` / `value`) because every display and scan layer
needs it. Counts now print as counts in the crosstab, the TSV, the export
matrix, the SVG and native-PPTX charts (plain axis format, data-driven max) and
the reader's plain-language sentences, with the unit named in the table's corner
cell and the matrix head. Everything that assumes a column proportion is gated:
Wilson intervals, the mean-CI and tracking/wave SD derivations (which read the
category distribution), data bars, the heat tint, wave trending + delta chips,
the Differences pp gaps, Patterns top-box + KeyShare eligibility and gathering,
and the confidence explainer's worked example. A row percentage keeps its "%"
but declares its denominator and takes no Wilson interval. A filtered / custom-
banner recompute is always a column percentage, so the model reports
`stat: "Column %"` + `statWas`, and the table says "published as Counts (n)"
rather than swapping unit in silence. Files: `lib/data_layer_writer.R`,
`01_format.js`, `21c_confidence.js`, `22_model.js`, `22w_waves.js`,
`23_render.js`, `23z_charts.js`, `24a_reader.js`, `25_cards.js`, `27d_diffs.js`,
`27f_takeout_data.js`, `27fa_takeout_shares.js`, `27t_tracking.js`,
`29_export.js`, `30x_exhibit.js`, `styles.css`. Tests: 4 in
`test_data_layer_writer.R` (3 proved failing pre-fix), a new 16-check
`tests/stat_label_tests.mjs` (13 proved failing pre-fix) and one in
`takeout_tests.mjs` (proved failing pre-fix). Gates after: tabs R suite
**3,742 / 0 / 0 / 0**, 29 JS suites green, project-root suite at its documented
3-failure baseline. Verified end-to-end by generating a real v2 report with one
counts-only and one column-% question and running its own bundle in headless
Chrome: `142  80 B  62` under "Counts (n)", `71%  80% B  62%` untouched.
Schema documented in `modules/tabs/docs/11_DATA_CENTRIC_REPORT_V2.md`.

### C2. A sub-k column's exact base prints in the v2 report while Excel masks it — FIXED 2026-08-06 (Job C2)
**Files:** `assets/js/22_model.js:541-565`, `23_render.js:208-209,357`
`applyDisclosureSuppression` blanks cells and strips letters but never masks
`col.base`. Executed repro: `min_reporting_base = 10`, a 4-person column →
cells "–" but the base row prints "4 ⚠" on screen, in TSV and in the PPTX
matrix. The Excel writer deliberately withholds the same count as "n<10".
Two deliverables of one run enforce different disclosure standards; the HTML
leaks the headcount of an identifiable subgroup.
**Fix:** mask `col.base` for suppressed columns in `tableHtml`/`matrix` the way
`write_base_rows` does.

**FIXED 2026-08-06.** New `render.baseMarker(col)` (`23_render.js`) returns
`"n<k"` for a suppressed column and `null` for every other, mirroring
`excel_utils.R disclosure_marker()`; it is the single site the display layers
call, so an unprotected report (nothing ever flagged) is byte-identical. The
leak was on **four** surfaces, not one, and two of them were not the base
number itself:
1. **All three base rows** — unweighted, weighted and Kish effective — in
   `tableHtml`, matching what `write_base_rows`'s `mark_suppressed` masks in the
   workbook (it marks all three too).
2. **`render.matrix`**, so the clipboard, the TSV, the XLSX download
   (`23y_xlsx.js` coerces only clean numerics — `"n<10"` lands as an inline
   string, as in Excel) and the PPTX matrix carry the marker as well.
3. **The base row's derivations, which invert to the exact base.** The
   worst-case margin is `98/√n`, so `±49.0pp` *is* `n=4`; a census column's
   coverage note ("2% of 200") reads the same way. A suppressed column now
   prints the marker alone — masking the number and keeping its arithmetic
   would have disclosed it anyway.
4. **The confidence explainer's "small groups swing more" bullet**
   (`21c_confidence.js smallColumnExample`), which was the worst of the four
   and is not in the finding above: it picks the **smallest** column of the
   default banner group *by construction*, so on any protected report it
   preferentially names the withheld group and its headcount in prose —
   verified in a real browser as "**Legal has only 4 respondents**" while the
   crosstab beside it said `n<10`. It now skips columns `TR.disclosure.cellOk()`
   would withhold and falls back to the smallest disclosable column (or drops
   the bullet when none qualifies, as it already does with no banner groups).

Also masked: the wave strip's current-wave base cell (`23za_trend.js`), which
prints `columns[0].base` on the same card and is suppressed in the
whole-audience-below-k case. Files: `23_render.js`, `21c_confidence.js`,
`23za_trend.js`, `styles.css` (one muted `.supb` rule — the marker is a
withholding, not the amber low-base warning). Tests: 21 checks appended to
`tests/disclosure_tests.mjs` in their own model+render sandbox (the existing
section is a 21d-only unit suite); 12 proved failing against the pre-fix code
by revert-run-restore. Gates after: tabs R **3,742 / 0 / 0 / 0** (unchanged —
JS-only), **29** JS suites green, project-root at its documented 3-failure
baseline. Verified end-to-end by generating a real v2 report through
`build_data_layer` → `serialize_data_layer` → `build_report_v2_html` with
`min_reporting_base = 10` and a 4-person banner column, and reading its own
bundle in headless Chrome — before: `4 ⚠  ±49.0pp` in the table, `4 ⚠` in the
TSV, "Legal has only 4 respondents"; after: `n<10`, `n<10`, "Sales has only 196
respondents", with the safe columns (`200 ±6.9pp`, `196 ±7.0pp`) untouched.

**Deliberately left alone** (recorded, not fixed): the question card's
`COMPUTED · n=3` badge (`25_cards.js:521`) and the filter bar's own
`TR.disclosure.note()` both state the **audience** base under the reader's own
filter. That is a different quantity from a banner column's headcount, and the
existing design discloses it on purpose — `note()`'s wording is literally
"Audience too small (n=3…) — broaden the filter". Masking the badge while the
note beside it prints the number would achieve nothing; whether the audience
count should be disclosed at all is a design question, not this fix.

### C3. Case-sensitive `"Y"` gates silently drop questions, banners and index rows — and preflight validates them case-insensitively — FIXED 2026-08-06 (Job C3)
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

**FIXED 2026-08-06.** New `normalise_flag_column()` in
`lib/crosstabs/data_setup.R` canonicalises a gate column to exactly `"Y"` /
`"N"`, case- and whitespace-insensitively. Every downstream reader — the
engine's exact `== "Y"` tests and preflight's `toupper(...) == "Y"` ones —
then sees the same value, so no reader needed touching.

**The finding named one load site; there are two, and six columns, not four.**
`ShowInOutput` and `ExcludeFromIndex` live on the Survey Structure's Options
sheet, not the Selection sheet, so `load_question_selection` cannot reach them —
they are normalised in `prepare_options_columns()`, the Options sheet's single
load site (`load_crosstabs_data` calls it before validation, so preflight sees
the normalised frame too). Two columns beyond the briefed four are in the same
family and were fixed with them:
- **`BannerBoxCategory`** (`banner.R:189`, exact `== "Y"`) — a lowercase `y`
  silently downgraded a box/category banner to a plain one.
- **`ExcludeFromIndex`** — worse than the briefed class, because here *two
  engine paths disagreed with each other* rather than engine-vs-preflight:
  `cell_calculator.R:344`, `score_utils.R:157`, `composite_processor.R:319` and
  `microdata_writer.R:418` read `!= "Y"`, while `summary_builder.R:302` and
  `tracking_wave_values.R:74` read `toupper(trimws(...)) == "Y"`. A lowercase
  `y` meant one thing in the mean and another in the summary.

**Decision on the vocabulary (the question the handover asked).** `Y`, `YES`,
`TRUE`, `T`, `1` all mean yes; `N`, `NO`, `FALSE`, `F`, `0` all mean no; blank
(NA or whitespace only) takes the column's documented default — `N` everywhere
except `ShowInOutput`, whose blank means show. Anything else **refuses**
(`CFG_INVALID_FLAG_VALUE`) naming the sheet, the column, the row number, the
QuestionCode and the offending value.

This departs from the handover's recommendation ("`Y` only; warn on any other
non-blank, non-`N` token") in two ways, deliberately:
1. **Refuse, not warn.** The handover cited "the sampling_method pattern", but
   `sampling_method` *refuses* on an unknown token — it does not warn. A bare
   warning is also the exact failure mode this review lists as IMPORTANT I3
   ("`safe_logical` warns one scrollback line and defaults FALSE"). Refusing at
   load, before any computation, costs one edit and a re-run.
2. **Accept the everyday spellings.** A warn branch is needed regardless (no
   accept-list can be exhaustive), so the only real question is its width. The
   chosen set is not invented — `workbook_builder.R:231` (create_index_summary)
   and `excel_writer.R:1476` already accept exactly `c("Y","YES","TRUE","T","1")`
   after `toupper(trimws())`. The same word now means the same thing everywhere
   in the module.

**Regression risk, stated plainly:** a config carrying an unreadable token in
one of these six columns now stops instead of running. Such a config is today
silently dropping that row, so the refusal surfaces a real defect rather than
breaking working work — but it is a behaviour change on live configs. Verified
against every shipped artefact: freshly generated Crosstab_Config and
Survey_Structure templates, the demo config and structure, and all four
`Parity_*` fixtures load without refusing.

One documentation error in the same family was corrected: `06_TEMPLATE_REFERENCE.md`
said a blank `ShowInOutput` **excludes** the option. It includes it —
`prepare_options_columns` defaults blank to `"Y"` and every filter reads
`== "Y" | is.na(...)`. An operator following the doc would have blanked cells
expecting options to disappear and shipped them instead.

Files: `lib/crosstabs/data_setup.R`, `docs/06_TEMPLATE_REFERENCE.md`. Tests:
new `tests/testthat/test_selection_flags.R`, 31 assertions; **18 proved failing
against the pre-fix code** by revert-run-restore, and each of the six columns
failed on *behaviour* (question dropped, banner absent, option hidden, the two
index paths disagreeing) rather than on the new function being missing.
Verified end-to-end on the shipped demo: with `Region` set to lowercase `y` in
both Include and UseBanner, the pre-fix engine ran to completion and reported
**25 questions / 12 banner columns** with Region in neither; after the fix the
same config gives **26 questions / 16 banner columns** with `Region::Gauteng`
… `Region::Eastern Cape` in the banner and Region as a stub. Gates after: tabs
R **3,773 / 0 / 0 / 0**, **29** JS suites green, project-root 571 pass / 3 fail
at its documented baseline.

---

## IMPORTANT — open

**I1. NPS significance letters test the wrong statistic (Excel engine) — FIXED 2026-08-06 (Job I-stats).**
`cell_calculator.R:512-518` stores raw 0–10 scores; the Sig row t-tests those,
while the printed row is promoters−detractors and the v2 JS engine tests ±100
bucket scores (whose mean IS the NPS). Executed: two columns with identical
NPS 0 got a significance letter (p=0.001) from the raw-scale test. Excel and
HTML can disagree on NPS letters; the Excel letter answers "is the mean rating
different", not "is the NPS different". Fix: store ±100 bucket values as the
test values for NPS rows.

**FIXED 2026-08-06.** `calculate_nps_score()` now returns the per-respondent
±100 buckets as `$values`, through `nps_bucket_score()` (score_utils.R) — the
module's single definition of the bucket, already shared by the microdata writer
and the v2 JS engine. Reproduced first: two columns both scoring NPS 0, one made
of 10s and 0s and one of 9s and 6s, drew a letter at **p = 0.043**; after, p = 1.

**Two things beyond the brief, both deliberate.**
1. **The published value is now derived from the tested vector** (its weighted
   mean) rather than computed a second way beside it. For the integer 0–10
   answers real NPS data carries this is arithmetically identical to
   promoters−detractors — verified against the existing value tests, which are
   unchanged. An out-of-range answer (negative, or a 6.5 after a coding slip)
   now leaves the NPS base instead of being counted as a detractor, which is
   what the microdata and the v2 report have always done. Excel and HTML now
   bucket every answer the same way.
2. **The Standard Deviation row moves to the same ±100 scale.** `$values` feeds
   the SD row as well as the test, and splitting them would leave a published SD
   that no longer explains the letters beside it — the class of defect this
   review exists to close. On a column of 24 promoters / 8 passives / 8
   detractors the row now prints **81.0** where it printed **1.9**; the v2
   report's own mean-CI has always derived its SD from the ±100 distribution, so
   this is the workbook catching up to the report, not a new number.
   **This is a visible change to a published figure on every NPS deliverable**
   and the one call here Duncan may want to reverse; it is one line.

**Recorded, not fixed:** the ±100 buckets make open finding **M-B** (two
zero-variance groups test at p = 1) bite NPS rows harder. "Every respondent in
this column is a promoter" is an ordinary small-column outcome; "every
respondent gave exactly the same rating" was rare. NPS +100 against NPS −100
draws no letter. Pinned by a named test so it is visible rather than discovered
in a deliverable.

**I2. `population_size` junk silently disables the FPC — FIXED 2026-08-06 (Job I-batch).**
`crosstabs_config.R:268-272`
turns any unparseable value (e.g. `"5,000"` with a comma) into NULL with no
message — on a census project every interval widens and letters can change.
The Population *sheet* path refuses loudly; the Settings cell doesn't. Fix: add
`population_size` to the raw-cell validation family (I11 pattern).

**I3. Junk `apply_weighting` silently runs unweighted — FIXED 2026-08-06 (Job I-batch).**
`safe_logical` warns one
scrollback line and defaults FALSE; all weight preflight checks then skip
(`preflight_validators.R:532`). Every number in the deliverable is
wrong-by-weighting. Same class: `generate_stats_pack = "TRUE"` (Y/N setting)
silently switches the contractual stats pack off; junk `alpha_secondary`
silently disables dual-sig; `ranking_*`/`decimal_places` junk silently defaults
(the M9 fix covered the ten dashboard cells only).

**I4. Qual confidentiality dials fail open on a case slip — FIXED 2026-08-06 (Job I-batch).**
`demographic_cuts
= "Block"` (capital) means *allow*; `qual_verbatim_scope = "Noteworthy"` means
*all* (`qual_quant_layer.R:37-39`, `qual_island_builder.R:95-99`). Executed.
And `qual_demographic_cuts = "safe"` is a silent no-op at the default
`min_reporting_base = 1` (k>1 never triggers) — raw demographic tag combos ship
believing they're k-protected. Fix: validate these enums at load (refuse
unknown tokens, the sampling_method pattern) and warn when safe-mode has k=1.

**I2/I3/I4 FIXED 2026-08-06.** All three are one defect wearing three coats: a
Settings cell the loader could not read silently became the DEFAULT — the value
the operator was overriding. The fix closes the whole class at the one place
that already refuses on junk statistical settings (`validate_config_settings`),
rather than the six cells the findings name.

**What now refuses at load, naming the cell and quoting its value:**
- **Every numeric setting** (`.TABS_NUMERIC_SETTINGS`, 26 keys — the M9
  dashboard ten plus `alpha`, `alpha_secondary`, the bases, all five
  `decimal_places*`, the four `ranking_*`, `index_summary_decimal_places`,
  `population_size`, `wave_order`). The raw cell is tested, because the parsed
  value cannot tell junk from a real default.
- **Every Y/N toggle** (`.TABS_LOGICAL_SETTINGS`, 40 keys — everything read
  through `safe_logical`, `apply_weighting` among them).
- **The two Y/N settings read as strings** (`.TABS_FLAG_SETTINGS`):
  `generate_stats_pack` and `create_index_summary`, both of which gate on an
  exact `== "Y"` downstream and are now canonicalised to `"Y"`/`"N"` in
  `build_config_object`, so `TRUE`/`yes`/`1` in the cell all mean yes. This is
  C3's vocabulary (`.TABS_FLAG_TRUE_TOKENS`/`.TABS_FLAG_FALSE_TOKENS`), moved to
  `type_utils.R` beside `safe_logical` — which now reads the same two vectors,
  so the converter and the validator cannot drift.
- **`population_size` ≤ 1**, which the template already documents as invalid
  ("whole number greater than 1, or leave blank").
- **All four qualitative dials** (`.TABS_QUAL_ENUMS`), normalised
  case-insensitively first (`"Block"` → `"block"`, `"Must Read"` →
  `"must_read"`) and refusing only on a genuinely unknown word. The finding
  names two dials; `qual_confidentiality_mode` and `qual_noteworthy_default`
  are the same enum family and fell through the same way (a mis-cased `"Full"`
  silently shipped no text at all), so they were fixed with them.

**A blank cell still means "use the documented default", silently** — including
`""`, whitespace, and the literal string `"NA"` (readxl keeps that as text).
That is what keeps every existing config byte-identical.

**The warning I4 asked for.** `qual_demographic_cuts = "safe"` with
`min_reporting_base = 1` prints a boxed console warning rather than refusing —
it is a legitimate operator choice, and it only fires when a `qual_workbook` is
actually configured. The claim in the box was verified by execution: with four
respondents of whom one is the only "Admin + <1yr" person, `safe` at the default
k=1 ships `Dept=Admin, Tenure=<1yr` on that comment; at k=2 both tags are
withheld.

**Regression risk, stated plainly:** a config carrying an unreadable value in
any of these ~70 cells now stops instead of running. Such a config is today
silently running the *other* way — unweighted, uncorrected, stats-pack-less or
with a confidentiality gate open — so the refusal surfaces a real defect; but it
is a behaviour change on live configs. Verified against every shipped artefact:
the generated `Crosstab_Config_Template.xlsx`, the demo config, and all four
`Parity_*` configs load and validate clean. Live client configs (CCPB, VAS —
OneDrive, outside the repo) were **not** checked and should be opened once.

Files: `lib/crosstabs/crosstabs_config.R`, `lib/type_utils.R`,
`lib/crosstabs/data_setup.R` (vocabulary moved out, no behaviour change).
Tests: 227 assertions appended to `test_config_contract.R`, including two drift
guards that parse `build_config_object` and fail if a new toggle or numeric
setting is added without joining its list, and one that reads
`qual_island_builder.R`'s own `QUAL_*` constants so the config cannot refuse a
token the island accepts. **16 of the 17 new blocks were proved failing against
the pre-fix code** by revert-run-restore (30 assertion failures + 9 errors); the
block that passed pre-fix is the byte-identical-behaviour guard, which is the
point. Gates after: tabs R **4,000 / 0 / 0 / 0** (3,773 + exactly the 227 new
assertions), **29** JS suites green, project-root **571 pass / 3 fail** at its
documented baseline.

**Not done (same class, recorded):** the non-qual enum settings —
`outlier_method`, `dashboard_sort_gauges`, `chart_palette_preset` — still fall
through to their defaults on an unknown token. `alpha_default` already refuses
case-insensitively, but only when `alpha_secondary` is set.

**I5. FPC missing from two paths that sit beside corrected rows — FIXED 2026-08-06 (Job I-stats).** NET POSITIVE
(`standard_processor.R:1054-1091`) and composites (`composite_processor.R:871`)
never pass `fpc_mul` — on a census project category rows correctly lose
letters, NET POSITIVE and composite rows keep them. (Extends the known
I1-residual list, which named composites/ranking but not NET POSITIVE.)
Related, deliberate-looking but undocumented: NET POSITIVE letters test the
top box only, not the printed top-minus-bottom (header calls it "Option A").

**FIXED 2026-08-06.** Both now build their multipliers through the same
`build_fpc_multipliers()` + `resolve_column_populations()` pair every other row
type uses, so there is still one definition of the correction.
- **NET POSITIVE** takes `fpc_mul` into its `test_data`, which
  `run_net_difference_tests()` already reads. On a four-column fixture the fix
  simultaneously **removes** a letter (the census column stopped lettering a
  20-point gap it had no sampling error to test) and **adds** one (a corrected
  column crossed the Bonferroni-adjusted threshold, p 0.008842 → 0.003838).
- **Composites** pass `fpc_mul1`/`fpc_mul2` to `weighted_t_test_means()`.
  `n_actual` is the composite's own unweighted base per column — respondents
  with a scoreable value — matching the definition `build_fpc_multipliers()`
  documents. The subset resolution that had been copy-pasted for `idx_a` and
  `idx_b` is now one helper (`composite_subset_indices()`), so the bases the
  correction reads and the rows each test reads cannot be different people.

**The related item was documented, then answered and CHANGED — 2026-08-06,
later the same day.** It was written up as a standalone brief
(`NET_POSITIVE_SIG_QUESTION.md`, commit 94e29cc7), handed to a fresh session,
and decided: the NET POSITIVE row's letters now test the printed
top-minus-bottom, through the weighted mean of a per-respondent ±100 score
(+100 top box, −100 bottom box, 0 otherwise) — the same device the NPS Score
row uses. The key fact that settled it: the score's variance,
`t + b − (t − b)²`, IS the correlated-difference variance, so the multinomial
covariance is carried by the score and no bespoke statistics are needed.
Decision, derivation, before/after letters and what was built:
`NET_POSITIVE_SIG_DECISION.md`. On the parity fixture it removes one letter
(two columns printing the identical +20 no longer letter each other) and adds
one (two columns with the identical 20% top box, printing +20 against −60, now
do).

**I6. Chi-square row: display-rounded weighted counts, no design correction,
not weight-scale invariant — FIXED 2026-08-06 (Job I-stats).** `standard_processor.R:1308-1314` reads counts
back out of formatted display rows — the one place display rounding feeds a
statistical decision; population-projected weights manufacture significance
(executed: ×10 weights flip p 0.315→0.0015). Also the single significance path
with no known-answer test anywhere in the suite.

**FIXED 2026-08-06, at the brief's stated minimum: unrounded counts +
effective-n scaling + a known-answer test.** All three defects were reproduced
by execution first.
- **Unrounded counts.** New `boxcategory_count_matrix()` recomputes the
  BoxCategory counts through `calculate_boxcategory_counts()` — the same
  function that produces the published Frequency rows — and the orchestrator
  passes that matrix in. Executed: a weighted table whose true counts were
  28.4/21.6 shipped **p = 0.2301** where its own numbers give **p = 0.1738**.
- **Effective-n scaling.** Each column's counts are multiplied by
  `effective base / weighted base` (`chi_square_design_scales()`) before
  anything reads the matrix — before the sparse-category filter and the
  expected-frequency checks, so all three describe the same table. This is a
  first-order design correction and it makes the test invariant to the scale of
  the weights, which is the runaway the review found: executed, the same design
  at ×10 weights gave **χ² 4.0 → 40.0** and now gives 4.0 either way.
- **Known-answer tests.** The 2×2 and a 3×2 are checked against base R's
  `chisq.test(correct = FALSE)`, closing the I12(d) blind spot.

**Both corrections are exactly inert on an unweighted run** (integer counts,
effective base == weighted base == unweighted base), so unweighted workbooks are
unchanged — verified by an explicit byte-identical test. Weighted chi-square
rows do change, always downward: a weighted design never carries more
information than the people interviewed.

**A third behaviour change, found in the adversarial pass and kept.** Because the
counts are now recomputed rather than read off the published rows, the
chi-square row no longer depends on `boxcategory_frequency` being switched on.
Executed: with `boxcategory_frequency = N` the pre-fix engine printed **no
chi-square row at all**; it now prints the same χ² = 3.60, p = 0.0578 it prints
with the toggle on. That is the M8 principle (a display toggle must not decide a
statistical result) arriving here for free — but a config with
`boxcategory_frequency = N` and `enable_chi_square = Y` **gains a row it never
had**. Pinned by a test.

**Recorded, not fixed (adjacent, found while here):** a config missing
`test_net_differences` errors inside `validate_net_difference_requirements`
(`!NULL`) rather than defaulting — caught by the caller's `tryCatch` and printed
as one warning line. `build_config_object` always sets the key, so it does not
bite a real run.

**I7. Union workbooks: one ResponseID in two member sheets = duplicate records
sharing one idx/rid — FIXED 2026-08-06.** The per-sheet integrity gate can't see cross-sheet
duplicates (`qual_unions.R:129-160`); executed: base inflated, same reader
token on both records. Fix: extend the dup check across union members.

**FIXED 2026-08-06.** New `qual_check_union_duplicates()` runs inside
`qual_apply_sheet_unions()` **before** anything is concatenated, and refuses
(`DATA_QUAL_UNION_DUPLICATE_ID`) naming the union, the ResponseID and both
sheets. It collects every offending union and id first, so one pass over the
workbook fixes them all — the principle `qual_check_workbook_integrity` already
follows, and it refuses rather than warning for the same reason that gate does:
this is the same defect, just crossing a sheet boundary.

**Reproduced by execution, and it is worse than recorded.** Respondent 54 in
both the Detractor and Promoter sheets gave a union of **3 records for 2
respondents** — and the two records share not only the `rid` but the **`idx`**,
so they resolve to the *identical* reader-mark key `QUAL_Q79#@<rid>`.
Shortlighting or highlighting one silently marks both, and `collectPool`'s
`byRef` index can only reach one of them. The respondent is also simultaneously
a Detractor and a Promoter in the band view, so the segmented report
contradicts itself.

**Deliberately narrow:** the check is per-union. The same respondent answering a
union member *and* an unrelated comment sheet is ordinary (one person, two
open-ends) and does not refuse; nor does the same respondent appearing once in
each of two different unions. Blank IDs are the per-sheet gate's business and
are not treated as duplicates of each other.

Files: `lib/qual_unions.R`, `lib/qual_report.R` (passes `module` through for the
refusal banner). Tests: 7 blocks appended to `test_qual_unions.R`, **6 proved
failing** against the pre-fix code by revert-run-restore; the 7th is the
no-regression guard that a clean union still reassembles unchanged.

**I8. Docs describe the retired classic report as current — FIXED 2026-08-06 (Job D, commit e2b2ef4e).**
`04_USER_MANUAL.md:481-511`, `02_TABS_OVERVIEW.md:93-107`,
`07_EXAMPLE_WORKFLOWS.md:744-750` describe Summary/Crosstabs/Added
Slides/Pinned Views tabs and an "Add Slide" button; the shipping v2 report has
Dashboard/Group overview/Story/Crosstabs/Differences/Report. A new user hunts
for UI that doesn't exist.

**I9. AddedSlides documented with wrong column names — FIXED 2026-08-06 (Job D, commit e2b2ef4e).** Docs say
`slide_id/title/content`; the loader requires `slide_title/content`
(`crosstabs_config.R:844-855`) and silently skips otherwise — slides built
from the docs never appear.

Verified 2026-08-06: `06_TEMPLATE_REFERENCE.md` now documents
`slide_title` / `content` / `display_order` / `image_path`, matching
`load_qualitative_sheet`'s `required_cols`. Both 06 and
`07_EXAMPLE_WORKFLOWS.md` additionally state that the sheet is **not wired
into the shipping v2 report** and point at the in-browser "Added slides"
card instead — which is the honest position: `load_added_slides` is defined
and called from nowhere.

**I10. Template Reference drift.** Three weighting settings documented as
"Required: Yes" were removed from the template as never-read — but
`weight_validators.R:178-180` *does* read them (removal comment and validator
contradict; reconcile). ~25 shipped settings undocumented in the core docs
(incl. `population_size`, `patterns_banner`); Comments-sheet columns
Banner/Headline and the `_BACKGROUND`/`_EXECUTIVE_SUMMARY` convention
undocumented; four ranking settings documented but absent from the template;
documented `AreaSummary` column absent from the template.

**FIXED 2026-08-06 (Job D, commit e2b2ef4e).** All five parts verified in the
docs on 2026-08-06: the three weighting settings now read "Required: No — not
included in the generated template… still read if added by hand", which
resolves the contradiction with `weight_validators.R` by documenting rather
than restoring (restoring would change the template's shape);
`population_size` and `patterns_banner` are documented; the Comments sheet's
`Banner` and `Headline` columns and the `_BACKGROUND` / `_EXECUTIVE_SUMMARY`
convention are documented; the four `ranking_*` settings are documented with
the same "not in the generated template" note; and `AreaSummary` is documented
as **RETIRED** rather than as a live column.

**I11. Dead-but-whitelisted settings defeat the typo warning — FIXED 2026-08-06.** `heatmap_colour`
(re-whitelisted in 2026-08 specifically to cure its silent no-op — still a
no-op), `output_folder`/`output_file` (read nowhere; an operator misspelling
`output_subfolder` gets no warning and output lands in the default folder),
plus the classic-report leftovers (`embed_frequencies`, `show_charts`,
`dashboard_metrics`, `dashboard_sort_gauges`, `*_descriptor`,
`include_summary`, `dashboard_green_net/amber_net/green_custom/amber_custom`).
Remove from the whitelist or wire to consumers.

**FIXED 2026-08-06.** The finding offers both dispositions, and both were used:
`heatmap_colour` is **wired**, the other fifteen are **retired**.

**The audit.** Every candidate was checked for a real consumer — a read of
`config_obj$<name>` outside the loader — repo-wide, not just in `modules/tabs/lib`.
Result: `dashboard_scale_mean/index` and the `green/amber_mean` and
`green/amber_index` pairs are live (`data_layer_writer.R build_dl_dashboard`);
everything else in the list reads nothing. **`priority_metric` is a sixteenth
member the finding does not name** — its `ai_extraction.R` namesake is an
unrelated per-question derived value, not this setting — and it was retired with
the rest.

**`heatmap_colour` is now wired.** New `TR.charts.heatOf()` (`23_render.js`) is
what the heat tint reads; `data_layer_writer.R` carries the field on the island
**only when the config sets it**, so an island from a config that never mentions
it is byte-identical and every existing report tints on `brand_colour` exactly
as before (verified: the parity harness regenerated clean). **The docs were
wrong in two ways and are corrected:** `06` and `09` both said the tint defaults
to `accent_colour` — it never did, it has always been `brand_colour` — and `09`
still described the retired classic report's alpha ramp. *Visible change: a
config that sets `heatmap_colour` gets a different tint on the next
regeneration. That is the point, and it is what the re-whitelisting intended.*

**The other fifteen are retired**, using the mechanism the classic-report
retirement already built: named and answered by `announce_retired_settings`
(which the typo warner deliberately skips), off `TABS_KNOWN_SETTINGS`, out of
`build_config_object`, out of `.TABS_NUMERIC_SETTINGS` / `.TABS_LOGICAL_SETTINGS`,
off the generated template, and out of the docs. Each message names the live
setting that replaced it where one exists — `output_folder` → `output_subfolder`,
`output_file` → `output_filename`, `include_summary` → `show_dashboard`. The two
path settings say "is not read by Tabs and never has been" rather than claiming
a retirement they never earned.

**One trap, and it is the kind this review exists to catch.**
`check_preflight_dashboard_scales` was gated on `include_summary`. Retiring that
setting makes `config$include_summary` NULL, so the gate would have returned
early **forever** — silently killing the green-vs-amber ordering check for the
mean and index pairs, which are live. The validator is now unconditional (its
pairs always have defaults, so there is always something to check) and the two
retired pairs are dropped from it, so it no longer warns about the ordering of
two numbers nothing reads.

**Also cleaned, or the fix would have announced itself forever:** the demo config
carried nine of the retired names and `generate_demo.R` still *wrote*
`html_report` — Job D removed that row from the shipped workbook without
updating the generator, so a regeneration would have reintroduced it. Both are
fixed and the demo now loads silently. The parity fixture generator carried
`include_summary` and `show_charts`; removed.

**Behaviour changes, stated plainly:** a live config carrying any of the sixteen
names now prints a boxed RETIRED notice (the run continues, nothing is refused);
a config that sets `heatmap_colour` changes its heat tint on regeneration; and
the ordering warning for the net/custom thresholds is gone. Live client configs
(CCPB, VAS — OneDrive, outside the repo) were **not** checked, the same caveat
the I-batch recorded; the likely effect there is a RETIRED box naming rows that
should be deleted.

Verified end-to-end by loading configs through `load_crosstabs_config`: the
shipped demo is silent, while a config carrying `output_folder`,
`include_summary` and a genuine typo (`show_pecent_column`) prints the RETIRED
box for the first two — naming `output_subfolder` and `show_dashboard` — and the
typo warning for the third.

Files: `lib/crosstabs/crosstabs_config.R`, `lib/data_layer_writer.R`,
`lib/generate_config_templates.R`, `lib/validation/preflight_validators.R`,
`assets/js/23_render.js`, `templates/Crosstab_Config_Template.xlsx`,
`docs/06_TEMPLATE_REFERENCE.md`, `docs/04_USER_MANUAL.md`,
`docs/09_COLOUR_REFERENCE.md`, `examples/tabs/demo_survey/generate_demo.R` + its
config, and the parity fixture generator. Tests: 8 new blocks in
`test_config_contract.R`, 1 in `test_data_layer_writer.R`, 2 in
`test_validation.R`, 4 checks in `audit_stats_tests.mjs`; the heatmap wiring and
the validator re-gate were each proved failing against the pre-fix code.
Gates after: tabs R **4,490 / 0 / 0 / 0**, **31** JS suites green, project-root
at its documented 3-failure baseline.

**I12. Test blind spots (where a real bug would ship green) — FIXED 2026-08-06 (Job T).**
(a) The main qual JS suite tests a pre-I20 island shape — 86 fixtures, zero
`rid`; the rekey suite has rid but no band/suppressed/demos; the shape
production actually emits is exercised by no JS test.
(b) Index_Summary values are never asserted (only "sheet exists");
`build_index_summary_table` and four sibling functions have zero direct tests.
(c) `27d_diffs.js` (Differences view) and `ai_insights_step.R` (freshly
refactored, degrades to console warnings by design) have no behavioural tests.
(d) Chi-square: no known-answer test (see I6).

**FIXED 2026-08-06.** (d) had already landed with Job I-stats (`test_stats_semantics.R`
checks a 2×2 and a 3×2 against base R's `chisq.test(correct = FALSE)`); (a), (b)
and (c) were built here. `ai_insights_step.R` — the second half of (c) — was
**not** done; see "Not done" below.

**A test written to cover a blind spot proves nothing by passing.** Each new
suite was therefore mutation-checked: the production code was deliberately broken
in the ways the tests exist to catch, and the suite had to go red. 20 mutations on
`27d_diffs.js`, 2 on the qual path, 1 on the island builder — all caught. Four
mutations survived the first draft of the Differences suite (the mean-path soft
gate, the no-difference gate, the group-side base gate, and column-name escaping);
those were real holes and the suite was widened until each was caught. The one
mutation worth recording: reverting `markRef` to its pre-I20 behaviour leaves
`qual_tests.mjs` — the suite finding (a) names — **completely green**, which is the
blind spot demonstrated rather than asserted.

**(a) The qual island — a fixture generated BY R, not transcribed from it.**
A hand-written JS fixture is a transcription, and a transcription can drift back
out of shape exactly as this one did. So the fixture is now built by the real
builder and committed as JSON, on the parity-harness pattern:
`tests/fixtures/qual_island/generate_qual_island.R` runs `qual_build_data_qual()`
and writes `qual_island.json`; `test_qual_island_fixture.R` rebuilds that island
in memory on every run and fails if the committed JSON is stale, so a deliberate
change to the builder goes red until the fixture is regenerated; and
`qual_island_shape_tests.mjs` reads the committed JSON. The fixture carries, on
one island, everything the old fixtures lacked: a `rid` on every record, `band`
on a split-bearing question, `suppressed` on three records (two tier-0 under
`verbatim_scope = "noteworthy"`, one tier-2 hide-marked), `demos` on every
record, all four tiers, and one respondent present in **both** questions under a
single rid. Two shape details a hand-written fixture would have hidden and this
one carries: an un-themed record's `themeVals` arrives as a JSON **array** `[]`
(R serialises an empty named list that way), and a mark on a withheld comment is
counted as `withheld`, not as an orphan.

**(b) Index_Summary — the numbers, not the sheet name.** Known-answer tests for
all five untested functions, asserting which rows are metrics (a Top-Box `Sig.`
letters row must never be mistaken for the percentage beside it), how labels are
built, what a section header does to the rows around it, and — the point of the
finding — that each value lands in the column it was computed for, end to end.

**(c) The Differences view.** `27d_diffs.js` shipped with three hooks explicitly
exposed "for the differences gate test" and no such test. There is one now, over
the real statistics module and real per-respondent microdata for the mean half:
classification exclusion, "the rest" and the two cases where it cannot be
computed, the tautological 0%/100% drop, scale-point suppression, the 95% vs
95%+80% split and its ranking, the bidirectional mean test with both base gates
and the disclosure floor, and the wording of every sentence a client reads.

**One real defect found, and fixed (the insurance paying out).** Writing (b)
surfaced it: `organize_by_composite_groups` indents a composite's source
questions by two spaces — that indent is the Index_Summary sheet's **only**
nesting cue, because `write_index_summary_sheet` writes the label string verbatim
into column 1 and applies no indent style — and `format_summary_for_excel` then
ran a blanket `trimws()` straight through it. Every source question therefore
landed flush against the margin, indistinguishable from an unrelated standalone
question, and the composite grouping the code goes to some trouble to build was
invisible in the deliverable. Verified by execution before and after, in a real
`.xlsx`: before, `[Q5 - Source five]` sat level with `[Q9 - Unrelated nine]`;
after, `[  Q5 - Source five]` nests under `[→ Engagement Index (Q5, Q6)]` while
Q9 stays flush. The fix trims *around* the indent rather than through it, and the
two tests that catch it were proved failing against the pre-fix code. Display
only — no number changes anywhere.

**A second defect found and fixed, 2026-08-06 (same session, after the job).**
`ExcludeFromSummary` (Composites sheet) was read with a bare
`toupper(trimws(x)) == "Y"`, so `"Yes"` meant NO and a composite the operator
had asked to hide **shipped to the client anyway, without a word**. It was not
among C3's six gate columns. It is now normalised at its single load site
(`load_composite_definitions`) through the same `normalise_flag_column()` and
the same vocabulary as every other gate column — `Y`/`YES`/`TRUE`/`T`/`1` mean
hide, `N`/`NO`/`FALSE`/`F`/`0` and blank mean keep, anything else refuses.

**One thing had to be fixed with it, or the refusal would have lied.** The whole
body of `load_composite_definitions` sits inside a `tryCatch` whose handler
re-labels any error as `IO_READ_ERROR` — "Error Loading Composite_Metrics Sheet…
verify the Excel file is not corrupted". A `CFG_INVALID_FLAG_VALUE` refusal
raised inside it was therefore caught and rewritten, sending an operator who had
typed one bad cell off to hunt a corrupt file. The handler now re-signals a
`turas_refusal` untouched and only wraps genuine read errors.

Files: `lib/composite_processor.R`. Tests: 4 blocks appended to
`test_composite_processor.R` (**15 assertion failures** against the pre-fix code
by revert-run-restore), plus the reader-end vocabulary block in
`test_summary_builder.R`.

**Not done:** behavioural tests for `ai_insights_step.R`, the second half of
(c). It degrades to console warnings by design and its failure mode is a missing
insight rather than a wrong number, so it is the lowest-value item in I12 and was
left. That is the whole of what this job leaves open.

Files: `lib/summary_builder.R` (the one fix). Tests: 88 assertions in
`test_summary_builder.R` (56 new; the 2 indent ones proved failing pre-fix), a new
`test_qual_island_fixture.R` (19), a new `tests/fixtures/qual_island/` (generator
+ committed island), a new `qual_island_shape_tests.mjs` (23 checks) and a new
`diffs_tests.mjs` (32 checks). Gates after: tabs R **4,373 / 0 / 0 / 0**
(4,277 at this job's start),
**31** JS suites green (29 + the two new), project-root at its documented
3-failure baseline.

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

**Status 2026-08-06: all three open CRITICALs (C1, C2, C3) have now landed and
every deploy condition above is lifted. The IMPORTANT and MINOR lists are
untouched — I1–I12 and the M-tier remain open.**

The statistical core's ordinary path is genuinely trustworthy: 3,733 R + 28 JS
gate assertions, hand-derived known answers, a cross-engine parity fixture,
and six adversarial fresh-context reviews that confirmed the letter/test
machinery, weighting, FPC threading, tracking honesty and qual privacy gates
hold under attack. The three wrong-number/wrong-ship CRITICALs found this
session (letters shifting past an empty column, allocation weight
misalignment, the comment report's microdata bypass) are fixed with
failing-first regression tests.

Conditions: (1) ~~do not ship a v2 report from a counts-only or row-%-only
config until C1 lands~~ — **C1 landed 2026-08-06; this condition is lifted**;
(2) ~~do not treat the v2 HTML as disclosure-safe for
sub-k audiences until C2 lands~~ — **C2 landed 2026-08-06; this condition is
lifted for the base row, the exports and the explainer. The audience-level
count under a reader's own filter is still stated by design (see C2's
"deliberately left alone")**; (3) ~~normalise the Y-flag columns (C3) before
the next hand-built config, or lowercase `y` cells will silently drop
questions/banners with preflight approving~~ — **C3 landed 2026-08-06; this
condition is lifted. Note the behaviour change: an unreadable value in
Include/UseBanner/BannerBoxCategory/CreateIndex/ShowInOutput/ExcludeFromIndex
now refuses at load instead of being read as "no".** For anonymity-critical work also
take I4 (confidentiality dials fail open) and note the F3 fix means
regenerated comment reports now honour the confidential ship.

The documentation answer to Duncan's question is **yes, with one afternoon of
corrections**: a new project can be run from the docs alone (verified by
execution), but I8/I9/I10 will each cost a future operator real time, and two
of them (AddedSlides columns, report-tab descriptions) describe things that
are simply false.

---

## Handover — running the fix jobs from this doc alone

Each job below is sized for one fresh session (Opus 4.8, high effort, with the
fable-method skill, unless noted). Brief the session with THIS document only —
do not reuse the review session's context.

**Shared context for every job:**
- Baseline at handover, main @ 4ccd6291: tabs R suite **3,733 / 0 / 0 / 0**
  (`Rscript tools/run_all_tests.R --module=tabs`, or
  `testthat::test_dir("modules/tabs/tests/testthat")` — both work now), 26 JS
  suites in `modules/tabs/lib/html_report_v2/tests/` + 2 in
  `modules/tabs/tests/js/`, all green. Anything below that is a regression.
- Every fix: write the test first and **prove it fails against the pre-fix
  code** (revert-run-restore). No `stop()` — TRS refusals with console output
  (CLAUDE.md). Annotate this doc's finding when done.
- Do not push; Duncan verifies via `launch_turas()` and regenerates
  deliverables himself. Run `git status` first and commit only your own files.

**Job C1 — island stat labelling (CRITICAL C1). DONE 2026-08-06** — see the
annotation under C1 above. Baseline for the next job is therefore tabs R
**3,742 / 0 / 0 / 0** and **29** JS suites (the new `stat_label_tests.mjs`
joins the 26 + 2).

**Job C2 — sub-k base masking in v2 (CRITICAL C2). DONE 2026-08-06** — see the
annotation under C2 above. It was wider than briefed (all three base rows, the
invertible ±pp margin and coverage note, and the confidence explainer naming
the withheld group in prose). Gates are unchanged for the next job: tabs R
**3,742 / 0 / 0 / 0** and **29** JS suites — the 21 new checks were appended to
`disclosure_tests.mjs` rather than added as a new suite.

**Job C3 — Y-flag normalisation (CRITICAL C3). DONE 2026-08-06** — see the
annotation under C3 above. It was wider than briefed: two load sites, not one
(the Options sheet's `ShowInOutput`/`ExcludeFromIndex` are out of
`load_question_selection`'s reach and normalise in `prepare_options_columns`),
and six columns, not four. `"Yes"`/`"TRUE"`/`"1"` count as yes; an unreadable
token refuses rather than warning — the reasoning, and the departure from this
brief's recommendation, is recorded under C3. Baseline for the next job: tabs R
**3,773 / 0 / 0 / 0** and **29** JS suites (the 31 new checks are a new
`test_selection_flags.R`; the JS suite count is unchanged — C3 is R-only).

**Job I-batch (config honesty — I2, I3, I4). DONE 2026-08-06** — see the
annotation under I2/I3/I4 above. It was wider than briefed by design: the six
named cells are instances of one class, so the refusal now covers every numeric
setting (26), every Y/N toggle (40), the two string-read Y/N settings and all
four qual dials, with the yes/no vocabulary moved beside `safe_logical` so the
converter and the validator share it. Baseline for the next job: tabs R
**4,000 / 0 / 0 / 0** and **29** JS suites (the 227 new checks are appended to
`test_config_contract.R`; the JS suite count is unchanged — this batch is
R-only). Note the behaviour change: an unreadable value in any of those cells
now refuses at load instead of being read as the default.

**Job I-stats (I1, I5, I6 — statistical semantics). DONE 2026-08-06** — see the
annotations under I1, I5 and I6 above. All three landed at or above the brief:
NPS rows test (and print an SD for) the ±100 buckets, the FPC reaches NET
POSITIVE and composites, and the chi-square row reads unrounded counts scaled to
each column's effective base with known-answer tests against base R.

**Two things a next session needs to know.**
1. **Duncan has one call to make.** The NPS Standard Deviation row moves from the
   0–10 rating scale to the ±100 bucket scale (81.0 where it printed 1.9). It is
   the coherent choice — it is the SD of the statistic printed above it, and it
   is what the v2 report's own confidence interval has always used — but it is a
   visible change to a published figure and it is one line to reverse. Nothing
   else in this batch changes a number on a non-census, unweighted, non-NPS run.
2. **The parity fixture's before/after diff was empty, and that was the
   finding.** The fixture carried no NPS question, no NET POSITIVE, no composite
   and no chi-square, so the gate could not have caught any of these three. The
   island regenerated byte-identical — useful as a no-collateral-damage proof and
   nothing more. **Q4, an NPS question, was therefore added to the fixture** with
   hand-derived NPS scores (40 / 20 / −70 / 10, Total −1) and real letters at
   both alphas, and both halves of the gate now assert on it: R-5 in
   `test_cross_engine_stats.R`, plus two runs in `parity_stats_tests.mjs` that
   prove the JS engine rebuilds the same ±100 scores from the published
   distribution. NET POSITIVE, composites and chi-square are still not in the
   fixture — they are covered by unit and end-to-end tests in
   `test_stats_semantics.R`, but not by the cross-engine gate. That is the next
   honest addition to it.

   **Update, 2026-08-06 (NET POSITIVE decision session):** NET POSITIVE is now
   in the fixture. Q5 carries both boxes and a distribution engineered so that
   both failure modes of the old top-box test appear on one table; the gate
   asserts on it in R-6 (`test_cross_engine_stats.R`) and JS-5
   (`parity_stats_tests.mjs`). Composites and chi-square remain outside it.

Files: `lib/cell_calculator.R`, `lib/standard_processor.R`,
`lib/composite_processor.R`, `lib/question_orchestrator.R`,
`lib/stats_diagnostics.R`, plus the parity fixture generator, its two committed
islands and both halves of the parity harness. Tests: new
`tests/testthat/test_stats_semantics.R` (94 assertions; **25 failures/errors
against the pre-fix code** by revert-run-restore, including an end-to-end one
that fails on the NUMBER — the engine shipped χ² 3.64 where the corrected answer
is 2.21 — rather than on a missing function), 4 new R-5 blocks in
`test_cross_engine_stats.R`, 4 new blocks in `test_stats_diagnostics.R`, 2 new
runs in `parity_stats_tests.mjs`.

**Declaration.** Two method notes were added to the stats pack's Assumptions,
each stated only when the run contains that statistic, so a study with neither
gets the Declaration it got before: *NPS significance* (what the letters test,
and that the SD row is on the same scale) and *Chi-square test* (unrounded
counts, plus the effective-base scaling sentence on weighted runs only).

Gates after: tabs R **4,160 / 0 / 0 / 0** (4,000 + 160 new assertions), **29** JS
suites green, project-root at its documented 3-failure baseline. That is the
baseline for the next job.

**Job D — docs batch (I8, I9, I10, M-D..M-G) — Sonnet 5, medium effort.**
Rewrite the report-navigation sections of 04/02/07 against the shipping v2
report; fix AddedSlides columns; sweep the template's settings into 06 (or
soften the "every field" claim); reconcile the `weight_validators.R:178-180`
vs generator-comment contradiction; the M-tier doc/example fixes. Pure
execution against this doc's findings list.

**Job T — test blind spots (I12) — optional but cheap insurance.** rid-bearing
fixtures for the qual JS suite; value assertions for Index_Summary; a
chi-square known-answer test (lands with Job I-stats); behavioural tests for
`27d_diffs.js`.
