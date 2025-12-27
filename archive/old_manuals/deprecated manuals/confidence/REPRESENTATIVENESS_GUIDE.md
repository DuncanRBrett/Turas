# QUOTA REPRESENTATIVENESS & WEIGHT DIAGNOSTICS GUIDE

**Module:** Turas Confidence Analysis
**Feature Version:** 2.1.0
**Date:** December 1, 2025
**Status:** ✅ PRODUCTION READY

---

## EXECUTIVE SUMMARY

The confidence module now includes **quota representativeness checking** and **weight concentration diagnostics** to assess sample quality after weighting.

**Key Features:**
- ✅ Compare weighted sample vs population targets (quota validation)
- ✅ Support simple quotas (Gender, Age, Region, etc.)
- ✅ Support nested quotas (Gender × Age, Region × Income, etc.)
- ✅ Automatic traffic-light flagging (GREEN/AMBER/RED)
- ✅ Weight concentration metrics (identify dominant cases)
- ✅ **OPTIONAL** - works with or without population targets

---

## WHEN TO USE THIS

### Use Representativeness Checking When:
1. **Quota-based studies**: You have population targets to achieve
2. **Post-weighting validation**: Verify weighting achieved desired margins
3. **Sample quality checks**: Identify over/under-representation

### Use Weight Diagnostics When:
1. **Weighted surveys**: Assess weight concentration
2. **Quality control**: Flag unstable weights (few cases dominate)
3. **DEFF investigation**: Understand why design effect is high

### Skip This Feature When:
- Unweighted convenience samples (no targets, no weights)
- Exploratory studies without representativeness goals

---

## HOW IT WORKS

### Margin Comparison
Compares **weighted sample proportions** vs **population targets**:

```
Diff_pp = Weighted_Sample_% - Target_%
```

**Example:**
```
Variable: Gender
Category: Male
Target: 48.0%
Weighted Sample: 45.3%
Diff_pp: -2.7pp  → AMBER flag (under-represented)
```

**Traffic-Light Flags:**
- 🟢 **GREEN**: |Difference| < 2pp - Excellent representativeness
- 🟡 **AMBER**: |Difference| 2-5pp - Acceptable, minor deviation
- 🔴 **RED**: |Difference| ≥ 5pp - Concerning, substantial deviation

### Weight Concentration
Measures how much total weight is held by top respondents:

```
Top_5pct_Share = (Sum of top 5% weights) / (Total weight) × 100
```

**Example:**
```
Top 5% of cases hold 22.3% of total weight → MODERATE concern
```

**Flags:**
- 🟢 **LOW**: Top 5% < 15% - Healthy distribution
- 🟡 **MODERATE**: Top 5% 15-25% - Acceptable
- 🔴 **HIGH**: Top 5% > 25% - Concerning (few cases dominate)

---

## CONFIGURATION

### Step 1: Add Population_Margins Sheet (Optional)

Add a new sheet called **`Population_Margins`** to your config workbook.

**Required Columns:**
| Column | Description | Example |
|--------|-------------|---------|
| `Variable` | Variable name in dataset (or comma-separated for nested) | `Gender` or `Gender,Age_Group` |
| `Category_Label` | Human-readable label | `Male`, `18-24`, `Male, 18-24` |
| `Category_Code` | Code as it appears in data | `1`, `M`, `Male`, `Male_18-24` |
| `Target_Prop` | Target proportion (0-1, **not** percentage) | `0.48`, `0.15`, `0.07` |
| `Include` | Y/N to enable/disable this target | `Y` |

**Important Notes:**
- `Target_Prop` must be between 0 and 1 (e.g., use `0.48` not `48`)
- For each variable, targets should sum to ≈ 1.0 (validated automatically)
- `Category_Code` must match data exactly (case-sensitive)
- `Include` column is optional (defaults to `Y` if omitted)
- **This sheet is OPTIONAL** - if not provided, only weight diagnostics run

---

## EXAMPLES

### Example 1: Simple Quotas

**Scenario:** National survey with Gender, Age, Region quotas

**Population_Margins Sheet:**

| Variable | Category_Label | Category_Code | Target_Prop | Include |
|----------|----------------|---------------|-------------|---------|
| Gender | Male | Male | 0.48 | Y |
| Gender | Female | Female | 0.52 | Y |
| Age_Group | 18-24 | 18-24 | 0.15 | Y |
| Age_Group | 25-34 | 25-34 | 0.20 | Y |
| Age_Group | 35-44 | 35-44 | 0.18 | Y |
| Age_Group | 45-54 | 45-54 | 0.22 | Y |
| Age_Group | 55+ | 55+ | 0.25 | Y |
| Region | Gauteng | GP | 0.25 | Y |
| Region | Western Cape | WC | 0.11 | Y |
| Region | KZN | KZN | 0.21 | Y |
| Region | Eastern Cape | EC | 0.13 | Y |
| Region | Other | Other | 0.30 | Y |

**Notes:**
- Gender sums to 1.00 (0.48 + 0.52)
- Age groups sum to 1.00 (0.15 + 0.20 + 0.18 + 0.22 + 0.25)
- Regions sum to 1.00 (0.25 + 0.11 + 0.21 + 0.13 + 0.30)
- `Category_Code` matches data exactly (`GP`, `WC`, etc.)

---

### Example 2: Nested Quotas

**Scenario:** National survey with Gender × Age nested quotas

**Population_Margins Sheet:**

| Variable | Category_Label | Category_Code | Target_Prop | Include |
|----------|----------------|---------------|-------------|---------|
| Gender,Age_Group | Male, 18-24 | Male_18-24 | 0.07 | Y |
| Gender,Age_Group | Female, 18-24 | Female_18-24 | 0.08 | Y |
| Gender,Age_Group | Male, 25-34 | Male_25-34 | 0.10 | Y |
| Gender,Age_Group | Female, 25-34 | Female_25-34 | 0.10 | Y |
| Gender,Age_Group | Male, 35-44 | Male_35-44 | 0.09 | Y |
| Gender,Age_Group | Female, 35-44 | Female_35-44 | 0.09 | Y |
| Gender,Age_Group | Male, 45-54 | Male_45-54 | 0.10 | Y |
| Gender,Age_Group | Female, 45-54 | Female_45-54 | 0.12 | Y |
| Gender,Age_Group | Male, 55+ | Male_55+ | 0.12 | Y |
| Gender,Age_Group | Female, 55+ | Female_55+ | 0.13 | Y |

**Key Points for Nested Quotas:**
1. **Variable column:** Comma-separated list: `Gender,Age_Group`
2. **Category_Code:** Underscore separator: `Male_18-24`
   - Code is created by combining variable values with `_`
   - If `Gender = "Male"` and `Age_Group = "18-24"`, code is `"Male_18-24"`
3. **Targets sum to 1.00** across all nested cells
4. **Must match data format exactly**

**How Nested Matching Works:**
```r
# For data row: Gender = "Male", Age_Group = "18-24"
# System creates: interaction_code = "Male_18-24"
# Matches against: Category_Code = "Male_18-24" in config
```

---

### Example 3: Numeric Codes

**Scenario:** Data uses numeric codes (1, 2, 3) but you want readable labels

**Your Data:**
```
Gender: 1 = Male, 2 = Female
Age: 1 = 18-24, 2 = 25-34, 3 = 35-44, etc.
```

**Population_Margins Sheet:**

| Variable | Category_Label | Category_Code | Target_Prop | Include |
|----------|----------------|---------------|-------------|---------|
| Gender | Male | 1 | 0.48 | Y |
| Gender | Female | 2 | 0.52 | Y |
| Age | 18-24 | 1 | 0.15 | Y |
| Age | 25-34 | 2 | 0.20 | Y |
| Age | 35-44 | 3 | 0.18 | Y |

**Notes:**
- `Category_Code` = `1`, `2`, `3` (matches data)
- `Category_Label` = readable labels for output
- Output shows both: `"Male (Code: 1)"`

---

### Example 4: Client-Specific Variables

**Scenario:** University study with course-specific quotas

**Population_Margins Sheet:**

| Variable | Category_Label | Category_Code | Target_Prop | Include |
|----------|----------------|---------------|-------------|---------|
| Course | Computer Science | COMP | 0.35 | Y |
| Course | Business | BUS | 0.25 | Y |
| Course | Engineering | ENG | 0.20 | Y |
| Course | Arts | ARTS | 0.20 | Y |
| Year_of_Study | First Year | 1 | 0.30 | Y |
| Year_of_Study | Second Year | 2 | 0.25 | Y |
| Year_of_Study | Third Year | 3 | 0.25 | Y |
| Year_of_Study | Fourth Year+ | 4 | 0.20 | Y |
| Channel | Online | online | 0.60 | Y |
| Channel | In-Person | in_person | 0.40 | Y |

---

## EXCEL OUTPUT

### New Sheet: Representativeness_Weights

**Contains Two Blocks:**

#### Block A: Weight Distribution & Concentration

| n_weights | Top_1pct_Share | Top_5pct_Share | Top_10pct_Share | Concentration_Flag |
|-----------|----------------|----------------|-----------------|-------------------|
| 487 | 3.2% | 14.8% | 24.1% | LOW |

**Interpretation:**
- `n_weights`: Number of valid weights
- `Top_5pct_Share`: % of total weight held by top 5% of cases
- `Concentration_Flag`: Overall assessment

#### Block B: Population Margin Comparison

| Variable | Category_Label | Category_Code | Target_Pct | Weighted_Sample_Pct | Diff_pp | Abs_Diff_pp | Flag |
|----------|----------------|---------------|------------|---------------------|---------|-------------|------|
| Gender | Male | Male | 48.0 | 45.3 | -2.7 | 2.7 | 🟡 AMBER |
| Gender | Female | Female | 52.0 | 54.7 | +2.7 | 2.7 | 🟡 AMBER |
| Age_Group | 18-24 | 18-24 | 15.0 | 13.2 | -1.8 | 1.8 | 🟢 GREEN |
| Age_Group | 25-34 | 25-34 | 20.0 | 21.1 | +1.1 | 1.1 | 🟢 GREEN |
| Region | Gauteng | GP | 25.0 | 30.1 | +5.1 | 5.1 | 🔴 RED |

**Flag Column:**
- Color-coded in Excel (green background for GREEN, yellow for AMBER, red for RED)
- Conditional formatting applied automatically

**Interpretation Notes Included:**
```
Difference from Target (in percentage points):
  GREEN: |Difference| < 2pp - Excellent representativeness
  AMBER: |Difference| 2-5pp - Acceptable, minor deviation
  RED: |Difference| >= 5pp - Concerning, substantial deviation

Diff_pp = Weighted_Sample_Pct - Target_Pct
Positive values: Over-represented vs target
Negative values: Under-represented vs target
```

---

## RUNNING THE ANALYSIS

### Option 1: With Population Targets

```r
# Your config file includes Population_Margins sheet
setwd("modules/confidence")
source("R/00_main.R")

results <- run_confidence_analysis(
  config_path = "path/to/config_with_quotas.xlsx",
  verbose = TRUE
)

# Check margin comparison
margin_comp <- attr(results$study_stats, "margin_comparison")
print(margin_comp)

# Check weight concentration
weight_conc <- attr(results$study_stats, "weight_concentration")
print(weight_conc)
```

**Console Output:**
```
STEP 3/6: Calculating study-level statistics...
  ✓ Actual n: 500
  ✓ Effective n: 427
  ✓ DEFF: 1.17
  ✓ Weight concentration: Top 5% hold 14.8% of weight (LOW)
  ✓ Margin comparison: 14 targets (10 GREEN, 3 AMBER, 1 RED)
```

### Option 2: Without Population Targets

```r
# Your config file does NOT have Population_Margins sheet
# System will still calculate weight diagnostics

results <- run_confidence_analysis(
  config_path = "path/to/config_no_quotas.xlsx",
  verbose = TRUE
)

# Margin comparison will be NULL
margin_comp <- attr(results$study_stats, "margin_comparison")
# NULL

# Weight concentration still works
weight_conc <- attr(results$study_stats, "weight_concentration")
print(weight_conc)
```

**Console Output:**
```
STEP 3/6: Calculating study-level statistics...
  ✓ Actual n: 500
  ✓ Effective n: 427
  ✓ DEFF: 1.17
  ✓ Weight concentration: Top 5% hold 14.8% of weight (LOW)
  - Population margins: (optional sheet not provided)
```

---

## TESTING

### Run Representativeness Test

```r
setwd("modules/confidence")
source("tests/test_representativeness.R")
```

**What the test does:**
1. Creates synthetic survey data with known quota deviations
2. Sets up simple quotas (Gender, Age, Region)
3. Sets up nested quotas (Gender × Age)
4. Runs full analysis pipeline
5. Validates all calculations
6. Tests with and without Population_Margins sheet

**Expected output:**
```
✓ Synthetic quota survey data written
✓ Test configuration workbook written with Population_Margins sheet
  - 14 simple margin targets (Gender, Age, Region)
  - 4 nested quota targets (Gender x Age)

Running run_confidence_analysis() with quota targets...

STEP 3/6: Calculating study-level statistics...
  ✓ Weight concentration: Top 5% hold 22.3% of weight (MODERATE)
  ✓ Margin comparison: 18 targets (12 GREEN, 4 AMBER, 2 RED)

=== WEIGHT CONCENTRATION DIAGNOSTICS ===
  n_weights Top_1pct_Share Top_5pct_Share Top_10pct_Share Concentration_Flag
1       495            5.2           22.3            36.8           MODERATE

=== MARGIN COMPARISON RESULTS ===
[Table showing all 18 margin targets with flags]

✓ All representativeness functionality verified
```

---

## INTERPRETING RESULTS

### Scenario 1: All GREEN Flags 🟢

**What it means:**
- Excellent quota achievement
- Weighted sample matches population within 2pp for all variables
- High confidence in representativeness

**Action:**
- None required
- Proceed with confidence in sample quality

---

### Scenario 2: Some AMBER Flags 🟡

**Example:**
```
Gender - Male: Target 48%, Actual 45.3% (-2.7pp) → AMBER
```

**What it means:**
- Minor deviation from target (2-5pp)
- Acceptable in most research contexts
- Common in practice (hard to hit all quotas exactly)

**Action:**
- Document in methodology section
- Consider acceptable if only a few AMBER flags
- Investigate if many AMBER flags (may indicate weighting issues)

---

### Scenario 3: RED Flags 🔴

**Example:**
```
Region - Gauteng: Target 25%, Actual 30.1% (+5.1pp) → RED
```

**What it means:**
- Substantial deviation from target (>5pp)
- Sample over-represents this group
- May bias results if Gauteng respondents differ from other regions

**Possible Causes:**
1. **Weighting didn't work:** Weights not constructed to hit this target
2. **Conflicting quotas:** Can't satisfy all quotas simultaneously (Gender × Age × Region)
3. **Data quality:** Wrong target specified, or variable coding mismatch

**Action:**
1. **Check weights:** Were they constructed to hit Region targets?
2. **Review targets:** Is 25% correct for Gauteng?
3. **Check variable:** Does `Region = "GP"` in data match `Category_Code = "GP"` in config?
4. **Nested quotas:** If using nested quotas, some simple margins may not match (expected)
5. **Consider reweighting:** If critical, revise weights to better achieve targets

---

### Scenario 4: HIGH Weight Concentration 🔴

**Example:**
```
Top 5% of cases hold 28.7% of total weight → HIGH
```

**What it means:**
- A small number of respondents dominate the weighted sample
- 5% of cases carry nearly 30% of influence
- Unstable estimates possible (if those few cases are outliers)

**Possible Causes:**
1. **Extreme weights needed:** To hit targets, some cases got very high weights
2. **Small subgroups:** Hard-to-reach demographic has few cases, high weights
3. **Weight trimming not applied:** Weights were not capped

**Action:**
1. **Review DEFF:** Is it also high (>2.0)? Confirms concentration issue
2. **Check top cases:** Identify which respondents have highest weights - do they share characteristics?
3. **Consider trimming:** Cap maximum weight (e.g., at 4.0 or 5.0)
4. **Sensitivity analysis:** Re-run key analyses excluding top 5% - do results change substantially?

---

## TROUBLESHOOTING

### Issue 1: "Margin comparison is NULL"

**Symptoms:**
- No margin comparison results
- Console shows: `- Population margins: (optional sheet not provided)`

**Cause:**
- Config file missing `Population_Margins` sheet

**Solution:**
- Add `Population_Margins` sheet to config workbook
- Or accept that only weight diagnostics will run

---

### Issue 2: "Variable 'Gender' proportions sum to 0.97 (should be 1.0)"

**Symptoms:**
- Warning during config loading

**Cause:**
- Target proportions don't sum to 1.0
- Example: Male 0.48 + Female 0.48 = 0.96 (missing 0.04)

**Solution:**
- Adjust targets to sum to 1.00
- Example: Male 0.48 + Female 0.52 = 1.00

---

### Issue 3: Flag is "MISSING_VAR"

**Symptoms:**
- Margin comparison shows `Flag = "MISSING_VAR"`
- `Weighted_Sample_Pct` is NA

**Cause:**
- Variable in `Population_Margins` doesn't exist in data
- Example: Config says `Gender`, but data has `gender` (case-sensitive!)

**Solution:**
- Check variable names match exactly (case-sensitive)
- Common issues:
  - `Gender` vs `gender`
  - `Age_Group` vs `age_group`
  - `Region` vs `region`

---

### Issue 4: Flag is "NO_SAMPLE"

**Symptoms:**
- Margin comparison shows `Flag = "NO_SAMPLE"`
- `Weighted_Sample_Pct` is 0%

**Cause:**
- Category exists in targets but has 0 cases in data
- Example: Target for `Gender = "Other"` but no respondents selected it

**Solution:**
- Check if category code matches data
  - Config: `Category_Code = "Other"`
  - Data: Does anyone have `Gender = "Other"`?
- If truly no cases, consider:
  - Removing from targets (set `Include = "N"`)
  - Or documenting as data quality issue

---

### Issue 5: Nested quota not calculated

**Symptoms:**
- No results for `Gender,Age_Group` nested quotas
- Only simple margins shown

**Cause:**
- Category_Code doesn't match data interaction
- Example: Config has `"Male_18-24"` but data creates `"Male_1"` (numeric age code)

**Solution:**
- Check how nested code is created:
  ```r
  # System creates: paste(Gender, Age_Group, sep = "_")
  # If Gender = "Male" and Age_Group = "18-24"
  # Result: "Male_18-24"
  ```
- Ensure `Category_Code` matches this exactly

---

## TECHNICAL DETAILS

### Statistical Methods

**Margin Comparison:**
```r
# For each category:
p_target = Target_Prop
p_weighted = sum(weights[category]) / sum(weights)

Diff_pp = (p_weighted - p_target) * 100

Flag = ifelse(abs(Diff_pp) < 2, "GREEN",
              ifelse(abs(Diff_pp) < 5, "AMBER", "RED"))
```

**Weight Concentration:**
```r
# Sort weights in descending order
w_sorted = sort(weights, decreasing = TRUE)

# Top 5% of cases
n_top5 = ceiling(0.05 * n)

# Share of total weight
Top_5pct_Share = sum(w_sorted[1:n_top5]) / sum(weights) * 100

# Flag
Flag = ifelse(Top_5pct_Share < 15, "LOW",
              ifelse(Top_5pct_Share < 25, "MODERATE", "HIGH"))
```

### Code Location

| Function | File | Purpose |
|----------|------|---------|
| `load_population_margins_sheet()` | `01_load_config.R` | Load and validate Population_Margins |
| `compute_margin_comparison()` | `03_study_level.R` | Compare sample vs targets |
| `compute_simple_margin()` | `03_study_level.R` | Single variable comparison |
| `compute_nested_margin()` | `03_study_level.R` | Multi-variable comparison |
| `compute_weight_concentration()` | `03_study_level.R` | Weight distribution metrics |
| `add_representativeness_sheet()` | `07_output.R` | Generate Excel output |

### Data Flow

```
1. load_population_margins_sheet()
   ↓
2. Config validation (targets sum to 1.0)
   ↓
3. Main analysis runs
   ↓
4. compute_weight_concentration(weights)
   ↓
5. compute_margin_comparison(data, weights, targets)
   ↓
6. Attach results to study_stats as attributes
   ↓
7. add_representativeness_sheet(wb, study_stats)
   ↓
8. Excel file with new sheet
```

---

## BEST PRACTICES

### 1. Always Validate Targets
- Check targets sum to 1.0 for each variable
- Review warnings during config loading
- Compare against census/official statistics

### 2. Document Deviations
- RED flags should be documented in methodology
- Explain why targets weren't achieved
- Assess potential impact on findings

### 3. Weight Concentration
- Review alongside DEFF
- HIGH concentration → consider weight trimming
- Run sensitivity analyses

### 4. Nested vs Simple Quotas
- Nested quotas are stricter (harder to achieve all cells)
- If using nested, expect some simple margins to be slightly off
- Prioritize which quotas matter most

### 5. Iterative Weighting
- Run analysis, check representativeness
- Adjust weights if needed
- Re-run until acceptable
- Document number of iterations

---

## FREQUENTLY ASKED QUESTIONS

**Q: Is Population_Margins sheet required?**
A: No. If not provided, weight diagnostics still run, but no margin comparison.

**Q: Can I have both simple and nested quotas?**
A: Yes. Include both in Population_Margins. Each is evaluated independently.

**Q: What if my quotas conflict (can't satisfy all)?**
A: Common with complex nested quotas. Prioritize critical quotas, document trade-offs.

**Q: How do I match numeric codes in data?**
A: Set `Category_Code` to the numeric code as a character: `"1"`, `"2"`, etc.

**Q: Can I disable certain targets temporarily?**
A: Yes. Set `Include = "N"` in Population_Margins sheet.

**Q: What's a good Top_5pct_Share value?**
A: < 15% is healthy. 15-25% is acceptable. > 25% warrants investigation.

**Q: My targets are in percentages (48%, not 0.48). What do I do?**
A: Divide by 100. Use `0.48` not `48` in Target_Prop column.

**Q: Can I use this for longitudinal/wave comparisons?**
A: This module checks ONE study. For wave comparisons, use the tracker module.

---

## CHANGELOG

**Version 2.1.0 (2025-12-01)**
- Initial release of representativeness feature
- Simple margin comparison
- Nested quota support
- Weight concentration diagnostics
- Excel output with traffic-light formatting

---

## SUPPORT

**For questions or issues:**
1. Check this guide first
2. Run `test_representativeness.R` to verify installation
3. Review console output for warning messages
4. Check config file carefully (column names, target values)

**Common mistakes:**
- Using percentages (48) instead of proportions (0.48)
- Variable names don't match data exactly (case-sensitive)
- Nested quota Category_Code doesn't match underscore format
- Targets don't sum to 1.0

---

## EXAMPLE: Complete Workflow

**Scenario:** National study with Gender and Age quotas

**Step 1: Prepare config workbook**

Add sheet `Population_Margins`:

| Variable | Category_Label | Category_Code | Target_Prop | Include |
|----------|----------------|---------------|-------------|---------|
| Gender | Male | Male | 0.48 | Y |
| Gender | Female | Female | 0.52 | Y |
| Age_Group | 18-24 | 18-24 | 0.15 | Y |
| Age_Group | 25-34 | 25-34 | 0.20 | Y |
| Age_Group | 35-44 | 35-44 | 0.18 | Y |
| Age_Group | 45-54 | 45-54 | 0.22 | Y |
| Age_Group | 55+ | 55+ | 0.25 | Y |

**Step 2: Run analysis**

```r
setwd("modules/confidence")
source("R/00_main.R")

results <- run_confidence_analysis(
  config_path = "configs/national_study_2024.xlsx",
  verbose = TRUE
)
```

**Step 3: Check console**

```
✓ Configuration loaded successfully
  - Population margins: 7 targets

STEP 3/6: Calculating study-level statistics...
  ✓ Weight concentration: Top 5% hold 16.2% of weight (MODERATE)
  ✓ Margin comparison: 7 targets (5 GREEN, 2 AMBER, 0 RED)
```

**Step 4: Review Excel output**

Open `output/confidence_results.xlsx`

Navigate to sheet: `Representativeness_Weights`

Check:
- Weight concentration flag (MODERATE - acceptable)
- Margin comparison table (2 AMBER - document in methodology)

**Step 5: Document findings**

```
Sample Quality Assessment:

Weight Distribution: MODERATE concentration (Top 5% hold 16.2% of weight).
Acceptable for analysis. DEFF = 1.18 indicates modest precision loss.

Quota Achievement:
- Gender: Male 46.8% (target 48%, -1.2pp) - GREEN ✓
- Gender: Female 53.2% (target 52%, +1.2pp) - GREEN ✓
- Age 18-24: 12.9% (target 15%, -2.1pp) - AMBER (minor under-representation)
- Age 25-34: 22.3% (target 20%, +2.3pp) - AMBER (minor over-representation)
- Age 35-44: 18.1% (target 18%, +0.1pp) - GREEN ✓
- Age 45-54: 21.8% (target 22%, -0.2pp) - GREEN ✓
- Age 55+: 24.9% (target 25%, -0.1pp) - GREEN ✓

Overall assessment: Sample achieves good representativeness. Minor deviations
in younger age groups (18-34) noted but within acceptable tolerance (<3pp).
```

**Done!** ✅

---

**END OF GUIDE**
