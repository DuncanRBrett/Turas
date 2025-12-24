# TURAS Weighting Module - Technical Specification

**Version:** 1.0  
**Date:** December 24, 2025  
**Module:** `modules/weighting/`  
**Status:** Specification for Development

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Product Context](#product-context)
3. [Module Objectives](#module-objectives)
4. [Architecture Overview](#architecture-overview)
5. [Excel Configuration Design](#excel-configuration-design)
6. [Functional Requirements](#functional-requirements)
7. [Technical Specifications](#technical-specifications)
8. [Quality Control & Diagnostics](#quality-control--diagnostics)
9. [Integration Requirements](#integration-requirements)
10. [Error Handling](#error-handling)
11. [Testing Requirements](#testing-requirements)
12. [Success Criteria](#success-criteria)
13. [Future Enhancements](#future-enhancements)

---

## Executive Summary

### Purpose
Build a comprehensive weighting module for TURAS that calculates survey weights using industry-standard methods and integrates seamlessly with existing analysis modules.

### Scope
- **In Scope:** Design weights, rim weighting (raking), multiple weight columns, diagnostics, trimming
- **Out of Scope:** Cell weighting (interlocking quotas), custom weighting algorithms, real-time weight updates

### Key Deliverables
1. Excel-based configuration system (`Weight_Config.xlsx`)
2. Main weighting script (`run_weighting.R`)
3. Supporting library functions for calculation and diagnostics
4. Template files for users
5. Comprehensive documentation

### Timeline
**Estimated effort:** 4 weeks (160 hours)

**Breakdown:**
- Week 1: Infrastructure + design weights + Excel config
- Week 2: Rim weighting integration + validation
- Week 3: Diagnostics + trimming + quality control
- Week 4: Testing + documentation + polish

---

## Product Context

### Business Problem
Mid-size research agencies and corporate insights teams need:
- **End-to-end workflow** without external tools (Excel → SPSS → Analysis platform)
- **Transparent methodology** with audit trail
- **Junior-friendly tools** that don't require SPSS/R expertise
- **Reproducible results** from documented configurations

### Current State
TURAS can **apply** weights but cannot **calculate** them. Users must:
1. Calculate weights externally (Excel/SPSS/R)
2. Add weight column to data
3. Import to TURAS for analysis

**Pain points:**
- Multi-tool workflow (fragmented)
- No audit trail (how were weights calculated?)
- Requires statistical expertise
- Not reproducible (manual steps)

### Future State
TURAS provides complete weighting solution:
1. User specifies targets in Excel config
2. TURAS calculates weights automatically
3. Weights added to data with full diagnostics
4. Data flows to analysis modules (crosstabs, tabs, ranking)

**Benefits:**
- Single integrated platform
- Transparent, documented methodology
- Accessible to junior researchers
- Fully reproducible from config files

---

## Module Objectives

### Primary Objectives

1. **Calculate design weights** for stratified samples
   - Input: Stratum sizes (population and sample)
   - Output: Weight = population_size / sample_size per stratum
   - Use case: Customer lists, employee surveys, stratified random samples

2. **Calculate rim weights** (iterative proportional fitting)
   - Input: Target marginal distributions for 2-5 variables
   - Output: Weights that match all target margins simultaneously
   - Use case: Quota samples, online panels, general population studies

3. **Support multiple weight columns** in single dataset
   - Different weighting schemes for same data
   - Example: revenue-weighted vs. entity-weighted analysis
   - Each weight set configured independently

4. **Provide comprehensive diagnostics**
   - Weight distribution statistics
   - Design effect calculation
   - Effective sample size
   - Quality warnings and recommendations

5. **Ensure data quality**
   - Weight trimming/capping for extreme values
   - Convergence diagnostics for rim weighting
   - Input validation and error checking

### Secondary Objectives

1. **Integrate seamlessly** with existing TURAS modules
2. **Follow established patterns** (Excel config, logging, validation)
3. **Maintain transparency** (all calculations documented)
4. **Enable reproducibility** (same config → same weights)
5. **Support grossing up** (representative weights + population metadata)

---

## Architecture Overview

### Module Structure

```
modules/weighting/
├── run_weighting.R              # Main entry point
├── lib/                         # Core functions
│   ├── config_loader.R         # Load and validate Weight_Config.xlsx
│   ├── design_weights.R        # Design weight calculation
│   ├── rim_weights.R           # Rim weighting (anesrake wrapper)
│   ├── diagnostics.R           # Weight quality diagnostics
│   ├── trimming.R              # Weight capping and trimming
│   ├── validation.R            # Input validation
│   └── output.R                # Generate reports and write data
├── templates/                   # User templates
│   └── Weight_Config_Template.xlsx
└── README.txt                   # Module documentation
```

### Data Flow

```
Input:
  ├── Survey data (CSV/XLSX) - unweighted
  └── Weight_Config.xlsx - specifications

Processing:
  ├── Load and validate config
  ├── Validate data (check variables exist, no missings)
  ├── Calculate weights (design or rim method)
  ├── Apply trimming if configured
  ├── Generate diagnostics
  └── Add weight column(s) to data

Output:
  ├── Survey data with weight column(s) added
  ├── Diagnostic report (console + optional file)
  └── Optional: standalone diagnostics report
```

### Integration Points

**With existing TURAS modules:**
- Uses `core/io.R` for file handling
- Uses `core/logging.R` for error/warning messages
- Uses `core/validation.R` for input checks
- Uses `core/utilities.R` for helper functions
- Outputs data compatible with `modules/tabs/`, `modules/crosstabs/`, `modules/ranking/`

**With existing weighting infrastructure:**
- Uses `shared/statistics/weighting.R` for:
  - `calculate_effective_n()` - Kish effective sample size
  - `summarize_weights()` - Weight diagnostics (extend if needed)

---

## Excel Configuration Design

### File: `Weight_Config_Template.xlsx`

#### Sheet 1: `General`

**Purpose:** Overall configuration and metadata

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| `project_name` | Text | Yes | Project identifier | "Customer_Survey_2025" |
| `data_file` | Text | Yes | Path to survey data file | "data/survey_responses.csv" |
| `output_file` | Text | No | Path for weighted data output | "data/survey_weighted.csv" |
| `save_diagnostics` | Text | No | Save diagnostics to file? (Y/N) | "Y" |
| `diagnostics_file` | Text | No | Path for diagnostics report | "output/weight_diagnostics.txt" |

**Notes:**
- If `output_file` is blank, data returned to R environment only
- If `save_diagnostics = "Y"`, must specify `diagnostics_file`

---

#### Sheet 2: `Weight_Specifications`

**Purpose:** Define one or more weight sets to calculate

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| `weight_name` | Text | Yes | Name for weight column | "design_weight" |
| `method` | Text | Yes | Weighting method: "design" or "rim" | "design" |
| `description` | Text | No | Human-readable description | "Weights by customer size" |
| `apply_trimming` | Text | No | Trim extreme weights? (Y/N) | "Y" |
| `trim_method` | Text | No | "cap" or "percentile" | "cap" |
| `trim_value` | Numeric | No | Max weight (cap) or percentile (0-1) | 5 |
| `population_total` | Numeric | No | Total population size (for grossing up) | 10000 |

**Valid values:**
- `method`: "design", "rim"
- `apply_trimming`: "Y", "N" (default: "N")
- `trim_method`: 
  - "cap" = hard maximum (e.g., no weight > 5)
  - "percentile" = trim to percentile (e.g., 0.95 = top 5% capped at 95th percentile)
- `trim_value`:
  - If `trim_method = "cap"`: numeric max (e.g., 5)
  - If `trim_method = "percentile"`: 0-1 (e.g., 0.95)

**Notes:**
- Multiple rows = multiple weight columns calculated
- Each `weight_name` must be unique
- If `method = "design"`, must have entries in `Design_Targets` sheet
- If `method = "rim"`, must have entries in `Rim_Targets` sheet

**Example:**
```
weight_name          | method | description              | apply_trimming | trim_method | trim_value
---------------------|--------|--------------------------|----------------|-------------|------------
revenue_weight       | design | Weight by revenue band   | Y              | cap         | 5
store_weight         | design | Weight by store count    | Y              | cap         | 5
population_weight    | rim    | Weight to census         | Y              | percentile  | 0.95
```

---

#### Sheet 3: `Design_Targets`

**Purpose:** Specify stratification for design weights

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| `weight_name` | Text | Yes | Links to Weight_Specifications | "revenue_weight" |
| `stratum_variable` | Text | Yes | Column name in data | "revenue_band" |
| `stratum_category` | Text | Yes | Value in data | "Small" |
| `population_size` | Numeric | Yes | Count in population | 2000 |

**Calculation:**
```
For each stratum:
  sample_size = count of rows where data[stratum_variable] == stratum_category
  weight = population_size / sample_size
```

**Validation:**
- All `stratum_category` values must exist in data
- `population_size` must be > 0
- No duplicate stratum categories per weight_name

**Example:**
```
weight_name     | stratum_variable | stratum_category | population_size
----------------|------------------|------------------|----------------
revenue_weight  | revenue_band     | Small            | 2000
revenue_weight  | revenue_band     | Medium           | 500
revenue_weight  | revenue_band     | Large            | 100
store_weight    | store_band       | 1-10             | 8000
store_weight    | store_band       | 11-50            | 1500
store_weight    | store_band       | 51+              | 500
```

---

#### Sheet 4: `Rim_Targets`

**Purpose:** Specify target marginal distributions for rim weighting

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| `weight_name` | Text | Yes | Links to Weight_Specifications | "population_weight" |
| `variable` | Text | Yes | Column name in data | "Age" |
| `category` | Text | Yes | Value in data | "18-34" |
| `target_percent` | Numeric | Yes | Population % (must sum to 100 per variable) | 30 |

**Calculation:**
- Uses iterative proportional fitting (anesrake package)
- Adjusts weights to match all target margins simultaneously

**Validation:**
- For each `variable`, `target_percent` must sum to 100 (within tolerance 99.9-100.1)
- All `category` values must exist in data
- Variable must have no missing values in data
- Maximum 5 variables recommended (convergence risk beyond that)

**Example:**
```
weight_name        | variable | category | target_percent
-------------------|----------|----------|---------------
population_weight  | Age      | 18-34    | 30
population_weight  | Age      | 35-54    | 40
population_weight  | Age      | 55+      | 30
population_weight  | Gender   | Male     | 48
population_weight  | Gender   | Female   | 52
population_weight  | Region   | North    | 25
population_weight  | Region   | South    | 35
population_weight  | Region   | East     | 20
population_weight  | Region   | West     | 20
```

---

#### Sheet 5: `Advanced_Settings` (Optional)

**Purpose:** Advanced rim weighting parameters

| Column | Type | Required | Description | Default |
|--------|------|----------|-------------|---------|
| `weight_name` | Text | Yes | Links to Weight_Specifications | - |
| `max_iterations` | Numeric | No | Maximum raking iterations | 25 |
| `convergence_tolerance` | Numeric | No | Stop when all margins within % | 0.01 (1%) |
| `force_convergence` | Text | No | Return weights even if no convergence? (Y/N) | "N" |

**Notes:**
- Only applies to rim weighting
- Default values usually work well
- Increase `max_iterations` if complex targets (4-5 variables)
- Decrease `convergence_tolerance` for more precision (slower)

---

## Functional Requirements

### FR1: Load Configuration

**Requirement:** Load and parse `Weight_Config.xlsx`

**Inputs:**
- Path to Excel config file

**Outputs:**
- Validated config object (nested list structure)

**Process:**
1. Check file exists and is readable
2. Load all sheets
3. Validate required sheets present
4. Parse each sheet into appropriate R structure
5. Cross-validate references (e.g., weight_name exists)

**Error conditions:**
- File not found
- Missing required sheets
- Invalid column names
- Type mismatches (e.g., text in numeric column)

---

### FR2: Calculate Design Weights

**Requirement:** Calculate design weights for stratified samples

**Inputs:**
- Survey data (data frame)
- Design targets (from config)

**Algorithm:**
```
For each weight specification with method="design":
  For each stratum:
    1. Extract population_size from config
    2. Count sample_size = rows in data for this stratum
    3. Calculate weight = population_size / sample_size
    4. Assign weight to all rows in stratum
```

**Outputs:**
- Vector of weights (same length as data rows)

**Validation:**
- Stratum variable exists in data
- All categories in config exist in data
- No missing values in stratum variable
- Sample size > 0 for each stratum

**Edge cases:**
- Stratum with 1 observation: Valid, weight = population_size / 1
- Stratum in data but not in config: Error (unspecified stratum)
- Stratum in config but not in data: Error (cannot weight, no observations)

---

### FR3: Calculate Rim Weights

**Requirement:** Calculate rim weights using iterative proportional fitting

**Inputs:**
- Survey data (data frame)
- Rim targets (from config)
- Advanced settings (optional)

**Algorithm:**
```
1. Build target list:
   For each variable:
     Create named vector: category -> target_percent/100

2. Call anesrake::anesrake():
   - targets = target list
   - dataframe = survey data
   - caseid = row numbers or ID column
   - cap = trim_value (if specified)
   - choosemethod = "total" (default)
   - type = "pctlim" (percentage limits)
   - pctlim = convergence_tolerance
   - maxit = max_iterations
   - force1 = TRUE (weights average to 1)

3. Check convergence:
   - If converged: Extract weights
   - If not converged: Warning + decision based on force_convergence

4. Return weight vector
```

**Outputs:**
- Vector of weights (same length as data rows)
- Convergence status (TRUE/FALSE)
- Number of iterations used

**Dependencies:**
- Requires `anesrake` package
- Check package installed at module load

**Validation:**
- All rim variables exist in data
- No missing values in rim variables
- Categories match between config and data
- Targets sum to 100 per variable (±0.1% tolerance)

**Error conditions:**
- Missing package: Clear message with install instructions
- Convergence failure: Warning with diagnostics
- Invalid targets: Error before attempting calculation

---

### FR4: Apply Weight Trimming

**Requirement:** Cap extreme weights to improve stability

**Inputs:**
- Weight vector
- Trim method ("cap" or "percentile")
- Trim value

**Algorithm:**

**Method: "cap"**
```
For each weight:
  If weight > trim_value:
    Set weight = trim_value
```

**Method: "percentile"**
```
1. Calculate percentile threshold:
   threshold = quantile(weights, trim_value)
   
2. For each weight:
     If weight > threshold:
       Set weight = threshold
```

**Outputs:**
- Trimmed weight vector
- Count of trimmed weights
- Original max before trimming

**Validation:**
- trim_value > 0
- For percentile: trim_value between 0 and 1
- Weights are numeric

**Reporting:**
- Log how many weights were trimmed
- Report original max and new max
- Warning if >5% of weights trimmed

---

### FR5: Generate Diagnostics

**Requirement:** Comprehensive weight quality report

**Inputs:**
- Weight vector(s)
- Original data
- Config metadata

**Metrics to calculate:**

**Basic statistics:**
- N total
- N with valid weights (>0, finite)
- N with zero/NA/infinite weights
- Min weight (non-zero)
- Max weight
- Mean weight (should be ~1.0 for representative weights)
- Median weight
- Standard deviation
- Coefficient of variation (SD/Mean)

**Sample size metrics:**
- Effective sample size (Kish formula)
- Design effect (N / n_eff)
- Efficiency (n_eff / N as percentage)

**Distribution:**
- Quartiles (Q1, Q3)
- Percentiles (5th, 95th, 99th)
- Count of extreme weights (>3, >5, >10)

**Rim weighting specific:**
- Convergence status
- Number of iterations
- Achieved vs. target margins (comparison table)

**Output formats:**
1. **Console output:** Formatted text summary
2. **File output (optional):** Text file with full diagnostics
3. **Return value:** List with all metrics for programmatic use

---

### FR6: Write Output

**Requirement:** Add weights to data and optionally export

**Inputs:**
- Original survey data
- Calculated weight vector(s)
- Weight names
- Output file path (optional)

**Process:**
```
1. For each weight specification:
   - Add column to data: data[[weight_name]] <- weights
   
2. If output_file specified:
   - Write data to CSV/Excel
   - Preserve all original columns
   - Add weight column(s)
   
3. Return data frame (always)
```

**Validation:**
- Weight names don't overwrite existing important columns
- Length of weight vector matches data rows
- Output file path is writable

**File format:**
- Auto-detect from extension (.csv, .xlsx)
- CSV: Use write.csv() with row.names=FALSE
- Excel: Use openxlsx::write.xlsx()

---

### FR7: Multiple Weight Support

**Requirement:** Handle multiple weight specifications in one run

**Process:**
```
For each row in Weight_Specifications sheet:
  1. Extract config for this weight
  2. Calculate weights based on method
  3. Apply trimming if configured
  4. Generate diagnostics
  5. Add column to data
  
All weights processed in single run
All weights added to same data frame
```

**Validation:**
- No duplicate weight names
- Each weight has corresponding targets (Design or Rim)
- All weight calculations successful

**Output:**
- Single data frame with multiple weight columns
- Separate diagnostic report per weight
- Summary showing all weights calculated

---

## Technical Specifications

### TS1: Dependencies

**R Version:** R >= 4.0.0

**Required Packages:**
```r
# Weighting algorithm
anesrake (>= 0.80)

# Excel I/O
openxlsx (>= 4.2.0)

# Data manipulation
dplyr (>= 1.0.0)

# Existing TURAS dependencies
# (already installed via core/dependencies.R)
```

**Installation check:**
```r
# At module load, check anesrake installed
if (!requireNamespace("anesrake", quietly = TRUE)) {
  stop(
    "Package 'anesrake' required for rim weighting.\n",
    "Install with: install.packages('anesrake')",
    call. = FALSE
  )
}
```

---

### TS2: Function Signatures

#### `run_weighting()`

Main entry point for module.

```r
run_weighting <- function(
  config_file,
  data_file = NULL,
  return_data = TRUE,
  verbose = TRUE
)

# Arguments:
#   config_file: Path to Weight_Config.xlsx
#   data_file: Path to survey data (NULL = use path from config)
#   return_data: Return data frame? (FALSE = only write to file)
#   verbose: Print progress messages?
#
# Returns:
#   List with elements:
#     $data: Data frame with weight columns added
#     $diagnostics: List of diagnostic results per weight
#     $config: Parsed configuration
#
# Example:
#   result <- run_weighting("config/Weight_Config.xlsx")
#   weighted_data <- result$data
```

---

#### `calculate_design_weights()`

Calculate design weights for stratified sample.

```r
calculate_design_weights <- function(
  data,
  stratum_variable,
  population_sizes,
  verbose = FALSE
)

# Arguments:
#   data: Data frame
#   stratum_variable: Character, column name
#   population_sizes: Named vector, category -> population count
#   verbose: Print detailed output?
#
# Returns:
#   Numeric vector of weights (length = nrow(data))
#
# Example:
#   pop_sizes <- c("Small" = 2000, "Medium" = 500, "Large" = 100)
#   weights <- calculate_design_weights(data, "customer_size", pop_sizes)
```

---

#### `calculate_rim_weights()`

Calculate rim weights via anesrake.

```r
calculate_rim_weights <- function(
  data,
  target_list,
  caseid = NULL,
  max_iterations = 25,
  convergence_tolerance = 0.01,
  force_convergence = FALSE,
  cap_weights = NULL,
  verbose = FALSE
)

# Arguments:
#   data: Data frame
#   target_list: Named list, variable -> named vector of targets
#   caseid: Optional ID column (default: row numbers)
#   max_iterations: Max raking iterations
#   convergence_tolerance: Convergence criterion (%)
#   force_convergence: Return weights even if no convergence?
#   cap_weights: Optional weight cap during raking
#   verbose: Print detailed output?
#
# Returns:
#   List with elements:
#     $weights: Numeric vector
#     $converged: Logical
#     $iterations: Integer
#     $margins: Data frame of achieved vs. target
#
# Example:
#   targets <- list(
#     Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
#     Gender = c("Male" = 0.48, "Female" = 0.52)
#   )
#   result <- calculate_rim_weights(data, targets)
```

---

#### `trim_weights()`

Apply weight trimming.

```r
trim_weights <- function(
  weights,
  method = c("cap", "percentile"),
  value,
  verbose = FALSE
)

# Arguments:
#   weights: Numeric vector
#   method: "cap" or "percentile"
#   value: Numeric, max weight or percentile threshold
#   verbose: Print trimming details?
#
# Returns:
#   List with elements:
#     $weights: Trimmed weight vector
#     $n_trimmed: Count of trimmed weights
#     $original_max: Max before trimming
#     $new_max: Max after trimming
#
# Example:
#   trimmed <- trim_weights(weights, method = "cap", value = 5)
```

---

#### `diagnose_weights()`

Generate weight diagnostics.

```r
diagnose_weights <- function(
  weights,
  label = "Weight Diagnostics",
  rim_result = NULL,
  save_to_file = NULL,
  verbose = TRUE
)

# Arguments:
#   weights: Numeric vector
#   label: Character, name for this weight
#   rim_result: Optional, rim weighting result for convergence info
#   save_to_file: Optional path to save diagnostics
#   verbose: Print to console?
#
# Returns:
#   List with all diagnostic metrics
#
# Example:
#   diag <- diagnose_weights(weights, label = "Population Weight")
```

---

### TS3: Performance Considerations

**Expected performance:**
- Design weights: O(n) - very fast, linear scan
- Rim weights: O(n × k × i) where:
  - n = sample size
  - k = number of variables
  - i = iterations (typically 10-25)
  
**Benchmarks:**
- n=1000, k=3 variables: ~1 second
- n=5000, k=4 variables: ~5 seconds
- n=10000, k=5 variables: ~15 seconds

**Memory:**
- Minimal overhead beyond data size
- Weight vectors are numeric (8 bytes per element)
- No large intermediate objects retained

**Optimization notes:**
- anesrake is already optimized (C code underneath)
- Main bottleneck is convergence iterations
- Use `verbose=FALSE` in production for speed

---

### TS4: Error Handling Strategy

**Error categories:**

**1. Configuration errors (fail fast):**
- Invalid Excel file
- Missing required sheets
- Type mismatches
- Invalid method specification
→ Stop with clear error message before any calculations

**2. Data validation errors (fail fast):**
- Missing variables
- Category mismatches
- Missing values in weight variables
→ Stop with actionable error message

**3. Calculation warnings (continue with warning):**
- Rim weighting convergence failure
- High design effect (>3)
- Many extreme weights
→ Continue but warn user, include in diagnostics

**4. Output errors (fail at end):**
- Cannot write output file
- Permissions issue
→ Calculations complete, but file write fails (data still returned)

**Error message format:**
```r
stop(
  "\n❌ ERROR: [Category]\n",
  "Issue: [What went wrong]\n",
  "Location: [Where - file/sheet/column]\n",
  "Action: [What user should do]\n",
  "Example: [Correct format if applicable]",
  call. = FALSE
)
```

---

## Quality Control & Diagnostics

### QC1: Diagnostic Report Format

**Console output format:**

```
================================================================================
WEIGHT DIAGNOSTICS: population_weight
================================================================================

METHOD: Rim Weighting
CONVERGENCE: ✓ Converged in 12 iterations

SAMPLE SIZE:
  Total cases:              1,000
  Valid weights:              998
  Zero/NA weights:              2 (0.2%)

WEIGHT DISTRIBUTION:
  Min:                       0.412
  Q1:                        0.823
  Median:                    0.991
  Q3:                        1.187
  Max:                       4.876
  Mean:                      1.000
  SD:                        0.543
  CV:                        0.543

EFFECTIVE SAMPLE SIZE:
  Effective N:                 847
  Design effect:              1.18
  Efficiency:                84.7% ✓

EXTREME WEIGHTS:
  Weights > 3:                   3 (0.3%)
  Weights > 5:                   0 (0.0%)
  Trimming applied:             No

TARGET ACHIEVEMENT:
  Variable    Category    Target    Achieved    Diff
  --------    --------    ------    --------    ----
  Age         18-34       30.0%     30.1%       +0.1%
  Age         35-54       40.0%     39.9%       -0.1%
  Age         55+         30.0%     30.0%        0.0%
  Gender      Male        48.0%     48.0%        0.0%
  Gender      Female      52.0%     52.0%        0.0%

QUALITY ASSESSMENT: ✓ GOOD
  - Convergence achieved
  - Design effect acceptable (<2)
  - No extreme weights
  - Targets achieved within tolerance

================================================================================
```

**Quality indicators:**
- ✓ Good: Design effect <2, CV <0.5, converged
- ⚠️  Acceptable: Design effect 2-3, CV 0.5-1.0, converged
- ❌ Poor: Design effect >3, CV >1.0, or not converged

---

### QC2: Automatic Warnings

**Warning conditions:**

1. **High design effect (>2.0):**
```
⚠️  WARNING: High design effect (2.35)
    This indicates substantial loss of precision due to weighting.
    Effective sample size reduced from 1000 to 426 (42.6%).
    
    Consider:
    - Trimming extreme weights (try cap at 3 or 4)
    - Reducing number of rim variables
    - Checking for unusual response patterns
```

2. **Convergence failure:**
```
❌ WARNING: Rim weighting did not converge after 25 iterations
    Achieved margins still differ from targets by up to 2.3%.
    
    Options:
    1. Increase max_iterations (try 50)
    2. Relax convergence_tolerance (try 0.02)
    3. Reduce number of variables (currently 5, try 3-4)
    4. Check for impossible target combinations
    
    Weights returned but may not exactly match targets.
```

3. **Many extreme weights (>5% above cap):**
```
⚠️  WARNING: 73 weights exceed 5.0 (7.3% of sample)
    This suggests large imbalances between sample and population.
    
    Consider:
    - Applying weight trimming (cap at 5)
    - Reviewing sample recruitment methods
    - Checking if targets are realistic
```

4. **High percentage zero/NA (>5%):**
```
⚠️  WARNING: 67 cases have zero or NA weights (6.7%)
    These cases are excluded from weighted analysis.
    
    Reasons:
    - Missing data in rim variables: 42 cases
    - Strata not in population: 25 cases
    
    Action: Review data quality and target specifications
```

---

### QC3: Validation Checks

**Pre-calculation validation:**

```r
validate_design_config <- function(data, config) {
  # Check stratum variable exists
  # Check all categories exist in data
  # Check no missing values
  # Check population sizes > 0
  # Check sample sizes > 0 for each stratum
  # Return: error_log (data frame of issues)
}

validate_rim_config <- function(data, config) {
  # Check all rim variables exist
  # Check all categories exist
  # Check no missing values in rim variables
  # Check targets sum to 100 per variable (±0.1)
  # Check <=5 variables (warning if >5)
  # Return: error_log
}
```

**Post-calculation validation:**

```r
validate_weights <- function(weights) {
  # Check length matches data
  # Check all finite (no Inf, -Inf)
  # Check all positive
  # Check mean approximately 1.0 (for representative weights)
  # Flag if CV > 1.5 (very high variability)
  # Flag if any weight > 10 (extreme)
  # Return: validation results
}
```

---

## Integration Requirements

### INT1: With Existing TURAS Modules

**Output compatibility:**

The weighted data must be usable by:
- `modules/tabs/run_tabs.R`
- `modules/crosstabs/run_crosstabs.R`
- `modules/ranking/run_ranking.R`

**Requirements:**
- Weight column added to existing data frame
- All original columns preserved
- Weight column is numeric
- No NA values in weight column (use 0 for excluded cases)

**Testing:**
```r
# 1. Calculate weights
result <- run_weighting("config/Weight_Config.xlsx")

# 2. Use in crosstabs
crosstab_config$weight_variable <- "population_weight"
crosstabs <- run_crosstabs(result$data, crosstab_config)

# Should work seamlessly
```

---

### INT2: With Core Functions

**Use existing core functions:**

```r
# From core/io.R
load_survey_data()        # Load data file
get_config_value()        # Extract config values
safe_numeric()            # Safe type conversion
safe_logical()            # Safe type conversion

# From core/logging.R
log_info()                # Info messages
log_warning()             # Warnings
log_error()               # Errors

# From core/validation.R
validate_data_frame()     # Check data structure
validate_column_exists()  # Check column present
validate_no_missing()     # Check for NAs

# From core/utilities.R
format_number()           # Number formatting for output
```

**Follow existing patterns:**
- Error logging to data frame
- Consistent message formatting
- Validation before processing
- Graceful error handling

---

### INT3: File Naming Conventions

**Follow TURAS conventions:**

```
modules/weighting/
├── run_weighting.R              # Entry point (lowercase, underscores)
├── lib/
│   ├── config_loader.R         # Lowercase, descriptive
│   ├── design_weights.R        # Function purpose in name
│   └── ...
├── templates/
│   └── Weight_Config_Template.xlsx  # TitleCase for user files
└── README.txt                   # Uppercase for documentation
```

**Function naming:**
- Verbs for actions: `calculate_`, `validate_`, `diagnose_`
- Nouns for getters: `get_`, `extract_`
- Predicates return logical: `is_`, `has_`
- Private helpers: `.helper_function()` (leading dot)

---

## Error Handling

### ERR1: Configuration Errors

**E001: Missing required sheet**
```
❌ ERROR: Configuration Validation
Issue: Required sheet 'Weight_Specifications' not found in config file
Location: config/Weight_Config.xlsx
Action: Add 'Weight_Specifications' sheet with at least one weight specification
Example: See templates/Weight_Config_Template.xlsx
```

**E002: Invalid method**
```
❌ ERROR: Configuration Validation  
Issue: Invalid method 'rake' in Weight_Specifications row 1
Location: Sheet 'Weight_Specifications', column 'method', row 1
Action: Use valid method: 'design' or 'rim'
Current value: 'rake'
Valid values: 'design', 'rim'
```

**E003: Duplicate weight names**
```
❌ ERROR: Configuration Validation
Issue: Duplicate weight_name 'population_weight' found
Location: Sheet 'Weight_Specifications', rows 1 and 3
Action: Each weight_name must be unique
Duplicate: 'population_weight'
```

**E004: Missing targets**
```
❌ ERROR: Configuration Validation
Issue: Weight 'population_weight' specifies method='rim' but no rim targets found
Location: Sheet 'Rim_Targets' is empty or missing entries for 'population_weight'
Action: Add rim target specifications for this weight
Example: variable='Age', category='18-34', target_percent=30
```

---

### ERR2: Data Validation Errors

**E101: Variable not found**
```
❌ ERROR: Data Validation
Issue: Stratum variable 'customer_size' not found in data
Location: Sheet 'Design_Targets', weight_name='revenue_weight'
Action: Check variable name matches data column exactly (case-sensitive)
Available columns: customer_type, revenue, store_count, region
```

**E102: Category not found**
```
❌ ERROR: Data Validation
Issue: Category 'Large' not found in variable 'customer_size'
Location: Sheet 'Design_Targets', stratum_category='Large'
Action: Check category value matches data exactly (case-sensitive)
Data contains: Small, Medium, Large Corp
Config specifies: Large
```

**E103: Missing values in weight variable**
```
❌ ERROR: Data Validation
Issue: Variable 'Age' has 23 missing (NA) values
Location: Sheet 'Rim_Targets', variable='Age'
Action: Rim weighting requires complete data for all weight variables
Options:
  1. Remove rows with missing Age
  2. Impute missing Age values
  3. Remove Age from rim targets
Missing: 23 of 1000 rows (2.3%)
```

**E104: Targets don't sum to 100**
```
❌ ERROR: Configuration Validation
Issue: Rim targets for 'Age' sum to 95.0%, must equal 100%
Location: Sheet 'Rim_Targets', variable='Age'
Action: Adjust target_percent values to sum to 100
Current sum: 95.0%
Categories:
  18-34: 30%
  35-54: 40%
  55+:   25%  ← Missing 5%
```

---

### ERR3: Calculation Warnings

**W201: Convergence failure**
```
⚠️  WARNING: Rim Weighting Convergence
Issue: Weighting did not converge after 25 iterations
Status: Maximum margin difference is 1.8% (tolerance: 1.0%)
Action: Weights returned but may not exactly match targets

Suggestions:
  1. Increase max_iterations to 50 (Advanced_Settings sheet)
  2. Relax convergence_tolerance to 0.02
  3. Reduce number of rim variables (currently 5, try 3-4)

Current margins:
  Variable    Worst margin    Target    Achieved
  Age         1.8%           30.0%     31.8%
  Gender      0.3%           48.0%     48.3%
```

**W202: High design effect**
```
⚠️  WARNING: Weight Quality
Issue: Design effect is 3.24 (>3.0 threshold)
Impact: Effective sample size reduced from 1000 to 309 (30.9%)
Status: Weights calculated but statistical power significantly reduced

Suggestions:
  1. Apply weight trimming: cap at 5 or percentile 0.95
  2. Review if all rim variables necessary
  3. Check for unusual response patterns

Weight distribution:
  Min: 0.23, Max: 12.4, Mean: 1.0, SD: 1.87, CV: 1.87
```

---

### ERR4: Output Errors

**E301: Cannot write output file**
```
❌ ERROR: File Output
Issue: Cannot write to output file (permission denied)
Location: data/survey_weighted.csv
Action: Check file permissions or close file if open in another program

Note: Weighted data was calculated successfully and returned.
      Only file write failed. You can save manually.
```

---

## Testing Requirements

### TEST1: Unit Tests

**Test files:**
```
tests/weighting/
├── test_design_weights.R
├── test_rim_weights.R
├── test_trimming.R
├── test_diagnostics.R
└── test_validation.R
```

**Key test cases:**

**Design weights:**
- [x] Simple 2-stratum case
- [x] Unequal stratum sizes
- [x] Single observation per stratum
- [x] Missing stratum in config (error)
- [x] Missing stratum in data (error)

**Rim weights:**
- [x] 2 variables, 2-3 categories each
- [x] 3-5 variables (complexity test)
- [x] Perfect sample (weights should ≈1)
- [x] Extreme imbalance
- [x] Convergence failure handling
- [x] Missing values in rim variables (error)

**Trimming:**
- [x] Cap method at 5
- [x] Percentile method at 0.95
- [x] No weights exceed cap (no trimming)
- [x] All weights exceed cap (mass trimming)

**Validation:**
- [x] Missing required config sheets
- [x] Invalid method specification
- [x] Targets sum to 99% or 101% (error)
- [x] Duplicate weight names
- [x] Variable not in data

---

### TEST2: Integration Tests

**End-to-end scenarios:**

**Scenario 1: Simple design weights**
```r
# Create test data
data <- data.frame(
  id = 1:100,
  size = rep(c("Small", "Medium", "Large"), c(60, 30, 10)),
  response = sample(1:5, 100, replace=TRUE)
)

# Create config
# ... (specify design weights)

# Run weighting
result <- run_weighting("test_config.xlsx")

# Verify
expect_equal(mean(result$data$weight), 1.0, tolerance=0.01)
expect_equal(nrow(result$data), 100)
expect_true("weight" %in% names(result$data))
```

**Scenario 2: Rim weighting with trimming**
```r
# Create test data with imbalance
# Run rim weighting with trim
# Verify convergence
# Verify no weights > cap
# Verify diagnostics generated
```

**Scenario 3: Multiple weights**
```r
# Create config with 2 weight specs
# Run weighting
# Verify 2 weight columns created
# Verify each has proper diagnostics
```

**Scenario 4: Integration with crosstabs**
```r
# Calculate weights
# Pass to run_crosstabs with weight_variable
# Verify weighted percentages correct
```

---

### TEST3: Validation Tests

**Config validation:**
- [x] Valid config passes
- [x] Missing sheet detected
- [x] Invalid method detected
- [x] Duplicate names detected
- [x] Orphan targets detected (no matching weight_name)

**Data validation:**
- [x] Variable existence check
- [x] Category matching check
- [x] Missing values check
- [x] Type validation (numeric targets)

**Weight validation:**
- [x] All positive
- [x] All finite
- [x] Length matches data
- [x] Mean approximately 1.0

---

### TEST4: Edge Cases

**Edge case tests:**

1. **Single stratum** (design weights)
   - All observations same category
   - Should work, all weights equal

2. **Perfect quota sample** (rim weights)
   - Sample already matches targets
   - Should converge in 1-2 iterations
   - Weights ≈1 for all

3. **Impossible targets** (rim weights)
   - Targets require category not in sample
   - Should fail or not converge

4. **Very small sample** (n<50)
   - Design weights: OK
   - Rim weights: May not converge

5. **Very large sample** (n>100,000)
   - Performance test
   - Should complete in reasonable time

6. **All missing in one category**
   - Should error early with clear message

---

## Success Criteria

### SC1: Functional Success

**Must achieve:**
- ✅ Calculate design weights correctly (verified against manual calculation)
- ✅ Calculate rim weights correctly (verified against anesrake direct usage)
- ✅ Handle multiple weight specifications
- ✅ Apply trimming correctly
- ✅ Generate accurate diagnostics
- ✅ Integrate with existing modules (crosstabs, tabs)

**Verification:**
- Unit tests pass (>95% coverage)
- Integration tests pass
- Manual validation against known results

---

### SC2: Usability Success

**User can:**
- ✅ Configure weights using Excel template (no R knowledge required)
- ✅ Understand diagnostic output (clear, actionable)
- ✅ Troubleshoot errors (clear error messages with solutions)
- ✅ Verify weight quality (comprehensive diagnostics)

**Verification:**
- Tested by non-technical user
- Documentation sufficient for self-service
- Error messages lead to successful resolution

---

### SC3: Quality Success

**Weights are:**
- ✅ Mathematically correct
- ✅ Reproducible (same config → same weights)
- ✅ Stable (small data changes → small weight changes)
- ✅ Transparent (can audit/explain methodology)

**Quality checks:**
- Effective sample size calculated correctly (Kish formula)
- Design effect reasonable (typically 1.0-2.0)
- Rim convergence when expected
- Edge cases handled gracefully

---

### SC4: Performance Success

**Performance targets:**
- Design weights: <1 second for n≤10,000
- Rim weights: <10 seconds for n≤10,000, k≤5
- Diagnostics: <2 seconds
- File I/O: <3 seconds

**Verification:**
- Benchmark tests on varying sample sizes
- No memory leaks
- Reasonable memory usage (<2x data size)

---

## Future Enhancements

### Phase 2 Features (Post-Launch)

**FE1: Cell weighting (interlocking quotas)**
- Calculate weights for joint category targets
- Handle sparse cells
- Validation for empty cells

**FE2: Interactive Shiny interface**
- GUI for weight configuration
- Real-time diagnostics
- Interactive trimming adjustment
- Visual weight distribution

**FE3: Weight comparison tools**
- Compare multiple weighting schemes
- Show impact on key metrics
- Recommend optimal approach

**FE4: Advanced diagnostics**
- Distribution plots (histogram, Q-Q plot)
- Influence diagnostics (high-leverage cases)
- Bias assessment (sample vs. population)
- Export diagnostics to PDF

**FE5: Population data integration**
- Built-in census data for common countries
- Auto-populate rim targets
- Update check for census releases

**FE6: Post-stratification weights**
- Combine probability sample with post-strat
- Variance estimation for complex designs
- Survey package integration

**FE7: Longitudinal weighting**
- Panel attrition adjustment
- Wave-to-wave weight updates
- Longitudinal weight tracking

---

## Appendix

### A1: anesrake Package Documentation

**Key function:**
```r
anesrake::anesrake(
  inputter,        # Target list
  dataframe,       # Survey data
  caseid,          # ID variable or row numbers
  weightvec = NULL,# Starting weights (NULL = all 1)
  cap = 5,         # Weight cap
  choosemethod = "total",  # Weighting method
  type = "pctlim", # Percentage limits
  pctlim = 0.05,   # Convergence tolerance (5%)
  nlim = 5,        # Min observations per category
  iterate = TRUE,  # Use raking algorithm
  weighttol = 0.00001,  # Weight convergence
  maxit = 1000,    # Max iterations
  convcrit = 0.01, # Convergence criterion
  center.baseweights = TRUE,
  force1 = FALSE   # Force weights to sum exactly to N?
)
```

**Returns:**
```r
$converge         # Logical, did it converge?
$iterations       # Number of iterations used
$weightvec        # Final weight vector
$raking.variables # Variables used
$caseid           # Case IDs
$targets          # Target list
$dataframe        # Input data
```

---

### A2: Example Configurations

**Example 1: Simple design weights**
```
Weight_Specifications:
weight_name: customer_weight
method: design
apply_trimming: N

Design_Targets:
weight_name: customer_weight
stratum_variable: customer_type
stratum_category: Small
population_size: 2000

weight_name: customer_weight
stratum_variable: customer_type
stratum_category: Large
population_size: 100
```

**Example 2: Rim weighting with trimming**
```
Weight_Specifications:
weight_name: population_weight
method: rim
apply_trimming: Y
trim_method: cap
trim_value: 5

Rim_Targets:
weight_name: population_weight
variable: Age
category: 18-34
target_percent: 30

weight_name: population_weight
variable: Age
category: 35-54
target_percent: 40

weight_name: population_weight
variable: Age
category: 55+
target_percent: 30

weight_name: population_weight
variable: Gender
category: Male
target_percent: 48

weight_name: population_weight
variable: Gender
category: Female
target_percent: 52
```

**Example 3: Multiple weights**
```
Weight_Specifications (2 rows):
Row 1: revenue_weight | design | ... 
Row 2: store_weight   | design | ...

Design_Targets:
revenue_weight targets on revenue_band
store_weight targets on store_count_band
```

---

### A3: Glossary

**Design weights:** Weights calculated from known sampling probabilities, typically for stratified samples. Formula: stratum_population / stratum_sample.

**Rim weighting (raking):** Iterative proportional fitting to match marginal distributions on multiple variables simultaneously. Also called raking or iterative proportional fitting (IPF).

**Cell weighting:** Weighting based on joint (interlocking) category combinations. Requires population data for all cells.

**Effective sample size:** The equivalent unweighted sample size that would give the same precision as the weighted sample. Formula: (Σw)² / Σw² (Kish 1965).

**Design effect:** Ratio of actual sample size to effective sample size. Measures loss of precision due to weighting. DEFF = n / n_eff.

**Coefficient of variation (CV):** Standard deviation / mean. Measures weight variability. CV > 1.0 indicates high variability.

**Weight trimming:** Capping extreme weights to reduce design effect and improve stability.

**Convergence:** In rim weighting, when achieved margins are within tolerance of target margins.

**Grossing weights:** Weights scaled to represent population totals (for extrapolation) rather than proportions.

---

## Document Control

**Version History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-24 | Duncan | Initial specification |

**Approval:**

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Product Owner | Duncan | 2025-12-24 | [Pending] |
| Technical Lead | [TBD] | [TBD] | [Pending] |

**Document Status:** Draft for Review

---

END OF SPECIFICATION
