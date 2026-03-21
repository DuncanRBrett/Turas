# Turas Categorical Key Driver Module

**Version:** 14.0
**Last Updated:** March 2026

Key driver analysis for categorical outcomes using logistic regression methods.

---

## Overview

The Categorical Key Driver module identifies which factors most strongly influence a categorical outcome. Unlike the standard Key Driver module (which handles continuous outcomes), this module handles categorical outcomes using appropriate logistic regression methods.

**Core Capabilities:**
- Binary logistic regression for 2-category outcomes
- Ordinal logistic regression for ordered 3+ categories
- Multinomial logistic regression for unordered 3+ categories
- Chi-square based variable importance
- Odds ratios with confidence intervals
- Probability lifts with intuitive percentage-point metrics
- Bootstrap confidence intervals (optional)
- Plain-English executive summaries
- Interactive HTML reports with SVG charts
- **Qualitative slides** — add narrative slides with markdown formatting
  and images directly within the HTML report; pin slides to Pinned Views
  for export
- **Help overlays** — contextual (?) help icons on every major report
  section explaining what each panel shows and how to interpret it
- **Subgroup comparison** — split analysis by a grouping variable
  (e.g., age, region) and compare driver importance across groups
- **Multi-config GUI** — run multiple outcome analyses and generate a
  unified tabbed report from a single panel
- **Stats pack** — diagnostic audit workbook (Declaration, Data_Used, Assumptions, Warnings, Reproducibility, Config_Echo) for advanced partners and research statisticians

---

## Use Cases

| Scenario | Outcome Type | Example |
|----------|--------------|---------|
| Customer churn | Binary | Retained vs Churned |
| Satisfaction levels | Ordinal | Low/Medium/High |
| Brand preference | Nominal | Brand A/B/C/D |
| Survey completion | Ordinal | Complete/Partial/Abandoned |
| Employee engagement | Ordinal | Disengaged/Neutral/Engaged |
| Churn by segment | Binary + Subgroup | Churned vs Retained, split by age group |

---

## Quick Start

### Using the GUI (Recommended)

```r
source("launch_turas.R")
# Click "Launch Categorical Key Driver"
```

The HTML report includes an **Add Slide** button for adding qualitative
commentary with markdown formatting and images. Pre-seed slides from
the config Excel by adding a **Slides** sheet (see User Manual Section 15).

### Using Command Line

```r
# Source module files
source("modules/catdriver/R/00_main.R")

# Run analysis
results <- run_categorical_keydriver("path/to/config.xlsx")
```

---

## Configuration

Create an Excel file with three required sheets (Settings, Variables, Driver_Settings) and one optional sheet (Slides):

### Settings Sheet

| Setting | Value |
|---------|-------|
| data_file | survey_data.csv |
| output_file | results.xlsx |
| outcome_type | ordinal |

**Note:** `outcome_type` is required. Must be `binary`, `ordinal`, or `multinomial`.

**Optional subgroup settings:**

| Setting | Value |
|---------|-------|
| subgroup_var | age_group |
| subgroup_min_n | 30 |
| subgroup_include_total | TRUE |

Set `subgroup_var` to split the analysis by a grouping variable. The variable must not be the outcome or a driver.

### Variables Sheet

| VariableName | Type | Label | Order |
|--------------|------|-------|-------|
| satisfaction | Outcome | Employment Satisfaction | Low;Neutral;High |
| grade | Driver | Academic Grade | D;C;B;A |
| campus | Driver | Campus Location | |

See [06_TEMPLATE_REFERENCE.md](docs/06_TEMPLATE_REFERENCE.md) for complete configuration.

---

## Output

The module generates an Excel workbook with:

| Sheet | Content |
|-------|---------|
| Executive Summary | Plain-English findings for non-statisticians |
| Importance Summary | Driver rankings with chi-square statistics |
| Factor Patterns | Category breakdowns and odds ratios |
| Model Summary | Fit statistics (pseudo-R², AIC) |
| Odds Ratios | Detailed comparisons (if detailed_output=TRUE) |
| Diagnostics | Data quality checks (if detailed_output=TRUE) |
| Subgroup Summary | Driver importance across subgroups (if subgroup_var set) |
| Subgroup OR Compare | Odds ratio comparison across subgroups (if subgroup_var set) |
| Subgroup Model Fit | Per-subgroup model fit statistics (if subgroup_var set) |

**Optional Stats Pack:** Set `Generate_Stats_Pack = Y` in Settings (or tick the GUI checkbox) to generate `{output}_stats_pack.xlsx` — a locked diagnostic workbook with Declaration, Data_Used, Assumptions, Warnings, Reproducibility, and Config_Echo sheets. Use `Project_Name`, `Analyst_Name`, and `Research_House` settings to populate the Declaration sheet.

---

## File Structure

```
modules/catdriver/
├── R/
│   ├── 00_main.R           # Entry point
│   ├── 01_config.R         # Configuration loader
│   ├── 02_validation.R     # Data validation
│   ├── 03_preprocessing.R  # Variable preparation
│   ├── 04_analysis.R       # Model dispatcher
│   ├── 04a_ordinal.R       # Ordinal logistic
│   ├── 04b_multinomial.R   # Multinomial logistic
│   ├── 05_importance.R     # Importance calculations
│   ├── 06_output.R         # Excel generation
│   ├── 06c_sheets_subgroup.R # Subgroup Excel sheets
│   ├── 07_utilities.R      # Helper functions
│   ├── 08_guard.R          # Guard framework
│   ├── 08a_guards_hard.R   # Hard guards (REFUSE)
│   ├── 08b_guards_soft.R   # Soft guards (WARN)
│   ├── 09_mapper.R         # Term-level mapping
│   ├── 10_missing.R        # Missing data handling
│   └── 11_subgroup_comparison.R  # Subgroup comparison logic
├── lib/html_report/        # HTML report pipeline
├── run_catdriver_gui.R     # Shiny GUI
└── docs/                   # Documentation
    ├── 01_README.md        # This file
    ├── 03_REFERENCE_GUIDE.md
    ├── 04_USER_MANUAL.md
    ├── 05_TECHNICAL_DOCS.md
    ├── 06_TEMPLATE_REFERENCE.md
    ├── 07_EXAMPLE_WORKFLOWS.md
    ├── 08_BOOTSTRAP_GUIDE.md
    └── templates/
```

---

## Dependencies

### Package Versions (from renv.lock)

| Package | Version | Role |
|---------|---------|------|
| MASS | 7.3-65 | Ordinal fallback (polr) |
| nnet | (bundled with R) | Multinomial logistic regression |
| car | (bundled with R) | Type II Wald chi-square tests |
| openxlsx | 4.2.8 | Excel I/O |
| ordinal | (install separately) | Primary ordinal engine (clm) |
| brglm2 | (install separately) | Firth bias-reduced estimation |
| haven | 2.5.5 | SPSS/Stata import |
| data.table | 1.17.8 | Fast data manipulation |
| htmltools | 0.5.8.1 | HTML report generation |
| jsonlite | 2.0.0 | JSON serialisation |
| base64enc | 0.1-3 | Image embedding in HTML reports |

**Required:**
```r
install.packages(c("MASS", "nnet", "car", "openxlsx"))
```

**Recommended:**
```r
install.packages(c("ordinal", "brglm2"))
```

**Optional (SPSS/Stata support):**
```r
install.packages("haven")
```

---

## Interpreting Results

### Odds Ratio Effect Sizes

| Odds Ratio | Effect Size |
|------------|-------------|
| 0.9 - 1.1 | Negligible |
| 0.67-0.9 or 1.1-1.5 | Small |
| 0.5-0.67 or 1.5-2.0 | Medium |
| 0.33-0.5 or 2.0-3.0 | Large |
| <0.33 or >3.0 | Very Large |

### Importance Percentages

| Importance % | Interpretation |
|--------------|----------------|
| > 30% | Dominant driver |
| 15-30% | Major driver |
| 5-15% | Moderate driver |
| < 5% | Minor driver |

---

## Documentation

| Document | Purpose |
|----------|---------|
| [03_REFERENCE_GUIDE.md](docs/03_REFERENCE_GUIDE.md) | Statistical methods reference |
| [04_USER_MANUAL.md](docs/04_USER_MANUAL.md) | Complete user guide |
| [05_TECHNICAL_DOCS.md](docs/05_TECHNICAL_DOCS.md) | Developer documentation |
| [06_TEMPLATE_REFERENCE.md](docs/06_TEMPLATE_REFERENCE.md) | Template field reference |
| [07_EXAMPLE_WORKFLOWS.md](docs/07_EXAMPLE_WORKFLOWS.md) | Practical examples |
| [08_BOOTSTRAP_GUIDE.md](docs/08_BOOTSTRAP_GUIDE.md) | Bootstrap confidence intervals |

---

## Version History

### v14.1 (March 2026)

- **Stats pack:** Diagnostic audit workbook generation. Adds `Generate_Stats_Pack`, `Project_Name`, `Analyst_Name`, `Research_House` config fields.

---

**Part of the Turas Analytics Platform**
