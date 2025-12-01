# Test Project: SaaS Subscription

## Overview

**Product:** Business Software Subscription
**Method:** Gabor-Granger with Profit Optimization
**Sample Size:** 350 respondents
**Price Range:** $25 - $55 per month
**Unit Cost:** $18 per month (server, support, licensing)

## Project Features

✅ **Profit Optimization** - Revenue-max vs. Profit-max comparison
✅ **Weighted Analysis** - Survey weights for B2B sample
✅ **7 Price Points** - Comprehensive demand curve
✅ **Segment Variables** - Age, company size, industry
✅ **DK Code Handling** - Code 99 for "Prefer not to answer" (3%)
✅ **Monotone Smoothing** - Ensures downward-sloping demand

## Setup Instructions

### 1. Generate Test Data
```r
source("generate_data.R")
```

Creates: `saas_subscription_data.csv` (350 rows)

### 2. Create Excel Config
```r
source("create_config.R")
```

Creates: `config_saas.xlsx` (includes unit_cost = $18)

### 3. Run Analysis via GUI

1. Launch Turas → Pricing → GUI
2. Select `config_saas.xlsx`
3. **Important:** Unit cost of $18 is already in config
4. Click "Run Analysis"
5. Check "Additional Plots" tab for profit curves

## Expected Results

**Revenue-Maximizing Price:** ~$40-42/month
- Purchase intent: ~43%
- Revenue index: ~17.2

**Profit-Maximizing Price:** ~$35-37/month
- Purchase intent: ~58%
- Margin: ~$17-19
- Profit index: ~9.8-10.2

**Key Finding:** Profit-max price is $5-7 lower than revenue-max

## What This Tests

- ✓ Gabor-Granger demand curve (7 price points)
- ✓ Revenue optimization
- ✓ **Profit optimization** (Phase 2 feature)
- ✓ Revenue vs. Profit comparison
- ✓ Margin analysis
- ✓ Survey weighting for B2B sample
- ✓ Demand curve smoothing (monotonicity)
- ✓ Bootstrap confidence intervals
- ✓ Profit curve visualization

## Output Files

**Excel Sheets:**
- GG_Demand_Curve - Purchase intent by price
- GG_Revenue_Curve - Revenue optimization (includes profit columns)
- **GG_Optimal_Revenue** - Revenue-maximizing price
- **GG_Optimal_Profit** - Profit-maximizing price + comparison table
- Validation - Sample statistics, weight summary

**Plots:**
- demand_curve.png - Classic GG demand curve
- revenue_curve.png - Revenue optimization
- **profit_curve.png** - Profit optimization (purple)
- **revenue_vs_profit.png** - Side-by-side comparison

## Profit Analysis Interpretation

| Metric | Revenue-Max | Profit-Max | Impact |
|--------|-------------|------------|--------|
| Price | $40-42 | $35-37 | -$5 to -$7 |
| Intent | ~43% | ~58% | +15pp |
| Volume* | 43,000 | 58,000 | +15,000 |
| Margin | $22-24 | $17-19 | -$5 |
| Profit* | $946k-1,032k | $986k-1,102k | **+$40k-70k** |

*Assumes 100,000 addressable market

**Recommendation:** Choose $35-37 profit-maximizing price for +4-7% profit

## Notes

- Realistic SaaS pricing (modeled after actual B2B software)
- Unit cost includes: servers ($8), support ($6), licensing ($4)
- Lower price → higher adoption → more total profit
- Common pattern in subscription businesses
- B2B samples often have non-response codes (99)

## Strategic Implications

**Choose Revenue-Max ($40-42) if:**
- Market share is strategic priority
- Building customer base for upsells
- Land-and-expand strategy
- Network effects important

**Choose Profit-Max ($35-37) if:**
- Profitability is primary goal
- Support capacity is limited  
- Customer acquisition cost is high
- Maximizing ARPU

## Next Steps

1. Try disabling profit optimization (remove unit_cost) to see revenue-only
2. Experiment with different unit costs ($15, $20, $25)
3. Compare weighted vs. unweighted results
4. Try "flag_only" smoothing to see raw demand curve
