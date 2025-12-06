# Turas Pricing Module - User Manual

**Version:** 2.0
**Module:** Pricing Analysis (Van Westendorp & Gabor-Granger)
**Last Updated:** December 2025

---

## Table of Contents

1. [Quick Start (5 Minutes)](#quick-start-5-minutes)
2. [Installation](#installation)
3. [Complete Tutorial](#complete-tutorial)
4. [Real-World Examples](#real-world-examples)
5. [Configuration Reference](#configuration-reference)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start (5 Minutes)

### Installation

```r
# Required packages
install.packages(c("shiny", "readxl", "openxlsx", "ggplot2"))
```

### 1. Launch GUI

From Turas launcher → Pricing → Launch GUI

Or from R:
```r
source("modules/pricing/run_pricing_gui.R")
run_pricing_gui()
```

### 2. Try a Test Project

**Option A: Consumer Electronics Example**
1. File → `test_projects/consumer_electronics/config.xlsx`
2. Data automatically loaded
3. Click "Run Analysis"
4. View results in tabs

**Option B: SaaS Subscription Example**
1. File → `test_projects/saas_subscription/config.xlsx`
2. Includes profit optimization
3. Click "Run Analysis"
4. Compare revenue vs profit in "Additional Plots"

### 3. Create Your Own Config

1. Click "Create Config Template"
2. Select method: `van_westendorp` or `gabor_granger`
3. Save as `my_config.xlsx`
4. Edit in Excel:
   - Set `data_file` path
   - Map column names
   - Configure options
5. Load and run

### Key Features Quick Reference

**Phase 1: Data Quality**
- **Weights**: Enter column name in "Weight Variable"
- **DK Codes**: Enter as `98,99` (comma-separated)
- **Monotonicity**: Select behavior from dropdown

**Phase 2: Profit Optimization**
- Enter **Unit Cost** to enable
- View profit-max vs revenue-max prices
- See comparison in "Additional Plots" tab

### Basic Workflow

```
Select Config → Override Settings (optional) → Run Analysis → Review Results
```

### Understanding Results

**Van Westendorp (Price Ranges)**
- **PMC to PME**: Acceptable range
- **OPP to IDP**: Optimal range
- **Recommendation**: Price within optimal range

**Gabor-Granger (Specific Price)**
- **Revenue-Max**: Highest Price × Volume
- **Profit-Max**: Highest (Price-Cost) × Volume
- **Recommendation**: Choose based on strategy

### Common Configurations

**Weighted Analysis:**
```
Weight Variable: survey_weight
```

**Profit Optimization:**
```
Unit Cost: 22.50
```

**Data Quality:**
```
DK Codes: 98,99
VW Monotonicity: flag_only
GG Monotonicity: smooth
```

### Output Files

**Location**: Same folder as config file

**Files Created**:
- `[prefix]_results.xlsx` - Main output with all sheets
- `plots/` folder - PNG visualizations

**Key Excel Sheets**:
- Summary - Overview & sample stats
- VW_Price_Points or GG_Optimal_Revenue - Main results
- GG_Optimal_Profit - If unit cost specified
- Validation - Data quality report

---

## Complete Tutorial

**Goal:** Complete a full pricing analysis from start to finish

**Time:** 30 minutes
**Level:** Beginner to Intermediate
**Project:** SaaS Subscription (Gabor-Granger with Profit Optimization)

### Part 1: Setup (5 minutes)

#### Step 1.1: Generate Test Data

```r
setwd("modules/pricing/test_projects/saas_subscription")
source("generate_data.R")
```

**Expected Output:**
```
✓ Created saas_subscription_data.csv (n=350)
✓ Includes: 7 price points ($25-$55), weights, segments
✓ Unit cost: $18/month
```

#### Step 1.2: Create Configuration

```r
source("create_config.R")
```

**Expected Output:**
```
✓ Created config_saas.xlsx
✓ Includes profit optimization (unit_cost = $18)
```

### Part 2: Launch GUI (5 minutes)

```r
setwd("../../..")
source("modules/pricing/run_pricing_gui.R")
run_pricing_gui()
```

1. Click **"Load Configuration"**
2. Navigate to `config_saas.xlsx`
3. Verify settings loaded

### Part 3: Run Analysis (5 minutes)

1. Click **"Data Preview"** tab - verify 350 rows, 7 price columns
2. Click **"Run Analysis"** button
3. Wait ~10-15 seconds

### Part 4: Interpret Results (10 minutes)

**Demand Curve Tab:**
```
Price   Purchase Rate   Expected Volume
$25     85.2%          298
$30     76.8%          269
$35     66.5%          233
$40     55.3%          194  ⭐
$45     43.7%          153
```

**Revenue Analysis Tab:**
```
Price   Revenue     Rank
$35     $8,155      1 ⭐ Revenue-Max
$40     $7,760      2
```

**Profit Analysis Tab:**
```
Price   Profit      Margin   Rank
$40     $4,268      55.0%    1 ⭐ Profit-Max
$35     $3,961      48.6%    3
```

**Key Finding:** Profit-max price ($40) is $5 higher than revenue-max, yielding $307 more profit (+7.8%)

### Part 5: Export Results (5 minutes)

1. Click **"Download Results"**
2. Review Excel workbook (8 sheets)
3. Share with stakeholders

---

## Real-World Examples

### Example 1: Van Westendorp - Smart Home Device

**Scenario:** New product launch, determine price range

**Data:** 500 consumers, 4 price perception questions

**Results:**
```
PMC: $52.30
OPP: $74.50  ⭐ Optimal
IDP: $89.20
PME: $118.40
```

**Recommendation:**
- Launch price: $79.99 (in optimal range $74.50-$89.20)
- Premium SKU: $99.99 (below PME)
- Avoid: Below $69.99 or above $119.99

---

### Example 2: Gabor-Granger - Subscription Repricing

**Scenario:** Existing SaaS platform, currently $39/month

**Data:** 750 customers, 5 price points

**Results:**
```
Price   Revenue      vs Current ($39)
$29     $19,227      -$6,666 (-26%)
$35     $21,455      -$4,438 (-17%)
$39     $22,308      Baseline ⭐
$45     $22,095      -$213 (-1%)
$49     $19,894      -$2,414 (-11%)
```

**Recommendation:** Keep $39 (revenue-maximizing, minimal risk)

---

### Example 3: Profit Optimization - E-commerce

**Scenario:** Physical product, unit cost = $14

**Results:**
```
Price   Profit      Margin
$29.99  $474,308    53.3%  ⭐ Revenue-Max
$34.99  $511,007    60.0%  ⭐ Profit-Max (+$37K)
```

**Recommendation:** Price at $34.99 (profit-max), use $29.99 for sales

---

### Example 4: Weighted Analysis - B2B SaaS

**Weighting:** Small=1.0, Medium=3.0, Large=10.0

**Results:**
```
Price   Unweighted    Weighted
$1000   58%           52%
$1500   42%           48%  ⭐ Enterprise preference
```

**Recommendation:** Tiered pricing - Enterprise tier at $1500

---

## Configuration Reference

### Van Westendorp Settings

```
method: van_westendorp
col_too_cheap: [column]
col_cheap: [column]
col_expensive: [column]
col_too_expensive: [column]
vw_monotonicity: flag_only|smooth|strict
```

### Gabor-Granger Settings

**Wide Format:**
```
method: gabor_granger
data_format: wide
price_columns: price_25,price_30,...
```

**Long Format:**
```
data_format: long
col_respondent: [ID column]
col_price: [price column]
col_purchase_intent: [0/1 column]
```

### General Settings

```
data_file: [path]
output_file: [path]
weight_var: [column]  (optional)
unit_cost: [value]  (enables profit optimization)
market_size: [value]  (for projections)
dk_codes: 98,99  (exclude values)
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "File not found" | Use absolute paths or co-locate files |
| "Column not found" | Check column names (case-sensitive) |
| "Too many exclusions" | Check DK codes, use vw_monotonicity: flag_only |
| "Monotonicity violation" | Use smooth mode or check data quality |
| Slow analysis | Reduce bootstrap iterations (1000 → 500) |
| "All 100% or 0%" | Expand price range tested |

---

**For technical details:** See `TECHNICAL_DOCS.md`
**For config templates:** See `/docs/Pricing_Config_Template_Manual.md`

**Version:** 2.0 | **Updated:** December 2025
