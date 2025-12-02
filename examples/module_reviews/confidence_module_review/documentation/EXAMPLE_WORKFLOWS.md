# Turas Confidence - Example Workflows

**Version:** 1.0.0
**Last Updated:** 2025-11-17

---

## Table of Contents

1. [Workflow 1: Basic MOE Calculation](#workflow-1-basic-moe-calculation)
2. [Workflow 2: Comparing Multiple Methods](#workflow-2-comparing-multiple-methods)
3. [Workflow 3: Tracking Study with Bayesian Priors](#workflow-3-tracking-study-with-bayesian-priors)
4. [Workflow 4: Small Sample with Wilson Score](#workflow-4-small-sample-with-wilson-score)
5. [Workflow 5: Complex Weighted Survey with DEFF](#workflow-5-complex-weighted-survey-with-deff)
6. [Workflow 6: NPS Confidence Intervals](#workflow-6-nps-confidence-intervals)
7. [Workflow 7: Integration with Turas Tabs](#workflow-7-integration-with-turas-tabs)

---

## Workflow 1: Basic MOE Calculation

### Scenario
You conducted a simple random sample survey (n=1,000, no weights) and need to report margin of error for key metrics in a client presentation.

### Data Structure
```
survey_data.xlsx:
ResponseID | Q1_Satisfaction | Q2_Purchase | Q3_Recommend
1          | 4               | 1           | 8
2          | 5               | 1           | 9
3          | 3               | 0           | 6
```

### Configuration File

**config_basic_moe.xlsx - Sheet: Question_Analysis**
```
Question_Code | Question_Type | Target_Values | Methods
Q1            | proportion    | 4,5           | moe
Q2            | proportion    | 1             | moe
Q3            | mean          |               | moe
```

**Sheet: Settings**
```
Setting_Name      | Setting_Value
Data_File         | survey_data.xlsx
Output_File       | moe_results.xlsx
Confidence_Level  | 0.95
```

### Running the Analysis

```r
source("modules/confidence/R/00_main.R")

result <- run_confidence_analysis(
  config_path = "config_basic_moe.xlsx"
)
```

### Expected Output

**Study_Level sheet:**
```
Study_Metrics    | Value
─────────────────|──────
Total_Respondents| 1,000
Weighted_Base    | 1,000  (no weights applied)
Overall_DEFF     | 1.00   (simple random sample)
```

**Q1_Satisfaction sheet:**
```
Metric                  | Value
────────────────────────|──────
Question                | Q1 - Satisfaction (Top 2 Box)
Target_Values           | 4,5
Sample_Size_Unweighted  | 1,000
Sample_Size_Effective   | 1,000
Proportion              | 62.4%
CI_Lower_95             | 59.4%
CI_Upper_95             | 65.4%
Margin_of_Error         | ±3.0%
```

### Client Reporting

**Slide Text:**
```
Key Findings:
• 62% of customers are satisfied (Top 2 Box)
  Margin of error: ±3.0% at 95% confidence level

• 45% made a purchase in the last month
  Margin of error: ±3.1% at 95% confidence level

• Average NPS score: 7.2 out of 10
  Margin of error: ±0.3 at 95% confidence level
```

---

## Workflow 2: Comparing Multiple Methods

### Scenario
Your stakeholder questions whether MOE is appropriate for a metric near 95%. You want to compare MOE vs. Wilson Score to show the difference.

### Configuration

**Sheet: Question_Analysis**
```
Question_Code | Question_Type | Target_Values | Methods
Q_AWARENESS   | proportion    | 1             | moe,wilson,bootstrap
```

Sample data: 95% aware (950 of 1,000 respondents)

### Results Comparison

**Output sheet: Q_AWARENESS**
```
Method      | Estimate | CI_Lower | CI_Upper | Width
──────────--|──────────|──────────|──────────|──────
MOE         | 95.0%    | 93.6%    | 96.4%    | 2.8%
Wilson      | 95.0%    | 93.4%    | 96.3%    | 2.9%
Bootstrap   | 95.0%    | 93.5%    | 96.2%    | 2.7%
```

### Analysis

**MOE upper bound: 96.4%**
- Mathematically valid but close to 100% ceiling
- Formula: 0.95 ± 1.96 × √[(0.95 × 0.05)/1000] = 0.95 ± 0.014

**Wilson upper bound: 96.3%**
- Slightly narrower, accounts for binomial nature
- More conservative for extreme proportions

**Recommendation:**
For proportions > 90% or < 10%, use **Wilson Score** to avoid reporting intervals that approach or exceed 0-100% range.

---

## Workflow 3: Tracking Study with Bayesian Priors

### Scenario
You're conducting Wave 5 of a quarterly tracking study. You want to incorporate previous wave results to get more stable estimates for small subgroups.

### Wave 4 Results (Prior Information)
```
Satisfaction (Q1 Top 2): 58.3%
Sample size: 1,000
```

### Wave 5 Configuration

**Sheet: Question_Analysis**
```
Question_Code | Question_Type | Target_Values | Methods
Q1            | proportion    | 4,5           | moe,bayesian
```

**Sheet: Settings**
```
Setting_Name      | Setting_Value
Data_File         | wave5_data.xlsx
Confidence_Level  | 0.95
Prior_Mean        | 0.583          # Wave 4 result
Prior_Sample_Size | 1000           # Wave 4 base
Bayesian_Method   | beta_binomial
```

### Results

**Without Prior (MOE only):**
```
Wave 5 (n=500):
Satisfaction: 60.1%
95% CI: [55.8%, 64.4%]
Width: 8.6%
```

**With Prior (Bayesian):**
```
Wave 5 (n=500) + Prior (n=1000):
Posterior Mean: 59.5%
95% Credible Interval: [56.8%, 62.2%]
Width: 5.4%  ← 37% narrower!
```

### Interpretation

Bayesian approach:
1. Starts with Wave 4 result as prior belief
2. Updates with Wave 5 data
3. Produces weighted average: (2×58.3% + 1×60.1%) / 3 ≈ 59%
4. More stable estimate, narrower interval

**When to use:**
- Tracking studies where metric is stable
- Small subgroup analysis
- Early wave results (before full sample collected)

**When NOT to use:**
- First wave (no prior available)
- Metrics expected to change significantly
- When stakeholders don't understand Bayesian statistics

---

## Workflow 4: Small Sample with Wilson Score

### Scenario
You're analyzing a B2B survey where a rare industry segment has only n=45 respondents.

### Configuration

**Sheet: Question_Analysis**
```
Question_Code | Question_Type | Target_Values | Methods
Q_SATISFACTION| proportion    | 4,5           | wilson
```

**Sheet: Settings**
```
Min_Base_Size | 30    # Still calculate even for small n
```

### Results (n=45, 31 satisfied)

**MOE (Wald interval):**
```
Proportion: 68.9%
95% CI: [54.0%, 83.8%]  ← Very wide!
```

**Wilson Score:**
```
Proportion: 68.9%
95% CI: [53.9%, 81.1%]  ← Slightly narrower, more accurate
```

### Why Wilson is Better for Small Samples

1. **Accounts for discreteness:** With n=45, possible values jump by 2.2% (1/45)
2. **Better coverage:** Wilson has true 95% coverage even for small n
3. **Continuity correction:** Adjusts for the fact that proportions are discrete

**Rule of thumb:** Use Wilson when:
- n < 100, OR
- Proportion < 10% or > 90%

---

## Workflow 5: Complex Weighted Survey with DEFF

### Scenario
You conducted a stratified sample with post-stratification weights. You need to report effective sample sizes and design-adjusted MOE.

### Data Structure
```
survey_data.xlsx:
ResponseID | Age | Gender | Region | Weight | Q1 | Q2 | Q3
1          | 25  | M      | North  | 1.45   | 4  | 1  | 8
2          | 35  | F      | South  | 0.82   | 5  | 1  | 9
3          | 55  | M      | West   | 1.10   | 3  | 0  | 6
```

### Configuration

**Sheet: Question_Analysis**
```
Question_Code | Question_Type | Target_Values | Methods
Q1            | proportion    | 4,5           | moe
Q2            | proportion    | 1             | moe
Q3            | mean          |               | moe
```

**Sheet: Settings**
```
Data_File       | survey_data.xlsx
Weight_Variable | Weight
Calculate_DEFF  | TRUE
Output_File     | weighted_confidence.xlsx
```

### Results

**Study_Level sheet:**
```
Metric                  | Value
────────────────────────|──────
Total_Respondents       | 1,500
Total_Weighted          | 1,500.0
Overall_DEFF            | 1.35
Overall_Effective_N     | 1,111
Weight_CV               | 0.42
```

**Q1 sheet:**
```
Metric                  | Unweighted | Weighted
────────────────────────|────────────|──────────
Sample_Size             | 1,500      | 1,500
Effective_Sample_Size   | 1,500      | 1,111  ← DEFF impact
Proportion              | 61.2%      | 58.7%
Margin_of_Error         | ±2.5%      | ±2.9%  ← Wider due to DEFF
95% CI                  | [58.7%,63.7%] | [55.8%,61.6%]
```

### Interpreting DEFF

**DEFF = 1.35** means:
- Weighting reduces effective sample by 26% [(1.35-1)/1.35]
- To achieve same precision as SRS, would need 35% more respondents
- Acceptable for most surveys (< 2.0 threshold)

**Reporting to Stakeholders:**
```
"The survey included 1,500 respondents, with an effective sample
size of 1,111 after weighting adjustments (DEFF=1.35). This results
in a margin of error of ±2.9% at the 95% confidence level for
total sample estimates."
```

---

## Workflow 6: NPS Confidence Intervals

### Scenario
You need to report confidence intervals for Net Promoter Score and its components.

### NPS Calculation Reminder
```
NPS = % Promoters (9-10) - % Detractors (0-6)
```

### Configuration

**Sheet: Question_Analysis**
```
Question_Code | Question_Type | Target_Values | Methods
NPS_PROMOTERS | proportion    | 9,10          | wilson
NPS_DETRACTORS| proportion    | 0,1,2,3,4,5,6 | wilson
```

### Calculating NPS Confidence Interval

**Step 1: Get component CIs**
```
Promoters: 45.2% [42.3%, 48.2%]
Detractors: 18.5% [16.2%, 20.9%]
```

**Step 2: Calculate NPS**
```
NPS = 45.2% - 18.5% = 26.7
```

**Step 3: Calculate NPS CI (conservative approach)**
```
Lower: (42.3% - 20.9%) = 21.4
Upper: (48.2% - 16.2%) = 32.0

NPS = 27 [21, 32]
```

### Alternative: Bootstrap for NPS CI

**Configuration:**
```
Question_Code | Question_Type | Target_Values | Methods
NPS_SCORE     | custom_nps    |               | bootstrap
```

**Custom calculation in post-processing:**
```r
# Bootstrap NPS directly
bootstrap_nps <- function(data, indices) {
  d <- data[indices, ]
  promoters <- mean(d$Q_NPS %in% c(9,10))
  detractors <- mean(d$Q_NPS %in% 0:6)
  return((promoters - detractors) * 100)
}

library(boot)
boot_results <- boot(data, bootstrap_nps, R=1000)
boot.ci(boot_results, type="perc")

# Result: NPS = 27 [22, 31]
```

---

## Workflow 7: Integration with Turas Tabs

### Scenario
You've run cross-tabs with Turas Tabs and now want to add confidence intervals to key metrics for client report.

### Step 1: Run Tabs Analysis

```r
source("modules/tabs/run_tabs.R")
# Generates: crosstabs_output.xlsx
```

### Step 2: Identify Key Metrics

From Tabs output, identify metrics needing CIs:
- Overall satisfaction (Q1 Top 2 Box): 62.4%
- Purchase intent (Q2): 45.2%
- NPS: 27

### Step 3: Configure Confidence Analysis

**Sheet: Question_Analysis**
```
Question_Code | Question_Type | Target_Values | Methods
Q1            | proportion    | 4,5           | wilson
Q2            | proportion    | 1             | wilson
NPS_PROM      | proportion    | 9,10          | wilson
NPS_DETR      | proportion    | 0,1,2,3,4,5,6 | wilson
```

### Step 4: Run Confidence Module

```r
source("modules/confidence/R/00_main.R")
result <- run_confidence_analysis("confidence_config.xlsx")
```

### Step 5: Append to Tabs Output

Manually add confidence intervals to Tabs summary:

**Enhanced Tabs Output:**
```
Metric              | Total  | Male   | Female | 18-34  | 35+
────────────────────|────────|────────|────────|────────|────
Satisfaction (Top 2)| 62.4%  | 65.1%A | 59.8%  | 60.2%  | 63.9%
  95% CI            | ±3.0%  | ±4.4%  | ±4.1%  | ±4.8%  | ±3.8%

Purchase Intent     | 45.2%  | 48.3%  | 42.4%B | 50.1%A | 41.8%
  95% CI            | ±3.1%  | ±4.6%  | ±4.2%  | ±4.9%  | ±3.9%

NPS                 | 27     | 32A    | 23     | 35A    | 21
  95% CI            | ±7     | ±10    | ±9     | ±12    | ±8
```

---

## Appendix: Method Selection Guide

### Decision Tree

```
START
  ↓
Is n < 100?
  ├─ YES → Use Wilson or Bootstrap
  └─ NO → Continue
       ↓
Is proportion near 0% or 100%?
  ├─ YES → Use Wilson
  └─ NO → Continue
       ↓
Is this a tracking study?
  ├─ YES → Consider Bayesian
  └─ NO → Continue
       ↓
Is distribution non-normal?
  ├─ YES → Use Bootstrap
  └─ NO → Use MOE
```

### Method Comparison Table

| Method | Best For | Pros | Cons | Time |
|--------|----------|------|------|------|
| **MOE** | Standard proportions, n>100 | Fast, familiar | Can exceed [0,1] | <1 sec |
| **Wilson** | Small n, extreme proportions | Accurate coverage | Less familiar | <1 sec |
| **Bootstrap** | Non-normal, complex stats | No assumptions | Slow | 5-30 sec |
| **Bayesian** | Tracking, small subgroups | Incorporates prior | Needs prior specification | 1-5 sec |

---

**End of Example Workflows**

*Version 1.0.0 | Turas Confidence Module | Real-World Use Cases*
