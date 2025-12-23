# Turas Categorical Key Driver Module - Overview

**Version:** 10.0
**Last Updated:** 22 December 2025

Understand what drives categorical outcomes with statistically rigorous logistic regression analysis.

---

## Table of Contents

1. [What is Categorical Key Driver Analysis?](#what-is-categorical-key-driver-analysis)
2. [Key Capabilities](#key-capabilities)
3. [Business Applications](#business-applications)
4. [Method Comparison](#method-comparison)
5. [When to Use This Module](#when-to-use-this-module)
6. [Technical Requirements](#technical-requirements)
7. [Comparison with Standard Key Driver](#comparison-with-standard-key-driver)

---

## What is Categorical Key Driver Analysis?

Categorical Key Driver Analysis identifies which factors most strongly influence a categorical outcome. While standard key driver analysis works with continuous outcomes (e.g., satisfaction scores 1-10), this module handles discrete category outcomes.

### The Challenge

Many important business outcomes are inherently categorical:
- Did the customer churn? (Yes/No)
- How satisfied is the employee? (Low/Medium/High)
- Which brand does the customer prefer? (A/B/C/D)

Standard regression assumes a continuous outcome. Using it on categorical data produces misleading results.

### The Solution

This module automatically selects the appropriate logistic regression method:

| Outcome Type | Method | R Package |
|--------------|--------|-----------|
| Binary (2 categories) | Binary Logistic | `stats::glm()` |
| Ordinal (3+ ordered) | Proportional Odds | `MASS::polr()` |
| Nominal (3+ unordered) | Multinomial Logistic | `nnet::multinom()` |

---

## Key Capabilities

### Automatic Method Selection

The module analyzes your outcome variable and automatically selects the appropriate method:

- **Binary outcomes** (Yes/No, Pass/Fail): Binary logistic regression
- **Ordered categories** (Low/Medium/High): Ordinal logistic regression
- **Unordered categories** (Brand A/B/C): Multinomial logistic regression

### Statistical Outputs

| Output | Description |
|--------|-------------|
| **Odds Ratios** | How much more likely is the outcome for one group vs. another? |
| **Confidence Intervals** | Range of plausible effect sizes |
| **Variable Importance** | Which drivers matter most? (chi-square based) |
| **Effect Size Labels** | Plain-English interpretation (Small/Medium/Large) |
| **Model Fit Statistics** | McFadden R², AIC, likelihood ratio tests |

### Quality Assurance

| Feature | Benefit |
|---------|---------|
| **Missing Data Reports** | Know exactly how much data is missing |
| **Small Cell Detection** | Warns when categories have few observations |
| **Convergence Checks** | Alerts if model has estimation problems |
| **Multicollinearity Tests** | Identifies correlated predictors |
| **Separation Detection** | Flags perfect prediction issues |

### Plain-English Executive Summaries

Auto-generated summaries translate statistics into actionable insights:

> "Grade is the strongest predictor of employment satisfaction (42% importance). Students with Grade A are 4.2 times more likely to report High satisfaction compared to Grade D students."

---

## Business Applications

### Customer Retention

**Question:** What drives customer churn?

**Outcome:** Retained vs. Churned (Binary)

**Drivers:** Service quality, price satisfaction, tenure, support interactions

**Output Example:**
- Customers with Low service quality are 3.5x more likely to churn
- Each year of tenure reduces churn odds by 15%
- Support interactions have 23% importance

### Employee Satisfaction

**Question:** What predicts employee satisfaction levels?

**Outcome:** Low/Medium/High (Ordinal)

**Drivers:** Manager support, workload, career growth, compensation

**Output Example:**
- Manager support is the dominant driver (45% importance)
- High workload reduces odds of High satisfaction by 60%
- Career growth opportunities increase High satisfaction odds by 2.8x

### Brand Preference

**Question:** What drives brand choice?

**Outcome:** Brand A/B/C/D (Nominal)

**Drivers:** Price perception, quality perception, brand awareness, recommendation

**Output Example:**
- Quality perception drives choice of Brand A vs. Brand D (OR = 4.2)
- Price sensitivity drives choice of Brand C vs. Brand D (OR = 2.8)
- Recommendation has highest overall importance (32%)

### Alumni Career Success

**Question:** What predicts graduate career satisfaction?

**Outcome:** Satisfied/Neutral/Dissatisfied (Ordinal)

**Drivers:** Academic grade, campus, course type, internship experience

**Output Example:**
- Academic grade has highest importance (38%)
- Internship experience increases satisfaction odds by 2.1x
- Online students have lower satisfaction odds (OR = 0.65)

---

## Method Comparison

### Binary Logistic Regression

**Use When:** Outcome has exactly 2 categories

**Strengths:**
- Most interpretable odds ratios
- Well-established methodology
- Handles separation with Firth correction (if brglm2 installed)

**Outputs:**
- Single odds ratio per predictor category
- Classification accuracy
- ROC curve metrics

### Ordinal Logistic Regression (Proportional Odds)

**Use When:** Outcome has 3+ ordered categories

**Strengths:**
- Respects natural ordering
- Single coefficient per predictor (parsimonious)
- Proportional odds interpretation

**Assumption:**
- Effect is consistent across thresholds
- Module checks this automatically

**Outputs:**
- Cumulative odds ratios
- Threshold parameters
- Proportional odds check

### Multinomial Logistic Regression

**Use When:** Outcome has 3+ unordered categories

**Strengths:**
- No ordering assumption
- Separate effects for each outcome vs. reference
- Flexible modeling

**Complexity:**
- More parameters to estimate
- Requires larger sample size
- Multiple comparisons

**Outputs:**
- Odds ratios for each outcome vs. reference
- Or aggregated importance across outcomes

---

## When to Use This Module

### Use This Module When:

- Your outcome is naturally categorical (not a binned continuous variable)
- You want to know which factors predict category membership
- You need odds ratios for communication
- Your outcome has 2-10 distinct categories

### Don't Use This Module When:

- Your outcome is a continuous score → Use standard Key Driver
- You have time-series data → Use Tracker module
- Your outcome has 10+ categories → Consider grouping or different approach
- You need to predict numeric values → Use standard Key Driver

### Sample Size Guidelines

| Model Type | Minimum N | Recommended N | Events per Predictor |
|------------|-----------|---------------|---------------------|
| Binary | 50 | 100+ | 10-15 per outcome |
| Ordinal | 75 | 150+ | 10 per threshold |
| Nominal | 100 | 200+ | 10 per category |

---

## Technical Requirements

### R Version

- **Minimum:** R 4.0+
- **Recommended:** R 4.2+

### Required Packages

```r
install.packages(c("MASS", "nnet", "car", "openxlsx"))
```

### Recommended Packages

```r
# Better ordinal regression
install.packages("ordinal")

# Handles separation in binary models
install.packages("brglm2")

# SPSS/Stata file support
install.packages("haven")
```

---

## Comparison with Standard Key Driver

| Feature | Standard Key Driver | Categorical Key Driver |
|---------|--------------------|-----------------------|
| **Outcome Type** | Continuous (1-10 scale) | Categorical (Yes/No, Low/Med/High) |
| **Method** | Multiple regression | Logistic regression |
| **Coefficients** | Beta weights | Log-odds / Odds ratios |
| **Importance** | Shapley, Relative Weights | Chi-square decomposition |
| **Effect Size** | Standardized betas | Odds ratio ranges |
| **Fit Statistic** | R-squared | McFadden R² |
| **Assumptions** | Linearity, normality | Independence, category sizes |

### When to Choose Each

| Scenario | Module |
|----------|--------|
| Satisfaction score 1-10 | Standard Key Driver |
| NPS (0-10 scale) | Standard Key Driver |
| Satisfaction category (Low/Med/High) | **Categorical Key Driver** |
| Churn (Yes/No) | **Categorical Key Driver** |
| Brand choice (A/B/C) | **Categorical Key Driver** |
| Likelihood to recommend (1-5) treated as ordered | **Categorical Key Driver** |

---

## Package Dependencies

### Why These Packages?

| Package | Purpose | Justification |
|---------|---------|---------------|
| **MASS** | Ordinal regression | R Core Team, industry standard |
| **nnet** | Multinomial regression | R Core Team, stable since R 1.0 |
| **car** | Chi-square tests | Gold standard for regression diagnostics |
| **openxlsx** | Excel I/O | No Java dependency, excellent formatting |
| **ordinal** | Better ordinal engine | More robust convergence (optional) |
| **brglm2** | Separation handling | Firth correction (optional) |

### Packages NOT Used

| Package | Reason |
|---------|--------|
| tidyverse/dplyr | Base R sufficient, reduces dependencies |
| ggplot2 | No visualization in output |
| xlsx | Requires Java |
| VGAM | Adds complexity without benefit |

---

## Documentation Resources

| Document | Content |
|----------|---------|
| [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) | Statistical methods in depth |
| [04_USER_MANUAL.md](04_USER_MANUAL.md) | Complete operational guide |
| [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) | Developer documentation |
| [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) | Configuration field reference |
| [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) | Step-by-step examples |

---

**Part of the Turas Analytics Platform**
