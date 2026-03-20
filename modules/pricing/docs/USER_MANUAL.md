# Turas Pricing Module - User Manual

**Version:** 12.0
**Last Updated:** March 2026

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Installation & Dependencies](#2-installation--dependencies)
3. [Van Westendorp Analysis](#3-van-westendorp-analysis)
4. [Gabor-Granger Analysis](#4-gabor-granger-analysis)
5. [Monadic Price Testing](#5-monadic-price-testing)
6. [Configuration Reference](#6-configuration-reference)
7. [Understanding Output](#7-understanding-output)
8. [HTML Report](#8-html-report)
9. [Interactive Simulator](#9-interactive-simulator)
10. [Added Slides & Images](#10-added-slides--images)
11. [Advanced Features](#11-advanced-features)
12. [Troubleshooting](#12-troubleshooting)
13. [Best Practices](#13-best-practices)
14. [End-to-End Walkthrough](#14-end-to-end-walkthrough)
15. [Known Limitations](#15-known-limitations)
16. [Appendix: Package Versions](#16-appendix-package-versions)

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
2. Select method: `van_westendorp`, `gabor_granger`, `monadic`, or `both`
3. Save as `my_config.xlsx`
4. Edit in Excel:
   - Set `data_file` path
   - Map column names
   - Configure options
5. Load and run

---

## 2. Installation & Dependencies

### 2.1 System Requirements

- R version 4.0 or higher
- Excel for editing configuration files
- Minimum 4GB RAM recommended
- Modern browser for HTML reports (Chrome, Firefox, Safari, Edge)

### 2.2 Package Dependencies

**Required (core functionality):**

| Package | Purpose | Minimum Version |
|---------|---------|-----------------|
| `readxl` | Excel config file reading | 1.4.0 |
| `openxlsx` | Excel results output with formatting | 4.2.5 |
| `stats` | GLM for monadic, statistical functions | (base R) |

**Required (HTML report):**

| Package | Purpose | Minimum Version |
|---------|---------|-----------------|
| `base64enc` | Image embedding in HTML reports | 0.1-3 |
| `jsonlite` | JSON data for simulator | 1.8.0 |

**Optional (enhanced features):**

| Package | Purpose | When Needed |
|---------|---------|-------------|
| `pricesensitivitymeter` | NMS extension for Van Westendorp | When using NMS calibration |
| `haven` | SPSS (.sav) / Stata (.dta) file support | When data is in SPSS/Stata format |
| `survey` | Design-aware weighted analysis | For complex survey designs |

Install all at once:
```r
install.packages(c("readxl", "openxlsx", "base64enc", "jsonlite",
                    "pricesensitivitymeter", "haven"))
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

## 5. Monadic Price Testing

### 5.1 What is Monadic Price Testing?

Monadic (randomised cell) price testing is the gold standard for unbiased price sensitivity measurement. Each respondent is shown ONE randomly assigned price and asked about their purchase intent. Because respondents see only a single price, there are no anchoring or order effects.

**Statistical Method**: Logistic regression models the relationship between price and purchase probability:

```
P(buy) = 1 / (1 + exp(-(β₀ + β₁ × price)))
```

This produces a smooth demand curve that can be used for revenue and profit optimisation.

### 5.2 Data Requirements

Each respondent needs exactly two values:
- **Price shown**: The single price randomly assigned to the respondent
- **Purchase intent**: Binary (yes/no) or scale (e.g. 1-5 Likert)

```
respondent_id | price_shown | purchase_intent
1001          | 35          | 1
1002          | 55          | 0
1003          | 45          | 1
1004          | 25          | 1
1005          | 65          | 0
```

**Sample size**: Minimum 200 respondents recommended. 50+ per price cell for reliable estimates.

### 5.3 Configuration (Monadic Sheet)

| Setting | Required | Description | Example |
|---------|----------|-------------|---------|
| price_column | YES | Column with assigned price | `price_shown` |
| intent_column | YES | Column with purchase intent | `purchase_intent` |
| intent_type | YES | `binary` or `scale` | `binary` |
| scale_threshold | NO | Top-box threshold for scale intent | `4` |
| model_type | NO | `logistic` or `log_logistic` | `logistic` |
| prediction_points | NO | Points on demand curve | `100` |
| confidence_intervals | NO | Enable bootstrap CIs | `TRUE` |
| bootstrap_iterations | NO | Number of bootstrap samples | `1000` |
| confidence_level | NO | CI confidence level | `0.95` |

### 5.4 Results Interpretation

**Example Output:**
```
Model: logistic, pseudo-R²: 0.15, AIC: 250.3
Revenue-Maximizing Price: $42.00
- Purchase Intent: 58.2%
- Revenue Index: $24.44

Profit-Maximizing Price: $48.00 (if unit_cost = $15)
- Purchase Intent: 49.5%
- Profit Index: $16.34
```

**Key Metrics:**
- **Pseudo-R²**: Model fit (0.05-0.20 typical for pricing data)
- **Price coefficient p-value**: Statistical significance of the price effect (< 0.05 desired)
- **AIC**: Model comparison metric (lower = better)
- **Elasticity**: Arc elasticity at sampled price intervals

**Decision Guide:**
- Use monadic when you need unbiased estimates (no anchoring effects)
- Works well for new products where respondents have no price reference
- Combine with Van Westendorp for both range identification and precise optimisation

---

## 6. Configuration Reference

### 6.1 Settings Sheet (Global)

| Setting | Required | Description | Values | Example |
|---------|----------|-------------|--------|---------|
| project_name | YES | Project name | Text | `Q4_Product_Pricing` |
| analysis_method | YES | Method(s) to run | `van_westendorp`, `gabor_granger`, `monadic`, `both` | `both` |
| data_file | YES | Survey data path | File path | `data/survey.csv` |
| output_file | YES | Results path | File path | `results/pricing_results.xlsx` |
| currency_symbol | YES | Currency | Symbol | `$` |
| id_var | YES | Respondent ID column | Column name | `ResponseID` |
| weight_var | NO | Weight column | Column name or blank | `weight` |
| dk_codes | NO | "Don't Know" codes | Comma-separated | `98,99` |
| unit_cost | NO | Cost per unit | Number | `18.50` |
| brand_colour | NO | Brand colour for HTML report | Hex colour | `#1e3a5f` |
| generate_html_report | NO | Generate HTML report | `TRUE`/`FALSE` | `TRUE` |
| generate_simulator | NO | Generate simulator dashboard | `TRUE`/`FALSE` | `TRUE` |

### 6.2 Monotonicity Handling

**Van Westendorp** (`vw_monotonicity_behavior`):
- `flag_only`: Report violations, keep all data (recommended)
- `drop`: Remove respondents with violations
- `fix`: Automatically sort prices (risky)

**Gabor-Granger** (`gg_monotonicity_behavior`):
- `smooth`: Apply isotonic regression (recommended)
- `diagnostic_only`: Report only, no correction
- `none`: No checking

### 6.3 Validation Settings

Configure data quality checks:
- `min_completeness`: Minimum % of questions answered (e.g., `0.75`)
- `min_price` / `max_price`: Valid price range
- `flag_outliers`: Enable outlier detection
- `outlier_method`: `iqr`, `zscore`, or `percentile`

---

## 7. Understanding Output

### 7.1 Excel Workbook Structure

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

### 7.2 Van Westendorp Output

**VW_Price_Points Sheet:**
```
Price_Point | Value  | Interpretation
PMC         | $52.30 | Marginal Cheapness
OPP         | $74.50 | Optimal Price
IDP         | $89.20 | Indifference Point
PME         | $118.40| Marginal Expensiveness
```

**Recommendation**: Price in optimal zone ($74.50 - $89.20)

### 7.3 Gabor-Granger Output

**GG_Demand_Curve Sheet:**
```
Price | Purchase_Intent | Revenue_Index | Elasticity
$25   | 85.2%          | $21.30        | -
$30   | 76.8%          | $23.04        | -1.62
$35   | 66.5%          | $23.28        | -1.45 ⭐ Revenue-Max
$40   | 55.3%          | $22.12        | -1.38
$45   | 43.7%          | $19.67        | -1.52
```

### 7.4 Monadic Output

**Monadic_Model Sheet:**
```
Metric              | Value
Model Type          | logistic
Pseudo-R²           | 0.148
AIC                 | 355.2
Price Coefficient P | 0.0001
N Observations      | 300
```

**Monadic_Demand Sheet:**
```
Price  | Predicted_Intent | Revenue_Index | Profit_Index
$25.00 | 71.3%           | $17.83        | $7.13
$35.00 | 62.8%           | $21.98        | $12.56
$45.00 | 53.7%           | $24.17        | $16.11
$55.00 | 44.2%           | $24.31        | $17.68
$65.00 | 35.1%           | $22.82        | $17.55
```

### 7.5 Charts

**Generated PNG Files:**
- `vw_psm_plot.png` - Van Westendorp curves with intersections
- `gg_demand_curve.png` - Purchase intent vs price
- `gg_revenue_curve.png` - Revenue optimization
- `gg_profit_curve.png` - Profit optimization (if applicable)
- `monadic_demand_curve.png` - Logistic demand curve with CI band
- `segment_comparison.png` - Segment-level analysis

---

## 8. HTML Report

When `generate_html_report = TRUE` in the Settings sheet, the module generates a self-contained HTML report alongside the Excel output.

### 8.1 Report Features

- **Self-contained**: Single HTML file with embedded CSS, SVG charts, and JavaScript
- **Tabbed navigation**: Summary | Van Westendorp | Gabor-Granger | Monadic | Segments | Recommendation | Simulator | Added Slides | Pinned | About
- **Brand theming**: Set `brand_colour` in config to customise the colour scheme
- **SVG charts**: Vector-based charts that scale to any resolution
- **Report hub integration**: Meta tags enable automatic discovery by the Turas Report Hub

### 8.2 Chart Types

- **VW Cumulative Distribution Curves**: Four lines with intersection points marked
- **GG Demand Curve with Revenue Overlay**: Dual-axis chart showing intent and revenue
- **Monadic Logistic Curve with CI Band**: Demand curve with bootstrap confidence band
- **Segment Comparison**: Forest-plot style comparison across segments
- **Price Ladder Tiers**: Visual tier breakdown

### 8.3 Sharing

The HTML file can be opened in any modern browser. No Turas installation is required. Attach it to emails or share via file transfer.

---

## 9. Interactive Simulator

When `generate_simulator = TRUE` in the Settings sheet, the module generates an interactive pricing simulator dashboard as a standalone HTML file.

### 9.1 Features

- **Price Sliders**: Drag to adjust price and see demand, revenue, and profit update in real-time
- **Preset Scenario Cards**: Named configurations (e.g., "Budget Launcher", "Premium Pro") configured via the Simulator sheet in the config
- **Battle Mode**: Side-by-side comparison of 2-3 scenarios across all metrics
- **Segment Toggle**: Switch between total sample and segment-specific views
- **PNG Export**: One-click capture of the current view for presentations

### 9.2 Simulator Configuration (Simulator Sheet)

Define preset scenarios in the config:

| Setting | Description | Example |
|---------|-------------|---------|
| scenario_name | Scenario identifier | `Budget Launcher` |
| scenario_price | Price for this scenario | `29.99` |
| competitor_prices | Competitor prices (semicolon-separated) | `35;42;50` |
| cost_assumption | Unit cost for profit calculation | `15` |

### 9.3 Sharing with Clients

The simulator is a single HTML file. Clients can:
1. Open it in any browser (Chrome, Firefox, Safari, Edge)
2. Adjust sliders and explore scenarios
3. Export PNG snapshots for internal presentations
4. No Turas installation, R, or technical knowledge required

---

## 10. Added Slides & Images

The pricing HTML report includes an "Added Slides" tab for embedding narrative content, quotes, findings, and images directly into the report.

### 10.1 Config-Driven Slides

Add an **AddedSlides** sheet to your config Excel with these columns:

| Column | Required | Description |
|--------|----------|-------------|
| `slide_title` | YES | Title displayed at the top of the slide card |
| `content` | YES | Markdown-formatted text content |
| `image_path` | NO | Path to an image file (relative to config file or absolute) |
| `display_order` | NO | Numeric sort order (auto-sequenced if omitted) |

**Example AddedSlides Sheet:**

| slide_title | content | image_path | display_order |
|-------------|---------|------------|---------------|
| Key Finding | Our target segment shows **high price sensitivity** below $30 | chart_export.png | 1 |
| Customer Quote | > "I would pay up to $45 for this quality level" - Focus Group Participant | | 2 |
| Market Context | ## Competitive Landscape\n- Competitor A: $35\n- Competitor B: $42 | | 3 |

### 10.2 Markdown Formatting

Slide content supports lightweight markdown:

| Syntax | Renders As |
|--------|------------|
| `**bold text**` | **bold text** |
| `*italic text*` | *italic text* |
| `## Heading` | Large heading |
| `- bullet point` | Bulleted list item |
| `> quoted text` | Blockquote (indented, styled) |

### 10.3 Interactive Slides in HTML Report

The "Added Slides" tab in the HTML report supports interactive editing:

- **Add Slide**: Click the "+ Add Slide" button to create new slides at runtime
- **Edit Content**: Double-click any slide's rendered content to switch to the markdown editor
- **Upload Images**: Click the image icon on any slide to upload a photo or chart (max 5MB, auto-resized to 800px)
- **Reorder**: Use the up/down arrows to rearrange slides
- **Pin to Curated**: Click the pin icon to add a slide to the Pinned Views tab for export
- **Remove**: Click the X to delete a slide (with confirmation)

### 10.4 Image Handling

- **Config images**: Paths in the `image_path` column are resolved relative to the config file directory. Images are embedded as base64 data URIs, making the HTML report fully self-contained.
- **Interactive uploads**: Images uploaded in the HTML report are client-side only (resized to max 800px, compressed to JPEG 70% quality). They are preserved when using the Save button.
- **Supported formats**: PNG, JPEG, GIF, WebP, SVG

---

## 11. Advanced Features

### 11.1 NMS Extension (Newton-Miller-Smith)

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

### 11.2 Segment Analysis

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

### 11.3 Price Ladder Builder

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

### 11.4 Recommendation Synthesis

Combines all analyses into executive summary.

**Factors Considered:**
1. Method agreement (Van Westendorp, Gabor-Granger, Monadic, NMS)
2. Sample size adequacy
3. Data quality
4. Zone fit
5. Method coverage

**Output**:
- Recommended price with confidence level (HIGH/MEDIUM/LOW)
- Supporting evidence
- Risk assessment
- Executive narrative

### 11.5 Point Price Elasticity

Computes derivative-based point elasticity at any price on the demand curve, providing more precise elasticity estimates than the default arc elasticity between consecutive tested prices.

**Function:** `compute_point_elasticity(demand_curve, prices_to_evaluate, delta)`

**How It Works:**
- Builds a monotone spline interpolator from the Gabor-Granger demand curve
- Computes dQ/dP via central finite difference at each evaluation price
- Returns point elasticity E(p) = (dQ/dP) × (P/Q)
- Also computes marginal revenue MR(p) = Q(p) + p × dQ/dP

**Output Columns:**
| Column | Description |
|--------|-------------|
| `price` | Evaluation price |
| `purchase_intent` | Interpolated demand at that price |
| `elasticity` | Point elasticity (negative = normal demand) |
| `elasticity_type` | "Elastic" (\|E\| > 1), "Inelastic" (\|E\| < 1), or "Unit Elastic" |
| `revenue_index` | Price × demand |
| `marginal_revenue` | Revenue change from a small price increase |

**Key Insight:** Revenue is maximized where marginal revenue = 0 (i.e., elasticity = -1). The `revenue_maximizing_price` attribute on the result identifies this point.

**Example:**
```r
dc <- run_gabor_granger(data, config)$demand_curve
elast <- compute_point_elasticity(dc)
cat("Revenue-maximizing price:", attr(elast, "revenue_maximizing_price"))
```

### 11.6 Segment Statistical Tests

Tests whether pricing metrics differ significantly between customer segments using non-parametric methods that make no distributional assumptions.

**Function:** `test_segment_differences(data, config, metric, method, n_perm)`

**Methods Available:**
- `"permutation"` (default) — Permutation test: shuffles segment labels to build a null distribution, then computes a two-sided p-value. P-values are Holm-Bonferroni adjusted for multiple comparisons.
- `"bootstrap_ci"` — Bootstrap confidence intervals for the difference in means between each pair of segments. Significant if the CI excludes zero.

**Configuration:**
```
segment_column = "customer_type"
```

**Output Structure:**
```r
result <- test_segment_differences(data, config, metric = "wtp")

result$overall       # Kruskal-Wallis global test (p-value)
result$pairwise      # Pairwise comparisons with p-values/CIs
result$summary       # Segment means with bootstrap CIs
result$significant_pairs  # Character vector: "Budget vs Premium"
```

**Interpreting Results:**
- **Overall p < 0.05**: At least one segment differs significantly
- **Pairwise p_adjusted < 0.05**: Specific pair differs (after multiple-comparison correction)
- **Summary CIs**: Non-overlapping CIs strongly suggest different pricing is warranted

**Example:**
```r
result <- test_segment_differences(
  data, config,
  metric = "wtp",
  method = "permutation",
  n_perm = 2000
)

if (length(result$significant_pairs) > 0) {
  cat("Segments with statistically different WTP:\n")
  cat(paste("-", result$significant_pairs, collapse = "\n"))
}
```

**Note:** This replaces the heuristic-based segment insights (e.g., "20% price difference" thresholds) with formal statistical inference. The heuristic insights in `generate_segment_insights()` remain available for quick interpretation, while `test_segment_differences()` provides rigorous p-values for decision support.

---

## 12. Troubleshooting

### 12.1 Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "File not found" | Invalid path | Use absolute paths |
| "Column not found" | Name mismatch | Check column names (case-sensitive) |
| "Too many exclusions" | High violation rate | Use `flag_only` monotonicity |
| "Package 'pricesensitivitymeter' required" | NMS not installed | `install.packages("pricesensitivitymeter")` |
| "All 100% or 0%" | Price range too narrow | Expand tested price range |

### 12.2 Data Quality Issues

| Warning | Meaning | Action |
|---------|---------|--------|
| "X% monotonicity violations" | Illogical price order | Normal if < 15%; review if higher |
| "Non-monotonic demand" | Purchase intent increases with price | Use `smooth` mode |
| "Segment n < 50" | Small segment | Combine segments or lower threshold |
| "High exclusion rate" | Many incomplete responses | Review data collection |

### 12.3 Interpretation Issues

**Issue**: Van Westendorp curves don't intersect clearly
**Solution**: May indicate poorly defined market; consider price bundling or segmentation

**Issue**: Gabor-Granger revenue curve is flat
**Solution**: Prices too similar; test wider range in next study

**Issue**: Methods give different recommendations
**Solution**: Normal! Van Westendorp shows *range*, Gabor-Granger shows *specific price*

---

## 13. Best Practices

### 13.1 Study Design

**Sample Size:**
- Minimum 100 respondents for basic analysis
- 300+ for segment analysis
- 500+ for complex segmentation or small niches

**Price Range:**
- Van Westendorp: Let respondents answer freely (don't constrain)
- Gabor-Granger: Test 5-7 price points spanning 50-200% of expected price
- Monadic: Use 4-8 price cells with at least 50 respondents per cell

**Question Design:**
- Van Westendorp: Use exact wording from methodology
- Gabor-Granger: Clear "Would you buy at $X?" questions
- Both: Randomize order to reduce bias

### 13.2 Data Collection

**Survey Flow:**
1. Van Westendorp questions first (open-ended)
2. Gabor-Granger questions second (build on awareness)
3. Demographics last

**Quality Checks:**
- Include attention checks
- Monitor completion time (< 1 min suggests speeding)
- Soft launch to test (n=50)

### 13.3 Configuration

**General:**
- Always set `validate_monotonicity = TRUE`
- Use `flag_only` for monotonicity (preserves sample)
- Enable bootstrap CIs for final analysis (not exploration)

**Gabor-Granger Specific:**
- Use `smooth` monotonicity for clean curves
- Set `unit_cost` if known (enables profit analysis)
- Test price sequence: lowest to highest

### 13.4 Analysis

**Validation:**
- Review data quality metrics in Validation sheet
- Check exclusion rates (should be < 15%)
- Verify segment sizes adequate

**Interpretation:**
- Van Westendorp: Focus on optimal zone (OPP to IDP)
- Gabor-Granger: Compare revenue-max vs profit-max
- Monadic: Check pseudo-R2 and price coefficient p-value for model quality
- Combined: Ensure optimal prices from all methods converge within acceptable range

**Reporting:**
- Use rescaled scores for client presentations
- Show both price ranges and specific recommendations
- Include confidence assessment from synthesis

---

## 14. End-to-End Walkthrough

This section walks through a complete pricing study from survey design to final deliverable.

### 14.1 Survey Design

**Step 1: Choose Your Method(s)**

| If You Need... | Use |
|----------------|-----|
| Acceptable price range for a new product | Van Westendorp |
| Revenue/profit-maximizing price with demand curve | Gabor-Granger |
| Unbiased price point without anchoring effects | Monadic |
| Both range and specific price | Van Westendorp + Gabor-Granger (`both`) |

**Step 2: Design Survey Questions**

For Van Westendorp, include these four open-ended price questions (exact wording matters):
1. "At what price would you consider this product to be so cheap that you would question its quality?"
2. "At what price would you consider this product a bargain — a great buy for the money?"
3. "At what price would you consider this product getting expensive — you might still consider it, but would need to think about it?"
4. "At what price would you consider this product too expensive to consider buying?"

For Gabor-Granger, ask purchase intent at 5-7 specific price points:
- "Would you purchase this product at $25?" (Yes/No)
- "Would you purchase this product at $30?" (Yes/No)
- ... and so on through your price range

For Monadic, randomly assign ONE price per respondent and ask:
- "Given this product at $XX, how likely are you to purchase?" (binary or scale)

**Step 3: Determine Sample Size**

- Van Westendorp: 200+ respondents minimum
- Gabor-Granger: 200+ respondents minimum
- Monadic: 50+ respondents per price cell (e.g., 5 cells = 250+ total)
- Segment analysis: 100+ per segment

### 14.2 Data Preparation

**Step 1: Export survey data** to CSV or Excel format

**Step 2: Verify data structure:**
```r
data <- read.csv("my_survey_data.csv")
str(data)
summary(data)
```

**Step 3: Check for common issues:**
- Missing values in price columns
- Non-numeric entries (e.g., "$25" instead of 25)
- Illogical responses (too_cheap > too_expensive)

### 14.3 Configuration

**Step 1: Generate a config template:**
```r
source("modules/pricing/R/00_main.R")
create_pricing_config("my_config.xlsx", method = "both")
```

**Step 2: Fill in the Settings sheet:**
- `Project_Name`: Your project identifier
- `Analysis_Method`: `van_westendorp`, `gabor_granger`, `monadic`, or `both`
- `Data_File`: Path to your survey data
- `Output_File`: Where to save results
- `Currency_Symbol`: `$`, `€`, `£`, `R`, etc.
- `Weight_Variable`: Column name if using survey weights

**Step 3: Fill in method-specific sheets** (VanWestendorp, GaborGranger, Monadic)

**Step 4: (Optional) Add narrative slides** in the AddedSlides sheet

### 14.4 Running the Analysis

**Via Shiny GUI:**
1. Launch Turas: `source("launch_turas.R"); launch_turas()`
2. Navigate to Pricing module
3. Load your config file
4. Click "Run Analysis"
5. Monitor progress in the R console

**Via R script:**
```r
source("modules/pricing/R/00_main.R")
result <- run_pricing_analysis("my_config.xlsx")

# Check status
cat("Status:", result$status, "\n")
if (result$status == "PASS") {
  cat("Results saved to:", result$output_file, "\n")
  cat("HTML report:", result$html_report_file, "\n")
}
```

### 14.5 Reviewing Results

1. **Excel workbook**: Open the output Excel file for detailed data tables
2. **HTML report**: Open the HTML file in a browser for interactive exploration
3. **Key things to check:**
   - Recommendation tab: What price does the module recommend?
   - Confidence level: HIGH/MEDIUM/LOW — how much agreement between methods?
   - Data quality: Check Validation sheet for exclusion rates and warnings
   - Segment differences: Do price sensitivities vary significantly across segments?

### 14.6 Delivering to Stakeholders

1. **Share the HTML report** — it's a single self-contained file, no installation needed
2. **Add narrative slides** with key findings and recommendations before sharing
3. **Include the simulator** (if enabled) for interactive scenario exploration
4. **Pin key views** to the Pinned tab for a curated story

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

## 15. Known Limitations

### 15.1 Statistical Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| Van Westendorp assumes curves intersect cleanly | Poorly defined markets may produce no clear intersection | Use segmentation to identify more homogeneous groups |
| Gabor-Granger assumes rational monotone demand | Some respondents may show non-monotonic responses | Use `smooth` monotonicity setting (isotonic regression) |
| Monadic logistic regression assumes linear log-odds | Non-linear price effects may be missed | Use `log_logistic` model type, or increase price cells |
| Bootstrap CIs require sufficient sample size | Small samples (< 100) produce wide, unstable intervals | Ensure 200+ respondents; 50+ per price cell for monadic |
| Weighted analysis assumes proper survey weights | Incorrect weights bias all estimates | Validate weights sum to expected population totals |

### 15.2 Data Limitations

- **CSV/Excel only**: Does not natively read SPSS (.sav) or Stata (.dta) without the `haven` package
- **Wide format preferred**: Gabor-Granger long format support is functional but less tested
- **No panel/longitudinal support**: Each run is cross-sectional; tracking price sensitivity over time requires separate runs
- **Maximum file size**: Performance may degrade with datasets exceeding 100,000 rows (rare in pricing research)

### 15.3 Output Limitations

- **HTML report is client-rendered**: Added slides and pinned views are stored in the browser — clearing browser data loses interactive changes (use Save button to persist)
- **Simulator is approximation**: The simulator interpolates from the fitted model; extrapolation beyond tested price range is unreliable
- **No direct PowerPoint export**: Use the PNG/slide export buttons to capture individual views, then assemble in your presentation tool

### 15.4 Methodology Scope

- **No conjoint integration**: Pricing module operates independently from the conjoint module; cross-method integration is planned but not yet implemented
- **No cross-price elasticity**: Only own-price elasticity is calculated; competitive dynamics require the competitive scenarios module (`08_competitive_scenarios.R`) for multi-brand simulation
- **No Bayesian methods**: All estimation is frequentist (MLE via GLM); Bayesian priors are not supported
- **Point elasticity requires 3+ price points**: The monotone spline interpolator needs at least 3 non-NA data points to compute derivatives

---

## 16. Appendix: Package Versions

The pricing module has been tested with the following R package versions. Earlier versions may work but are not guaranteed.

### Core Dependencies

| Package | Tested Version | CRAN | Purpose |
|---------|---------------|------|---------|
| R | 4.3.x / 4.4.x | — | Base R runtime |
| `stats` | (base) | — | `glm()`, `predict()`, `quantile()` |
| `readxl` | 1.4.3 | Yes | Excel config file reading |
| `openxlsx` | 4.2.7 | Yes | Excel output with styled formatting |
| `base64enc` | 0.1-3 | Yes | Image embedding for HTML reports |
| `jsonlite` | 1.8.9 | Yes | JSON serialization for simulator |
| `tools` | (base) | — | `file_ext()` for MIME type detection |

### Optional Dependencies

| Package | Tested Version | CRAN | Purpose |
|---------|---------------|------|---------|
| `pricesensitivitymeter` | 1.2.1 | Yes | Newton-Miller-Smith (NMS) extension |
| `haven` | 2.5.4 | Yes | SPSS/Stata data import |
| `survey` | 4.4-2 | Yes | Complex survey weighting |

### Development/Testing Dependencies

| Package | Tested Version | Purpose |
|---------|---------------|---------|
| `testthat` | 3.2.1 | Unit testing framework |
| `shiny` | 1.9.1 | GUI launcher |

---

*For additional examples and walkthroughs, see [Example Workflows](EXAMPLE_WORKFLOWS.md).*

*For detailed methodology, see [Authoritative Guide](AUTHORITATIVE_GUIDE.md).*

*For survey design guidance, see [Questionnaire Design Guide](QUESTIONNAIRE_DESIGN_GUIDE.md).*

*For method selection and comparison, see [Methodology Comparison](METHODOLOGY_COMPARISON.md).*

*For developer documentation, see [Technical Reference](TECHNICAL_REFERENCE.md).*
