# Turas Report Hub — User Guide

**Version:** 1.0
**Module:** `modules/report_hub/`
**Last Updated:** March 2026

---

## Overview

The **Report Hub** combines multiple Turas HTML reports (Tracker, Crosstabs, etc.) into a single unified report with:

- **Two-tier navigation** — Top-level tabs for each report, sub-tabs for sections within each report
- **Unified front page** — Overview cards showing key statistics for every included report
- **Consolidated pinned views** — All pinned items from all reports merged into one panel
- **Namespace isolation** — Each report's CSS, JavaScript, and DOM IDs are scoped to prevent conflicts
- **Branded header** — Project title, company logo, and colour scheme
- **Save & print** — Single "Save Report" button preserves the entire combined report

---

## Quick Start

### 1. Prepare Your Reports

Generate individual HTML reports first using the Tabs and/or Tracker modules. You need at least one `.html` report file.

### 2. Create the Config File

Create an Excel file (`.xlsx`) with the required sheets. See [Config File Reference](#config-file-reference) below.

### 3. Run via GUI

```r
source("modules/report_hub/run_report_hub_gui.R")
run_report_hub_gui()
```

The GUI lets you:
- Browse for your config file
- Preview settings
- Click **Run** to generate the combined report

### 4. Run via Script

```r
source("modules/report_hub/00_main.R")

result <- combine_reports(
  config_file = "path/to/Report_Hub_Config.xlsx"
)

# Check result
if (result$status == "PASS") {
  cat("Combined report saved to:", result$result$output_path, "\n")
}
```

---

## Config File Reference

The config file is an Excel workbook (`.xlsx`) with three sheets:

### Settings Sheet (Required)

Contains project-level settings in key-value format.

| Field | Value | Required? | Description |
|-------|-------|-----------|-------------|
| `project_title` | Brand Health Study 2026 | **Yes** | Main title shown in the report header |
| `company_name` | The Research LampPost | **Yes** | Company name shown in "Prepared by" line |
| `client_name` | Acme Corp | No | Client name shown in "Prepared by ... for ..." line |
| `subtitle` | Wave 3 Results | No | Subtitle shown under the main title |
| `brand_colour` | #323367 | No | Primary brand colour (hex). Default: `#323367` |
| `accent_colour` | #CC9900 | No | Accent colour for highlights. Default: `#CC9900` |
| `logo_path` | logo.png | No | Path to company logo (PNG, JPG, or SVG). Relative to config file or absolute. |
| `output_dir` | ./output | No | Output directory. Relative to config file or absolute. Default: same directory as config file. |
| `output_file` | Combined_Report.html | No | Output filename. `.html` extension added if missing. Default: auto-generated from project title + date. |

**Format options:** The Settings sheet supports two formats:

**Key-Value format** (recommended):
| Field | Value |
|-------|-------|
| project_title | Brand Health Study 2026 |
| company_name | The Research LampPost |
| ... | ... |

**Single-row format** (column names = field names):
| project_title | company_name | client_name | ... |
|--------------|-------------|-------------|-----|
| Brand Health Study 2026 | The Research LampPost | Acme Corp | ... |

### Reports Sheet (Required)

Lists each HTML report to include in the combined output.

| Column | Required? | Description |
|--------|-----------|-------------|
| `report_path` | **Yes** | Path to the HTML report file. Can be absolute or relative to the config file location. |
| `report_label` | **Yes** | Display label shown in navigation tabs (e.g., "Brand Tracker", "Crosstabs"). |
| `report_key` | **Yes** | Unique identifier for this report. Used internally for namespacing. Must start with a letter and contain only letters, numbers, hyphens, or underscores (e.g., `tracker`, `brand-health`, `tabs_v2`). |
| `order` | **Yes** | Numeric sort order. Reports are displayed in ascending order (1, 2, 3...). |
| `report_type` | No | Report type override (`tracker` or `tabs`). Auto-detected if omitted. |

**Example:**

| report_path | report_label | report_key | order |
|-------------|-------------|------------|-------|
| Tracker_Report.html | Brand Tracker | tracker | 1 |
| Crosstabs_Report.html | Crosstabs | tabs | 2 |

**Important rules:**
- Each `report_key` must be unique across all reports
- `report_key` format: starts with a letter, only `a-z`, `A-Z`, `0-9`, `-`, `_` allowed
- Paths can be absolute or relative to the config file location
- Only `.html` and `.htm` files are accepted

### CrossRef Sheet (Optional)

Maps questions between tracker and crosstabs reports for cross-referencing.

| Column | Description |
|--------|-------------|
| `tracker_code` | Question code in the tracker report |
| `tabs_code` | Corresponding question code in the crosstabs report |

**Example:**

| tracker_code | tabs_code |
|-------------|-----------|
| Q1_awareness | Q1 |
| Q5_satisfaction | Q5 |

Rows with empty `tracker_code` or `tabs_code` are automatically skipped.

---

## Function Reference

### `combine_reports(config_file, output_file = NULL, auto_cross_ref = FALSE)`

Main entry point. Combines multiple HTML reports into one.

**Parameters:**
- `config_file` — Path to the Excel config file (required)
- `output_file` — Output file path (optional; auto-generated if NULL)
- `auto_cross_ref` — Enable fuzzy question matching (default FALSE)

**Returns:** TRS-compliant list:
```r
list(
  status = "PASS",           # "PASS", "PARTIAL", or "REFUSED"
  result = list(
    output_path = "...",     # Path to the generated HTML file
    file_size = 1234567,     # File size in bytes
    n_reports = 2,           # Number of reports combined
    report_keys = c("tracker", "tabs")
  ),
  warnings = character(0),   # Any non-fatal warnings
  message = "Combined 2 reports successfully"
)
```

### `run_report_hub_gui()`

Launches the Shiny GUI for interactive report combining. No parameters needed.

---

## Processing Pipeline

The Report Hub processes reports through these steps:

```
1. Guard Validation    → Validates config file, report paths, settings
2. HTML Parsing        → Extracts CSS, JS, panels, metadata from each report
3. Namespace Rewriting → Prefixes all DOM IDs, CSS selectors, JS variables
4. Front Page Building → Creates overview cards with report statistics
5. Navigation Building → Creates two-tier tab navigation
6. Page Assembly       → Combines everything into a single HTML document
7. HTML Writing        → Writes the final file to disk
```

Each step is fail-safe with TRS refusal handling. If any step encounters an unrecoverable error, you'll see a detailed error message in the R console.

---

## Combined Report Features

### Navigation

The combined report has two levels of navigation:

1. **Top-level tabs** — One tab per report (e.g., "Brand Tracker", "Crosstabs"), plus "Overview" and "Pinned Views"
2. **Sub-tabs** — Each report's original internal tabs (e.g., "Metrics", "Overview", "Summary")

### Front Page / Overview

The Overview tab shows:
- **Report cards** — One card per report with key statistics (sample size, number of questions/metrics, date range, etc.)
- **Summary area** — Editable summaries from each report

Click any report card to navigate directly to that report.

### Pinned Views

All pinned items from all reports are merged into a single "Pinned Views" panel. Each pin shows its source report (Tracker or Crosstabs badge).

Features:
- **Add sections** — Organize pins with section dividers
- **Drag to reorder** — Rearrange pins and sections
- **Export all as PNGs** — Download individual slide-ready images
- **Print / PDF** — Print all pinned views for presentation

### Save Report

The **Save Report** button in the header saves the entire combined report (including any edits to insights, pinned views, and summaries) as a self-contained HTML file.

---

## Supported Report Types

| Type | Auto-Detected By | Status |
|------|-----------------|--------|
| **Tracker** | `<meta name="turas-report-type" content="tracker">` or `id="tab-metrics"` | Fully supported |
| **Tabs (Crosstabs)** | `<meta name="turas-report-type" content="tabs">` or `id="tab-crosstabs"` | Fully supported |

---

## Branding & Colours

### Brand Colour

Set `brand_colour` in the Settings sheet to customise the primary colour used throughout the report (header, accent bars, navigation highlights).

**Format:** Hex colour code with `#` prefix (e.g., `#323367`)

### Accent Colour

Set `accent_colour` for secondary highlights (badges, hover states).

**Format:** Hex colour code with `#` prefix (e.g., `#CC9900`)

### Logo

Provide a `logo_path` in the Settings sheet. The logo is Base64-encoded and embedded directly in the HTML, so the report remains fully self-contained.

**Supported formats:** PNG, JPG/JPEG, SVG

---

## Troubleshooting

### "Config file not found"

**Code:** `IO_FILE_NOT_FOUND`

Check that the path to your config Excel file is correct. Ensure the file exists and is accessible.

### "Report file not found"

**Code:** `IO_FILE_NOT_FOUND`

The `report_path` in your Reports sheet doesn't resolve to an existing file. Paths can be:
- **Absolute:** `/Users/me/projects/report.html`
- **Relative to config file:** `./output/report.html` or `report.html`

### "report_key contains invalid characters"

**Code:** `CFG_INVALID_VALUE`

Report keys must start with a letter and contain only letters, numbers, hyphens (`-`), or underscores (`_`). Examples of valid keys: `tracker`, `brand-health`, `tabs_v2`.

### "Duplicate report_key values"

**Code:** `CFG_DUPLICATE_KEY`

Each report must have a unique `report_key`. If you have two crosstabs reports, use different keys (e.g., `tabs_wave1`, `tabs_wave2`).

### "Missing required columns in Reports sheet"

**Code:** `CFG_MISSING_FIELD`

The Reports sheet must have these columns: `report_path`, `report_label`, `report_key`, `order`.

### "Logo file not found"

This is a **warning**, not an error. The report will be generated without a logo. Check the `logo_path` in your Settings sheet.

### Console output not visible

If you're running through the Shiny GUI, check the R console/terminal where the Shiny app is running. All errors are output to the console in a boxed format for easy identification.

---

## Output File

The combined report is a **single, self-contained HTML file** with:
- All CSS embedded inline
- All JavaScript embedded inline
- Logo Base64-encoded (no external file dependencies)
- Pinned views data stored as JSON within the document
- Full interactivity (charts, tables, navigation, pin/unpin, export)

The file can be:
- Opened in any modern browser (Chrome, Edge, Firefox, Safari)
- Emailed as an attachment
- Shared via file storage (OneDrive, Google Drive, Dropbox)
- Archived for future reference

---

## Architecture

```
modules/report_hub/
├── 00_main.R                # Main entry point: combine_reports()
├── 00_guard.R               # Config validation (TRS v1.0)
├── 01_html_parser.R         # Extracts CSS/JS/panels from each HTML report
├── 02_namespace_rewriter.R  # Prefixes IDs to prevent cross-report conflicts
├── 03_front_page_builder.R  # Generates overview cards and summary area
├── 04_navigation_builder.R  # Builds two-tier tab navigation
├── 07_page_assembler.R      # Assembles final HTML document
├── 08_html_writer.R         # Writes output file
├── run_report_hub_gui.R     # Shiny GUI launcher
├── assets/
│   └── hub_styles.css       # Hub-specific CSS
├── js/
│   ├── hub_id_resolver.js   # Scoped DOM query helpers
│   ├── hub_navigation.js    # Tab switching and report navigation
│   └── hub_pinned.js        # Consolidated pinned views management
├── tests/
│   └── testthat/
│       └── test_report_hub.R
└── docs/
    └── REPORT_HUB_USER_GUIDE.md  # This file
```

---

## Dependencies

| Package | Purpose | Required? |
|---------|---------|-----------|
| `openxlsx` | Read config Excel file | Yes |
| `htmltools` | HTML escaping | Yes |
| `jsonlite` | Pinned data JSON handling | Yes |
| `base64enc` | Logo embedding | Yes (if logo used) |
| `shiny` | GUI only | GUI only |
| `shinyFiles` | GUI file browser | GUI only |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | March 2026 | Initial release with tracker + tabs support, namespace isolation, consolidated pinned views, branded header, front page with report cards |
