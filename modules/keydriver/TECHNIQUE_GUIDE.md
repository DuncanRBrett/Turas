# Key Driver Analysis: Technique Guide

**Module:** Turas KeyDriver
**Audience:** Researchers, analysts, and clients commissioning key driver analysis
**Last updated:** April 2026

---

## What key driver analysis does

Key driver analysis (KDA) answers: "Which aspects of the experience matter most for the outcome we care about?" It takes a set of rated attributes (the drivers) and a single outcome measure, and quantifies each driver's relative contribution to explaining variation in the outcome.

The output is a ranking. The top-ranked driver is the one that, if improved, would have the most impact on the outcome — all else being equal.

---

## When to use it

KDA is appropriate when:

- You have a **continuous outcome** (e.g., overall satisfaction on a 1-10 scale, NPS, likelihood to recommend)
- You have **multiple rated attributes** measured on the same or similar scales (e.g., "rate your satisfaction with price, quality, service, delivery")
- You want to **prioritise** which attributes to focus on
- The sample is large enough: at minimum 10 respondents per driver, with a floor of 30

KDA is **not** appropriate when:

- The outcome is categorical (use CatDriver instead)
- You have fewer than 3 drivers (the analysis is trivial)
- Drivers are not measured on interval-like scales (binary or nominal predictors need CatDriver)
- You need causal claims (KDA shows association, not causation)

---

## Questionnaire design

Good KDA starts with good questionnaire design. The quality of the output depends entirely on what goes in.

### The outcome variable

Choose one outcome that represents the "so what" of the research. Common choices:

- Overall satisfaction (1-10 scale)
- Likelihood to recommend / NPS (0-10 scale)
- Likelihood to repurchase (1-5 or 1-7 scale)
- Brand consideration score

The outcome should be measured **after** the attribute ratings in the questionnaire, to avoid priming effects. If you measure overall satisfaction first, respondents adjust their attribute ratings to be consistent with their overall score.

### The driver battery

The drivers are the attributes you suspect might influence the outcome. Design guidance:

**Number of items.** 8-15 drivers is the sweet spot. Fewer than 5 gives trivial results. More than 15 causes estimation problems (multicollinearity, Shapley computation time, respondent fatigue in the questionnaire). If you have 20+ candidate attributes, consider grouping them into themes and running separate analyses per theme.

**Scale choice.** Use the same scale across all drivers. A 7-point or 10-point satisfaction scale works well. Avoid mixing scale types (e.g., some drivers on 1-5, others on 1-10) — it introduces artifactual differences in importance due to different variances.

**Scale direction.** All scales should run in the same direction (e.g., 1 = very dissatisfied, 10 = very satisfied). Mixed directions create interpretation confusion and can mislead the analysis.

**Wording.** Each driver should measure one distinct concept. Avoid double-barrelled items ("The staff were friendly and knowledgeable" — is that one concept or two?). Ambiguous drivers produce ambiguous importance scores.

**Independence.** Drivers should be conceptually distinct. If "price" and "value for money" are both in the battery, they will share variance and the analysis cannot cleanly separate their contributions. This is multicollinearity, and it is the single biggest threat to KDA quality.

**DK/NA handling.** Decide in advance how "Don't Know" and "Not Applicable" responses will be handled. Turas uses listwise deletion (respondents missing any driver or the outcome are excluded). If many respondents select DK on specific drivers, the effective sample shrinks. Consider whether DK options are genuinely needed, or whether a midpoint anchor serves better.

### Weighting

If the survey uses sample weights (e.g., rim weighting for demographic targets), the KeyDriver module will apply them throughout. Ensure the weight variable is numeric and positive. The stats pack reports the effective sample size after weighting — always check this, as heavy weighting can substantially reduce effective N.

---

## Method selection

Turas computes multiple importance metrics simultaneously. Each has strengths; the consensus across methods is what matters.

### Core methods (always computed)

| Method | What it measures | Strengths | Limitations |
|--------|-----------------|-----------|-------------|
| **Shapley value** | Fair allocation of R-squared across all possible driver combinations | Theoretically optimal; accounts for all interactions between drivers | Computationally expensive (O(2^k)); maxes out at 15 drivers |
| **Relative weight** (Johnson) | Orthogonalised share of R-squared | Handles multicollinearity gracefully; always non-negative; sums to 100% | Less intuitive than Shapley; approximation rather than exact decomposition |
| **Beta weight** | Standardised regression coefficient share | Simple to interpret; widely understood | Unstable with multicollinearity; can produce negative importance |
| **Correlation** | Zero-order Pearson correlation with outcome | Easy to explain; no model assumptions | Ignores other drivers; inflates importance of correlated attributes |

**Recommendation:** Lead with Shapley values for prioritisation decisions. Use relative weights as a cross-check. Report correlations as context (the "raw relationship" before controlling for other drivers). Mention beta weights for audiences familiar with regression.

### Optional methods (v10.4)

| Method | When to use |
|--------|-------------|
| **Elastic Net** | Variable selection when you suspect some drivers are noise. Produces sparse models — drivers with zero coefficient are genuinely unimportant. |
| **Dominance Analysis** | Formal pairwise comparison of drivers. Answers "does driver A dominate driver B across all subsets?" Useful for resolving close rankings. |
| **NCA** (Necessary Condition Analysis) | Identifies drivers that are *necessary* for high outcome scores (as opposed to merely correlated). Valuable when the business question is "what must we get right?" rather than "what drives the most variance?" |
| **GAM** (Generalised Additive Models) | Detects nonlinear relationships (e.g., diminishing returns — satisfaction with price matters a lot at the bottom but not at the top). Produces EDF (effective degrees of freedom) indicating how nonlinear the effect is. |

### SHAP (XGBoost TreeSHAP)

SHAP values from a gradient boosted tree model capture nonlinear effects and interactions that linear methods miss. Enable this when:

- You have reason to believe relationships are nonlinear
- You want per-respondent driver importance (not just aggregate)
- The audience is comfortable with machine learning explanations

SHAP adds a dependency plot and beeswarm chart to the HTML report, which can be powerful for storytelling.

### Quadrant analysis (Importance-Performance)

The quadrant chart plots performance (mean rating) against derived importance for each driver. Drivers fall into four quadrants:

1. **Concentrate here** (high importance, low performance) — priority improvement areas
2. **Keep up the good work** (high importance, high performance) — current strengths
3. **Low priority** (low importance, low performance) — not worth investing in
4. **Possible overkill** (low importance, high performance) — potential to reallocate resources

This is the single most actionable output for clients. Always include it.

---

## Interpreting the output

### Importance scores

Importance percentages answer: "Of the total explained variance, what share does this driver account for?" They sum to 100% for methods that decompose R-squared (Shapley, relative weight, beta weight).

| Importance % | Interpretation |
|--------------|----------------|
| > 20% | Major driver — high priority for action |
| 10-20% | Moderate driver — worth attention |
| < 10% | Minor driver — limited leverage |

### What "importance" does NOT mean

- It does not mean "if we improve this driver by 1 point, the outcome will improve by X points." That is the regression coefficient, not the importance score.
- It does not mean causation. A driver may be important because it is correlated with the true cause, not because it is the cause itself.
- Importance is relative to the other drivers in the model. Adding or removing a driver can change the rankings.

### Model R-squared

The model R-squared tells you how much of the outcome's variation is explained by the drivers collectively. In market research:

- R-squared > 0.50: Strong model — drivers explain most of what is going on
- R-squared 0.30-0.50: Good model — substantial explanation
- R-squared 0.15-0.30: Moderate — drivers explain some but other factors matter
- R-squared < 0.15: Weak — the driver battery may be missing key factors

A low R-squared does not invalidate the analysis — it just means the ranking of drivers should be interpreted with more caution.

### Bootstrap confidence intervals

When enabled, bootstrap CIs show the precision of each importance score. If two drivers' confidence intervals overlap substantially, their rank order is uncertain — don't over-interpret which is "first" vs "second".

### VIF (multicollinearity)

VIF values above 5 indicate moderate multicollinearity; above 10 indicates severe. When VIF is high:

- Importance scores for the collinear drivers are unstable (they trade off against each other)
- Consider removing one of the collinear pair, or combining them into a composite
- The Shapley value is more robust to multicollinearity than beta weights

---

## Common watchouts

### 1. Multicollinearity

The most common problem. When drivers are highly correlated (e.g., "friendliness of staff" and "helpfulness of staff"), the model cannot separate their effects. Symptoms: unstable rankings, high VIF, large discrepancy between methods.

**Prevention:** Design the questionnaire with conceptually distinct drivers. **Remedy:** Combine correlated drivers into composites, or drop one.

### 2. Small samples

With fewer than 10 respondents per driver, estimates are unstable. With fewer than 30 total, don't run KDA at all. Bootstrap CIs will be wide, correctly reflecting the uncertainty.

### 3. Dominant drivers

If one driver has much higher variance than others (e.g., a price attribute with extreme responses while service attributes cluster around the midpoint), it may appear artificially important. Standardisation (which Turas applies automatically) mitigates this, but check for floor/ceiling effects in the raw data.

### 4. Missing data

Turas uses listwise deletion — any respondent missing any driver or the outcome is excluded. If a specific driver has high non-response, the effective sample may be much smaller than expected. The stats pack reports the analysis N; always compare it to the total sample.

### 5. Scale artefacts

If drivers use different scale lengths (some 1-5, some 1-10), the wider scale will have higher variance and may appear more important. Use the same scale for all drivers.

### 6. Too many drivers

More than 15 drivers causes: (a) Shapley computation hitting the 15-driver cap, (b) multicollinearity becoming near-certain, (c) respondent fatigue degrading data quality. Break large batteries into thematic sub-analyses.

---

## Where this module could go

The current implementation covers the standard toolkit for continuous-outcome key driver analysis. Potential extensions:

- **Relative importance visualisation:** Waterfall charts, tornado diagrams, and animated method-comparison views
- **Automated variable selection:** Using Elastic Net or LASSO to suggest which drivers to keep/drop before running the full analysis
- **Interaction detection:** Identifying pairs of drivers whose combined effect is greater (or less) than the sum of their individual effects
- **Longitudinal tracking:** Running KDA across waves and tracking how driver importance shifts over time
- **Derived importance vs stated importance:** Combining KDA results with direct "how important is X to you?" ratings to create a stated-vs-derived gap analysis

---

## References

- Johnson, J. W. (2000). A heuristic method for estimating the relative weight of predictor variables in multiple regression. *Multivariate Behavioral Research*, 35(1), 1-19.
- Shapley, L. S. (1953). A value for n-person games. In *Contributions to the Theory of Games* (Vol. II), pp. 307-317.
- Tonidandel, S., & LeBreton, J. M. (2011). Relative importance analysis: A useful supplement to regression analysis. *Journal of Business and Psychology*, 26(1), 1-9.
- Budescu, D. V. (1993). Dominance analysis: A new approach to the problem of relative importance of predictors. *Psychological Bulletin*, 114(3), 542-551.
- Dul, J. (2016). Necessary Condition Analysis (NCA): Logic and methodology. *Organizational Research Methods*, 19(1), 10-52.
- Lundberg, S. M., & Lee, S. I. (2017). A unified approach to interpreting model predictions. *Advances in Neural Information Processing Systems*, 30.
- Martilla, J. A., & James, J. C. (1977). Importance-performance analysis. *Journal of Marketing*, 41(1), 77-79.
