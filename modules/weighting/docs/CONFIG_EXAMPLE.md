# Weight_Config.xlsx - Complete Example Guide

## Overview

This guide shows you **exactly** what your Weight_Config.xlsx should look like. It covers all three weighting methods and all available configuration sheets.

## Quick Start Template

Run this in R to generate a working template:

```r
source("modules/weighting/templates/create_template.R")
create_weight_config_template("my_project/Weight_Config.xlsx")
```

This creates a pre-configured template with all sheets and v3.0 parameters.

---

## Manual Configuration Guide

If creating manually, your Excel file can have up to 7 sheets:

| Sheet | Required | Purpose |
|-------|----------|---------|
| General | Yes | Project settings, file paths, report options |
| Weight_Specifications | Yes | Define each weight to calculate |
| Design_Targets | If method=design | Population sizes per stratum |
| Rim_Targets | If method=rim | Target percentages per variable |
| Cell_Targets | If method=cell | Joint distribution targets |
| Advanced_Settings | No | Fine-tune rim convergence parameters |
| Notes | No | Document assumptions, methodology, caveats |

### Sheet 1: General

| Setting | Value |
|---------|-------|
| project_name | My_Survey_Project |
| data_file | data/survey_responses.csv |
| output_file | data/survey_weighted.csv |
| save_diagnostics | Y |
| diagnostics_file | output/weight_diagnostics.xlsx |
| html_report | Y |
| html_report_file | output/weighting_report.html |
| brand_colour | #1e3a5f |
| accent_colour | #2aa198 |
| researcher_name | Jane Smith |
| client_name | Acme Corp |
| logo_file | assets/acme_logo.png |

**Notes:**
- `data_file` path is relative to the Weight_Config.xlsx location
- All paths can be relative or absolute
- Supported data formats: .csv, .xlsx, .xls, .sav
- `html_report_file` is auto-generated if left blank
- `brand_colour`/`accent_colour` are optional (defaults used if blank)
- `researcher_name`/`client_name` appear in the HTML report header as "Prepared by X for Y"
- `logo_file` is embedded as a base64 image in the report header (PNG, JPG, SVG supported)

---

### Sheet 2: Weight_Specifications

| weight_name | method | description | apply_trimming | trim_method | trim_value |
|------------|--------|-------------|----------------|-------------|------------|
| design_wt | design | Segment design weights | N | | |
| pop_weight | rim | Population demographics | Y | cap | 5 |
| cell_wt | cell | Age x Gender interlocked | N | | |

**Column Meanings:**
- `weight_name`: Name for the weight column (will be added to your data)
- `method`: `design`, `rim` (or `rake`), or `cell`
- `apply_trimming`: "Y" or "N" - cap extreme weights after calculation
- `trim_method`: "cap" (hard maximum) or "percentile" (e.g., 95 = 95th percentile)
- `trim_value`: Maximum weight value (for cap method) or percentile threshold

**Important:** The `weight_name` here must match in the corresponding targets sheet and Advanced_Settings.

---

### Sheet 3: Design_Targets

**Only needed for `method = "design"`.**

| weight_name | stratum_variable | stratum_category | population_size |
|-------------|------------------|------------------|-----------------|
| design_wt | segment | Small | 5000 |
| design_wt | segment | Medium | 3500 |
| design_wt | segment | Large | 1500 |

---

### Sheet 4: Rim_Targets

**This is the key sheet for rim weighting.**

Example with 3 demographic variables:

| weight_name | variable | category | target_percent |
|-------------|----------|----------|----------------|
| pop_weight | Age | 18-34 | 30 |
| pop_weight | Age | 35-54 | 40 |
| pop_weight | Age | 55+ | 30 |
| pop_weight | Gender | Male | 48 |
| pop_weight | Gender | Female | 52 |
| pop_weight | Region | Urban | 35 |
| pop_weight | Region | Suburban | 45 |
| pop_weight | Region | Rural | 20 |

**Critical Rules:**
1. **Targets must sum to 100 per variable:**
   - Age: 30 + 40 + 30 = 100
   - Gender: 48 + 52 = 100
   - Region: 35 + 45 + 20 = 100

2. **Variable names must exactly match your data columns** (case-sensitive)

3. **Category values must exactly match your data** (case-sensitive, no extra spaces)

4. **All categories must exist in your data**

5. **Maximum 5 variables recommended** for convergence

---

### Sheet 5: Cell_Targets

**This is the key sheet for cell/interlocked weighting.**

Example with Gender x Age cross-tabulation:

| weight_name | Gender | Age | target_percent |
|-------------|--------|-----|----------------|
| cell_wt | Male | 18-34 | 14.5 |
| cell_wt | Male | 35-54 | 19.4 |
| cell_wt | Male | 55+ | 14.6 |
| cell_wt | Female | 18-34 | 15.5 |
| cell_wt | Female | 35-54 | 20.6 |
| cell_wt | Female | 55+ | 15.4 |

**Critical Rules:**
1. **All target_percent values must sum to 100** (14.5 + 19.4 + 14.6 + 15.5 + 20.6 + 15.4 = 100)
2. **Every cell combination must have a row** (2 genders x 3 age groups = 6 rows)
3. **Every combination must have at least one respondent in your data**
4. **Column names must exactly match your data** (case-sensitive)

**When to use cell over rim:**
- Use cell weighting when the *joint distribution* matters (e.g., young males specifically under-represented)
- Use rim weighting when you only need marginal distributions to match

---

### Sheet 6: Advanced_Settings

**Optional sheet - defaults work for most cases.**

| weight_name | max_iterations | convergence_tolerance | force_convergence |
|-------------|----------------|----------------------|-------------------|
| pop_weight | 100 | 0.001 | N |

**Parameter Guide:**

**max_iterations** (default: 50)
- How many iterations before stopping
- Increase to 100 if convergence fails

**convergence_tolerance** (default: 0.001)
- How precisely margins must match targets
- Smaller values = tighter convergence

**force_convergence** (default: N)
- Set to Y to accept non-converged weights (not recommended)
- Always review diagnostics if using this

---

### Sheet 7: Notes

**Optional sheet - document your methodology.**

| Section | Note |
|---------|------|
| Assumptions | Population data sourced from Census 2021 |
| Assumptions | Age categories collapsed from 5-year bands |
| Methodology | Rim weighting chosen over cell due to sparse cells |
| Data Quality | 3 records excluded due to missing age data |
| Caveats | Rural areas may be under-represented |

**Sections:** Use any of: Assumptions, Methodology, Data Quality, Caveats (or custom names).

Notes appear in:
- HTML report (Method Notes tab)
- Excel diagnostics (Notes sheet)

---

## Data Requirements

Your survey data file must:

1. **Have columns matching your weighting variables:**
   ```r
   # If Rim_Targets uses "Age", "Gender", "Region"
   # Your data MUST have columns named exactly: Age, Gender, Region
   ```

2. **Use exact category values:**
   ```r
   # If Rim_Targets has category "18-34" for Age
   # Your data's Age column must contain "18-34" (exact match)
   ```

3. **No missing values in weighting variables:**
   ```r
   # Check for NAs:
   sum(is.na(data$Age))      # Should be 0
   sum(is.na(data$Gender))   # Should be 0
   ```

4. **All target categories present in data:**
   ```r
   # Check what's in your data:
   table(data$Age)
   table(data$Gender)
   ```

---

## Common Errors and Fixes

### "Category names don't match"
**Cause:** Case mismatch between targets and data.
**Fix:** Check `unique(data$ColumnName)` against your target values. Values are case-sensitive.

### "Target percentages don't sum to 100"
**Cause:** Rim or cell targets don't add up.
**Fix:** Tolerance is 0.5%. Double-check arithmetic.

### "Variable not found in data"
**Cause:** Column name in targets doesn't exist in data.
**Fix:** Check `names(your_data)` to see exact column names.

### "Calibration did not converge"
**Try (in order):**
1. Increase `max_iterations` to 100
2. Reduce number of rim variables
3. Widen the gap between sample and target (fewer extreme adjustments needed)
4. Check minimum cell sizes (each category should have 20+ respondents)

### "Empty cells in cell weighting"
**Cause:** A cell combination in targets has no respondents in data.
**Fix:** Either collapse categories or use rim weighting instead.

---

## Running the Module

Once your config is ready:

```r
source("modules/weighting/run_weighting.R")
result <- run_weighting("Weight_Config.xlsx")

# Check results
head(result$data)                                  # Data with new weight column(s)
result$weight_results$pop_weight$diagnostics       # Quality metrics
```

Or from the Turas GUI: click **Weighting**, browse to your folder, select config, and click **Calculate Weights**.

---

*TURAS Weighting Module v3.0 Configuration Guide*
