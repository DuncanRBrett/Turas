# Turas Report Hub — Technical Documentation

**Version:** 1.0
**Last Updated:** March 2026
**Target Audience:** Developers, Maintainers

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Pipeline Steps](#2-pipeline-steps)
3. [Namespace Isolation System](#3-namespace-isolation-system)
4. [JavaScript Runtime](#4-javascript-runtime)
5. [CSS Architecture](#5-css-architecture)
6. [Configuration System](#6-configuration-system)
7. [Report Type Detection](#7-report-type-detection)
8. [Pinned Views Unification](#8-pinned-views-unification)
9. [Error Handling](#9-error-handling)
10. [Testing](#10-testing)
11. [Extension Guide](#11-extension-guide)
12. [Common Maintenance Tasks](#12-common-maintenance-tasks)
13. [Dependencies](#13-dependencies)
14. [Data Flow Diagram](#14-data-flow-diagram)

---

## 1. Architecture Overview

The Report Hub combines multiple Turas HTML reports into a single unified interactive document. It follows a **7-step pipeline** orchestrated by `00_main.R::combine_reports()`.

### Pipeline Flow

```
Config File (Excel)
    │
    ▼
┌──────────────────────┐
│ 1. Guard Validation   │  00_guard.R
│    (config, paths)    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ 2. Pre-flight Checks  │  lib/validation/preflight_validators.R
│    (14 cross-checks)  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ 3. HTML Parsing       │  01_html_parser.R
│    (per report)       │  Extracts CSS, JS, panels, metadata, pinned data
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ 4. Namespace Rewrite  │  02_namespace_rewriter.R (MOST COMPLEX)
│    (per report)       │  Prefixes IDs, rewrites CSS/JS, wraps in IIFEs
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ 5. Navigation Build   │  04_navigation_builder.R
│    (two-tier tabs)    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ 6. Front Page Build   │  03_front_page_builder.R
│    (overview cards)   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ 7. Page Assembly      │  07_page_assembler.R
│    + HTML Writing     │  08_html_writer.R
└──────────┬───────────┘
           │
           ▼
     Combined HTML File
```

### Key Design Principle

The output is a **single, self-contained HTML file** with all CSS, JS, images (Base64-encoded), and data embedded inline. No external dependencies. Works offline.

---

## 2. Pipeline Steps

### Step 1: Guard Validation (00_guard.R)

Validates before any processing:
- Config file exists and is readable `.xlsx`
- Required sheets present: `Settings`, `Reports`
- Required fields populated in Settings: `project_title`, `company_name`
- Required columns in Reports: `report_path`, `report_label`, `report_key`, `order`
- Report keys are valid format (starts with letter, only `a-z`, `A-Z`, `0-9`, `-`, `_`)
- Report keys are unique
- Colour values are valid hex codes (if provided)
- **Slides sheet** (if present): validates required columns (`slide_title`, `content`, `display_order`), filters to slides with title + content or image, resolves `image_path` values, and compresses/encodes images
- Logo path resolution and output directory validation

Returns TRS refusal with actionable `how_to_fix` on any failure.

### Step 2: Pre-flight Checks (lib/validation/preflight_validators.R — 931 lines)

14 cross-referential checks between config and actual files:
1. Report HTML files exist and are readable
2. Files are valid HTML (contain `<html` or `<!DOCTYPE`)
3. Report type auto-detection succeeds
4. CrossRef sheet mappings are valid (if provided)
5. Tracker codes exist in tracker reports
6. Tabs codes exist in tabs reports
7. Colour values are valid hex
8. Logo file exists (if specified)
9. Output directory is writable
10. No duplicate report keys
11. Order values are numeric
12. Report keys don't conflict with reserved names (overview, pinned)
13. CrossRef has required columns
14. All report paths resolve correctly

### Step 3: HTML Parsing (01_html_parser.R — 557 lines)

For each input report, extracts:
- **CSS blocks** — All `<style>` tags and inline styles
- **JS blocks** — All `<script>` tags (excluding external CDN links)
- **Content panels** — The main body sections (report content)
- **Metadata** — Report type, question counts, sample sizes from `<meta>` tags
- **Pinned data** — JSON-encoded pinned views stored in the report

Report type is auto-detected from:
1. `<meta name="turas-report-type" content="tracker|tabs">` tags
2. DOM structure markers (`id="tab-metrics"` → tracker, `id="tab-crosstabs"` → tabs)

### Step 4: Namespace Rewriting (02_namespace_rewriter.R — 775 lines)

**This is the most complex component.** It prevents cross-report DOM/CSS/JS conflicts.

For each report:

1. **DOM ID Prefixing** — All `id="xxx"` attributes become `id="{key}--xxx"` (e.g., `id="tracker--tab-metrics"`)

2. **CSS Selector Rewriting** — `#xxx` selectors become `#tracker--xxx`. Class selectors within report scope are also adjusted.

3. **JS Reference Rewriting** — All JavaScript patterns that reference DOM IDs are rewritten:
   - `getElementById("xxx")` → `getElementById("tracker--xxx")`
   - `querySelector("#xxx")` → `querySelector("#tracker--xxx")`
   - `document.querySelector('[data-id="xxx"]')` → rewritten with prefix
   - Hash references (`#xxx`) in event handlers

4. **IIFE Wrapping** — All JS is wrapped in Immediately Invoked Function Expressions to prevent global scope pollution:
   ```js
   (function() {
     // original report JS with rewritten references
   })();
   ```

5. **Hub-conflicting Function Removal** — Functions that would conflict with hub-level equivalents are stripped:
   - Save/download handlers (hub has its own Save button)
   - Print handlers
   - Pin management functions (hub unifies pins)

### Step 5: Navigation Building (04_navigation_builder.R — 106 lines)

Generates two-tier navigation HTML:
- **Level 1 tabs:** Overview | Report 1 | Report 2 | ... | Pinned Views
- **Level 2 sub-tabs:** Per-report internal tabs (e.g., Metrics | Summary | Crosstabs)

Tab order comes from the `order` column in the Reports sheet.

### Step 6: Front Page Building (03_front_page_builder.R — 205 lines)

Builds the Overview tab with:
- **Report index cards** — One card per report showing key statistics extracted from metadata (sample size, question count, metric count, date range)
- **Summary area** — Aggregate statistics across all reports

Cards are clickable — clicking navigates to that report's tab.

### Step 7: Page Assembly (07_page_assembler.R — 325 lines)

Assembles the final HTML document:
1. `<!DOCTYPE html>` and `<html>` wrapper
2. `<head>` with merged CSS: hub styles first, then each report's CSS (scoped by namespace)
3. `<body>` containing:
   - Branded header (title, subtitle, company, logo)
   - Level 1 navigation
   - Overview panel
   - Report panels (each containing Level 2 nav + content)
   - Pinned Views panel
4. Merged JS: hub scripts first, then each report's namespaced JS
5. CSS colour placeholder replacement (`BRAND_COLOUR` → actual hex value)

### Step 8: HTML Writing (08_html_writer.R — 58 lines)

Writes the assembled HTML to disk. Creates the output directory if needed. Reports file size for logging.

---

## 3. Namespace Isolation System

### The Problem

Multiple Turas reports use identical DOM IDs (e.g., `tab-overview`, `tab-summary`, `panel-content`). Without isolation, clicking a tab in one report would affect all reports.

### The Solution

Every DOM element, CSS selector, and JS reference is prefixed with the report's unique `report_key`:

| Original | Namespaced (key = "tracker") |
|----------|------------------------------|
| `id="tab-metrics"` | `id="tracker--tab-metrics"` |
| `#tab-metrics` (CSS) | `#tracker--tab-metrics` |
| `getElementById("tab-metrics")` (JS) | `getElementById("tracker--tab-metrics")` |

### Implementation Details

The namespace rewriter uses **regex-based string replacement** on the parsed HTML, CSS, and JS strings. Key patterns:

```r
# DOM ID rewriting
html <- gsub('id="([^"]+)"', paste0('id="', key, '--\\1"'), html)

# CSS selector rewriting
css <- gsub('#([a-zA-Z][a-zA-Z0-9_-]*)', paste0('#', key, '--\\1'), css)

# JS getElementById rewriting
js <- gsub('getElementById\\("([^"]+)"\\)',
           paste0('getElementById("', key, '--\\1")'), js)
```

**Caution:** Pattern ordering matters. More specific patterns must be applied before general ones to prevent double-prefixing.

### IIFE Wrapping

All report JS is wrapped in IIFEs to prevent variable name collisions:

```js
(function() {
  // Report's entire JS block with rewritten references
  // Variables are local to this scope
})();
```

---

## 4. JavaScript Runtime

Three JS files provide client-side interactivity in the combined report:

### hub_id_resolver.js (12 lines)

Creates the `ReportHub` global namespace object used by other hub JS modules. Must load first.

### hub_navigation.js (179 lines)

- **Tab switching** — Level 1 (reports) and Level 2 (sub-tabs within reports)
- **URL hash deep-linking** — `#tracker` navigates to the tracker tab; `#tracker/metrics` navigates to a specific sub-tab
- **Keyboard navigation** — Arrow keys move between tabs
- **Save/Print** — Hub-level Save and Print buttons that operate on the entire combined report

### hub_pinned.js (854 lines)

- **Pin collection** — Gathers pinned views from all reports into one panel
- **Section dividers** — Users can add section headers between pins for narrative structure
- **Drag-to-reorder** — Pins and sections can be rearranged by dragging
- **JSON persistence** — Pin state is serialized to JSON and stored within the HTML document's data attributes; restored on page load
- **Export** — Individual pins or all pins can be exported as PNG images

---

## 5. CSS Architecture

### hub_styles.css (643 lines)

Hub-specific styles covering:
- **Header** — Branded banner with logo, title, subtitle
- **Two-tier navigation** — Top-level tabs and per-report sub-tabs
- **Report cards** — Front page overview cards with hover effects
- **Content panels** — Container for each report's content
- **Pinned views panel** — Layout for unified pins with section dividers
- **Responsive design** — Adapts to different viewport sizes

### Colour Variables

CSS uses placeholder values replaced at assembly time:
- `BRAND_COLOUR` → replaced with `brand_colour` from config (default: `#323367`)
- `ACCENT_COLOUR` → replaced with `accent_colour` from config (default: `#CC9900`)

Replacement happens in `07_page_assembler.R` via simple string substitution.

---

## 6. Configuration System

### Excel Config Structure

| Sheet | Format | Required |
|-------|--------|----------|
| Settings | Key-value (Field/Value columns) OR single-row (column names = fields) | Yes |
| Reports | Table with one row per report | Yes |
| Slides | Table with one row per qualitative slide (title, content, image, order) | No |
| CrossRef | Table mapping tracker ↔ tabs question codes | No |

### Config Reading

The guard layer (`00_guard.R`) reads the config. Settings sheet supports both formats — key-value is auto-detected by checking if the first column header is "Field" or similar.

### Slides Sheet Processing

The optional Slides sheet adds qualitative insight slides to the Overview front page. Processing in `00_guard.R`:

1. **Validation:** Each slide requires `slide_title` + at least one of `content` or `image_path`. Slides missing both are silently skipped.
2. **Content:** Markdown text stored as-is; rendered client-side. Empty content (`""`) is valid when an image is provided.
3. **Image encoding:** Images go through `.encode_slide_image()` — a compression pipeline that:
   - Reads PNG/JPEG files via the `png` and `jpeg` R packages
   - Downscales images wider than 800px (bilinear interpolation, aspect ratio preserved)
   - Re-encodes as JPEG at 0.85 quality
   - Base64-encodes the result as a `data:image/jpeg;base64,...` URI
   - SVG images are base64-encoded as-is (no rasterisation)
   - Falls back to raw base64 embedding if `png`/`jpeg` packages are unavailable
4. **Path resolution:** `image_path` values are tried as absolute paths first, then relative to the config file directory.

The encoded image data is stored in `slide$image_data` and rendered by `03_front_page_builder.R` as an `<img>` thumbnail above the content area, with a hidden `<textarea>` holding the base64 data for client-side serialisation.

### Template Generation

`lib/generate_config_templates.R` (328 lines) creates professional Excel templates using the shared infrastructure from `modules/shared/template_styles.R`. Templates include dropdown validation, colour-coded sections, and help text.

---

## 7. Report Type Detection

Detection priority:
1. **Meta tag:** `<meta name="turas-report-type" content="tracker">` — highest priority
2. **DOM markers:** `id="tab-metrics"` → tracker; `id="tab-crosstabs"` → tabs
3. **Config override:** `report_type` column in Reports sheet
4. **Fallback:** `"unknown"` — report is included but with limited metadata extraction

To add support for a new report type, update the detection logic in `01_html_parser.R` and add type-specific metadata extraction.

---

## 8. Pinned Views Unification

Individual Turas reports store pinned views as JSON within the HTML document. The hub:

1. **Extracts** pinned data from each report during HTML parsing
2. **Tags** each pin with its source report key (shown as a badge in the UI)
3. **Merges** all pins into a single collection
4. **Presents** them in the unified Pinned Views panel

At runtime, `hub_pinned.js` manages:
- Adding/removing pins
- Section divider creation
- Drag-to-reorder
- JSON serialization for save/restore
- PNG export

---

## 9. Error Handling

All errors use the **TRS (Turas Refusal System) v1.0** pattern:

```r
list(
  status = "REFUSED",
  code = "IO_FILE_NOT_FOUND",
  message = "Report file 'tracker_report.html' not found",
  how_to_fix = "Check report_path in Reports sheet. Path is relative to config file.",
  context = list(report_key = "tracker", path = "tracker_report.html")
)
```

Console output is mandatory for Shiny visibility. All errors are boxed in the console:

```
┌─── TURAS ERROR ────────────────────────┐
│ Code: IO_FILE_NOT_FOUND                │
│ Message: Report file not found         │
│ Fix: Check report_path in Reports sheet│
└────────────────────────────────────────┘
```

---

## 10. Testing

### Test File

`tests/testthat/test_report_hub.R` — 1,900 lines covering:

- **Guard validation** — Missing config, missing sheets, invalid fields, duplicate keys
- **HTML parsing** — CSS extraction, JS extraction, panel extraction, metadata extraction, type detection
- **Namespace rewriting** — ID prefixing, CSS rewriting, JS rewriting, IIFE wrapping, conflict removal
- **Front page building** — Card generation, metadata display
- **Pinned data extraction** — JSON parsing, source tagging
- **Page assembly** — Complete HTML generation, structure validation

Tests use **synthetic HTML input** — small hand-crafted HTML strings that simulate real Turas reports. No external fixture files needed.

### Running Tests

```r
testthat::test_file("modules/report_hub/tests/testthat/test_report_hub.R")
```

---

## 11. Extension Guide

### Adding a New Report Type

1. **Update type detection** in `01_html_parser.R`:
   - Add meta tag pattern: `<meta name="turas-report-type" content="new_type">`
   - Add DOM marker detection (identify unique elements in the new report type)

2. **Add metadata extraction** in `01_html_parser.R`:
   - Extract type-specific statistics (sample sizes, counts, etc.)

3. **Update front page cards** in `03_front_page_builder.R`:
   - Add card layout for the new type's metadata

4. **Test** with synthetic HTML containing the new type's markers

### Adding New Config Fields

1. **Add to guard validation** in `00_guard.R` (if required field)
2. **Add to preflight checks** in `lib/validation/preflight_validators.R` (if cross-referential)
3. **Read the field** in the appropriate pipeline step
4. **Update template generator** in `lib/generate_config_templates.R`
5. **Update user documentation** in `docs/USER_MANUAL.md`

### Adding New JavaScript Features

1. Create new JS file in `js/` directory
2. Update `07_page_assembler.R` to include the new file in the assembled HTML
3. Ensure the new JS uses the `ReportHub` namespace to avoid global pollution
4. Add tests in `test_report_hub.R`

### Adding New Front Page Components

Modify `03_front_page_builder.R`:
- Add new card types or summary sections
- Metadata comes from `01_html_parser.R` — ensure it extracts what you need

---

## 12. Common Maintenance Tasks

### Namespace Conflicts Appearing

**Symptom:** Clicking a tab in one report affects another report.

**Diagnosis:** A DOM ID wasn't properly prefixed. Check `02_namespace_rewriter.R` regex patterns. The most common cause is a new HTML attribute or JS pattern that the rewriter doesn't handle.

**Fix:** Add a new regex pattern to the rewriter for the unhandled case.

### Pinned Views Not Working

**Symptom:** Pins from individual reports don't appear in hub, or pins can't be saved.

**Diagnosis:** Check `hub_pinned.js` JSON serialization/deserialization. Verify that the HTML parser extracts pinned data correctly from the report's data attributes.

### CSS Styling Issues

**Symptom:** Hub elements styled incorrectly, or report styles leaking.

**Diagnosis:** Check `hub_styles.css` for specificity issues. Report CSS should be scoped by namespace prefix. Hub CSS should use hub-specific class names.

**Fix:** Increase specificity of hub selectors or add namespace scoping to the offending report CSS.

### New Turas Module Integration

When a new analytical module is added to Turas:
1. Ensure the module's HTML report includes `<meta name="turas-report-type">` tag
2. Update parser type detection
3. Update metadata extraction for the new type
4. Add front page card layout
5. Test namespace isolation with the new report

---

## 13. Dependencies

| Package | Purpose | Required |
|---------|---------|----------|
| `openxlsx` | Read config Excel file | Yes |
| `htmltools` | HTML escaping and generation | Yes |
| `jsonlite` | Pinned data JSON handling | Yes |
| `base64enc` | Logo Base64 encoding | If logo used |
| `shiny` | GUI interface | GUI only |
| `shinyFiles` | GUI file browser | GUI only |

### Shared Module Dependencies

- `modules/shared/lib/trs_refusal.R` — TRS refusal system
- `modules/shared/lib/validation_utils.R` — Input validation helpers
- `modules/shared/lib/logging_utils.R` — Console logging (optional fallback)
- `modules/shared/template_styles.R` — Template generation styling

---

## 14. Data Flow Diagram

```
                    ┌─────────────────────┐
                    │  Config File (.xlsx) │
                    │  ┌─────────────┐    │
                    │  │ Settings    │    │
                    │  │ Reports     │    │
                    │  │ CrossRef    │    │
                    │  └─────────────┘    │
                    └─────────┬───────────┘
                              │
                    ┌─────────▼───────────┐
                    │   Guard + Preflight  │
                    │   Validation         │
                    └─────────┬───────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
     ┌────────▼──────┐ ┌─────▼──────┐ ┌──────▼────────┐
     │ Report A.html │ │ Report B   │ │ Report C      │
     │ (Parse)       │ │ (Parse)    │ │ (Parse)       │
     └────────┬──────┘ └─────┬──────┘ └──────┬────────┘
              │               │               │
     ┌────────▼──────┐ ┌─────▼──────┐ ┌──────▼────────┐
     │ Namespace     │ │ Namespace  │ │ Namespace     │
     │ Rewrite (A)   │ │ Rewrite(B) │ │ Rewrite (C)   │
     └────────┬──────┘ └─────┬──────┘ └──────┬────────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
                    ┌─────────▼───────────┐
                    │  Navigation Builder  │
                    │  Front Page Builder  │
                    └─────────┬───────────┘
                              │
                    ┌─────────▼───────────┐
                    │   Page Assembler     │
                    │                     │
                    │  ┌──────────────┐   │
                    │  │ hub_styles   │   │
                    │  │ hub JS files │   │
                    │  │ Report CSS   │   │
                    │  │ Report JS    │   │
                    │  │ Report HTML  │   │
                    │  └──────────────┘   │
                    └─────────┬───────────┘
                              │
                    ┌─────────▼───────────┐
                    │   HTML Writer        │
                    │                     │
                    │  Combined_Report    │
                    │  .html              │
                    └─────────────────────┘
```
