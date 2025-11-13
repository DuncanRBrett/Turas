# Turas Segmentation Module

K-means clustering segmentation for survey data with exploration and final run modes.

## Overview

The Turas Segmentation Module provides a standardized, repeatable approach to clustering survey respondents into meaningful segments based on behavioral, attitudinal, or satisfaction data.

**Phase 1 Features:**
- K-means clustering with automatic k selection
- Excel-based configuration
- Exploration mode (compare multiple k values)
- Final run mode (detailed output for chosen k)
- Validation metrics (silhouette, elbow, optional gap statistic)
- Segment profiling and characterization
- Excel output reports

## Quick Start

### 1. Prepare Your Configuration

Create an Excel file (`segment_config.xlsx`) with a "Config" sheet containing:

```
parameter                | value
-------------------------|---------------------------
data_file                | survey_data.xlsx
id_variable              | respondent_id
clustering_vars          | q1,q2,q3,q4,q5
k_min                    | 3
k_max                    | 6
output_folder            | output/
```

See `turas_segmentation_module_specs.md` for complete configuration options.

### 2. Run Exploration Mode

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("segment_config.xlsx")
```

This tests k=3 through k=6 and outputs `k_selection_report.xlsx`.

### 3. Review and Choose Optimal K

Open the k selection report and review:
- Silhouette scores (higher = better separation)
- Segment sizes (check for very small segments)
- Profile tables for each k

### 4. Run Final Segmentation

Update your config file:
```
k_fixed                  | 4
```

Run again:
```r
result <- turas_segment_from_config("segment_config.xlsx")
```

**Outputs:**
- `segment_assignments.xlsx` - Respondent ID + segment assignment
- `segmentation_report.xlsx` - Comprehensive multi-tab report
- `model.rds` - Saved model object

## File Structure

```
modules/segment/
├── lib/
│   ├── segment_config.R        # Configuration loading/validation
│   ├── segment_data_prep.R     # Data loading and preparation
│   ├── segment_kmeans.R        # K-means clustering engine
│   ├── segment_validation.R    # Validation metrics
│   ├── segment_profile.R       # Segment profiling
│   └── segment_export.R        # Excel export functions
├── run_segment.R               # Main entry point
├── README.md                   # This file
└── turas_segmentation_module_specs.md  # Complete specifications

```

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
| `segment_names` | auto | Custom segment names (comma-separated) |

See specifications document for complete list.

## Workflow

### Exploration Mode (k_fixed blank)

1. **Load & validate data** - Check for missing data, validate variables
2. **Standardize** - Z-score standardization (optional but recommended)
3. **Run k-means** - Test each k value from k_min to k_max
4. **Calculate metrics** - Silhouette, WSS, between/total SS ratio
5. **Export report** - Multi-tab Excel with metrics and profiles
6. **Recommend k** - Automated recommendation based on silhouette

### Final Run Mode (k_fixed specified)

1. **Load & validate data** - Same as exploration
2. **Run k-means** - Single run with fixed k
3. **Validate solution** - Check segment sizes, calculate silhouette
4. **Profile segments** - Calculate means, run ANOVA tests
5. **Export outputs** - Assignments + comprehensive report
6. **Save model** - RDS file for reproducibility

## Integration with Other Modules

### Join Segments Back to Data

```r
library(dplyr)

# Original survey data
survey_data <- readxl::read_excel("survey_data.xlsx")

# Segment assignments
segments <- readxl::read_excel("output/seg_segment_assignments.xlsx")

# Join
survey_with_segments <- left_join(survey_data, segments, by = "respondent_id")
```

### Use with Tabs Module

```r
# After joining segments to data, use tabs module for crosstabs by segment
# (Integration code TBD - future enhancement)
```

## Dependencies

**Required R packages:**
- `stats` (built-in) - kmeans()
- `cluster` - silhouette(), clusGap()
- `readxl` - Excel reading
- `writexl` - Excel writing

**Optional:**
- `data.table` - Faster CSV loading
- `haven` - SPSS .sav file support

## Validation Metrics

### Silhouette Score
- Range: -1 to 1
- **>0.7**: Strong structure
- **>0.5**: Good structure ← Recommended minimum
- **>0.3**: Acceptable structure
- **<0.3**: Weak/artificial structure

### Between/Total SS Ratio
- Range: 0 to 1
- Higher = better separation
- Typical good values: >0.6

### Gap Statistic
- Compares clustering to random data
- Computationally expensive
- Optional in config

## Troubleshooting

### "Sample size insufficient"
- Need at least 50 observations per potential cluster
- Reduce `k_max` or get more data

### "Variable has zero variance"
- Remove constant variables from `clustering_vars`

### "Smallest segment below threshold"
- Reduce k or lower `min_segment_size_pct`
- Very small segments may not be meaningful

### High missing data warning
- Check data quality
- Consider `missing_data = mean_imputation`
- Or increase `missing_threshold`

## Version History

- **V1.0** (2025-11-13) - Initial Phase 1 release
  - K-means clustering
  - Exploration and final modes
  - Basic Excel outputs
  - Silhouette and elbow metrics
  - Optional gap statistic

## Future Enhancements (Phase 2+)

- Additional clustering methods (PAM, hierarchical, latent class)
- Mixed data types (categorical + continuous)
- Temporal tracking (segment classification across waves)
- Auto-generated segment names based on characteristics
- Enhanced Excel formatting
- Interactive Shiny app
- Integration with tabs module for automated crosstabs

## Support

For issues or questions:
1. Review the complete specifications: `turas_segmentation_module_specs.md`
2. Check the troubleshooting section above
3. Ensure all dependencies are installed

---

**Part of the Turas Analytics Platform**
Version 1.0 | November 2025
