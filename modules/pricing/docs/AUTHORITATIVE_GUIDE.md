# Turas Pricing Module - Authoritative Guide

**Version:** 11.0
**Last Updated:** December 2025

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Pricing Research Methodology](#2-pricing-research-methodology)
3. [Turas Implementation](#3-turas-implementation)
4. [Strengths and Capabilities](#4-strengths-and-capabilities)
5. [Limitations and Considerations](#5-limitations-and-considerations)
6. [Competitive Landscape](#6-competitive-landscape)
7. [Statistical Packages and Dependencies](#7-statistical-packages-and-dependencies)
8. [When to Use Pricing Research](#8-when-to-use-pricing-research)
9. [Future Development](#9-future-development)
10. [References](#10-references)

---

## 1. Introduction

### 1.1 Purpose of This Guide

This authoritative guide provides a comprehensive technical and methodological overview of the Turas Pricing module. It is intended for:

- **Researchers** evaluating pricing methodologies
- **Methodologists** comparing approaches and implementations
- **Clients** seeking to understand rigor and validity
- **Developers** maintaining or extending the module

### 1.2 What is Pricing Research?

Pricing research applies behavioral economics and psychometric methods to understand how consumers perceive value and make purchase decisions at different price points.

**Core principle:** Price is not just a number—it's a signal of quality, value, and positioning. Optimal pricing balances consumer willingness-to-pay with business objectives.

### 1.3 Theoretical Foundation

Pricing research builds on:

- **Economic Utility Theory**: Consumers maximize utility subject to budget constraints
- **Behavioral Economics**: Price perceptions are relative and context-dependent
- **Psychophysics**: Weber-Fechner law of just-noticeable differences
- **Signal Theory**: Price signals quality when information is asymmetric

---

## 2. Pricing Research Methodology

### 2.1 Van Westendorp Price Sensitivity Meter

#### Historical Context

Developed by Dutch economist Peter Van Westendorp in 1976, the PSM has become the most widely used pricing research technique globally.

#### Methodology

**The Four Questions:**
1. "At what price would you consider the product to be so expensive that you would not consider buying it? (Too expensive)"
2. "At what price would you consider the product to be priced so low that you would feel the quality couldn't be very good? (Too cheap)"
3. "At what price would you consider the product starting to get expensive, so that it is not out of the question, but you would have to give some thought to buying it? (Expensive/Getting expensive)"
4. "At what price would you consider the product to be a bargain—a great buy for the money? (Cheap/Bargain)"

#### Cumulative Distribution Functions

For each price point P:

**Too Cheap Curve:**
$$f_{tc}(P) = Pr(P_{too\_cheap} \geq P)$$

**Not Cheap Curve:**
$$f_{nc}(P) = Pr(P_{bargain} \leq P) = 1 - Pr(P_{bargain} > P)$$

**Not Expensive Curve:**
$$f_{ne}(P) = Pr(P_{expensive} \geq P)$$

**Too Expensive Curve:**
$$f_{te}(P) = Pr(P_{too\_expensive} \leq P)$$

#### Key Price Points

**Point of Marginal Cheapness (PMC):**
$$PMC = \{P : f_{tc}(P) = f_{nc}(P)\}$$

**Optimal Price Point (OPP):**
$$OPP = \{P : f_{tc}(P) = f_{te}(P)\}$$

**Indifference Price Point (IDP):**
$$IDP = \{P : (1-f_{nc}(P)) = (1-f_{ne}(P))\}$$
$$= \{P : f_{expensive}(P) = f_{cheap}(P)\}$$

**Point of Marginal Expensiveness (PME):**
$$PME = \{P : f_{ne}(P) = f_{te}(P)\}$$

#### Acceptable Price Range

**Range of Acceptable Prices (RAP):**
$$RAP = [PMC, PME]$$

**Optimal Price Range (OPR):**
$$OPR = [OPP, IDP]$$

**Interpretation:**
- Below PMC: Risk of quality perception issues
- PMC to OPP: Acceptable but potentially underpriced
- OPP to IDP: Optimal zone for pricing
- IDP to PME: Acceptable but increasing resistance
- Above PME: Unacceptable to most consumers

#### Intersection Algorithm

Turas uses linear interpolation between adjacent grid points:

```r
find_intersection <- function(x, y1, y2) {
  diff <- y1 - y2
  sign_changes <- which(diff[-1] * diff[-length(diff)] < 0)
  idx <- sign_changes[1]

  # Linear interpolation
  weight <- abs(diff[idx]) / (abs(diff[idx]) + abs(diff[idx+1]))
  x[idx] * (1 - weight) + x[idx+1] * weight
}
```

#### Bootstrap Confidence Intervals

For statistical rigor:

1. Resample n respondents with replacement
2. Calculate price points on resampled data
3. Repeat B times (default: 1000)
4. Calculate percentile confidence intervals:

$$CI_{lower} = quantile(boot\_results, \alpha/2)$$
$$CI_{upper} = quantile(boot\_results, 1 - \alpha/2)$$

### 2.2 Gabor-Granger Methodology

#### Historical Context

Introduced by Gabor and Granger (1966), this method constructs demand curves through direct purchase intent questions.

#### Methodology

Respondents are shown multiple price points and asked:
"Would you purchase this product at $X?"

Responses are aggregated to construct:

**Demand Curve:**
$$D(P) = \frac{\sum_{i=1}^{n} w_i \cdot \mathbb{1}[purchase_i(P) = yes]}{\sum_{i=1}^{n} w_i}$$

Where:
- $w_i$ = respondent weight (default: 1)
- $\mathbb{1}[\cdot]$ = indicator function

**Revenue Curve:**
$$R(P) = P \times D(P)$$

**Profit Curve** (if unit cost $C$ provided):
$$\Pi(P) = (P - C) \times D(P)$$

#### Optimal Price

**Revenue-Maximizing Price:**
$$P^*_{revenue} = \arg\max_P \{P \times D(P)\}$$

**Profit-Maximizing Price:**
$$P^*_{profit} = \arg\max_P \{(P - C) \times D(P)\}$$

#### Price Elasticity

Arc elasticity between consecutive prices $P_1$ and $P_2$:

$$E_{arc} = \frac{\frac{Q_2 - Q_1}{(Q_2 + Q_1)/2}}{\frac{P_2 - P_1}{(P_2 + P_1)/2}}$$

$$= \frac{Q_2 - Q_1}{Q_2 + Q_1} \times \frac{P_2 + P_1}{P_2 - P_1}$$

**Interpretation:**
- $|E| > 1$: Elastic demand (price-sensitive)
- $|E| = 1$: Unit elastic
- $|E| < 1$: Inelastic demand (price-insensitive)

### 2.3 Newton-Miller-Smith (NMS) Extension

#### Purpose

The NMS extension calibrates Van Westendorp results with actual purchase intent to provide more accurate revenue predictions.

#### Additional Data

At two anchor points (bargain and expensive prices):
- "How likely are you to purchase at this price?" (0-100%)

#### Calibration

Purchase probability at price P:

$$Pr(purchase|P) = f_{calibrated}(P, PI_{bargain}, PI_{expensive})$$

Where calibration uses the `pricesensitivitymeter` R package implementation.

**Revenue-Optimal Price:**
$$P^*_{NMS} = \arg\max_P \{P \times Pr(purchase|P)\}$$

---

## 3. Turas Implementation

### 3.1 Architecture

**Design Philosophy:**
1. **Excel-driven configuration** - Accessible to non-programmers
2. **Modular structure** - Each method is independent
3. **Graceful degradation** - Optional features fail safely
4. **Comprehensive validation** - Data quality checks throughout
5. **Reproducibility** - Deterministic results with audit trail

**Workflow:**
```
Excel Config → Config Loader → Validator → Analysis Engine → Output Generator
     ↓              ↓              ↓             ↓                ↓
  Template      Structured    Clean Data    Results Object   Excel + Plots
                  List
```

### 3.2 Key Innovations

#### 1. Unified Configuration System

Single Excel workbook controls both Van Westendorp and Gabor-Granger:
- Reduces setup complexity
- Ensures consistency
- Familiar interface for researchers

#### 2. Monotonicity Handling

**Van Westendorp:**
- `flag_only`: Reports violations but keeps all data
- `drop`: Removes violating respondents
- `fix`: Automatically sorts prices (not recommended)

**Gabor-Granger:**
- `smooth`: Isotonic regression to enforce monotonicity
- `diagnostic_only`: Reports violations without correction
- `none`: No checking

#### 3. Profit Optimization

Distinguishes between revenue-maximizing and profit-maximizing prices:
- Profit-max typically $3-7 higher than revenue-max
- Critical for margin-sensitive businesses

#### 4. Advanced Features (v11.0)

**Segment Analysis:**
- Run pricing analysis across customer segments
- Identify tiered pricing opportunities
- Compare price sensitivity

**Price Ladder Builder:**
- Automatic Good/Better/Best tier generation
- Gap analysis between tiers
- Cannibalization risk assessment

**Recommendation Synthesis:**
- AI-driven price recommendations
- Confidence assessment (HIGH/MEDIUM/LOW)
- Evidence-based decision support

### 3.3 Technical Stack

**Core Language:** R (≥ 4.0)

**Required Dependencies:**
- `readxl` - Excel file reading
- `openxlsx` - Excel file writing
- `ggplot2` - Visualizations

**Optional Dependencies:**
- `pricesensitivitymeter` - NMS extension
- `haven` - SPSS/Stata file support

---

## 4. Strengths and Capabilities

### 4.1 Methodological Strengths

**Robust Methodology:**
- Van Westendorp: 45+ years of validation across industries
- Gabor-Granger: Econometrically sound demand curve estimation
- NMS: Behavioral calibration for improved accuracy

**Dual Approach:**
- Range finding (Van Westendorp)
- Point estimation (Gabor-Granger)
- Together provide complete pricing strategy

**Statistical Rigor:**
- Bootstrap confidence intervals
- Price elasticity calculation
- Validation diagnostics
- Reproducible results

### 4.2 Practical Capabilities

**Flexibility:**
- Handles B2C and B2B pricing
- Works with any survey platform
- Supports weighted analysis
- Allows filtering and subsetting

**Automation:**
- End-to-end workflow automation
- Minutes from data to insights
- Automatic visualization generation
- Built-in quality checks

**Accessibility:**
- No programming required
- Excel-based configuration
- GUI interface available
- Comprehensive documentation

**Scalability:**
- Handles small (n=100) to large (n=10,000+) samples
- Multiple segments
- Multiple products (run separately)
- Efficient computation

### 4.3 Advanced Features

**Profit Optimization:**
- Revenue vs profit trade-off analysis
- Margin-aware pricing recommendations
- Cost sensitivity analysis

**Segment Analysis:**
- Unlimited segment definitions
- Cross-tabulation capabilities
- Automatic significance testing
- Price discrimination opportunities

**Price Ladder:**
- Automatic tier generation
- Gap validation
- Cannibalization assessment
- Revenue projection by tier

**Recommendation Synthesis:**
- Multi-method triangulation
- Confidence scoring
- Risk assessment
- Executive-ready narratives

---

## 5. Limitations and Considerations

### 5.1 Methodological Limitations

**Van Westendorp PSM:**

**Strengths:**
- Intuitive for respondents
- Provides price ranges
- Industry-standard methodology

**Limitations:**
- Assumes price is only quality signal
- No competitive context
- Relies on hypothetical intent
- Monotonicity violations (10-20% typical)
- Curve intersections may be unclear

**Gabor-Granger:**

**Strengths:**
- Direct demand curve estimation
- Revenue/profit optimization
- Elasticity measurement

**Limitations:**
- Hypothetical purchase intent
- No competitive context
- Order effects possible
- Requires sufficient price range
- Assumes independence of price points

**NMS Extension:**

**Strengths:**
- Behavioral calibration
- More accurate revenue prediction

**Limitations:**
- Requires additional questions
- Dependent on `pricesensitivitymeter` package
- More complex for respondents

### 5.2 Technical Limitations

**Sample Size:**
- Van Westendorp: Minimum 100 respondents
- Gabor-Granger: Minimum 200 respondents
- Segment analysis: 50+ per segment
- Small samples may yield unstable estimates

**Survey Design:**
- Question wording must be precise
- Price range must be appropriate
- Respondent engagement required
- Order effects need management

**Software Dependencies:**
- Requires R installation
- Package management complexity
- NMS requires additional package

### 5.3 Practical Considerations

**Context Effects:**
- No competitive pricing shown
- No feature trade-offs
- Abstract purchase scenarios
- May not reflect actual behavior

**Data Quality:**
- Speeders problematic
- Attention checks needed
- Validation critical
- May require data cleaning

**Interpretation:**
- Results are relative, not absolute
- Assumes rational actors
- Context-dependent
- Requires business judgment

---

## 6. Competitive Landscape

### 6.1 Commercial Software

#### Qualtrics Pricing Tools

**Overview:**
Built-in pricing module in Qualtrics survey platform.

**Strengths:**
- Integrated with survey platform
- Easy setup for basic studies
- Good for quick exploratory research

**Weaknesses:**
- Van Westendorp only (no Gabor-Granger)
- No profit optimization
- Limited segment analysis
- Basic visualizations
- Expensive platform requirement

**Turas Advantage:**
- Multiple methodologies
- Profit optimization
- Advanced segmentation
- Free and open source

#### Sawtooth Pricing Tools

**Overview:**
Part of Sawtooth's suite of pricing and choice modeling tools.

**Strengths:**
- Comprehensive pricing toolkit
- Professional support
- Mature platform
- Large user community

**Weaknesses:**
- Expensive ($2,500-5,000+ per year)
- Proprietary platform
- Windows-centric
- Limited customization

**Turas Advantage:**
- Included at no cost
- Open methodology
- Cross-platform
- Full source code access
- Modern statistical methods

#### Conjointly Pricing Tools

**Overview:**
Cloud-based pricing research platform.

**Strengths:**
- Easy online setup
- Fast fielding
- Modern interface

**Weaknesses:**
- Subscription model ($$$)
- Limited to platform
- No customization
- Basic analysis

**Turas Advantage:**
- No subscription fees
- Works with any survey platform
- Advanced analytics
- Complete customization

### 6.2 Academic/Open Source

#### R Packages

**pricesensitivitymeter:**
- Focused on Van Westendorp with NMS
- Good for Van Westendorp only
- Turas integrates this for NMS extension

**Other tools:**
- Most require manual coding
- No integrated workflow
- Limited documentation

**Turas Advantage:**
- Complete workflow automation
- Excel configuration
- Comprehensive documentation
- Multiple methodologies integrated

### 6.3 Pricing Research vs. Alternatives

**vs. Conjoint Analysis:**
- Pricing research: Focused on price optimization
- Conjoint: Tests feature/price trade-offs
- Use pricing when price is the primary question
- Use conjoint for complex product configurations

**vs. Discrete Choice:**
- Pricing research: Price-specific
- DCE: Tests full offerings (price + features + brand)
- Pricing research is simpler and faster
- DCE provides competitive context

**vs. A/B Testing:**
- Pricing research: Pre-launch optimization
- A/B testing: Live market testing
- Pricing research lower risk
- A/B testing shows actual behavior

---

## 7. Statistical Packages and Dependencies

### 7.1 Core Dependencies

#### readxl (v1.4.0+)

**Purpose:** Excel file reading

**Why this package:**
- Fast and reliable
- Handles both .xls and .xlsx
- No Java dependency
- Cross-platform

**Usage in Turas:**
- Configuration file loading
- Data file reading
- Template parsing

#### openxlsx (v4.2.5+)

**Purpose:** Excel file writing with formatting

**Why this package:**
- Pure R (no Java)
- Supports formatting and styling
- Multiple sheet writing
- Cross-platform

**Usage in Turas:**
- Results workbook generation
- Formatted output tables
- Multi-sheet reports

#### ggplot2 (v3.4.0+)

**Purpose:** Statistical visualizations

**Why this package:**
- Best-in-class R graphics
- Highly customizable
- Publication quality
- Consistent aesthetic

**Charts generated:**
- Van Westendorp PSM plot
- Gabor-Granger demand curves
- Revenue and profit curves
- Segment comparisons

**Alternatives considered:**
- Base R graphics: Less polished
- plotly: Overkill for static charts
- lattice: Less flexible

### 7.2 Optional Dependencies

#### pricesensitivitymeter (v1.2.0+)

**Purpose:** NMS extension implementation

**Why this package:**
- Industry-standard NMS implementation
- Well-tested and validated
- Active maintenance
- Peer-reviewed methodology

**What is NMS:**
Newton-Miller-Smith extension calibrates Van Westendorp with purchase intent for more accurate revenue prediction.

**Installation:**
```r
install.packages("pricesensitivitymeter")
```

**Usage in Turas:**
- NMS analysis when purchase intent data provided
- Revenue-optimal price calculation
- Trial-optimal price calculation

#### haven (v2.5.0+)

**Purpose:** SPSS/Stata file support

**Why this package:**
- Supports multiple research data formats
- Preserves variable labels
- Handles value labels

**Supported formats:**
- SPSS (.sav)
- Stata (.dta)
- SAS (limited)

**Usage in Turas:**
- Data loading from SPSS/Stata
- Optional, falls back to CSV/Excel

### 7.3 Development Dependencies

**For testing:**
- `testthat` - Unit testing framework
- `mockery` - Mocking for tests

**For development:**
- `devtools` - Development tools
- `roxygen2` - Documentation generation

### 7.4 Future Considerations

**Potential additions:**
- `data.table` - For very large datasets
- `future` - Parallel processing for bootstrap
- `shiny` - Enhanced GUI
- `plotly` - Interactive charts (optional)

---

## 8. When to Use Pricing Research

### 8.1 Ideal Use Cases

**New Product Launch:**
- No market price history
- Need to understand acceptable ranges
- Strategic positioning decision
- Competitive entry pricing

**Price Optimization:**
- Existing product repricing
- Revenue/profit maximization
- Understanding elasticity
- Testing price changes

**Tiered Pricing:**
- Good/Better/Best structure
- Subscription tiers
- Service packages
- Product line pricing

**Market Segmentation:**
- Price discrimination opportunities
- Segment-specific pricing
- Geographic pricing
- Customer lifetime value optimization

### 8.2 When Pricing Research is Appropriate

✅ **Use Pricing Research when:**
- Price is the primary decision variable
- Testing specific price points or ranges
- Need to understand price sensitivity
- Revenue or profit optimization is the goal
- Sample sizes are adequate (100-300+)
- Product/service is well-defined

❌ **Don't use Pricing Research when:**
- Features/attributes need to be tested together (use conjoint)
- Competitive context is critical (use choice-based methods)
- Actual purchase data available (use revealed preference)
- Product concept is unclear
- Sample size too small (n < 100)
- Multiple products need simultaneous testing

### 8.3 Method Selection Guide

**Use Van Westendorp PSM when:**
- Exploring acceptable price ranges
- New product with no price benchmark
- Understanding quality perceptions
- Strategic positioning decisions
- Simple, fast research needed

**Use Gabor-Granger when:**
- Need specific optimal price
- Revenue/profit optimization
- Understanding price elasticity
- Testing specific price alternatives
- Demand curve estimation needed

**Use Both Methods when:**
- Comprehensive pricing strategy needed
- Want range AND optimal price
- Triangulation for confidence
- Budget allows (minimal additional cost)

**Add NMS Extension when:**
- More accurate revenue prediction needed
- Behavioral calibration valuable
- `pricesensitivitymeter` package available
- Slightly longer survey acceptable

**Add Segment Analysis when:**
- Tiered pricing strategy considered
- Customer heterogeneity expected
- Price discrimination possible
- Adequate sample per segment (50+)

---

## 9. Future Development

### 9.1 Planned Enhancements

**Near-term (6-12 months):**
- [ ] Enhanced GUI with real-time visualization
- [ ] Competitive pricing scenarios
- [ ] Time series/tracking capabilities
- [ ] Additional chart types
- [ ] Export to PowerPoint

**Medium-term (1-2 years):**
- [ ] Machine learning price prediction
- [ ] Advanced segmentation (clustering)
- [ ] Integration with pricing systems
- [ ] Real-time API endpoints
- [ ] Multi-product optimization

**Long-term (2+ years):**
- [ ] Adaptive pricing experiments
- [ ] Dynamic pricing algorithms
- [ ] Market simulation capabilities
- [ ] Cloud deployment option
- [ ] Multi-language support

### 9.2 Research Directions

**Methodological:**
- Comparing bootstrap vs analytical CIs
- Optimal price point selection
- Handling missing data
- Improving NMS calibration

**Applied:**
- Industry-specific benchmarks
- Validation studies
- Best practices documentation
- Case study library

### 9.3 Community Contributions

Turas Pricing is part of the open-source Turas suite. Contributions welcome:

- Bug reports and fixes
- Feature requests
- Documentation improvements
- Example workflows
- Validation studies
- Industry applications

---

## 10. References

### Academic Literature

**Van Westendorp PSM:**
- Van Westendorp, P. (1976). NSS Price Sensitivity Meter (PSM) – A new approach to study consumer perception of price. Proceedings of the ESOMAR Congress.
- Lewis, M., & Shoemaker, S. (1997). Price-sensitivity measurement: A tool for the hospitality industry. Cornell Hotel and Restaurant Administration Quarterly, 38(2), 44-54.

**Gabor-Granger:**
- Gabor, A., & Granger, C. W. J. (1966). Price as an indicator of quality: Report on an enquiry. Economica, 33(129), 43-70.
- Lyon, D. W. (2002). The price is right (or is it?). Marketing Research, 14(4), 8-13.

**NMS Extension:**
- Newton, D., Miller, J., & Smith, P. (1993). A market acceptance extension to traditional price sensitivity measurement. Proceedings of the American Marketing Association Advanced Research Techniques Forum.

**Pricing Theory:**
- Nagle, T. T., Hogan, J., & Zale, J. (2016). The Strategy and Tactics of Pricing: A Guide to Growing More Profitably (6th ed.). Routledge.
- Simon, H., & Fassnacht, M. (2019). Price Management: Strategy, Analysis, Decision, Implementation. Springer.

**Behavioral Economics:**
- Kahneman, D., & Tversky, A. (1979). Prospect theory: An analysis of decision under risk. Econometrica, 47(2), 263-291.
- Ariely, D. (2008). Predictably Irrational: The Hidden Forces That Shape Our Decisions. HarperCollins.

### Software Documentation

- R Core Team (2024). R: A language and environment for statistical computing. R Foundation for Statistical Computing.
- Wickham, H., et al. (2024). readxl: Read Excel Files. R package.
- Schauberger, P., & Walker, A. (2024). openxlsx: Read, Write and Edit xlsx Files. R package.
- Wickham, H. (2016). ggplot2: Elegant Graphics for Data Analysis. Springer-Verlag.
- Dehmelt, M. (2024). pricesensitivitymeter: Van Westendorp Price Sensitivity Meter Analysis. R package.

### Industry Resources

- Sawtooth Software (2024). Pricing Research Technical Papers.
- Professional Pricing Society (2024). Pricing Research Best Practices.
- ESOMAR (2024). Guidelines for Pricing Research.

---

*This authoritative guide is maintained as part of the Turas Survey Analysis Suite. For updates and additional resources, see the Turas documentation repository.*
