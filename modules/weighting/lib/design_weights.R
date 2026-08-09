# ==============================================================================
# WEIGHTING MODULE - DESIGN WEIGHT CALCULATION
# ==============================================================================
# Calculate design weights for stratified samples
# Part of TURAS Weighting Module v3.0
#
# METHODOLOGY:
# Design weights adjust for unequal selection probabilities in stratified samples.
# For each stratum: weight = population_size / sample_size
#
# USE CASES:
# - Customer lists with known segment sizes
# - Employee surveys with departmental stratification
# - Stratified random samples with known population counts
# ==============================================================================

#' Calculate Design Weights
#'
#' Calculates design weights for a stratified sample based on population sizes.
#'
#' @param data Data frame, survey data
#' @param stratum_variable Character, column name for stratification variable
#' @param population_sizes Named vector, stratum category -> population count
#' @param verbose Logical, print progress messages (default: FALSE)
#' @return Numeric vector of weights (length = nrow(data))
#' @export
#'
#' @examples
#' pop_sizes <- c("Small" = 2000, "Medium" = 500, "Large" = 100)
#' weights <- calculate_design_weights(data, "customer_size", pop_sizes)
calculate_design_weights <- function(data,
                                     stratum_variable,
                                     population_sizes,
                                     allow_unmatched = FALSE,
                                     allow_empty_targets = FALSE,
                                     verbose = FALSE) {

  # Validate inputs
  if (!is.data.frame(data) || nrow(data) == 0) {
    weighting_refuse(
      code = "DATA_INVALID_INPUT",
      title = "Invalid Input Data",
      problem = "data must be a non-empty data frame",
      why_it_matters = "Design weights cannot be calculated without valid survey data",
      how_to_fix = "Provide a data frame with at least one row of survey data"
    )
  }

  if (!stratum_variable %in% names(data)) {
    weighting_refuse(
      code = "CFG_INVALID_COLUMN",
      title = "Stratum Variable Not Found",
      problem = sprintf("Stratum variable '%s' not found in data", stratum_variable),
      why_it_matters = "Design weights require a valid stratification column to group observations",
      how_to_fix = sprintf("Use one of these available columns: %s", paste(head(names(data), 15), collapse = ", "))
    )
  }

  if (!is.numeric(population_sizes) || is.null(names(population_sizes))) {
    weighting_refuse(
      code = "CFG_INVALID_POPULATION_SIZES",
      title = "Invalid Population Sizes Format",
      problem = "population_sizes must be a named numeric vector",
      why_it_matters = "Population sizes must map stratum categories to their counts for weight calculation",
      how_to_fix = "Provide a named numeric vector like c('Category1' = 1000, 'Category2' = 500)"
    )
  }

  if (verbose) {
    message("\nCalculating design weights...")
    message("  Stratum variable: ", stratum_variable)
    message("  Number of strata: ", length(population_sizes))
  }

  # Get stratum values from data. Both sides are trimmed before matching: a
  # leading space in an Excel target cell is invisible on screen and used to
  # send every respondent in that stratum to an NA weight. Case is still
  # respected, because two spellings that differ in case are two answers.
  stratum_values <- trimws(as.character(data[[stratum_variable]]))
  names(population_sizes) <- trimws(names(population_sizes))

  # Initialize weight vector
  weights <- rep(NA_real_, nrow(data))

  # Track issues
  unmatched_categories <- character(0)
  zero_sample_strata <- character(0)

  # Calculate weights for each stratum
  for (stratum_cat in names(population_sizes)) {
    pop_size <- population_sizes[stratum_cat]

    # Find rows in this stratum
    in_stratum <- stratum_values == stratum_cat & !is.na(stratum_values)
    sample_size <- sum(in_stratum)

    if (sample_size == 0) {
      zero_sample_strata <- c(zero_sample_strata, stratum_cat)
      next
    }

    # Calculate weight: population / sample
    weight <- pop_size / sample_size

    if (verbose) {
      message(sprintf(
        "    %s: pop=%d, sample=%d, weight=%.4f",
        stratum_cat, pop_size, sample_size, weight
      ))
    }

    weights[in_stratum] <- weight
  }

  # An NA weight is not a small problem. The lookup file this run produces exists
  # to be merged back into the survey data, and a respondent with an NA weight
  # drops out of every weighted base, percentage and significance test in tabs
  # without appearing anywhere as a missing case. Rim weighting already refuses
  # rather than emit one; design weighting warned and emitted, so the deflated
  # base reached the report unannounced. Two ways in, counted separately.
  unmatched <- is.na(weights) & !is.na(stratum_values)
  n_unmatched <- sum(unmatched)
  unmatched_cats <- if (n_unmatched > 0) unique(stratum_values[unmatched]) else character(0)

  n_na_stratum <- sum(is.na(stratum_values))
  n_unweighted <- n_unmatched + n_na_stratum

  # Two different problems, two different remedies. A respondent with no weight
  # is the respondent side (allow_unmatched); a stratum with a population and no
  # respondents is the population side (allow_empty_targets). They were one
  # setting, so an analyst excluding a handful of missing values also switched
  # off the empty-stratum guard without being asked.
  population_total <- sum(population_sizes)
  population_covered <- sum(population_sizes[setdiff(names(population_sizes),
                                                     zero_sample_strata)])

  problems <- character(0)
  blocking <- character(0)

  if (n_unmatched > 0) {
    problems <- c(problems, sprintf(
      "%d row%s (%.1f%%) are in strata with no population target: %s",
      n_unmatched, if (n_unmatched == 1) "" else "s",
      100 * n_unmatched / nrow(data),
      paste(sprintf("'%s'", head(unmatched_cats, 10)), collapse = ", ")
    ))
  }
  if (n_na_stratum > 0) {
    problems <- c(problems, sprintf(
      "%d row%s (%.1f%%) have a missing value in '%s'",
      n_na_stratum, if (n_na_stratum == 1) "" else "s",
      100 * n_na_stratum / nrow(data), stratum_variable
    ))
  }
  if (n_unweighted > 0 && !isTRUE(allow_unmatched)) {
    blocking <- c(blocking, "allow_unmatched")
  }

  if (length(zero_sample_strata) > 0) {
    problems <- c(problems, sprintf(
      "%d stratum/strata have a population target but nobody in the sample, so %s of %s people (%.1f%%) have no one to represent them: %s",
      length(zero_sample_strata),
      format(population_total - population_covered, big.mark = ",", scientific = FALSE),
      format(population_total, big.mark = ",", scientific = FALSE),
      100 * (population_total - population_covered) / population_total,
      paste(sprintf("'%s'", zero_sample_strata), collapse = ", ")
    ))
    if (!isTRUE(allow_empty_targets)) blocking <- c(blocking, "allow_empty_targets")
  }

  if (length(blocking) > 0) {
    weighting_refuse(
      code = "DATA_UNWEIGHTED_ROWS",
      title = "This design weight cannot be calculated as specified",
      problem = paste(problems, collapse = "; "),
      why_it_matters = "A respondent with an NA weight disappears from every weighted base, percentage and significance test downstream, without being reported as a missing case — the base simply comes out smaller than the sample. A stratum with a population target but no respondents is the mirror image: that share of the population has nobody to carry it.",
      how_to_fix = sprintf(
        "Best: add the missing categories to Design_Targets for this weight, fix the category spellings so they match the data (matching ignores surrounding spaces but is case-sensitive), and check '%s' for missing values. Otherwise set %s in Advanced_Settings. allow_unmatched leaves those respondents' weights blank and reports the count; allow_empty_targets proceeds on the strata that do have respondents — with grossing = N their populations are absorbed proportionally by the rest, and with grossing = Y the grossed total comes out short by the missing strata.",
        stratum_variable,
        paste(sprintf("%s = YES", blocking), collapse = " and ")
      )
    )
  }

  if (length(problems) > 0) {
    # Opted in: the rows still get no weight, but nobody can say they were not
    # told which ones, how many, or what it did to the base.
    sum_raw <- sum(weights[!is.na(weights)])
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Context: Weighting - design weights\n")
    cat("│ Code: DATA_UNWEIGHTED_ROWS_ALLOWED\n")
    for (p in problems) cat(sprintf("│   - %s\n", p))
    cat("│\n")
    cat(sprintf("│ %d of %d respondents carry a weight, grossing to %s people\n",
                nrow(data) - n_unweighted, nrow(data),
                format(round(sum_raw), big.mark = ",", scientific = FALSE)))
    cat(sprintf("│ against a stated population of %s.\n",
                format(population_total, big.mark = ",", scientific = FALSE)))
    cat("│ How to fix: this is deliberate. Remove the opt-in to make it\n")
    cat("│ a refusal again.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
  }

  if (verbose) {
    n_valid <- sum(!is.na(weights) & weights > 0)
    message("  Weights assigned: ", n_valid, " of ", nrow(data), " rows")
  }

  # Carried for diagnostics. Stripped by the config wrapper before the vector is
  # attached to the data, so nothing leaks into the lookup file.
  attr(weights, "n_unweighted") <- n_unweighted
  attr(weights, "unmatched_categories") <- unmatched_cats
  attr(weights, "zero_sample_strata") <- zero_sample_strata
  attr(weights, "population_total") <- population_total
  attr(weights, "population_covered") <- population_covered

  return(weights)
}

#' Calculate Design Weights from Config
#'
#' Wrapper function that uses configuration objects to calculate design weights.
#'
#' @param data Data frame, survey data
#' @param config List, full configuration object
#' @param weight_name Character, name of the weight to calculate
#' @param verbose Logical, print progress messages
#' @return List with $weights, $validation, $stratum_summary
#' @export
calculate_design_weights_from_config <- function(data, config, weight_name, verbose = FALSE) {

  # Get design targets for this weight
  targets <- get_design_targets(config, weight_name)

  if (is.null(targets) || nrow(targets) == 0) {
    weighting_refuse(
      code = "CFG_MISSING_TARGETS",
      title = "No Design Targets Found",
      problem = sprintf("No design targets found for weight '%s'", weight_name),
      why_it_matters = "Design weights require population targets to calculate stratum weights",
      how_to_fix = sprintf("Add design targets for '%s' in the configuration file", weight_name)
    )
  }

  # Validate configuration against data
  validation <- validate_design_config(data, targets, weight_name)

  if (!validation$valid) {
    weighting_refuse(
      code = "CFG_VALIDATION_FAILED",
      title = "Design Weight Configuration Invalid",
      problem = sprintf("Configuration validation failed for weight '%s'", weight_name),
      why_it_matters = "Invalid configuration prevents correct weight calculation",
      how_to_fix = paste(validation$errors, collapse = "; ")
    )
  }

  if (length(validation$warnings) > 0) {
    for (w in validation$warnings) {
      warning(w, call. = FALSE)
    }
  }

  # Get stratum variable (should be unique per weight)
  stratum_variable <- unique(targets$stratum_variable)[1]

  # Build population sizes named vector
  population_sizes <- setNames(
    as.numeric(targets$population_size),
    as.character(targets$stratum_category)
  )

  # An NA weight silently deflates every weighted base downstream, so it is a
  # refusal unless the config author has said otherwise in Advanced_Settings.
  allow_unmatched <- read_allow_unmatched_setting(config, weight_name)
  allow_empty_targets <- read_allow_empty_targets_setting(config, weight_name)

  # Calculate weights
  weights <- calculate_design_weights(
    data = data,
    stratum_variable = stratum_variable,
    population_sizes = population_sizes,
    allow_unmatched = allow_unmatched,
    allow_empty_targets = allow_empty_targets,
    verbose = verbose
  )

  # Read the counts off, then strip them: the vector is attached to the data as
  # a column and written to the lookup file, and attributes have no business
  # travelling with it.
  n_unweighted <- attr(weights, "n_unweighted") %||% 0
  unmatched_categories <- attr(weights, "unmatched_categories") %||% character(0)
  zero_sample_strata <- attr(weights, "zero_sample_strata") %||% character(0)
  population_total_stated <- attr(weights, "population_total") %||% NA_real_
  population_covered <- attr(weights, "population_covered") %||% NA_real_
  attributes(weights) <- NULL

  # A raw design weight is population / sample, so it arrives at population
  # scale — mean 20 on a 1-in-20 sample. Rim weights calibrate to sum ≈ n. Both
  # were being written into the same lookup file, so two weights on one study
  # could put weighted bases three orders of magnitude apart with nothing saying
  # which scale a column was on. Kish n_eff is scale-invariant, so significance
  # testing is unaffected either way; what moves is every weighted N on the face
  # of the report.
  #
  # Default is therefore to normalise to sum = n, matching rim. Grossing = YES
  # keeps population scale for anyone who wants grossed-up counts, and says so
  # in the diagnostics rather than leaving the reader to infer it.
  grossing <- read_grossing_setting(config, weight_name)
  population_scale_sum <- sum(weights[!is.na(weights)])

  if (!grossing) {
    weights <- normalize_design_weights(weights)
  }

  weight_scale <- if (grossing) "population" else "sample"

  # The scale factor the weight vector actually went through. The summary table
  # below has to travel on the same scale as the weights: it was reporting
  # population/sample while the lookup file carried the normalised column, so
  # the module's own report and its deliverable disagreed by three orders of
  # magnitude with nothing saying which was which.
  scale_factor <- if (grossing || population_scale_sum == 0) {
    1
  } else {
    sum(weights[!is.na(weights)]) / population_scale_sum
  }

  # Build stratum summary
  stratum_values <- trimws(as.character(data[[stratum_variable]]))
  stratum_summary <- data.frame(
    stratum = character(0),
    population_size = numeric(0),
    sample_size = numeric(0),
    weight = numeric(0),
    weight_population_scale = numeric(0),
    stringsAsFactors = FALSE
  )

  for (cat in names(population_sizes)) {
    sample_n <- sum(stratum_values == cat, na.rm = TRUE)
    raw_wt <- if (sample_n > 0) population_sizes[cat] / sample_n else NA_real_

    stratum_summary <- rbind(stratum_summary, data.frame(
      stratum = cat,
      population_size = population_sizes[cat],
      sample_size = sample_n,
      # As applied — this is what is in the lookup file.
      weight = raw_wt * scale_factor,
      # As calculated, before normalisation. Kept so a reader can still see the
      # population/sample arithmetic the weight came from.
      weight_population_scale = raw_wt,
      stringsAsFactors = FALSE
    ))
  }

  # Validate calculated weights. A normalised design weight sums to the number
  # of respondents carrying one; a grossed one sums to the population it covers,
  # and there is nothing independent to check that against, so no expectation is
  # asserted in that case.
  n_carrying <- sum(!is.na(weights))
  weight_validation <- validate_calculated_weights(
    weights, weight_name,
    expected_sum = if (grossing) NULL else n_carrying,
    population_scale = grossing
  )

  if (verbose || grossing) {
    cat(sprintf(
      "\n  [%s] weight scale: %s — the column sums to %s across %d respondents%s\n",
      weight_name, weight_scale,
      format(round(sum(weights[!is.na(weights)]), 2), big.mark = ",", scientific = FALSE),
      n_carrying,
      if (grossing) sprintf(" (stated population %s)",
                            format(population_total_stated, big.mark = ",", scientific = FALSE)) else ""
    ))
  }

  return(list(
    weights = weights,
    validation = weight_validation,
    stratum_summary = stratum_summary,
    stratum_variable = stratum_variable,
    # Zero unless allow_unmatched was set — otherwise the run would have refused.
    n_unweighted = n_unweighted,
    unmatched_categories = unmatched_categories,
    zero_sample_strata = zero_sample_strata,
    allow_unmatched = allow_unmatched,
    allow_empty_targets = allow_empty_targets,
    population_stated = population_total_stated,
    population_covered = population_covered,
    # Which scale the weights are on, and what the un-normalised total was, so
    # the report can say "these sum to n" or "these gross to 47.2m" on its face.
    weight_scale = weight_scale,
    grossing = grossing,
    population_total = population_scale_sum,
    sum_weights = sum(weights[!is.na(weights)])
  ))
}

#' Print Design Weight Summary
#'
#' Prints a formatted summary of design weight calculation.
#'
#' @param result List, result from calculate_design_weights_from_config
#' @param weight_name Character, name of the weight
#' @export
print_design_summary <- function(result, weight_name) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("DESIGN WEIGHT SUMMARY: ", weight_name, "\n")
  cat(strrep("=", 70), "\n")
  cat("\nMethod: Design Weights (Stratified Sample)\n")
  cat("Stratum Variable: ", result$stratum_variable, "\n")
  if (!is.null(result$weight_scale)) {
    cat("Scale: ", result$weight_scale,
        if (identical(result$weight_scale, "sample")) " (weights sum to the number of respondents)"
        else " (weights gross to population counts)", "\n", sep = "")
  }
  cat("\nStratum Details:\n")
  cat(strrep("-", 74), "\n")
  cat(sprintf("%-20s %12s %12s %12s %14s\n",
              "Stratum", "Population", "Sample", "Weight", "Pop/Sample"))
  cat(strrep("-", 74), "\n")

  for (i in seq_len(nrow(result$stratum_summary))) {
    row <- result$stratum_summary[i, ]
    # "Weight" is what is in the lookup file. "Pop/Sample" is the arithmetic it
    # came from, before normalisation — the two are the same only when grossing.
    cat(sprintf("%-20s %12s %12d %12.4f %14.4f\n",
                row$stratum,
                format(row$population_size, big.mark = ",", scientific = FALSE),
                row$sample_size,
                row$weight,
                row$weight_population_scale %||% NA_real_))
  }

  cat(strrep("-", 74), "\n")

  # Total
  total_pop <- sum(result$stratum_summary$population_size)
  total_sample <- sum(result$stratum_summary$sample_size)
  cat(sprintf("%-20s %12s %12d\n",
              "TOTAL",
              format(total_pop, big.mark = ",", scientific = FALSE),
              total_sample))

  cat("\n")
}

#' Normalize Design Weights
#'
#' Normalize design weights to sum to sample size (mean = 1).
#' This is useful when you want relative weights rather than absolute.
#'
#' @param weights Numeric vector of design weights
#' @param target_sum Numeric, desired sum of weights (default: NULL = n valid weights)
#' @return Numeric vector of normalized weights
#' @export
normalize_design_weights <- function(weights, target_sum = NULL) {
  valid_idx <- !is.na(weights) & is.finite(weights) & weights > 0
  n_valid <- sum(valid_idx)

  if (n_valid == 0) {
    warning("No valid weights to normalize", call. = FALSE)
    return(weights)
  }

  if (is.null(target_sum)) {
    target_sum <- n_valid
  }

  current_sum <- sum(weights[valid_idx])

  if (current_sum == 0) {
    warning("Sum of weights is zero, cannot normalize", call. = FALSE)
    return(weights)
  }

  # Scale factor to achieve target sum
  scale_factor <- target_sum / current_sum

  # Apply to valid weights only
  normalized <- weights
  normalized[valid_idx] <- weights[valid_idx] * scale_factor

  return(normalized)
}

#' Calculate Grossing Weights
#'
#' Creates weights that gross up the sample to population totals.
#' Unlike normalized weights, these represent actual population counts.
#'
#' @param weights Numeric vector of design weights
#' @param population_total Numeric, total population size
#' @return Numeric vector of grossing weights
#' @export
calculate_grossing_weights <- function(weights, population_total) {
  if (!is.numeric(population_total) || population_total <= 0) {
    weighting_refuse(
      code = "DATA_INVALID_POPULATION_TOTAL",
      title = "Invalid Population Total",
      problem = "population_total must be a positive number",
      why_it_matters = "Grossing weights require a valid population total to scale sample weights",
      how_to_fix = "Provide a positive numeric value for population_total"
    )
  }

  valid_idx <- !is.na(weights) & is.finite(weights) & weights > 0
  n_valid <- sum(valid_idx)

  if (n_valid == 0) {
    warning("No valid weights to convert to grossing weights", call. = FALSE)
    return(weights)
  }

  # Design weights already represent population proportions
  # Grossing weight = design_weight * (population_total / sum_of_design_weights)

  sum_weights <- sum(weights[valid_idx])
  scale_factor <- population_total / sum_weights

  grossing <- weights
  grossing[valid_idx] <- weights[valid_idx] * scale_factor

  return(grossing)
}
