# Pricing Module - Quick Start Guide

## Overview

The TURAS Pricing module analyzes pricing sensitivity using:
- **Van Westendorp PSM** (Price Sensitivity Meter)
- **Gabor-Granger** methodology
- **Segmented Analysis** (NEW in v11.0)
- **Price Ladder Generation** (NEW in v11.0)
- **Recommendation Synthesis** (NEW in v11.0)

## Getting Started

### 1. Prepare Your Data

Your data file (CSV or Excel) should contain:

**For Van Westendorp:**
- `too_cheap`: Price considered too cheap (suspicious quality)
- `bargain`: Price considered a bargain (good value)
- `expensive`: Price considered expensive (but still acceptable)
- `too_expensive`: Price considered too expensive (would not buy)

**For Gabor-Granger:**
- Multiple purchase intent columns at different price points
- Column names should indicate the price (e.g., `purchase_40`, `purchase_50`)

**Optional:**
- Segment variable for segmented analysis
- Demographics or other grouping variables

### 2. Configure Your Analysis

The configuration Excel file should have:
- **Settings** sheet with analysis parameters
- Method-specific sheets (Van_Westendorp, Gabor_Granger)
- Optional: Segmentation settings

### 3. Run Analysis

1. Select your configuration file
2. Select your data file (or use path from config)
3. Click **Run Analysis**
4. Review results in the tabs

### 4. Review Outputs

**Van Westendorp Results:**
- PMC (Point of Marginal Cheapness)
- OPP (Optimal Price Point)
- IDP (Indifference Price Point)
- PME (Point of Marginal Expensiveness)
- Optional: NMS Revenue Optimal price

**Gabor-Granger Results:**
- Demand curve
- Revenue-maximizing price
- Purchase intent at each price point

**New in v11.0:**
- **Segment Comparison**: Compare pricing across customer segments
- **Price Ladder**: Good/Better/Best tier recommendations
- **Synthesis**: Executive summary with confidence assessment

## Tips

- Ensure price questions are answered by all respondents
- Check for outliers in price data
- Use segmentation to understand price sensitivity by customer type
- The recommendation synthesis combines multiple methods for robust pricing

## Need Help?

See the full documentation in `modules/pricing/README.md` or the technical docs in `modules/pricing/TECHNICAL_DOCS.md`.
