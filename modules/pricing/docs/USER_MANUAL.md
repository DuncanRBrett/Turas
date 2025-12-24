# Turas Pricing Module - User Manual

**Version:** 11.0
**Last Updated:** December 2025

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Installation](#2-installation)
3. [Van Westendorp Analysis](#3-van-westendorp-analysis)
4. [Gabor-Granger Analysis](#4-gabor-granger-analysis)
5. [Configuration Reference](#5-configuration-reference)
6. [Understanding Output](#6-understanding-output)
7. [Advanced Features](#7-advanced-features)
8. [Troubleshooting](#8-troubleshooting)
9. [Best Practices](#9-best-practices)

---

## 1. Quick Start

### 1.1 Installation

```r
# Required packages
install.packages(c("shiny", "readxl", "openxlsx", "ggplot2"))

# Optional for NMS extension
install.packages("pricesensitivitymeter")
```

### 1.2 Launch GUI

From Turas launcher → Pricing → Launch GUI

Or from R:
```r
source("modules/pricing/run_pricing_gui.R")
run_pricing_gui()
```

### 1.3 Try a Test Project

**Option A: Consumer Electronics Example**
1. File → `examples/pricing/basic/pricing_config.xlsx`
2. Data automatically loaded
3. Click "Run Analysis"
4. View results in tabs

### 1.4 Create Your Own Config

1. Click "Create Config Template"
2. Select method: `van_westendorp`, `gabor_granger`, or `both`
3. Save as `my_config.xlsx`
4. Edit in Excel:
   - Set `data_file` path
   - Map column names
   - Configure options
5. Load and run

---

## 2. Installation

### 2.1 System Requirements

- R version 4.0 or higher
- Excel for editing configuration files
- Minimum 4GB RAM recommended

### 2.2 Package Dependencies

**Required:**
- `readxl` - Excel file reading
- `openxlsx` - Excel file writing
- `ggplot2` - Visualizations

**Optional:**
- `pricesensitivitymeter` - For NMS extension
- `haven` - SPSS/Stata file support

Install all at once:
```r
install.packages(c("readxl", "openxlsx", "ggplot2", "pricesensitivitymeter", "haven"))
```

---

## 3. Van Westendorp Analysis

### 3.1 What is Van Westendorp PSM?

Van Westendorp Price Sensitivity Meter uses four price perception questions to identify acceptable price ranges:

**The Four Questions:**
1. **Too Cheap**: "At what price would you consider this product too cheap, such that you'd question its quality?"
2. **Bargain**: "At what price would you consider this product a bargain?"
3. **Getting Expensive**: "At what price would you consider this product getting expensive, but you might still consider buying it?"
4. **Too Expensive**: "At what price would you consider this product too expensive that you wouldn't consider buying it?"

**Key Price Points:**
- **PMC** (Point of Marginal Cheapness): Below this, quality concerns arise
- **OPP** (Optimal Price Point): Minimizes resistance
- **IDP** (Indifference Price Point): Equal numbers find it cheap vs expensive
- **PME** (Point of Marginal Expensiveness): Above this, too expensive for most

**Acceptable Range**: PMC to PME
**Optimal Range**: OPP to IDP

### 3.2 Data Requirements

Your data file must contain:
- Respondent ID column
- Four price columns (numeric values)
- Optional: weight column, segment variables

**Example Data Structure:**
```
respondent_id | too_cheap | bargain | expensive | too_expensive | weight
1001          | 80        | 120     | 180       | 250           | 1.0
1002          | 90        | 140     | 200       | 300           | 1.2
```

### 3.3 Configuration (VanWestendorp Sheet)

| Setting | Required | Description | Example |
|---------|----------|-------------|---------|
| col_too_cheap | YES | Column for "too cheap" question | `vw_too_cheap` |
| col_cheap | YES | Column for "bargain" question | `vw_bargain` |
| col_expensive | YES | Column for "expensive" question | `vw_expensive` |
| col_too_expensive | YES | Column for "too expensive" question | `vw_too_expensive` |
| validate_monotonicity | YES | Check price logic | `TRUE` |
| calculate_confidence | NO | Bootstrap CIs | `TRUE/FALSE` |

### 3.4 Results Interpretation

**Example Output:**
```
PMC: $52.30    ← Lower bound of acceptable range
OPP: $74.50    ← Optimal price (minimal resistance)
IDP: $89.20    ← Indifference point
PME: $118.40   ← Upper bound of acceptable range
```

**Recommendation**: Price between OPP ($74.50) and IDP ($89.20) for optimal positioning.

**Zones:**
- Below PMC ($52): Risk of quality perception issues
- PMC to OPP ($52-$75): Acceptable but potentially underpriced
- OPP to IDP ($75-$89): **Optimal zone**
- IDP to PME ($89-$118): Acceptable but increasing resistance
- Above PME ($118): Too expensive for most customers

---

## 4. Gabor-Granger Analysis

### 4.1 What is Gabor-Granger?

Gabor-Granger measures purchase intent at different price points to:
- Build a demand curve
- Find revenue-maximizing price
- Find profit-maximizing price (if cost provided)
- Calculate price elasticity

**Approach**: Respondents see multiple prices and indicate whether they would purchase at each price.

### 4.2 Data Requirements

**Wide Format (Recommended):**
```
respondent_id | price_25 | price_30 | price_35 | price_40 | price_45 | weight
1001          | 1        | 1        | 1        | 0        | 0        | 1.0
1002          | 1        | 1        | 0        | 0        | 0        | 1.2
```

**Long Format:**
```
respondent_id | price | purchase_intent | weight
1001          | 25    | 1               | 1.0
1001          | 30    | 1               | 1.0
1001          | 35    | 1               | 1.0
```

### 4.3 Configuration (GaborGranger Sheet)

| Setting | Required | Description | Example |
|---------|----------|-------------|---------|
| data_format | YES | `wide` or `long` | `wide` |
| price_sequence | YES | Prices tested | `25,30,35,40,45,50` |
| response_columns | YES (wide) | Purchase intent columns | `gg_25,gg_30,gg_35,gg_40,gg_45,gg_50` |
| response_type | YES | `binary`, `scale`, `auto` | `binary` |
| revenue_optimization | YES | Find optimal price | `TRUE` |

### 4.4 Results Interpretation

**Example Output:**
```
Revenue-Maximizing Price: $35.00
- Purchase Intent: 66.5%
- Revenue Index: $23.28
- Elasticity: -1.45 (elastic)

Profit-Maximizing Price: $40.00 (if unit_cost = $18)
- Purchase Intent: 55.3%
- Profit per Unit: $22.00
- Profit Index: $12.17
```

**Decision Guide:**
- **Revenue-Max**: Best for market share strategy
- **Profit-Max**: Best for profitability strategy (typically $3-7 higher)

---

## 5. Configuration Reference

### 5.1 Settings Sheet (Global)

| Setting | Required | Description | Values | Example |
|---------|----------|-------------|--------|---------|
| project_name | YES | Project name | Text | `Q4_Product_Pricing` |
| analysis_method | YES | Method(s) to run | `van_westendorp`, `gabor_granger`, `both` | `both` |
| data_file | YES | Survey data path | File path | `data/survey.csv` |
| output_file | YES | Results path | File path | `results/pricing_results.xlsx` |
| currency_symbol | YES | Currency | Symbol | `$` |
| id_var | YES | Respondent ID column | Column name | `ResponseID` |
| weight_var | NO | Weight column | Column name or blank | `weight` |
| dk_codes | NO | "Don't Know" codes | Comma-separated | `98,99` |
| unit_cost | NO | Cost per unit | Number | `18.50` |

### 5.2 Monotonicity Handling

**Van Westendorp** (`vw_monotonicity_behavior`):
- `flag_only`: Report violations, keep all data (recommended)
- `drop`: Remove respondents with violations
- `fix`: Automatically sort prices (risky)

**Gabor-Granger** (`gg_monotonicity_behavior`):
- `smooth`: Apply isotonic regression (recommended)
- `diagnostic_only`: Report only, no correction
- `none`: No checking

### 5.3 Validation Settings

Configure data quality checks:
- `min_completeness`: Minimum % of questions answered (e.g., `0.75`)
- `min_price` / `max_price`: Valid price range
- `flag_outliers`: Enable outlier detection
- `outlier_method`: `iqr`, `zscore`, or `percentile`

---

## 6. Understanding Output

### 6.1 Excel Workbook Structure

The results workbook contains multiple sheets:

| Sheet | Content |
|-------|---------|
| Summary | Project overview and key results |
| VW_Price_Points | Van Westendorp key prices |
| VW_Curves | Cumulative distribution data |
| VW_NMS_Results | NMS extension results (if applicable) |
| GG_Demand_Curve | Purchase intent by price |
| GG_Revenue_Curve | Revenue optimization data |
| GG_Profit_Curve | Profit optimization (if cost provided) |
| Segment_Comparison | Segment-level results |
| Price_Ladder | Good/Better/Best tiers |
| Recommendation | Synthesized recommendation |
| Executive_Summary | Formatted text report |
| Validation | Data quality diagnostics |
| Configuration | Settings used |

### 6.2 Van Westendorp Output

**VW_Price_Points Sheet:**
```
Price_Point | Value  | Interpretation
PMC         | $52.30 | Marginal Cheapness
OPP         | $74.50 | Optimal Price
IDP         | $89.20 | Indifference Point
PME         | $118.40| Marginal Expensiveness
```

**Recommendation**: Price in optimal zone ($74.50 - $89.20)

### 6.3 Gabor-Granger Output

**GG_Demand_Curve Sheet:**
```
Price | Purchase_Intent | Revenue_Index | Elasticity
$25   | 85.2%          | $21.30        | -
$30   | 76.8%          | $23.04        | -1.62
$35   | 66.5%          | $23.28        | -1.45 ⭐ Revenue-Max
$40   | 55.3%          | $22.12        | -1.38
$45   | 43.7%          | $19.67        | -1.52
```

### 6.4 Charts

**Generated PNG Files:**
- `vw_psm_plot.png` - Van Westendorp curves with intersections
- `gg_demand_curve.png` - Purchase intent vs price
- `gg_revenue_curve.png` - Revenue optimization
- `gg_profit_curve.png` - Profit optimization (if applicable)
- `segment_comparison.png` - Segment-level analysis

---

## 7. Advanced Features

### 7.1 NMS Extension (Newton-Miller-Smith)

Enhances Van Westendorp with behavioral calibration.

**Additional Questions:**
- "At your bargain price, how likely would you be to purchase?" (0-100%)
- "At your expensive price, how likely would you be to purchase?" (0-100%)

**Configuration:**
```
col_pi_cheap = "pi_bargain"
col_pi_expensive = "pi_expensive"
```

**Output**: Revenue-optimal price based on actual purchase likelihood.

### 7.2 Segment Analysis

Run pricing analysis across customer segments.

**Configuration (Settings Sheet):**
```
segment_vars = "age_group,income_bracket"
min_segment_n = 50
```

**Output**: Separate price points for each segment, enabling:
- Tiered pricing strategies
- Segment-specific offers
- Price sensitivity comparison

### 7.3 Price Ladder Builder

Automatically generates Good/Better/Best pricing tiers.

**Configuration (Settings Sheet):**
```
n_tiers = 3
tier_names = "Value;Standard;Premium"
min_gap_pct = 15
max_gap_pct = 50
round_to = 0.99
anchor = "Standard"
```

**Output**: Price_Ladder sheet with:
- Tier names and recommended prices
- Gap percentages between tiers
- Purchase intent estimates
- Revenue projections

### 7.4 Recommendation Synthesis

Combines all analyses into executive summary.

**Factors Considered:**
1. Method agreement (Van Westendorp, Gabor-Granger, NMS)
2. Sample size adequacy
3. Data quality
4. Zone fit
5. Method coverage

**Output**:
- Recommended price with confidence level (HIGH/MEDIUM/LOW)
- Supporting evidence
- Risk assessment
- Executive narrative

---

## 8. Troubleshooting

### 8.1 Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "File not found" | Invalid path | Use absolute paths |
| "Column not found" | Name mismatch | Check column names (case-sensitive) |
| "Too many exclusions" | High violation rate | Use `flag_only` monotonicity |
| "Package 'pricesensitivitymeter' required" | NMS not installed | `install.packages("pricesensitivitymeter")` |
| "All 100% or 0%" | Price range too narrow | Expand tested price range |

### 8.2 Data Quality Issues

| Warning | Meaning | Action |
|---------|---------|--------|
| "X% monotonicity violations" | Illogical price order | Normal if < 15%; review if higher |
| "Non-monotonic demand" | Purchase intent increases with price | Use `smooth` mode |
| "Segment n < 50" | Small segment | Combine segments or lower threshold |
| "High exclusion rate" | Many incomplete responses | Review data collection |

### 8.3 Interpretation Issues

**Issue**: Van Westendorp curves don't intersect clearly
**Solution**: May indicate poorly defined market; consider price bundling or segmentation

**Issue**: Gabor-Granger revenue curve is flat
**Solution**: Prices too similar; test wider range in next study

**Issue**: Methods give different recommendations
**Solution**: Normal! Van Westendorp shows *range*, Gabor-Granger shows *specific price*

---

## 9. Best Practices

### 9.1 Study Design

**Sample Size:**
- Minimum 100 respondents for basic analysis
- 300+ for segment analysis
- 500+ for complex segmentation or small niches

**Price Range:**
- Van Westendorp: Let respondents answer freely (don't constrain)
- Gabor-Granger: Test 5-7 price points spanning 50-200% of expected price

**Question Design:**
- Van Westendorp: Use exact wording from methodology
- Gabor-Granger: Clear "Would you buy at $X?" questions
- Both: Randomize order to reduce bias

### 9.2 Data Collection

**Survey Flow:**
1. Van Westendorp questions first (open-ended)
2. Gabor-Granger questions second (build on awareness)
3. Demographics last

**Quality Checks:**
- Include attention checks
- Monitor completion time (< 1 min suggests speeding)
- Soft launch to test (n=50)

### 9.3 Configuration

**General:**
- Always set `validate_monotonicity = TRUE`
- Use `flag_only` for monotonicity (preserves sample)
- Enable bootstrap CIs for final analysis (not exploration)

**Gabor-Granger Specific:**
- Use `smooth` monotonicity for clean curves
- Set `unit_cost` if known (enables profit analysis)
- Test price sequence: lowest to highest

### 9.4 Analysis

**Validation:**
- Review data quality metrics in Validation sheet
- Check exclusion rates (should be < 15%)
- Verify segment sizes adequate

**Interpretation:**
- Van Westendorp: Focus on optimal zone (OPP to IDP)
- Gabor-Granger: Compare revenue-max vs profit-max
- Both: Ensure Gabor-Granger optimal falls within Van Westendorp range

**Reporting:**
- Use rescaled scores for client presentations
- Show both price ranges and specific recommendations
- Include confidence assessment from synthesis

---

## 10. Example Data Files

### Van Westendorp Example

**File**: `examples/pricing/van_westendorp_sample.csv`

```
ResponseID,too_cheap,bargain,expensive,too_expensive,age_group,weight
1001,80,120,180,250,18-34,1.0
1002,90,140,200,300,35-54,1.2
1003,70,110,170,240,55+,0.9
```

### Gabor-Granger Example

**File**: `examples/pricing/gabor_granger_sample.csv`

```
ResponseID,gg_25,gg_30,gg_35,gg_40,gg_45,gg_50,weight
1001,1,1,1,0,0,0,1.0
1002,1,1,0,0,0,0,1.2
1003,1,1,1,1,0,0,0.9
```

---

## 11. Template Reference

The configuration template (`Pricing_Config_Template.xlsx`) includes:

1. **Instructions** sheet - Methodology overview
2. **Settings** sheet - Global configuration
3. **VanWestendorp** sheet - Van Westendorp settings
4. **GaborGranger** sheet - Gabor-Granger settings
5. **Validation** sheet - Data quality rules

**Color Coding:**
- **Yellow** = Required setting
- **Green** = Optional (has default)
- **Blue** = Example value

For complete template documentation, see the template file itself.

---

## Appendix: Quick Reference Card

### Van Westendorp Quick Setup
```
1. Map four price columns
2. Set validate_monotonicity = TRUE
3. Set vw_monotonicity_behavior = flag_only
4. Run analysis
5. Interpret optimal zone (OPP to IDP)
```

### Gabor-Granger Quick Setup
```
1. Set data_format = wide
2. List price_sequence (ascending)
3. Map response_columns (matching order)
4. Set revenue_optimization = TRUE
5. Optionally set unit_cost
6. Run analysis
7. Identify revenue-max (or profit-max) price
```

### Both Methods Together
```
1. Set analysis_method = both
2. Configure both VanWestendorp and GaborGranger sheets
3. Run once
4. Use Van Westendorp for acceptable range
5. Use Gabor-Granger for specific price within that range
```

---

*For additional examples and walkthroughs, see [Example Workflows](EXAMPLE_WORKFLOWS.md).*

*For detailed methodology, see [Authoritative Guide](AUTHORITATIVE_GUIDE.md).*

*For developer documentation, see [Technical Reference](TECHNICAL_REFERENCE.md).*
