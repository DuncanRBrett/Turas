# Turas Pricing Module - Quick Start Guide

## Installation

```r
# Required packages
install.packages(c("shiny", "readxl", "openxlsx", "ggplot2"))
```

## 5-Minute Start

### 1. Launch GUI
From Turas launcher → Pricing → Launch GUI

Or from R:
```r
source("modules/pricing/run_pricing_gui.R")
run_pricing_gui()
```

### 2. Try a Test Project

**Option A: Consumer Electronics Example**
1. File → `test_projects/consumer_electronics/config.xlsx`
2. Data automatically loaded
3. Click "Run Analysis"
4. View results in tabs

**Option B: SaaS Subscription Example  **
1. File → `test_projects/saas_subscription/config.xlsx`
2. Includes profit optimization
3. Click "Run Analysis"
4. Compare revenue vs profit in "Additional Plots"

### 3. Create Your Own Config

1. Click "Create Config Template"
2. Select method: `van_westendorp` or `gabor_granger`
3. Save as `my_config.xlsx`
4. Edit in Excel:
   - Set `data_file` path
   - Map column names
   - Configure options
5. Load and run

## Key Features Quick Reference

### Phase 1: Data Quality
- **Weights**: Enter column name in "Weight Variable"
- **DK Codes**: Enter as `98,99` (comma-separated)
- **Monotonicity**: Select behavior from dropdown

### Phase 2: Profit Optimization  
- Enter **Unit Cost** to enable
- View profit-max vs revenue-max prices
- See comparison in "Additional Plots" tab

### Basic Workflow

```
Select Config → Override Settings (optional) → Run Analysis → Review Results
```

## Understanding Results

### Van Westendorp (Price Ranges)
- **PMC to PME**: Acceptable range
- **OPP to IDP**: Optimal range  
- **Recommendation**: Price within optimal range

### Gabor-Granger (Specific Price)
- **Revenue-Max**: Highest Price × Volume
- **Profit-Max**: Highest (Price-Cost) × Volume
- **Recommendation**: Choose based on strategy

## Common Configurations

### Weighted Analysis
```
Weight Variable: survey_weight
```

### Profit Optimization
```
Unit Cost: 22.50
```

### Data Quality
```
DK Codes: 98,99
VW Monotonicity: flag_only
GG Monotonicity: smooth
```

## Output Files

**Location**: Same folder as config file

**Files Created**:
- `[prefix]_results.xlsx` - Main output with all sheets
- `plots/` folder - PNG visualizations

**Key Excel Sheets**:
- Summary - Overview & sample stats
- VW_Price_Points or GG_Optimal_Revenue - Main results
- GG_Optimal_Profit - If unit cost specified
- Validation - Data quality report

## Troubleshooting

**"File not found"**
→ Use absolute paths or place config in same folder as data

**"Column not found"**
→ Check column names in data file (case-sensitive)

**"Too many exclusions"**
→ Check DK codes, try VW monotonicity = "flag_only"

**Slow analysis**
→ Reduce bootstrap iterations (1000 → 500 for testing)

## Next Steps

- Review `sample_config_comprehensive.R` for all options
- Try test projects in `test_projects/` folder
- See `USER_MANUAL.md` for complete documentation
- Read `TUTORIAL.md` for step-by-step walkthrough

## Support

- GitHub Issues: [Turas Issues](https://github.com/DuncanRBrett/Turas/issues)
- Sample configs: `modules/pricing/sample_config_comprehensive.R`
- Test data: `modules/pricing/test_projects/`

---

**Quick Tips**:
- Start with test projects to learn the interface
- Use "flag_only" monotonicity initially
- Enable bootstrap for final analysis only (faster testing without)
- Profit optimization requires unit cost - use variable costs only
- Check Validation sheet if results seem wrong

**Version**: 2.0.0 | **Updated**: December 2025
