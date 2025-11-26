# ==============================================================================
# CONJOINT ANALYSIS - NONE OPTION HANDLING
# ==============================================================================
#
# Module: Conjoint Analysis - None Option Detection and Handling
# Purpose: Auto-detect and handle "none of these" options in CBC data
# Version: 2.0.0 (Phase 1 Implementation)
# Date: 2025-11-26
#
# ==============================================================================

#' Detect None Option in Data
#'
#' Auto-detects if data contains a "none of these" or opt-out option
#' Uses multiple detection methods for robustness
#'
#' DETECTION METHODS:
#'   1. Check for "none" patterns in attribute values
#'   2. Check for choice sets where all alternatives are unchosen
#'   3. Check for "none" in alternative_id column
#'
#' @param data Data frame with choice data
#' @param config Configuration list
#' @return List with has_none flag, method, and details
#' @export
detect_none_option <- function(data, config) {

  # None detection patterns
  none_patterns <- c(
    "none", "no choice", "neither", "none of these", "none of the above",
    "no option", "opt out", "skip", "no selection"
  )

  # METHOD 1: Check for none in attribute values
  has_none_in_attributes <- FALSE
  none_attribute <- NULL

  for (attr in config$attributes$AttributeName) {
    if (attr %in% names(data)) {
      attr_values <- unique(tolower(as.character(data[[attr]])))

      # Check if any value matches none patterns
      for (pattern in none_patterns) {
        if (any(grepl(pattern, attr_values))) {
          has_none_in_attributes <- TRUE
          none_attribute <- attr
          break
        }
      }

      if (has_none_in_attributes) break
    }
  }

  # METHOD 2: Check for choice sets where all alternatives are unchosen
  # This indicates implicit none option
  chosen_per_set <- aggregate(
    data[[config$chosen_column]],
    by = list(choice_set_id = data[[config$choice_set_column]]),
    FUN = sum
  )
  names(chosen_per_set)[2] <- "n_chosen"

  all_unchosen_sets <- chosen_per_set$choice_set_id[chosen_per_set$n_chosen == 0]
  has_all_zeros <- length(all_unchosen_sets) > 0

  # METHOD 3: Check alternative_id column
  has_none_alt_id <- FALSE
  if (!is.null(config$alternative_id_column) &&
      config$alternative_id_column %in% names(data)) {

    alt_ids <- unique(tolower(as.character(data[[config$alternative_id_column]])))

    for (pattern in none_patterns) {
      if (any(grepl(pattern, alt_ids))) {
        has_none_alt_id <- TRUE
        break
      }
    }
  }

  # Determine detection method and result
  has_none <- has_none_in_attributes || has_all_zeros || has_none_alt_id

  method <- if (has_none_in_attributes) {
    "none_in_attributes"
  } else if (has_none_alt_id) {
    "none_alternative_id"
  } else if (has_all_zeros) {
    "all_unchosen_sets"
  } else {
    "no_none_detected"
  }

  list(
    has_none = has_none,
    method = method,
    none_count = length(all_unchosen_sets),
    none_attribute = none_attribute,
    none_patterns_used = none_patterns
  )
}


#' Handle None Option in Data
#'
#' Processes data based on detected none option method
#' Ensures data integrity and proper none handling
#'
#' @param data Data frame with choice data
#' @param config Configuration list
#' @param verbose Logical, print progress messages
#' @return List with processed data, none handling info
#' @export
handle_none_option <- function(data, config, verbose = TRUE) {

  # Detect none option
  none_info <- detect_none_option(data, config)

  if (!none_info$has_none) {
    return(list(
      data = data,
      has_none = FALSE,
      none_handling = "not_applicable",
      n_none_chosen = 0
    ))
  }

  log_verbose(sprintf("None option detected (method: %s)", none_info$method), verbose)

  # Handle based on detection method
  if (none_info$method %in% c("none_in_attributes", "none_alternative_id")) {
    # Explicit none rows exist in data
    result <- handle_explicit_none(data, config, none_info, verbose)
  } else if (none_info$method == "all_unchosen_sets") {
    # Implicit none (need to add rows)
    result <- handle_implicit_none(data, config, none_info, verbose)
  }

  result
}


#' Handle Explicit None Rows
#'
#' Data already has none rows - just flag them
#'
#' @keywords internal
handle_explicit_none <- function(data, config, none_info, verbose = TRUE) {

  # Identify none rows
  none_rows <- identify_none_rows(data, config, none_info)

  # Add flag column
  data$is_none_alternative <- FALSE
  data$is_none_alternative[none_rows] <- TRUE

  # Count none selections
  n_none_chosen <- sum(data[[config$chosen_column]][data$is_none_alternative])

  # Validate
  validate_none_choices(data, config)

  log_verbose(sprintf("  ✓ Found %d explicit none rows (%d selected)",
                     length(none_rows), n_none_chosen), verbose)

  list(
    data = data,
    has_none = TRUE,
    none_handling = "explicit_none_rows",
    n_none_chosen = n_none_chosen,
    none_label = config$none_label
  )
}


#' Handle Implicit None
#'
#' None is implicit (all unchosen) - add explicit rows
#'
#' @keywords internal
handle_implicit_none <- function(data, config, none_info, verbose = TRUE) {

  # Find choice sets where all alternatives are unchosen
  all_unchosen_sets <- data %>%
    group_by(!!sym(config$choice_set_column)) %>%
    summarise(
      resp_id = first(!!sym(config$respondent_id_column)),
      n_chosen = sum(!!sym(config$chosen_column)),
      .groups = "drop"
    ) %>%
    filter(n_chosen == 0)

  if (nrow(all_unchosen_sets) == 0) {
    # No implicit none after all
    data$is_none_alternative <- FALSE
    return(list(
      data = data,
      has_none = FALSE,
      none_handling = "false_positive",
      n_none_chosen = 0
    ))
  }

  log_verbose(sprintf("  ✓ Adding explicit 'none' rows for %d choice sets",
                     nrow(all_unchosen_sets)), verbose)

  # Create none rows
  none_rows <- create_none_rows(all_unchosen_sets, config, data)

  # Add to original data
  data$is_none_alternative <- FALSE
  data <- bind_rows(data, none_rows)

  # Validate
  validate_none_choices(data, config)

  list(
    data = data,
    has_none = TRUE,
    none_handling = "implicit_none_added",
    n_none_chosen = nrow(all_unchosen_sets),
    none_label = config$none_label
  )
}


#' Identify None Rows in Data
#'
#' @keywords internal
identify_none_rows <- function(data, config, none_info) {

  none_patterns <- none_info$none_patterns_used
  is_none <- rep(FALSE, nrow(data))

  # Check each attribute for none values
  for (attr in config$attributes$AttributeName) {
    if (attr %in% names(data)) {
      attr_values <- tolower(as.character(data[[attr]]))

      for (pattern in none_patterns) {
        is_none <- is_none | grepl(pattern, attr_values)
      }
    }
  }

  # Also check alternative_id
  if (!is.null(config$alternative_id_column) &&
      config$alternative_id_column %in% names(data)) {

    alt_ids <- tolower(as.character(data[[config$alternative_id_column]]))

    for (pattern in none_patterns) {
      is_none <- is_none | grepl(pattern, alt_ids)
    }
  }

  which(is_none)
}


#' Create None Rows
#'
#' Creates explicit none alternative rows for choice sets
#'
#' @keywords internal
create_none_rows <- function(all_unchosen_sets, config, original_data) {

  # Create template row
  none_rows_list <- list()

  for (i in seq_len(nrow(all_unchosen_sets))) {
    row_data <- list()

    # Required columns
    row_data[[config$respondent_id_column]] <- all_unchosen_sets$resp_id[i]
    row_data[[config$choice_set_column]] <- all_unchosen_sets[[config$choice_set_column]][i]
    row_data[[config$chosen_column]] <- 1
    row_data[["is_none_alternative"]] <- TRUE

    # Alternative ID
    if (config$alternative_id_column %in% names(original_data)) {
      row_data[[config$alternative_id_column]] <- "NONE"
    }

    # Set all attributes to none label
    for (attr in config$attributes$AttributeName) {
      row_data[[attr]] <- config$none_label
    }

    none_rows_list[[i]] <- as.data.frame(row_data, stringsAsFactors = FALSE)
  }

  # Combine all none rows
  do.call(rbind, none_rows_list)
}


#' Validate None Choices
#'
#' Ensures data integrity with none option
#'
#' @keywords internal
validate_none_choices <- function(data, config) {

  # Check 1: Exactly one chosen per choice set
  chosen_per_set <- data %>%
    group_by(!!sym(config$choice_set_column)) %>%
    summarise(n_chosen = sum(!!sym(config$chosen_column)), .groups = "drop")

  if (any(chosen_per_set$n_chosen != 1)) {
    bad_sets <- chosen_per_set[[config$choice_set_column]][chosen_per_set$n_chosen != 1]
    stop(create_error(
      "DATA",
      sprintf("Invalid choice counts in %d choice sets", length(bad_sets)),
      "Each choice set must have exactly ONE chosen alternative (including 'none')",
      sprintf("Problem choice sets: %s", paste(head(bad_sets, 5), collapse = ", "))
    ), call. = FALSE)
  }

  # Check 2: If none is chosen, no other alternative should be chosen
  if ("is_none_alternative" %in% names(data)) {
    none_chosen_sets <- data %>%
      filter(is_none_alternative, !!sym(config$chosen_column) == 1) %>%
      pull(!!sym(config$choice_set_column))

    other_chosen_in_none_sets <- data %>%
      filter(
        !!sym(config$choice_set_column) %in% none_chosen_sets,
        !is_none_alternative,
        !!sym(config$chosen_column) == 1
      )

    if (nrow(other_chosen_in_none_sets) > 0) {
      stop(create_error(
        "DATA",
        "Some choice sets have both 'none' and another alternative selected",
        "When 'none' is chosen, no other alternative should be chosen",
        "Check your Alchemer data export for errors"
      ), call. = FALSE)
    }
  }

  TRUE
}


#' Calculate None Diagnostics
#'
#' Calculates statistics specific to none option
#'
#' @param model Fitted model object
#' @param data Data with choice data
#' @param config Configuration
#' @return List with none-specific diagnostics
#' @keywords internal
calculate_none_diagnostics <- function(model, data, config) {

  if (!"is_none_alternative" %in% names(data)) {
    return(NULL)
  }

  # None selection rate
  none_selections <- sum(data$is_none_alternative & data[[config$chosen_column]] == 1)
  total_choice_sets <- length(unique(data[[config$choice_set_column]]))
  none_share <- none_selections / total_choice_sets

  # Get none utility if available
  none_utility <- NA
  if ("utilities" %in% names(model)) {
    none_util_rows <- model$utilities[model$utilities$is_none_alternative, ]
    if (nrow(none_util_rows) > 0) {
      none_utility <- mean(none_util_rows$Utility, na.rm = TRUE)
    }
  }

  list(
    none_selection_count = none_selections,
    none_selection_rate = none_share,
    none_utility = none_utility,
    total_choice_sets = total_choice_sets
  )
}
