# Helderberg Village Segmentation Testing Guide

## Quick Start

You now have everything set up to test the segmentation module with your HV Cluster data.

---

## Prerequisites

✅ Data file: `HV Cluster data.xlsx` in the Turas directory
✅ Segmentation module: Restored and ready
✅ Testing script: `test_HV_segmentation.R` created

---

## Step-by-Step Testing

### 1. Open RStudio

Open RStudio and set your working directory to the Turas folder:
```r
setwd("/Users/duncan/Documents/Turas")
```

### 2. Verify Data File

Make sure your data file is in the Turas directory:
```r
file.exists("HV Cluster data.xlsx")
# Should return: TRUE
```

### 3. Run the Testing Script

```r
source("test_HV_segmentation.R")
```

### 4. Follow the Interactive Prompts

The script will:
- ✓ Load and inspect your data
- ✓ Show you all column names
- ✓ Suggest ID and clustering variables
- ✓ Ask you to confirm the configuration
- ✓ Validate data quality
- ✓ Generate a configuration file
- ✓ Run the segmentation analysis

### 5. Review Configuration

When prompted, the script will show:
- Detected ID variable
- Suggested clustering variables

**Review carefully** and type `y` to continue, or `n` to modify.

If you need to change the variables:
1. Open `test_HV_segmentation.R` in a text editor
2. Find lines ~160-161 (marked with CONFIGURATION SECTION)
3. Modify:
   ```r
   YOUR_ID_VARIABLE <- "your_id_column"
   YOUR_CLUSTERING_VARS <- c("var1", "var2", "var3", ...)
   ```
4. Save and run again

---

## What to Expect

### During Execution

You'll see:
```
================================================================================
HELDERBERG VILLAGE - SEGMENTATION TEST
================================================================================

STEP 1: Loading and Inspecting Data
--------------------------------------------------------------------------------
✓ Found data file: HV Cluster data.xlsx
✓ Loaded XXX respondents with XX variables

Column names and types:
...

STEP 2: Configure Segmentation Variables
--------------------------------------------------------------------------------
Current configuration:
  ID variable: respondent_id
  Clustering variables: q1, q2, q3, q4, q5

Is this configuration correct? (y/n):
```

### Output Files

After completion, you'll find:

**Configuration:**
- `config/HV_segmentation_config.xlsx` - Your configuration file

**Results (in `output/` folder with timestamp):**
- `seg_k_selection_report.xlsx` - Main exploration report
  - **Metrics_Comparison** sheet: Shows k=3, 4, 5, 6 with silhouette scores
  - **Profile_k3, Profile_k4, etc.** sheets: Segment profiles for each k
- Charts/visualizations (PNG files)

---

## Interpreting Results

### 1. Open the K Selection Report

Open `output/[timestamp]/seg_k_selection_report.xlsx`

### 2. Review Metrics Comparison Sheet

Look for:
- **avg_silhouette_width**: Higher is better (aim for > 0.4)
- **betweenss_totss**: Higher is better (between-cluster variance)
- **min_segment_pct**: No segment too small (> 10%)

### 3. Choose Optimal K

The recommended k will have:
- ✓ Highest silhouette score
- ✓ Good separation between segments
- ✓ Meaningful segment sizes

### 4. Review Segment Profiles

Check the profile sheets (Profile_k3, Profile_k4, etc.) to see:
- How segments differ on each variable
- Whether segments are interpretable
- Which k makes most business sense

---

## Next Steps

### If Test Succeeds ✅

1. Review the outputs and verify they make sense
2. Choose your optimal k from the report
3. Report back that testing passed
4. We'll merge the segmentation module to main

### If Issues Occur ❌

Report the error message and I'll help debug:
- What step did it fail at?
- What was the error message?
- Did data validation pass?

---

## Common Issues & Solutions

### Issue: "Data file not found"
**Solution**: Make sure you're in the Turas directory and the file is named exactly `HV Cluster data.xlsx`

### Issue: "Missing required packages"
**Solution**: Install packages:
```r
install.packages(c("readxl", "openxlsx", "cluster", "factoextra"))
```

### Issue: "Too few clustering variables"
**Solution**: Select at least 5 numeric variables for clustering

### Issue: "Too much missing data"
**Solution**: Check which variables have missing data and either:
- Remove those variables, or
- Use only complete cases

---

## Alternative: Manual Step-by-Step

If you prefer more control, run each step manually:

```r
# 1. Load data
library(readxl)
data <- read_excel("HV Cluster data.xlsx")

# 2. Inspect
str(data)
head(data)

# 3. Generate config
source("modules/segment/lib/segment_utils.R")
generate_config_template(
  data_file = "HV Cluster data.xlsx",
  output_file = "config/HV_config.xlsx",
  mode = "exploration"
)

# 4. Edit config in Excel (set id_variable and clustering_vars)

# 5. Run segmentation
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("config/HV_config.xlsx")
```

---

## Need Help?

- Check: `modules/segment/TESTING_CHECKLIST.md` for detailed testing
- Check: `modules/segment/USER_MANUAL.md` for full documentation
- Check: `modules/segment/QUICK_START.md` for quick reference

---

**Ready to test!** Just run:
```r
source("test_HV_segmentation.R")
```
