# Turas Confidence - Quick Start Guide

**Version:** 1.0
**Estimated Time:** 10 minutes
**Difficulty:** Intermediate

---

## What is Turas Confidence?

Turas Confidence calculates statistical confidence intervals for survey data using multiple methods:
- **Margin of Error (MOE)** - Traditional approach
- **Wilson Score** - More accurate for proportions
- **Bootstrap** - Non-parametric resampling
- **Bayesian** - Credible intervals with prior knowledge

It also calculates **Design Effect (DEFF)** to quantify impact of complex sampling and weighting.

---

## Prerequisites

```r
install.packages(c("openxlsx", "readxl", "survey"))
```

### What You Need
1. **Survey data file** (.xlsx or .csv)
2. **Configuration file** (.xlsx) specifying:
   - Questions to analyze
   - Methods to use
   - Confidence level (default 95%)

---

## Quick Start (5 Minutes)

### Step 1: Prepare Configuration

Create `config.xlsx` with two sheets:

**Sheet 1: Question_Analysis**
```
Question_Code | Question_Type | Target_Values | Methods
Q1            | proportion    | 1,2           | moe,wilson,bootstrap
Q2            | mean          |               | moe,bootstrap,bayesian
```

**Sheet 2: Settings**
```
Setting_Name      | Setting_Value
Data_File         | survey_data.xlsx
Weight_Variable   | weight
Output_File       | confidence_output.xlsx
Confidence_Level  | 0.95
Bootstrap_Iterations | 1000
```

### Step 2: Run Analysis

**Using GUI:**
```r
source("modules/confidence/run_confidence_gui.R")
# 1. Browse to config file
# 2. Click "Run Analysis"
# 3. Wait 30-60 seconds
```

**Using Script:**
```r
source("modules/confidence/R/00_main.R")

result <- run_confidence_analysis(
  config_path = "config.xlsx"
)
```

### Step 3: Review Output

Output Excel file contains:

**Sheet 1: Study_Level_DEFF**
- Overall weighting efficiency
- Design effect by question
- Effective sample sizes

**Sheet 2-N: Question Results**
One sheet per question with:
```
Method      | Estimate | CI_Lower | CI_Upper | Effective_N | MOE
────────────|──────────|──────────|──────────|─────────────|────
MOE         | 45.2%    | 42.1%    | 48.3%    | 856         | 3.1%
Wilson      | 45.2%    | 42.3%    | 48.2%    | 856         | 2.9%
Bootstrap   | 45.3%    | 42.0%    | 48.5%    | 856         | 3.2%
Bayesian    | 45.1%    | 42.2%    | 48.0%    | 856         | 2.9%
```

---

## Understanding Methods

### Margin of Error (MOE)
**Best for:** Standard proportions, large samples
**Formula:** ±1.96 × √[p(1-p)/n]
**Pros:** Industry standard, easy to explain
**Cons:** Can exceed 0-100% range for extreme proportions

### Wilson Score
**Best for:** Small samples, extreme proportions (near 0% or 100%)
**Formula:** Adjusted proportion with continuity correction
**Pros:** Always stays within 0-100%
**Cons:** Less familiar to stakeholders

### Bootstrap
**Best for:** Complex statistics, non-normal distributions
**Method:** Resample data 1,000+ times
**Pros:** No distributional assumptions
**Cons:** Computationally intensive

### Bayesian
**Best for:** Small samples, incorporating prior knowledge
**Method:** Beta-Binomial conjugate prior
**Pros:** Can incorporate previous waves
**Cons:** Requires specifying prior

---

## Configuration Options

### Question Types

**`proportion`** - Percent answering specific values
Example: % who selected "Very Satisfied" (codes 4,5)
```
Question_Code | Question_Type | Target_Values
Q1            | proportion    | 4,5
```

**`mean`** - Average value
Example: Mean satisfaction score (1-5 scale)
```
Question_Code | Question_Type | Target_Values
Q2            | mean          |               [leave blank]
```

### Methods

Specify in `Methods` column (comma-separated):
- `moe` - Margin of Error
- `wilson` - Wilson Score Interval
- `bootstrap` - Bootstrap Resampling
- `bayesian` - Bayesian Credible Interval

Example: `moe,wilson,bootstrap`

### Advanced Settings

```
Bootstrap_Iterations    | 1000           [default: 1000]
Prior_Mean             | 0.5            [Bayesian prior, default: 0.5]
Prior_Sample_Size      | 100            [Bayesian prior strength]
Min_Base_Size          | 30             [Skip if n < 30]
```

---

## Common Use Cases

### Case 1: Standard MOE for Client Report
```
Methods: moe
Confidence_Level: 0.95
```
Output: "±3.1% at 95% confidence"

### Case 2: Small Sample with Wilson
```
Methods: wilson
# Use when n < 100 or proportion near 0% or 100%
```

### Case 3: Tracking Study with Bayesian
```
Methods: bayesian
Prior_Mean: 0.45          # Last wave result
Prior_Sample_Size: 500    # Last wave base
```
Output: Credible interval incorporating prior data

### Case 4: Complex Weighted Data
```
Weight_Variable: weight
Calculate_DEFF: TRUE
```
Output: Design-adjusted effective sample sizes

---

## Interpreting DEFF

**Design Effect (DEFF)** measures efficiency loss from weighting:

| DEFF | Meaning | Action |
|------|---------|--------|
| 1.0 | No efficiency loss | Great! Weighting not impacting precision |
| 1.5 | 50% larger sample needed | Acceptable for most surveys |
| 2.0 | Sample worth half as much | Review weight efficiency |
| 3.0+ | Severe efficiency loss | Check for extreme weights |

**Formula:** DEFF = (n × Σw²) / (Σw)²

**Effective Sample Size:** n_eff = n / DEFF

---

## Troubleshooting

### ❌ "Not enough data for bootstrap"
**Fix:** Reduce `Bootstrap_Iterations` or increase sample size

### ❌ "Confidence interval exceeds [0,1]"
**Fix:** Use `wilson` method instead of `moe` for extreme proportions

### ❌ "Weight variable has negative values"
**Fix:** Check your weighting - negative weights are invalid

### ⚠️ "DEFF > 2.0"
**Review:** Weighting may be too aggressive. Consider:
- Trimming extreme weights
- Using raking instead of post-stratification
- Increasing sample size

---

## Best Practices

✅ **DO:**
- Use Wilson for proportions near 0% or 100%
- Calculate DEFF for weighted data
- Use multiple methods and compare results
- Report effective N in addition to raw N

❌ **DON'T:**
- Use MOE for very small samples (n < 30)
- Ignore DEFF > 2.0 (precision seriously impacted)
- Report only MOE without method specification
- Use Bayesian without understanding the prior

---

## Next Steps

1. Review **USER_MANUAL.md** for comprehensive feature documentation
2. See **EXAMPLE_WORKFLOWS.md** for real-world scenarios
3. Check **MAINTENANCE_GUIDE.md** for technical details

---

**Ready to go!** You can now calculate rigorous confidence intervals for your survey data.

*Version 1.0.0 | Quick Start | Turas Confidence Module*
