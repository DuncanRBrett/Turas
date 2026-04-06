# Categorical Key Driver Analysis: Technique Guide

**Module:** Turas CatDriver **Audience:** Researchers, analysts, and clients commissioning categorical driver analysis **Last updated:** April 2026

------------------------------------------------------------------------

## What categorical driver analysis does

Categorical driver analysis answers: "Which factors best predict membership in an outcome category?" Where standard key driver analysis (KeyDriver) handles continuous outcomes like satisfaction scores, CatDriver handles outcomes that are categories — yes/no, low/medium/high, Brand A/B/C/D.

The output is a ranking of driver importance (which factors matter most), plus odds ratios and probability lifts that show *how* each factor's categories relate to the outcome.

------------------------------------------------------------------------

## When to use it

CatDriver is appropriate when:

-   The **outcome is categorical**: binary (yes/no, churn/retain), ordinal (low/medium/high), or nominal (brand A/B/C)
-   The **predictors are categorical** (demographic segments, satisfaction tiers, usage categories)
-   You want to know which factors best **discriminate** between outcome groups
-   You need **odds ratios** or **probability lifts** for stakeholder communication
-   Sample size is at least 30, with at least 10 events per predictor (see watchouts)

CatDriver is **not** appropriate when:

-   The outcome is continuous (use KeyDriver instead)
-   Predictors are continuous scales (use KeyDriver; CatDriver treats everything as categorical)
-   You need time-series or longitudinal analysis (use Tracker)
-   You have fewer than 2 predictor variables

### CatDriver vs KeyDriver: decision framework

| Question | Use KeyDriver | Use CatDriver |
|----|----|----|
| "What drives overall satisfaction (1-10)?" | Yes | No |
| "What predicts whether someone churns?" | No | Yes (binary) |
| "What drives satisfaction tier (Low/Med/High)?" | No | Yes (ordinal) |
| "What predicts brand choice (A/B/C/D)?" | No | Yes (nominal) |
| "Which attributes have the biggest impact on NPS (0-10)?" | Yes | No |
| "What predicts whether someone would recommend (Yes/No)?" | No | Yes (binary) |

------------------------------------------------------------------------

## Questionnaire design for categorical outcomes

### The outcome variable

The outcome must be a categorical variable with well-defined, mutually exclusive categories.

**Binary outcomes** (most common): The simplest and most powerful case. Examples:

-   Churned vs Retained
-   Purchased vs Did not purchase
-   Promoter vs Non-promoter (collapsing NPS into two groups)
-   Satisfied vs Dissatisfied (collapsing a satisfaction scale)

When collapsing a scale into binary, choose a meaningful cut point and document it. "Top-2 box on a 5-point scale" is standard. Avoid arbitrary splits that create near-50/50 groups just for balance — the split should reflect a real business distinction.

**Ordinal outcomes** (ordered categories): The categories have a natural order. Examples:

-   Low / Medium / High satisfaction
-   Disengaged / Neutral / Engaged
-   Never / Sometimes / Often / Always

Ordinal analysis uses proportional odds logistic regression, which assumes each predictor has the same effect across all threshold transitions. This is usually a reasonable assumption in market research but can be violated when the drivers of moving from "low to medium" differ from those driving "medium to high."

**Multinomial outcomes** (unordered categories): No natural ordering. Examples:

-   Brand preference (A/B/C/D)
-   Channel preference (Online/In-store/Phone)
-   Segment membership (if pre-defined)

Multinomial analysis is the most complex and requires larger samples. Each comparison (A vs B, A vs C, etc.) estimates a separate set of coefficients.

### The driver variables

All predictors in CatDriver are treated as categorical. Design guidance:

**Number of drivers.** 5-12 is ideal. Each driver adds parameters to the model (one coefficient per category minus one reference level). A driver with 5 categories adds 4 parameters. With 10 drivers averaging 4 categories each, the model estimates 40+ coefficients — this demands large samples.

**Number of categories per driver.** Fewer is better for stability. 2-5 categories per driver is the sweet spot. If a driver has 10+ categories, consider collapsing rare categories before analysis (CatDriver can do this automatically via the `rare_level_policy` config setting).

**Reference categories.** Each driver has a reference category that all other categories are compared against. By default, this is the first factor level. Choose reference categories that make business sense — typically the most common category or the "baseline" condition (e.g., "No contact" as reference for a contact method driver).

**Category ordering.** For ordinal drivers (e.g., age bands), specify the order in the config. This doesn't affect the model (which treats each level independently) but affects the output presentation.

### Events per predictor rule

The single most important sample size consideration for logistic regression is the **events per predictor (EPP)** ratio. "Events" means the count of the less common outcome category (for binary) or the smallest outcome group (for ordinal/multinomial).

| EPP | Guidance |
|----|----|
| \< 5 | Don't run. Results will be unreliable. Reduce drivers or combine categories. |
| 5-10 | Proceed with caution. Consider Firth correction (CatDriver enables this automatically). |
| 10-20 | Acceptable for most purposes. |
| \> 20 | Comfortable. |

Example: 200 respondents, 30 churned (15%), 10 drivers with 3 categories each = 20 parameters. EPP = 30/20 = 1.5. **Don't run.** Reduce to 5 drivers (10 parameters, EPP = 3) or combine driver categories.

------------------------------------------------------------------------

## How the statistical methods work

### Binary logistic regression

The workhorse method. Models the log-odds of the outcome as a linear function of predictor dummy variables:

log(p / (1-p)) = b0 + b1*X1 + b2*X2 + ...

Where p is the probability of the outcome (e.g., churn), and each X is a dummy variable for a driver category (1 if that category, 0 otherwise).

**Separation and Firth correction.** When a predictor category perfectly predicts the outcome (e.g., every respondent in category X churned), standard logistic regression produces infinite coefficients. CatDriver detects this automatically and falls back to Firth bias-reduced logistic regression (via the `brglm2` package), which produces finite, usable estimates. The stats pack flags when this fallback was used.

### Ordinal logistic regression (proportional odds)

Extends binary logistic to ordered outcomes by modelling cumulative probabilities. Instead of one equation, it produces K-1 equations (one per threshold) but assumes the driver effects are the same across all thresholds (the proportional odds assumption).

CatDriver uses `ordinal::clm()` as the primary engine, with `MASS::polr()` as fallback.

### Multinomial logistic regression

For unordered outcomes with 3+ categories. Fits K-1 binary comparisons simultaneously (each category vs the reference category). Requires larger samples because each comparison has its own set of coefficients.

CatDriver uses `nnet::multinom()`. Two modes are available:

-   **One-vs-rest:** Each category compared against all others combined
-   **One-vs-one:** Pairwise comparisons between specific categories

### Variable importance

CatDriver ranks drivers using Type II Wald chi-square tests from `car::Anova()`. The chi-square statistic measures each driver's overall contribution to the model, aggregating across all its category levels. Drivers are ranked by chi-square, and importance percentages show each driver's share of the total chi-square.

This is the categorical equivalent of the R-squared decomposition used in KeyDriver.

------------------------------------------------------------------------

## Interpreting the output

### Odds ratios

The primary output for stakeholder communication. An odds ratio (OR) compares the odds of the outcome for one category against the reference category.

| Odds Ratio | Meaning                                   |
|------------|-------------------------------------------|
| OR = 1.0   | No difference from reference              |
| OR = 2.0   | 2x the odds of the outcome vs reference   |
| OR = 0.5   | Half the odds of the outcome vs reference |
| OR = 5.0   | 5x the odds — strong effect               |

**Odds ratios are not probabilities.** OR = 2.0 does NOT mean "twice as likely." It means twice the odds. When the outcome is rare (\< 20% prevalence), odds ratios approximate risk ratios. When the outcome is common, odds ratios exaggerate the effect size.

### Probability lifts

Because odds ratios are hard to explain to non-statistical audiences, CatDriver also produces **probability lifts**: the percentage-point difference in predicted probability between each category and the reference.

Example: If the reference category has a 20% predicted churn probability and category X has 35%, the probability lift is +15 percentage points. This is directly interpretable: "Customers in category X are 15 percentage points more likely to churn than the reference group."

Probability lifts are model-adjusted (they account for all other drivers) and are the recommended metric for client-facing reports.

### Importance rankings

| Importance % | Interpretation                                         |
|--------------|--------------------------------------------------------|
| \> 30%       | Dominant driver — drives most of the outcome variation |
| 15-30%       | Major driver — should be a focus area                  |
| 5-15%        | Moderate driver — worth monitoring                     |
| \< 5%        | Minor driver — limited explanatory power               |

### Model fit (McFadden pseudo R-squared)

Unlike linear regression R-squared, McFadden R-squared values are typically much lower:

| McFadden R-squared | Interpretation |
|----|----|
| \> 0.40 | Excellent fit |
| 0.20-0.40 | Good fit |
| 0.10-0.20 | Moderate fit — drivers explain some but not all variation |
| \< 0.10 | Limited — the model has weak explanatory power |

A McFadden R-squared of 0.20 corresponds roughly to a linear R-squared of 0.50-0.60, so the numbers are not directly comparable with KeyDriver output.

### Confidence intervals

The 95% CI for an odds ratio tells you the range of plausible values. If the CI includes 1.0, the effect is not statistically significant at the 5% level. Wide CIs indicate imprecise estimates — typically due to small cell sizes or rare categories.

Bootstrap CIs (when enabled) are more robust than model-based CIs for non-probability samples.

------------------------------------------------------------------------

## Common watchouts

### 1. Rare events

When the outcome is rare (\< 10% prevalence), logistic regression can be unstable. Symptoms: very large odds ratios, wide confidence intervals, separation warnings. The Firth correction helps but is not a cure for genuinely insufficient data. If you have fewer than 20 events, reconsider the analysis.

### 2. Separation (complete or quasi-complete)

When a predictor category perfectly predicts the outcome, the maximum likelihood estimate is infinite. CatDriver detects this and applies Firth correction automatically. The stats pack will flag "Firth fallback used" — always check why. Common causes: very rare categories, many predictor levels relative to sample size.

**Prevention:** Collapse rare categories (set `rare_level_policy = collapse` in config). CatDriver can do this automatically for categories with fewer than N respondents.

### 3. Overfitting

With many predictors and small samples, the model can memorise the data rather than learning generalisable patterns. Signs: excellent apparent model fit but unstable odds ratios, wildly different results when a few respondents are removed.

**Rule of thumb:** Keep EPP above 10. Use bootstrap CIs to assess stability.

### 4. Multicollinearity

When two drivers are highly associated (e.g., "income band" and "education level"), the model cannot cleanly separate their effects. CatDriver reports GVIF (generalised VIF) — values above 5 warrant investigation. Unlike continuous KDA, multicollinearity in categorical models can also cause estimation failure.

### 5. Category ordering mistakes

For ordinal outcomes, the order of categories matters. If "High" is coded as 1 and "Low" as 3, the model will estimate effects in the wrong direction. Always verify category ordering in the config Variables sheet.

### 6. Ignoring the reference category

All odds ratios and probability lifts are relative to the reference category. If the reference is unusual (e.g., a very small group), the comparisons may be misleading. Choose a reference that is common and represents a meaningful baseline.

------------------------------------------------------------------------

## Subgroup comparison

CatDriver can split the analysis by a grouping variable (e.g., age group, region, segment) and compare driver importance and odds ratios across groups. This answers: "Do the same drivers matter for all segments, or do different groups have different drivers?"

The output classifies each driver as:

-   **Universal:** Important across all subgroups
-   **Segment-specific:** Important in some subgroups but not others
-   **Mixed:** Moderate importance that varies by subgroup

This is powerful for targeted strategy — e.g., "price matters most for younger customers, while service quality drives satisfaction for older customers."

**Sample size warning:** Each subgroup must have sufficient EPP independently. A total sample of 300 split into 4 subgroups of 75 may not support stable within-group logistic regression.

------------------------------------------------------------------------

## Where this module could go

The current implementation covers binary, ordinal, and multinomial logistic regression with comprehensive diagnostics. Potential extensions:

-   **Multinomial outcome expansion:** Full support for unordered multi-category outcomes with relative risk ratios and IIA diagnostics
-   **Interaction detection:** Identifying pairs of drivers whose combined effect on the outcome is greater (or less) than expected from their individual effects
-   **Marginal effects:** Beyond probability lifts, compute average marginal effects (AME) for direct probability-scale interpretation at different covariate profiles
-   **Penalised logistic regression:** LASSO or elastic net regularisation for automatic variable selection with categorical predictors
-   **Mixed effects:** Multilevel logistic regression for hierarchically structured data (respondents within regions within countries)
-   **SHAP for categorical outcomes:** TreeSHAP via XGBoost classification for nonlinear categorical driver importance

------------------------------------------------------------------------

## References

-   Agresti, A. (2013). *Categorical Data Analysis*. 3rd ed. Wiley.
-   Hosmer, D. W., Lemeshow, S., & Sturdivant, R. X. (2013). *Applied Logistic Regression*. 3rd ed. Wiley.
-   Firth, D. (1993). Bias reduction of maximum likelihood estimates. *Biometrika*, 80(1), 27-38.
-   Kosmidis, I., & Firth, D. (2009). Bias reduction in exponential family nonlinear models. *Biometrika*, 96(4), 793-804.
-   McCullagh, P. (1980). Regression models for ordinal data. *Journal of the Royal Statistical Society: Series B*, 42(2), 109-142.
-   McFadden, D. (1974). Conditional logit analysis of qualitative choice behavior. In *Frontiers in Econometrics*, pp. 105-142.
-   Peduzzi, P., Concato, J., Kemper, E., Holford, T. R., & Feinstein, A. R. (1996). A simulation study of the number of events per variable in logistic regression analysis. *Journal of Clinical Epidemiology*, 49(12), 1373-1379.
