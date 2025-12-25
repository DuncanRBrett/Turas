# Example 1: Design Weights (B2B Customer Survey)

## Overview
This example demonstrates **design weighting** for a stratified sample where the sampling frame is known but the sample distribution doesn't match the population.

## Scenario
A B2B customer satisfaction survey targeting companies of different sizes:
- **Population:** 10,000 companies (50% Small, 35% Medium, 15% Large)
- **Sample:** 300 companies (70% Small, 25% Medium, 5% Large)
- **Issue:** Small companies were easier to recruit, causing sampling bias

## Files
- `data/customer_survey.csv` - Survey responses (300 respondents)
- `Weight_Config.xlsx` - Weighting configuration
- `output/` - Output directory (created when running)

## How to Run

```r
# From R console
setwd("path/to/example1_design_weights")
source("../../run_weighting.R")

result <- run_weighting("Weight_Config.xlsx")

# View results
head(result$data)
result$weight_results$company_size_weight$diagnostics
```

## What This Example Shows

### Design Weight Calculation
- **Purpose:** Correct for known sampling bias by company size
- **Method:** Each respondent gets a weight based on their stratum (company size)
- **Formula:** Weight = (Population % / Sample %) × mean normalization

### Expected Results
- Small companies: Lower weights (over-sampled)
- Large companies: Higher weights (under-sampled)
- Total weighted n = 10,000 (population total)

### Key Learnings
1. Design weights correct for known stratification bias
2. Requires population sizes for each stratum
3. Works best when strata are clearly defined
4. No iteration required (direct calculation)

## Configuration Details

### General Settings
- Project: B2B_Customer_Survey
- Data: `data/customer_survey.csv` (relative path)
- Output: `output/customer_survey_weighted.csv`
- Diagnostics: Enabled

### Weight Specification
- **Name:** company_size_weight
- **Method:** design
- **Trimming:** Not applied (N)
- **Population Total:** 10,000 companies

### Design Targets
| Stratum Variable | Category | Population Size | Sample % | Population % |
|-----------------|----------|-----------------|----------|--------------|
| company_size    | Small    | 5,000          | 70%      | 50%         |
| company_size    | Medium   | 3,500          | 25%      | 35%         |
| company_size    | Large    | 1,500          | 5%       | 15%         |

## Moving to OneDrive
All paths are relative - you can move this entire folder anywhere and it will work.
Just update the `setwd()` path when running.
