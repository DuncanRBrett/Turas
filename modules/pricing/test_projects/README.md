# Turas Pricing Module - Test Projects

Complete real-world test scenarios with synthetic data for learning and testing the pricing module.

## Quick Setup

### Generate All Test Projects

```r
# From R console, in the test_projects/ directory
source("setup_all_projects.R")
```

This will:
1. Generate all test data files (CSV)
2. Create all Excel configuration files
3. Verify all files created successfully

**Time:** ~30 seconds total

## Test Projects Overview

### 1. Consumer Electronics (Smart Speaker)

**File:** `consumer_electronics/`
**Method:** Van Westendorp
**Sample:** 300 respondents
**Features:** Weights, DK codes, monotonicity violations

**Best For Learning:**
- Van Westendorp basics
- Survey weighting
- Data quality issues
- Monotonicity handling

**Setup:**
```r
setwd("consumer_electronics")
source("generate_data.R")
source("create_config.R")
```

**Files Created:**
- `smart_speaker_data.csv` (300 rows)
- `config_electronics.xlsx`

---

### 2. SaaS Subscription

**File:** `saas_subscription/`
**Method:** Gabor-Granger with Profit
**Sample:** 350 respondents
**Features:** 7 price points, profit optimization, B2B segments

**Best For Learning:**
- Gabor-Granger analysis
- **Profit optimization (Phase 2)**
- Revenue vs. profit trade-offs
- Demand curve smoothing

**Setup:**
```r
setwd("saas_subscription")
source("generate_data.R")
source("create_config.R")
```

**Files Created:**
- `saas_subscription_data.csv` (350 rows)
- `config_saas.xlsx`

---

### 3. Retail Product (Premium Coffee Maker)

**File:** `retail_product/`
**Method:** Both (VW + GG)
**Sample:** 400 respondents
**Features:** Dual method, profit optimization, method convergence

**Best For Learning:**
- **Dual method analysis**
- Method comparison
- **Complete feature set**
- Real-world complexity

**Setup:**
```r
setwd("retail_product")
source("generate_data.R")
source("create_config.R")
```

**Files Created:**
- `coffee_maker_data.csv` (400 rows)
- `config_retail.xlsx`

---

## Usage in Turas GUI

### Method 1: Direct Load (Recommended for Testing)

1. Generate project (see setup above)
2. Launch Turas → Pricing → GUI
3. Browse to `config_[project].xlsx`
4. Click "Run Analysis"
5. Review results

### Method 2: Copy to OneDrive (Real-World Testing)

1. Generate all projects: `source("setup_all_projects.R")`
2. Copy entire project folder to OneDrive: 
   ```
   OneDrive/Projects/pricing_tests/consumer_electronics/
   ```
3. In Turas GUI, browse to OneDrive location
4. Select config file
5. Run analysis (data file path is relative, will work)

## Feature Coverage Matrix

| Feature | Electronics | SaaS | Retail |
|---------|:-----------:|:----:|:------:|
| **Method** |
| Van Westendorp | ✓ | - | ✓ |
| Gabor-Granger | - | ✓ | ✓ |
| Both Methods | - | - | ✓ |
| **Phase 1** |
| Survey Weighting | ✓ | ✓ | ✓ |
| DK Code Handling | ✓ | ✓ | ✓ |
| Monotonicity (VW) | ✓ | - | ✓ |
| Monotonicity (GG) | - | ✓ | ✓ |
| Segment Variables | ✓ | ✓ | ✓ |
| **Phase 2** |
| Profit Optimization | - | ✓ | ✓ |
| Revenue vs Profit | - | ✓ | ✓ |
| **Analysis** |
| Bootstrap CI | ✓ | ✓ | ✓ |
| Validation Reports | ✓ | ✓ | ✓ |
| Weight Statistics | ✓ | ✓ | ✓ |

## Learning Path

### Beginner: Start with Consumer Electronics
1. Simple Van Westendorp analysis
2. Learn GUI basics
3. Understand price ranges
4. See data quality handling

### Intermediate: Move to SaaS Subscription
1. Gabor-Granger method
2. **Profit optimization**
3. Revenue vs. profit decisions
4. Demand curve interpretation

### Advanced: Complete with Retail Product
1. Dual method analysis
2. Method convergence
3. Full feature integration
4. Strategic recommendations

## Expected Analysis Time

- **Fast (Testing):** Disable bootstrap, 2-3 minutes per project
- **Production:** Enable bootstrap (1000 iterations), 5-10 minutes per project
- **All Projects:** ~15-30 minutes total

## Output Structure

Each project creates:

```
project_folder/
├── [data].csv                    # Generated data
├── config_[project].xlsx         # Configuration
├── output/                       # Analysis results
│   ├── [prefix]_results.xlsx   # Main Excel output
│   └── plots/                   # Visualizations
│       ├── van_westendorp.png   # (if VW)
│       ├── demand_curve.png     # (if GG)
│       ├── revenue_curve.png    # (if GG)
│       ├── profit_curve.png     # (if profit)
│       └── revenue_vs_profit.png # (if profit)
├── generate_data.R              # Data generator script
├── create_config.R              # Config generator script
└── README.md                    # Project documentation
```

## Customization Ideas

### Modify Sample Sizes
Edit `generate_data.R`:
```r
n <- 500  # Change from 300/350/400
```

### Change Price Ranges
Edit price generation code:
```r
too_cheap = pmax(60, pmin(140, rnorm(n, 90, 20)))  # Adjust min, max, mean, SD
```

### Adjust Weights
Edit weight distribution:
```r
survey_weight = pmax(0.5, pmin(2.0, rnorm(n, 1, 0.3)))  # Narrower range
```

### Add/Remove DK Codes
Edit DK code injection:
```r
dk_indices <- sample(1:n, floor(n * 0.10))  # 10% instead of 5%
```

### Change Profit Optimization
Edit `create_config.R`:
```r
"unit_cost", "25"  # Different cost structure
```

## Troubleshooting

**"Cannot find data file"**
→ Run `generate_data.R` first before running analysis

**"Package 'openxlsx' not found"**
→ Install: `install.packages("openxlsx")`

**Excel file won't open**
→ Make sure openxlsx package is installed and loaded

**Analysis runs but no results**
→ Check console output for errors
→ Verify data file is in same folder as config

**Plots not generating**
→ Install ggplot2: `install.packages("ggplot2")`

## File Sizes

- Each CSV: ~50-100 KB
- Each Excel config: ~15-20 KB
- Output Excel: ~200-500 KB
- Plots: ~200-300 KB each
- **Total per project:** ~1-2 MB

Safe to copy to OneDrive or email for sharing.

## Next Steps

1. ✓ Generate all projects: `source("setup_all_projects.R")`
2. ✓ Test Consumer Electronics first (simplest)
3. ✓ Progress to SaaS Subscription (profit optimization)
4. ✓ Complete with Retail Product (full features)
5. ✓ Copy to OneDrive for real-world GUI testing
6. ✓ Use as templates for your own studies

## Support

- Quick Start: `../QUICK_START.md`
- User Manual: `../USER_MANUAL.md` (comprehensive)
- Tutorial: `../TUTORIAL.md` (step-by-step)
- Technical Docs: `../TECHNICAL_DOCUMENTATION.md`
- Sample Configs: `../sample_config_comprehensive.R`

---

**Note:** All data is synthetically generated and resembles real consumer behavior patterns. Safe for training, testing, and demonstrations.

**Version:** 2.0.0 | **Updated:** December 2025
