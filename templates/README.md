# Turas Module Templates

This directory contains ready-to-use Excel templates for all Turas modules.

## Quick Start

1. **Copy** the template you need to your project directory
2. **Rename** it (e.g., `Tabs_Config_Template.xlsx` → `Tabs_Config.xlsx`)
3. **Edit** the template with your project data
4. **Run** the corresponding Turas module

## Available Templates

### Parser Module

**Parser_Questionnaire_Template.xlsx**
- Use this to input your survey questionnaire
- Contains examples of all question types:
  - Multi-select questions
  - Single choice questions
  - Rating scales (1-5)
  - NPS (0-10)
  - Numeric questions
  - Open-ended questions
- Run Parser to convert to Survey_Structure.xlsx

### Tabs Module

**Tabs_Survey_Structure_Template.xlsx**
- Defines your survey structure (questions and response options)
- Two sheets:
  - **Questions:** Question metadata (code, text, type)
  - **Options:** Response option definitions
- Pre-populated with examples:
  - Brand awareness, consideration, preference
  - Satisfaction rating (1-5)
  - NPS (0-10)
  - Demographics (Gender, Age Group)

**Tabs_Config_Template.xlsx**
- Main configuration for crosstabulation analysis
- Three sheets:
  - **Settings:** Analysis parameters (significance, decimal places, stat tests)
  - **Banner:** Columns for crosstabulation (demographics)
  - **Stub:** Rows for crosstabulation (questions with optional filters)
- Fully configured example ready to modify

### Tracker Module

**Tracker_Config_Template.xlsx**
- Configuration for multi-wave tracking studies
- Four sheets:
  - **Waves:** Define survey waves (4 quarterly waves example)
  - **TrackedQuestions:** Questions to track over time
  - **Banner:** Demographic segments for trend analysis
  - **Settings:** Tracker parameters (confidence level, trend significance)
- Ready for quarterly brand tracking

**Tracker_Question_Mapping_Template.xlsx**
- Maps question codes across waves when they change
- One sheet:
  - **QuestionMap:** Shows how Q1 in Wave 1 becomes Q01 in Wave 3
- Handles evolving questionnaires
- Includes instructions for adding more waves

### Confidence Module

**Confidence_Config_Template.xlsx**
- Configuration for confidence interval analysis
- Two sheets:
  - **Settings:** Analysis methods (MOE, Wilson, Bootstrap, Bayesian)
  - **Questions:** Question-level configuration with Bayesian priors
- Pre-configured for proportion, rating, and NPS questions
- Includes helpful parameter descriptions

### Segment Module

**Segment_Config_Template.xlsx**
- Configuration for k-means clustering segmentation
- One sheet:
  - **Config:** 15 parameters controlling segmentation
- Pre-configured for exploration mode (test k=3 to k=6)
- Includes outlier detection settings
- Ready to switch to final run mode

### Pricing Module

**Pricing_Config_Template.xlsx**
- Configuration for pricing research analysis
- Three sheets:
  - **Settings:** Analysis method (Van Westendorp, Gabor-Granger, or both)
  - **VanWestendorp:** PSM question mapping (too cheap/cheap/expensive/too expensive)
  - **GaborGranger:** Price points and purchase intent columns
- Supports weighted analysis and segmentation
- Includes profit optimization with unit cost

### Key Driver Module

**KeyDriver_Config_Template.xlsx**
- Configuration for key driver analysis
- Two sheets:
  - **Settings:** Analysis name, data/output files, minimum sample size
  - **Variables:** Outcome variable, driver variables, optional weight variable
- Pre-configured for brand health driver analysis
- Ready for regression-based relative importance analysis

### Conjoint Module

**Conjoint_Config_Template.xlsx**
- Configuration for choice-based conjoint analysis
- Two sheets:
  - **Settings:** Analysis type, data file, choice set structure
  - **Attributes:** Product attributes with levels (e.g., Price, Brand, Storage)
- Pre-configured for smartphone CBC example
- Estimates part-worth utilities and relative importance

## Template Features

All templates include:
- ✓ **Professional formatting** (bold headers, color-coded)
- ✓ **Example data** pre-populated
- ✓ **Clear column labels**
- ✓ **Helpful descriptions** and instructions
- ✓ **Appropriate column widths** for readability

## Regenerating Templates

If templates get corrupted or you need fresh copies:

```bash
# From Turas root directory
python3 create_all_templates.py
python3 create_missing_templates.py
```

This will regenerate all 10 templates in the `templates/` directory (7 core module templates + 3 additional module templates).

## Example Workflow

**Starting a new Tabs project:**

```bash
# 1. Copy templates to project
cp templates/Tabs_Config_Template.xlsx my_project/Tabs_Config.xlsx
cp templates/Tabs_Survey_Structure_Template.xlsx my_project/Survey_Structure.xlsx

# 2. Edit with your data
# - Update Survey_Structure.xlsx with your questions
# - Update Tabs_Config.xlsx with your data file path and settings

# 3. Run Tabs
# In R:
source("turas.R")
turas_load("tabs")
# ... run analysis
```

**Starting a new Tracker project:**

```bash
# 1. Copy templates
cp templates/Tracker_Config_Template.xlsx my_project/tracking_config.xlsx
cp templates/Tracker_Question_Mapping_Template.xlsx my_project/question_mapping.xlsx

# 2. Edit with your waves and questions
# - Add your wave data files to Waves sheet
# - List questions to track in TrackedQuestions sheet
# - Map question codes if they changed (question_mapping.xlsx)

# 3. Run Tracker
# In R:
source("turas.R")
turas_load("tracker")
# ... run analysis
```

## Need Help?

See the module-specific documentation:
- **QUICK_START.md** - 10-15 minute getting started guide
- **USER_MANUAL.md** - Comprehensive user guide
- **EXAMPLE_WORKFLOWS.md** - Real-world usage examples
- **TECHNICAL_DOCUMENTATION.md** - Developer reference

---

**Last Updated:** December 2, 2025
**Turas Version:** 10.0
