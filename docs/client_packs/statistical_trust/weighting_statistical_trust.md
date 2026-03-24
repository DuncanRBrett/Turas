# Why You Can Trust Turas: Sample Weighting

**Module:** Weighting (Design, Rim/Raking, Cell Weights)
**Quality Score:** 86/100

---

## What Turas Does

Turas adjusts survey samples to match known population characteristics. It supports design weights (correcting for unequal selection probabilities), rim weights (iterative proportional fitting to match marginal distributions), cell weights (matching joint distributions), and weight trimming to control extreme values. Comprehensive diagnostics quantify the precision impact of weighting.

## The Statistical Engine Behind Turas

| Method | Package | Author | Status |
|--------|---------|--------|--------|
| Rim Weighting (Calibration/Raking) | **survey** | Thomas Lumley (University of Auckland) | **The** canonical package for complex survey analysis in R. Continuously developed for 20+ years. |
| Design Weights | **Base R** | Standard formula: N_stratum / n_stratum | Textbook methodology. |
| Cell Weights | **Base R** | Standard formula: target% x N / n_cell | Textbook methodology. |
| Effective Sample Size | **Base R** | Kish (1965) formula | Universally accepted. |

## Why This Is a Defensible Choice

- **The survey package by Thomas Lumley is beyond question.** It is the undisputed gold standard for complex survey analysis in R. Lumley (2004, *Journal of Statistical Software*) is one of the most-cited survey methodology papers ever published. A retrospective article in 2023 celebrated 20 years of continuous development.
- The survey package's `calibrate()` function implements modern generalised calibration (Deville & Sarndal, 1992), which subsumes classical raking as a special case. This is the same framework used by national statistical offices (e.g., US Census Bureau, Statistics Canada, ONS).
- The companion book *Complex Surveys: A Guide to Analysis Using R* (Wiley) by Thomas Lumley is a standard reference in survey methodology.
- **No credible alternative exists** for this task in R. The srvyr package provides a dplyr-compatible interface but uses the survey package as its engine.

## Built-In Safeguards

- **Convergence monitoring:** Rim weighting reports iteration count, tolerance achieved, and margin achievement (target vs. actual distributions).
- **Weight bounds:** Configurable bounds (default 0.3 to 3.0) prevent extreme weights during calibration.
- **Weight trimming:** Hard cap, percentile-based, and Winsorisation (two-sided) methods control extreme weights post-calibration.
- **Iterative rim-trim:** Combines trimming with recalibration to maintain margin fit after trimming.
- **Effective sample size and DEFF reporting** quantifies the precision cost of weighting, using the universally-accepted Kish (1965) formula.
- **Weight distribution diagnostics:** Min, max, mean, SD, quartiles, and coefficient of variation are reported for every weighting run.
- **Margin validation:** Target percentages are validated to sum to 100% (within tolerance) before weighting begins.

## Methodology Notes

Rim weighting (also called raking or iterative proportional fitting) is the most widely-used post-stratification method in market and social research. It adjusts sample weights iteratively to match known population marginal distributions across multiple variables simultaneously. The survey package implements the modern generalised calibration framework, which provides optimal efficiency under the calibration constraints.

## Academic References

- Lumley, T. (2004). Analysis of complex survey samples. *Journal of Statistical Software*.
- Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*. Wiley.
- Deville, J.C. & Sarndal, C.E. (1992). Calibration estimators in survey sampling. *Journal of the American Statistical Association*.
- Kish, L. (1965). *Survey Sampling*. Wiley.

## Bottom Line

Turas Weighting is powered by the survey package -- the most authoritative, longest-running, and most-cited survey analysis package in R. It implements the same calibration framework used by national statistical offices around the world. There is no more defensible choice for survey weighting in the R ecosystem.

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
