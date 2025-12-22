# Client Transparency Review: Turas Statistical Methods & R Packages

**Version:** 1.0
**Date:** December 2025
**Purpose:** Technical transparency for clients on statistical methods and R package usage

---

## Overview

This document explains the statistical methods and R packages used in Turas analytics modules. Each section covers what we use, why we use it, and alternatives worth considering for future development.

---

## 1. TABS (Crosstabulation)

### Current Implementation

**Primary Packages:**
- **Base R (stats)** - Chi-square tests, weighted calculations
- **openxlsx** - Excel output with formatting
- **readxl** - Data import

**Why These Packages:**
- Base R provides reliable, well-tested statistical functions with no dependencies
- openxlsx creates formatted Excel outputs clients expect
- Custom algorithms give precise control over weighting and complex question types

**Statistical Methods:**
- **Weighted crosstabulation** using custom cell calculators
- **Chi-square significance testing** to identify meaningful differences
- **Column/row percentages** with proper weight handling
- **Index calculations** (base=100) for easy comparison
- **Multi-mention question handling** with category-level analysis
- **Composite scores** for multi-item scales

**How It Works:**
1. Data is weighted using survey weights (if provided)
2. Cross-classifications create frequency tables
3. Chi-square tests determine if relationships are statistically significant
4. Percentages are calculated with denominator options (total, row, column)
5. Indices normalize scores to 100 for easy interpretation

### Packages to Consider

- **survey** - Complex survey design with stratification, clustering, and finite population corrections
- **srvyr** - Tidyverse-compatible survey analysis with dplyr syntax
- **questionr** - French package with excellent crosstab formatting and visualization
- **gmodels::CrossTable** - SAS/SPSS-style output with multiple test statistics
- **descr::crosstab** - Compact crosstab output with multiple percentage options

**Future Value:** The `survey` package would add design effect calculations and complex sample handling. `srvyr` would modernize the syntax for easier maintenance.

---

## 2. TRACKER (Multi-Wave Trend Analysis)

### Current Implementation

**Primary Packages:**
- **Base R (stats)** - T-tests, Z-tests for significance
- **openxlsx** - Multi-sheet Excel reports
- **readxl** - Wave data loading

**Why These Packages:**
- Base R t-tests and z-tests are industry-standard for wave-over-wave comparisons
- Custom wave management handles complex tracking scenarios (missing waves, multiple breakouts)
- Excel output format matches client expectations for tracking reports

**Statistical Methods:**
- **T-tests** for comparing means across waves (continuous metrics)
- **Z-tests** for comparing proportions across waves (categorical metrics)
- **Trend calculations** showing absolute change and percent change
- **NPS tracking** with promoter/detractor decomposition
- **Banner breakout trends** for subgroup analysis
- **Composite score evolution** across waves

**How It Works:**
1. Each wave is loaded and validated for consistency
2. Metrics are calculated within each wave using proper weights
3. T-tests compare means between consecutive or reference waves
4. Z-tests compare proportions with pooled standard errors
5. Trends show direction and magnitude of change
6. Significance flags highlight meaningful movement

### Packages to Consider

- **forecast** - Time series forecasting with ARIMA, exponential smoothing
- **tseries** - Time series analysis and stationarity tests
- **changepoint** - Automated detection of significant trend changes
- **trend** - Non-parametric trend tests (Mann-Kendall)
- **broom** - Tidy statistical output for easier automation
- **EnvStats** - Enhanced t-tests with trend analysis

**Future Value:** `forecast` could predict future waves. `changepoint` would automatically flag significant shifts without manual inspection. `trend` offers non-parametric alternatives when normality assumptions fail.

---

## 3. CONFIDENCE (Confidence Intervals & Study Diagnostics)

### Current Implementation

**Primary Packages:**
- **Base R (stats)** - qnorm, qt, qbeta for interval calculations
- **openxlsx** - Excel output
- **readxl** - Configuration import

**Why These Packages:**
- Base R statistical distributions are mathematically rigorous and battle-tested
- Custom implementation allows multiple CI methods in one analysis
- Bayesian methods provide more intuitive interpretations for clients

**Statistical Methods:**

**For Proportions (e.g., % agreeing):**
- **Normal approximation** - Classic ±margin of error (quick but less accurate at extremes)
- **Wilson score interval** - More accurate near 0% or 100%
- **Bootstrap confidence intervals** - Distribution-free, works for any metric
- **Bayesian credible intervals** - Probability-based interpretation using Beta-Binomial model

**For Means (e.g., average rating):**
- **t-distribution intervals** - Accounts for sample size uncertainty
- **Bootstrap intervals** - Robust to non-normal distributions
- **Bayesian credible intervals** - Normal-Normal conjugate prior

**For NPS (Net Promoter Score):**
- **Variance of difference** - Proper handling of correlated proportions
- **Bootstrap intervals** - Empirical approach for complex metrics
- **Bayesian intervals** - Coherent probability statements

**Study-Level Diagnostics:**
- **Design Effect (DEFF)** - Measures weight concentration (DEFF = 1 + CV²)
- **Effective sample size** - Kish formula: n_eff = n / DEFF
- **Weight diagnostics** - Concentration and representativeness metrics

**How It Works:**
1. Sample statistics (mean, proportion) are calculated with weights
2. Standard errors account for finite population and design effects
3. Multiple CI methods provide robustness checks
4. Bootstrap resampling (1000-10000 iterations) creates empirical distributions
5. Bayesian methods use weakly informative priors for stable estimates

### Packages to Consider

- **Hmisc::binconf** - Multiple binomial CI methods in one function
- **PropCIs** - Specialized proportion confidence intervals (Agresti-Coull, Jeffreys)
- **DescTools** - Comprehensive CI toolkit for many statistics
- **boot** - Advanced bootstrap methods (BCa, studentized)
- **bayestestR** - Modern Bayesian credible intervals and diagnostics
- **MBESS** - Confidence intervals for effect sizes and R²
- **surveyCIs** - Confidence intervals for complex survey designs

**Future Value:** `boot` would add bias-corrected accelerated (BCa) intervals. `PropCIs` offers Jeffreys interval (often better than Wilson). `surveyCIs` would integrate with complex sampling designs.

---

## 4. PRICING (Van Westendorp PSM & Gabor-Granger)

### Current Implementation

**Primary Packages:**
- **ggplot2** - Professional demand curves and PSM charts
- **Base R (stats)** - Smoothing (loess, kernel density)
- **openxlsx** - Excel deliverables

**Why These Packages:**
- ggplot2 creates publication-quality visualizations clients need
- Kernel density estimation provides smooth willingness-to-pay distributions
- Custom implementations give full control over revenue/profit optimization

**Statistical Methods:**

**Van Westendorp Price Sensitivity Meter (PSM):**
- **Cumulative distribution analysis** of four price questions:
  - Too cheap (quality concerns)
  - Bargain
  - Getting expensive
  - Too expensive
- **Key price points:**
  - PMC (Point of Marginal Cheapness) - intersection of "too cheap" and "not expensive"
  - OPP (Optimal Price Point) - intersection of "expensive" and "bargain"
  - IDP (Indifference Price Point) - intersection of "bargain" and "expensive"
  - PME (Point of Marginal Expensiveness) - intersection of "too expensive" and "not bargain"
- **Acceptable price range** bounded by PMC and PME

**Gabor-Granger:**
- **Demand curve construction** from sequential purchase intent at different prices
- **Revenue optimization** finding price that maximizes units × price
- **Profit optimization** incorporating cost structures
- **Price elasticity estimation** measuring demand sensitivity
- **WTP distribution** using kernel density smoothing
- **Competitive scenarios** modeling market share at different price points

**How It Works:**
1. PSM: Cumulative curves show % of respondents at each price threshold
2. Intersections identify psychologically meaningful price points
3. Gabor-Granger: Purchase probability at each price level creates demand curve
4. Smooth curves using loess or kernel methods
5. Optimize over price range considering revenue = price × demand × market size
6. Sensitivity analysis shows robustness to assumptions

### Packages to Consider

- **pricesensitivitymeter** - Automated PSM analysis and visualization
- **conjoint** - Add price as an attribute in choice modeling
- **DiscreteChoiceModels** - More sophisticated demand models
- **optimization** - Advanced optimization for complex pricing scenarios
- **fitdistrplus** - Better distribution fitting for WTP
- **maxLik** - Maximum likelihood estimation for custom demand functions
- **mco** - Multi-criteria optimization (revenue, market share, profit simultaneously)

**Future Value:** `pricesensitivitymeter` would standardize PSM calculations. `fitdistrplus` could identify the best statistical distribution for WTP. `mco` would handle trade-offs between multiple business objectives.

---

## 5. SEGMENT (K-means Clustering)

### Current Implementation

**Primary Packages:**
- **stats::kmeans** - Hartigan-Wong algorithm (default, most robust)
- **cluster** - Silhouette analysis and Gap statistic
- **Base R** - Distance calculations, standardization
- **writexl** - Excel export

**Why These Packages:**
- K-means is fast, interpretable, and works well for most market segmentation
- Hartigan-Wong algorithm produces stable, high-quality clusters
- Silhouette and Gap statistics provide objective cluster quality measures
- Z-score standardization ensures all variables contribute equally

**Statistical Methods:**

**Clustering:**
- **K-means** with Hartigan-Wong algorithm (minimizes within-cluster sum of squares)
- **Z-score standardization** to handle different scales
- **Multiple k exploration** to find optimal number of segments
- **Iterative refinement** with multiple random starts (nstart=25)

**Validation:**
- **Silhouette coefficient** - measures how similar each point is to its cluster vs. other clusters (−1 to +1, higher is better)
- **Elbow method** - plots within-cluster sum of squares (WSS) vs. k
- **Gap statistic** - compares WSS to null reference distribution
- **Between/Total SS ratio** - % variance explained by clustering

**Outlier Detection:**
- **Z-score method** - flags extreme values (|z| > 3)
- **Mahalanobis distance** - multivariate outlier detection accounting for correlations

**Segment Profiling:**
- **ANOVA** - identifies which variables significantly differ across segments
- **Post-hoc comparisons** - shows which segments differ from each other

**How It Works:**
1. Variables are standardized to mean=0, SD=1
2. K-means runs multiple times with different random starts
3. Best solution (lowest WSS) is selected
4. Silhouette and Gap statistics evaluate cluster quality
5. ANOVA profiles segments on input and outcome variables
6. Segments are assigned interpretable names based on characteristics

### Packages to Consider

- **mclust** - Model-based clustering using Gaussian mixture models (automatically selects k)
- **dbscan** - Density-based clustering (no need to specify k, finds outliers)
- **hclust / dendextend** - Hierarchical clustering with better dendrograms
- **factoextra** - Enhanced visualization (silhouette plots, cluster plots)
- **fpc** - More cluster validation metrics (Dunn index, connectivity)
- **NbClust** - Tests 30+ indices to recommend optimal k
- **clustMixType** - K-prototypes for mixed numeric/categorical data
- **protoclust** - Finds prototype observations for each cluster
- **poLCA** - Latent class analysis for categorical data

**Future Value:** `mclust` provides probabilistic segment membership (useful for soft assignment). `NbClust` reduces guesswork in choosing k. `clustMixType` would handle attitudinal + demographic variables simultaneously. `dbscan` finds natural groupings without forcing spherical clusters.

---

## 6. CONJOINT (Choice-Based Analysis)

### Current Implementation

**Primary Packages:**
- **mlogit** - Multinomial logit estimation (primary method)
- **dfidx** - Data indexing required by mlogit
- **survival::clogit** - Conditional logit (fallback)
- **dplyr / tidyr** - Data manipulation
- **openxlsx** - Excel output

**Why These Packages:**
- mlogit is the gold standard for discrete choice analysis in R
- Multinomial logit assumes independence of irrelevant alternatives (IIA), appropriate for most choice studies
- Conditional logit accounts for choice set variation
- OLS fallback handles rating-based designs

**Statistical Methods:**

**Estimation:**
- **Multinomial logit (MNL)** using Newton-Raphson optimization
  - Models choice probability: P(choice) = exp(V_i) / Σ exp(V_j)
  - V_i = utility of alternative i = Σ β_k × X_ik
- **Conditional logit** when using survival::clogit (mathematically similar, different software implementation)
- **OLS regression** for rating-based conjoint (less common, assumes metric scale)
- **Hierarchical Bayes** planned for Phase 2 (individual-level utilities)

**Analysis:**
- **Part-worth utilities** - β coefficients showing preference for each attribute level
- **Relative importance** - % contribution of each attribute to total utility range
  - Importance_k = (max(β_k) − min(β_k)) / Σ(max(β) − min(β))
- **Choice probability simulation** - predict market share for new products
- **Market share scenarios** - "what if" analysis with different competitive sets
- **Interaction effects** - test non-additive preferences (e.g., brand × price)
- **None option handling** - models opt-out behavior

**How It Works:**
1. Choice data is reshaped to one row per alternative per choice task
2. Maximum likelihood estimation finds β coefficients
3. Part-worths show directional preference (higher = more preferred)
4. Relative importance normalizes contributions across attributes
5. Simulation uses fitted model to predict choices in new scenarios
6. Standard errors and p-values indicate statistical significance

### Packages to Consider

- **support.CEs** - Experimental design for choice experiments
- **AlgDesign** - Optimal design generation (D-efficient, orthogonal)
- **choicetools** - Choice modeling utilities and diagnostics
- **apollo** - Advanced discrete choice (mixed logit, latent class, hybrid choice)
- **gmnl** - Generalized multinomial logit (random parameters, WTP space)
- **bayesm** - Bayesian methods including hierarchical Bayes conjoint
- **RSGHB** - Hierarchical Bayes estimation (individual-level utilities)
- **idefix** - Efficient designs for MNL and mixed logit
- **mixl** - Fast mixed logit in R and C++
- **logitr** - Fast multinomial logit with WTP space parameterization

**Future Value:** `bayesm` or `RSGHB` would add hierarchical Bayes for individual utilities (critical for microsegmentation). `gmnl` handles preference heterogeneity with random parameters. `apollo` is comprehensive for advanced choice models (mixed logit, nested logit, latent class). `support.CEs` and `idefix` would improve experimental design efficiency.

---

## 7. KEY DRIVER (Relative Importance Analysis)

### Current Implementation

**Primary Packages:**
- **Base R (stats::lm)** - OLS regression
- **Base R (stats::cor)** - Correlation matrices
- **openxlsx** - Excel output

**Why These Packages:**
- OLS regression is widely understood and interpretable
- Multiple importance methods provide triangulation
- Custom implementations allow weighted analysis throughout

**Statistical Methods:**

Turas provides **four complementary importance methods**:

**1. Standardized Beta Weights (Johnson 2000):**
- Uses |standardized regression coefficients|
- Assumes predictors are independent
- Quick, intuitive, but biased when predictors correlate

**2. Relative Weights (Johnson 2000):**
- Decomposes R² using eigenvalue decomposition
- Accounts for correlated predictors
- Gold standard for observational data
- Method: R² = Σ λ_k × (Σ β_j × e_jk)²

**3. Shapley Value Regression (Game Theory):**
- Evaluates each predictor's average marginal contribution
- Tests all possible predictor combinations (2^p models)
- Most rigorous but computationally intensive
- Limited to ≤15 drivers due to factorial complexity
- Provides unique, fair attribution

**4. Zero-Order Correlations:**
- Simple Pearson correlation with outcome
- Ignores multicollinearity
- Useful baseline, but not recommended as primary method

**Diagnostics:**
- **VIF (Variance Inflation Factor)** - detects multicollinearity (VIF > 5 is concern)
- **R² decomposition** - shows how much variance each driver explains
- **Weighted analysis** - all calculations respect survey weights

**How It Works:**
1. Correlation matrix computed with pairwise complete observations
2. OLS regression fits outcome = β₀ + β₁X₁ + ... + βₚXₚ
3. Standardized betas calculated from correlation matrix
4. Relative weights use eigendecomposition of correlation matrix
5. Shapley method fits all 2^p − 1 subset models and averages marginal contributions
6. VIF calculated as 1/(1−R²) from auxiliary regressions
7. Results normalized to sum to 100% for client clarity

### Packages to Consider

- **relaimpo** - Multiple relative importance metrics (LMG, PMVD, first/last)
- **dominanceanalysis** - Dominance analysis (complete, conditional, general)
- **randomForest** - Variable importance from machine learning
- **randomForestExplainer** - Enhanced RF importance metrics
- **vip** - Unified variable importance framework for many models
- **iml** - Interpretable ML (Shapley values, LIME, PDP)
- **DALEX** - Model-agnostic importance and explanations
- **shapper** - Fast Shapley value computation
- **car::vif** - Enhanced VIF with generalized variance inflation
- **mctest** - Comprehensive multicollinearity diagnostics

**Future Value:** `relaimpo` provides LMG metric (same as relative weights but faster). `dominanceanalysis` offers dominance analysis (pairwise comparisons of predictors). `randomForest` handles non-linear relationships better than OLS. `iml` or `DALEX` would add model-agnostic explanations for complex models. `shapper` accelerates Shapley computation for >15 drivers.

---

## Cross-Cutting Considerations

### Weighting Throughout
All modules handle survey weights properly:
- Weighted means, proportions, correlations
- Weighted regression (diagonal weight matrix)
- Design effect (DEFF) calculations
- Effective sample size adjustments

### Excel Integration
- **openxlsx** used consistently for formatted output
- Multi-sheet workbooks with conditional formatting
- Direct copy-paste to PowerPoint for clients
- Configuration-driven analysis via Excel templates

### GUI Accessibility
- All modules have **Shiny** interfaces for non-technical users
- File browsers (**shinyFiles**) for data/config selection
- Real-time validation and user feedback
- Export to Excel with one click

### Testing & Quality
- **testthat** framework with 67 regression tests
- Automated checks prevent breaking changes
- Version control and reproducibility

---

## General Recommendations for Future Development

### Immediate Value
1. **survey** / **srvyr** - Professional survey analysis with complex sampling
2. **boot** - Enhanced bootstrap methods (BCa intervals)
3. **bayesm** / **RSGHB** - Hierarchical Bayes conjoint for individual-level utilities
4. **relaimpo** - Faster relative importance calculations
5. **mclust** - Model-based clustering with automatic k selection

### Medium-Term
6. **forecast** - Time series forecasting for tracker
7. **apollo** - Advanced choice models (mixed logit, latent class)
8. **NbClust** - Objective cluster number selection
9. **PropCIs** - Better proportion confidence intervals
10. **DALEX** / **iml** - Model-agnostic explanations

### Advanced/Specialized
11. **gmnl** - Random parameters conjoint (WTP distributions)
12. **dbscan** - Non-spherical clustering
13. **changepoint** - Automated trend detection in tracker
14. **support.CEs** / **idefix** - Optimal conjoint design generation
15. **poLCA** - Latent class analysis for segmentation

---

## Philosophical Approach

**Turas balances:**
- **Rigor** - Proper statistical methods, validated implementations
- **Accessibility** - Excel interfaces, clear output, intuitive methods
- **Transparency** - Multiple methods for triangulation, diagnostics included
- **Practicality** - Fast computation, handles real-world messy data
- **Client focus** - Outputs designed for non-statisticians, actionable insights

We use base R and established packages rather than cutting-edge methods because:
- Stability matters for production systems
- Clients trust well-known methods
- Maintenance is easier with fewer dependencies
- Results are reproducible across R versions

We implement custom code when:
- No package handles weighted analysis properly
- We need precise control over output formatting
- Standard packages are overkill for the use case
- Computation speed matters for large datasets

---

## Summary Table: R Packages by Module

| Module | Core Packages | Statistical Packages | Output | GUI |
|--------|--------------|---------------------|--------|-----|
| **Tabs** | Base R | stats (chi-square) | openxlsx | shiny, shinyFiles |
| **Tracker** | Base R | stats (t-test, z-test) | openxlsx | shiny, shinyFiles |
| **Confidence** | Base R | stats (qnorm, qt, qbeta) | openxlsx | shiny, shinyFiles |
| **Pricing** | ggplot2 | stats (density, loess) | openxlsx | shiny, shinyFiles |
| **Segment** | cluster | stats (kmeans, ANOVA) | writexl | shiny, shinyFiles |
| **Conjoint** | mlogit, dfidx | survival (clogit), dplyr | openxlsx | shiny, shinyFiles |
| **Key Driver** | Base R | stats (lm, cor) | openxlsx | shiny, shinyFiles |

---

## Contact & Questions

For technical questions about statistical methods or to request new features, please contact the Turas development team.

**Document maintained by:** Turas Analytics Team
**Last updated:** December 2025
**Next review:** June 2026
