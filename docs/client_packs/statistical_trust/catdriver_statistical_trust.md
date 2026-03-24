# Why You Can Trust Turas: Categorical Driver Analysis

**Module:** Categorical Driver Analysis (Binary, Ordinal, Multinomial Outcomes)
**Quality Score:** 92/100

---

## What Turas Does

Turas identifies which attributes most influence a categorical outcome -- whether binary (yes/no), ordinal (low/medium/high), or multinomial (Brand A/B/C/D). It automatically detects the outcome type and selects the appropriate regression model, providing odds ratios, confidence intervals, and importance rankings.

## The Statistical Engines Behind Turas

| Method | Package | Authors | Status |
|--------|---------|---------|--------|
| Binary Logistic Regression | **Base R** (stats::glm) | R Core Team | The foundational GLM implementation. Ships with every R installation. |
| Firth Bias-Corrected Logistic | **brglm2** | Ioannis Kosmidis (Warwick) | Standard solution for separation in logistic regression. Based on Firth (1993). |
| Ordinal Regression (CLM) | **ordinal** | Rune Haubo Christensen | The specialist package for cumulative link models. More capable than MASS::polr. |
| Ordinal Regression (fallback) | **MASS::polr** | Venables & Ripley | Ships with R. One of the most cited statistics textbooks (*Modern Applied Statistics with S*). |
| Multinomial Logistic | **nnet::multinom** | Venables & Ripley | Ships with R. The standard simple interface for multinomial logit. |
| Type II Wald Tests | **car::Anova** | John Fox (McMaster) | The definitive R package for regression diagnostics. Fox's textbook is a standard reference. |

## Why These Are Defensible Choices

- **ordinal::clm** is the specialist tool for ordinal regression, supporting proportional odds, scale effects, and structured thresholds. It is strictly more capable than the commonly-used MASS::polr.
- **brglm2** implements Firth's (1993) penalised likelihood method, the accepted solution when logistic regression encounters perfect or quasi-complete separation -- a common issue with survey data.
- **car::Anova** by John Fox provides Type II Wald chi-square tests, the standard method for assessing predictor importance in categorical regression while properly handling multi-level factors.
- **nnet::multinom** is the textbook-standard implementation recommended by UCLA's Statistical Consulting Group and used across thousands of published studies.

## Built-In Safeguards

- **Automatic model selection:** Turas detects whether the outcome is binary (2 levels), ordinal (3+ ordered levels), or multinomial (3+ unordered levels) and selects the appropriate model.
- **Separation detection:** When binary logistic regression encounters perfect prediction (coefficient > 10, SE > 5), Turas automatically switches to Firth bias-corrected estimation.
- **Proportional odds validation:** For ordinal models, Turas checks whether the proportional odds assumption holds by comparing odds ratios across thresholds.
- **Automatic fallback chain:** ordinal::clm -> MASS::polr -> base R glm, ensuring estimation succeeds even if optional packages are unavailable.
- **Multiple comparison modes** for multinomial outcomes: baseline category, all pairwise, and one-vs-all.

## Academic References

- Agresti, A. (2013). *Categorical Data Analysis* (3rd ed.). Wiley.
- Firth, D. (1993). Bias reduction of maximum likelihood estimates. *Biometrika*.
- Fox, J. & Weisberg, S. (2019). *An R Companion to Applied Regression* (3rd ed.). Sage.
- Christensen, R.H.B. (2019). Cumulative link models for ordinal regression with the R package ordinal. *Journal of Statistical Software* (submitted).

## Bottom Line

Turas Categorical Driver Analysis uses the same regression engines found in academic research and clinical trials worldwide. The automatic model selection and fallback system ensures robust estimation regardless of data characteristics, while the Firth correction handles the edge cases (separation) that trip up naive implementations. Every computation is performed by packages authored by leading statisticians.

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
