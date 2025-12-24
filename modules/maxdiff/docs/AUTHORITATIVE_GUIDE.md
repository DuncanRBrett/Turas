# Turas MaxDiff Module - Authoritative Guide

**Version:** 10.0
**Last Updated:** December 2025

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [MaxDiff Methodology](#2-maxdiff-methodology)
3. [Turas Implementation](#3-turas-implementation)
4. [Strengths and Capabilities](#4-strengths-and-capabilities)
5. [Limitations and Considerations](#5-limitations-and-considerations)
6. [Competitive Landscape](#6-competitive-landscape)
7. [Statistical Packages and Dependencies](#7-statistical-packages-and-dependencies)
8. [When to Use MaxDiff](#8-when-to-use-maxdiff)
9. [Future Development](#9-future-development)

---

## 1. Introduction

### 1.1 Purpose of This Guide

This authoritative guide provides a comprehensive technical and methodological overview of the Turas MaxDiff module. It is intended for:

- **Researchers** evaluating MaxDiff for their studies
- **Methodologists** comparing approaches and implementations
- **Clients** seeking to understand the rigor and capabilities
- **Developers** maintaining or extending the module

### 1.2 What is MaxDiff?

MaxDiff (Maximum Difference Scaling), introduced by Louviere (1991), is a discrete choice experiment designed to measure preferences or importance across a set of items. It belongs to the family of Best-Worst Scaling (BWS) methods, specifically Case 1 BWS (object case).

**Core principle:** Respondents evaluate small subsets of items and identify the extremes (best and worst), leveraging the psychological reality that people can more reliably identify extremes than rate items on scales.

### 1.3 Theoretical Foundation

MaxDiff builds on Random Utility Theory (McFadden, 1974):

- Each item $i$ has an underlying utility $U_i = \beta_i + \epsilon_i$
- The systematic component $\beta_i$ represents the item's mean preference
- The random component $\epsilon_i$ follows an extreme value distribution
- Choices reveal preferences through comparisons, not absolute magnitudes

---

## 2. MaxDiff Methodology

### 2.1 Experimental Design

#### Balanced Incomplete Block Design (BIBD)

Turas MaxDiff primarily uses BIBDs where:
- Not all items appear in every task (incomplete)
- Each item appears with equal frequency (balanced)
- Each pair of items appears together equally (pairwise balance)

**Advantages:**
- Statistical efficiency
- Equal information per item
- Unbiased parameter estimates

#### Design Quality Metrics

**D-efficiency:**
$$D\text{-efficiency} = \left(\frac{|X'X|}{|X'X|_{\text{optimal}}}\right)^{1/p}$$

Where $X$ is the design matrix and $p$ is the number of parameters.

- Values range from 0 to 1
- Above 0.90 is considered excellent
- Above 0.80 is acceptable

**Item Balance:**
Coefficient of variation (CV) of item frequencies should be < 0.10 for balanced designs.

**Pair Balance:**
CV of pair co-occurrence frequencies should be < 0.20 for well-balanced designs.

### 2.2 Estimation Methods

#### Count-Based Scores

The simplest approach, computing descriptive statistics:

**Best Percentage:**
$$\text{Best\%}_i = \frac{\sum_{n,t} w_n \cdot \mathbb{1}[\text{best}_{n,t} = i]}{\sum_{n,t} w_n \cdot \mathbb{1}[i \in S_{n,t}]} \times 100$$

**Net Score:**
$$\text{Net}_i = \text{Best\%}_i - \text{Worst\%}_i$$

**Strengths:**
- Intuitive and easy to communicate
- No assumptions about response processes
- Resistant to model specification errors

**Weaknesses:**
- Not true interval scale
- Doesn't account for design effects
- Can't handle incomplete data elegantly

#### Aggregate Conditional Logit

The industry standard approach, using maximum likelihood:

**Likelihood function:**
$$P(\text{choice } i | S) = \frac{\exp(\beta_i)}{\sum_{j \in S} \exp(\beta_j)}$$

For best choices, and the complement for worst choices (negative utilities).

**Implementation:**
Turas uses `survival::clogit()` which:
- Handles stratified choice data efficiently
- Provides standard errors and significance tests
- Scales to large datasets

**Identification:**
One item (anchor) is fixed at $\beta = 0$ for identification. All other utilities are relative to this anchor.

**Strengths:**
- True interval scale properties
- Asymptotically efficient
- Well-understood statistical properties
- Industry standard for comparability

**Weaknesses:**
- Assumes homogeneous preferences
- May underestimate heterogeneity
- Requires sufficient sample size

#### Hierarchical Bayes (HB)

Individual-level estimation using Bayesian MCMC:

**Model structure:**
$$\beta_n \sim \text{MVN}(\mu, \Sigma)$$
$$\mu \sim \text{Normal}(0, 2^2 I)$$
$$\Sigma = \text{diag}(\sigma) \cdot \Omega \cdot \text{diag}(\sigma)$$

Where:
- $\beta_n$ are individual-level utilities
- $\mu$ is the population mean
- $\Sigma$ is the covariance matrix
- $\Omega$ is the correlation matrix (LKJ prior)

**Non-centered parameterization:**
For better MCMC performance, Turas uses:
$$\beta_n = \mu + L \cdot z_n$$

Where $L$ is the Cholesky factor of $\Sigma$ and $z_n \sim \text{Normal}(0, I)$.

**Implementation:**
Uses Stan via cmdstanr:
- Modern Hamiltonian Monte Carlo (HMC) sampling
- Automatic differentiation for efficient computation
- Comprehensive convergence diagnostics (Rhat, ESS)
- Parallel chain execution

**Strengths:**
- Individual-level utilities enable advanced segmentation
- Better for smaller samples (borrows strength)
- Naturally handles heterogeneity
- Can incorporate respondent-level covariates (future extension)

**Weaknesses:**
- Computationally intensive (10-30 minutes typical)
- Requires cmdstanr setup
- More complex to interpret for non-technical audiences
- Priors can influence results with very small samples

---

## 3. Turas Implementation

### 3.1 Architecture

**Design Philosophy:**
1. **Excel-driven configuration** - Accessible to non-programmers
2. **Modular structure** - Each component is independently testable
3. **Graceful degradation** - Optional features fail safely
4. **Defensive coding** - Comprehensive validation throughout
5. **Reproducibility** - Seed-based randomization, complete logging

**Workflow:**
```
Configuration → Validation → Execution → Output → Visualization
     ↓              ↓            ↓          ↓          ↓
  Excel file    Guards       Design or   Excel    PNG charts
                             Analysis
```

### 3.2 Key Innovations

#### 1. Unified Configuration System

Single Excel workbook controls both DESIGN and ANALYSIS modes:
- Reduces user error
- Ensures consistency between design and analysis
- Familiar interface for researchers

#### 2. Comprehensive Validation

Multiple validation layers:
- **Configuration validation** - Required fields, valid values
- **Design validation** - Balance metrics, efficiency scores
- **Data validation** - Consistency checks, outlier detection
- **Model validation** - Convergence diagnostics, fit statistics

#### 3. Multi-Method Scoring

Automatically generates all three score types:
- Allows methodological triangulation
- Enables sensitivity analysis
- Provides options for different audiences

#### 4. Segment Analysis Framework

Built-in segmentation:
- Define segments via Excel
- Automatic score computation per segment
- Statistical comparison tests
- Segment-specific visualizations

### 3.3 Technical Stack

**Core Language:** R (≥ 4.0)

**Required Dependencies:**
- `openxlsx` - Excel file I/O
- `survival` - Conditional logit estimation
- `ggplot2` - Visualization

**Optional Dependencies:**
- `cmdstanr` - Hierarchical Bayes
- `AlgDesign` - Optimal experimental designs

---

## 4. Strengths and Capabilities

### 4.1 Methodological Strengths

**Robust Design Generation:**
- Multiple design algorithms (BALANCED, OPTIMAL, RANDOM)
- Automatic balance optimization
- Quality metrics and diagnostics
- Multi-version support for blocking

**Comprehensive Analysis:**
- Three complementary estimation methods
- Individual and aggregate-level insights
- Segment analysis with statistical tests
- Model diagnostics and fit statistics

**Statistical Rigor:**
- Implements published best practices
- Validates against known results
- Comprehensive error handling
- Reproducible via seeds

### 4.2 Practical Capabilities

**Flexibility:**
- Handles 6-100+ items
- Works with any survey platform
- Supports weighted analysis
- Allows for filtering and subsetting

**Automation:**
- End-to-end workflow automation
- Batch processing capable
- Automatic output generation
- Built-in visualization

**Accessibility:**
- No programming required for basic use
- Excel-based configuration
- GUI interface available
- Comprehensive documentation

**Scalability:**
- Handles small (n=100) to large (n=10,000+) samples
- Efficient memory management
- Parallel HB chain execution
- Streaming design generation

### 4.3 Advanced Features

**Individual-Level Utilities:**
- Every respondent gets a preference profile
- Enables customer segmentation
- Supports personalization strategies
- Can link to CRM systems

**Custom Segmentation:**
- Unlimited segment definitions
- R expression support for complex segments
- Cross-tabulation capabilities
- Automatic significance testing

**Quality Assurance:**
- Design efficiency metrics
- Response quality flags
- Model convergence diagnostics
- Data validation reports

---

## 5. Limitations and Considerations

### 5.1 Methodological Limitations

**Task Complexity:**
- Requires respondent engagement
- Not suitable for very young children
- May be challenging for cognitively impaired populations
- Online panels may give inattentive responses

**Item Requirements:**
- Items must be conceptually comparable
- Works best with 8-30 items
- Very large item sets (50+) require long surveys
- Items should be understood independently

**Context Effects:**
- Order effects possible despite randomization
- Position bias can occur (mitigated by design)
- Fatigue effects in long surveys
- No price or competitive context unless designed in

### 5.2 Technical Limitations

**HB Requirements:**
- Requires cmdstanr installation (non-trivial)
- Stan can be memory-intensive
- Long computation time for large studies
- Complex diagnostics require expertise

**Sample Size:**
- Minimum ~200 for stable aggregate estimates
- Segments require ~50+ per cell
- HB benefits from larger samples
- Very small samples (n<100) may be unstable

**Software Dependencies:**
- Requires R installation
- Package management can be complex
- Version compatibility issues possible
- Platform differences (Windows/Mac/Linux)

### 5.3 Practical Considerations

**Survey Programming:**
- Requires competent survey programmer
- Design file must be correctly implemented
- Testing is critical
- Mobile compatibility important

**Data Quality:**
- Online panels vary in quality
- Speeders and satisficers problematic
- Need attention checks
- May require data cleaning

**Interpretation:**
- Utilities are relative, not absolute
- Anchor choice can affect interpretation
- Segment differences need statistical testing
- Requires some statistical literacy

---

## 6. Competitive Landscape

### 6.1 Commercial Software

#### Sawtooth Software

**Overview:**
Market leader in MaxDiff and conjoint analysis since 1985.

**Strengths:**
- Mature, well-tested platform
- Integrated survey and analysis
- Large user community
- Extensive documentation and training

**Weaknesses:**
- Expensive (starting ~$1,495/year per user)
- Proprietary platform
- Limited customization
- Windows-centric

**Turas Advantage:**
- Free and open source
- Modern statistical methods (Stan for HB)
- Complete customization possible
- Cross-platform
- Works with any survey tool

#### Qualtrics MaxDiff

**Overview:**
Built-in MaxDiff module in Qualtrics survey platform.

**Strengths:**
- Integrated with survey platform
- Easy setup for basic studies
- No separate software needed
- Good for quick studies

**Weaknesses:**
- Basic analysis only (mostly counts)
- Limited segment capabilities
- No HB estimation
- No design customization
- Expensive platform

**Turas Advantage:**
- All three estimation methods
- Complete design control
- Advanced segmentation
- Full data access and customization
- Works with any survey platform

#### Lighthouse Studio (Sawtooth)

**Overview:**
Sawtooth's premium platform for choice modeling.

**Strengths:**
- Comprehensive choice modeling suite
- Professional support
- Simulation tools
- Market share modeling

**Weaknesses:**
- Very expensive ($5,000-15,000+)
- Steep learning curve
- Proprietary methods
- Limited extensibility

**Turas Advantage:**
- Included in Turas at no cost
- Open methodology
- Modern statistical approaches
- Full source code access

### 6.2 Academic/Open Source

#### choicetools (R package)

**Overview:**
R package for discrete choice experiments.

**Strengths:**
- Free and open source
- Flexible
- R-native

**Weaknesses:**
- Requires R programming
- Limited documentation
- No GUI
- Manual workflow

**Turas Advantage:**
- Excel-based configuration
- GUI available
- Automated workflow
- Better documentation

#### Support.BWS (R package)

**Overview:**
R package specifically for Best-Worst Scaling.

**Strengths:**
- Specialized for BWS
- Academic rigor
- Free

**Weaknesses:**
- Requires extensive R knowledge
- No design generation
- Manual analysis workflow
- Limited output options

**Turas Advantage:**
- End-to-end solution (design + analysis)
- Accessible to non-programmers
- Automated reporting
- Publication-ready charts

### 6.3 DIY/Spreadsheet Approaches

**Common approach:**
- Design in Excel
- Collect data via generic survey tool
- Analyze with spreadsheet formulas

**Weaknesses:**
- Error-prone design generation
- Limited to count-based scores
- No validation
- Not reproducible
- Time-intensive

**Turas Advantage:**
- Automated design generation with quality checks
- Multiple estimation methods
- Comprehensive validation
- Fully reproducible
- Minutes vs. hours/days

---

## 7. Statistical Packages and Dependencies

### 7.1 Core Dependencies

#### openxlsx (v4.2.5+)

**Purpose:** Excel file reading and writing

**Why this package:**
- Pure R implementation (no Java dependency)
- Supports .xlsx format
- Can write formatted workbooks
- Cross-platform

**Alternatives considered:**
- `readxl` - Read-only
- `xlsx` - Requires Java, maintenance issues
- `writexl` - Limited formatting

#### survival (v3.5.0+)

**Purpose:** Conditional logit estimation via `clogit()`

**Why this package:**
- Industry standard for survival and choice modeling
- Efficient stratified logit implementation
- Well-tested and maintained
- Provides standard errors and model fit

**Methodology:**
Uses Cox proportional hazards framework to estimate conditional logit models efficiently.

**Alternatives considered:**
- `mlogit` - Less efficient for MaxDiff structure
- Custom MLE - Reinventing the wheel
- `VGAM` - Overkill for this application

#### ggplot2 (v3.4.0+)

**Purpose:** Publication-quality visualizations

**Why this package:**
- Best-in-class R graphics
- Highly customizable
- Consistent aesthetic
- Wide adoption

**Charts generated:**
- Utility bar charts
- Diverging best-worst charts
- Segment comparisons
- Distribution plots (HB)

**Alternatives considered:**
- Base R graphics - Less polished
- `lattice` - Less flexible
- `plotly` - Overkill, interactive not needed

### 7.2 Optional Dependencies

#### cmdstanr (v0.6.0+)

**Purpose:** Interface to Stan for Hierarchical Bayes

**Why this package:**
- Modern HMC sampling (better than Gibbs)
- Excellent convergence diagnostics
- Parallel chain execution
- Active development

**What is Stan:**
Probabilistic programming language for Bayesian inference using Hamiltonian Monte Carlo.

**Installation:**
Requires separate Stan installation (cmdstan), which is why it's optional.

**Alternatives considered:**
- `rstan` - Older interface, compilation issues
- `RStan` - Deprecated
- JAGS via `rjags` - Slower, less diagnostic
- Custom MCMC - Not worth the effort

**Turas HB Implementation:**
- Non-centered parameterization for efficiency
- LKJ prior on correlation matrix
- Half-Student-t priors on scales
- Full diagnostics (Rhat, ESS, divergences)

#### AlgDesign (v1.2.1+)

**Purpose:** D-optimal experimental design generation

**Why this package:**
- Implements Federov exchange algorithm
- Optimizes D-efficiency
- Handles constraints

**When used:**
Only for OPTIMAL design type. BALANCED designs use custom algorithm.

**Alternatives considered:**
- Custom implementation - AlgDesign is well-tested
- `DoE.base` - Less focused on discrete choice

### 7.3 Future Considerations

**Potential additions:**
- `data.table` - For very large datasets
- `future` / `parallel` - Enhanced parallelization
- `shiny` - Enhanced GUI (currently minimal)
- `targets` - Workflow management for large studies

---

## 8. When to Use MaxDiff

### 8.1 Ideal Use Cases

**Feature Prioritization:**
- Product features to develop
- Service improvements to implement
- Content topics to cover
- Benefits to communicate

**Brand Positioning:**
- Attribute importance
- Brand personality dimensions
- Value propositions
- Messaging themes

**Customer Understanding:**
- Needs assessment
- Preference drivers
- Segment differences
- Decision criteria

**Resource Allocation:**
- Budget priorities
- Time allocation
- Investment decisions
- Portfolio optimization

### 8.2 When MaxDiff is Appropriate

✅ **Use MaxDiff when:**
- You have 8-30 comparable items
- You need to prioritize or rank items
- Trade-offs are important
- You want individual-level data
- Sample sizes are modest (200+)
- Preferences may vary by segment

❌ **Don't use MaxDiff when:**
- Items are not conceptually comparable
- You need absolute measures (use scales)
- You need to understand item combinations (use conjoint)
- You have fewer than 6 items (use ranking)
- Sample size is very small (n<100)
- Items are already clearly ordered

### 8.3 MaxDiff vs. Alternatives

**vs. Rating Scales:**
- MaxDiff forces trade-offs (more discriminating)
- MaxDiff avoids scale use bias
- But ratings are easier for respondents
- Use MaxDiff when differentiation is critical

**vs. Ranking:**
- MaxDiff can handle more items (ranking limited to ~10)
- MaxDiff is easier for respondents
- But full ranking provides more information per respondent
- Use MaxDiff for 10+ items

**vs. Choice-Based Conjoint:**
- Conjoint tests combinations of attributes
- MaxDiff tests single attributes/items
- Conjoint handles interactions, MaxDiff doesn't
- Use MaxDiff for attribute importance, conjoint for configurations

**vs. Discrete Choice Experiments:**
- MaxDiff is a simplified DCE
- DCE can include prices, competitors
- MaxDiff is simpler and faster
- Use MaxDiff for preferences, DCE for market simulation

---

## 9. Future Development

### 9.1 Planned Enhancements

**Near-term (6-12 months):**
- [ ] Enhanced GUI with real-time design preview
- [ ] Built-in data quality metrics and flagging
- [ ] Automated report generation (Word/PowerPoint)
- [ ] Additional chart types (heatmaps, networks)
- [ ] Import/export to other formats (SPSS, Stata)

**Medium-term (1-2 years):**
- [ ] Covariates in HB models (latent class)
- [ ] Market simulation tools
- [ ] Integration with survey platforms (APIs)
- [ ] Enhanced segment discovery (clustering)
- [ ] Time series / tracking study support

**Long-term (2+ years):**
- [ ] Machine learning alternatives to HB
- [ ] Adaptive MaxDiff designs
- [ ] Real-time analysis dashboard
- [ ] Multi-language support
- [ ] Cloud deployment option

### 9.2 Research Directions

**Methodological:**
- Investigating sparse priors for high-dimensional HB
- Comparison of estimation methods via simulation
- Optimal design strategies for specific goals
- Response time modeling for quality detection

**Applied:**
- Industry-specific templates and examples
- Validation studies in different domains
- Best practices documentation
- Case study library

### 9.3 Community Contributions

Turas MaxDiff is part of the open-source Turas suite. Contributions are welcome:

- Bug reports and fixes
- Feature requests
- Documentation improvements
- Example workflows
- Validation studies

---

## 10. References

### Academic Literature

**MaxDiff Foundations:**
- Louviere, J. J. (1991). Best-worst scaling: A model for the largest difference judgments. Working Paper, University of Alberta.
- Finn, A., & Louviere, J. J. (1992). Determining the appropriate response to evidence of public concern: The case of food safety. Journal of Public Policy & Marketing, 11(2), 12-25.

**Random Utility Theory:**
- McFadden, D. (1974). Conditional logit analysis of qualitative choice behavior. In P. Zarembka (Ed.), Frontiers in Econometrics (pp. 105-142). Academic Press.

**Hierarchical Bayes:**
- Allenby, G. M., & Rossi, P. E. (1998). Marketing models of consumer heterogeneity. Journal of Econometrics, 89(1-2), 57-78.
- Orme, B., & Howell, J. (2009). Application of covariates within Sawtooth Software's CBC/HB program. Sawtooth Software Research Paper Series.

**Experimental Design:**
- Kuhfeld, W. F. (2010). Marketing research methods in SAS. SAS Institute Technical Paper MR-2010.
- Street, D. J., & Burgess, L. (2007). The Construction of Optimal Stated Choice Experiments: Theory and Methods. Wiley.

**Stan and HMC:**
- Carpenter, B., et al. (2017). Stan: A probabilistic programming language. Journal of Statistical Software, 76(1), 1-32.
- Hoffman, M. D., & Gelman, A. (2014). The No-U-Turn sampler: Adaptively setting path lengths in Hamiltonian Monte Carlo. Journal of Machine Learning Research, 15(1), 1593-1623.

### Software Documentation

- R Core Team (2024). R: A language and environment for statistical computing. R Foundation for Statistical Computing.
- Therneau, T. M. (2024). A Package for Survival Analysis in R. R package version 3.5-0.
- Wickham, H. (2016). ggplot2: Elegant Graphics for Data Analysis. Springer-Verlag New York.
- Stan Development Team (2024). CmdStanR: R Interface to CmdStan.

### Industry Resources

- Sawtooth Software (2024). MaxDiff Technical Paper.
- Qualtrics (2024). MaxDiff Analysis documentation.
- Cohen, S. H. (2003). Maximum difference scaling: Improved measures of importance and preference for segmentation. Sawtooth Software Conference Proceedings.

---

*This authoritative guide is maintained as part of the Turas Survey Analysis Suite. For updates and additional resources, see the Turas documentation repository.*
