# Part 4: Alchemer Choice Types & Format Support

## Overview

This specification extends the Turas Conjoint module to support all Alchemer choice-based conjoint formats through a phased approach:

- **Phase 1:** Single Choice + Single Choice with None
- **Phase 2:** Best vs. Worst + Continuous Sum

## 1. Alchemer Choice Type Overview

### 1.1 Choice Type Summary

| Choice Type | Use Case | Dependent Variable | Phase |
|-------------|----------|-------------------|-------|
| Single Choice | Standard CBC | Binary (0/1) | ✅ Phase 1 |
| Single Choice + None | CBC with opt-out | Binary (0/1) + none | ✅ Phase 1 |
| Best vs. Worst | Ranking/MaxDiff | Scored (0 to 2/n) | ⚠️ Phase 2 |
| Continuous Sum | Share allocation | Percentage (0-100) | ⚠️ Phase 2 |

### 1.2 Data Structure by Choice Type

#### Single Choice (Current Implementation)
```
resp_id | choice_set_id | alternative_id | Price | Brand | chosen
1       | 1             | 1              | $10   | A     | 0
1       | 1             | 2              | $15   | B     | 1
1       | 1             | 3              | $20   | A     | 0
```

#### Single Choice with None (Phase 1 Addition)
```
resp_id | choice_set_id | alternative_id | Price    | Brand  | chosen
1       | 1             | 1              | $10      | A      | 0
1       | 1             | 2              | $15      | B      | 0
1       | 1             | 3              | $20      | A      | 0
1       | 1             | 4              | NONE     | NONE   | 1
# OR alternative coding:
1       | 1             | NONE           | NA       | NA     | 1
```

#### Best vs. Worst (Phase 2)
```
resp_id | choice_set_id | alternative_id | Price | Brand | best | worst
1       | 1             | 1              | $10   | A     | 1    | 0
1       | 1             | 2              | $15   | B     | 0    | 0
1       | 1             | 3              | $20   | A     | 0    | 1
```

#### Continuous Sum (Phase 2)
```
resp_id | choice_set_id | alternative_id | Price | Brand | allocation
1       | 1             | 1              | $10   | A     | 40
1       | 1             | 2              | $15   | B     | 35
1       | 1             | 3              | $20   | A     | 25
# Must sum to max_total (e.g., 100)
```

## 2. Phase 1 Implementation: None Option Support

### 2.1 Detection Logic

```r
detect_none_option <- function(data, config) {
  
  # Method 1: Check for "none" in attribute values
  none_patterns <- c(
    "none", "no choice", "neither", "none of these", "none of the above",
    "no option", "opt out", "skip"
  )
  
  has_none_in_attributes <- FALSE
  for (attr in config$attributes$AttributeName) {
    attr_values <- unique(tolower(as.character(data[[attr]])))
    if (any(sapply(none_patterns, function(p) any(grepl(p, attr_values))))) {
      has_none_in_attributes <- TRUE
      break
    }
  }
  
  # Method 2: Check for choice sets where all alternatives unchosen
  # (indicates none was selected but not in data as row)
  chosen_per_set <- data %>%
    group_by(!!sym(config$settings$choice_set_column)) %>%
    summarise(n_chosen = sum(!!sym(config$settings$chosen_column)))
  
  has_all_zeros <- any(chosen_per_set$n_chosen == 0)
  
  # Method 3: Check if alternative_id includes "none" identifier
  if (!is.null(config$settings$alternative_id_column)) {
    if (config$settings$alternative_id_column %in% names(data)) {
      alt_ids <- unique(tolower(as.character(data[[config$settings$alternative_id_column]])))
      has_none_alt_id <- any(sapply(none_patterns, function(p) any(grepl(p, alt_ids))))
    }
  } else {
    has_none_alt_id <- FALSE
  }
  
  list(
    has_none = has_none_in_attributes || has_all_zeros || has_none_alt_id,
    method = case_when(
      has_none_in_attributes ~ "none_in_attributes",
      has_all_zeros ~ "all_unchosen_sets",
      has_none_alt_id ~ "none_alternative_id",
      TRUE ~ "no_none_detected"
    ),
    none_count = if (has_all_zeros) sum(chosen_per_set$n_chosen == 0) else 0
  )
}
```

### 2.2 Data Handling for None Option

```r
handle_none_option <- function(data, config) {
  
  none_info <- detect_none_option(data, config)
  
  if (!none_info$has_none) {
    return(list(
      data = data,
      has_none = FALSE,
      none_handling = "not_applicable"
    ))
  }
  
  message(sprintf("None option detected (method: %s)", none_info$method))
  
  # Case 1: None is explicit row in data
  if (none_info$method == "none_in_attributes" || 
      none_info$method == "none_alternative_id") {
    
    # Identify none rows
    none_rows <- identify_none_rows(data, config)
    
    # Flag none alternatives
    data$is_none_alternative <- FALSE
    data$is_none_alternative[none_rows] <- TRUE
    
    # Validation: Check each choice set has at most 1 chosen
    validate_none_choices(data, config)
    
    return(list(
      data = data,
      has_none = TRUE,
      none_handling = "explicit_none_rows",
      n_none_chosen = sum(data$chosen[data$is_none_alternative])
    ))
  }
  
  # Case 2: None is implicit (all alternatives unchosen in some sets)
  if (none_info$method == "all_unchosen_sets") {
    
    # Add explicit none rows for these choice sets
    data <- add_none_rows(data, config)
    
    return(list(
      data = data,
      has_none = TRUE,
      none_handling = "implicit_none_added",
      n_none_chosen = none_info$none_count
    ))
  }
}

identify_none_rows <- function(data, config) {
  
  none_patterns <- c(
    "none", "no choice", "neither", "none of these", 
    "none of the above", "no option", "opt out", "skip"
  )
  
  # Check each attribute for none values
  is_none <- rep(FALSE, nrow(data))
  
  for (attr in config$attributes$AttributeName) {
    attr_values <- tolower(as.character(data[[attr]]))
    matches_none <- sapply(none_patterns, function(p) grepl(p, attr_values))
    is_none <- is_none | apply(matches_none, 1, any)
  }
  
  # Also check alternative_id if available
  if (!is.null(config$settings$alternative_id_column)) {
    if (config$settings$alternative_id_column %in% names(data)) {
      alt_ids <- tolower(as.character(data[[config$settings$alternative_id_column]]))
      matches_none_alt <- sapply(none_patterns, function(p) grepl(p, alt_ids))
      is_none <- is_none | apply(matches_none_alt, 1, any)
    }
  }
  
  which(is_none)
}

add_none_rows <- function(data, config) {
  
  # Find choice sets where all alternatives are unchosen
  all_unchosen_sets <- data %>%
    group_by(!!sym(config$settings$choice_set_column)) %>%
    summarise(
      resp_id = first(!!sym(config$settings$respondent_id_column)),
      n_chosen = sum(!!sym(config$settings$chosen_column))
    ) %>%
    filter(n_chosen == 0)
  
  if (nrow(all_unchosen_sets) == 0) {
    return(data)
  }
  
  message(sprintf("Adding explicit 'none' rows for %d choice sets", 
                  nrow(all_unchosen_sets)))
  
  # Create none rows
  none_rows <- data.frame(
    resp_id = all_unchosen_sets$resp_id,
    choice_set_id = all_unchosen_sets[[config$settings$choice_set_column]],
    alternative_id = "NONE",
    chosen = 1,
    is_none_alternative = TRUE
  )
  
  # Set all attributes to "NONE" for none rows
  for (attr in config$attributes$AttributeName) {
    none_rows[[attr]] <- "NONE"
  }
  
  # Add to original data
  data$is_none_alternative <- FALSE
  data <- bind_rows(data, none_rows)
  
  data
}

validate_none_choices <- function(data, config) {
  
  # Check: Exactly one chosen per choice set
  chosen_per_set <- data %>%
    group_by(!!sym(config$settings$choice_set_column)) %>%
    summarise(n_chosen = sum(!!sym(config$settings$chosen_column)))
  
  if (any(chosen_per_set$n_chosen != 1)) {
    bad_sets <- chosen_per_set %>%
      filter(n_chosen != 1) %>%
      pull(!!sym(config$settings$choice_set_column))
    
    stop(sprintf(
      "[DATA] Error: Choice sets with invalid choice counts: %s
 → Each choice set must have exactly 1 chosen alternative (including 'none')
 → Check these choice set IDs in your data",
      paste(head(bad_sets, 5), collapse = ", ")
    ))
  }
  
  # Check: If none is chosen, no other alternative should be chosen
  none_chosen_sets <- data %>%
    filter(is_none_alternative & !!sym(config$settings$chosen_column) == 1) %>%
    pull(!!sym(config$settings$choice_set_column))
  
  other_chosen_in_none_sets <- data %>%
    filter(
      !!sym(config$settings$choice_set_column) %in% none_chosen_sets,
      !is_none_alternative,
      !!sym(config$settings$chosen_column) == 1
    )
  
  if (nrow(other_chosen_in_none_sets) > 0) {
    stop(
      "[DATA] Error: Some choice sets have both 'none' and another alternative selected
 → When 'none' is chosen, no other alternative should be chosen
 → Check your data export from Alchemer"
    )
  }
  
  TRUE
}
```

### 2.3 Model Estimation with None

```r
estimate_mlogit_with_none <- function(data, config) {
  
  # Handle none option
  data_processed <- handle_none_option(data, config)
  data <- data_processed$data
  
  if (data_processed$has_none) {
    message(sprintf(
      "None option included: %d respondents chose 'none' option (%.1f%%)",
      data_processed$n_none_chosen,
      data_processed$n_none_chosen / length(unique(data$choice_set_id)) * 100
    ))
  }
  
  # For mlogit: None is just another alternative
  # It will get its own utility estimate
  # The baseline handling determines which level is reference
  
  # If baseline_handling = "first_level_zero":
  # - None typically becomes the baseline (utility = 0) if it sorts first
  # - Or specify none as baseline explicitly
  
  # Prepare data for mlogit
  mlogit_data <- prepare_mlogit_data(data, config)
  
  # Fit model
  model <- mlogit::mlogit(
    formula = build_mlogit_formula(config),
    data = mlogit_data,
    method = "nr"  # Newton-Raphson
  )
  
  # Extract results
  results <- extract_mlogit_results(model, data, config)
  
  # Add none-specific diagnostics
  if (data_processed$has_none) {
    results$none_diagnostics <- calculate_none_diagnostics(model, data, config)
  }
  
  results
}

calculate_none_diagnostics <- function(model, data, config) {
  
  # Calculate metrics specific to none option
  list(
    none_share = mean(data$is_none_alternative[data$chosen == 1]),
    none_utility = get_none_utility(model, data),
    none_vs_alternatives = compare_none_to_alternatives(model, data, config)
  )
}
```

### 2.4 Market Simulator with None

```r
# In market simulator, add "None" as a product option

create_market_simulator_with_none <- function(wb, results, config) {
  
  # If none option exists in data:
  if (results$has_none) {
    
    # Option 1: Add "None" as Product 6
    # - User can't change attributes (all are "NONE")
    # - Utility is fixed from model
    # - Always included in share calculation
    
    # Option 2: Add "Include None?" checkbox
    # - User can toggle none in/out
    # - Affects market shares of other products
    
    # Recommended: Option 2 (more flexible)
    
    # Add None toggle
    writeData(wb, "Market Simulator", 
              "Include 'None' Option?", 
              startRow = 9, startCol = 7)
    
    dataValidation(
      wb, "Market Simulator",
      col = 8, rows = 9,
      type = "list",
      value = '"Yes,No"'
    )
    
    writeData(wb, "Market Simulator", "Yes", 
              startRow = 9, startCol = 8)
    
    # Add None utility (fixed)
    none_utility <- results$utilities %>%
      filter(is_none_alternative) %>%
      pull(Utility) %>%
      first()
    
    # Modify market share formula to include none conditionally
    # =IF(H9="Yes", EXP(none_utility), 0)
  }
  
  # Rest of simulator creation...
}
```

### 2.5 Configuration Changes for None

```r
# Add to Settings sheet:

Setting: none_as_baseline
Value: TRUE | FALSE
Default: FALSE
Description: If TRUE, force 'none' to be the baseline (utility=0). 
             If FALSE, use standard baseline handling.

Setting: none_label
Value: string
Default: "None"
Description: Label to use for none option in outputs and simulator
```

## 3. Phase 2 Groundwork: Best vs. Worst

### 3.1 Data Structure Requirements

**Expected Format:**
```
resp_id | choice_set_id | alternative_id | Price | Brand | best | worst
1       | 1             | 1              | $10   | A     | 1    | 0
1       | 1             | 2              | $15   | B     | 0    | 0
1       | 1             | 3              | $20   | A     | 0    | 1
```

**Validation Rules:**
- Exactly one `best=1` per choice set
- Exactly one `worst=1` per choice set
- `best` and `worst` cannot both be 1 for same alternative
- All other alternatives have `best=0` and `worst=0`

### 3.2 Analysis Approach

**Method 1: Convert to Scores (Alchemer Method)**
```r
convert_best_worst_to_scores <- function(data, config) {
  
  # Calculate n alternatives per choice set
  n_alts_per_set <- data %>%
    count(!!sym(config$settings$choice_set_column)) %>%
    pull(n)
  
  # Score calculation:
  # - Worst = 0
  # - Middle = 1/n
  # - Best = 2/n
  
  data <- data %>%
    mutate(
      score = case_when(
        worst == 1 ~ 0,
        best == 1 ~ 2 / n_alts_per_set[cur_group_id()],
        TRUE ~ 1 / n_alts_per_set[cur_group_id()]
      )
    )
  
  data
}

estimate_best_worst_conjoint <- function(data, config) {
  
  # Convert to scores
  data <- convert_best_worst_to_scores(data, config)
  
  # Use OLS regression with scores as DV
  # OR use ChoiceModelR with share-dependent variable
  
  # Build formula
  formula_str <- paste(
    "score ~",
    paste(config$attributes$AttributeName, collapse = " + ")
  )
  
  model <- lm(as.formula(formula_str), data = data)
  
  # Extract utilities
  # Similar to rating-based conjoint
  utilities <- extract_utilities_from_lm(model, config)
  
  # Calculate importance
  importance <- calculate_importance(utilities, config)
  
  list(
    method = "best_worst_ols",
    model = model,
    utilities = utilities,
    importance = importance,
    fit = calculate_fit_ols(model, data)
  )
}
```

**Method 2: Exploded Logit (Advanced)**
```r
# Convert Best vs. Worst to two separate choice observations
# - Choice 1: Best (standard discrete choice)
# - Choice 2: Worst (reverse-coded discrete choice)

explode_best_worst <- function(data, config) {
  
  # Create "best" choice sets
  best_data <- data %>%
    mutate(
      choice_set_id_new = paste0(choice_set_id, "_best"),
      chosen = best
    ) %>%
    select(-best, -worst)
  
  # Create "worst" choice sets (with reversed coding)
  worst_data <- data %>%
    mutate(
      choice_set_id_new = paste0(choice_set_id, "_worst"),
      chosen = worst,
      # Reverse code: worst becomes "chosen" but utilities will be negative
      is_worst_task = TRUE
    ) %>%
    select(-best, -worst)
  
  bind_rows(best_data, worst_data)
}

# Then use standard mlogit with task type as covariate
```

### 3.3 Configuration for Best vs. Worst

```r
# Add to Settings sheet:

Setting: choice_type
Values: "single" | "single_with_none" | "best_worst" | "continuous_sum"
Default: "single"
Required: Yes

Setting: best_column
Value: string (column name)
Default: "best"
Required if choice_type = "best_worst"

Setting: worst_column  
Value: string (column name)
Default: "worst"
Required if choice_type = "best_worst"

Setting: best_worst_method
Values: "scored_ols" | "exploded_logit" | "choicemodelr"
Default: "scored_ols"
Required if choice_type = "best_worst"
```

### 3.4 Implementation Stub

```r
# In 03_estimation.R

estimate_choice_model <- function(data, config, method = "auto") {
  
  # Determine choice type
  choice_type <- config$settings$choice_type %||% "single"
  
  if (choice_type == "best_worst") {
    
    # Validate Phase 2 is implemented
    if (!exists("estimate_best_worst_conjoint")) {
      stop(
        "[FEATURE] Best vs. Worst analysis not yet implemented
 → This is a Phase 2 feature
 → Use Alchemer's built-in analysis for now
 → Or contact support about Phase 2 timeline"
      )
    }
    
    return(estimate_best_worst_conjoint(data, config))
  }
  
  # Standard single choice or single_with_none
  # (existing implementation)
  # ...
}
```

## 4. Phase 2 Groundwork: Continuous Sum

### 4.1 Data Structure Requirements

**Expected Format:**
```
resp_id | choice_set_id | alternative_id | Price | Brand | allocation
1       | 1             | 1              | $10   | A     | 40
1       | 1             | 2              | $15   | B     | 35
1       | 1             | 3              | $20   | A     | 25
```

**Validation Rules:**
- Allocations sum to `max_total` (typically 100) per choice set
- All allocations >= 0
- At least one allocation > 0 per choice set

### 4.2 Analysis Approach

**Method: Convert to Shares**
```r
convert_continuous_sum_to_shares <- function(data, config) {
  
  max_total <- config$settings$max_total %||% 100
  
  # Calculate actual total per choice set
  totals <- data %>%
    group_by(!!sym(config$settings$choice_set_column)) %>%
    summarise(actual_total = sum(allocation))
  
  # Validate
  if (any(abs(totals$actual_total - max_total) > 0.01)) {
    warning("Some choice sets don't sum to max_total. Converting to shares anyway.")
  }
  
  # Convert to shares (0-1 scale)
  data <- data %>%
    group_by(!!sym(config$settings$choice_set_column)) %>%
    mutate(share = allocation / sum(allocation))
  
  data
}

estimate_continuous_sum_conjoint <- function(data, config) {
  
  # Convert to shares
  data <- convert_continuous_sum_to_shares(data, config)
  
  # Use OLS regression with shares as DV
  # OR use ChoiceModelR with share-dependent variable
  
  formula_str <- paste(
    "share ~",
    paste(config$attributes$AttributeName, collapse = " + ")
  )
  
  model <- lm(as.formula(formula_str), data = data)
  
  # Extract utilities
  utilities <- extract_utilities_from_lm(model, config)
  
  # Calculate importance
  importance <- calculate_importance(utilities, config)
  
  list(
    method = "continuous_sum_ols",
    model = model,
    utilities = utilities,
    importance = importance,
    fit = calculate_fit_ols(model, data)
  )
}
```

### 4.3 Configuration for Continuous Sum

```r
# Add to Settings sheet:

Setting: allocation_column
Value: string (column name)
Default: "allocation"
Required if choice_type = "continuous_sum"

Setting: max_total
Value: numeric
Default: 100
Required if choice_type = "continuous_sum"
Description: Expected sum of allocations per choice set
```

### 4.4 Market Simulator for Continuous Sum

**Different Interpretation:**
- Instead of market share (0-100%)
- Show expected allocation (e.g., "of next 10 purchases")
- Formula is same (utility-based), but interpretation differs

```r
create_simulator_continuous_sum <- function(wb, results, config) {
  
  # Similar structure to standard simulator
  # But change labels:
  # - "Market Share" → "Expected Allocation"
  # - "% of Market" → "% of Purchases"
  
  # Instructions emphasize:
  # "This shows how respondents would allocate their next X purchases"
  # "Not mutually exclusive - represents purchase frequency"
}
```

## 5. Unified Detection Logic

### 5.1 Auto-Detect Choice Type

```r
detect_choice_type <- function(data, config) {
  
  # Check 1: User specified in config?
  if (!is.null(config$settings$choice_type)) {
    return(list(
      choice_type = config$settings$choice_type,
      confidence = "user_specified"
    ))
  }
  
  # Check 2: Look for column patterns
  col_names <- tolower(names(data))
  
  # Best vs. Worst: has both "best" and "worst" columns
  has_best <- any(grepl("best", col_names))
  has_worst <- any(grepl("worst", col_names))
  
  if (has_best && has_worst) {
    return(list(
      choice_type = "best_worst",
      confidence = "high",
      detected_columns = list(
        best = names(data)[grepl("best", col_names)][1],
        worst = names(data)[grepl("worst", col_names)][1]
      )
    ))
  }
  
  # Continuous Sum: has "allocation" or numeric DV that sums to constant
  has_allocation <- any(grepl("allocation|points|chips", col_names))
  
  if (has_allocation) {
    return(list(
      choice_type = "continuous_sum",
      confidence = "high",
      detected_columns = list(
        allocation = names(data)[grepl("allocation|points|chips", col_names)][1]
      )
    ))
  }
  
  # Single Choice with None: check for none option
  none_info <- detect_none_option(data, config)
  
  if (none_info$has_none) {
    return(list(
      choice_type = "single_with_none",
      confidence = "high",
      none_method = none_info$method
    ))
  }
  
  # Default: Standard single choice
  return(list(
    choice_type = "single",
    confidence = "assumed",
    note = "No special choice type detected, assuming standard CBC"
  ))
}
```

### 5.2 Validation by Choice Type

```r
validate_by_choice_type <- function(data, config) {
  
  choice_type_info <- detect_choice_type(data, config)
  choice_type <- choice_type_info$choice_type
  
  message(sprintf(
    "Detected choice type: %s (confidence: %s)",
    choice_type, choice_type_info$confidence
  ))
  
  # Route to appropriate validation
  switch(choice_type,
    "single" = validate_single_choice(data, config),
    "single_with_none" = validate_single_choice_with_none(data, config),
    "best_worst" = validate_best_worst(data, config),
    "continuous_sum" = validate_continuous_sum(data, config),
    stop("Unknown choice type: ", choice_type)
  )
}

validate_best_worst <- function(data, config) {
  
  best_col <- config$settings$best_column %||% "best"
  worst_col <- config$settings$worst_column %||% "worst"
  
  # Check columns exist
  if (!all(c(best_col, worst_col) %in% names(data))) {
    stop(sprintf(
      "[DATA] Error: Best vs. Worst requires '%s' and '%s' columns
 → Check your Alchemer export includes these columns",
      best_col, worst_col
    ))
  }
  
  # Validate: Exactly one best per set
  best_per_set <- data %>%
    group_by(!!sym(config$settings$choice_set_column)) %>%
    summarise(n_best = sum(!!sym(best_col)))
  
  if (any(best_per_set$n_best != 1)) {
    stop("[DATA] Error: Each choice set must have exactly 1 'best' selection")
  }
  
  # Validate: Exactly one worst per set
  worst_per_set <- data %>%
    group_by(!!sym(config$settings$choice_set_column)) %>%
    summarise(n_worst = sum(!!sym(worst_col)))
  
  if (any(worst_per_set$n_worst != 1)) {
    stop("[DATA] Error: Each choice set must have exactly 1 'worst' selection")
  }
  
  # Validate: Best and worst not same alternative
  same_best_worst <- data %>%
    filter(!!sym(best_col) == 1 & !!sym(worst_col) == 1)
  
  if (nrow(same_best_worst) > 0) {
    stop("[DATA] Error: Same alternative cannot be both best and worst")
  }
  
  TRUE
}

validate_continuous_sum <- function(data, config) {
  
  allocation_col <- config$settings$allocation_column %||% "allocation"
  max_total <- config$settings$max_total %||% 100
  
  # Check column exists
  if (!allocation_col %in% names(data)) {
    stop(sprintf(
      "[DATA] Error: Continuous Sum requires '%s' column",
      allocation_col
    ))
  }
  
  # Validate: Allocations sum to max_total (within tolerance)
  sums_per_set <- data %>%
    group_by(!!sym(config$settings$choice_set_column)) %>%
    summarise(total = sum(!!sym(allocation_col)))
  
  tolerance <- max_total * 0.01  # 1% tolerance
  
  bad_sums <- sums_per_set %>%
    filter(abs(total - max_total) > tolerance)
  
  if (nrow(bad_sums) > 0) {
    warning(sprintf(
      "[DATA] Warning: %d choice sets don't sum to max_total (%.0f)
 → Example: Choice set %s sums to %.0f",
      nrow(bad_sums),
      max_total,
      bad_sums[[config$settings$choice_set_column]][1],
      bad_sums$total[1]
    ))
  }
  
  # Validate: All allocations non-negative
  if (any(data[[allocation_col]] < 0)) {
    stop("[DATA] Error: Allocations must be non-negative")
  }
  
  TRUE
}
```

## 6. Configuration Updates

### 6.1 Enhanced Settings Sheet

```xlsx
Setting                 | Value           | Type    | Required | Phase
------------------------|-----------------|---------|----------|-------
choice_type             | single          | string  | No       | 1
none_as_baseline        | FALSE           | logical | No       | 1
none_label              | "None"          | string  | No       | 1
best_column             | "best"          | string  | If BvW   | 2
worst_column            | "worst"         | string  | If BvW   | 2
best_worst_method       | scored_ols      | string  | If BvW   | 2
allocation_column       | "allocation"    | string  | If CS    | 2
max_total               | 100             | numeric | If CS    | 2
```

**Valid Values:**
- `choice_type`: "single" | "single_with_none" | "best_worst" | "continuous_sum"
- `best_worst_method`: "scored_ols" | "exploded_logit" | "choicemodelr"

### 6.2 Example Configurations

**Standard CBC:**
```xlsx
Setting: choice_type
Value: single
```

**CBC with None:**
```xlsx
Setting: choice_type
Value: single_with_none

Setting: none_as_baseline
Value: TRUE

Setting: none_label
Value: "None of these"
```

**Best vs. Worst:**
```xlsx
Setting: choice_type
Value: best_worst

Setting: best_column
Value: best

Setting: worst_column
Value: worst

Setting: best_worst_method
Value: scored_ols
```

**Continuous Sum:**
```xlsx
Setting: choice_type
Value: continuous_sum

Setting: allocation_column
Value: allocation

Setting: max_total
Value: 100
```

## 7. Testing Requirements

### 7.1 Phase 1 Tests (None Option)

```r
# Test 1: None as explicit row
test_that("None option handled when explicit row", {
  data <- create_test_data_with_none_row()
  config <- create_test_config()
  
  result <- handle_none_option(data, config)
  
  expect_true(result$has_none)
  expect_equal(result$none_handling, "explicit_none_rows")
  expect_gt(result$n_none_chosen, 0)
})

# Test 2: None as implicit (all unchosen)
test_that("None option handled when implicit", {
  data <- create_test_data_all_unchosen()
  config <- create_test_config()
  
  result <- handle_none_option(data, config)
  
  expect_true(result$has_none)
  expect_equal(result$none_handling, "implicit_none_added")
})

# Test 3: Estimation with none
test_that("Model estimates with none option", {
  data <- create_test_data_with_none_row()
  config <- create_test_config()
  
  results <- run_conjoint_analysis(
    data = data,
    config = config
  )
  
  expect_true("none_diagnostics" %in% names(results))
  expect_true(any(results$utilities$is_none_alternative))
})

# Test 4: Market simulator with none
test_that("Market simulator includes none toggle", {
  results <- run_conjoint_with_none()
  
  wb <- loadWorkbook(results$output_file)
  sim_data <- readWorkbook(wb, "Market Simulator")
  
  # Check for none toggle at H9
  expect_equal(sim_data$H8, "Include 'None' Option?")
})
```

### 7.2 Phase 2 Tests (Best vs. Worst)

```r
# Test stub for Phase 2
test_that("Best vs. Worst not yet implemented", {
  data <- create_best_worst_data()
  config <- create_config_best_worst()
  
  expect_error(
    run_conjoint_analysis(data, config),
    "Phase 2 feature"
  )
})

# When Phase 2 implemented:
test_that("Best vs. Worst estimation works", {
  data <- create_best_worst_data()
  config <- create_config_best_worst()
  
  results <- run_conjoint_analysis(data, config)
  
  expect_equal(results$method, "best_worst")
  expect_true(!is.null(results$utilities))
})
```

### 7.3 Phase 2 Tests (Continuous Sum)

```r
# Test stub for Phase 2
test_that("Continuous Sum not yet implemented", {
  data <- create_continuous_sum_data()
  config <- create_config_continuous_sum()
  
  expect_error(
    run_conjoint_analysis(data, config),
    "Phase 2 feature"
  )
})

# When Phase 2 implemented:
test_that("Continuous Sum estimation works", {
  data <- create_continuous_sum_data()
  config <- create_config_continuous_sum()
  
  results <- run_conjoint_analysis(data, config)
  
  expect_equal(results$method, "continuous_sum")
  expect_true(!is.null(results$utilities))
})
```

## 8. Documentation Updates

### 8.1 User Guide Section: Choice Types

```markdown
# Supported Choice Types

## Single Choice (Standard CBC)
Most common format. Respondents select one preferred alternative per choice set.

**When to use:** Standard conjoint studies

**Data format:** One row per alternative, binary `chosen` column

**Example:** Smartphone preference study

## Single Choice with None
Same as Single Choice, but includes "none of these" option.

**When to use:** When opting out is realistic (e.g., not all choice sets force purchase)

**Data format:** Either explicit "none" row OR all alternatives unchosen

**Example:** Restaurant selection (can choose not to eat out)

## Best vs. Worst (Phase 2)
Respondents select both best AND worst alternative per choice set.

**When to use:** When you want more information per task, similar to MaxDiff

**Data format:** Separate `best` and `worst` columns

**Example:** Ranking product features

## Continuous Sum (Phase 2)
Respondents allocate points/chips across alternatives.

**When to use:** Representing purchase frequency or budget allocation

**Data format:** `allocation` column (sums to max_total per set)

**Example:** "Of your next 10 purchases, how many would be each brand?"
```

### 8.2 Troubleshooting Guide Updates

```markdown
## Issue: "None option not detected"

**Symptoms:** Your data has a none option but the module doesn't recognize it

**Solutions:**
1. Check none is labeled consistently (e.g., "None", "NONE", "none of these")
2. Verify choice sets with none selected have no other alternatives chosen
3. Set `choice_type = "single_with_none"` explicitly in config

## Issue: "Phase 2 feature not available"

**Symptoms:** Error message about Best vs. Worst or Continuous Sum

**Solutions:**
1. This feature is coming in Phase 2
2. Use Alchemer's built-in analysis for now
3. Contact support for Phase 2 timeline
4. Consider converting to standard CBC format if possible
```

## 9. Migration Path

### 9.1 From Phase 1 to Phase 2

**When Phase 2 is implemented:**

1. **No breaking changes** - Phase 1 functionality remains identical
2. **Opt-in features** - Phase 2 features activated by `choice_type` setting
3. **Backward compatible** - Old configs continue to work

**Implementation checklist:**
- [ ] Implement `estimate_best_worst_conjoint()`
- [ ] Implement `estimate_continuous_sum_conjoint()`
- [ ] Add ChoiceModelR integration
- [ ] Update validation functions
- [ ] Add Phase 2 tests
- [ ] Update documentation
- [ ] Create example datasets for each type
- [ ] Test migration of Phase 1 configs

### 9.2 Feature Flags

```r
# In 00_main.R

PHASE_2_ENABLED <- FALSE  # Toggle for Phase 2 features

check_feature_availability <- function(feature) {
  
  phase_2_features <- c("best_worst", "continuous_sum", "choicemodelr")
  
  if (feature %in% phase_2_features && !PHASE_2_ENABLED) {
    stop(sprintf(
      "[FEATURE] '%s' is a Phase 2 feature
 → Not yet implemented
 → Use Alchemer's built-in analysis for now
 → Or set PHASE_2_ENABLED = TRUE if you're testing",
      feature
    ))
  }
  
  TRUE
}
```

## 10. Summary

### Phase 1 Deliverables (Current)

✅ **Single Choice**
- Standard CBC format
- Fully implemented
- Production ready

✅ **Single Choice with None**
- Auto-detection of none option
- Explicit and implicit none handling
- Market simulator integration
- ~4-6 hours implementation time

### Phase 2 Deliverables (Future)

⚠️ **Best vs. Worst**
- Data validation stubs in place
- Scored OLS method specified
- Alternative exploded logit method specified
- ~2-3 weeks implementation time

⚠️ **Continuous Sum**
- Data validation stubs in place
- Share-based OLS method specified
- ~1-2 weeks implementation time

⚠️ **ChoiceModelR Integration**
- Hierarchical Bayes estimation
- Individual-level utilities
- Required for advanced Phase 2 features
- ~3-4 weeks implementation time

### Implementation Priority

**Now (Phase 1):**
1. Standard Single Choice (done per previous specs)
2. None option detection and handling (+4-6 hours)

**Later (Phase 2):**
3. Best vs. Worst (when needed)
4. Continuous Sum (when needed)
5. ChoiceModelR (when HB needed)

---

**See Part 1 for Core Technical Specification**
**See Part 2 for Configuration, Testing & Validation details**
**See Part 3 for Excel Output & Market Simulator specifications**
