# Test Project: Retail Product (Premium Coffee Maker)

## Overview

**Product:** Premium Automatic Coffee Maker
**Methods:** Van Westendorp + Gabor-Granger (Both)
**Sample Size:** 400 respondents
**VW Range:** $150 - $350
**GG Range:** $180 - $280
**Unit Cost:** $95 (manufacturing + fulfillment)

## Project Features

✅ **Dual Method Analysis** - Both VW and GG in one study
✅ **Profit Optimization** - Unit cost included
✅ **Weighted Analysis** - Representative consumer sample
✅ **3 Segment Variables** - Age, income, coffee consumption
✅ **DK Code Handling** - Codes 98 and 99 (4% of sample)
✅ **Monotonicity Management** - 6% violations in VW data

## Setup Instructions

### 1. Generate Test Data
```r
source("generate_data.R")
```

Creates: `coffee_maker_data.csv` (400 rows with both VW and GG columns)

### 2. Create Excel Config
```r
source("create_config.R")
```

Creates: `config_retail.xlsx` (method = "both")

### 3. Run Analysis via GUI

1. Launch Turas → Pricing → GUI
2. Select `config_retail.xlsx`
3. Click "Run Analysis"
4. Review both VW and GG results across tabs

## Expected Results

### Van Westendorp:
- **PMC:** ~$155-165
- **OPP:** ~$195-205
- **IDP:** ~$240-250
- **PME:** ~$280-295
- **Acceptable Range:** $155-295
- **Optimal Range:** $195-250

### Gabor-Granger:
- **Revenue-Max Price:** ~$240-250
- Purchase intent: ~38%
- **Profit-Max Price:** ~$220-230
- Purchase intent: ~51%
- Margin at profit-max: ~$125-135

### Method Comparison:
- VW suggests $195-250 range
- GG profit-max of $220-230 falls within VW optimal range ✓
- Strong methodological agreement
- **Recommendation:** $220-230 based on convergence

## What This Tests

- ✓ **Dual method analysis** (VW + GG)
- ✓ Method comparison and convergence
- ✓ Van Westendorp with weighting
- ✓ Gabor-Granger with profit optimization
- ✓ Both DK codes (98 and 99)
- ✓ Monotonicity in both methods
- ✓ Comprehensive segment variables
- ✓ Complete output suite (VW + GG sheets)
- ✓ All visualization types

## Output Files

**Excel Sheets (Complete Set):**
- Summary - Project overview
- **VW_Price_Points** - PSM results
- VW_Curves, VW_Descriptives, VW_Confidence_Intervals
- **GG_Demand_Curve** - Purchase intent by price
- **GG_Revenue_Curve** - Revenue & profit data
- **GG_Optimal_Revenue** - Revenue-maximizing
- **GG_Optimal_Profit** - Profit-maximizing + comparison
- Validation - Full diagnostics
- Configuration - All settings

**Plots (Full Set):**
- van_westendorp.png - PSM chart with ranges
- demand_curve.png - GG demand
- revenue_curve.png - Revenue optimization
- profit_curve.png - Profit optimization
- revenue_vs_profit.png - Comparison

## Method Convergence Analysis

| Method | Lower Bound | Upper Bound | Midpoint |
|--------|-------------|-------------|----------|
| VW Optimal Range | $195 | $250 | $222.50 |
| GG Profit-Max | - | - | ~$225 |
| **Agreement** | ✓ | ✓ | **Excellent** |

Strong convergence indicates:
- Consistent consumer perceptions
- Reliable pricing recommendation
- Both methods point to same strategic range
- Confidence in $220-230 recommendation

## Profit Analysis

Assumes 50,000 annual unit market:

| Price | Intent | Volume | Revenue | Margin | Profit |
|-------|--------|--------|---------|--------|--------|
| $250 (Rev-Max) | 38% | 19,000 | $4.75M | $155 | $2.95M |
| $225 (Profit-Max) | 51% | 25,500 | $5.74M | $130 | **$3.32M** |

**Profit gain:** $370k (+12.5%) by choosing profit-max over revenue-max

## Strategic Recommendations

**Pricing Strategy:** $220-230
- Within VW optimal range ($195-250)
- At GG profit-maximizing price
- Strong method convergence
- Maximizes profitability

**Supporting Evidence:**
1. VW shows this is perceived as "optimal value"
2. GG confirms 51% purchase intent sustainable
3. Profit analysis shows $370k annual gain vs. revenue-max
4. Consumer segments all support this range

**Implementation:**
- Launch at $229 (psychological pricing)
- Monitor actual sales vs. projected 51% intent
- A/B test $219 vs. $229 if volume lower than expected
- Premium positioning justified by VW results

## Notes

- Realistic premium coffee maker market data
- Dual method provides validation (both point to same range)
- Unit cost of $95 is typical for premium appliances
- Weighted for representative consumer demographics
- Coffee consumption is relevant segment (Heavy users more price-insensitive)

## Advanced Analysis Ideas

After initial run, try:

1. **Segment Analysis:**
   - Compare Heavy vs. Light coffee consumers
   - Income bracket differences
   - Age group sensitivities

2. **Sensitivity Analysis:**
   - Change unit cost ($85, $95, $105)
   - Remove weighting to see impact
   - Try different monotonicity behaviors

3. **Method Comparison:**
   - Disable GG (method = "van_westendorp")
   - Disable VW (method = "gabor_granger")
   - Compare standalone vs. combined insights

4. **Output Customization:**
   - Change plot formats (PDF, SVG)
   - Modify bootstrap iterations (500, 2000)
   - Test CSV vs. XLSX output

## Next Steps

1. Review convergence between VW and GG
2. Examine profit vs. revenue trade-offs
3. Check segment differences (if future feature enabled)
4. Use this as template for your own dual-method studies
