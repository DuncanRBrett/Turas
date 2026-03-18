# Report Hub Module -- Code Inventory

## Overview

The **Turas Report Hub** combines multiple individual HTML reports (from Tracker, Tabs, and other modules) into a single unified interactive report. It parses each source report's HTML, rewrites all DOM IDs and CSS/JS references to prevent cross-report namespace conflicts, builds a two-tier navigation system, adds an Overview front page with report index cards, and unifies pinned views from all reports into a single curated panel.

Configuration is driven by an Excel file with **Settings**, **Reports**, **Slides** (optional), and **CrossRef** (optional) sheets. The Slides sheet supports qualitative insight slides with markdown text and/or images — slides can be image-only (no text content required). Images are automatically compressed and base64-embedded. The core pipeline follows a strict 7-step architecture from guard validation through final HTML output.

**Key architectural feature:** The namespace rewriter (`02_namespace_rewriter.R`) is the most complex component -- it prefixes all DOM IDs with report keys, rewrites CSS selectors, wraps all JS in IIFEs, and removes hub-conflicting functions.

---

## Summary Statistics

| Category         | File Count | Total Lines |
|------------------|:----------:|:-----------:|
| R (Core Pipeline)| 8          | 4,201       |
| R (Lib/Config)   | 2          | 1,325       |
| R (GUI)          | 1          | 653         |
| R Subtotal       | 11         | 6,179       |
| JavaScript       | 3          | 1,838       |
| CSS              | 1          | 1,139       |
| **Grand Total**  | **15**     | **9,156**   |

---

## Detailed File Inventory

### Shiny GUI Entry Point

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `run_report_hub_gui.R` | 653 | Shiny GUI launcher with file browser, preview panel, and config validation | 88 | Standalone launcher; provides interactive workflow for selecting config, previewing reports, and running the combine pipeline |

### Core Pipeline (R)

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `00_guard.R` | 891 | TRS v1.0 guard layer: validates config file, required sheets/fields, report paths, Slides sheet (with image compression/encoding), and logo/output resolution | 90 | Fully TRS-compliant; includes `.encode_slide_image()` for PNG/JPEG compression (downscale to 800px, JPEG 0.85 quality, base64 embedding); SVG pass-through; fallback for missing `png`/`jpeg` packages |
| `00_main.R` | 201 | Main entry point: `combine_reports()` orchestrates the 7-step pipeline from config loading through final HTML output | 92 | Clean and compact; each step clearly documented; handles PASS/PARTIAL/REFUSED status propagation |
| `01_html_parser.R` | 873 | Parses individual HTML reports: extracts CSS blocks, JS blocks, content panels, and metadata | 88 | Handles multiple report types (Tracker, Tabs); regex-based extraction with `perl = TRUE` |
| `02_namespace_rewriter.R` | 1,029 | Rewrites DOM IDs, CSS selectors, and JS references to prevent cross-report collisions; wraps JS in IIFEs | 85 | **Most complex file**; regex-heavy; handles edge cases in CSS selector rewriting and JS scope isolation |
| `03_front_page_builder.R` | 545 | Builds the Overview tab with report index cards, summary statistics, qualitative slides (with image preview + markdown content), and About panel | 90 | Generates slide cards supporting text-only, image-only, or both; images shown as thumbnails above editable content area |
| `04_navigation_builder.R` | 126 | Constructs two-tier navigation: L1 tabs for reports, L2 sub-tabs for sections within each report | 88 | Compact and single-purpose; generates accessible HTML nav structure |
| `07_page_assembler.R` | 478 | Assembles the final HTML document: DOCTYPE, head section, unified CSS, body, header, navigation, content panels, and JS | 90 | Well-structured assembly; clear ordering of document sections; handles CSS/JS deduplication |
| `08_html_writer.R` | 58 | Writes the combined HTML string to file; creates output directory if needed | 90 | Minimal and focused; handles directory creation and file write with TRS error handling |

### Configuration and Validation (lib/)

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `generate_config_templates.R` | 394 | Professional Excel config template generator with data validation dropdowns and example values; includes Slides sheet template | 92 | Uses shared infrastructure patterns; produces ready-to-use config workbooks |
| `validation/preflight_validators.R` | 931 | 14 pre-flight cross-referential validation checks run before the pipeline begins | 90 | Comprehensive coverage: file existence, sheet structure, field completeness, cross-ref consistency, duplicate detection |

### JavaScript (js/)

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `hub_id_resolver.js` | 12 | Namespace initializer: creates the `ReportHub` global object used by other JS modules | 90 | Minimal and clear; single responsibility |
| `hub_navigation.js` | 300 | Tab switching for L1 and L2 navigation, URL hash-based deep linking, keyboard shortcuts, Save/Print actions | 88 | Clean event handling; supports accessibility via keyboard navigation |
| `hub_pinned.js` | 1,526 | Unified pinned views system: add/remove pins across reports, section dividers, drag-to-reorder, JSON persistence, slide image upload/compression | 85 | Most complex JS file; many interacting features; includes client-side image compression (resize to 800px, JPEG 0.7 quality) for manual slide image uploads |

### CSS (assets/)

| File | Lines | Purpose | Quality | Notes |
|------|:-----:|---------|:-------:|-------|
| `hub_styles.css` | 1,139 | Hub-specific styling: navigation bars, report cards, slide cards with image previews, layout grid, header/branding, responsive breakpoints | 88 | Comprehensive coverage; responsive design; consistent with Turas visual identity |

---

## Architecture Diagram

```
                          +---------------------+
                          |   Excel Config File  |
                          |  (Settings, Reports, |
                          |  Slides, CrossRef)   |
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
                          | preflight_validators |
                          | 14 Cross-Ref Checks  |
                          +----------+----------+
                                     |
                                     v
                          +---------------------+
                          |     00_main.R        |
                          | combine_reports()    |
                          | 7-Step Orchestration |
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
         | |Extract CSS/JS | |                        |
         | |Extract Panels | |                        |
         | +-------+-------+ |                        |
         |         |         |                        |
         |         v         |                        |
         | +---------------+ |                        |
         | |02_namespace   | |                        |
         | |_rewriter      | |                        |
         | |Prefix IDs     | |                        |
         | |Rewrite CSS/JS | |                        |
         | |Wrap in IIFEs  | |                        |
         | +---------------+ |                        |
         +--------+----------+                        |
                  |                                   |
                  +-----------------------------------+
                  |
                  v
         +-------------------+     +--------------------+
         |04_navigation      |     |03_front_page       |
         |_builder           |     |_builder             |
         |L1 + L2 Nav Tabs   |     |Overview Cards +    |
         |                   |     |Slides + About      |
         +---------+---------+     +---------+----------+
                   |                         |
                   +------------+------------+
                                |
                                v
                     +---------------------+
                     |  07_page_assembler   |
                     |  Assemble Final HTML |
                     |  DOCTYPE + Head +    |
                     |  CSS + Body + Nav +  |
                     |  Panels + JS        |
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
  +------------------+    | Keyboard Shorts  |    | JSON Persistence |
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
| **Test Coverage** | 20% | Existence and quality of unit tests, edge case coverage, integration tests, golden file comparisons |
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

The Report Hub module is production-ready with clean architecture, comprehensive validation (14 preflight checks plus TRS guard), and a well-defined pipeline. The primary area for improvement is the namespace rewriter (`02_namespace_rewriter.R`), which carries inherent complexity due to regex-based DOM/CSS/JS rewriting. Its score of 85 reflects the difficulty of the task rather than code quality issues -- the implementation is thorough and well-tested for its complexity level.
