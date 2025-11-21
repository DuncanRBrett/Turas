# TURAS TRACKER ENHANCEMENT - DESIGN SPECIFICATION

## Document Control

| Item | Details |
|------|---------|
| Project | Turas Tracker - Setup Flexibility & Multi-Mention Support |
| Document Type | Technical Design Specification |
| Version | 1.0 |
| Date | 2025-11-21 |
| Target | Claude Code Implementation |
| Estimated Effort | 2-3 weeks |
| Priority | HIGH |

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Objectives & Requirements](#2-objectives--requirements)
3. [Technical Architecture](#3-technical-architecture)
4. [Detailed Specifications](#4-detailed-specifications)
5. [Implementation Plan](#5-implementation-plan)
6. [Testing Strategy](#6-testing-strategy)
7. [Documentation Updates](#7-documentation-updates)
8. [Acceptance Criteria](#8-acceptance-criteria)
9. [Risks & Mitigation](#9-risks--mitigation)
10. [Appendices](#10-appendices)

---

## 1. EXECUTIVE SUMMARY

### 1.1 Purpose

Enhance Turas Tracker to provide:
- Flexible metric tracking within questions (top-box, custom ranges, etc.)
- Multi-mention question support (currently unsupported)
- Enhanced validation with actionable error messages
- Selective option tracking to control output size

### 1.2 Scope

**IN SCOPE:**
- Add TrackingSpecs column to question_mapping.xlsx
- Implement multi-mention (Multi_Mention) question type
- Enhance rating questions with top-box, bottom-box, custom ranges
- Enhance composite questions with TrackingSpecs
- Improve validation with pre-flight checks
- Maintain full backward compatibility

**OUT OF SCOPE:**
- Reporting flexibility enhancements (separate phase)
- Auto-configuration wizards (separate phase)
- Chart generation (already planned for Phase 4)
- HTML/PowerPoint output (separate phase)

### 1.3 Key Principles

- **Backward Compatibility**: All existing configs must work without modification
- **Opt-In Enhancement**: New features available via optional TrackingSpecs column
- **No Breaking Changes**: Current functionality preserved exactly
- **Clear Defaults**: Sensible defaults if TrackingSpecs not specified

---

## 2. OBJECTIVES & REQUIREMENTS

### 2.1 Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-001 | Support TrackingSpecs column in question_mapping.xlsx | HIGH |
| FR-002 | Track rating questions: mean, top_box, top2_box, bottom_box, custom ranges | HIGH |
| FR-003 | Track Multi_Mention questions (% mentioning each option) | HIGH |
| FR-004 | Support selective option tracking for Multi_Mention | MEDIUM |
| FR-005 | Apply TrackingSpecs to composite questions | MEDIUM |
| FR-006 | Provide validation function with actionable warnings | MEDIUM |
| FR-007 | Maintain existing output format compatibility | HIGH |

### 2.2 Non-Functional Requirements

| ID | Requirement | Target |
|---|---|---|
| NFR-001 | Backward compatibility with existing configs | 100% |
| NFR-002 | Processing time increase | <10% for standard configs |
| NFR-003 | Memory usage increase | <20% for standard configs |
| NFR-004 | Code maintainability | Clear documentation, modular design |
| NFR-005 | Test coverage | >80% for new code |

### 2.3 Constraints

- Must work within existing two-file structure (tracking_config.xlsx + question_mapping.xlsx)
- Must use existing statistical testing methods (no new algorithms)
- Must integrate with existing output module (tracker_output.R)
- R code only (no external dependencies beyond openxlsx, readxl)

---

## 3. TECHNICAL ARCHITECTURE

### 3.1 System Context

```
┌─────────────────────────────────────────────────────────────┐
│                    TURAS TRACKER                            │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│  │   Config     │    │   Question   │    │   Wave       │ │
│  │   Loader     │───▶│   Mapper     │───▶│   Loader     │ │
│  └──────────────┘    └──────────────┘    └──────────────┘ │
│         │                    │                    │         │
│         │                    │                    │         │
│         ▼                    ▼                    ▼         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Validation Module (ENHANCED)            │  │
│  └──────────────────────────────────────────────────────┘  │
│                              │                              │
│                              ▼                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Trend Calculator (ENHANCED)                 │  │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────────────┐ │  │
│  │  │ Rating   │  │   NPS    │  │  Multi-Mention     │ │  │
│  │  │ Enhanced │  │ Existing │  │      (NEW)         │ │  │
│  │  └──────────┘  └──────────┘  └────────────────────┘ │  │
│  │  ┌──────────┐  ┌──────────┐                         │  │
│  │  │ Single   │  │Composite │                         │  │
│  │  │ Choice   │  │ Enhanced │                         │  │
│  │  └──────────┘  └──────────┘                         │  │
│  └──────────────────────────────────────────────────────┘  │
│                              │                              │
│                              ▼                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Output Writer (UPDATE)                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Module Changes Overview

| Module | Change Type | Description |
|---|---|---|
| tracker_config_loader.R | MINOR | No changes needed |
| wave_loader.R | MINOR | No changes needed |
| question_mapper.R | ENHANCE | Add get_tracking_specs() function |
| validation_tracker.R | ENHANCE | Add enhanced validation function |
| trend_calculator.R | MAJOR | Add Multi_Mention support, enhance Rating/Composite |
| tracker_output.R | ENHANCE | Add Multi_Mention output formatting |
| formatting_utils.R | MINOR | Possible formatting helpers |

### 3.3 Data Flow - Enhanced

```
User Config Files
       │
       ├─────▶ tracking_config.xlsx (unchanged structure)
       │
       └─────▶ question_mapping.xlsx (NEW: TrackingSpecs column)
                     │
                     ├─ QuestionCode
                     ├─ QuestionText
                     ├─ QuestionType
                     ├─ TrackingSpecs ◄─── NEW (optional)
                     ├─ Wave1, Wave2, ...
                     └─ SourceQuestions
                            │
                            ▼
                   Question Map Index
                            │
                            ├─ Includes TrackingSpecs
                            └─ Routes to appropriate calculator
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼
              Rating Enhanced   Multi-Mention    Composite Enhanced
              (top-box, etc.)      (NEW)         (with specs)
                    │                │                │
                    └────────────────┴────────────────┘
                                     │
                                     ▼
                            Trend Results
                                     │
                                     ▼
                            Excel Output
```

---

## 4. DETAILED SPECIFICATIONS

### 4.1 TrackingSpecs Column Specification

#### 4.1.1 Schema Addition

**File**: question_mapping.xlsx  
**Sheet**: QuestionMap  
**New Column**: TrackingSpecs (optional)

**Column Specifications:**
- **Type**: Text
- **Required**: NO
- **Default**: Empty/blank (uses default behavior)
- **Format**: Comma-separated list
- **Case-Sensitive**: NO (will be normalized to lowercase)

#### 4.1.2 TrackingSpecs Syntax Definition

**Grammar (EBNF-like notation):**

```
TrackingSpecs ::= <spec> ("," <spec>)*
<spec>        ::= <rating_spec> | <nps_spec> | <choice_spec> | <multi_spec>

<rating_spec> ::= "mean" | "top_box" | "top2_box" | "top3_box" 
                | "bottom_box" | "bottom2_box" | "distribution"
                | "range:" <number> "-" <number>

<nps_spec>    ::= "nps_score" | "promoters_pct" | "passives_pct" 
                | "detractors_pct" | "full"

<choice_spec> ::= "all" | "top3" | "category:" <category_name>

<multi_spec>  ::= "auto" | "any" | "count_mean" | "count_distribution"
                | "option:" <column_name>
```

**Examples:**
- `mean,top2_box`
- `range:9-10,range:0-6`
- `option:Q30_1,option:Q30_3,any,count_mean`

#### 4.1.3 Default Behaviors (if TrackingSpecs blank)

| Question Type | Default TrackingSpecs | Backward Compatible |
|---|---|---|
| Rating | mean | ✓ YES |
| NPS | full | ✓ YES |
| Single_Choice | all | ✓ YES |
| Multi_Mention | auto | N/A (new support) |
| Composite | mean | ✓ YES |

### 4.2 Multi-Mention Implementation

#### 4.2.1 Data Format Requirements

**Expected Structure:**

```csv
ResponseID, Q30_1, Q30_2, Q30_3, Q30_4, weight
1,          1,     1,     0,     0,     1.0
2,          1,     0,     1,     0,     1.2
3,          0,     1,     0,     1,     0.9
```

Where:
- Base question code: Q30
- Option columns: Q30_1, Q30_2, Q30_3, Q30_4
- Values: 1 = selected, 0 = not selected
- Missing values handled as NA

**Column Naming Convention:**
- **Pattern**: `{BaseCode}_{OptionNumber}`
- **Example**: Q30_1, Q30_2, ... Q30_N
- Must be sequential integers (gaps allowed but not recommended)

#### 4.2.2 Question Mapping Setup

**question_mapping.xlsx:**

| QuestionCode | QuestionType | TrackingSpecs | Wave1 | Wave2 |
|---|---|---|---|---|
| Q_REASON | Multi_Mention | auto | Q30 | Q35 |
| Q_THEMES | Multi_Mention | option:Q40_1,option:Q40_3 | Q40 | Q45 |

**Interpretation:**
- Wave1 = Q30 → Auto-detects Q30_1, Q30_2, Q30_3, ...
- TrackingSpecs = auto → Track all detected options
- TrackingSpecs = option:Q40_1,option:Q40_3 → Track only these 2

#### 4.2.3 Column Auto-Detection Algorithm

**Function Signature:**

```r
detect_multi_mention_columns <- function(wave_df, base_code)

# Parameters:
#   wave_df: data.frame - Wave data
#   base_code: character - Base question code (e.g., "Q30")
#
# Returns:
#   character vector - Detected column names (e.g., c("Q30_1", "Q30_2", "Q30_3"))
#   NULL if no columns found
```

**Algorithm:**
1. Build regex pattern: `^{base_code}_[0-9]+$`
2. Find all matching column names in wave_df
3. Extract numeric suffixes
4. Sort by numeric value (not lexicographic)
5. Return sorted column names
6. If no matches, return NULL and issue warning

**Implementation Pseudocode:**

```r
detect_multi_mention_columns <- function(wave_df, base_code) {
  # Escape special regex characters in base_code
  base_code_escaped <- gsub("([.|()\\^{}+$*?])", "\\\\\\1", base_code)
  
  # Build pattern
  pattern <- paste0("^", base_code_escaped, "_[0-9]+$")
  
  # Find matches
  matched_cols <- grep(pattern, names(wave_df), value = TRUE)
  
  if (length(matched_cols) == 0) {
    warning(paste0("No multi-mention columns found for base code: ", base_code))
    return(NULL)
  }
  
  # Extract numeric parts and sort
  numeric_parts <- as.integer(sub(paste0("^", base_code_escaped, "_"), "", matched_cols))
  sort_order <- order(numeric_parts)
  matched_cols <- matched_cols[sort_order]
  
  return(matched_cols)
}
```

**Edge Cases:**
- Base code contains special regex characters (e.g., Q1.5) → Escape properly
- Non-sequential numbering (Q30_1, Q30_3, Q30_5) → Include all found
- Column exists but all NA → Include in detection, handle in calculation
- Different numbering across waves (Wave1 has 1-5, Wave2 has 1-8) → Track union

#### 4.2.4 TrackingSpecs Parsing for Multi-Mention

**Function Signature:**

```r
parse_multi_mention_specs <- function(tracking_specs, base_code, wave_df)

# Parameters:
#   tracking_specs: character - TrackingSpecs string from mapping
#   base_code: character - Base question code
#   wave_df: data.frame - Wave data for validation
#
# Returns:
#   list with:
#     $mode: character - "auto" or "selective"
#     $columns: character vector - Column names to track
#     $additional_metrics: character vector - Additional metrics (any, count_mean, etc.)
```

**Implementation Pseudocode:**

```r
parse_multi_mention_specs <- function(tracking_specs, base_code, wave_df) {
  
  # Default to auto if blank
  if (is.null(tracking_specs) || tracking_specs == "" || tracking_specs == "auto") {
    return(list(
      mode = "auto",
      columns = detect_multi_mention_columns(wave_df, base_code),
      additional_metrics = character(0)
    ))
  }
  
  # Parse comma-separated specs
  specs <- trimws(strsplit(tracking_specs, ",")[[1]])
  
  result <- list(
    mode = "selective",
    columns = character(0),
    additional_metrics = character(0)
  )
  
  for (spec in specs) {
    if (spec == "auto") {
      result$mode <- "auto"
      result$columns <- unique(c(result$columns, 
                                 detect_multi_mention_columns(wave_df, base_code)))
      
    } else if (startsWith(spec, "option:")) {
      # Extract: "option:Q30_1" -> "Q30_1"
      col_name <- sub("^option:", "", spec)
      result$columns <- c(result$columns, col_name)
      
    } else if (spec %in% c("any", "count_mean", "count_distribution")) {
      result$additional_metrics <- c(result$additional_metrics, spec)
      
    } else {
      warning(paste0("Unknown Multi_Mention spec: ", spec))
    }
  }
  
  # Remove duplicates
  result$columns <- unique(result$columns)
  result$additional_metrics <- unique(result$additional_metrics)
  
  # Validate columns exist
  missing <- setdiff(result$columns, names(wave_df))
  if (length(missing) > 0) {
    warning(paste0("Multi-mention columns not found in data: ", 
                   paste(missing, collapse = ", ")))
    result$columns <- intersect(result$columns, names(wave_df))
  }
  
  return(result)
}
```

#### 4.2.5 Multi-Mention Metrics Calculation

**For each wave, calculate:**

**Mention Proportions (% mentioning each option):**

```r
For each option column:
  mentioned <- (column_data == 1)
  weighted_count <- sum(weights[mentioned])
  total_weight <- sum(weights)
  proportion <- (weighted_count / total_weight) * 100
```

**Additional Metrics (if requested):**

**"any" - % mentioning at least one option:**
```r
option_matrix <- as.matrix(wave_df[valid_idx, option_columns])
mentioned_any <- rowSums(option_matrix == 1, na.rm = TRUE) > 0
any_pct <- sum(weights[mentioned_any]) / sum(weights) * 100
```

**"count_mean" - Mean number of mentions:**
```r
option_matrix <- as.matrix(wave_df[valid_idx, option_columns])
mention_counts <- rowSums(option_matrix == 1, na.rm = TRUE)
count_mean <- sum(mention_counts * weights) / sum(weights)
```

**"count_distribution" - Distribution of mention counts:**
```r
For count_val in 0 to length(option_columns):
  matched <- (mention_counts == count_val)
  dist[count_val] <- sum(weights[matched]) / sum(weights) * 100
```

#### 4.2.6 Multi-Mention Significance Testing

**Test Type**: Z-test for proportions (same as single-choice)

For each option, between consecutive waves:

```r
p1 <- wave1_mention_proportion / 100  # Convert to 0-1
p2 <- wave2_mention_proportion / 100
n1 <- wave1_n_unweighted
n2 <- wave2_n_unweighted

# Use existing z_test_for_proportions()
result <- z_test_for_proportions(p1, n1, p2, n2, alpha)
```

Significance stored per option, per wave pair.

### 4.3 Enhanced Rating Questions

#### 4.3.1 Top/Bottom Box Calculation

**Top Box Metrics:**

**Scale Auto-Detection:**
```r
unique_values <- sort(unique(values[!is.na(values)]))
scale_min <- min(unique_values)
scale_max <- max(unique_values)

# For top_box:
top_values <- tail(unique_values, 1)  # Highest value

# For top2_box:
top_values <- tail(unique_values, 2)  # Top 2 values

# Percentage:
in_top_box <- values %in% top_values
pct <- sum(weights[in_top_box]) / sum(weights) * 100
```

**Function Signature:**

```r
calculate_top_box <- function(values, weights, n_boxes = 1)

# Parameters:
#   values: numeric vector - Response values
#   weights: numeric vector - Weights (same length as values)
#   n_boxes: integer - Number of top values to include (1, 2, or 3)
#
# Returns:
#   list with:
#     $proportion: numeric - Percentage (0-100)
#     $scale_detected: character - e.g., "1-5"
#     $top_values: numeric vector - Values included in top box
```

**Bottom Box**: Same algorithm but use `head()` instead of `tail()`

#### 4.3.2 Custom Range Calculation

**Syntax**: `range:X-Y` where X and Y are numbers

**Examples:**
- `range:9-10` → % giving 9 or 10
- `range:1-3` → % giving 1, 2, or 3
- `range:7-8` → % giving 7 or 8

**Function Signature:**

```r
calculate_custom_range <- function(values, weights, range_spec)

# Parameters:
#   values: numeric vector - Response values
#   weights: numeric vector - Weights
#   range_spec: character - e.g., "range:9-10"
#
# Returns:
#   list with:
#     $proportion: numeric - Percentage (0-100)
#     $range_values: numeric vector - Values included
#     $range_spec: character - Original spec (for labeling)
```

**Implementation:**

```r
calculate_custom_range <- function(values, weights, range_spec) {
  # Parse: "range:9-10" -> c(9, 10)
  range_str <- sub("^range:", "", range_spec)
  parts <- strsplit(range_str, "-")[[1]]
  
  if (length(parts) != 2) {
    warning(paste0("Invalid range specification: ", range_spec))
    return(list(proportion = NA, range_values = NA, range_spec = range_spec))
  }
  
  range_min <- as.numeric(parts[1])
  range_max <- as.numeric(parts[2])
  
  if (is.na(range_min) || is.na(range_max) || range_min > range_max) {
    warning(paste0("Invalid range values: ", range_spec))
    return(list(proportion = NA, range_values = NA, range_spec = range_spec))
  }
  
  # Generate sequence
  range_values <- seq(range_min, range_max)
  
  # Calculate proportion
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]
  
  in_range <- values_valid %in% range_values
  range_weight <- sum(weights_valid[in_range])
  total_weight <- sum(weights_valid)
  
  proportion <- if (total_weight > 0) (range_weight / total_weight) * 100 else NA
  
  return(list(
    proportion = proportion,
    range_values = range_values,
    range_spec = range_spec
  ))
}
```

#### 4.3.3 Distribution Calculation

**Spec**: `distribution`  
**Returns**: Percentage for each unique value found in data

**Implementation:**

```r
calculate_distribution <- function(values, weights) {
  unique_vals <- sort(unique(values[!is.na(values)]))
  
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]
  
  distribution <- list()
  
  for (val in unique_vals) {
    matched <- values_valid == val
    val_weight <- sum(weights_valid[matched])
    total_weight <- sum(weights_valid)
    distribution[[as.character(val)]] <- (val_weight / total_weight) * 100
  }
  
  return(distribution)
}
```

### 4.4 Enhanced Composite Questions

#### 4.4.1 Composite Calculation Flow

**Step 1**: Calculate composite score per respondent
```
composite_score = mean(source_question_1, source_question_2, ..., source_question_N)
```

**Step 2**: Apply TrackingSpecs to composite scores

If TrackingSpecs = "mean,top2_box":
- Calculate mean of composite_scores
- Calculate % with composite_score in top 2 values

#### 4.4.2 Composite Score Per Respondent

**Function Signature:**

```r
calculate_composite_values_per_respondent <- function(wave_df, wave_id, 
                                                      source_questions, 
                                                      question_map)

# Parameters:
#   wave_df: data.frame - Wave data
#   wave_id: character - Wave identifier
#   source_questions: character vector - Source question codes
#   question_map: list - Question map index
#
# Returns:
#   numeric vector - Composite score per respondent (length = nrow(wave_df))
```

**Implementation:**

```r
calculate_composite_values_per_respondent <- function(wave_df, wave_id, 
                                                      source_questions, 
                                                      question_map) {
  # Extract each source question
  source_values <- list()
  
  for (src_code in source_questions) {
    src_data <- extract_question_data(wave_df, wave_id, src_code, question_map)
    if (!is.null(src_data)) {
      source_values[[src_code]] <- src_data
    }
  }
  
  if (length(source_values) == 0) {
    warning("No valid source questions found for composite")
    return(rep(NA, nrow(wave_df)))
  }
  
  # Build matrix: rows = respondents, cols = source questions
  n_resp <- nrow(wave_df)
  n_sources <- length(source_values)
  source_matrix <- matrix(NA, nrow = n_resp, ncol = n_sources)
  
  for (i in seq_along(source_values)) {
    source_matrix[, i] <- source_values[[i]]
  }
  
  # Row means (composite per respondent)
  composite_values <- rowMeans(source_matrix, na.rm = TRUE)
  
  # Set to NA if all sources were NA for a respondent
  all_na <- apply(source_matrix, 1, function(row) all(is.na(row)))
  composite_values[all_na] <- NA
  
  return(composite_values)
}
```

#### 4.4.3 Apply TrackingSpecs to Composite

Once we have composite scores per respondent, treat them like rating values:
- `mean` → calculate weighted mean
- `top2_box` → apply calculate_top_box(composite_values, weights, 2)
- `distribution` → apply calculate_distribution(composite_values, weights)

### 4.5 Helper Functions

#### 4.5.1 Get TrackingSpecs

**Function Signature:**

```r
get_tracking_specs <- function(question_map, question_code)

# Parameters:
#   question_map: list - Question map index
#   question_code: character - Question code
#
# Returns:
#   character - TrackingSpecs string (or NULL if not specified/blank)
```

**Implementation:**

```r
get_tracking_specs <- function(question_map, question_code) {
  metadata_df <- question_map$question_metadata
  
  # Check if column exists
  if (!"TrackingSpecs" %in% names(metadata_df)) {
    return(NULL)
  }
  
  # Find row
  q_row <- metadata_df[metadata_df$QuestionCode == question_code, ]
  
  if (nrow(q_row) == 0) {
    return(NULL)
  }
  
  tracking_specs <- q_row$TrackingSpecs[1]
  
  # Return NULL if blank/NA
  if (is.na(tracking_specs) || trimws(tracking_specs) == "") {
    return(NULL)
  }
  
  return(trimws(tracking_specs))
}
```

#### 4.5.2 Validate TrackingSpecs

**Function Signature:**

```r
validate_tracking_specs <- function(specs_str, question_type)

# Parameters:
#   specs_str: character - TrackingSpecs string
#   question_type: character - Question type
#
# Returns:
#   list with:
#     $valid: logical
#     $message: character (if invalid)
```

**Valid specs by question type:**

```r
VALID_SPECS <- list(
  Rating = c("mean", "top_box", "top2_box", "top3_box", 
             "bottom_box", "bottom2_box", "distribution"),
  NPS = c("nps_score", "promoters_pct", "passives_pct", 
          "detractors_pct", "full"),
  Single_Choice = c("all", "top3"),
  Multi_Mention = c("auto", "any", "count_mean", "count_distribution"),
  Composite = c("mean", "top_box", "top2_box", "top3_box", "distribution")
)
```

**Also allow:**
- Specs starting with `range:` (for Rating, Composite)
- Specs starting with `category:` (for Single_Choice)
- Specs starting with `option:` (for Multi_Mention)

### 4.6 Enhanced Validation

#### 4.6.1 Validation Function

**Function Signature:**

```r
validate_tracking_setup_enhanced <- function(tracking_config_path,
                                             question_mapping_path,
                                             data_dir = NULL,
                                             report_mode = "detailed")

# Parameters:
#   tracking_config_path: character - Path to config
#   question_mapping_path: character - Path to mapping
#   data_dir: character - Data directory (optional)
#   report_mode: character - "summary" or "detailed"
#
# Returns:
#   list with:
#     $valid: logical - Overall validation result
#     $issues: list with $errors, $warnings, $info vectors
```

#### 4.6.2 Validation Checks

**Configuration Checks:**
- [ ] Config file exists and readable
- [ ] Required sheets present (Waves, Settings, Banner, TrackedQuestions)
- [ ] Required columns present in each sheet
- [ ] WaveIDs unique
- [ ] DataFile paths valid

**Question Mapping Checks:**
- [ ] Mapping file exists and readable
- [ ] QuestionMap sheet present
- [ ] Required columns present (QuestionCode, QuestionText, QuestionType, Wave columns)
- [ ] QuestionCodes unique
- [ ] QuestionTypes valid
- [ ] TrackingSpecs valid for each question type (if specified)

**Data File Checks:**
- [ ] All wave data files exist
- [ ] All files loadable (no corruption)
- [ ] Sample sizes adequate (n >= minimum_base)
- [ ] Sample size consistency across waves (warn if >50% difference)

**Question Availability Checks:**
- [ ] All tracked questions exist in mapping
- [ ] For each wave, mapped question columns exist in data
- [ ] For Multi_Mention, option columns detected
- [ ] For Composite, source questions exist

**Weight Checks:**
- [ ] Weight variables exist if specified
- [ ] Weight values valid (no negative, not all zero)
- [ ] Weight distribution reasonable (warn if max/min > 5)

**Banner Checks:**
- [ ] Banner variables exist in all wave data
- [ ] Banner variables have reasonable number of unique values (<50)

#### 4.6.3 Validation Output Format

```
================================================================================
TRACKING SETUP VALIDATION
================================================================================

CONFIGURATION
✓ Configuration loaded: 3 waves, 10 questions
✓ Wave data files found for all waves

DATA FILES
✓ Wave W1 loaded: n=500
✓ Wave W2 loaded: n=500
✓ Wave W3 loaded: n=480
⚠ Wave W3 sample size (480) is 4% smaller than Wave 1 (500)

QUESTION MAPPING
✓ Question mapping loaded: 10 questions
✓ All tracked questions found in mapping
⚠ Q_REASON (Multi_Mention): Wave W1 found 5 options, Wave W2 found 8 options
  → Different number of options across waves

TRACKINGSPECS VALIDATION
✓ Q_SAT: TrackingSpecs valid (mean,top2_box)
✗ Q_QUALITY: Invalid spec "top4_box" for Rating question

SUMMARY
-------
Errors: 1
Warnings: 2
Ready to run: NO (fix errors first)

================================================================================
```

### 4.7 Updated Main Trend Calculator

#### 4.7.1 calculate_all_trends Enhancement

**Modified routing logic:**

```r
calculate_all_trends <- function(config, question_map, wave_data) {
  
  message("\n", strrep("=", 80))
  message("CALCULATING TRENDS")
  message(strrep("=", 80), "\n")
  
  tracked_questions <- config$tracked_questions$QuestionCode
  trend_results <- list()
  
  for (q_code in tracked_questions) {
    message(paste0("Processing question: ", q_code))
    
    metadata <- get_question_metadata(question_map, q_code)
    
    if (is.null(metadata)) {
      warning(paste0("  Question ", q_code, " not found in mapping - skipping"))
      next
    }
    
    q_type_raw <- metadata$QuestionType
    q_type <- normalize_question_type(q_type_raw)
    
    # Route to appropriate calculator
    trend_result <- tryCatch({
      
      if (q_type == "rating") {
        calculate_rating_trend_enhanced(q_code, question_map, wave_data, config)
        
      } else if (q_type == "nps") {
        calculate_nps_trend(q_code, question_map, wave_data, config)
        
      } else if (q_type == "single_choice") {
        calculate_single_choice_trend(q_code, question_map, wave_data, config)
        
      } else if (q_type == "multi_choice" || q_type_raw == "Multi_Mention") {
        # NEW: Multi-mention support
        calculate_multi_mention_trend(q_code, question_map, wave_data, config)
        
      } else if (q_type == "composite") {
        calculate_composite_trend_enhanced(q_code, question_map, wave_data, config)
        
      } else if (q_type == "open_end") {
        warning(paste0("  Open-end questions cannot be tracked - skipping"))
        NULL
        
      } else {
        warning(paste0("  Question type '", q_type_raw, "' not supported - skipping"))
        NULL
      }
      
    }, error = function(e) {
      warning(paste0("  Error calculating trend for ", q_code, ": ", e$message))
      NULL
    })
    
    if (!is.null(trend_result)) {
      trend_results[[q_code]] <- trend_result
      message(paste0("  ✓ Trend calculated"))
    }
  }
  
  message(paste0("\nCompleted trend calculation for ", length(trend_results), " questions"))
  
  return(trend_results)
}
```

#### 4.7.2 normalize_question_type Enhancement

**Add Multi_Mention mapping:**

```r
normalize_question_type <- function(q_type) {
  type_map <- c(
    "Single_Response" = "single_choice",
    "SingleChoice" = "single_choice",
    "Multi_Mention" = "multi_choice",  # NEW
    "MultiChoice" = "multi_choice",    # NEW
    "Multi_Choice" = "multi_choice",   # NEW (alternate spelling)
    "Rating" = "rating",
    "Likert" = "rating",
    "NPS" = "nps",
    "Index" = "rating",
    "Numeric" = "rating",
    "Open_End" = "open_end",
    "OpenEnd" = "open_end",
    "Ranking" = "ranking",
    "Composite" = "composite"
  )
  
  normalized <- type_map[q_type]
  
  if (is.na(normalized)) {
    return(tolower(q_type))
  }
  
  return(as.character(normalized))
}
```

### 4.8 Output Module Updates

#### 4.8.1 Multi-Mention Output Format

**Excel Sheet Structure:**

```
Q_REASON: Reasons for Choosing (Multi-Mention)
TrackingSpecs: auto, any, count_mean

                            Wave 1      Wave 2      Trend   Wave 3      Trend
Base (n=)                   500         500                 500

% Mentioning:
  Quality (Q30_1)           45%         50%         ↑       55%         ↑
  Price (Q30_2)             30%         28%         →       25%         ↓
  Customer Service (Q30_3)  25%         30%         ↑       32%         →
  Brand (Q30_4)             20%         22%         →       24%         →
  Recommendation (Q30_5)    15%         18%         →       20%         →

Summary Metrics:
  % Mentioning Any          92%         95%         →       96%         →
  Mean # Mentions           2.3         2.5         →       2.7         ↑
```

**Implementation:**

```r
write_multi_mention_sheet <- function(wb, sheet_name, result, config, styles) {
  
  current_row <- 1
  
  # Header
  writeData(wb, sheet_name, result$question_code, 
            startRow = current_row, startCol = 1)
  addStyle(wb, sheet_name, styles$title, rows = current_row, cols = 1)
  current_row <- current_row + 1
  
  writeData(wb, sheet_name, result$question_text,
            startRow = current_row, startCol = 1)
  current_row <- current_row + 1
  
  # TrackingSpecs if present
  if (!is.null(result$tracking_specs)) {
    writeData(wb, sheet_name, 
              paste0("TrackingSpecs: ", paste(result$tracking_specs, collapse = ", ")),
              startRow = current_row, startCol = 1)
    current_row <- current_row + 2
  }
  
  wave_ids <- names(result$wave_results)
  
  # Column headers
  headers <- c("% Mentioning", wave_ids)
  writeData(wb, sheet_name, t(headers),
            startRow = current_row, startCol = 1, colNames = FALSE)
  addStyle(wb, sheet_name, styles$header,
           rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1
  
  # Base row
  writeData(wb, sheet_name, "Base (n=)",
            startRow = current_row, startCol = 1)
  for (i in seq_along(wave_ids)) {
    n <- result$wave_results[[wave_ids[i]]]$n_unweighted
    writeData(wb, sheet_name, n, startRow = current_row, startCol = i + 1)
  }
  current_row <- current_row + 2
  
  # Mention rows (one per tracked column)
  for (col_name in result$tracked_columns) {
    # Write column label
    writeData(wb, sheet_name, col_name,
              startRow = current_row, startCol = 1)
    
    # Write proportions for each wave
    for (i in seq_along(wave_ids)) {
      wave_result <- result$wave_results[[wave_ids[i]]]
      if (wave_result$available && col_name %in% names(wave_result$mention_proportions)) {
        pct <- round(wave_result$mention_proportions[[col_name]], 1)
        writeData(wb, sheet_name, pct, startRow = current_row, startCol = i + 1)
      } else {
        writeData(wb, sheet_name, "—", startRow = current_row, startCol = i + 1)
      }
    }
    
    current_row <- current_row + 1
  }
  
  # Additional metrics if present
  if (length(result$wave_results[[wave_ids[1]]]$additional_metrics) > 0) {
    current_row <- current_row + 1
    writeData(wb, sheet_name, "Summary Metrics:",
              startRow = current_row, startCol = 1)
    addStyle(wb, sheet_name, styles$header, rows = current_row, cols = 1)
    current_row <- current_row + 1
    
    # "any" metric
    if ("any_mention_pct" %in% names(result$wave_results[[wave_ids[1]]]$additional_metrics)) {
      writeData(wb, sheet_name, "% Mentioning Any",
                startRow = current_row, startCol = 1)
      for (i in seq_along(wave_ids)) {
        pct <- result$wave_results[[wave_ids[i]]]$additional_metrics$any_mention_pct
        if (!is.null(pct) && !is.na(pct)) {
          writeData(wb, sheet_name, round(pct, 1), 
                    startRow = current_row, startCol = i + 1)
        }
      }
      current_row <- current_row + 1
    }
    
    # "count_mean" metric
    if ("count_mean" %in% names(result$wave_results[[wave_ids[1]]]$additional_metrics)) {
      writeData(wb, sheet_name, "Mean # Mentions",
                startRow = current_row, startCol = 1)
      for (i in seq_along(wave_ids)) {
        mean_count <- result$wave_results[[wave_ids[i]]]$additional_metrics$count_mean
        if (!is.null(mean_count) && !is.na(mean_count)) {
          writeData(wb, sheet_name, round(mean_count, 1),
                    startRow = current_row, startCol = i + 1)
        }
      }
      current_row <- current_row + 1
    }
  }
  
  # Set column widths
  setColWidths(wb, sheet_name, cols = 1:length(headers), widths = "auto")
}
```

#### 4.8.2 Enhanced Rating Output

**Show multiple metrics when TrackingSpecs specified:**

```
Overall Satisfaction (1-5 scale)
TrackingSpecs: mean, top2_box, range:4-5

                    Wave 1      Wave 2      Trend   Wave 3      Trend
Base (n=)           500         500                 500

Mean Score          3.8         3.9         →       4.2         ↑
% Top 2 Box (4-5)   55%         58%         →       68%         ↑
% Range 4-5         55%         58%         →       68%         ↑
```

**Implementation**: Similar structure to current rating output, but iterate through tracked metrics from TrackingSpecs.

---

## 5. IMPLEMENTATION PLAN

### 5.1 Phase 1: Infrastructure (Week 1 - Days 1-5)

#### Day 1-2: Helper Functions & Validation

**Files to modify:**
- `question_mapper.R`
- `validation_tracker.R`

**Tasks:**
- [ ] Add `get_tracking_specs()` function to question_mapper.R
- [ ] Add `validate_tracking_specs()` function to validation_tracker.R
- [ ] Add `validate_tracking_setup_enhanced()` to validation_tracker.R
- [ ] Write unit tests for validation functions

#### Day 3-4: Rating Enhancements

**Files to modify:**
- `trend_calculator.R`

**Tasks:**
- [ ] Add `calculate_top_box()` function
- [ ] Add `calculate_bottom_box()` function
- [ ] Add `calculate_custom_range()` function
- [ ] Add `calculate_distribution()` function
- [ ] Rename `calculate_rating_trend()` → `calculate_rating_trend_legacy()`
- [ ] Create `calculate_rating_trend_enhanced()`
- [ ] Update routing in `calculate_all_trends()` to use enhanced version
- [ ] Write unit tests for box/range calculations

#### Day 5: Composite Enhancements

**Files to modify:**
- `trend_calculator.R`

**Tasks:**
- [ ] Add `calculate_composite_values_per_respondent()` function
- [ ] Rename `calculate_composite_trend()` → `calculate_composite_trend_legacy()`
- [ ] Create `calculate_composite_trend_enhanced()`
- [ ] Write unit tests

### 5.2 Phase 2: Multi-Mention Support (Week 2 - Days 6-10)

#### Day 6-7: Multi-Mention Detection & Parsing

**Files to modify:**
- `trend_calculator.R`

**Tasks:**
- [ ] Add `detect_multi_mention_columns()` function
- [ ] Add `parse_multi_mention_specs()` function
- [ ] Update `normalize_question_type()` to handle Multi_Mention
- [ ] Write unit tests for detection and parsing

#### Day 8-9: Multi-Mention Calculation

**Files to modify:**
- `trend_calculator.R`

**Tasks:**
- [ ] Add `calculate_multi_mention_trend()` function
- [ ] Add `perform_significance_tests_multi_mention()` function
- [ ] Add `perform_significance_tests_for_metric()` helper
- [ ] Update `calculate_all_trends()` routing
- [ ] Write unit tests for calculation

#### Day 10: Multi-Mention Output

**Files to modify:**
- `tracker_output.R`

**Tasks:**
- [ ] Add `write_multi_mention_sheet()` function
- [ ] Update `write_tracker_output()` to detect and route Multi_Mention results
- [ ] Write integration test for full Multi_Mention flow

### 5.3 Phase 3: Output & Testing (Week 3 - Days 11-15)

#### Day 11: Enhanced Output Formatting

**Files to modify:**
- `tracker_output.R`

**Tasks:**
- [ ] Update `write_trend_sheets()` to handle enhanced results
- [ ] Add support for multiple metrics in rating sheets
- [ ] Update formatting for TrackingSpecs display
- [ ] Test output with all question types

#### Day 12-13: Integration Testing

**Tasks:**
- [ ] Create comprehensive test dataset with all question types
- [ ] Test backward compatibility (run old configs, verify identical output)
- [ ] Test each TrackingSpecs combination
- [ ] Test Multi_Mention with various configurations
- [ ] Test validation function with valid and invalid configs

#### Day 14: Documentation Updates

**Files to update:**
- `USER_MANUAL.md`
- `TECHNICAL_DOCUMENTATION.md`
- `QUICK_START.md`
- `EXAMPLE_WORKFLOWS.md`
- `README_TEMPLATES.md`

**Tasks:**
- [ ] Add TrackingSpecs section to USER_MANUAL
- [ ] Add Multi_Mention section to USER_MANUAL
- [ ] Update TECHNICAL_DOCUMENTATION with new functions
- [ ] Add example workflows
- [ ] Update templates

#### Day 15: Final Polish & Release

**Tasks:**
- [ ] Run full test suite
- [ ] Performance testing (ensure <10% slowdown)
- [ ] Code review
- [ ] Create updated templates
- [ ] Update version numbers
- [ ] Create release notes

### 5.4 Implementation Order Summary

```
Week 1: Core Infrastructure
├── Day 1-2: Validation & helpers
├── Day 3-4: Rating enhancements
└── Day 5: Composite enhancements

Week 2: Multi-Mention
├── Day 6-7: Detection & parsing
├── Day 8-9: Calculation & significance
└── Day 10: Output formatting

Week 3: Testing & Release
├── Day 11: Enhanced output
├── Day 12-13: Testing
├── Day 14: Documentation
└── Day 15: Release
```

---

## 6. TESTING STRATEGY

### 6.1 Unit Tests

**File Structure:**

```
modules/tracker/tests/
├── test_tracking_specs.R
├── test_multi_mention.R
├── test_rating_enhanced.R
├── test_composite_enhanced.R
├── test_validation.R
└── fixtures/
    ├── test_data_multi_mention.csv
    ├── test_config.xlsx
    └── test_mapping.xlsx
```

### 6.2 Critical Unit Tests

**test_tracking_specs.R:**

```r
library(testthat)

test_that("get_tracking_specs returns NULL when column missing", {
  question_map <- create_test_question_map(include_tracking_specs = FALSE)
  result <- get_tracking_specs(question_map, "Q_SAT")
  expect_null(result)
})

test_that("get_tracking_specs returns NULL when blank", {
  question_map <- create_test_question_map(tracking_specs = "")
  result <- get_tracking_specs(question_map, "Q_SAT")
  expect_null(result)
})

test_that("get_tracking_specs parses correctly", {
  question_map <- create_test_question_map(tracking_specs = "mean,top2_box")
  result <- get_tracking_specs(question_map, "Q_SAT")
  expect_equal(result, "mean,top2_box")
})

test_that("validate_tracking_specs catches invalid specs", {
  result <- validate_tracking_specs("top4_box", "Rating")
  expect_false(result$valid)
})

test_that("validate_tracking_specs allows range specs", {
  result <- validate_tracking_specs("mean,range:9-10", "Rating")
  expect_true(result$valid)
})
```

**test_multi_mention.R:**

```r
test_that("detect_multi_mention_columns finds columns", {
  test_df <- data.frame(
    Q30_1 = c(1, 0, 1),
    Q30_2 = c(0, 1, 0),
    Q30_3 = c(1, 1, 0),
    Q31_1 = c(1, 0, 1)
  )
  
  result <- detect_multi_mention_columns(test_df, "Q30")
  expect_equal(result, c("Q30_1", "Q30_2", "Q30_3"))
})

test_that("detect_multi_mention_columns sorts numerically", {
  test_df <- data.frame(
    Q30_10 = c(1),
    Q30_2 = c(0),
    Q30_1 = c(1)
  )
  
  result <- detect_multi_mention_columns(test_df, "Q30")
  expect_equal(result, c("Q30_1", "Q30_2", "Q30_10"))
})

test_that("parse_multi_mention_specs handles auto", {
  test_df <- data.frame(Q30_1 = c(1), Q30_2 = c(0))
  result <- parse_multi_mention_specs("auto", "Q30", test_df)
  expect_equal(result$mode, "auto")
  expect_equal(result$columns, c("Q30_1", "Q30_2"))
})

test_that("parse_multi_mention_specs handles selective", {
  test_df <- data.frame(Q30_1 = c(1), Q30_2 = c(0), Q30_3 = c(1))
  result <- parse_multi_mention_specs("option:Q30_1,option:Q30_3", "Q30", test_df)
  expect_equal(result$mode, "selective")
  expect_equal(result$columns, c("Q30_1", "Q30_3"))
})
```

**test_rating_enhanced.R:**

```r
test_that("calculate_top_box works for 1-5 scale", {
  values <- c(1, 2, 3, 4, 5, 4, 5, 3, 4, 5)
  weights <- rep(1, 10)
  
  result <- calculate_top_box(values, weights, n_boxes = 1)
  expect_equal(result$proportion, 30)  # 3 out of 10 are 5
  expect_equal(result$top_values, 5)
})

test_that("calculate_top_box works for top 2", {
  values <- c(1, 2, 3, 4, 5, 4, 5, 3, 4, 5)
  weights <- rep(1, 10)
  
  result <- calculate_top_box(values, weights, n_boxes = 2)
  expect_equal(result$proportion, 60)  # 6 out of 10 are 4 or 5
  expect_equal(sort(result$top_values), c(4, 5))
})

test_that("calculate_custom_range works", {
  values <- 1:10
  weights <- rep(1, 10)
  
  result <- calculate_custom_range(values, weights, "range:9-10")
  expect_equal(result$proportion, 20)  # 2 out of 10
  expect_equal(result$range_values, c(9, 10))
})

test_that("calculate_custom_range handles invalid syntax", {
  values <- 1:10
  weights <- rep(1, 10)
  
  result <- calculate_custom_range(values, weights, "range:invalid")
  expect_true(is.na(result$proportion))
})
```

### 6.3 Integration Tests

**test_integration.R:**

```r
test_that("Full tracking analysis with Multi_Mention", {
  # Setup
  create_test_tracking_dataset(
    output_dir = tempdir(),
    n_waves = 3,
    n_respondents = 100,
    include_multi_mention = TRUE
  )
  
  # Run
  result <- run_tracker(
    tracking_config_path = file.path(tempdir(), "tracking_config.xlsx"),
    question_mapping_path = file.path(tempdir(), "question_mapping.xlsx"),
    data_dir = tempdir()
  )
  
  # Verify
  expect_true(file.exists(result))
  
  # Load results and check
  wb <- loadWorkbook(result)
  sheets <- names(wb)
  expect_true("Q_REASON" %in% sheets)  # Multi-mention question
})

test_that("Backward compatibility - configs without TrackingSpecs", {
  # Setup old-style config
  create_legacy_config(tempdir())
  
  # Run
  result_new <- run_tracker(
    tracking_config_path = file.path(tempdir(), "legacy_config.xlsx"),
    question_mapping_path = file.path(tempdir(), "legacy_mapping.xlsx")
  )
  
  # Load and verify same structure as before
  wb <- loadWorkbook(result_new)
  expect_true("Q_SAT" %in% names(wb))
  
  # Check that default metrics calculated (mean for ratings)
  # (Would need to parse Excel to verify exact values match)
})

test_that("TrackingSpecs with all combinations", {
  # Test each question type with various TrackingSpecs
  test_cases <- list(
    list(type = "Rating", specs = "mean,top2_box"),
    list(type = "Rating", specs = "range:9-10,range:7-8"),
    list(type = "NPS", specs = "nps_score"),
    list(type = "Multi_Mention", specs = "auto,any,count_mean"),
    list(type = "Composite", specs = "mean,top2_box")
  )
  
  for (test_case in test_cases) {
    result <- run_tracker_with_specs(
      question_type = test_case$type,
      tracking_specs = test_case$specs
    )
    expect_true(file.exists(result))
  }
})
```

### 6.4 Validation Tests

**test_validation.R:**

```r
test_that("Validation catches missing TrackingSpecs column gracefully", {
  config <- create_config_without_tracking_specs()
  
  validation <- validate_tracking_setup_enhanced(
    tracking_config_path = config$tracking,
    question_mapping_path = config$mapping
  )
  
  expect_true(validation$valid)
  expect_equal(length(validation$issues$errors), 0)
})

test_that("Validation catches invalid TrackingSpecs", {
  config <- create_config_with_invalid_specs(
    question_type = "Rating",
    invalid_spec = "top4_box"
  )
  
  validation <- validate_tracking_setup_enhanced(
    tracking_config_path = config$tracking,
    question_mapping_path = config$mapping
  )
  
  expect_false(validation$valid)
  expect_true(length(validation$issues$warnings) > 0)
})

test_that("Validation detects Multi_Mention column issues", {
  config <- create_config_with_multi_mention_missing_columns()
  
  validation <- validate_tracking_setup_enhanced(
    tracking_config_path = config$tracking,
    question_mapping_path = config$mapping,
    data_dir = config$data_dir
  )
  
  expect_true(length(validation$issues$warnings) > 0)
  # Should warn about missing columns
})
```

### 6.5 Performance Tests

**test_performance.R:**

```r
test_that("Performance impact < 10% for standard config", {
  # Create large dataset
  create_large_test_dataset(
    n_waves = 10,
    n_respondents = 1000,
    n_questions = 50
  )
  
  # Baseline (legacy without TrackingSpecs)
  time_baseline <- system.time({
    run_tracker_legacy()
  })
  
  # With TrackingSpecs (but using defaults)
  time_enhanced <- system.time({
    run_tracker_enhanced()
  })
  
  # Check overhead
  overhead <- (time_enhanced["elapsed"] - time_baseline["elapsed"]) / time_baseline["elapsed"]
  expect_true(overhead < 0.10)  # Less than 10% slower
})
```

---

## 7. DOCUMENTATION UPDATES

### 7.1 Files to Update

| File | Changes Required |
|------|------------------|
| USER_MANUAL.md | Add TrackingSpecs section, Multi_Mention examples |
| TECHNICAL_DOCUMENTATION.md | Document new functions, API changes |
| QUICK_START.md | Brief TrackingSpecs mention, Multi_Mention example |
| EXAMPLE_WORKFLOWS.md | Add workflows 9-10 for new features |
| README_TEMPLATES.md | Update template descriptions |

### 7.2 USER_MANUAL.md Updates

**New Section to Add:**

## TrackingSpecs - Advanced Metric Tracking

### Overview

The optional `TrackingSpecs` column in `question_mapping.xlsx` allows you to specify exactly which metrics to track for each question.

### Rating Questions

**Available specs:**
- `mean` - Mean score (default)
- `top_box` - % giving highest value
- `top2_box` - % giving top 2 values
- `top3_box` - % giving top 3 values
- `bottom_box` - % giving lowest value
- `bottom2_box` - % giving bottom 2 values
- `range:X-Y` - % giving values between X and Y
- `distribution` - % for each value

**Example:**

| QuestionCode | QuestionType | TrackingSpecs | Wave1 | Wave2 |
|---|---|---|---|---|
| Q_SAT | Rating | mean,top2_box | Q10 | Q11 |

**Output:**
```
Overall Satisfaction (1-5)
                Wave 1  Wave 2  Trend
Mean            3.8     4.2     ↑
% Top 2 Box     55%     68%     ↑
```

### Multi-Mention Questions

**NEW: Multi-mention questions are now supported!**

**Data Format:**
Your data should have one column per option:

```csv
Q30_1, Q30_2, Q30_3, Q30_4
1,     1,     0,     0      (selected options 1 and 2)
1,     0,     1,     0      (selected options 1 and 3)
```

**Setup:**

| QuestionCode | QuestionType | TrackingSpecs | Wave1 | Wave2 |
|---|---|---|---|---|
| Q_REASON | Multi_Mention | auto | Q30 | Q35 |

**Available specs:**
- `auto` - Track all detected options (default)
- `option:Q30_1` - Track specific option
- `any` - % mentioning at least one
- `count_mean` - Mean number of mentions

**Example output:**

```
Reasons for Choosing
                    Wave 1  Wave 2  Trend
% Mentioning:
  Quality (Q30_1)   45%     50%     ↑
  Price (Q30_2)     30%     28%     →
  Service (Q30_3)   25%     30%     ↑

% Mentioning Any    92%     95%     →
```

*(Continue with more examples...)*

### 7.3 TECHNICAL_DOCUMENTATION.md Updates

**New Section:**

## Enhanced Trend Calculation

### TrackingSpecs System

#### get_tracking_specs()

Retrieves TrackingSpecs for a question.

**Signature:**

```r
get_tracking_specs(question_map, question_code)
```

**Returns**: Character string or NULL

#### validate_tracking_specs()

Validates TrackingSpecs syntax for question type.

**Signature:**

```r
validate_tracking_specs(specs_str, question_type)
```

**Returns**: List with `$valid` and `$message`

### Multi-Mention Support

#### detect_multi_mention_columns()

Auto-detects multi-mention option columns.

**Signature:**

```r
detect_multi_mention_columns(wave_df, base_code)
```

**Algorithm:**
1. Build regex pattern: `^{base_code}_[0-9]+$`
2. Find matching columns
3. Sort numerically by suffix
4. Return sorted vector

*(Continue with detailed documentation...)*

---

## 8. ACCEPTANCE CRITERIA

### 8.1 Functional Acceptance

**All must pass for release:**

- [ ] **FR-001**: TrackingSpecs column supported in question_mapping.xlsx
  - Test: Create mapping with TrackingSpecs, verify parsing
  
- [ ] **FR-002**: Rating questions support all TrackingSpecs
  - Test: Run tracker with each spec (mean, top_box, range, etc.)
  - Verify: Output contains correct metrics
  
- [ ] **FR-003**: Multi_Mention questions fully supported
  - Test: Track Multi_Mention question across 3 waves
  - Verify: % for each option calculated, trends shown
  
- [ ] **FR-004**: Selective option tracking works
  - Test: Use `option:Q30_1,option:Q30_3` spec
  - Verify: Only specified options in output
  
- [ ] **FR-005**: Composite questions support TrackingSpecs
  - Test: Composite with `mean,top2_box`
  - Verify: Both metrics calculated on composite scores
  
- [ ] **FR-006**: Validation function provides actionable warnings
  - Test: Deliberately create invalid config
  - Verify: Validation catches issues with clear messages
  
- [ ] **FR-007**: Backward compatibility maintained
  - Test: Run 5 existing project configs without modification
  - Verify: Output identical to previous version

### 8.2 Non-Functional Acceptance

- [ ] **NFR-001**: 100% backward compatibility
  - Test: Run 20 existing configs, verify no errors
  
- [ ] **NFR-002**: Processing time increase <10%
  - Test: Benchmark standard config before/after
  
- [ ] **NFR-003**: Memory usage increase <20%
  - Test: Monitor memory during large dataset processing
  
- [ ] **NFR-004**: Code maintainability
  - Review: All functions documented
  - Review: Code follows existing patterns
  
- [ ] **NFR-005**: Test coverage >80%
  - Measure: Run coverage analysis on new code
  - Verify: >80% of new lines covered

### 8.3 Quality Gates

**Gate 1: Development Complete**
- [ ] All functions implemented
- [ ] Unit tests written and passing
- [ ] No compilation errors

**Gate 2: Integration Testing**
- [ ] Integration tests passing
- [ ] Backward compatibility verified
- [ ] Performance acceptable

**Gate 3: Documentation**
- [ ] All documentation updated
- [ ] Templates updated
- [ ] Examples provided

**Gate 4: Release**
- [ ] Code reviewed
- [ ] All acceptance criteria met
- [ ] Release notes prepared

---

## 9. RISKS & MITIGATION

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Breaking existing configs | HIGH | LOW | Comprehensive backward compatibility testing |
| Performance degradation | MEDIUM | MEDIUM | Performance testing, optimization if needed |
| Multi-mention edge cases | MEDIUM | MEDIUM | Extensive unit testing, clear error messages |
| Complex TrackingSpecs syntax confusing | LOW | MEDIUM | Good documentation, validation with clear errors |
| Output format becomes too large | MEDIUM | LOW | Selective tracking feature, pagination if needed |

---

## 10. APPENDICES

### 10.1 Function Signature Reference

**New Functions:**

```r
# Helper functions
get_tracking_specs(question_map, question_code)
validate_tracking_specs(specs_str, question_type)

# Multi-mention
detect_multi_mention_columns(wave_df, base_code)
parse_multi_mention_specs(tracking_specs, base_code, wave_df)
calculate_multi_mention_trend(q_code, question_map, wave_data, config)
perform_significance_tests_multi_mention(wave_results, wave_ids, column_name, config)

# Rating enhancements
calculate_top_box(values, weights, n_boxes = 1)
calculate_bottom_box(values, weights, n_boxes = 1)
calculate_custom_range(values, weights, range_spec)
calculate_distribution(values, weights)
calculate_rating_trend_enhanced(q_code, question_map, wave_data, config)

# Composite enhancements
calculate_composite_values_per_respondent(wave_df, wave_id, source_questions, question_map)
calculate_composite_trend_enhanced(q_code, question_map, wave_data, config)

# Validation
validate_tracking_setup_enhanced(tracking_config_path, question_mapping_path, 
                                 data_dir = NULL, report_mode = "detailed")

# Output
write_multi_mention_sheet(wb, sheet_name, result, config, styles)

# Utility
perform_significance_tests_for_metric(wave_results, wave_ids, metric_name, 
                                      config, test_type = "proportion")
```

### 10.2 File Modification Summary

| File | LOC Added | LOC Modified | LOC Removed |
|------|-----------|--------------|-------------|
| question_mapper.R | ~50 | ~10 | 0 |
| validation_tracker.R | ~300 | ~50 | 0 |
| trend_calculator.R | ~800 | ~100 | 0 |
| tracker_output.R | ~200 | ~100 | 0 |
| **TOTAL** | **~1,350** | **~260** | **0** |

**Estimated Total Code Changes**: ~1,600 lines

---

## DOCUMENT APPROVAL

| Item | Details |
|------|---------|
| Prepared By | [System] |
| Date | 2025-11-21 |
| Version | 1.0 |
| Ready for Implementation | ✓ YES |

---

## END OF SPECIFICATION

This specification is complete and ready for Claude Code to implement. All requirements are clearly defined, implementation steps are detailed, and acceptance criteria are measurable.
