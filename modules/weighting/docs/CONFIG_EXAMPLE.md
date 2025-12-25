# Weight_Config.xlsx - Complete Example Guide

## Overview

This guide shows you **exactly** what your Weight_Config.xlsx should look like for rim weighting with v2.0.

## Quick Start Template

Run this in R to generate a working template:

```r
source("modules/weighting/templates/create_template.R")
create_weight_config_template("my_project/Weight_Config.xlsx")
```

This creates a pre-configured template with all sheets and v2.0 parameters.

---

## Manual Configuration Guide

If creating manually, your Excel file needs these 5 sheets:

### Sheet 1: General

| Setting | Value |
|---------|-------|
| project_name | My_Survey_Project |
| data_file | data/survey_responses.csv |
| output_file | data/survey_weighted.csv |
| save_diagnostics | Y |
| diagnostics_file | output/weight_diagnostics.txt |

**Notes:**
- `data_file` path is relative to the Weight_Config.xlsx location
- All paths can be relative or absolute
- Supported data formats: .csv, .xlsx, .xls, .sav

---

### Sheet 2: Weight_Specifications

| weight_name | method | description | apply_trimming | trim_method | trim_value |
|------------|--------|-------------|----------------|-------------|------------|
| pop_weight | rim | Population demographics | Y | cap | 5 |

**Column Meanings:**
- `weight_name`: Name for the weight column (will be added to your data)
- `method`: Use "rim" for demographic adjustment
- `apply_trimming`: "Y" or "N" - cap extreme weights after calibration
- `trim_method`: "cap" (hard maximum) or "percentile" (e.g., 0.95 = 95th percentile)
- `trim_value`: Maximum weight value (for cap method) or percentile threshold

**Important:** The `weight_name` here must match in Rim_Targets and Advanced_Settings sheets.

---

### Sheet 3: Design_Targets

**Skip this sheet if only doing rim weighting.** Only needed for `method = "design"`.

If you need design weights, structure looks like:

| weight_name | stratum_variable | stratum_category | population_size |
|-------------|------------------|------------------|-----------------|
| seg_weight | segment | Small | 5000 |
| seg_weight | segment | Medium | 3500 |
| seg_weight | segment | Large | 1500 |

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
   - Age: 30 + 40 + 30 = 100 ✓
   - Gender: 48 + 52 = 100 ✓
   - Region: 35 + 45 + 20 = 100 ✓

2. **Variable names must exactly match your data columns:**
   - Case-sensitive: "Age" ≠ "age"
   - Check column names: `names(your_data)`

3. **Category values must exactly match your data:**
   - Case-sensitive: "Male" ≠ "male"
   - No extra spaces: "Male " ≠ "Male"
   - Check unique values: `unique(your_data$Gender)`

4. **All categories must exist in your data:**
   - If your data doesn't have "Rural" respondents, don't include in targets
   - Module will error if target category not found in data

5. **Maximum 5 variables recommended** for convergence

---

### Sheet 5: Advanced_Settings

**Optional sheet - defaults work for most cases.**

For v2.0, structure is:

| weight_name | max_iterations | convergence_tolerance | calibration_method | weight_bounds |
|-------------|----------------|----------------------|-------------------|---------------|
| pop_weight | 50 | 1e-7 | raking | 0.3,3.0 |

**Parameter Guide:**

**max_iterations** (default: 50)
- How many iterations before giving up
- Increase to 100 if convergence fails
- Rarely need more than 200

**convergence_tolerance** (default: 1e-7)
- How precise convergence needs to be
- 1e-7 = 0.00001% (very tight)
- Larger values (1e-6, 1e-5) allow faster convergence

**calibration_method** (default: "raking")
- **"raking"**: Traditional iterative proportional fitting (recommended)
- **"linear"**: Linear calibration (Newton-Raphson, more flexible)
- **"logit"**: Logistic calibration (best for tight bounds, prevents extremes)
- Try "logit" if having convergence issues with bounds

**weight_bounds** (default: "0.3,3.0")
- Format: "lower,upper" (e.g., "0.3,3.0" means weights between 0.3 and 3.0)
- Or single value: "5" means "0.3,5.0"
- **KEY v2.0 FEATURE**: Bounds applied **DURING** calibration (not after)
- Prevents extreme weights from forming during fitting
- Use with calibration_method="logit" for best results

**Examples:**
- Standard: `0.3,3.0` - Prevents weights below 0.3 or above 3.0
- Strict: `0.5,2.0` - Tighter control, less variance
- Relaxed: `0.2,5.0` - More flexibility for difficult targets

---

## Data Requirements

Your survey data file must:

1. **Have columns matching rim variables:**
   ```r
   # If Rim_Targets uses "Age", "Gender", "Region"
   # Your data MUST have columns named exactly: Age, Gender, Region
   ```

2. **Use exact category values:**
   ```r
   # If Rim_Targets has category "18-34" for Age
   # Your data's Age column must contain "18-34" (exact match)
   ```

3. **No missing values in rim variables:**
   ```r
   # Check for NAs:
   sum(is.na(data$Age))      # Should be 0
   sum(is.na(data$Gender))   # Should be 0
   sum(is.na(data$Region))   # Should be 0
   ```

4. **All target categories present:**
   ```r
   # Check what's actually in your data:
   table(data$Age)
   table(data$Gender)
   table(data$Region)
   ```

---

## Example Data Structure

If your Weight_Config.xlsx has the Rim_Targets shown above, your data should look like:

```csv
ResponseID,Age,Gender,Region,Q1,Q2,Q3
1,18-34,Male,Urban,5,3,4
2,35-54,Female,Suburban,4,4,5
3,55+,Male,Rural,3,2,3
4,18-34,Female,Urban,5,5,5
...
```

**Key Points:**
- Column names: `Age`, `Gender`, `Region` (exact match to Rim_Targets `variable`)
- Values: `18-34`, `Male`, `Urban` (exact match to Rim_Targets `category`)
- No NAs in weighting variables
- Other columns (Q1, Q2, Q3) are fine - only Age/Gender/Region need to be clean

---

## Common Errors and Fixes

### Error: "Population and sample totals are not the same length"

**Cause:** Mismatch between target structure and data structure.

**Check:**
1. Variable names in Rim_Targets exactly match data column names
2. All categories in Rim_Targets exist in your data
3. No extra spaces or case mismatches
4. No NAs in rim variables

**Fix:**
```r
# Check your data structure
data <- read.csv("your_data.csv")
str(data)

# Check rim variables exist
c("Age", "Gender", "Region") %in% names(data)  # All should be TRUE

# Check categories match
unique(data$Age)      # Compare to Rim_Targets
unique(data$Gender)   # Compare to Rim_Targets
unique(data$Region)   # Compare to Rim_Targets
```

---

### Error: "Target percentages don't sum to 100"

**Cause:** Targets for a variable don't sum to exactly 100.

**Fix:**
```r
# In Excel, add a check row:
Age totals: 30 + 40 + 30 = 100
```

---

### Error: "Variable not found in data"

**Cause:** Rim_Targets `variable` column has a name not in your data.

**Fix:**
```r
# Check data columns
names(your_data)

# Make sure Rim_Targets variable names match exactly
```

---

### Error: "Calibration did not converge"

**Try (in order):**
1. Increase `max_iterations` to 100
2. Change `calibration_method` to "logit"
3. Widen `weight_bounds` (e.g., "0.2,5.0")
4. Reduce number of rim variables
5. Check if targets are mathematically feasible

---

## Testing Your Config

Before running on full data, test with diagnostic code:

```r
# Load config
source("modules/weighting/lib/config_loader.R")
config <- load_weighting_config("Weight_Config.xlsx")

# Check structure
print(config$rim_targets)
print(config$advanced_settings)

# Load data
data <- read.csv(config$general$data_file_resolved)

# Verify rim variables exist
rim_vars <- unique(config$rim_targets$variable)
all(rim_vars %in% names(data))  # Should be TRUE

# Check for NAs
sapply(data[, rim_vars], function(x) sum(is.na(x)))  # All should be 0

# Check categories
for(var in rim_vars) {
  cat("\n", var, ":\n")
  print(table(data[[var]]))
}
```

---

## Running the Module

Once your config is ready:

```r
source("modules/weighting/run_weighting.R")
result <- run_weighting("Weight_Config.xlsx")

# Check results
head(result$data)  # Data with new weight column
result$weight_results$pop_weight$diagnostics  # Quality metrics
```

---

## Need Help?

1. **Generate a template:** Use `create_weight_config_template()` for working example
2. **Check documentation:** See USER_GUIDE.md for detailed explanations
3. **Review examples:** See TEMPLATE_REFERENCE.md for specifications

---

*TURAS Weighting Module v2.0 Configuration Guide*
