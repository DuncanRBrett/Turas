# Turas Conjoint Module - Capabilities Overview

**For Clients and Stakeholders**

---

## What Does This Module Do?

The Turas Conjoint Module analyzes consumer choices to understand what product features matter most to your customers. When you show consumers different product configurations and ask them to choose, this module tells you:

- **Which features drive decisions** (attribute importance)
- **How much each option is worth** (part-worth utilities)
- **What market share your products could capture** (market simulation)

---

## Why You Need Conjoint Analysis

### The Business Problem

Product development teams face difficult trade-offs:
- Should we add more storage or improve battery life?
- Is a premium brand worth the higher manufacturing cost?
- Will customers pay £100 more for the better display?

**Without conjoint:**
> "Let's survey customers about which features they want"
> (Result: Everyone says they want everything)

**With conjoint:**
> "Battery life contributes 35% to choice decisions, while brand only contributes 15%. Customers are willing to pay £85 more for 24-hour battery vs. 12-hour."

---

## Key Benefits

### 1. Understand Trade-Offs

Conjoint forces realistic trade-offs. When customers choose between complete products, you see what they'll actually sacrifice.

**Example Output:**
> "When forced to choose, 67% of customers prefer better battery over larger storage, but only if the price difference is under £50."

### 2. Quantify Feature Value

Part-worth utilities let you calculate the pound value of each feature.

**Example Output:**
> "Moving from Samsung to Apple brand is worth £120 in perceived value. Adding 256GB storage (vs 128GB) is worth £85."

### 3. Predict Market Shares

The market simulator lets you test product configurations before launch.

**Example Output:**
> "Product A (Apple, 256GB, £599) would capture 42% share against competitor configurations B and C."

### 4. Optimize Pricing

Combine utilities with costs to find the profit-maximizing configuration.

**Example Output:**
> "The optimal configuration at £599 is: Apple, 256GB, 18-hour battery. This captures 38% share at the highest margin."

---

## What Can Be Analyzed?

### Product Attributes

Any discrete product characteristic:
- Price levels (£399, £499, £599)
- Brands (Apple, Samsung, Google)
- Features (128GB, 256GB, 512GB)
- Performance levels (Standard, Premium)
- Warranty terms (1 year, 2 years, 3 years)
- Colors, sizes, delivery options...

### Analysis Types

| Type | Description | Use Case |
|------|-------------|----------|
| **Standard CBC** | Choose best option | Most studies |
| **CBC with None** | Include "buy nothing" | Market entry |
| **Best-Worst** | Best and worst in set | Detailed preferences |

---

## How It Works

### 1. Design Your Experiment

Define 4-6 product attributes with 3-4 levels each.

**Example:**
| Attribute | Levels |
|-----------|--------|
| Brand | Apple, Samsung, Google |
| Price | £449, £599, £699 |
| Storage | 128GB, 256GB, 512GB |
| Battery | 12 hours, 18 hours, 24 hours |

### 2. Collect Choice Data

Respondents see product profiles and choose their preferred option.

```
Choice Task 1:
┌─────────────────┬─────────────────┬─────────────────┐
│    Option A     │    Option B     │    Option C     │
├─────────────────┼─────────────────┼─────────────────┤
│ Apple           │ Samsung         │ Google          │
│ £449            │ £599            │ £699            │
│ 128GB           │ 256GB           │ 512GB           │
│ 12 hours        │ 18 hours        │ 24 hours        │
└─────────────────┴─────────────────┴─────────────────┘
     [ Choose ]       [ Choose ]       [ Choose ]
```

### 3. Run the Analysis

Upload data and configuration to Turas Conjoint.

**Process Time:** 2-5 minutes for typical study

### 4. Review Results

**Part-Worth Utilities:**
```
Brand:
  Apple:    +0.45  ████████████████████
  Samsung:  +0.12  █████
  Google:   -0.57  (baseline)

Price:
  £449:     +0.78  ████████████████████████████
  £599:     +0.23  █████████
  £699:     -1.01  (baseline)
```

**Attribute Importance:**
```
Price:      42% ████████████████████████████████████████
Brand:      28% ████████████████████████████
Storage:    18% ██████████████████
Battery:    12% ████████████
```

### 5. Simulate Markets

Test any product configuration against competitors.

```
┌─────────────────────────────────────────────────────┐
│ Market Simulator                                    │
├─────────────────────────────────────────────────────┤
│ Product 1: Apple, £599, 256GB, 18hr   → 42% share  │
│ Product 2: Samsung, £449, 128GB, 12hr → 33% share  │
│ Product 3: Google, £699, 512GB, 24hr  → 25% share  │
└─────────────────────────────────────────────────────┘
```

---

## Typical Use Cases

### Case 1: New Product Launch

**Objective:** Determine optimal feature configuration for new smartphone

**Input:**
- 500 respondents
- 4 attributes × 3 levels each
- 10 choice tasks per respondent

**Output:**
> "Launch at £549 with 256GB and 18-hour battery. Projected 38% market share in target segment. Apple brand premium worth £120 vs. Samsung."

### Case 2: Pricing Optimization

**Objective:** Find price elasticity for premium features

**Input:**
- 800 respondents
- 5 price points (£399-£699)
- Storage and battery variations

**Output:**
> "Price sensitivity: -0.8% share per £10 increase. Storage upgrade (128→256GB) supports £70 premium. Battery upgrade (12→18hr) supports £45 premium."

### Case 3: Portfolio Strategy

**Objective:** Design product line to maximize total share

**Input:**
- 600 respondents
- Simulate 2-product and 3-product portfolios

**Output:**
> "Optimal 2-product portfolio: Entry model (£449, 128GB) at 28% share + Premium (£649, 512GB) at 24% share = 52% total. Adding mid-tier cannibalizes 12% from premium."

### Case 4: Competitive Response

**Objective:** Predict competitor reaction impact

**Input:**
- Current market with 3 competitors
- Simulate competitor price cuts

**Output:**
> "If Competitor A drops price by £50, our share falls from 35% to 31%. Matching the price cut recovers share to 34% but reduces margin by 8%. Recommended response: Add value through storage upgrade instead."

---

## Output Deliverables

### Excel Workbook Contents

| Sheet | Description |
|-------|-------------|
| **Utilities** | Part-worth utilities for every level |
| **Relative_Importance** | Attribute importance (%) |
| **Market_Simulator** | Interactive dropdown tool |
| **Model_Summary** | Fit statistics, hit rate |
| **Confidence_Intervals** | Statistical precision |
| **README** | Interpretation guide |

### Market Simulator

The interactive simulator is the crown jewel:

- Configure up to 5 products using dropdowns
- See market shares update automatically
- Test unlimited scenarios
- No R knowledge required

---

## What Sets Us Apart

### Compared to Manual Analysis

| Manual | Turas Conjoint |
|--------|----------------|
| Error-prone calculations | Automated, tested |
| Days of work | Minutes |
| Static results | Interactive simulator |
| Limited scenarios | Unlimited what-if |

### Compared to Generic Statistics Software

| Generic Tools | Turas Conjoint |
|---------------|----------------|
| Steep learning curve | Excel configuration |
| No simulator | Interactive simulator |
| Raw output | Client-ready report |
| No Alchemer support | Direct Alchemer import |

### Compared to Expensive Platforms

| Premium Platforms | Turas Conjoint |
|-------------------|----------------|
| £50,000+ licenses | Included in Turas |
| Complex interface | Simple Excel config |
| Overkill for standard CBC | Right-sized solution |

---

## Technical Credibility

### Statistical Methods

- **Multinomial Logit** (mlogit package): Industry standard
- **Conditional Logit** (survival package): Robust alternative
- **Effects Coding**: Zero-centered utilities
- **Delta Method**: Confidence intervals

### Validation

- 50+ automated tests
- Real-world project validation
- Hit rates typically 60-70% (vs. 33% chance)

### Fit Statistics

Every analysis includes:
- McFadden R² (pseudo R-squared)
- Log-likelihood
- AIC/BIC for model comparison
- Hit rate (prediction accuracy)

---

## Design Recommendations

### Optimal Design

| Element | Recommended |
|---------|-------------|
| Attributes | 4-6 |
| Levels per attribute | 3-4 |
| Alternatives per choice set | 3-4 |
| Choice sets per respondent | 8-12 |
| Minimum respondents | 300 |

### Sample Size Formula

```
recommended_n = max(300, 300 × (n_attributes/4) × (max_levels/4))
```

---

## Getting Started

### What You Need

1. **Choice data file** (CSV or Excel)
   - From Alchemer, Qualtrics, or custom survey
2. **Configuration file** (Excel template provided)
3. **R 4.0+** with required packages

### Process

1. Export choice data from survey platform
2. Configure analysis in Excel template
3. Run through GUI or command line
4. Review Excel output
5. Use simulator for strategic decisions

### Timeline

- **Setup:** 30-60 minutes for first analysis
- **Subsequent runs:** 5-10 minutes
- **Simulator use:** Unlimited, instant results

---

## Summary

The Turas Conjoint Module provides:

- **Part-worth utilities** for every attribute level
- **Importance scores** showing what drives decisions
- **Interactive simulator** for market predictions
- **Professional output** ready for client presentations
- **Alchemer integration** for seamless data import

**Result:** Data-driven product decisions based on real consumer trade-offs.

---

**For technical details, see:** [AUTHORITATIVE_GUIDE.md](AUTHORITATIVE_GUIDE.md)
**For setup instructions, see:** [USER_MANUAL.md](USER_MANUAL.md)

---

*Turas Conjoint Module v2.1.0*
*Part of the Turas Analytics Platform*
