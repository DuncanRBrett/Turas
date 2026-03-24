# Why You Can Trust Turas: Conjoint Analysis

**Module:** Conjoint (Choice-Based Conjoint, Hierarchical Bayes, Latent Class)
**Version:** 3.1.0 | **Quality Score:** 91/100

---

## What Turas Does

Turas estimates product preferences from choice-based conjoint experiments. It calculates part-worth utilities (how much each product feature contributes to preference), attribute importance, willingness to pay, and market share simulations. It supports aggregate-level, individual-level (Hierarchical Bayes), and segment-level (Latent Class) estimation.

## The Statistical Engines Behind Turas

Turas does not implement its own statistical algorithms. It delegates all estimation to peer-reviewed, widely-cited R packages maintained by leading academics:

| Method | Package | Authors | Status |
|--------|---------|---------|--------|
| Multinomial Logit (MLE) | **mlogit** | Yves Croissant | Gold-standard for discrete choice models. Based on McFadden's Nobel Prize-winning framework. |
| Hierarchical Bayes (MCMC) | **bayesm** | Peter Rossi (UCLA Anderson) | Canonical HB package. Companion to the textbook *Bayesian Statistics and Marketing* (Rossi, Allenby, McCulloch). |
| Conditional Logit (fallback) | **survival::clogit** | Terry Therneau (Mayo Clinic) | One of the most foundational R packages. Ships with base R. Tens of thousands of academic citations. |
| Latent Class | **bayesm** | Peter Rossi | Uses mixture-of-normals HB with multiple components for class-level utility estimation. |

## Why These Are Defensible Choices

- **mlogit** implements the McFadden (1974) random utility framework, the theoretical foundation for all modern choice modeling. Daniel McFadden received the Nobel Prize in Economics for this work.
- **bayesm** is the reference implementation for Hierarchical Bayes choice models in R. Its MCMC sampler (rhierMnlRwMixture) is the same class of algorithm used by Sawtooth Software, the industry leader in conjoint.
- **survival::clogit** is among the top 5 most-cited R packages in statistics. No credible alternative exists.

## Built-In Safeguards

- **Automatic method selection:** If mlogit fails to converge, Turas automatically falls back to the more robust survival::clogit engine.
- **MCMC convergence diagnostics:** HB estimation includes burn-in removal, posterior draw analysis, and optional Rhat/ESS checks via the coda package.
- **BIC model selection:** Latent Class analysis tests multiple class solutions and selects the optimal number using Bayesian Information Criterion.
- **Delta method confidence intervals** for willingness-to-pay estimates, following standard econometric practice.

## Academic References

- McFadden, D. (1974). Conditional logit analysis of qualitative choice behavior. *Frontiers in Econometrics*.
- Train, K. (2009). *Discrete Choice Methods with Simulation*. Cambridge University Press.
- Rossi, P., Allenby, G., & McCulloch, R. (2005). *Bayesian Statistics and Marketing*. Wiley.

## Bottom Line

Every statistical computation in Turas Conjoint is performed by packages written by the leading academics in their field. The same underlying algorithms power Sawtooth Software, the most widely-used commercial conjoint platform. Your results are reproducible, peer-reviewed, and defensible.

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
