# Turas MaxDiff Module - Marketing Guide

**Version:** 10.0
**Last Updated:** December 2025

---

## What is MaxDiff?

MaxDiff (Maximum Difference Scaling), also known as Best-Worst Scaling, is a powerful market research technique that reveals what matters most to your customers. Instead of asking respondents to rate items individually, MaxDiff presents sets of options and asks respondents to choose:

- The **BEST** (most important/preferred) option
- The **WORST** (least important/preferred) option

This forced-choice approach produces more discriminating and actionable insights than traditional rating scales.

---

## Why Choose Turas MaxDiff?

### Complete End-to-End Solution

Turas MaxDiff handles your entire MaxDiff study from design to insights:

1. **Design Generation** - Creates statistically optimal experimental designs
2. **Survey Integration** - Works with any survey platform
3. **Advanced Analytics** - Multiple scoring methods including Hierarchical Bayes
4. **Actionable Insights** - Publication-ready charts and segmentation analysis

### Key Advantages

#### 1. No Programming Required
- **Excel-based configuration** - Set up your entire study in a familiar interface
- **Point-and-click interface** - Launch from Turas GUI with a single click
- **Automated workflow** - From design to results with minimal manual intervention

#### 2. Statistically Rigorous
- **Balanced designs** - Ensures all items and pairs are tested equally
- **Multiple estimation methods** - Count-based, logit, and Hierarchical Bayes
- **Individual-level utilities** - Understand preference heterogeneity
- **Robust validation** - Comprehensive quality checks throughout

#### 3. Flexible and Scalable
- **Any study size** - From 10 to 100+ items
- **Segment analysis** - Compare preferences across demographic or behavioral groups
- **Weighted analysis** - Incorporate sample weights for representative results
- **Version management** - Support for multiple design versions

#### 4. Client-Ready Deliverables
- **Publication-quality charts** - Bar charts, diverging charts, segment comparisons
- **Excel output** - Comprehensive results workbooks ready for presentation
- **Clear interpretation** - Rescaled utilities (0-100) for easy communication
- **Diagnostic reporting** - Model fit statistics and quality metrics

---

## What Can MaxDiff Tell You?

### Business Applications

| Industry | Use Case | Questions Answered |
|----------|----------|-------------------|
| **Banking** | Product features | Which banking features drive account selection? |
| **Retail** | Brand attributes | What brand characteristics influence purchase decisions? |
| **Technology** | Product roadmap | Which features should we prioritize in development? |
| **Healthcare** | Service priorities | What service improvements matter most to patients? |
| **Travel** | Destination attributes | Which travel features drive booking decisions? |
| **FMCG** | Pack design elements | What packaging elements attract consumers? |

### Common Research Questions

- What product features drive purchase decisions?
- How do preferences differ between customer segments?
- Which brand attributes create competitive advantage?
- What messaging themes resonate most with our audience?
- How should we prioritize our product roadmap?
- Which service improvements deliver the most value?

---

## How It Works

### Three Simple Steps

#### Step 1: Design Your Study (DESIGN Mode)

Define your items in Excel and let Turas generate an optimal experimental design:

```
Input:
- 15 product features
- 4 features per task
- 12 tasks per respondent

Output:
- Statistically balanced design
- Ready for survey programming
- Quality metrics and diagnostics
```

#### Step 2: Field Your Survey

Program your survey using the design file:
- Works with any survey platform (Qualtrics, Decipher, Confirmit, etc.)
- Simple question format (radio buttons for Best/Worst)
- Mobile-friendly and respondent-tested

#### Step 3: Analyze Results (ANALYSIS Mode)

Upload your survey data and receive comprehensive analysis:

```
Input:
- Survey response data
- Original design file

Output:
- Preference scores for each item
- Segment comparisons
- Individual-level utilities
- Publication-ready charts
```

---

## Scoring Methods Explained

### 1. Count-Based Scores (Descriptive)

Simple, intuitive metrics perfect for initial exploration:

- **Best%** - Percentage of times chosen as best when shown
- **Worst%** - Percentage of times chosen as worst when shown
- **Net Score** - Best% minus Worst% (ranges from -100 to +100)

**When to use:** Quick insights, client presentations, hypothesis testing

### 2. Aggregate Logit (Advanced)

Conditional logit model providing interval-scale utilities:

- Controls for design effects
- Produces ratio-scale scores
- Includes significance testing
- Industry-standard approach

**When to use:** Academic research, competitive analysis, pricing studies

### 3. Hierarchical Bayes (Premium)

Individual-level preference utilities via Bayesian estimation:

- Every respondent gets a preference profile
- Enables advanced segmentation
- Better for small samples
- Most precise estimates

**When to use:** Customer segmentation, personalization, CRM applications

---

## Competitive Advantages

### vs. Sawtooth Software

| Feature | Turas MaxDiff | Sawtooth |
|---------|--------------|----------|
| **Licensing** | Included in Turas | Separate license required |
| **Platform** | Open source R | Proprietary |
| **HB Method** | Modern Stan (cmdstanr) | Traditional methods |
| **Integration** | Works with any survey platform | Sawtooth surveys preferred |
| **Customization** | Full source code access | Limited customization |
| **Cost** | Included | $1,495+ per year |

### vs. Qualtrics MaxDiff

| Feature | Turas MaxDiff | Qualtrics |
|---------|--------------|-----------|
| **Flexibility** | Complete control over design | Limited design options |
| **Analysis** | All methods (counts, logit, HB) | Basic counts only |
| **Segments** | Unlimited custom segments | Basic segmentation |
| **Output** | Full data + charts + Excel | Summary reports only |
| **Data ownership** | Complete access to all data | Platform-dependent |
| **Advanced features** | Individual utilities, custom models | Limited options |

### vs. Manual Analysis

| Aspect | Turas MaxDiff | Manual/Spreadsheet |
|--------|--------------|-------------------|
| **Design generation** | Automated optimal designs | Manual creation prone to errors |
| **Analysis time** | Minutes | Hours or days |
| **Statistical rigor** | Multiple validated methods | Basic counts only |
| **Reproducibility** | Fully automated and logged | Difficult to reproduce |
| **Quality checks** | Comprehensive validation | Manual checking |
| **Scalability** | Handles any study size | Becomes unwieldy at scale |

---

## Study Design Recommendations

### Optimal Study Parameters

| Item Count | Items per Task | Tasks per Respondent | Minimum Sample |
|------------|----------------|----------------------|----------------|
| 6-10 items | 4 | 8-12 | 150 |
| 11-15 items | 4-5 | 12-15 | 200 |
| 16-25 items | 5 | 15-20 | 300 |
| 26-40 items | 5-6 | 20-25 | 400 |

### Best Practices

**Item Selection:**
- Test 10-20 items for most studies
- All items should be conceptually similar (features, benefits, attributes)
- Avoid items that are universally desired or rejected
- Pre-test items qualitatively when possible

**Survey Design:**
- Keep surveys to 15 minutes or less
- 12-15 tasks is the sweet spot for most studies
- Randomize task and item order
- Include attention checks for online panels

**Sample Size:**
- Minimum 200 respondents for stable estimates
- Add 50-100 per segment for segment analysis
- Larger samples enable more granular segmentation

---

## Deliverables

### Standard Analysis Package

1. **Results Workbook** (Excel)
   - Summary tab with key findings
   - Item scores with all metrics
   - Segment comparisons
   - Model diagnostics

2. **Visualization Suite** (PNG/PDF)
   - Preference utility bar chart
   - Best-worst diverging chart
   - Segment comparison charts
   - Distribution plots (if HB)

3. **Technical Documentation**
   - Methodology summary
   - Sample composition
   - Quality metrics
   - Model fit statistics

### Optional Add-Ons

- **Individual-level utilities** - Preference profile for each respondent
- **Custom segmentation** - Advanced clustering based on preferences
- **Simulation tools** - What-if scenario analysis
- **Integration support** - Link to CRM or marketing platforms

---

## Case Study Example

### Background
A retail bank wanted to understand which account features drive customer acquisition.

### Study Design
- 18 account features tested
- 5 features per task, 15 tasks per respondent
- N=600 respondents, quota sampled
- 3 key segments: Age groups, Account type, Digital usage

### Key Findings

**Top 5 Features (Overall):**
1. Low monthly fees (Utility: 100)
2. High interest rates on savings (Utility: 87)
3. Mobile app quality (Utility: 72)
4. 24/7 customer service (Utility: 65)
5. ATM network size (Utility: 58)

**Segment Insights:**
- Young customers (18-34) prioritized mobile app and digital features
- Older customers (55+) valued branch access and personal service
- High-balance customers were less price-sensitive

### Business Impact
- Product team prioritized mobile app improvements
- Marketing messaging tailored by segment
- Fee structure revised based on preference data
- 23% increase in account openings after implementing changes

---

## Getting Started

### Quick Start Checklist

- [ ] Define research objectives
- [ ] Identify items/attributes to test (aim for 10-20)
- [ ] Determine target sample size and segments
- [ ] Create configuration file using Excel template
- [ ] Generate design and program survey
- [ ] Field survey and collect responses
- [ ] Run Turas MaxDiff analysis
- [ ] Review results and create presentation

### Required Resources

**Time:**
- Design setup: 2-4 hours
- Survey programming: 4-8 hours
- Fielding: Varies by sample
- Analysis: 1-2 hours
- Reporting: 4-8 hours

**Budget:**
- Turas MaxDiff: Included in Turas license
- Survey platform: Varies (or use free tools)
- Sample/panel: Varies by provider and sample size

**Skills:**
- Basic Excel skills for configuration
- Survey programming (or partner with vendor)
- R installation (guided installation available)

### Support and Training

- **Documentation** - Comprehensive user manual and examples
- **Templates** - Excel templates for quick setup
- **Example workflows** - Step-by-step guides
- **Technical support** - Contact Turas development team

---

## Frequently Asked Questions

**Q: How does MaxDiff compare to rating scales?**
A: MaxDiff forces trade-offs and produces more discriminating results. Rating scales often suffer from response bias and lack of differentiation.

**Q: Can I use MaxDiff for brand tracking?**
A: Yes! MaxDiff is excellent for measuring brand attribute importance over time. Use consistent items and designs for tracking studies.

**Q: What sample size do I need?**
A: Minimum 200 respondents for stable overall estimates. Add 50-100 per segment for meaningful segment comparisons.

**Q: Can I test more than 20 items?**
A: Yes! Turas MaxDiff can handle 40+ items, though this requires more tasks per respondent and larger samples.

**Q: Do I need to know R programming?**
A: No! The Excel-based configuration and Turas GUI make it accessible to non-programmers. R is only needed for installation.

**Q: How long does analysis take?**
A: Basic analysis (counts, logit): 1-5 minutes. Hierarchical Bayes: 10-30 minutes depending on sample size and items.

**Q: Can I customize the charts?**
A: Yes! Turas generates high-quality PNG files that can be edited. Advanced users can modify the chart generation code.

**Q: What survey platforms are supported?**
A: Any platform that can export data to Excel/CSV. We've tested with Qualtrics, Decipher, Confirmit, SurveyMonkey, and others.

---

## Next Steps

Ready to harness the power of MaxDiff for your research?

1. **Review the [User Manual](USER_MANUAL.md)** for detailed instructions
2. **Check [Example Workflows](EXAMPLE_WORKFLOWS.md)** for practical guidance
3. **Download the Excel template** to start configuring your study
4. **Contact our team** for consultation and support

---

*Turas MaxDiff - Powerful preference research, simplified.*
