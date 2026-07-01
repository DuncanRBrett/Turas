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

### Fixed
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
