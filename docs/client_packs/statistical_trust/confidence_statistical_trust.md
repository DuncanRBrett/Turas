# Why You Can Trust Turas: Confidence Intervals

**Module:** Confidence Intervals (Proportions, Means, NPS)
**Quality Score:** 91/100

---

## What Turas Does

Turas calculates confidence intervals for survey proportions, means, and Net Promoter Scores. It properly accounts for survey weights, computes effective sample sizes, and provides four complementary CI methods so analysts can select the approach most appropriate for their data characteristics.

## The Statistical Engines Behind Turas

| Method | Package | Source | Status |
|--------|---------|--------|--------|
| Wilson Score Interval | **Base R** (qnorm) | Wilson (1927) | Recommended by Agresti & Coull (1998) over the normal approximation. |
| Normal Approximation (MOE) | **Base R** (qnorm) | Standard z-interval | Textbook method, included for familiarity. |
| Bootstrap Percentile CI | **Base R** (sample, quantile) | Efron & Tibshirani (1994) | Distribution-free. Handles weighted data naturally. |
| Bayesian Credible Interval | **Base R** (qbeta, qnorm) | Beta-Binomial / Normal-Normal conjugate | Gelman et al. (2013), *Bayesian Data Analysis*. |
| t-Distribution CI for Means | **Base R** (qt) | Student (1908) | Textbook method with degrees of freedom correction. |
| Effective Sample Size (Kish) | **Base R** | Kish (1965) | The universally-accepted formula for weighted survey data. |

**Note:** The entire confidence module runs on **base R only**. No external statistical packages are required. Optional packages (future/future.apply) provide parallel processing for large bootstrap jobs but do not affect results.

## Why These Are Defensible Choices

- **Wilson Score Interval** is explicitly recommended over the normal approximation by Agresti & Coull (1998) in one of the most influential papers on confidence interval methodology. It performs better for small samples and proportions near 0 or 1.
- **Kish's effective sample size** (1965) is the universally-accepted method for adjusting sample sizes when survey weights are applied. It is used by every national statistical office and major research agency.
- The **bootstrap** method makes no distributional assumptions and naturally handles weighted data, making it the most robust option for complex survey designs.
- The **Bayesian credible interval** uses conjugate priors (Beta-Binomial for proportions, Normal-Normal for means), following the standard treatment in Gelman et al. (2013), the most widely-used Bayesian statistics textbook.

## Built-In Safeguards

- **Four methods available simultaneously:** Analysts can compare Wilson, Normal, Bootstrap, and Bayesian intervals side-by-side, selecting the method most appropriate for their sample size and data characteristics.
- **Design Effect (DEFF) reporting** quantifies the precision loss from weighting, so analysts understand the true statistical power of their weighted data.
- **Weighted variance calculation** uses Bessel's correction for reliability weights, following the standard formula.
- **Parallel processing** for large bootstrap jobs (B >= 5,000) via future/future.apply ensures computational feasibility without compromising statistical rigour.
- **Graceful degradation:** If optional packages are unavailable, all computations fall back to base R with identical results.

## Academic References

- Wilson, E.B. (1927). Probable inference, the law of succession, and statistical inference. *Journal of the American Statistical Association*.
- Agresti, A. & Coull, B. (1998). Approximate is better than 'exact' for interval estimation of binomial proportions. *The American Statistician*.
- Kish, L. (1965). *Survey Sampling*. Wiley.
- Efron, B. & Tibshirani, R.J. (1994). *An Introduction to the Bootstrap*. Chapman & Hall.
- Gelman, A. et al. (2013). *Bayesian Data Analysis* (3rd ed.). Chapman & Hall/CRC.

## Bottom Line

Turas Confidence Intervals uses textbook-standard statistical methods implemented entirely in base R -- the same mathematical foundations used by national statistical offices worldwide. The Wilson score interval is the method recommended by the statistics community for survey proportions. By providing four complementary methods, Turas allows analysts to verify that their conclusions are robust across different statistical paradigms (frequentist, bootstrap, and Bayesian).

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
