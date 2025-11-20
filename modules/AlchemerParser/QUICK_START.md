# Quick Start Guide: Turas AlchemerParser Module

Get your first Alchemer survey parsed and ready for Tabs in under 10 minutes.

## Prerequisites

Ensure you have R installed with the following packages:

```r
install.packages(c("readxl", "openxlsx", "officer", "shiny"))
```

## Step 1: Export Files from Alchemer (5 minutes)

You need to export three files from your Alchemer survey:

### 1. Questionnaire Document
- Go to Survey → Build
- Click **Export** → **Print to Word**
- Save as: `{ProjectName}_questionnaire.docx`

### 2. Data Export Map
- Go to Survey → Results → Data Exports
- Create new export with **Question Numbers** format
- Download the export mapping
- Save as: `{ProjectName}_data_export_map.xlsx`

### 3. Translation Export
- Go to Survey → Build → Translations
- Export **Default Language**
- Save as: `{ProjectName}_translation-export.xlsx`

**Important:** All three files must use the same project name prefix.

## Step 2: Launch AlchemerParser GUI (1 minute)

### Option A: From Turas Launcher

```r
setwd("/path/to/Turas")
source("launch_turas.R")
# Click "Launch AlchemerParser" in the GUI
```

### Option B: Direct Launch

```r
setwd("/path/to/Turas")
source("modules/AlchemerParser/run_alchemerparser_gui.R")
# GUI will launch automatically
```

## Step 3: Select Project Directory (1 minute)

1. In the GUI, enter or browse to the folder containing your three exported files
2. The parser will automatically detect the project name and validate files
3. You should see: **"✓ All required files found"**

## Step 4: Parse Files (1 minute)

1. Optionally adjust the **Project Name** or **Output Directory**
2. Click **"Parse Files"**
3. Wait for completion (typically 10-30 seconds)

The parser will:
- Detect question types (NPS, Likert, Rating, Single/Multi-Mention, etc.)
- Generate question codes (Q01, Q02a, Q04_1, etc.)
- Handle grid questions automatically
- Flag any ambiguous questions for review

## Step 5: Review Results (1 minute)

After parsing completes, review:

- **Question Preview Table**: Shows all detected questions with codes and types
- **Validation Flags**: Any items needing manual review
- **Summary**: Question type distribution

## Step 6: Download Outputs (1 minute)

Three files are automatically saved to your output directory:

1. **{ProjectName}_Crosstab_Config.xlsx** - For Tabs banner/crosstab setup
2. **{ProjectName}_Survey_Structure.xlsx** - For Tabs question/option mapping
3. **{ProjectName}_Data_Headers.xlsx** - Column headers for your data file

Click the download buttons to get copies, or find them in your output directory.

## Next Steps

You're now ready to use these files with the Tabs module!

1. Rename your data file columns using the `Data_Headers.xlsx` file
2. Load the config files into Tabs
3. Run your cross-tabulation analysis

See the [User Manual](USER_MANUAL.md) for detailed guidance on:
- Handling complex grid questions
- Resolving validation flags
- Customizing question codes
- Using the CLI mode for batch processing

---

**Total Time:** ~10 minutes
**Difficulty:** Beginner
**Prerequisites:** Alchemer survey access, R with required packages
