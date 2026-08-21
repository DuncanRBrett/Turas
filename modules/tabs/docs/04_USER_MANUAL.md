---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tabs - User Manual

**Version:** 10.8 **Date:** 14 March 2026

This manual walks you through using Turas Tabs from start to finish. By
the end, you'll be able to set up and run cross-tabulation analyses on
your survey data.

------------------------------------------------------------------------

## Before You Start

### What You'll Need

1.  **R installed** on your computer (version 4.0 or higher recommended)
2.  **Turas** downloaded and accessible
3.  **Your survey data** in Excel (.xlsx), CSV, or SPSS (.sav) format
4.  **Template files** from the `templates/` folder in this
    documentation

### Installing Required Packages

Open R and run:

``` r
install.packages(c("openxlsx", "readxl", "jsonlite"))
```

If you're working with SPSS files or large CSV files, also install:

``` r
install.packages(c("haven", "data.table"))
```

------------------------------------------------------------------------

## Step 1: Prepare Your Survey Structure

The Survey Structure file defines your survey questions and response
options. This is the master reference that Tabs uses to understand your
data.

### Generate Professional Templates (Recommended)

Turas can generate professionally formatted, hardened config templates
with dropdown validation, colour-coded cells, and built-in help text:

``` r
source("modules/tabs/lib/generate_config_templates.R")

# Generate both templates in your project folder. generate_all_templates
# takes the FOLDER; the two single-template functions take a full FILE path.
generate_all_templates("path/to/your/project")
```

The generated templates include:
- **Dropdown menus** for Variable_Type, Include, UseBanner, etc.
- **Colour-coded cells** (green = editable, blue = reference, grey = auto)
- **Help text** describing every field and valid values
- **Data validation** preventing invalid entries
- **Cover sheet** with instructions

### Create the Questions Sheet

Open `Survey_Structure_Template.xlsx` from the templates folder (or use
the generated template). Go to the Questions sheet.

For each question in your survey, add a row with:

| Column | What to Enter |
|----|----|
| QuestionCode | The column name in your data file (e.g., Q01, Gender, Satisfaction) |
| QuestionText | The question wording as you want it to appear in output |
| Variable_Type | The question type (see below) |
| Columns | Number of data columns (1 for most questions, more for multi-mention) |

**Variable_Type options:** - `Single_Response` - Pick one answer -
`Multi_Mention` - Pick multiple answers - `Rating` - Numeric scale (1-5,
1-10, etc.) - `Likert` - Agreement scale with index weights - `NPS` -
Net Promoter Score (0-10) - `Ranking` - Rank items in order -
`Numeric` - Open numeric response - `Allocation` - Constant-sum /
budget allocation (multiple columns, one per option) - `Open_End` -
Text response (not analyzed in Tabs)

**Example Questions sheet:**

| QuestionCode | QuestionText                          | Variable_Type  | Columns |
|--------------|---------------------------------------|----------------|---------|
| Q01          | Overall satisfaction with our service | Rating         | 1       |
| Q02          | Which features do you use?            | Multi_Mention  | 5       |
| Q03          | Gender                                | Single_Response | 1       |
| Q04          | Age group                             | Single_Response | 1       |
| Q05          | Likelihood to recommend               | NPS            | 1       |

### Create the Options Sheet

For each question, list all possible response options.

| Column       | What to Enter                                        |
|--------------|------------------------------------------------------|
| QuestionCode | The question code (must match Questions sheet)       |
| OptionText   | The value as it appears in your data                 |
| DisplayText  | The label you want shown in output                   |
| ShowInOutput | Y to include this option in output, blank to exclude |
| DisplayOrder | Numeric order for display (1, 2, 3...)               |

**Example Options sheet:**

| QuestionCode | OptionText | DisplayText       | ShowInOutput | DisplayOrder |
|--------------|------------|-------------------|--------------|--------------|
| Q01          | 1          | Very dissatisfied | Y            | 1            |
| Q01          | 2          | Dissatisfied      | Y            | 2            |
| Q01          | 3          | Neutral           | Y            | 3            |
| Q01          | 4          | Satisfied         | Y            | 4            |
| Q01          | 5          | Very satisfied    | Y            | 5            |
| Q03          | 1          | Male              | Y            | 1            |
| Q03          | 2          | Female            | Y            | 2            |
| Q04          | 1          | 18-34             | Y            | 1            |
| Q04          | 2          | 35-54             | Y            | 2            |
| Q04          | 3          | 55+               | Y            | 3            |

**Important:** The OptionText must exactly match what's in your data
file. If your data has "1" for Male, enter "1" as OptionText, not
"Male".

### For Multi-Mention Questions

Multi-mention questions need special handling. In the Questions sheet,
list the root code and the number of columns:

| QuestionCode | QuestionText               | Variable_Type | Columns |
|--------------|----------------------------|---------------|---------|
| Q02          | Which features do you use? | Multi_Mention | 5       |

In the Options sheet, list options for the first column (Q02_1):

| QuestionCode | OptionText | DisplayText | ShowInOutput |
|--------------|------------|-------------|--------------|
| Q02_1        | Feature A  | Feature A   | Y            |
| Q02_1        | Feature B  | Feature B   | Y            |
| Q02_1        | Feature C  | Feature C   | Y            |

Your data file should have columns Q02_1, Q02_2, Q02_3, Q02_4, Q02_5.

### Save the Survey Structure

Save the file with a meaningful name like `Survey_Structure.xlsx` in
your project folder.

------------------------------------------------------------------------

## Step 2: Configure Your Analysis

The Tabs Config file tells Tabs what analysis to run.

### Create the Settings Sheet

Open `Crosstab_Config_Template.xlsx` from the templates folder. Go to
the Settings sheet.

Essential settings to configure:

| Setting | Value |
|----|----|
| structure_file | Path to your Survey_Structure file |
| output_subfolder | Folder for output (e.g., Crosstabs) |
| output_filename | Output file name (e.g., Results.xlsx) |
| apply_weighting | TRUE if you have weights, FALSE if not |
| weight_variable | Your weight column name (or - if not using) |
| show_frequency | TRUE to show counts, FALSE for percentages only |
| show_percent_column | TRUE to show percentages |
| enable_significance_testing | TRUE to test significance |
| alpha | Significance level (typically 0.05 for 95% confidence) |
| alpha_secondary | Optional second significance level for HTML report toggle (e.g. 0.10 for 90%). Leave blank to disable. |
| alpha_default | Which level the HTML report opens on: `primary` (default) or `secondary`. Only used when alpha_secondary is set. |

See the [Template Reference](06_TEMPLATE_REFERENCE.md) for all available
settings.

### Create the Selection Sheet

The Selection sheet controls which questions to analyze and which to use
as banner columns.

| Column       | What to Enter                                   |
|--------------|-------------------------------------------------|
| QuestionCode | The question code                               |
| Include      | Y to analyze this question as a stub, N to skip |
| UseBanner    | Y to use this question as a banner column       |
| BannerLabel  | Label for banner column (e.g., "Gender")        |
| DisplayOrder | Order for banner columns (1, 2, 3...)           |
| CreateIndex  | Y to calculate mean/index for this question     |
| Source       | Where this question's numbers come from (the survey question, or the columns a derived one was built from) |
| Formula      | Derived questions only: how the figure was worked out, in plain words |
| BaseFilter   | Optional filter expression                      |
| FilterLabel  | Human-readable label shown in reports instead of the filter expression |

**Example Selection sheet:**

| QuestionCode | Include | UseBanner | BannerLabel | DisplayOrder | CreateIndex |
|--------------|---------|-----------|-------------|--------------|-------------|
| Q01          | Y       | N         |             |              | Y           |
| Q02          | Y       | N         |             |              | N           |
| Q03          | Y       | Y         | Gender      | 2            | N           |
| Q04          | Y       | Y         | Age         | 3            | N           |
| Q05          | Y       | N         |             |              | N           |
| Total        | N       | Y         | Total       | 1            | N           |

**Tips:** - Always include a "Total" banner column (it shows all
respondents) - Put Total first in DisplayOrder - Questions can be both
stubs (Include=Y) and banners (UseBanner=Y)

### Save the Config

Save the file as `Tabs_Config.xlsx` in your project folder.

------------------------------------------------------------------------

## Step 3: Check Your Data File

Before running the analysis, verify your data file:

1.  **Column names match:** The column names in your data should match
    the QuestionCode values in Survey_Structure
2.  **Values match:** The response values should match the OptionText
    values in the Options sheet
3.  **Weight column exists:** If using weighting, confirm the weight
    column exists
4.  **No completely empty columns:** Questions with all missing data
    will cause warnings

### Common Data Issues

**Issue:** Question not found in data **Fix:** Check that QuestionCode
in Survey_Structure matches the column name in your data exactly
(case-sensitive)

**Issue:** Option values not matching **Fix:** Check that OptionText
values match your data exactly. If your data has "1" and you entered
"Male", change OptionText to "1"

**Issue:** Multi-mention columns not found **Fix:** Verify your data has
columns like Q02_1, Q02_2, etc. and that Columns in Survey_Structure
matches the count

------------------------------------------------------------------------

## Step 4: Run the Analysis

### Using the GUI

The graphical interface is the easiest way to run Tabs:

``` r
# Set your working directory to the Turas folder
setwd("path/to/Turas")

# Launch the GUI: sourcing only DEFINES the function - you must call it
source("modules/tabs/run_tabs_gui.R")
run_tabs_gui()
```

In the GUI: 1. Click Browse to select your Tabs_Config.xlsx 2. Click Run
Analysis 3. Wait for processing to complete 4. The output file opens
automatically

### Using R Script

For scripted or batch processing:

``` r
setwd("path/to/Turas")
source("modules/tabs/run_tabs.R")

# Point it at a config workbook, not a project folder.
ok <- run_tabs_analysis("path/to/My_Crosstab_Config.xlsx")

if (!ok) {
  # Every refusal and warning is already printed to the console — Turas
  # convention is that errors must be visible where the run happened.
  # The workbook's Error Log and Run_Status sheets hold the same detail.
  stop("Tabs run did not complete — see the console output above.")
}
```

### What Happens During Processing

1.  Tabs loads your configuration and structure files
2.  It validates everything is properly set up
3.  It loads your survey data
4.  **Pre-flight validation** cross-references your config, structure,
    and data to catch mismatches before analysis begins (see below)
5.  For each stub question:
    -   It calculates frequencies and percentages across banner columns
    -   It runs significance tests
    -   It builds the output table
6.  It writes the Excel workbook (including the Guide sheet)
7.  If HTML report is enabled, it generates the interactive HTML report
8.  It returns the results

### Pre-Flight Validation

Before processing begins, Tabs automatically runs 16 cross-referential
checks that catch configuration mistakes early:

-   **Selection vs Structure:** Verifies every selected question exists
    in the Survey Structure
-   **Option values vs Data:** Checks that configured options actually
    appear in your data
-   **Multi-Mention columns:** Verifies expected columns (e.g., Q02_1,
    Q02_2) exist in data
-   **Data types:** Confirms numeric questions contain numeric data
-   **Banner variables:** Validates banner questions exist in both
    structure and data
-   **Base filter variables:** Checks that filter expressions reference
    valid columns
-   **Weight variable:** Validates the weight column exists and contains
    valid values
-   **Logo files:** Warns if configured logo files are missing
-   **Colour codes:** Validates hex colour codes used for report
    branding
-   **Dashboard scales:** Warns if green/amber thresholds are inverted

Pre-flight issues appear in the console and in the Error Log sheet of
the Excel output. Warnings don't stop the analysis but help you catch
problems early.

Processing time depends on your data size. A typical survey (1,000
respondents, 30 questions, 10 banner columns) takes about 10-15 seconds.

------------------------------------------------------------------------

## Step 5: Review the Output

### Excel Output

Open the output Excel file. You'll find these sheets:

| Sheet | Purpose |
|----|----|
| Summary | Project info, settings used, question list with base sizes |
| Guide | How to read this report — explains row types, significance letters, weighting, index scores |
| Index_Summary | Consolidated mean/index scores across all banner columns |
| Error Log | Any validation warnings or errors found during processing |
| Run_Status | TRS pass/partial/refused status with timing |
| Sample Composition | Banner variable distributions (if enabled) |
| Crosstabs | The full cross-tabulation results |

### Guide Sheet

The Guide sheet is automatically generated and explains how to interpret
the output. It adapts to your configuration — for example, the
significance testing section only appears if significance testing is
enabled, and the weighting section only appears if weighting is applied.
This makes the Excel file self-documenting for anyone who receives it.

### Index_Summary Sheet

If you set CreateIndex=Y for any questions, this sheet shows a summary
of all mean/index scores:

| Question         | Total | Male | Female | 18-34 | 35-54 | 55+ |
|------------------|-------|------|--------|-------|-------|-----|
| Q01 Satisfaction | 3.8   | 4.0  | 3.6    | 3.9   | 3.7   | 3.8 |
| Q05 NPS          | 32    | 38   | 26     | 40    | 28    | 30  |

This gives you a quick view of key metrics across all banner columns.

### Question Sheets

Each analyzed question gets its own sheet. The layout includes:

**Base rows at the top:**

```         
Base (unweighted)     1000    480    520    350    400    250
Base (weighted)       1000    500    500    380    370    250
Effective N            925    460    465    352    342    231
```

**Response rows in the middle:**

```         
Very satisfied        35%     40%C   31%    38%    34%    32%
Satisfied             40%     38%    42%A   39%    42%    38%
Neutral               15%     13%    17%A   14%    15%    18%
Dissatisfied           7%      6%     8%     6%     7%     9%
Very dissatisfied      3%      3%     2%     3%     2%     3%
```

The letters (A, B, C) indicate significance. A value with "C" is
significantly higher than column C.

**Summary rows at the bottom (for Rating/NPS questions):**

```         
Mean                  3.97    4.06C  3.89   4.01   3.95   3.92
Top 2 Box             75%     78%C   73%    77%    76%    70%
```

### Understanding Significance Letters

Each banner column gets a letter: - A = first banner column (usually
Total) - B = second column - C = third column - And so on...

When you see "40%C" in the Male column, it means 40% for Males is
significantly higher than the value in column C (Female).

If a cell has no letter, it's not significantly different from any other
column.

### Dual Significance Levels (HTML Report Toggle)

When working with smaller subgroups, a finding that doesn't reach 95%
confidence may still be worth flagging at 90%. The optional dual
significance level feature lets you set a second alpha value in your
config. The HTML report then shows a segmented button ("95% / 90%") in
the controls bar, allowing you to switch between the two levels without
re-running the analysis.

**To enable:**

Set `alpha_secondary` and optionally `alpha_default` in your Settings sheet:

```
alpha            = 0.05    # primary level (required — existing setting)
alpha_secondary  = 0.10    # second level (optional — leave blank to disable)
alpha_default    = primary # which level the report opens on (primary or secondary)
```

**How it works:**

-   The Excel output gains a second sig row labelled "Sig. (95%)" and
    "Sig. (90%)" (or whatever confidence levels you configured).
-   The HTML report shows both sets of badges embedded in each cell. The
    controls bar gains a segmented button to switch which set is visible.
-   When printing, the primary level is always used. The toggle button
    is hidden in print view.

**Note:** This feature is designed for situations where subgroup bases are
small and 90% confidence is a meaningful analytical threshold. It is not
intended for exploring which level happens to produce significant results.
The significance level should be decided before analysis, not after seeing
the data.

------------------------------------------------------------------------

## Working with the Interactive Report

Tabs writes a self-contained interactive HTML report beside the Excel
workbook. The GUI builds it on every run; a config can force it on or off
with `html_report_v2`.

### Key Report Settings

These settings in your config's Settings sheet control how the report looks:

| Setting | Default | Description |
|---------|---------|-------------|
| `html_report_v2` | (GUI: on) | TRUE forces the report on; FALSE forces it off, even from the GUI |
| `brand_colour` | #323367 | Primary brand colour (hex) — used for headers, gauges, and accents |
| `accent_colour` | #CC9900 | Secondary accent colour (hex) |
| `chart_palette_preset` | warm | Colour palette for ordinal/scale charts: `warm` (earth tones), `cool` (blue-anchored), `research` (purple-green diverging), `teal` (monochromatic teal), `red` (Coca-Cola-inspired muted red), or `brand` (monochromatic gradient from brand_colour) |
| `chart_bar_colour` | (brand) | Colour for simple bar charts (hex) |

See the [Template Reference](06_TEMPLATE_REFERENCE.md) for the full list of settings including dashboard thresholds, analyst details, and closing section options.

### Opening the Report

The HTML file is saved in your output folder with the same base name as
your Excel file (e.g., `My_Analysis.html`). Open it in any modern
browser — Chrome, Firefox, Edge, or Safari. No internet connection is
required.

### Report Navigation

The tab bar is split into two groups:

**Read**

- **Dashboard** — Headline gauges, heatmap grid, and significant findings
- **Group overview** — How each banner group compares to its peers across every question
- **Tracking** *(appears when wave history is configured)* — Wave-on-wave trends
- **Qualitative** *(appears when a comment workbook is configured)* — Coded comment themes and a verbatim quote drawer
- **Story** — Your ordered, annotated narrative of pinned questions and exhibits, presentable full-screen or exportable to editable PowerPoint

**Analyse**

- **Crosstabs** — Interactive tables with search, banner switching, and heatmap colouring
- **Differences** — Significant banner gaps, written as plain-English findings
- **Report** — Background & method, executive summary, added slides, and About

Any tab can be switched off per-report from Settings
(`show_dashboard`, `show_patterns`, `show_tracking`, `show_qualitative`,
`show_differences`). See
[Data-Centric Report v2](11_DATA_CENTRIC_REPORT_V2.md) for the full picture.

### Using Charts and Tables

- **Heatmap toggle** — Click the heatmap icon to colour-code cells by value
- **Banner switching** — Use the dropdown to switch between banner groups
- **Search** — Type in the search box to filter questions
- **Copy to clipboard** — Click the clipboard icon on any table to copy it
- **Export as PNG** — Click the camera icon to download a table as an image
- **Chart palette** — Set `chart_palette_preset` in your config to change the ordinal chart colours across the entire report

### Added Slides

On the **Report** tab, the "Added slides" card lets you bring in material
from outside the crosstab data — e.g. slides exported as images from a
qualitative phase (in PowerPoint: right-click a slide → *Save as
Picture*), or short text blocks with a caption. Use **+ Import image** or
**+ Text block**, then edit the caption inline. Added slides persist in
the browser and travel inside any saved copy of the report.

For narrative that should come from the config instead of being typed in
the browser — background & method, executive summary — use the
**Comments** sheet's reserved `_BACKGROUND` / `_EXECUTIVE_SUMMARY` rows;
see [Template Reference](06_TEMPLATE_REFERENCE.md). A third reserved row,
`_REPORT_CONSTRUCTION`, states how the study's numbers were actually built when
other stages sit around Turas — a derived engine ahead of it, a preparation
layer, pages that compute in the browser. It replaces the whole *Report
construction* section of the About card — the standard paragraphs on
reproducibility, AI and author review go with it, so write whichever of those
you want into the row. Leave the row out and the report reads exactly as before.

### The report's explanatory text — where it lives

Everything the report says *about itself* — the "How to read this report"
panel, the significance explainers, the precision footer, the weighting note,
the About card's construction note — is written by you, not by the code and not
by a model. It lives in the **Callout Editor** (a tile on the `launch_turas()`
home screen, module `tabs`). Edit a sentence there and every study picks it up
at its next generation.

To find the entry behind a paragraph, open a generated report and press
**ctrl+alt+K**. Every authored block wears its key; click one to copy it, then
paste it into the editor's filter. Gold badges are platform text from the
editor; navy `config:` badges are text this study wrote in its own config.
Press the same keys again to hide them — the badges are author-only and never
appear in a pin, an export or a saved copy.

Each entry is a whole block, not a sentence: blank lines between paragraphs,
one line per bullet, exactly as you would type it. The "Understanding the
significance testing" panel is one entry, and so is the Report construction
note. Some entries carry **placeholders** in curly brackets, like `{producer}` or
`{waves_note}`. The report fills each one in when it builds. The editor lists
them under the text you are editing and says in plain words what each becomes,
which of them your text is currently using, and — as you type — flags any that
are not real. Move a placeholder to say that thing somewhere else, or delete it
to never say it at all; invent one and the next build stops and names it rather
than printing the brackets into a client's report.

Two more things worth knowing. Text applies at the **next report generation** —
an editor save changes nothing in an HTML file that already exists. And clearing
an entry to blank is a legitimate way to switch a block off; deleting the entry
outright will stop the next build instead.

When one study alone must word something differently, use the config's
**ReportText** sheet rather than changing the platform text: put the key in
`Key` and your wording in `Text`. The sheet ships empty and should usually stay
that way.

### Study Slides — from the config

For exhibits that belong to the study rather than to one reader, fill in the
config's **AddedSlides** sheet: a title, some text, and optionally an
`image_path`. They render on the **Report** tab under *Study slides*,
read-only, identical in every copy, and they survive a rebuild — unlike the
in-browser card above, which lives in whoever's browser made it.

Each study slide carries a pin (📌). Pin one and it joins the **Story**; from
there it exports to PowerPoint as a **genuine full-slide picture** — the
original file rather than a screenshot of a card, so it is the sharpest thing
in the deck. Images are limited to 1.5 MB each; a bigger file is refused with
a console message and the slide keeps its text. See
[Template Reference](06_TEMPLATE_REFERENCE.md) for the columns and the export
format caveats.

### The Story Tab

Pin any chart, table, or dashboard heatmap by clicking its pin icon
(📌) — pinned items collect on the **Story** tab as an ordered,
annotated narrative. Add section dividers, reorder items, present the
story full-screen, or export it as a native, editable PowerPoint deck.
The story persists in the browser and travels inside any saved copy of
the report.

------------------------------------------------------------------------

## Step 6: Troubleshooting

### "Configuration file not found"

Check the file path. Either: - Use an absolute path:
`C:/Projects/Survey/Tabs_Config.xlsx` - Make sure your working directory
is set correctly

### "Question not found in data"

The QuestionCode in Survey_Structure doesn't match any column in your
data. Check: - Spelling (exact match required) - Case sensitivity (Q01
is different from q01) - No extra spaces

### "Weight variable not found"

Your weight_variable setting doesn't match a column in your data.
Either: - Correct the weight_variable name in Settings - Set
apply_weighting to FALSE if you don't need weights

### "Base size too small for significance testing"

A banner column has fewer respondents than the significance_min_base threshold.
Either: - This is expected (small segments don't get tested) - Reduce
significance_min_base in Settings (not recommended below 20) - Combine
segments to increase base sizes

### "All values are NA"

The question or banner column has no data. Check: - Your data file for
the problematic column - Whether a filter might be excluding all
respondents

### Output file won't open

The file might be locked from a previous run. Close Excel and try again.

------------------------------------------------------------------------

## Common Tasks

### Adding a New Banner Column

1.  Add the question to Survey_Structure (Questions and Options sheets)
    if not already there
2.  In Tabs_Config Selection sheet:
    -   Find or add the question row
    -   Set UseBanner = Y
    -   Set BannerLabel to your desired header
    -   Set DisplayOrder (higher numbers appear to the right)

### Filtering a Question

To analyze only a subset of respondents for a specific question:

1.  In the Selection sheet, find the question row
2.  In the BaseFilter column, enter a filter expression
3.  Optionally, in the FilterLabel column, enter a human-readable description (e.g., "Purchasers only"). This label is shown in reports instead of the raw filter expression

Example: To analyze Q01 only among purchasers:

```         
Q_Purchased == "Yes"
```

Example: To analyze among females aged 18-34:

```         
Q_Gender == "Female" & Q_Age %in% c("18-24", "25-34")
```

### Saying Where a Question's Numbers Came From

Turas only ever sees a finished column. If a figure was worked out
before the data reached it — a derived column, a composite, anything
computed upstream — nothing in the data says so, and on the page it
looks exactly like a question someone was asked.

Two Selection columns close that gap:

1.  In the Source column, name where the numbers come from — the survey
    question, or the columns a derived figure was built from
2.  For a derived figure, in the Formula column, say how it was worked
    out in plain words

The report then badges each question **ASKED** or **DERIVED** beside its
code. A derived question always carries its formula as a line under the
base, and that line travels with the question into a pinned card and a
PowerPoint slide. An asked question shows no line — the badge says
everything, and its Source sits in the badge tooltip.

The **Sources** toggle on the controls bar governs only the source names
beside the formula, not the formula itself. A DERIVED badge with nothing
next to it would tell a reader the number was worked out and then
withhold how, behind a control called "Sources" that they have no reason
to click. So the Formula column is the one that earns its keep on a
derived question; Source is optional there, naming what it was built
from. On an asked question it is the other way round: without a Source
the question carries no badge at all.

A question with a formula reads as derived; a question with a source and
no formula reads as asked. Nothing is inferred, so be careful which one
you write: a figure the respondent answered directly should carry a
Source and no Formula, even if the data was cleaned on the way in.

Example:

| QuestionCode        | Source                          | Formula                                        |
|---------------------|---------------------------------|------------------------------------------------|
| Q01                 | survey question                 |                                                |
| Spend_PerTransaction| Q01 spend and Q02 transactions  | monthly spend / monthly transactions, among buyers |

Leave both blank and nothing changes — no badges, and the Sources toggle
does not appear. Only a study that declares its provenance gets it.

Composites are the exception: Turas builds them, so it knows the answer
already and fills both columns from the Composite_Metrics sheet. Write
your own Source or Formula on a composite's Selection row and yours wins
for that field.

### Creating a Composite Score

To calculate an average across multiple questions:

1.  In Survey_Structure, go to the Composite_Metrics sheet
2.  Add a row:

| CompositeCode | CompositeLabel       | CalculationType | SourceQuestions |
|---------------|----------------------|-----------------|-----------------|
| COMP_SAT      | Overall Satisfaction | Mean            | Q01,Q02,Q03     |

3.  In Tabs_Config Selection sheet, add the composite:

| QuestionCode | Include | CreateIndex |
|--------------|---------|-------------|
| COMP_SAT     | Y       | Y           |

### Running Multiple Configurations

Create separate config files for different analyses: -
`Tabs_Config_Demographics.xlsx` - By gender and age -
`Tabs_Config_Regions.xlsx` - By region - `Tabs_Config_Segments.xlsx` -
By customer segment

Run each one separately to get different output files.

------------------------------------------------------------------------

## Tips for Better Results

### Configuration

-   **Start simple.** Begin with a few questions and banner columns. Add
    more once basic analysis works.
-   **Check a sample first.** Run on a subset of data before processing
    everything.
-   **Use meaningful labels.** BannerLabel values appear in output, so
    make them clear.

### Data Preparation

-   **Clean your data first.** Handle missing values and outliers before
    running Tabs.
-   **Recode to numeric.** Tabs works best when response values are
    numeric codes.
-   **Validate weights.** Check that weight values are reasonable (most
    between 0.5 and 2.0).

### Output Review

-   **Check base sizes.** Small bases produce unreliable percentages.
-   **Look at DEFF.** High design effects (\>2.0) indicate weighting
    efficiency issues.
-   **Verify significance makes sense.** If nothing is significant, you
    may have small bases or low variability.

### Interactive Report Output

Tabs writes an interactive HTML report alongside the Excel output. It
includes:

-   **Summary dashboard** with gauge charts and heatmap grids
-   **Interactive crosstab tables** with heatmap colouring and
    significance badges, with an optional dual significance level toggle
-   **Inline SVG charts** (stacked bars for ordinal, horizontal bars for
    nominal)
-   **Pinned views** for saving and annotating key findings
-   **Column sorting and export** (CSV and Excel)
-   **Search and navigation** across all questions

The HTML file is completely self-contained (no external dependencies)
and can be shared with anyone who has a web browser.

See [Data-Centric Report v2](11_DATA_CENTRIC_REPORT_V2.md) for full
details.

### Console Output

The console shows a configuration summary before processing begins,
including:

-   Number of questions, respondents, and banner columns
-   Weighting and significance settings
-   HTML report, charts, and dashboard status
-   Estimated processing time

After completion, a run summary shows the TRS status, question count,
output path, duration, and number of issues found.

------------------------------------------------------------------------

## Next Steps

-   See [Example Workflows](07_EXAMPLE_WORKFLOWS.md) for complete worked
    examples
-   See [Template Reference](06_TEMPLATE_REFERENCE.md) for detailed
    field specifications
-   See [Reference Guide](03_REFERENCE_GUIDE.md) for in-depth feature
    explanations
