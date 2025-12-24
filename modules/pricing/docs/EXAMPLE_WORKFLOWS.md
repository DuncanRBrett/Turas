# Turas Pricing Module - Example Workflows

**Version:** 11.0
**Last Updated:** December 2025

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Example 1: Van Westendorp Only - New Product Launch](#2-example-1-van-westendorp-only---new-product-launch)
3. [Example 2: Gabor-Granger Only - SaaS Repricing](#3-example-2-gabor-granger-only---saas-repricing)
4. [Example 3: Both Methods - Consumer Electronics](#4-example-3-both-methods---consumer-electronics)
5. [Example 4: Profit Optimization - E-commerce](#5-example-4-profit-optimization---e-commerce)
6. [Example 5: Segment Analysis - B2B Software](#6-example-5-segment-analysis---b2b-software)
7. [Example 6: Price Ladder - Subscription Tiers](#7-example-6-price-ladder---subscription-tiers)
8. [Common Scenarios](#8-common-scenarios)

---

## 1. Introduction

This document provides complete, step-by-step examples of pricing studies from design to implementation. Each example includes:

- Study background and objectives
- Configuration setup
- Survey design guidance
- Analysis and interpretation
- Business recommendations

Use these as templates for your own pricing research.

---

## 2. Example 1: Van Westendorp Only - New Product Launch

### 2.1 Study Background

**Client:** Consumer goods company launching premium coffee maker

**Objective:** Determine acceptable price range for new smart coffee maker with app connectivity

**Context:**
- No directly comparable product in market
- Competitors range from $89 (basic) to $299 (high-end)
- Need to understand what "smart" features are worth

**Sample:** 400 coffee enthusiasts
**Timeline:** 2 weeks design to results

### 2.2 Survey Design

**Van Westendorp Questions:**

*"We're interested in your perceptions of value for a new smart coffee maker with programmable brewing, automatic grinding, and smartphone app control."*

1. "At what price would you consider this coffee maker to be priced so low that you would feel the quality couldn't be very good?"
2. "At what price would you consider the coffee maker to be a bargain—a great buy for the money?"
3. "At what price would you consider the coffee maker starting to get expensive, but you might still consider buying it?"
4. "At what price would you consider the coffee maker to be so expensive that you would not consider buying it?"

**Additional Questions:**
- Demographics
- Coffee consumption frequency
- Current coffee maker owned
- Feature importance ratings

### 2.3 Configuration

**Settings Sheet:**
```
project_name: SmartCoffeeMaker_Pricing
analysis_method: van_westendorp
data_file: coffee_maker_data.csv
output_file: results/coffee_maker_results.xlsx
currency_symbol: $
id_var: ResponseID
weight_var: (blank)
dk_codes: 98,99
vw_monotonicity_behavior: flag_only
```

**VanWestendorp Sheet:**
```
col_too_cheap: vw_too_cheap
col_cheap: vw_bargain
col_expensive: vw_expensive
col_too_expensive: vw_too_expensive
validate_monotonicity: TRUE
calculate_confidence: TRUE
confidence_level: 0.95
bootstrap_iterations: 1000
```

### 2.4 Results

**Van Westendorp Price Points:**
```
PMC: $118
OPP: $162
IDP: $189
PME: $247

Acceptable Range: $118 - $247
Optimal Range: $162 - $189
```

**Bootstrap 95% Confidence Intervals:**
```
OPP: [$156, $168]
IDP: [$182, $196]
```

**Data Quality:**
- n = 400
- Monotonicity violations: 12.5% (acceptable)
- Missing data: 2.8%
- Valid cases: 389

### 2.5 Interpretation

**Key Findings:**
1. **Acceptable range is wide** ($118-$247): Market has diverse price expectations
2. **Optimal zone is narrow** ($162-$189): Clear price sweet spot
3. **OPP significantly above competitor mid-range** ($89-$150): "Smart" features command premium

**Segment Insights** (post-hoc analysis by coffee consumption):
- Heavy users (3+ cups/day): OPP = $175, IDP = $205 (willing to pay more)
- Light users (1-2 cups/day): OPP = $152, IDP = $178 (more price-sensitive)

### 2.6 Recommendations

**Pricing Strategy:**
- **Launch Price: $179.99**
  - Within optimal range ($162-$189)
  - Just below IDP (leaves room for premium positioning)
  - 77% above mid-market competitors (justified by features)

**Positioning:**
- Position as premium-but-accessible
- Emphasize smart features justify price premium
- Avoid pricing below $160 (quality perception risk)

**Product Line Strategy:**
- Standard model: $179.99 (recommended)
- Premium+ with milk frother: $229.99 (below PME)
- Basic model without app: $149.99 (captures price-sensitive segment)

### 2.7 Business Outcome

**Launched at $179.99**
- 18% market share in smart coffee maker category within 6 months
- Average customer satisfaction: 4.3/5.0
- Price perception: "Fair value" (67%), "Expensive but worth it" (28%)
- No significant quality concerns reported
- Premium positioning established

---

## 3. Example 2: Gabor-Granger Only - SaaS Repricing

### 3.1 Study Background

**Client:** B2B SaaS company with project management software

**Objective:** Find revenue-maximizing price for existing product (currently $39/month)

**Context:**
- Current price set 3 years ago
- Significant feature additions since launch
- Competitors range $25-$59/month
- Considering price increase

**Sample:** 750 current customers
**Timeline:** 1 week fielding, same-day analysis

### 3.2 Survey Design

**Gabor-Granger Questions:**

*"Thinking about the [Product Name] project management software..."*

For each price: "Would you purchase at this price?"
- At $29/month?
- At $35/month?
- At $39/month? (current)
- At $45/month?
- At $49/month?
- At $55/month?
- At $59/month?

Response options: Yes / No

**Additional Questions:**
- Company size
- Usage frequency
- Feature usage
- Likelihood to renew

### 3.3 Configuration

**Settings Sheet:**
```
project_name: SaaS_Repricing_2025
analysis_method: gabor_granger
data_file: customer_survey.csv
output_file: results/repricing_results.xlsx
currency_symbol: $
id_var: CustomerID
weight_var: company_size_weight
dk_codes: (blank)
gg_monotonicity_behavior: smooth
```

**GaborGranger Sheet:**
```
data_format: wide
price_sequence: 29,35,39,45,49,55,59
response_columns: gg_29,gg_35,gg_39,gg_45,gg_49,gg_55,gg_59
response_type: binary
revenue_optimization: TRUE
calculate_elasticity: TRUE
```

### 3.4 Results

**Demand Curve:**
```
Price   Purchase Intent   Revenue Index   Elasticity
$29     87.3%            $25.32          -
$35     81.2%            $28.42          -1.24
$39     75.8%            $29.56          -1.18 (Current)
$45     67.4%            $30.33          -1.32 ⭐ Revenue-Max
$49     58.9%            $28.86          -1.47
$55     48.2%            $26.51          -1.73
$59     39.7%            $23.42          -1.95
```

**Revenue-Maximizing Price: $45**
- Purchase intent: 67.4%
- Revenue index: $30.33
- vs Current ($39): +2.6% revenue

**Price Elasticity:**
- Overall: -1.32 (elastic, but not highly)
- At current price: -1.18
- Interpretation: 10% price increase → ~12% volume decrease

### 3.5 Interpretation

**Key Findings:**
1. **Current price is suboptimal**: Leaving money on the table
2. **Revenue-max at $45**: 15% increase from current
3. **Elastic demand**: But not so elastic that price increases fail
4. **Reasonable tolerance**: 67% would still purchase at $45

**Segment Analysis** (by company size):
- Small (1-10 employees): Revenue-max = $39 (current)
- Medium (11-50): Revenue-max = $45
- Large (51+): Revenue-max = $49

### 3.6 Recommendations

**Recommended Strategy: Tiered Pricing**

Rather than single price increase:

```
Tier Structure:
- Starter: $35/month (for small teams 1-10)
- Professional: $45/month (for teams 11-50) ⭐ Focus
- Enterprise: $custom (for 51+, custom pricing)
```

**Rationale:**
- Captures revenue-optimal price for core segment
- Retains price-sensitive small teams
- Allows premium pricing for large customers
- More palatable than straight price increase

**Implementation Plan:**
- Grandfather existing customers at $39 for 6 months
- New customers start at tiered pricing immediately
- Migrate existing customers after 6 months with 30-day notice

### 3.7 Business Outcome

**Implemented Tiered Pricing**
- Average revenue per customer: +18% (from $39 to $46)
- Churn rate: +1.2% (minimal increase)
- New customer acquisition: +8% (better fit with market)
- Total MRR: +$127K (+22%)
- Customer satisfaction: Maintained (4.2/5.0)

---

## 4. Example 3: Both Methods - Consumer Electronics

### 4.1 Study Background

**Client:** Electronics manufacturer launching wireless headphones

**Objective:**
- Understand acceptable price range (Van Westendorp)
- Find optimal price point (Gabor-Granger)
- Validate consistency between methods

**Context:**
- Competitive market with prices $79-$399
- Mid-tier positioning target
- Premium audio quality, noise cancellation

**Sample:** 500 audio enthusiasts
**Timeline:** 2 weeks

### 4.2 Configuration

**Settings Sheet:**
```
project_name: Headphones_Pricing_Study
analysis_method: both
data_file: headphones_survey.csv
output_file: results/headphones_results.xlsx
currency_symbol: $
```

**VanWestendorp Sheet:**
```
col_too_cheap: vw_too_cheap
col_cheap: vw_bargain
col_expensive: vw_expensive
col_too_expensive: vw_too_expensive
```

**GaborGranger Sheet:**
```
data_format: wide
price_sequence: 99,129,149,169,199,229,249
response_columns: gg_99,gg_129,gg_149,gg_169,gg_199,gg_229,gg_249
```

### 4.3 Results

**Van Westendorp:**
```
PMC: $108
OPP: $142
IDP: $178
PME: $234

Optimal Range: $142-$178
```

**Gabor-Granger:**
```
Revenue-Maximizing Price: $169
- Purchase Intent: 62.4%
- Falls within Van Westendorp optimal range ✓
```

**Method Agreement:**
- Gabor-Granger optimal ($169) is within Van Westendorp optimal range ($142-$178)
- Strong methodological triangulation
- High confidence in recommendation

### 4.4 Recommendations

**Recommended Price: $169.99**

**Supporting Evidence:**
1. Gabor-Granger revenue-maximizing price
2. Within Van Westendorp optimal range
3. 13% below IDP (headroom for premium model)
4. 58% premium over budget competitors ($79-$99)
5. 43% discount to premium competitors ($299-$399)

**Positioning:**
- "Premium performance, accessible price"
- Target middle 40% of market
- Competitive with $149-$199 segment

---

## 5. Example 4: Profit Optimization - E-commerce

### 5.1 Study Background

**Client:** E-commerce retailer with private label products

**Objective:** Maximize profit (not just revenue) on new yoga mat line

**Context:**
- Unit cost: $18.50 (including fulfillment)
- Need minimum 40% margin
- Price-sensitive category

**Sample:** 350 yoga practitioners

### 5.2 Configuration (Key Addition)

**Settings Sheet:**
```
unit_cost: 18.50  ⭐ Enables profit analysis
```

**GaborGranger Sheet:**
```
price_sequence: 25,29,34,39,44,49,54
```

### 5.3 Results

**Revenue vs Profit Analysis:**
```
Price   Purchase%   Revenue   Profit    Margin   Status
$25     78.2%       $19.55    $5.09     26%      Below target margin
$29     71.4%       $20.71    $7.50     36%      Below target margin
$34     63.8%       $21.69    $9.89     46%      ⭐ Min margin met
$39     54.2%       $21.14    $11.11    53%      ⭐ Profit-max
$44     44.9%       $19.76    $11.46    58%      Revenue declining
$49     36.2%       $17.74    $11.04    62%      Revenue declining
```

**Key Finding:**
- Revenue-max: $34 (profit = $9.89)
- Profit-max: $39 (profit = $11.11, +12% vs revenue-max)
- $5 price increase → 12% more profit despite 15% volume loss

### 5.4 Recommendation

**Recommended Price: $39.99**

**Rationale:**
- Maximizes profit ($11.11 per unit)
- Meets minimum margin requirement (53%)
- Volume still healthy (54% purchase intent)
- Room for promotional pricing ($34.99 for sales)

**Promotional Strategy:**
- Regular price: $39.99
- Sale price: $34.99 (revenue-max, drives volume)
- Never below $29 (margin too thin)

---

## 6. Example 5: Segment Analysis - B2B Software

### 6.1 Study Background

**Client:** B2B software company with CRM platform

**Objective:** Understand pricing for different customer segments

**Segments:**
- Small Business (1-10 employees)
- Mid-Market (11-100 employees)
- Enterprise (101+ employees)

**Sample:** 600 business decision-makers (200 per segment)

### 6.2 Configuration

**Settings Sheet:**
```
analysis_method: both
segment_vars: company_size_segment
min_segment_n: 50
```

### 6.3 Results by Segment

**Small Business:**
```
Van Westendorp OPP: $29
Gabor-Granger Revenue-Max: $35
Price Elasticity: -1.82 (highly elastic)
```

**Mid-Market:**
```
Van Westendorp OPP: $79
Gabor-Granger Revenue-Max: $89
Price Elasticity: -1.34 (elastic)
```

**Enterprise:**
```
Van Westendorp OPP: $189
Gabor-Granger Revenue-Max: $219
Price Elasticity: -0.87 (inelastic)
```

### 6.4 Recommendations

**Tiered Pricing Strategy:**
```
Small Business Tier: $39/user/month
- Base features
- Email support
- Max 10 users

Professional Tier: $89/user/month
- Advanced features
- Priority support
- 11-100 users

Enterprise Tier: Custom pricing (starting $199/user/month)
- Full features
- Dedicated support
- 100+ users
- Custom integration
```

**Pricing Insights:**
- 3.6x price differential between Small Business and Enterprise
- Justified by feature differentiation
- Segment-specific value proposition

---

## 7. Example 6: Price Ladder - Subscription Tiers

### 7.1 Study Background

**Client:** Streaming service adding mid-tier subscription

**Current Tiers:**
- Basic: $9.99
- Premium: $19.99

**Objective:** Add "Standard" tier in between

### 7.2 Configuration

**Settings Sheet:**
```
analysis_method: both
n_tiers: 3
tier_names: Basic;Standard;Premium
min_gap_pct: 15
max_gap_pct: 50
round_to: 0.99
anchor: Standard
```

### 7.3 Results

**Van Westendorp:** OPP = $14, IDP = $16
**Gabor-Granger:** Revenue-max = $14.99

**Price Ladder Output:**
```
Tier      Price    Gap from Previous
Basic     $9.99    -
Standard  $14.99   50% ⭐ Optimal price from analysis
Premium   $19.99   33%

Gap Validation:
- Basic → Standard: 50% (healthy, above 15% minimum)
- Standard → Premium: 33% (healthy, below 50% maximum)
- No cannibalization risk flagged
```

### 7.4 Recommendations

**Implemented Three-Tier Structure:**
```
Basic: $9.99/month
- 480p streaming
- 1 device
- Ads included

Standard: $14.99/month ⭐ NEW
- 1080p HD streaming
- 2 devices
- Ad-free
- Optimal price from research

Premium: $19.99/month
- 4K Ultra HD
- 4 devices
- Ad-free
- Downloads
```

**Business Outcome:**
- 34% of Basic users upgraded to Standard
- 8% of prospects chose Standard (vs 3% Premium previously)
- $2.8M additional monthly revenue
- Minimal Premium cannibalization (4% downgrade)

---

## 8. Common Scenarios

### 8.1 Handling Missing Data

**Scenario:** 15% of respondents have missing Van Westendorp answers

**Solution 1: Default (Flag Only)**
```
vw_monotonicity_behavior: flag_only
min_completeness: 0.75
```
Result: Excludes respondents with <75% completion

**Solution 2: More Lenient**
```
min_completeness: 0.50
```
Result: Accepts respondents who answered at least 2 of 4 questions

### 8.2 Non-Monotonic Demand

**Scenario:** Gabor-Granger purchase intent increases at higher prices (violation)

**Solution:**
```
gg_monotonicity_behavior: smooth
```

**Before smoothing:**
```
$25 → 78%
$30 → 71%
$35 → 69%
$40 → 72% ⭐ Violation (higher than $35)
$45 → 65%
```

**After isotonic regression smoothing:**
```
$25 → 78%
$30 → 71%
$35 → 70%
$40 → 70% ⭐ Smoothed
$45 → 65%
```

### 8.3 Integrating with Conjoint

**Scenario:** Ran conjoint study, need to set actual prices

**Approach:**
1. Conjoint shows relative importance of features
2. Pricing research determines absolute price levels
3. Combine insights:

**Example:**
- Conjoint: Premium features worth +30% vs base
- Van Westendorp: Base OPP = $50
- Conclusion: Premium tier = $65 (30% premium)

### 8.4 Tracking Over Time

**Scenario:** Monitor price perceptions quarterly

**Approach:**
1. Use identical survey every quarter
2. Same Van Westendorp questions
3. Track OPP/IDP trends:

```
Q1 2025: OPP = $142
Q2 2025: OPP = $146 (+2.8%)
Q3 2025: OPP = $151 (+3.4%)
Q4 2025: OPP = $149 (-1.3%)
```

**Insight:** Gradual tolerance for higher prices (inflation, value perception improvement)

### 8.5 Competitive Pricing Context

**Scenario:** Want to show competitive prices during research

**Limitation:** Standard Van Westendorp/Gabor-Granger don't include competitive context

**Workaround:**
1. Add competitive awareness questions
2. Show competitors in separate question
3. Analyze by competitive awareness segments

**Alternative:** Use discrete choice experiment for competitive scenarios

### 8.6 International Pricing

**Scenario:** Same product, multiple countries

**Approach:**
1. Run separate studies per country
2. Account for purchasing power parity
3. Local currency symbol in each config

**Example Results:**
```
US: OPP = $149 (USD)
UK: OPP = £129 (GBP) ≈ $162 USD
EU: OPP = €139 (EUR) ≈ $152 USD
```

Insight: Adjust for PPP and local market conditions

---

## 9. Troubleshooting Real Examples

### 9.1 Example: Wide, Unclear Van Westendorp Curves

**Situation:** Curves intersect at multiple points, unclear optimal price

**Investigation:**
- Check if product concept is well-defined
- Review if market is segmented (run segment analysis)
- Examine if competitors span very wide price range

**Finding:** High heterogeneity in market

**Solution:** Segment analysis revealed three distinct groups:
- Budget segment: OPP = $79
- Mid-tier segment: OPP = $129
- Premium segment: OPP = $189

**Result:** Created three product variants

### 9.2 Example: Flat Gabor-Granger Revenue Curve

**Situation:** Revenue index nearly identical across prices

**Investigation:**
```
Price   Revenue Index
$35     $21.45
$40     $21.52
$45     $21.48
$50     $21.39
```

**Finding:** Price insensitivity in tested range

**Solution:** Expand price range in follow-up study:
- Test $25, $30, $35, $40, $45, $50, $60, $70

**Result:** Found revenue-max at $60 (outside original range)

### 9.3 Example: Methods Disagree

**Situation:**
- Van Westendorp optimal range: $80-$110
- Gabor-Granger revenue-max: $140

**Investigation:**
- Van Westendorp shows *perception*
- Gabor-Granger shows *behavior*
- $140 is above Van Westendorp PME ($120)

**Interpretation:**
- Market perceives higher prices as "expensive"
- But still willing to purchase at those prices
- Indicates strong value proposition

**Recommendation:** Price at $129
- Between VW optimal and GG revenue-max
- Test actual market response
- Monitor price perception

---

## 10. Complete Project Template

### 10.1 Project Structure

```
PricingProject/
├── config/
│   └── pricing_config.xlsx
├── data/
│   ├── survey_data.csv
│   └── survey_codebook.xlsx
├── results/
│   ├── pricing_results.xlsx
│   ├── charts/
│   │   ├── vw_psm.png
│   │   └── gg_demand.png
│   └── log.txt
└── reports/
    └── pricing_recommendations.pptx
```

### 10.2 Workflow Checklist

**Phase 1: Planning (Week 1)**
- [ ] Define research objectives
- [ ] Select pricing methodology
- [ ] Determine sample size and segments
- [ ] Budget approval

**Phase 2: Design (Week 2)**
- [ ] Design survey with pricing questions
- [ ] Create configuration file
- [ ] Set up data collection platform
- [ ] Soft launch test (n=50)

**Phase 3: Fielding (Weeks 3-4)**
- [ ] Full launch
- [ ] Monitor daily completes
- [ ] Check data quality
- [ ] Reach target sample size

**Phase 4: Analysis (Week 5)**
- [ ] Export clean data
- [ ] Run Turas Pricing analysis
- [ ] Review results
- [ ] Validate findings

**Phase 5: Reporting (Week 5)**
- [ ] Create summary presentation
- [ ] Generate recommendations
- [ ] Present to stakeholders
- [ ] Get pricing approval

**Phase 6: Implementation (Week 6+)**
- [ ] Set prices
- [ ] Update systems
- [ ] Launch pricing
- [ ] Monitor performance

---

*These workflows demonstrate the flexibility and power of the Turas Pricing module. Adapt them to your specific research needs.*
