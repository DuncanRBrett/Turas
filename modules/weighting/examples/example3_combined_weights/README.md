# Example 3: Combined Design + Rim Weights (Market Research Study)

## Overview
This example demonstrates using **both design weights and rim weights** together in a single study - a common approach in market research.

## Scenario
A national market research study with two weighting needs:
1. **Regional stratification** - Sample distribution doesn't match regional population
2. **Demographic adjustment** - Within regions, demographics don't match targets

## Files
- `data/market_research.csv` - Survey responses (600 respondents)
- `Weight_Config.xlsx` - Configuration with both weight types
- `output/` - Output directory (created when running)

## How to Run

```r
# From R console
setwd("path/to/example3_combined_weights")
source("../../run_weighting.R")

result <- run_weighting("Weight_Config.xlsx")

# View both weights
head(result$data[, c("respondent_id", "region", "age_group", "gender",
                     "regional_weight", "demographic_weight")])

# Compare diagnostics
result$weight_results$regional_weight$diagnostics
result$weight_results$demographic_weight$diagnostics
```

## What This Example Shows

### Two-Stage Weighting
1. **Stage 1 - Design Weight:** Correct regional sampling bias
   - Adjusts for over/under-sampling of geographic regions
   - Uses known population sizes by region

2. **Stage 2 - Rim Weight:** Demographic adjustment
   - Corrects age and gender within the already-weighted sample
   - Uses iterative proportional fitting

### Expected Results
- **regional_weight:** Higher for West (under-sampled), lower for North (over-sampled)
- **demographic_weight:** Adjusts for age/gender independent of region
- **Combined effect:** Apply both weights in analysis (multiply if needed)

### Key Learnings
1. Can calculate multiple weights for different purposes
2. Design weights correct known stratification issues
3. Rim weights handle demographic imbalances
4. Analyze using the appropriate weight for each research question
5. Document clearly which weight to use when

## Configuration Details

### General Settings
- Project: Market_Research_Study
- Data: `data/market_research.csv` (relative path)
- Output: `output/market_research_weighted.csv`
- Diagnostics: Enabled

### Weight Specifications

#### 1. Regional Weight (Design)
- **Name:** regional_weight
- **Method:** design
- **Purpose:** Correct regional sampling bias
- **Trimming:** Not applied
- **Population Total:** 50,000

#### 2. Demographic Weight (Rim)
- **Name:** demographic_weight
- **Method:** rim
- **Purpose:** Match age and gender demographics
- **Trimming:** 95th percentile (removes extreme outliers)

### Design Targets (Regional Population)
| Region | Sample % | Population % | Population Size |
|--------|----------|--------------|-----------------|
| North  | 40%      | 30%          | 15,000         |
| South  | 30%      | 35%          | 17,500         |
| East   | 20%      | 25%          | 12,500         |
| West   | 10%      | 10%          | 5,000          |

### Rim Targets (Demographics)

#### Age Groups
| Category | Sample % | Target % |
|----------|----------|----------|
| 18-34    | 25%      | 35%      |
| 35-54    | 50%      | 40%      |
| 55+      | 25%      | 25%      |

#### Gender
| Category | Sample % | Target % |
|----------|----------|----------|
| Male     | 45%      | 48%      |
| Female   | 53%      | 50%      |
| Other    | 2%       | 2%       |

## When to Use Each Weight

### Use regional_weight when:
- Analyzing regional differences
- Reporting national totals that need regional representation
- Geographic-based segmentation

### Use demographic_weight when:
- Analyzing demographic segments (age, gender)
- National averages where demographics matter more than geography
- Behavioral/attitudinal analysis

### Use both (multiplied) when:
- Need both regional AND demographic correction
- Final national projections
- Most rigorous population estimates

## Moving to OneDrive
All paths are relative - you can move this entire folder anywhere and it will work.
Just update the `setwd()` path when running.

## Advanced: Creating a Combined Weight

If you need a single weight combining both effects:

```r
# After running the weighting
weighted_data <- result$data
weighted_data$combined_weight <- weighted_data$regional_weight * weighted_data$demographic_weight

# Normalize to mean=1
weighted_data$combined_weight <- weighted_data$combined_weight / mean(weighted_data$combined_weight)

# Use in analysis
weighted.mean(weighted_data$satisfaction, weighted_data$combined_weight)
```
