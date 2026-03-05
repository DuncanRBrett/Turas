# Turas Segmentation Module - Sales Demo

A complete demonstration of the Turas segmentation module using synthetic telecom/retail customer data. Designed for client-facing presentations to showcase multi-algorithm clustering, automated HTML reporting, and actionable segment insights.

## What This Demo Does

Generates an 800-respondent dataset with 4 embedded customer segments, then runs 4 segmentation analyses to demonstrate the module's capabilities:

| Run | Config File | Method | Mode | Purpose |
|-----|-------------|--------|------|---------|
| 1 | `demo_kmeans_explore.xlsx` | K-means | Exploration (k=3-6) | Determine optimal number of segments |
| 2 | `demo_kmeans_final.xlsx` | K-means | Final (k=4) | Full segmentation with profiles and reports |
| 3 | `demo_hclust_final.xlsx` | Hierarchical | Final (k=4) | Compare algorithms on the same data |
| 4 | `demo_gmm_final.xlsx` | GMM | Final (k=4) | Probabilistic segment membership |

### Synthetic Data Profile

The dataset simulates 4 customer archetypes:

- **Premium Loyalists** (~25%): High satisfaction, strong brand trust, low price sensitivity
- **Price Seekers** (~30%): Below-average satisfaction, very high price sensitivity, low loyalty
- **Digital Enthusiasts** (~20%): High digital engagement, innovation-oriented, tech-savvy
- **Passive Users** (~25%): Average across all metrics, low engagement, churn-prone

12 clustering variables (1-10 scales), 5 demographic variables, and 3 behavioral variables are included with ~3% missing data to simulate real-world conditions.

## How to Run

### From the Turas project root

```r
Sys.setenv(TURAS_ROOT = getwd())
source("examples/segment/demo_showcase/run_demo.R")
```

### From the demo directory

```r
setwd("examples/segment/demo_showcase")
Sys.setenv(TURAS_ROOT = normalizePath("../../.."))
source("run_demo.R")
```

### Step-by-step (manual)

```r
# 1. Generate synthetic data
source("examples/segment/demo_showcase/generate_demo_data.R")

# 2. Create config files
source("examples/segment/demo_showcase/create_demo_configs.R")

# 3. Run individual analyses
Sys.setenv(TURAS_ROOT = getwd())
source("modules/segment/run_segment.R")
turas_segment_from_config("examples/segment/demo_showcase/demo_kmeans_final.xlsx")
```

## Expected Outputs

All outputs are written to the `output/` subdirectory:

| File Pattern | Description |
|-------------|-------------|
| `*_k_selection_report.xlsx` | Exploration mode: metrics for k=3 through k=6 |
| `*_k_selection_report.html` | Interactive HTML version of the k-selection report |
| `*_segmentation_report.xlsx` | Full report: profiles, validation, rules, cards |
| `*_segmentation_report.html` | Interactive HTML report with charts and tables |
| `*_segment_assignments.xlsx` | Per-respondent segment assignments with IDs |
| `*_model.rds` | Serialized model object for scoring new data |

## Key Features Demonstrated

- **Multi-algorithm comparison**: K-means, hierarchical clustering, and GMM on the same dataset
- **Exploration mode**: Automated k-selection with silhouette scores and elbow method
- **Final mode**: Full segment profiling with demographic and behavioral cross-tabulation
- **HTML reports**: Branded, interactive reports ready for client presentations
- **Classification rules**: Decision-tree-based rules for assigning new respondents
- **Segment action cards**: Automated summaries with strategic recommendations
- **Outlier detection**: Mahalanobis distance-based flagging
- **Missing data handling**: Median imputation with configurable thresholds
- **Model persistence**: Saved RDS models for scoring future survey waves

## File Structure

```
demo_showcase/
  generate_demo_data.R       # Synthetic data generator
  create_demo_configs.R      # Config file generator (4 configs)
  run_demo.R                 # Main demo runner (runs all 4 analyses)
  README.md                  # This file
  demo_customer_data.csv     # Generated data (after running)
  demo_kmeans_explore.xlsx   # Config: k-means exploration
  demo_kmeans_final.xlsx     # Config: k-means final
  demo_hclust_final.xlsx     # Config: hierarchical final
  demo_gmm_final.xlsx        # Config: GMM final
  output/                    # Analysis outputs (after running)
```
