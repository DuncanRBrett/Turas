# Key Driver Analysis - Demo Showcase

## Scenario

A telecommunications company surveys **800 customers** to understand what drives **overall satisfaction**. Eight service attributes are evaluated across three customer segments: Business, Residential, and Premium.

## Quick Start

From the Turas project root:

```r
source("examples/keydriver/demo_showcase/run_demo.R")
```

This runs the full demo and generates all outputs in approximately 30-60 seconds.

## What This Demo Showcases

| Feature | Output File | Description |
|---------|------------|-------------|
| **Core Analysis** | `Demo_KeyDriver_Results.xlsx` | Shapley, Relative Weight, Beta Weight, Correlation importance |
| **Bootstrap CIs** | `Demo_Bootstrap_CIs.csv` | 95% confidence intervals on importance scores (500 iterations) |
| **Effect Sizes** | `Demo_Effect_Sizes.csv` | Cohen's f-squared classifications (Negligible/Small/Medium/Large) |
| **Segment Comparison** | `Demo_Segment_Comparison.csv` | Driver importance across Business/Residential/Premium |
| **Executive Summary** | `Demo_Executive_Summary.txt/.html` | Automated headline, findings, recommendations |
| **Elastic Net** | (in Excel + HTML) | Penalized variable selection via glmnet (NEW v10.4) |
| **NCA** | (in Excel + HTML) | Necessary Condition Analysis — hygiene vs motivator (NEW v10.4) |
| **Dominance Analysis** | (in Excel + HTML) | General, conditional & complete dominance (NEW v10.4) |
| **GAM** | (in Excel + HTML) | Nonlinear effects detection via mgcv (NEW v10.4) |
| **HTML Report** | `Demo_KeyDriver_Report.html` | Interactive standalone report with all sections |

## Data Description

- **Outcome**: Overall Satisfaction (1-10 scale)
- **8 Drivers**: Network Reliability, Customer Service, Value for Money, Data Speed, Billing Clarity, Coverage Area, App Experience, Contract Flexibility
- **Segments**: Business (40%), Residential (35%), Premium (25%)
- **Weights**: Survey weights (0.4 - 2.5)
- **Missing Data**: ~3% (realistic)

## Expected Results

The synthetic data is designed so that:

- **Network Reliability** is the #1 driver (~28% importance)
- **Customer Service** is #2 (~22%)
- **Value for Money** is a strong #3 (~15%)
- **Contract Flexibility** has negligible impact (~2%)
- Business customers prioritise reliability/speed
- Premium customers prioritise service/app experience
- All methods should agree on the top 3 drivers
- Elastic Net should zero out Contract Flexibility (negligible driver)
- GAM should show approximately linear relationships (survey scales)

## Config File

The demo config (`Demo_KeyDriver_Config.xlsx`) includes 5 sheets:

| Sheet | Purpose |
|-------|---------|
| **Settings** | All analysis parameters including v10.4 feature toggles |
| **Variables** | Outcome, drivers, weight definitions with DriverType |
| **Segments** | Customer segment definitions |
| **StatedImportance** | Stated importance values for quadrant analysis |
| **CustomSlides** | Config-driven qualitative slides for HTML report (NEW v10.4) |

## Files

| File | Purpose |
|------|---------|
| `run_demo.R` | Main demo runner - source this to run everything |
| `generate_demo_data.R` | Synthetic data generator (fully reproducible, seed=42) |
| `create_demo_config.R` | Config Excel file generator |
| `README.md` | This file |
