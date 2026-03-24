# Why You Can Trust Turas: MaxDiff Analysis

**Module:** MaxDiff (Best-Worst Scaling)
**Quality Score:** 91/100

---

## What Turas Does

Turas estimates item preference rankings from MaxDiff (Best-Worst Scaling) experiments. Respondents repeatedly choose the "best" and "worst" items from subsets, producing robust preference scales. Turas supports aggregate logit estimation, individual-level Hierarchical Bayes, TURF analysis, and interactive market simulation.

## The Statistical Engines Behind Turas

| Method | Package | Authors | Status |
|--------|---------|---------|--------|
| Conditional Logit (aggregate) | **survival::clogit** | Terry Therneau (Mayo Clinic) | Ships with base R. Among the most-cited R packages in existence. |
| Hierarchical Bayes (individual) | **cmdstanr / Stan** | Stan Development Team (Columbia, Helsinki, et al.) | The de facto gold standard for Bayesian computation. 100,000+ collective citations. |
| HB Approximate (fallback) | **Base R** | James-Stein shrinkage estimator | Well-established statistical technique when Stan is unavailable. |
| Experimental Design | **AlgDesign** | Bob Wheeler | Standard package for D-optimal experimental design. |

## Why These Are Defensible Choices

- **survival::clogit** is the unquestioned reference implementation for conditional logistic regression. It is maintained by Terry Therneau at Mayo Clinic and has been continuously developed for 25+ years.
- **Stan** (via cmdstanr) uses Hamiltonian Monte Carlo with the No-U-Turn Sampler (NUTS), which is dramatically more efficient than older Gibbs sampling approaches. Stan is used at major technology companies, pharmaceutical firms, and throughout academia. The foundational paper (Carpenter et al., 2017) has thousands of citations.
- The MaxDiff model specification follows the **Louviere & Woodworth** framework, the original and universally-accepted methodology for Best-Worst Scaling.

## Built-In Safeguards

- **Full MCMC convergence diagnostics:** Rhat, effective sample size (ESS), divergence detection, and tree depth monitoring ensure reliable posterior estimates.
- **Non-centered parameterization** in the Stan model improves sampling efficiency for hierarchical models, following Stan best practices.
- **Multiple scoring methods:** Count-based scores (BW, Net Score), logit utilities, and HB individual utilities provide cross-validation of results.
- **Bootstrap confidence intervals** for count-based scores quantify estimation uncertainty.
- **Design quality metrics:** D-efficiency and pair frequency balance are computed and reported.

## Academic References

- Louviere, J.J. & Woodworth, G.G. (1991). Best-worst scaling: A model for the largest difference judgments. University of Alberta Working Paper.
- Carpenter, B. et al. (2017). Stan: A probabilistic programming language. *Journal of Statistical Software*.
- Therneau, T. & Grambsch, P. (2000). *Modeling Survival Data*. Springer.

## Bottom Line

Turas MaxDiff uses the same foundational algorithms as commercial platforms (Sawtooth Software, Lighthouse Studio) but built on open-source, peer-reviewed engines. Stan is the most advanced Bayesian computation platform available, and survival::clogit is beyond reproach. Your preference scales are statistically rigorous and fully reproducible.

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
