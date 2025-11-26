# Part 3: Excel Output & Market Simulator Specification

## 1. Excel Output Structure

### 1.1 Workbook Sheet Organization

```
conjoint_results.xlsx:
├── 1. Executive Summary      [NEW - Overview for clients]
├── 2. Attribute Importance   [Enhanced version]
├── 3. Part-Worth Utilities   [Enhanced with CIs and significance]
├── 4. Model Diagnostics      [Enhanced with interpretation]
├── 5. Market Simulator       [NEW - Interactive tool]
├── 6. Simulator Data         [Hidden - lookup tables]
├── 7. Detailed Results       [For technical users]
└── 8. Configuration Summary  [What was run]
```

## 2. Sheet Specifications

### 2.1 Executive Summary Sheet

**Purpose:** One-page overview for non-technical stakeholders

**Layout:**
```
Row 1-3: Title and metadata
Row 5-15: Key findings (text + visuals)
Row 17-25: Top insights
Row 27-35: Recommendations
```

**Content:**
```r
create_executive_summary <- function(results, config) {
  
  # Section 1: Header
  # - Study name
  # - Date of analysis
  # - Sample size
  # - Model quality (R², hit rate)
  
  # Section 2: Key Findings (auto-generated text)
  findings <- list(
    sprintf("NutriScore is the most important attribute (%.0f%% importance)", 
            top_importance),
    sprintf("Price sensitivity: %.0f%% importance", 
            price_importance),
    sprintf("Model accurately predicts %.0f%% of choices (hit rate)", 
            hit_rate * 100),
    sprintf("Based on %d respondents across %d choice sets",
            n_resp, n_sets)
  )
  
  # Section 3: Top 3 Preferred Levels (auto-generated)
  # - Rank levels by utility across all attributes
  # - Show top 3 with utility bars
  
  # Section 4: Attribute Importance Chart
  # - Horizontal bar chart
  # - Color-coded by importance tier
  
  # Section 5: Recommendations (template with placeholders)
  recommendations <- list(
    "Focus on [TOP ATTRIBUTE] when developing products",
    "Price point should be [OPTIMAL LEVEL] based on utility",
    "Consider [ATTRIBUTE] as secondary differentiator"
  )
}
```

**Formatting:**
- Large, clear fonts (14-16pt for headers)
- Color scheme: Blue/green for positive, red/orange for negative
- Minimal text, maximum visual impact
- Print-friendly (fits on one page)

### 2.2 Attribute Importance Sheet (Enhanced)

**Columns:**
```
A: Attribute
B: Relative Importance (%)
C: Importance Rank
D: Range of Utilities
E: CI Lower (95%)
F: CI Upper (95%)
G: Discrimination Index
H: Interpretation
```

**Sample row:**
```
NutriScore | 59.06 | 1 | 2.465 | 55.2 | 63.1 | High | Critical driver of choice
Price      | 18.88 | 2 | 0.788 | 15.3 | 22.4 | Medium | Moderate influence
MSG        | 10.16 | 3 | 0.424 | 7.8  | 12.5 | Medium | Notable concern
```

**Auto-generated Interpretation:**
```r
interpret_importance <- function(importance_pct) {
  case_when(
    importance_pct > 40 ~ "Critical driver of choice",
    importance_pct > 20 ~ "Major influence on decisions",
    importance_pct > 10 ~ "Moderate influence",
    importance_pct > 5  ~ "Minor influence",
    TRUE ~ "Minimal impact"
  )
}
```

**Visualizations:**
1. Horizontal bar chart (sorted by importance)
2. Pie chart (for executive summary)
3. Waterfall chart (showing cumulative importance)

**Formatting:**
```r
format_importance_sheet <- function(wb, sheet_name, data) {
  
  # Header row: Bold, blue background, white text
  header_style <- createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "left",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  
  # Importance values: Conditional formatting
  # >40%: Dark green
  # 20-40%: Light green  
  # 10-20%: Yellow
  # <10%: Orange
  
  conditionalFormatting(
    wb, sheet_name,
    cols = 2,  # Importance column
    rows = 2:(nrow(data) + 1),
    rule = c(0, 10, 20, 40, 100),
    style = c("#FFC000", "#FFFF00", "#92D050", "#00B050"),
    type = "colorScale"
  )
  
  # Interpretation column: Text color based on importance
  # Critical: Dark blue, bold
  # Major: Blue
  # Moderate: Gray
  # Minor/Minimal: Light gray
}
```

### 2.3 Part-Worth Utilities Sheet (Enhanced)

**Columns:**
```
A: Attribute
B: Level
C: Utility (zero-centered)
D: Std Error
E: CI Lower (95%)
F: CI Upper (95%)
G: p-value
H: Significant?
I: Interpretation
J: Baseline?
```

**Sample rows:**
```
Price | Low_071  | 0.788 | 0.089 | 0.614 | 0.962 | <0.001 | *** | Highly preferred | No
Price | Mid_089  | 0.585 | 0.087 | 0.414 | 0.756 | <0.001 | *** | Preferred       | No
Price | High_107 | 0.000 | -     | -     | -     | -      | -   | Baseline        | Yes
MSG   | Absent   | 0.212 | 0.064 | 0.087 | 0.337 | 0.001  | **  | Preferred       | Yes
MSG   | Present  |-0.212 | 0.064 |-0.337 |-0.087 | 0.001  | **  | Avoided         | No
```

**Auto-generated Interpretation:**
```r
interpret_utility <- function(utility, p_value, is_baseline) {
  if (is_baseline) return("Baseline (reference level)")
  
  sig_level <- case_when(
    p_value < 0.001 ~ "***",
    p_value < 0.01  ~ "**",
    p_value < 0.05  ~ "*",
    TRUE ~ "ns"
  )
  
  magnitude <- case_when(
    abs(utility) > 1.0 ~ "Strongly",
    abs(utility) > 0.5 ~ "Moderately",
    abs(utility) > 0.2 ~ "Somewhat",
    TRUE ~ "Slightly"
  )
  
  direction <- if_else(utility > 0, "preferred", "avoided")
  
  if (sig_level == "ns") {
    return("Not significantly different from baseline")
  }
  
  sprintf("%s %s %s", magnitude, direction, sig_level)
}
```

**Visualizations:**
1. Diverging bar chart (by attribute, showing positive/negative utilities)
2. Forest plot (utilities with confidence intervals)
3. Heatmap (all utilities color-coded)

**Formatting:**
```r
format_utilities_sheet <- function(wb, sheet_name, utilities) {
  
  # Utility column: Diverging color scale
  # Positive: Shades of green
  # Negative: Shades of red
  # Zero: White
  
  conditionalFormatting(
    wb, sheet_name,
    cols = 3,  # Utility column
    rows = 2:(nrow(utilities) + 1),
    type = "colorScale",
    style = c("#F8696B", "#FFFFFF", "#63BE7B"),
    rule = c(min(utilities$Utility), 0, max(utilities$Utility))
  )
  
  # Significance: Bold and color-code
  # ***: Dark green
  # **: Green
  # *: Light green
  # ns: Gray
  
  # p-value: Scientific notation for very small values
  addStyle(wb, sheet_name,
    style = createStyle(numFmt = "0.000"),
    rows = 2:(nrow(utilities) + 1),
    cols = 7  # p-value column
  )
  
  # Add banding: Alternate row colors by attribute
  # Each attribute gets consistent shading
}
```

### 2.4 Model Diagnostics Sheet (Enhanced)

**Structure:**
```
Section 1: Overall Model Fit (rows 1-12)
Section 2: Attribute-Level Diagnostics (rows 14-25)
Section 3: Data Quality Indicators (rows 27-35)
Section 4: Prediction Accuracy (rows 37-45)
Section 5: Interpretation Guide (rows 47-60)
```

**Section 1: Overall Model Fit**
```
Metric                    | Value  | Benchmark        | Assessment
--------------------------|--------|------------------|-------------
McFadden R²              | 0.147  | >0.20 = Good     | Acceptable
Adjusted McFadden R²     | 0.142  | >0.15 = Good     | Good
Log-Likelihood (fitted)  |-2809.2 | -                | -
Log-Likelihood (null)    |-3296.1 | -                | -
LR Test Statistic        | 973.8  | -                | -
LR Test p-value          | <0.001 | <0.05 = Sig      | Highly significant
AIC                      | 5636.4 | Lower is better  | -
BIC                      | 5691.2 | Lower is better  | -
Hit Rate                 | 47.3%  | >chance = Good   | Good (chance=33%)
N Respondents            | 335    | >300 = Adequate  | Adequate
N Choice Sets            | 1,005  | -                | -
Convergence              | Yes    | Must be Yes      | ✓
```

**Section 2: Attribute-Level Diagnostics**
```
Attribute    | N Levels | Range | % Significant | Overall p-value | Assessment
-------------|----------|-------|---------------|-----------------|------------
NutriScore   | 5        | 2.465 | 100%          | <0.001          | Strong
Price        | 3        | 0.788 | 100%          | <0.001          | Strong  
MSG          | 2        | 0.424 | 100%          | <0.001          | Moderate
PotassiumChl | 2        | 0.289 | 100%          | <0.001          | Moderate
I+G          | 2        | 0.014 | 0%            | 0.828           | Weak
Salt         | 2        | 0.191 | 100%          | 0.003           | Moderate
```

**Section 5: Interpretation Guide**
```r
# Auto-generated interpretation text
interpretation_guide <- sprintf("

MODEL QUALITY ASSESSMENT:
Your conjoint model shows %s fit with a McFadden R² of %.3f.

%s

PREDICTION ACCURACY:
The model correctly predicts %.1f%% of choices, which is %.1fx better than 
random guessing (%.1f%%).

%s

ATTRIBUTE INSIGHTS:
- %s is the dominant driver (%.0f%% importance)
- %d of %d attributes show strong statistical significance
- %s shows weak effects and may not influence choice

RECOMMENDATIONS:
%s

",
  # Quality assessment
  quality_level,  # "excellent", "good", "acceptable", "poor"
  mcfadden_r2,
  quality_explanation,
  
  # Prediction accuracy
  hit_rate * 100,
  hit_rate / chance_rate,
  chance_rate * 100,
  accuracy_explanation,
  
  # Attribute insights  
  top_attribute,
  top_importance,
  n_significant,
  n_total,
  weak_attribute,
  
  # Recommendations
  generate_recommendations(results)
)
```

## 3. Market Simulator Sheet (The Crown Jewel)

### 3.1 Simulator Layout

```
Section A: Instructions (rows 1-8)
Section B: Product Configuration (rows 10-25)
Section C: Market Share Results (rows 27-35)
Section D: Utilities Breakdown (rows 37-50)
Section E: Sensitivity Analysis (rows 52-65)
Section F: Comparison Chart (rows 67-80)
```

### 3.2 Product Configuration Section

**Layout:**
```
Row 10: Headers

     A              B          C          D          E          F
10 | Attribute   | Product 1 | Product 2 | Product 3 | Product 4 | Product 5
11 | Price       | [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]
12 | MSG         | [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]
13 | Potassium.. | [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]
14 | I+G         | [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]
15 | Salt        | [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]
16 | NutriScore  | [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]| [DROPDOWN]
```

**Dropdown Implementation:**
```r
# Create dropdowns for each attribute
for (attr in attributes) {
  levels <- get_attribute_levels(config, attr)
  
  # Create data validation
  dataValidation(
    wb, "Market Simulator",
    col = 2:6,  # Columns B through F
    rows = attr_row,
    type = "list",
    value = sprintf('"%s"', paste(levels, collapse = '","'))
  )
}
```

### 3.3 Market Share Calculation

**Formulas:**

```excel
# For Product 1, Cell B28 (Total Utility)
=SUMIFS('Simulator Data'!$C:$C, 
        'Simulator Data'!$A:$A, B11,  # Price match
        'Simulator Data'!$B:$B, "Price") +
 SUMIFS('Simulator Data'!$C:$C,
        'Simulator Data'!$A:$A, B12,  # MSG match
        'Simulator Data'!$B:$B, "MSG") +
 SUMIFS('Simulator Data'!$C:$C,
        'Simulator Data'!$A:$A, B13,  # PotassiumChloride match
        'Simulator Data'!$B:$B, "PotassiumChloride") +
 SUMIFS('Simulator Data'!$C:$C,
        'Simulator Data'!$A:$A, B14,  # I+G match
        'Simulator Data'!$B:$B, "I+G") +
 SUMIFS('Simulator Data'!$C:$C,
        'Simulator Data'!$A:$A, B15,  # Salt match
        'Simulator Data'!$B:$B, "Salt") +
 SUMIFS('Simulator Data'!$C:$C,
        'Simulator Data'!$A:$A, B16,  # NutriScore match
        'Simulator Data'!$B:$B, "NutriScore")

# Cell B29 (Exponential Utility)
=EXP(B28)

# Cell B30 (Market Share %)
=B29/SUM($B$29:$F$29)*100
```

**Market Share Display:**
```
     A              B          C          D          E          F
27 | Metric      | Product 1 | Product 2 | Product 3 | Product 4 | Product 5
28 | Total Util  | [FORMULA] | [FORMULA] | [FORMULA] | [FORMULA] | [FORMULA]
29 | exp(Util)   | [FORMULA] | [FORMULA] | [FORMULA] | [FORMULA] | [FORMULA]
30 | Share (%)   | [FORMULA] | [FORMULA] | [FORMULA] | [FORMULA] | [FORMULA]
31 |             |           |           |           |           |
32 | CHART: Pie chart showing market shares
```

### 3.4 Utilities Breakdown Section

**Purpose:** Show how each attribute contributes to total utility

```
Row 37: Utilities Contributing to Choice

     A              B          C          D          E          F
37 | Attribute   | Product 1 | Product 2 | Product 3 | Product 4 | Product 5
38 | Price       | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP]
39 | MSG         | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP]
40 | Potassium.. | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP]
41 | I+G         | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP]
42 | Salt        | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP]
43 | NutriScore  | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP] | [VLOOKUP]
44 | TOTAL       | [SUM]     | [SUM]     | [SUM]     | [SUM]     | [SUM]
45 |             |           |           |           |           |
46 | CHART: Stacked bar chart showing utility breakdown by attribute
```

**VLOOKUP Formula:**
```excel
# Cell B38 (Price utility for Product 1)
=VLOOKUP(B11, 'Simulator Data'!$A:$C, 3, FALSE)

# Where:
# B11 = selected price level for Product 1
# 'Simulator Data'!$A:$C = lookup table with Level | Attribute | Utility
# 3 = return utility (column 3)
# FALSE = exact match
```

### 3.5 Sensitivity Analysis Section

**One-Way Sensitivity:**
```
Row 52: Price Sensitivity for Product 1

     A              B          C          D
52 | Price Level | Utility   | Share (%) | Change vs Current
53 | Low_071     | [FORMULA] | [FORMULA] | [FORMULA]
54 | Mid_089     | [FORMULA] | [FORMULA] | [FORMULA]
55 | High_107    | [FORMULA] | [FORMULA] | [FORMULA]
56 |
57 | Current:    | [CURRENT] | [CURRENT] | -
58 |
59 | CHART: Line chart showing share by price level
```

**What-If Scenarios:**
```
Row 61: Scenario Comparison

     A              B          C          D          E
61 | Scenario    | Product 1 | Product 2 | Winner    | Share Diff
62 | Current     | [CONFIG]  | [CONFIG]  | [CALC]    | -
63 | +MSG        | [CONFIG]  | [CONFIG]  | [CALC]    | [CALC]
64 | +NutriA     | [CONFIG]  | [CONFIG]  | [CALC]    | [CALC]
65 | Price-10%   | [CONFIG]  | [CONFIG]  | [CALC]    | [CALC]
```

### 3.6 Simulator Data Sheet (Hidden)

**Purpose:** Lookup tables for VLOOKUP/SUMIFS formulas

**Structure:**
```
     A          B              C
1  | Level    | Attribute    | Utility
2  | Low_071  | Price        | 0.788
3  | Mid_089  | Price        | 0.585
4  | High_107 | Price        | 0.000
5  | Absent   | MSG          | 0.212
6  | Present  | MSG          | -0.212
7  | Absent   | PotassiumChl | 0.145
8  | Present  | PotassiumChl | -0.145
...
```

**Additional Tables:**
```
# Table 2: Attribute Importance (for reference)
Column E-F:
Attribute | Importance
Price     | 18.88
MSG       | 10.16
...

# Table 3: Market Simulator Scenarios (saved configurations)
Column H-M:
Scenario  | Product1_Price | Product1_MSG | ... | Market_Share
Default   | Low_071       | Absent        | ... | 45.2
Scenario1 | Mid_089       | Present       | ... | 32.1
...
```

## 4. Formatting & User Experience

### 4.1 Color Scheme (Consistent Across All Sheets)

```r
# Define color palette
colors <- list(
  primary_blue   = "#4472C4",    # Headers, main elements
  secondary_blue = "#5B9BD5",    # Secondary headers
  light_blue     = "#D9E1F2",    # Background highlights
  
  positive_green = "#70AD47",    # Positive utilities
  negative_red   = "#E74C3C",    # Negative utilities
  neutral_gray   = "#767676",    # Neutral/baseline
  
  warning_orange = "#FFC000",    # Warnings
  success_green  = "#92D050",    # Success indicators
  
  chart_colors   = c("#4472C4", "#ED7D31", "#A5A5A5", "#FFC000", "#5B9BD5")
)
```

### 4.2 Instructions & Help Text

**Instructions Box (Top of Market Simulator):**
```
┌─────────────────────────────────────────────────────────────────┐
│ MARKET SIMULATOR INSTRUCTIONS                                   │
│                                                                 │
│ 1. Select attribute levels for each product using dropdowns    │
│ 2. Market shares update automatically                          │
│ 3. View utility breakdown to see what drives preference        │
│ 4. Use sensitivity analysis to test price changes              │
│                                                                 │
│ TIP: Start with your current product (Product 1) and           │
│      competitor products (Product 2-3), then test new concepts │
└─────────────────────────────────────────────────────────────────┘
```

**Cell Comments (Excel notes):**
```r
# Add helpful comments to key cells
add_cell_comment <- function(wb, sheet, row, col, text) {
  writeComment(
    wb, sheet,
    col = col, row = row,
    comment = createComment(
      text = text,
      author = "Turas Conjoint",
      visible = FALSE
    )
  )
}

# Example comments:
"Total Utility: Sum of part-worth utilities for selected levels"
"Market Share: Calculated using multinomial logit formula"
"This assumes all products equally available and no outside option"
```

### 4.3 Chart Specifications

**Chart 1: Attribute Importance (Horizontal Bar)**
```r
# Location: Attribute Importance sheet
# Type: Bar chart (horizontal)
# Data: Importance percentages
# Format:
#   - Bars sorted descending
#   - Color by importance tier
#   - Data labels showing percentage
#   - Clean, minimal gridlines
```

**Chart 2: Utilities by Attribute (Diverging Bar)**
```r
# Location: Part-Worth Utilities sheet
# Type: Clustered bar (diverging from 0)
# Data: Utilities for each level, grouped by attribute
# Format:
#   - Positive utilities: Green
#   - Negative utilities: Red
#   - Zero line emphasized
#   - Error bars showing confidence intervals
```

**Chart 3: Market Share (Pie + Bar)**
```r
# Location: Market Simulator sheet
# Type: Combination (Pie + Bar)
# Data: Market shares for Products 1-5
# Format:
#   - Pie chart: Shows relative shares
#   - Bar chart (below): Shows absolute shares with values
#   - Color-coded by product
#   - Updates automatically with dropdown changes
```

**Chart 4: Utility Waterfall**
```r
# Location: Market Simulator sheet (Utilities Breakdown)
# Type: Waterfall chart
# Data: Contribution of each attribute to total utility
# Format:
#   - Start at 0
#   - Each attribute adds/subtracts
#   - End at total utility
#   - Color: Green (positive), Red (negative)
```

## 5. Implementation Functions

### 5.1 Main Output Generator

```r
generate_excel_output <- function(results, config, output_file) {
  
  wb <- createWorkbook()
  
  # Add all sheets
  create_executive_summary_sheet(wb, results, config)
  create_importance_sheet(wb, results)
  create_utilities_sheet(wb, results)
  create_diagnostics_sheet(wb, results)
  create_market_simulator_sheet(wb, results, config)
  create_simulator_data_sheet(wb, results, config)  # Hidden
  create_detailed_results_sheet(wb, results)
  create_config_summary_sheet(wb, config)
  
  # Hide technical sheets
  sheetVisibility(wb)["Simulator Data"] <- "hidden"
  sheetVisibility(wb)["Detailed Results"] <- "hidden"
  
  # Set active sheet to Executive Summary
  activeSheet(wb) <- 1
  
  # Save
  saveWorkbook(wb, output_file, overwrite = TRUE)
  
  message(sprintf("✓ Excel output saved: %s", output_file))
}
```

### 5.2 Market Simulator Generator

```r
create_market_simulator_sheet <- function(wb, results, config) {
  
  addWorksheet(wb, "Market Simulator", 
               gridLines = TRUE, 
               tabColour = "#4472C4")
  
  # Section 1: Instructions
  write_simulator_instructions(wb, "Market Simulator")
  
  # Section 2: Product configuration with dropdowns
  row_start <- 10
  for (i in seq_along(config$attributes$AttributeName)) {
    attr <- config$attributes$AttributeName[i]
    levels <- get_attribute_levels(config, attr)
    
    # Write attribute name
    writeData(wb, "Market Simulator", attr, 
              startCol = 1, startRow = row_start + i)
    
    # Create dropdowns for products 1-5
    for (prod in 1:5) {
      dataValidation(
        wb, "Market Simulator",
        col = 1 + prod,
        rows = row_start + i,
        type = "list",
        value = sprintf('"%s"', paste(levels, collapse = '","'))
      )
      
      # Set default value (first level)
      writeData(wb, "Market Simulator", levels[1],
                startCol = 1 + prod, startRow = row_start + i)
    }
  }
  
  # Section 3: Market share calculations
  create_market_share_formulas(wb, "Market Simulator", config, 
                               row_start = 27)
  
  # Section 4: Utilities breakdown
  create_utilities_breakdown(wb, "Market Simulator", config,
                             row_start = 37)
  
  # Section 5: Sensitivity analysis
  create_sensitivity_analysis(wb, "Market Simulator", config,
                              row_start = 52)
  
  # Add charts
  create_simulator_charts(wb, "Market Simulator")
  
  # Format sheet
  format_simulator_sheet(wb, "Market Simulator")
}
```

### 5.3 Simulator Data Sheet (Lookup Tables)

```r
create_simulator_data_sheet <- function(wb, results, config) {
  
  addWorksheet(wb, "Simulator Data")
  
  # Create lookup table: Level | Attribute | Utility
  lookup_data <- results$utilities %>%
    select(Level, Attribute, Utility) %>%
    arrange(Attribute, Level)
  
  writeData(wb, "Simulator Data", lookup_data, startRow = 1)
  
  # Format as Excel table for easier VLOOKUP
  addTable(wb, "Simulator Data",
           x = lookup_data,
           tableName = "UtilityLookup",
           withFilter = FALSE)
  
  # Add attribute importance table
  importance_data <- results$importance %>%
    select(Attribute, Importance)
  
  writeData(wb, "Simulator Data", importance_data,
            startCol = 5, startRow = 1)
  
  # Name ranges for easier formula writing
  createNamedRegion(wb, "Simulator Data", 
                   cols = 1:3, rows = 2:(nrow(lookup_data) + 1),
                   name = "UtilityTable")
}
```

## 6. Testing & Validation

### 6.1 Output Testing

```r
test_excel_output <- function() {
  
  # Generate test output
  results <- run_conjoint_analysis(
    config_file = "test_data/DE_noodle_config.xlsx"
  )
  
  # Verify output file exists
  expect_true(file.exists(results$output_file))
  
  # Load workbook
  wb <- loadWorkbook(results$output_file)
  
  # Check all sheets exist
  expected_sheets <- c(
    "Executive Summary",
    "Attribute Importance",
    "Part-Worth Utilities",
    "Model Diagnostics",
    "Market Simulator",
    "Simulator Data",
    "Detailed Results",
    "Configuration Summary"
  )
  expect_equal(names(wb), expected_sheets)
  
  # Verify market simulator calculations
  # Change a dropdown value and check market share updates
  sim_data <- readWorkbook(wb, "Market Simulator")
  
  # Check formulas are present (not values)
  expect_true(grepl("^=", sim_data$B28))  # Total utility formula
  expect_true(grepl("^=", sim_data$B30))  # Market share formula
}
```

### 6.2 Simulator Validation

```r
test_market_simulator <- function() {
  
  # Manual calculation
  # Product 1: Price=Low, MSG=Absent, ..., NutriScore=A
  # Expected utility: 0.788 + 0.212 + ... = [calculated total]
  # Expected share: exp(utility) / sum(exp(all_utilities))
  
  # Load simulator
  wb <- loadWorkbook("test_output.xlsx")
  sim_data <- readWorkbook(wb, "Market Simulator")
  
  # Compare calculated vs. expected
  calculated_share <- sim_data$B30
  expected_share <- calculate_expected_share_manually()
  
  expect_equal(calculated_share, expected_share, tolerance = 0.01)
}
```

## 7. User Documentation for Simulator

### 7.1 Quick Start Guide (In Excel)

Create a "How to Use" sheet with:

```
┌──────────────────────────────────────────────────────────────┐
│ CONJOINT MARKET SIMULATOR - QUICK START GUIDE                │
└──────────────────────────────────────────────────────────────┘

STEP 1: UNDERSTAND YOUR RESULTS
→ Go to "Attribute Importance" to see what matters most
→ Check "Part-Worth Utilities" to see preferred levels

STEP 2: SET UP YOUR SCENARIO
→ Go to "Market Simulator" sheet
→ Use dropdowns to configure products:
  • Product 1: Your current product
  • Product 2-3: Competitor products
  • Product 4-5: New concepts to test

STEP 3: ANALYZE RESULTS
→ Market shares calculate automatically
→ Higher share = more appealing product
→ Check "Utilities Breakdown" to see why

STEP 4: TEST SCENARIOS
→ Change one attribute at a time to see impact
→ Use "Sensitivity Analysis" for systematic testing
→ Try: What if we reduce MSG? Change price? Improve NutriScore?

EXAMPLE INSIGHTS:
"If we reduce MSG (change to Absent), market share increases 
 from 32% to 45%. But if we also improve NutriScore from C to B,
 share jumps to 58%!"

IMPORTANT ASSUMPTIONS:
• All products are equally available
• No outside option (must choose one)
• Respondents make rational choices
• Market size is constant
```

## 8. Summary of Excel Output Features

### Core Deliverables

1. ✅ **Executive Summary** (1-page client overview)
   - Key findings in plain language
   - Top 3 preferred levels
   - Visual importance chart
   - Auto-generated recommendations

2. ✅ **Enhanced Attribute Importance** 
   - With confidence intervals
   - Auto-generated interpretation
   - Multiple visualizations
   - Importance ranking

3. ✅ **Enhanced Part-Worth Utilities**
   - With standard errors and CIs
   - Significance testing (p-values)
   - Auto-generated interpretation
   - Baseline level identification

4. ✅ **Comprehensive Model Diagnostics**
   - Overall fit statistics
   - Attribute-level diagnostics
   - Data quality indicators
   - Auto-generated interpretation guide

5. ✅ **Interactive Market Simulator** (The Crown Jewel)
   - Product configuration dropdowns
   - Automatic market share calculation
   - Utilities breakdown by attribute
   - Sensitivity analysis
   - What-if scenarios
   - Multiple visualizations

6. ✅ **Hidden Simulator Data**
   - Lookup tables for formulas
   - Attribute importance reference
   - Saved scenarios

7. ✅ **Detailed Technical Results**
   - Full model output
   - Coefficients table
   - Variance-covariance matrix

8. ✅ **Configuration Summary**
   - What was run
   - Reproducibility information

### Key Improvements Over ChatGPT Output

- ✅ Interactive simulation vs. static results
- ✅ Confidence intervals and significance testing
- ✅ Professional formatting and visualizations
- ✅ Client-ready executive summary
- ✅ Sensitivity analysis capabilities
- ✅ Clear interpretation guides
- ✅ Comprehensive error checking
- ✅ Automatic chart generation
- ✅ Market simulator with what-if analysis
- ✅ Production-ready professional output

---

**Implementation Priorities:**

**Phase 1 (Essential):**
- All 8 sheets created
- Basic formatting
- Market simulator with formulas
- Core charts

**Phase 2 (Enhanced):**
- Advanced formatting
- Cell comments
- Additional charts
- Sensitivity analysis

**Phase 3 (Polish):**
- Auto-generated text interpretation
- Scenario saving/loading
- Print optimization
- Additional what-if tools

---

**See Part 1 for Core Technical Specification**
**See Part 2 for Configuration, Testing & Validation details**
