# Turas Segmentation Module

**Version:** 11.0
**Last Updated:** 5 March 2026

Multi-algorithm clustering segmentation for survey data with exploration and final run modes, interactive HTML reporting, and executive-ready deliverables.

---

## Overview

The Turas Segmentation Module provides a standardized, repeatable approach to clustering survey respondents into meaningful segments based on behavioral, attitudinal, or satisfaction data.

**Core Capabilities:**
- Multi-algorithm clustering: **K-means**, **Hierarchical (hclust)**, **Gaussian Mixture Models (GMM)**, and **Latent Class Analysis (LCA)**
- Excel-based configuration
- Interactive GUI interface with real-time console output
- Exploration mode (compare multiple k values across all methods)
- Final run mode (detailed output for chosen k and method)
- Interactive HTML reports with SVG charts, pinned views, and slide export
- Executive summary with auto-generated narrative insights
- Outlier detection and handling (Z-score or Mahalanobis)
- Variable selection for high-dimensional data
- Validation metrics (Silhouette, Elbow, Gap statistic, Calinski-Harabasz)
- Multi-method comparison with combined tabbed HTML report
- Segment vulnerability/switching analysis with assignment confidence scores
- Segment profiling, classification rules, and action cards
- Stability assessment for solution robustness
- Segment assignment output (Excel with ID, segment_id, segment_name, and GMM/LCA probabilities)
- Model scoring for new data
- Golden question identification for simplified segment typing
- `merge_segment_to_data()` utility to merge segment assignments back to original data

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
5. **View Results** - See summary, download outputs, and open HTML report

### Using Command Line

**Step 1: Prepare Configuration**

Create `segment_config.xlsx` with a "Config" sheet:

```
parameter        | value
-----------------|---------------------------
data_file        | survey_data.xlsx
id_variable      | respondent_id
clustering_vars  | q1,q2,q3,q4,q5
method           | kmeans
k_min            | 3
k_max            | 6
html_report      | TRUE
output_folder    | output/
```

**Step 2: Run Exploration Mode**

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("segment_config.xlsx")
```

**Step 3: Review and Choose Optimal K**

Open the exploration report (Excel and/or HTML) and review:
- Silhouette scores (higher = better separation)
- Segment sizes (check for very small segments)
- Profile tables for each k

**Step 4: Run Final Segmentation**

Update config: `k_fixed = 4` then re-run.

**Outputs:**
- `seg_assignments.xlsx` - Respondent ID + segment_id + segment_name (+ probabilities if method = gmm or lca)
- `seg_segmentation_report.xlsx` - Comprehensive multi-tab report
- `seg_segmentation_report.html` - Interactive HTML report with SVG charts and navigation
- `seg_model.rds` - Saved model for scoring new data

---

## File Structure

```
modules/segment/
├── R/                                  # Core analysis code
│   ├── 00_main.R                      # Main orchestrator
│   ├── 00_guard.R                     # TRS guard framework
│   ├── 00a_guards_hard.R             # Hard guards (REFUSE)
│   ├── 00b_guards_soft.R             # Soft guards (PARTIAL)
│   ├── 01_config.R                    # Configuration loading/validation
│   ├── 02_data_prep.R                # Data loading and preparation
│   ├── 02a_variable_selection.R      # Variable selection
│   ├── 02b_outliers.R                # Outlier detection and handling
│   ├── 03_clustering.R               # Method dispatcher
│   ├── 03a_kmeans.R                  # K-means clustering engine
│   ├── 03b_hclust.R                  # Hierarchical clustering engine
│   ├── 03c_gmm.R                     # Gaussian Mixture Models engine
│   ├── 04_validation.R               # Validation metrics
│   ├── 05_profiling.R                # Segment profiling
│   ├── 05a_profiling_stats.R         # ANOVA and effect sizes
│   ├── 06_rules.R                    # Classification rules
│   ├── 07_cards.R                    # Segment action cards
│   ├── 08_scoring.R                  # Score new data
│   ├── 09_output.R                   # Excel export functions
│   ├── 10_utilities.R                # Utilities & quick run
│   ├── 11_lca.R                      # Latent Class Analysis
│   ├── 12_executive_summary.R        # Auto-generated narrative summary
│   └── 13_vulnerability.R           # Segment vulnerability/switching analysis
├── lib/                               # Supporting libraries
│   ├── html_report/                   # HTML report pipeline
│   │   ├── 00_html_guard.R           # HTML input validation
│   │   ├── 01_data_transformer.R     # Results to HTML data
│   │   ├── 02_table_builder.R        # HTML table generation
│   │   ├── 03_page_builder.R         # CSS + HTML + JS assembly
│   │   ├── 04_html_writer.R          # Atomic file writer
│   │   ├── 05_chart_builder.R        # SVG chart generation
│   │   ├── 06_exploration_report.R   # Exploration mode report
│   │   ├── 99_html_report_main.R     # HTML report entry point
│   │   └── js/                        # JavaScript modules
│   └── (legacy lib files)
├── run_segment.R                      # Main entry point
├── run_segment_gui.R                  # GUI launcher
├── tests/                             # Module tests
├── test_data/                         # Test datasets
└── docs/                              # Documentation
    ├── 01_README.md                   # This file
    ├── 02_SEGMENT_OVERVIEW.md         # Capabilities overview
    ├── 03_REFERENCE_GUIDE.md          # Statistical methods
    ├── 04_USER_MANUAL.md              # User guide
    ├── 05_TECHNICAL_DOCS.md           # Developer documentation
    ├── 06_TEMPLATE_REFERENCE.md       # Template field reference
    ├── 07_EXAMPLE_WORKFLOWS.md        # Practical examples
    ├── 08_HTML_REPORT_GUIDE.md        # HTML report reference
    └── templates/                     # Config templates
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
| `method` | kmeans | Clustering algorithm: `kmeans`, `hclust`, `gmm`, or comma-separated for multi-method comparison (e.g., `kmeans,hclust,gmm` or `all` which expands to `kmeans,hclust,gmm`). LCA is not a `method` value -- use `use_lca = TRUE` separately. |
| `k_fixed` | (blank) | Fixed k for final run; blank = exploration |
| `k_min` | 3 | Minimum k to test in exploration |
| `k_max` | 6 | Maximum k to test |
| `linkage_method` | ward.D2 | Linkage for hclust: ward.D2, complete, average, etc. |
| `gmm_model_type` | (auto) | GMM covariance structure: VVV, EEE, etc. (NULL = auto) |
| `lca_n_classes` | (from k) | Number of latent classes (requires `use_lca = TRUE`; defaults to k_fixed or k_min:k_max range) |
| `lca_max_iter` | 1000 | Maximum EM iterations for LCA (requires `use_lca = TRUE`) |
| `lca_n_rep` | 10 | Number of random starts for LCA (requires `use_lca = TRUE`) |
| `missing_data` | listwise_deletion | How to handle missing data |
| `standardize` | TRUE | Standardize variables before clustering |
| `outlier_detection` | FALSE | Enable outlier detection |
| `variable_selection` | FALSE | Enable automatic variable selection |
| `html_report` | FALSE | Generate interactive HTML report |
| `brand_colour` | #323367 | Primary brand colour for HTML report |
| `accent_colour` | #CC9900 | Accent colour for HTML report |
| `report_title` | (auto) | Title for HTML report header |
| `generate_rules` | FALSE | Generate classification rules |
| `generate_action_cards` | FALSE | Generate segment action cards |
| `run_stability_check` | FALSE | Run stability assessment |

See [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) for complete parameter list.

---

## Clustering Methods

### Method Comparison

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **K-means** | Default choice, continuous scales | Fast, scalable, well-understood | Assumes spherical clusters |
| **Hierarchical** | Exploring nested structures | Dendrogram, no k needed upfront | O(n^2) memory, max ~15k rows |
| **GMM** | Overlapping segments, soft assignment | Probability-based, handles elliptical clusters | Requires `mclust` package, heavier |
| **LCA** | Categorical/ordinal data (e.g., Likert scales) | Probabilistic, fit indices (AIC/BIC), no normality assumption | Requires `poLCA` package, categorical inputs |

---

## Workflow Modes

### Exploration Mode (k_fixed blank)

1. Load & validate data
2. Standardize variables (optional)
3. Test clustering for each k value (k_min to k_max)
4. Calculate validation metrics
5. Export exploration report with recommendations (Excel + HTML)
6. Automated k recommendation based on silhouette

### Final Run Mode (k_fixed specified)

1. Load & validate data
2. Run clustering with specified k and method
3. Validate solution (segment sizes, silhouette)
4. Profile segments (means, ANOVA tests, effect sizes)
5. Generate enhanced features (rules, cards, stability, executive summary)
6. Export assignments, comprehensive report, and HTML report
7. Save model for scoring new data

---

## Validation Metrics

| Metric | Range | Good Value | Description |
|--------|-------|------------|-------------|
| Silhouette | -1 to 1 | > 0.5 | Cluster cohesion and separation |
| Within SS | 0+ | Lower is better | Within-cluster variance |
| Between/Total | 0 to 1 | > 0.6 | Separation quality |
| Calinski-Harabasz | 0+ | Higher is better | Cluster separation |
| Cophenetic Corr. | 0 to 1 | > 0.7 | Dendrogram fit (hclust only) |
| BIC | varies | Lower is better | Model fit (GMM and LCA) |
| AIC | varies | Lower is better | Model fit (LCA) |
| Entropy R-sq | 0 to 1 | > 0.80 | Classification certainty (LCA) |

---

## Dependencies

**Required R packages:**
- `stats` (built-in) - kmeans(), hclust()
- `cluster` - silhouette(), clusGap()
- `readxl` - Excel reading
- `writexl` - Excel writing
- `openxlsx` - Formatted Excel output
- `htmltools` - HTML report generation

**Optional:**
- `mclust` - Gaussian Mixture Models (required for method = gmm)
- `fastcluster` - Faster hierarchical clustering
- `haven` - SPSS .sav file support
- `MASS` - Discriminant analysis
- `fmsb` - Spider plots
- `ggplot2` - Enhanced visualizations
- `rpart` - Classification rules (decision trees)
- `poLCA` - Latent Class Analysis (required for method = lca; handled gracefully if missing)

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
| [08_HTML_REPORT_GUIDE.md](08_HTML_REPORT_GUIDE.md) | HTML report configuration and usage |

---

**Part of the Turas Analytics Platform**
