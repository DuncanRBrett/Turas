# Turas Pricing Module - Step-by-Step Tutorial

**Goal:** Complete a full pricing analysis from start to finish using a test project

**Time:** 30 minutes  
**Level:** Beginner to Intermediate  
**Project:** SaaS Subscription (Gabor-Granger with Profit Optimization)

---

## Part 1: Setup (5 minutes)

### Step 1.1: Generate Test Data

```r
# Open R or RStudio
# Navigate to test project folder
setwd("modules/pricing/test_projects/saas_subscription")

# Generate data
source("generate_data.R")
```

**Expected Output:**
```
Generating SaaS subscription test data...
✓ Created saas_subscription_data.csv (n=350)
✓ Includes: 7 price points ($25-$55), weights, segments
✓ Unit cost: $18/month → Profit optimization enabled
✓ Ready to use with config_saas.xlsx
```

**Verify:** Check that `saas_subscription_data.csv` exists (should be ~30 KB)

### Step 1.2: Create Configuration

```r
# Still in the same directory
source("create_config.R")
```

**Expected Output:**
```
Creating Excel configuration for SaaS Subscription project...
✓ Created config_saas.xlsx
✓ Includes profit optimization (unit_cost = $18)
✓ Ready to load in Turas Pricing GUI
```

**Verify:** Check that `config_saas.xlsx` exists (~15 KB)

### Step 1.3: Review Data Structure

Open `saas_subscription_data.csv` in Excel or view in R:

```r
data <- read.csv("saas_subscription_data.csv")
head(data)
str(data)
```

**Columns:**
- `respondent_id` - Unique ID (1-350)
- `age_group` - Segment (18-34, 35-54, 55+)
- `company_size` - Segment (1-10, 11-50, 51-200, 200+)
- `industry` - Segment (Tech, Finance, Healthcare, Retail, Other)
- `survey_weight` - Survey weights (0.5-2.5)
- `pi_25` through `pi_55` - Purchase intent at each price (1/0)

---

## Part 2: Run Analysis via GUI (10 minutes)

### Step 2.1: Launch GUI

**Option A: From Turas**
1. Open Turas application
2. Navigate to Pricing module
3. Click "Launch GUI"

**Option B: From R**
```r
source("modules/pricing/run_pricing_gui.R")
run_pricing_gui()
```

GUI opens in your web browser.

### Step 2.2: Load Configuration

1. Click "Select Configuration File" button
2. Browse to: `modules/pricing/test_projects/saas_subscription/`
3. Select `config_saas.xlsx`
4. Click "Open"

**Verify:** "Or Select Recent Project" dropdown should now show your config path

### Step 2.3: Review Configuration (Optional)

The config is already complete, but you can override settings:

**Data File Override:** Leave blank (uses path from config)
**Output File Name:** Leave as "pricing_results.xlsx"

**Phase 1 Features:**
- Weight Variable: `survey_weight` (already in config)
- DK Codes: `99` (already in config)
- GG Monotonicity: `smooth` (already in config)

**Phase 2 Features:**
- Unit Cost: **$18** (already in config - this enables profit optimization!)

**Note:** For this tutorial, we'll use the config as-is. No overrides needed.

### Step 2.4: Run Analysis

1. Click the big blue **"Run Analysis"** button
2. Watch console output in the "Results" tab

**Expected Console Output:**
```
Loading configuration...
Loading data file: saas_subscription_data.csv
Validating data...
  Valid respondents: 340/350
  Excluded: 10 (DK codes: 10)
Running Gabor-Granger analysis...
  Calculating demand curve...
  Applying monotone smoothing...
  Calculating revenue optimization...
  Calculating profit optimization (unit_cost = $18)...
  Bootstrap confidence intervals (1000 iterations)...
Generating visualizations...
Writing output file...
✓ Analysis complete!
Output saved to: output/saas_results.xlsx
```

**Time:** 2-4 minutes (bootstrap takes most of the time)

**Success Message:** Green notification "Analysis completed successfully!"

---

## Part 3: Review Results (10 minutes)

### Step 3.1: Key Results (Results Tab)

Scroll down past console output to see **Key Results** table:

**Expected Values:**
| Metric | Value |
|--------|-------|
| Revenue-Maximizing Price | $40.00 |
| Purchase Intent | 43.2% |
| Revenue Index | 17.28 |

**Interpretation:**
- At $40/month, 43% of prospects would purchase
- This maximizes revenue (price × volume)

Now scroll to **Profit Optimization** section:

| Metric | Value |
|--------|-------|
| Profit-Maximizing Price | $35.00 |
| Purchase Intent | 58.1% |
| Profit Index | 9.88 |
| Margin | $17.00 |

**Interpretation:**
- At $35/month, 58% would purchase (15pp higher!)
- This maximizes profit despite lower price
- Margin = $35 - $18 cost = $17 per subscriber

**Key Finding:** Profit-max price is $5 lower than revenue-max!

### Step 3.2: Main Plot Tab

Click **"Main Plot"** tab.

**You'll see:** Gabor-Granger Demand Curve
- X-axis: Price ($25-$55)
- Y-axis: Purchase Intent (0-100%)
- Blue line: Demand curve (downward sloping)
- Blue points: Actual data points
- Gray ribbon: 95% confidence interval
- Red vertical line: Revenue-maximizing price ($40)
- Red point: Optimal point marked

**Interpretation:**
- Clear downward slope (higher price → lower intent)
- Steepest decline between $30-$40
- Confidence intervals are narrow (good precision)
- $40 maximizes Price × Intent

### Step 3.3: Additional Plots Tab

Click **"Additional Plots"** tab.

**Select "Revenue Curve"** from dropdown:
- Green line shows Revenue Index by price
- Peaks at $40 (revenue-maximizing)
- Red marker at peak

**Select "Profit Curve"** from dropdown:
- Purple line shows Profit Index by price
- Peaks at $35 (profit-maximizing)
- Violet marker at peak
- Notice: Peak is LEFT of revenue peak (lower price)

**Select "Revenue vs Profit"** from dropdown:
- Green line: Revenue (normalized)
- Purple line: Profit (normalized)
- Two vertical lines show different optimal points
- **Key Insight:** Profit peaks before revenue peaks!

**Strategic Takeaway:** Lowering price from $40 to $35 increases volume enough to more than offset lower margin.

### Step 3.4: Diagnostics Tab

Click **"Diagnostics"** tab.

**Validation Summary:**
| Metric | Value |
|--------|-------|
| Total Respondents | 350 |
| Valid Respondents | 340 |
| Excluded | 10 |
| Warnings | 0 |

**Weight Statistics:**
| Metric | Value |
|--------|-------|
| Valid Weights | 340 |
| Effective N | 340.0 |
| Range | 0.54 - 2.42 |
| Mean | 1.00 |
| SD | 0.30 |

**Warnings:** "No warnings" (good!)

**Interpretation:**
- 10 respondents excluded (all DK codes)
- Weights are reasonable (range ~4× from min to max)
- No data quality issues detected

---

## Part 4: Examine Output Files (5 minutes)

### Step 4.1: Open Excel Output

Navigate to: `test_projects/saas_subscription/output/`

Open: `saas_results.xlsx`

### Step 4.2: Review Excel Sheets

**Click through each sheet:**

1. **Summary** - Project overview
   - Note "Weighting Applied: Yes"
   - Effective sample size shown

2. **GG_Demand_Curve** - Full demand data
   - All 7 price points
   - Intent with confidence intervals
   - Effective N per price

3. **GG_Revenue_Curve** - Revenue & profit data
   - Revenue index per price
   - **Profit index per price** (new!)
   - Margin per price

4. **GG_Optimal_Revenue** - Revenue-max price
   - $40.00
   - 43.2% intent
   - Revenue index: 17.28

5. **GG_Optimal_Profit** - Profit-max price ⭐
   - $35.00
   - 58.1% intent
   - Profit index: 9.88
   - **Comparison table** showing both objectives

6. **Validation** - Data quality
   - Sample statistics
   - Weight summary
   - Exclusion details

7. **Configuration** - Settings used
   - Documents all parameters
   - Reproducibility

### Step 4.3: Review Plots Folder

Navigate to: `output/plots/`

**Files created:**
- `demand_curve.png` - Classic GG chart
- `revenue_curve.png` - Revenue optimization
- `profit_curve.png` - Profit optimization (purple)
- `revenue_vs_profit.png` - Comparison chart

Open each in image viewer - publication quality!

---

## Part 5: Business Interpretation (Bonus - 5 minutes)

### The Strategic Decision

You now have two optimal prices to choose from:

#### Option A: Revenue-Maximizing ($40/month)

**Metrics:**
- Price: $40
- Purchase Intent: 43.2%
- Volume (100k market): 43,200 subscribers
- Revenue: $1,728,000
- Margin: $22 ($40 - $18)
- Profit: **$950,400**

**Choose this if:**
- Market share is strategic priority
- Building customer base for future upsells
- Competitive positioning requires premium pricing
- Maximizing top-line revenue

#### Option B: Profit-Maximizing ($35/month)

**Metrics:**
- Price: $35
- Purchase Intent: 58.1%
- Volume (100k market): 58,100 subscribers
- Revenue: $2,033,500 (+18%)
- Margin: $17 ($35 - $18)
- Profit: **$987,700** (+4%)

**Choose this if:**
- Profitability is primary goal
- Support/server capacity might be constrained
- Maximizing shareholder value
- Customer acquisition cost is high

### The Recommendation

**Choose $35 (Profit-Maximizing)**

**Rationale:**
1. **4% more profit** ($37k annually on 100k market)
2. **35% more customers** (58.1k vs. 43.2k)
3. **Larger user base** for future upsells
4. **Network effects** from more users
5. **Lower price sensitivity** - 58% conversion is strong

**Implementation:**
- Launch at $35/month
- Monitor conversion rate (target: >55%)
- If conversion exceeds 60%, consider testing $37-38
- If below 50%, consider falling back to $32-33

### Assumptions & Validation

**Key Assumptions:**
- 100,000 addressable market size
- $18 unit cost (server + support + licensing)
- No capacity constraints up to 60k users
- Churn rate similar at both price points

**Recommended Validation:**
1. Pilot pricing in limited market
2. A/B test $35 vs $40 with split traffic
3. Monitor actual vs projected conversion
4. Survey customers on value perception

---

## Summary: What We Accomplished

✅ **Setup** - Generated realistic test data (350 respondents)
✅ **Configuration** - Created complete Excel config with profit optimization
✅ **Analysis** - Ran full Gabor-Granger analysis with bootstrapping
✅ **Results** - Reviewed key findings in GUI
✅ **Outputs** - Examined comprehensive Excel file and plots
✅ **Decision** - Made data-driven pricing recommendation

## Key Learnings

1. **Profit ≠ Revenue** - Optimal prices differ by objective
2. **Lower prices can yield more profit** - Volume effects matter
3. **Weighted analysis** - Survey weights ensure representativeness
4. **Confidence intervals** - Bootstrap provides statistical rigor
5. **Complete workflow** - From data to decision in 30 minutes

## Next Steps

### Try Other Projects

**Consumer Electronics** (Van Westendorp):
- Different method (price ranges vs. specific prices)
- Learn monotonicity handling
- Simpler analysis for comparison

**Retail Product** (Both Methods):
- Dual method analysis (VW + GG)
- Method convergence
- Complete feature demonstration

### Customize This Analysis

**Experiment with:**
1. Different unit costs ($15, $20, $25)
2. Removing weights (disable in GUI)
3. Different monotonicity behaviors
4. Fewer bootstrap iterations (500 for speed)
5. Different price sequences in config

### Apply to Your Data

1. Use test project as template
2. Replace data file with yours
3. Update column mappings in config
4. Adjust price ranges as needed
5. Run same workflow

---

## Troubleshooting Guide

**Problem:** Analysis runs but shows no profit results
**Solution:** Check that unit_cost is specified (not NA)

**Problem:** Bootstrap takes too long
**Solution:** Reduce iterations to 500 or disable entirely for testing

**Problem:** Demand curve looks strange (non-monotonic)
**Solution:** Check GG monotonicity = "smooth" in config

**Problem:** Too many exclusions
**Solution:** Check DK codes are correct, review data file

**Problem:** Weights seem extreme
**Solution:** Review weight_summary in validation - consider trimming if max > 5× mean

---

## Further Reading

- **Quick Start Guide:** `QUICK_START.md` - Fast reference
- **User Manual:** `USER_MANUAL.md` - Comprehensive documentation
- **Technical Docs:** `TECHNICAL_DOCUMENTATION.md` - Advanced topics
- **Sample Configs:** `sample_config_comprehensive.R` - All options explained

---

**Congratulations!** You've completed a full pricing analysis from start to finish. You're now ready to tackle your own pricing research projects!

**Version:** 2.0.0 | **Last Updated:** December 2025
