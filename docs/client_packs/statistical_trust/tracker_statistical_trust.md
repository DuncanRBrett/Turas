# Why You Can Trust Turas: Tracking & Trend Analysis

**Module:** Tracker (Longitudinal Tracking Studies)
**Quality Score:** 87/100

---

## What Turas Does

Turas tracks survey metrics across multiple waves (time periods), identifying statistically significant changes in KPIs over time. It supports rating scales, NPS, single-choice, multi-mention, and composite index questions -- calculating wave-over-wave changes with significance testing that properly accounts for survey weights.

## The Statistical Engines Behind Turas

| Method | Package | Status |
|--------|---------|--------|
| T-Test for Means | **Base R** (stats::pt) | Pooled-variance Student's t-test. Textbook standard for comparing means across waves. |
| Z-Test for Proportions | **Base R** (stats::pnorm) | Two-proportion z-test. The universal standard for comparing percentages across time points. |
| NPS Significance Test | **Base R** (stats::pnorm) | Z-test with conservative variance estimate for Net Promoter Score differences. |
| Effective Sample Size | **Base R** | Kish (1965) formula. Universally accepted for weighted survey data. |
| Weighted Mean & Variance | **Base R** | Design-effect-adjusted weighted statistics. |
| Confidence Intervals | **Base R** (stats::qnorm) | 95% CI using effective sample size and weighted standard error. |

**Note:** The entire Tracker module runs on **base R only** for all statistical computations. The optional future/future.apply packages provide parallel processing for large studies but do not affect statistical results.

## Why These Are Defensible Choices

- The **two-sample t-test** and **two-proportion z-test** are the universally-accepted methods for wave-over-wave significance testing in tracking studies. They are the same tests used by every major tracking platform (Kantar, Ipsos, Nielsen).
- All tests use **effective sample sizes** (Kish, 1965) rather than raw counts, properly accounting for the precision loss from weighting. This is critical -- failing to adjust for design effects inflates significance, leading to false positives.
- The **conservative NPS variance estimate** (SE = sqrt(100^2/n1 + 100^2/n2)) accounts for worst-case variance in the NPS metric, ensuring that flagged changes are genuinely significant rather than artifacts of the score's bounded nature.
- By implementing all statistics in base R, the module has **zero external statistical dependencies**, ensuring reproducibility and eliminating version-related computation differences.

## Built-In Safeguards

- **Design effect adjustment:** Every significance test uses Kish's effective N, not the raw sample size. This prevents false positives from heavily-weighted samples.
- **Minimum base enforcement:** Configurable threshold prevents significance testing when effective sample sizes are too small for reliable inference.
- **Consecutive wave testing:** Tests are performed between adjacent waves (Wave 1 vs. 2, Wave 2 vs. 3), which is the methodologically correct approach for tracking studies.
- **Two-tailed tests:** All tests are two-tailed at the default alpha = 0.05, the standard for market research tracking.
- **Data cleaning:** Handles European decimal formats (comma separators), DK/NS/NA values, and type coercion automatically.
- **Parallel processing:** For large studies (10+ tracked questions), optional parallel computation via the future package reduces processing time without affecting results.
- **Centralised statistical core:** All calculations flow through a single `statistical_core.R` file -- one source of truth that prevents inconsistencies between question types.

## Metrics Tracked Per Question Type

| Question Type | Metrics | Change Detection | Significance Test |
|---------------|---------|-----------------|-------------------|
| Rating / Likert | Weighted mean, SD, CI, Top Box | Absolute & % change | T-test |
| NPS (0-10) | NPS score, Promoter/Passive/Detractor % | Absolute change | Z-test (conservative) |
| Single Choice | Weighted % per option | Absolute & % change | Z-test per option |
| Multi-Mention | Weighted % per mention, Any Mention % | Absolute & % change | Z-test per mention |
| Composite Index | Weighted mean, Top/Bottom Box | Absolute & % change | T-test |

## Academic References

- Kish, L. (1965). *Survey Sampling*. Wiley.
- Bain, L.J. & Engelhardt, M. (1992). *Introduction to Probability and Mathematical Statistics*. Duxbury.
- Reichheld, F.F. (2003). The one number you need to grow. *Harvard Business Review*.

## Bottom Line

Tracking studies require straightforward, well-understood statistical methods applied consistently across waves. Turas uses the same textbook significance tests employed by every major research agency worldwide, with the critical addition of design-effect adjustment via Kish's effective sample size. The centralised statistical architecture ensures that every question type is tested identically, eliminating the inconsistencies that can arise when different analysts apply ad-hoc methods. These are proven, transparent methods that any statistician can verify.

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
