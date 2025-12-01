# Turas Segmentation Module - Quick Start Guide

**Get started with customer segmentation in 5 minutes!**

## What is Segmentation?

The Turas Segmentation Module uses k-means clustering to automatically group survey respondents into meaningful segments based on their attitudes, behaviors, or satisfaction levels.

## Before You Start

**You need:**
- Survey data (CSV or Excel) with respondents as rows and questions as columns
- A respondent ID column
- 5-20 numeric variables for clustering (e.g., satisfaction ratings 1-10)
- At least 100 respondents (300+ recommended)

## Quick Start: 3 Steps

### Step 1: Launch the Segmentation Module

```r
source("launch_turas.R")
# Click "Launch Segment" button
```

### Step 2: Create Your Configuration

**Option A: Use the GUI**
1. Click "Select Config File" → "New Project"
2. Choose your survey data file
3. Fill in:
   - **ID Variable**: Name of respondent ID column (e.g., "respondent_id")
   - **Clustering Variables**: Questions to segment on (e.g., "q1,q2,q3,q4,q5")
4. Leave other settings at defaults
5. Save configuration

**Option B: Use Template Generator**
```r
source("modules/segment/lib/segment_utils.R")
initialize_segmentation_project(
  project_name = "My_Segmentation",
  data_file = "path/to/survey_data.csv"
)
# Then edit: projects/My_Segmentation/config/segmentation_config.xlsx
```

### Step 3: Run Segmentation

**Option A: Use the GUI (Recommended)**
```r
source("modules/segment/run_segment_gui.R")
run_segment_gui()
```

Then:
1. Click "Select Config File" → browse to your config
2. Click "Validate Configuration"
3. Click "Run Segmentation Analysis"
4. **Watch the console output** for real-time progress
5. View results when complete

**Option B: Use Command Line**
```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("path/to/your_config.xlsx")
```

**That's it!** Results will be saved to the output folder specified in your configuration.

## Understanding Your Results

After running, you'll find these files in your output folder:

| File | What It Contains |
|------|------------------|
| `seg_exploration_report.xlsx` | K-selection metrics (which k is best?) |
| `seg_segment_profiles_k4.xlsx` | Detailed profiles for k=4 solution |
| `seg_assignments_k4.xlsx` | Each respondent's segment assignment |
| `seg_k_selection.png` | Visual charts showing optimal k |
| `seg_segment_sizes.png` | Bar chart of segment sizes |
| `seg_model.rds` | Saved model (for scoring new data later) |

**Start with the exploration report** to choose your optimal number of segments (k).

## Example Workflow

**Using GUI (Easiest):**
```r
# 1. Launch GUI
source("modules/segment/run_segment_gui.R")
run_segment_gui()

# 2. In GUI:
#    - Select your exploration config
#    - Click Validate → Run
#    - Watch console output for progress
#    - Review results to choose k

# 3. Edit config: set k_fixed = 4 (your chosen k)

# 4. In GUI:
#    - Select your final config
#    - Click Validate → Run
#    - Download results

# 5. Score new data with saved model
source("modules/segment/lib/segment_scoring.R")
new_scores <- score_new_data(
  model_file = "output/seg_model.rds",
  new_data = new_survey_data,
  id_variable = "respondent_id"
)
```

**Using Command Line (Advanced):**
```r
# 1. Load module
source("modules/segment/run_segment.R")

# 2. Run segmentation (exploration mode)
result <- turas_segment_from_config("my_config.xlsx")

# 3. Review results, choose k=4
#    Edit config: set k_fixed = 4

# 4. Run final segmentation
final <- turas_segment_from_config("my_config_final.xlsx")

# 5. Score new data with saved model
source("modules/segment/lib/segment_scoring.R")
new_scores <- score_new_data(
  model_file = "output/seg_model.rds",
  new_data = new_survey_data,
  id_variable = "respondent_id"
)
```

## Common Settings

### Exploration vs. Final Mode

**Exploration Mode** (finding optimal k):
```
k_fixed = [leave blank]
k_min = 3
k_max = 6
```

**Final Mode** (using chosen k):
```
k_fixed = 4
```

### Variable Selection (20+ variables)

If you have many variables, enable automatic selection:
```
variable_selection = TRUE
max_clustering_vars = 10
```

### Outlier Detection

Identify extreme respondents before clustering:
```
outlier_detection = TRUE
outlier_handling = flag    # or "remove"
```

### Question Labels

Show full question text instead of "q1, q2, q3":

1. Create labels file (Excel, 2 columns):
   ```
   Variable | Label
   q1       | Overall satisfaction with product
   q2       | Satisfaction with customer service
   ...
   ```

2. Add to config:
   ```
   question_labels_file = path/to/labels.xlsx
   ```

## Troubleshooting

**"Missing clustering variables"**
→ Check variable names match exactly (case-sensitive)

**"Not enough complete cases"**
→ Too much missing data. Try mean_imputation or remove variables with >20% missing

**"Segments are unstable"**
→ Try fewer clustering variables or different k

**"All segments look the same"**
→ Variables don't differentiate respondents well. Try different variables

## Next Steps

- **Full documentation**: See `USER_MANUAL.md` for comprehensive guide
- **Advanced features**: Variable selection, outlier detection, validation metrics
- **Scoring new data**: Apply segments to ongoing survey responses
- **Visualizations**: Create profile heatmaps and spider charts

## Need Help?

Check the full User Manual (`USER_MANUAL.md`) or Maintenance Manual (`MAINTENANCE_MANUAL.md`) for detailed documentation.

---

**Happy Segmenting!** 🎯
