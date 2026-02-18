# Turas Tabs HTML Report - User Manual

**Version:** 10.6.0
**Product:** Turas Analytics Platform - Crosstabs Module
**Publisher:** The Research LampPost (Pty) Ltd

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Getting Started](#2-getting-started)
3. [Configuration Reference](#3-configuration-reference)
   - [Settings Sheet](#31-settings-sheet)
   - [Selection Sheet](#32-selection-sheet)
   - [Comments Sheet](#33-comments-sheet)
   - [Instructions Sheet](#34-instructions-sheet)
4. [Using the HTML Report](#4-using-the-html-report)
   - [Report Layout](#41-report-layout)
   - [Navigating Questions](#42-navigating-questions)
   - [Banner Groups](#43-banner-groups)
   - [Reading Tables](#44-reading-tables)
   - [Dashboard Summary](#45-dashboard-summary)
   - [Charts](#46-charts)
   - [Adding Insights](#47-adding-insights)
   - [Pinned Views](#48-pinned-views)
   - [Exporting Data](#49-exporting-data)
   - [Printing](#410-printing)
5. [Browser Compatibility & Known Issues](#5-browser-compatibility--known-issues)

---

## 1. Introduction

The Turas Tabs HTML Report is an interactive, self-contained HTML document generated from your crosstabulation analysis. It provides a rich, browser-based interface for exploring survey crosstab results without needing Excel or any other software installed.

**Key benefits:**

- **Self-contained** - A single `.html` file with no external dependencies. Open it in any modern browser.
- **Interactive** - Filter, sort, toggle columns, switch banner groups, and explore data dynamically.
- **Presentation-ready** - Export individual slides as high-resolution PNG images for PowerPoint, or print the entire report as PDF.
- **Collaborative** - Add written insights per question and per banner group, then save the report with your annotations embedded.
- **Dashboard view** - Headline metrics with traffic-light colour coding give you an instant overview of results.

---

## 2. Getting Started

### Running the Analysis

To generate an HTML report, you need three files:

1. **Configuration file** (`.xlsx`) - Defines what to analyse and how to display it
2. **Survey structure file** (`.xlsx`) - Defines questions, response options, and variable types
3. **Survey data file** (`.xlsx` or `.csv`) - The raw response data

**Quick start:**

```r
config_file <- "path/to/your/Config.xlsx"
toolkit_path <- "modules/tabs/lib/run_crosstabs.R"
source(toolkit_path)
```

Or launch via the Shiny GUI:

```r
source("launch_turas.R")
launch_turas()
```

Select your configuration file when prompted. The system generates both an Excel workbook and (if enabled) an HTML report in your configured output folder.

### Opening the Report

The HTML report is saved alongside your Excel output. Simply double-click the `.html` file to open it in your default browser. No internet connection is required.

---

## 3. Configuration Reference

The configuration file is an Excel workbook with up to four sheets. Every aspect of the analysis and HTML report is controlled through these sheets.

### 3.1 Settings Sheet

The Settings sheet has two columns: **Setting** (the field name) and **Value** (what you set it to). Below is a complete reference of every field.

#### File Paths & Output

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `structure_file` | Yes | *(none)* | Path to your survey structure Excel file. Can be absolute or relative to the config file location. |
| `output_subfolder` | No | `Crosstabs` | Folder name for output files. Created automatically if it does not exist. Relative to the config file directory. |
| `output_filename` | No | `Crosstabs.xlsx` | Name of the Excel output file. The HTML report uses the same name with `.html` extension. |
| `output_format` | No | `xlsx` | Output format. Use `xlsx` for Excel (recommended) or `csv` for comma-separated. |

#### Weighting

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `apply_weighting` | No | `FALSE` | Set to `TRUE` or `Y` to apply survey weights. Weights adjust for sample bias so results better represent the population. |
| `weight_variable` | When weighting | *(none)* | Column name in your data file containing the weight values (e.g., `Weight`). |
| `show_unweighted_n` | No | `TRUE` | Show the actual (unweighted) number of respondents alongside weighted counts. Useful for transparency. |
| `show_effective_n` | No | `TRUE` | Show the effective sample size, which reflects how much the weighting reduces statistical power. |
| `weight_label` | No | `Weighted` | Label displayed for weighted base rows. |

#### Display & Formatting

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `show_frequency` | No | `TRUE` | Show raw count (frequency) rows in tables. |
| `show_percent_column` | No | `TRUE` | Show column percentage rows (percentage of each column's base). This is the most common display format for crosstabs. |
| `show_percent_row` | No | `FALSE` | Show row percentage rows (percentage of each row's total across columns). |
| `decimal_places_percent` | No | `0` | Number of decimal places for percentage values. `0` displays "45%", `1` displays "45.3%". |
| `decimal_places_ratings` | No | `1` | Number of decimal places for mean, NPS, and rating values. `1` displays "7.5". |
| `decimal_places_index` | No | `1` | Number of decimal places for index scores. |

#### Box Categories

Box categories combine multiple response options into summary rows (e.g., "Top 2 Box" combining "Agree" and "Strongly Agree").

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `boxcategory_frequency` | No | `FALSE` | Show frequency counts for box category rows. |
| `boxcategory_percent_column` | No | `TRUE` | Show column percentages for box category rows. |

#### Significance Testing

Significance testing tells you whether differences between groups (e.g., Male vs Female) are statistically meaningful or could be due to chance.

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `enable_significance_testing` | No | `TRUE` | Enable pairwise significance testing between banner columns. Results appear as letter codes in cells. |
| `alpha` | No | `0.05` | The p-value threshold. Lower values (e.g., `0.01`) require stronger evidence to declare significance. Common values: `0.01`, `0.05`, `0.10`. |
| `significance_min_base` | No | `30` | Minimum sample size required in a column before significance testing is performed. Columns below this threshold are dimmed and show a warning. |
| `bonferroni_correction` | No | `TRUE` | Apply Bonferroni correction to adjust for multiple comparisons. Reduces false positives when testing many columns simultaneously. Recommended for most studies. |

#### Summary Statistics

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `show_standard_deviation` | No | `FALSE` | Show standard deviation for numeric and scale questions. |
| `show_net_positive` | No | `TRUE` | Show NET POSITIVE row for scale questions (percentage of positive responses minus negative). |
| `create_index_summary` | No | `Y` | Create a summary sheet in Excel with index scores for all questions that have indices. |

#### HTML Report Settings

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `html_report` | No | `FALSE` | Set to `TRUE` to generate an interactive HTML report alongside the Excel output. |
| `project_title` | No | `Crosstab Report` | Title displayed in the report header and browser tab. Use your project name (e.g., "Customer Experience Survey 2025"). |
| `company_name` | No | `The Research Lamppost` | Your company name, displayed in the report footer. |
| `client_name` | No | *(none)* | Client name, displayed as "Prepared for [Client]" in the header. |
| `brand_colour` | No | `#323367` | Primary brand colour as a hex code. Used for header accents, heatmap tinting, active states, and chart colours. |
| `accent_colour` | No | `#CC9900` | Secondary accent colour. Used for toggle buttons and borders. |
| `chart_bar_colour` | No | *(brand_colour)* | Override colour for horizontal bar charts. Defaults to brand colour if not set. |
| `researcher_logo_path` | No | *(none)* | File path to your company logo (PNG, JPG, or SVG). Displayed in the top-left of the report header. Can be absolute or relative to the config file. |
| `client_logo_path` | No | *(none)* | File path to the client logo. Displayed in the top-right of the header. |
| `embed_frequencies` | No | `TRUE` | Embed frequency data in the HTML report so users can toggle between percentages and counts. Set to `FALSE` for smaller file sizes. |
| `fieldwork_dates` | No | *(none)* | Text description of the fieldwork period (e.g., "Jan - Feb 2025"). Displayed in the dashboard summary. |
| `show_charts` | No | `FALSE` | Set to `TRUE` to generate inline SVG charts for each question. Charts are interactive and can be exported as PNG slides. |

#### Dashboard Configuration

The dashboard is a summary page showing headline metrics with traffic-light colour coding.

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `include_summary` | No | `TRUE` | Include the dashboard summary tab in the report. |
| `dashboard_metrics` | No | `NET POSITIVE` | Comma-separated list of metrics to display. Options: `NET POSITIVE`, `NPS Score`, `Mean`, or any custom label matching a row label in your data (e.g., `Good or excellent`). |

#### Dashboard Colour Thresholds

These settings control when metrics appear green (good), amber (moderate), or red (concern) in the dashboard. Set thresholds appropriate to your industry and study context.

| Setting | Default | Description |
|---------|---------|-------------|
| `dashboard_scale_mean` | `10` | Maximum value on the mean scale (e.g., `10` for a 1-10 scale, `5` for a 1-5 scale). |
| `dashboard_scale_index` | `5` | Maximum value on the index scale. |
| `dashboard_green_net` | `60` | NET percentage at or above this value appears green. |
| `dashboard_amber_net` | `40` | NET percentage at or above this value (but below green) appears amber. Below this is red. |
| `dashboard_green_mean` | `7` | Mean at or above this value appears green. |
| `dashboard_amber_mean` | `5` | Mean at or above this value appears amber. |
| `dashboard_green_index` | `4` | Index score at or above this value appears green. |
| `dashboard_amber_index` | `3` | Index score at or above this value appears amber. |
| `dashboard_green_custom` | `60` | Custom metric percentage at or above this value appears green. |
| `dashboard_amber_custom` | `50` | Custom metric percentage at or above this value appears amber. |

#### Descriptors

Descriptors add explanatory text beneath summary statistic rows, helping readers understand what the scales mean.

| Setting | Default | Description |
|---------|---------|-------------|
| `index_descriptor` | *(none)* | Text displayed below index rows, e.g., "Strongly disagree(1) = 1 to Strongly agree(5) = 5". |
| `mean_descriptor` | *(none)* | Text displayed below mean rows, e.g., "1 = Very dissatisfied to 10 = Very satisfied". |
| `nps_descriptor` | *(none)* | Text displayed below NPS rows, e.g., "0 = Not at all likely to 10 = Extremely likely". |

#### Advanced Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `priority_metric` | *(none)* | Comma-separated list of metric types to highlight in charts (e.g., "Mean, NPS, Index"). When set, charts display the metric value as a styled badge. |

### 3.2 Selection Sheet

The Selection sheet controls which questions are analysed and how they are used. Each row represents one question from your survey structure.

| Column | Required | Default | Description |
|--------|----------|---------|-------------|
| `QuestionCode` | Yes | *(none)* | The unique question identifier, matching a code in your survey structure file. |
| `Include` | No | `N` | Set to `Y` to include this question as a **stub** (row question) in the crosstab analysis. |
| `UseBanner` | No | `N` | Set to `Y` to use this question as a **banner** (column break). Banner questions create the column groupings that stub questions are cross-tabulated against. |
| `BannerLabel` | No | *(QuestionCode)* | Display name for the banner group when `UseBanner = Y`. This label appears on the banner tab buttons (e.g., "Region", "Gender", "Age"). |
| `DisplayOrder` | No | *(auto)* | Numeric value controlling the display order. Lower numbers appear first. Banner questions are ordered by this value. |
| `CreateIndex` | No | `N` | Set to `Y` to calculate an index score for this question. Requires scale-type response options with defined weights in the structure file. |
| `BaseFilter` | No | *(none)* | Advanced: An R expression to filter the base for this question (e.g., filtering to only respondents who answered a previous question). |

**Understanding Banners vs Stubs:**

- **Banner questions** (columns): Typically demographic or segmentation variables like Region, Gender, Age Group. These create the column breaks so you can compare sub-groups.
- **Stub questions** (rows): The questions you want to analyse. Each stub question gets its own table showing results broken down by all banner groups.

**Example:**

| QuestionCode | Include | UseBanner | BannerLabel |
|---|---|---|---|
| Region | N | Y | Region |
| Gender | N | Y | Gender |
| Q001 | Y | N | |
| Q002 | Y | N | |

This analyses Q001 and Q002, cross-tabulated by Region and Gender.

### 3.3 Comments Sheet

The Comments sheet (optional) lets you pre-populate analyst comments that appear in the HTML report alongside each question.

| Column | Required | Description |
|--------|----------|-------------|
| `QuestionCode` | Yes | The question code this comment applies to. |
| `Banner` | No | If specified, the comment only appears when this banner group is active. Leave blank for a comment that appears for all banners. |
| `Comment` | Yes | The comment text. Plain text only. |

**Example:**

| QuestionCode | Banner | Comment |
|---|---|---|
| Q002 | Region | Western Cape leads overall satisfaction |
| Q002 | Gender | No gender differences observed |
| Q005 | | NPS trending upward across all segments |

### 3.4 Instructions Sheet

The Instructions sheet is for human reference only. It is not processed by the system. Use it to document your project setup, analysis decisions, or notes for colleagues.

---

## 4. Using the HTML Report

This section is written for anyone opening and exploring a Turas HTML report in their browser.

### 4.1 Report Layout

When you open the report, you see:

```
+------------------------------------------------------------------+
|  [Logo]   PROJECT TITLE                          [Client Logo]   |
|           Company Name                                           |
+------------------------------------------------------------------+
|  Summary  |  Crosstabs  |  Pinned Views (0)                     |
+------------------------------------------------------------------+
|           |                                                      |
|  Question | [ Banner Group Tabs: Region | Gender | Age | ... ]   |
|  List     |                                                      |
|  -------  | [ Controls: Heatmap | Frequencies | Print | Help ]   |
|  Search   |                                                      |
|  Q001 ... | +--------------------------------------------------+|
|  Q002 ... | | Table with data                                   ||
|  Q003 ... | | Chart (if enabled)                                 ||
|  Q004 ... | | Insight area                                       ||
|  ...      | +--------------------------------------------------+|
|           |                                                      |
+------------------------------------------------------------------+
|  Footer with methodology notes                                   |
+------------------------------------------------------------------+
```

**Three main tabs** appear at the top (when dashboard is enabled):
- **Summary** - Dashboard with headline metrics and colour-coded gauges
- **Crosstabs** - The main analysis tables, one per question
- **Pinned Views** - Your curated collection of pinned questions

### 4.2 Navigating Questions

**Sidebar (left panel):**
- Lists all questions by code and title
- Click any question to jump to it
- Only one question displays at a time

**Search box:**
- Type any part of a question code or title to filter the list
- Filtering is instant (no need to press Enter)
- Clear the search box to show all questions again

### 4.3 Banner Groups

Banner groups appear as tab buttons above the data table (e.g., "Region", "Gender", "Age").

**Switching banners:**
- Click any banner tab to switch the column groupings
- The table, chart, and all controls update automatically
- Each banner group shows different column splits (e.g., Region shows North/South/East/West, Gender shows Male/Female)

**The "Total" column** is always visible regardless of which banner is active. It shows the overall result across all respondents.

**Column visibility:**
- When a banner has many columns, a chip bar appears below the tabs
- Click any column chip to show/hide that column
- Hidden columns are greyed out but can be toggled back on
- At least one column must remain visible

### 4.4 Reading Tables

Each table displays your crosstab results with the following row types:

| Row Type | Appearance | What It Shows |
|----------|------------|---------------|
| **Base (n=)** | Light grey background, bold | Sample size for each column. This is how many respondents are in each group. |
| **Category rows** | White background | Individual response options with their percentages (and optional frequencies). |
| **NET rows** | Warm tan background, bold | Aggregated categories (e.g., "Top 2 Box" combining Agree + Strongly Agree). |
| **Mean/Index/NPS** | Pale yellow, italic | Summary statistics calculated from the scale values. |

**Heatmap colouring:**
- Data cells have subtle background tinting proportional to their value
- Higher percentages appear in deeper shades of your brand colour
- Toggle the heatmap on/off using the "Heatmap" checkbox in the controls bar

**Frequency toggle:**
- Click "Show Frequencies" to display raw counts alongside percentages
- Frequencies appear as small numbers within each cell

**Significance letters:**
- When significance testing is enabled, cells may show small green letter badges (e.g., "AB")
- These letters indicate which other columns this cell is significantly higher than
- Each column is assigned a letter (A, B, C, etc.) shown in the column header
- Example: If the "Male" column shows "B" on a row, it means Males are significantly higher than Females (column B) on that measure

**Low base warnings:**
- Columns with fewer respondents than the minimum base threshold appear dimmed
- A warning icon appears in the base row
- Results for these columns should be interpreted with caution

**Sorting:**
- Click any column header to sort the table by that column
- First click: descending (highest values first)
- Second click: ascending (lowest values first)
- Third click: back to original order
- A sort arrow indicator shows the current sort direction

**Scale descriptors:**
- When configured, a small annotation appears below Mean, Index, or NPS rows explaining the scale (e.g., "1 = Very dissatisfied to 10 = Very satisfied")

### 4.5 Dashboard Summary

The dashboard (Summary tab) provides a high-level overview of all your metrics.

**Metadata cards** at the top show:
- Total number of respondents
- Fieldwork dates
- Number of questions analysed
- Number of banner groups

**Colour legend** explains the traffic-light thresholds for the current metrics.

**Gauge section:**
- Each metric appears as a semi-circular gauge showing its Total value
- Colour indicates performance: green (strong), amber (moderate), red (concern)
- The question text is shown below each gauge

**Heatmap grid:**
- A compact table showing all metrics across all banner columns
- Cells are colour-coded using the same traffic-light system
- Allows quick comparison across groups
- Each metric section has its own "Export to Excel" button

**Significant findings:**
- Cards highlighting columns that are statistically significantly higher than others
- Shows the actual percentages and which columns differ
- Helps identify the most important group differences at a glance

### 4.6 Charts

When charts are enabled (`show_charts = TRUE`), each question displays a visualisation above or beside its table.

**Chart types** are selected automatically based on the question type:

| Question Type | Chart Style | Description |
|---|---|---|
| Likert, Rating, NPS | Stacked horizontal bar | Colour-coded segments showing the proportion in each response category. Sentiment colours (red for negative, amber for neutral, green for positive) are applied automatically. |
| Single response | Horizontal bar chart | Individual bars for each response option showing their percentages. |

**Interacting with charts:**

- **Column selection:** When multiple banner columns exist, a "Chart:" chip bar appears above the chart. Click chips to add/remove columns from the chart display. At least one column must remain selected.
- **Row exclusion:** Click the small exclude button on any table row to remove that category from the chart. The row dims and the chart redraws without it. Click again to restore it.
- **Priority metrics:** When configured, a styled metric badge appears beside each chart bar showing the Mean, NPS, or Index value.

**Chart and table synchronisation:**
- Sorting the table automatically reorders the chart bars to match
- Hiding columns from the table also hides them from the chart

### 4.7 Adding Insights

Insights are text annotations you can add to any question to record your observations.

**Adding an insight:**
1. Click the "Add Insight" button below the table/chart area
2. An editable text area appears
3. Type your observation or commentary
4. Your text is automatically saved as you type

**Per-banner insights:**
- Insights are stored separately for each banner group
- Switch to a different banner, and you can write a separate insight for that view
- When you switch back, your previous insight reappears

**Pre-configured comments:**
- If the analyst populated the Comments sheet in the config file, those comments appear automatically for the relevant question and banner combination

**Saving insights:**
- Click "Save Report" in the controls bar
- A new HTML file downloads with all your insights embedded
- When you reopen this saved file, all insights are restored

**Exporting insights:**
- Use the "Export Insights" option to download a standalone HTML file containing only your written insights, grouped by question
- This file is ideal for sharing observations with colleagues who do not need the full data

### 4.8 Pinned Views

Pinning lets you bookmark important questions to create a curated collection for presentations or focused review.

**How to pin a question:**
1. Navigate to the question you want to pin
2. Click the pin icon in the question header
3. The icon fills in and changes colour to confirm the pin
4. A badge on the "Pinned Views" tab updates with the count

**What gets captured:**
- The current chart (with your selected columns)
- The current table (with your sort and column selections)
- Any insight text you have written
- The active banner group name and base size

**Viewing pinned items:**
- Click the "Pinned Views" tab to see all your pins
- Each pin appears as a card with the question title, table, chart, and insight

**Managing pins:**
- **Reorder:** Use the up/down arrow buttons on each card to change the order
- **Remove:** Click the remove button to unpin a question
- **The pin icon** in the main view reflects the current pin state

**Exporting pinned views:**
- **Export All Slides:** Downloads one high-resolution PNG image per pinned question (1280x720 at 3x resolution). These are ready to paste into PowerPoint.
- **Print / Save PDF:** Opens the browser print dialog with each pinned view on a separate page. Select "Save as PDF" in the print dialog for a PDF file.

### 4.9 Exporting Data

The report offers several export options:

| Export | Format | What It Contains | How to Access |
|--------|--------|------------------|---------------|
| **CSV** | `.csv` | Current question's table data (visible columns only) | "Export CSV" button on each question |
| **Excel** | `.xls` | Current question's table with formatting | "Export Excel" button on each question |
| **Chart PNG** | `.png` | Current chart as a high-resolution image | Chart export dropdown |
| **Slide PNG** | `.png` | Presentation slide with title, table, chart, and insight | Slide export dropdown (3 modes: Chart+Table, Chart Only, Table Only) |
| **All Pinned Slides** | `.png` (multiple) | One PNG per pinned view | Button in Pinned Views tab |
| **Insights HTML** | `.html` | All insights across all questions and banners | "Export Insights" in controls |
| **Full Report HTML** | `.html` | Complete report with embedded insights | "Save Report" button |

**Dashboard exports:**
- Each metric section in the dashboard has an "Export to Excel" button for its heatmap grid
- Dashboard gauge sections can be exported as slide PNGs

### 4.10 Printing

**Print the full report:**
1. Click "Print Report" in the controls bar (or press Ctrl+P / Cmd+P)
2. The report temporarily expands to show all questions
3. The browser print dialog opens
4. Select your printer or choose "Save as PDF"
5. After printing, the report returns to its normal interactive view

**Print pinned views:**
1. Go to the Pinned Views tab
2. Click "Print / Save PDF"
3. Each pinned view appears on its own page
4. Use the browser print dialog to print or save as PDF

**Print tips:**
- Table colours and heatmap shading are preserved in print
- Interactive controls (buttons, search, toggles) are hidden in print
- For best results, use Chrome or Edge and select "Background graphics" in print settings

---

## 5. Browser Compatibility & Known Issues

### Supported Browsers

| Browser | Support Level | Notes |
|---------|---------------|-------|
| **Google Chrome** (v90+) | Full support | Recommended. Best performance for exports and printing. |
| **Microsoft Edge** (v90+) | Full support | Chromium-based Edge works identically to Chrome. |
| **Mozilla Firefox** (v90+) | Full support | Minor differences in print layout. SVG export may differ slightly. |
| **Apple Safari** (v14+) | Mostly supported | PNG export may not trigger automatic download on older versions. See workarounds below. |
| **Internet Explorer** | Not supported | IE11 and earlier lack required JavaScript features. |
| **Mobile browsers** | Partial | Report is viewable but interactive features are optimised for desktop. |

### Operating System Notes

| OS | Notes |
|---|---|
| **Windows 10/11** | Full support across Chrome, Edge, and Firefox. Print to PDF works via Microsoft Print to PDF. |
| **macOS** | Full support across Chrome, Safari, and Firefox. Print to PDF is built into the system print dialog. |
| **Linux** | Supported via Chrome and Firefox. Print to PDF available in most distributions. |
| **ChromeOS** | Supported via the built-in Chrome browser. |

### Known Issues and Workarounds

**Safari: PNG downloads may not trigger automatically**
- On older Safari versions, clicking export buttons may open the image in a new tab instead of downloading
- **Workaround:** Right-click the image and select "Save Image As..." to download manually
- Alternatively, use Chrome or Firefox for export-heavy workflows

**Firefox: Print layout differences**
- Firefox may render table borders slightly differently in print mode
- Background colours may not appear unless "Print backgrounds" is enabled in the print settings
- **Workaround:** Enable "Print Background Colours" in Firefox print settings (under "More Settings")

**Large reports (100+ questions): Performance**
- Reports with a very large number of questions may take a few seconds to fully load
- Switching banner groups on large reports may briefly pause
- **Workaround:** No action needed; the report will respond after processing. If performance is a concern, consider splitting the analysis into multiple config files.

**Large file sizes**
- Reports with embedded frequencies and many banner columns can exceed 5 MB
- **Workaround:** Set `embed_frequencies = FALSE` in your config to reduce file size. Frequency data will still be in the Excel output.

**Heatmap colours on high-contrast displays**
- Very subtle heatmap colours may not be visible on high-contrast monitor settings
- **Workaround:** The heatmap can be toggled off if it causes readability issues

**Multiple simultaneous PNG exports**
- Some browsers limit the number of concurrent downloads. Exporting many pinned slides at once may cause some downloads to be blocked.
- **Workaround:** The system includes a 600ms delay between downloads. If downloads are still blocked, check your browser's download settings and allow multiple downloads from the file.

**Saved HTML file size**
- When you "Save Report" with insights, the saved file may be larger than the original because it includes insight data
- The saved file is fully self-contained and can be shared via email or file transfer

**Corporate firewalls / email filters**
- Some corporate email systems block `.html` attachments
- **Workaround:** Zip the HTML file before sending, or share via a file-sharing service

**Screen readers and accessibility**
- Charts include `aria-label` attributes for basic screen reader support
- Tables use semantic HTML for accessibility
- Full keyboard navigation is not yet implemented; mouse interaction is required for most features

### Recommended Setup for Best Experience

1. Use **Google Chrome** or **Microsoft Edge** for the most reliable experience
2. Ensure your browser is updated to the latest version
3. Enable "Background graphics" in print settings for accurate printed output
4. Allow multiple downloads if you plan to export pinned slides
5. For presentations, export slides as PNG and insert into PowerPoint for best quality

---

*This manual was generated for Turas Analytics Platform v10.6.0. For technical documentation, see the separate Technical Developer Manual.*
