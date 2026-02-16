---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas HTML Report — User Guide

## What It Does

The HTML Report generates a **self-contained, interactive HTML file**
alongside your standard Excel crosstabs. It has two tabs:

1.  **Summary Dashboard** — Headline metrics at a glance: gauges,
    heatmap grids, and significant findings
2.  **Crosstabs Explorer** — Full interactive crosstab tables with
    search, banner switching, heatmap colouring, and export

The HTML file works offline (no internet required), opens in any modern
browser, and can be shared as a single file.

------------------------------------------------------------------------

## Quick Start

Add these two rows to your **Settings sheet** and re-run:

| Setting             | Value          |
|---------------------|----------------|
| `html_report`       | `TRUE`         |
| `dashboard_metrics` | `NET POSITIVE` |

That's it. The HTML file will appear in the same folder as your Excel
output, with the same filename but `.html` extension.

------------------------------------------------------------------------

## Settings Reference

All settings go in the **Settings sheet** of your config workbook
(Column A = Setting name, Column B = Value). Every setting below is
**optional** — sensible defaults apply if omitted.

### Core Settings

| Setting | Default | Description |
|------------------------|------------------------|------------------------|
| `html_report` | `FALSE` | Set to `TRUE` to generate the HTML report |
| `project_title` | *(from config)* | Title shown in the page header (e.g., "SACAP Student Annual 2025") |
| `brand_colour` | `#0d8a8a` | Primary accent colour — used for buttons, highlights, gauges. Any valid hex code |
| `embed_frequencies` | `TRUE` | Include frequency counts (n=) inside table cells. Set `FALSE` to reduce file size |
| `include_summary` | `TRUE` | Show the Summary Dashboard tab. Set `FALSE` for crosstabs-only |
| `fieldwork_dates` | *(none)* | Text shown in the metadata strip (e.g., "Sep - Nov 2025") |
| `show_charts` | `FALSE` | Set to `TRUE` to enable inline SVG charts below crosstab tables |
| `index_descriptor` | *(none)* | Descriptive text shown below the Index row label explaining the scale (e.g., "Strongly disagree(1) = 1 to Strongly agree(5) = 5") |

### Dashboard Metrics

| Setting | Default | Description |
|------------------------|------------------------|------------------------|
| `dashboard_metrics` | `NET POSITIVE` | Comma-separated list of metric types to display. See **Metric Types** below |

### Colour Thresholds

The dashboard uses a **traffic light system**: Green (strong), Amber
(moderate), Red (concern). You configure the breakpoints for each metric
type.

**How it works:** Value \>= green threshold = Green. Value \>= amber
threshold = Amber. Below amber = Red.

#### NET / NPS Thresholds

| Setting | Default | Description |
|------------------------|------------------------|------------------------|
| `dashboard_green_net` | `30` | NET/NPS score at or above this = **Green** |
| `dashboard_amber_net` | `0` | NET/NPS score at or above this = **Amber** (below green) |

Scale is always -100 to +100 (fixed, not configurable).

#### Mean Thresholds

| Setting | Default | Description |
|------------------------|------------------------|------------------------|
| `dashboard_scale_mean` | `10` | Maximum of the Mean scale (e.g., `10` for 0-10, `100` for 0-100) |
| `dashboard_green_mean` | `7` | Mean at or above this = **Green** |
| `dashboard_amber_mean` | `5` | Mean at or above this = **Amber** |

#### Index Thresholds

| Setting | Default | Description |
|------------------------|------------------------|------------------------|
| `dashboard_scale_index` | `10` | Maximum of the Index scale (e.g., `10` for 0-10, `100` for 0-100) |
| `dashboard_green_index` | `7` | Index at or above this = **Green** |
| `dashboard_amber_index` | `5` | Index at or above this = **Amber** |

#### Custom % Thresholds

These apply to custom label metrics (e.g., "Good or excellent"). Values
are always percentages.

| Setting                  | Default | Description                             |
|------------------------|------------------------|------------------------|
| `dashboard_green_custom` | `60`    | Percentage at or above this = **Green** |
| `dashboard_amber_custom` | `40`    | Percentage at or above this = **Amber** |

> **Note:** All custom label metrics share the same thresholds. If you
> have multiple custom labels, they all use `dashboard_green_custom` and
> `dashboard_amber_custom`.

------------------------------------------------------------------------

## Dashboard Metric Types

The `dashboard_metrics` setting accepts a comma-separated list. Each
type creates its own section with gauges + heatmap grid.

### Built-in Types

| Config Value | What It Matches | Value Range | Example |
|------------------|------------------|------------------|------------------|
| `NET POSITIVE` | Rows labelled "NET POSITIVE" (Column %) | -100 to +100 | `+42` |
| `NPS` or `NPS Score` | NPS Score rows (RowType = "Score") | -100 to +100 | `+45` |
| `Mean` | Average/Mean rows (RowType = "Average") | 0 to scale | `7.2` |
| `Index` | Index rows (RowType = "Index") | 0 to scale | `82.0` |

### Custom Labels

Any text that matches a row label in your crosstabs. The match is
case-insensitive.

| Config Value | What It Matches | Example Questions |
|------------------------|------------------------|------------------------|
| `Good or excellent` | Box-category row labelled "Good or excellent" | Rating questions with top-box summary |
| `Very Satisfied (9-10)` | Category row with that label | Satisfaction scales |
| `Fully trust` | Category row labelled "Fully trust" | Trust questions |
| `Top 2 Box` | Aggregated category row | Any rating with top-2-box summary |

Custom labels always use **percentage thresholds**
(`dashboard_green_custom` / `dashboard_amber_custom`).

### Examples

**Single metric:**

```         
dashboard_metrics = NET POSITIVE
```

**Multiple metrics:**

```         
dashboard_metrics = NET POSITIVE, NPS Score, Mean
```

**Mix of built-in and custom:**

```         
dashboard_metrics = NET POSITIVE, Mean, Good or excellent
```

**Custom only:**

```         
dashboard_metrics = Very Satisfied (9-10), Fully trust
```

------------------------------------------------------------------------

## Complete Config Examples

### Example 1: Simple NET POSITIVE Report

| Setting             | Value                   |
|---------------------|-------------------------|
| `html_report`       | `TRUE`                  |
| `project_title`     | `Brand Tracker Q4 2025` |
| `brand_colour`      | `#1a5276`               |
| `dashboard_metrics` | `NET POSITIVE`          |

Everything else defaults. Green \>= +30, Amber \>= 0, Red \< 0.

### Example 2: NPS + Mean (Scale 0-10)

| Setting                | Value                        |
|------------------------|------------------------------|
| `html_report`          | `TRUE`                       |
| `project_title`        | `Customer Satisfaction 2025` |
| `fieldwork_dates`      | `Sep - Nov 2025`             |
| `dashboard_metrics`    | `NPS Score, Mean`            |
| `dashboard_scale_mean` | `10`                         |
| `dashboard_green_mean` | `8`                          |
| `dashboard_amber_mean` | `6`                          |

### Example 3: Index on 0-100 Scale

| Setting                 | Value                 |
|-------------------------|-----------------------|
| `html_report`           | `TRUE`                |
| `dashboard_metrics`     | `NET POSITIVE, Index` |
| `dashboard_scale_index` | `100`                 |
| `dashboard_green_index` | `70`                  |
| `dashboard_amber_index` | `50`                  |

### Example 4: Custom Labels with Tight Breaks

| Setting                  | Value                             |
|--------------------------|-----------------------------------|
| `html_report`            | `TRUE`                            |
| `dashboard_metrics`      | `Good or excellent, NET POSITIVE` |
| `dashboard_green_custom` | `70`                              |
| `dashboard_amber_custom` | `50`                              |
| `dashboard_green_net`    | `40`                              |
| `dashboard_amber_net`    | `10`                              |

### Example 5: Everything (Kitchen Sink)

| Setting | Value |
|------------------------------------|------------------------------------|
| `html_report` | `TRUE` |
| `project_title` | `SACAP Student Annual 2025` |
| `brand_colour` | `#0d8a8a` |
| `fieldwork_dates` | `Sep - Nov 2025` |
| `embed_frequencies` | `TRUE` |
| `include_summary` | `TRUE` |
| `show_charts` | `TRUE` |
| `index_descriptor` | `Strongly disagree(1) = 1 to Strongly agree(5) = 5` |
| `dashboard_metrics` | `NPS Score, NET POSITIVE, Index, Good or excellent` |
| `dashboard_scale_mean` | `10` |
| `dashboard_scale_index` | `100` |
| `dashboard_green_net` | `30` |
| `dashboard_amber_net` | `0` |
| `dashboard_green_mean` | `7` |
| `dashboard_amber_mean` | `5` |
| `dashboard_green_index` | `70` |
| `dashboard_amber_index` | `50` |
| `dashboard_green_custom` | `60` |
| `dashboard_amber_custom` | `40` |

------------------------------------------------------------------------

## The Summary Dashboard

When `include_summary = TRUE` (the default), the first tab shows an
at-a-glance dashboard.

### Components

#### 1. Metadata Strip

Four cards across the top: - **Total Respondents** — Sample size
(weighted if applicable) - **Fieldwork** — Date range from
`fieldwork_dates` setting - **Questions Analysed** — Number of questions
processed - **Banner Groups** — Count and names (e.g., "Campus -
Course - Age")

#### 2. Colour Legend

Shows the actual configured thresholds so readers know what the colours
mean:

```         
Colour Key:
🟢 Strong (NET≥+30 / Mean≥7.0 / %≥60)
🟠 Moderate (NET≥+0 / Mean≥5.0 / %≥40)
🔴 Concern (NET<+0 / Mean<5.0 / %<40)
```

#### 3. Gauge Cards (per metric type section)

Each headline metric gets a semi-circular gauge showing the **Total**
value: - Colour reflects the traffic light threshold (green/amber/red) -
Full question text displayed below with wrapping - Type badge shows the
metric category (NET POSITIVE, NPS, MEAN, INDEX, or the custom label)

#### 4. Heatmap Grid (per metric type section)

A compact matrix showing **all metrics across all banner columns**: -
Rows = questions - Columns = Total + each banner group's columns - Cells
colour-coded by value (4-tier: strong green, light green, amber, red) -
Banner group labels as column headers (e.g., "Campus" not "Q002") -
**Export Excel** button downloads the heatmap as a colour-coded
spreadsheet

#### 5. Significant Findings

Cards showing statistically significant differences on headline
metrics: - **Three badges:** Question code, Banner group name, Metric
type - **Full question text** (wraps naturally) - **Comparison text:**
e.g., "Pretoria 86% vs Total 83% — sig. higher than Cape Town (79%)" -
Only shows **within-group** comparisons (Campus vs Campus, not Campus vs
Age) - Only appears if `enable_significance_testing = TRUE`

------------------------------------------------------------------------

## The Crosstabs Explorer

The second tab provides a full interactive crosstab viewer.

### Sidebar

-   **Search box** — Type to filter questions by code or text
-   **Question list** — Click any question to view it
-   **Legend** — Explains significance badges and low-base warnings

### Banner Group Tabs

Buttons across the top to switch between banner groupings (e.g., Campus,
Course, Age). The Total column is always visible.

### Display Controls

| Control | What It Does | Default |
|------------------------|------------------------|------------------------|
| **Heatmap** (checkbox) | Toggles background colours on percentage cells | ON |
| **Show count** (checkbox) | Shows/hides frequency counts (n=) below percentages | OFF |
| **Chart** (checkbox) | Shows/hides inline SVG charts below each table | OFF |

> **Important:** The "Show count" toggle only works when
> `embed_frequencies = TRUE` in your config. If set to `FALSE`, the
> counts are not included in the HTML file and the toggle has nothing to
> show.
>
> The "Chart" toggle only appears when `show_charts = TRUE` in your
> config.

### Table Features

-   **Sticky labels** — Question text stays visible when scrolling
    horizontally
-   **Significance badges** — Green "▲AB" badges show which columns are
    significantly higher
-   **Low base warnings** — Orange warning icon and dimmed cells for
    bases under 30
-   **NET rows** — Highlighted with beige background
-   **Mean/Index rows** — Highlighted with pale yellow, italic values
-   **Index descriptor** — When `index_descriptor` is set in config,
    a small annotation appears below the Index row label explaining
    the scale weights (e.g., "Strongly disagree(1) = 1 to Strongly
    agree(5) = 5")
-   **Base row** — Shows sample size per column

### Inline Charts

When `show_charts = TRUE`, each question gets an inline SVG chart
displayed below its crosstab table. Charts are toggled on/off with
the **Chart** checkbox in the controls bar.

#### Chart Types

| Question Type | Chart Style | What It Shows |
|---------------|-------------|---------------|
| Likert, Rating, NPS | **Stacked horizontal bar** | Category distribution as proportional segments |
| Single_Response | **Horizontal bar chart** | Individual bars per category |

#### Box Categories vs Individual Items

Charts automatically detect **box categories** from the Survey
Structure Options sheet. When box categories are defined for a
question (e.g., Negative / Neutral / Positive), the chart shows
those summary categories rather than individual scale points. If
no box categories exist, individual response items are charted.

#### Semantic Colours

Known category labels are assigned meaningful colours automatically:

| Label | Colour |
|-------|--------|
| Negative, Poor, Dissatisfied, Detractor | Warm red |
| Neutral, Average, Passive, Undecided | Warm grey |
| Positive, Good or excellent, Satisfied, Promoter | Green |

Unknown labels fall back to a gradient of the configured
`brand_colour`.

#### Chart Labels

Labels are sized dynamically to accommodate long text without
truncation. Stacked bar legends wrap to multiple rows when needed.

### Export

Each question table has export buttons:

-   **Export Excel** — Downloads as `.xls` with formatting preserved
-   **Export CSV** — Downloads as plain `.csv`
-   **Export Chart** — Downloads the chart as a high-resolution PNG
    (3x scale, presentation-ready). Only visible when charts are
    toggled on.

The exported PNG includes the question code and text as a title at
the top, making it self-contained for pasting into PowerPoint or
other presentations. The on-screen chart does not show this title
(since the question card above already displays it).

Exports respect the current state: if "Show count" is on, counts are
included in the table exports.

### Print Report

The **Print Report** button (🖨) in the controls bar generates a
clean, paginated print layout:

-   **All questions** are shown (not just the active one)
-   **Active banner only** — prints whichever banner group is
    currently selected (e.g., "by Campus")
-   **One question per page** with page breaks between questions
-   **Charts included** if they have content
-   **UI elements hidden** — sidebar, toggles, export buttons, and
    navigation are stripped from the printed output
-   **Compact table styling** — smaller font and tighter padding for
    better fit on paper

To print a different banner, switch to it first (e.g., click "Age")
then click Print Report again.

------------------------------------------------------------------------

## Colour Reference

### Traffic Light Colours

| Tier      | Colour       | Hex       | When                                    |
|------------------|------------------|------------------|------------------|
| **Green** | Green        | `#059669` | Value \>= green threshold               |
| **Amber** | Amber/Orange | `#d97706` | Value \>= amber threshold (below green) |
| **Red**   | Red          | `#dc2626` | Value \< amber threshold                |

### Heatmap (4-tier gradient)

| Tier | Style | When |
|------------------------|------------------------|------------------------|
| **Strong green** | Dark green background, bold text | Well above green threshold |
| **Light green** | Light green background | At or just above green threshold |
| **Amber** | Light amber background | Between amber and green |
| **Red** | Light red background | Below amber threshold |

The "strong green" tier is calculated automatically — no config needed.
It kicks in at approximately one-third of the way between the green
threshold and the scale maximum.

------------------------------------------------------------------------

## Output Files

When `html_report = TRUE`, two files are generated:

| File  | Example                | Content                          |
|-------|------------------------|----------------------------------|
| Excel | `SACAP_Crosstabs.xlsx` | Standard crosstab workbook       |
| HTML  | `SACAP_Crosstabs.html` | Interactive report (same folder) |

The HTML file is **fully self-contained** — all CSS, JavaScript, and SVG
graphics are inline. No external files or internet connection needed.

**Typical file size:** 2-10 MB depending on number of questions,
categories, and banner complexity.

------------------------------------------------------------------------

## Troubleshooting

### HTML file not generated

| Check | Fix |
|------------------------------------|------------------------------------|
| Is `html_report = TRUE` in Settings? | Add the row to your Settings sheet |
| Check the R console for errors | Look for `[TURAS ERROR]` or `[WARNING]` messages |
| Is `htmltools` package installed? | Run `install.packages("htmltools")` |

### Dashboard is empty / "No headline metrics detected"

| Check | Fix |
|------------------------------------|------------------------------------|
| Is `dashboard_metrics` set? | Add it to Settings (e.g., `NET POSITIVE`) |
| Does your data have the right rows? | Check that crosstabs include NET POSITIVE / Mean / NPS rows |
| Check the console | Look for `[Dashboard] No metrics found for type 'X'` message |
| Custom label not matching? | Ensure the label text matches exactly (case-insensitive) |

### "Show count" checkbox does nothing

| Check | Fix |
|------------------------------------|------------------------------------|
| Is `embed_frequencies = TRUE`? | Set to `TRUE` in Settings, or remove the row (defaults to TRUE) |
| If set to FALSE or N | Change to `TRUE` and re-generate |

### All gauges are red (even good scores)

| Check | Fix |
|------------------------------------|------------------------------------|
| Scale mismatch | If your Mean is 0-100, set `dashboard_scale_mean = 100` |
| Thresholds too high | Lower `dashboard_green_mean` / `dashboard_amber_mean` |
| Index on wrong scale | Set `dashboard_scale_index` to match your data (10 or 100) |

### Significance findings show wrong comparisons

| Check | Fix |
|------------------------------------|------------------------------------|
| Cross-group comparisons (Campus vs Age) | Fixed in V10.4.3 — only same-group comparisons shown |
| Letters instead of names | Fixed in V10.4.3 — shows column names and values |

### Charts not appearing

| Check | Fix |
|------------------------------------|------------------------------------|
| Is `show_charts = TRUE` in Settings? | Add the row to your Settings sheet |
| No "Chart" checkbox in controls bar? | Charts require `show_charts = TRUE` |
| Chart toggle is on but no chart for a question? | Charts require a Survey Structure file with an Options sheet. Composite metrics do not get charts |
| Labels truncated in chart? | Fixed in V10.5.0 — label width is now dynamic based on longest label |

### Chart export downloads blank or broken PNG

| Check | Fix |
|------------------------------------|------------------------------------|
| Browser compatibility | Use Chrome, Edge, or Firefox. Safari may have issues with SVG-to-canvas rendering |
| Very large chart | Try a smaller browser zoom level before exporting |

### Index descriptor not showing

| Check | Fix |
|------------------------------------|------------------------------------|
| Is `index_descriptor` set? | Add it to Settings with the scale description text |
| Only shows on Index rows | The descriptor appears below the "Index" row label in Likert/Rating tables that have an Index row |

### Last heatmap row clipped in Safari

| Check | Fix |
|------------------------------------|------------------------------------|
| Browser rendering issue | Fixed in V10.4.3 — added bottom padding to heatmap container |

------------------------------------------------------------------------

## Version History

| Version | Changes |
|------------------------------------|------------------------------------|
| **V10.5.1** | Print Report button (all questions, active banner, one per page); compact print styling |
| **V10.5.0** | Inline SVG charts (stacked bar for ordinal, horizontal bar for nominal); automatic box category detection from Survey Structure; semantic colour palette; PNG chart export with question title injection (3x resolution, PowerPoint-ready); configurable `index_descriptor` annotation for Index rows; dynamic chart label sizing; legend row wrapping |
| **V10.4.3** | Resolved sig letter codes to column names + values; banner group labels instead of Q codes; full question text with wrapping; metric type badge on sig findings; NPS Score config matching; Safari table clipping fix |
| **V10.4.2** | Configurable colour breaks via Settings; configurable Mean/Index scale; colour legend with actual thresholds; sig findings show value vs Total context |
| **V10.4.1** | Multi-section dashboard (one section per metric type); heatmap Excel export; custom metric type support |
| **V10.4.0** | Initial HTML report with Summary Dashboard and Crosstabs Explorer |
