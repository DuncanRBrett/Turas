# Report Hub Module - Script Inventory

> Last updated: 2026-03-08

## Overview

The Report Hub module combines multiple Turas HTML reports (tracker, crosstabs, confidence, etc.) into a single unified HTML document with two-tier navigation, a front page with report cards, unified pinned views, and DOM namespace isolation to prevent cross-report conflicts.

## Script Inventory

| File | Lines | Purpose | Status | Quality |
|------|------:|---------|--------|:-------:|
| `00_main.R` | 174 | Main orchestration: `combine_reports()` entry point | Active | 5/5 |
| `00_guard.R` | 368 | TRS v1.0 guard layer: config validation, path resolution | Active | 5/5 |
| `01_html_parser.R` | 557 | Extracts CSS, JS, content panels, metadata from HTML reports | Active | 4/5 |
| `02_namespace_rewriter.R` | 775 | Rewrites DOM IDs and CSS selectors to prevent cross-report conflicts | Active | 4/5 |
| `03_front_page_builder.R` | 205 | Builds overview page with report cards and summary statistics | Active | 4/5 |
| `04_navigation_builder.R` | 106 | Generates two-tier navigation HTML (L1: reports, L2: sub-tabs) | Active | 4/5 |
| `07_page_assembler.R` | 325 | Assembles final HTML document with all CSS, JS, and content | Active | 4/5 |
| `08_html_writer.R` | 58 | Writes combined HTML to output file | Active | 5/5 |
| `run_report_hub_gui.R` | 589 | Shiny GUI launcher for interactive report combining | Active | 4/5 |
| `lib/generate_config_templates.R` | NEW | Professional Excel config template generator | Active | 5/5 |
| `lib/validation/preflight_validators.R` | NEW | 14 pre-flight cross-referential checks | Active | 5/5 |

## JavaScript Assets

| File | Lines | Purpose | Status | Quality |
|------|------:|---------|--------|:-------:|
| `js/hub_navigation.js` | 179 | Tab switching logic for two-tier navigation | Active | 4/5 |
| `js/hub_pinned.js` | 854 | Pinned views management (save, restore, navigate) | Active | 4/5 |
| `js/hub_id_resolver.js` | 12 | Scoped DOM query helpers for namespaced IDs | Active | 5/5 |

## CSS Assets

| File | Lines | Purpose | Status | Quality |
|------|------:|---------|--------|:-------:|
| `assets/hub_styles.css` | 643 | Hub-specific styling (navigation, cards, layout) | Active | 4/5 |

## Tests

| File | Lines | Purpose | Status | Quality |
|------|------:|---------|--------|:-------:|
| `tests/testthat/test_report_hub.R` | 1900 | Unit and integration tests for all pipeline steps | Active | 4/5 |

## Pipeline Flow

```
00_main.R::combine_reports()
  |-> 00_guard.R              Validate config (Settings, Reports, CrossRef sheets)
  |-> lib/validation/         Pre-flight cross-referential checks
  |-> 01_html_parser.R        Parse each HTML report (CSS, JS, panels, metadata)
  |-> 02_namespace_rewriter.R Rewrite DOM IDs/CSS selectors per report_key
  |-> 03_front_page_builder.R Build overview page with report cards
  |-> 04_navigation_builder.R Generate two-tier navigation HTML
  |-> 07_page_assembler.R     Assemble final combined HTML document
  |-> 08_html_writer.R        Write output file
```

## Config Sheets

| Sheet | Format | Required | Content |
|-------|--------|----------|---------|
| Settings | Key-Value | Yes | Project title, company, branding, output paths |
| Reports | Table | Yes | HTML report paths, labels, keys, order |
| CrossRef | Table | No | Tracker-to-tabs question code mappings |

## Support Files

| File | Purpose | Status |
|------|---------|--------|
| `lib/generate_config_templates.R` | Professional Excel config template with dropdowns, validation, and help text | Active |
| `lib/validation/preflight_validators.R` | 14 pre-flight checks validating report files, cross-references, and compatibility | Active |
| `docs/REPORT_HUB_USER_GUIDE.md` | User documentation for the Report Hub | Active |

## Notes

- `lib/generate_config_templates.R` uses shared template infrastructure from `modules/shared/template_styles.R`.
- `lib/validation/preflight_validators.R` provides its own `log_issue()` fallback if `modules/shared/lib/logging_utils.R` is not loaded.
- The namespace rewriting in `02_namespace_rewriter.R` is the most complex component, handling HTML IDs, CSS selectors, and JS references.
- Quality scores: 5/5 = production-hardened with comprehensive error handling; 4/5 = production-ready with good coverage.
