# MaxDiff Demo Showcase

## Smartphone Feature Prioritization Study

This demo showcases the TURAS MaxDiff Module v11.0 with every feature enabled. It uses synthetic data with known true utilities so you can validate results against ground truth.

### Quick Start

```r
# From the Turas project root:
setwd("/path/to/Turas")

# Option A: Run everything in one step (auto-generates data and config if missing)
source("examples/maxdiff/demo_showcase/run_demo.R")

# Option B: Run each step manually
source("examples/maxdiff/demo_showcase/generate_demo_data.R")   # Step 1: Generate data
source("examples/maxdiff/demo_showcase/create_demo_config.R")   # Step 2: Create config
source("examples/maxdiff/demo_showcase/run_demo.R")             # Step 3: Run analysis
```

### Features Demonstrated

| Feature | Config Setting | Description |
|---------|---------------|-------------|
| Count-based scoring | Generate_Count_Scores = YES | Best%, Worst%, BW Score |
| Aggregate logit | Generate_Aggregate_Logit = YES | Population-level MNL utilities |
| Hierarchical Bayes | Generate_HB_Model = YES | Individual-level utilities via HB |
| Segment tables | Generate_Segment_Tables = YES | Breakdowns by Age Group and Gender |
| SVG charts | Generate_Charts = YES | Bar charts, discrimination plots |
| HTML report | Generate_HTML_Report = YES | Interactive tabbed report |
| Interactive simulator | Generate_Simulator = YES | Head-to-head comparisons, portfolio builder |
| TURF analysis | Generate_TURF = YES | Portfolio optimization (max 8 items) |
| Anchored MaxDiff | Has_Anchor_Question = YES | Must-have threshold from anchor question |
| Individual utilities | Export_Individual_Utils = YES | Per-respondent utility estimates |
| Weighted analysis | Weight_Variable = Weight | Respondent-level weights (0.5 to 2.0) |
| Brand styling | Brand_Colour / Accent_Colour | Custom colours for reports and charts |

### cmdstanr Is Optional

The HB estimation works in two modes:

- **With cmdstanr installed**: Full Bayesian HB estimation using Stan (best quality, slower)
- **Without cmdstanr**: Approximate HB fallback (fast, good quality for most use cases)

The demo runs successfully either way. Install cmdstanr only if you need publication-quality HB estimates.

### Synthetic Data Design

- **12 smartphone features** tested via MaxDiff (Best-Worst Scaling)
- **200 respondents** with known true utilities for validation
- **10 tasks** per respondent, **4 items per task**, **3 design versions**
- **3 latent segments**: Tech-Focused (35%), Value-Focused (40%), Design-Focused (25%)
- **Weight variable**: Random weights between 0.5 and 2.0 (correlated with demographics)
- **Anchor question**: Comma-separated list of "must-have" item IDs per respondent
- **Demographics**: Age group (18-34, 35-54, 55+), Gender (Male, Female)

### Input Files

| File | Description |
|------|-------------|
| `demo_data.csv` | Survey responses with weights and anchor column |
| `demo_design.xlsx` | Experimental design matrix (3 versions x 10 tasks) |
| `Demo_MaxDiff_Config.xlsx` | Full configuration with all features enabled |
| `true_utilities.csv` | Known true utilities per respondent (for validation) |
| `segment_truth.csv` | True segment assignments (for validation) |

### Expected Output Files

After running, check the `output/` subdirectory for:

| File | Description |
|------|-------------|
| `*_MaxDiff_Results.xlsx` | Excel workbook with all results (scores, utilities, segments) |
| `*_MaxDiff_Results.html` | Interactive HTML report with tabbed navigation and SVG charts |
| `*_MaxDiff_Results_simulator.html` | Interactive simulator for head-to-head and portfolio analysis |
| `*_individual_utilities.csv` | Per-respondent HB utility estimates |

### Validation

The `true_utilities.csv` and `segment_truth.csv` files contain the ground truth used to generate the synthetic data. You can compare estimated utilities against true values to assess model recovery:

```r
# After running the demo:
true <- read.csv("examples/maxdiff/demo_showcase/true_utilities.csv")
# Compare with results$hb_results$individual_utilities
```
