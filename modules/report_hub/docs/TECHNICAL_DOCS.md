# Turas Report Hub -- Technical Documentation

**Version:** 2.0 (iframe architecture)
**Last Updated:** March 2026
**Target Audience:** Developers, Maintainers

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Pipeline Steps](#2-pipeline-steps)
3. [Iframe Isolation System](#3-iframe-isolation-system)
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

The Report Hub combines multiple Turas HTML reports into a single unified interactive document. It follows a **6-step pipeline** orchestrated by `00_main.R::combine_reports()`.

Each source report is embedded as-is inside a base64-encoded iframe. This **iframe isolation** approach guarantees that reports behave identically to their standalone versions -- no CSS/JS/DOM conflicts are possible because each report runs in its own browsing context.

### Pipeline Flow

```
Config File (Excel)
    |
    v
+----------------------+
| 1. Guard Validation   |  00_guard.R
|    (config, paths)    |
+----------+-----------+
           |
           v
+----------------------+
| 2. HTML Reading       |  01_html_parser.R
|    (per report)       |  Reads file, extracts metadata
+----------+-----------+
           |
           v
+----------------------+
| 3. Navigation Build   |  04_navigation_builder.R
|    (L1 report tabs)   |
+----------+-----------+
           |
           v
+----------------------+
| 4. Front Page Build   |  03_front_page_builder.R
|    (overview cards)   |
+----------+-----------+
           |
           v
+----------------------+
| 5. Page Assembly      |  07_page_assembler.R
|    (iframe embedding) |  Base64-encodes each report into iframe srcdoc
+----------+-----------+
           |
           v
+----------------------+
| 6. HTML Writing       |  08_html_writer.R
+----------+-----------+
           |
           v
     Combined HTML File
```

### Key Design Principle

The output is a **single, self-contained HTML file** with all CSS, JS, images (Base64-encoded), and report HTML embedded inline. No external dependencies. Works offline.

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

### Step 2: HTML Reading (01_html_parser.R)

For each input report:
- Reads the complete HTML file into memory (`raw_html`)
- Extracts **metadata** -- report type, question counts, sample sizes from `<meta>` tags
- Extracts **pinned data** -- JSON-encoded pinned views stored in the report

Report type is auto-detected from:
1. `<meta name="turas-report-type" content="tracker|tabs">` tags
2. DOM structure markers (`id="tab-metrics"` -> tracker, `id="tab-crosstabs"` -> tabs)

The full HTML content is preserved unchanged for iframe embedding in step 5.

### Step 3: Navigation Building (04_navigation_builder.R)

Generates Level 1 navigation HTML:
- **L1 tabs:** Overview | Report 1 | Report 2 | ... | Pinned Views | About

Tab order comes from the `order` column in the Reports sheet.

Note: Each report's internal navigation (sub-tabs) is preserved inside its iframe -- no L2 nav is built by the hub.

### Step 4: Front Page Building (03_front_page_builder.R)

Builds the Overview tab with:
- **Report index cards** -- One card per report showing key statistics extracted from metadata (sample size, question count, metric count, date range)
- **Qualitative slides** -- Optional markdown slides with image support
- **About panel** -- Analyst contact details and notes (if configured)

Cards are clickable -- clicking navigates to that report's tab.

### Step 5: Page Assembly (07_page_assembler.R)

Assembles the final HTML document with iframe isolation:
1. `<!DOCTYPE html>` and `<html>` wrapper with `hub-version: iframe-b64` marker
2. `<head>` with hub-only CSS (report styles live inside iframes)
3. `<body>` containing:
   - Branded header (title, subtitle, company, logo)
   - Level 1 navigation
   - Overview panel
   - Report panels (each containing an empty `<iframe>` element)
   - Pinned Views panel
   - About panel (if configured)
4. `<script type="text/plain">` blocks containing each report's full HTML, base64-encoded
5. Hub JavaScript (navigation, pinned views, iframe loading)
6. Initialization script that decodes base64 and loads each report into its iframe via `srcdoc`

### Step 6: HTML Writing (08_html_writer.R)

Writes the assembled HTML to disk. Creates the output directory if needed. Reports file size for logging.

---

## 3. Iframe Isolation System

### The Problem

Multiple Turas reports use identical DOM IDs (e.g., `tab-overview`, `tab-summary`, `panel-content`), identical CSS class names, and identical JS function names. Without isolation, these would conflict.

### The Solution

Each report's complete HTML is base64-encoded and stored in a `<script type="text/plain" data-encoding="base64">` element. At runtime, the hub JavaScript decodes the base64, creates a Blob URL or sets `srcdoc`, and loads the report into its dedicated `<iframe>`.

This provides **complete isolation**:
- Each iframe has its own DOM -- no ID conflicts possible
- Each iframe has its own CSS scope -- no style leaking
- Each iframe has its own JS scope -- no function/variable conflicts
- Reports behave identically to their standalone versions

### Why Base64?

Base64 encoding uses only `A-Za-z0-9+/=` characters, which cannot interfere with HTML parsing (no `<`, `>`, or `/` that could form closing tags). This guarantees safe roundtrip through unlimited create/edit/save/reopen cycles.

The ~33% size overhead is the cost of guaranteed safety.

---

## 4. JavaScript Runtime

Three JS files provide client-side interactivity in the combined report:

### hub_id_resolver.js

Creates the `ReportHub` global namespace object used by other hub JS modules. Must load first.

### hub_navigation.js

- **Tab switching** -- Level 1 report tabs and special panels (Overview, Pinned Views, About)
- **URL hash deep-linking** -- `#tracker` navigates to the tracker tab
- **Keyboard navigation** -- Arrow keys move between tabs
- **Save/Print** -- Hub-level Save and Print buttons
- **Iframe loading** -- Decodes base64 report HTML and loads into iframes on first tab activation (lazy loading)

### hub_pinned.js

- **Pin collection** -- Gathers pinned views from all reports into one panel
- **Section dividers** -- Users can add section headers between pins for narrative structure
- **Drag-to-reorder** -- Pins and sections can be rearranged by dragging
- **JSON persistence** -- Pin state is serialized to JSON and stored within the HTML document's data attributes; restored on page load
- **Export** -- Individual pins or all pins can be exported as PNG images
- **Slide image uploads** -- Client-side image compression (resize to max 1200px, JPEG 0.7 quality)

---

## 5. CSS Architecture

### hub_styles.css

Hub-specific styles covering:
- **Header** -- Branded banner with logo, title, subtitle
- **Navigation** -- Top-level tabs for reports and special panels
- **Report cards** -- Front page overview cards with hover effects
- **Content panels** -- Container for each report's iframe
- **Pinned views panel** -- Layout for unified pins with section dividers
- **Responsive design** -- Adapts to different viewport sizes

Note: Report-specific CSS lives inside each report's iframe and does not interact with hub styles.

### Colour Variables

CSS uses placeholder values replaced at assembly time:
- `BRAND_COLOUR` -> replaced with `brand_colour` from config (default: `#323367`)
- `ACCENT_COLOUR` -> replaced with `accent_colour` from config (default: `#CC9900`)

Replacement happens in `07_page_assembler.R` via simple string substitution.

---

## 6. Configuration System

### Excel Config Structure

| Sheet | Format | Required |
|-------|--------|----------|
| Settings | Key-value (Field/Value columns) OR single-row (column names = fields) | Yes |
| Reports | Table with one row per report | Yes |
| Slides | Table with one row per qualitative slide (title, content, image, order) | No |

### Config Reading

The guard layer (`00_guard.R`) reads the config. Settings sheet supports both formats -- key-value is auto-detected by checking if the first column header is "Field" or similar.

### Slides Sheet Processing

The optional Slides sheet adds qualitative insight slides to the Overview front page. Processing in `00_guard.R`:

1. **Validation:** Each slide requires `slide_title` + at least one of `content` or `image_path`. Slides missing both are silently skipped.
2. **Content:** Markdown text stored as-is; rendered client-side. Empty content (`""`) is valid when an image is provided.
3. **Image encoding:** Images go through `.encode_slide_image()` -- a compression pipeline that:
   - Reads PNG/JPEG files via the `png` and `jpeg` R packages
   - Downscales images wider than 1200px (bilinear interpolation, aspect ratio preserved)
   - Re-encodes as JPEG at 0.85 quality
   - Base64-encodes the result as a `data:image/jpeg;base64,...` URI
   - SVG images are base64-encoded as-is (no rasterisation)
   - Falls back to raw base64 embedding if `png`/`jpeg` packages are unavailable
4. **Path resolution:** `image_path` values are tried as absolute paths first, then relative to the config file directory.

### Template Generation

`lib/generate_config_templates.R` creates professional Excel templates using the shared infrastructure from `modules/shared/template_styles.R`. Templates include dropdown validation, colour-coded sections, and help text.

---

## 7. Report Type Detection

Detection priority:
1. **Meta tag:** `<meta name="turas-report-type" content="tracker">` -- highest priority
2. **DOM markers:** `id="tab-metrics"` -> tracker; `id="tab-crosstabs"` -> tabs
3. **Config override:** `report_type` column in Reports sheet
4. **Fallback:** `"unknown"` -- report is included but with limited metadata extraction

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
=== TURAS ERROR ===
Code: IO_FILE_NOT_FOUND
Message: Report file not found
Fix: Check report_path in Reports sheet
==================
```

---

## 10. Testing

### Test Files

83 tests across 8 test files in `tests/testthat/`:

- `test_guard.R` -- Config validation, missing sheets, invalid fields, duplicate keys
- `test_html_parser.R` -- Metadata extraction, type detection, file reading
- `test_front_page.R` -- Card generation, metadata display, slides
- `test_help_overlay.R` -- Help overlay extraction and rendering
- `test_visual_features.R` -- Visual styling and layout features
- `test_page_assembler.R` -- Complete HTML generation, iframe structure
- `test_integration.R` -- End-to-end pipeline tests

Tests use **synthetic HTML input** -- small hand-crafted HTML strings that simulate real Turas reports. No external fixture files needed.

### Running Tests

```r
testthat::test_dir("modules/report_hub/tests/testthat")
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
2. **Read the field** in the appropriate pipeline step
3. **Update template generator** in `lib/generate_config_templates.R`
4. **Update user documentation** in `docs/USER_MANUAL.md`

### Adding New JavaScript Features

1. Create new JS file in `js/` directory
2. Update `07_page_assembler.R` to include the new file in the assembled HTML
3. Ensure the new JS uses the `ReportHub` namespace to avoid global pollution
4. Add tests

### Adding New Front Page Components

Modify `03_front_page_builder.R`:
- Add new card types or summary sections
- Metadata comes from `01_html_parser.R` -- ensure it extracts what you need

---

## 12. Common Maintenance Tasks

### Iframe Not Loading

**Symptom:** Report panel shows loading spinner but never loads content.

**Diagnosis:** Check browser console for errors. Common causes: base64 encoding/decoding failure, or the source HTML contains characters that break `srcdoc` attribute parsing.

**Fix:** Verify that `base64enc::base64encode()` and the JS-side `atob()` decode produce identical HTML. Check for any post-processing that might corrupt the base64 string.

### Pinned Views Not Working

**Symptom:** Pins from individual reports don't appear in hub, or pins can't be saved.

**Diagnosis:** Check `hub_pinned.js` JSON serialization/deserialization. Verify that the HTML parser extracts pinned data correctly from the report's data attributes.

### CSS Styling Issues

**Symptom:** Hub elements styled incorrectly.

**Diagnosis:** Check `hub_styles.css` for specificity issues. Hub CSS only affects the hub shell (header, nav, panels). Report styles are fully isolated inside iframes.

### New Turas Module Integration

When a new analytical module is added to Turas:
1. Ensure the module's HTML report includes `<meta name="turas-report-type">` tag
2. Update parser type detection
3. Update metadata extraction for the new type
4. Add front page card layout
5. Test that the report loads correctly in an iframe

---

## 13. Dependencies

| Package | Purpose | Required |
|---------|---------|----------|
| `openxlsx` | Read config Excel file | Yes |
| `htmltools` | HTML escaping and generation | Yes |
| `jsonlite` | Pinned data JSON handling | Yes |
| `base64enc` | Report HTML, logo, and image encoding | Yes |
| `png` | PNG image reading (slide compression) | For slides with images |
| `jpeg` | JPEG image reading/writing (slide compression) | For slides with images |
| `shiny` | GUI interface | GUI only |
| `shinyFiles` | GUI file browser | GUI only |

### Shared Module Dependencies

- `modules/shared/lib/design_system/` -- Design tokens, fonts, base CSS
- `modules/shared/template_styles.R` -- Template generation styling

---

## 14. Data Flow Diagram

```
                    +---------------------+
                    |  Config File (.xlsx) |
                    |  +-----------+      |
                    |  | Settings  |      |
                    |  | Reports   |      |
                    |  | Slides    |      |
                    |  +-----------+      |
                    +---------+-----------+
                              |
                    +---------v-----------+
                    |   Guard Validation   |
                    |   (00_guard.R)       |
                    +---------+-----------+
                              |
              +---------------+---------------+
              |               |               |
     +--------v------+ +-----v------+ +------v--------+
     | Report A.html | | Report B   | | Report C      |
     | (Read + Meta) | | (Read)     | | (Read)        |
     +--------+------+ +-----+------+ +------+--------+
              |               |               |
              +---------------+---------------+
                              |
                    +---------v-----------+
                    |  Navigation Builder  |
                    |  Front Page Builder  |
                    +---------+-----------+
                              |
                    +---------v-----------+
                    |   Page Assembler     |
                    |                     |
                    |  +---------------+  |
                    |  | hub_styles    |  |
                    |  | hub JS files  |  |
                    |  | Base64-encoded|  |
                    |  | report HTML   |  |
                    |  | (in iframes)  |  |
                    |  +---------------+  |
                    +---------+-----------+
                              |
                    +---------v-----------+
                    |   HTML Writer        |
                    |                     |
                    |  Combined_Report    |
                    |  .html              |
                    +---------------------+
```
