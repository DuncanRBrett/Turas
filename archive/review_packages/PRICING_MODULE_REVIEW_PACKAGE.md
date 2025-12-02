# Turas Pricing Module - External Code Review Package

**Version:** 1.0.0
**Date:** 2025-11-30
**Purpose:** Comprehensive code listing for external review and quality assurance

---

## Executive Summary

The Turas Pricing Research Module implements two standard pricing methodologies:
1. **Van Westendorp Price Sensitivity Meter (PSM)** - Analyzes four price perception questions to determine acceptable price ranges
2. **Gabor-Granger** - Analyzes sequential purchase intent at various price points to construct demand curves and find revenue-maximizing prices

The module provides both programmatic (R functions) and graphical (Shiny GUI) interfaces.

---

## Module Structure

```
modules/pricing/
├── R/                          # Core analysis functions
│   ├── 00_main.R              # Main entry point
│   ├── 01_config.R            # Configuration management
│   ├── 02_validation.R        # Data validation
│   ├── 03_van_westendorp.R    # Van Westendorp PSM implementation
│   ├── 04_gabor_granger.R     # Gabor-Granger implementation
│   ├── 05_visualization.R     # Plot generation
│   └── 06_output.R            # Excel output generation
├── run_pricing_gui.R           # Shiny GUI application
├── examples/
│   └── sample_vw_data.csv     # Sample data
└── Documentation files (see below)
```

---

## Core Functionality Files

### 1. Main Entry Point
**File:** `modules/pricing/R/00_main.R` (222 lines)

**Purpose:** Primary API function `run_pricing_analysis()`

**Key Functions:**
- `run_pricing_analysis()` - Main analysis workflow orchestrator
- `pricing()` - Convenience alias

**Workflow:**
1. Load configuration from Excel
2. Load and validate survey data
3. Run selected analysis method(s)
4. Generate visualizations
5. Write Excel output

**Dependencies:**
- Sources all other R files in sequence
- Requires: readxl, openxlsx, ggplot2 (optional)

---

### 2. Configuration Management
**File:** `modules/pricing/R/01_config.R` (622 lines)

**Purpose:** Load and validate Excel configuration files

**Key Functions:**
- `load_pricing_config()` - Parse Excel config
- `load_van_westendorp_config()` - VW-specific settings
- `load_gabor_granger_config()` - GG-specific settings
- `create_pricing_config()` - Generate config template (exported)

**Configuration Structure:**
- Settings sheet: General project settings
- VanWestendorp sheet: PSM-specific parameters
- GaborGranger sheet: GG-specific parameters
- Validation sheet: Data quality rules
- Visualization sheet: Plot customization

**Data Validation:**
- Validates required settings
- Resolves relative file paths
- Applies sensible defaults

---

### 3. Data Loading & Validation
**File:** `modules/pricing/R/02_validation.R` (337 lines)

**Purpose:** Load survey data and ensure quality

**Key Functions:**
- `load_pricing_data()` - Multi-format file loader (CSV, XLSX, SAV, DTA, RDS)
- `validate_pricing_data()` - Comprehensive validation
- `check_vw_monotonicity()` - Validate Van Westendorp price sequence logic

**Validation Checks:**
- Column existence verification
- Data type conversion
- Missing value detection
- Range validation (configurable min/max)
- Monotonicity checks (too_cheap ≤ cheap ≤ expensive ≤ too_expensive)
- Completeness thresholds
- Outlier flagging

**Return Structure:**
- Clean dataset (exclusions removed)
- Exclusion counts and reasons
- Warning list
- Diagnostic metadata

---

### 4. Van Westendorp PSM Analysis
**File:** `modules/pricing/R/03_van_westendorp.R` (349 lines)

**Purpose:** Implement Van Westendorp Price Sensitivity Meter

**Key Functions:**
- `run_van_westendorp()` - Main VW analysis
- `calculate_vw_curves()` - Compute cumulative distribution curves
- `find_vw_intersections()` - Calculate four key price points
- `bootstrap_vw_confidence()` - Optional bootstrap confidence intervals
- `calculate_vw_descriptives()` - Summary statistics

**Methodology:**
Creates cumulative distribution curves for:
- "Too Cheap" (reverse cumulative)
- "Not Cheap" (cumulative of cheap threshold)
- "Not Expensive" (reverse cumulative of expensive threshold)
- "Too Expensive" (cumulative)

**Four Key Price Points:**
1. **PMC** (Point of Marginal Cheapness): Too Cheap ∩ Not Cheap
2. **OPP** (Optimal Price Point): Too Cheap ∩ Too Expensive
3. **IDP** (Indifference Price Point): Cheap ∩ Expensive
4. **PME** (Point of Marginal Expensiveness): Not Expensive ∩ Too Expensive

**Technical Details:**
- Uses empirical cumulative distribution functions (ECDF)
- Linear interpolation for intersection finding
- 200-point price grid for smooth curves
- Bootstrap resampling for confidence intervals

---

### 5. Gabor-Granger Analysis
**File:** `modules/pricing/R/04_gabor_granger.R` (435 lines)

**Purpose:** Implement Gabor-Granger pricing methodology

**Key Functions:**
- `run_gabor_granger()` - Main GG analysis
- `prepare_gg_wide_data()` - Convert wide format to long
- `prepare_gg_long_data()` - Validate long format
- `code_gg_response()` - Standardize response coding (binary, scale, auto)
- `check_gg_monotonicity()` - Validate demand monotonicity
- `calculate_demand_curve()` - Aggregate purchase intent by price
- `calculate_revenue_curve()` - Compute revenue = price × demand
- `find_optimal_price()` - Identify revenue-maximizing price
- `calculate_price_elasticity()` - Arc elasticity calculation
- `bootstrap_gg_confidence()` - Bootstrap confidence intervals

**Data Format Support:**
- **Wide format:** One respondent per row, multiple price columns
- **Long format:** Multiple rows per respondent, one row per price point

**Response Coding:**
- Binary (0/1, Yes/No)
- Scale (top-box threshold)
- Auto-detection

**Revenue Optimization:**
- Revenue Index = Price × Purchase Intent
- Identifies maximum on revenue curve

**Elasticity Calculation:**
Arc elasticity formula:
```
E = [(Q2-Q1)/((Q2+Q1)/2)] / [(P2-P1)/((P2+P1)/2)]
```

**Monotonicity Check:**
Validates that purchase intent decreases (or stays constant) as price increases

---

### 6. Visualization
**File:** `modules/pricing/R/05_visualization.R` (346 lines)

**Purpose:** Generate ggplot2 visualizations

**Key Functions:**
- `generate_pricing_plots()` - Main plot generator
- `plot_van_westendorp()` - Classic PSM four-curve plot
- `plot_gg_demand()` - Demand curve with confidence bands
- `plot_gg_revenue()` - Revenue curve with optimal point
- `save_pricing_plots()` - Export plots to files

**Van Westendorp Plot Features:**
- Four cumulative curves with distinct colors
- Shaded acceptable range (PMC to PME)
- Highlighted optimal range (OPP to IDP)
- Vertical dashed lines at key price points
- Annotated price point labels

**Gabor-Granger Plots:**
- Demand curve: Line + points with optional confidence ribbons
- Revenue curve: Identifies and marks optimal price
- Red highlighting for optimal point

**Customization:**
- Theme (default: minimal)
- Color palettes
- Font families and sizes
- Export format (PNG, PDF, etc.)
- Resolution (DPI)

---

### 7. Output Generation
**File:** `modules/pricing/R/06_output.R` (347 lines)

**Purpose:** Generate comprehensive Excel output workbooks

**Key Functions:**
- `write_pricing_output()` - Main output generator
- `export_pricing_csv()` - Export to CSV format (exported)

**Excel Workbook Structure:**

**Common Sheets:**
- Summary: Project metadata and sample sizes
- Configuration: Analysis settings used
- Validation: Data quality diagnostics

**Van Westendorp Sheets:**
- VW_Price_Points: Four key prices and ranges
- VW_Curves: Raw curve data for custom charting
- VW_Descriptives: Mean, median, SD by question
- VW_Confidence_Intervals: Bootstrap CIs (if calculated)

**Gabor-Granger Sheets:**
- GG_Demand_Curve: Price × purchase intent data
- GG_Revenue_Curve: Price × revenue index data
- GG_Optimal_Price: Revenue-maximizing price details
- GG_Elasticity: Arc elasticity by price segment
- GG_Confidence_Intervals: Bootstrap CIs (if calculated)

**Formatting:**
- Professional styling (headers, colors)
- Currency formatting
- Percentage formatting
- Auto-sized columns

**Additional Outputs:**
- Plots saved to `plots/` subdirectory
- CSV export option for further analysis

---

## Graphical User Interface

### 8. Shiny GUI Application
**File:** `modules/pricing/run_pricing_gui.R` (377 lines)

**Purpose:** Interactive web-based interface for pricing analysis

**Key Function:**
- `run_pricing_gui()` - Launch Shiny application (exported)

**UI Features:**

**Sidebar:**
- Configuration file upload
- Recent projects dropdown
- Data file override option
- Output file naming
- Template creation tool

**Main Panel Tabs:**
1. **Results:** Console output + key results table
2. **Plots:** Interactive visualization display
3. **Diagnostics:** Validation summary and warnings
4. **Help:** Quick start guide (embedded markdown)

**Functionality:**
- Real-time console capture
- Error handling with notifications
- Recent project tracking (persisted to `.recent_pricing_projects.rds`)
- Template generation directly from GUI
- Results displayed in formatted tables

**Module Location Detection:**
Robust script directory detection using multiple methods:
1. Call stack inspection (`sys.frame()`)
2. Command args parsing (`--file=`)
3. Fallback to CWD + `modules/pricing`

---

## Integration with Turas Suite

### 9. Suite Launcher Integration
**File:** `launch_turas.R` (lines 261-268, 477-496)

**Integration Points:**
- Module card in main launcher UI (lines 261-269)
- Launch handler (lines 477-496)
- Background process spawning
- Status message updates

**Launch Mechanism:**
```r
launch_module("pricing",
             file.path(turas_root, "modules/pricing/run_pricing_gui.R"))
```

Launches as detached background Rscript process with `launch.browser = TRUE`

---

## Documentation Files

### User Documentation
1. **README.md** (6,899 bytes)
   - Module overview
   - Installation instructions
   - Basic usage examples
   - Function reference

2. **QUICK_START.md** (6,215 bytes)
   - Step-by-step getting started guide
   - Configuration template creation
   - Sample workflow
   - Troubleshooting tips

3. **USER_MANUAL.md** (18,460 bytes)
   - Comprehensive user guide
   - Detailed methodology explanations
   - All configuration options documented
   - Interpretation guidelines
   - Best practices

4. **EXAMPLE_WORKFLOWS.md** (12,303 bytes)
   - Real-world use cases
   - Sample configurations
   - Interpretation examples

### Technical Documentation
5. **TECHNICAL_DOCUMENTATION.md** (11,238 bytes)
   - Architecture overview
   - Function reference
   - Data structures
   - Algorithm details
   - Extension guidelines

### Specification
6. **turas_pricing_module_spec.md** (root directory)
   - Original module specification
   - Requirements document
   - Design decisions

---

## Example Data

**File:** `modules/pricing/examples/sample_vw_data.csv` (180 bytes)

Sample Van Westendorp data for testing and demonstration purposes.

---

## Dependencies

### Required R Packages
**Core:**
- `readxl` - Read Excel configuration files
- `openxlsx` - Write Excel output workbooks

**GUI:**
- `shiny` - Web application framework
- `later` - Asynchronous operations

**Optional:**
- `ggplot2` - Visualization (module works without, skips plots)
- `haven` - Read SPSS/Stata files (.sav, .dta)

### R Version
- Minimum: R 3.6.0 (uses modern syntax)
- Tested: R 4.x

---

## Code Quality Metrics

### Total Lines of Code
| File | Lines | Purpose |
|------|-------|---------|
| 00_main.R | 222 | Entry point & workflow |
| 01_config.R | 622 | Configuration |
| 02_validation.R | 337 | Data validation |
| 03_van_westendorp.R | 349 | VW methodology |
| 04_gabor_granger.R | 435 | GG methodology |
| 05_visualization.R | 346 | Plotting |
| 06_output.R | 347 | Excel generation |
| run_pricing_gui.R | 377 | Shiny GUI |
| **Total** | **3,035** | **Core module** |

### Code Organization
- **Modular design:** Each methodology in separate file
- **Consistent structure:** All files follow same pattern
- **Clear separation:** Analysis ↔ Visualization ↔ Output
- **Well-documented:** Roxygen-style function headers
- **Error handling:** Graceful failures with informative messages

### Naming Conventions
- **Functions:** snake_case (e.g., `run_pricing_analysis`)
- **Internal functions:** Documented with `@keywords internal`
- **Exported functions:** Documented with `@export`
- **Variables:** snake_case
- **Constants:** UPPER_CASE in comments

---

## Key Features for Review

### Strengths
✅ **Methodology correctness:** Implements standard academic methodologies
✅ **Robust validation:** Comprehensive data quality checks
✅ **Flexible input:** Supports multiple file formats and data structures
✅ **Professional output:** Publication-ready Excel reports and visualizations
✅ **User-friendly:** Both programmatic and GUI interfaces
✅ **Well-documented:** Extensive inline comments and user documentation
✅ **Configurable:** Excel-based configuration for non-programmers
✅ **Error handling:** Graceful failures with helpful error messages

### Areas for Review
🔍 **Statistical correctness:** Verify Van Westendorp and Gabor-Granger implementations
🔍 **Edge cases:** Validate handling of small samples, missing data, outliers
🔍 **Performance:** Check efficiency with large datasets
🔍 **Bootstrap accuracy:** Verify confidence interval calculations
🔍 **Curve interpolation:** Review intersection finding algorithm
🔍 **Monotonicity violations:** Assess exclusion vs. warning trade-offs
🔍 **Price elasticity:** Validate arc elasticity formula
🔍 **GUI robustness:** Test file upload edge cases

---

## Testing Recommendations

### Unit Testing Priorities
1. **Curve calculations:** Test ECDF computation with known inputs
2. **Intersection finding:** Verify accuracy with synthetic data
3. **Bootstrap:** Validate confidence interval coverage
4. **Data validation:** Test all validation rules with edge cases
5. **Response coding:** Verify binary/scale conversions
6. **Revenue optimization:** Confirm optimal price selection

### Integration Testing
1. End-to-end workflow with sample data
2. Config file parsing with various formats
3. Multi-format data file loading
4. Excel output generation and formatting
5. Plot generation with different themes

### Validation Testing
1. Compare results to manual calculations
2. Verify against R packages (if available)
3. Cross-check with Excel implementations
4. Test with published research data

---

## Security Considerations

### Data Handling
- No data stored persistently (except user-specified output)
- File paths validated before access
- Recent projects list sanitized (only existing files retained)

### Input Validation
- All numeric inputs validated and converted
- File existence checked before reading
- Config structure validated before parsing

### Dependencies
- Only CRAN packages used (trusted sources)
- No external API calls
- No network access (except Shiny local server)

---

## Version Control

**Current Version:** 1.0.0 (Initial Implementation)
**Date:** 2025-11-18
**Git Branch:** `claude/pricing-module-review-01N4UG5NMs3BCuSFCUFuZY3j`

---

## Contact & Support

For questions about this code review package:
- Repository: DuncanRBrett/Turas
- Branch: claude/pricing-module-review-01N4UG5NMs3BCuSFCUFuZY3j

---

## File Checklist for External Reviewers

### Core R Files (7 files)
- [ ] `modules/pricing/R/00_main.R`
- [ ] `modules/pricing/R/01_config.R`
- [ ] `modules/pricing/R/02_validation.R`
- [ ] `modules/pricing/R/03_van_westendorp.R`
- [ ] `modules/pricing/R/04_gabor_granger.R`
- [ ] `modules/pricing/R/05_visualization.R`
- [ ] `modules/pricing/R/06_output.R`

### GUI (1 file)
- [ ] `modules/pricing/run_pricing_gui.R`

### Documentation (6 files)
- [ ] `modules/pricing/README.md`
- [ ] `modules/pricing/QUICK_START.md`
- [ ] `modules/pricing/USER_MANUAL.md`
- [ ] `modules/pricing/EXAMPLE_WORKFLOWS.md`
- [ ] `modules/pricing/TECHNICAL_DOCUMENTATION.md`
- [ ] `turas_pricing_module_spec.md`

### Examples (1 file)
- [ ] `modules/pricing/examples/sample_vw_data.csv`

### Integration (1 file - relevant sections)
- [ ] `launch_turas.R` (lines 261-269, 477-496)

**Total: 16 files for review**

---

## Review Completion Checklist

### Code Review
- [ ] Statistical methodology verified
- [ ] Edge cases tested
- [ ] Error handling assessed
- [ ] Performance benchmarked
- [ ] Security reviewed
- [ ] Code style consistent
- [ ] Documentation accurate
- [ ] Dependencies appropriate

### Functionality Review
- [ ] Van Westendorp results validated
- [ ] Gabor-Granger results validated
- [ ] Visualizations correct
- [ ] Excel output formatted properly
- [ ] GUI functional
- [ ] Configuration parsing robust

### Quality Assurance
- [ ] No hardcoded paths
- [ ] All functions documented
- [ ] Warning/error messages helpful
- [ ] Memory usage reasonable
- [ ] No infinite loops possible
- [ ] File I/O safe

---

**End of Review Package**
