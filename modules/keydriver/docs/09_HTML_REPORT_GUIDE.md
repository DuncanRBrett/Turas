# HTML Report Guide

## Overview

The keydriver HTML report is a self-contained, interactive report generated alongside the standard Excel output. It presents driver importance results, diagnostics, effect sizes, correlation analysis, quadrant analysis, SHAP findings, bootstrap confidence intervals, and segment comparisons in a single navigable document.

The report is a standalone `.html` file that opens in any modern browser. It requires no server, no internet connection, and no additional software. All styles, scripts, and data are embedded in the file.

The HTML report is designed for three audiences:

- **Analysts** who need to explore results, add commentary, and build presentation slides
- **Stakeholders** who receive the report and want to navigate findings without opening Excel
- **Report Hub** integration, where multiple module reports are combined into a unified dashboard

## How to Enable

### From the Shiny GUI

When running keydriver through the Shiny GUI (`launch_turas.R`), check the **"Generate HTML Report"** checkbox in the settings panel. This overrides the config file setting.

### From the Config File

Add this setting to the **Settings** sheet of your config Excel file:

| Setting | Value |
|---------|-------|
| enable_html_report | TRUE |

### Optional Styling Settings

| Setting | Default | Description |
|---------|---------|-------------|
| brand_colour | #323367 | Primary brand colour (hex) |
| accent_colour | #f59e0b | Secondary accent colour (hex) |
| report_title | (analysis name) | Title displayed in report header |

The HTML report requires the `htmltools` R package. If it is not installed, the module will return a TRS refusal with code `PKG_HTMLTOOLS_MISSING`.

## Section Visibility Configuration

All sections can be independently shown or hidden via config settings. Add these to the **Settings** sheet. All default to TRUE.

| Setting | Section | Default |
|---------|---------|---------|
| html_show_exec_summary | Executive Summary | TRUE |
| html_show_importance | Driver Importance | TRUE |
| html_show_methods | Method Comparison | TRUE |
| html_show_effect_sizes | Effect Sizes | TRUE |
| html_show_correlations | Correlation Matrix | TRUE |
| html_show_quadrant | Quadrant Analysis | TRUE |
| html_show_shap | SHAP Analysis | TRUE |
| html_show_diagnostics | Model Diagnostics | TRUE |
| html_show_bootstrap | Bootstrap CIs | TRUE |
| html_show_segments | Segment Comparison | TRUE |
| html_show_guide | Interpretation Guide | TRUE |

Additionally, two display mode settings control how certain sections render:

| Setting | Default | Options | Description |
|---------|---------|---------|-------------|
| correlation_display | heatmap | heatmap, table, both | How the correlation matrix is displayed |
| bootstrap_display | summary | summary, full, table | How bootstrap CIs are displayed |

## Report Sections

The report contains up to eleven sections. Sections with no data are automatically omitted, regardless of visibility settings.

### Executive Summary

High-level overview with key insights about the most important drivers, standout findings, and sample size badges. Importance percentages are shown as whole numbers (e.g., 31% not 31.1%). Always present unless hidden via config.

### Driver Importance

The primary results section with a horizontal bar chart ranked from highest to lowest importance and a four-column importance table (Rank, Driver, Importance bar, %). Filter chips (All, Top 3, Top 5, Top 8) let you focus on the most relevant drivers. The chart and table are synchronized -- filtering updates both.

A methodology callout explains that the final importance percentages use Shapley value decomposition to fairly apportion the model's explanatory power across all drivers, and directs analysts to the Method Comparison section for cross-method agreement details.

### Method Comparison

Compares importance rankings across Correlation, Beta Weight, Relative Weight, and Shapley Value (plus SHAP if enabled). Includes:

- An agreement chart showing rank positions across methods
- A side-by-side comparison table
- An **Agreement** column (High/Medium/Low) based on rank consistency across methods -- High agreement means the driver's relative rank is consistent regardless of method

A callout explains each analytical method and how to interpret agreement between them.

### Effect Sizes

Standardised effect sizes (Cohen's f-squared or configured method) with benchmark bands. A callout explains the Cohen's f² benchmarks:

- **Large** (f² ≥ 0.35) -- substantial practical impact
- **Medium** (f² ≥ 0.15) -- moderate practical impact
- **Small** (f² ≥ 0.02) -- detectable but limited practical impact
- **Negligible** (f² < 0.02) -- trivial practical effect

Appears when effect size data is available in results.

### Correlation Matrix

Inter-driver correlation heatmap showing the strength of relationships between drivers. A callout explains that high correlations (above 0.7) indicate multicollinearity that can inflate beta weight uncertainty, and that this is why the report uses Shapley value decomposition as the primary importance method.

Display mode is controlled by the `correlation_display` config setting:

- **heatmap** (default): Colour-coded matrix only
- **table**: Numeric correlation table only
- **both**: Both heatmap and table

### Quadrant Analysis

Importance-Performance Analysis (IPA) mapping drivers onto a four-quadrant grid. Includes:

- A scatter chart with colour-shaded quadrants and label collision avoidance
- An action table with colour-coded action badges (IMPROVE, MAINTAIN, MONITOR, ASSESS)
- A priority callout explaining how priorities are determined
- An Action Guide callout explaining each action:
  - **IMPROVE** -- High importance, low performance. Priority investment area
  - **MAINTAIN** -- High importance, high performance. Protect current standards
  - **MONITOR** -- Low importance, low performance. Watch for changes
  - **ASSESS** -- Low importance, high performance. Evaluate resource allocation

Appears when `enable_quadrant = TRUE`.

### SHAP Analysis

Machine learning-based importance using XGBoost and TreeSHAP, providing a complementary non-linear perspective. Includes:

- A horizontal bar chart showing SHAP-derived importance percentages
- A callout explaining why SHAP values may differ from the primary driver importance analysis (SHAP captures non-linear relationships and interactions, while driver importance uses linear decomposition)

Appears when `enable_shap = TRUE`.

### Diagnostics

Statistical health checks with a prominent verdict banner at the top:

- **Reliable** (R² ≥ 0.50 + significant F-test)
- **Directionally reliable** (R² ≥ 0.25 + significant)
- **Interpret with caution** (R² ≥ 0.10 + significant)
- **Exploratory only** (low R² or not significant)

Also includes VIF for multicollinearity (values above 5 warrant attention; above 10 indicate serious multicollinearity), model R-squared, and pass/flag/fail indicators.

### Bootstrap Confidence Intervals

Forest-style CI chart with point estimates and error bars, plus a detailed table. Display mode is controlled by the `bootstrap_display` config setting:

- **summary** (default): Forest plot chart only
- **table**: CI table only
- **full**: Both chart and table

Appears when `enable_bootstrap = TRUE`. See `08_BOOTSTRAP_GUIDE.md` for interpretation guidance.

### Segment Comparison

Side-by-side importance scores across defined customer segments, with:

- A grouped horizontal bar chart showing per-segment importance percentages with a curated colour palette
- A comparison table with segment toggle chips (click to show/hide specific segments)
- Sort functionality (click column headers to sort by a segment's values)
- Highlights for drivers whose importance varies substantially between segments

Appears when segments are defined in config.

### Interpretation Guide

Built-in reference explaining the statistical methods, how to read charts and tables, and common caveats. Always present unless hidden via config.

## Navigation

The report uses a two-level tab structure:

1. **Report tabs** -- A top-level tab bar with "Analysis" and "Pinned Views" tabs
2. **Section nav bar** -- Within the Analysis tab, a horizontal nav bar pinned below the report header containing a link for each visible section

Clicking a section link smoothly scrolls to that section. As you scroll, the active link updates automatically to reflect the currently visible section. The nav bar remains sticky so you can jump to any section at any time.

In unified mode (Report Hub), each analysis panel has its own independently operating section nav bar.

## Pinned Views

Pinned views let you collect specific sections, charts, or tables into a curated panel for presentation or export. Access pinned views by clicking the "Pinned Views" tab at the top of the report.

### How to Pin

Each section header has a pin button on the right side. Click it to pin the entire section (chart, table, and any analyst insight) to the Pinned Views panel. Click again to unpin. You can also pin individual components (chart only or table only) using smaller pin buttons on chart and table containers.

### The Pinned Views Panel

Located in the Pinned Views tab. Contains a card for each pinned view with the section title, chart, table, and analyst insight. A badge in the report tab bar shows the pin count. Each card has controls to move up, move down, export as PNG, or remove.

### Reordering

Use the up/down arrow buttons on each pinned card to build a logical narrative sequence for your presentation.

### Section Dividers

Click "Add Section" in the Pinned Views toolbar to insert a divider between pins. Divider titles are editable -- click the title text to rename. Use dividers to organize pins into groups (e.g., "Key Findings", "Deep Dive", "Appendix"). Dividers appear as heading strips when printing or exporting.

### Analyst Insights

Each section in the main report has an insight text area. Type your commentary there before pinning -- the insight text is captured along with the chart and table. Insights appear as styled callout blocks in pinned cards, print output, and PNG exports. Insights are preserved when you save the report.

## Slide Export

Pinned views can be exported as presentation-quality PNG images at 1280x720 resolution (standard 16:9 landscape), rendered at 3x scale for crisp output on high-DPI screens.

### Exporting a Single Slide

Click the export button on any pinned card. The PNG downloads with a filename derived from the panel label and section title. Each slide includes a brand bar, title, analyst insight callout (if present), chart, table (limited to 12 rows and 8 columns for readability), and a footer with method, sample size, date, and Turas branding.

### Quadrant Slide Layout

When a quadrant analysis pin is exported, the slide uses a side-by-side layout: chart on the left (55% width) and action table on the right (45% width). Below both, an action guide legend strip shows the four action types (IMPROVE, MAINTAIN, MONITOR, ASSESS) with colour-coded badges and descriptions.

### Exporting All Slides

Click "Export All as PNG" in the Pinned Views toolbar. Exports are staggered by 500ms to avoid overwhelming the browser's download queue. The 1280x720 dimensions match standard presentation aspect ratios for direct insertion into PowerPoint, Google Slides, or Keynote.

## Saving

Click the **Save** button in the action bar. This downloads the complete HTML file with all current state preserved: analyst insights, pinned views and their order, and section divider titles.

The saved file has `_Updated` appended to the filename. When reopened, a hydration routine automatically restores all insights, pinned views, and pin button states. No user action is required.

| State | Preserved on Save? |
|-------|-------------------|
| Analyst insight text | Yes |
| Pinned views and order | Yes |
| Section divider titles | Yes |
| Chart/table data | Yes (embedded) |
| Importance filter selection | No (resets on reload) |

## Printing

### Standard Print

Click the **Print** button in the action bar to open the browser's print dialog.

### Printing Pinned Views

Click "Print Pinned Views" in the Pinned Views toolbar. This generates an A4 landscape layout with one pinned view per page, section dividers as heading strips, a project header on the first page, and page numbers. A screen preview appears before printing. Click "Close Preview" to cancel, or proceed to save as PDF.

## Report Hub Integration

The HTML report embeds metadata tags (`turas-report-type`, `turas-module-version`, `turas-source-filename`) that the Report Hub reads to identify and catalogue it. All CSS classes and JavaScript functions use the `kd-` prefix to avoid namespace collisions with other modules (tabs uses `ct-`, tracker uses `trk-`, catdriver uses `cd-`).

In unified mode, the keydriver sections are displayed within their own panel with an independently operating section nav bar. Pinned views include a panel label so the source is clear when combined with pins from other modules.

## Troubleshooting

### "Package 'htmltools' is required"

Install the package:

```r
renv::install("htmltools")
```

### HTML Report File Is Very Large

Large files are typically caused by many drivers (20+), SHAP visualizations, or many segment comparisons. Reduce driver count or limit segments. The file compresses well as a .zip for transfer.

### Report Does Not Display Correctly

Ensure JavaScript is enabled. Test in Chrome, Firefox, Safari, or Edge (Internet Explorer is not supported). Check for browser extensions that block scripts or modify styles.

### Charts Are Missing

Check the R console for `[WARN]` messages about chart build failures. The report will still render with tables if chart generation fails for a section.

### Pinned Views Are Lost

Pinned views are only preserved if you use the Save button. Reloading the original unsaved report will not retain pins. Always save after adding insights or pinning views.

### PNG Export Produces a Blank Image

Slide export uses the browser's Canvas API. Check the developer console (F12) for errors. The report uses system fonts to avoid Canvas font resolution issues.

### GUI Checkbox Has No Effect

If checking "Generate HTML Report" in the Shiny GUI does not produce an HTML file, ensure that the keydriver module has been properly sourced. The GUI checkbox overrides the config file setting, but the HTML report library files must be present in `modules/keydriver/lib/html_report/`.

### Sections Are Missing

Sections are conditionally included based on both data availability and visibility settings:

| Section | Requires |
|---------|----------|
| Executive Summary | Always present (unless html_show_exec_summary = FALSE) |
| Driver Importance | Always present (unless html_show_importance = FALSE) |
| Method Comparison | Always present (unless html_show_methods = FALSE) |
| Effect Sizes | Effect size data in results + html_show_effect_sizes = TRUE |
| Correlation Matrix | Correlation data in results + html_show_correlations = TRUE |
| Quadrant Analysis | enable_quadrant = TRUE + html_show_quadrant = TRUE |
| SHAP Analysis | enable_shap = TRUE + html_show_shap = TRUE |
| Diagnostics | Model diagnostics in results + html_show_diagnostics = TRUE |
| Bootstrap CIs | enable_bootstrap = TRUE + html_show_bootstrap = TRUE |
| Segment Comparison | Segments defined in config + html_show_segments = TRUE |
| Interpretation Guide | Always present (unless html_show_guide = FALSE) |

If an expected section is missing, verify the corresponding feature is enabled and check the console for TRS refusal messages.
