# TURAS Weighting Module

**Version 3.0** | Production-ready survey weighting for market research

---

## What It Does

Calculates survey weights to correct sample biases so your data accurately represents the target population. Three methods available:

| Method | When to Use | How It Works |
|--------|-------------|--------------|
| **Design** | Stratified samples with known population sizes | Weight = population share / sample share per stratum |
| **Rim (Raking)** | Sample demographics don't match population margins | Iteratively adjusts to match marginal distributions on multiple variables |
| **Cell (Interlocked)** | Need to match a joint distribution (e.g., age x gender) | Weight = target proportion / observed proportion for each cell |

All three methods can be combined in one run, producing multiple weight columns.

---

## Quick Start

### 1. From the Turas GUI

Launch Turas, click **Weighting** in the module list. Browse to your project folder, select your config file, and click **Calculate Weights**.

### 2. From R

```r
source("modules/weighting/run_weighting.R")
result <- run_weighting("path/to/Weight_Config.xlsx")

# Access weighted data
weighted_data <- result$data
```

### 3. From Command Line

```bash
Rscript modules/weighting/run_weighting.R path/to/Weight_Config.xlsx
```

---

## Setting Up a Config File

The config file is an Excel workbook (`Weight_Config.xlsx`) with required and optional sheets. All file paths are **relative to the config file location** (or absolute).

### Generate a Template

```r
source("modules/weighting/lib/generate_config_templates.R")
generate_weight_config_template("my_project/Weight_Config.xlsx")
```

### Required Sheets

#### Sheet 1: General

Key-value format (Setting | Value columns):

| Setting | Value | Required | Description |
|---------|-------|----------|-------------|
| `project_name` | My Survey 2026 | Yes | Identifies the project in reports |
| `data_file` | data/survey.csv | Yes | Path to input data (.csv, .xlsx, .sav) |
| `output_file` | output/weighted.csv | No | Where to save weighted data |
| `save_diagnostics` | Y | No | Generate Excel diagnostics report |
| `diagnostics_file` | output/diagnostics.xlsx | If save_diagnostics=Y | Path for diagnostics workbook |
| `html_report` | Y | No | Generate self-contained HTML report |
| `html_report_file` | output/report.html | No | Path for HTML report (auto-generated if blank) |
| `brand_colour` | #1e3a5f | No | Brand hex colour for HTML report |
| `accent_colour` | #2aa198 | No | Accent hex colour for HTML report |
| `researcher_name` | Jane Smith | No | Researcher name shown in report header |
| `client_name` | Acme Corp | No | Client name shown in report header ("Prepared by X for Y") |
| `logo_file` | assets/logo.png | No | Logo image embedded in report header (PNG/JPG/SVG) |

#### Sheet 2: Weight_Specifications

One row per weight to calculate:

| weight_name | method | apply_trimming | trim_method | trim_value |
|-------------|--------|----------------|-------------|------------|
| design_wt | design | N | | |
| demo_wt | rim | Y | cap | 5 |
| cell_wt | cell | N | | |

**Columns:**
- `weight_name` — Name for the weight column added to your data. Must be unique.
- `method` — One of: `design`, `rim`, `rake`, `cell`
- `apply_trimming` — `Y` or `N`. Caps extreme weights to improve stability.
- `trim_method` — `cap` (absolute cap) or `percentile` (trim to percentile range)
- `trim_value` — For `cap`: maximum weight value (e.g., 5). For `percentile`: upper percentile (e.g., 95)

### Method-Specific Sheets

#### Design_Targets (required if method = "design")

| weight_name | stratum_variable | stratum_category | population_size |
|-------------|-----------------|------------------|-----------------|
| design_wt | Region | North | 250000 |
| design_wt | Region | South | 180000 |
| design_wt | Region | East | 120000 |
| design_wt | Region | West | 150000 |

**How design weights work:** If the North region is 35.7% of the population but only 20% of your sample, respondents from the North get a weight > 1 to correct for under-representation. The weight = (population proportion) / (sample proportion).

#### Rim_Targets (required if method = "rim" or "rake")

| weight_name | variable | category | target_percent |
|-------------|----------|----------|----------------|
| demo_wt | Gender | Male | 48.5 |
| demo_wt | Gender | Female | 51.5 |
| demo_wt | Age | 18-34 | 30.0 |
| demo_wt | Age | 35-54 | 40.0 |
| demo_wt | Age | 55+ | 30.0 |

**Rules:**
- `target_percent` values must sum to 100 for each variable (within 0.5% tolerance)
- Categories must match exactly the values in your data (case-sensitive)
- You can use up to ~5 rim variables. More variables = harder convergence.

#### Cell_Targets (required if method = "cell")

| weight_name | Gender | Age | target_percent |
|-------------|--------|-----|----------------|
| cell_wt | Male | 18-34 | 14.5 |
| cell_wt | Male | 35-54 | 19.4 |
| cell_wt | Male | 55+ | 14.6 |
| cell_wt | Female | 18-34 | 15.5 |
| cell_wt | Female | 35-54 | 20.6 |
| cell_wt | Female | 55+ | 15.4 |

**Rules:**
- All `target_percent` values must sum to 100 (within 0.5% tolerance)
- Every combination of variable levels must have a row
- Every combination must appear in your data (no empty cells)

### Optional Sheets

#### Advanced_Settings

Fine-tune rim weight calculation:

| weight_name | max_iterations | convergence_tolerance | force_convergence |
|-------------|---------------|----------------------|-------------------|
| demo_wt | 100 | 0.001 | N |

- `max_iterations` — Maximum raking iterations (default: 50)
- `convergence_tolerance` — Stopping threshold (default: 0.01)
- `force_convergence` — `Y` to accept non-converged weights (not recommended)

#### Notes

Document your assumptions and methodology:

| Section | Note |
|---------|------|
| Assumptions | Population data sourced from Census 2021 |
| Assumptions | Age categories collapsed from 5-year bands |
| Methodology | Rim weighting chosen over cell due to sparse cells |
| Data Quality | 3 records excluded due to missing age |
| Caveats | Rural areas may be under-represented |

Notes appear in the HTML report's Method Notes tab and the Excel diagnostics Notes sheet.

---

## Choosing the Right Method

### Design Weights

**Best for:**
- Stratified samples where you over/under-sampled specific groups by design
- B2B surveys where you sampled by company size
- Regional studies with geographic stratification

**Pros:** Simple, deterministic, no iteration needed.
**Cons:** Only corrects for one stratification variable.

### Rim Weights (Raking)

**Best for:**
- Online panels needing demographic adjustment
- Quota samples that didn't perfectly match targets
- Any survey where multiple demographics need correction simultaneously

**Pros:** Corrects multiple variables at once, widely used in market research.
**Cons:** Can produce extreme weights if sample is far from targets. May not converge if too many variables or categories.

**Pitfalls:**
- Don't use more than ~5 rim variables — convergence becomes unstable
- Check that no category has fewer than ~20 respondents
- Always review the design effect — if it's above 2.0, your effective sample size is halved

### Cell Weights (Interlocked)

**Best for:**
- When the joint distribution matters (e.g., young males are specifically under-represented)
- When rim weighting doesn't adequately correct because biases are concentrated in specific cells

**Pros:** Precisely matches the joint distribution. No iteration needed.
**Cons:** Requires every cell to have at least one respondent. Sparse cells produce extreme weights.

**Pitfalls:**
- With 3+ variables, the number of cells can explode (e.g., 5 ages x 2 genders x 4 regions = 40 cells)
- Empty cells make cell weighting impossible — use rim weighting instead
- Very small cells (n < 5) produce very high weights

---

## Understanding Diagnostics

Every weight run produces diagnostic metrics:

| Metric | Good | Acceptable | Poor | What It Means |
|--------|------|------------|------|---------------|
| **Design Effect (DEFF)** | < 1.5 | 1.5 - 2.0 | > 2.0 | How much variance increases due to weighting. DEFF = 2 means you need twice the sample to get the same precision as an unweighted sample. |
| **Efficiency** | > 70% | 50-70% | < 50% | 1/DEFF expressed as percentage. Higher is better. |
| **CV** | < 0.5 | 0.5 - 1.0 | > 1.0 | Coefficient of variation of weights. Lower = more uniform weights. |
| **Max Weight** | < 3 | 3-5 | > 5 | Largest individual weight. Very high values mean one respondent counts as multiple people. |

### When to Apply Trimming

Apply trimming (`apply_trimming = Y`) when:
- Max weight exceeds 5
- Design effect exceeds 2.0
- A small number of respondents have disproportionate influence

Trimming introduces a small bias (weighted distribution won't perfectly match targets) but reduces variance. This is almost always a good trade-off.

---

## Output Files

| Output | Config Setting | Description |
|--------|---------------|-------------|
| **Weighted data** | `output_file` | Your data with weight column(s) added (.csv or .xlsx) |
| **Excel diagnostics** | `diagnostics_file` | Per-weight diagnostics, configuration summary, notes |
| **HTML report** | `html_report_file` | Self-contained interactive report with 3 tabs: Summary, Weight Details, Method Notes |

The HTML report integrates with the Turas Report Hub — it can be combined with tabs, tracker, and driver reports into a single multi-module report.

---

## File Paths and Portability

All paths in the config file are resolved relative to the config file's location. This means:

```
my_project/
  Weight_Config.xlsx      <-- config file lives here
  data/
    survey.csv            <-- data_file = "data/survey.csv"
  output/
    weighted.csv          <-- output_file = "output/weighted.csv"
```

You can move the entire project folder anywhere (including OneDrive, Dropbox, or another computer) and it will work without changes. Absolute paths are also supported for data stored elsewhere.

---

## Common Pitfalls

1. **Category names don't match** — "Male" in your targets but "male" in the data. Values are case-sensitive.
2. **Target percentages don't sum to 100** — Allowed tolerance is 0.5%. Double-check your arithmetic.
3. **Missing values in weighting variables** — Respondents with NA in a rim variable are excluded. Clean your data first.
4. **Too many rim variables** — More than 5 variables often fails to converge. Combine fine categories.
5. **Empty cells in cell weighting** — If no respondents fall in a cell, cell weighting can't work. Use rim weighting instead or collapse categories.
6. **Ignoring diagnostics** — Always check design effect and efficiency. A design effect of 3.0 means your 1000-respondent survey has the precision of a 333-respondent unweighted survey.

---

## Module Structure

```
modules/weighting/
  run_weighting.R              # Main entry point
  run_weighting_gui.R          # Shiny GUI
  lib/
    00_guard.R                 # Input validation (TRS)
    config_loader.R            # Excel config parser
    validation.R               # Data validation
    design_weights.R           # Design weight calculation
    rim_weights.R              # Rim/raking weights (survey::calibrate)
    cell_weights.R             # Cell/interlocked weights
    trimming.R                 # Weight trimming/capping
    diagnostics.R              # DEFF, efficiency, quality
    output.R                   # Excel/CSV output
    html_report/               # HTML report generation
      00_html_guard.R
      01_data_transformer.R
      02_table_builder.R
      03_page_builder.R
      04_html_writer.R
      05_chart_builder.R
      99_html_report_main.R
      js/weighting_navigation.js
  tests/
    testthat/                  # ~298 tests
  examples/
    example1_design_weights/   # Design weight walkthrough
    example2_rim_weights/      # Rim weight walkthrough
    example3_combined_weights/ # Combined methods
  docs/
    Weight_Config_Template.xlsx   # Pre-built template
    USER_MANUAL.md
    TECHNICAL_DOCS.md
    TEMPLATE_REFERENCE.md
    CONFIG_EXAMPLE.md
```

---

## Dependencies

| Package | Version | Purpose | Required |
|---------|---------|---------|----------|
| `readxl` | 1.4.5 | Read Excel config files | Yes |
| `survey` | 4.4.8 | Rim weight calibration | Yes |
| `openxlsx` | 4.2.8 | Write Excel output | Yes |
| `haven` | 2.5.5 | Read SPSS .sav files | Optional |
| `htmltools` | 0.5.8.1 | HTML report generation | If html_report=Y |
| `base64enc` | 0.1.3 | Logo embedding in HTML | If logo used |

**R version:** 4.5.1 or later recommended (tested on R 4.0+).

---

## API Reference

### Main Functions

```r
# Full pipeline from config file
result <- run_weighting("Weight_Config.xlsx")

# Quick design weight (no config file needed)
weighted_data <- quick_design_weight(
  data = survey_data,
  stratum_variable = "Region",
  population_sizes = c(North = 250000, South = 180000)
)

# Quick rim weight (no config file needed)
weighted_data <- quick_rim_weight(
  data = survey_data,
  targets = list(
    Gender = c(Male = 0.485, Female = 0.515),
    Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
)
```

### Return Value

`run_weighting()` returns a list:

| Field | Type | Description |
|-------|------|-------------|
| `status` | Character | "PASS", "PARTIAL", or TRS refusal |
| `data` | Data frame | Input data with weight columns added |
| `weight_names` | Character vector | Names of weight columns created |
| `weight_results` | List | Per-weight results with diagnostics |
| `config` | List | Parsed configuration |
| `output_file` | Character | Path to saved weighted data (if configured) |
| `diagnostics_file` | Character | Path to diagnostics workbook (if configured) |
| `html_report_file` | Character | Path to HTML report (if configured) |
| `run_state` | List | TRS run state with timing and events |
