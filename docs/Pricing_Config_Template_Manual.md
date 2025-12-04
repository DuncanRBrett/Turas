# Pricing Config Template - User Manual

**Template File:** `templates/Pricing_Config_Template.xlsx`
**Version:** 10.0
**Last Updated:** 4 December 2025

---

## Overview

The Pricing Config Template configures pricing research analysis in TURAS. This module supports two primary pricing methodologies:

1. **Van Westendorp PSM (Price Sensitivity Meter)** - Finds acceptable price ranges
2. **Gabor-Granger** - Finds optimal revenue/profit-maximizing price points

**You can run either method alone or both together** for comprehensive pricing insights.

---

## Template Structure

The template contains **6 sheets**:

1. **Instructions** - Methodology overview and comparison
2. **Settings** - Global analysis configuration
3. **VanWestendorp** - Van Westendorp PSM settings
4. **GaborGranger** - Gabor-Granger settings
5. **Validation** - Data validation rules

**Important:** Delete the method sheet you don't use (if only running one method).

---

## Sheet 1: Instructions

**Purpose:** Explains both pricing methodologies and when to use each.

**Action Required:** Review for understanding. Not read by analysis code.

**Van Westendorp PSM:**
- **What:** 4 questions about price perception to find acceptable range
- **Questions:**
  1. At what price is it too cheap (poor quality)?
  2. At what price is it a bargain?
  3. At what price is it getting expensive?
  4. At what price is it too expensive?
- **Output:** Acceptable range (PMC to PME), Optimal range (OPP to IDP)
- **Best for:** Finding acceptable price ranges, understanding price perceptions, early-stage pricing research

**Gabor-Granger:**
- **What:** Shows different price points and asks "Would you buy at this price?" to build demand curve
- **Approach:** Respondent sees 5-7 different prices, answers Yes/No for each
- **Output:** Specific optimal price (revenue-maximizing or profit-maximizing), revenue/profit curves, demand elasticity
- **Best for:** Finding a specific price point, revenue/profit optimization, testing specific price alternatives

**Quick Comparison:**
| Feature | Van Westendorp | Gabor-Granger |
|---------|---------------|---------------|
| Output | Price range | Specific price |
| Questions | 4 open-ended prices | 5-7 buy/don't buy |
| Use when | Exploring acceptable ranges | Need exact optimal price |
| Strategic | Positioning decisions | Revenue maximization |

**Recommendation:** Run both methods in same survey - Van Westendorp for range, Gabor-Granger for specific price within that range.

**Gabor-Granger Data Format:**
Turas uses **monadic approach** - all respondents answer for all price points (wide format data). Each respondent has response at every price level.

---

## Sheet 2: Settings

**Purpose:** Global settings that apply to both methods.

**Required Columns:** 2 columns only (`Setting`, `Value`)

### Field Specifications

#### Setting: project_name

- **Purpose:** Project name for reports
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any text
- **Example:** `Premium Coffee Maker Pricing`

#### Setting: analysis_method

- **Purpose:** Which pricing method(s) to run
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `van_westendorp`, `gabor_granger`, `both`
- **Logic:**
  - `van_westendorp` = Run only Van Westendorp PSM
  - `gabor_granger` = Run only Gabor-Granger
  - `both` = Run both methods
- **Example:** `both`

#### Setting: currency_symbol

- **Purpose:** Currency symbol for display in output
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any currency symbol
- **Example:** `$`, `£`, `€`, `¥`

#### Setting: data_file

- **Purpose:** Path to survey data file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Relative or absolute path to .csv, .xlsx, .sav
- **Example:** `coffee_maker_data.csv` or `../data/survey.xlsx`

#### Setting: id_var

- **Purpose:** Respondent ID column name
- **Required:** YES
- **Data Type:** Text (column name)
- **Valid Values:** Must match column name in data
- **Example:** `respondent_id` or `ResponseID`

#### Setting: weight_var

- **Purpose:** Survey weight column (optional)
- **Required:** NO
- **Data Type:** Text (column name) or blank
- **Valid Values:** Column name or leave blank for unweighted
- **Example:** `survey_weight` or blank

#### Setting: dk_codes

- **Purpose:** "Don't Know" codes to recode as NA
- **Required:** NO
- **Data Type:** Text (comma-separated numbers)
- **Valid Values:** Numeric codes
- **Logic:** These values will be recoded to NA before analysis
- **Example:** `98,99`

#### Setting: unit_cost

- **Purpose:** Cost per unit for profit analysis
- **Required:** NO (only for profit-based optimization)
- **Data Type:** Numeric or blank
- **Valid Values:** Cost value
- **Logic:** Used to calculate profit curve (revenue - cost)
- **Example:** `95` (if product costs $95 to produce)

#### Setting: vw_monotonicity_behavior

- **Purpose:** How to handle Van Westendorp price order violations
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `flag_only`, `drop`, `fix`
- **Logic:**
  - `flag_only` = Reports violations but keeps all data (recommended)
  - `drop` = Removes respondents with price order violations
  - `fix` = Automatically sorts prices to enforce order (risky)
- **Example:** `flag_only`

#### Setting: gg_monotonicity_behavior

- **Purpose:** How to handle Gabor-Granger demand monotonicity
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `smooth`, `diagnostic_only`, `none`
- **Logic:**
  - `smooth` = Applies isotonic regression to enforce decreasing demand (recommended)
  - `diagnostic_only` = Reports violations only, no smoothing
  - `none` = No monotonicity checking
- **Example:** `smooth`

#### Setting: segment_vars

- **Purpose:** Variables for subgroup analysis
- **Required:** NO
- **Data Type:** Text (comma-separated column names)
- **Valid Values:** Column names from data
- **Logic:** Runs separate analysis for each subgroup
- **Example:** `age_group,income_bracket,coffee_consumption`

#### Setting: output_file

- **Purpose:** Output file name with full path
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Path ending in .xlsx
- **Example:** `results/pricing_analysis.xlsx`

---

## Sheet 3: VanWestendorp

**Purpose:** Configure Van Westendorp Price Sensitivity Meter analysis.

**Only required if:** `analysis_method = van_westendorp` or `both`

**Required Columns:** `Setting`, `Value`, `Required`, `Description`

### Field Specifications

#### Setting: col_too_cheap

- **Purpose:** Column for "At what price too cheap/low quality?"
- **Required:** YES
- **Data Type:** Text (column name)
- **Valid Values:** Must match column in data
- **Example:** `vw_too_cheap`

#### Setting: col_cheap

- **Purpose:** Column for "At what price a bargain?"
- **Required:** YES
- **Data Type:** Text (column name)
- **Valid Values:** Must match column in data
- **Example:** `vw_cheap`

#### Setting: col_expensive

- **Purpose:** Column for "At what price getting expensive?"
- **Required:** YES
- **Data Type:** Text (column name)
- **Valid Values:** Must match column in data
- **Example:** `vw_expensive`

#### Setting: col_too_expensive

- **Purpose:** Column for "At what price too expensive?"
- **Required:** YES
- **Data Type:** Text (column name)
- **Valid Values:** Must match column in data
- **Example:** `vw_too_expensive`

#### Setting: validate_monotonicity

- **Purpose:** Check if prices are in logical order
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:** Checks that too_cheap < cheap < expensive < too_expensive
- **Example:** `TRUE`

#### Setting: violation_threshold

- **Purpose:** Triggers warning if violations exceed this percentage
- **Required:** NO
- **Data Type:** Decimal (0-1)
- **Valid Values:** 0 to 1
- **Default:** `0.1` (10%)
- **Example:** `0.1`

#### Setting: interpolation_method

- **Purpose:** Method used in curve calculation
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** `linear`, `spline`
- **Default:** `linear`
- **Example:** `linear`

#### Setting: calculate_confidence

- **Purpose:** Enables bootstrap confidence intervals
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:** Can also use Bootstrap sheet for detailed settings
- **Example:** `FALSE`

#### Setting: confidence_level

- **Purpose:** CI level for bootstrap
- **Required:** Only if calculate_confidence = TRUE
- **Data Type:** Decimal (0-1)
- **Valid Values:** `0.90`, `0.95`, `0.99`
- **Default:** `0.95`
- **Example:** `0.95`

#### Setting: bootstrap_iterations

- **Purpose:** Number of bootstrap samples
- **Required:** Only if calculate_confidence = TRUE
- **Data Type:** Integer
- **Valid Values:** 1000 to 10000
- **Default:** `1000`
- **Example:** `1000`

---

## Sheet 4: GaborGranger

**Purpose:** Configure Gabor-Granger demand curve analysis.

**Only required if:** `analysis_method = gabor_granger` or `both`

**Required Columns:** `Setting`, `Value`, `Required`, `Description`

### Field Specifications

#### Setting: data_format

- **Purpose:** Data structure format
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `wide` or `long`
- **Logic:**
  - `wide` = Each price point has separate column (recommended)
  - `long` = Single price column, single response column
- **Example:** `wide`

#### Setting: price_sequence

- **Purpose:** Price points tested
- **Required:** YES
- **Data Type:** Text (comma or semicolon-separated numbers)
- **Valid Values:** Numeric prices in ascending order
- **Logic:** Must match number of response_columns
- **Example:** `180,200,220,240,260,280`

#### Setting: response_columns

- **Purpose:** Purchase intent columns (wide format)
- **Required:** YES for wide format
- **Data Type:** Text (comma/semicolon-separated column names)
- **Valid Values:** Must match columns in data
- **Logic:**
  - Count must match price_sequence count
  - Order must match price_sequence order
- **Example:** `gg_180,gg_200,gg_220,gg_240,gg_260,gg_280`

#### Setting: response_type

- **Purpose:** How responses are coded
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `binary`, `scale`, `auto`
- **Logic:**
  - `binary` = 1/0 or Yes/No responses
  - `scale` = 1-5 or 1-7 scale (use with scale_threshold)
  - `auto` = Module detects automatically
- **Example:** `binary`

#### Setting: revenue_optimization

- **Purpose:** Find revenue-maximizing price
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Logic:**
  - `TRUE` = Calculate optimal price based on revenue
  - `FALSE` = Just report demand curve
  - If unit_cost specified, also calculates profit-maximizing price
- **Example:** `TRUE`

#### Setting: price_column

- **Purpose:** For long format data
- **Required:** Only if data_format = long
- **Data Type:** Text (column name)
- **Valid Values:** Column name
- **Example:** `price`

#### Setting: response_column

- **Purpose:** For long format data
- **Required:** Only if data_format = long
- **Data Type:** Text (column name)
- **Valid Values:** Column name
- **Example:** `purchase_intent`

#### Setting: respondent_column

- **Purpose:** For long format data
- **Required:** Only if data_format = long
- **Data Type:** Text (column name)
- **Valid Values:** Column name
- **Example:** `respondent_id`

#### Setting: scale_threshold

- **Purpose:** Minimum response value to count as "would purchase"
- **Required:** Only if response_type = scale
- **Data Type:** Numeric
- **Valid Values:** Must be ≤ max of your scale
- **Logic:** For 1-5 scale, 4 means "Top 2 Box" (4 and 5)
- **Example:** `4` (for 1-5 scale top 2 box)

#### Setting: check_monotonicity

- **Purpose:** Checks for monotonic demand
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:** Demand should decrease as price increases
- **Example:** `TRUE`

#### Setting: calculate_elasticity

- **Purpose:** Calculates price elasticity
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Example:** `TRUE`

#### Setting: confidence_intervals

- **Purpose:** Enables bootstrap CIs
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:** Can also use Bootstrap sheet
- **Example:** `FALSE`

#### Setting: bootstrap_iterations

- **Purpose:** Number of bootstrap samples
- **Required:** Only if confidence_intervals = TRUE
- **Data Type:** Integer
- **Valid Values:** 1000 to 10000
- **Default:** `1000`
- **Example:** `1000`

#### Setting: confidence_level

- **Purpose:** CI level
- **Required:** Only if confidence_intervals = TRUE
- **Data Type:** Decimal
- **Valid Values:** `0.90`, `0.95`, `0.99`
- **Default:** `0.95`
- **Example:** `0.95`

---

## Sheet 5: Validation

**Purpose:** Data validation rules to ensure data quality.

**Required Columns:** `Setting`, `Value`, `Required`, `Description`

### Field Specifications

#### Setting: min_completeness

- **Purpose:** Minimum % of price questions answered
- **Required:** YES
- **Data Type:** Decimal (0-1)
- **Valid Values:** 0 to 1
- **Logic:** Respondents below threshold excluded
- **Example:** `0.75` (must answer 75% of price questions)

#### Setting: check_ranges

- **Purpose:** Validate price values are within bounds
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Example:** `TRUE`

#### Setting: min_price

- **Purpose:** Minimum valid price
- **Required:** YES
- **Data Type:** Numeric
- **Valid Values:** Any number
- **Logic:** Values below this flagged as invalid
- **Example:** `0`

#### Setting: max_price

- **Purpose:** Maximum valid price
- **Required:** YES
- **Data Type:** Numeric
- **Valid Values:** Any number
- **Logic:** Values above this flagged as invalid
- **Example:** `600`

#### Setting: flag_outliers

- **Purpose:** Enables outlier detection
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Example:** `TRUE`

#### Setting: outlier_method

- **Purpose:** Outlier detection algorithm
- **Required:** Only if flag_outliers = TRUE
- **Data Type:** Text
- **Valid Values:** `iqr`, `zscore`, `percentile`
- **Default:** `iqr`
- **Example:** `iqr`

#### Setting: outlier_threshold

- **Purpose:** Threshold for outlier flagging
- **Required:** Only if flag_outliers = TRUE
- **Data Type:** Numeric
- **Valid Values:** 1.5 to 5
- **Default:** `3`
- **Example:** `3`

---

## Data Requirements

### Van Westendorp Data Structure

```
respondent_id | vw_too_cheap | vw_cheap | vw_expensive | vw_too_expensive | survey_weight
1001          | 80           | 120      | 180          | 250              | 1.0
1002          | 90           | 140      | 200          | 300              | 1.2
```

### Gabor-Granger Data Structure (Wide Format)

```
respondent_id | gg_180 | gg_200 | gg_220 | gg_240 | gg_260 | gg_280 | survey_weight
1001          | 1      | 1      | 0      | 0      | 0      | 0      | 1.0
1002          | 1      | 1      | 1      | 1      | 0      | 0      | 1.2
```

---

## Common Mistakes

### Mistake 1: Price Columns Don't Match

**Problem:** Error "Column 'vw_cheap' not found"
**Solution:** Check column names match data exactly

### Mistake 2: Price Sequence Mismatch

**Problem:** Error "price_sequence count doesn't match response_columns count"
**Solution:** Must have same number of prices and response columns

### Mistake 3: Invalid Price Order

**Problem:** Warning "X% respondents have invalid price order"
**Solution:** Normal - some respondents give illogical answers. Use vw_monotonicity_behavior to handle

### Mistake 4: Non-Monotonic Demand

**Problem:** Warning "Demand curve not monotonically decreasing"
**Solution:** Use gg_monotonicity_behavior = smooth to fix

---

**End of Pricing Config Template Manual**
