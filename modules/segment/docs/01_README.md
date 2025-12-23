# Turas Segmentation Module

**Version:** 10.0
**Last Updated:** 22 December 2025

K-means clustering segmentation for survey data with exploration and final run modes.

---

## Overview

The Turas Segmentation Module provides a standardized, repeatable approach to clustering survey respondents into meaningful segments based on behavioral, attitudinal, or satisfaction data.

**Core Capabilities:**
- K-means clustering with automatic k selection
- Excel-based configuration
- Interactive GUI interface with real-time console output
- Exploration mode (compare multiple k values)
- Final run mode (detailed output for chosen k)
- Outlier detection and handling (Z-score or Mahalanobis)
- Variable selection for high-dimensional data
- Validation metrics (Silhouette, Elbow, Gap statistic)
- Segment profiling and characterization
- Model scoring for new data

---

## Quick Start

### Using the GUI (Recommended)

**Launch the GUI:**
```r
source("modules/segment/run_segment_gui.R")
run_segment_gui()
```

**Follow the 5-step workflow:**
1. **Select Configuration** - Browse to your config Excel file
2. **Validate** - Click to verify configuration is correct
3. **Run Analysis** - Start the segmentation
4. **Monitor Console** - Watch real-time progress
5. **View Results** - See summary and download outputs

### Using Command Line

**Step 1: Prepare Configuration**

Create `segment_config.xlsx` with a "Config" sheet:

```
parameter        | value
-----------------|---------------------------
data_file        | survey_data.xlsx
id_variable      | respondent_id
clustering_vars  | q1,q2,q3,q4,q5
k_min            | 3
k_max            | 6
output_folder    | output/
```

**Step 2: Run Exploration Mode**

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("segment_config.xlsx")
```

**Step 3: Review and Choose Optimal K**

Open the exploration report and review:
- Silhouette scores (higher = better separation)
- Segment sizes (check for very small segments)
- Profile tables for each k

**Step 4: Run Final Segmentation**

Update config: `k_fixed = 4` then re-run.

**Outputs:**
- `seg_assignments.xlsx` - Respondent ID + segment assignment
- `seg_final_report.xlsx` - Comprehensive multi-tab report
- `seg_model.rds` - Saved model for scoring new data

---

## File Structure

```
modules/segment/
├── lib/
│   ├── segment_config.R        # Configuration loading/validation
│   ├── segment_data_prep.R     # Data loading and preparation
│   ├── segment_kmeans.R        # K-means clustering engine
│   ├── segment_outliers.R      # Outlier detection and handling
│   ├── segment_validation.R    # Validation metrics
│   ├── segment_profile.R       # Segment profiling
│   ├── segment_profiling_enhanced.R  # ANOVA and effect sizes
│   ├── segment_scoring.R       # Score new data
│   ├── segment_visualization.R # Charts and plots
│   └── segment_export.R        # Excel export functions
├── run_segment.R               # Main entry point
├── run_segment_gui.R           # GUI launcher
└── docs/                       # Documentation
    ├── 01_README.md            # This file
    ├── 02_SEGMENT_OVERVIEW.md  # Capabilities overview
    ├── 03_REFERENCE_GUIDE.md   # Statistical methods
    ├── 04_USER_MANUAL.md       # User guide
    ├── 05_TECHNICAL_DOCS.md    # Developer documentation
    ├── 06_TEMPLATE_REFERENCE.md # Template field reference
    ├── 07_EXAMPLE_WORKFLOWS.md  # Practical examples
    └── templates/              # Config templates
```

---

## Configuration Parameters

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `data_file` | Path to survey data (Excel/CSV) | survey_data.xlsx |
| `id_variable` | Unique respondent ID column | respondent_id |
| `clustering_vars` | Variables to cluster on | q1,q2,q3,q4,q5 |

### Key Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `k_fixed` | (blank) | Fixed k for final run; blank = exploration |
| `k_min` | 3 | Minimum k to test in exploration |
| `k_max` | 6 | Maximum k to test |
| `missing_data` | listwise_deletion | How to handle missing data |
| `standardize` | TRUE | Standardize variables before clustering |
| `outlier_detection` | FALSE | Enable outlier detection |
| `variable_selection` | FALSE | Enable automatic variable selection |

See [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) for complete parameter list.

---

## Workflow Modes

### Exploration Mode (k_fixed blank)

1. Load & validate data
2. Standardize variables (optional)
3. Test k-means for each k value (k_min to k_max)
4. Calculate validation metrics
5. Export exploration report with recommendations
6. Automated k recommendation based on silhouette

### Final Run Mode (k_fixed specified)

1. Load & validate data
2. Run k-means with specified k
3. Validate solution (segment sizes, silhouette)
4. Profile segments (means, ANOVA tests)
5. Export assignments and comprehensive report
6. Save model for scoring new data

---

## Validation Metrics

| Metric | Range | Good Value | Description |
|--------|-------|------------|-------------|
| Silhouette | -1 to 1 | > 0.5 | Cluster cohesion and separation |
| Within SS | 0+ | Lower is better | Within-cluster variance |
| Between/Total | 0 to 1 | > 0.6 | Separation quality |
| Calinski-Harabasz | 0+ | Higher is better | Cluster separation |

---

## Dependencies

**Required R packages:**
- `stats` (built-in) - kmeans()
- `cluster` - silhouette(), clusGap()
- `readxl` - Excel reading
- `writexl` - Excel writing

**Optional:**
- `haven` - SPSS .sav file support
- `MASS` - Discriminant analysis
- `fmsb` - Spider plots
- `ggplot2` - Enhanced visualizations

---

## Documentation

| Document | Purpose |
|----------|---------|
| [02_SEGMENT_OVERVIEW.md](02_SEGMENT_OVERVIEW.md) | Capabilities and use cases |
| [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) | Statistical methods reference |
| [04_USER_MANUAL.md](04_USER_MANUAL.md) | Complete user guide |
| [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) | Developer documentation |
| [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) | Template field reference |
| [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) | Practical examples |

---

**Part of the Turas Analytics Platform**
