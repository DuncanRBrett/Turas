# Example 4: Cell (Interlocked) Weights

This example demonstrates cell weighting, which adjusts for joint distributions of two or more variables simultaneously.

## Scenario

A consumer survey (n=300) where the **joint distribution** of Gender x Age is skewed compared to the population. Young males are particularly under-represented.

Unlike rim weighting (which adjusts marginal distributions independently), cell weighting matches the exact cross-tabulation of Gender x Age.

## Files

```
example4_cell_weights/
  Weight_Config.xlsx    <- Configuration (will be generated)
  data/
    consumer_panel.csv  <- Survey data (will be generated)
  output/               <- Weighted data appears here after running
  README.md             <- This file
```

## Running the Example

### Step 1: Generate test data and config

```r
source("modules/weighting/examples/example4_cell_weights/create_example.R")
```

### Step 2: Run weighting

```r
source("modules/weighting/run_weighting.R")
result <- run_weighting("modules/weighting/examples/example4_cell_weights/Weight_Config.xlsx")
```

### Step 3: Check results

```r
# View weight diagnostics
result$weight_results$cell_weight$diagnostics

# Compare sample vs weighted distributions
table(result$data$Gender, result$data$Age)
```

## When to Use Cell Weighting

**Use cell weighting when:**
- The joint distribution matters (not just marginals)
- Specific combinations are under/over-represented (e.g., young males)
- You have known population cross-tabulations (e.g., census data)

**Use rim weighting instead when:**
- You have many variables (cell weighting with 3+ variables creates many cells)
- Some cells have very few respondents (< 5)
- You only know marginal distributions, not joint distributions

## Key Considerations

- All target_percent values must sum to 100
- Every cell combination must have at least one respondent
- Small cells (n < 5) produce very high weights - consider collapsing categories
- With 3+ variables, the number of cells can explode (e.g., 5 ages x 2 genders x 4 regions = 40 cells)
