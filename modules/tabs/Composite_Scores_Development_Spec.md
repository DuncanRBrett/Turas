# TurasTabs Composite Scores & Index Summary - Development Specification

**Version:** 1.0  
**Date:** 2025-11-06  
**Developer:** Claude Code  
**Project:** TurasTabs Enhancement  
**Estimated Effort:** 2-3 weeks  

---

## 1. EXECUTIVE SUMMARY

### Objective
Add composite score calculation and index summary reporting to TurasTabs. This enhancement allows analysts to:
- Define composite metrics (e.g., "Overall Satisfaction" as average of 4 satisfaction questions)
- Automatically calculate composites across all banner columns
- Generate an executive summary sheet showing all key metrics in one view

### Core Principle
Composites are **virtual questions** - they're calculated from existing questions and processed through the exact same pipeline (banner columns, weighting, significance testing, Excel formatting).

### Deliverables
1. New module: `/modules/composite_processor.R`
2. New module: `/modules/summary_builder.R`
3. Enhanced: `Survey_Structure_Template.xlsx` (new sheet)
4. Enhanced: `run_crosstabs.R` (integration points)
5. Enhanced: Excel output (new Index_Summary sheet)
6. Test data and validation scripts

---

## 2. ARCHITECTURE OVERVIEW

### 2.1 Processing Flow

```
Current Flow:
┌─────────────────┐
│ Load Config     │
│ Load Data       │
│ Build Banner    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Process         │
│ Questions       │ ──► results_list
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Write Excel     │
│ - Crosstabs     │
└─────────────────┘

Enhanced Flow:
┌─────────────────┐
│ Load Config     │
│ Load Data       │
│ Build Banner    │
│ Load Composites │ ◄── NEW
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Process         │
│ Questions       │ ──► results_list
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Process         │ ◄── NEW
│ Composites      │ ──► composite_results
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Build Summary   │ ◄── NEW
│ Table           │ ──► summary_table
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Write Excel     │
│ - Summary       │
│ - Index Summary │ ◄── NEW
│ - Crosstabs     │
│ - Sample Comp   │
└─────────────────┘
```

### 2.2 Module Dependencies

```
composite_processor.R
├── Requires: cell_calculator.R (calculate_summary_statistic)
├── Requires: banner.R (banner structure)
├── Requires: weighting.R (apply_weights)
├── Requires: validation.R (error handling)
└── Produces: composite_results (same structure as results_list)

summary_builder.R
├── Requires: results_list (from standard processing)
├── Requires: composite_results (from composite processing)
├── Requires: banner.R (column structure)
└── Produces: summary_table (data frame for Excel)
```

---

## 3. FILE SPECIFICATIONS

### 3.1 Survey_Structure_Template.xlsx - New Sheet: "Composite_Metrics"

**Sheet Purpose:** Define composite scores that combine multiple questions

**Column Specifications:**

| Column | Type | Required | Validation | Description |
|--------|------|----------|------------|-------------|
| CompositeCode | Text | Yes | Must be unique, alphanumeric + underscore, start with COMP_ | Unique identifier (e.g., COMP_SAT_OVERALL) |
| CompositeLabel | Text | Yes | Max 200 chars | Display label for reports |
| CalculationType | Text | Yes | Must be: Mean, Sum, WeightedMean | How to combine source questions |
| SourceQuestions | Text | Yes | Comma-separated QuestionCodes that exist in Survey_Structure | Questions to combine (e.g., SAT_01,SAT_02,SAT_03) |
| Weights | Text | Conditional | Required if CalculationType=WeightedMean. Comma-separated numbers matching SourceQuestions count | Weights for each source (e.g., 1,1,2,1) |
| ExcludeFromSummary | Text | No | Y or blank | If Y, don't show in Index_Summary sheet |
| SectionLabel | Text | No | Max 100 chars | Groups composites in summary (e.g., SATISFACTION METRICS) |
| Notes | Text | No | Max 500 chars | Internal documentation |

**Example Rows:**

| CompositeCode | CompositeLabel | CalculationType | SourceQuestions | Weights | ExcludeFromSummary | SectionLabel |
|---------------|----------------|-----------------|-----------------|---------|-------------------|--------------|
| COMP_SAT_OVERALL | Overall Satisfaction | Mean | SAT_01,SAT_02,SAT_03,SAT_04 | | | SATISFACTION METRICS |
| COMP_QUALITY | Quality Index | WeightedMean | QUAL_01,QUAL_02,QUAL_03 | 2,1,1 | | QUALITY METRICS |
| COMP_LIKELIHOOD | Total Likelihood Score | Sum | LIK_01,LIK_02,LIK_03 | | | BEHAVIORAL METRICS |

**Validation Rules:**
1. All SourceQuestions must exist in Questions sheet
2. All SourceQuestions must be same type (all Rating, or all Likert, or all Numeric)
3. If CalculationType = WeightedMean, Weights must be provided
4. Number of weights must equal number of SourceQuestions
5. Weights must be positive numbers
6. CompositeCode cannot duplicate any QuestionCode

---

### 3.2 Crosstab_Config.xlsx - Settings Sheet (Additions)

Add these rows to the Settings sheet:

| Setting | Value | Options | Description |
|---------|-------|---------|-------------|
| create_index_summary | Y | Y/N | Create Index_Summary sheet |
| index_summary_show_sections | Y | Y/N | Group by SectionLabel |
| index_summary_show_base_sizes | Y | Y/N | Show base sizes at bottom |
| index_summary_show_composites | Y | Y/N | Include composite scores |
| index_summary_decimal_places | 1 | 0-3 | Override decimal places for summary |

**Default Values:** All Y, decimal_places = 1

---

## 4. NEW MODULE: composite_processor.R

### 4.1 Module Header

```r
# ==============================================================================
# MODULE: COMPOSITE_PROCESSOR.R
# ==============================================================================
#
# PURPOSE:
#   Process composite metrics that combine multiple questions
#   Composites are treated as "virtual questions" and processed through
#   the same pipeline as regular questions (banner, weighting, significance)
#
# FUNCTIONS:
#   - load_composite_definitions() - Load from Survey_Structure.xlsx
#   - validate_composite_definitions() - Pre-flight checks
#   - process_composite_question() - Main processor for one composite
#   - process_all_composites() - Process all composites
#   - calculate_composite_values() - Core calculation logic
#
# DEPENDENCIES:
#   - cell_calculator.R (calculate_summary_statistic)
#   - banner.R (get_banner_subsets)
#   - weighting.R (apply_weights)
#   - validation.R (error handling)
#
# VERSION: 1.0.0
# DATE: 2025-11-06
# ==============================================================================
```

### 4.2 Function Specifications

#### Function: `load_composite_definitions()`

**Purpose:** Load composite definitions from Survey_Structure.xlsx

**Signature:**
```r
load_composite_definitions <- function(survey_structure_file) {
  # Returns: data frame with composite definitions or NULL if sheet doesn't exist
}
```

**Logic:**
1. Check if "Composite_Metrics" sheet exists in survey_structure_file
2. If not, return NULL (no composites defined - this is valid)
3. If exists, read sheet
4. Validate required columns exist
5. Clean data (trim whitespace, handle NA)
6. Return data frame

**Error Handling:**
- If sheet exists but is empty → Warning, return NULL
- If required columns missing → Error, stop processing
- If any row has blank CompositeCode → Warning, skip that row

**Returns:**
```r
# Data frame structure:
data.frame(
  CompositeCode = character(),      # "COMP_SAT_OVERALL"
  CompositeLabel = character(),     # "Overall Satisfaction"
  CalculationType = character(),    # "Mean", "Sum", "WeightedMean"
  SourceQuestions = character(),    # "SAT_01,SAT_02,SAT_03"
  Weights = character(),            # "1,1,2" or NA
  ExcludeFromSummary = character(), # "Y" or NA
  SectionLabel = character(),       # "SATISFACTION METRICS" or NA
  Notes = character()               # Documentation or NA
)
```

---

#### Function: `validate_composite_definitions()`

**Purpose:** Validate composite definitions against survey structure

**Signature:**
```r
validate_composite_definitions <- function(composite_defs, questions_df, survey_data) {
  # Returns: list(is_valid = TRUE/FALSE, errors = character vector)
}
```

**Validation Checks:**

1. **CompositeCode uniqueness**
   - No duplicate CompositeCodes
   - No CompositeCode that matches existing QuestionCode
   - Error if violated

2. **SourceQuestions existence**
   - Parse comma-separated SourceQuestions
   - Check each exists in questions_df$QuestionCode
   - Check each exists as column in survey_data
   - Error if any missing

3. **SourceQuestions type compatibility**
   - Get Variable_Type for each source question
   - All must be same type: Rating, Likert, or Numeric
   - Cannot mix types (e.g., Rating + Likert)
   - Error if mixed

4. **CalculationType validation**
   - Must be: "Mean", "Sum", or "WeightedMean"
   - Error if invalid

5. **Weights validation** (if CalculationType = WeightedMean)
   - Weights must be provided
   - Parse comma-separated weights
   - Count must equal count of SourceQuestions
   - All weights must be numeric
   - All weights must be > 0
   - Error if violated

6. **SourceQuestions have values**
   - For each source question, check if it has ExcludeFromIndex != "Y"
   - At least one source must have usable values
   - Warning if all sources are excluded from index

**Returns:**
```r
list(
  is_valid = TRUE,  # FALSE if any errors
  errors = c(),     # Character vector of error messages
  warnings = c()    # Character vector of warnings
)
```

---

#### Function: `calculate_composite_values()`

**Purpose:** Calculate composite score for one respondent subset

**Signature:**
```r
calculate_composite_values <- function(data_subset, source_questions, 
                                       calculation_type, weights = NULL,
                                       weight_vector = NULL) {
  # Returns: numeric vector of composite values (one per respondent)
}
```

**Logic:**

**Step 1: Extract source values**
```r
# For each source question, get the numeric value
# Handle Rating: use OptionValue if available, else numeric conversion
# Handle Likert: use OptionValue
# Handle Numeric: use value directly

source_values_matrix <- matrix(NA, nrow = nrow(data_subset), 
                                ncol = length(source_questions))

for (i in seq_along(source_questions)) {
  q_code <- source_questions[i]
  source_values_matrix[, i] <- get_numeric_value(data_subset[[q_code]], 
                                                   question_type)
}
```

**Step 2: Handle missing values**
```r
# For each row:
# - If ALL source values are NA → composite is NA
# - If SOME are NA → exclude those from calculation (pairwise deletion)
# - Track how many valid sources each respondent has

valid_count <- rowSums(!is.na(source_values_matrix))
composite_values <- rep(NA_real_, nrow(data_subset))
```

**Step 3: Calculate based on type**
```r
if (calculation_type == "Mean") {
  # Simple mean of available values
  composite_values <- rowMeans(source_values_matrix, na.rm = TRUE)
  
} else if (calculation_type == "Sum") {
  # Sum of available values
  composite_values <- rowSums(source_values_matrix, na.rm = TRUE)
  
} else if (calculation_type == "WeightedMean") {
  # Weighted mean: sum(values * weights) / sum(weights for non-NA values)
  for (i in 1:nrow(source_values_matrix)) {
    row_values <- source_values_matrix[i, ]
    valid_idx <- !is.na(row_values)
    if (sum(valid_idx) > 0) {
      composite_values[i] <- sum(row_values[valid_idx] * weights[valid_idx]) / 
                              sum(weights[valid_idx])
    }
  }
}

# Set to NA if no valid sources
composite_values[valid_count == 0] <- NA
```

**Step 4: Apply survey weights (if provided)**
```r
if (!is.null(weight_vector)) {
  # Weight vector is survey-level weights (not calculation weights)
  # Used for weighted mean calculation
  weighted_mean <- weighted.mean(composite_values, w = weight_vector, na.rm = TRUE)
  return(weighted_mean)
} else {
  return(composite_values)
}
```

**Returns:** Numeric vector (unweighted) or single value (weighted)

---

#### Function: `process_composite_question()`

**Purpose:** Process one composite through the full crosstab pipeline

**Signature:**
```r
process_composite_question <- function(composite_def, data, questions_df,
                                       banner_info, config) {
  # Returns: list(question_table, metadata) - same structure as standard questions
}
```

**Logic:**

**Step 1: Create synthetic question_info**
```r
# Build a question_info structure that mimics a regular question
# This allows reuse of existing cell_calculator functions

source_questions <- strsplit(composite_def$SourceQuestions, ",")[[1]]
source_questions <- trimws(source_questions)

# Get the type from first source question
first_source <- questions_df[questions_df$QuestionCode == source_questions[1], ]
source_type <- first_source$Variable_Type  # "Rating", "Likert", or "Numeric"

question_info <- list(
  QuestionCode = composite_def$CompositeCode,
  QuestionText = composite_def$CompositeLabel,
  Variable_Type = source_type,  # Same as sources
  QuestionType = "Composite",   # NEW type
  SourceQuestions = source_questions,
  CalculationType = composite_def$CalculationType,
  Weights = if (!is.na(composite_def$Weights)) {
    as.numeric(strsplit(composite_def$Weights, ",")[[1]])
  } else NULL
)
```

**Step 2: Calculate composite values and add to data**
```r
# Calculate composite for full dataset
composite_values <- calculate_composite_values(
  data_subset = data,
  source_questions = source_questions,
  calculation_type = composite_def$CalculationType,
  weights = question_info$Weights
)

# Add as new column to data
data[[composite_def$CompositeCode]] <- composite_values
```

**Step 3: Process through banner structure**
```r
# Initialize results table
results_table <- data.frame()
internal_keys <- banner_info$internal_keys

# For each banner column, calculate the composite score
for (key in internal_keys) {
  # Get subset for this banner column
  subset_indices <- banner_info$subsets[[key]]
  data_subset <- data[subset_indices, ]
  
  # Apply weights if configured
  weights <- if (config$apply_weighting) {
    data_subset[[config$weight_variable]]
  } else NULL
  
  # Calculate weighted mean for this subset
  composite_value <- calculate_composite_values(
    data_subset = data_subset,
    source_questions = source_questions,
    calculation_type = composite_def$CalculationType,
    weights = question_info$Weights,
    weight_vector = weights
  )
  
  # Store in results (same structure as rating/index rows)
  # This is a single row showing the composite score
}
```

**Step 4: Build output table**
```r
# Create table matching standard question output format
# Row 1: Base sizes (like any other question)
# Row 2: Composite score (like Average or Index row)
# Row 3: Significance letters (if enabled)

result_table <- build_composite_output_table(
  composite_def = composite_def,
  banner_results = banner_results,
  banner_info = banner_info,
  config = config
)
```

**Step 5: Run significance testing**
```r
# Composites tested like any other numeric metric
# Use t-test for mean comparisons across banner columns

if (config$enable_significance_testing) {
  sig_results <- test_composite_significance(
    data = data,
    composite_code = composite_def$CompositeCode,
    banner_info = banner_info,
    config = config
  )
  
  # Add significance row to result_table
  result_table <- rbind(result_table, sig_results$sig_row)
}
```

**Returns:**
```r
list(
  question_table = result_table,  # Data frame with rows for composite
  metadata = list(
    composite_code = composite_def$CompositeCode,
    source_questions = source_questions,
    calculation_type = composite_def$CalculationType,
    has_significance = config$enable_significance_testing
  )
)
```

---

#### Function: `process_all_composites()`

**Purpose:** Process all composite definitions

**Signature:**
```r
process_all_composites <- function(composite_defs, data, questions_df, 
                                    banner_info, config) {
  # Returns: list of results (same structure as results_list from standard processing)
}
```

**Logic:**
```r
if (is.null(composite_defs) || nrow(composite_defs) == 0) {
  return(list())  # No composites
}

composite_results <- list()

for (i in 1:nrow(composite_defs)) {
  composite_def <- composite_defs[i, ]
  
  tryCatch({
    result <- process_composite_question(
      composite_def = composite_def,
      data = data,
      questions_df = questions_df,
      banner_info = banner_info,
      config = config
    )
    
    composite_results[[composite_def$CompositeCode]] <- result
    
  }, error = function(e) {
    warning(paste("Error processing composite", composite_def$CompositeCode, 
                  ":", e$message))
  })
}

return(composite_results)
```

---

## 5. NEW MODULE: summary_builder.R

### 5.1 Module Header

```r
# ==============================================================================
# MODULE: SUMMARY_BUILDER.R
# ==============================================================================
#
# PURPOSE:
#   Build Index_Summary sheet that consolidates all key metrics
#   Extracts means, indices, NPS scores, top box summaries, and composites
#
# FUNCTIONS:
#   - build_index_summary_table() - Main builder
#   - extract_metric_rows() - Extract specific row types
#   - group_by_sections() - Apply section grouping
#   - format_summary_table() - Prepare for Excel output
#
# VERSION: 1.0.0
# DATE: 2025-11-06
# ==============================================================================
```

### 5.2 Function Specifications

#### Function: `build_index_summary_table()`

**Purpose:** Build complete summary table from all results

**Signature:**
```r
build_index_summary_table <- function(results_list, composite_results, 
                                       banner_info, config, composite_defs = NULL) {
  # Returns: data frame ready for Excel output
}
```

**Logic:**

**Step 1: Extract metric rows from standard questions**
```r
# From results_list, extract rows where RowType is:
# - "Average" (rating questions)
# - "Index" (Likert questions)
# - "Score" (NPS questions)

metric_rows <- list()

for (question_code in names(results_list)) {
  question_result <- results_list[[question_code]]
  table <- question_result$question_table
  
  # Find metric rows
  avg_rows <- table[table$RowType == "Average", ]
  idx_rows <- table[table$RowType == "Index", ]
  score_rows <- table[table$RowType == "Score", ]
  
  # Also get "Top 2 Box" or "Bottom 2 Box" if they exist
  box_rows <- table[grepl("Top.*Box|Bottom.*Box", table$RowLabel), ]
  
  if (nrow(avg_rows) > 0) metric_rows[[length(metric_rows) + 1]] <- avg_rows
  if (nrow(idx_rows) > 0) metric_rows[[length(metric_rows) + 1]] <- idx_rows
  if (nrow(score_rows) > 0) metric_rows[[length(metric_rows) + 1]] <- score_rows
  if (nrow(box_rows) > 0) metric_rows[[length(metric_rows) + 1]] <- box_rows
}

standard_metrics <- do.call(rbind, metric_rows)
```

**Step 2: Extract composite rows**
```r
if (config$index_summary_show_composites && length(composite_results) > 0) {
  
  composite_rows <- list()
  
  for (comp_code in names(composite_results)) {
    comp_result <- composite_results[[comp_code]]
    table <- comp_result$question_table
    
    # Composite tables should have the score row
    metric_row <- table[table$RowType %in% c("Average", "Index", "Score"), ]
    
    if (nrow(metric_row) > 0) {
      # Mark as composite and add section
      metric_row$IsComposite <- TRUE
      
      # Look up section from composite_defs
      if (!is.null(composite_defs)) {
        comp_def <- composite_defs[composite_defs$CompositeCode == comp_code, ]
        if (nrow(comp_def) > 0 && !is.na(comp_def$SectionLabel)) {
          metric_row$Section <- comp_def$SectionLabel
        }
      }
      
      composite_rows[[length(composite_rows) + 1]] <- metric_row
    }
  }
  
  composite_metrics <- do.call(rbind, composite_rows)
  
} else {
  composite_metrics <- data.frame()
}
```

**Step 3: Combine and sort**
```r
# Combine standard and composite metrics
all_metrics <- rbind(
  cbind(standard_metrics, IsComposite = FALSE, Section = NA),
  composite_metrics
)

# Sort by Section (if enabled), then by RowLabel
if (config$index_summary_show_sections) {
  all_metrics <- all_metrics[order(all_metrics$Section, all_metrics$RowLabel), ]
} else {
  all_metrics <- all_metrics[order(all_metrics$RowLabel), ]
}
```

**Step 4: Add section header rows**
```r
if (config$index_summary_show_sections) {
  # Insert section header rows
  all_metrics <- insert_section_headers(all_metrics, banner_info)
}
```

**Step 5: Format for Excel**
```r
# Ensure consistent formatting
# - Composite rows get special marking (→ prefix or different style)
# - Section headers are bold
# - Column structure matches Crosstabs sheet exactly

summary_table <- format_summary_for_excel(all_metrics, banner_info, config)
```

**Returns:**
```r
# Data frame structure matches crosstabs output:
data.frame(
  RowLabel = character(),        # Metric name (or section header)
  RowType = character(),          # "Average", "Index", "Score", "SectionHeader"
  IsComposite = logical(),        # TRUE if from composite_results
  Section = character(),          # Section grouping
  # ... banner columns (same as crosstabs)
  TOTAL::Total = character(),
  Gender::Male = character(),
  Gender::Female = character(),
  # etc.
)
```

---

#### Function: `insert_section_headers()`

**Purpose:** Insert section header rows into summary table

**Signature:**
```r
insert_section_headers <- function(metrics_df, banner_info) {
  # Returns: data frame with section header rows inserted
}
```

**Logic:**
```r
# Get unique sections (excluding NA)
sections <- unique(metrics_df$Section[!is.na(metrics_df$Section)])

if (length(sections) == 0) return(metrics_df)

# Build new table with headers
result_rows <- list()

for (section in sections) {
  # Create header row
  header_row <- data.frame(
    RowLabel = paste("Section:", section),
    RowType = "SectionHeader",
    IsComposite = NA,
    Section = section,
    stringsAsFactors = FALSE
  )
  
  # Add empty values for all banner columns
  for (key in banner_info$internal_keys) {
    header_row[[key]] <- ""
  }
  
  result_rows[[length(result_rows) + 1]] <- header_row
  
  # Add all metrics in this section
  section_metrics <- metrics_df[metrics_df$Section == section & 
                                  !is.na(metrics_df$Section), ]
  result_rows[[length(result_rows) + 1]] <- section_metrics
}

# Add metrics with no section at the end
no_section_metrics <- metrics_df[is.na(metrics_df$Section), ]
if (nrow(no_section_metrics) > 0) {
  result_rows[[length(result_rows) + 1]] <- no_section_metrics
}

return(do.call(rbind, result_rows))
```

---

#### Function: `format_summary_for_excel()`

**Purpose:** Format summary table for Excel output with special styling cues

**Signature:**
```r
format_summary_for_excel <- function(metrics_df, banner_info, config) {
  # Returns: formatted data frame with style hints
}
```

**Logic:**
```r
# Add formatting hints as additional columns (removed before writing)
metrics_df$StyleHint <- "Normal"
metrics_df$StyleHint[metrics_df$RowType == "SectionHeader"] <- "SectionHeader"
metrics_df$StyleHint[metrics_df$IsComposite == TRUE] <- "Composite"

# Add prefix to composite labels
metrics_df$RowLabel[metrics_df$IsComposite == TRUE] <- 
  paste0("→ ", metrics_df$RowLabel[metrics_df$IsComposite == TRUE])

# Clean up display
metrics_df$RowLabel <- trimws(metrics_df$RowLabel)

# Ensure consistent decimal places (use index_summary_decimal_places)
decimal_places <- if (!is.null(config$index_summary_decimal_places)) {
  config$index_summary_decimal_places
} else {
  1  # Default
}

# Format all numeric columns
for (key in banner_info$internal_keys) {
  if (key %in% names(metrics_df)) {
    # Extract numeric values
    values <- as.numeric(gsub("[^0-9.-]", "", metrics_df[[key]]))
    # Reformat with consistent decimals
    metrics_df[[key]] <- format_output_value(values, "rating", decimal_places)
  }
}

return(metrics_df)
```

---

## 6. INTEGRATION INTO run_crosstabs.R

### 6.1 Modification Points

**Location 1: After loading survey structure**

```r
# EXISTING CODE:
questions_df <- load_survey_structure(config$survey_structure_file)

# ADD AFTER:
# Load composite definitions
composite_defs <- load_composite_definitions(config$survey_structure_file)

if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
  cat(sprintf("Loaded %d composite metric(s)\n", nrow(composite_defs)))
  
  # Validate composites
  validation_result <- validate_composite_definitions(
    composite_defs = composite_defs,
    questions_df = questions_df,
    survey_data = data
  )
  
  if (!validation_result$is_valid) {
    stop("Composite validation failed:\n", 
         paste(validation_result$errors, collapse = "\n"))
  }
  
  if (length(validation_result$warnings) > 0) {
    for (warn in validation_result$warnings) {
      warning(warn)
    }
  }
} else {
  cat("No composite metrics defined\n")
}
```

**Location 2: After processing all questions**

```r
# EXISTING CODE:
results_list <- list()
for (i in 1:nrow(questions_df)) {
  # ... process question ...
  results_list[[question_code]] <- result
}

# ADD AFTER:
# Process composite questions
composite_results <- list()

if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
  cat("\nProcessing composite metrics...\n")
  
  composite_results <- process_all_composites(
    composite_defs = composite_defs,
    data = data,
    questions_df = questions_df,
    banner_info = banner_info,
    config = config
  )
  
  cat(sprintf("Processed %d composite(s)\n", length(composite_results)))
}
```

**Location 3: Before Excel output**

```r
# ADD NEW SECTION:
# Build index summary table
summary_table <- NULL

if (config$create_index_summary) {
  cat("\nBuilding index summary...\n")
  
  summary_table <- build_index_summary_table(
    results_list = results_list,
    composite_results = composite_results,
    banner_info = banner_info,
    config = config,
    composite_defs = composite_defs
  )
  
  cat(sprintf("Summary table has %d metrics\n", nrow(summary_table)))
}
```

**Location 4: Excel writing section**

```r
# EXISTING CODE:
write_summary_sheet(wb, config, banner_info, ...)
write_crosstabs_sheet(wb, results_list, banner_info, ...)

# ADD BETWEEN SUMMARY AND CROSSTABS:
# Write Index_Summary sheet
if (!is.null(summary_table)) {
  cat("Writing Index_Summary sheet...\n")
  write_index_summary_sheet(
    wb = wb,
    summary_table = summary_table,
    banner_info = banner_info,
    config = config,
    styles = styles
  )
}

# CONTINUE WITH EXISTING:
write_crosstabs_sheet(wb, results_list, banner_info, ...)
```

---

## 7. EXCEL OUTPUT: Index_Summary Sheet

### 7.1 Function: `write_index_summary_sheet()`

**Purpose:** Write formatted Index_Summary sheet to Excel workbook

**Signature:**
```r
write_index_summary_sheet <- function(wb, summary_table, banner_info, 
                                       config, styles) {
  # Side effect: Adds "Index_Summary" sheet to workbook
}
```

**Sheet Structure:**

```
Row 1: [Empty]
Row 2: INDEX & RATING SUMMARY
Row 3: Survey: [SurveyName]
Row 4: Base: [BaseDescription]
Row 5: [Empty]
Row 6: Column Headers
Row 7: Banner column labels (Total, Male, Female, etc.)
Row 8+: Metrics and section headers
Last Row: [Empty]
Last Row+1: Base sizes (if enabled)
```

**Styling:**

```r
# Style 1: Title (Row 2)
title_style <- createStyle(
  fontSize = 14,
  textDecoration = "bold",
  halign = "left"
)

# Style 2: Section Headers
section_style <- createStyle(
  fontSize = 11,
  textDecoration = "bold",
  fgFill = "#E8E8E8",  # Light gray
  border = "TopBottom"
)

# Style 3: Composite Rows
composite_style <- createStyle(
  fontSize = 10,
  fgFill = "#FFF8DC",  # Light yellow/cream
  textDecoration = "italic"
)

# Style 4: Standard Metrics
metric_style <- createStyle(
  fontSize = 10,
  halign = "left"
)

# Style 5: Data Cells (numbers)
data_style <- createStyle(
  fontSize = 10,
  halign = "right",
  numFmt = "0.0"  # Or based on config decimal places
)

# Style 6: Significance Letters
sig_style <- createStyle(
  fontSize = 8,
  textDecoration = "bold",
  fontColour = "#0066CC"
)
```

**Column Widths:**
- Column A (RowLabel): 40 characters
- Data columns: 12 characters each

**Logic:**
```r
# Create sheet
addWorksheet(wb, "Index_Summary")

current_row <- 1

# Write title section
writeData(wb, "Index_Summary", "INDEX & RATING SUMMARY", 
          startCol = 1, startRow = current_row)
addStyle(wb, "Index_Summary", title_style, rows = current_row, cols = 1)
current_row <- current_row + 2

# Write metadata
writeData(wb, "Index_Summary", 
          paste("Survey:", config$project_name), 
          startRow = current_row)
current_row <- current_row + 1

writeData(wb, "Index_Summary", 
          paste("Base:", banner_info$base_description), 
          startRow = current_row)
current_row <- current_row + 2

# Write column headers
headers <- c("Metric", banner_info$column_labels)
writeData(wb, "Index_Summary", t(headers), 
          startCol = 1, startRow = current_row)
addStyle(wb, "Index_Summary", styles$header_style, 
         rows = current_row, cols = 1:length(headers))
current_row <- current_row + 1

# Write data rows
for (i in 1:nrow(summary_table)) {
  row_data <- summary_table[i, ]
  
  # Determine style based on row type
  if (row_data$StyleHint == "SectionHeader") {
    row_style <- section_style
  } else if (row_data$StyleHint == "Composite") {
    row_style <- composite_style
  } else {
    row_style <- metric_style
  }
  
  # Write row label
  writeData(wb, "Index_Summary", row_data$RowLabel, 
            startCol = 1, startRow = current_row)
  addStyle(wb, "Index_Summary", row_style, 
           rows = current_row, cols = 1)
  
  # Write data values (skip if section header)
  if (row_data$StyleHint != "SectionHeader") {
    for (j in seq_along(banner_info$internal_keys)) {
      key <- banner_info$internal_keys[j]
      value <- row_data[[key]]
      
      writeData(wb, "Index_Summary", value, 
                startCol = j + 1, startRow = current_row)
      addStyle(wb, "Index_Summary", data_style, 
               rows = current_row, cols = j + 1)
    }
  }
  
  current_row <- current_row + 1
}

# Add base sizes at bottom (if enabled)
if (config$index_summary_show_base_sizes) {
  current_row <- current_row + 1
  
  # Write "Base sizes:" label
  writeData(wb, "Index_Summary", "Base sizes:", 
            startCol = 1, startRow = current_row)
  
  # Write unweighted n
  current_row <- current_row + 1
  writeData(wb, "Index_Summary", "Unweighted n:", 
            startCol = 1, startRow = current_row)
  
  for (j in seq_along(banner_info$internal_keys)) {
    key <- banner_info$internal_keys[j]
    n <- banner_info$base_sizes[[key]]$unweighted
    writeData(wb, "Index_Summary", n, 
              startCol = j + 1, startRow = current_row)
  }
  
  # Write weighted n (if applicable)
  if (config$apply_weighting) {
    current_row <- current_row + 1
    writeData(wb, "Index_Summary", "Weighted n:", 
              startCol = 1, startRow = current_row)
    
    for (j in seq_along(banner_info$internal_keys)) {
      key <- banner_info$internal_keys[j]
      n <- banner_info$base_sizes[[key]]$weighted
      writeData(wb, "Index_Summary", round(n, 0), 
                startCol = j + 1, startRow = current_row)
    }
  }
}

# Set column widths
setColWidths(wb, "Index_Summary", cols = 1, widths = 40)
setColWidths(wb, "Index_Summary", cols = 2:(length(headers)), widths = 12)
```

---

## 8. TESTING REQUIREMENTS

### 8.1 Unit Tests

Create test file: `tests/test_composite_processor.R`

**Test 1: Load composite definitions**
```r
test_that("load_composite_definitions handles missing sheet", {
  # Test with file that has no Composite_Metrics sheet
  result <- load_composite_definitions(test_file_no_composites)
  expect_null(result)
})

test_that("load_composite_definitions loads valid composites", {
  result <- load_composite_definitions(test_file_with_composites)
  expect_s3_class(result, "data.frame")
  expect_true("CompositeCode" %in% names(result))
  expect_gt(nrow(result), 0)
})
```

**Test 2: Validation**
```r
test_that("validate_composite_definitions catches duplicate codes", {
  composite_defs <- data.frame(
    CompositeCode = c("COMP_A", "COMP_A"),
    # ... other fields
  )
  result <- validate_composite_definitions(composite_defs, questions_df, data)
  expect_false(result$is_valid)
  expect_true(any(grepl("duplicate", result$errors, ignore.case = TRUE)))
})

test_that("validate_composite_definitions catches missing source questions", {
  composite_defs <- data.frame(
    CompositeCode = "COMP_A",
    SourceQuestions = "Q1,Q2,NONEXISTENT",
    # ...
  )
  result <- validate_composite_definitions(composite_defs, questions_df, data)
  expect_false(result$is_valid)
})

test_that("validate_composite_definitions catches mismatched weights", {
  composite_defs <- data.frame(
    CompositeCode = "COMP_A",
    CalculationType = "WeightedMean",
    SourceQuestions = "Q1,Q2,Q3",
    Weights = "1,2"  # Only 2 weights for 3 questions
  )
  result <- validate_composite_definitions(composite_defs, questions_df, data)
  expect_false(result$is_valid)
})
```

**Test 3: Calculation**
```r
test_that("calculate_composite_values computes mean correctly", {
  data_subset <- data.frame(
    Q1 = c(5, 4, 3),
    Q2 = c(4, 5, 4),
    Q3 = c(5, 5, 5)
  )
  
  result <- calculate_composite_values(
    data_subset = data_subset,
    source_questions = c("Q1", "Q2", "Q3"),
    calculation_type = "Mean"
  )
  
  expect_equal(result, c(4.67, 4.67, 4.00), tolerance = 0.01)
})

test_that("calculate_composite_values handles NA values", {
  data_subset <- data.frame(
    Q1 = c(5, NA, 3),
    Q2 = c(4, 5, NA),
    Q3 = c(5, 5, 5)
  )
  
  result <- calculate_composite_values(
    data_subset = data_subset,
    source_questions = c("Q1", "Q2", "Q3"),
    calculation_type = "Mean"
  )
  
  expect_equal(result[1], 4.67, tolerance = 0.01)
  expect_equal(result[2], 5.00, tolerance = 0.01)
  expect_equal(result[3], 4.00, tolerance = 0.01)
})

test_that("calculate_composite_values computes weighted mean correctly", {
  data_subset <- data.frame(
    Q1 = c(5, 4, 3),
    Q2 = c(4, 5, 4)
  )
  
  result <- calculate_composite_values(
    data_subset = data_subset,
    source_questions = c("Q1", "Q2"),
    calculation_type = "WeightedMean",
    weights = c(2, 1)  # Q1 weighted 2x Q2
  )
  
  # (5*2 + 4*1) / 3 = 4.67
  expect_equal(result[1], 4.67, tolerance = 0.01)
})
```

**Test 4: Summary builder**
```r
test_that("build_index_summary_table extracts correct rows", {
  # Create mock results_list
  results_list <- list(
    Q1 = list(question_table = data.frame(
      RowLabel = c("Very Satisfied", "Average"),
      RowType = c("Frequency", "Average"),
      Total = c("50", "7.2")
    ))
  )
  
  summary <- build_index_summary_table(
    results_list = results_list,
    composite_results = list(),
    banner_info = mock_banner_info,
    config = mock_config
  )
  
  expect_true(any(summary$RowType == "Average"))
  expect_false(any(summary$RowType == "Frequency"))
})

test_that("build_index_summary_table includes composites", {
  composite_results <- list(
    COMP_A = list(question_table = data.frame(
      RowLabel = "Overall Score",
      RowType = "Average",
      Total = "7.5"
    ))
  )
  
  summary <- build_index_summary_table(
    results_list = list(),
    composite_results = composite_results,
    banner_info = mock_banner_info,
    config = list(index_summary_show_composites = TRUE)
  )
  
  expect_true(any(summary$IsComposite == TRUE))
  expect_true(any(grepl("→", summary$RowLabel)))
})
```

### 8.2 Integration Tests

Create test file: `tests/test_composite_integration.R`

**Test: End-to-end composite processing**
```r
test_that("full pipeline processes composites correctly", {
  # Setup test files
  config_file <- "tests/test_data/config_with_composites.xlsx"
  structure_file <- "tests/test_data/survey_structure_with_composites.xlsx"
  data_file <- "tests/test_data/survey_data_composite_test.csv"
  
  # Run full pipeline
  result <- run_crosstabs(config_file)
  
  # Check output file exists
  expect_true(file.exists(result$output_file))
  
  # Load output and verify Index_Summary sheet exists
  wb <- loadWorkbook(result$output_file)
  sheets <- names(wb)
  expect_true("Index_Summary" %in% sheets)
  
  # Read Index_Summary and verify content
  summary_data <- read.xlsx(wb, sheet = "Index_Summary", startRow = 6)
  expect_gt(nrow(summary_data), 0)
  
  # Verify composites are marked
  expect_true(any(grepl("→", summary_data$Metric)))
})
```

### 8.3 Test Data

Create minimal test dataset: `tests/test_data/survey_data_composite_test.csv`

```csv
RespondentID,Gender,Age_Group,SAT_01,SAT_02,SAT_03,Weight
1,Male,18-24,5,4,5,1.0
2,Female,25-34,4,5,4,0.9
3,Male,35-44,3,3,4,1.1
4,Female,45-54,5,5,5,1.0
5,Male,18-24,2,3,2,1.2
```

Create test structure: `tests/test_data/survey_structure_with_composites.xlsx`

**Sheet: Questions**
| QuestionCode | QuestionText | Variable_Type | QuestionType |
|--------------|--------------|---------------|--------------|
| SAT_01 | Product Quality | Rating | Single |
| SAT_02 | Customer Service | Rating | Single |
| SAT_03 | Value for Money | Rating | Single |

**Sheet: Options**
| QuestionCode | OptionValue | OptionText |
|--------------|-------------|------------|
| SAT_01 | 1 | Very Dissatisfied |
| SAT_01 | 2 | Dissatisfied |
| SAT_01 | 3 | Neutral |
| SAT_01 | 4 | Satisfied |
| SAT_01 | 5 | Very Satisfied |
(Repeat for SAT_02, SAT_03)

**Sheet: Composite_Metrics**
| CompositeCode | CompositeLabel | CalculationType | SourceQuestions | SectionLabel |
|---------------|----------------|-----------------|-----------------|--------------|
| COMP_SAT | Overall Satisfaction | Mean | SAT_01,SAT_02,SAT_03 | SATISFACTION |

---

## 9. ERROR HANDLING & EDGE CASES

### 9.1 Error Scenarios

**Error 1: Composite references non-existent question**
```r
Action: Stop processing, show clear error
Message: "Composite 'COMP_SAT' references question 'SAT_99' which does not exist"
```

**Error 2: Mixed question types in composite**
```r
Action: Stop processing, show error
Message: "Composite 'COMP_MIX' combines Rating and Likert questions. All sources must be same type."
```

**Error 3: WeightedMean without weights**
```r
Action: Stop processing, show error
Message: "Composite 'COMP_A' uses WeightedMean but Weights column is empty"
```

**Error 4: Weight count mismatch**
```r
Action: Stop processing, show error
Message: "Composite 'COMP_A' has 3 source questions but only 2 weights provided"
```

### 9.2 Warning Scenarios

**Warning 1: All source questions excluded from index**
```r
Action: Continue, show warning, composite will be NA
Message: "Composite 'COMP_SAT' has all source questions excluded from index. Composite will be NA."
```

**Warning 2: No composites defined**
```r
Action: Continue normally
Message: "No composite metrics defined (Composite_Metrics sheet not found or empty)"
```

**Warning 3: Composite excluded from summary**
```r
Action: Calculate but don't show in Index_Summary
Message: (No message needed - expected behavior)
```

### 9.3 Edge Cases

**Edge Case 1: Single source question composite**
```r
Action: Allow, but warn
Logic: Composite simply equals the source question
Warning: "Composite 'COMP_A' has only one source question"
```

**Edge Case 2: All responses NA for a composite**
```r
Action: Show NA in results, no error
Logic: Standard missing data handling
```

**Edge Case 3: Different sample sizes across source questions**
```r
Action: Use pairwise deletion (standard approach)
Logic: Each respondent contributes if they have any valid sources
```

**Edge Case 4: Composite of composites**
```r
Action: Not supported in v1.0
Error: "Composite 'COMP_B' references 'COMP_A' which is also a composite. Nested composites not supported."
```

---

## 10. DOCUMENTATION UPDATES

### 10.1 Update User Manual

Add new section: **"7. Working with Composite Metrics"**

Content:
- What are composites
- When to use them
- How to define them in Survey_Structure
- How they appear in output
- Examples

### 10.2 Update Quick Reference

Add to **"Survey Structure File"** section:

**Composite_Metrics Sheet (Optional)**
- Define combined metrics
- Columns: CompositeCode, CompositeLabel, CalculationType, SourceQuestions, Weights
- Appears in output like any other rating/index
- Shows in Index_Summary sheet

### 10.3 Code Comments

All new functions must have:
- Roxygen2 style documentation
- @param and @return tags
- @examples showing usage
- @keywords internal (for helper functions)

---

## 11. ACCEPTANCE CRITERIA

### Phase 1: Composite Calculation (Week 1-2)
- ✅ Load composite definitions from Survey_Structure.xlsx
- ✅ Validate composite definitions with clear error messages
- ✅ Calculate Mean composites correctly
- ✅ Calculate Sum composites correctly
- ✅ Calculate WeightedMean composites correctly
- ✅ Handle missing values (pairwise deletion)
- ✅ Apply survey weights to composites
- ✅ Process composites through banner structure
- ✅ Run significance testing on composites
- ✅ Output composite results in Crosstabs sheet
- ✅ Unit tests pass for all calculation types

### Phase 2: Summary Table (Week 2-3)
- ✅ Extract metric rows from results_list
- ✅ Include composite rows in summary
- ✅ Group by sections (if enabled)
- ✅ Insert section headers
- ✅ Format for Excel output
- ✅ Mark composite rows visually (→ prefix)
- ✅ Match banner column structure exactly
- ✅ Include base sizes at bottom
- ✅ Write Index_Summary sheet with correct styling
- ✅ Handle empty results gracefully

### Phase 3: Integration & Testing (Week 3)
- ✅ Integrate into run_crosstabs.R
- ✅ Config settings work correctly
- ✅ All unit tests pass
- ✅ Integration test passes
- ✅ Manual QC with real data
- ✅ Documentation updated
- ✅ Template files updated
- ✅ Example data provided

### Final Acceptance:
- ✅ End-to-end test: Define 3 composites, process survey, verify Excel output
- ✅ Verify calculations match manual computation
- ✅ Verify significance testing works on composites
- ✅ Verify Index_Summary contains all expected metrics
- ✅ No regression in existing functionality
- ✅ Code review passes
- ✅ Performance acceptable (no significant slowdown)

---

## 12. DEVELOPMENT CHECKLIST

### Week 1: Foundation
- [ ] Create `composite_processor.R` module
- [ ] Implement `load_composite_definitions()`
- [ ] Implement `validate_composite_definitions()`
- [ ] Implement `calculate_composite_values()` for Mean
- [ ] Implement `calculate_composite_values()` for Sum
- [ ] Implement `calculate_composite_values()` for WeightedMean
- [ ] Write unit tests for calculation functions
- [ ] Test with mock data

### Week 2: Processing Pipeline
- [ ] Implement `process_composite_question()`
- [ ] Implement `process_all_composites()`
- [ ] Integrate into `run_crosstabs.R` (load and validate)
- [ ] Integrate into `run_crosstabs.R` (process composites)
- [ ] Test composite output in Crosstabs sheet
- [ ] Verify significance testing works
- [ ] Write integration tests

### Week 2-3: Summary Builder
- [ ] Create `summary_builder.R` module
- [ ] Implement `build_index_summary_table()`
- [ ] Implement `extract_metric_rows()`
- [ ] Implement `insert_section_headers()`
- [ ] Implement `format_summary_for_excel()`
- [ ] Write unit tests for summary builder
- [ ] Create `write_index_summary_sheet()`
- [ ] Define Excel styles for summary sheet
- [ ] Integrate into `run_crosstabs.R` (build summary)
- [ ] Integrate into `run_crosstabs.R` (write Excel)

### Week 3: Testing & Documentation
- [ ] Create test data files
- [ ] Run end-to-end integration test
- [ ] Manual QC with real survey data
- [ ] Performance testing
- [ ] Update Survey_Structure_Template.xlsx
- [ ] Update Crosstab_Config_Template.xlsx
- [ ] Update user documentation
- [ ] Update developer documentation
- [ ] Code review
- [ ] Final acceptance testing

---

## 13. EXAMPLE OUTPUT

### Input: Composite_Metrics Sheet
```
CompositeCode        | CompositeLabel           | CalculationType | SourceQuestions      | SectionLabel
COMP_SAT_OVERALL     | Overall Satisfaction     | Mean            | SAT_01,SAT_02,SAT_03 | SATISFACTION
COMP_QUALITY_INDEX   | Quality Index           | WeightedMean    | QUAL_01,QUAL_02      | QUALITY
```

### Output: Crosstabs Sheet (Excerpt)
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
COMP_SAT_OVERALL: Overall Satisfaction
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    Total    Male    Female   18-24
Base (Unweighted)   500      245     255      82
Base (Weighted)     500      250     250      75
Base (Effective)    487      238     249      71

Average             7.2      7.0 A   7.4 B    6.8
Sig.                         B       A        
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Output: Index_Summary Sheet
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INDEX & RATING SUMMARY
Survey: Customer Satisfaction Q4 2025
Base: All Respondents

Section: SATISFACTION
─────────────────────────────────────────────────────
Metric                      Total  Male   Female 18-24
─────────────────────────────────────────────────────
Product Quality              8.1   8.0    8.2    7.9
Customer Service             6.9   6.7    7.1 A  6.5
Value for Money              6.5   6.4    6.6    6.2
→ Overall Satisfaction       7.2   7.0 A  7.4 B  6.8

Section: QUALITY
─────────────────────────────────────────────────────
Feature Quality              8.3   8.2    8.4    8.1
Reliability                  7.9   7.8    8.0    7.7
→ Quality Index              8.1   8.0    8.2    7.9

Base sizes:
Unweighted n:               500   245    255     82
Weighted n:                 500   250    250     75
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 14. CONTACT & SUPPORT

**Developer:** Claude Code  
**Specification Author:** Claude (Anthropic)  
**Project Owner:** Duncan Brett  

**Questions during development:**
- Clarify any ambiguous requirements before implementing
- Flag any technical constraints discovered
- Propose alternative approaches if specs are problematic
- Document all deviations from spec with rationale

**Status Updates:**
- End of Week 1: Calculation engine complete
- End of Week 2: Processing pipeline complete
- End of Week 3: Summary builder and integration complete

---

## END OF SPECIFICATION

**Version:** 1.0  
**Date:** 2025-11-06  
**Total Pages:** 38  
**Estimated Development Time:** 2-3 weeks  
**Status:** Ready for Development
