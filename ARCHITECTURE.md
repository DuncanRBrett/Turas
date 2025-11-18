# Turas Analytics System - Architecture Documentation

**Version:** 1.0.0 (Baseline)
**Date:** 2025-11-17
**Status:** Production

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Principles](#architecture-principles)
3. [Module Architecture](#module-architecture)
4. [Data Flow](#data-flow)
5. [Integration Points](#integration-points)
6. [Technology Stack](#technology-stack)
7. [Directory Structure](#directory-structure)
8. [Extension & Customization](#extension--customization)
9. [Deployment & Scaling](#deployment--scaling)
10. [Future Roadmap](#future-roadmap)

---

## 1. System Overview

### 1.1 Purpose

Turas is a **modular analytics platform** for market research, designed to handle the complete survey analysis workflow from questionnaire parsing to advanced statistical analysis.

### 1.2 System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        TURAS ANALYTICS SUITE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───┐│
│  │  PARSER  │  │   TABS   │  │ TRACKER  │  │CONFIDENCE│  │SEG││
│  │          │  │          │  │          │  │          │  │   ││
│  │ Parse    │  │ Cross-   │  │ Multi-   │  │ Conf.    │  │K- ││
│  │ Question-│→ │ tabs +   │  │ Wave     │  │ Intervals│  │mea││
│  │ naires   │  │ Sig Test │  │ Trending │  │ + DEFF   │  │ns ││
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └───┘│
│       ↓             ↓             ↓              ↓          ↓   │
│  ┌────────────────────────────────────────────────────────────┐│
│  │              SHARED UTILITIES & LIBRARIES                  ││
│  │  • Config Loading  • Data I/O  • Weighting  • Validation  ││
│  └────────────────────────────────────────────────────────────┘│
│                              ↓                                  │
│  ┌────────────────────────────────────────────────────────────┐│
│  │                    OUTPUT LAYER                            ││
│  │  • Excel Reports  • Data Exports  • Visualizations         ││
│  └────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘

                              ↓

              ┌──────────────────────────────┐
              │   ANALYSIS WORKFLOWS          │
              │                               │
              │  Project                      │
              │  Directories  ← User Works   │
              │              Here             │
              └──────────────────────────────┘
```

### 1.3 Core Modules

| Module | Purpose | Input | Output | Status |
|--------|---------|-------|--------|--------|
| **Parser** | Extract questionnaire structure from Word docs | .docx | Excel survey structure | Production |
| **Tabs** | Generate weighted cross-tabulations with sig testing | Survey data + config | Excel crosstabs | Production |
| **Tracker** | Multi-wave tracking analysis with trends | Multiple wave data | Excel trend reports | Production |
| **Confidence** | Calculate confidence intervals (MOE, Wilson, Bootstrap, Bayesian) | Survey data + config | Excel CI tables | Production |
| **Segment** | K-means clustering segmentation | Survey data + config | Excel segments + profiles | Production |

---

## 2. Architecture Principles

### 2.1 Design Philosophy

**Modularity**
- Each module is self-contained
- Clear interfaces between modules
- Modules can be used independently or combined

**Configuration-Driven**
- Behavior controlled via Excel config files
- Minimal hard-coding
- Easy to adapt to new projects

**Reproducibility**
- All analysis parameters documented in config
- Version control friendly
- Audit trail of processing steps

**Transparency**
- Flags uncertain results for review
- Provides diagnostic outputs (DEFF, effective N, etc.)
- Clear documentation of methods used

### 2.2 Architectural Patterns

**Pipeline Pattern**
- Data flows through processing stages
- Each stage is isolated and testable
- Example: Read → Clean → Analyze → Output

**Strategy Pattern**
- Multiple algorithms for same task (e.g., confidence interval methods)
- Select via configuration
- Easy to add new strategies

**Builder Pattern**
- Complex outputs built incrementally
- Example: Excel workbook with multiple sheets

**Observer Pattern** (GUI only)
- Shiny reactive programming
- UI updates when data changes

---

## 3. Module Architecture

### 3.1 Standard Module Structure

Each module follows this structure:

```
modules/[module_name]/
├── lib/                      # Core library functions
│   ├── [component1].R       # Focused on one responsibility
│   ├── [component2].R
│   └── ...
│
├── test_data/                # Test datasets and scripts
│   ├── generate_test_data.R
│   └── ...
│
├── run_[module].R            # Command-line entry point
├── run_[module]_gui.R        # GUI entry point
│
├── QUICK_START.md            # 5-10 min getting started
├── USER_MANUAL.md            # Comprehensive user guide
├── TECHNICAL_DOCUMENTATION.md# Developer documentation
├── EXAMPLE_WORKFLOWS.md      # Real-world examples
└── README.md                 # Module overview
```

### 3.2 Module Independence

Modules are designed to work independently:

**Parser** → Standalone (no dependencies on other modules)
**Tabs** → Can use Parser output, but not required
**Tracker** → Can use Parser output, but not required
**Confidence** → Standalone (can complement Tabs output)
**Segment** → Standalone

### 3.3 Shared Components

Common functionality extracted to `/modules/shared/`:

```r
modules/shared/lib/
├── config_utils.R          # Excel config loading
├── data_utils.R            # Data import/export
├── validation_utils.R      # Input validation
└── logging_utils.R         # Logging functions
```

**Note:** Legacy `/shared/` directory exists but is deprecated. Use `/modules/shared/` instead.

---

## 4. Data Flow

### 4.1 Typical Workflow

```
1. QUESTIONNAIRE PREPARATION
   Questionnaire.docx
        ↓
   [Parser Module]
        ↓
   Survey_Structure.xlsx

2. DATA COLLECTION
   Field survey → Collect data
        ↓
   survey_data.xlsx/csv/sav

3. ANALYSIS
        ↓
   ┌─────────────────┬─────────────────────┬──────────────┐
   │                 │                     │              │
   ▼                 ▼                     ▼              ▼
[Tabs Module]   [Tracker Module]   [Confidence]   [Segment]
   │                 │                     │              │
   ▼                 ▼                     ▼              ▼
Crosstabs.xlsx  Trends.xlsx      Confidence.xlsx  Segments.xlsx

4. REPORTING
   Excel Reports → PowerPoint → Client Presentation
```

### 4.2 Data Formats

**Input Formats Supported:**
- Excel (.xlsx, .xls)
- CSV (.csv)
- SPSS (.sav) - via `haven` package
- Word (.docx) - Parser only

**Output Formats:**
- Excel (.xlsx) - Primary output
- CSV (.csv) - Optional exports
- RDS (.rds) - Model objects (Segment)

**Data Structure Requirements:**

**Survey Data:**
```
- One row per respondent
- One column per question
- Column names = question codes
- Optional weight column
```

**Configuration Files:**
```
- Excel workbooks (.xlsx)
- Multiple sheets (Questions, Settings, Banner, etc.)
- Specific column names expected
```

---

## 5. Integration Points

### 5.1 Module Integration Patterns

#### Pattern 1: Parser → Tabs
```r
# Step 1: Parse questionnaire
parse_questionnaire("questionnaire.docx", "structure.xlsx")

# Step 2: Use structure in Tabs config
tabs_config$survey_structure <- "structure.xlsx"
run_crosstabs(tabs_config)
```

#### Pattern 2: Parser → Tracker
```r
# Use parser output as question metadata
question_metadata <- read_excel("structure.xlsx", sheet = "Questions")

# Reference in tracker config
tracker_config$question_metadata <- question_metadata
```

#### Pattern 3: Tabs → Confidence
```r
# Run tabs first
run_crosstabs("tabs_config.xlsx")

# Then calculate CIs for key metrics
run_confidence_analysis("confidence_config.xlsx")

# Manually combine in final report
```

#### Pattern 4: Segment → Tabs
```r
# Step 1: Run segmentation
segments <- run_segmentation("segment_config.xlsx")

# Step 2: Join segments to survey data
survey_data$Segment <- segments$assignments

# Step 3: Use Segment as banner variable in Tabs
banner_config$BreakVariable <- "Segment"
```

### 5.2 External System Integration

**Survey Platforms:**
- Export data from Qualtrics/SurveyMonkey/Confirmit
- Load into Turas via standard data loaders
- Use Parser to extract questionnaire structure

**Reporting Tools:**
- Excel output can be imported to PowerPoint
- Charts can be copied to Word/PowerPoint
- Data can be exported to Tableau/Power BI

**Version Control:**
- Configuration files are text-based (Excel converted to CSV for git)
- R scripts tracked in git
- Analysis reproducible from config + data

---

## 6. Technology Stack

### 6.1 Core Technologies

**Language:**
- R 4.0+ (primary language)
- R Markdown (future: reporting)

**Key Packages:**

| Package | Purpose | Critical? |
|---------|---------|-----------|
| `openxlsx` | Excel writing | Yes |
| `readxl` | Excel reading | Yes |
| `officer` | Word document reading (Parser) | Parser only |
| `shiny` | GUI interfaces | Optional |
| `data.table` | Fast data manipulation | Recommended |
| `haven` | SPSS file reading | Optional |
| `survey` | Complex survey analysis (Confidence) | Confidence only |
| `cluster` | Clustering algorithms (Segment) | Segment only |

### 6.2 Development Tools

**Required:**
- R 4.0+
- RStudio (recommended IDE)
- Git (version control)

**Optional:**
- `testthat` (unit testing)
- `roxygen2` (documentation generation)
- `devtools` (development utilities)

---

## 7. Directory Structure

### 7.1 Full Repository Structure

```
Turas/
├── modules/                   # Core modules
│   ├── parser/
│   ├── tabs/
│   ├── tracker/
│   ├── confidence/
│   ├── segment/
│   └── shared/               # Shared utilities
│
├── templates/                 # Configuration templates
│   ├── Crosstab_Config_Template.xlsx
│   ├── Survey_Structure_Template.xlsx
│   └── Tracking_Config_Template.xlsx
│
├── docs/                      # Centralized documentation
│   ├── CODE_REVIEW_SUMMARY.md
│   ├── USER_MANUAL.md
│   ├── TROUBLESHOOTING.md
│   └── ...
│
├── tests/                     # Test suite
│   ├── testthat/
│   └── testthat.R
│
├── shared/                    # DEPRECATED - use modules/shared/
│
├── launch_turas.R            # Main launcher GUI
├── README.md                  # Project overview
├── ARCHITECTURE.md            # This file
├── Turas.Rproj               # RStudio project
└── .gitignore                # Git exclusions
```

### 7.2 Project Workflow Directory

**User's project directory (separate from Turas):**

```
MyProject/
├── data/
│   ├── raw/                  # Original survey data
│   ├── processed/            # Cleaned data
│   └── wave1/                # Multi-wave tracking
│       ├── wave1_data.xlsx
│       ├── wave2_data.xlsx
│       └── ...
│
├── config/                    # Project-specific configs
│   ├── tabs_config.xlsx
│   ├── tracker_config.xlsx
│   └── segment_config.xlsx
│
├── output/                    # Analysis outputs
│   ├── crosstabs/
│   ├── trends/
│   ├── segments/
│   └── reports/
│
├── questionnaires/           # Original questionnaires
│   └── survey.docx
│
└── scripts/                  # Project-specific R scripts
    ├── 01_data_prep.R
    ├── 02_run_tabs.R
    └── 03_create_charts.R
```

---

## 8. Extension & Customization

### 8.1 Adding a New Module

**Steps:**

1. **Create directory structure:**
```r
modules/new_module/
├── lib/
├── run_new_module.R
├── run_new_module_gui.R
└── QUICK_START.md
```

2. **Follow architecture patterns:**
- Use config-driven approach
- Extract shared code to `/modules/shared/`
- Create Excel output format
- Write documentation

3. **Add to main launcher:**
Edit `launch_turas.R` to include new module card

4. **Add tests:**
Create `tests/testthat/test_new_module.R`

### 8.2 Extending Existing Modules

**Example: Adding a new statistical test to Tabs**

1. **Create new function in lib:**
```r
# modules/tabs/lib/new_test.R
perform_new_test <- function(data, config) {
  # Implementation
}
```

2. **Integrate into orchestrator:**
```r
# modules/tabs/lib/run_crosstabs.R
if (config$use_new_test) {
  result <- perform_new_test(data, config)
}
```

3. **Update configuration:**
Add new option to config template

4. **Document:**
Update USER_MANUAL.md with new feature

### 8.3 Custom Output Formats

**Example: Adding PDF export**

```r
# Create new output module
modules/tabs/lib/pdf_writer.R

generate_pdf_report <- function(results, config) {
  library(rmarkdown)

  # Render R Markdown template
  rmarkdown::render(
    "templates/report_template.Rmd",
    params = list(results = results),
    output_file = config$pdf_output_file
  )
}
```

---

## 9. Deployment & Scaling

### 9.1 Single-User Deployment

**Current architecture** is optimized for single-user desktop use:

- Local R installation
- File-based data storage
- Excel configuration files
- Manual execution via R or Shiny GUI

**Advantages:**
- Simple setup
- No server required
- Full control over data
- Works offline

### 9.2 Team Deployment

**For teams:**

1. **Shared network drive:**
```
Z:/
├── Turas/                    # Shared Turas installation
├── Projects/                 # Shared project files
│   ├── Client_A/
│   ├── Client_B/
│   └── ...
└── Templates/                # Centralized templates
```

2. **Version control:**
- Git repository for Turas code
- Separate repos for project configurations
- `.gitignore` data files (large, confidential)

3. **Standards:**
- Shared configuration templates
- Naming conventions for projects
- Documentation in central wiki

### 9.3 Enterprise Deployment (Future)

**Potential enhancements for enterprise:**

**Shiny Server:**
- Web-based interface
- Multi-user concurrent access
- Centralized processing

**Database Backend:**
- Replace Excel config with database
- Store analysis history
- Track versions

**API Layer:**
- RESTful API for programmatic access
- Integration with other tools
- Automated workflows

**Containerization:**
- Docker containers for consistent environment
- Easy deployment across systems
- Scalable processing

---

## 10. Future Roadmap

### 10.1 Planned Enhancements

**Short-Term (Next 6 Months):**
- [ ] Complete comprehensive documentation for all modules
- [ ] Implement unit test coverage (target: 80%)
- [ ] Fix critical bugs identified in code review
- [ ] Create video tutorials for each module
- [ ] Develop Conjoint analysis module

**Medium-Term (6-12 Months):**
- [ ] Refactor Parser for better questionnaire handling
- [ ] Enhance Tracker with forecasting capabilities
- [ ] Add automated PowerPoint report generation
- [ ] Implement CI/CD pipeline
- [ ] Create Python wrapper for Turas modules

**Long-Term (1-2 Years):**
- [ ] Web-based deployment via Shiny Server
- [ ] API development for external integrations
- [ ] Machine learning integration (auto-segmentation, text analysis)
- [ ] Real-time dashboard capabilities
- [ ] Multi-language support (Spanish, French, German)

### 10.2 Known Limitations & Future Work

**Current Limitations:**

1. **Parser:**
   - Complex grid questions not auto-detected
   - Image-based options not supported
   - Skip logic not modeled

2. **Tabs:**
   - No automated chart generation (future R Markdown)
   - Limited customization of Excel formatting
   - No export to Tableau/Power BI

3. **Tracker:**
   - No forecasting/prediction
   - Manual question mapping required if codes change
   - Limited visualization options

4. **Confidence:**
   - No multi-level modeling (future `lme4` integration)
   - Bootstrap can be slow for large datasets

5. **Segment:**
   - K-means only (future: hierarchical, DBSCAN)
   - No automated segment naming
   - No profile export to visualization tools

**Planned Improvements:**

See **CODE_REVIEW_SUMMARY.md** for detailed list of identified issues and prioritized fixes.

---

## Appendix A: Module Comparison Matrix

| Feature | Parser | Tabs | Tracker | Confidence | Segment |
|---------|--------|------|---------|------------|---------|
| **Lines of Code** | ~3,000 | ~13,000 | ~4,700 | ~4,900 | ~4,000 |
| **Complexity** | Medium | High | High | Medium | Medium |
| **Dependencies** | officer, openxlsx | openxlsx, readxl | openxlsx, readxl | openxlsx, survey | cluster, openxlsx |
| **GUI Available** | Yes | Yes | Yes | Yes | Yes |
| **CLI Available** | Yes | Yes | Yes | Yes | Yes |
| **Batch Processing** | Yes | Yes | Yes | Yes | Yes |
| **Typical Run Time** | 5-15 sec | 30-120 sec | 30-180 sec | 30-90 sec | 60-300 sec |
| **Documentation Quality** | Complete | Partial | Partial | Complete | Complete |
| **Test Coverage** | None | Partial | None | Partial | Good |
| **Production Ready** | Yes | Yes | Yes (bugs) | Yes (bugs) | Yes |

---

## Appendix B: Configuration File Standards

All modules use Excel-based configuration with these standards:

**Sheet Names:**
- Use underscores, not spaces: `Question_Analysis` not `Question Analysis`
- CamelCase for multi-word: `SummarySheet`

**Column Names:**
- CamelCase for readability: `QuestionCode`, `BreakVariable`
- Consistent across modules when possible

**Settings Sheet:**
- Always: `SettingName | SettingValue`
- One setting per row
- Blank values = use default

**Boolean Values:**
- Use: `TRUE` / `FALSE` (all caps)
- Not: true/false, T/F, 1/0

**File Paths:**
- Relative paths preferred: `data/survey.xlsx`
- Absolute paths supported: `C:/Projects/data/survey.xlsx`
- Use forward slashes (/) even on Windows

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| **Banner** | Demographic variables used as columns in cross-tabs |
| **Base** | Sample size for a metric (weighted or unweighted) |
| **DEFF** | Design Effect - efficiency loss from weighting/clustering |
| **Effective N** | Sample size after adjusting for DEFF |
| **MOE** | Margin of Error - precision of an estimate |
| **NPS** | Net Promoter Score - % Promoters minus % Detractors |
| **Sig Testing** | Statistical significance testing (chi-square, t-test, z-test) |
| **Top Box** | Highest response option (e.g., "Strongly Agree") |
| **Top 2 Box** | Combined top 2 response options |
| **Wave** | Single data collection period in tracking study |

---

**End of Architecture Documentation**

*Version 1.0.0 | System Architecture | Turas Analytics Suite*

---

**Maintained by:** Development Team
**Last Major Update:** 2025-11-17 (Baseline v1.0)
**Next Review:** 2025-12-17
