# KeyDriver Module Basic Example

**Purpose:** Example for TURAS KeyDriver module (importance analysis, correlation, rankings)

**Sample Size:** 100 respondents

**Variables:**
- `overall_satisfaction` - Outcome variable (5-10 scale)
- `product_quality` - Driver (4-10 scale)
- `customer_service` - Driver (6-9 scale)
- `value_for_money` - Driver (4-8 scale)
- `delivery_speed` - Driver (5-9 scale)
- `website_usability` - Driver (4-8 scale)
- `brand_reputation` - Driver (5-9 scale)

## Expected Results

- **R² :** ~0.98 (high explanatory power)
- **Top driver:** Product Quality (~25% importance)
- **#2 driver:** Customer Service (~23% importance)
- **All correlations:** Very high (r > 0.95) - synthetic data pattern

## Run Test

```r
source("tests/regression/test_regression_keydriver_mock.R")
```

**Expected:** 10 checks pass ✅
