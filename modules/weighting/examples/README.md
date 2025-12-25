# TURAS Weighting Module - Example Projects

This directory contains complete, working examples demonstrating different weighting scenarios. All examples use **relative paths only** and can be moved to OneDrive or any location.

## Available Examples

### Example 1: Design Weights (B2B Customer Survey)
**Directory:** `example1_design_weights/`

- **Scenario:** B2B customer survey with sampling bias by company size
- **Method:** Design weighting (stratified sample correction)
- **Dataset:** 300 responses
- **Use Case:** When you have a stratified sample and know population sizes

**Key Features:**
- Single design weight by company size
- No demographic adjustment needed
- Direct calculation (no iteration)
- Demonstrates weight efficiency reporting

---

### Example 2: Rim Weights (Consumer Panel)
**Directory:** `example2_rim_weights/`

- **Scenario:** Consumer panel with demographic biases
- **Method:** Rim weighting (iterative proportional fitting)
- **Dataset:** 500 responses
- **Use Case:** When sample demographics don't match population

**Key Features:**
- Multiple demographic variables (age, gender, region)
- Iterative convergence process
- Weight trimming (capping extreme weights)
- Advanced settings configuration

---

### Example 3: Combined Weights (Market Research)
**Directory:** `example3_combined_weights/`

- **Scenario:** National market research with regional stratification
- **Method:** Both design + rim weights
- **Dataset:** 600 responses
- **Use Case:** When you need both geographic and demographic correction

**Key Features:**
- Two separate weights calculated
- Design weight for regional balance
- Rim weight for demographic adjustment
- Shows how to use multiple weights

---

## Quick Start

### Running an Example

```r
# 1. Navigate to an example directory
setwd("path/to/example1_design_weights")

# 2. Source the weighting module
source("../../run_weighting.R")

# 3. Run weighting
result <- run_weighting("Weight_Config.xlsx")

# 4. View results
head(result$data)
result$diagnostics
```

### What Gets Created
Each example will create an `output/` directory containing:
- Weighted data file (CSV)
- Diagnostics report (TXT) - if enabled

---

## File Structure

Each example follows this structure:
```
example_name/
├── README.md                    # Detailed documentation
├── Weight_Config.xlsx           # Configuration file
├── data/
│   └── survey_data.csv          # Sample survey data
└── output/                      # Created when you run
    ├── *_weighted.csv           # Weighted data
    └── diagnostics.txt          # Weight diagnostics
```

---

## Moving to OneDrive

✅ **All paths are relative** - you can move any example folder anywhere!

### Steps to Move:
1. Copy the entire example folder to your OneDrive
2. Update only the `setwd()` path when running
3. Everything else just works!

### Example:
```r
# Before (local)
setwd("/Users/duncan/Documents/Turas/modules/weighting/examples/example1_design_weights")

# After (OneDrive)
setwd("/Users/duncan/Library/CloudStorage/OneDrive-Personal/Turas_Examples/example1_design_weights")

# The rest stays the same
source("../../run_weighting.R")
result <- run_weighting("Weight_Config.xlsx")
```

---

## Understanding the Configuration Files

All examples use `Weight_Config.xlsx` with these sheets:

### 1. General
- `project_name`: Project identifier
- `data_file`: Path to data (relative)
- `output_file`: Where to save weighted data (relative)
- `save_diagnostics`: Y/N
- `diagnostics_file`: Diagnostics path (relative)

### 2. Weight_Specifications
- `weight_name`: Unique name for each weight
- `method`: "design" or "rim"
- `apply_trimming`: Y/N
- `trim_method`: "cap" or "percentile"
- `trim_value`: Max weight or percentile

### 3. Design_Targets (for design weights)
- Links to weight by `weight_name`
- Specifies stratum variable and categories
- Population sizes for each stratum

### 4. Rim_Targets (for rim weights)
- Links to weight by `weight_name`
- Demographic variables and categories
- Target percentages (must sum to 100 per variable)

### 5. Advanced_Settings (optional, for rim weights)
- Iteration limits
- Convergence tolerance
- Force convergence option

---

## Comparison of Examples

| Feature | Example 1 | Example 2 | Example 3 |
|---------|-----------|-----------|-----------|
| **Method** | Design only | Rim only | Both |
| **Sample Size** | 300 | 500 | 600 |
| **Variables** | Company size | Age, Gender, Region | Region + Age + Gender |
| **Complexity** | Simple | Medium | Advanced |
| **Iteration** | No | Yes | Yes (rim only) |
| **Trimming** | No | Yes (cap) | Yes (percentile) |
| **Best For Learning** | Basics | Rim weighting | Full workflow |

---

## Customizing for Your Data

To adapt an example for your own data:

1. **Copy an example** that's closest to your use case
2. **Replace the data file** with your survey data (CSV)
3. **Update Weight_Config.xlsx:**
   - General: Update file paths
   - Weight_Specifications: Define your weights
   - Design_Targets or Rim_Targets: Set your population targets
4. **Run and review diagnostics**
5. **Adjust trimming** if weights are too extreme

---

## Getting Help

- **Module Documentation:** See `../docs/USER_GUIDE.md`
- **Template Reference:** See `../docs/TEMPLATE_REFERENCE.md`
- **Technical Details:** See `../docs/TECHNICAL_DOCS.md`
- **Template File:** See `../templates/Weight_Config_Template.xlsx`

---

## Tips for Success

✅ **DO:**
- Start with example 1 to understand basics
- Review diagnostics after each run
- Use weight trimming for extreme weights
- Test with small sample first
- Keep configurations organized

❌ **DON'T:**
- Hard-code file paths
- Over-weight (use trimming)
- Use too many rim variables (max 5)
- Ignore convergence warnings
- Skip diagnostics review

---

## Need More Examples?

These examples cover the most common scenarios. For specialized cases:

1. **Multi-stage sampling:** Extend example 3 with more strata
2. **Post-stratification:** Use rim weighting with finer categories
3. **Replicate weights:** Calculate multiple weight sets
4. **Custom trimming:** Modify Advanced_Settings

---

**Last Updated:** 2025-12-25
**Module Version:** 1.0
