# Turas Statistical Validation & Package Reference

**Document Purpose:** To provide transparency about the statistical foundations of Turas and assure clients that analyses are powered by industry-standard, peer-reviewed methodologies.

**Prepared by:** The Research LampPost (Pty) Ltd **Version:** 2.0 **Date:** December 2025 **Turas Platform Version:** v10.x-11.x (Post Phase 2-4 Refactoring)

------------------------------------------------------------------------

## Executive Summary

Turas is built on the R statistical computing platform, the gold standard for statistical analysis in academia and industry. Every analytical module in Turas leverages **peer-reviewed, open-source packages** maintained by the global statistical community, ensuring:

-   **Reproducibility** – Results can be independently verified
-   **Transparency** – All algorithms are open for inspection
-   **Accuracy** – Methods have been validated across thousands of academic publications
-   **Continuous Improvement** – Packages are actively maintained and updated
-   **Reliability** – TRS v1.0 framework ensures no silent failures

This document details the statistical packages used in each Turas module and explains why you can trust the results.

------------------------------------------------------------------------

## What's New in Turas v10-11

### TRS v1.0: Turas Reliability Standard

The 2025 refactoring introduced a comprehensive reliability framework across all modules:

| Component               | Purpose                                           |
|-------------------------|---------------------------------------------------|
| **Guard Layer**         | Pre-flight validation before any analysis runs    |
| **Structured Refusals** | Clear error messages with actionable fix guidance |
| **Run State Tracking**  | Four outcomes: PASS, PARTIAL, REFUSE, ERROR       |
| **Atomic File Writes**  | Prevents corrupt/partial output files             |

**What this means for clients:** Every Turas analysis produces a definitive outcome. There are no silent failures or ambiguous results. If something goes wrong, you receive a structured explanation of what happened, why it matters, and how to fix it.

### Refactoring Achievements

| Module | Change | Benefit |
|----|----|----|
| Tabs (Crosstabs) | Reduced from 1,700 to 350 lines | Cleaner code, easier maintenance |
| Confidence | Reduced from 1,396 to 600 lines | Modular architecture |
| All Modules | TRS v1.0 integration | Consistent error handling |
| Shared Infrastructure | Centralized utilities | Reduced duplication |

### New Modules

-   **CatDriver** – Categorical key driver analysis (binary, ordinal, multinomial)
-   **Weighting** – Design weights and rim/raking weights with diagnostics
-   **AlchemerParser** – Automated survey configuration from Alchemer exports

------------------------------------------------------------------------

## Why R and Open-Source Packages?

### For the Non-Technical Reader

Think of R packages like verified recipes from master chefs. Each package:

-   Has been **tested by thousands of users** worldwide
-   Is **publicly reviewed** by statisticians and researchers
-   Follows **documented mathematical formulas** that anyone can verify
-   Is used by **leading universities, pharmaceutical companies, and research institutions**

When Turas calculates a confidence interval or runs a significance test, it's using the same proven methods that power academic research published in peer-reviewed journals.

### For the Statistical Expert

R packages on CRAN (Comprehensive R Archive Network) undergo rigorous quality checks:

-   Automated testing across multiple platforms
-   Documented source code available for audit
-   Version control and changelog tracking
-   Citation standards enabling reproducible research
-   Active maintenance with bug fixes and improvements

Turas exclusively uses CRAN-published packages with established track records in their respective domains.

------------------------------------------------------------------------

## Module-by-Module Package Reference

### 1. Tabs Module (Crosstabulation & Significance Testing)

**Version:** 10.2 **Purpose:** Weighted cross-tabulations with statistical significance testing for survey data.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **openxlsx** | 15M+ | Excel report generation | Industry standard for Excel I/O in R |
| **readxl** | 30M+ | Excel data import | Developed by RStudio/Posit, rigorously tested |
| **lobstr** | 1M+ | Memory monitoring (optional) | Diagnostic support for large datasets |
| **Base R stats** | Built-in | Core statistical functions | Part of R core, maintained by R Foundation |

**Statistical Methods Implemented:**

-   **Weighted z-tests for proportions** – Standard two-proportion test with pooled variance
-   **Weighted t-tests for means** – Welch's t-test accounting for unequal variances
-   **Chi-square tests** – Tests of independence between categorical variables
-   **Effective sample size (Kish 1965)** – Design effect correction: n_eff = (Σw)² / Σw²
-   **Small base handling** – Configurable thresholds (default n≥30) with suppression

**Refactoring Notes:** - Reduced from \~1,700 lines to \~350 lines (80% reduction) - Extracted to focused modules: config, data setup, analysis runner, workbook builder - Checkpoint system for large studies (recovers from interruptions) - Memory monitoring with configurable thresholds

**Validation:** All significance tests use standard formulas from Kish, L. (1965) *Survey Sampling* and follow AAPOR guidelines for weighted survey analysis.

**Statistical Rigor Rating:** 8/10

------------------------------------------------------------------------

### 2. Weighting Module (Survey Weight Calculation)

**Version:** 2.0 **Purpose:** Design weights and rim weights (raking/IPF) with diagnostics.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **survey** | 10M+ | Raking/IPF algorithms | **Gold standard** – Used by US Census, CDC, WHO |
| **readxl** | 30M+ | Configuration import | Posit-maintained |
| **dplyr** | 50M+ | Data manipulation | Most popular R data package |
| **openxlsx** | 15M+ | Excel output | Industry standard |
| **haven** | 20M+ | SPSS/Stata import (optional) | Statistical software interoperability |

**Statistical Methods Implemented:**

-   **Design weights (cell weighting)** – Direct population proportion adjustment
-   **Rim weights (raking/IPF)** – Iterative proportional fitting to marginal totals
    -   Convergence monitoring with configurable tolerance
    -   Multiple dimensions supported (up to 10)
-   **Weight trimming** – Configurable bounds to prevent extreme weights
-   **Weight efficiency** – n_eff/n ratio reporting
-   **Diagnostic output** – Cell-by-cell weight distribution analysis

**Package Provenance:**

The `survey` package by Thomas Lumley (University of Auckland, formerly UCLA) is the definitive R implementation for complex survey analysis. It powers: - US Census Bureau American Community Survey - CDC National Health Interview Survey - World Health Organization surveys

**Validation:** Raking algorithm follows Deming & Stephan (1940). Weight efficiency follows Kish (1965).

**Statistical Rigor Rating:** 9/10

------------------------------------------------------------------------

### 3. Tracker Module (Longitudinal Trend Analysis)

**Version:** MVT Phase 2 **Purpose:** Multi-wave tracking studies with trend analysis and significance testing.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **openxlsx** | 15M+ | Excel I/O and formatting | Industry standard |
| **Base R stats** | Built-in | t-tests, z-tests, distributions | R Foundation maintained |

**Statistical Methods Implemented:**

-   **Two-sample z-tests** – Proportion comparisons between waves
-   **Two-sample t-tests** – Mean comparisons with pooled standard deviation
-   **Trend significance** – Wave-over-wave and baseline comparison
-   **Banner trend analysis** – Segment-level tracking over time
-   **Effective sample size** – Weight-adjusted sample sizes for accurate inference
-   **Question mapping** – Alignment across waves with code changes

**Architecture:** - 17 focused library modules (config, validation, statistical core, output) - Dashboard report generation - Multi-wave data alignment

**Validation:** Tests follow standard parametric inference procedures. Minimum base size requirements (default n≥30) ensure assumptions are met.

**Statistical Rigor Rating:** 6.5/10 (functional for standard tracking; lacks advanced time series methods)

------------------------------------------------------------------------

### 4. Confidence Module (Confidence Intervals & Sample Quality)

**Version:** 10.1 **Purpose:** Calculate confidence intervals using multiple methods and assess sample representativeness.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **readxl** | 30M+ | Configuration import | Posit-maintained |
| **openxlsx** | 15M+ | Report generation | Industry standard |
| **Base R stats** | Built-in | Core statistical functions | R Foundation maintained |

**Statistical Methods Implemented:**

*For Proportions (4 methods):* - **Normal approximation (MOE)** – CI = p ± z × √(p(1-p)/n) - **Wilson score interval** – Better coverage for extreme proportions and small samples - **Bootstrap percentile** – Non-parametric resampling, configurable iterations (default 5,000) - **Bayesian credible interval** – Beta-Binomial conjugate prior with configurable prior parameters

*For Means (3 methods):* - **t-distribution CI** – mean ± t_crit × (SD/√n) - **Bootstrap percentile** – Non-parametric resampling for non-normal distributions - **Bayesian credible interval** – Normal-Normal conjugate with prior mean/SD/n

*For NPS (3 methods):* - **Normal approximation** – Delta method for NPS variance - **Bootstrap percentile** – Resamples full dataset, calculates NPS each iteration - **Bayesian credible interval** – Dirichlet-based modeling of promoter/detractor proportions

*Sample Quality:* - **Kish effective sample size** – n_eff = (Σw)² / Σw² - **Design effect (DEFF)** – Measures efficiency loss from weighting - **CI adjustment for DEFF** – Proper uncertainty quantification for weighted data - **Weighted bootstrap** – Accounts for survey weights in resampling

**Refactoring Notes:** - Reduced from 1,396 lines to \~600 lines (57% reduction) - Extracted question processor and CI dispatcher modules - 200 question limit check (protective, configurable)

**Validation:** Methods follow Brown, Cai & DasGupta (2001) for interval estimation, Kish (1965) for design effects, Efron & Tibshirani (1993) for bootstrap methods, and Gelman et al. (2013) for Bayesian inference.

**Statistical Rigor Rating:** 8/10

------------------------------------------------------------------------

### 5. KeyDriver Module (Driver Analysis & SHAP)

**Version:** 10.3 **Purpose:** Identify which factors drive key outcomes using regression, relative importance, and machine learning.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **xgboost** | 10M+ | Gradient boosting for SHAP | Industry-leading ML library, used by Kaggle winners |
| **shapviz** | 500K+ | SHAP value visualization | Implements Lundberg & Lee (2017) TreeSHAP algorithm |
| **ggplot2** | 50M+ | Visualization | Most-cited R visualization package |
| **ggrepel** | 5M+ | Smart label placement | Prevents label overlap in quadrant charts |
| **openxlsx** | 15M+ | Excel output | Industry standard |
| **haven** | 20M+ | SPSS/Stata import (optional) | Statistical software interoperability |

**Statistical Methods Implemented:**

-   **Partial R² decomposition** – Lindeman, Merenda & Gold (1980) methodology
    -   Handles correlated predictors appropriately
    -   Primary importance method
-   **SHAP (TreeSHAP)** – Model-agnostic feature importance via XGBoost
    -   Individual-level explanations
    -   Beeswarm and waterfall visualizations
-   **Importance-Performance Analysis** – Quadrant mapping for prioritization
-   **Segment comparison** – Driver importance across customer segments
-   **Feature-level on_fail policies** – refuse vs continue_with_flag

**v10.3 Enhancements:** - Explicit driver_type declarations required - Enhanced output contract with Run Status sheet - Full TRS v1.0 integration

**Validation:** Partial R² follows Lindeman, Merenda & Gold (1980). SHAP implements Lundberg & Lee (2017), cited 15,000+ times.

**Statistical Rigor Rating:** 8/10

------------------------------------------------------------------------

### 6. CatDriver Module (Categorical Driver Analysis)

**Version:** 1.1 (TRS Hardening) **Purpose:** Key driver analysis for categorical outcomes—binary, ordinal, or multinomial.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **MASS** | 30M+ | Ordinal logistic regression (polr) | Venables & Ripley, R Core Team maintained |
| **nnet** | 15M+ | Multinomial logistic regression | Part of R's recommended packages |
| **Base R stats** | Built-in | Binary logistic regression (glm) | R Foundation maintained |
| **openxlsx** | 15M+ | Excel output | Industry standard |

**Statistical Methods Implemented:**

-   **Binary logistic regression** – `glm()` with logit link for yes/no outcomes
-   **Ordinal logistic regression** – `MASS::polr()` proportional odds model for ordered categories
-   **Multinomial logistic regression** – `nnet::multinom()` for unordered multi-category outcomes
-   **Canonical design-matrix mapper** – Correct coefficient-to-level mapping
    -   No string parsing hacks
    -   Handles factor level encoding properly
    -   Deterministic and auditable
-   **Rare level policy** – Deterministic collapsing to prevent estimation failures
-   **Per-variable missing data strategies** – Configurable handling
-   **Bootstrap confidence intervals** – Optional resampling-based inference

**Why the Design-Matrix Mapper Matters:**

Many implementations incorrectly match regression coefficients to factor levels using string matching or position assumptions. This breaks when: - Level names contain special characters - Reference categories change - Factors have similar prefixes

CatDriver uses R's actual model matrix to create a canonical mapping, ensuring coefficients are always correctly attributed.

**Validation:** Logistic regression follows Agresti (2002). Ordinal regression follows McCullagh (1980).

**Statistical Rigor Rating:** 8.5/10

------------------------------------------------------------------------

### 7. Pricing Module (Price Sensitivity & Optimization)

**Version:** 11.0 **Purpose:** Van Westendorp PSM, Gabor-Granger demand curves, and price optimization.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **pricesensitivitymeter** | 100K+ | Van Westendorp PSM | Purpose-built for pricing research |
| **ggplot2** | 50M+ | Visualization | Industry standard |
| **readxl/openxlsx** | 30M+/15M+ | Excel I/O | Posit-maintained |
| **scales** | 15M+ | Axis formatting | ggplot2 companion package |
| **haven** | 20M+ | SPSS/Stata import (optional) | Statistical software interoperability |

**Statistical Methods Implemented:**

-   **Van Westendorp PSM** – Four-question price perception analysis
    -   Point of Marginal Cheapness (PMC)
    -   Point of Marginal Expensiveness (PME)
    -   Optimal Price Point (OPP)
    -   Indifference Price Point (IDP)
-   **Newton-Miller-Smith extension** – Purchase probability calibration for PSM
-   **Gabor-Granger demand curve** – Sequential purchase intent across price points
    -   Revenue optimization
    -   Demand elasticity
-   **Segment analysis** – Price sensitivity by customer segment
-   **Price ladder generation** – Good/Better/Best tier recommendations
-   **Recommendation synthesis** – Executive summary with confidence assessment

**Validation:** PSM follows Van Westendorp (1976). Gabor-Granger implements Gabor & Granger (1966). NMS follows Newton, Miller & Smith (1993).

**Statistical Rigor Rating:** 7/10

------------------------------------------------------------------------

### 8. Conjoint Module (Choice-Based Conjoint Analysis)

**Version:** 10.1 (Alchemer Integration) **Purpose:** Discrete choice modeling to understand preference trade-offs.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **mlogit** | 2M+ | Multinomial logit estimation | **Gold standard** for discrete choice in R |
| **dfidx** | 1M+ | Data indexing for mlogit | Required companion to mlogit (v1.1+) |
| **survival** | 20M+ | Conditional logit (fallback) | R's premier survival analysis package |
| **dplyr** | 50M+ | Data manipulation | Most popular data package |
| **tidyr** | 40M+ | Data reshaping | Part of tidyverse ecosystem |
| **readxl** | 30M+ | Excel configuration import | Posit-maintained |
| **openxlsx** | 15M+ | Excel I/O | Industry standard |

**Statistical Methods Implemented:**

-   **Multinomial logit (MNL)** – Standard discrete choice model: P(i\|S) = exp(βᵢ)/Σexp(βⱼ)
-   **Conditional logistic regression** – Robust fallback using survival::clogit
-   **Part-worth utilities** – Attribute level values from coefficients
-   **Zero-centering** – Utilities centered within attributes for interpretation
-   **Attribute importance** – Range-based importance calculation
-   **Market simulator** – Interactive Excel sheet with:
    -   Product configuration with dropdowns
    -   Automatic market share calculations
    -   Sensitivity analysis
    -   Share of preference visualization
-   **Alchemer CBC import** – Direct import from Alchemer choice-based conjoint exports

**v10.1 Enhancements:** - Enhanced mlogit estimation with better diagnostics - Improved zero-centering calculations - Direct Alchemer CBC export import

**Validation:** mlogit implements McFadden's (1974) random utility model, winner of the 2000 Nobel Prize in Economics. The package is authored by Yves Croissant (University of the Reunion), a leading econometrician.

**Statistical Rigor Rating:** 7/10 (basic CBC correct; advanced features limited)

------------------------------------------------------------------------

### 9. Segment Module (Market Segmentation)

**Version:** 10.0 **Purpose:** K-means clustering, Latent Class Analysis, validation, and segment profiling.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **cluster** | 15M+ | Silhouette analysis, gap statistic | Part of R's recommended packages |
| **MASS** | 30M+ | Linear Discriminant Analysis | Venables & Ripley's classic package |
| **poLCA** | 500K+ | Latent Class Analysis | Standard LCA implementation |
| **Base R stats** | Built-in | K-means clustering | R Foundation maintained |
| **readxl** | 30M+ | Excel configuration import | Posit-maintained |
| **writexl** | 5M+ | Excel output | Fast, dependency-free Excel writing |
| **rpart** | 10M+ | Decision trees for rules | Part of R's recommended packages |
| **ggplot2** | 50M+ | Visualization (optional) | Industry standard |
| **haven** | 20M+ | SPSS/Stata import (optional) | Statistical software interoperability |

**Statistical Methods Implemented:**

-   **K-means clustering** – Hartigan-Wong algorithm (Base R)
    -   Exploration mode: Test K=2 through K=8
    -   Final mode: Apply chosen solution
-   **Latent Class Analysis** – Probabilistic clustering for categorical data via poLCA
-   **Silhouette analysis** – Cluster validation metric
-   **Gap statistic** – Optimal K selection
-   **Calinski-Harabasz index** – Between/within cluster variance ratio
-   **Linear Discriminant Analysis** – Validate cluster separation
-   **ANOVA/Chi-square profiling** – Statistical differences between segments
-   **Mahalanobis distance** – Multivariate outlier detection
-   **Segment scoring** – Classify new respondents into existing segments
-   **Segment cards** – Persona-style segment summaries
-   **Rule-based assignment** – Operational segment classification

**Architecture:** - Dual exploration/final mode workflow - 14 focused library modules - Test data generators included

**Validation:** K-means uses Hartigan & Wong (1979). Silhouette follows Rousseeuw (1987). LCA uses Lazarsfeld & Henry (1968).

**Statistical Rigor Rating:** 7/10 (appropriate methods; lacks stability testing)

------------------------------------------------------------------------

### 10. MaxDiff Module (Maximum Difference Scaling)

**Version:** 10.0 **Purpose:** Best-worst scaling to measure item preferences on a ratio scale.

| Package | CRAN Downloads | Purpose in Turas | Why Trusted |
|----|----|----|----|
| **survival** | 20M+ | Conditional logit for aggregate analysis | R's premier survival package, Mayo Clinic maintained |
| **cmdstanr** | 500K+ | Hierarchical Bayes via Stan (optional) | Stan is the gold standard for Bayesian inference |
| **AlgDesign** | 500K+ | D-optimal experimental design | Purpose-built for design optimization |
| **ggplot2** | 50M+ | Visualization | Industry standard |
| **openxlsx** | 15M+ | Excel I/O | Industry standard |

**Statistical Methods Implemented:**

-   **Design generation** – Balanced incomplete block designs via AlgDesign
    -   D-optimal efficiency maximization
    -   Federov algorithm for design optimization
-   **Count analysis** – Best%, Worst%, Net Score descriptive statistics
-   **Aggregate logit** – Population-level utility estimation via conditional logit
    -   Uses survival::clogit (Terry Therneau, Mayo Clinic)
    -   30+ years of clinical trial validation
-   **Hierarchical Bayes** – Individual-level utilities via MCMC (Stan)
    -   β_n \~ MVN(μ, Σ) with LKJ correlation prior
    -   Convergence diagnostics (Rhat, ESS, divergences)
-   **Utility rescaling** – 0-100 scale for client interpretation
-   **Preference simulation** – Share of preference prediction

**Dual Mode Support:** - DESIGN mode: Generate MaxDiff experiment configurations - ANALYSIS mode: Analyze collected MaxDiff data

**Package Provenance:**

Stan (via cmdstanr) is developed by the Stan Development Team including Andrew Gelman (Columbia University). It is used for: - Pharmaceutical clinical trials - Sports analytics (FiveThirtyEight) - Tech industry A/B testing at scale

**Validation:** MaxDiff follows Louviere & Woodworth (1983). HB estimation uses Stan (Carpenter et al., 2017), the most rigorous Bayesian platform available.

**Statistical Rigor Rating:** 7.5/10

------------------------------------------------------------------------

### 11. AlchemerParser Module (Survey Configuration)

**Version:** 1.0 **Purpose:** Automated parsing of Alchemer survey exports to generate Tabs configuration files.

| Package    | CRAN Downloads | Purpose in Turas    | Why Trusted             |
|------------|----------------|---------------------|-------------------------|
| **Base R** | Built-in       | File parsing, regex | R Foundation maintained |

**Functionality:**

-   **Three-file triangulation:**
    -   Data export map (column structure)
    -   Translation export (labels and options)
    -   Word questionnaire (additional hints)
-   **Automatic question classification** – Detects question types from structure
-   **Grid question handling** – Proper parsing of matrix/grid questions
-   **Tabs config generation** – Creates ready-to-use configuration files

**Note:** This module handles data transformation, not statistical analysis. Statistical rigor rating is not applicable.

------------------------------------------------------------------------

## Shared Infrastructure

### TRS v1.0 Components

All modules share common infrastructure from `modules/shared/lib/`:

| Component | Purpose | Lines of Code |
|----|----|----|
| **trs_refusal.R** | Structured error handling with actionable messages | 892 |
| **turas_save_workbook_atomic.R** | Atomic file writes (temp → rename) | 320 |
| **trs_run_state.R** | Run state tracking (PASS/PARTIAL/REFUSE/ERROR) | — |
| **trs_banner.R** | Console output formatting | — |
| **trs_run_status_writer.R** | Run status Excel sheet generation | — |
| **validation_utils.R** | Input validation helpers | — |
| **config_utils.R** | Configuration parsing | — |
| **data_utils.R** | Data manipulation utilities | — |
| **weights_utils.R** | Weight handling utilities | — |
| **hb_diagnostics.R** | Hierarchical Bayes convergence diagnostics (Rhat, ESS) | — |
| **turas_excel_escape.R** | Excel special character handling | — |

### Refusal Code Taxonomy

All error codes follow a structured prefix system:

| Prefix    | Category                            | Example                    |
|-----------|-------------------------------------|----------------------------|
| CFG\_     | Configuration errors                | CFG_MISSING_COLUMN         |
| DATA\_    | Data quality issues                 | DATA_INSUFFICIENT_VARIANCE |
| IO\_      | File/path problems                  | IO_FILE_NOT_FOUND          |
| MODEL\_   | Statistical model issues            | MODEL_CONVERGENCE_FAILURE  |
| MAPPER\_  | Mapping/alignment issues            | MAPPER_LEVEL_MISMATCH      |
| PKG\_     | Package dependency issues           | PKG_MISSING_PACKAGES       |
| FEATURE\_ | Unsupported feature requests        | FEATURE_NOT_IMPLEMENTED    |
| BUG\_     | Internal errors (should not happen) | BUG_UNEXPECTED_STATE       |

------------------------------------------------------------------------

## Summary: Statistical Rigor by Module

| Module | Version | Rigor Rating | Primary Packages | Key Strength |
|----|----|----|----|----|
| **Weighting** | 2.0 | 9/10 | survey | Gold-standard raking |
| **CatDriver** | 1.1 | 8.5/10 | MASS, nnet | Canonical design-matrix mapper |
| **Confidence** | 10.1 | 8/10 | Base R | Proper DEFF adjustment |
| **KeyDriver** | 10.3 | 8/10 | xgboost, shapviz | SHAP validation |
| **Tabs** | 10.2 | 8/10 | Base R, openxlsx | Checkpoint recovery |
| **MaxDiff** | 10.0 | 7.5/10 | survival, cmdstanr | HB via Stan |
| **Conjoint** | 10.1 | 7/10 | mlogit | McFadden MNL |
| **Pricing** | 11.0 | 7/10 | pricesensitivitymeter | NMS extension |
| **Segment** | 10.0 | 7/10 | cluster, poLCA | Dual K-means/LCA |
| **Tracker** | MVT-2 | 6.5/10 | Base R | Multi-wave alignment |

**Overall Platform Rating: 7.5/10**

Turas uses established methods correctly. It is not cutting-edge statistical research, but for applied market research, it provides solid, defensible analysis.

------------------------------------------------------------------------

## Package Reliability Matrix

| Module | Primary Packages | Total CRAN Downloads | Academic Foundation |
|----|----|----|----|
| **Tabs** | Base R, openxlsx, readxl | 70M+ | Kish (1965) |
| **Weighting** | survey, dplyr | 60M+ | Deming & Stephan (1940) |
| **Tracker** | Base R, openxlsx | 15M+ | Standard parametric inference |
| **Confidence** | Base R, openxlsx | 15M+ | Kish (1965), Brown et al. (2001), Efron & Tibshirani (1993) |
| **KeyDriver** | xgboost, shapviz, ggplot2 | 70M+ | Lundberg & Lee (2017) |
| **CatDriver** | MASS, nnet | 45M+ | Agresti (2002), McCullagh (1980) |
| **Pricing** | pricesensitivitymeter, ggplot2 | 55M+ | Van Westendorp (1976) |
| **Conjoint** | mlogit, survival, dplyr, tidyr | 110M+ | McFadden (1974) – Nobel Prize |
| **Segment** | cluster, MASS, poLCA, rpart | 60M+ | Hartigan & Wong (1979) |
| **MaxDiff** | survival, cmdstanr, AlgDesign | 25M+ | Louviere (1983), Carpenter (2017) |

------------------------------------------------------------------------

## Areas for Continuous Improvement

### Completed in v10-11 Refactoring

| Enhancement                      | Modules               | Status     |
|----------------------------------|-----------------------|------------|
| TRS v1.0 reliability framework   | All                   | ✓ Complete |
| Atomic file writes               | All with Excel output | ✓ Complete |
| Structured refusal messages      | All                   | ✓ Complete |
| Orchestrator pattern refactoring | Tabs, Confidence      | ✓ Complete |
| Alchemer CBC import              | Conjoint              | ✓ Complete |
| Design-matrix mapper             | CatDriver             | ✓ Complete |
| HB via Stan                      | MaxDiff               | ✓ Complete |
| SHAP validation                  | KeyDriver             | ✓ Complete |

### Under Consideration

| Enhancement | Modules Affected | Rationale |
|----|----|----|
| Multiple comparison correction | Tabs, Tracker | FDR/Bonferroni for significance testing |
| Bootstrap stability analysis | Segment | Cluster membership stability |
| Hierarchical Bayes | Conjoint | Individual-level part-worths |
| Time series methods | Tracker | Trend decomposition, seasonality |
| Multicollinearity diagnostics | KeyDriver, CatDriver | VIF output |
| Formal simulation validation | All | Monte Carlo accuracy testing |

### Quality Assurance

-   **TRS v1.0 framework** – Consistent error handling across all modules
-   **Guard layer validation** – Pre-flight checks before analysis
-   **Atomic file operations** – No corrupt partial outputs
-   **Run status tracking** – Every analysis has documented outcome

------------------------------------------------------------------------

## Conclusion

Turas delivers statistical analyses you can trust because:

1.  **Established Packages** – Every calculation uses peer-reviewed, widely-adopted R packages
2.  **Transparent Methods** – All formulas are documented and auditable
3.  **Academic Foundations** – Methods cite foundational statistical literature
4.  **Active Maintenance** – Packages receive continuous updates and bug fixes
5.  **Reproducible Results** – Same inputs always produce same outputs
6.  **Reliable Operations** – TRS v1.0 ensures no silent failures

When you receive a Turas report, you're receiving results computed using the same statistical rigor expected in academic publications and regulatory submissions.

------------------------------------------------------------------------

## References

-   Agresti, A. (2002). *Categorical Data Analysis* (2nd ed.). Wiley.
-   Brown, L.D., Cai, T.T., & DasGupta, A. (2001). Interval estimation for a binomial proportion. *Statistical Science*, 16(2), 101-133.
-   Carpenter, B., et al. (2017). Stan: A probabilistic programming language. *Journal of Statistical Software*, 76(1).
-   Deming, W.E., & Stephan, F.F. (1940). On a least squares adjustment of a sampled frequency table. *Annals of Mathematical Statistics*, 11(4), 427-444.
-   Efron, B., & Tibshirani, R.J. (1993). *An Introduction to the Bootstrap*. Chapman & Hall/CRC.
-   Gabor, A., & Granger, C.W.J. (1966). Price as an indicator of quality. *Economica*, 33(129), 43-70.
-   Gelman, A., Carlin, J.B., Stern, H.S., Dunson, D.B., Vehtari, A., & Rubin, D.B. (2013). *Bayesian Data Analysis* (3rd ed.). Chapman & Hall/CRC.
-   Hartigan, J.A., & Wong, M.A. (1979). Algorithm AS 136: A k-means clustering algorithm. *Applied Statistics*, 28(1), 100-108.
-   Johnson, J.W. (2000). A heuristic method for estimating the relative weight of predictor variables. *Multivariate Behavioral Research*, 35(1), 1-19.
-   Kish, L. (1965). *Survey Sampling*. John Wiley & Sons.
-   Lazarsfeld, P.F., & Henry, N.W. (1968). *Latent Structure Analysis*. Houghton Mifflin.
-   Lindeman, R.H., Merenda, P.F., & Gold, R.Z. (1980). *Introduction to Bivariate and Multivariate Analysis*. Scott, Foresman.
-   Louviere, J.J., & Woodworth, G. (1983). Design and analysis of simulated consumer choice. *Journal of Marketing Research*, 20(4), 350-367.
-   Lundberg, S.M., & Lee, S.I. (2017). A unified approach to interpreting model predictions. *Advances in Neural Information Processing Systems*, 30.
-   McCullagh, P. (1980). Regression models for ordinal data. *Journal of the Royal Statistical Society: Series B*, 42(2), 109-142.
-   McFadden, D. (1974). Conditional logit analysis of qualitative choice behavior. In P. Zarembka (Ed.), *Frontiers in Econometrics* (pp. 105-142). Academic Press.
-   Newton, D., Miller, J., & Smith, P. (1993). A market acceptance extension to traditional price sensitivity measurement. *Proceedings of the American Marketing Association*.
-   Rousseeuw, P.J. (1987). Silhouettes: A graphical aid to the interpretation and validation of cluster analysis. *Journal of Computational and Applied Mathematics*, 20, 53-65.
-   Van Westendorp, P. (1976). NSS Price Sensitivity Meter. *ESOMAR Congress*.
-   Wilson, E.B. (1927). Probable inference, the law of succession, and statistical inference. *Journal of the American Statistical Association*, 22(158), 209-212.

------------------------------------------------------------------------

*For technical inquiries about statistical methodology, please contact The Research LampPost (Pty) Ltd.*
