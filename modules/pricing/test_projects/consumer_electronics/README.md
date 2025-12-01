# Test Project: Consumer Electronics (Smart Speaker)

## Overview

**Product:** Smart Speaker with AI Assistant
**Method:** Van Westendorp Price Sensitivity Meter
**Sample Size:** 300 respondents
**Price Range:** $80 - $180 (typical range for premium smart speakers)

## Project Features

✅ **Weighted Analysis** - Survey weights included (realistic sampling variation)
✅ **Segment Variables** - Age, income, region  
✅ **DK Code Handling** - Code 98 for "Don't know" responses (5% of sample)
✅ **Monotonicity Violations** - 8% of respondents have non-monotonic answers
✅ **Bootstrap CI** - 1000 iterations for confidence intervals

## Setup Instructions

### 1. Generate Test Data
```r
# From this directory (test_projects/consumer_electronics/)
source("generate_data.R")
```

This creates: `smart_speaker_data.csv` (300 rows)

### 2. Create Excel Config
```r
source("create_config.R")
```

This creates: `config_electronics.xlsx`

### 3. Run Analysis via GUI

1. Launch Turas → Pricing → GUI
2. Select `config_electronics.xlsx`
3. Click "Run Analysis"
4. Review results in tabs

## Expected Results

**Acceptable Range:** ~$85 - $155
**Optimal Range:** ~$105 - $135
**Recommendation:** Price between $105-$135

**Sample Statistics:**
- Total: 300
- Valid: ~270-280 (after exclusions)
- Excluded: ~20-30 (DK codes + monotonicity violations)

## What This Tests

- ✓ Van Westendorp analysis with 4 price questions
- ✓ Survey weighting application
- ✓ DK code recoding and exclusion  
- ✓ Monotonicity violation detection and handling
- ✓ Bootstrap confidence intervals
- ✓ Segment variable inclusion (ready for future analysis)
- ✓ Excel output generation
- ✓ PSM visualization

## Validation Sheet Contents

- **Weight Statistics:** Min, max, mean, SD of weights
- **Exclusion Breakdown:** Count by reason (DK codes, monotonicity)
- **Monotonicity Violations:** 8% flagged, action = "flag_only"

## Notes

- Realistic smart speaker market data (modeled after actual products)
- Weights represent post-stratification to match target demographics
- DK responses common for expensive electronics (quality uncertainty)
- Monotonicity violations reflect survey fatigue / confusion
- Bootstrap may take 1-2 minutes with 1000 iterations

## Next Steps

After reviewing results:
1. Try changing monotonicity behavior to "fix" or "drop"
2. Compare weighted vs. unweighted (remove weight_var in GUI)
3. Disable bootstrap for faster testing (set to FALSE in config)
