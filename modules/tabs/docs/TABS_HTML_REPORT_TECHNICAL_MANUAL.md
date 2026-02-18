# Turas Tabs HTML Report - Technical Developer Manual

**Version:** 10.6.0
**Module:** `modules/tabs/lib/html_report/`
**Audience:** Developers maintaining or extending the HTML report system

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [File Structure & Dependencies](#2-file-structure--dependencies)
3. [Processing Pipeline](#3-processing-pipeline)
4. [R Module Reference](#4-r-module-reference)
   - [00_html_guard.R](#41-00_html_guardr)
   - [01_data_transformer.R](#42-01_data_transformerr)
   - [02_table_builder.R](#43-02_table_builderr)
   - [03_page_builder.R](#44-03_page_builderr)
   - [04_html_writer.R](#45-04_html_writerr)
   - [05_dashboard_transformer.R](#46-05_dashboard_transformerr)
   - [06_dashboard_builder.R](#47-06_dashboard_builderr)
   - [07_chart_builder.R](#48-07_chart_builderr)
5. [JavaScript Module Reference](#5-javascript-module-reference)
   - [core_navigation.js](#51-core_navigationjs)
   - [chart_picker.js](#52-chart_pickerjs)
   - [table_export_init.js](#53-table_export_initjs)
   - [slide_export.js](#54-slide_exportjs)
   - [pinned_views.js](#55-pinned_viewsjs)
6. [Global State & Data Flow](#6-global-state--data-flow)
7. [CSS Architecture](#7-css-architecture)
8. [Config Object Reference](#8-config-object-reference)
9. [Data Structures](#9-data-structures)
10. [Error Handling & TRS Codes](#10-error-handling--trs-codes)
11. [Extending the System](#11-extending-the-system)
12. [Testing & Debugging](#12-testing--debugging)
13. [Performance Considerations](#13-performance-considerations)

---

## 1. Architecture Overview

The HTML report system generates a **self-contained HTML document** with no external dependencies. All CSS, JavaScript, images (base64-encoded), and data are embedded inline.

### Design Principles

- **Zero external dependencies** at runtime - no CDN links, no npm packages, no framework
- **Vanilla JavaScript** (ES5-compatible) - no transpilation required
- **Plain HTML tables** - no htmlwidgets, no React, no jQuery
- **Server-side rendering** in R with client-side interactivity in JS
- **TRS-compliant** error handling throughout
- **Self-contained output** - single `.html` file can be opened anywhere

### Technology Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Data processing | R | data.table, jsonlite |
| HTML generation | R (string concatenation) | No templating engine |
| CSS | Inline `<style>` block | CSS custom properties for theming |
| JavaScript | Vanilla JS (ES5) | No build step |
| Charts | Inline SVG | Generated server-side in R |
| Logos | Base64 data URIs | PNG, JPG, SVG supported |
| Exports | Client-side Blob API | CSV, Excel XML, PNG via Canvas |

---

## 2. File Structure & Dependencies

```
modules/tabs/lib/html_report/
├── 00_html_guard.R           # Input validation + shared utilities
├── 01_data_transformer.R     # Crosstab data → HTML-ready format
├── 02_table_builder.R        # HTML <table> generation
├── 03_page_builder.R         # Full page HTML assembly (CSS + structure)
├── 04_html_writer.R          # File I/O
├── 05_dashboard_transformer.R # Extract dashboard metrics from results
├── 06_dashboard_builder.R    # Dashboard HTML components
├── 07_chart_builder.R        # SVG chart generation
├── 99_html_report_main.R     # Main orchestrator
└── js/
    ├── core_navigation.js    # Navigation, banners, heatmap, insights
    ├── chart_picker.js       # Multi-column chart rendering
    ├── table_export_init.js  # CSV/Excel export, sorting, column toggle
    ├── slide_export.js       # PNG slide export
    └── pinned_views.js       # Pinned views management
```

### R File Load Order

Files are sourced by `99_html_report_main.R` in this order:

```
00_html_guard.R          → defines %||%, validation, shared utilities
01_data_transformer.R    → transform_for_html()
02_table_builder.R       → build_question_table()
03_page_builder.R        → build_html_page()
04_html_writer.R         → write_html_report()
05_dashboard_transformer.R → transform_dashboard_data()
06_dashboard_builder.R   → build_dashboard_html()
07_chart_builder.R       → build_chart_svg()
```

### JavaScript Load Order in HTML

JS files are embedded as `<script>` blocks in this order (defined in `03_page_builder.R`):

```
1. core_navigation.js     (foundational - defines globals)
2. table_export_init.js   (depends on core_navigation)
3. chart_picker.js        (depends on core_navigation, table_export_init)
4. slide_export.js        (depends on chart_picker)
5. pinned_views.js        (depends on all above)
```

### R Package Dependencies

| Package | Usage | Required |
|---------|-------|----------|
| `jsonlite` | JSON serialisation for chart data, banner groups | Yes |
| `htmltools` | HTML escaping (`htmlEscape`) | Yes |
| `base64enc` | Logo embedding (PNG/JPG to data URI) | Optional (logos skipped if missing) |
| `data.table` | Fast data manipulation in transformer | Recommended |

---

## 3. Processing Pipeline

```
generate_html_report(all_results, banner_info, config_obj, output_path, survey_structure)
                     │
                     ├─ 1. VALIDATE INPUTS (00_html_guard.R)
                     │   └─ validate_html_inputs() → TRS refusal or PASS
                     │
                     ├─ 2. SOURCE SUBMODULES
                     │   └─ Source 01-07 R files from html_report directory
                     │
                     ├─ 3. EMBED LOGOS
                     │   ├─ embed_logo(researcher_logo_path)
                     │   └─ embed_logo(client_logo_path)
                     │
                     ├─ 4. TRANSFORM DATA (01_data_transformer.R)
                     │   └─ transform_for_html(all_results, banner_info, config_obj)
                     │       └─ Returns: list of question_data objects
                     │
                     ├─ 5. BUILD DASHBOARD (conditional: include_summary=TRUE)
                     │   ├─ transform_dashboard_data(all_results, banner_info, config_obj)
                     │   └─ build_dashboard_html(dashboard_data, config_obj, banner_info)
                     │
                     ├─ 6. BUILD TABLES (02_table_builder.R)
                     │   └─ For each question:
                     │       └─ build_question_table(question_data, banner_groups, config_obj)
                     │
                     ├─ 7. BUILD CHARTS (conditional: show_charts=TRUE)
                     │   └─ For each question:
                     │       └─ build_chart_svg(question_data, config_obj, survey_structure)
                     │
                     ├─ 8. ASSEMBLE PAGE (03_page_builder.R)
                     │   └─ build_html_page(tables, charts, dashboard_html,
                     │                      banner_groups, config_obj)
                     │       ├─ CSS block
                     │       ├─ Header HTML
                     │       ├─ Dashboard HTML
                     │       ├─ Sidebar + question containers
                     │       ├─ Footer HTML
                     │       ├─ JS files (read from disk and embedded)
                     │       └─ Init script (DOMContentLoaded)
                     │
                     └─ 9. WRITE FILE (04_html_writer.R)
                         └─ write_html_report(html_content, output_path)
```

---

## 4. R Module Reference

### 4.1 00_html_guard.R

**Purpose:** Input validation and shared utility definitions.

**Key functions:**

```r
validate_html_inputs(all_results, banner_info, config_obj, output_path)
```
- Validates all required parameters exist and have correct types
- Returns TRS `PASS` or `REFUSED` with specific error codes
- Checks: `all_results` is non-empty list, `banner_info` has required fields (`columns`, `letters`, `banner_info`, `banner_headers`), `config_obj` is a list, `output_path` is non-empty string

```r
build_banner_code_to_label(banner_info)
```
- Maps internal banner group codes (e.g., "Q002") to display labels (e.g., "Campus")
- Used by dashboard transformer and builder
- Returns named character vector

**Shared definitions:**
- `%||%` null-coalescing operator (defined once, used across all files)

### 4.2 01_data_transformer.R

**Purpose:** Transform raw crosstab results into the structure expected by the table and chart builders.

**Key function:**

```r
transform_for_html(all_results, banner_info, config_obj)
```

**Input:** `all_results` - a named list where each element contains:
- `table` - data.frame with columns: `RowLabel`, `RowType`, and one column per banner key (e.g., `TOTAL::Total`, `REGION::North`)
- `bases` - list of base sizes (weighted/unweighted) per banner key

**Output:** Named list of `question_data` objects, each containing:
- `q_code` - question code (e.g., "Q001")
- `q_text` - full question text
- `table_data` - data.frame with display-ready values
- `stats` - list with flags: `has_sig`, `has_freq`, `has_net`, `has_mean`, `has_index`, `has_nps`
- `bases` - formatted base information
- `descriptor` - scale descriptor text (if configured)

**Key transformations:**
- Percentage values formatted with `%` suffix
- Frequencies formatted with comma separators
- Base rows identified and tagged
- NET/Mean/Index/NPS rows classified by `RowType`
- Descriptors attached from config (`index_descriptor`, `mean_descriptor`, `nps_descriptor`)

### 4.3 02_table_builder.R

**Purpose:** Generate HTML `<table>` elements from transformed question data.

**Key function:**

```r
build_question_table(question_data, banner_groups, config_obj)
```

**Output:** HTML string containing a complete `<table>` element.

**Table structure:**
```html
<table class="ct-table" id="table-Q001">
  <thead>
    <tr><!-- Banner group headers with colspans --></tr>
    <tr><!-- Column labels with letter codes --></tr>
  </thead>
  <tbody>
    <tr class="ct-row-base"><!-- Base row --></tr>
    <tr class="ct-row-category"><!-- Category rows --></tr>
    <tr class="ct-row-net"><!-- NET rows --></tr>
    <tr class="ct-row-mean"><!-- Mean/Index/NPS rows --></tr>
  </tbody>
</table>
```

**Cell attributes:**
- `data-sort-val` - numeric value for JavaScript sorting
- `data-heatmap` - RGBA colour string for heatmap background
- `data-col-key` - internal column key for column toggling
- CSS class `bg-{groupCode}` - associates cell with its banner group

**Heatmap calculation:**
- Brand colour parsed to RGB
- Cell percentage scaled 0-1 (0% = transparent, 100% = full intensity)
- Applied as `rgba(r, g, b, alpha)` where alpha = percentage / 200 (max 0.5 opacity)

**Low base handling:**
- Bases below `config_obj$significance_min_base` get class `ct-low-base-dim`
- Opacity reduced to 0.45
- Warning icon added to base row

### 4.4 03_page_builder.R

**Purpose:** Assemble the complete HTML page including CSS, header, navigation, content areas, footer, and embedded JavaScript.

**Key function:**

```r
build_html_page(table_html_list, chart_html_list, dashboard_html,
                banner_groups_json, config_obj)
```

**Output:** Complete HTML document as a single string.

**Major sections generated:**

1. **DOCTYPE and `<head>`** - UTF-8 charset, viewport meta, title, favicon
2. **CSS block** (~1200 lines) - All styles for layout, tables, charts, dashboard, print
3. **Header** - Logo, title, company/client names
4. **Tab navigation** - Summary, Crosstabs, Pinned Views tabs
5. **Sidebar** - Question list with search input
6. **Banner tabs** - One button per banner group
7. **Controls bar** - Heatmap toggle, frequency toggle, print, help, etc.
8. **Question containers** - One `div.question-container` per question containing table, chart, and insight area
9. **Footer** - Methodology notes, branding
10. **JavaScript** - Five JS files read from disk and embedded in `<script>` blocks
11. **Init script** - `DOMContentLoaded` handler for hydration

**Banner groups JSON injection:**
```javascript
// In the generated HTML:
var bannerGroups = ["Q002","Q003","Q004"]; // BANNER_GROUPS_JSON replaced
```

**CSS custom properties:**
```css
:root {
  --ct-brand: #323367;
  --ct-accent: #CC9900;
  --ct-text-primary: #1e293b;
  --ct-text-secondary: #64748b;
  --ct-bg-surface: #ffffff;
  --ct-bg-muted: #f8f9fa;
  --ct-border: #e2e8f0;
}
```

**Comment/Insight system HTML structure:**
```html
<div class="insight-area" data-q-code="Q001">
  <button class="insight-toggle">+ Add Insight</button>
  <div class="insight-container" style="display:none">
    <div class="insight-editor" contenteditable="true"></div>
    <button class="insight-dismiss">&times;</button>
  </div>
  <textarea class="insight-store" style="display:none">{"banner1":"text..."}</textarea>
  <!-- Pre-loaded comments from config -->
  <div class="config-comment" data-banner="Region">Western Cape leads...</div>
</div>
```

### 4.5 04_html_writer.R

**Purpose:** Write the assembled HTML string to disk.

**Key function:**

```r
write_html_report(html_content, output_path)
```

**Behaviour:**
- Validates output path ends in `.html`
- Creates parent directories recursively if needed
- Writes UTF-8 encoded file using `writeLines()`
- Reports file size to console
- Warns if file exceeds 5 MB
- Returns TRS result (`PASS` or `REFUSED`)

**TRS codes:** `IO_INVALID_PATH`, `IO_DIR_CREATE_FAILED`, `IO_WRITE_FAILED`, `IO_HTML_WRITE_FAILED`

### 4.6 05_dashboard_transformer.R

**Purpose:** Extract headline metrics from crosstab results for the dashboard.

**Key function:**

```r
transform_dashboard_data(all_results, banner_info, config_obj, bases)
```

**Metric detection logic:**
- Parses `config_obj$dashboard_metrics` (comma-separated string)
- For each metric type, scans all question results for matching rows:
  - `NET POSITIVE` → matches `RowLabel` containing "NET POSITIVE" with `RowType = "Column %"`
  - `NPS Score` → matches `RowLabel` containing "NPS" with `RowType` in `["Score", "Average"]`
  - `Mean` → matches `RowType = "Average"`
  - Custom labels → matches exact `RowLabel` text
- Extracts numeric values for Total and all banner columns
- Performs significance testing between banner columns (if enabled)

**Output:** List containing:
- `metrics` - list of metric objects (one per question-metric match)
- `banner_columns` - column labels for the heatmap grid
- `banner_code_to_label` - mapping of codes to display names
- `fieldwork_dates` - from config
- `significant_findings` - list of significant differences found

### 4.7 06_dashboard_builder.R

**Purpose:** Generate dashboard HTML components from transformed metrics.

**Key function:**

```r
build_dashboard_html(dashboard_data, config_obj, banner_info)
```

**Components generated:**

1. **Metadata strip** - Four cards: respondents, dates, questions, banners
2. **Colour legend** - Dynamic legend based on configured thresholds
3. **Gauge section** - Per metric type, SVG semi-circle gauges
4. **Heatmap grid** - Per metric type, HTML table with colour-coded cells
5. **Significant findings** - Cards showing statistically significant differences

**Colour threshold system:**
```r
thresholds <- list(
  net_positive = list(
    green = config_obj$dashboard_green_net %||% 30,
    amber = config_obj$dashboard_amber_net %||% 0
  ),
  average = list(
    green = config_obj$dashboard_green_mean %||% 7,
    amber = config_obj$dashboard_amber_mean %||% 5,
    scale = config_obj$dashboard_scale_mean %||% 10
  ),
  index = list(
    green = config_obj$dashboard_green_index %||% 7,
    amber = config_obj$dashboard_amber_index %||% 5,
    scale = config_obj$dashboard_scale_index %||% 10
  ),
  custom = list(
    green = config_obj$dashboard_green_custom %||% 60,
    amber = config_obj$dashboard_amber_custom %||% 40
  )
)
```

**4-tier gradient logic:**
```r
if (value > green + (scale - green) * 0.4)  → strong green (#2d8a4e)
else if (value >= green)                      → light green (#68a67d)
else if (value >= amber)                      → amber (#e8c170)
else                                          → red (#c0695c)
```

**SVG gauge rendering:**
- Semi-circle arc (180 degrees)
- Fill arc proportional to value/scale
- Colour matches threshold tier
- Value text centred in gauge
- Type badge below (NET, NPS, MEAN, IDX)

### 4.8 07_chart_builder.R

**Purpose:** Generate inline SVG charts for each question.

**Key function:**

```r
build_chart_svg(question_data, config_obj, survey_structure)
```

**Chart type selection:**
```r
if (has_box_categories OR is_likert OR is_rating OR is_nps) {
  → stacked horizontal bar chart
} else {
  → horizontal bar chart
}
```

**Semantic colour mapping** (`get_semantic_colour()`):
- 18 predefined label-to-colour mappings
- Pattern matching (case-insensitive, substring match)
- Fallback: gradient from brand colour based on position index

| Label Pattern | Colour | Hex |
|---|---|---|
| Negative, Poor, Detractor, Strongly Disagree | Strong negative | #c0695c |
| Disagree, Dissatisfied, Below Average | Moderate negative | #cf8a7c |
| Neutral, Average, Passive, Undecided | Neutral | #e8c170 |
| Agree, Satisfied, Good, Above Average | Moderate positive | #68a67d |
| Excellent, Promoter, Very Satisfied, Strongly Agree | Strong positive | #3d8b5e |
| DK, N/A, Refused, Other | Grey | #d4d4d4 |

**Chart data embedding:**

Each chart wrapper includes a `data-chart-data` attribute containing JSON:
```json
{
  "columns": {
    "TOTAL::Total": { "label": "Total", "values": [45, 30, 25] },
    "REGION::North": { "label": "North", "values": [50, 28, 22] }
  },
  "labels": ["Agree", "Neutral", "Disagree"],
  "colours": ["#3d8b5e", "#e8c170", "#c0695c"],
  "priority_metric": { "label": "Mean", "values": {"TOTAL::Total": 7.5} }
}
```

This JSON is consumed by `chart_picker.js` to rebuild charts client-side when the user selects different columns.

**SVG structure:**
```xml
<svg viewBox="0 0 700 {height}" role="img" aria-label="Chart for Q001">
  <g class="chart-bars">
    <!-- Bar elements with fill, width proportional to value -->
  </g>
  <g class="chart-labels">
    <!-- Category labels on left, value labels on bars -->
  </g>
  <g class="chart-legend">
    <!-- Colour dots + labels below chart -->
  </g>
</svg>
```

---

## 5. JavaScript Module Reference

### 5.1 core_navigation.js

**Global variables defined:**
```javascript
var bannerGroups = BANNER_GROUPS_JSON;  // Injected by R
var currentGroup = bannerGroups[0] || "";
var heatmapEnabled = true;
var hiddenColumns = {};    // {groupCode: {colKey: true}}
var sortState = {};        // {tableId: {colKey, direction}}
var originalRowOrder = {}; // {tableId: [row elements]}
```

**Key functions:**

| Function | Purpose |
|----------|---------|
| `selectQuestion(index)` | Show question container at index, hide others |
| `filterQuestions(term)` | Filter sidebar question list by search term |
| `switchBannerGroup(groupCode, btn)` | Switch active banner: saves insights, shows/hides columns, rebuilds charts |
| `toggleHeatmap()` | Toggle `data-heatmap` background colours on all cells |
| `toggleFrequencies()` | Toggle `.show-freq` class on main container |
| `toggleInsight(qCode)` | Show/hide insight editor for a question |
| `getInsightStore(area)` | Parse JSON from hidden textarea for insight area |
| `setInsightStore(area, obj)` | Serialise object to hidden textarea |
| `getActiveBannerName()` | Get display name of current active banner tab |
| `saveReportHTML()` | Serialise page + insights, trigger download |
| `hydrateInsights()` | Load saved insights from hidden textareas on page load |
| `printReport()` | Show all questions, trigger browser print dialog, restore |
| `showHelp()` / `dismissHelp()` | Toggle help overlay |
| `exportInsightsHTML()` | Export all insights as standalone HTML file |

**Banner switching cascade:**
```
switchBannerGroup(groupCode)
  ├─ Save current insights to insight stores
  ├─ Update currentGroup
  ├─ Toggle .active on banner tab buttons
  ├─ Show/hide table columns by .bg-{groupCode} class
  ├─ Reset sortState for all tables
  ├─ Clear excluded rows
  ├─ Call buildChartPickersForGroup(groupCode)  [chart_picker.js]
  ├─ Call buildColumnChips(groupCode)           [table_export_init.js]
  ├─ Load banner-specific insights
  └─ Restore hiddenColumns for this banner group
```

### 5.2 chart_picker.js

**Depends on:** `core_navigation.js` (getLabelText), `table_export_init.js` (sortChartBars, downloadBlob)

**Global variables:**
```javascript
var chartColumnState = {};  // {qCode: {colKey: true/false}}
```

**Key functions:**

| Function | Purpose |
|----------|---------|
| `getChartKeysForGroup(chartData, groupCode)` | Get column keys belonging to active banner group |
| `initChartColumnPickers()` | Build chart column picker chips for initial banner |
| `buildChartPickersForGroup(groupCode)` | Rebuild chart pickers when banner changes |
| `toggleChartColumn(qCode, colKey, chip)` | Toggle a column in the chart, rebuild SVG |
| `rebuildChart(wrapper)` | Full chart rebuild from `data-chart-data` JSON |
| `buildStackedBarSVG(data, keys, ...)` | Generate stacked bar SVG string |
| `buildHorizontalBarSVG(data, keys, ...)` | Generate horizontal bar SVG string |
| `exportChartPNG(svgElement, filename)` | Convert SVG to Canvas to PNG download |
| `escapeHtml(str)` | HTML entity escaping utility |
| `hslToHex(h, s, l)` | HSL to hex colour conversion |
| `generateDistinctColours(n)` | Generate n visually distinct colours for multi-column charts |

**Chart rebuild flow:**
```
toggleChartColumn(qCode, colKey)
  ├─ Update chartColumnState[qCode][colKey]
  ├─ Enforce minimum 1 column selected
  ├─ Update chip styling (.col-chip-off)
  └─ rebuildChart(wrapper)
        ├─ Parse data-chart-data JSON
        ├─ Filter to selected columns
        ├─ Filter excluded rows
        ├─ Determine chart type (stacked vs horizontal)
        ├─ Generate new SVG HTML
        └─ Replace wrapper innerHTML
```

### 5.3 table_export_init.js

**Depends on:** `core_navigation.js` (getLabelText, currentGroup)

**Key functions:**

| Function | Purpose |
|----------|---------|
| `buildColumnChips(groupCode)` | Build column visibility toggle chips for banner group |
| `toggleColumnVisibility(colKey, chip)` | Show/hide a table column across all tables |
| `initTableSorting()` | Attach click handlers to column headers |
| `sortTable(tableId, colKey)` | Sort table rows by column (3-state: desc → asc → none) |
| `sortChartBars(tableId)` | Reorder chart bars to match current table sort |
| `exportCSV(tableId)` | Export table as CSV (semicolon-separated) |
| `exportExcel(tableId)` | Export table as Excel XML Spreadsheet |
| `downloadBlob(blob, filename)` | Create download link and trigger browser download |
| `getLabelText(el)` | Extract clean text from label cell (excluding badges) |

**Sort algorithm:**
```javascript
// 3-state cycle per column
sortTable(tableId, colKey)
  ├─ If no sort → sort descending
  ├─ If descending → sort ascending
  └─ If ascending → restore original order

// Row classification:
// - .ct-row-base    → pinned at top (never sorted)
// - .ct-row-mean    → pinned at bottom (never sorted)
// - .ct-row-net     → pinned at bottom (never sorted)
// - .ct-row-category → sorted by data-sort-val
```

**CSV export format:**
- Semicolon delimited (handles commas in values)
- Quoted fields
- UTF-8 BOM header for Excel compatibility
- Only visible columns included
- Filename: `{qCode}_crosstab.csv`

**Excel XML export:**
- Microsoft Excel 2003 XML Spreadsheet format
- Styled header row (dark blue background, white text, bold)
- Automatic type detection (Number vs String)
- Alternating row colours
- Filename: `{qCode}_crosstab.xls`

### 5.4 slide_export.js

**Depends on:** `chart_picker.js` (escapeHtml)

**Key functions:**

| Function | Purpose |
|----------|---------|
| `exportSlidePNG(qCode, mode)` | Export question as presentation slide PNG |
| `extractSlideTableData(tableEl)` | Extract clean data from table DOM for slide rendering |
| `wrapTextLines(ctx, text, maxWidth)` | Word-wrap text for Canvas rendering |
| `buildSlideCanvas(data, mode)` | Compose slide on Canvas element |
| `exportDashboardSlide(sectionEl)` | Export dashboard gauge section as slide(s) |

**Export modes:**
- `"both"` → Chart + Table side by side
- `"chart"` → Chart only, centred
- `"table"` → Table only, full width

**Slide composition (Canvas):**
```
┌──────────────────────────────────────────────────────┐
│ Question Code: Q001                                  │
│ Question Title (wrapped to multiple lines if needed) │
├──────────────────────────────────────────────────────┤
│ Base: n=1,000  │  Banner: Region  │  Report Title    │
├──────────────────────────────────────────────────────┤
│                                                      │
│  [Table]                    [Chart SVG → Image]      │
│                                                      │
├──────────────────────────────────────────────────────┤
│ Mean: 7.5  │  NPS: +42  │  Index: 4.2               │
├──────────────────────────────────────────────────────┤
│ 💬 "User-written insight text here..."               │
└──────────────────────────────────────────────────────┘
```

**Resolution:** 1280 x variable height, rendered at 3x DPI (3840px canvas).

**SVG-to-Image pipeline:**
```
SVG element
  → XMLSerializer.serializeToString()
  → Blob (image/svg+xml)
  → URL.createObjectURL()
  → new Image()
  → image.onload → canvas.drawImage()
  → canvas.toBlob('image/png')
  → downloadBlob()
```

### 5.5 pinned_views.js

**Depends on:** All other JS modules (reads global state)

**Global variables:**
```javascript
var pinnedViews = [];  // Array of pinned snapshot objects
```

**Pinned view object structure:**
```javascript
{
  qCode: "Q001",
  qTitle: "Overall satisfaction",
  bannerName: "Region",
  baseText: "n=1,000",
  tableHTML: "<table>...</table>",
  chartSVG: "<svg>...</svg>",
  insightText: "Key finding...",
  sortState: {colKey: "Total", direction: "desc"},
  excludedRows: {"DK": true},
  timestamp: 1708234567890
}
```

**Key functions:**

| Function | Purpose |
|----------|---------|
| `togglePin(qCode)` | Pin or unpin a question |
| `captureCurrentView(qCode)` | Snapshot current table, chart, insight state |
| `renderPinnedViews()` | Rebuild pinned views container from pinnedViews array |
| `movePinUp(index)` / `movePinDown(index)` | Reorder pins |
| `removePin(index)` | Remove a pin and update UI |
| `exportAllSlides()` | Download PNG for each pinned view (sequential with 600ms delay) |
| `printPinnedViews()` | Create print layout and trigger browser print |
| `hydratePinnedViews()` | Restore pins from embedded JSON on page load |
| `serializePinnedViews()` | Save pins to hidden data attribute for HTML save |

**Pin lifecycle:**
```
User clicks pin icon
  → togglePin(qCode)
    → captureCurrentView(qCode)
      ├─ Clone current table HTML
      ├─ Clone current chart SVG
      ├─ Read current insight text
      ├─ Record sort state and excluded rows
      └─ Push to pinnedViews array
    → renderPinnedViews()
      ├─ Clear container
      ├─ For each pin: create card HTML
      └─ Update pin count badge
    → Update pin icon styling (filled/unfilled)
```

**Persistence:**
- Pins are serialised as JSON in a hidden `<div id="pinned-data">` element
- `saveReportHTML()` includes this element in the saved file
- `hydratePinnedViews()` parses this JSON on load to restore pins

---

## 6. Global State & Data Flow

### R → HTML Data Injection Points

| Data | Injection Method | Consumer |
|------|-----------------|----------|
| Banner group codes | `var bannerGroups = [...]` inline JS | core_navigation.js |
| Chart data (per question) | `data-chart-data` attribute (JSON) | chart_picker.js |
| Column-to-banner mapping | `class="bg-{groupCode}"` on `<th>` and `<td>` | core_navigation.js |
| Significance letters | `data-col-key` attribute | table_export_init.js |
| Sort values | `data-sort-val` attribute | table_export_init.js |
| Heatmap colours | `data-heatmap` attribute (RGBA) | core_navigation.js |
| Insight pre-fills | `.config-comment[data-banner]` elements | core_navigation.js |
| Pinned views | `#pinned-data` hidden div (JSON) | pinned_views.js |

### JavaScript Global State Map

```
core_navigation.js
  ├─ bannerGroups         (read by all)
  ├─ currentGroup         (read/written by banner switching)
  ├─ heatmapEnabled       (read/written by toggle)
  ├─ hiddenColumns        (read/written by column toggling)
  ├─ sortState            (read/written by table sorting)
  └─ originalRowOrder     (set on init, read by sort reset)

chart_picker.js
  └─ chartColumnState     (read/written by chart column picker)

pinned_views.js
  └─ pinnedViews          (read/written by pin operations)
```

### Cross-module function calls

```
chart_picker.js
  → getLabelText()          from core_navigation.js
  → sortChartBars()         from table_export_init.js
  → downloadBlob()          from table_export_init.js

slide_export.js
  → escapeHtml()            from chart_picker.js

pinned_views.js
  → currentGroup            from core_navigation.js
  → chartColumnState        from chart_picker.js
  → sortState               from core_navigation.js
  → exportChartPNG()        from chart_picker.js

core_navigation.js (switchBannerGroup)
  → buildChartPickersForGroup()  from chart_picker.js
  → buildColumnChips()           from table_export_init.js
```

---

## 7. CSS Architecture

### Class Naming Convention

All HTML report classes use the `ct-` prefix (crosstab) to avoid conflicts:

```
ct-table          → main table element
ct-row-base       → base/sample size row
ct-row-category   → standard data row
ct-row-net        → NET/aggregated row
ct-row-mean       → summary statistic row
ct-row-excluded   → row excluded from chart
ct-td             → data cell
ct-label-col      → label column (sticky left)
ct-data-col       → data column header
ct-sig            → significance badge
ct-low-base-dim   → dimmed low-base cell
ct-heatmap-cell   → cell with heatmap background
ct-sort-indicator → sort direction arrow
```

### Responsive Breakpoints

```css
@media (max-width: 768px) {
  /* Mobile: 2-column metadata, hidden sidebar */
}

@media print {
  /* Hide controls, full-width content, page breaks */
}
```

### Print Styles

Key print CSS rules:
```css
@media print {
  .sidebar, .controls-bar, .banner-tabs,
  .chart-col-picker, .insight-toggle { display: none !important; }
  .question-container { display: block !important; page-break-inside: avoid; }
  .ct-table { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
}
```

### Sticky Elements

```css
.ct-label-col {
  position: sticky;
  left: 0;
  z-index: 1;
}

.ct-table thead th {
  position: sticky;
  top: 0;
  z-index: 2;
}
```

---

## 8. Config Object Reference

Fields accessed from `config_obj` across all R modules:

| Field | Accessed By | Default |
|-------|------------|---------|
| `brand_colour` | 02, 03, 06, 07 | `"#323367"` |
| `accent_colour` | 03 | `"#CC9900"` |
| `chart_bar_colour` | 07 | `brand_colour` |
| `project_title` | 03 | `"Crosstab Report"` |
| `company_name` | 03 | `"The Research Lamppost"` |
| `client_name` | 03 | `NULL` |
| `researcher_logo_path` | 99 | `NULL` |
| `client_logo_path` | 99 | `NULL` |
| `researcher_logo_uri` | 03 | Set by 99 |
| `client_logo_uri` | 03 | Set by 99 |
| `significance_min_base` | 02, 03 | `30` |
| `enable_significance_testing` | 03, 05 | `FALSE` |
| `bonferroni_correction` | 03 | `FALSE` |
| `alpha` | 03 | `0.05` |
| `embed_frequencies` | 01, 02 | `TRUE` |
| `include_summary` | 99 | `TRUE` |
| `show_charts` | 99 | `FALSE` |
| `apply_weighting` | 01, 05 | `FALSE` |
| `dashboard_metrics` | 05, 06 | `"NET POSITIVE"` |
| `dashboard_green_net` | 06 | `30` |
| `dashboard_amber_net` | 06 | `0` |
| `dashboard_green_mean` | 06 | `7` |
| `dashboard_amber_mean` | 06 | `5` |
| `dashboard_scale_mean` | 06 | `10` |
| `dashboard_green_index` | 06 | `7` |
| `dashboard_amber_index` | 06 | `5` |
| `dashboard_scale_index` | 06 | `10` |
| `dashboard_green_custom` | 06 | `60` |
| `dashboard_amber_custom` | 06 | `40` |
| `decimal_places_ratings` | 02, 07 | `1` |
| `index_descriptor` | 01 | `NULL` |
| `mean_descriptor` | 01 | `NULL` |
| `nps_descriptor` | 01 | `NULL` |
| `priority_metric` | 07 | `NULL` |
| `fieldwork_dates` | 05 | `NULL` |
| `comments` | 03 | `NULL` |

---

## 9. Data Structures

### banner_info (Input)

```r
list(
  columns = c("Total", "North", "South", "Male", "Female"),
  letters = c("-", "A", "B", "C", "D"),
  banner_info = list(
    REGION = list(
      internal_keys = c("REGION::North", "REGION::South"),
      display_labels = c("North", "South"),
      letters = c("A", "B"),
      banner_code = "REGION"
    ),
    GENDER = list(
      internal_keys = c("GENDER::Male", "GENDER::Female"),
      display_labels = c("Male", "Female"),
      letters = c("C", "D"),
      banner_code = "GENDER"
    )
  ),
  banner_headers = data.frame(
    label = c("Region", "Gender"),
    stringsAsFactors = FALSE
  )
)
```

### all_results (Input)

```r
list(
  Q001 = list(
    table = data.frame(
      RowLabel = c("Base", "Excellent", "Good", "Average", "Poor",
                   "NET POSITIVE", "Mean"),
      RowType = c("Base", "Column %", "Column %", "Column %", "Column %",
                  "Column %", "Average"),
      `TOTAL::Total` = c(1000, 25.5, 35.2, 22.1, 17.2, 60.7, 7.5),
      `REGION::North` = c(400, 28.0, 33.5, 21.0, 17.5, 61.5, 7.6),
      `REGION::South` = c(600, 23.8, 36.3, 22.8, 17.0, 60.1, 7.4),
      check.names = FALSE
    ),
    bases = list(
      `TOTAL::Total` = list(weighted = 1000, unweighted = 950),
      `REGION::North` = list(weighted = 400, unweighted = 380),
      `REGION::South` = list(weighted = 600, unweighted = 570)
    )
  ),
  Q002 = list(...)
)
```

### banner_groups_json (Generated)

```json
["REGION", "GENDER", "AGE_GROUP"]
```

Array of banner group codes injected into JavaScript.

### Chart data JSON (Per question)

```json
{
  "type": "stacked",
  "columns": {
    "TOTAL::Total": {
      "label": "Total",
      "values": [25.5, 35.2, 22.1, 17.2]
    },
    "REGION::North": {
      "label": "North",
      "values": [28.0, 33.5, 21.0, 17.5]
    }
  },
  "labels": ["Excellent", "Good", "Average", "Poor"],
  "colours": ["#3d8b5e", "#68a67d", "#e8c170", "#c0695c"],
  "nets": {
    "NET POSITIVE": 60.7
  },
  "priority_metric": {
    "label": "Mean",
    "decimals": 1,
    "values": {
      "TOTAL::Total": 7.5,
      "REGION::North": 7.6
    }
  }
}
```

---

## 10. Error Handling & TRS Codes

### HTML Report TRS Codes

| Code | Module | Scenario |
|------|--------|----------|
| `IO_INVALID_PATH` | 04 | Output path missing, empty, or wrong extension |
| `IO_DIR_CREATE_FAILED` | 04 | Cannot create output directory |
| `IO_WRITE_FAILED` | 04 | File write failed |
| `IO_HTML_WRITE_FAILED` | 04 | Write error with exception details |
| `IO_HTML_SUBMODULE_MISSING` | 99 | Required R file not found in html_report directory |
| `DATA_MISSING` | 00 | all_results or banner_info is NULL or missing |
| `DATA_INVALID` | 00 | Invalid data structure (wrong types, missing fields) |
| `DATA_TRANSFORM_FAILED` | 99 | transform_for_html returned error |
| `DATA_EMPTY` | 99 | No questions successfully transformed |
| `CFG_INVALID` | 00 | config_obj is missing, NULL, or not a list |
| `CALC_TABLE_BUILD_FAILED` | 99 | No tables could be built |
| `CALC_PAGE_BUILD_FAILED` | 99 | Page assembly failed |
| `PKG_MISSING_JSONLITE` | 99 | jsonlite package not installed |
| `PKG_HTMLTOOLS_MISSING` | 99 | htmltools package not installed |
| `DASH_NO_RESULTS` | 05 | No analysis results available for dashboard |

### Console Output Pattern

All TRS refusals print to console for Shiny debugging:
```
┌─── TURAS ERROR ───────────────────────────────────────┐
│ Context: HTML Report: [step description]
│ Code: DATA_INVALID
│ Message: banner_info missing required fields: columns, letters
│ Fix: Ensure banner structure was created correctly
└───────────────────────────────────────────────────────┘
```

### Graceful Degradation

The system degrades gracefully when optional components fail:
- Missing logos → skipped with warning, no logo in header
- Dashboard transform fails → report generated without dashboard
- Chart build fails for one question → other charts still generated
- Individual table build fails → question skipped, others continue

---

## 11. Extending the System

### Adding a New Config Field

1. **Add to config builder** (`modules/tabs/lib/crosstabs/crosstabs_config.R`):
   ```r
   config_obj$my_new_field <- safe_logical(
     settings_lookup("my_new_field", settings_df),
     default = FALSE
   )
   ```

2. **Access in HTML report modules** using `config_obj$my_new_field %||% default_value`

3. **Document** in the Settings sheet reference

### Adding a New Chart Type

1. **Add detection logic** in `07_chart_builder.R`:
   ```r
   if (is_my_new_type(question_data)) {
     svg_html <- build_my_chart_svg(question_data, config_obj)
   }
   ```

2. **Add JS rebuild function** in `chart_picker.js`:
   ```javascript
   function buildMyChartSVG(data, keys, colours) {
     // Return SVG HTML string
   }
   ```

3. **Update `rebuildChart()`** to detect and dispatch to new chart type

### Adding a New Export Format

1. **Add export function** in `table_export_init.js` or new JS file:
   ```javascript
   function exportMyFormat(tableId) {
     var data = extractTableData(tableId);
     var blob = new Blob([formatted_data], {type: 'my/mimetype'});
     downloadBlob(blob, qCode + '_crosstab.ext');
   }
   ```

2. **Add button** in `03_page_builder.R` question controls section

3. **Ensure JS file load order** in `03_page_builder.R` if adding new file

### Adding a New Dashboard Metric Type

1. **Add detection logic** in `05_dashboard_transformer.R`:
   ```r
   if (metric_name == "MY_METRIC") {
     # Match rows where RowLabel or RowType matches
   }
   ```

2. **Add threshold config fields** in `06_dashboard_builder.R`:
   ```r
   my_metric = list(
     green = config_obj$dashboard_green_my_metric %||% 70,
     amber = config_obj$dashboard_amber_my_metric %||% 50
   )
   ```

3. **Add formatting** in `format_gauge_value()`:
   ```r
   if (type == "my_metric") return(sprintf("%.0f%%", value))
   ```

### Adding a New JavaScript Module

1. Create file in `modules/tabs/lib/html_report/js/`
2. Add to the JS embedding section in `03_page_builder.R`:
   ```r
   js_files <- c("core_navigation.js", "table_export_init.js",
                 "chart_picker.js", "slide_export.js",
                 "pinned_views.js", "my_new_module.js")
   ```
3. Respect load order - foundational modules first
4. Use ES5-compatible JavaScript (no `let`, `const`, `class`, arrow functions, template literals)
5. Test with `node --check my_new_module.js` for syntax validation

### Modifying CSS

CSS is generated as a string in `03_page_builder.R`. The CSS block is the `build_css()` function (or inline in `build_html_page()`).

- Use CSS custom properties (`var(--ct-brand)`) for themeable values
- Add print styles in the `@media print` block
- Use `ct-` prefix for all new class names

---

## 12. Testing & Debugging

### Running the Demo

```r
config_file <- "examples/tabs/demo_survey/Demo_Crosstab_Config.xlsx"
toolkit_path <- "modules/tabs/lib/run_crosstabs.R"
source(toolkit_path)
```

This generates both Excel and HTML output in `examples/tabs/demo_survey/Output/`.

### JavaScript Syntax Checking

After modifying any JS file:
```bash
node --check modules/tabs/lib/html_report/js/core_navigation.js
node --check modules/tabs/lib/html_report/js/chart_picker.js
node --check modules/tabs/lib/html_report/js/table_export_init.js
node --check modules/tabs/lib/html_report/js/slide_export.js
node --check modules/tabs/lib/html_report/js/pinned_views.js
```

### Browser DevTools Debugging

1. Open the generated HTML report in Chrome
2. Open DevTools (F12)
3. **Console tab:** Check for JavaScript errors
4. **Elements tab:** Inspect table structure, data attributes
5. **Application tab:** Check localStorage for `turas-help-seen`
6. **Network tab:** Not needed (everything is inline)

**Useful console commands:**
```javascript
// Check current state
console.log(currentGroup);
console.log(chartColumnState);
console.log(pinnedViews);

// Manually switch banner
switchBannerGroup('GENDER', document.querySelector('.banner-tab'));

// Check chart data for a question
var wrapper = document.querySelector('[data-q-code="Q001"] .chart-wrapper');
JSON.parse(wrapper.getAttribute('data-chart-data'));
```

### Common Issues

**"BANNER_GROUPS_JSON is not defined"**
- The R-side placeholder replacement failed
- Check that `banner_groups_json` is properly generated in `99_html_report_main.R`

**Charts not appearing**
- Verify `show_charts = TRUE` in config
- Check `build_chart_svg()` return value in R console
- Inspect `data-chart-data` attribute in DevTools

**Columns not toggling**
- Check CSS classes: `bg-{groupCode}` on `<th>` and `<td>` elements
- Verify `banner_groups` array matches actual group codes

**Heatmap colours wrong**
- Check `brand_colour` is valid 6-digit hex (e.g., `#323367` not `323367`)
- Verify `data-heatmap` attribute has valid RGBA value

**Print missing colours**
- Add `print-color-adjust: exact; -webkit-print-color-adjust: exact;` to relevant elements

---

## 13. Performance Considerations

### File Size Factors

| Factor | Impact | Mitigation |
|--------|--------|------------|
| Number of questions | ~20-50 KB per question | Split large studies across configs |
| Banner columns | ~5 KB per column per question | Limit banner groups |
| Embedded frequencies | ~30% larger | Set `embed_frequencies = FALSE` |
| Chart data JSON | ~2-10 KB per question | Disable charts if not needed |
| Logos (base64) | 10-500 KB per logo | Use SVG logos (smaller) |
| JavaScript modules | ~100 KB total | Fixed cost |
| CSS | ~50 KB | Fixed cost |

### Browser Performance

| Scenario | Impact | Notes |
|----------|--------|-------|
| 50 questions | Smooth | No issues |
| 100 questions | Minor delay on load | ~1-2 second sidebar render |
| 200+ questions | Noticeable delay | Banner switching may pause briefly |
| 10+ banner columns | Smooth | Column toggling is efficient |
| Large tables (50+ rows) | Smooth | Sorting is fast (DOM-based) |

### Optimisation Opportunities

1. **Virtualised question list** - Only render visible questions in sidebar (not implemented, rarely needed)
2. **Lazy chart rendering** - Only build charts when question is selected (not implemented)
3. **Web Workers** - Move sorting/filtering off main thread (not implemented, not needed at current scale)
4. **Compressed HTML** - gzip the output file (not implemented, browser handles this if served over HTTP)

---

## Appendix: Version History

| Version | Changes |
|---------|---------|
| 10.3.0 | Initial HTML report with plain HTML tables, vanilla JS |
| 10.4.0 | Dashboard summary with gauges and heatmap grid |
| 10.4.1 | Multi-section dashboard, Excel export per section, significant findings |
| 10.4.2 | Configurable colour thresholds, custom metric scales |
| 10.4.3 | Sig findings with resolved letter codes, full question text, descriptors |
| 10.5.0 | Advanced chart rendering with multi-column support, chart column picker |
| 10.6.0 | Pinned views, slide export, insight system, comments sheet, save/hydrate |

---

*This manual is intended for developers maintaining the Turas HTML report system. For end-user documentation, see the separate User Manual.*
