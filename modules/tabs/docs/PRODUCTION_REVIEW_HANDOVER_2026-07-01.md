# Production Review — fix handover (continue in a new session)

**Branch:** `feature/tabs-qualitative-tab` (pre-merge to `main`). **Do NOT push/merge** — Duncan
regenerates the reports via `launch_turas` and merges himself.

This continues the independent pre-merge review of the integrated v2 reporting system. Context:
- **Brief (scope + independence rule):** `PRODUCTION_REVIEW_BRIEF_2026-06-30.md`
- **Findings (the 19 confirmed bugs, full detail + file:line + fix):** `PRODUCTION_REVIEW_FINDINGS_2026-06-30.md`

The review was run as an independent multi-agent audit; 19 bugs confirmed (0 tooling-blockers, 9 high),
5 refuted. This session fixed a coherent chunk with tests; the rest is scoped below. **Keep the
independence stance: verify by reading code + running suites, don't trust these notes blindly.**

---

## Done this session (committed on this branch, all suites green)

**Disclosure blocker — comment/identity side + quant sub-k suppression (Duncan eyeballed the comment side):**
- Fail-**closed** when microdata is absent (`21d_disclosure.js` `audienceBase` → null; `audienceTooSmall`
  treats unknown as too-small). Was failing OPEN.
- Source de-identification via a **three-mode** `qual_demographic_cuts` dial (independent of `k`):
  `block` (no tags in source) / `safe` (**k-anonymised** tags — broadest combo covering ≥k, finer
  crossings dropped; `qual_kanon_tags` in `qual_island_builder.R`) / `allow` (internal only).
- Render + export gates: prevalence board, comment drawer, and the comment Excel export all withhold on
  a sub-k audience (`27q_qualitative.js`). Fixed an export path that leaked verbatim text.
- `qual_warn_source_disclosure()` (`qual_report.R`) loud console warning when `k>1` but tags/full-text
  left in the page source; wired in `run_crosstabs.R` (+ a micro-absent fail-closed warning).
- **Quant sub-k column suppression** (`22_model.js` `applyDisclosureSuppression`, at model level so
  crosstab/dashboard/differences + the HTML Copy/Excel/PNG exports inherit it): blanks any column with
  base 1..k-1, strips letters pointing at a blanked column. **This closed Duncan's live n=1 leak** (filter
  → 1 respondent → their answers were showing). `k=1` (off) is a no-op → unprotected reports byte-identical.

**Weighted crosstab significance/intervals (#6 — the E1 inversion):**
- `data_layer_writer.R` serialises the **weighted base + Kish effective base** into published columns
  (weighted reports only; unweighted byte-identical).
- `22_model.js` `sigCell` forms the weighted proportion on the weighted base and sizes the test on the
  effective base (the R weighted z-test); wired into the 80%-letter recompute (now also covers NET rows)
  and `attachIntervals`. Known-answer test: buggy z = −1.77 (B>A) → fixed z = +2.59 (A>B).

**Two more confirmed highs:**
- **K1** Save-copy now persists Patterns/takeout curation (`27f` `snapshot()` + `32_report` `saveCopy`).
- **L1** single-pass template fill (`build_report_v2.R`) — a verbatim containing `{{JS}}` can no longer
  splice the bundle into an island and corrupt the report.

Tests added/updated (all green): disclosure 16, qual 59, composite 10, takeout 26, tracking-nav 10,
portrait 8; R island 54, report 20, join 44, quant-layer 16, data-layer 194, bundler 28.

---

## Outstanding (priority order)

### 1. `#5` — main Excel workbook disclosure coverage  *(finishes the disclosure blocker)*
`excel_writer.R` `write_crosstab_workbook()` has **no** disclosure awareness — the standalone `.xlsx` the
pipeline writes ships every sub-k cut in full. Distinct code path from the HTML (the model-level fix does
NOT reach it). Structure: col 1 = row label, col 2 = row type, **cols 3+ = banner columns**; each column's
base = `question_bases[[key]]$unweighted` (see `write_base_rows`). Fix: when `config$min_reporting_base>1`,
blank the cells + base of any column with unweighted base < k (write a marker, e.g. `n<k`) and add a
cover-sheet note. **Complementary (subtraction) suppression across a banner group is a noted follow-up per
the brief** — the first pass just blanks the small columns. Add a test in `test_data_layer_writer.R` /
`test_excel_output.R`. **Until this ships, do not hand out the standalone workbook for a sensitive survey.**

### 2. `#8` — weighted wave-on-wave significance uses the unweighted base  *(fully scoped)*
`22w_waves.js`: `sdOfScores` computes the Kish `effN` (line ~201) but the sig tests `meanLevel`/`propLevel`
feed the test the **unweighted** base → over-liberal flags on weighted trackers. Plan (Total path only —
segments carry pre-computed `seg_stats`, no per-respondent weights, so they fall back to the plain base):
- add `effNfromWeights(w, n)` + `effBaseOf(waveQ, seg)` (Total: Kish over `waveQ.weights`) + `waves.currentEffBase()`;
- thread `effBase` onto points in `waves.series` + `waves.currentPoint` **and** the current-wave push in
  `27t_tracking.js:266` (check `27u_summary.js` for a parallel push);
- new `sigPair(p)` (weighted: `x = value%/100 * effBase` over `effBase`; unweighted: exact `p.x/p.base`);
- `propLevel`/`meanLevel` use `effBase` not `base`.
Needs a **weighted known-answer test** (effN < base flips a flag). Deferred deliberately — the weighted-
tracker path awaits a real weighted-project run; don't rush sig math.

### 3. `#7` — JS↔R significance-convention parity  *(medium; census/weighted edge cases)*
- **FPC on significance:** `22_model.js` `applyFpcSignificance` re-letters the DEFAULT view of a
  population report; the R engine applies no FPC to sig → on a census the HTML letters differ from the
  Excel. NOTE it's already gated `!weighted`, so this is **census-only**. Decide: port FPC into the R
  z-test, or gate the JS off. (`reportHasPopulation` / `population_size`.)
- **eff_n rounding:** R `calculate_effective_n` rounds to integer; JS uses the float — boundary flips.
- **z constants:** JS `Z_CRITICAL=1.96` / `Z_80=1.2816` vs R exact `qnorm` — hairline boundary divergence.
- **#6 residual:** weighted **mean-row** 80% letters + weighted mean CI still use the unweighted SD path
  (the mean-SD machinery); pairs naturally with this task.

### 4. `#11` — cluster 3/4/5 mediums + lows
- **F1 (high):** `27e_takeout_engine.js:436` odd-one-out mixes raw scale points across scales — an NPS
  (±100) question fabricates a spurious "exception" against 1–5 thresholds. Normalise gaps to per-scale
  units, or exclude NPS/Score from the index-scale scan. (`27f_takeout_data.js:319` `gatherBimodality`
  has the sibling non-1..K bug.)
- **I1 (high):** `24_shell.js` `snapshotLines` harvests headings/paras but not `<th>/<td>`, so a theme
  crosstab pinned to the Story exports to PPTX/PNG with the title but **no numbers**. Harvest table cells.
- **I2 (medium):** `23y_xlsx.js:37` `cell()` coerces numeric-looking strings to numbers for every cell,
  mangling verbatims (`50%`→50, `007`→7). Don't coerce text columns.
- **H (medium):** `28c_composite.js:69` `nextToken()` reissues a freed `composite:N` id, so a new profile
  banner inherits the previous one's saved analyst insight. Monotonic counter, or clear on remove.
- **G2 (high, narrow):** `23za_trend.js:17` current-wave x-key re-parses `project.wave` and ignores
  `wave_order`, colliding with a prior same-year wave on **twice-yearly** trackers. Use the wave's
  `wave_order_key`. (Annual trackers unaffected.)
- **Lows:** `27q_qualitative.js:96` sentiment-split rounding drift (cosmetic); `microdata_writer.R:174`
  unescaped regex on the question code (`fixed`/escape it); `23z_charts.js:43` repel clamp (cosmetic).

---

## Merge gate

- **Disclosure (the hard blocker):** comment side + quant HTML suppression **done**; `#5` (Excel workbook)
  is the last piece before it's fully closed.
- **Weighted/census stats:** `#6` done (crosstab); `#8` (wave sig) + `#7` (FPC/parity) remain — block for
  weighted/census deliverables.
- The cluster-3/4/5 mediums are fix-forward, not individually merge-blocking.

## How to verify
- JS (from `modules/tabs/lib/html_report_v2/`): `node tests/{qual,disclosure,tracking_nav,composite,portrait,takeout}_tests.mjs`.
- R: `Rscript -e 'testthat::test_file("modules/tabs/tests/testthat/<f>.R")'` per file (test_dir on the
  parent errors — tests live in `tests/testthat/`). Full `test_dir` is slow (~50s); run the changed files.
- **Generated HTML is verified by Duncan via `launch_turas` — never `preview_start`, never headless-run
  the pipeline on OneDrive data.** Regenerate the SACS report (`min_reporting_base: 10`) to eyeball
  disclosure; a weighted project (e.g. CCS) to eyeball the weighted stats.
