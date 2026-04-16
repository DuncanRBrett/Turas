# Portfolio Module

Cross-category brand mapping for multi-category studies. Requires 2+ categories and per-category data from the brand module.

## Quick Start

```r
source("modules/portfolio/R/00_main.R")

# Prepare category-level metrics (from brand module per-category outputs)
cat_metrics <- data.frame(
  Category = c("Frozen Veg", "Ready Meals", "Sauces"),
  Penetration_Pct = c(45, 30, 25),
  MMS = c(0.20, 0.15, 0.10)
)

result <- run_portfolio(cat_metrics, focal_brand = "IPK",
                        category_penetration_matrix = pen_matrix)
```

## Sub-views

| Sub-view | Description |
|----------|-------------|
| Portfolio Map | Focal brand position across categories (configurable axes) |
| Priority Quadrants | Defend / Improve / Expand / Evaluate classification |
| Category TURF | Optimal category combination for maximum consumer reach |

## Configuration

Portfolio is activated via `element_portfolio = Y` in Brand_Config.xlsx. Requires 2+ categories in the Categories sheet. Axis metrics are configurable (default: Penetration x MMS).

## File Layout

```
modules/portfolio/
  R/
    00_main.R          -- run_portfolio() entry point
  tests/
    testthat/
      test_portfolio.R -- 29 tests
```

## Dependencies

- shared/lib/turf_engine.R (Category TURF)
- brand module (per-category metrics as input)
