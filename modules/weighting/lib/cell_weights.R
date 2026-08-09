# ==============================================================================
# WEIGHTING MODULE - CELL/INTERLOCKED WEIGHT CALCULATION
# ==============================================================================
# Calculate weights for joint distributions (e.g., Age x Gender cells)
# Part of TURAS Weighting Module v3.0
#
# METHODOLOGY:
# Cell (interlocked) weighting adjusts for joint distributions of two or more
# variables simultaneously. Unlike rim weighting which adjusts marginal
# distributions independently, cell weighting matches the exact cross-tabulation.
#
# For each cell: weight = (target_proportion * N) / cell_count
#
# USE CASES:
# - When joint distributions are known (e.g., census cross-tabs)
# - When variable interactions matter (e.g., young males underrepresented)
# - Smaller surveys where rim weighting may not converge
# ==============================================================================

#' Calculate Cell Weights
#'
#' Calculates weights to match joint distribution targets for combinations
#' of two or more variables.
#'
#' @param data Data frame, survey data
#' @param cell_targets Data frame with columns: cell combination variables and target_percent
#' @param cell_variables Character vector, names of variables defining cells
#' @param verbose Logical, print progress messages (default: FALSE)
#' @return List with $weights, $cell_summary, $method
#' @export
calculate_cell_weights <- function(data,
                                   cell_targets,
                                   cell_variables,
                                   allow_unmatched = FALSE,
                                   allow_empty_targets = FALSE,
                                   verbose = FALSE) {

  # Validate inputs
  if (!is.data.frame(data) || nrow(data) == 0) {
    weighting_refuse(
      code = "DATA_INVALID_INPUT",
      title = "Invalid Input Data",
      problem = "data must be a non-empty data frame",
      why_it_matters = "Cell weights cannot be calculated without valid survey data",
      how_to_fix = "Provide a data frame with at least one row of survey data"
    )
  }

  if (!is.data.frame(cell_targets) || nrow(cell_targets) == 0) {
    weighting_refuse(
      code = "CFG_INVALID_TARGETS",
      title = "Invalid Cell Targets",
      problem = "cell_targets must be a non-empty data frame",
      why_it_matters = "Cell weighting requires target proportions for each cell combination",
      how_to_fix = "Provide a data frame with cell variable columns and a target_percent column"
    )
  }

  # Check all cell variables exist in data
  missing_vars <- setdiff(cell_variables, names(data))
  if (length(missing_vars) > 0) {
    weighting_refuse(
      code = "CFG_MISSING_VARS",
      title = "Cell Variables Not Found",
      problem = sprintf("Cell variables not found in data: %s", paste(missing_vars, collapse = ", ")),
      why_it_matters = "All cell variables must exist in the data for interlocked weighting",
      how_to_fix = sprintf("Available columns: %s", paste(head(names(data), 20), collapse = ", "))
    )
  }

  # Validate target_percent column exists
  if (!"target_percent" %in% names(cell_targets)) {
    weighting_refuse(
      code = "CFG_MISSING_COLUMNS",
      title = "Missing target_percent Column",
      problem = "cell_targets must have a 'target_percent' column",
      why_it_matters = "Target percentages define the desired joint distribution",
      how_to_fix = "Add a 'target_percent' column to your cell targets table"
    )
  }

  # Validate all cell variable columns exist in targets
  missing_target_vars <- setdiff(cell_variables, names(cell_targets))
  if (length(missing_target_vars) > 0) {
    weighting_refuse(
      code = "CFG_MISSING_COLUMNS",
      title = "Cell Variables Missing From Targets",
      problem = sprintf("Cell variables not in targets table: %s", paste(missing_target_vars, collapse = ", ")),
      why_it_matters = "Each cell variable must appear as a column in the cell targets table",
      how_to_fix = "Ensure your cell targets table has columns for each cell variable"
    )
  }

  # A missing or negative target has to be caught before the sum check, which
  # uses na.rm = TRUE and would otherwise let an NA row through as long as the
  # remaining rows happened to reach 100.
  #
  # A target of exactly 0 is not caught here. In a real interlocked design
  # against a census table, a sparse cell rounding to 0.0% is ordinary, and
  # refusing it blocks a legitimate study. What matters is not the zero but
  # whether anybody is standing in that cell: an empty zero-share cell costs the
  # weighting nothing, while a zero target with respondents in it would hand
  # them a weight of zero and remove them from every base without their
  # appearing as missing. That second case is an unweighted respondent, and it
  # is handled with the other unweighted respondents below.
  bad_targets <- is.na(cell_targets$target_percent) | cell_targets$target_percent < 0
  if (any(bad_targets)) {
    cell_label <- function(i) {
      paste(sprintf("%s=%s", cell_variables,
                    vapply(cell_variables, function(v) as.character(cell_targets[[v]][i]),
                           character(1))),
            collapse = ", ")
    }
    weighting_refuse(
      code = "CFG_INVALID_TARGET_VALUE",
      title = "A cell target is missing or negative",
      problem = sprintf("These cells have a target_percent that is not a number of at least zero: %s",
                        paste(vapply(which(bad_targets),
                                     function(i) sprintf("%s (%s)", cell_label(i),
                                                         as.character(cell_targets$target_percent[i])),
                                     character(1)),
                              collapse = "; ")),
      why_it_matters = "A negative or missing target cannot describe a share of a population, so there is no distribution to weight towards.",
      how_to_fix = "Give every cell a target_percent of zero or more. A cell with a genuine zero share is allowed; if respondents are standing in it, either give it its real share or collapse them into a neighbouring cell."
    )
  }

  # Validate target percentages sum to ~100
  total_pct <- sum(cell_targets$target_percent, na.rm = TRUE)
  if (abs(total_pct - 100) > RIM_TARGET_SUM_TOLERANCE) {
    weighting_refuse(
      code = "CFG_TARGET_SUM_ERROR",
      title = "Cell Target Percentages Do Not Sum to 100",
      problem = sprintf("Cell target percentages sum to %.2f%%, expected 100%%", total_pct),
      why_it_matters = "Target percentages must represent a complete distribution",
      how_to_fix = sprintf("Adjust target_percent values so they sum to 100. Current sum: %.2f", total_pct)
    )
  }

  if (verbose) {
    message("\nCalculating cell weights (interlocked)...")
    message("  Variables: ", paste(cell_variables, collapse = " x "))
    message("  Number of cells: ", nrow(cell_targets))
  }

  n <- nrow(data)

  # Convert data columns to character for matching, trimming both sides. A
  # leading space in an Excel target cell is invisible on screen and used to
  # route every respondent in that cell to "undefined cell". Case is still
  # respected, because two spellings that differ in case are two answers.
  for (var in cell_variables) {
    data[[var]] <- trimws(as.character(data[[var]]))
    cell_targets[[var]] <- trimws(as.character(cell_targets[[var]]))
  }

  # Missing data has to be found BEFORE the key is built. paste() turns NA into
  # the three characters "NA", so a respondent with a missing age used to be
  # routed to an "undefined cell" and reported as an unmatched category — the
  # one problem disguised as a different one. Find them first, and keep the rows
  # out of key matching entirely.
  na_in_variable <- vapply(cell_variables, function(v) sum(is.na(data[[v]])),
                           numeric(1))
  names(na_in_variable) <- cell_variables
  has_na <- Reduce(`|`, lapply(cell_variables, function(v) is.na(data[[v]])))
  n_na_rows <- sum(has_na)

  # Cell keys are built by pasting the category values together, so the
  # separator must be a character no survey category can contain. "|" can and
  # does appear in category labels ("Yes|No", multi-select exports), and when it
  # does two different cells collide into one key and their weights merge. The
  # ASCII unit separator cannot appear in an Excel cell.
  KEY_SEP <- "\x1F"

  contains_sep <- function(df, vars) {
    hits <- character(0)
    for (v in vars) {
      vals <- unique(df[[v]])
      bad <- vals[!is.na(vals) & grepl(KEY_SEP, vals, fixed = TRUE)]
      if (length(bad) > 0) hits <- c(hits, sprintf("%s: %s", v, paste(bad, collapse = ", ")))
    }
    hits
  }

  sep_hits <- c(contains_sep(data, cell_variables),
                contains_sep(cell_targets, cell_variables))
  if (length(sep_hits) > 0) {
    weighting_refuse(
      code = "DATA_KEY_SEPARATOR_IN_VALUE",
      title = "A category value contains the cell key separator",
      problem = sprintf("These values contain the ASCII unit separator used to build cell keys: %s",
                        paste(sep_hits, collapse = "; ")),
      why_it_matters = "Cell keys are built by joining the category values with that separator. A value containing it can collide with a different combination of categories, merging two cells and their weights.",
      how_to_fix = "Remove the control character from those category values in the data and in Cell_Targets."
    )
  }

  build_keys <- function(df) {
    do.call(paste, c(df[, cell_variables, drop = FALSE], sep = KEY_SEP))
  }

  # Create cell key for each row in data
  data_keys <- build_keys(data)
  data_keys[has_na] <- NA_character_

  # Create cell key for each target row
  target_keys <- build_keys(cell_targets)

  pretty_key <- function(k) gsub(KEY_SEP, " x ", k, fixed = TRUE)

  # ---------------------------------------------------------------------------
  # Pass 1: count the sample in every target cell, and sort the problems into
  # the two kinds they actually are.
  #
  # Respondent side — somebody would carry no weight: a missing value in a cell
  # variable, a cell with no target at all, or a cell whose target is zero.
  # Population side — a share of the population has nobody to carry it: a target
  # cell with a share above zero and no respondents in it.
  #
  # These used to be one opt-in. They are two problems with two different
  # remedies, and an analyst excluding three people with a missing age should not
  # have to switch off the empty-target guard to do it.
  # ---------------------------------------------------------------------------
  cell_counts <- integer(nrow(cell_targets))
  for (i in seq_len(nrow(cell_targets))) {
    cell_counts[i] <- sum(!is.na(data_keys) & data_keys == target_keys[i])
  }

  is_empty_cell  <- cell_counts == 0 & cell_targets$target_percent > 0
  is_zero_target <- cell_targets$target_percent == 0 & cell_counts > 0
  is_usable_cell <- cell_counts > 0 & cell_targets$target_percent > 0

  empty_cells <- target_keys[is_empty_cell]
  empty_share <- sum(cell_targets$target_percent[is_empty_cell])

  zero_target_keys <- target_keys[is_zero_target]
  n_zero_target <- sum(cell_counts[is_zero_target])

  matched <- !is.na(data_keys) & data_keys %in% target_keys
  unmatched <- !is.na(data_keys) & !matched
  n_unmatched <- sum(unmatched)
  unmatched_keys <- if (n_unmatched > 0) unique(data_keys[unmatched]) else character(0)

  # Respondents who will carry a weight. The weights are calibrated to sum to
  # this rather than to nrow(data): a respondent who has been excluded should not
  # still be inflating the weighted base, and rim already works this way — it
  # calibrates to the complete cases it kept.
  n_unweighted <- n_unmatched + n_na_rows + n_zero_target
  n_base <- n - n_unweighted

  # ---------------------------------------------------------------------------
  # Pass 2: decide whether to proceed, and on what distribution.
  # ---------------------------------------------------------------------------
  problems <- character(0)
  blocking <- character(0)

  if (n_na_rows > 0) {
    per_var <- na_in_variable[na_in_variable > 0]
    problems <- c(problems, sprintf(
      "%d row%s (%.1f%%) have a missing value in a cell variable (%s)",
      n_na_rows, if (n_na_rows == 1) "" else "s", 100 * n_na_rows / n,
      paste(sprintf("%s: %d", names(per_var), per_var), collapse = ", ")
    ))
  }
  if (n_unmatched > 0) {
    problems <- c(problems, sprintf(
      "%d row%s (%.1f%%) are in cells with no target: %s",
      n_unmatched, if (n_unmatched == 1) "" else "s", 100 * n_unmatched / n,
      paste(sprintf("'%s'", pretty_key(head(unmatched_keys, 10))), collapse = ", ")
    ))
  }
  if (n_zero_target > 0) {
    problems <- c(problems, sprintf(
      "%d row%s (%.1f%%) are in cells whose target is zero, so they would weight to nothing: %s",
      n_zero_target, if (n_zero_target == 1) "" else "s", 100 * n_zero_target / n,
      paste(sprintf("'%s'", pretty_key(head(zero_target_keys, 10))), collapse = ", ")
    ))
  }
  if (n_unweighted > 0 && !isTRUE(allow_unmatched)) {
    blocking <- c(blocking, "allow_unmatched")
  }

  if (length(empty_cells) > 0) {
    problems <- c(problems, sprintf(
      "%d target cell%s have nobody in the sample, so %.1f%% of the population has no one to represent it: %s",
      length(empty_cells), if (length(empty_cells) == 1) "" else "s", empty_share,
      paste(sprintf("'%s'", pretty_key(head(empty_cells, 10))), collapse = ", ")
    ))
    if (!isTRUE(allow_empty_targets)) blocking <- c(blocking, "allow_empty_targets")
  }

  if (length(blocking) > 0) {
    weighting_refuse(
      code = "DATA_UNWEIGHTED_ROWS",
      title = "This cell weight cannot be calculated as specified",
      problem = paste(problems, collapse = "; "),
      why_it_matters = "A respondent with an NA weight disappears from every weighted base, percentage and significance test downstream without being reported as a missing case — the base simply comes out smaller than the sample. A target cell with no respondents is the mirror image: that share of the population has nobody to carry it, so the weighted totals lose it.",
      how_to_fix = paste0(
        "Best: add the missing combinations to Cell_Targets, fix the category spellings so they match the data (matching ignores surrounding spaces but is case-sensitive), collapse the sparse cells into larger ones, and check the cell variables for missing values. If empty cells are unavoidable, rim weighting does not require every combination to be populated. Otherwise set ",
        paste(sprintf("%s = YES", blocking), collapse = " and "),
        " in Advanced_Settings. allow_unmatched leaves those respondents' weights blank and reports the count; allow_empty_targets redistributes the orphaned population share across the cells that do have respondents."
      )
    )
  }

  # Nothing left to weight towards. Only reachable when every populated cell has
  # a zero target, which is a config describing no distribution at all.
  surviving_share <- sum(cell_targets$target_percent[is_usable_cell])
  if (surviving_share <= 0) {
    weighting_refuse(
      code = "CFG_NO_USABLE_TARGETS",
      title = "No cell target has both a population share and respondents",
      problem = sprintf("Of %d target cells, none has a target above zero with anybody in it.",
                        nrow(cell_targets)),
      why_it_matters = "There is no distribution left to weight towards, so no weight can be calculated.",
      how_to_fix = "Check that the cell variables and Cell_Targets describe the same categories, and that the targets are percentages rather than proportions."
    )
  }

  # The orphaned population share is redistributed across the cells that do have
  # respondents, in proportion to what they already carry. Without this the
  # opt-in produces exactly the defect the refusal exists to prevent: weights
  # summing to less than the sample, and every weighted base short with nothing
  # on its face to say why. In the ordinary case — no empty cells — the factor is
  # 1 and nothing moves.
  redistribution_factor <- 100 / surviving_share

  # ---------------------------------------------------------------------------
  # Pass 3: assign the weights.
  # ---------------------------------------------------------------------------
  weights <- rep(NA_real_, n)

  cell_summary <- data.frame(
    cell = character(0),
    target_pct = numeric(0),
    adjusted_pct = numeric(0),
    sample_count = integer(0),
    sample_pct = numeric(0),
    weight = numeric(0),
    stringsAsFactors = FALSE
  )

  for (i in which(is_usable_cell)) {
    cell_count <- cell_counts[i]
    in_cell <- !is.na(data_keys) & data_keys == target_keys[i]

    adjusted_pct <- cell_targets$target_percent[i] * redistribution_factor
    weight <- (adjusted_pct / 100 * n_base) / cell_count

    weights[in_cell] <- weight

    cell_label <- paste(
      paste0(cell_variables, "=", cell_targets[i, cell_variables]),
      collapse = ", "
    )

    cell_summary <- rbind(cell_summary, data.frame(
      cell = cell_label,
      target_pct = cell_targets$target_percent[i],
      adjusted_pct = round(adjusted_pct, 4),
      sample_count = cell_count,
      sample_pct = round(100 * cell_count / n, 2),
      weight = round(weight, 4),
      stringsAsFactors = FALSE
    ))

    if (verbose) {
      message(sprintf("    %s: target=%.1f%%, n=%d, weight=%.4f",
                      cell_label, cell_targets$target_percent[i], cell_count, weight))
    }
  }

  sum_weights <- sum(weights, na.rm = TRUE)

  # The disclosure has to lead with the number an analyst can act on: how much
  # weighted base this weight actually carries against the sample it came from.
  # Saying "0 respondents affected" and then listing a quarter of the population
  # underneath it told them nothing.
  if (length(problems) > 0) {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Context: Weighting - cell weights\n")
    cat("│ Code: DATA_UNWEIGHTED_ROWS_ALLOWED\n")
    for (p in problems) cat(sprintf("│   - %s\n", p))
    cat("│\n")
    cat(sprintf("│ %d of %d respondents carry a weight, and the weighted base\n",
                n_base, n))
    cat(sprintf("│ for this weight is %.2f.\n", sum_weights))
    if (length(empty_cells) > 0) {
      cat(sprintf("│ The orphaned %.1f%% was redistributed across the %d populated\n",
                  empty_share, sum(is_usable_cell)))
      cat(sprintf("│ cells (targets scaled by %.6f), so the base is not short —\n",
                  redistribution_factor))
      cat("│ but those cells now stand in for people the sample never\n")
      cat("│ reached. Say so wherever these numbers are quoted.\n")
    }
    cat("│ How to fix: this is deliberate. Remove the opt-in to make it\n")
    cat("│ a refusal again.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
  }

  if (verbose) {
    n_valid <- sum(!is.na(weights) & weights > 0)
    message(sprintf("  Weights assigned: %d of %d rows", n_valid, n))
    if (n_valid > 0) {
      valid_w <- weights[!is.na(weights)]
      message(sprintf("  Weight range: [%.4f, %.4f], mean=%.4f",
                      min(valid_w), max(valid_w), mean(valid_w)))
    }
  }

  return(list(
    weights = weights,
    cell_summary = cell_summary,
    cell_variables = cell_variables,
    method = "cell",
    n_cells_defined = nrow(cell_targets),
    n_cells_empty = length(empty_cells),
    n_unmatched = n_unmatched,
    # Respondents left with no weight, split by cause. Zero unless
    # allow_unmatched was set — otherwise the run would have refused.
    n_unweighted = n_unweighted,
    n_missing_cell_data = n_na_rows,
    n_zero_target_rows = n_zero_target,
    na_by_variable = na_in_variable,
    unmatched_cells = pretty_key(unmatched_keys),
    empty_cells = pretty_key(empty_cells),
    allow_unmatched = isTRUE(allow_unmatched),
    allow_empty_targets = isTRUE(allow_empty_targets),
    # What the weights actually add up to, and what they were meant to. The two
    # differ only through a bug now that empty targets are redistributed, which
    # is why the caller asserts it.
    n_base = n_base,
    sum_weights = sum_weights,
    empty_target_share = empty_share,
    redistribution_factor = redistribution_factor
  ))
}

#' Calculate Cell Weights from Config
#'
#' Wrapper function that uses configuration objects to calculate cell weights.
#'
#' @param data Data frame, survey data
#' @param config List, full configuration object
#' @param weight_name Character, name of the weight to calculate
#' @param verbose Logical, print progress messages
#' @return List with $weights, $cell_summary, $validation
#' @export
calculate_cell_weights_from_config <- function(data, config, weight_name,
                                                verbose = FALSE) {

  # Get cell targets for this weight
  cell_targets <- get_cell_targets(config, weight_name)

  if (is.null(cell_targets) || nrow(cell_targets) == 0) {
    weighting_refuse(
      code = "CFG_MISSING_TARGETS",
      title = "No Cell Targets Found",
      problem = sprintf("No cell targets found for weight '%s'", weight_name),
      why_it_matters = "Cell weighting requires joint distribution targets",
      how_to_fix = sprintf("Add cell targets for '%s' in the Cell_Targets sheet", weight_name)
    )
  }

  # Determine cell variables (all columns except weight_name and target_percent)
  cell_variables <- setdiff(names(cell_targets), c("weight_name", "target_percent"))

  if (length(cell_variables) == 0) {
    weighting_refuse(
      code = "CFG_NO_CELL_VARIABLES",
      title = "No Cell Variables Defined",
      problem = "Cell targets must include at least one variable column besides weight_name and target_percent",
      why_it_matters = "Cell weighting requires at least one variable to define cells",
      how_to_fix = "Add variable columns (e.g., Gender, Age) to the Cell_Targets sheet"
    )
  }

  # Validate cell targets against data
  validation <- validate_cell_config(data, cell_targets, weight_name, cell_variables)

  if (!validation$valid) {
    weighting_refuse(
      code = "CFG_VALIDATION_FAILED",
      title = "Cell Weight Configuration Invalid",
      problem = sprintf("Configuration validation failed for weight '%s'", weight_name),
      why_it_matters = "Invalid configuration prevents correct cell weight calculation",
      how_to_fix = paste(validation$errors, collapse = "; ")
    )
  }

  if (length(validation$warnings) > 0) {
    for (w in validation$warnings) {
      warning(w, call. = FALSE)
    }
  }

  # Calculate cell weights. An NA weight silently deflates every weighted base
  # downstream, so it is a refusal unless the config author has said otherwise.
  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = cell_variables,
    allow_unmatched = read_allow_unmatched_setting(config, weight_name),
    allow_empty_targets = read_allow_empty_targets_setting(config, weight_name),
    verbose = verbose
  )

  # Cell weights are constructed to sum to the number of respondents carrying
  # one. Asserting it here is cheap and turns any future arithmetic slip into a
  # refusal rather than a quietly wrong weighted base in tabs.
  result$validation <- validate_calculated_weights(
    result$weights, weight_name, expected_sum = result$n_base
  )

  return(result)
}

#' Validate Cell Weight Configuration
#'
#' Validates cell weight targets against the data.
#'
#' @param data Data frame, survey data
#' @param cell_targets Data frame, cell target definitions
#' @param weight_name Character, name of the weight
#' @param cell_variables Character vector, cell variable names
#' @return List with $valid, $errors, $warnings
#' @keywords internal
validate_cell_config <- function(data, cell_targets, weight_name, cell_variables) {
  errors <- character(0)
  warnings_list <- character(0)

  # Check variables exist in data
  for (var in cell_variables) {
    if (!var %in% names(data)) {
      errors <- c(errors, sprintf("Variable '%s' not found in data", var))
    }
  }

  # Check target_percent is numeric and valid
  if (any(is.na(cell_targets$target_percent))) {
    errors <- c(errors, "Some target_percent values are NA")
  }

  if (any(cell_targets$target_percent < 0, na.rm = TRUE)) {
    errors <- c(errors, "target_percent values must be non-negative")
  }

  # Check targets sum to ~100
  total_pct <- sum(cell_targets$target_percent, na.rm = TRUE)
  if (abs(total_pct - 100) > RIM_TARGET_SUM_TOLERANCE) {
    errors <- c(errors, sprintf(
      "Cell target percentages sum to %.2f%%, should be 100%% (+/- %.1f%%)",
      total_pct, RIM_TARGET_SUM_TOLERANCE
    ))
  }

  # Check for duplicate cells
  if (length(cell_variables) > 0 && all(cell_variables %in% names(cell_targets))) {
    cell_keys <- apply(cell_targets[, cell_variables, drop = FALSE], 1, paste, collapse = "|")
    if (any(duplicated(cell_keys))) {
      dup_keys <- unique(cell_keys[duplicated(cell_keys)])
      errors <- c(errors, sprintf("Duplicate cell definitions: %s", paste(dup_keys, collapse = ", ")))
    }
  }

  # Check that cell categories exist in data
  if (length(errors) == 0) {
    for (var in cell_variables) {
      if (var %in% names(data)) {
        data_vals <- unique(as.character(data[[var]]))
        target_vals <- unique(as.character(cell_targets[[var]]))
        missing <- setdiff(target_vals, data_vals)
        if (length(missing) > 0) {
          warnings_list <- c(warnings_list, sprintf(
            "Variable '%s': target categories not in data: %s",
            var, paste(missing, collapse = ", ")
          ))
        }
      }
    }
  }

  # Warn about small cell sizes
  if (length(errors) == 0 && all(cell_variables %in% names(data))) {
    for (var in cell_variables) {
      data[[var]] <- as.character(data[[var]])
      cell_targets[[var]] <- as.character(cell_targets[[var]])
    }

    data_keys <- apply(data[, cell_variables, drop = FALSE], 1, paste, collapse = "|")
    target_keys <- apply(cell_targets[, cell_variables, drop = FALSE], 1, paste, collapse = "|")

    for (key in target_keys) {
      cell_n <- sum(data_keys == key, na.rm = TRUE)
      if (cell_n > 0 && cell_n < 5) {
        warnings_list <- c(warnings_list, sprintf(
          "Cell '%s' has only %d observations (minimum 5 recommended)", key, cell_n
        ))
      }
    }
  }

  return(list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings_list
  ))
}

#' Print Cell Weight Summary
#'
#' Displays a formatted summary of cell weight calculation.
#'
#' @param result List, result from calculate_cell_weights_from_config
#' @param weight_name Character, name of the weight
#' @export
print_cell_summary <- function(result, weight_name = "cell_weight") {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("CELL WEIGHT SUMMARY:", weight_name, "\n")
  cat(strrep("=", 70), "\n\n")

  cat("Method: Cell/Interlocked Weighting\n")
  cat("Variables: ", paste(result$cell_variables, collapse = " x "), "\n")
  cat("Cells defined: ", result$n_cells_defined, "\n")
  if (result$n_cells_empty > 0) {
    cat("Empty cells: ", result$n_cells_empty, "\n")
  }
  if (result$n_unmatched > 0) {
    cat("Unmatched rows: ", result$n_unmatched, "\n")
  }
  cat("\n")

  cat("CELL DETAILS:\n")
  cat(strrep("-", 70), "\n")
  cat(sprintf("%-35s %8s %8s %8s %8s\n",
              "Cell", "Target%", "Sample#", "Sample%", "Weight"))
  cat(strrep("-", 70), "\n")

  for (i in seq_len(nrow(result$cell_summary))) {
    row <- result$cell_summary[i, ]
    cat(sprintf("%-35s %8.1f %8d %8.1f %8.4f\n",
                substr(row$cell, 1, 35),
                row$target_pct,
                row$sample_count,
                row$sample_pct,
                row$weight))
  }

  cat(strrep("-", 70), "\n")

  valid_w <- result$weights[!is.na(result$weights)]
  if (length(valid_w) > 0) {
    cat(sprintf("\nWeight range: [%.4f, %.4f], mean=%.4f\n",
                min(valid_w), max(valid_w), mean(valid_w)))
  }

  cat(strrep("=", 70), "\n")
}
