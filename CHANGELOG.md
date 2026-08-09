# Changelog

All notable changes to TURAS are documented in this file.

## [Unreleased]

### Added
- **Tabs: Qualitative tab** — a dedicated view for pre-coded open-end / verbatim
  comments in the v2 interactive report. Coded themes are treated as ordinary quant
  (a multi-mention variable, each mention carrying a 1/2/3 sentiment valence), so
  theme prevalence, theme×banner crosstabs, significance and the global composite
  filter all flow through the existing engine — zero new stats. Reading path: a
  per-question prevalence board (salience, i.e. raised unprompted, with a diverging
  sentiment split that is never sized by volume) plus a verbatim drawer with a
  noteworthy-tier filter, a sentiment filter (only where coded), select-to-highlight,
  a ★ shortlist and an Excel export. A 💬 affordance jumps from a closed / composite
  finding to the open-end comments behind it, in the active cut. Verbatim
  confidentiality has three modes (hidden / redacted / full) and a demographic-cuts
  dial; a disclosure control (`min_reporting_base`) suppresses small-cell detail at
  render and export. Fully additive: with no qualitative workbook configured, every
  report is byte-identical. See `modules/tabs/docs/QUALITATIVE_TAB_BUILD_NOTES.md`.
- **Tabs: Comment Hubs** — named collections over the pool of shortlisted +
  highlighted comments. "★ Your collection" gathers every mark across all questions
  into one place (group by question or theme, honouring the audience filter — so a
  filter to e.g. Master's gives "Master's reactions across questions"). Named reader
  hubs let you file comments into "Master's students", "account issues", etc.; filing
  a comment in a hub is itself a way to save it (shortlist and hub in one), from the
  question list or the collection, via a scalable add-to-hub dropdown. Each hub
  carries a one-line analyst insight and promotes into the Story as a clean exhibit
  (name + finding + coverage + quotes) that exports to PowerPoint. A named hub is
  independent of the audience filter; a hub whose distinct-respondent count is below
  the disclosure threshold keeps its comments but drops the demographic tags.
  Non-destructive by construction — hubs are views over the pool, never containers,
  so no mark is ever mutated. Reader hubs persist per report in the browser
  (localStorage); baking authored hubs into a delivered saved copy (with the
  privacy-clear at save) is the remaining step. See
  `modules/tabs/docs/COMMENT_HUBS_PLAN.md`.
- **Tabs: Finite population correction (FPC)** — for census / full-invite
  studies (e.g. staff or student surveys) where the universe is small and only
  part of it responds. A new `population_size` setting (study total) and an
  optional `Population` sheet (per-banner-subgroup universe sizes) let the v2
  interactive report size its statistics on what was actually sampled: the
  effective base becomes `n·(N-1)/(N-n)`, so confidence intervals **narrow as a
  group's coverage rises** (reaching zero for a full census), significance is
  tested on that corrected base, and a small base that is most of a known group
  is no longer flagged "unstable" (the low-base flag is coverage-aware, showing
  `xx% of N`). Significance and intervals stay consistent because population
  reports' default view is recomputed through the microdata path (badged
  `PUBLISHED · FPC`); FPC is suppressed under a live filter / custom banner,
  where the sub-population's universe is unknown. The design note names the
  response rate and flags non-response as the residual, uncorrectable
  uncertainty. Fully additive: with no population configured, every report is
  byte-identical. Canonical helpers (`calculate_fpc_factor`, `apply_fpc`) live
  in the confidence module and are ported verbatim to the report's JS. See
  `modules/tabs/docs/FINITE_POPULATION_CORRECTION_PLAN.md`. New tests: confidence
  known-answers, data-layer emission, JS gate (`tests/fpc.mjs`), template
  round-trip.
- **Tabs: Allocation question type** — new `Variable_Type = "Allocation"` for
  constant-sum / budget-allocation survey questions (Alchemer `CONT_SUM`).
  Produces mean allocation per option cross-tabbed by banner, with optional
  significance testing. Zero allocations retained as meaningful data.
  Includes full TRS validation and 46 new tests (1833 total).
  `alchemer_to_turas.R` now maps `CONT_SUM` → `Allocation` automatically.
  Survey Structure Template updated: `Single_Mention` dropdown corrected to
  `Single_Response`; `Allocation` added to the Variable_Type dropdown.
- **Brand: Audience Lens v1** — new per-category tab showing focal-brand
  performance across pre-defined audience cuts. Banner table with all
  audiences side-by-side, deck-ready per-audience cards, pair-audience
  scorecards with auto-classified GROW / FIX / DEFEND chips. Pin + PNG
  capture via TurasPins. Audience definitions live on a new `AudienceLens`
  sheet in `Survey_Structure.xlsx`; per-category opt-in via
  `AudienceLens_Use` on the Categories sheet of `Brand_Config.xlsx`.
  TRS validation for malformed filters, unknown columns, and the
  6-audience ceiling. HTML size delta +3.0% on the 9cat fixture.
- Docker deployment support (Dockerfile, .dockerignore, TURAS_ROOT env var)
- Platform health check script (`scripts/health_check.R`)
- Operator quick-start guide (`OPERATOR_GUIDE.md`)
- Root-level README.md for all modules

### Changed
- Decomposed oversized functions across 7 modules to meet <100 line target:
  - CatDriver: `run_categorical_keydriver_impl()` 825 -> 212 lines
  - MaxDiff: `run_maxdiff_analysis_mode()` 531 -> 182 lines
  - Weighting config: `load_weighting_config()` 525 -> 94 lines
  - Conjoint: `run_conjoint_analysis_impl()` 344 -> 223 lines
  - Weighting rim: `calculate_rim_weights()` 342 -> 188 lines
  - Segment: `validate_segment_config()` 330 -> 38 lines
  - Confidence: `write_confidence_output()` 203 -> 48 lines

- **Tabs (v2 report): the published view no longer re-letters significance for
  population reports.** That overlay recomputed the letters from
  display-rounded percentages, and was switched off entirely for weighted
  designs — so a weighted census silently kept uncorrected letters. With R
  correcting at source it was a second, worse computation of the same thing,
  and it is gone. FPC confidence intervals, the corrected interval base,
  coverage-aware low-base flags, the census framing and the PUBLISHED·FPC badge
  are all unchanged. Filtered and custom-banner views keep standard
  significance, as before — a sub-population's universe is unknown.

### Fixed
- **Weighting: a rim run stops claiming convergence it never checked (W2 /
  review H4).** `calculate_rim_weights()` returned `converged = TRUE` with the
  comment "TRUE if we got here". `survey::calibrate(force = FALSE)` does error
  on hard non-convergence, but a bounds-constrained calibration can return while
  a category sits well off its target — the bound binds, calibration stops, and
  the run reported success. The achieved-margin arithmetic already existed but
  was display-only; nothing compared it to the targets. Convergence is now
  decided by `judge_margin_convergence()`, which reads the recomputed weighted
  margins and asks whether any category sits further from its target than
  `margin_tolerance` (new Advanced_Settings key, default 0.5 percentage points,
  refused if unreadable). Missing it prints `CALC_MARGINS_NOT_ACHIEVED` naming
  the worst categories and makes the run PARTIAL rather than PASS; the weights
  are still written, because they are usable — they are simply not the weights
  the config asked for. Unknown margins now count as not-converged rather than
  as success. The judgement is a separate function so the rule is tested
  directly instead of by trying to provoke a particular behaviour out of
  `survey`.
- **Weighting: post-hoc trimming no longer silently unpicks a rim calibration
  (W1 / review C1).** `apply_trimming = Y` capped the weights after the engine
  had finished and put nothing back: `rescale_after_trimming()` existed but had
  zero callers module-wide, and nothing re-raked or re-checked the margins. On a
  rim weight that meant the weights stopped summing to n, the raked margins
  stopped holding, and the diagnostics still reported the raked margins as
  achieved on a GOOD-quality run — every weighted base and percentage downstream
  in tabs was wrong with nothing on the face of the report to show it. Now: a
  rim or rake spec with `apply_trimming = Y` is refused with `CFG_TRIM_USE_CAP`,
  which names `cap_weights` — the setting that reaches `survey::calibrate()` as
  a bound and caps *during* calibration, leaving the margins intact. Design and
  cell weights keep post-hoc trimming, but are now rescaled to their original
  sum so the weighted base does not shrink, with the rescale factor and both
  sums recorded in diagnostics; because rescaling lifts the capped weights back
  above the nominal cap, the run says so on the console
  (`CALC_TRIM_RESCALED_ABOVE_CAP`). The shipped template demonstrated the
  refused combination on its own `wgt_demo` rim row — that example, and the
  trimming guidance in README, USER_MANUAL, TEMPLATE_REFERENCE and
  CONFIG_EXAMPLE, are corrected (including the percentile `trim_value`, which is
  a proportion between 0 and 1, never 95).
- **Weighting: the config template the module generates can now be loaded by the
  module.** `write_table_sheet()` puts a title in row 1, a subtitle in row 2, the
  real column headers in row 3 and per-column help text in row 4; the weighting
  loader called `readxl::read_excel()` with no `skip`, so it took the title as
  the header row. Every generated template — and both templates checked into
  `docs/templates/` — was refused with `CFG_MISSING_COLUMNS` before any weighting
  could run. Hand-built and script-built configs put headers in row 1 and were
  unaffected, which is why nothing caught it: every test fixture and example
  script builds configs that way, and the template tests read at `startRow = 3`
  and never touched the loader. Tabs, brand, confidence and pricing had each
  already solved this locally; the shared `load_config_sheet()` even did it for
  Setting/Value sheets. Weighting simply never adopted it. The table-sheet
  counterpart now lives beside it as `load_config_table_sheet()` in
  `modules/shared/lib/config_utils.R` — it reads row 1 first, scans for the
  header row if the required columns are not there, and drops template help text
  and blank rows — and all five weighting read sites use it. A round-trip test
  fills in a generated template and asserts the loader accepts it; that gate is
  what was missing. Two further defects surfaced once the round trip ran: the
  template's own `wgt_cell` example set `trim_value = 95` for percentile
  trimming when the engine requires a proportion between 0 and 1, and the column
  help text said the same, so anyone following the example got a refusal. Both
  corrected, and the two checked-in template workbooks regenerated.
- **Weighting: a rim target the default method cannot reach now says which lever
  to pull, and zero weights never ship.** The rim engine has supported
  `calibration_method` (`raking` / `linear` / `logit`) via the `Advanced_Settings`
  sheet since v2.0, but no document mentioned it, so a config author had no way
  to know the default could be changed. It matters: raking cannot always reach a
  feasible target that needs a large stretch on one category — a real n=1101 case
  with one region at 8% of sample against a 27% target never converged at any
  bounds or iteration count, while `logit` solved it exactly. Three things
  changed. The refusal that suggests `logit` was never actually reaching users:
  `survey` reports non-convergence as a warning carrying the epsilon and then
  errors with the bare string `"Calibration failed"`, which matched neither
  pattern the handler looked for, so every non-convergence fell through to a
  generic refusal that named no fix. Non-convergence is now recognised and the
  achieved epsilon is quoted. Second, `linear` calibration parked 219 of 1101
  respondents on a zero lower bound (and went negative when unbounded) — a zero
  weight removes a respondent from every base, percentage and significance test
  without appearing as a missing case, so this is now a refusal
  (`CALC_NONPOSITIVE_WEIGHTS`) rather than a warning nothing read. Third,
  `calibration_method` and `weight_bounds` are documented in the README, user
  manual and template reference, along with the corrected
  `convergence_tolerance` default (the docs said 0.01; the code reads 1e-7).
  Both settings now also ship as columns in the generated Excel template —
  `calibration_method` as a raking/linear/logit dropdown — so a config author
  starting from the template is prompted that they exist. In the same pass,
  `force_convergence` was **removed**: it was offered as a Y/N dropdown in that
  template and documented in three places, but no code read it, so setting it
  did nothing and a non-converged run refused anyway. It is not being wired up.
  Weights whose margins do not match the targets are not rim weights, and
  shipping them unmarked is what TRS exists to prevent; to accept a looser fit
  deliberately, raise `convergence_tolerance`, which states how loose in a
  number you can report and leaves the gap visible in the achieved margins.
- **Tabs: significance testing is finite-population corrected — in the Excel
  workbook as well as the report.** For a census / full-invite study the
  interactive report has narrowed its intervals on the FPC-corrected base for a
  while, but the workbook — the deliverable of record — tested on the raw base,
  so Excel and HTML could letter the same pair differently. The correction now
  happens once, in the R engine, and the letters are carried everywhere from
  there. Weighted census studies are corrected for the first time. Two visible
  consequences on a census report: a **fully counted column carries no
  significance letters** (there is no sampling error left to test), and a
  corrected column earns letters more readily than the same data without a
  population configured. `calculate_fpc_factor()`, `apply_fpc()` and the 5%
  coverage floor moved unchanged from the confidence module to
  `modules/shared/lib/fpc.R` so both modules share one definition. With no
  Population configuration nothing changes. See the FPC section of
  `OPERATOR_GUIDE.md`.
- **Tabs: the mean test and the proportion test now size on the same effective
  base.** `calculate_effective_n()` returned an integer-rounded Kish n_eff while
  `calculate_effective_base()` — the one the proportion tests actually ride —
  returned the fraction. On one column of one table an n_eff of 29.6 therefore
  failed a `significance_min_base` of 30 for the % rows and passed it for the
  Average row above them. n_eff is now fractional everywhere in R (rounding
  happens at display), which also aligns R with the v2 report's JS engine.
  *Behaviour change:* mean pairs whose n_eff rounded up across `min_base` stop
  testing, and marginal Welch p-values move slightly. Weighted studies only.
- **Tabs: the interactive report's 80% significance letters now come from R.**
  On a dual-alpha run the published view recomputed the secondary letters from
  the published Frequency row — which is rounded to 0 decimal places — so a
  marginal p≈0.20 pair could earn a letter in the Excel workbook and not in the
  report, or the reverse. The data layer now carries the workbook's `Sig.2` row
  verbatim (`sig2`) and the report renders it, exactly as it already did for the
  95% letters. Reports built before this fall back to the old recompute.
- **Tabs: mean rows show their significance letters in the interactive report.**
  R has always tested means, but the data layer carried no letters for
  mean/Index/Score rows, so the workbook lettered them and the report did not.
  They are now carried at both alpha levels. Letters attach to the headline
  statistic, never to the Standard Deviation row beneath it (the workbook
  appends the `Sig.` row after Std Dev, so a naive label match landed there).
- CatDriver: `run_bootstrap_ci()` call corrected to `run_bootstrap_or()`
- **Segment (classic v1 report): silently-dropped sections.** Production bug
  audit fixed the class where a section vanishes because its analytic crashes
  (swallowed by `tryCatch → NULL`) or a data key/shape mismatches:
  - **Classification Rules** was always missing — `generate_segment_rules()`
    indexed rpart's `yval2` by names it never assigns, and the page builder
    gated on a non-existent key. Fixed (`06_rules.R`, `03_page_builder.R`).
  - **Segment Cards** was always missing — wrong gate key + a card data-shape
    mismatch in the builder. Fixed (`03_page_builder.R`, `03c_section_builders.R`).
  - Variable-Importance / Profile-heatmap / Golden-questions **charts crashed**
    (silently dropped) on a `question_labels` vector that didn't cover every
    variable (`ql[[v]]` on a named vector). Guarded (`05_chart_builder.R`).
  - `generate_headline()` crashed on an all-NA segment variable → Cards dropped
    (`07_cards.R`, now `na.rm` + finite guards).
  - About panel always printed "Average silhouette: 0.000" (wrong key).
  - Segment-assignments file (the segment-as-banner join table for Tabs) could
    carry NA segment names for outlier/NA clusters → now `"Unassigned"`.
  Standard final-mode report verified end-to-end; new regression tests
  (`test_html_robustness.R`, `test_rules.R`); segment suite 1026 pass / 0 fail.
  Audit + verdict: `modules/segment/docs/V1_BUG_AUDIT_2026-06.md`. Exploration
  and combined/multi-method modes have audit-flagged suspects deferred to a
  follow-up pass.

## [10.1] - 2025-12-28

### Added
- Tracker module v10.1 with extracted metric_types, trend_changes, trend_significance, output_formatting
- Report Hub module for combining HTML reports

### Changed
- All modules updated to TRS v1.0 refusal system
- Guard layers standardized across all 11 modules
