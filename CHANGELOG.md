# Changelog

All notable changes to TURAS are documented in this file.

## [Unreleased]

### Added
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

## [10.1] - 2025-12-28

### Added
- Tracker module v10.1 with extracted metric_types, trend_changes, trend_significance, output_formatting
- Report Hub module for combining HTML reports

### Changed
- All modules updated to TRS v1.0 refusal system
- Guard layers standardized across all 11 modules
