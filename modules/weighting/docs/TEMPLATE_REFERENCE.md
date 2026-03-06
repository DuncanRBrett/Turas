# TURAS Weighting Module - Template Reference

## Weight_Config.xlsx Template Specification

This document provides complete specifications for the
Weight_Config.xlsx configuration file.

---

## File Structure Overview

```
Weight_Config.xlsx
├── General              (Required) Project settings
├── Weight_Specifications (Required) Define weights to calculate
├── Design_Targets       (Required for design weights)
├── Rim_Targets          (Required for rim weights)
├── Cell_Targets         (Required for cell weights)
├── Advanced_Settings    (Optional) Rim weighting parameters
└── Notes                (Optional) Assumptions and methodology
```

---

## Sheet 1: General

**Purpose:** Project-level configuration settings.

**Format:** Two-column layout with Setting and Value columns.

### Required Settings

| Setting      | Type | Description                    | Example                   |
|--------------|------|--------------------------------|---------------------------|
| project_name | Text | Project identifier for reports | `Customer_Survey_Q4_2025` |
| data_file    | Path | Path to survey data file       | `data/responses.csv`      |

### Optional Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| output_file | Path | (none) | Path to save weighted data |
| save_diagnostics | Y/N | N | Save Excel diagnostic report to file |
| diagnostics_file | Path | (none) | Path for diagnostic report (required if save_diagnostics=Y) |
| html_report | Y/N | N | Generate self-contained HTML report |
| html_report_file | Path | (auto) | Path for HTML report (auto-generated from output_file if blank) |
| brand_colour | Hex | #1e3a5f | Brand hex colour for HTML report |
| accent_colour | Hex | #2aa198 | Accent hex colour for HTML report |
| researcher_name | Text | (none) | Researcher/analyst name shown in report header |
| client_name | Text | (none) | Client name shown in report header |
| logo_file | Path | (none) | Path to logo image (PNG/JPG/SVG) embedded in report header |

### Path Resolution

Paths are resolved in this order:
1. If absolute path (starts with `/` or `C:\`), use as-is
2. Otherwise, resolve relative to config file location

### Supported Data Formats

| Extension | Format                 | Notes                        |
|-----------|------------------------|------------------------------|
| .csv      | Comma-separated values | Standard CSV with header row |
| .xlsx     | Excel 2007+            | First sheet is read          |
| .xls      | Excel 97-2003          | First sheet is read          |
| .sav      | SPSS                   | Requires `haven` package     |

### Example

```
| Setting           | Value                               |
|-------------------|-------------------------------------|
| project_name      | Brand_Tracking_Wave_12              |
| data_file         | data/brand_track_w12.csv            |
| output_file       | output/brand_track_w12_weighted.csv |
| save_diagnostics  | Y                                   |
| diagnostics_file  | output/weight_diagnostics.xlsx      |
| html_report       | Y                                   |
| html_report_file  | output/weighting_report.html        |
| brand_colour      | #1e3a5f                             |
| researcher_name   | Jane Smith                          |
| client_name       | Acme Corp                           |
| logo_file         | assets/acme_logo.png                |
```

---

## Sheet 2: Weight_Specifications

**Purpose:** Define each weight column to calculate.

**Format:** One row per weight, with columns for configuration.

### Columns

| Column           | Required    | Type   | Description                            |
|------------------|-------------|--------|----------------------------------------|
| weight_name      | Yes         | Text   | Column name for weight (added to data) |
| method           | Yes         | Text   | `design`, `rim`, `rake`, or `cell`     |
| description      | No          | Text   | Documentation only                     |
| apply_trimming   | No          | Y/N    | Apply weight trimming (default: N)     |
| trim_method      | If trimming | Text   | `cap` or `percentile`                  |
| trim_value       | If trimming | Number | Trim threshold                         |

### Weight Naming Rules

- Must be valid R column name
- No spaces (use underscores)
- Must be unique
- Recommended: descriptive lowercase with underscores

**Good names:** `design_weight`, `pop_weight`, `segment_wt`
**Bad names:** `Weight 1`, `wt`, `123weight`

### Method Values

| Value  | Description                             | Requires Sheet |
|--------|-----------------------------------------|----------------|
| design | Stratified sample weights               | Design_Targets |
| rim    | Iterative proportional fitting (raking) | Rim_Targets    |
| rake   | Alias for rim                           | Rim_Targets    |
| cell   | Interlocked/joint distribution weights  | Cell_Targets   |

### Trimming Configuration

**When apply_trimming = Y:**

| trim_method | trim_value Meaning            | Example                         |
|-------------|-------------------------------|---------------------------------|
| cap         | Maximum weight value          | `5` = cap weights at 5          |
| percentile  | Upper percentile threshold    | `95` = cap at 95th percentile   |

### Example

```
| weight_name    | method | description              | apply_trimming | trim_method | trim_value |
|----------------|--------|--------------------------|----------------|-------------|------------|
| segment_weight | design | Stratified by segment    | N              |             |            |
| pop_weight     | rim    | Census demographics      | Y              | cap         | 5          |
| cell_weight    | cell   | Age x Gender interlocked | N              |             |            |
```

---

## Sheet 3: Design_Targets

**Purpose:** Specify population sizes for design weight calculation.

**Required for:** All weights with `method = design`

### Columns

| Column           | Required | Type   | Description                       |
|------------------|----------|--------|-----------------------------------|
| weight_name      | Yes      | Text   | Must match Weight_Specifications  |
| stratum_variable | Yes      | Text   | Column name in data               |
| stratum_category | Yes      | Text   | Category value (exact match)      |
| population_size  | Yes      | Number | Population count for this stratum |

### Rules

1. **All categories must be covered** — Every unique value in stratum_variable must have a row
2. **Category matching is exact** — Case-sensitive: "Male" ≠ "male"
3. **Population sizes must be positive** — Zero or negative values are invalid
4. **One stratum variable per weight** — For multiple variables, use rim weighting

### Example

```
| weight_name    | stratum_variable | stratum_category | population_size |
|----------------|------------------|------------------|-----------------|
| segment_weight | company_size     | Small            | 8500            |
| segment_weight | company_size     | Medium           | 1200            |
| segment_weight | company_size     | Large            | 300             |
```

---

## Sheet 4: Rim_Targets

**Purpose:** Specify target percentages for rim weighting (raking).

**Required for:** All weights with `method = rim` or `method = rake`

### Columns

| Column         | Required | Type   | Description                      |
|----------------|----------|--------|----------------------------------|
| weight_name    | Yes      | Text   | Must match Weight_Specifications |
| variable       | Yes      | Text   | Column name in data              |
| category       | Yes      | Text   | Category value (exact match)     |
| target_percent | Yes      | Number | Target percentage (0-100)        |

### Rules

1. **Percentages must sum to 100** — For each variable, tolerance: +/- 0.5%
2. **All categories must be covered** — Missing categories will cause an error
3. **Use percentages, not proportions** — Enter `48` for 48%, not `0.48`
4. **Maximum recommended variables: 5** — More increases convergence risk
5. **No missing values in data** — Rim variables must have no NAs

### Example

```
| weight_name | variable   | category  | target_percent |
|-------------|------------|-----------|----------------|
| pop_weight  | Gender     | Male      | 48             |
| pop_weight  | Gender     | Female    | 52             |
| pop_weight  | Age_Group  | 18-34     | 30             |
| pop_weight  | Age_Group  | 35-54     | 40             |
| pop_weight  | Age_Group  | 55+       | 30             |
```

---

## Sheet 5: Cell_Targets

**Purpose:** Specify joint distribution targets for cell/interlocked weighting.

**Required for:** All weights with `method = cell`

### Columns

| Column         | Required | Type   | Description                          |
|----------------|----------|--------|--------------------------------------|
| weight_name    | Yes      | Text   | Must match Weight_Specifications     |
| *(variables)*  | Yes      | Text   | One column per cell variable         |
| target_percent | Yes      | Number | Joint distribution target (0-100)    |

The variable columns (e.g., Gender, Age) must match column names in your data exactly.

### Rules

1. **All target_percent values must sum to 100** — Tolerance: +/- 0.5%
2. **Every combination must have a row** — All possible cells must be defined
3. **Every combination must exist in data** — Empty cells cannot be weighted
4. **No duplicate cell combinations** — Each row must be unique
5. **Small cells (n < 5) produce high weights** — Consider rim weighting instead

### Example

```
| weight_name | Gender | Age   | target_percent |
|-------------|--------|-------|----------------|
| cell_wt     | Male   | 18-34 | 14.5           |
| cell_wt     | Male   | 35-54 | 19.4           |
| cell_wt     | Male   | 55+   | 14.6           |
| cell_wt     | Female | 18-34 | 15.5           |
| cell_wt     | Female | 35-54 | 20.6           |
| cell_wt     | Female | 55+   | 15.4           |
```

**Validation:** 14.5 + 19.4 + 14.6 + 15.5 + 20.6 + 15.4 = 100.0

---

## Sheet 6: Advanced_Settings

**Purpose:** Fine-tune rim weighting algorithm parameters.

**Optional:** Default values work for most cases.

### Columns

| Column | Required | Type | Default | Description |
|--------|----------|------|---------|-------------|
| weight_name | Yes | Text | - | Must match Weight_Specifications |
| max_iterations | No | Integer | 50 | Maximum raking iterations |
| convergence_tolerance | No | Number | 0.001 | Convergence precision threshold |
| force_convergence | No | Y/N | N | Accept non-converged weights |

### Parameter Guidelines

**max_iterations** (default: 50)
- Increase to 100 if convergence fails
- Maximum useful: 200 (if not converged by then, likely won't)

**convergence_tolerance** (default: 0.001)
- Smaller values = tighter convergence
- 0.0001 for high-precision work

**force_convergence** (default: N)
- Set to Y to use non-converged weights (not recommended)
- Review diagnostics carefully if using this option

### Example

```
| weight_name | max_iterations | convergence_tolerance | force_convergence |
|-------------|----------------|----------------------|-------------------|
| pop_weight  | 100            | 0.001                | N                 |
```

---

## Sheet 7: Notes

**Purpose:** Document assumptions, methodology, and caveats.

**Optional:** Notes appear in the HTML report (Method Notes tab) and Excel diagnostics.

### Columns

| Column  | Required | Type | Description                                    |
|---------|----------|------|------------------------------------------------|
| Section | Yes      | Text | Category: Assumptions, Methodology, Data Quality, Caveats |
| Note    | Yes      | Text | Description text                               |

### Example

```
| Section      | Note                                              |
|--------------|---------------------------------------------------|
| Assumptions  | Population data sourced from Census 2021           |
| Assumptions  | Age categories collapsed from 5-year bands         |
| Methodology  | Rim weighting chosen over cell due to sparse cells |
| Data Quality | 3 records excluded due to missing age data         |
| Caveats      | Rural areas may be under-represented               |
```

---

## Complete Example Configuration

### General Sheet

```
| Setting           | Value                               |
|-------------------|-------------------------------------|
| project_name      | Customer_Satisfaction_2025           |
| data_file         | data/csat_responses.xlsx             |
| output_file       | output/csat_weighted.xlsx            |
| save_diagnostics  | Y                                   |
| diagnostics_file  | output/weight_diagnostics.xlsx       |
| html_report       | Y                                   |
| html_report_file  | output/weighting_report.html         |
```

### Weight_Specifications Sheet

```
| weight_name    | method | description                | apply_trimming | trim_method | trim_value |
|----------------|--------|----------------------------|----------------|-------------|------------|
| segment_weight | design | Account segment weights    | N              |             |            |
| demo_weight    | rim    | Demographic adjustment     | Y              | cap         | 5          |
| cell_weight    | cell   | Age x Gender interlocked   | N              |             |            |
```

### Design_Targets Sheet

```
| weight_name    | stratum_variable | stratum_category | population_size |
|----------------|------------------|------------------|-----------------|
| segment_weight | account_tier     | Enterprise       | 500             |
| segment_weight | account_tier     | Mid-Market       | 2500            |
| segment_weight | account_tier     | SMB              | 12000           |
```

### Rim_Targets Sheet

```
| weight_name | variable | category | target_percent |
|-------------|----------|----------|----------------|
| demo_weight | industry | Tech     | 25             |
| demo_weight | industry | Finance  | 20             |
| demo_weight | industry | Retail   | 30             |
| demo_weight | industry | Other    | 25             |
| demo_weight | region   | Americas | 40             |
| demo_weight | region   | EMEA     | 35             |
| demo_weight | region   | APAC     | 25             |
```

### Cell_Targets Sheet

```
| weight_name | Gender | Age   | target_percent |
|-------------|--------|-------|----------------|
| cell_weight | Male   | 18-34 | 14.5           |
| cell_weight | Male   | 35-54 | 19.4           |
| cell_weight | Male   | 55+   | 14.6           |
| cell_weight | Female | 18-34 | 15.5           |
| cell_weight | Female | 35-54 | 20.6           |
| cell_weight | Female | 55+   | 15.4           |
```

### Notes Sheet

```
| Section     | Note                                    |
|-------------|-----------------------------------------|
| Assumptions | Census 2025 population estimates used   |
| Methodology | Cell weights for precise demographic fit |
```

---

## Validation Checklist

Before running, verify:

### General Sheet

- [ ] project_name is set
- [ ] data_file points to existing file
- [ ] output_file path is writable (if specified)
- [ ] diagnostics_file path is writable (if save_diagnostics=Y)

### Weight_Specifications Sheet

- [ ] Each weight has unique weight_name
- [ ] method is "design", "rim", "rake", or "cell"
- [ ] If apply_trimming=Y, trim_method and trim_value are set

### Design_Targets Sheet

- [ ] weight_name matches Weight_Specifications
- [ ] stratum_variable exists in data
- [ ] stratum_category values exist in data (exact match)
- [ ] population_size is positive for all rows
- [ ] All data categories are covered

### Rim_Targets Sheet

- [ ] weight_name matches Weight_Specifications
- [ ] variable exists in data
- [ ] category values exist in data (exact match)
- [ ] target_percent sums to 100 per variable (+/- 0.5%)
- [ ] No duplicate category within same variable
- [ ] No missing values in rim variables in data

### Cell_Targets Sheet

- [ ] weight_name matches Weight_Specifications
- [ ] Variable columns exist in data
- [ ] Category values exist in data (exact match)
- [ ] target_percent sums to 100 across all rows (+/- 0.5%)
- [ ] No duplicate cell combinations
- [ ] Every cell has at least one respondent in data

---

## Creating a Template

Generate a pre-filled template using R:

```r
source("modules/weighting/templates/create_template.R")
create_weight_config_template("my_project/Weight_Config.xlsx")
```

This creates a template with example data for all three methods that you can modify.

---

*TURAS Weighting Module - Template Reference v3.0*
