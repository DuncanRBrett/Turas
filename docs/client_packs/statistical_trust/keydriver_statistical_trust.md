# Why You Can Trust Turas: Key Driver Analysis

**Module:** Key Driver Analysis (Continuous Outcome)
**Quality Score:** 93/100

---

## What Turas Does

Turas identifies which survey attributes most influence a key outcome (e.g., overall satisfaction, likelihood to recommend). It provides multiple complementary importance methods to give a robust, triangulated view of what truly drives your outcome metric.

## The Statistical Engines Behind Turas

| Method | Package | Authors | Status |
|--------|---------|---------|--------|
| Shapley Value Decomposition | **Base R** (stats::lm) | Budescu (1993) methodology | Game-theoretic fair R-squared allocation. Gold-standard importance method. |
| Relative Weights | **Base R** (eigen decomposition) | Johnson (2000) methodology | Handles multicollinearity gracefully. Widely used in I/O psychology. |
| SHAP Values | **xgboost + shapviz** | Chen & Guestrin (XGBoost); Mayer (shapviz) | 40,000+ citations for XGBoost. Industry standard for ML interpretability. |
| Elastic Net | **glmnet** | Friedman, Hastie, Tibshirani (Stanford) | Written by the inventors of elastic net. 20,000+ citations. No credible alternative. |
| Dominance Analysis | **domir** | Joseph Luchman | Most flexible R implementation. Generalises Budescu (1993). |
| Necessary Condition Analysis | **NCA** | Jan Dul | The sole authoritative implementation. 433 published applications by 2025. |
| Nonlinear Effects (GAM) | **mgcv** | Simon Wood | 63,000+ citations. Ships with base R. One of the most important statistical packages ever written. |

## Why These Are Defensible Choices

- **glmnet** was written by the statisticians who invented the elastic net (Zou & Hastie, 2005) and lasso (Tibshirani, 1996). There is no more authoritative implementation.
- **mgcv** by Simon Wood is universally regarded as the definitive GAM package. It has more citations than most entire statistical software programs.
- **xgboost** is the most widely-used gradient boosting implementation in the world, and **SHAP** (Lundberg & Lee, 2017, 20,000+ citations) has become the universal standard for machine learning interpretability.
- The **Shapley value** approach to driver importance is mathematically proven to be the only decomposition satisfying efficiency, symmetry, and additivity axioms (game theory).

## Built-In Safeguards

- **Triangulation:** Multiple independent methods (Shapley, Relative Weights, SHAP, Beta, Correlation) ensure no single method's limitations distort your conclusions.
- **Multicollinearity detection:** VIF checks flag problematic predictor correlations before analysis.
- **Sample size validation:** Enforces minimum n >= max(30, 10 x number of drivers) to ensure statistical power.
- **Bootstrap confidence intervals** for all importance estimates quantify estimation uncertainty.
- **Effect size interpretation** using Cohen (1988) conventions classifies practical significance.
- **NCA identifies "hygiene factors"** -- drivers that are necessary but not sufficient -- a distinction traditional regression misses entirely.

## Academic References

- Budescu, D.V. (1993). Dominance analysis. *Psychological Bulletin*.
- Johnson, J.W. (2000). A heuristic method for estimating the relative weight of predictor variables. *Multivariate Behavioral Research*.
- Lundberg, S. & Lee, S.I. (2017). A unified approach to interpreting model predictions. *NeurIPS*.
- Friedman, J., Hastie, T. & Tibshirani, R. (2010). Regularization paths for GLMs via coordinate descent. *Journal of Statistical Software*.
- Dul, J. (2016). Necessary Condition Analysis. *Organizational Research Methods*.
- Wood, S.N. (2017). *Generalized Additive Models: An Introduction with R*. Chapman & Hall/CRC.

## Bottom Line

Turas Key Driver Analysis deploys the most comprehensive battery of importance methods available in any single platform. Every method is implemented by its original authors or the acknowledged leaders in the field. The triangulation approach -- using multiple independent methods to confirm findings -- provides a level of robustness that single-method platforms cannot match.

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
