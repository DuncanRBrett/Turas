# Tabs Basic Example

**Purpose:** Minimal working example for the TURAS Tabs (crosstabulation) module

**Status:** POC - Data created, awaiting full Tabs integration

**Use cases:**
1. **Tutorial** - Learn how to use the Tabs module
2. **Testing** - Regression test to ensure Tabs produces consistent outputs
3. **Reference** - Example of correct data format and configuration

---

## Files

| File | Description |
|------|-------------|
| `data.csv` | Synthetic survey data (50 respondents) |
| `tabs_config.xlsx` | Crosstabulation configuration |
| `README.md` | This file |

---

## Dataset Description

**Sample Size:** 50 respondents

**Variables:**
- `respondent_id` - Unique identifier (1-50)
- `gender` - Male, Female
- `age_group` - 18-34, 35-54, 55+
- `region` - North, South, East, West
- `satisfaction` - Rating 1-10
- `recommend` - Rating 1-10
- `quality` - Rating 1-10
- `value` - Rating 1-10
- `weight` - Sampling weight (0.8-1.3)

**Data Characteristics:**
- Balanced gender (25 each)
- Males rate slightly higher on average
- Includes weighting variable
- No missing values
- Clean, analysis-ready format

---

## Expected Outputs

When running Tabs on this data, you should see:

### Overall Metrics (Unweighted)
- Mean satisfaction: ~7.6
- Mean recommend: ~8.1
- Base size: 50

### By Gender
- **Male:** Higher satisfaction (~8.0)
- **Female:** Lower satisfaction (~7.2)
- **Significance:** Male vs Female should be significant at 95% level

### Top 2 Box (Ratings 9-10)
- Recommend: ~68% of respondents

---

## How to Run This Example

### Option 1: Via Shiny GUI

```r
# From TURAS root directory
source("turas.R")
turas_load("tabs")

# Select this example project when prompted
```

### Option 2: Programmatically (Once Implemented)

```r
# From TURAS root directory
source("modules/tabs/lib/run_crosstabs.R")

# Run on this example
output <- run_tabs_analysis(
  project_path = "examples/tabs/basic"
)

# View results
print(output$all_results)
```

### Option 3: Regression Test

```r
# From TURAS root directory
library(testthat)
test_file("tests/regression/test_regression_tabs.R")
```

---

## Configuration Notes

The `tabs_config.xlsx` file specifies:
- Banner variables: gender, age_group, region
- Questions to analyze: satisfaction, recommend, quality, value
- Statistical tests: Column proportions at 95% confidence
- Weighting: Use the `weight` variable

---

## Next Steps

**To Complete This Example:**

1. **Add Survey_Structure.xlsx**
   - Define question types and response options
   - Map variable names to display labels
   - Specify value ranges

2. **Verify Config**
   - Open tabs_config.xlsx
   - Check all settings match data structure
   - Verify output requirements

3. **Run Tabs**
   - Execute Tabs module on this data
   - Verify outputs are generated
   - Check output format and values

4. **Update Golden Values**
   - Extract key metrics from output
   - Update `tests/regression/golden/tabs_basic.json`
   - Set appropriate tolerances

5. **Complete Regression Test**
   - Implement `extract_tabs_value()` function
   - Implement `run_tabs_for_test()` wrapper
   - Remove `skip()` statement
   - Verify all checks pass

---

## Troubleshooting

**"Missing Survey_Structure.xlsx"**
- This file needs to be created
- Use templates/Survey_Structure_Template.xlsx as starting point
- Define the 4 rating questions and banner variables

**"Config validation errors"**
- Open tabs_config.xlsx
- Check sheet names match Tabs expectations
- Verify variable names exist in data.csv

**"Output doesn't match expected"**
- This is expected until golden values are updated
- Run Tabs manually first
- Capture actual outputs
- Update tabs_basic.json with real values

---

**Created:** 2025-12-02
**TURAS Version:** 10.0
**Module:** Tabs (Crosstabulation)
**Author:** TURAS Development Team
