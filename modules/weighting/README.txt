================================================================================
TURAS WEIGHTING MODULE
================================================================================
Version: 2.0
Date: December 2025
================================================================================

OVERVIEW
--------
The TURAS Weighting Module calculates survey weights using industry-standard
methods. It supports design weights for stratified samples and rim weights
(raking) for demographic adjustment.

FEATURES
--------
- Design weights: For stratified samples with known population sizes
- Rim weights: Iterative proportional fitting to match population margins
- Multiple weight columns: Calculate several weight sets in one run
- Weight trimming: Cap extreme weights to improve stability
- Comprehensive diagnostics: Design effect, efficiency, quality assessment
- Excel configuration: Easy-to-use Excel-based configuration

REQUIREMENTS
------------
Required R packages:
  - readxl (Excel file reading)
  - dplyr (data manipulation)
  - openxlsx (Excel output)
  - survey (rim weighting/calibration)

Install with:
  install.packages(c("readxl", "dplyr", "openxlsx", "survey"))


QUICK START
-----------
1. Create a configuration file (Weight_Config.xlsx) with your specifications
2. Run the weighting module:

   source("modules/weighting/run_weighting.R")
   result <- run_weighting("path/to/Weight_Config.xlsx")
   weighted_data <- result$data

Or from command line:
   Rscript modules/weighting/run_weighting.R path/to/Weight_Config.xlsx


CONFIGURATION FILE FORMAT
-------------------------
The Weight_Config.xlsx file has the following sheets:

1. GENERAL (Required)
   Configuration settings in Setting/Value format:

   Setting             | Value
   --------------------|----------------------------------
   project_name        | My_Survey_Project
   data_file           | data/survey_responses.csv
   output_file         | data/survey_weighted.csv
   save_diagnostics    | Y
   diagnostics_file    | output/weight_diagnostics.txt

2. WEIGHT_SPECIFICATIONS (Required)
   Define each weight to calculate:

   weight_name  | method | description           | apply_trimming | trim_method | trim_value
   -------------|--------|----------------------|----------------|-------------|------------
   seg_weight   | design | Segment weights      | Y              | cap         | 5
   pop_weight   | rim    | Population weights   | Y              | percentile  | 0.95

   - weight_name: Unique name for the weight column (will be added to data)
   - method: "design" or "rim"
   - apply_trimming: "Y" or "N" (default: N)
   - trim_method: "cap" (hard maximum) or "percentile"
   - trim_value: Maximum weight (for cap) or percentile threshold (0-1)

3. DESIGN_TARGETS (Required for design weights)
   Population sizes for each stratum:

   weight_name | stratum_variable | stratum_category | population_size
   ------------|------------------|------------------|----------------
   seg_weight  | segment          | Small            | 5000
   seg_weight  | segment          | Medium           | 3500
   seg_weight  | segment          | Large            | 1500

   Design weight = population_size / sample_size for each stratum

4. RIM_TARGETS (Required for rim weights)
   Target percentages for each variable/category:

   weight_name | variable | category | target_percent
   ------------|----------|----------|---------------
   pop_weight  | Age      | 18-34    | 30
   pop_weight  | Age      | 35-54    | 40
   pop_weight  | Age      | 55+      | 30
   pop_weight  | Gender   | Male     | 48
   pop_weight  | Gender   | Female   | 52

   NOTE: target_percent must sum to 100 for each variable

5. ADVANCED_SETTINGS (Optional)
   Rim weighting parameters:

   weight_name | max_iterations | convergence_tolerance | force_convergence
   ------------|----------------|----------------------|------------------
   pop_weight  | 25             | 0.01                 | N

   - max_iterations: Maximum raking iterations (default: 50)
   - convergence_tolerance: Stop when margins within % (default: 1e-7)
   - calibration_method: "raking", "linear", or "logit" (default: raking)
   - weight_bounds: Weight limits during calibration (default: 0.3,3.0)


DESIGN WEIGHTS
--------------
Use design weights when you have a stratified sample with known population
sizes for each stratum.

Example: Customer survey sampled by company size
  Population: 5000 small, 3500 medium, 1500 large companies
  Sample: 100 small, 80 medium, 60 large companies

  Design weight for small = 5000/100 = 50
  Design weight for medium = 3500/80 = 43.75
  Design weight for large = 1500/60 = 25

Use cases:
  - Stratified random samples
  - Customer lists with known segment sizes
  - Employee surveys by department


RIM WEIGHTS (RAKING)
--------------------
Use rim weights when you need to adjust sample demographics to match
known population margins.

Example: Online panel survey
  Sample has 45% male, 55% female
  Population is 48% male, 52% female
  Sample has Age: 40% 18-34, 35% 35-54, 25% 55+
  Population is: 30% 18-34, 40% 35-54, 30% 55+

Rim weighting iteratively adjusts weights until all margins match targets.

Use cases:
  - Online panel samples
  - Quota samples
  - General population surveys

Notes:
  - Requires survey package: install.packages("survey")
  - Maximum 5 variables recommended for convergence
  - All categories must exist in data
  - No missing values allowed in rim variables
  - Weight bounds applied DURING calibration (v2.0 improvement)


WEIGHT TRIMMING
---------------
Extreme weights can destabilize estimates. Trimming caps high weights.

Methods:
  - cap: Hard maximum (e.g., cap at 5 means no weight > 5)
  - percentile: Cap at percentile (e.g., 0.95 = 95th percentile)

Example in Weight_Specifications:
  apply_trimming = Y
  trim_method = cap
  trim_value = 5

After trimming, weights are NOT automatically rescaled. If you need
weights to sum to sample size, normalize after loading.


DIAGNOSTICS
-----------
The module generates comprehensive diagnostics:

SAMPLE SIZE:
  - Total cases
  - Valid weights (positive, finite)
  - NA/zero weights

WEIGHT DISTRIBUTION:
  - Min, Q1, Median, Q3, Max
  - Mean, SD, CV (coefficient of variation)

EFFECTIVE SAMPLE SIZE:
  - Effective N (Kish formula)
  - Design effect (n / effective_n)
  - Efficiency (effective_n / n as %)

QUALITY ASSESSMENT:
  - GOOD: Design effect < 2, CV < 0.5
  - ACCEPTABLE: Design effect 2-3, CV 0.5-1.0
  - POOR: Design effect > 3, CV > 1.0, or convergence failure


RETURN VALUE
------------
run_weighting() returns a list with:

  $data           Data frame with weight column(s) added
  $weight_names   Character vector of weight column names
  $weight_results List of detailed results per weight
  $config         Parsed configuration
  $output_file    Path to output file (if written)
  $diagnostics_file  Path to diagnostics file (if saved)

Access diagnostics:
  result$weight_results[["pop_weight"]]$diagnostics


CONVENIENCE FUNCTIONS
---------------------
For simple use cases without full configuration:

  # Quick design weight
  pop <- c("Small" = 5000, "Medium" = 3500, "Large" = 1500)
  data <- quick_design_weight(data, "segment", pop)

  # Quick rim weight
  targets <- list(
    Gender = c("Male" = 0.48, "Female" = 0.52),
    Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  data <- quick_rim_weight(data, targets)


TEMPLATE
--------
To create a configuration template:

  source("modules/weighting/templates/create_template.R")
  create_weight_config_template("my_project/Weight_Config.xlsx")

This creates a pre-populated template with example data.


TROUBLESHOOTING
---------------
1. "Package 'survey' not installed"
   Run: install.packages("survey")

2. "Rim weighting did not converge"
   - Increase max_iterations (try 100)
   - Try different calibration_method (logit handles bounds better)
   - Adjust weight_bounds if needed
   - Reduce number of rim variables
   - Check for impossible target combinations

3. "High design effect (> 3)"
   - Apply weight trimming
   - Review sampling design
   - Check for unusual response patterns

4. "Categories not found in data"
   - Ensure category values match exactly (case-sensitive)
   - Check for leading/trailing spaces
   - Verify variable names

5. "Targets don't sum to 100"
   - Rim targets must sum to exactly 100 per variable
   - Check for typos in percentages


INTEGRATION WITH OTHER TURAS MODULES
------------------------------------
Weighted data can be used directly with:
  - modules/tabs/ (crosstabulations)
  - modules/ranking/ (ranking analysis)
  - modules/crosstabs/ (banner tables)

Simply specify the weight column in those module configurations.


FILES
-----
modules/weighting/
  run_weighting.R          Main entry point
  lib/
    config_loader.R        Load Weight_Config.xlsx
    validation.R           Input validation
    design_weights.R       Design weight calculation
    rim_weights.R          Rim weight calculation (survey::calibrate)
    trimming.R             Weight capping/trimming
    diagnostics.R          Quality diagnostics
    output.R               Report generation
  templates/
    create_template.R      Generate config template
  README.txt               This file


REFERENCES
----------
Kish, L. (1965). Survey Sampling. John Wiley & Sons.
  - Effective sample size formula

Lumley, T. (2023). survey: Analysis of complex survey samples.
R package version 4.2+. https://CRAN.R-project.org/package=survey
  - Calibration methodology (survey::calibrate)

Deville, J.C. & Särndal, C.E. (1992). Calibration estimators in survey sampling.
Journal of the American Statistical Association, 87(418), 376-382.
  - Theoretical foundation for calibration weighting


SUPPORT
-------
For issues and feature requests, see the main TURAS documentation.

================================================================================
END OF README
================================================================================
