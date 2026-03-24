# Why You Can Trust Turas: Pricing Analysis

**Module:** Pricing (Van Westendorp, Gabor-Granger, Monadic Price Testing)
**Quality Score:** 90/100

---

## What Turas Does

Turas determines optimal price points and demand curves from survey-based pricing research. It supports three complementary methodologies: Van Westendorp Price Sensitivity Meter, Gabor-Granger demand analysis, and Monadic Price Testing with logistic regression. It also provides revenue/profit optimisation, price elasticity calculation, and tiered pricing structures.

## The Statistical Engines Behind Turas

| Method | Package | Authors | Status |
|--------|---------|---------|--------|
| Van Westendorp PSM | **pricesensitivitymeter** | Max Alletsee | The only CRAN-published implementation. Faithfully implements the standard methodology. |
| Logistic Regression (Monadic) | **Base R** (stats::glm) | R Core Team | The foundational GLM implementation. Universally accepted. |
| Demand Curve Smoothing | **Base R** (stats::loess, splinefun) | R Core Team | Standard nonparametric smoothing methods. |
| Isotonic Regression (PAVA) | **Custom implementation** | Pool Adjacent Violators Algorithm | Textbook algorithm for monotone function estimation. |
| Bootstrap CIs | **Base R** (sample, quantile) | Efron & Tibshirani (1994) | Standard percentile bootstrap. |

## Why These Are Defensible Choices

- **Van Westendorp PSM** (1976) is one of the most established pricing methodologies in market research. The pricesensitivitymeter package is the sole CRAN-published R implementation and includes the Newton-Miller-Smith (1993) extension that adds purchase probability calibration.
- **Gabor-Granger** (1966) is the foundational demand curve methodology. Turas implements it with four smoothing options (cumulative maximum, isotonic regression/PAVA, LOESS, and PCHIP interpolation), all of which are standard numerical methods.
- **Monadic price testing** via logistic regression is the gold-standard randomised experimental approach to pricing. The GLM framework in base R is the same engine used across all of academic statistics.
- All interpolation and smoothing methods use base R's built-in implementations, which are themselves wrappers around vetted FORTRAN and C numerical libraries.

## Built-In Safeguards

- **Bootstrap confidence intervals** (configurable, default 1,000 iterations) for all key price points and demand curves, quantifying estimation uncertainty.
- **Monotonicity enforcement:** Four alternative methods ensure demand curves are monotone decreasing, as economic theory requires.
- **Price ordering validation:** Checks that respondent price thresholds are internally consistent (too cheap < cheap < expensive < too expensive).
- **Minimum sample size enforcement** (n >= 30) with quality scoring.
- **Multiple optimisation objectives:** Revenue index, profit index, and constrained optimisation (minimum volume, margin, or revenue thresholds).
- **Arc and point elasticity** calculations classify price sensitivity as elastic, inelastic, or unit elastic.

## Methodology Notes

Van Westendorp and Gabor-Granger are descriptive pricing techniques -- they identify price thresholds and demand curves from stated preferences. They are not econometric causal models. This is standard practice in market research pricing studies and is well-understood by the research community. The Monadic method (logistic regression) provides the strongest statistical foundation, as it uses a randomised experimental design.

## Academic References

- Van Westendorp, P. (1976). NSS Price Sensitivity Meter. *ESOMAR Congress*.
- Newton, D., Miller, J. & Smith, P. (1993). A market acceptance extension to traditional price sensitivity measurement. *AMA Proceedings*.
- Gabor, A. & Granger, C.W.J. (1966). Price as an indicator of quality. *Economica*.
- Efron, B. & Tibshirani, R.J. (1994). *An Introduction to the Bootstrap*. Chapman & Hall.

## Bottom Line

Turas Pricing implements the three most established pricing methodologies in market research using proven statistical engines. The Van Westendorp and Gabor-Granger methods are industry standards used by every major research agency worldwide. The Monadic approach adds econometric rigour via logistic regression. Bootstrap confidence intervals on all outputs ensure that recommendations come with appropriate uncertainty quantification.

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
