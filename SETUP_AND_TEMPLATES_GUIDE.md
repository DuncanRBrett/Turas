# Turas Analytics - Setup & Configuration Templates Guide

**Version:** 10.0
**Date:** December 2, 2025

---

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Module-Specific Configuration Templates](#module-specific-configuration-templates)
3. [Data Preparation Standards](#data-preparation-standards)
4. [Project Workflow Setup](#project-workflow-setup)
5. [Configuration Best Practices](#configuration-best-practices)
6. [Template Customization](#template-customization)
7. [Troubleshooting Configuration Issues](#troubleshooting-configuration-issues)

---

## 1. Initial Setup

### 1.1 Installing R and Dependencies

**Step 1: Install R**
- Download from: https://cloud.r-project.org/
- Version required: R 4.0 or higher
- Recommended: R 4.3+

**Step 2: Install RStudio (Optional but Recommended)**
- Download from: https://posit.co/download/rstudio-desktop/
- Any recent version works

**Step 3: Install Required Packages**

```r
# Essential packages (all modules)
install.packages(c(
  "openxlsx",    # Excel writing
  "readxl",      # Excel reading
  "shiny"        # GUI interfaces
))

# Module-specific packages
install.packages(c(
  "officer",     # Parser: Word document reading
  "data.table",  # Tabs: Fast data processing
  "haven",       # All: SPSS file support
  "survey",      # Confidence: Complex survey analysis
  "cluster"      # Segment: Clustering algorithms
))

# Optional packages
install.packages(c(
  "testthat",    # Testing
  "devtools"     # Development tools
))
```

**Step 4: Verify Installation**

```r
# Check R version
R.version.string
# Should show: "R version 4.x.x ..."

# Check packages
library(openxlsx)
library(readxl)
library(shiny)

# If no errors, you're ready!
```

### 1.2 Downloading Turas

**Option A: Clone from GitHub**
```bash
git clone https://github.com/your-org/Turas.git
cd Turas
```

**Option B: Download ZIP**
1. Download ZIP file
2. Extract to desired location (e.g., `C:/Projects/Turas` or `~/Documents/Turas`)
3. Note the path

### 1.3 Setting Up Your Workspace

**Create project directory structure:**

```r
# Run this R code to set up a new project
create_turas_project <- function(project_path) {

  # Create directories
  dir.create(file.path(project_path, "data/raw"), recursive = TRUE)
  dir.create(file.path(project_path, "data/processed"), recursive = TRUE)
  dir.create(file.path(project_path, "config"), recursive = TRUE)
  dir.create(file.path(project_path, "output/crosstabs"), recursive = TRUE)
  dir.create(file.path(project_path, "output/trends"), recursive = TRUE)
  dir.create(file.path(project_path, "output/segments"), recursive = TRUE)
  dir.create(file.path(project_path, "questionnaires"), recursive = TRUE)
  dir.create(file.path(project_path, "scripts"), recursive = TRUE)

  # Copy templates
  turas_root <- "path/to/Turas"  # Update this
  file.copy(
    from = file.path(turas_root, "templates"),
    to = file.path(project_path, "config"),
    recursive = TRUE
  )

  cat("Project created at:", project_path, "\n")
  cat("Next: Add your data files to data/raw/\n")
}

# Use it:
create_turas_project("C:/Projects/MyAnalysis")
```

**Result:**
```
MyAnalysis/
├── data/
│   ├── raw/           ← Put original survey data here
│   └── processed/     ← Cleaned data goes here
├── config/            ← Configuration files
├── output/            ← Analysis outputs
├── questionnaires/    ← Original questionnaires
└── scripts/           ← Your R scripts
```

---

## 2. Module-Specific Configuration Templates

### 2.1 Parser Configuration

**Template Location:** `templates/Survey_Structure_Template.xlsx`

**Not applicable** - Parser has no config file. Just provide the .docx questionnaire.

**Usage:**
```r
source("modules/parser/shiny_app.R")
# Upload questionnaire.docx via GUI
```

---

### 2.2 Tabs Configuration Template

**Template Location:** `templates/Crosstab_Config_Template.xlsx`

#### Sheet 1: Questions

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| QuestionCode | Yes | Column name in data file | Q1_Satisfaction |
| QuestionText | Yes | Label for output | How satisfied are you? |
| QuestionType | Yes | Type of question | Single_Response, Multi_Mention, Rating, NPS |
| ValueLabels | Optional | Label for each code | 1=Very dissatisfied; 2=Dissatisfied; ... |
| ExcludeFromAnalysis | Optional | Skip this question | FALSE |

**Example:**
```
QuestionCode     | QuestionText                  | QuestionType
Q1_Age           | Age group                     | Single_Response
Q2_Gender        | Gender                        | Single_Response
Q3_Satisfaction  | Overall satisfaction          | Rating
Q4_Purchase      | Purchased in last 3 months    | Single_Response
Q5_NPS           | Likelihood to recommend (0-10)| NPS
```

#### Sheet 2: Banner

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| BannerLabel | Yes | Label in output | Male |
| BreakVariable | Yes | Column name to filter on | Q2_Gender |
| BreakValue | Yes | Value(s) to include | 1 (or 1,2 for multiple) |
| DisplayOrder | Yes | Order in output (numeric) | 2 |

**Example:**
```
BannerLabel | BreakVariable | BreakValue | DisplayOrder
Total       | Total         |            | 1
Male        | Q2_Gender     | 1          | 2
Female      | Q2_Gender     | 2          | 3
18-34       | Q1_Age        | 1,2        | 4
35-54       | Q1_Age        | 3,4        | 5
55+         | Q1_Age        | 5          | 6
```

#### Sheet 3: Settings

| Setting | Required | Description | Example |
|---------|----------|-------------|---------|
| data_file | Yes | Path to survey data | data/raw/survey.xlsx |
| weight_var | No | Weight column name (blank = unweighted) | Weight |
| output_file | Yes | Output path | output/crosstabs/results.xlsx |
| confidence_level | No | Confidence level (default 0.95) | 0.95 |
| show_percentages | No | Show % (default TRUE) | TRUE |
| show_counts | No | Show n (default TRUE) | TRUE |
| apply_sig_testing | No | Statistical testing (default TRUE) | TRUE |
| min_base_for_sig_testing | No | Min n for sig test (default 30) | 30 |

**Full Example:**
```
SettingName               | SettingValue
data_file                 | ../data/raw/survey_wave1.xlsx
weight_var                | Weight
output_file               | ../output/crosstabs/wave1_results.xlsx
confidence_level          | 0.95
show_percentages          | TRUE
show_counts               | TRUE
show_means                | TRUE
apply_sig_testing         | TRUE
min_base_for_sig_testing  | 30
decimal_places            | 1
```

---

### 2.3 Tracker Configuration Template

**Template Location:** `templates/Tracking_Config_Template.xlsx` (in tracker module)

#### Sheet 1: Waves

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| WaveID | Yes | Unique wave identifier | W1, W2, W3 or Q1_2024, Q2_2024 |
| WaveLabel | Yes | Display label | Wave 1 (Jan 2024) |
| DataFile | Yes | Path to wave data file | data/wave1_data.xlsx |
| FieldingDate | No | Collection date | 2024-01-15 |
| WeightVariable | No | Weight column name | Weight |

**Example:**
```
WaveID   | WaveLabel        | DataFile                  | FieldingDate | WeightVariable
Q1_2024  | Q1 2024 (Jan)    | ../data/wave1_data.xlsx   | 2024-01-15   | Weight
Q2_2024  | Q2 2024 (Apr)    | ../data/wave2_data.xlsx   | 2024-04-15   | Weight
Q3_2024  | Q3 2024 (Jul)    | ../data/wave3_data.xlsx   | 2024-07-15   | Weight
Q4_2024  | Q4 2024 (Oct)    | ../data/wave4_data.xlsx   | 2024-10-15   | Weight
```

#### Sheet 2: Questions

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| QuestionCode | Yes | Column name in data | Q1_Awareness |
| QuestionText | Yes | Label for output | Brand awareness (unaided) |
| QuestionType | Yes | Type of question | proportion, mean, nps |
| TargetValues | For proportions | Values to calculate % | 1 (or 4,5 for Top 2 Box) |

**Example:**
```
QuestionCode      | QuestionText                    | QuestionType | TargetValues
Q1_Awareness      | Brand awareness (unaided)       | proportion   | 1
Q2_Consideration  | Brand consideration             | proportion   | 1
Q3_Purchase       | Purchased in last 3 months      | proportion   | 1
Q4_Satisfaction   | Overall satisfaction (1-5)      | mean         |
Q5_NPS            | Likelihood to recommend (0-10)  | nps          |
```

#### Sheet 3: Settings

**Example:**
```
SettingName          | SettingValue
output_file          | ../output/trends/tracking_report.xlsx
confidence_level     | 0.95
trend_significance   | TRUE
min_base_for_testing | 30
decimal_places       | 1
```

#### Sheet 4: Banner (Optional)

Same structure as Tabs Banner sheet.

---

### 2.4 Confidence Configuration Template

#### Sheet 1: Question_Analysis

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| Question_Code | Yes | Column name in data | Q1_Satisfaction |
| Question_Type | Yes | proportion or mean | proportion |
| Target_Values | For proportions | Values for % calculation | 4,5 (Top 2 Box) |
| Methods | Yes | Comma-separated methods | moe,wilson,bootstrap |

**Methods options:**
- `moe` - Margin of Error (traditional)
- `wilson` - Wilson Score Interval
- `bootstrap` - Bootstrap resampling
- `bayesian` - Bayesian credible interval

**Example:**
```
Question_Code | Question_Type | Target_Values | Methods
Q1            | proportion    | 4,5           | moe,wilson,bootstrap
Q2            | proportion    | 1             | moe,wilson
Q3            | mean          |               | moe,bootstrap,bayesian
Q4            | proportion    | 9,10          | wilson
```

#### Sheet 2: Settings

```
Setting_Name          | Setting_Value
Data_File             | ../data/raw/survey.xlsx
Weight_Variable       | Weight
Output_File           | ../output/confidence/ci_results.xlsx
Confidence_Level      | 0.95
Bootstrap_Iterations  | 1000
Prior_Mean            | 0.5
Prior_Sample_Size     | 100
Min_Base_Size         | 30
```

---

### 2.5 Segment Configuration Template

**Template Location:** `modules/segment/test_data/test_segment_config.csv`

**Format: CSV file**

```csv
setting_name,setting_value
data_file,../data/raw/survey.xlsx
output_file,../output/segments/segmentation_results.xlsx
clustering_vars,"Q1,Q2,Q3,Q4,Q5,Q6,Q7,Q8,Q9,Q10"
k_min,2
k_max,6
k_fixed,
missing_data_handling,mean_imputation
remove_outliers,TRUE
outlier_method,zscore
outlier_threshold,3
perform_variable_selection,FALSE
weight_variable,
respondent_id_column,ResponseID
```

**Key Settings:**

| Setting | Description | Example |
|---------|-------------|---------|
| clustering_vars | Comma-separated question codes | Q1,Q2,Q3,Q4,Q5 |
| k_min / k_max | Range of cluster counts to test | 2 / 6 |
| k_fixed | Force specific k (blank = auto-select) | 4 |
| missing_data_handling | mean_imputation, median_imputation, or remove_cases | mean_imputation |
| remove_outliers | Remove outliers before clustering | TRUE |

---

## 3. Data Preparation Standards

### 3.1 Survey Data Format

**Required structure:**

```
Column 1: ResponseID (unique identifier)
Column 2: Weight (optional, if weighted)
Column 3+: Question responses (one column per question)
```

**Example:**

```csv
ResponseID,Weight,Q1_Age,Q2_Gender,Q3_Satisfaction,Q4_Purchase
1,1.25,2,1,4,1
2,0.85,3,2,5,1
3,1.10,1,1,3,0
```

### 3.2 Coding Standards

**Categorical Questions:**
- Use numeric codes: 1, 2, 3, 4, 5
- NOT: "Male", "Female" (use 1, 2 instead)
- NOT: "Yes", "No" (use 1, 0 instead)

**Missing Data:**
- Use NA (R's missing value indicator)
- NOT: -99, 999, "DK", "Refused"
- If using codes, recode to NA before analysis

**Rating Scales:**
- Start at 1, not 0: 1, 2, 3, 4, 5
- Exception: NPS must be 0-10

**Multi-Mention (Multi-Select):**
- Option A: Separate binary columns (Q1_a, Q1_b, Q1_c)
- Option B: Single column with comma-separated values (1,3,5)
- Recommended: Option A for easier analysis

### 3.3 Variable Naming Conventions

**Good:**
```
Q1_Age
Q2_Gender
Q3_Satisfaction
Q4_Purchase_Intent
DEM_Region
BRAND_Aware_Unaided
```

**Bad:**
```
q1               [Too vague]
Question 1       [Spaces not allowed]
Q1 - Age Group   [Special characters problematic]
```

**Rules:**
- Start with letter
- Use alphanumeric + underscore only
- No spaces
- CamelCase or underscore_case (be consistent)
- Prefix for question categories (Q1, DEM, BRAND)

---

## 4. Project Workflow Setup

### 4.1 Standard Project Template

**Use this structure for every project:**

```
ProjectName/
├── 00_setup.R              # Package installation, paths
├── 01_data_import.R        # Load raw data
├── 02_data_cleaning.R      # Clean, recode, create derived variables
├── 03_run_tabs.R           # Generate cross-tabs
├── 04_run_tracker.R        # Tracking analysis (if multi-wave)
├── 05_run_segments.R       # Segmentation (if needed)
├── 06_compile_report.R     # Combine outputs for client
│
├── data/
│   ├── raw/                # Original survey data (never modify)
│   │   └── survey_data.xlsx
│   └── processed/          # Cleaned data
│       └── survey_clean.xlsx
│
├── config/                 # Configuration files
│   ├── tabs_config.xlsx
│   ├── tracker_config.xlsx
│   └── segment_config.csv
│
├── output/                 # Analysis outputs
│   ├── crosstabs/
│   ├── trends/
│   └── segments/
│
├── questionnaires/
│   └── questionnaire.docx
│
└── client_deliverables/    # Final outputs for client
    ├── crosstabs_final.xlsx
    ├── trends_final.xlsx
    └── presentation.pptx
```

### 4.2 Script Template: 00_setup.R

```r
# =============================================================================
# PROJECT: [Project Name]
# CLIENT: [Client Name]
# DATE: [YYYY-MM-DD]
# ANALYST: [Your Name]
# =============================================================================

# Set working directory to project root
setwd("~/Projects/ProjectName")

# Turas installation path
TURAS_ROOT <- "~/Turas"  # Update to your Turas location

# Install/load required packages
required_packages <- c("openxlsx", "readxl", "data.table")
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)
lapply(required_packages, library, character.only = TRUE)

# Define paths
paths <- list(
  data_raw = "data/raw",
  data_processed = "data/processed",
  config = "config",
  output_tabs = "output/crosstabs",
  output_tracker = "output/trends",
  output_segment = "output/segments",
  questionnaires = "questionnaires",
  client_deliverables = "client_deliverables"
)

# Source Turas modules
source(file.path(TURAS_ROOT, "modules/parser/run_parser.R"))
source(file.path(TURAS_ROOT, "modules/tabs/run_tabs.R"))
source(file.path(TURAS_ROOT, "modules/tracker/run_tracker.R"))
source(file.path(TURAS_ROOT, "modules/confidence/R/00_main.R"))
source(file.path(TURAS_ROOT, "modules/segment/run_segment.R"))

cat("Setup complete!\n")
cat("Turas root:", TURAS_ROOT, "\n")
cat("Project paths configured.\n")
```

### 4.3 Script Template: 03_run_tabs.R

```r
# =============================================================================
# CROSS-TABULATION ANALYSIS
# =============================================================================

# Source setup
source("00_setup.R")

# Run cross-tabs
cat("Running cross-tabulation analysis...\n")

result <- run_crosstabs(
  config_file = file.path(paths$config, "tabs_config.xlsx")
)

cat("Cross-tabs complete! Output saved to:\n")
cat(" ", file.path(paths$output_tabs, "crosstabs_output.xlsx"), "\n")

# Open output (optional)
shell.exec(file.path(paths$output_tabs, "crosstabs_output.xlsx"))
```

---

## 5. Configuration Best Practices

### 5.1 File Paths

**✅ DO:**
- Use relative paths: `../data/survey.xlsx`
- Use forward slashes: `data/survey.xlsx` (works on all OS)
- Test paths before running full analysis

**❌ DON'T:**
- Use absolute paths unless necessary: `C:/Users/John/Desktop/survey.xlsx`
- Use backslashes: `data\survey.xlsx` (Windows-specific)
- Hardcode user-specific paths

### 5.2 Configuration Versioning

**Save versions of config files:**

```
config/
├── tabs_config_v1.xlsx         # Initial version
├── tabs_config_v2.xlsx         # After client feedback
├── tabs_config_final.xlsx      # Final approved version
└── tabs_config.xlsx            # Symlink or copy of current
```

**Document changes:**
```
# config/CHANGELOG.md

## 2024-07-15 - Version 2
- Added Q10_NewQuestion to question list
- Removed "Other" category from Q3 banner
- Changed confidence level from 0.90 to 0.95

## 2024-07-10 - Version 1
- Initial configuration
```

### 5.3 Commenting Configurations

**Use comment columns:**

In Excel configs, add a "Notes" column:

```
QuestionCode | QuestionText    | QuestionType | Notes
Q1           | Age             | Single       | Standard demographic
Q2           | Gender          | Single       | Standard demographic
Q3           | Satisfaction    | Rating       | PRIMARY METRIC - track over time
```

---

## 6. Template Customization

### 6.1 Creating Custom Templates

**Step 1: Copy base template**
```r
file.copy(
  from = "templates/Crosstab_Config_Template.xlsx",
  to = "MyOrg_Tabs_Template.xlsx"
)
```

**Step 2: Customize for your organization**
- Add standard banner variables (Age, Gender, Region)
- Set default settings (confidence_level, decimal_places)
- Add company branding to documentation sheets

**Step 3: Save as organizational standard**

**Step 4: Train team on using template**

### 6.2 Creating Project-Specific Templates

For recurring projects (e.g., monthly tracking):

```
templates/
├── MonthlyTracking_Tabs.xlsx     # Standard tabs config for monthly
├── MonthlyTracking_Tracker.xlsx  # Standard tracker config
└── MonthlyTracking_README.md     # Instructions for updating
```

**MonthlyTracking_README.md:**
```markdown
# Monthly Tracking Analysis Template

## Setup Instructions
1. Copy this template to your project config/ folder
2. Update Settings sheet:
   - data_file: Point to current month's data
   - output_file: Update month in filename
3. Update Waves sheet (tracker only):
   - Add new wave row
   - Update DataFile path
4. Run analysis

## DO NOT MODIFY:
- Questions sheet (unless new questions added)
- Banner sheet (unless segments change)
```

---

## 7. Troubleshooting Configuration Issues

### 7.1 Common Configuration Errors

**Error: "Sheet 'Questions' not found"**
```
Cause: Config file missing required sheet
Fix: Ensure Excel file has all required sheets with exact names
     (Questions, Settings, Banner, etc. - case-sensitive)
```

**Error: "Required column 'QuestionCode' not found"**
```
Cause: Column name misspelled or missing
Fix: Check column names match exactly (case-sensitive):
     QuestionCode (not Question_Code or questioncode)
```

**Error: "Data file not found: data/survey.xlsx"**
```
Cause: Incorrect file path
Fix: Check path is correct relative to R working directory
     Use getwd() to see current directory
     Use file.exists("data/survey.xlsx") to test
```

**Error: "Weight variable 'Weight' not found in data"**
```
Cause: Weight column name doesn't match data
Fix: Check spelling and case in both config and data file
     Or remove weight_var setting to run unweighted
```

### 7.2 Validation Checklist

Before running analysis, verify:

- [ ] All required sheets present in config file
- [ ] All required columns present in each sheet
- [ ] Data file path is correct and file exists
- [ ] Question codes in config match column names in data
- [ ] Banner break variables exist in data
- [ ] Weight variable (if specified) exists in data
- [ ] Output directory exists or can be created
- [ ] No typos in setting names (use exact names from templates)

### 7.3 Testing Configuration

**Quick test script:**

```r
# Test configuration before full analysis
test_config <- function(config_path) {

  # Check file exists
  if (!file.exists(config_path)) {
    stop("Config file not found: ", config_path)
  }

  # Check sheets
  sheets <- readxl::excel_sheets(config_path)
  required_sheets <- c("Questions", "Settings", "Banner")

  missing_sheets <- setdiff(required_sheets, sheets)
  if (length(missing_sheets) > 0) {
    stop("Missing required sheets: ", paste(missing_sheets, collapse = ", "))
  }

  # Check data file path
  settings <- readxl::read_excel(config_path, sheet = "Settings")
  data_file <- settings$SettingValue[settings$SettingName == "data_file"]

  if (!file.exists(data_file)) {
    warning("Data file not found: ", data_file)
  } else {
    cat("✓ Config file valid\n")
    cat("✓ All required sheets present\n")
    cat("✓ Data file found\n")
  }
}

# Use it:
test_config("config/tabs_config.xlsx")
```

---

## Appendix A: Complete Example - End-to-End Workflow

**Scenario:** Brand tracking survey, 3 waves, 1,000 respondents per wave

### Step 1: Project Setup

```r
# Create project structure
dir.create("BrandTracking2024", recursive = TRUE)
setwd("BrandTracking2024")

# Create folders
sapply(c("data/raw", "data/processed", "config", "output/tabs",
         "output/trends", "questionnaires"), dir.create, recursive = TRUE)
```

### Step 2: Parse Questionnaire

```r
source("~/Turas/modules/parser/run_parser.R")

parse_questionnaire(
  docx_path = "questionnaires/survey_q1_2024.docx",
  output_path = "config/survey_structure.xlsx"
)
```

### Step 3: Prepare Data

**Ensure data follows standards:**
- Column names match question codes
- Numeric coding
- Weight column included

**Files:**
- `data/raw/wave1_q1_2024.xlsx`
- `data/raw/wave2_q2_2024.xlsx`
- `data/raw/wave3_q3_2024.xlsx`

### Step 4: Create Tracker Config

**Copy template:**
```r
file.copy(
  from = "~/Turas/modules/tracker/tracking_config_template.xlsx",
  to = "config/tracker_config.xlsx"
)
```

**Edit in Excel:**
- Waves sheet: Add 3 waves
- Questions sheet: Key brand metrics
- Settings sheet: Paths and preferences

### Step 5: Run Analysis

```r
source("~/Turas/modules/tracker/run_tracker.R")

result <- run_tracking_analysis(
  config_path = "config/tracker_config.xlsx"
)
```

### Step 6: Review Output

Output saved to: `output/trends/tracking_report.xlsx`

Contains:
- Trend summary
- Individual question sheets with wave comparisons
- Statistical significance indicators

### Step 7: Create Client Deliverable

**Manually:**
- Copy key slides from tracking_report.xlsx
- Add to PowerPoint template
- Add executive summary

**Or automated (future):**
- Use R Markdown template
- Generate PDF report

---

## Appendix B: Configuration Template Checklist

Use this checklist when creating new configuration files:

### Tabs Configuration

- [ ] Questions sheet
  - [ ] QuestionCode column
  - [ ] QuestionText column
  - [ ] QuestionType column
  - [ ] At least 1 question listed
- [ ] Banner sheet
  - [ ] BannerLabel column
  - [ ] BreakVariable column
  - [ ] BreakValue column
  - [ ] DisplayOrder column
  - [ ] "Total" row included
- [ ] Settings sheet
  - [ ] data_file specified
  - [ ] output_file specified
  - [ ] weight_var specified (or blank if unweighted)
- [ ] File paths are correct
- [ ] Question codes match data columns

### Tracker Configuration

- [ ] Waves sheet
  - [ ] WaveID column
  - [ ] WaveLabel column
  - [ ] DataFile column
  - [ ] At least 2 waves listed
- [ ] Questions sheet
  - [ ] QuestionCode column
  - [ ] QuestionType column
  - [ ] At least 1 question listed
- [ ] Settings sheet
  - [ ] output_file specified
- [ ] All wave data files exist
- [ ] Question codes exist in all waves (or mapping provided)

### Confidence Configuration

- [ ] Question_Analysis sheet
  - [ ] Question_Code column
  - [ ] Question_Type column
  - [ ] Methods column
- [ ] Settings sheet
  - [ ] Data_File specified
  - [ ] Output_File specified
- [ ] Methods are valid (moe, wilson, bootstrap, bayesian)

### Segment Configuration (CSV)

- [ ] All required settings present
- [ ] clustering_vars specified
- [ ] k_min and k_max are reasonable (2-10)
- [ ] data_file path is correct

---

**End of Setup & Templates Guide**

*Version 1.0.0 | Configuration Guide | Turas Analytics Suite*
