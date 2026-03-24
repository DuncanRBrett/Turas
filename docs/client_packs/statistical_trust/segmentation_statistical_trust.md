# Why You Can Trust Turas: Segmentation

**Module:** Segmentation (Clustering & Latent Class Analysis)
**Quality Score:** 86/100

---

## What Turas Does

Turas discovers natural groupings (segments) within survey respondents based on their attitudes, behaviours, or preferences. It supports multiple clustering algorithms, automatic segment quality validation, profiling, classification rules, and ensemble consensus methods.

## The Statistical Engines Behind Turas

| Method | Package | Authors | Status |
|--------|---------|---------|--------|
| K-Means Clustering | **Base R** (stats::kmeans) | R Core Team | Hartigan-Wong algorithm. The universal standard. |
| Hierarchical Clustering | **fastcluster** | Daniel Mullner | Optimised C++ implementation, 10x faster than base R. Identical results. |
| Gaussian Mixture Models | **mclust** | Scrucca, Fraley, Murphy, Raftery | **The** definitive GMM package. 1,291+ citations. Full Chapman & Hall textbook (2023). |
| Latent Class Analysis | **poLCA** | Linzer & Lewis | The most widely-used LCA package in R. Published in *Journal of Statistical Software* (2011). |
| Silhouette Analysis | **cluster** | Kaufman & Rousseeuw | Authors of *Finding Groups in Data* (1990), the foundational clustering textbook. |
| Discriminant Analysis | **MASS::lda** | Venables & Ripley | Ships with R. Textbook standard. |
| Classification Rules | **rpart** | Therneau & Atkinson | The standard recursive partitioning implementation. |

## Why These Are Defensible Choices

- **mclust** is authored by Adrian Raftery (University of Washington), one of the most influential statisticians in model-based clustering. Fraley & Raftery (2002, JASA) is among the most-cited clustering papers in statistics. mclust automatically selects the best covariance structure from 14 parameterisations using BIC.
- **poLCA** is the standard for latent class analysis with categorical indicators. It follows the standard EM algorithm with multiple random starts to avoid local optima.
- **cluster** by Kaufman & Rousseeuw provides the silhouette metric, the most widely-used internal cluster validation measure, from the authors who invented it.

## Built-In Safeguards

- **Multi-method validation:** Silhouette, Calinski-Harabasz, Davies-Bouldin, and Gap Statistic indices are all computed to triangulate the optimal number of segments.
- **Exploration mode:** Turas tests all k values from k_min to k_max, presenting a full diagnostic comparison rather than forcing a single solution.
- **Bootstrap stability analysis** assesses whether segments are reproducible across resamples.
- **Ensemble/consensus clustering** (Fred & Jain, 2005) combines multiple partition runs via co-association matrices for more robust final solutions.
- **Entropy R-squared** for LCA measures classification quality on a 0-1 scale.
- **Outlier detection** via Mahalanobis distance (MASS) identifies respondents that may distort cluster centres.
- **Profiling uses effect sizes (eta-squared)**, not just p-values, because post-hoc significance tests on clustering variables are inherently descriptive, not inferential. Turas explicitly documents this distinction.

## Academic References

- Fraley, C. & Raftery, A.E. (2002). Model-based clustering, discriminant analysis, and density estimation. *Journal of the American Statistical Association*.
- Kaufman, L. & Rousseeuw, P.J. (1990). *Finding Groups in Data*. Wiley.
- Linzer, D.A. & Lewis, J.B. (2011). poLCA: An R package for polytomous variable latent class analysis. *Journal of Statistical Software*.
- Fred, A.L.N. & Jain, A.K. (2005). Combining multiple clusterings using evidence accumulation. *IEEE TPAMI*.

## Bottom Line

Turas Segmentation provides the most comprehensive clustering toolkit available in a single market research platform. The package choices -- mclust for GMM, poLCA for LCA, cluster for validation -- represent the acknowledged gold standards in their respective domains. The multi-method validation approach ensures that segment solutions are statistically robust, not artifacts of a single algorithm's assumptions.

---
*The Research LampPost (Pty) Ltd | Turas Analytics Platform*
