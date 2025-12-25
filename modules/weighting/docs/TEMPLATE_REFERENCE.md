---
editor_options: 
  markdown: 
    wrap: 72
---

# TURAS Weighting Module - Template Reference

## Weight_Config.xlsx Template Specification

This document provides complete specifications for the
Weight_Config.xlsx configuration file.

------------------------------------------------------------------------

## File Structure Overview

```         
Weight_Config.xlsx
├── General              (Required) Project settings
├── Weight_Specifications (Required) Define weights to calculate
├── Design_Targets       (Required for design weights)
├── Rim_Targets          (Required for rim weights)
└── Advanced_Settings    (Optional) Rim weighting parameters
```

------------------------------------------------------------------------

## Sheet 1: General

**Purpose:** Project-level configuration settings.

**Format:** Two-column layout with Setting and Value columns.

### Required Settings

| Setting      | Type | Description                    | Example                   |
|----------------|----------------|-----------------------|----------------|
| project_name | Text | Project identifier for reports | `Customer_Survey_Q4_2025` |
| data_file    | Path | Path to survey data file       | `data/responses.csv`      |

### Optional Settings

| Setting | Type | Default | Description |
|----------------|----------------|----------------|-----------------------|
| output_file | Path | (none) | Path to save weighted data |
| save_diagnostics | Y/N | N | Save diagnostic report to file |
| diagnostics_file | Path | (none) | Path for diagnostic report (required if save_diagnostics=Y) |

### Path Resolution

Paths are resolved in this order: 1. If absolute path (starts with `/`
or `C:\`), use as-is 2. Otherwise, resolve relative to config file
location

### Supported Data Formats

| Extension | Format                 | Notes                        |
|-----------|------------------------|------------------------------|
| .csv      | Comma-separated values | Standard CSV with header row |
| .xlsx     | Excel 2007+            | First sheet is read          |
| .xls      | Excel 97-2003          | First sheet is read          |
| .sav      | SPSS                   | Requires `haven` package     |

### Example

```         
| Setting           | Value                          |
|-------------------|--------------------------------|
| project_name      | Brand_Tracking_Wave_12         |
| data_file         | data/brand_track_w12.csv       |
| output_file       | output/brand_track_w12_weighted.csv |
| save_diagnostics  | Y                              |
| diagnostics_file  | output/weight_diagnostics.txt  |
```

------------------------------------------------------------------------

## Sheet 2: Weight_Specifications

**Purpose:** Define each weight column to calculate.

**Format:** One row per weight, with columns for configuration.

### Columns

| Column           | Required    | Type   | Description                            |
|------------------|-------------|--------|----------------------------------------|
| weight_name      | Yes         | Text   | Column name for weight (added to data) |
| method           | Yes         | Text   | `design` or `rim`                      |
| description      | No          | Text   | Documentation only                     |
| apply_trimming   | No          | Y/N    | Apply weight trimming (default: N)     |
| trim_method      | If trimming | Text   | `cap` or `percentile`                  |
| trim_value       | If trimming | Number | Trim threshold                         |
| population_total | No          | Number | Total population (for grossing)        |

### Weight Naming Rules

-   Must be valid R column name
-   No spaces (use underscores)
-   Must be unique
-   Recommended: descriptive lowercase with underscores

**Good names:** `design_weight`, `pop_weight`, `segment_wt` **Bad
names:** `Weight 1`, `wt`, `123weight`

### Method Values

| Value  | Description                             | Requires Sheet |
|--------|-----------------------------------------|----------------|
| design | Stratified sample weights               | Design_Targets |
| rim    | Iterative proportional fitting (raking) | Rim_Targets    |

### Trimming Configuration

**When apply_trimming = Y:**

| trim_method | trim_value Meaning         | Example                         |
|-------------|----------------------------|---------------------------------|
| cap         | Maximum weight value       | `5` = cap weights at 5          |
| percentile  | Percentile threshold (0-1) | `0.95` = cap at 95th percentile |

### Example

```         
| weight_name    | method | description              | apply_trimming | trim_method | trim_value |
|----------------|--------|--------------------------|----------------|-------------|------------|
| segment_weight | design | Stratified by segment    | N              |             |            |
| pop_weight     | rim    | Census demographics      | Y              | cap         | 5          |
| alt_weight     | rim    | Relaxed demographics     | Y              | percentile  | 0.95       |
```

------------------------------------------------------------------------

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

1.  **All categories must be covered**
    -   Every unique value in stratum_variable must have a row
    -   Uncovered values will have NA weights
2.  **Category matching is exact**
    -   Case-sensitive: "Male" ≠ "male"
    -   Whitespace-sensitive: "Male " ≠ "Male"
3.  **Population sizes must be positive**
    -   Zero or negative values are invalid
    -   Use actual counts, not percentages
4.  **One stratum variable per weight**
    -   Each weight uses exactly one stratification variable
    -   For multiple variables, use rim weighting

### Example

```         
| weight_name    | stratum_variable | stratum_category | population_size |
|----------------|------------------|------------------|-----------------|
| segment_weight | company_size     | Small            | 8500            |
| segment_weight | company_size     | Medium           | 1200            |
| segment_weight | company_size     | Large            | 300             |
| dept_weight    | department       | Sales            | 150             |
| dept_weight    | department       | Marketing        | 45              |
| dept_weight    | department       | Operations       | 280             |
| dept_weight    | department       | Finance          | 35              |
```

------------------------------------------------------------------------

## Sheet 4: Rim_Targets

**Purpose:** Specify target percentages for rim weighting (raking).

**Required for:** All weights with `method = rim`

### Columns

| Column         | Required | Type   | Description                      |
|----------------|----------|--------|----------------------------------|
| weight_name    | Yes      | Text   | Must match Weight_Specifications |
| variable       | Yes      | Text   | Column name in data              |
| category       | Yes      | Text   | Category value (exact match)     |
| target_percent | Yes      | Number | Target percentage (0-100)        |

### Rules

1.  **Percentages must sum to 100**
    -   For each variable, all category percentages must sum to 100
    -   Tolerance: ±0.1%
2.  **All categories must be covered**
    -   Every unique value in the variable must have a target
    -   Missing categories will cause an error
3.  **Use percentages, not proportions**
    -   Enter `48` for 48%, not `0.48`
    -   Range: 0 to 100
4.  **Maximum recommended variables: 5**
    -   More variables increase convergence risk
    -   Each additional variable multiplies complexity
5.  **No missing values in data**
    -   Rim variables must have no NAs
    -   Impute or exclude before weighting

### Example

```         
| weight_name | variable   | category  | target_percent |
|-------------|------------|-----------|----------------|
| pop_weight  | Gender     | Male      | 48             |
| pop_weight  | Gender     | Female    | 52             |
| pop_weight  | Age_Group  | 18-34     | 30             |
| pop_weight  | Age_Group  | 35-54     | 40             |
| pop_weight  | Age_Group  | 55+       | 30             |
| pop_weight  | Region     | Northeast | 18             |
| pop_weight  | Region     | Midwest   | 22             |
| pop_weight  | Region     | South     | 38             |
| pop_weight  | Region     | West      | 22             |
```

### Validation Check

Each variable should sum to 100: - Gender: 48 + 52 = 100 ✓ - Age_Group:
30 + 40 + 30 = 100 ✓ - Region: 18 + 22 + 38 + 22 = 100 ✓

------------------------------------------------------------------------

## Sheet 5: Advanced_Settings

**Purpose:** Fine-tune rim weighting algorithm parameters.

**Optional:** Default values work for most cases.

### Columns

| Column | Required | Type | Default | Description |
|--------------|--------------|--------------|--------------|----------------|
| weight_name | Yes | Text | \- | Must match Weight_Specifications |
| max_iterations | No | Integer | 25 | Maximum raking iterations |
| convergence_tolerance | No | Number | 0.01 | Stop when margins within this % |
| force_convergence | No | Y/N | N | Return weights even if not converged |

### Parameter Guidelines

**max_iterations** - Default: 25 - Increase to: 50 if convergence
fails - Maximum useful: 100 (if not converged by then, likely won't)

**convergence_tolerance** - Default: 0.01 (1%) - Means: Stop when all
margins are within 1% of target - Relax to: 0.02 or 0.05 if convergence
is difficult

**force_convergence** - Default: N (refuse if not converged) - Set to: Y
only when you accept approximate weights - Warning: Targets may not be
exactly achieved

### Example

```         
| weight_name | max_iterations | convergence_tolerance | force_convergence |
|-------------|----------------|----------------------|-------------------|
| pop_weight  | 50             | 0.01                 | N                 |
| relaxed_wt  | 30             | 0.05                 | Y                 |
```

------------------------------------------------------------------------

## Complete Example Configuration

### General Sheet

```         
| Setting           | Value                           |
|-------------------|---------------------------------|
| project_name      | Customer_Satisfaction_2025      |
| data_file         | data/csat_responses.xlsx        |
| output_file       | output/csat_weighted.xlsx       |
| save_diagnostics  | Y                               |
| diagnostics_file  | output/weight_report.txt        |
```

### Weight_Specifications Sheet

```         
| weight_name    | method | description                | apply_trimming | trim_method | trim_value |
|----------------|--------|----------------------------|----------------|-------------|------------|
| segment_weight | design | Account segment weights    | N              |             |            |
| demo_weight    | rim    | Demographic adjustment     | Y              | cap         | 5          |
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

### Advanced_Settings Sheet

```         
| weight_name | max_iterations | convergence_tolerance | force_convergence |
|-------------|----------------|----------------------|-------------------|
| demo_weight | 30             | 0.01                 | N                 |
```

------------------------------------------------------------------------

## Validation Checklist

Before running, verify:

### General Sheet

-   [ ] project_name is set
-   [ ] data_file points to existing file
-   [ ] output_file path is writable (if specified)
-   [ ] diagnostics_file path is writable (if save_diagnostics=Y)

### Weight_Specifications Sheet

-   [ ] Each weight has unique weight_name
-   [ ] method is "design" or "rim"
-   [ ] If apply_trimming=Y, trim_method and trim_value are set

### Design_Targets Sheet

-   [ ] weight_name matches Weight_Specifications
-   [ ] stratum_variable exists in data
-   [ ] stratum_category values exist in data (exact match)
-   [ ] population_size is positive for all rows
-   [ ] All data categories are covered

### Rim_Targets Sheet

-   [ ] weight_name matches Weight_Specifications
-   [ ] variable exists in data
-   [ ] category values exist in data (exact match)
-   [ ] target_percent sums to 100 per variable
-   [ ] No duplicate category within same variable
-   [ ] No missing values in rim variables in data

------------------------------------------------------------------------

## Creating a Template

Generate a pre-filled template using R:

``` r
source("modules/weighting/templates/create_template.R")
create_weight_config_template("my_project/Weight_Config.xlsx")
```

This creates a template with example data that you can modify.

------------------------------------------------------------------------

*TURAS Weighting Module - Template Reference v1.0*
