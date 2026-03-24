# Report Hub Module -- Code Inventory

## Overview

The **Turas Report Hub** combines multiple individual HTML reports (from Tracker, Tabs, and other modules) into a single unified interactive report. Each source report is embedded as-is inside a base64-encoded iframe, guaranteeing that reports behave identically to their standalone versions with zero CSS/JS/DOM conflicts.

Configuration is driven by an Excel file with **Settings**, **Reports**, and **Slides** (optional) sheets. The Slides sheet supports qualitative insight slides with markdown text and/or images -- slides can be image-only (no text content required). Images are automatically compressed and base64-embedded. The core pipeline follows a 6-step architecture from guard validation through final HTML output.

**Key architectural feature:** The iframe isolation approach (`07_page_assembler.R`) base64-encodes each report's complete HTML and loads it into a dedicated `<iframe>` at runtime. This eliminates all cross-report conflicts without any DOM/CSS/JS rewriting.

---

## Summary Statistics

| Category         | File Count | Total Lines |
|------------------|:----------:|:-----------:|
| R (Core Pipeline)| 7          | 2,215       |
| R (Lib/Config)   | 2          | 1,333       |
| R (GUI)          | 1          | 690         |
| R Subtotal       | 10         | 4,238       |
| JavaScript       | 3          | 2,762       |
| CSS              | 1          | 1,277       |
| **Grand Total**  | **14**     | **8,277**   |

---

## Detailed File Inventory

### Shiny GUI Entry Point

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `run_report_hub_gui.R` | 690 | Shiny GUI launcher with file browser, preview panel, and config validation | 88 | Standalone launcher; provides interactive workflow for selecting config, previewing reports, and running the combine pipeline |

### Core Pipeline (R)

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `00_guard.R` | 952 | TRS v1.0 guard layer: validates config file, required sheets/fields, report paths, Slides sheet (with image compression/encoding), and logo/output resolution | 90 | Fully TRS-compliant; includes `.encode_slide_image()` for PNG/JPEG compression (downscale to 1200px, JPEG 0.85 quality, base64 embedding); SVG pass-through; fallback for missing `png`/`jpeg` packages |
| `00_main.R` | 207 | Main entry point: `combine_reports()` orchestrates the 6-step pipeline from config loading through final HTML output | 92 | Clean and compact; each step clearly documented; handles PASS/PARTIAL/REFUSED status propagation |
| `01_html_parser.R` | 201 | Reads individual HTML report files and extracts metadata (report type, sample sizes, question counts) | 88 | Preserves full raw HTML for iframe embedding; metadata extraction from meta tags and DOM markers |
| `03_front_page_builder.R` | 415 | Builds the Overview tab with report index cards, summary statistics, qualitative slides (with image preview + markdown content), and About panel | 90 | Generates slide cards supporting text-only, image-only, or both; images shown as thumbnails above editable content area |
| `04_navigation_builder.R` | 45 | Constructs Level 1 navigation: tabs for Overview, each report, Pinned Views, and About | 88 | Compact and single-purpose; generates accessible HTML nav structure |
| `07_page_assembler.R` | 325 | Assembles the final HTML document with iframe isolation: base64-encodes each report's HTML and creates iframe panels | 90 | Well-structured assembly; hub-only CSS in head; report HTML stored as base64 in script tags |
| `08_html_writer.R` | 70 | Writes the combined HTML string to file; creates output directory if needed | 90 | Minimal and focused; handles directory creation and file write with TRS error handling |

### Configuration and Validation (lib/)

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `generate_config_templates.R` | 402 | Professional Excel config template generator with data validation dropdowns and example values; includes Slides sheet template | 92 | Uses shared infrastructure patterns; produces ready-to-use config workbooks |
| `validation/preflight_validators.R` | 931 | Pre-flight cross-referential validation checks run before the pipeline begins | 90 | Comprehensive coverage: file existence, sheet structure, field completeness, duplicate detection |

### JavaScript (js/)

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `hub_id_resolver.js` | 10 | Namespace initializer: creates the `ReportHub` global object used by other JS modules | 90 | Minimal and clear; single responsibility |
| `hub_navigation.js` | 960 | Tab switching for L1 navigation, URL hash-based deep linking, keyboard shortcuts, Save/Print actions, iframe lazy-loading (base64 decode + srcdoc) | 88 | Clean event handling; supports accessibility via keyboard navigation |
| `hub_pinned.js` | 1,792 | Unified pinned views system: add/remove pins across reports, section dividers, drag-to-reorder, JSON persistence, slide image upload/compression | 85 | Most complex JS file; many interacting features; includes client-side image compression (resize to 1200px, JPEG 0.7 quality) for manual slide image uploads |

### CSS (assets/)

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `hub_styles.css` | 1,277 | Hub-specific styling: navigation bars, report cards, slide cards with image previews, layout grid, header/branding, responsive breakpoints | 88 | Comprehensive coverage; responsive design; consistent with Turas visual identity |

---

## Architecture Diagram

```
                          +---------------------+
                          |   Excel Config File  |
                          |  (Settings, Reports, |
                          |  Slides)             |
                          +----------+----------+
                                     |
                                     v
                          +---------------------+
                          |     00_guard.R       |
                          |  TRS Input Validation|
                          +----------+----------+
                                     |
                                     v
                          +---------------------+
                          |     00_main.R        |
                          | combine_reports()    |
                          | 6-Step Orchestration |
                          +----------+----------+
                                     |
                    +----------------+----------------+
                    |                                 |
                    v                                 |
         +-------------------+                        |
         | FOR EACH REPORT:  |                        |
         |                   |                        |
         | +---------------+ |                        |
         | |01_html_parser | |                        |
         | |Read HTML file | |                        |
         | |Extract meta   | |                        |
         | +---------------+ |                        |
         +--------+----------+                        |
                  |                                   |
                  +-----------------------------------+
                  |
                  v
         +-------------------+     +--------------------+
         |04_navigation      |     |03_front_page       |
         |_builder           |     |_builder             |
         |L1 Nav Tabs        |     |Overview Cards +    |
         |                   |     |Slides + About      |
         +---------+---------+     +---------+----------+
                   |                         |
                   +------------+------------+
                                |
                                v
                     +---------------------+
                     |  07_page_assembler   |
                     |  Base64-encode each  |
                     |  report HTML into    |
                     |  iframe srcdoc       |
                     +----------+----------+
                                |
                                v
                     +---------------------+
                     |   08_html_writer     |
                     |  Write to Disk      |
                     +---------------------+
                                |
                                v
                     +---------------------+
                     |  Combined HTML File  |
                     |  (Single Output)     |
                     +---------------------+

  Client-Side Runtime (in the combined HTML):

  +------------------+    +------------------+    +------------------+
  | hub_id_resolver  |    | hub_navigation   |    | hub_pinned       |
  | Namespace Init   |--->| Tab Switching    |--->| Pinned Views     |
  | ReportHub Global |    | Deep Linking     |    | Drag Reorder     |
  +------------------+    | Iframe Loading   |    | JSON Persistence |
                          | Save / Print     |    +------------------+
                          +------------------+

  Styling: hub_styles.css (navigation, cards, layout, responsive)
```

---

## Quality Scoring Criteria

Each file is scored on a 100-point scale across five dimensions:

| Criterion | Weight | Description |
|-----------|:------:|-------------|
| **TRS Compliance** | 25% | Uses structured refusals (never `stop()`); returns `status`, `code`, `message`, `how_to_fix`; errors visible in console for Shiny debugging |
| **Code Clarity** | 25% | Readable variable names, clear function structure, functions under 100 lines where feasible, logical flow, comments on non-obvious logic |
| **Test Coverage** | 20% | Existence and quality of unit tests, edge case coverage, integration tests |
| **Documentation** | 15% | Roxygen2 headers on exported functions, inline comments, parameter descriptions, return value documentation |
| **Robustness** | 15% | Edge case handling (empty inputs, missing fields, malformed HTML), graceful degradation, defensive coding patterns |

### Score Interpretation

| Range | Rating | Meaning |
|-------|--------|---------|
| 93-100 | Excellent | Production-hardened, fully tested, exemplary documentation |
| 85-92 | Strong | Production-ready, well-tested, minor gaps in docs or edge cases |
| 75-84 | Good | Functional and reliable, needs additional tests or documentation |
| 65-74 | Adequate | Works but has notable gaps in testing, error handling, or clarity |
| Below 65 | Needs Work | Significant refactoring, testing, or documentation required |

### Module-Wide Score: **89/100** (Strong)

The Report Hub module is production-ready with clean architecture, comprehensive validation, and a well-defined pipeline. The iframe isolation approach is simpler and more robust than the previous namespace-rewriting architecture, providing guaranteed isolation with zero risk of cross-report conflicts.
