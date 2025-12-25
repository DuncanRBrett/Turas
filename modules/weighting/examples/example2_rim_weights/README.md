# Example 2: Rim Weights (Consumer Panel)

## Overview
This example demonstrates **rim weighting (raking)** for a non-probability sample where multiple demographic variables need adjustment to match population targets.

## Scenario
A consumer panel study with demographic biases:
- **Sample:** 500 panelists with known demographic skews
- **Issue:** Panel over-represents females, older adults, and urban residents
- **Solution:** Rim weighting to match census demographics

## Files
- `data/consumer_panel.csv` - Panel responses (500 panelists)
- `Weight_Config.xlsx` - Weighting configuration
- `output/` - Output directory (created when running)

## How to Run

```r
# From R console
setwd("path/to/example2_rim_weights")
source("../../run_weighting.R")

result <- run_weighting("Weight_Config.xlsx")

# View results
head(result$data)
result$weight_results$population_weight$diagnostics

# Check convergence
result$weight_results$population_weight$rim_result$converged
```

## What This Example Shows

### Rim Weighting Process
- **Purpose:** Adjust for demographic bias across multiple variables
- **Method:** Iterative proportional fitting (raking)
- **Variables:** Age (6 categories), Gender (2), Region (3)

### Expected Results
- Males: Higher weights (under-represented in sample)
- Younger respondents: Higher weights (panel skews older)
- Rural residents: Higher weights (panel is more urban)
- Convergence: Should achieve within 15-20 iterations

### Key Learnings
1. Rim weights handle multiple demographic variables simultaneously
2. Requires population percentages (targets must sum to 100% per variable)
3. Iterative process - may require tuning max_iterations
4. Weight trimming helps prevent extreme weights
5. Best for 2-5 demographic variables

## Configuration Details

### General Settings
- Project: Consumer_Panel_Study
- Data: `data/consumer_panel.csv` (relative path)
- Output: `output/consumer_panel_weighted.csv`
- Diagnostics: Enabled

### Weight Specification
- **Name:** population_weight
- **Method:** rim
- **Trimming:** Cap at 4.0 (prevents extreme weights)
- **Population Total:** Not set (proportional weighting only)

### Rim Targets

#### Age Distribution
| Category | Sample % | Target % | Adjustment Needed |
|----------|----------|----------|-------------------|
| 18-24    | 10%      | 13%      | Up-weight         |
| 25-34    | 15%      | 18%      | Up-weight         |
| 35-44    | 20%      | 17%      | Down-weight       |
| 45-54    | 25%      | 17%      | Down-weight       |
| 55-64    | 20%      | 16%      | Down-weight       |
| 65+      | 10%      | 19%      | Up-weight         |

#### Gender Distribution
| Category | Sample % | Target % | Adjustment Needed |
|----------|----------|----------|-------------------|
| Male     | 35%      | 49%      | Up-weight         |
| Female   | 65%      | 51%      | Down-weight       |

#### Region Distribution
| Category | Sample % | Target % | Adjustment Needed |
|----------|----------|----------|-------------------|
| Urban    | 55%      | 35%      | Down-weight       |
| Suburban | 30%      | 45%      | Up-weight         |
| Rural    | 15%      | 20%      | Up-weight         |

### Advanced Settings
- **Max Iterations:** 30
- **Convergence Tolerance:** 0.01 (1%)
- **Force Convergence:** No (fail if doesn't converge)

## Moving to OneDrive
All paths are relative - you can move this entire folder anywhere and it will work.
Just update the `setwd()` path when running.
