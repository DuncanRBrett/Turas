# HTML Report Guide

## Overview

The keydriver HTML report is a self-contained, interactive report generated alongside the standard Excel output. It presents driver importance results, diagnostics, effect sizes, correlation analysis, quadrant analysis, SHAP findings, bootstrap confidence intervals, and segment comparisons in a single navigable document.

The report is a standalone `.html` file that opens in any modern browser. It requires no server, no internet connection, and no additional software. All styles, scripts, and data are embedded in the file.

The HTML report is designed for three audiences:

- **Analysts** who need to explore results, add commentary, and build presentation slides
- **Stakeholders** who receive the report and want to navigate findings without opening Excel
- **Report Hub** integration, where multiple module reports are combined into a unified dashboard

## How to Enable

Add this setting to the **Settings** sheet of your config Excel file:

| Setting | Value |
|---------|-------|
| enable_html_report | TRUE |

Optional styling settings:

| Setting | Default | Description |
|---------|---------|-------------|
| brand_colour | #ec4899 | Primary brand colour (hex) |
| accent_colour | #f59e0b | Secondary accent colour (hex) |
| report_title | (analysis name) | Title displayed in report header |

The HTML report requires the `htmltools` R package. If it is not installed, the module will return a TRS refusal with code `PKG_HTMLTOOLS_MISSING`.

When running keydriver through the Shiny GUI, check the "Generate HTML Report" checkbox in the settings panel.

## Report Sections

The report contains up to eleven sections. Sections with no data are automatically omitted.

### Executive Summary

High-level overview with key insights about the most important drivers, standout findings, and sample size badges. Always present.

### Driver Importance

The primary results section with a horizontal bar chart ranked from highest to lowest importance, an importance table with significance indicators, and filter chips to show all drivers, top 3, top 5, top 8, or only statistically significant drivers. The chart and table are synchronized -- filtering updates both.

### Method Comparison

Compares importance rankings across Correlation, Beta Weight, and Relative Weight. Includes an agreement chart showing rank positions across methods and a side-by-side comparison table.

### Effect Sizes

Standardized effect sizes (Cohen's f-squared or configured method) with benchmark bands for small, medium, and large effects. Appears when effect size data is available.

### Correlation Matrix

Inter-driver correlation heatmap and numeric table. High correlations (above 0.7) indicate multicollinearity that can inflate beta weight uncertainty.

### Quadrant Analysis

Importance-Performance Analysis mapping drivers onto a four-quadrant grid. Includes a scatter chart and action table with prioritized recommendations. The quadrants are: Concentrate Here (high importance, low performance), Keep Up the Good Work (high importance, high performance), Low Priority (low importance, low performance), and Possible Overkill (low importance, high performance). Appears when `enable_quadrant = TRUE`.

### SHAP Analysis

Machine learning-based importance using XGBoost and TreeSHAP, providing a complementary non-linear perspective. Appears when `enable_shap = TRUE`.

### Diagnostics

Statistical health checks: VIF for multicollinearity, model R-squared, residual diagnostics, and pass/flag/fail indicators. VIF values above 5 warrant attention; above 10 indicate serious multicollinearity.

### Bootstrap Confidence Intervals

Forest-style CI chart with point estimates and error bars, plus a detailed table. Appears when `enable_bootstrap = TRUE`. See `08_BOOTSTRAP_GUIDE.md` for interpretation guidance.

### Segment Comparison

Side-by-side importance scores across defined customer segments, with highlights for drivers whose importance varies substantially between segments. Appears when segments are defined in config.

### Interpretation Guide

Built-in reference explaining the statistical methods, how to read charts and tables, and common caveats. Always present.

## Navigation

A horizontal tab bar is pinned below the report header, containing a tab for each visible section. Clicking a tab smoothly scrolls to that section. As you scroll, the active tab updates automatically to reflect the currently visible section. The nav bar remains sticky so you can jump to any section at any time.

## Pinned Views

Pinned views let you collect specific sections, charts, or tables into a curated panel for presentation or export.

### How to Pin

Each section header has a pin button on the right side. Click it to pin the entire section (chart, table, and any analyst insight) to the Pinned Views panel. Click again to unpin. You can also pin individual components (chart only or table only) using smaller pin buttons on chart and table containers.

### The Pinned Views Panel

Located at the bottom of the report. Contains a card for each pinned view with the section title, chart, table, and analyst insight. A badge in the nav bar shows the pin count. Each card has controls to move up, move down, export as PNG, or remove.

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

### Sections Are Missing

Sections are conditionally included:

| Section | Requires |
|---------|----------|
| Executive Summary | Always present |
| Driver Importance | Always present |
| Method Comparison | Always present |
| Effect Sizes | Effect size data in results |
| Correlation Matrix | Correlation data in results |
| Quadrant Analysis | enable_quadrant = TRUE |
| SHAP Analysis | enable_shap = TRUE |
| Diagnostics | Model diagnostics in results |
| Bootstrap CIs | enable_bootstrap = TRUE |
| Segment Comparison | Segments defined in config |
| Interpretation Guide | Always present |

If an expected section is missing, verify the corresponding feature is enabled and check the console for TRS refusal messages.
