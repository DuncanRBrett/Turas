---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tracker - Module Overview

**Version:** 10.0 **Last Updated:** 22 December 2025

------------------------------------------------------------------------

## What is Turas Tracker?

Turas Tracker is a comprehensive R-based system for analyzing multi-wave
tracking studies. It transforms raw survey data from multiple time
periods into actionable trend insights with statistical rigor.

**Core Purpose:** Compare metrics across survey waves, calculate
statistical significance of changes, and generate professional reports
for tracking study analysis.

------------------------------------------------------------------------

## Key Capabilities

### Time Series Analysis

-   Track any metric across 2 or more waves
-   Automatic trend direction detection (up, down, stable)
-   Support for irregular wave intervals

### Statistical Rigor

-   Two-proportion Z-tests for percentage changes
-   Welch's T-tests for mean comparisons
-   Design effect (DEFF) adjustment for weighted data
-   Configurable confidence levels (default 95%)

### Flexible Question Handling

-   Map questions when codes change between waves
-   Support for multiple question types:
    -   **Rating** - Numeric scales (1-5, 1-10, etc.)
    -   **NPS** - Net Promoter Score (0-10)
    -   **Single Choice** - Categorical single response
    -   **Multi-Mention** - Select all that apply
    -   **Composite** - Derived from multiple questions

### Custom Metrics via TrackingSpecs

-   Track mean, top box, top 2 box, custom ranges
-   Specify different metrics per question
-   Auto-detect multi-mention options

### Banner Analysis

-   Analyze trends by demographic segments
-   Gender, age, region, or any categorical variable
-   Segment-level significance testing

### Multiple Report Formats

-   **Detailed** - One sheet per question, full statistics
-   **Wave History** - Compact executive summary
-   **Dashboard** - Trend status with indicators
-   **Sig Matrix** - All wave-pair comparisons

------------------------------------------------------------------------

## When to Use Turas Tracker

**Use Tracker when you have:** - Survey data from multiple time periods
(waves) - Need to identify significant changes over time - Questions
tracked consistently (or with mapping) - Weighted or unweighted data

**Typical Use Cases:** - Brand health tracking (awareness,
consideration, purchase) - Customer satisfaction monitoring - NPS trend
analysis - Employee engagement surveys - Market research tracking
studies

------------------------------------------------------------------------

## How It Works

```         
┌─────────────────────────────────────────────────────────────┐
│                    TURAS TRACKER                            │
│                                                             │
│  Configuration    Question      Wave Data                   │
│  (xlsx)           Mapping       (csv/xlsx/sav)              │
│      │            (xlsx)             │                      │
│      └──────────────┬────────────────┘                      │
│                     ▼                                       │
│            ┌────────────────┐                               │
│            │   Validation   │  Check all inputs             │
│            └────────────────┘                               │
│                     │                                       │
│                     ▼                                       │
│            ┌────────────────┐                               │
│            │  Trend Calc    │  Calculate metrics per wave   │
│            └────────────────┘  Statistical testing          │
│                     │                                       │
│                     ▼                                       │
│            ┌────────────────┐                               │
│            │ Report Output  │  Excel workbooks              │
│            └────────────────┘                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

------------------------------------------------------------------------

## Output Examples

### Trend Summary

```         
Question          | W1    | W2    | W3    | Trend
──────────────────|───────|───────|───────|───────
Brand Awareness   | 45%   | 48%   | 52%   | ↑↑
Consideration     | 32%   | 31%   | 33%   | →
Satisfaction      | 3.8   | 3.9   | 4.1   | ↑
NPS               | +32   | +35   | +38   | ↑
```

### Significance Indicators

| Symbol | Meaning                                        |
|--------|------------------------------------------------|
| ↑      | Statistically significant increase (p \< 0.05) |
| ↓      | Statistically significant decrease (p \< 0.05) |
| →      | No significant change                          |

------------------------------------------------------------------------

## Getting Started

1.  **Prepare your wave data** - One file per wave with consistent
    structure
2.  **Create configuration** - Use templates in `docs/templates/`
3.  **Run analysis** - Via GUI or script
4.  **Review output** - Excel workbooks with trends and significance

See [04_USER_MANUAL.md](04_USER_MANUAL.md) for detailed instructions.

------------------------------------------------------------------------

## Comparison with Other Modules

| Feature    | Turas Tabs                     | Turas Tracker      |
|------------|--------------------------------|--------------------|
| Purpose    | Cross-tabulation               | Time-series trends |
| Input      | Single survey                  | Multiple waves     |
| Output     | Frequency tables               | Trend tables       |
| Statistics | Chi-square, column proportions | Z-tests, T-tests   |
| Banner     | Demographic columns            | Demographic + wave |

------------------------------------------------------------------------

## Version History

| Version | Date     | Key Features                                       |
|---------|----------|----------------------------------------------------|
| 1.0     | Nov 2025 | Initial release with basic tracking                |
| 2.0     | Nov 2025 | TrackingSpecs, Wave History reports                |
| 2.1     | Dec 2025 | Multi-Mention category mode, bug fixes             |
| 2.2     | Dec 2025 | Dashboard reports, significance matrices           |
| 10.0    | Dec 2025 | Module reorganization, documentation consolidation |

------------------------------------------------------------------------

## Support

-   **User Manual:** [04_USER_MANUAL.md](04_USER_MANUAL.md)
-   **Technical Docs:** [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md)
-   **Examples:** [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md)
