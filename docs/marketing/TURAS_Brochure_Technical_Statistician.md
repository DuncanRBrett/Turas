# TURAS: Technical Specification & Statistical Documentation

## Production-Grade Survey Analytics Platform

**For:** Research statisticians, methodologists, and technical analysts requiring rigorous, defensible, auditable survey analysis

**Quality Score:** 85/100 | **Status:** Production-ready | **Modules:** 11

---

## Platform Architecture

### Design Philosophy

**TURAS** is a modular R-based analytics platform built on three core principles:

1. **Transparency:** All methods use published R packages with peer-reviewed implementations. No proprietary black boxes.
2. **Defensibility:** Industry-standard methods with documented assumptions and limitations.
3. **Production Quality:** Structured error handling (TRS v1.0), comprehensive validation, auditable outputs.

**Development:** The Research LampPost (Pty) Ltd | **Language:** R 4.0+ | **Environment:** `renv` for reproducibility

---

## Statistical Methods & Implementations

### 1. Enhanced Cross-Tabulation (`tabs` module)

**Methods:**
- Z-tests for proportions (normal approximation)
- Chi-square tests for independence
- Fisher's exact test (small cells)
- Design effect-corrected confidence intervals
- Weighted crosstabulation with proper variance estimation

**R Packages:**
- `survey` - Design-aware variance estimation (Lumley, 2004)
- `data.table` - Efficient tabulation
- `effectsize` - Standardized effect sizes (Cohen's h, Cramér's V)

**Key Features:**
- Handles complex survey designs (stratification, clustering, weights)
- Multiple comparison correction options (Bonferroni, Holm)
- Net score calculations (Top-2-Box, Bottom-2-Box with proper SE)

**Assumptions:**
- Simple random sampling (default) or user-specified design
- Independence of observations (unless clustered design specified)
- Minimum expected cell count >5 for chi-square validity

**Output:**
- Cross-tabulation matrices with row/column proportions
- Statistical significance markers with p-values
- Confidence intervals (Wilson score method)
- Sample sizes (weighted and unweighted)

---

### 2. Confidence Interval Estimation (`confidence` module)

**Methods Implemented:**
- **Wilson score interval** (recommended for proportions)
- **Bootstrap percentile intervals** (BCa, percentile, normal)
- **Exact binomial intervals** (Clopper-Pearson)
- **Agresti-Coull interval**
- **Weighted proportion intervals** with design effect adjustment

**R Packages:**
- `binom` - Multiple interval estimation methods
- `boot` - Bootstrap resampling (Efron, 1979)
- `survey` - Design-consistent variance estimation

**Theoretical Basis:**
- Wilson score: Brown, Cai & DasGupta (2001) Statistical Science
- Bootstrap: Efron & Tibshirani (1993) "An Introduction to the Bootstrap"

**Minimum Sample Requirements:**
- n ≥ 30 for normal approximation methods
- n ≥ 10 per cell for Wilson score
- Any n for exact methods (computationally intensive for large n)

**Design Effect Handling:**
- DEFF = 1 + (b-1)ρ where b = cluster size, ρ = intraclass correlation
- Effective sample size: n_eff = n / DEFF
- Conservative approach: CI width inflated by √DEFF

**Validation:**
- Coverage probability tested via simulation (10,000 iterations)
- Validated against published statistical tables

---

### 3. Correlation-Based Driver Analysis (`keydriver` module)

**Method:**
Pearson product-moment correlation (continuous) or Spearman rank correlation (ordinal) between driver variables and outcome variable.

**R Packages:**
- `Hmisc` - Robust correlation with p-values and CI
- `data.table` - Efficient computation
- `weights` - Weighted correlation

**Formula:**
```
r = Σ[(xi - x̄)(yi - ȳ)] / √[Σ(xi - x̄)² Σ(yi - ȳ)²]
```

**Weighted Correlation:**
```
r_w = Σ[wi(xi - x̄_w)(yi - ȳ_w)] / √[Σwi(xi - x̄_w)² Σwi(yi - ȳ_w)²]
```

**Significance Testing:**
- t-statistic: t = r√[(n-2)/(1-r²)]
- df = n - 2
- Two-tailed p-value from t-distribution

**Assumptions:**
- Linear relationship between variables
- Bivariate normality (for Pearson)
- Homoscedasticity
- Independent observations (or proper weighting)

**Limitations:**
- Correlation ≠ causation
- Doesn't account for multicollinearity among drivers
- No control for confounding variables

**Output:**
- Correlation coefficients with 95% CI
- p-values (Bonferroni-corrected option available)
- Importance rankings
- Categorization (High/Medium/Low impact)

---

### 4. Categorical Driver Analysis (`catdriver` module)

**Methods:**
- **Binary logistic regression** (2-category outcome)
- **Ordinal logistic regression** (proportional odds model)
- **Multinomial logistic regression** (unordered categories)
- **Firth correction** for separation issues
- **SHAP values** for individual-level driver importance

**R Packages:**
- `MASS::polr` - Proportional odds logistic regression
- `nnet::multinom` - Multinomial logistic regression
- `logistf` - Firth penalized likelihood (Heinze & Schemper, 2002)
- `shapr` - SHapley Additive exPlanations (Lundberg & Lee, 2017)
- `survey` - Design-aware GLM estimation

**Binary Logistic Model:**
```
logit(P(Y=1)) = β₀ + β₁X₁ + β₂X₂ + ... + βₖXₖ
```

**Proportional Odds Model:**
```
logit(P(Y ≤ j)) = θⱼ - (β₁X₁ + β₂X₂ + ... + βₖXₖ)
```
where θⱼ are threshold parameters

**SHAP Implementation:**
- Kernel SHAP approximation (model-agnostic)
- Individual prediction decomposition
- Additive feature attribution
- Computationally intensive (recommend n < 1,000 for real-time)

**Model Fit Metrics:**
- AIC, BIC for model comparison
- McFadden's pseudo-R²
- Hosmer-Lemeshow goodness-of-fit test (binary)
- Confusion matrix, sensitivity, specificity
- ROC curves and AUC

**Assumptions:**
- Linearity of logit (for continuous predictors)
- Independence of observations
- No perfect multicollinearity
- **Proportional odds** assumption (ordinal model)

**Validation:**
- Test proportional odds assumption (Brant test)
- Check for separation (Firth correction applied if detected)
- Residual diagnostics
- Cross-validation option for prediction accuracy

**Output:**
- Regression coefficients with SE and p-values
- Odds ratios with 95% CI
- SHAP importance values (aggregate and individual)
- Model fit statistics
- Predicted probabilities

---

### 5. Choice-Based Conjoint Analysis (`conjoint` module)

**Method:**
Hierarchical Bayes multinomial logit estimation

**R Packages:**
- `ChoiceModelR` - HB estimation (Rossi, Allenby & McCulloch, 2005)
- `support.CEs` - Choice experiment design
- `mlogit` - Aggregate MNL (alternative method)

**Model:**
Random utility model:
```
Uᵢⱼₜ = Σₖ βᵢₖXₖⱼₜ + εᵢⱼₜ
```
where:
- Uᵢⱼₜ = utility of alternative j for individual i in choice task t
- βᵢₖ = individual-specific part-worth for attribute k
- Xₖⱼₜ = level of attribute k in alternative j, task t
- εᵢⱼₜ = iid extreme value error (Gumbel distribution)

**Choice Probability:**
```
P(choose j | choice set Cₜ) = exp(Uᵢⱼₜ) / Σₘ∈Cₜ exp(Uᵢₘₜ)
```

**Hierarchical Bayes Estimation:**
- Individual part-worths: βᵢ ~ MVN(μ, Σ)
- Population hyperparameters: μ, Σ estimated
- MCMC sampling (Gibbs sampler)
- Burn-in: 10,000 iterations (default)
- Sampling: 10,000 iterations (default)
- Thinning: Every 10th draw

**Convergence Diagnostics:**
- Trace plots of log-likelihood
- Gelman-Rubin R-hat statistics
- Effective sample size (ESS)
- Visual inspection of parameter chains

**Assumptions:**
- IIA (Independence of Irrelevant Alternatives)
- Additive utility
- No interactions between attributes (unless specified)
- Choice tasks orthogonal and balanced

**Minimum Sample Requirements:**
- n ≥ 200 for stable aggregate estimates
- n ≥ 300 for reliable individual HB estimates
- 10-15 choice tasks per respondent

**Output:**
- Individual part-worth utilities
- Aggregate utilities (mean, median, SD)
- Attribute importance (range method)
- Market share simulation
- Willingness-to-pay (price coefficient ratio)

**Validation:**
- Holdout task prediction accuracy
- Cross-validation
- Hit rate (% correctly predicted choices)

---

### 6. MaxDiff Analysis (`maxdiff` module)

**Method:**
Maximum Difference Scaling using multinomial logit or Hierarchical Bayes

**R Packages:**
- `ChoiceModelR` - HB estimation
- `ordinal` - Aggregate MaxDiff via ordinal regression
- `support.CEs` - MaxDiff experimental design

**Model:**
Best-worst multinomial logit:
```
P(item i is best | set S) = exp(βᵢ) / Σⱼ∈S exp(βⱼ)
P(item i is worst | set S) = exp(-βᵢ) / Σⱼ∈S exp(-βⱼ)
```

**Joint Probability:**
```
P(i best, k worst | S) = P(best=i|S) × P(worst=k|S\{i})
```

**Preference Score Rescaling:**
```
Score = 100 × (β - βₘᵢₙ) / (βₘₐₓ - βₘᵢₙ)
```

**Hierarchical Bayes:**
- Same MCMC approach as conjoint
- Individual preference vectors estimated
- Segmentation possible on individual scores

**Experimental Design:**
- Balanced incomplete block design (BIBD)
- Each item appears equal frequency
- Item pairs balanced across sets
- Orthogonality constraints

**Sample Requirements:**
- n ≥ 150 for aggregate
- n ≥ 200 for individual HB scores
- 8-15 best-worst tasks per respondent
- 4-5 items per task (optimal)

**Output:**
- Preference scores (0-100 scale)
- Rankings (with ties handling)
- Share of preference
- Individual scores (HB)
- Statistical significance testing between items

---

### 7. Price Sensitivity Analysis (`pricing` module)

**Methods:**

**A. Van Westendorp Price Sensitivity Meter**

Four price perception questions:
1. Too expensive (upper bound)
2. Too cheap (quality concern)
3. Getting expensive (consideration threshold)
4. Good value (bargain)

**Key Price Points:**
- **Optimal Price Point (OPP):** Intersection of "too expensive" and "too cheap" curves
- **Indifference Price Point (IPP):** Intersection of "getting expensive" and "good value"
- **Acceptable Price Range:** Between PME and PMC

**Methodology:**
- Cumulative distribution analysis
- Curve intersection calculation
- Range estimation with confidence intervals (bootstrap)

**B. Gabor-Granger**

Purchase intent at multiple price points:
```
Demand(p) = % who would purchase at price p
Revenue(p) = p × Demand(p) × Market size
```

**Price Elasticity:**
```
ε = (ΔQ/Q) / (ΔP/P)
```

**R Packages:**
- `data.table` - Cumulative distribution calculation
- `stats` - Curve fitting and interpolation
- `boot` - Bootstrap confidence intervals for price points

**Assumptions (Van Westendorp):**
- Respondents can accurately assess price perceptions
- Price perceptions correlate with actual purchase behavior
- Product description sufficient for realistic evaluation

**Limitations:**
- Stated intent ≠ actual behavior
- No competitive context
- Static analysis (no dynamic pricing)

**Output:**
- Optimal price point with CI
- Acceptable price range
- Demand curve (Gabor-Granger)
- Price elasticity estimates
- Revenue projection tables

---

### 8. Statistical Segmentation (`segment` module)

**Methods:**
- K-means clustering
- Hierarchical clustering (Ward's method, complete linkage)
- Model-based clustering (Gaussian mixture models)

**R Packages:**
- `stats::kmeans` - K-means algorithm
- `cluster` - PAM, CLARA for large datasets
- `mclust` - Model-based clustering (Fraley & Raftery, 2002)
- `factoextra` - Cluster validation

**K-Means Algorithm:**
```
Minimize: Σᵢ₌₁ᵏ Σₓ∈Sᵢ ||x - μᵢ||²
```
where μᵢ is centroid of cluster Sᵢ

**Optimal Cluster Selection:**
- **Elbow method:** Plot within-cluster SS vs. k
- **Silhouette score:** s(i) = [b(i) - a(i)] / max{a(i), b(i)}
- **Calinski-Harabasz index:** Between-cluster variance / within-cluster variance
- **BIC for model-based:** Balances fit and complexity

**Validation:**
- **Stability:** Bootstrap resampling, compare cluster assignments
- **Discrimination:** MANOVA/discriminant analysis on cluster membership
- **Interpretability:** Profile variables F-tests / chi-square tests

**Distance Metrics:**
- Euclidean (continuous variables)
- Gower's distance (mixed data types)
- Standardization: z-scores before clustering

**Sample Requirements:**
- Minimum 100 per expected cluster
- n ≥ 500 for 4-5 stable clusters
- More segmentation variables = larger n needed

**Output:**
- Cluster assignments
- Cluster profiles (means, proportions)
- Discriminating variables (F-statistics)
- Silhouette plots
- Dendrogram (hierarchical)

---

### 9. Longitudinal Tracking Analysis (`tracker` module)

**Methods:**
- Wave-to-wave significance testing (paired t-tests, McNemar's test)
- Trend analysis (linear regression, LOESS smoothing)
- Seasonal decomposition (STL, X-13ARIMA-SEATS)
- Base composition drift detection

**R Packages:**
- `brolgar` - Longitudinal data exploration
- `lme4` - Mixed-effects models (if needed)
- `forecast` - Time series forecasting
- `survey` - Consistent variance estimation across waves

**Wave-to-Wave Comparison:**
Independent samples t-test:
```
t = (x̄₁ - x̄₂) / √(s₁²/n₁ + s₂²/n₂)
```

Paired samples (panel data):
```
t = d̄ / (sₐ/√n)
```
where d̄ = mean difference, sₐ = SD of differences

**Trend Detection:**
Linear trend:
```
y = β₀ + β₁(time) + ε
```
Test: H₀: β₁ = 0

**Seasonal Adjustment:**
STL decomposition:
```
Y(t) = T(t) + S(t) + R(t)
```
where T = trend, S = seasonal, R = remainder

**Data Quality Checks:**
- Base size stability across waves
- Demographic composition drift (chi-square tests)
- Question continuity validation
- Missing data patterns

**Output:**
- Trend tables with significance markers
- Wave-over-wave change (%  points)
- Year-over-year comparisons
- Seasonally adjusted series
- Alert flags for significant changes

---

### 10. Sample Weighting (`weighting` module)

**Method:**
Iterative proportional fitting (raking)

**R Packages:**
- `anesrake` - Rake weighting implementation
- `survey` - Survey design objects
- `weights` - Weight diagnostics

**Algorithm:**
Iterates through marginal distributions:
```
1. Adjust weights to match margin 1
2. Adjust weights to match margin 2
   ...
k. Adjust weights to match margin k
Repeat until convergence (Δw < tolerance)
```

**Convergence Criteria:**
- Maximum weight change < 0.001
- Or maximum iterations (default: 100)

**Weight Trimming:**
- Cap extreme weights at specified percentile (e.g., 3.0)
- Prevents individual respondents dominating analysis

**Efficiency Metrics:**
```
Weighting Efficiency = (Σwᵢ)² / (n × Σwᵢ²)
Effective Sample Size = n × Efficiency
Design Effect (DEFF) = 1 / Efficiency
```

**Quality Checks:**
- Compare weighted vs. unweighted distributions
- Chi-square goodness-of-fit to targets
- Extreme weight identification (>3.0 or <0.33)
- Efficiency threshold (recommend >0.70)

**Output:**
- Individual weights
- Weight summary statistics (min, max, mean, median)
- Efficiency metrics
- Before/after comparison tables
- Convergence diagnostics

---

### 11. Survey Data Parser (`AlchemerParser` module)

**Function:**
Automated parsing of Alchemer survey exports to generate Turas-compatible configuration files.

**R Packages:**
- `readxl` - Excel parsing
- `officer` - Word document parsing
- `openxlsx` - Configuration file generation

**Inputs:**
1. Data export map (Excel)
2. Translation export (Excel)
3. Questionnaire (Word .docx)

**Processing:**
- Question type classification (Single_Response, Multi_Mention, Grid, NPS, etc.)
- Grid structure detection
- Code generation with padding
- Response option extraction

**Outputs:**
- `question_metadata.xlsx` - Question catalogue
- `response_codes.xlsx` - Answer option codes
- `banner_specification.xlsx` - Analysis structure

**Quality Score:** 90/100 | **Use Case:** Workflow automation for Alchemer-based projects

---

## Quality Assurance & Validation

### TRS (Turas Refusal System) v1.0

**Error Handling Framework:**
All functions return structured lists:
```r
list(
  status = "PASS" | "PARTIAL" | "REFUSED",
  result = [analysis output],
  message = "descriptive message",
  code = "ERROR_CODE",
  how_to_fix = "actionable guidance"
)
```

**Error Code Taxonomy:**
- `IO_*` - File/input-output errors
- `DATA_*` - Data validation failures
- `CFG_*` - Configuration issues
- `CALC_*` - Calculation/statistical failures
- `PKG_*` - Package dependency errors

**No Silent Failures:** Every error returns actionable diagnostic information.

---

### Testing Framework

**Test Categories:**
1. **Unit Tests** - Individual function validation
2. **Integration Tests** - Module workflow testing
3. **Edge Case Tests** - Boundary conditions, missing data, extreme values
4. **Golden File Tests** - Output validation against known-good results
5. **Performance Tests** - Speed and memory benchmarks

**Current Coverage:** ~60% (target: 80%+)

**Test Infrastructure:**
- `testthat` framework
- Synthetic data generators for each module
- Regression test suite (67 assertions across 8 modules)

---

### Statistical Validation

**Validation Methods:**
1. **Comparison to Published Results** - Replicate analyses from peer-reviewed papers
2. **Simulation Studies** - Monte Carlo validation of coverage probabilities, Type I error rates
3. **Cross-Platform Verification** - Compare TURAS output to Stata, SPSS, SAS where applicable
4. **Sensitivity Analysis** - Test robustness to assumption violations

**Documentation:**
- `STATISTICAL_VALIDATION_AND_PACKAGE_REFERENCE.md` - Comprehensive method documentation
- Package version tracking via `renv.lock`
- Reproducible analysis with version-controlled dependencies

---

## Reproducibility & Environment Management

### renv Package Management

**Approach:**
- `renv::snapshot()` - Lock file captures exact package versions
- `renv::restore()` - Reproduce exact environment
- Cross-platform compatibility (Windows, macOS, Linux)

**Benefits:**
- Analyses reproducible years later
- No version drift issues
- Audit trail of dependencies

**Package Sources:**
- CRAN (primary source)
- GitHub (for development versions with justification)
- Bioconductor (statistical genetics packages if needed)

---

## Computational Performance

### Benchmarks (Intel i7, 16GB RAM)

| Module | Sample Size | Variables | Processing Time |
|--------|-------------|-----------|----------------|
| Tabs | 1,000 | 50 | <5 seconds |
| KeyDriver | 1,000 | 15 | <10 seconds |
| CatDriver (SHAP) | 500 | 20 | 2-5 minutes |
| Conjoint (HB) | 300 | 5 attributes | 10-20 minutes |
| MaxDiff (HB) | 300 | 20 items | 15-25 minutes |
| Segment (K-means) | 1,000 | 15 | <30 seconds |
| Weighting | 2,000 | 4 margins | <20 seconds |

**Scalability:**
- Most modules: O(n) or O(n log n)
- HB estimation: O(n × iterations) - computationally intensive
- Large samples (n > 5,000): `data.table` optimizations applied

---

## Limitations & Assumptions

### General Limitations

**Sample Requirements:**
- Minimum sample sizes specified per module (see individual sections)
- Underpowered analyses flagged, not executed

**Assumption Violations:**
- Normality: Robust methods preferred (e.g., bootstrap)
- Outliers: Diagnostic plots provided, trimming documented
- Missing data: Listwise deletion default (multiple imputation not yet implemented)

**Not Implemented:**
- Bayesian methods (except HB conjoint/MaxDiff)
- Machine learning algorithms (random forests, neural nets)
- Causal inference frameworks (instrumental variables, regression discontinuity)
- Real-time/streaming analysis
- Interactive dashboards (outputs are static reports)

---

## Output Specifications

### Excel Reports

**Format:**
- Multiple worksheets for different analyses
- Formatted headers and labels
- Embedded charts (where appropriate)
- Color-coded significance markers
- Formulas visible (transparency)

**Content:**
- Summary statistics
- Analytical results (coefficients, p-values, CI)
- Model diagnostics
- Sample sizes (weighted/unweighted)

**Software Compatibility:**
- Excel 2016+ (Windows/Mac)
- LibreOffice Calc
- Google Sheets (with some formatting limitations)

---

### Methodology Documentation

**Included With Every Project:**
- Methods used (equations, citations)
- R packages and versions
- Assumptions tested
- Limitations acknowledged
- Interpretation guidance

**Technical Appendix Available:**
- Detailed statistical specifications
- Code excerpts (upon request)
- Diagnostic plots
- Sensitivity analyses

---

## Peer Review & Audit Trail

### Code Review Standards

**All modules:**
- Peer-reviewed by second statistician
- `styler` code formatting
- Roxygen2 documentation
- Version controlled (Git)

**Pre-Release Checklist:**
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Regression tests pass
- [ ] Code review approval
- [ ] Documentation updated
- [ ] CHANGELOG.md entry

---

## Professional Standards Compliance

### Statistical Best Practices

**Adheres to:**
- ASA Guidelines on Statistical Practice
- AAPOR Code of Professional Ethics and Practices
- ICH E9 Statistical Principles for Clinical Trials (where applicable)
- Journal submission standards (JAMA, APA, AMA)

**Reporting Standards:**
- Effect sizes reported alongside p-values
- Confidence intervals preferred over point estimates
- Multiple comparison adjustments when appropriate
- Assumptions tested and documented

---

## Technical Support & Consultation

### For Statisticians

**We provide:**
- Technical specification documents
- Sample code (R scripts)
- Diagnostic output review
- Method selection consultation
- Sensitivity analysis recommendations

**Collaboration Options:**
- Joint authorship for publishable analyses
- Technical review of your team's analyses
- Custom module development
- Training workshops (R-based)

---

## Pricing for Technical Analysts

### Project-Based Pricing

**Simple Analysis (Single Module):**
- KeyDriver, Tabs, Confidence, Weighting
- $1,500-$2,500

**Intermediate Analysis:**
- CatDriver (without SHAP), Segment, Tracker, Pricing
- $2,500-$4,000

**Advanced Analysis:**
- Conjoint, MaxDiff, CatDriver (with SHAP)
- $4,000-$7,500

**Integrated Multi-Method:**
- Custom scope and pricing
- Volume discounts for ongoing work

### Retainer Options

**Monthly Analytical Support:**
- Priority turnaround
- Unlimited consultation
- Method development included
- $5,000-$15,000/month depending on volume

---

## Getting Started

### Initial Technical Consultation (Free)

**We discuss:**
- Your analytical requirements
- Sample characteristics
- Method appropriateness
- Software/platform compatibility
- Turnaround expectations

**You receive:**
- Recommended analytical approach
- Sample size assessment
- Method documentation
- Transparent pricing

### Pilot Project

**Test TURAS with:**
- One module on your data
- Full technical documentation
- Diagnostic outputs included
- Competitive pricing for first engagement

---

## References & Further Reading

**Key Citations:**

**Conjoint Analysis:**
- Rossi, P.E., Allenby, G.M., & McCulloch, R. (2005). *Bayesian Statistics and Marketing*. Wiley.
- Orme, B. (2010). *Getting Started with Conjoint Analysis*. Research Publishers LLC.

**MaxDiff:**
- Louviere, J., Flynn, T.N., & Marley, A.A.J. (2015). *Best-Worst Scaling*. Cambridge University Press.

**Driver Analysis:**
- Lundberg, S.M., & Lee, S.I. (2017). A unified approach to interpreting model predictions. *NIPS*.

**Survey Statistics:**
- Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*. Wiley.
- Lohr, S.L. (2019). *Sampling: Design and Analysis* (3rd ed.). CRC Press.

**Segmentation:**
- Fraley, C., & Raftery, A.E. (2002). Model-based clustering, discriminant analysis, and density estimation. *JASA*.

**R Packages:**
- Full package documentation: https://cran.r-project.org

---

## Contact

**For technical inquiries:**
The Research LampPost (Pty) Ltd

**Technical Lead:** Duncan Brett
**Email:** [technical email]
**Phone:** [phone]
**Web:** [website]

**Request:**
- Technical specification documents
- Sample R code
- Method validation studies
- Collaboration discussion

---

## The Bottom Line

**TURAS delivers:**
- Transparent, peer-reviewed methods
- Reproducible analyses (renv environment management)
- Comprehensive documentation
- Defensible statistical approaches
- Production-quality code

**For statisticians who need:**
- Rigorous survey analytics
- Auditable methodology
- Rapid turnaround without compromising quality
- Documented assumptions and limitations

**No black boxes. No proprietary algorithms. Just solid statistical practice.**

---

*TURAS: Production-Grade Survey Analytics*
*The Research LampPost (Pty) Ltd*
*Statistical Rigor. Computational Efficiency. Transparent Methods.*
