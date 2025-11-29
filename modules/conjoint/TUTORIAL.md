# Turas Conjoint Analysis - Step-by-Step Tutorial

**Tutorial:** Complete Conjoint Analysis from Start to Finish
**Time Required:** 30-45 minutes
**Difficulty:** Beginner-friendly

---

## What You'll Learn

By the end of this tutorial, you will:

✅ Set up your R environment for conjoint analysis
✅ Create a configuration file for your study
✅ Prepare your data in the correct format
✅ Run a complete conjoint analysis
✅ Interpret the results
✅ Use the interactive market simulator
✅ Test what-if scenarios

---

## Tutorial Overview

We'll analyze a **smartphone choice study** with:
- **5 attributes**: Brand, Price, Screen Size, Battery Life, Camera Quality
- **50 respondents**
- **8 choice sets per respondent**
- **3 alternatives per choice set**

This is a realistic conjoint study that demonstrates all key features.

---

## Part 1: Environment Setup (10 minutes)

### Step 1.1: Install R

**If you already have R installed, skip to Step 1.2**

**Windows:**
1. Go to https://cloud.r-project.org/
2. Click "Download R for Windows"
3. Click "base"
4. Click "Download R 4.x.x for Windows"
5. Run the installer (.exe file)
6. Accept all defaults

**Mac:**
1. Go to https://cloud.r-project.org/
2. Click "Download R for macOS"
3. Download the appropriate .pkg file for your Mac
4. Run the installer
5. Accept all defaults

**Verify installation:**
- Open R (or R console)
- You should see version information
- Type `quit()` to exit (for now)

### Step 1.2: Install Required Packages

**Open R or RStudio** and run these commands:

```r
# This will take 5-10 minutes the first time
# You only need to do this once

install.packages(c(
  "mlogit",
  "survival",
  "openxlsx",
  "dplyr",
  "tidyr"
))
```

**Wait for installation to complete.** You'll see messages like "package 'mlogit' successfully unpacked".

**Troubleshooting:**
- If asked "Do you want to install from sources?", answer **No**
- If asked about CRAN mirror, choose **0-Cloud** or any USA mirror
- If you see errors about permissions, try running R as administrator (Windows) or with sudo (Mac/Linux)

### Step 1.3: Verify Packages Work

```r
# Test that packages load correctly
library(mlogit)
library(survival)
library(openxlsx)
library(dplyr)
library(tidyr)

# If no errors appear, you're good to go!
# You should see some startup messages, that's normal
```

✅ **Checkpoint:** All five packages loaded without errors

---

## Part 2: Run the Example Analysis (5 minutes)

Before creating your own project, let's run the built-in example to make sure everything works.

### Step 2.1: Set Working Directory

```r
# Change this path to where you have Turas installed
setwd("/home/user/Turas")

# Verify you're in the right place
list.files("modules/conjoint/R")
# You should see: 00_main.R, 01_config.R, etc.
```

**Troubleshooting:**
- If you get "cannot change working directory", the path is wrong
- Find where you saved Turas and use that full path
- On Windows, use forward slashes: `setwd("C:/Users/YourName/Documents/Turas")`

### Step 2.2: Load All Module Files

**Copy and paste this entire block:**

```r
# Load all module files (in order)
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/05_simulator.R")
source("modules/conjoint/R/08_market_simulator.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")
```

**You should see:** No errors (some messages are OK)

### Step 2.3: Run the Example

```r
# Run the example analysis
results <- run_conjoint_analysis(
  config_file = "modules/conjoint/examples/example_config.xlsx"
)
```

**You should see:**
```
================================================================================
TURAS CONJOINT ANALYSIS - Enhanced Version 2.0
================================================================================

1. Loading configuration...
   ✓ Loaded 5 attributes with 17 total levels

2. Loading and validating data...
   ✓ Validated 50 respondents with 400 choice sets

3. Estimating choice model...
   → Method: auto (trying mlogit first)
   ✓ mlogit estimation successful

4. Calculating part-worth utilities...
   ✓ Estimated 17 part-worth utilities

5. Calculating attribute importance...
   ✓ Importance scores calculated

6. Running model diagnostics...
   ✓ McFadden R² = 0.31 (Good)
   ✓ Hit rate = 54.2%

7. Generating Excel output...
   ✓ Results written to: examples/output/example_results.xlsx

================================================================================
ANALYSIS COMPLETE
Total time: X.X seconds
================================================================================
```

### Step 2.4: View Results

```r
# View attribute importance
print(results$importance)

# You should see something like:
#   Attribute       Importance Rank
# 1 Price              35.2     1
# 2 Brand              28.7     2
# 3 Camera_Quality     16.8     3
# 4 Battery_Life       12.1     4
# 5 Screen_Size         7.2     5
```

### Step 2.5: Open Excel Output

Navigate to: `modules/conjoint/examples/output/example_results.xlsx`

**Open it in Excel and explore:**
- Executive Summary
- Attribute Importance
- Part-Worth Utilities
- Model Diagnostics
- Market Simulator (try changing dropdowns!)

✅ **Checkpoint:** Example analysis completed successfully and Excel file opens

---

## Part 3: Create Your Own Test Project (10 minutes)

Now let's create a project from scratch using a different example: **Coffee Shop Choice Study**

### Step 3.1: Create Project Directory

```r
# Create a new directory for your project
dir.create("my_conjoint_project", showWarnings = FALSE)
dir.create("my_conjoint_project/data", showWarnings = FALSE)
dir.create("my_conjoint_project/output", showWarnings = FALSE)
```

### Step 3.2: Define Your Study

**Our coffee shop study will test:**

| Attribute | Levels |
|-----------|--------|
| **Price** | $3.00, $4.00, $5.00 |
| **Coffee_Type** | Regular, Specialty, Premium |
| **Size** | Small, Medium, Large |
| **Location** | Downtown, Suburban, Mall |

### Step 3.3: Create Configuration File

**Option A: Use Python (if you have it)**

Create file `my_conjoint_project/create_config.py`:

```python
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill

wb = Workbook()
wb.remove(wb.active)

# Settings sheet
ws_settings = wb.create_sheet("Settings")
settings_data = [
    ["Setting", "Value", "Description"],
    ["analysis_type", "choice", "Choice-based conjoint"],
    ["estimation_method", "auto", "Auto-select best method"],
    ["baseline_handling", "first_level_zero", "First level as reference"],
    ["choice_type", "single", "Single choice per set"],
    ["data_file", "data/coffee_data.csv", "Path to data"],
    ["output_file", "output/coffee_results.xlsx", "Path to results"],
    ["respondent_id_column", "resp_id", "Respondent ID column"],
    ["choice_set_column", "choice_set_id", "Choice set ID column"],
    ["chosen_column", "chosen", "Chosen indicator column"],
    ["confidence_level", "0.95", "95% confidence intervals"],
    ["generate_market_simulator", "TRUE", "Create simulator"],
]

for row_idx, row_data in enumerate(settings_data, start=1):
    for col_idx, value in enumerate(row_data, start=1):
        cell = ws_settings.cell(row=row_idx, column=col_idx, value=value)
        if row_idx == 1:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill(start_color="4F81BD", end_color="4F81BD", fill_type="solid")

# Attributes sheet
ws_attributes = wb.create_sheet("Attributes")
attributes_data = [
    ["AttributeName", "AttributeLabel", "NumLevels", "Level1", "Level2", "Level3", "Level4"],
    ["Price", "Price", 3, "$3.00", "$4.00", "$5.00", None],
    ["Coffee_Type", "Coffee Type", 3, "Regular", "Specialty", "Premium", None],
    ["Size", "Size", 3, "Small", "Medium", "Large", None],
    ["Location", "Location", 3, "Downtown", "Suburban", "Mall", None],
]

for row_idx, row_data in enumerate(attributes_data, start=1):
    for col_idx, value in enumerate(row_data, start=1):
        cell = ws_attributes.cell(row=row_idx, column=col_idx, value=value)
        if row_idx == 1:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill(start_color="4F81BD", end_color="4F81BD", fill_type="solid")

wb.save("my_conjoint_project/coffee_config.xlsx")
print("✓ Configuration file created!")
```

Run: `python3 my_conjoint_project/create_config.py`

**Option B: Use Excel Manually**

1. Open Excel
2. Create new workbook
3. Rename Sheet1 to "Settings"
4. Enter the settings table shown above
5. Add Sheet2, rename to "Attributes"
6. Enter the attributes table shown above
7. Save as: `my_conjoint_project/coffee_config.xlsx`

✅ **Checkpoint:** Configuration file created

### Step 3.4: Create Sample Data

**Use Python to create realistic sample data:**

Create file `my_conjoint_project/create_data.py`:

```python
import pandas as pd
import numpy as np
import random

random.seed(42)
np.random.seed(42)

# Define attribute levels
attributes = {
    'Price': ['$3.00', '$4.00', '$5.00'],
    'Coffee_Type': ['Regular', 'Specialty', 'Premium'],
    'Size': ['Small', 'Medium', 'Large'],
    'Location': ['Downtown', 'Suburban', 'Mall']
}

# True utilities (will drive choices)
true_utilities = {
    'Price': {'$3.00': 1.0, '$4.00': 0.0, '$5.00': -1.0},
    'Coffee_Type': {'Regular': -0.5, 'Specialty': 0.5, 'Premium': 0.0},
    'Size': {'Small': -0.3, 'Medium': 0.3, 'Large': 0.0},
    'Location': {'Downtown': 0.4, 'Suburban': -0.2, 'Mall': -0.2}
}

# Study design
n_respondents = 100
n_choice_sets_per_respondent = 10
n_alternatives_per_set = 3

# Generate data
data_rows = []
choice_set_counter = 0

for resp_id in range(1, n_respondents + 1):
    for cs in range(1, n_choice_sets_per_respondent + 1):
        choice_set_counter += 1

        # Generate alternatives
        alternatives = []
        for alt in range(1, n_alternatives_per_set + 1):
            profile = {
                attr: random.choice(levels)
                for attr, levels in attributes.items()
            }

            # Calculate utility
            utility = sum(true_utilities[attr][profile[attr]]
                         for attr in profile.keys())
            utility += np.random.gumbel(0, 1)  # Random error

            alternatives.append({
                'resp_id': resp_id,
                'choice_set_id': choice_set_counter,
                'alternative_id': alt,
                **profile,
                'utility': utility
            })

        # Determine chosen (highest utility)
        chosen_idx = max(range(len(alternatives)),
                        key=lambda i: alternatives[i]['utility'])

        # Create data rows
        for idx, alt in enumerate(alternatives):
            data_rows.append({
                'resp_id': alt['resp_id'],
                'choice_set_id': alt['choice_set_id'],
                'alternative_id': alt['alternative_id'],
                'Price': alt['Price'],
                'Coffee_Type': alt['Coffee_Type'],
                'Size': alt['Size'],
                'Location': alt['Location'],
                'chosen': 1 if idx == chosen_idx else 0
            })

# Create DataFrame
df = pd.DataFrame(data_rows)

# Verify
print(f"✓ Generated {len(df)} rows of data")
print(f"  - {n_respondents} respondents")
print(f"  - {choice_set_counter} choice sets")
print(f"  - {df['chosen'].sum()} choices")

# Check validation
choices_per_set = df.groupby('choice_set_id')['chosen'].sum()
if (choices_per_set == 1).all():
    print("  ✓ Validation passed: exactly one chosen per choice set")

# Save
df.to_csv("my_conjoint_project/data/coffee_data.csv", index=False)
print("✓ Data saved to: my_conjoint_project/data/coffee_data.csv")

# Show sample
print("\nFirst few rows:")
print(df.head(12))
```

Run: `python3 my_conjoint_project/create_data.py`

✅ **Checkpoint:** Sample data file created with 3,000 rows

---

## Part 4: Run Your Analysis (5 minutes)

### Step 4.1: Load Modules (if not already loaded)

```r
# If you closed R, reload modules
setwd("/home/user/Turas")

source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/05_simulator.R")
source("modules/conjoint/R/08_market_simulator.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")
```

### Step 4.2: Run Your Coffee Shop Analysis

```r
# Run analysis
coffee_results <- run_conjoint_analysis(
  config_file = "my_conjoint_project/coffee_config.xlsx",
  verbose = TRUE
)
```

**Watch the progress:**
```
================================================================================
TURAS CONJOINT ANALYSIS - Enhanced Version 2.0
================================================================================

1. Loading configuration...
2. Loading and validating data...
3. Estimating choice model...
4. Calculating part-worth utilities...
5. Calculating attribute importance...
6. Running model diagnostics...
7. Generating Excel output...

================================================================================
ANALYSIS COMPLETE
================================================================================
```

### Step 4.3: View Your Results

```r
# Attribute importance
print(coffee_results$importance)

# Part-worth utilities
print(coffee_results$utilities)

# Model fit
print(coffee_results$diagnostics$fit_statistics)
```

**Expected results:**
- Price should be most important (~40-50%)
- Utilities should match the true values we used to generate data
- McFadden R² should be around 0.20-0.35 (good fit)

✅ **Checkpoint:** Coffee shop analysis completed successfully

---

## Part 5: Interpret Your Results (10 minutes)

### Step 5.1: Open Excel Output

Navigate to: `my_conjoint_project/output/coffee_results.xlsx`

### Step 5.2: Executive Summary

**Look at:**
- Sample size: 100 respondents, 1,000 choice sets
- Top attributes: Price, Location, Coffee_Type, Size
- Model quality: Should show "Good" or "Excellent"

### Step 5.3: Attribute Importance

**Examine the table:**

```
Rank | Attribute    | Importance | Interpretation
-----|--------------|------------|----------------------------------
1    | Price        | 45.2%      | Price is the most important factor
2    | Location     | 22.3%      | Location is a very important factor
3    | Coffee_Type  | 18.1%      | Coffee Type notably influences choice
4    | Size         | 14.4%      | Size moderately influences choice
```

**What this means:**
- Price matters almost 2x more than Location
- Price matters 3x more than Size
- Together, these 4 attributes explain choice behavior

### Step 5.4: Part-Worth Utilities

**Look at Price utilities:**

```
Attribute | Level  | Utility | Std Error | CI Lower | CI Upper | P-value | Sig
----------|--------|---------|-----------|----------|----------|---------|----
Price     | $3.00  |  0.98   |   0.07    |   0.84   |   1.12   | <0.001  | ***
Price     | $4.00  | -0.02   |   0.07    |  -0.16   |   0.12   | 0.776   | ns
Price     | $5.00  | -0.96   |   0.08    |  -1.12   |  -0.80   | <0.001  | ***
```

**Interpretation:**
- **$3.00**: Utility = +0.98 → Strongly preferred
- **$4.00**: Utility = -0.02 → Neutral (close to zero)
- **$5.00**: Utility = -0.96 → Strongly avoided
- All differences are significant (*** = p<0.001)

**This makes sense!** Lower prices are preferred.

**Look at Coffee_Type utilities:**

```
Coffee_Type | Level     | Utility | Interpretation
------------|-----------|---------|-------------------
            | Regular   | -0.48   | Somewhat avoided
            | Specialty |  0.51   | Moderately preferred
            | Premium   | -0.03   | Neutral
```

**Interpretation:**
- Customers prefer Specialty coffee over Regular
- Premium is in the middle (neutral)

### Step 5.5: Model Diagnostics

**Check these metrics:**

```
McFadden R²: 0.28 (Good)
Hit Rate: 51.2% (chance = 33.3%)
Convergence: Yes
```

**What this means:**
- **R² = 0.28**: Good fit for a choice model (0.2-0.4 is typical)
- **Hit Rate = 51.2%**: Model predicts correctly 51% of the time (vs. 33% by chance)
- **Convergence = Yes**: Model estimation successful

✅ **Checkpoint:** Results interpreted correctly

---

## Part 6: Use the Market Simulator (10 minutes)

### Step 6.1: Open Market Simulator Sheet

In Excel, go to the **"Market Simulator"** sheet.

### Step 6.2: Configure Competing Coffee Shops

**Product 1: Your Current Shop**
- Price: $4.00
- Coffee_Type: Specialty
- Size: Medium
- Location: Downtown

**Product 2: Budget Competitor**
- Price: $3.00
- Coffee_Type: Regular
- Size: Small
- Location: Suburban

**Product 3: Premium Competitor**
- Price: $5.00
- Coffee_Type: Premium
- Size: Large
- Location: Mall

### Step 6.3: View Market Shares

**You should see shares like:**
```
Product 1: 48.2%
Product 2: 38.7%
Product 3: 13.1%
```

**Interpretation:**
- Your shop (Product 1) has largest share
- Budget competitor is competitive
- Premium competitor has smallest share

### Step 6.4: Test What-If Scenarios

**Scenario 1: Lower Your Price**
- Change Product 1 Price to $3.00
- Watch share increase to ~55-60%

**Scenario 2: Upgrade to Premium**
- Change Product 1 Coffee_Type to Premium
- Keep price at $4.00
- Share might drop slightly (Premium isn't preferred over Specialty)

**Scenario 3: Competitor Response**
- Reset Product 1 to original
- Change Product 2 Coffee_Type to Specialty (matching yours)
- Product 2 share should increase (better coffee at lower price)

### Step 6.5: Find Optimal Configuration

**Goal:** Maximize your share against competitors

**Test combinations:**
1. $3.00 + Specialty + Medium + Downtown = ?% share
2. $4.00 + Specialty + Large + Downtown = ?% share
3. $3.00 + Premium + Medium + Suburban = ?% share

**Find the winner!**

The optimal configuration balances:
- Low price (most important)
- Good location (second most important)
- Preferred coffee type
- Preferred size

✅ **Checkpoint:** Market simulator used successfully

---

## Part 7: Advanced Analysis (Optional - 5 minutes)

### Step 7.1: Test Sensitivity Analysis

**Question:** How sensitive is market share to price changes?

**In R:**
```r
# Load simulator functions
source("modules/conjoint/R/05_simulator.R")

# Define your current product
my_shop <- list(
  Price = "$4.00",
  Coffee_Type = "Specialty",
  Size = "Medium",
  Location = "Downtown"
)

# Define competitors
competitors <- list(
  list(Price = "$3.00", Coffee_Type = "Regular",
       Size = "Small", Location = "Suburban"),
  list(Price = "$5.00", Coffee_Type = "Premium",
       Size = "Large", Location = "Mall")
)

# Test price sensitivity
price_sensitivity <- sensitivity_one_way(
  base_product = my_shop,
  attribute = "Price",
  all_levels = c("$3.00", "$4.00", "$5.00"),
  utilities = coffee_results$utilities,
  other_products = competitors,
  method = "logit"
)

print(price_sensitivity)
```

**Results show:**
```
Level  | Share_Percent | Share_Change | Is_Current
-------|---------------|--------------|------------
$3.00  | 55.2%         | +7.0%        | FALSE
$4.00  | 48.2%         | 0.0%         | TRUE
$5.00  | 35.1%         | -13.1%       | FALSE
```

**Interpretation:**
- Lowering price to $3.00 increases share by 7 percentage points
- Raising price to $5.00 decreases share by 13 percentage points
- Price elasticity is asymmetric (bigger loss from increase than gain from decrease)

### Step 7.2: Compare Multiple Scenarios

```r
# Define scenarios
scenarios <- list(
  "Current" = list(my_shop, competitors[[1]], competitors[[2]]),
  "Price_Drop" = list(
    list(Price = "$3.00", Coffee_Type = "Specialty",
         Size = "Medium", Location = "Downtown"),
    competitors[[1]],
    competitors[[2]]
  ),
  "Go_Premium" = list(
    list(Price = "$4.00", Coffee_Type = "Premium",
         Size = "Large", Location = "Downtown"),
    competitors[[1]],
    competitors[[2]]
  )
)

# Compare
scenario_results <- compare_scenarios(
  scenarios = scenarios,
  utilities = coffee_results$utilities,
  method = "logit"
)

print(scenario_results)
```

**Results show which strategy works best.**

✅ **Checkpoint:** Advanced analysis completed

---

## Part 8: Save and Document (5 minutes)

### Step 8.1: Save Your R Workspace

```r
# Save all results for later
save(coffee_results,
     file = "my_conjoint_project/coffee_analysis.RData")

# Later, you can reload with:
# load("my_conjoint_project/coffee_analysis.RData")
```

### Step 8.2: Export Key Results

```r
# Export importance to CSV
write.csv(coffee_results$importance,
          "my_conjoint_project/output/importance.csv",
          row.names = FALSE)

# Export utilities to CSV
write.csv(coffee_results$utilities,
          "my_conjoint_project/output/utilities.csv",
          row.names = FALSE)
```

### Step 8.3: Create Analysis Summary

Create file: `my_conjoint_project/ANALYSIS_SUMMARY.txt`

```
COFFEE SHOP CONJOINT ANALYSIS
Date: 2025-11-27
Analyst: [Your Name]

STUDY DESIGN:
- 100 respondents
- 10 choice sets per respondent
- 3 alternatives per choice set
- 4 attributes tested

KEY FINDINGS:
1. Price is most important (45% importance)
2. Location is second most important (22%)
3. Customers prefer:
   - Lower prices ($3.00 best)
   - Specialty coffee
   - Medium size
   - Downtown location

MODEL QUALITY:
- McFadden R²: 0.28 (Good)
- Hit rate: 51.2% (vs 33% chance)
- All attributes significant

RECOMMENDATIONS:
1. Price point: $3.00-$4.00 optimal range
2. Focus on Specialty coffee offerings
3. Prioritize Downtown location
4. Medium size is preferred

MARKET SIMULATION:
- Current config: 48% market share
- With $3.00 price: 55% share (+7%)
- With $5.00 price: 35% share (-13%)

FILES:
- Config: coffee_config.xlsx
- Data: data/coffee_data.csv
- Results: output/coffee_results.xlsx
- R workspace: coffee_analysis.RData
```

✅ **Checkpoint:** Analysis documented and saved

---

## Summary: What You've Accomplished

🎉 **Congratulations!** You've completed a full conjoint analysis from start to finish.

**You now know how to:**

✅ Set up R environment with required packages
✅ Create configuration files for your studies
✅ Prepare data in the correct format
✅ Run conjoint analysis with the Turas module
✅ Interpret part-worth utilities and attribute importance
✅ Use the interactive market simulator
✅ Test what-if scenarios and sensitivity analysis
✅ Document and save your results

---

## Next Steps

### For Your Own Studies

1. **Define your research question**
   - What product/service are you studying?
   - What attributes matter to customers?

2. **Design your study**
   - Choose 4-6 attributes
   - Define 3-4 levels per attribute
   - Plan 8-12 choice sets per respondent

3. **Collect data**
   - Use survey platform (Qualtrics, Alchemer, etc.)
   - Export in correct format
   - Clean data (remove speeders, attention check failures)

4. **Create config file**
   - Use `example_config.xlsx` as template
   - Modify for your attributes and levels

5. **Run analysis**
   - Follow this tutorial
   - Check validation messages
   - Review model diagnostics

6. **Interpret and act**
   - Focus on importance first
   - Use utilities to understand preferences
   - Test scenarios in market simulator
   - Make data-driven decisions

### Additional Resources

- **User Manual**: `modules/conjoint/USER_MANUAL.md` - Comprehensive reference
- **Quick Start**: `modules/conjoint/examples/QUICK_START_GUIDE.md` - Quick reference
- **Specifications**: `modules/conjoint/Part*.md` - Technical details
- **Test Scripts**: `modules/conjoint/tests/` - Example code
- **Implementation Status**: `modules/conjoint/IMPLEMENTATION_STATUS.md` - Feature list

### Getting Help

- Review validation messages (they tell you what's wrong)
- Check the Troubleshooting section in USER_MANUAL.md
- Run the example analysis to verify setup
- Examine the specification files for technical details

---

## Quick Reference

**Load modules:**
```r
setwd("/path/to/Turas")
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/05_simulator.R")
source("modules/conjoint/R/08_market_simulator.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")
```

**Run analysis:**
```r
results <- run_conjoint_analysis(config_file = "your_config.xlsx")
```

**View results:**
```r
print(results$importance)
print(results$utilities)
print(results$diagnostics$fit_statistics)
```

**Use market simulator:**
- Open Excel output
- Go to "Market Simulator" sheet
- Use dropdown menus to configure products
- Watch shares update automatically

---

**End of Tutorial**

*You're now ready to run professional conjoint analyses!*

*For detailed reference information, see USER_MANUAL.md*
