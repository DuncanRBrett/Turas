# Turas Confidence Module - Capabilities Overview

**For Clients and Stakeholders**

---

## What Does This Module Do?

The Turas Confidence Module provides **statistical confidence intervals** for your survey results. When you report that "65% of customers are satisfied," this module tells you the precision of that estimate - for example, "65% ± 3% at 95% confidence."

---

## Why You Need Confidence Intervals

### The Problem

Survey results are estimates based on samples. A sample of 500 customers represents your entire customer base, but there's always uncertainty in that estimate.

**Without confidence intervals:**
> "65% of customers are satisfied"

**With confidence intervals:**
> "65% of customers are satisfied (95% CI: 62%-68%)"

The second statement is more honest and defensible. It acknowledges the statistical uncertainty inherent in survey sampling.

---

## Key Benefits

### 1. Credibility

Confidence intervals are the gold standard for reporting survey statistics. They demonstrate rigorous methodology and are expected by:
- Academic reviewers
- Regulatory bodies
- Sophisticated clients
- Quality auditors

### 2. Better Decision Making

Knowing the precision of your estimates helps decision-makers:
- Distinguish real differences from noise
- Set appropriate thresholds for action
- Allocate resources effectively

### 3. Weighted Data Support

Complex surveys often use weights to correct for sampling bias. This module:
- Correctly calculates confidence intervals for weighted data
- Reports **effective sample size** (accounts for weight variation)
- Calculates **design effect** (measures precision impact of weighting)

### 4. Multiple Methods

Different statistical methods suit different situations:

| Method | Best For |
|--------|----------|
| **Margin of Error** | Standard reporting, large samples |
| **Wilson Score** | Small samples, extreme proportions (near 0% or 100%) |
| **Bootstrap** | Complex weighting, non-normal distributions |
| **Bayesian** | Incorporating prior knowledge, tracking studies |

---

## What Can Be Analyzed?

### Proportions (Percentages)

Any survey question that can be expressed as a percentage:
- % who recommend (NPS promoters)
- % satisfied (top 2 box)
- % aware of brand
- % who purchased
- % agreeing with statement

### Means (Averages)

Numeric survey questions:
- Average satisfaction rating (1-10 scale)
- Mean likelihood to purchase
- Average time spent
- Mean purchase amount

### Net Promoter Score (NPS)

The industry-standard customer loyalty metric:
- Calculated as % Promoters minus % Detractors
- Full confidence interval support
- Weighted data handling

---

## Sample Quality Diagnostics

### Design Effect (DEFF)

When using weighted data, the module calculates how much precision is lost due to weighting:

| DEFF | Interpretation |
|------|----------------|
| 1.0 | No precision loss from weighting |
| 1.2 | 20% increase in variance |
| 2.0 | Precision halved - review weights |

### Effective Sample Size

The "true" sample size after accounting for weighting:

> "Your 1,000 weighted respondents provide precision equivalent to 850 unweighted respondents"

### Quota Representativeness (Optional)

Compare your weighted sample to population targets:
- Traffic-light flagging (GREEN/AMBER/RED)
- Simple quotas (Gender, Age, Region)
- Nested quotas (Gender × Age)

---

## Output Deliverables

The module generates a professional Excel workbook with:

| Sheet | Contents |
|-------|----------|
| **Summary** | High-level overview of results |
| **Study_Level** | Sample size, DEFF, weight diagnostics |
| **Proportions_Detail** | Full results for proportion questions |
| **Means_Detail** | Full results for mean questions |
| **NPS_Detail** | Net Promoter Score results |
| **Representativeness** | Quota achievement (if configured) |
| **Methodology** | Statistical documentation for reports |
| **Warnings** | Data quality flags |
| **Inputs** | Configuration record for reproducibility |

---

## Typical Use Cases

### Case 1: Customer Satisfaction Survey

**Input:** 1,500 weighted respondents, 20 satisfaction questions
**Output:** Confidence intervals for each satisfaction metric

**Report excerpt:**
> "Overall satisfaction stands at 72% (95% CI: 69%-75%). This represents a statistically significant improvement from last quarter's 66% (95% CI: 63%-69%)."

### Case 2: Brand Tracking Study

**Input:** 800 respondents per wave, brand awareness questions
**Output:** Trend analysis with precision estimates

**Report excerpt:**
> "Unaided awareness increased from 34% (±3.3%) in Q1 to 41% (±3.4%) in Q4. The 7 percentage point increase exceeds the combined margin of error, indicating a real improvement."

### Case 3: Net Promoter Score Analysis

**Input:** 2,000 respondents, NPS question (0-10 scale)
**Output:** NPS with confidence interval

**Report excerpt:**
> "Net Promoter Score: +27 (95% CI: +22 to +32). DEFF of 1.15 indicates acceptable weight efficiency."

### Case 4: B2B Survey with Small Segments

**Input:** 150 decision-makers, industry segmentation
**Output:** Wilson Score intervals for small subgroups

**Report excerpt:**
> "Among financial services respondents (n=45), 78% would recommend (95% CI: 63%-88%). The wider interval reflects smaller sample size."

---

## Statistical Rigor

### Methods Meet Industry Standards

- **Wilson Score** recommended by statisticians for proportions
- **Bootstrap** used in academic research for complex designs
- **Bayesian** supports tracking studies with prior data
- **DEFF calculation** follows Kish (1965) standard

### Transparent Methodology

Every output includes:
- Clear documentation of methods used
- Formulas and references
- Assumptions and limitations

---

## Integration with Turas Suite

The Confidence Module integrates seamlessly with other Turas modules:

| Integration | Benefit |
|-------------|---------|
| **Turas Tabs** | Same data file, consistent question codes |
| **Turas Weighting** | Weight variable automatically recognized |
| **Turas Suite GUI** | One-click launch, visual interface |

---

## What Sets Us Apart

### Compared to Manual Calculation

| Manual | Turas Confidence |
|--------|------------------|
| Error-prone | Automated, tested |
| Time-consuming | Seconds per analysis |
| Single method | Multiple methods |
| No weighting support | Full weighting support |

### Compared to Generic Statistics Software

| Generic Tools | Turas Confidence |
|---------------|------------------|
| Steep learning curve | Survey-focused |
| Complex scripting | Excel configuration |
| Generic output | Survey-ready reports |
| No quota checking | Representativeness built-in |

---

## Getting Started

### What You Need

1. **Survey data file** (CSV or Excel)
2. **Configuration file** (Excel template provided)
3. **R 4.0+** with required packages

### Process

1. Configure analysis in Excel template
2. Run through GUI or command line
3. Review Excel output
4. Integrate into reports

### Timeline

- **Setup:** 15-30 minutes for first analysis
- **Subsequent runs:** 2-5 minutes

---

## Summary

The Turas Confidence Module provides:

- **Four confidence interval methods** for proportions
- **Three methods** for means
- **Full NPS support** with intervals
- **Weighted data handling** with DEFF
- **Quota checking** for sample quality
- **Professional output** ready for client reports

**Result:** More credible, defensible survey reporting with rigorous statistical backing.

---

**For technical details, see:** [AUTHORITATIVE_GUIDE.md](AUTHORITATIVE_GUIDE.md)
**For setup instructions, see:** [USER_MANUAL.md](USER_MANUAL.md)

---

*Turas Confidence Module v2.0.0*
*Part of the Turas Analytics Platform*
