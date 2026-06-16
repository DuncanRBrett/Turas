# Changelog

All notable changes to TURAS are documented in this file.

## [Unreleased]

### Added
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
