# Key Driver Analysis - Quick Start Guide

**Get up and running with key driver analysis in 5 minutes!**

---

## Prerequisites

- R installed (4.0+)
- Required packages: `openxlsx`, `shiny`, `shinyFiles`
- Optional: `haven` (for SPSS/Stata files)

---

## Option 1: Launch from Turas GUI (Easiest)

```r
# In R console
setwd("~/Documents/Turas")  # Or your Turas directory
source("launch_turas.R")
```

Click the **🔑 Key Driver** button and follow the GUI prompts.

---

## Option 2: Run from R Console

### Step 1: Prepare Your Data

**Data file** (CSV, XLSX, SAV, or DTA):
- One row per respondent
- All variables numeric (1-10 scales recommended)
- At least 60 cases for 6 drivers (rule: n ≥ max(30, 10×k))

### Step 2: Create Config File

Create an Excel file with 2 sheets:

**Sheet: Settings**
| Setting | Value |
|---------|-------|
| analysis_name | My Analysis Name |
| data_file | survey_data.csv |
| output_file | results.xlsx |

**Sheet: Variables**
| VariableName | Type | Label |
|--------------|------|-------|
| satisfaction | Outcome | Overall Satisfaction |
| quality | Driver | Product Quality |
| service | Driver | Customer Service |
| price | Driver | Value for Money |
| speed | Driver | Delivery Speed |

### Step 3: Run Analysis

```r
# Source the module
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

# Run
results <- run_keydriver_analysis(
  config_file = "my_config.xlsx"
)

# Or specify paths explicitly
results <- run_keydriver_analysis(
  config_file = "my_config.xlsx",
  data_file = "my_data.csv",
  output_file = "my_results.xlsx"
)
```

### Step 4: View Results

Open the Excel output file. You'll find **6 sheets**:

1. **Importance Summary** - All importance scores
2. **Method Rankings** - Rank by each method
3. **Model Summary** - R², VIF diagnostics
4. **Correlations** - Full correlation matrix
5. **Charts** - Shapley impact bar chart 📊
6. **README** - Methodology documentation

---

## Understanding Your Results

### Top 5 Drivers (Example)

```
1. Product Quality (28.5%)      ← Fix this first!
2. Customer Service (23.1%)     ← High impact
3. Delivery Speed (19.7%)       ← Moderate impact
4. Value for Money (15.2%)      ← Secondary
5. Website Experience (8.9%)    ← Lower priority
```

### What the Numbers Mean

- **>20%** = Major driver (high priority for improvement)
- **10-20%** = Moderate driver (secondary priority)
- **<10%** = Minor driver (limited impact)

### Check VIF (Multicollinearity)

In **Model Summary** sheet:
- **VIF < 5**: Good, low multicollinearity
- **VIF 5-10**: Moderate, watch for instability
- **VIF > 10**: High, consider removing or combining drivers

---

## Common Issues & Fixes

### Error: "Insufficient complete cases"
**Problem**: Not enough data for number of drivers
**Fix**: You need at least `max(30, 10 × #drivers)` complete cases
- 5 drivers → need 50 cases
- 8 drivers → need 80 cases

### Error: "Aliased/NA coefficients"
**Problem**: Perfect multicollinearity (two drivers perfectly correlated)
**Fix**: Remove or combine the correlated drivers

### Error: "Too many drivers (>15)"
**Problem**: Shapley computation becomes impractical with >15 drivers
**Fix**: Reduce to top 12-15 most important drivers first

### Chart doesn't display
**Problem**: Image rendering issue
**Fix**: Make sure you have a graphics device available (should work automatically)

---

## Next Steps

- Read the **USER_MANUAL.md** for detailed methodology
- Check **README.md** for advanced features (weights, etc.)
- See example configs in `test_data/` directory

---

## Quick Tips

✅ **DO:**
- Use at least 60-100 respondents
- Keep drivers to 12 or fewer if possible
- Check VIF for multicollinearity
- Use descriptive labels in config

❌ **DON'T:**
- Use <30 complete cases
- Include perfectly correlated drivers
- Use >15 drivers (Shapley limit)
- Mix categorical and numeric without recoding

---

**Need Help?** See USER_MANUAL.md or contact support.
