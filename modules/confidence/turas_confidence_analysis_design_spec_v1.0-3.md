# Turas Confidence Analysis Module - Design Specification v1.0

## 1. Overview

### 1.1 Purpose
The Confidence Analysis Module is an independent, optional module for the Turas survey analysis platform. It provides additional statistical confidence checks for crosstab results, particularly useful for market research applications using quota samples, online self-completion, and occasional probability samples.

### 1.2 Context
- **Platform**: R-based modular system accessed via RStudio/Shiny
- **Use case**: Market research, primarily single-wave studies, with future extension to tracking studies
- **User profile**: Market researchers who need practical confidence checks, not academic statisticians
- **Integration**: Standalone module that references existing Turas files but operates independently

### 1.3 Scope - Phase 1
**In Scope:**
- Study-level settings (effective sample size, multiple comparison adjustments)
- Question-level confidence methods for proportions and means
- Manual prior specification for Bayesian credible intervals
- Batch processing (not real-time)
- Support for up to 200 questions per analysis
- User-configurable decimal separator (, or .)

**Out of Scope (Future Phases):**
- Automatic prior extraction from previous waves
- Direct integration with tabs module output
- Real-time/interactive analysis
- Advanced sample design adjustments beyond weighting

---

## 2. Technical Requirements

### 2.1 Development Standards
- **Language**: R (version 4.0 or higher)
- **Architecture**: Modular, function-based design
- **Code Style**: Tidyverse style guide
- **Dependencies**: Document all package dependencies with minimum versions
- **Performance**: Optimize for datasets up to 10,000 respondents, 200 questions
- **Localization**: Support both comma and period as decimal separators

### 2.2 Code Structure Requirements

```
confidence_analysis/
├── R/
│   ├── 00_main.R                    # Main orchestration script
│   ├── 01_load_config.R             # Config file reading functions
│   ├── 02_load_data.R               # Data loading and validation
│   ├── 03_study_level.R             # Effective sample size, DEFF
│   ├── 04_proportions.R             # Proportion-based methods
│   ├── 05_means.R                   # Mean-based methods
│   ├── 06_multiple_comparisons.R    # Adjustment methods
│   ├── 07_output.R                  # Output generation
│   └── utils.R                      # Helper functions
├── tests/
│   ├── test_proportions.R
│   ├── test_means.R
│   └── test_integration.R
├── docs/
│   ├── user_guide.md
│   ├── technical_documentation.md
│   └── calculation_formulas.md
└── examples/
    ├── example_confidence_config.xlsx
    └── example_output.xlsx
```

### 2.3 Documentation Requirements

**Each function must include:**
- Purpose and description
- Parameter definitions with types and valid ranges
- Return value description
- Example usage
- References to statistical methods/formulas
- Author and date

**Example template:**
```r
#' Calculate Margin of Error for a Proportion
#'
#' Calculates the standard margin of error for a proportion using the normal
#' approximation to the binomial distribution.
#'
#' @param p Numeric. Observed proportion (0 to 1)
#' @param n Integer. Sample size (unweighted base)
#' @param conf_level Numeric. Confidence level (default 0.95 for 95% CI)
#' @param use_wilson Logical. Use Wilson score interval instead (default FALSE)
#'
#' @return Numeric. Margin of error as proportion (multiply by 100 for percentage points)
#'
#' @examples
#' calc_moe(p = 0.45, n = 200, conf_level = 0.95)
#' # Returns: 0.0689 (approximately ±6.9 percentage points)
#'
#' @references
#' Agresti, A., & Coull, B. A. (1998). Approximate is better than "exact"
#'
#' @author [Dev Name]
#' @date 2025-11-12
calc_moe <- function(p, n, conf_level = 0.95, use_wilson = FALSE) {
  # Function implementation
}
```

### 2.4 Error Handling
- Validate all inputs with informative error messages
- Warn (don't fail) for small sample sizes with recommendations
- Log all warnings and errors to output
- Include data quality checks (e.g., weight ranges, missing data %)

---

## 3. Input Specifications

### 3.1 File Structure Overview

The module requires ONE input file:

**confidence_config.xlsx** with 3 sheets:
1. File_Paths
2. Study_Settings  
3. Question_Analysis

### 3.2 Sheet 1: File_Paths

**Purpose:** Points to existing Turas files

**Structure:**

| Parameter | Value | Notes |
|-----------|-------|-------|
| survey_structure_file | data/survey_struct_2024.xlsx | Path to existing survey structure |
| crosstab_config_file | data/tabs_config_wave1.xlsx | Path to existing crosstab config |
| raw_data_file | data/wave1_data.csv | Path to raw survey data |
| output_file | output/confidence_results.xlsx | Where to save results |

**Validation Rules:**
- All file paths must be valid
- Files must exist and be readable
- Relative or absolute paths both acceptable
- If output_file path doesn't exist, create directory

**Example:**
```
Parameter              | Value
----------------------|----------------------------------------
survey_structure_file | ../data/2024_brand_tracker/survey.xlsx
crosstab_config_file  | ../data/2024_brand_tracker/tabs.xlsx
raw_data_file         | ../data/2024_brand_tracker/raw_data.csv
output_file           | results/brand_confidence_nov2024.xlsx
```

---

### 3.3 Sheet 2: Study_Settings

**Purpose:** Study-level/global settings that apply to entire analysis

**Structure:**

| Setting | Value | Valid_Values | Description |
|---------|-------|--------------|-------------|
| calculate_eff_sample_size | Y | Y/N | Calculate effective sample size when data is weighted |
| multiple_comparison_adjust | Y | Y/N | Apply adjustment to existing column significance tests |
| adjustment_method | Holm | Bonferroni/Holm/FDR | Which adjustment method to use |
| bootstrap_iterations | 5000 | 1000-10000 | Number of bootstrap resamples |
| confidence_level | 0.95 | 0.90/0.95/0.99 | Confidence level for all intervals |
| random_seed | 12345 | Any integer | For reproducible bootstrap results |
| decimal_separator | . | . or , | Decimal separator for numeric output |

**Field Specifications:**

**calculate_eff_sample_size**
- Type: Character ("Y" or "N")
- Default: "Y"
- Description: If Y and data contains weights, calculate design effect (DEFF) and effective sample size for each column in crosstab
- Notes: Only applicable when weight variable exists in data

**multiple_comparison_adjust**
- Type: Character ("Y" or "N")
- Default: "N"
- Description: Adjust p-values when testing multiple column pairs to control family-wise error rate
- Notes: Applied to significance tests already performed in tabs module

**adjustment_method**
- Type: Character
- Valid values: "Bonferroni", "Holm", "FDR"
- Default: "Holm"
- Description:
  - Bonferroni: Most conservative, divides alpha by number of tests
  - Holm: Less conservative than Bonferroni, sequential method
  - FDR (False Discovery Rate): Controls expected proportion of false discoveries
- Only used if multiple_comparison_adjust = "Y"

**bootstrap_iterations**
- Type: Integer
- Valid range: 1000 to 10000
- Default: 5000
- Recommended: 5000 for most applications, 10000 for small samples or critical decisions
- Description: Number of resamples for bootstrap confidence intervals

**confidence_level**
- Type: Numeric
- Valid values: 0.90, 0.95, 0.99
- Default: 0.95
- Description: Confidence level for all intervals (MOE, bootstrap, credible intervals)

**random_seed**
- Type: Integer
- Default: NULL (will use system default)
- Description: Set seed for reproducible bootstrap results (useful for testing/validation)

**decimal_separator**
- Type: Character
- Valid values: "." or ","
- Default: "."
- Description: Decimal separator used in numeric output
- Notes: 
  - "." = period (1.234) - standard for English locales
  - "," = comma (1,234) - standard for many European locales
  - Affects all numeric output in Excel file
  - Does NOT affect input parsing (R standard decimal point always used internally)

**Example:**
```
Setting                    | Value
--------------------------|-------
calculate_eff_sample_size  | Y
multiple_comparison_adjust | Y
adjustment_method          | Holm
bootstrap_iterations       | 5000
confidence_level           | 0.95
random_seed                | 12345
decimal_separator          | .
```

---

### 3.4 Sheet 3: Question_Analysis

**Purpose:** Specifies which questions/statistics to analyze and which methods to apply

**Structure:**

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| Question_ID | Text | Yes | Variable name from raw data |
| Statistic_Type | Text | Yes | "proportion", "mean", or "nps" |
| Categories | Text | Conditional | For proportions: comma-separated category codes to include |
| Exclude_Codes | Text | No | Codes to exclude (DK, Refused, etc.) |
| Promoter_Codes | Text | Conditional | For NPS: codes representing promoters (typically 9,10) |
| Detractor_Codes | Text | Conditional | For NPS: codes representing detractors (typically 0-6) |
| Description | Text | No | User label for output (e.g., "Top 2 Box", "NPS") |
| Run_MOE | Text | No | Y/N - Calculate margin of error |
| Run_Bootstrap | Text | No | Y/N - Calculate bootstrap confidence intervals |
| Run_Credible | Text | No | Y/N - Calculate Bayesian credible intervals |
| Use_Wilson | Text | No | Y/N - Use Wilson score instead of normal approximation |
| Prior_Mean | Numeric | No | For credible intervals: prior mean/proportion/NPS |
| Prior_SD | Numeric | No | For means/NPS: prior standard deviation |
| Prior_N | Numeric | No | Effective sample size of prior |
| Notes | Text | No | For user reference only |

**Maximum Rows:** 200 (system should validate and warn if exceeded)

**Field Specifications:**

**Question_ID**
- Must match variable name in raw_data_file
- Case-sensitive
- Required for every row

**Statistic_Type**
- Valid values: "proportion", "mean", "nps"
- Determines which methods are applicable
- Required for every row
- "nps" = Net Promoter Score (% Promoters - % Detractors)

**Categories** (for Statistic_Type = "proportion")
- Comma-separated list of category codes/values
- Example: "4,5" for top 2 box on 5-point scale
- Example: "1" for single category
- Can be numeric or character codes
- Must match coding in raw data
- Required when Statistic_Type = "proportion"
- Ignored when Statistic_Type = "mean" or "nps"

**Exclude_Codes**
- Comma-separated list of codes to exclude from calculation
- For means: codes like 98,99 for Don't Know and Refused
- For NPS: codes to exclude from all calculations (e.g., 99 for Don't Know)
- Optional for means and NPS
- Ignored when Statistic_Type = "proportion"

**Promoter_Codes** (for Statistic_Type = "nps")
- Comma-separated list of codes representing promoters
- Standard NPS: "9,10" on 0-10 scale
- Required when Statistic_Type = "nps"
- Ignored when Statistic_Type = "proportion" or "mean"

**Detractor_Codes** (for Statistic_Type = "nps")
- Comma-separated list of codes representing detractors
- Standard NPS: "0,1,2,3,4,5,6" on 0-10 scale
- Required when Statistic_Type = "nps"
- Ignored when Statistic_Type = "proportion" or "mean"
- Note: Codes 7-8 are "Passives" - not used in NPS calculation but reported separately

**Description**
- User-friendly label for outputs
- Example: "Top 2 Box", "Brand A Awareness", "Mean NPS Score"
- Recommended but optional

**Run_MOE**
- Valid values: "Y", "N", blank (treated as "N")
- For proportions: Calculate traditional margin of error
- For NPS: Calculate margin of error for NPS score (difference of proportions)
- For means: Ignored (MOE not applicable to means)

**Run_Bootstrap**
- Valid values: "Y", "N", blank (treated as "N")
- Available for proportions, means, and NPS
- Uses bootstrap_iterations from Study_Settings

**Run_Credible**
- Valid values: "Y", "N", blank (treated as "N")
- Calculate Bayesian credible intervals
- Available for proportions, means, and NPS
- Uses different prior distributions:
  - Proportions: Beta distribution
  - Means: Normal distribution
  - NPS: Difference of Beta distributions (for promoters and detractors)

**Use_Wilson**
- Valid values: "Y", "N", blank (treated as "N")
- Only applicable when Run_MOE = "Y" for proportions
- Uses Wilson score interval instead of normal approximation
- Better for small samples or extreme proportions (near 0% or 100%)
- Ignored for means and NPS

**Prior_Mean**
- Numeric value
- For proportions: value between 0 and 1 (e.g., 0.45 for 45%)
- For means: previous mean estimate (e.g., 7.2 on 1-10 scale)
- For NPS: prior NPS score between -100 and 100 (e.g., 25 for NPS of +25)
- Only used when Run_Credible = "Y"
- If blank and Run_Credible = "Y": uses uninformed prior
  - Proportions: Beta(1,1)
  - Means: Non-informative normal prior
  - NPS: Uninformed priors for both promoters and detractors Beta(1,1)

**Prior_SD**
- Numeric value > 0
- Applicable for Statistic_Type = "mean" or "nps"
- For means: Standard deviation of prior distribution
- For NPS: Standard deviation of prior NPS distribution
- Required when Prior_Mean is specified for means or NPS
- Ignored for proportions

**Prior_N**
- Integer > 0
- Effective sample size of prior
- Represents "weight" or confidence in the prior
- Used to convert prior information into distribution parameters
- Optional when Prior_Mean is specified
- If blank when Prior_Mean specified: defaults to 100

**Notes**
- Free text for user reference
- Not used in calculations
- Appears in output for traceability

**Validation Rules:**
1. Question_ID must exist in raw data
2. Statistic_Type must be "proportion", "mean", or "nps"
3. If Statistic_Type = "proportion", Categories must be specified
4. If Statistic_Type = "nps", Promoter_Codes and Detractor_Codes must be specified
5. If Statistic_Type = "mean" and Prior_Mean specified, Prior_SD must be specified
6. If Statistic_Type = "nps" and Prior_Mean specified, Prior_SD must be specified
7. All Run_* columns must be Y/N or blank
8. Prior values must be in valid ranges
9. At least one Run_* method must be "Y" per row
10. Total rows must not exceed 200

**Example Rows:**

```
Question_ID | Statistic_Type | Categories | Exclude_Codes | Promoter_Codes | Detractor_Codes | Description | Run_MOE | Run_Bootstrap | Run_Credible | Use_Wilson | Prior_Mean | Prior_SD | Prior_N | Notes
-----------|----------------|------------|---------------|----------------|-----------------|-------------|---------|---------------|--------------|------------|------------|----------|---------|------------------
Q1         | proportion     | 1          |               |                |                 | Brand A     | Y       | Y             | N            | N          |            |          |         | Main brand
Q1         | proportion     | 4,5        |               |                |                 | Top 2 Box   | Y       | Y             | Y            | Y          | 0.67       |          | 500     | From pilot study
Q3         | mean           |            | 98,99         |                |                 | Satisfaction| N       | Y             | Y            | N          | 7.2        | 1.8      | 300     | Last wave result
Q5         | proportion     | 1,2        |               |                |                 | Bottom 2    | Y       | N             | N            | Y          |            |          |         | Low incidence
Q7         | mean           |            | 99            |                |                 | Rating 0-10 | N       | Y             | N            | N          |            |          |         | 0-10 scale
Q8         | nps            |            | 99            | 9,10           | 0,1,2,3,4,5,6   | NPS         | Y       | Y             | Y            | N          | 25         | 15       | 450     | Prior from W1
```

**Tips for Users:**
- One row per statistic to test
- Can analyze same question multiple ways (e.g., Q1 single code AND Q1 top box)
- Start with basics (MOE, Bootstrap) before adding priors
- Use Wilson for proportions <10% or >90%
- For tracking: Prior_Mean from last wave, Prior_N = last wave base size
- Maximum 200 rows per analysis

---

## 4. Processing Logic

### 4.1 Main Processing Flow

```
1. Load and validate confidence_config.xlsx
   ├── Read File_Paths sheet
   ├── Read Study_Settings sheet
   └── Read Question_Analysis sheet (max 200 rows)
   
2. Load referenced files
   ├── Load survey_structure (for question metadata)
   ├── Load crosstab_config (for banner/stub definitions)
   └── Load raw_data
   
3. Validate data integrity
   ├── Check all Question_IDs exist
   ├── Check category codes are valid
   ├── Identify weight variable (if exists)
   ├── Check for missing data
   └── Validate decimal_separator setting
   
4. Study-level calculations (if requested)
   ├── Calculate effective sample sizes (if weighted)
   └── Calculate design effects (DEFF)
   
5. Question-level calculations (loop through Question_Analysis)
   For each row (up to 200):
   ├── Extract relevant data
   ├── Calculate base statistic (proportion or mean)
   ├── Apply requested methods:
   │   ├── MOE (if Run_MOE = Y)
   │   ├── Bootstrap (if Run_Bootstrap = Y)
   │   ├── Credible intervals (if Run_Credible = Y)
   │   └── Wilson score (if Use_Wilson = Y)
   └── Store results
   
6. Multiple comparison adjustments (if requested)
   └── Apply adjustment method to significance tests
   
7. Generate output file
   ├── Apply decimal separator formatting
   ├── Study-level summary sheet
   ├── Detailed results by question
   └── Methodology documentation sheet
```

### 4.2 Study-Level Calculations

**4.2.1 Effective Sample Size & Design Effect**

Only calculated if:
- calculate_eff_sample_size = "Y" in Study_Settings
- Weight variable exists in data

**For each column in the crosstab banner:**

```r
# Design Effect (Kish approximation)
DEFF = 1 + CV_weights^2
where CV_weights = coefficient of variation of weights

# Effective Sample Size
n_eff = n_actual / DEFF

# Also report:
- Sum of weights
- Mean weight
- Min/Max weights
- CV of weights
```

**Output:** Table showing for each column:
- Actual sample size
- Sum of weights
- Mean weight
- Weight CV
- DEFF
- Effective sample size

**Warning triggers:**
- DEFF > 2.0: "Weighting substantially reduces effective sample size"
- Max weight / Min weight > 10: "Extreme weight range detected"

---

### 4.3 Proportion-Based Calculations

**4.3.1 Base Proportion Calculation**

```r
# For specified categories
n_in_category = count of respondents with response in Categories
n_total = count of valid responses (excluding Exclude_Codes if specified)
p = n_in_category / n_total

# If weighted:
p_weighted = sum(weights for responses in Categories) / sum(all weights)
n_effective = n_total / DEFF
```

**4.3.2 Margin of Error (Normal Approximation)**

```r
# Standard error
SE = sqrt(p * (1-p) / n)

# For weighted data
SE_weighted = sqrt(p * (1-p) / n_effective)

# Critical value
z = qnorm(1 - (1 - conf_level)/2)
# For 95% CI: z = 1.96

# Margin of error
MOE = z * SE

# Confidence interval
CI_lower = p - MOE
CI_upper = p + MOE

# Bound between 0 and 1
CI_lower = max(0, CI_lower)
CI_upper = min(1, CI_upper)
```

**Warning triggers:**
- n < 30: "Very small base - results unstable"
- n < 50: "Small base - interpret with caution"
- p < 0.05 or p > 0.95: "Consider Wilson score interval"

**4.3.3 Wilson Score Interval**

More accurate for small samples or extreme proportions.

```r
# Wilson score interval
z = qnorm(1 - (1 - conf_level)/2)
denominator = 1 + z^2/n
center = (p + z^2/(2*n)) / denominator
margin = z * sqrt((p*(1-p) + z^2/(4*n))/n) / denominator

CI_lower = center - margin
CI_upper = center + margin
```

**When to use:** 
- Automatically used if Use_Wilson = "Y"
- Recommended when p < 0.10 or p > 0.90
- Recommended when n < 50

**4.3.4 Bootstrap Confidence Intervals for Proportions**

```r
# Initialize
B = bootstrap_iterations from Study_Settings
bootstrap_proportions = vector of length B

# Resample
for i in 1:B {
  # Sample with replacement
  resample_indices = sample(1:n, size=n, replace=TRUE)
  resample_data = data[resample_indices, ]
  
  # If weighted, resample weights too
  resample_weights = weights[resample_indices]
  
  # Calculate proportion for this resample
  bootstrap_proportions[i] = calculate_proportion(resample_data, resample_weights)
}

# Percentile method
CI_lower = quantile(bootstrap_proportions, (1-conf_level)/2)
CI_upper = quantile(bootstrap_proportions, 1-(1-conf_level)/2)

# Also report:
- Bootstrap SE = sd(bootstrap_proportions)
- Bootstrap mean = mean(bootstrap_proportions)
```

**Options to implement:**
- Basic percentile method (start with this)
- BCa (bias-corrected and accelerated) - future enhancement

**4.3.5 Bayesian Credible Intervals for Proportions**

Uses Beta-Binomial conjugate prior.

**Uninformed Prior (when Prior_Mean is blank):**
```r
# Beta(1,1) - uniform prior
alpha_prior = 1
beta_prior = 1
```

**Informed Prior (when Prior_Mean is specified):**
```r
# Convert prior proportion and sample size to Beta parameters
# Prior: Beta(alpha_prior, beta_prior)
# Mean = alpha/(alpha+beta) = Prior_Mean
# "Sample size" = alpha + beta = Prior_N (if specified, else default 100)

prior_n = ifelse(is.na(Prior_N), 100, Prior_N)
alpha_prior = Prior_Mean * prior_n
beta_prior = (1 - Prior_Mean) * prior_n
```

**Posterior calculation:**
```r
# Likelihood: successes = n_in_category, failures = n_total - n_in_category
alpha_post = alpha_prior + n_in_category
beta_post = beta_prior + (n_total - n_in_category)

# Posterior mean
p_post = alpha_post / (alpha_post + beta_post)

# Credible interval
CI_lower = qbeta((1-conf_level)/2, alpha_post, beta_post)
CI_upper = qbeta(1-(1-conf_level)/2, alpha_post, beta_post)
```

**Output should include:**
- Posterior mean
- Credible interval
- Prior parameters used (for transparency)

---

### 4.4 Mean-Based Calculations

**4.4.1 Base Mean Calculation**

```r
# Exclude specified codes
valid_responses = data where response not in Exclude_Codes

# Calculate mean
if (weighted) {
  mean_value = weighted.mean(valid_responses, weights)
  n_effective = n_valid / DEFF
} else {
  mean_value = mean(valid_responses)
  n_effective = n_valid
}

# Standard deviation
sd_value = sd(valid_responses)  # or weighted.sd if weighted
```

**4.4.2 Standard Error and Confidence Interval for Means**

```r
# Standard error
SE = sd_value / sqrt(n_effective)

# For weighted data, adjust:
# Use effective sample size from DEFF calculation

# Degrees of freedom
df = n_effective - 1

# Critical value (t-distribution)
t_crit = qt(1 - (1-conf_level)/2, df)

# Margin of error
MOE = t_crit * SE

# Confidence interval
CI_lower = mean_value - MOE
CI_upper = mean_value + MOE
```

**Warning triggers:**
- n < 30: "Small sample - t-distribution used but results may be unstable"
- High SD relative to mean: "High variability detected"

**4.4.3 Bootstrap Confidence Intervals for Means**

```r
# Initialize
B = bootstrap_iterations from Study_Settings
bootstrap_means = vector of length B

# Resample
for i in 1:B {
  resample_indices = sample(1:n_valid, size=n_valid, replace=TRUE)
  resample_data = valid_responses[resample_indices]
  
  if (weighted) {
    resample_weights = weights[resample_indices]
    bootstrap_means[i] = weighted.mean(resample_data, resample_weights)
  } else {
    bootstrap_means[i] = mean(resample_data)
  }
}

# Percentile method
CI_lower = quantile(bootstrap_means, (1-conf_level)/2)
CI_upper = quantile(bootstrap_means, 1-(1-conf_level)/2)

# Also report:
- Bootstrap SE = sd(bootstrap_means)
- Bootstrap mean = mean(bootstrap_means)
```

**4.4.4 Bayesian Credible Intervals for Means**

Uses Normal-Normal conjugate prior.

**Uninformed Prior (when Prior_Mean is blank):**
```r
# Use non-informative prior
# Effectively: very large variance, no prior information
use_uninformative = TRUE
```

**Informed Prior (when Prior_Mean AND Prior_SD are specified):**
```r
# Prior: Normal(mu_prior, sigma_prior^2)
mu_prior = Prior_Mean
sigma_prior = Prior_SD
n_prior = ifelse(is.na(Prior_N), 100, Prior_N)

# Prior precision (inverse variance)
tau_prior = n_prior / (sigma_prior^2)
```

**Posterior calculation:**
```r
# Data precision
tau_data = n_valid / (sd_value^2)

if (use_uninformative) {
  # Posterior is just the data
  mu_post = mean_value
  sigma_post = sd_value / sqrt(n_valid)
} else {
  # Combine prior and data
  tau_post = tau_prior + tau_data
  mu_post = (tau_prior * mu_prior + tau_data * mean_value) / tau_post
  sigma_post = sqrt(1 / tau_post)
}

# Credible interval (using normal approximation)
z = qnorm(1 - (1-conf_level)/2)
CI_lower = mu_post - z * sigma_post
CI_upper = mu_post + z * sigma_post
```

**Output should include:**
- Posterior mean
- Credible interval
- Prior parameters used (for transparency)

---

### 4.5 Multiple Comparison Adjustments

Only applied if multiple_comparison_adjust = "Y" in Study_Settings.

**Purpose:** Adjust p-values from column significance tests already performed in tabs module to control for multiple testing.

**Input:** 
- Set of p-values from column comparisons
- Example: Testing Total column vs columns A, B, C, D, E = 5 comparisons

**Methods:**

**4.5.1 Bonferroni Correction**
```r
# Most conservative
p_adjusted = min(p_value * n_comparisons, 1)

# Interpretation: reject null if p_adjusted < alpha
```

**4.5.2 Holm Method**
```r
# Step-down procedure
# 1. Order p-values from smallest to largest: p(1) <= p(2) <= ... <= p(m)
# 2. For i = 1 to m:
#    p_adjusted(i) = min(max(p(i) * (m - i + 1), p_adjusted(i-1)), 1)

p_adjusted = p.adjust(p_values, method = "holm")
```

**4.5.3 FDR (False Discovery Rate)**
```r
# Benjamini-Hochberg procedure
p_adjusted = p.adjust(p_values, method = "fdr")

# Controls expected proportion of false discoveries
# Less conservative than FWER methods
```

**Output:**
- Original p-values
- Adjusted p-values
- Method used
- Number of comparisons
- Significant flags at original and adjusted levels

---

### 4.6 NPS (Net Promoter Score) Calculations

**4.6.1 Base NPS Calculation**

NPS is calculated as the percentage of Promoters minus the percentage of Detractors:

```r
# Exclude specified codes (e.g., Don't Know)
valid_responses = data where response not in Exclude_Codes

# Count promoters, passives, and detractors
n_promoters = count of responses in Promoter_Codes
n_passives = count of responses not in Promoter_Codes OR Detractor_Codes
n_detractors = count of responses in Detractor_Codes
n_total = n_promoters + n_passives + n_detractors

# Calculate proportions
p_promoters = n_promoters / n_total
p_passives = n_passives / n_total
p_detractors = n_detractors / n_total

# NPS Score
nps = (p_promoters - p_detractors) * 100

# If weighted:
p_promoters_weighted = sum(weights for promoters) / sum(all weights)
p_detractors_weighted = sum(weights for detractors) / sum(all weights)
nps_weighted = (p_promoters_weighted - p_detractors_weighted) * 100
n_effective = n_total / DEFF
```

**4.6.2 Margin of Error for NPS**

NPS is a difference of two proportions, so its variance is:

```r
# Standard error for difference of proportions
# Since promoters and detractors are mutually exclusive from same sample,
# we calculate SE for each and combine

SE_promoters = sqrt(p_promoters * (1 - p_promoters) / n)
SE_detractors = sqrt(p_detractors * (1 - p_detractors) / n)

# For mutually exclusive categories from same sample:
# Var(p1 - p2) = Var(p1) + Var(p2) - 2*Cov(p1, p2)
# But for proportions where p1 + p_passive + p2 = 1:
# Cov(p1, p2) = -p1*p2/n

SE_nps = sqrt(SE_promoters^2 + SE_detractors^2)

# For weighted data, use effective n
SE_nps_weighted = sqrt(
  (p_promoters * (1 - p_promoters) / n_effective) + 
  (p_detractors * (1 - p_detractors) / n_effective)
)

# Critical value
z = qnorm(1 - (1 - conf_level)/2)

# Margin of error (in NPS points)
MOE_nps = z * SE_nps * 100

# Confidence interval
CI_lower = nps - MOE_nps
CI_upper = nps + MOE_nps

# Bound between -100 and 100
CI_lower = max(-100, CI_lower)
CI_upper = min(100, CI_upper)
```

**Warning triggers:**
- n < 30: "Very small base - NPS results unstable"
- n < 50: "Small base - interpret NPS with caution"
- p_promoters < 0.05 or p_detractors < 0.05: "Very few promoters or detractors"

**4.6.3 Bootstrap Confidence Intervals for NPS**

```r
# Initialize
B = bootstrap_iterations from Study_Settings
bootstrap_nps = vector of length B

# Resample
for i in 1:B {
  # Sample with replacement
  resample_indices = sample(1:n, size=n, replace=TRUE)
  resample_data = data[resample_indices, ]
  
  # If weighted, resample weights too
  if (weighted) {
    resample_weights = weights[resample_indices]
  }
  
  # Calculate NPS for this resample
  n_prom_boot = count promoters in resample
  n_detr_boot = count detractors in resample
  n_tot_boot = count valid responses in resample
  
  if (weighted) {
    p_prom_boot = sum(weights for promoters) / sum(weights)
    p_detr_boot = sum(weights for detractors) / sum(weights)
  } else {
    p_prom_boot = n_prom_boot / n_tot_boot
    p_detr_boot = n_detr_boot / n_tot_boot
  }
  
  bootstrap_nps[i] = (p_prom_boot - p_detr_boot) * 100
}

# Percentile method
CI_lower = quantile(bootstrap_nps, (1-conf_level)/2)
CI_upper = quantile(bootstrap_nps, 1-(1-conf_level)/2)

# Also report:
- Bootstrap SE = sd(bootstrap_nps)
- Bootstrap mean NPS = mean(bootstrap_nps)
```

**4.6.4 Bayesian Credible Intervals for NPS**

Uses Beta-Binomial model for promoters and detractors separately, then calculates distribution of difference.

**Uninformed Prior (when Prior_Mean is blank):**
```r
# Beta(1,1) for both promoters and detractors
alpha_prom_prior = 1
beta_prom_prior = 1
alpha_detr_prior = 1
beta_detr_prior = 1
```

**Informed Prior (when Prior_Mean and Prior_SD are specified):**
```r
# Convert prior NPS to promoter and detractor proportions
# Requires assumptions about the distribution
# Simpler approach: use Prior_Mean as NPS and Prior_N as sample size

# If prior NPS = 25, assume it came from some p_prom and p_detr
# We need to make assumptions - use typical patterns:
# For NPS = 25, could be: 45% promoters, 20% detractors
# Or: 50% promoters, 25% detractors, etc.

# SIMPLIFICATION for Phase 1:
# User specifies prior separately for promoters and detractors
# OR use simulation approach with specified NPS mean and SD

prior_n = ifelse(is.na(Prior_N), 100, Prior_N)

# For informed prior on NPS, use Monte Carlo simulation:
# 1. Sample from prior distribution of NPS (Normal with mean, SD)
# 2. Use these to inform Beta priors
# OR use moment matching to convert NPS distribution to Beta distributions

# Recommended: Keep it simple - use uninformed priors for Phase 1
# Add informed NPS priors in Phase 2
```

**Posterior calculation (uninformed prior):**
```r
# Promoters posterior
alpha_prom_post = alpha_prom_prior + n_promoters
beta_prom_post = beta_prom_prior + (n_total - n_promoters)

# Detractors posterior  
alpha_detr_post = alpha_detr_prior + n_detractors
beta_detr_post = beta_detr_prior + (n_total - n_detractors)

# To get credible interval for NPS = (p_prom - p_detr) * 100:
# Use Monte Carlo simulation
n_sim = 10000
prom_samples = rbeta(n_sim, alpha_prom_post, beta_prom_post)
detr_samples = rbeta(n_sim, alpha_detr_post, beta_detr_post)
nps_samples = (prom_samples - detr_samples) * 100

# Credible interval
CI_lower = quantile(nps_samples, (1-conf_level)/2)
CI_upper = quantile(nps_samples, 1-(1-conf_level)/2)
nps_post_mean = mean(nps_samples)
```

**Output should include:**
- Promoter % and credible interval
- Detractor % and credible interval
- Passive % (for reference)
- NPS score and credible interval
- Prior type used

---

### 4.7 Decimal Separator Formatting

**Implementation:**

```r
# Function to format numbers with user-specified decimal separator
format_number <- function(x, decimal_sep = ".", digits = 2) {
  formatted <- formatC(x, format = "f", digits = digits)
  if (decimal_sep == ",") {
    formatted <- gsub("\\.", ",", formatted)
  }
  return(formatted)
}

# Apply to all numeric output columns before writing to Excel
# Store internally as numeric, format only at output stage
```

**Rules:**
- Internal calculations always use R standard (period)
- Formatting applied only at output generation
- Affects all numeric columns in all output sheets
- Does not affect column headers or text fields

---

## 5. Output Specifications

### 5.1 Output File Structure

**Excel workbook with multiple sheets:**

1. **Summary** - Executive overview
2. **Study_Level** - Effective sample sizes, DEFF (if calculated)
3. **Proportions_Detail** - All proportion-based results
4. **Means_Detail** - All mean-based results
5. **NPS_Detail** - All NPS results
6. **Multiple_Comparisons** - Adjusted p-values (if calculated)
7. **Methodology** - Documentation of methods and formulas used
8. **Warnings** - Any warnings or data quality flags
9. **Inputs** - Copy of Study_Settings and Question_Analysis for reference

### 5.2 Summary Sheet

**Content:**
- Analysis date/time
- Input files used
- Study settings applied
- Number of questions analyzed
- Key warnings/flags
- Quick reference table of all results

**Format:**
```
TURAS CONFIDENCE ANALYSIS - SUMMARY
Analysis Date: 2024-11-12 14:32:15
Confidence Level: 95%
Bootstrap Iterations: 5000
Decimal Separator: .

INPUT FILES:
Survey Structure: data/survey_struct_2024.xlsx
Crosstab Config: data/tabs_config_wave1.xlsx
Raw Data: data/wave1_data.csv

ANALYSIS SCOPE:
Total Questions Analyzed: 9 (of maximum 200)
  - Proportions: 6
  - Means: 2
  - NPS: 1
Methods Applied:
  - Margin of Error: 6 questions
  - Bootstrap: 9 questions
  - Credible Intervals: 4 questions
  - Wilson Score: 2 questions

STUDY-LEVEL RESULTS:
Effective Sample Size Calculated: Yes
Multiple Comparison Adjustment: Yes (Holm method)

WARNINGS: 2
  - Q5: Small base size (n=47)
  - Q7: Extreme proportion (p=0.94) - Wilson score used

[Followed by summary table of all results]
```

### 5.3 Study_Level Sheet

**Content (if calculate_eff_sample_size = Y):**

| Column | Actual_n | Sum_Weights | Mean_Weight | Weight_CV | DEFF | Effective_n | Warning |
|--------|----------|-------------|-------------|-----------|------|-------------|---------|
| Total | 1000 | 1000.0 | 1.00 | 0.000 | 1.00 | 1000 | |
| Male | 450 | 500.2 | 1.11 | 0.182 | 1.03 | 437 | |
| Female | 550 | 499.8 | 0.91 | 0.157 | 1.02 | 539 | |
| Age 18-34 | 300 | 350.5 | 1.17 | 0.245 | 1.06 | 283 | |
| Age 35-54 | 400 | 399.8 | 1.00 | 0.128 | 1.02 | 392 | |
| Age 55+ | 300 | 249.7 | 0.83 | 0.198 | 1.04 | 288 | |

**Notes section:**
- Explanation of DEFF
- Interpretation guidance
- Any warnings about high DEFF values
- Note about decimal separator used

### 5.4 Proportions_Detail Sheet

**Columns:**

| Column Name | Description | Example |
|-------------|-------------|---------|
| Question_ID | Variable name | Q1 |
| Description | User description | Top 2 Box |
| Statistic_Type | Always "proportion" | proportion |
| Categories | Categories included | 4,5 |
| Banner_Column | Column from crosstab | Total |
| Base_n | Unweighted base | 1000 |
| Effective_n | Effective n (if weighted) | 950 |
| Proportion | Observed proportion | 0.67 |
| Proportion_Pct | As percentage | 67.0% |
| **MOE Results** | | |
| MOE_Lower | Lower CI | 0.64 |
| MOE_Upper | Upper CI | 0.70 |
| MOE_Width | ±MOE | ±0.03 |
| MOE_Method | Normal or Wilson | Wilson |
| **Bootstrap Results** | | |
| Boot_Lower | Lower CI | 0.64 |
| Boot_Upper | Upper CI | 0.70 |
| Boot_SE | Bootstrap SE | 0.015 |
| **Credible Interval Results** | | |
| Cred_Lower | Lower CI | 0.65 |
| Cred_Upper | Upper CI | 0.69 |
| Cred_Mean | Posterior mean | 0.67 |
| Prior_Type | Uninformed/Informed | Informed |
| Prior_Mean | Prior used | 0.65 |
| Prior_N | Prior sample size | 500 |
| **Flags** | | |
| Warning | Any warnings | Small base |
| Notes | User notes | From pilot |

**Sorting:** Group by Question_ID, then by Banner_Column

**Formatting:**
- Proportions: 2 decimal places (or 3 if needed)
- Percentages: 1 decimal place
- Highlight rows with warnings in yellow
- Use specified decimal separator throughout

### 5.5 Means_Detail Sheet

**Similar structure to Proportions_Detail but adapted for means:**

| Column Name | Description | Example |
|-------------|-------------|---------|
| Question_ID | Variable name | Q3 |
| Description | User description | NPS Score |
| Statistic_Type | Always "mean" | mean |
| Exclude_Codes | Codes excluded | 98,99 |
| Banner_Column | Column from crosstab | Total |
| Base_n | Valid responses | 985 |
| Effective_n | Effective n (if weighted) | 940 |
| Mean | Observed mean | 7.2 |
| SD | Standard deviation | 1.8 |
| SE | Standard error | 0.058 |
| **Traditional CI** | | |
| CI_Lower | Lower CI | 7.09 |
| CI_Upper | Upper CI | 7.31 |
| CI_Method | t-distribution | t(984) |
| **Bootstrap Results** | | |
| Boot_Lower | Lower CI | 7.08 |
| Boot_Upper | Upper CI | 7.32 |
| Boot_SE | Bootstrap SE | 0.059 |
| Boot_Mean | Bootstrap mean | 7.20 |
| **Credible Interval Results** | | |
| Cred_Lower | Lower CI | 7.10 |
| Cred_Upper | Upper CI | 7.30 |
| Cred_Mean | Posterior mean | 7.20 |
| Prior_Type | Uninformed/Informed | Informed |
| Prior_Mean | Prior used | 7.1 |
| Prior_SD | Prior SD | 1.9 |
| Prior_N | Prior sample size | 300 |
| **Flags** | | |
| Warning | Any warnings | |
| Notes | User notes | Last wave |

### 5.6 NPS_Detail Sheet

**Structure for Net Promoter Score results:**

| Column Name | Description | Example |
|-------------|-------------|---------|
| Question_ID | Variable name | Q8 |
| Description | User description | Net Promoter Score |
| Statistic_Type | Always "nps" | nps |
| Promoter_Codes | Codes for promoters | 9,10 |
| Detractor_Codes | Codes for detractors | 0,1,2,3,4,5,6 |
| Exclude_Codes | Codes excluded | 99 |
| Banner_Column | Column from crosstab | Total |
| Base_n | Valid responses | 985 |
| Effective_n | Effective n (if weighted) | 940 |
| **Component Proportions** | | |
| Promoter_Pct | % Promoters | 42.0% |
| Passive_Pct | % Passives (7-8) | 38.0% |
| Detractor_Pct | % Detractors | 20.0% |
| **NPS Score** | | |
| NPS | Net Promoter Score | 22 |
| **MOE Results** | | |
| NPS_MOE_Lower | Lower CI | 16 |
| NPS_MOE_Upper | Upper CI | 28 |
| NPS_MOE_Width | ±MOE | ±6 |
| **Bootstrap Results** | | |
| NPS_Boot_Lower | Lower CI | 16 |
| NPS_Boot_Upper | Upper CI | 29 |
| NPS_Boot_SE | Bootstrap SE | 3.2 |
| NPS_Boot_Mean | Bootstrap mean NPS | 22.1 |
| **Credible Interval Results** | | |
| NPS_Cred_Lower | Lower CI | 17 |
| NPS_Cred_Upper | Upper CI | 27 |
| NPS_Cred_Mean | Posterior mean NPS | 22.0 |
| Promoter_Cred_Lower | Promoter % lower CI | 38.5% |
| Promoter_Cred_Upper | Promoter % upper CI | 45.5% |
| Detractor_Cred_Lower | Detractor % lower CI | 17.0% |
| Detractor_Cred_Upper | Detractor % upper CI | 23.0% |
| Prior_Type | Uninformed/Informed | Uninformed |
| Prior_NPS | Prior NPS (if informed) | |
| Prior_N | Prior sample size | |
| **Flags** | | |
| Warning | Any warnings | |
| Notes | User notes | Standard NPS |

**Sorting:** Group by Question_ID, then by Banner_Column

**Formatting:**
- Percentages: 1 decimal place
- NPS scores: whole numbers (integers)
- Highlight rows with warnings in yellow
- Use specified decimal separator throughout

**Notes:**
- Passives (typically 7-8) are reported but not used in NPS calculation
- NPS ranges from -100 to +100
- Confidence intervals for NPS account for correlation between promoters and detractors

### 5.7 Multiple_Comparisons Sheet

**Only included if multiple_comparison_adjust = "Y"**

Structure showing adjusted p-values from column significance tests:

| Test_ID | Column_A | Column_B | Statistic | Original_p | Adjusted_p | Method | Sig_Original | Sig_Adjusted |
|---------|----------|----------|-----------|------------|------------|--------|--------------|--------------|
| 1 | Total | Male | Q1_prop | 0.023 | 0.092 | Holm | * | |
| 2 | Total | Female | Q1_prop | 0.045 | 0.135 | Holm | * | |
| 3 | Total | Age18_34 | Q1_prop | 0.001 | 0.005 | Holm | ** | ** |
| 4 | Total | Age35_54 | Q1_prop | 0.156 | 0.312 | Holm | | |
| 5 | Total | Age55plus | Q1_prop | 0.089 | 0.178 | Holm | | |

**Legend:**
- * = p < 0.05
- ** = p < 0.01
- Blank = not significant

**Summary stats:**
- Number of tests
- Number significant before adjustment
- Number significant after adjustment
- Method used

### 5.8 Methodology Sheet

**Content:**

Documentation of all methods used, including:

1. **Study-Level Methods**
   - Effective sample size formula
   - DEFF calculation (Kish approximation)
   - When/how applied

2. **Proportion Methods**
   - Normal approximation MOE formula
   - Wilson score formula
   - Bootstrap procedure
   - Bayesian credible intervals (Beta-Binomial)
   - Prior specifications

3. **Mean Methods**
   - Standard error formula
   - t-distribution CI
   - Bootstrap procedure
   - Bayesian credible intervals (Normal-Normal)
   - Prior specifications

4. **Multiple Comparison Methods**
   - Bonferroni correction
   - Holm step-down procedure
   - FDR (Benjamini-Hochberg)

5. **Output Formatting**
   - Decimal separator used
   - Rounding conventions
   - Precision levels

6. **References**
   - Key statistical references
   - Software versions used

7. **Interpretation Guidance**
   - How to read confidence intervals
   - When to use each method
   - Limitations and assumptions

**Format:** Clear, concise text with formulas in LaTeX or clear notation

### 5.9 Warnings Sheet

**All warnings and flags generated during analysis:**

| Warning_Type | Question_ID | Banner_Column | Message | Recommendation |
|--------------|-------------|---------------|---------|----------------|
| Small_Base | Q5 | Age_55plus | Base size = 47 | Interpret with caution |
| Extreme_Prop | Q7 | Total | Proportion = 0.94 | Wilson score recommended |
| High_DEFF | - | Male | DEFF = 2.3 | Large design effect from weighting |
| Missing_Data | Q9 | - | 15% missing responses | Check data quality |
| Question_Limit | - | - | 200 question limit reached | Consider splitting analysis |

### 5.10 Inputs Sheet

**Copy of user inputs for full traceability:**

Reproduce Study_Settings and Question_Analysis sheets from confidence_config.xlsx

---

## 6. Detailed Output Examples

### 6.1 Example: Complete Proportions_Detail Output

**Scenario:** Brand awareness study with 3 questions, analyzing top boxes and single codes

**Configuration Used:**
- Confidence Level: 95%
- Bootstrap Iterations: 5000
- Decimal Separator: . (period)
- Sample Size: 1000 respondents

**Proportions_Detail Sheet:**

| Question_ID | Description | Statistic_Type | Categories | Banner_Column | Base_n | Effective_n | Proportion | Proportion_Pct | MOE_Lower | MOE_Upper | MOE_Width | MOE_Method | Boot_Lower | Boot_Upper | Boot_SE | Cred_Lower | Cred_Upper | Cred_Mean | Prior_Type | Prior_Mean | Prior_N | Warning | Notes |
|-------------|-------------|----------------|------------|---------------|--------|-------------|------------|----------------|-----------|-----------|-----------|------------|------------|------------|---------|------------|------------|-----------|------------|------------|---------|---------|-------|
| Q1_BrandAware | Brand A Awareness | proportion | 1 | Total | 1000 | 1000 | 0.45 | 45.0% | 0.42 | 0.48 | ±0.03 | Normal | 0.42 | 0.48 | 0.016 | 0.43 | 0.47 | 0.45 | Informed | 0.42 | 450 | | Pilot data |
| Q1_BrandAware | Brand A Awareness | proportion | 1 | Male | 450 | 450 | 0.48 | 48.0% | 0.44 | 0.53 | ±0.05 | Normal | 0.43 | 0.52 | 0.023 | | | | | | | | |
| Q1_BrandAware | Brand A Awareness | proportion | 1 | Female | 550 | 550 | 0.42 | 42.0% | 0.38 | 0.46 | ±0.04 | Normal | 0.38 | 0.46 | 0.021 | | | | | | | | |
| Q2_Satisfaction | Top 2 Box | proportion | 4,5 | Total | 1000 | 1000 | 0.67 | 67.0% | 0.64 | 0.70 | ±0.03 | Normal | 0.64 | 0.70 | 0.015 | 0.65 | 0.69 | 0.67 | Informed | 0.65 | 500 | | Wave 1 |
| Q2_Satisfaction | Top 2 Box | proportion | 4,5 | Male | 450 | 450 | 0.71 | 71.0% | 0.67 | 0.75 | ±0.04 | Normal | 0.67 | 0.76 | 0.021 | | | | | | | | |
| Q2_Satisfaction | Top 2 Box | proportion | 4,5 | Female | 550 | 550 | 0.64 | 64.0% | 0.60 | 0.68 | ±0.04 | Normal | 0.60 | 0.68 | 0.020 | | | | | | | | |
| Q3_LowIncidence | Bottom 2 Box | proportion | 1,2 | Total | 1000 | 1000 | 0.08 | 8.0% | 0.06 | 0.10 | ±0.02 | Wilson | 0.06 | 0.10 | 0.009 | | | | | | | Consider Wilson | Low % |
| Q3_LowIncidence | Bottom 2 Box | proportion | 1,2 | Male | 450 | 450 | 0.09 | 9.0% | 0.06 | 0.12 | ±0.03 | Wilson | 0.06 | 0.12 | 0.013 | | | | | | | | |
| Q3_LowIncidence | Bottom 2 Box | proportion | 1,2 | Female | 550 | 550 | 0.07 | 7.0% | 0.05 | 0.10 | ±0.02 | Wilson | 0.05 | 0.10 | 0.011 | | | | | | | | |
| Q3_LowIncidence | Bottom 2 Box | proportion | 1,2 | Age_55plus | 47 | 47 | 0.13 | 13.0% | 0.05 | 0.25 | ±0.10 | Wilson | 0.04 | 0.26 | 0.049 | | | | | | | Small base | n<50 |

**Notes on this example:**
- Q1 uses informed prior from pilot study (42%, n=450)
- Q2 uses informed prior from previous wave (65%, n=500)
- Q3 automatically uses Wilson score due to low proportion
- Age_55plus for Q3 flagged for small base size (n=47)
- Effective_n equals Base_n when no weighting applied
- Bootstrap results generally align with parametric intervals
- Credible intervals slightly narrower when using informed priors

---

### 6.2 Example: Complete Means_Detail Output

**Scenario:** Satisfaction ratings on 0-10 scale

**Configuration Used:**
- Confidence Level: 95%
- Bootstrap Iterations: 5000
- Decimal Separator: . (period)
- Exclude Codes: 99 (Don't Know)

**Means_Detail Sheet:**

| Question_ID | Description | Statistic_Type | Exclude_Codes | Banner_Column | Base_n | Effective_n | Mean | SD | SE | CI_Lower | CI_Upper | CI_Method | Boot_Lower | Boot_Upper | Boot_SE | Boot_Mean | Cred_Lower | Cred_Upper | Cred_Mean | Prior_Type | Prior_Mean | Prior_SD | Prior_N | Warning | Notes |
|-------------|-------------|----------------|---------------|---------------|--------|-------------|------|-----|-----|----------|----------|-----------|------------|------------|---------|-----------|------------|------------|-----------|------------|------------|----------|---------|---------|-------|
| Q5_NPS | NPS Score | mean | 99 | Total | 985 | 985 | 7.2 | 1.8 | 0.057 | 7.09 | 7.31 | t(984) | 7.08 | 7.32 | 0.058 | 7.20 | 7.10 | 7.30 | 7.20 | Informed | 7.1 | 1.9 | 300 | | Last wave |
| Q5_NPS | NPS Score | mean | 99 | Male | 442 | 442 | 7.4 | 1.7 | 0.081 | 7.24 | 7.56 | t(441) | 7.23 | 7.57 | 0.083 | 7.40 | | | | | | | | | |
| Q5_NPS | NPS Score | mean | 99 | Female | 543 | 543 | 7.0 | 1.9 | 0.082 | 6.84 | 7.16 | t(542) | 6.83 | 7.17 | 0.084 | 7.00 | | | | | | | | | |
| Q5_NPS | NPS Score | mean | 99 | Age_18_34 | 298 | 298 | 6.8 | 2.1 | 0.122 | 6.56 | 7.04 | t(297) | 6.54 | 7.06 | 0.125 | 6.80 | | | | | | | | | |
| Q5_NPS | NPS Score | mean | 99 | Age_35_54 | 392 | 392 | 7.3 | 1.6 | 0.081 | 7.14 | 7.46 | t(391) | 7.13 | 7.47 | 0.082 | 7.30 | | | | | | | | | |
| Q5_NPS | NPS Score | mean | 99 | Age_55plus | 295 | 295 | 7.5 | 1.7 | 0.099 | 7.30 | 7.70 | t(294) | 7.29 | 7.71 | 0.101 | 7.50 | | | | | | | | | |
| Q7_Satisfaction | Overall Satisfaction | mean | 98,99 | Total | 972 | 972 | 8.1 | 1.5 | 0.048 | 8.00 | 8.20 | t(971) | 8.00 | 8.20 | 0.049 | 8.10 | | | | | | | | | Current wave |
| Q7_Satisfaction | Overall Satisfaction | mean | 98,99 | Male | 438 | 438 | 8.3 | 1.4 | 0.067 | 8.17 | 8.43 | t(437) | 8.16 | 8.44 | 0.068 | 8.30 | | | | | | | | | |
| Q7_Satisfaction | Overall Satisfaction | mean | 98,99 | Female | 534 | 534 | 7.9 | 1.6 | 0.069 | 7.76 | 8.04 | t(533) | 7.75 | 8.05 | 0.071 | 7.90 | | | | | | | | | |

**Notes on this example:**
- Q5 uses informed prior from previous wave (mean=7.1, SD=1.9, n=300)
- Q7 has no prior, so credible intervals not calculated
- Base_n varies by column due to different numbers of DK responses
- Bootstrap means closely match observed means
- Traditional t-based CIs and bootstrap CIs are very similar
- Standard errors properly reflect sample sizes

---

### 6.3 Example: Study_Level Output (Weighted Data)

**Scenario:** Weighted data with gender and age quotas

**Study_Level Sheet:**

| Banner_Column | Actual_n | Sum_Weights | Mean_Weight | Min_Weight | Max_Weight | Weight_CV | DEFF | Effective_n | Warning |
|---------------|----------|-------------|-------------|------------|------------|-----------|------|-------------|---------|
| Total | 1000 | 1000.0 | 1.000 | 0.421 | 2.347 | 0.285 | 1.081 | 925 | |
| Male | 450 | 500.2 | 1.112 | 0.876 | 1.523 | 0.182 | 1.033 | 436 | |
| Female | 550 | 499.8 | 0.909 | 0.421 | 1.245 | 0.157 | 1.025 | 537 | |
| Age_18_34 | 300 | 350.5 | 1.168 | 0.923 | 2.347 | 0.245 | 1.060 | 283 | |
| Age_35_54 | 400 | 399.8 | 1.000 | 0.754 | 1.432 | 0.128 | 1.016 | 394 | |
| Age_55plus | 300 | 249.7 | 0.832 | 0.421 | 1.234 | 0.198 | 1.039 | 289 | |

**Interpretation Notes (included on sheet):**

```
DESIGN EFFECT (DEFF) INTERPRETATION:
- DEFF = 1.00: No loss of precision from weighting
- DEFF = 1.05-1.20: Modest loss of precision (5-20%)
- DEFF = 1.20-2.00: Moderate loss of precision (20-50%)
- DEFF > 2.00: Substantial loss of precision (>50%)

EFFECTIVE SAMPLE SIZE:
The effective sample size represents the equivalent unweighted sample that would 
provide the same precision. For example, Total has 1000 actual respondents but 
weighting reduces this to an effective sample of 925.

WEIGHT COEFFICIENT OF VARIATION (CV):
- CV < 0.20: Modest variation in weights
- CV = 0.20-0.30: Moderate variation
- CV > 0.30: High variation - consider reviewing weighting scheme

WARNINGS:
- Total: Weight_CV = 0.285 indicates moderate weight variation
- Total: Weight range 0.421 to 2.347 (ratio 5.6:1) is within acceptable limits
```

---

### 6.4 Example: Multiple_Comparisons Output

**Scenario:** Testing Total column against 5 demographic segments for Q1 awareness

**Multiple_Comparisons Sheet:**

| Test_ID | Base_Column | Comparison_Column | Question_ID | Statistic | Base_Proportion | Comp_Proportion | Difference | Original_p | Adjusted_p | Adjustment_Method | Sig_Original | Sig_Adjusted | Interpretation |
|---------|-------------|-------------------|-------------|-----------|-----------------|-----------------|------------|------------|------------|-------------------|--------------|--------------|----------------|
| 1 | Total | Male | Q1_BrandAware | proportion | 0.450 | 0.480 | +0.030 | 0.184 | 0.552 | Holm | | | Not significant |
| 2 | Total | Female | Q1_BrandAware | proportion | 0.450 | 0.420 | -0.030 | 0.162 | 0.486 | Holm | | | Not significant |
| 3 | Total | Age_18_34 | Q1_BrandAware | proportion | 0.450 | 0.380 | -0.070 | 0.012 | 0.048 | Holm | * | * | Significant |
| 4 | Total | Age_35_54 | Q1_BrandAware | proportion | 0.450 | 0.470 | +0.020 | 0.447 | 0.894 | Holm | | | Not significant |
| 5 | Total | Age_55plus | Q1_BrandAware | proportion | 0.450 | 0.510 | +0.060 | 0.037 | 0.148 | Holm | * | | Sig. before, NS after |

**Summary Statistics (included on sheet):**

```
MULTIPLE COMPARISON ADJUSTMENT SUMMARY

Method Used: Holm (step-down procedure)
Number of Tests: 5
Original Significance Level: 0.05
Adjusted Significance Level: Varies by test (step-down)

RESULTS:
Tests Significant at α = 0.05 BEFORE adjustment: 2 (40.0%)
Tests Significant at α = 0.05 AFTER adjustment: 1 (20.0%)

INTERPRETATION:
The Holm method controls the family-wise error rate, reducing the risk of 
false positives when making multiple comparisons. 

Test #3 (Age_18_34) remains significant after adjustment (p_adj = 0.048),
indicating a robust difference from Total.

Test #5 (Age_55plus) was significant before adjustment (p = 0.037) but not 
after (p_adj = 0.148), suggesting this difference may be due to chance when 
considering multiple comparisons.
```

---

### 6.5 Example: Warnings Sheet

**Warnings Sheet:**

| Warning_ID | Severity | Warning_Type | Question_ID | Banner_Column | Value | Threshold | Message | Recommendation | Timestamp |
|------------|----------|--------------|-------------|---------------|-------|-----------|---------|----------------|-----------|
| W001 | Medium | Small_Base | Q3_LowIncidence | Age_55plus | 47 | 50 | Base size below recommended threshold | Interpret with caution. Consider combining age groups. | 2024-11-12 14:32:18 |
| W002 | Low | Extreme_Proportion | Q3_LowIncidence | Total | 0.080 | 0.10 | Low proportion detected | Wilson score interval used automatically. Results reliable. | 2024-11-12 14:32:19 |
| W003 | Medium | High_DEFF | - | Total | 2.15 | 2.00 | Weighting substantially reduces precision | Effective sample = 465 vs actual = 1000. Consider reviewing weights. | 2024-11-12 14:32:17 |
| W004 | Low | Missing_Data | Q5_NPS | - | 1.5% | 5.0% | Missing responses detected | 15 of 1000 respondents excluded. Within acceptable limits. | 2024-11-12 14:32:20 |
| W005 | Low | Weight_Range | - | Total | 5.6:1 | 10:1 | Wide range in weights | Min=0.421, Max=2.347. Within acceptable limits but monitor. | 2024-11-12 14:32:17 |

**Warning Severity Levels:**

```
LOW: Informational, no action typically needed
MEDIUM: Caution advised, interpret results carefully
HIGH: Serious concern, results may be unreliable
CRITICAL: Analysis may have failed or produced invalid results
```

---

### 6.6 Example: Decimal Separator Variant (European Format)

**Same data as 6.1, but with decimal_separator = ","**

**Proportions_Detail Sheet (first 3 rows):**

| Question_ID | Description | Banner_Column | Base_n | Proportion | Proportion_Pct | MOE_Lower | MOE_Upper | MOE_Width | Boot_Lower | Boot_Upper | Boot_SE |
|-------------|-------------|---------------|--------|------------|----------------|-----------|-----------|-----------|------------|------------|---------|
| Q1_BrandAware | Brand A Awareness | Total | 1000 | 0,45 | 45,0% | 0,42 | 0,48 | ±0,03 | 0,42 | 0,48 | 0,016 |
| Q1_BrandAware | Brand A Awareness | Male | 450 | 0,48 | 48,0% | 0,44 | 0,53 | ±0,05 | 0,43 | 0,52 | 0,023 |
| Q1_BrandAware | Brand A Awareness | Female | 550 | 0,42 | 42,0% | 0,38 | 0,46 | ±0,04 | 0,38 | 0,46 | 0,021 |

**Notes:**
- All numeric values use comma as decimal separator
- Integer values (Base_n) remain unchanged
- Percentages show comma: 45,0% instead of 45.0%
- Applies consistently across all sheets
- Internal calculations still use period (R standard)

---

### 6.7 Example: Simple Single-Code Proportion (Q10 Overall Satisfaction)

**Scenario:** Testing confidence intervals for a simple Yes/No question using all three methods

**User Configuration:**

Question_Analysis Sheet:
```
Question_ID | Statistic_Type | Categories | Description | Run_MOE | Run_Bootstrap | Run_Credible | Use_Wilson | Prior_Mean | Prior_N
-----------|----------------|------------|-------------|---------|---------------|--------------|------------|------------|--------
Q10        | proportion     | 1          | Overall Satisfaction = Yes | Y | Y | Y | N | | 
```

**Study Settings:**
- Confidence Level: 95%
- Bootstrap Iterations: 5000
- Decimal Separator: . (period)

**Output - Proportions_Detail Sheet:**

| Question_ID | Description | Statistic_Type | Categories | Banner_Column | Base_n | Effective_n | Proportion | Proportion_Pct | MOE_Lower | MOE_Upper | MOE_Width | MOE_Method | Boot_Lower | Boot_Upper | Boot_SE | Cred_Lower | Cred_Upper | Cred_Mean | Prior_Type | Prior_Mean | Prior_N | Warning | Notes |
|-------------|-------------|----------------|------------|---------------|--------|-------------|------------|----------------|-----------|-----------|-----------|------------|------------|------------|---------|------------|------------|-----------|------------|------------|---------|---------|-------|
| Q10 | Overall Satisfaction = Yes | proportion | 1 | Total | 1000 | 1000 | 0.72 | 72.0% | 0.69 | 0.75 | ±0.03 | Normal | 0.69 | 0.75 | 0.014 | 0.70 | 0.74 | 0.72 | Uninformed | | | | |
| Q10 | Overall Satisfaction = Yes | proportion | 1 | Male | 450 | 450 | 0.69 | 69.0% | 0.65 | 0.73 | ±0.04 | Normal | 0.64 | 0.73 | 0.022 | 0.66 | 0.72 | 0.69 | Uninformed | | | | |
| Q10 | Overall Satisfaction = Yes | proportion | 1 | Female | 550 | 550 | 0.75 | 75.0% | 0.71 | 0.79 | ±0.04 | Normal | 0.71 | 0.78 | 0.018 | 0.72 | 0.77 | 0.75 | Uninformed | | | | |
| Q10 | Overall Satisfaction = Yes | proportion | 1 | Age_18_34 | 300 | 300 | 0.68 | 68.0% | 0.63 | 0.73 | ±0.05 | Normal | 0.62 | 0.73 | 0.027 | 0.65 | 0.71 | 0.68 | Uninformed | | | | |
| Q10 | Overall Satisfaction = Yes | proportion | 1 | Age_35_54 | 400 | 400 | 0.74 | 74.0% | 0.70 | 0.78 | ±0.04 | Normal | 0.69 | 0.78 | 0.022 | 0.71 | 0.77 | 0.74 | Uninformed | | | | |
| Q10 | Overall Satisfaction = Yes | proportion | 1 | Age_55plus | 300 | 300 | 0.75 | 75.0% | 0.70 | 0.80 | ±0.05 | Normal | 0.69 | 0.80 | 0.025 | 0.71 | 0.78 | 0.75 | Uninformed | | | | |

**Interpretation for Total (72% satisfied):**

**Margin of Error (MOE):**
- 95% Confidence Interval: 69% to 75%
- Interpretation: "We're 95% confident the true satisfaction rate is between 69% and 75%"
- Width: ±3 percentage points

**Bootstrap Confidence Interval:**
- 95% CI: 69% to 75%
- Bootstrap SE: 0.014
- Interpretation: "Based on 5,000 resamples, we're 95% confident the true rate is between 69% and 75%"
- Very similar to parametric MOE (expected for large samples)

**Credible Interval (Bayesian):**
- 95% Credible Interval: 70% to 74%
- Posterior Mean: 72%
- Prior Type: Uninformed (Beta(1,1))
- Interpretation: "There's a 95% probability the true satisfaction rate is between 70% and 74%"
- Slightly narrower than frequentist intervals due to prior

**Key Observations:**
- All three methods produce very similar results for this sample size (n=1000)
- Credible interval is marginally narrower (more precise) due to incorporating prior information
- Bootstrap results validate the parametric assumptions
- No warnings flagged - all bases adequate

**With Informed Prior Example:**

If the user had specified a prior from a pilot study (e.g., Prior_Mean = 0.68, Prior_N = 400):

| Cred_Lower | Cred_Upper | Cred_Mean | Prior_Type | Prior_Mean | Prior_N |
|------------|------------|-----------|------------|------------|---------|
| 0.70 | 0.73 | 0.71 | Informed | 0.68 | 400 |

- The credible interval would be tighter (70% to 73%)
- Posterior mean (71%) pulled slightly toward prior (68%)
- Greater certainty due to combining current data with prior knowledge

---

### 6.8 Example: Mean Rating Analysis (Q12 Likelihood to Recommend)

**Scenario:** Testing confidence intervals for a 0-10 rating scale using all three methods

**User Configuration:**

Question_Analysis Sheet:
```
Question_ID | Statistic_Type | Exclude_Codes | Description | Run_MOE | Run_Bootstrap | Run_Credible | Prior_Mean | Prior_SD | Prior_N
-----------|----------------|---------------|-------------|---------|---------------|--------------|------------|----------|--------
Q12        | mean           | 99            | Likelihood to Recommend (0-10) | N | Y | Y | 7.5 | 2.0 | 500
```

**Study Settings:**
- Confidence Level: 95%
- Bootstrap Iterations: 5000
- Decimal Separator: . (period)
- Code 99 = "Don't Know" (excluded from mean calculation)

**Output - Means_Detail Sheet:**

| Question_ID | Description | Statistic_Type | Exclude_Codes | Banner_Column | Base_n | Effective_n | Mean | SD | SE | CI_Lower | CI_Upper | CI_Method | Boot_Lower | Boot_Upper | Boot_SE | Boot_Mean | Cred_Lower | Cred_Upper | Cred_Mean | Prior_Type | Prior_Mean | Prior_SD | Prior_N | Warning | Notes |
|-------------|-------------|----------------|---------------|---------------|--------|-------------|------|-----|-----|----------|----------|-----------|------------|------------|---------|-----------|------------|------------|-----------|------------|------------|----------|---------|---------|-------|
| Q12 | Likelihood to Recommend (0-10) | mean | 99 | Total | 985 | 985 | 7.8 | 1.9 | 0.061 | 7.68 | 7.92 | t(984) | 7.67 | 7.93 | 0.062 | 7.80 | 7.70 | 7.87 | 7.77 | Informed | 7.5 | 2.0 | 500 | | Prior from pilot |
| Q12 | Likelihood to Recommend (0-10) | mean | 99 | Male | 442 | 442 | 8.1 | 1.7 | 0.081 | 7.94 | 8.26 | t(441) | 7.93 | 8.27 | 0.083 | 8.10 | 7.98 | 8.22 | 8.08 | Informed | 7.5 | 2.0 | 500 | | |
| Q12 | Likelihood to Recommend (0-10) | mean | 99 | Female | 543 | 543 | 7.6 | 2.0 | 0.086 | 7.43 | 7.77 | t(542) | 7.42 | 7.78 | 0.088 | 7.60 | 7.49 | 7.71 | 7.58 | Informed | 7.5 | 2.0 | 500 | | |
| Q12 | Likelihood to Recommend (0-10) | mean | 99 | Age_18_34 | 295 | 295 | 7.3 | 2.2 | 0.128 | 7.05 | 7.55 | t(294) | 7.03 | 7.57 | 0.132 | 7.30 | 7.15 | 7.48 | 7.31 | Informed | 7.5 | 2.0 | 500 | | |
| Q12 | Likelihood to Recommend (0-10) | mean | 99 | Age_35_54 | 394 | 394 | 7.9 | 1.8 | 0.091 | 7.72 | 8.08 | t(393) | 7.71 | 8.09 | 0.093 | 7.90 | 7.77 | 8.01 | 7.88 | Informed | 7.5 | 2.0 | 500 | | |
| Q12 | Likelihood to Recommend (0-10) | mean | 99 | Age_55plus | 296 | 296 | 8.2 | 1.6 | 0.093 | 8.02 | 8.38 | t(295) | 8.01 | 8.39 | 0.095 | 8.20 | 8.06 | 8.32 | 8.18 | Informed | 7.5 | 2.0 | 500 | | |

**Interpretation for Total (Mean = 7.8):**

**Traditional Confidence Interval (t-distribution):**
- 95% CI: 7.68 to 7.92
- Standard Error: 0.061
- Method: t(984) - t-distribution with 984 degrees of freedom
- Interpretation: "We're 95% confident the true mean rating is between 7.68 and 7.92"

**Bootstrap Confidence Interval:**
- 95% CI: 7.67 to 7.93
- Bootstrap SE: 0.062
- Bootstrap Mean: 7.80
- Interpretation: "Based on 5,000 resamples, we're 95% confident the true mean is between 7.67 and 7.93"
- Virtually identical to parametric CI (validates normality assumption)

**Credible Interval (Bayesian):**
- 95% Credible Interval: 7.70 to 7.87
- Posterior Mean: 7.77
- Prior: Normal(7.5, SD=2.0, n=500)
- Prior Type: Informed
- Interpretation: "There's a 95% probability the true mean rating is between 7.70 and 7.87"
- Narrower interval due to incorporating prior information from pilot study

**Key Observations:**

1. **Prior Impact:** 
   - Current data: Mean = 7.8 (n=985)
   - Prior data: Mean = 7.5 (n=500)
   - Posterior mean = 7.77 (pulled slightly toward prior)
   - Credible interval is tighter than frequentist intervals

2. **Method Comparison:**
   - Traditional CI width: 0.24 (7.68 to 7.92)
   - Bootstrap CI width: 0.26 (7.67 to 7.93)
   - Credible CI width: 0.17 (7.70 to 7.87) - 30% narrower!

3. **Gender Differences:**
   - Male: 8.1 (significantly higher)
   - Female: 7.6 (significantly lower)
   - All methods show non-overlapping CIs with Total

4. **Age Pattern:**
   - Youngest group (7.3) shows lowest ratings
   - Oldest group (8.2) shows highest ratings
   - Clear trend visible across all confidence methods

**Without Prior (Uninformed) Example:**

If user had not specified a prior, the Credible Interval columns would show:

| Cred_Lower | Cred_Upper | Cred_Mean | Prior_Type |
|------------|------------|-----------|------------|
| 7.68 | 7.92 | 7.80 | Uninformed |

- Credible interval would match the traditional CI
- No additional precision gained
- Posterior mean equals sample mean

**Data Quality Notes:**
- Base_n = 985 (15 respondents excluded for code 99 "Don't Know")
- Missing data rate: 1.5% (acceptable)
- SD = 1.9 indicates moderate variability on 0-10 scale
- No warnings flagged

---

### 6.9 Example: Net Promoter Score (NPS) Analysis (Q8 Likelihood to Recommend)

**Scenario:** Calculating NPS with all three confidence methods

**User Configuration:**

Question_Analysis Sheet:
```
Question_ID | Statistic_Type | Exclude_Codes | Promoter_Codes | Detractor_Codes | Description | Run_MOE | Run_Bootstrap | Run_Credible | Prior_Mean | Prior_SD | Prior_N
-----------|----------------|---------------|----------------|-----------------|-------------|---------|---------------|--------------|------------|----------|--------
Q8         | nps            | 99            | 9,10           | 0,1,2,3,4,5,6   | Net Promoter Score | Y | Y | Y | 25 | 15 | 450
```

**Study Settings:**
- Confidence Level: 95%
- Bootstrap Iterations: 5000
- Decimal Separator: . (period)
- Code 99 = "Don't Know" (excluded from all calculations)
- Promoters = 9-10 on 0-10 scale
- Detractors = 0-6 on 0-10 scale
- Passives = 7-8 (reported but not used in NPS calculation)

**Output - NPS_Detail Sheet:**

| Question_ID | Description | Statistic_Type | Promoter_Codes | Detractor_Codes | Exclude_Codes | Banner_Column | Base_n | Effective_n | Promoter_Pct | Passive_Pct | Detractor_Pct | NPS | NPS_MOE_Lower | NPS_MOE_Upper | NPS_MOE_Width | NPS_Boot_Lower | NPS_Boot_Upper | NPS_Boot_SE | NPS_Boot_Mean | NPS_Cred_Lower | NPS_Cred_Upper | NPS_Cred_Mean | Promoter_Cred_Lower | Promoter_Cred_Upper | Detractor_Cred_Lower | Detractor_Cred_Upper | Prior_Type | Prior_NPS | Prior_N | Warning | Notes |
|-------------|-------------|----------------|----------------|-----------------|---------------|---------------|--------|-------------|--------------|-------------|---------------|-----|---------------|---------------|---------------|----------------|----------------|-------------|---------------|----------------|----------------|---------------|---------------------|---------------------|----------------------|----------------------|------------|-----------|---------|---------|-------|
| Q8 | Net Promoter Score | nps | 9,10 | 0,1,2,3,4,5,6 | 99 | Total | 985 | 985 | 42.0% | 38.0% | 20.0% | 22 | 16 | 28 | ±6 | 16 | 29 | 3.2 | 22.1 | 17 | 27 | 22.0 | 38.5% | 45.5% | 17.0% | 23.0% | Informed | 25 | 450 | | Prior from W1 |
| Q8 | Net Promoter Score | nps | 9,10 | 0,1,2,3,4,5,6 | 99 | Male | 442 | 442 | 45.0% | 36.0% | 19.0% | 26 | 18 | 34 | ±8 | 17 | 35 | 4.6 | 26.2 | 19 | 33 | 26.1 | 40.0% | 50.0% | 14.5% | 23.5% | Informed | 25 | 450 | | |
| Q8 | Net Promoter Score | nps | 9,10 | 0,1,2,3,4,5,6 | 99 | Female | 543 | 543 | 39.0% | 40.0% | 21.0% | 18 | 11 | 25 | ±7 | 11 | 26 | 3.8 | 18.3 | 12 | 24 | 18.2 | 34.5% | 43.5% | 17.5% | 24.5% | Informed | 25 | 450 | | |
| Q8 | Net Promoter Score | nps | 9,10 | 0,1,2,3,4,5,6 | 99 | Age_18_34 | 295 | 295 | 35.0% | 40.0% | 25.0% | 10 | 1 | 19 | ±9 | 0 | 20 | 5.1 | 10.3 | 3 | 17 | 10.1 | 29.5% | 40.5% | 20.0% | 30.0% | Informed | 25 | 450 | | |
| Q8 | Net Promoter Score | nps | 9,10 | 0,1,2,3,4,5,6 | 99 | Age_35_54 | 394 | 394 | 44.0% | 38.0% | 18.0% | 26 | 18 | 34 | ±8 | 17 | 35 | 4.6 | 26.5 | 19 | 33 | 26.2 | 39.0% | 49.0% | 13.5% | 22.5% | Informed | 25 | 450 | | |
| Q8 | Net Promoter Score | nps | 9,10 | 0,1,2,3,4,5,6 | 99 | Age_55plus | 296 | 296 | 48.0% | 36.0% | 16.0% | 32 | 23 | 41 | ±9 | 22 | 42 | 5.1 | 32.3 | 25 | 39 | 32.1 | 42.0% | 54.0% | 11.0% | 21.0% | Informed | 25 | 450 | | |

**Interpretation for Total (NPS = 22):**

**Component Breakdown:**
- Promoters (9-10): 42.0% of respondents
- Passives (7-8): 38.0% of respondents
- Detractors (0-6): 20.0% of respondents
- NPS = 42% - 20% = +22

**Margin of Error (Difference of Proportions):**
- 95% CI: 16 to 28
- Width: ±6 NPS points
- Interpretation: "We're 95% confident the true NPS is between +16 and +28"
- Calculation accounts for variance in both promoters and detractors

**Bootstrap Confidence Interval:**
- 95% CI: 16 to 29
- Bootstrap SE: 3.2
- Bootstrap Mean NPS: 22.1
- Interpretation: "Based on 5,000 resamples, we're 95% confident the true NPS is between +16 and +29"
- Very similar to parametric MOE

**Credible Interval (Bayesian):**
- 95% Credible Interval: 17 to 27
- Posterior Mean NPS: 22.0
- Prior: NPS = 25 (from Wave 1, n=450)
- Prior Type: Informed
- Interpretation: "There's a 95% probability the true NPS is between +17 and +27"
- Slightly tighter than frequentist intervals due to incorporating prior knowledge

**Component Credible Intervals:**
- Promoters: 38.5% to 45.5% (observed 42%)
- Detractors: 17.0% to 23.0% (observed 20%)
- These show uncertainty in each component separately

**Key Observations:**

1. **Prior Impact:** 
   - Current data: NPS = 22 (n=985)
   - Prior data: NPS = 25 (n=450)
   - Posterior mean NPS = 22.0 (pulled slightly toward prior)
   - Prior information helps tighten the interval

2. **Method Comparison:**
   - MOE CI width: 12 points (16 to 28)
   - Bootstrap CI width: 13 points (16 to 29)
   - Credible CI width: 10 points (17 to 27) - 20% narrower!

3. **Gender Differences:**
   - Male: NPS = +26 (significantly higher)
   - Female: NPS = +18 (significantly lower)
   - No overlap in confidence intervals suggests real difference

4. **Age Pattern:**
   - Youngest group (Age 18-34): NPS = +10 (lowest)
   - Oldest group (Age 55+): NPS = +32 (highest)
   - Clear positive trend with age
   - Age 18-34 CI includes values near zero, indicating uncertainty

**NPS Classification (Standard Benchmarks):**
- Total NPS = +22 falls in "Good" range
- Range 0-30 = Good
- Range 30-70 = Great
- Range 70-100 = Excellent
- Below 0 = Needs improvement

**Data Quality Notes:**
- Base_n = 985 (15 respondents excluded for code 99 "Don't Know")
- Missing data rate: 1.5% (acceptable)
- Strong promoter base (42%) with moderate detractors (20%)
- No warnings flagged - sufficient base sizes across all segments

**Without Prior (Uninformed) Example:**

If user had not specified a prior, the Credible Interval columns would show:

| NPS_Cred_Lower | NPS_Cred_Upper | NPS_Cred_Mean | Prior_Type |
|----------------|----------------|---------------|------------|
| 16 | 28 | 22.0 | Uninformed |

- Credible interval would closely match the traditional MOE
- No additional precision gained from prior information
- Posterior mean equals observed NPS

**Comparison to Previous Wave:**
With Prior_NPS = 25 from Wave 1 and observed NPS = 22 in current wave:
- Decline of 3 points, but within margin of error
- Credible interval (17 to 27) includes the prior mean of 25
- Cannot conclude with 95% confidence that NPS has changed
- Recommendation: Continue monitoring in future waves

---

## 7. Code Architecture

### 7.1 Modular Design Principles

**Each R script should:**
- Focus on one logical area of functionality
- Export clearly documented functions
- Handle its own error checking
- Be independently testable
- Have minimal dependencies on other modules

### 7.2 Function Naming Conventions

```r
# Use verb_noun pattern
load_config()
validate_data()
calculate_moe()
run_bootstrap()

# Be specific
calculate_proportion_moe()
calculate_mean_ci()
extract_prior_parameters()

# Internal helper functions start with dot
.check_valid_proportion()
.resample_indices()
.format_with_decimal_sep()
```

### 7.3 Key Function Specifications

**7.3.1 Config Loading (01_load_config.R)**

```r
#' Load confidence analysis configuration
#'
#' Reads and validates the confidence_config.xlsx file
#'
#' @param config_path Character. Path to confidence_config.xlsx
#'
#' @return List with three elements:
#'   - file_paths: data frame from File_Paths sheet
#'   - study_settings: data frame from Study_Settings sheet  
#'   - question_analysis: data frame from Question_Analysis sheet
#'
#' @export
load_confidence_config <- function(config_path) {
  # Implementation
}

#' Validate configuration inputs
#'
#' Checks all config values are valid and within limits
#'
#' @param config List. Output from load_confidence_config()
#'
#' @return List with valid = TRUE/FALSE and messages vector
#'
#' @export
validate_config <- function(config) {
  # Check question count
  n_questions <- nrow(config$question_analysis)
  if (n_questions > 200) {
    return(list(
      valid = FALSE,
      messages = sprintf("Question limit exceeded: %d questions specified (maximum 200)", n_questions)
    ))
  }
  # Additional validation...
}
```

**7.3.2 Output Formatting (07_output.R)**

```r
#' Format numeric values with specified decimal separator
#'
#' Converts numeric values to character strings with user-specified
#' decimal separator for output
#'
#' @param x Numeric vector. Values to format
#' @param decimal_sep Character. "." or ","
#' @param digits Integer. Number of decimal places
#'
#' @return Character vector. Formatted numbers
#'
#' @examples
#' format_decimal(c(0.456, 1.234), decimal_sep = ",", digits = 2)
#' # Returns: c("0,46", "1,23")
#'
#' @export
format_decimal <- function(x, decimal_sep = ".", digits = 2) {
  formatted <- formatC(x, format = "f", digits = digits)
  if (decimal_sep == ",") {
    formatted <- gsub("\\.", ",", formatted)
  }
  return(formatted)
}

#' Apply decimal formatting to all numeric columns in data frame
#'
#' @param df Data frame. Output data
#' @param decimal_sep Character. "." or ","
#' @param digits Integer. Decimal places (default 2)
#' @param exclude_cols Character vector. Columns to exclude from formatting
#'
#' @return Data frame with formatted numeric columns
#'
#' @export
format_output_df <- function(df, decimal_sep = ".", digits = 2, 
                              exclude_cols = c("Base_n", "Effective_n")) {
  # Implementation
}
```

**7.3.3 Effective Sample Size (03_study_level.R)**

```r
#' Calculate effective sample size and design effect
#'
#' For weighted data, calculates DEFF using Kish approximation
#' and effective sample size
#'
#' @param data Data frame. Survey data
#' @param weight_var Character. Name of weight variable (NULL if unweighted)
#' @param grouping_var Character. Variable defining columns (NULL for total)
#'
#' @return Data frame with columns:
#'   - group_value
#'   - actual_n
#'   - sum_weights
#'   - mean_weight
#'   - min_weight
#'   - max_weight
#'   - weight_cv
#'   - deff
#'   - effective_n
#'   - warning
#'
#' @references
#' Kish, L. (1965). Survey Sampling. Wiley.
#'
#' @export
calculate_effective_n <- function(data, weight_var = NULL, grouping_var = NULL) {
  # Implementation
}
```

**7.3.4 Proportion Methods (04_proportions.R)**

```r
#' Calculate margin of error for proportion
#'
#' @param p Numeric. Proportion (0 to 1)
#' @param n Integer. Sample size
#' @param conf_level Numeric. Confidence level (default 0.95)
#' @param method Character. "normal" or "wilson" (default "normal")
#'
#' @return List with:
#'   - lower: Lower confidence limit
#'   - upper: Upper confidence limit
#'   - moe: Margin of error
#'   - method: Method used
#'
#' @export
calculate_proportion_ci <- function(p, n, conf_level = 0.95, 
                                   method = "normal") {
  # Implementation
}

#' Bootstrap confidence interval for proportion
#'
#' @param data Vector. Binary data or categorical data with specified categories
#' @param categories Vector. Categories to include in proportion
#' @param weights Vector. Survey weights (NULL if unweighted)
#' @param B Integer. Number of bootstrap iterations
#' @param conf_level Numeric. Confidence level
#' @param seed Integer. Random seed for reproducibility
#'
#' @return List with:
#'   - lower: Lower confidence limit
#'   - upper: Upper confidence limit
#'   - boot_se: Bootstrap standard error
#'   - boot_mean: Bootstrap mean proportion
#'   - boot_samples: Vector of all bootstrap proportions (for diagnostics)
#'
#' @export
bootstrap_proportion_ci <- function(data, categories, weights = NULL,
                                   B = 5000, conf_level = 0.95, 
                                   seed = NULL) {
  # Implementation
}

#' Bayesian credible interval for proportion
#'
#' @param p Numeric. Observed proportion
#' @param n Integer. Sample size
#' @param conf_level Numeric. Confidence level
#' @param prior_mean Numeric. Prior proportion (NULL for uninformed)
#' @param prior_n Integer. Prior sample size
#'
#' @return List with:
#'   - lower: Lower credible limit
#'   - upper: Upper credible limit
#'   - post_mean: Posterior mean
#'   - prior_alpha: Prior Beta alpha parameter
#'   - prior_beta: Prior Beta beta parameter
#'
#' @export
credible_interval_proportion <- function(p, n, conf_level = 0.95,
                                        prior_mean = NULL, prior_n = NULL) {
  # Implementation
}
```

**7.3.5 Mean Methods (05_means.R)**

```r
#' Calculate confidence interval for mean
#'
#' Uses t-distribution
#'
#' @param values Vector. Numeric data
#' @param weights Vector. Survey weights (NULL if unweighted)
#' @param conf_level Numeric. Confidence level
#'
#' @return List with:
#'   - mean: Sample mean
#'   - sd: Standard deviation
#'   - se: Standard error
#'   - lower: Lower confidence limit
#'   - upper: Upper confidence limit
#'   - df: Degrees of freedom
#'
#' @export
calculate_mean_ci <- function(values, weights = NULL, conf_level = 0.95) {
  # Implementation
}

#' Bootstrap confidence interval for mean
#'
#' @param values Vector. Numeric data
#' @param weights Vector. Survey weights (NULL if unweighted)
#' @param B Integer. Number of bootstrap iterations
#' @param conf_level Numeric. Confidence level
#' @param seed Integer. Random seed
#'
#' @return List with:
#'   - lower: Lower confidence limit
#'   - upper: Upper confidence limit
#'   - boot_se: Bootstrap standard error
#'   - boot_mean: Bootstrap mean
#'   - boot_samples: Vector of all bootstrap means
#'
#' @export
bootstrap_mean_ci <- function(values, weights = NULL, B = 5000,
                             conf_level = 0.95, seed = NULL) {
  # Implementation
}

#' Bayesian credible interval for mean
#'
#' @param values Vector. Numeric data
#' @param weights Vector. Survey weights (NULL if unweighted)
#' @param conf_level Numeric. Confidence level
#' @param prior_mean Numeric. Prior mean (NULL for uninformed)
#' @param prior_sd Numeric. Prior standard deviation
#' @param prior_n Integer. Prior sample size
#'
#' @return List with:
#'   - lower: Lower credible limit
#'   - upper: Upper credible limit
#'   - post_mean: Posterior mean
#'   - post_sd: Posterior standard deviation
#'
#' @export
credible_interval_mean <- function(values, weights = NULL, 
                                  conf_level = 0.95,
                                  prior_mean = NULL, prior_sd = NULL,
                                  prior_n = NULL) {
  # Implementation
}
```

**7.3.6 Multiple Comparisons (06_multiple_comparisons.R)**

```r
#' Adjust p-values for multiple comparisons
#'
#' @param p_values Vector. Original p-values
#' @param method Character. "bonferroni", "holm", or "fdr"
#'
#' @return Data frame with:
#'   - original_p
#'   - adjusted_p
#'   - method
#'   - significant_original (at alpha = 0.05)
#'   - significant_adjusted (at alpha = 0.05)
#'
#' @export
adjust_pvalues <- function(p_values, method = "holm") {
  # Implementation
}
```

### 7.4 Error Handling Strategy

**All functions should:**

```r
# 1. Validate inputs
if (!is.numeric(p) || p < 0 || p > 1) {
  stop("p must be a proportion between 0 and 1")
}

# 2. Check for edge cases
if (n < 30) {
  warning("Sample size < 30. Results may be unstable.")
}

# 3. Handle missing data
if (any(is.na(values))) {
  warning(sprintf("Removing %d missing values", sum(is.na(values))))
  values <- values[!is.na(values)]
}

# 4. Validate decimal separator
if (!decimal_sep %in% c(".", ",")) {
  stop("decimal_sep must be either '.' or ','")
}

# 5. Check question limit
if (nrow(question_analysis) > 200) {
  stop(sprintf("Question limit exceeded: %d questions (max 200)", 
               nrow(question_analysis)))
}

# 6. Return informative errors
tryCatch({
  result <- complex_calculation()
}, error = function(e) {
  stop(sprintf("Failed in calculate_moe for Question %s: %s", 
               question_id, e$message))
})
```

### 7.5 Testing Strategy

**Required tests for each module:**

```r
# tests/test_proportions.R

test_that("MOE calculation matches hand calculation", {
  # Known values
  p <- 0.5
  n <- 100
  expected_moe <- 1.96 * sqrt(0.5 * 0.5 / 100)
  
  result <- calculate_proportion_ci(p, n, conf_level = 0.95)
  
  expect_equal(result$moe, expected_moe, tolerance = 0.001)
})

test_that("Wilson score handles extreme proportions", {
  p <- 0.01
  n <- 50
  
  result <- calculate_proportion_ci(p, n, method = "wilson")
  
  expect_true(result$lower >= 0)
  expect_true(result$upper <= 1)
})

test_that("Bootstrap is reproducible with seed", {
  data <- rbinom(100, 1, 0.6)
  
  result1 <- bootstrap_proportion_ci(data, categories = 1, seed = 123)
  result2 <- bootstrap_proportion_ci(data, categories = 1, seed = 123)
  
  expect_equal(result1$lower, result2$lower)
  expect_equal(result1$upper, result2$upper)
})

test_that("Decimal separator formatting works correctly", {
  expect_equal(format_decimal(0.456, ",", 2), "0,46")
  expect_equal(format_decimal(0.456, ".", 2), "0.46")
  expect_equal(format_decimal(1.234, ",", 3), "1,234")
})

test_that("Question limit is enforced", {
  config <- list(
    question_analysis = data.frame(Question_ID = paste0("Q", 1:201))
  )
  
  validation <- validate_config(config)
  expect_false(validation$valid)
  expect_true(grepl("Question limit exceeded", validation$messages))
})
```

**Integration tests:**

```r
# tests/test_integration.R

test_that("Full workflow runs without errors", {
  # Use example config and data
  config <- load_confidence_config("examples/example_confidence_config.xlsx")
  
  expect_true(validate_config(config)$valid)
  
  # Should complete without errors
  expect_error(
    run_confidence_analysis(config),
    NA
  )
  
  # Output file should exist
  expect_true(file.exists(config$file_paths$output_file))
})

test_that("Analysis handles 200 questions", {
  # Create config with 200 questions
  config <- create_large_config(n_questions = 200)
  
  expect_true(validate_config(config)$valid)
  
  # Should complete (may be slow)
  expect_error(
    run_confidence_analysis(config),
    NA
  )
})

test_that("Decimal separator applies to all outputs", {
  config <- load_confidence_config("examples/example_config_comma.xlsx")
  
  run_confidence_analysis(config)
  
  # Read output and check formatting
  output <- readxl::read_excel(config$file_paths$output_file, 
                                sheet = "Proportions_Detail")
  
  # Check that numeric columns use comma
  expect_true(all(grepl(",", output$Proportion[1:10])))
})
```

---

## 8. Performance Considerations

### 8.1 Expected Performance Targets

| Dataset Size | Questions | Bootstrap Iterations | Expected Runtime |
|--------------|-----------|---------------------|------------------|
| 500 respondents | 5 questions | 5000 | < 30 seconds |
| 1000 respondents | 10 questions | 5000 | < 2 minutes |
| 1000 respondents | 50 questions | 5000 | < 8 minutes |
| 5000 respondents | 20 questions | 5000 | < 10 minutes |
| 5000 respondents | 100 questions | 5000 | < 45 minutes |
| 10000 respondents | 50 questions | 5000 | < 30 minutes |
| 10000 respondents | 200 questions | 10000 | < 3 hours |

**Note:** Performance will vary based on:
- Number of banner columns
- Proportion of questions using bootstrap
- Hardware specifications
- Whether data is weighted

### 8.2 Optimization Strategies

**Bootstrap Optimization:**
```r
# Use vectorization where possible
# Instead of:
for (i in 1:B) {
  resample <- sample(data, replace = TRUE)
  results[i] <- mean(resample)
}

# Do:
library(boot)
boot_results <- boot(data, statistic = function(x, i) mean(x[i]), R = B)
```

**Parallel Processing (Future Enhancement):**
```r
# For large datasets, consider parallel bootstrap
library(parallel)
cl <- makeCluster(detectCores() - 1)
# ... parallel operations ...
stopCluster(cl)
```

**Progress Reporting:**
```r
# For long-running operations
message(sprintf("Processing question %d of %d: %s", 
                i, n_questions, question_id))

# Consider progress bars for batch operations
if (requireNamespace("progress", quietly = TRUE)) {
  pb <- progress::progress_bar$new(
    total = n_questions,
    format = "[:bar] :percent :eta remaining"
  )
  for (i in 1:n_questions) {
    # ... processing ...
    pb$tick()
  }
}
```

**Memory Management:**
```r
# For 200 questions, manage memory carefully
# Clear large objects when no longer needed
rm(bootstrap_samples)
gc()

# Consider processing in batches if memory constrained
batch_size <- 50
for (batch_start in seq(1, n_questions, by = batch_size)) {
  batch_end <- min(batch_start + batch_size - 1, n_questions)
  # Process batch
  # Save results
  # Clear memory
}
```

---

## 9. Dependencies

### 9.1 Required R Packages

**Core:**
- readxl (>= 1.4.0) - Reading Excel files
- writexl (>= 1.4.0) - Writing Excel files (or openxlsx for more control)
- dplyr (>= 1.1.0) - Data manipulation
- tidyr (>= 1.3.0) - Data reshaping

**Statistical:**
- boot (>= 1.3-28) - Bootstrap methods
- Hmisc (>= 5.0-0) - Weighted statistics

**Optional (with fallbacks):**
- testthat (>= 3.0.0) - Unit testing
- knitr (>= 1.42) - Documentation
- progress (>= 1.2.2) - Progress bars

### 9.2 Dependency Management

```r
# At top of each script
required_packages <- c("readxl", "writexl", "dplyr", "boot")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    stop(sprintf("Package '%s' is required but not installed.", pkg))
  }
}
```

### 9.3 Version Tracking

```r
# In output file methodology sheet, include:
session_info <- sessionInfo()

# Record:
# - R version
# - Platform
# - All package versions used
# - Date/time of analysis
```

---

## 10. Future Extensions (Out of Scope for Phase 1)

### 10.1 Phase 2 Enhancements

**Automatic Prior Extraction:**
- Point to previous wave tabs output
- Automatically extract proportions/means as priors
- Handle multiple waves (rolling averages)

**Smart Integration:**
- Reference nets/top boxes from crosstab_config
- Reduce duplication of specifications

**Advanced Sample Designs:**
- Stratified sampling adjustments
- Cluster sampling (ICC adjustments)
- Finite Population Correction

**Performance:**
- Parallel bootstrap processing
- Optimize for >200 questions
- Incremental output (stream results)

### 10.2 Phase 3 Enhancements

**Additional Methods:**
- Permutation tests
- Exact tests for small samples
- Non-parametric bootstrap (BCa)

**Interactive Mode:**
- Shiny interface for selecting questions
- Real-time parameter adjustment
- Interactive plots

**Integration:**
- Unified output with tabs module
- Cross-module confidence checks (segmentation, KDA)

---

## 11. Validation and Testing

### 11.1 Unit Testing Requirements

**Minimum test coverage: 80%**

Each module should have tests for:
- Normal cases
- Edge cases (n=1, p=0, p=1, etc.)
- Error conditions
- Weighted vs unweighted data
- Consistency checks (e.g., bootstrap CI should contain point estimate)
- Decimal separator formatting
- 200 question limit

### 11.2 Integration Testing

**Test scenarios:**
1. Minimal config (1 question, MOE only)
2. Full config (multiple questions, all methods)
3. Weighted data with DEFF
4. Informed priors
5. Multiple comparison adjustments
6. Mixed proportions and means
7. Maximum questions (200)
8. European decimal format (comma)

### 11.3 Validation Against Known Results

**Create reference datasets with:**
- Hand-calculated results
- Results from established software (SPSS, Stata)
- Extreme cases (n=10, p=0.99, etc.)

**Tolerance:**
- Exact methods: match to machine precision
- Bootstrap/simulation: match within expected Monte Carlo error
- Document any systematic differences

### 11.4 User Acceptance Testing

**Checklist:**
- [ ] Config file is intuitive to set up
- [ ] Error messages are clear and actionable
- [ ] Output is easy to interpret
- [ ] Performance meets targets for 200 questions
- [ ] Results match expectations
- [ ] Documentation is complete
- [ ] Decimal separator works correctly
- [ ] Question limit properly enforced

---

## 12. Documentation Deliverables

### 12.1 For Developers

**Technical Documentation (docs/technical_documentation.md):**
- Architecture overview
- Module descriptions
- Function reference
- Database schema (if applicable)
- Testing procedures

**Formula Documentation (docs/calculation_formulas.md):**
- All statistical formulas with LaTeX
- Worked examples
- References to academic sources
- Edge case handling

### 12.2 For Users

**User Guide (docs/user_guide.md):**
- Quick start guide
- Config file setup instructions
- Interpretation of results
- Common scenarios (with examples)
- Troubleshooting guide
- FAQs
- Decimal separator selection guide

**Example Files:**
- Complete working example with:
  - Sample data
  - Filled-out confidence_config.xlsx
  - Expected output (both decimal formats)
  - Interpretation notes

### 12.3 In-Code Documentation

**Every function must have:**
- Roxygen2 documentation
- @param for each parameter
- @return describing return value
- @examples with working examples
- @references for statistical methods

---

## 13. Change Log and Versioning

### 13.1 Versioning Scheme

Use semantic versioning: MAJOR.MINOR.PATCH

- MAJOR: Breaking changes to config format or output structure
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

### 13.2 Change Log

Maintain CHANGELOG.md:

```
# Changelog

## [1.0.0] - 2025-11-12
### Added
- Initial release
- Proportion-based methods (MOE, Bootstrap, Credible Intervals, Wilson)
- Mean-based methods (CI, Bootstrap, Credible Intervals)
- Study-level effective sample size calculation
- Multiple comparison adjustments (Bonferroni, Holm, FDR)
- Manual prior specification
- Support for up to 200 questions
- User-configurable decimal separator (period or comma)

### Known Limitations
- No automatic prior extraction from previous waves
- No direct integration with tabs output
- Bootstrap uses basic percentile method only
- No parallel processing (long run times for 200 questions)
```

---

## 14. Success Criteria

### 14.1 Phase 1 Complete When:

- [ ] All core methods implemented and tested
- [ ] Unit test coverage > 80%
- [ ] All integration tests pass
- [ ] Validation against known results successful
- [ ] Performance targets met (including 200 questions)
- [ ] All documentation complete
- [ ] User guide written and reviewed
- [ ] Example files provided (both decimal formats)
- [ ] Code review completed
- [ ] User acceptance testing completed
- [ ] Decimal separator functionality verified
- [ ] 200 question limit tested and working

### 14.2 Quality Gates

**Code Review Checklist:**
- [ ] Functions follow naming conventions
- [ ] All functions documented with roxygen2
- [ ] No hard-coded values (use parameters)
- [ ] Error handling implemented
- [ ] Edge cases handled
- [ ] Code is DRY (Don't Repeat Yourself)
- [ ] Consistent style throughout
- [ ] Decimal separator formatting correct
- [ ] Question limit properly enforced

**Testing Checklist:**
- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Validation tests pass
- [ ] Performance tests pass (200 questions)
- [ ] No unhandled warnings/errors in test runs
- [ ] Decimal separator tests pass
- [ ] Question limit tests pass

---

## 15. Support and Maintenance

### 15.1 Issue Tracking

Use GitHub Issues (or equivalent) with labels:
- bug: Something isn't working
- enhancement: New feature request
- documentation: Documentation improvements
- question: User question/clarification
- performance: Performance issues

### 15.2 Maintenance Plan

**Regular maintenance:**
- Update package dependencies (quarterly)
- Review and close stale issues (monthly)
- Performance profiling (bi-annually)

**User support:**
- Document common issues in FAQ
- Provide example solutions
- Consider user forum or Slack channel

---

## Appendix A: Statistical Formulas Reference

### A.1 Margin of Error (Normal Approximation)

$$MOE = z_{\alpha/2} \times \sqrt{\frac{p(1-p)}{n}}$$

Where:
- $z_{\alpha/2}$ = critical value from standard normal distribution
- For 95% CI: $z_{0.025} = 1.96$
- $p$ = observed proportion
- $n$ = sample size

**Confidence Interval:**
$$CI = [p - MOE, p + MOE]$$

### A.2 Wilson Score Interval

$$\frac{p + \frac{z^2}{2n} \pm z\sqrt{\frac{p(1-p)}{n} + \frac{z^2}{4n^2}}}{1 + \frac{z^2}{n}}$$

More accurate for small samples and extreme proportions.

### A.3 Design Effect (Kish Approximation)

$$DEFF = 1 + CV_w^2$$

Where:
$$CV_w = \frac{\sigma_w}{\bar{w}}$$

$CV_w$ = coefficient of variation of weights

**Effective Sample Size:**
$$n_{eff} = \frac{n_{actual}}{DEFF}$$

### A.4 Bayesian Credible Interval for Proportion

**Prior:** $p \sim Beta(\alpha_0, \beta_0)$

**Posterior:** $p | data \sim Beta(\alpha_0 + s, \beta_0 + f)$

Where:
- $s$ = number of successes
- $f$ = number of failures
- For uninformed prior: $\alpha_0 = \beta_0 = 1$
- For informed prior: $\alpha_0 = \mu_0 \times n_0$, $\beta_0 = (1-\mu_0) \times n_0$

**Credible Interval:**
$$CI = [Beta_{(\alpha/2)}(\alpha_1, \beta_1), Beta_{(1-\alpha/2)}(\alpha_1, \beta_1)]$$

### A.5 Multiple Comparison Adjustments

**Bonferroni:**
$$p_{adj} = min(p \times m, 1)$$

**Holm (step-down):**
1. Order p-values: $p_{(1)} \leq p_{(2)} \leq ... \leq p_{(m)}$
2. For $i = 1, ..., m$:
   $$p_{adj(i)} = max_{j=1,...,i}\{min((m-j+1) \times p_{(j)}, 1)\}$$

**FDR (Benjamini-Hochberg):**
1. Order p-values: $p_{(1)} \leq p_{(2)} \leq ... \leq p_{(m)}$
2. For $i = 1, ..., m$:
   $$p_{adj(i)} = min_{k=i,...,m}\{min(\frac{m}{k} \times p_{(k)}, 1)\}$$

---

## Appendix B: Example Configurations

### B.1 Simple Analysis (MOE Only) - 10 Questions

**confidence_config.xlsx - Question_Analysis:**

```
Question_ID | Statistic_Type | Categories | Run_MOE | Run_Bootstrap | Run_Credible
-----------|----------------|------------|---------|---------------|-------------
Q1         | proportion     | 1          | Y       | N             | N
Q2         | proportion     | 4,5        | Y       | N             | N
Q3         | mean           | 1-10       | N       | N             | N
Q4         | proportion     | 1,2,3      | Y       | N             | N
Q5         | proportion     | 5          | Y       | N             | N
Q6         | mean           | 0-10       | N       | N             | N
Q7         | proportion     | 1          | Y       | N             | N
Q8         | proportion     | 1,2        | Y       | N             | N
Q9         | mean           | 1-5        | N       | N             | N
Q10        | proportion     | 4,5        | Y       | N             | N
```

### B.2 Comprehensive Analysis (All Methods) - 20 Questions

```
Question_ID | Statistic_Type | Categories | Exclude | Run_MOE | Run_Bootstrap | Run_Credible | Use_Wilson | Prior_Mean | Prior_SD | Prior_N
-----------|----------------|------------|---------|---------|---------------|--------------|------------|------------|----------|--------
Q1         | proportion     | 1          |         | Y       | Y             | Y            | N          | 0.42       |          | 450
Q2         | proportion     | 4,5        |         | Y       | Y             | Y            | Y          | 0.67       |          | 500
Q3         | mean           | 1-10       | 99      | N       | Y             | Y            | N          | 7.2        | 1.8      | 300
Q4         | proportion     | 1,2        |         | Y       | Y             | N            | Y          |            |          |
Q5         | mean           | 0-10       | 98,99   | N       | Y             | N            | N          |            |          |
Q6         | proportion     | 1          |         | Y       | Y             | Y            | N          | 0.35       |          | 600
Q7         | proportion     | 5          |         | Y       | Y             | N            | Y          |            |          |
Q8         | mean           | 1-5        | 9       | N       | Y             | Y            | N          | 3.8        | 0.9      | 450
Q9         | proportion     | 3,4,5      |         | Y       | Y             | N            | N          |            |          |
Q10        | proportion     | 1,2,3      |         | Y       | Y             | Y            | N          | 0.58       |          | 750
... (continues to Q20)
```

### B.3 Maximum Configuration (200 Questions)

**Structure:**
- Mix of proportions and means
- Various combinations of methods
- Some with informed priors
- Demonstrates system capacity

---

## Appendix C: References

**Statistical Methods:**
- Agresti, A., & Coull, B. A. (1998). Approximate is better than "exact" for interval estimation of binomial proportions. *The American Statistician*, 52(2), 119-126.
- Efron, B., & Tibshirani, R. J. (1994). *An introduction to the bootstrap*. CRC press.
- Kish, L. (1965). *Survey sampling*. John Wiley and Sons, Inc., New York.
- Gelman, A., et al. (2013). *Bayesian data analysis* (3rd ed.). Chapman and Hall/CRC.
- Benjamini, Y., & Hochberg, Y. (1995). Controlling the false discovery rate: a practical and powerful approach to multiple testing. *Journal of the Royal Statistical Society: Series B*, 57(1), 289-300.
- Wilson, E. B. (1927). Probable inference, the law of succession, and statistical inference. *Journal of the American Statistical Association*, 22(158), 209-212.

**R Documentation:**
- R Core Team. *Writing R Extensions*.
- Wickham, H. *R Packages* (2nd ed.). https://r-pkgs.org/

**Market Research Standards:**
- ESOMAR (2023). *Global Market Research Guidelines*
- MRS (2023). *Code of Conduct and Guidelines*

---

## Document Control

**Version:** 1.0  
**Date:** 2025-11-12  
**Author:** Design Specification Team  
**Approved By:** [Stakeholder]  
**Next Review:** 2025-12-12

**Distribution:**
- Development Team
- QA Team
- Product Owner
- Stakeholders

**Change History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-12 | Design Team | Initial specification with 200 question support and decimal separator |

---

**END OF SPECIFICATION**
