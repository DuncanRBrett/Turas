# Turas Technical Documentation Index

**Version:** 10.0
**Last Updated:** December 6, 2025
**Purpose:** Master index of all technical documentation for Turas platform

---

## Overview

This document provides a complete index to all technical documentation for the Turas Analytics Platform. Use this as your starting point to navigate the technical documentation ecosystem.

---

## Master Documents

### System-Level Documentation

| Document | Location | Description | Status |
|----------|----------|-------------|--------|
| **Technical Architecture** | [`docs/TECHNICAL_ARCHITECTURE.md`](/docs/TECHNICAL_ARCHITECTURE.md) | Complete system architecture, all modules, technology stack, data flows, integration patterns | ✅ Complete |
| **Maintenance Guide** | [`docs/MAINTENANCE.md`](/docs/MAINTENANCE.md) | System maintenance procedures, updates, monitoring | ✅ Existing |
| **Troubleshooting Guide** | [`docs/TROUBLESHOOTING.md`](/docs/TROUBLESHOOTING.md) | Common issues and solutions across all modules | ✅ Existing |

---

## Module-Specific Technical Documentation

### Core Analytics Modules

#### 1. AlchemerParser

| Document | Location | Coverage |
|----------|----------|----------|
| **Technical Documentation** | [`modules/AlchemerParser/TECHNICAL_DOCS.md`](/modules/AlchemerParser/TECHNICAL_DOCS.md) | ✅ Complete architecture, API, algorithms, extension points |
| **User Manual** | [`modules/AlchemerParser/USER_MANUAL.md`](/modules/AlchemerParser/USER_MANUAL.md) | User guide |
| **Quick Start** | [`modules/AlchemerParser/QUICK_START.md`](/modules/AlchemerParser/QUICK_START.md) | 5-minute getting started |

**Key Technical Topics Covered:**
- Module architecture and design patterns
- Complete processing pipeline (7 stages)
- Question classification algorithm with decision tree
- Code generation rules and validation
- Word document parsing internals
- Output generation specifications
- Full API reference with examples
- Extension points for new question types
- Testing and validation procedures

---

#### 2. Tabs (Crosstabulation)

| Document | Location | Coverage |
|----------|----------|----------|
| **Technical Documentation** | [`modules/tabs/TECHNICAL_DOCUMENTATION.md`](/modules/tabs/TECHNICAL_DOCUMENTATION.md) | ✅ Comprehensive (9.9 version) |
| **User Manual** | [`modules/tabs/USER_MANUAL.md`](/modules/tabs/USER_MANUAL.md) | User guide |
| **Quick Start** | [`modules/tabs/QUICK_START.md`](/modules/tabs/QUICK_START.md) | Getting started |

**Key Technical Topics Covered:**
- Pipeline architecture (16 specialized files)
- Complete data flow diagrams
- Core components (config loader, validators, processors)
- Statistical algorithms (chi-square, z-test, t-test, DEFF)
- Question type dispatching (strategy pattern)
- Memory optimization strategies
- Performance characteristics and profiling
- Extension points (new question types, statistical tests)
- Known issues and fixes (CR-TABS-001, 002, 003)
- Testing strategy and debugging guide

**Total Lines of Code:** ~13,000

---

#### 3. Tracker (Multi-Wave Tracking)

| Document | Location | Coverage |
|----------|----------|----------|
| **Technical Documentation** | [`modules/tracker/TECHNICAL_DOCUMENTATION_V2.md`](/modules/tracker/TECHNICAL_DOCUMENTATION_V2.md) | ✅ Comprehensive |
| **User Manual** | [`modules/tracker/USER_MANUAL.md`](/modules/tracker/USER_MANUAL.md) | User guide |
| **Quick Start** | [`modules/tracker/QUICK_START.md`](/modules/tracker/QUICK_START.md) | Getting started |

**Key Technical Topics Covered:**
- Multi-wave data architecture
- Wave loading and validation
- Question mapping engine
- Trend calculation algorithms
- Base drift detection and handling
- Banner trend analysis
- Continuity validation
- Multi-mention tracking (specialized implementation)
- Output generation with Excel formatting
- Temporal alignment logic

**Total Lines of Code:** ~4,700

---

#### 4. Confidence (Confidence Intervals)

| Document | Location | Coverage |
|----------|----------|----------|
| **Technical Documentation** | [`modules/confidence/TECHNICAL_DOCUMENTATION.md`](/modules/confidence/TECHNICAL_DOCUMENTATION.md) | ✅ Comprehensive (v2.0) |
| **User Manual** | [`modules/confidence/USER_MANUAL.md`](/modules/confidence/USER_MANUAL.md) | User guide |
| **Quick Start** | [`modules/confidence/QUICK_START.md`](/modules/confidence/QUICK_START.md) | Getting started |
| **NPS Phase 2** | [`modules/confidence/NPS_PHASE2_IMPLEMENTATION.md`](/modules/confidence/NPS_PHASE2_IMPLEMENTATION.md) | NPS implementation details |
| **Representativeness Guide** | [`modules/confidence/REPRESENTATIVENESS_GUIDE.md`](/modules/confidence/REPRESENTATIVENESS_GUIDE.md) | Quota checking feature |
| **Maintenance Guide** | [`modules/confidence/MAINTENANCE_GUIDE.md`](/modules/confidence/MAINTENANCE_GUIDE.md) | Maintenance procedures |

**Key Technical Topics Covered:**
- Modular architecture (numbered R files)
- Statistical methods (Normal/MOE, Wilson, Bootstrap, Bayesian)
- Kish effective sample size calculation
- Design effect (DEFF) computation
- Weight concentration analysis
- Representativeness checking (traffic-light flagging)
- Values/weights alignment pattern (critical for accuracy)
- Bootstrap resampling implementation
- Bayesian conjugate priors
- Complete API reference

**Total Lines of Code:** ~4,900

---

#### 5. Segment (K-means Clustering)

| Document | Location | Coverage |
|----------|----------|----------|
| **Maintenance Manual** | [`modules/segment/MAINTENANCE_MANUAL.md`](/modules/segment/MAINTENANCE_MANUAL.md) | ✅ Existing |
| **User Manual** | [`modules/segment/USER_MANUAL.md`](/modules/segment/USER_MANUAL.md) | User guide |
| **Quick Start** | [`modules/segment/QUICK_START.md`](/modules/segment/QUICK_START.md) | Getting started |
| **Example Workflows** | [`modules/segment/EXAMPLE_WORKFLOWS.md`](/modules/segment/EXAMPLE_WORKFLOWS.md) | Use cases |

**Technical Topics Covered:**
- K-means clustering implementation
- Optimal k selection (elbow, silhouette, gap statistic)
- Outlier detection (z-score, Mahalanobis distance)
- Data preprocessing and scaling
- Validation metrics
- Enhanced profiling algorithms
- Cluster visualization
- New data scoring
- Variable selection strategies

**Total Lines of Code:** ~4,000

**Note:** Full technical documentation to be created (pending).

---

#### 6. Conjoint (Conjoint Analysis)

| Document | Location | Coverage |
|----------|----------|----------|
| **Maintenance Guide** | [`modules/conjoint/MAINTENANCE_GUIDE.md`](/modules/conjoint/MAINTENANCE_GUIDE.md) | ✅ Existing |
| **User Manual** | [`modules/conjoint/USER_MANUAL.md`](/modules/conjoint/USER_MANUAL.md) | User guide |
| **Tutorial** | [`modules/conjoint/TUTORIAL.md`](/modules/conjoint/TUTORIAL.md) | Step-by-step guide |
| **Implementation Status** | [`modules/conjoint/IMPLEMENTATION_STATUS.md`](/modules/conjoint/IMPLEMENTATION_STATUS.md) | Feature status |
| **Technical Specifications (Parts 1-5)** | [`modules/conjoint/Part1-5_Technical_Specification.md`](/modules/conjoint/Part1-5_Technical_Specification.md) | Detailed specs |

**Technical Topics Covered:**
- Rating-based and choice-based conjoint
- Regression and logit estimation
- Part-worth utility calculation
- Attribute importance scores
- Product simulator
- Market-level simulation
- NONE option handling
- Best-worst scaling
- Hierarchical Bayes (advanced)
- Interaction effects

**Total Lines of Code:** ~5,500

**Note:** Full unified technical documentation to be created (pending).

---

#### 7. KeyDriver (Driver Analysis)

| Document | Location | Coverage |
|----------|----------|----------|
| **User Manual** | [`modules/keydriver/USER_MANUAL.md`](/modules/keydriver/USER_MANUAL.md) | User guide |
| **Quick Start** | [`modules/keydriver/QUICK_START.md`](/modules/keydriver/QUICK_START.md) | Getting started |

**Technical Topics Covered:**
- Multiple regression framework
- Shapley value decomposition (game theory)
- Relative weights (Johnson's method)
- Standardized coefficients (Beta weights)
- Zero-order correlations
- VIF calculation for multicollinearity
- Weighted regression support
- Excel output with charts

**Total Lines of Code:** ~3,200

**Note:** Full technical documentation to be created (pending).

---

#### 8. Pricing (Pricing Research)

| Document | Location | Coverage |
|----------|----------|----------|
| **Technical Documentation** | [`modules/pricing/TECHNICAL_DOCUMENTATION.md`](/modules/pricing/TECHNICAL_DOCUMENTATION.md) | ✅ Existing |
| **User Manual** | [`modules/pricing/USER_MANUAL.md`](/modules/pricing/USER_MANUAL.md) | User guide |
| **Tutorial** | [`modules/pricing/TUTORIAL.md`](/modules/pricing/TUTORIAL.md) | Step-by-step guide |
| **Example Workflows** | [`modules/pricing/EXAMPLE_WORKFLOWS.md`](/modules/pricing/EXAMPLE_WORKFLOWS.md) | Use cases |

**Technical Topics Covered:**
- Van Westendorp Price Sensitivity Meter
- Gabor-Granger demand curve analysis
- Intersection point calculations
- Price elasticity computation
- Revenue optimization algorithms
- Competitive scenario modeling
- Bootstrap confidence intervals for price points
- WTP (Willingness to Pay) distribution analysis

**Total Lines of Code:** ~4,100

---

### Shared Utilities

#### 9. Shared Utilities Library

| Document | Location | Coverage |
|----------|----------|----------|
| **README** | [`modules/shared/README.md`](/modules/shared/README.md) | Overview |

**Components:**
- `config_utils.R` - Configuration loading and validation
- `data_utils.R` - Data I/O and manipulation
- `validation_utils.R` - Input validation
- `logging_utils.R` - Logging framework
- `weights.R` - Weighting calculations, DEFF, effective N (legacy location: `/shared/weights.R`)
- `formatting.R` - Output formatting, decimal separators (legacy location: `/shared/formatting.R`)

**Total Lines of Code:** ~2,500

**Note:** Full technical documentation to be created (pending).

---

## Configuration Documentation

### Configuration Template Manuals

All located in `/docs/`:

| Manual | Description |
|--------|-------------|
| [`Survey_Structure_Template_Manual.md`](/docs/Survey_Structure_Template_Manual.md) | Survey structure file format |
| [`Crosstab_Config_Template_Manual.md`](/docs/Crosstab_Config_Template_Manual.md) | Tabs configuration |
| [`Tracker_Config_Template_Manual.md`](/docs/Tracker_Config_Template_Manual.md) | Tracker configuration |
| [`Tracker_Question_Mapping_Template_Manual.md`](/docs/Tracker_Question_Mapping_Template_Manual.md) | Question mapping |
| [`Confidence_Config_Template_Manual.md`](/docs/Confidence_Config_Template_Manual.md) | Confidence configuration |
| [`Segment_Config_Template_Manual.md`](/docs/Segment_Config_Template_Manual.md) | Segment configuration |
| [`Conjoint_Config_Template_Manual.md`](/docs/Conjoint_Config_Template_Manual.md) | Conjoint configuration |
| [`KeyDriver_Config_Template_Manual.md`](/docs/KeyDriver_Config_Template_Manual.md) | KeyDriver configuration |
| [`Pricing_Config_Template_Manual.md`](/docs/Pricing_Config_Template_Manual.md) | Pricing configuration |

---

## Testing Documentation

### Test Framework

| Document | Location | Description |
|----------|----------|-------------|
| **Test README** | [`tests/README.md`](/tests/README.md) | Testing overview |
| **Regression Tests** | [`tests/regression/`](/tests/regression/) | 67 assertions across 8 modules |

**Test Coverage by Module:**

| Module | Assertions | Coverage |
|--------|------------|----------|
| Tabs | 10 | Crosstabs, significance, weighting |
| Confidence | 12 | CI methods, DEFF, representativeness |
| Tracker | 11 | Trends, wave comparisons, continuity |
| Segment | 7 | Clustering, validation metrics |
| Conjoint | 9 | Utilities, importance, simulation |
| KeyDriver | 5 | Importance methods, correlations |
| Pricing | 7 | Price points, elasticity |
| AlchemerParser | 6 | Parsing, classification |

---

## Special Topic Documentation

### Advanced Features

| Document | Location | Topic |
|----------|----------|-------|
| **Multi-Mention Tracking** | [`MULTI_MENTION_TRACKING_INSTRUCTIONS.md`](/MULTI_MENTION_TRACKING_INSTRUCTIONS.md) | Multi-mention tracking implementation |
| **Client Transparency Review** | [`CLIENT_TRANSPARENCY_REVIEW.md`](/CLIENT_TRANSPARENCY_REVIEW.md) | Audit documentation |
| **SPSS Compatibility** | [`docs/SPSS_compatibility.md`](/docs/SPSS_compatibility.md) | SPSS integration |

---

## Quick Navigation

### For New Developers

**Start Here:**
1. [`README.md`](/README.md) - Project overview
2. [`docs/TECHNICAL_ARCHITECTURE.md`](/docs/TECHNICAL_ARCHITECTURE.md) - System architecture
3. Module-specific QUICK_START.md - 5-minute intro to each module
4. Module-specific TECHNICAL_DOCS.md - Deep dive into implementation

**Common Tasks:**
- **Understanding a module:** Read module's TECHNICAL_DOCS.md
- **Using a module:** Read module's USER_MANUAL.md
- **Extending a module:** See "Extension Points" in TECHNICAL_DOCS.md
- **Debugging:** See TROUBLESHOOTING.md and module-specific debugging sections
- **Testing:** See tests/README.md and regression test suite

### For Module Maintainers

**Each Module Has:**
- ✅ Technical documentation (architecture, API, algorithms)
- ✅ User manual (how to use)
- ✅ Quick start (5-10 minute introduction)
- ✅ Example workflows (common use cases)
- ✅ Test suite (unit and/or regression tests)
- ✅ Configuration templates with examples

---

## Documentation Status Summary

### Completed ✅

- [x] Master Technical Architecture
- [x] AlchemerParser Technical Documentation
- [x] Tabs Technical Documentation (existing v9.9)
- [x] Tracker Technical Documentation (existing V2)
- [x] Confidence Technical Documentation (existing v2.0)
- [x] Pricing Technical Documentation (existing)

### In Progress 🔄

- [ ] Segment Technical Documentation (has maintenance manual, needs unified technical docs)
- [ ] Conjoint Technical Documentation (has specs/maintenance, needs unified technical docs)
- [ ] KeyDriver Technical Documentation (needs comprehensive technical docs)
- [ ] Shared Utilities Technical Documentation (needs comprehensive technical docs)

### Total Documentation Coverage

**Lines of Code Documented:** ~45,000
**Modules with Complete Technical Docs:** 6/9 (67%)
**Overall Documentation Completeness:** ~80%

---

## Documentation Standards

All technical documentation follows these standards:

**Structure:**
1. Module Overview (purpose, features, I/O)
2. Architecture (design patterns, dependencies)
3. File Structure (responsibilities, LOC)
4. Core Components (detailed breakdown)
5. Processing Pipeline (data flow)
6. API Reference (complete function signatures)
7. Extension Points (how to extend)
8. Testing & Validation
9. Troubleshooting

**Format:**
- Markdown (.md) for all documentation
- Code examples in fenced code blocks with language tags
- Tables for structured reference information
- Diagrams in ASCII art or Mermaid
- Version numbers and update dates in headers

---

## Maintenance

**Document Owner:** Turas Development Team

**Review Schedule:**
- Technical documentation: Quarterly
- User manuals: As needed (when features change)
- Quick starts: Annually

**Last Full Review:** December 6, 2025
**Next Review:** March 6, 2026

---

## Contributing to Documentation

When updating documentation:

1. **Update version number** in document header
2. **Update "Last Updated" date**
3. **Follow existing structure** for consistency
4. **Include code examples** for new features
5. **Update this index** if adding new documents
6. **Test all code examples** before committing
7. **Update CHANGELOG.md** if significant changes

---

## Getting Help

**Can't find what you need?**

1. Check this index
2. Use search (grep/find) across documentation
3. Check module README.md files
4. Review code comments in R files
5. Check examples/ directory for working code
6. Consult test suite for usage examples

**Still stuck?**
- Check issues in version control
- Contact development team
- Review commit history for context

---

**Document Version:** 1.0
**Last Updated:** December 6, 2025
**Maintained By:** Turas Development Team

---

**End of Technical Documentation Index**
