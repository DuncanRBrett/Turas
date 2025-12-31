# TURAS Analytics Platform - Client Pack Index

**The Research LampPost (Pty) Ltd**
**Date:** December 2024
**Version:** 1.0

---

## About This Client Pack

This collection of documents explains each analytical module in the TURAS platform in plain, accessible language. Each brief is designed for research professionals who need to understand what the modules do, how they work, and when to use them—without requiring deep statistical expertise.

**Target Audience:** Research directors, client services teams, project managers, and business stakeholders who commission or interpret market research.

---

## Module Overview

TURAS provides 11 specialized analytical modules covering the full spectrum of market research needs:

| # | Module | Purpose | Page |
|---|--------|---------|------|
| 1 | **AlchemerParser** | Automated survey setup from Alchemer exports | [Link](01_AlchemerParser_Client_Brief.md) |
| 2 | **Tabs** | Cross-tabulation & significance testing | [Link](02_Tabs_Client_Brief.md) |
| 3 | **Confidence** | Confidence interval calculations & margins of error | [Link](03_Confidence_Client_Brief.md) |
| 4 | **KeyDriver** | Correlation-based driver analysis | [Link](04_KeyDriver_Client_Brief.md) |
| 5 | **CatDriver** | Categorical driver analysis (regression + SHAP) | [Link](05_CatDriver_Client_Brief.md) |
| 6 | **Conjoint** | Choice-based conjoint analysis | [Link](06_Conjoint_Client_Brief.md) |
| 7 | **MaxDiff** | Maximum difference scaling for preferences | [Link](07_MaxDiff_Client_Brief.md) |
| 8 | **Pricing** | Price sensitivity & optimization | [Link](08_Pricing_Client_Brief.md) |
| 9 | **Segment** | Customer segmentation & clustering | [Link](09_Segment_Client_Brief.md) |
| 10 | **Tracker** | Longitudinal tracking & trend analysis | [Link](10_Tracker_Client_Brief.md) |
| 11 | **Weighting** | Sample balancing & rim weighting | [Link](11_Weighting_Client_Brief.md) |

---

## How to Use These Briefs

Each 1-page brief follows a consistent structure:

### Standard Sections
1. **What This Module Does** - One-sentence summary
2. **What Problem Does It Solve?** - Business context
3. **How It Works** - High-level methodology
4. **What You Get** - Outputs and deliverables
5. **Technology Used** - R packages and why they were chosen
6. **Strengths** - What the module does well
7. **Limitations** - When not to use it
8. **Statistical Concepts Explained** - Plain English explanations
9. **Best Use Cases** - Ideal applications
10. **Quality & Reliability** - Production readiness assessment
11. **Example Outputs** - Real-world sample results
12. **What's Next** - Future enhancements roadmap
13. **Bottom Line** - One-paragraph executive summary

### Finding the Right Module

**By Research Objective:**
- **Survey Analysis Basics:** Tabs, Confidence, Weighting
- **Understanding Drivers:** KeyDriver, CatDriver
- **Product Optimization:** Conjoint, MaxDiff, Pricing
- **Customer Understanding:** Segment
- **Performance Monitoring:** Tracker
- **Workflow Efficiency:** AlchemerParser

**By Data Type:**
- **Categorical outcomes:** Tabs, CatDriver
- **Continuous outcomes:** KeyDriver
- **Time-series data:** Tracker
- **Choice data:** Conjoint, MaxDiff
- **Price data:** Pricing

**By Analysis Complexity:**
- **Simple (accessible to all):** Tabs, Confidence, Weighting
- **Moderate (some stats knowledge helpful):** KeyDriver, Segment, Tracker
- **Advanced (sophisticated methods):** CatDriver, Conjoint, MaxDiff, Pricing

---

## Quality Ratings Summary

All modules are production-ready with the following quality scores:

| Module | Quality Score | Status | Test Coverage |
|--------|--------------|--------|---------------|
| KeyDriver | 93/100 | ✅ Production | High |
| CatDriver | 92/100 | ✅ Production | High |
| Conjoint | 91/100 | ✅ Production | High |
| AlchemerParser | 90/100 | ✅ Production | Medium |
| Confidence | 90/100 | ✅ Production | High |
| MaxDiff | 90/100 | ✅ Production | High |
| Pricing | 90/100 | ✅ Production | Medium |
| Tabs | 85/100 | ✅ Production | Medium |
| Tracker | 85/100 | ✅ Production | Medium |
| Segment | 85/100 | ✅ Production | Medium |
| Weighting | 85/100 | ✅ Production | Medium |

**Overall Platform Quality:** 85/100 (High)

---

## Technology Philosophy

### Why R?
- Industry-standard for statistical computing
- Extensive package ecosystem for research methods
- Reproducible, auditable analysis
- Strong academic and commercial support

### Package Selection Criteria
All R packages used in TURAS meet these standards:
- ✅ Actively maintained (updates within 12 months)
- ✅ Published on CRAN (official R repository)
- ✅ Peer-reviewed methodology
- ✅ Cross-platform compatibility (Windows, Mac, Linux)
- ✅ No commercial licensing requirements

### Statistical Rigor
- Industry-standard methods (not experimental)
- Peer-reviewed algorithms
- Published validation studies
- Transparent assumptions and limitations

---

## Common Use Cases

### 1. Brand Health Tracking Study
**Modules Used:**
- **Tracker:** Monitor brand metrics over time
- **Tabs:** Cross-tabs by demographics
- **KeyDriver:** Identify what drives brand consideration
- **Weighting:** Ensure national representativeness

### 2. Product Development & Pricing
**Modules Used:**
- **Conjoint:** Understand feature trade-offs
- **Pricing:** Optimize price point
- **MaxDiff:** Prioritize features to develop
- **Segment:** Identify different customer need states

### 3. Customer Satisfaction Analysis
**Modules Used:**
- **Tabs:** Satisfaction by customer segment
- **CatDriver:** Drivers of satisfaction categories
- **Confidence:** Report margins of error
- **Weighting:** Balance sample to customer base

### 4. Market Entry Decision
**Modules Used:**
- **Segment:** Identify customer opportunity spaces
- **Conjoint:** Simulate market share for product concepts
- **Pricing:** Find optimal launch price
- **Tabs:** Size of target segments

### 5. Ad Campaign Effectiveness
**Modules Used:**
- **Tabs:** Pre/post awareness and perception shifts
- **Tracker:** Monitor metrics during campaign
- **Confidence:** Validate lift is statistically significant
- **Segment:** Identify most responsive audiences

---

## Understanding Output Quality

### What "Production Ready" Means
All modules marked "Production Ready" have:
- ✅ Comprehensive error handling (won't crash on bad data)
- ✅ Validation of inputs (catches data problems early)
- ✅ Clear error messages (tells you how to fix issues)
- ✅ Tested with real-world data
- ✅ Excel-based outputs ready for client delivery

### Interpreting Quality Scores

**90-100:** Exceptional
- Comprehensive testing
- Advanced statistical methods
- Robust error handling
- Well-documented

**85-89:** Very Good
- Core functionality solid
- Good error handling
- Expanding test coverage
- Clear documentation

**80-84:** Good
- Reliable for standard use cases
- Basic error handling
- Documentation adequate
- Some edge cases need testing

---

## Technical Support

### Getting Help
For questions about:
- **Which module to use:** Review the "Best Use Cases" section in each brief
- **How to interpret outputs:** See "Example Outputs" sections
- **Statistical methodology:** Check "Statistical Concepts Explained" sections
- **Implementation support:** Contact The Research LampPost

### Training & Onboarding
Available training:
- Module-specific workshops (2 hours each)
- Full platform training (2 days)
- Custom training for your specific use cases
- Ongoing support retainers

---

## Roadmap & Future Development

### Short-Term (Q1-Q2 2025)
- Enhanced automation for all modules
- Expanded test coverage to 90%+
- Additional output format options (PowerPoint, dashboards)
- More example datasets and templates

### Medium-Term (Q3-Q4 2025)
- Interactive dashboards integrated with modules
- API access for programmatic analysis
- Real-time analysis for selected modules
- Advanced visualization options

### Long-Term (2026+)
- Machine learning integration
- Cloud-based analysis platform
- Collaboration features
- Enterprise integrations (CRM, BI tools)

---

## About The Research LampPost

The Research LampPost (Pty) Ltd specializes in advanced market research analytics. TURAS represents our commitment to:
- **Quality:** No compromises on statistical rigor
- **Transparency:** Clear explanations of methods and limitations
- **Practicality:** Tools that solve real business problems
- **Innovation:** Cutting-edge methods made accessible

---

## Document Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 2024 | Initial client pack release (11 modules) |

---

## Quick Reference: When to Use Which Module

```
START HERE
│
├─ Need to SET UP a survey?
│  └─ AlchemerParser
│
├─ Need to ANALYZE survey results?
│  │
│  ├─ Basic cross-tabs & demographics?
│  │  └─ Tabs + Confidence + Weighting
│  │
│  ├─ Track over time?
│  │  └─ Tracker
│  │
│  ├─ Understand what drives outcomes?
│  │  ├─ Continuous outcome (ratings)? → KeyDriver
│  │  └─ Categorical outcome (segments)? → CatDriver
│  │
│  ├─ Optimize product features?
│  │  ├─ Trade-off between features? → Conjoint
│  │  ├─ Prioritize features? → MaxDiff
│  │  └─ Find optimal price? → Pricing
│  │
│  └─ Identify customer segments?
│     └─ Segment
```

---

**For additional information or support, contact:**
The Research LampPost (Pty) Ltd
Email: info@researchlamppost.com
Web: www.researchlamppost.com

---

*Last Updated: December 2024*
