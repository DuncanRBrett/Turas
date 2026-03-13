# MaxDiff Demo Showcase

## Smartphone Feature Prioritization Study

This demo showcases the TURAS MaxDiff Module v11.0 with all features enabled.

### Scenario

A smartphone manufacturer wants to understand which features matter most to consumers. 12 features are tested across 200 respondents using a MaxDiff (Best-Worst Scaling) design.

### Features Demonstrated

1. **Count-based scoring** - Best%, Worst%, BW Score
2. **Aggregate logit model** - Population-level utilities
3. **Hierarchical Bayes** - Individual-level utilities (falls back to approximate HB if cmdstanr unavailable)
4. **TURF analysis** - Portfolio optimization (which combination of features reaches the most consumers)
5. **Anchored MaxDiff** - Must-have threshold from anchor question
6. **Item discrimination** - Identifies universal favorites vs polarizing features
7. **Segment analysis** - By age group and gender
8. **HTML report** - Interactive tabbed report with SVG charts
9. **Interactive simulator** - Head-to-head comparisons, portfolio builder

### How to Run

```r
# From the Turas project root:
setwd("/path/to/Turas")

# Step 1: Generate demo data (only needed once)
source("examples/maxdiff/demo_showcase/generate_demo_data.R")

# Step 2: Create config file (only needed once)
source("examples/maxdiff/demo_showcase/create_demo_config.R")

# Step 3: Run the full demo
source("examples/maxdiff/demo_showcase/run_demo.R")
```

### Output Files

After running, check `output/` for:
- `Smartphone_Feature_Priorities_MaxDiff_Results.xlsx` - Excel results
- `Smartphone_Feature_Priorities_MaxDiff_Results.html` - Interactive HTML report
- `Smartphone_Feature_Priorities_MaxDiff_Results_simulator.html` - Interactive simulator

### Synthetic Data Design

- **12 items**: Battery Life, Camera Quality, Screen Size, Price, Brand, Storage, Speed, Water Resistance, 5G, Wireless Charging, Weight, Build Quality
- **200 respondents** with known true utilities
- **3 latent segments**: Tech-Focused (35%), Value-Focused (40%), Design-Focused (25%)
- **Balanced design**: 4 items per task, 12 tasks, 3 versions
- **Anchor question**: Respondents flag "must-have" features
- **Demographics**: Age group (18-34, 35-54, 55+), Gender (M, F)
