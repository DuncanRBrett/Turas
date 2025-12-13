# Changelog

All notable changes to Turas will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- ADR documentation system (`/docs/adr/`)
  - ADR-001: Module structure standard
  - ADR-002: Shared utilities location
  - ADR-003: File size guidelines
  - ADR-004: No hardcoded paths
  - ADR-005: Error handling patterns
- Consolidated shared utilities in `/modules/shared/lib/`
  - `formatting_utils.R` - Number formatting for Excel and text
  - `weights_utils.R` - Weight efficiency calculations
  - `import_all.R` - Single-file import mechanism
  - `find_turas_root()` - Dynamic path resolution
- README.md files for Tabs and Tracker modules
- CONTRIBUTING.md with development guidelines
- Reference implementation `tracker/lib/statistical_core.R`

### Changed
- Tracker module now uses consolidated shared utilities
  - `formatting_utils.R` - Sources from `/modules/shared/lib/`
  - `tracker_output.R` - Uses shared formatting
  - `wave_loader.R` - Uses shared weights utilities
- Tabs module updated
  - `lib/excel_writer.R` - Uses consolidated shared utilities
- KeyDriver module updated
  - `R/00_main.R` - Improved `find_turas_root()` with caching
- Conjoint module updated
  - `R/99_helpers.R` - Sources shared utilities when available
- MaxDiff module updated
  - `R/utils.R` - Sources shared utilities when available
- Test files updated to use consolidated paths
  - `test_shared_weights.R`
  - `test_shared_formatting.R`
  - `test_shared_config.R`

### Removed
- Root `/shared/` directory - fully removed, replaced by `/modules/shared/lib/`
  - `shared/formatting.R` → `modules/shared/lib/formatting_utils.R`
  - `shared/weights.R` → `modules/shared/lib/weights_utils.R`
  - `shared/config_utils.R` → `modules/shared/lib/config_utils.R`
- Updated `find_turas_root()` detection to use `modules/shared` instead of deprecated `shared`

### Documentation
- Added architecture notes to large files documenting target decomposition
  - `tracker/trend_calculator.R` - Target structure documented
  - `tracker/tracker_output.R` - Target structure documented

## [10.0] - Previous Release

### Modules
- **Tabs** - Cross-tabulation and survey analysis
- **Tracker** - Time-series tracking and trend analysis
- **Confidence** - Confidence interval calculations
- **KeyDriver** - Key driver analysis (SHAP, Quadrant)
- **Segment** - Segmentation (K-means, LCA)
- **Conjoint** - Conjoint analysis
- **Pricing** - Price sensitivity analysis
- **MaxDiff** - Maximum difference scaling
- **AlchemerParser** - Alchemer data parsing

### Features
- Excel-based configuration
- Weighted data support
- Statistical significance testing
- Multiple output formats
- Shiny GUI interfaces
