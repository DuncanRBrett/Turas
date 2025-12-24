# Turas Conjoint Analysis Module

**Version:** 2.1.0 (Alchemer Integration)
**Last Updated:** December 2025
**Status:** Production Ready

---

## Overview

The Turas Conjoint Module performs Choice-Based Conjoint (CBC) analysis to estimate consumer preferences for product attributes. It calculates part-worth utilities and attribute importance scores to guide product development, pricing, and positioning decisions.

---

## Quick Start

### 1. Launch from Turas Suite

```r
setwd("/path/to/Turas")
source("launch_turas.R")
# Click "Launch Conjoint" button
```

### 2. Run from Command Line

```r
setwd("/path/to/Turas/modules/conjoint")
source("R/00_main.R")

run_conjoint_analysis(
  config_file = "path/to/your_config.xlsx",
  verbose = TRUE
)
```

---

## Key Capabilities

| Feature | Description |
|---------|-------------|
| **Choice-Based Conjoint** | Multinomial logit modeling of discrete choices |
| **Part-Worth Utilities** | Estimated utility for each attribute level |
| **Attribute Importance** | Relative importance percentages |
| **Market Simulator** | Interactive Excel tool for what-if scenarios |
| **Alchemer Integration** | Direct import of Alchemer CBC exports |
| **None Option** | Support for "None of these" alternatives |
| **Confidence Intervals** | Delta method CIs for utilities |

---

## Documentation Pack

| Document | Purpose | Audience |
|----------|---------|----------|
| **[README.md](README.md)** | Quick start guide | Everyone |
| **[MARKETING.md](MARKETING.md)** | Module capabilities for clients | Clients, Sales |
| **[AUTHORITATIVE_GUIDE.md](AUTHORITATIVE_GUIDE.md)** | Deep technical reference | Analysts, Researchers |
| **[USER_MANUAL.md](USER_MANUAL.md)** | Complete setup and usage guide | End Users |
| **[TECHNICAL_DOCS.md](TECHNICAL_DOCS.md)** | Developer documentation | Developers |
| **[EXAMPLE_WORKFLOWS.md](EXAMPLE_WORKFLOWS.md)** | Common use cases and examples | Everyone |
| **Conjoint_Config_Template.xlsx** | Configuration template | End Users |

---

## Requirements

### Software
- R 4.0+ (R 4.2+ recommended)
- RStudio (optional but recommended)

### R Packages

```r
# Required
install.packages(c("readxl", "openxlsx", "mlogit", "survival"))

# Optional
install.packages(c("dfidx", "dplyr"))
```

---

## Configuration Overview

Create an Excel workbook with these sheets:

| Sheet | Required | Purpose |
|-------|----------|---------|
| **Instructions** | No | Documentation (not read by code) |
| **Settings** | Yes | Analysis parameters, file paths |
| **Attributes** | Yes | Product attributes and levels |

See **[USER_MANUAL.md](USER_MANUAL.md)** for detailed configuration.

---

## Data Requirements

Your conjoint data file must contain:

| Column | Purpose |
|--------|---------|
| resp_id | Respondent identifier |
| choice_set_id | Choice task identifier |
| alternative_id | Alternative within choice set |
| [Attributes] | One column per product attribute |
| chosen | Binary indicator (1 = chosen, 0 = not) |

**Critical:** Each choice set must have exactly ONE chosen=1.

---

## Output

The module generates an Excel workbook with:

1. **Utilities** - Part-worth utilities for each level
2. **Relative_Importance** - Attribute importance percentages
3. **Market_Simulator** - Interactive dropdown tool
4. **Model_Summary** - Fit statistics and diagnostics
5. **Confidence_Intervals** - CIs for utilities
6. **README** - Interpretation guide

---

## Analysis Types

| Type | Status | Description |
|------|--------|-------------|
| **Choice-Based (CBC)** | Production | Standard discrete choice modeling |
| **CBC with None** | Production | Includes "None of these" option |
| **Best-Worst Scaling** | Beta | Maximum difference scaling |
| **Rating-Based** | Planned | Regression on profile ratings |

---

## Version History

### v2.1.0 (December 2025)
- Alchemer CBC direct import
- Automatic level name cleaning
- Enhanced validation

### v2.0.0 (November 2025)
- Multi-respondent data support
- Hit rate calculation fixes
- Market simulator improvements

### v1.0.0 (October 2025)
- Initial release
- CBC with mlogit/clogit estimation
- Part-worth utilities and importance

---

## Support

For questions or issues:
1. Check **[USER_MANUAL.md](USER_MANUAL.md)** troubleshooting section
2. Review Model_Summary sheet in output
3. Contact Turas development team

---

**Module Status:** Production Ready
**Maintainer:** Turas Development Team
