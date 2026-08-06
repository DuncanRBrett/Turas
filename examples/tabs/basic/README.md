# Tabs Basic Example

**Purpose:** Minimal working example for the TURAS Tabs (crosstabulation) module

**Status:** Working. `tabs_config.xlsx` and `Survey_Structure.xlsx` were
rebuilt 2026-08-06 against the current template shape (both previously
predated the 2-column Settings-sheet format and failed to load). Verified
end-to-end: `run_tabs_analysis("examples/tabs/basic/tabs_config.xlsx")`
completes PASS and produces sensible output (see Expected Outputs below,
independently cross-checked against `data.csv`). Weighting is on
(`weight` column). `tests/regression/test_regression_tabs_mock.R` still
reads `data.csv` directly through its own hand-written mock, unaffected
by this rebuild, and continues to pass.

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
| `Survey_Structure.xlsx` | Question definitions, response options, box categories |
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

Verified 2026-08-06 against the real Tabs engine's output, cross-checked
independently against `data.csv` (both agree).

### Overall Metrics (Unweighted)
- Mean satisfaction: 7.7
- Mean recommend: 8.2
- Base size: 50 (unweighted), 51 (weighted)

### By Gender
- **Male:** Higher satisfaction (8.3)
- **Female:** Lower satisfaction (7.0)
- **Significance:** Male vs Female is significant at 95% (confirmed — the
  Mean row's Sig. column carries a letter)

### Box Categories (1-10 rating questions)
Options are grouped `Bottom (1-6)` / `Middle (7-8)` / `Top 2 Box (9-10)`.
- Top 2 Box, recommend: ~43% of respondents (weighted; 42% unweighted —
  **not** ~68%, a stale figure in an earlier draft of this README that
  didn't match `data.csv`)

---

## How to Run This Example

### Option 1: Via Shiny GUI

```r
# From TURAS root directory
source("turas.R")
turas_load("tabs")

# Select this example project when prompted
```

### Option 2: Programmatically

```r
# From TURAS root directory
source("modules/tabs/run_tabs.R")
run_tabs_analysis("examples/tabs/basic/tabs_config.xlsx")

# Output workbook lands at examples/tabs/basic/Output/Crosstabs.xlsx
```

### Option 3: Regression Test

```r
# From TURAS root directory
library(testthat)
test_file("tests/regression/test_regression_tabs_mock.R")
```

---

## Configuration Notes

The `tabs_config.xlsx` file specifies:
- Banner variables: gender, age_group, region
- Questions to analyze: satisfaction, recommend, quality, value (each
  declared as `Rating` in `Survey_Structure.xlsx`, options 1-10 grouped
  into `Bottom (1-6)` / `Middle (7-8)` / `Top 2 Box (9-10)` box categories)
- Significance testing: alpha = 0.05, minimum base = 10 (lowered from the
  default 30 so the 25-respondent gender split still gets tested)
- Weighting: on, using the `weight` variable

---

## Next Steps

**Done (2026-08-06):** config rebuilt against the current template shape,
verified to run PASS end-to-end, output values cross-checked independently
against `data.csv`.

**Still open — upgrading the regression test to use the real engine:**
`tests/regression/test_regression_tabs_mock.R` currently passes using a
hand-written mock that duplicates a small slice of Tabs' logic rather than
calling the module. Now that `run_tabs_analysis()` can load this example,
replacing the mock is possible:

1. Write a thin wrapper that calls
   `run_tabs_analysis("examples/tabs/basic/tabs_config.xlsx")` and reads
   back `examples/tabs/basic/Output/Crosstabs.xlsx`
2. Extract the same metrics `extract_tabs_value()` currently reads from
   the mock's `summary` list, from the real workbook's Index_Summary /
   Crosstabs sheets instead
3. Recompute golden values in `tests/regression/golden/tabs_basic.json`
   from the real engine's output (the Expected Outputs above are a start)
   and set tolerances
4. Remove the mock once the real-engine path is green

This is a stretch goal, not a prerequisite — the mock test is honest
about being a mock and passes either way.

---

## Troubleshooting

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
**Config rebuilt:** 2026-08-06 (TURAS Version 10.8.1)
**Module:** Tabs (Crosstabulation)
**Author:** TURAS Development Team
