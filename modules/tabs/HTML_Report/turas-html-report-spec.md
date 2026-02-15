# Turas HTML Report Module — Development Spec

## Background

This spec describes a new feature for the Turas tabs module: an interactive HTML report output that runs alongside the existing Excel crosstab deliverable. The HTML report is a single self-contained `.html` file that opens in any browser with no installation, no server, and no internet connection required.

The feature is controlled by parameters in the tabs module config. The existing Excel output is unchanged — the HTML is a parallel rendering layer that reads from the same structured tab output.

Two React prototypes exist showing the target design. They were built in a Claude.ai conversation and are available as `.jsx` files for visual reference only — the actual implementation will be in R using `reactable` + Quarto.

---

## Architecture

### Core Principle

The HTML report is a **rendering layer**, not a new analysis engine. It reads from the tab output that the tabs module has already computed — the same percentages, frequencies, base sizes, significance flags, and NET scores. No analysis logic is duplicated.

### Output

A single self-contained `.html` file containing:

- All CSS, JavaScript, and data embedded inline
- No external dependencies at runtime
- Branded with project name, client logo (optional), and Turas/Research Lamppost footer
- Typical file size target: under 5MB for most projects

### Integration with Tabs Module

Add parameters to the existing tabs function:

```r
# Proposed interface (adapt to actual tabs module structure)
turas_tabs(
  ...,
  html_report = TRUE,        # Generate HTML alongside Excel
  include_summary = TRUE,     # Include summary dashboard page
  brand_colour = "#0d8a8a",  # Primary accent colour
  project_title = "SACAP Student Survey 2025"
)
```

The default behaviour (`html_report = FALSE`) produces Excel tabs exactly as today. No breaking changes.

---

## Technology Stack

### R Packages Required

- **reactable** — Interactive tables with sorting, filtering, conditional styling, cell rendering functions
- **reactablefmtr** — Extended formatting helpers for reactable (colour scales, data bars)
- **crosstalk** — Shared filtering widgets across reactable tables (for banner group switching)
- **htmlwidgets** — Framework for embedding JavaScript widgets in R
- **quarto** (or rmarkdown) — Document structure, tabbed navigation, theming, rendering to self-contained HTML
- **htmltools** — Building custom HTML components (summary dashboard cards, gauges)
- **bslib** — Bootstrap theming for consistent styling

### No Additional Toolchain

Everything runs from R. No Node.js, no npm, no build step. The researcher runs an R script and gets an HTML file.

---

## Feature 1: Interactive Crosstab Explorer

### What It Does

Each survey question renders as an interactive `reactable` table showing column percentages across banner point columns, with significance testing results displayed visually.

### Layout

- **Left sidebar**: Scrollable question navigator listing all questions by number and truncated text. Click to jump to that question's table. Includes a search/filter box.
- **Main area**: The crosstab table for the selected question with controls above it.
- **Banner group tabs**: Buttons above the table to switch between banner groups (e.g., Campus, Course, Intensity, Year, Age). Only one group's columns display at a time, plus the Total column. This prevents the 37-column sprawl problem.

### Table Structure

For each question, the table adapts to the statistics present in the tab output:

| Row | Content | Condition |
|-----|---------|-----------|
| **Header row** | Column labels from the banner group, with letter codes (A, B, C...) shown beneath | Always |
| **Base row** | Sample sizes per column (n=). Cells with n<30 flagged in red with ⚠ warning | Always |
| **Category rows** | One row per response option. Primary value is column %, row %, frequency, or mean rank depending on what's configured. Secondary value (e.g., count beneath percentage) shown via toggle if both are available | Always |
| **Mean/Mode row** | Summary statistics for numeric/continuous questions | Only if mean/mode enabled for that question |
| **Separator** | Visual divider line | Only if NET rows exist |
| **NET rows** | Summary rows (e.g., "Good or excellent", "NET POSITIVE") displayed in bold with slightly different background | Only if NETs were computed |

The header area above the table shows which statistic is being displayed (e.g., "Column %" or "Row %" or "Frequency") so the user always knows what they're looking at. If multiple percentage types are available, a toggle lets the user switch between them.

### Significance Display

**Only rendered if significance testing is enabled in the tabs module config.**

Instead of a separate "Sig." row with letter codes, significance is shown **inline in each cell**:

- Cells that are significantly higher than other columns display a green badge: `▲AB` (meaning significantly higher than columns A and B)
- The badge appears to the right of the percentage value
- Styling: green text (#059669), small monospace font, subtle green background tint

This is the single biggest UX improvement over the Excel tabs — no more cross-referencing sig rows with column headers.

### Heatmap Shading

- Toggle on/off via a checkbox control — **only shown if percentage data exists**
- When enabled, category cells (not NETs, not bases) get background colour intensity proportional to the percentage value
- Colour scale: light teal to medium teal (matching brand palette)
- Cells with 0% or 100% excluded from shading
- For frequency-only tables (no percentages), heatmap shading applies to frequencies instead, scaled to the maximum frequency in the question
- The visual effect: your eye is immediately drawn to where the high values cluster

### Low Base Warnings

Low base warnings apply regardless of whether significance testing is enabled — they're always useful context.

- Any column with base n<30 gets:
  - Base cell displayed in red/coral colour
  - ⚠ icon next to the base number
  - All category cells in that column rendered at reduced opacity (e.g., 0.45)
- This threshold (default 30) should read from the tabs module significance testing config, not be hard-coded

### Show/Hide Frequencies

- Toggle checkbox: "Show count" — **only shown if both percentages and frequencies exist in the output**
- When enabled, each category cell shows both the percentage and the frequency count beneath it (labelled as "count", not "n=")
- **Important terminology**: "n=" refers exclusively to the base size (total number of responses for that column), shown in the base row. The per-cell frequency is "count". Do not conflate the two.
- Default: off (cleaner view), user enables when they want to audit numbers
- If only frequencies exist (no percentages), frequencies are the primary display and this toggle is hidden

### Export to Excel

- Each table includes a download button
- Clicking exports the currently visible table (with active banner group filter) to `.csv` or `.xlsx`
- Uses `reactable`'s built-in download parameter, or SheetJS for xlsx format
- This is the "Corporate Bridge" — the client explores interactively but can pull data into Excel when needed

### Data Source

The renderer reads from the tabs module output. The key data structures it needs per question:

- Question number and full text
- Question type (single choice, rating scale, ranking, numeric/continuous)
- Base sizes per banner point
- Category labels
- Banner group structure (which columns belong to which group, with letter codes)
- Whichever statistics the tabs module was configured to produce (see below)

### Handling Tab Configuration Permutations

**CRITICAL**: The tabs module is configurable. Any combination of the following statistics may be present or absent in the output, and the HTML renderer must handle all permutations gracefully.

#### Statistics that may be enabled/disabled:

| Statistic | When Present | HTML Display |
|-----------|-------------|--------------|
| **Frequency counts** | Show raw n per cell | Secondary text beneath percentage, or as primary value if no percentages enabled |
| **Column %** | Show percentage down columns | Primary cell value (the most common view) |
| **Row %** | Show percentage across rows | Primary cell value — label clearly as "Row %" in the table header to avoid confusion with column % |
| **Significance testing** | Column proportion z-tests | Inline sig badges (▲AB). If disabled, no badges rendered — cells show values only |
| **Mean** | Numeric/continuous questions | Display as a single summary row beneath the category rows, or as the primary cell value for numeric questions |
| **Mode** | Numeric/continuous questions | Display alongside or beneath mean |
| **Ranking data** | Ranking questions | May show mean rank, or % ranked 1st/2nd/3rd — renderer must detect and display appropriately |

#### Renderer logic:

The renderer must **inspect what's present** in the tab output for each question and adapt:

1. If only column % is present → show percentages as primary values
2. If only frequency is present → show frequencies as primary values
3. If both column % and frequency → percentages as primary, frequencies as toggleable secondary (the "Show count" checkbox)
4. If row % is present → show row percentages, clearly labelled. If both column % and row % exist, provide a toggle to switch between them
5. If significance is absent → render clean tables with no sig badges, no sig legend
6. If significance is present → render sig badges inline
7. If mean/mode are present (numeric questions) → show as summary statistics row(s) beneath category breakdowns, or as the primary display for continuous variables
8. If ranking data → display mean ranks or rank percentages as appropriate to the data structure

#### Key principle:

**Do not hard-code assumptions about which statistics are present.** The renderer should check what the tab output contains for each question and build the table accordingly. A project might have column % with significance on some questions and just frequencies on others (e.g., open-ended coded responses).

The toggle controls (Show count, Heatmap, etc.) should only appear if the relevant data exists. Don't show a "Show count" toggle if no frequency data was generated. Don't show a heatmap toggle if there are no percentages to shade.

The summary dashboard (Phase 2) similarly adapts — NET score gauges only appear for questions that have NET rows. If the project has no significance testing, the "Significant Findings" section is omitted entirely.

---

## Feature 2: Summary Dashboard

### What It Does

A single overview page that appears **before** the crosstab explorer. It shows headline metrics across all questions in a compact visual format. This is the "so what" page — the insights director opens the report, sees the big picture, then clicks through to detail.

### Location in Document

The HTML file has two sections:

1. **Summary Dashboard** (top/first tab)
2. **Crosstab Explorer** (below/second tab)

Implementation options: either a scrollable single page with the dashboard at the top and tables below, or a tabbed navigation with "Summary" and "Crosstabs" tabs. Tabbed is probably cleaner.

### Dashboard Components

#### A. Project Metadata Strip

A row of 4 cards across the top:

- Total respondents (n=)
- Fieldwork dates
- Questions analysed
- Number of banner groups

These values come from the tabs module Summary sheet.

#### B. Key Score Gauges

For questions that have NET POSITIVE / NPS scores, display semi-circle gauge visualisations:

- Score displayed as large number in the centre (e.g., "+45")
- Colour-coded: green (≥50), amber (20-49), red (<20)
- Below the gauge: a stacked horizontal bar showing the positive/neutral/negative split
- Beside the gauge: small coloured chips showing the score per banner point (e.g., "Online +47", "CT +34")

The tabs module already computes NET POSITIVE rows. The dashboard identifies these automatically from rows where the label contains "NET POSITIVE" or "NPS" or "Promoter - Detractor".

#### C. Service Ratings Summary

For rating-scale questions (those with "Good or excellent" / "Terrible or Not good" NET rows), display a compact stacked horizontal bar chart:

- Question label on the left
- Stacked bar: green (positive), amber (neutral), red (negative)
- Percentage labels at the ends
- Base size shown small on the right

#### D. NET Score Heatmap Grid

A compact table showing all key metrics across all banner groups simultaneously:

| Metric | TOTAL | Online | CT | Jhb | Pta | Dbn | 1st | 2nd | 3rd | Hon | 18-20 | 21-24 | 25-34 | 35+ |
|--------|-------|--------|-----|-----|-----|-----|-----|-----|-----|-----|-------|-------|-------|-----|

- Each cell shows the NET score with colour-coded background (green = strong, amber = watch, red = concern)
- Total column highlighted with slightly different background
- Banner group headers span their columns
- Hover effect on rows for readability

This is the power piece — all key numbers in one view, with colour guiding the eye to outliers.

#### E. Significant Findings Cards

Auto-generated cards highlighting statistically significant differences:

- Each card shows: the metric name, a description of the finding, a directional indicator (↑/↓)
- Displayed in a 2-column grid
- Cards are generated by scanning NET rows for significance flags and translating them into plain English

**Note**: The auto-generation of finding descriptions is aspirational. For v1, these could be manually specified in the config, or simply list the sig flags without natural language descriptions. Discuss implementation approach.

### Data Source for Dashboard

The dashboard reads from the same tab output, specifically:

- Summary/metadata sheet values
- NET rows from all questions (identified by row type)
- Base sizes from each question
- Significance flags from NET rows

---

## Styling & Branding

### Design Language

The prototypes establish a specific visual identity:

- **Primary colour**: Dark navy (#1a2744) for headers, emphasis
- **Accent colour**: Teal (#0d8a8a) for interactive elements, highlights — configurable per project
- **Typography**: Clean sans-serif (DM Sans or similar available web font), monospace for numbers (DM Mono or similar)
- **Background**: Warm off-white (#f8f7f5) for page, pure white for cards/tables
- **Borders**: Light grey (#e2e8f0), 1px, with subtle rounded corners on containers

### Customisation Parameters

At minimum, allow configuration of:

- `project_title` — displayed in the header
- `brand_colour` — primary accent (defaults to teal)
- `logo_path` — optional path to client/company logo image for the header
- `analyst_name` — optional, shown in footer
- `fieldwork_dates` — shown in metadata strip

---

## Scope & Phasing

### Phase 1 (Build First)

- Reactable crosstab tables with significance badges, heatmap shading, low base warnings
- Banner group tab switching
- Question navigator sidebar with search
- Show/hide frequencies toggle
- Export-to-CSV/Excel button per table
- Single self-contained HTML output
- Basic Quarto/RMarkdown document structure with branding

### Phase 2 (Build Second)

- Summary dashboard with metadata strip, gauge visualisations, stacked bars, NET heatmap grid
- Tabbed navigation between Summary and Crosstabs

### Phase 3 (Future)

- Auto-generated significant findings cards with natural language descriptions
- Client logo embedding
- Custom colour theme per project
- Extension to other Turas modules (catdriver, etc.)

---

## Technical Notes

### Self-Contained HTML

Quarto's `self-contained: true` option (or `embed-resources: true` in newer versions) bundles all CSS, JS, fonts, and data into a single HTML file. This is essential — the client must be able to open the file offline.

### Data Embedding

The tab data will need to be serialised as JSON and embedded in the HTML. For large surveys (200+ questions, many banner points), this could produce large files. Consider:

- Compressing the JSON (removing redundant keys, using arrays instead of objects)
- Only embedding the data needed for display (percentages, sigs, bases — not necessarily all raw frequencies unless show-freq is enabled)
- Testing with a full-size dataset to verify browser performance

### reactable Cell Rendering

The significance badges, heatmap colours, and low-base dimming are all implemented via `reactable`'s `colDef(cell = ...)` and `colDef(style = ...)` functions. These accept R functions that receive the cell value and return HTML/CSS.

Example pattern (conceptual — must adapt to what statistics are present):

```r
# Determine what to display based on tab config
has_col_pct <- "col_pct" %in% available_stats
has_row_pct <- "row_pct" %in% available_stats
has_freq <- "freq" %in% available_stats
has_sig <- "sig" %in% available_stats
has_mean <- "mean" %in% available_stats

colDef(
  cell = function(value, index) {
    # Build cell content based on what's available
    primary <- if (has_col_pct) paste0(value, "%")
               else if (has_freq) value
               else "—"
    
    sig_badge <- if (has_sig) {
      sig <- sig_data[index, col_name]
      if (nchar(sig) > 0) {
        htmltools::span(class = "sig-badge", paste0("▲", sig))
      }
    }
    
    htmltools::div(primary, sig_badge)
  },
  style = function(value, index) {
    base_n <- base_data[[col_name]]
    list(
      background = if (show_heatmap && (has_col_pct || has_freq)) {
        heat_color(value, max_val)
      },
      opacity = if (base_n < min_base) 0.45 else 1
    )
  }
)
```

### Existing Tabs Module

The implementation needs to read from the tabs module's internal data structures. Before coding, Claude Code should examine:

- The tabs module configuration system — which statistics are toggled on/off and how that's stored
- How question blocks are stored after analysis (and how question type is identified: single choice, ranking, numeric)
- How banner groups and letter codes are structured
- How NET rows are identified and stored
- How significance results are attached to cells (and whether sig is enabled/disabled)
- How mean, mode, and ranking data are stored for numeric/ranking questions
- The current Excel rendering function (to understand the data flow and what permutations it already handles)
- The minimum base size setting and where it's stored

---

## Deployment Considerations

### Browser Compatibility

The HTML output uses standard HTML5, CSS3, and ES6 JavaScript. It works in any modern browser:

- Chrome, Firefox, Edge, Safari — all current versions
- Windows, macOS, Linux, ChromeOS
- iPad Safari (functional but cramped for wide tables)
- **Not supported**: Internet Explorer (dead, but some SA corporates still have legacy systems — the answer is no)

No plugins, extensions, or internet connection required. Double-click the file, it opens.

### File Size and Distribution

Self-contained HTML files embed all data, CSS, and JavaScript. Estimated sizes:

| Survey Size | Approximate File Size |
|-------------|----------------------|
| 30 questions, 3 banner groups | 1-2 MB |
| 80 questions, 5 banner groups | 3-5 MB |
| 150+ questions, 5+ banner groups | 5-10 MB |

**Email limits**: Many corporate email systems cap attachments at 5-10MB. For larger projects:

- Share via WeTransfer, Google Drive link, or similar file transfer
- Offer a "lite" version embedding percentages only (no frequencies) to reduce data payload
- Consider compressing JSON data within the file (removing whitespace, using arrays instead of keyed objects)

Add a note in the project config: `embed_frequencies = TRUE/FALSE` to control data density and therefore file size.

### Printing

Clients will try to print the report. Interactive features (sorting, filtering, hover effects) do not survive printing, but the currently displayed table should print cleanly.

**Required**: Include a `@media print` CSS stylesheet that:

- Removes the sidebar navigation, toggle controls, and interactive buttons
- Ensures the currently visible table renders at full width
- Sets appropriate font sizes and removes background colours that waste ink (except significance badges which should remain visible)
- Forces page breaks between questions if printing multiple tables
- Includes a header with project name and footer with page numbers

### Mobile

Crosstabs are inherently a desktop/laptop deliverable. On mobile devices:

- Tables scroll horizontally (functional but not ideal)
- The question navigator sidebar would need to collapse
- Banner group tabs remain usable

**Recommendation**: Do not invest time in mobile optimisation. If asked, the answer is "designed for desktop viewing — the tables need screen width to be useful." This matches how every other research tool handles tabular data.

### Offline Use

The file works fully offline once downloaded. No CDN calls, no API requests, no external font loading at runtime. All resources are embedded. This is critical for:

- Presentations in boardrooms with no WiFi
- Clients who save reports to local drives or shared network folders
- Archival — the file will render identically in 5 years as it does today

---

## Reference Materials

### Prototype Files

Two React (`.jsx`) prototypes were created during the design conversation. They show:

1. **crosstab-explorer.jsx** — The interactive table with question navigator, banner tabs, heatmap, sig badges
2. **summary-dashboard.jsx** — The executive summary with gauges, stacked bars, heatmap grid, findings cards

These are React components for visual reference only. The R implementation will replicate this look using `reactable`, `htmltools`, and Quarto, not React.

### SACAP Test Dataset

The SACAP Student Survey 2025 crosstab Excel file is the ideal test case:

- 1,363 respondents
- 118 questions (81 in the crosstab sheet)
- 5 banner groups: Campus (5 cols), Course (17 cols), Intensity (2 cols), Year (6 cols), Age (4 cols)
- 37 total banner columns
- Significance testing enabled with Bonferroni correction at p<0.05
- Mix of rating scales, single choice, and NPS-style questions
- Contains NET POSITIVE rows suitable for dashboard gauges

### Key R Package Documentation

- reactable: https://glin.github.io/reactable/
- reactablefmtr: https://kcuilla.github.io/reactablefmtr/
- crosstalk: https://rstudio.github.io/crosstalk/
- Quarto HTML documents: https://quarto.org/docs/output-formats/html-basics.html
- htmltools: https://rstudio.github.io/htmltools/
