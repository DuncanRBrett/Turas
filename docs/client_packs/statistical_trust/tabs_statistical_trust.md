# Why You Can Trust Turas: Cross-Tabulation & Significance Testing

**Module:** Tabs (Cross-Tabulation, Significance Testing, Banner Tables)
**Quality Score:** 90/100

---

## What Turas Does

Turas produces publication-ready cross-tabulation tables from survey data. It generates frequency counts, column/row percentages, means, indices, NPS scores, and Top/Bottom Box summaries -- all with statistical significance testing between columns. It handles weighted data correctly, supports all standard question types (single-choice, multi-mention, rating scales, rankings, grids, composites), and outputs formatted Excel workbooks and interactive HTML reports.

## The Statistical Engines Behind Turas

| Method | Package | Status |
|--------|---------|--------|
| Z-Test for Proportions | **Base R** (stats::pnorm) | Textbook two-proportion z-test. The standard method used by every major tabulation platform. |
| T-Test for Means | **Base R** (stats::pt) | Pooled-variance Student's t-test with degrees of freedom correction. |
| Chi-Square Test | **Base R** (stats::pchisq) | Pearson's chi-square test of independence. |
| Effective Sample Size | **Base R** | Kish (1965) formula: n_eff = (sum w)^2 / sum(w^2). Universally accepted. |
| Weighted Variance | **Base R** | Population estimator with design-effect adjustment. |

**Note:** The entire Tabs module runs on **base R only** for all statistical computations. No external statistical packages are required.

## Why These Are Defensible Choices

- The **two-proportion z-test** is the universal standard for comparing percentages across subgroups in cross-tabulation. It is the same test used by SPSS, Q Research Software, Displayr, and every other major tabulation platform.
- The **pooled-variance t-test** is the textbook method for comparing means between independent groups, appropriate for the banner-column comparisons in cross-tabulation.
- **Kish's effective sample size** (1965) is the universally-accepted adjustment for weighted survey data. It is used by every national statistical office and is the standard in market research.
- Using base R for these calculations means there are **zero external dependencies** that could introduce version conflicts or computation differences. The mathematical functions (pnorm, pt, pchisq) are wrappers around highly-optimised C/FORTRAN numerical libraries that ship with every R installation.

## Built-In Safeguards

- **Effective sample size adjustment:** All significance tests use Kish's effective N rather than raw sample size, properly accounting for the precision loss from weighting.
- **Minimum base size enforcement:** Configurable threshold (default: 30) prevents significance testing on unreliably small subgroups.
- **Bonferroni correction** available for multiple comparisons, controlling the family-wise error rate when testing many column pairs simultaneously.
- **Chi-square cell frequency warnings:** Flags results when more than 20% of expected cell frequencies fall below 5, following standard statistical practice.
- **Edge case handling:** Proportions are clamped to [0, 1], zero bases are handled gracefully, and division-by-zero guards are in place throughout.
- **Net difference testing:** Tests the gap between aggregated nets (e.g., Satisfied vs. Dissatisfied) with proper Bonferroni adjustment.

## Question Types & Metrics Supported

| Type | Metrics | Significance Test |
|------|---------|-------------------|
| Single Choice | Frequency, Column %, Row % | Z-test for proportions |
| Multi-Mention | Frequency, Column % | Z-test for proportions |
| Rating / Likert | Mean, Top/Bottom Box | T-test for means |
| NPS (0-10) | NPS Score, Promoter/Detractor % | Z-test for proportions |
| Ranking | Mean Rank, % Ranked 1st, % Top N | T-test for means |
| Numeric | Mean, Median | T-test for means |
| Composite | Weighted Index, Top/Bottom Box | T-test for means |

## Academic References

- Kish, L. (1965). *Survey Sampling*. Wiley.
- Agresti, A. (2013). *Categorical Data Analysis* (3rd ed.). Wiley.
- Fleiss, J.L., Levin, B. & Paik, M.C. (2003). *Statistical Methods for Rates and Proportions* (3rd ed.). Wiley.

## Bottom Line

Cross-tabulation with significance testing is the bread and butter of survey research, and the statistical methods involved are well-established textbook procedures. Turas implements these using base R's built-in statistical functions -- the same mathematical engines used by statisticians worldwide. The effective sample size adjustment and Bonferroni correction ensure that results from weighted data with multiple comparisons are statistically sound. These are the same tests produced by SPSS, Q, and every other reputable tabulation tool.

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
