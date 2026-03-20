# ==============================================================================
# TURAS KEY DRIVER - EXECUTIVE SUMMARY GENERATOR
# ==============================================================================
#
# Purpose: Generate plain-English executive summary of KDA results
# Version: Turas v10.1
# Date: 2025-12
#
# Generates structured, human-readable summaries from key driver analysis
# results including: headline finding, key findings, method agreement
# assessment, model quality interpretation, warnings, and recommendations.
#
# All functions use TRS refusal patterns (no stop()/warning()/message()).
# Console output uses cat("[INFO] ...") and cat("[WARN] ...") only.
#
# ==============================================================================


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Generate Executive Summary of Key Driver Analysis Results
#'
#' Takes the full results list from a key driver analysis and produces a
#' structured, plain-English executive summary suitable for inclusion in
#' reports, Excel output, or console display.
#'
#' @param results List returned by \code{run_keydriver_analysis}. Expected
#'   fields: \code{$importance} (data.frame), \code{$model} (lm object),
#'   \code{$correlations} (matrix), \code{$config} (list).
#' @param config Optional list of summary configuration overrides:
#'   \describe{
#'     \item{top_n}{Number of top drivers to highlight (default 3)}
#'     \item{dominant_threshold}{Importance \% above which a driver is flagged
#'       as dominant (default 40)}
#'     \item{vif_threshold}{VIF value above which multicollinearity is flagged
#'       (default 5)}
#'     \item{r2_thresholds}{Named list with \code{low}, \code{moderate},
#'       \code{good} R-squared cutoffs (defaults: 0.10, 0.30, 0.50)}
#'   }
#'
#' @return A list with components:
#'   \describe{
#'     \item{headline}{Single-sentence summary of the key finding}
#'     \item{key_findings}{Character vector of 3-6 bullet-point findings}
#'     \item{method_agreement}{Plain-English assessment of cross-method consensus}
#'     \item{model_quality}{Plain-English model quality assessment}
#'     \item{warnings}{Character vector of concerns (may be empty)}
#'     \item{recommendations}{Character vector of 2-3 action-oriented recommendations}
#'   }
#'
#' @examples
#' \dontrun{
#'   results <- run_keydriver_analysis("config.xlsx")
#'   summary <- generate_executive_summary(results)
#'   cat(summary$headline, "\n")
#'   for (f in summary$key_findings) cat(" - ", f, "\n")
#' }
#'
#' @export
generate_executive_summary <- function(results, config = list()) {


  # --- Validate inputs ---
  if (is.null(results) || !is.list(results)) {
    keydriver_refuse(
      code = "DATA_INVALID_RESULTS",
      title = "Invalid Results Object",
      problem = "The 'results' argument is NULL or not a list.",
      why_it_matters = "Executive summary requires a valid key driver results object.",
      how_to_fix = "Pass the list returned by run_keydriver_analysis() to this function."
    )
  }

  if (is.null(results$importance) || !is.data.frame(results$importance)) {
    keydriver_refuse(
      code = "DATA_MISSING_IMPORTANCE",
      title = "Missing Importance Data",
      problem = "results$importance is NULL or not a data.frame.",
      why_it_matters = "The importance table is required to generate the executive summary.",
      how_to_fix = "Ensure the key driver analysis completed successfully before calling this function."
    )
  }

  if (is.null(results$model)) {
    keydriver_refuse(
      code = "DATA_MISSING_MODEL",
      title = "Missing Model Object",
      problem = "results$model is NULL.",
      why_it_matters = "The fitted model is needed to assess model quality and calculate diagnostics.",
      how_to_fix = "Ensure the key driver analysis completed successfully before calling this function."
    )
  }

  # --- Resolve config defaults ---
  top_n <- config$top_n %||% 3L
  dominant_threshold <- config$dominant_threshold %||% 40
  vif_threshold <- config$vif_threshold %||% 5
  r2_thresholds <- config$r2_thresholds %||% list(low = 0.10, moderate = 0.30, good = 0.50)

  importance_df <- results$importance
  model <- results$model
  model_summ <- summary(model)
  r_squared <- model_summ$r.squared
  n_obs <- stats::nobs(model)
  n_drivers <- nrow(importance_df)

  # --- Calculate VIF values ---
  vif_values <- tryCatch(
    calculate_vif(model),
    error = function(e) NULL
  )

  # --- Build summary components ---
  warnings_out <- character(0)

  # 1. Headline
  headline <- .build_headline(importance_df, r_squared, n_obs)

  # 2. Compute reusable summaries (called once, used in key_findings + return list)
  model_quality <- assess_model_quality(r_squared, n_obs, n_drivers,
                                         thresholds = r2_thresholds)
  method_agreement <- assess_method_agreement(importance_df)

  # 3. Key findings
  key_findings <- character(0)
  key_findings <- c(key_findings, summarize_top_drivers(importance_df, top_n = top_n))
  key_findings <- c(key_findings, model_quality)
  key_findings <- c(key_findings, method_agreement)

  # Add dominant driver finding if applicable
  dominant_msg <- detect_dominant_driver(importance_df, threshold = dominant_threshold)
  if (!is.null(dominant_msg)) {
    key_findings <- c(key_findings, dominant_msg)
    warnings_out <- c(warnings_out, dominant_msg)
  }

  # Add VIF concern if applicable
  vif_msg <- check_vif_concerns(vif_values, threshold = vif_threshold)
  if (!is.null(vif_msg)) {
    key_findings <- c(key_findings, vif_msg)
    warnings_out <- c(warnings_out, vif_msg)
  }

  # Add low R-squared warning
  if (r_squared < r2_thresholds$low) {
    low_r2_msg <- sprintf(
      "Low explanatory power: The model explains only %.0f%% of variance, suggesting important drivers may be missing.",
      r_squared * 100
    )
    warnings_out <- c(warnings_out, low_r2_msg)
  }

  # 5. Recommendations
  effect_sizes <- .extract_effect_sizes(importance_df, r_squared)
  recommendations <- generate_recommendations(importance_df, model_quality,
                                               effect_sizes = effect_sizes)

  list(
    headline = headline,
    key_findings = key_findings,
    method_agreement = method_agreement,
    model_quality = model_quality,
    warnings = warnings_out,
    recommendations = recommendations
  )
}


# ==============================================================================
# FINDING GENERATORS
# ==============================================================================

#' Summarize Top Drivers
#'
#' Produces a plain-English sentence listing the top N drivers with their
#' importance percentages. Uses Shapley_Value if available, otherwise
#' falls back to Relative_Weight or the first available importance column.
#'
#' @param importance_df Data frame with at least \code{Driver} and one
#'   importance column (Shapley_Value, Relative_Weight, Beta_Weight, or
#'   Importance).
#' @param top_n Number of top drivers to include (default 3).
#'
#' @return A single character string summarizing the top drivers, e.g.
#'   \code{"The top 3 drivers are: Price (32\%), Quality (28\%), Service (19\%)"}
#'
#' @keywords internal
summarize_top_drivers <- function(importance_df, top_n = 3L) {

  if (is.null(importance_df) || nrow(importance_df) == 0) {
    return("No importance data available.")
  }

  # Determine best importance column
  imp_col <- .pick_importance_column(importance_df)
  if (is.null(imp_col)) {
    return("No recognised importance metric found in results.")
  }

  # Use Label if available, otherwise Driver
  label_col <- if ("Label" %in% names(importance_df)) "Label" else "Driver"

  # Sort by importance descending
  ordered_df <- importance_df[order(-importance_df[[imp_col]]), , drop = FALSE]
  top_n_actual <- min(top_n, nrow(ordered_df))
  top_df <- ordered_df[seq_len(top_n_actual), , drop = FALSE]

  # Build driver descriptions
  driver_parts <- vapply(seq_len(top_n_actual), function(i) {
    label <- top_df[[label_col]][i]
    if (is.na(label) || !nzchar(label)) label <- top_df$Driver[i]
    pct <- top_df[[imp_col]][i]
    sprintf("%s (%.0f%%)", label, pct)
  }, character(1))

  sprintf("The top %d drivers are: %s.", top_n_actual, paste(driver_parts, collapse = ", "))
}


#' Assess Method Agreement
#'
#' Checks rank correlation between importance methods to determine whether
#' they agree on the relative ordering of drivers. Uses Spearman rank
#' correlation across available ranking columns.
#'
#' @param importance_df Data frame with ranking columns (e.g.
#'   \code{Shapley_Rank}, \code{RelWeight_Rank}, \code{Beta_Rank},
#'   \code{Corr_Rank}).
#'
#' @return A single character string describing the level of agreement, e.g.
#'   \code{"Strong agreement across methods (avg rank correlation = 0.95)"}
#'
#' @keywords internal
assess_method_agreement <- function(importance_df) {

  if (is.null(importance_df) || nrow(importance_df) < 3) {
    return("Too few drivers to assess method agreement.")
  }

  # Collect available rank columns
  rank_cols <- intersect(
    c("Shapley_Rank", "RelWeight_Rank", "Beta_Rank", "Corr_Rank",
      "SHAP_Rank", "Importance_Rank"),
    names(importance_df)
  )

  if (length(rank_cols) < 2) {
    return("Only one ranking method available; cross-method agreement cannot be assessed.")
  }

  # Extract rank matrix
  rank_matrix <- as.matrix(importance_df[, rank_cols, drop = FALSE])

  # Remove columns that are all NA
  valid_cols <- apply(rank_matrix, 2, function(col) !all(is.na(col)))
  rank_matrix <- rank_matrix[, valid_cols, drop = FALSE]

  if (ncol(rank_matrix) < 2) {
    return("Insufficient valid ranking columns for agreement assessment.")
  }

  # Calculate pairwise Spearman correlations
  cor_matrix <- tryCatch(
    stats::cor(rank_matrix, use = "pairwise.complete.obs", method = "spearman"),
    error = function(e) NULL
  )

  if (is.null(cor_matrix)) {
    return("Could not calculate rank correlations between methods.")
  }

  # Average off-diagonal correlation
  n_methods <- ncol(cor_matrix)
  off_diag <- cor_matrix[lower.tri(cor_matrix)]
  avg_cor <- mean(off_diag, na.rm = TRUE)

  # Classify agreement
  if (is.na(avg_cor)) {
    return("Could not determine method agreement (insufficient data).")
  }

  if (avg_cor >= 0.85) {
    level <- "Strong agreement"
    detail <- "all methods largely agree on driver rankings"
  } else if (avg_cor >= 0.60) {
    level <- "Moderate agreement"
    detail <- "methods mostly agree but differ on some mid-ranking drivers"
  } else {
    level <- "Methods disagree"
    detail <- "rankings differ substantially across methods, interpret with caution"
  }

  # Check if top driver is consistent
  top_driver_note <- .check_top_driver_consensus(importance_df, rank_cols[rank_cols %in% names(importance_df)])

  agreement_msg <- sprintf(
    "%s across %d methods (avg rank correlation = %.2f): %s.",
    level, n_methods, avg_cor, detail
  )

  if (!is.null(top_driver_note)) {
    agreement_msg <- paste(agreement_msg, top_driver_note)
  }

  agreement_msg
}


#' Assess Model Quality
#'
#' Interprets the model R-squared value in plain English, incorporating
#' sample size context and the number of drivers.
#'
#' @param r_squared Numeric R-squared value from the model.
#' @param n_obs Integer number of observations.
#' @param n_drivers Integer number of driver variables.
#' @param thresholds Named list with \code{low}, \code{moderate}, \code{good}
#'   R-squared cutoffs (defaults: 0.10, 0.30, 0.50).
#'
#' @return A single character string interpreting the model quality, e.g.
#'   \code{"The model explains 65\% of variance in the outcome, which is
#'   considered good for survey data (n=450, 8 drivers)."}
#'
#' @keywords internal
assess_model_quality <- function(r_squared, n_obs, n_drivers,
                                  thresholds = list(low = 0.10,
                                                    moderate = 0.30,
                                                    good = 0.50)) {

  if (is.null(r_squared) || is.na(r_squared)) {
    return("Model R-squared is not available.")
  }

  pct <- round(r_squared * 100, 0)

  # Classify
  if (r_squared >= thresholds$good) {
    quality <- "good"
  } else if (r_squared >= thresholds$moderate) {
    quality <- "moderate"
  } else if (r_squared >= thresholds$low) {
    quality <- "low"
  } else {
    quality <- "very low"
  }

  sprintf(
    "The model explains %d%% of variance in the outcome, which is considered %s for survey data (n=%d, %d drivers).",
    pct, quality, n_obs, n_drivers
  )
}


#' Detect Dominant Driver
#'
#' Checks whether any single driver accounts for more than a given threshold
#' of total importance. A dominant driver can mask the effects of others and
#' may indicate a structural issue in the analysis.
#'
#' @param importance_df Data frame with importance scores.
#' @param threshold Numeric percentage threshold above which a driver is
#'   flagged as dominant (default 40).
#'
#' @return A character string warning about the dominant driver, or \code{NULL}
#'   if no driver exceeds the threshold.
#'
#' @keywords internal
detect_dominant_driver <- function(importance_df, threshold = 40) {

  if (is.null(importance_df) || nrow(importance_df) == 0) {
    return(NULL)
  }

  imp_col <- .pick_importance_column(importance_df)
  if (is.null(imp_col)) return(NULL)

  label_col <- if ("Label" %in% names(importance_df)) "Label" else "Driver"

  max_idx <- which.max(importance_df[[imp_col]])
  max_pct <- importance_df[[imp_col]][max_idx]

  if (max_pct > threshold) {
    label <- importance_df[[label_col]][max_idx]
    if (is.na(label) || !nzchar(label)) label <- importance_df$Driver[max_idx]
    sprintf(
      "Warning: %s accounts for %.0f%% of importance - potential dominant driver effect. Consider whether this driver is too closely related to the outcome.",
      label, max_pct
    )
  } else {
    NULL
  }
}


#' Check VIF Concerns
#'
#' Examines VIF values for evidence of multicollinearity. Drivers with VIF
#' above the threshold are reported.
#'
#' @param vif_values Named numeric vector of VIF values, or \code{NULL}.
#' @param threshold Numeric VIF threshold above which a concern is raised
#'   (default 5).
#'
#' @return A character string describing the concern, or \code{NULL} if no
#'   VIF values exceed the threshold.
#'
#' @keywords internal
check_vif_concerns <- function(vif_values, threshold = 5) {

  if (is.null(vif_values) || length(vif_values) == 0) {
    return(NULL)
  }

  high_vif <- vif_values[vif_values > threshold]

  if (length(high_vif) == 0) {
    return(NULL)
  }

  driver_details <- vapply(names(high_vif), function(nm) {
    sprintf("%s (VIF=%.1f)", nm, high_vif[nm])
  }, character(1))

  sprintf(
    "Multicollinearity detected: %s %s VIF > %d, which may inflate their importance estimates.",
    paste(driver_details, collapse = ", "),
    if (length(high_vif) == 1) "has" else "have",
    threshold
  )
}


#' Generate Recommendations
#'
#' Produces 2-3 action-oriented recommendations based on the analysis results.
#' Recommendations are tailored to the specific findings: which drivers matter
#' most, model quality issues, and methodological concerns.
#'
#' @param importance_df Data frame with importance scores.
#' @param model_quality Character string from \code{assess_model_quality()}.
#' @param effect_sizes Optional list with effect size information (e.g.
#'   \code{r_squared}, \code{top_driver_pct}).
#'
#' @return A character vector of 2-3 recommendation strings.
#'
#' @keywords internal
generate_recommendations <- function(importance_df, model_quality,
                                      effect_sizes = NULL) {

  recs <- character(0)

  if (is.null(importance_df) || nrow(importance_df) == 0) {
    return("Insufficient data to generate recommendations.")
  }

  imp_col <- .pick_importance_column(importance_df)
  label_col <- if ("Label" %in% names(importance_df)) "Label" else "Driver"

  # --- Recommendation 1: Focus on top driver ---
  if (!is.null(imp_col)) {
    ordered_df <- importance_df[order(-importance_df[[imp_col]]), , drop = FALSE]
    top_label <- ordered_df[[label_col]][1]
    if (is.na(top_label) || !nzchar(top_label)) top_label <- ordered_df$Driver[1]
    top_pct <- ordered_df[[imp_col]][1]

    recs <- c(recs, sprintf(
      "Prioritise %s as the primary lever for improvement - it accounts for %.0f%% of driver importance.",
      top_label, top_pct
    ))

    # Second driver recommendation if gap is not too large
    if (nrow(ordered_df) >= 2) {
      second_label <- ordered_df[[label_col]][2]
      if (is.na(second_label) || !nzchar(second_label)) second_label <- ordered_df$Driver[2]
      second_pct <- ordered_df[[imp_col]][2]
      if (second_pct >= 10) {
        recs <- c(recs, sprintf(
          "Also focus on %s (%.0f%%) as a secondary improvement area.",
          second_label, second_pct
        ))
      }
    }
  }

  # --- Recommendation 2: Model quality based ---
  r2 <- effect_sizes$r_squared %||% NULL
  if (!is.null(r2)) {
    if (r2 < 0.30) {
      recs <- c(recs, sprintf(
        "The model explains only %.0f%% of variance. Consider adding additional drivers (e.g., emotional factors, brand perceptions) to improve explanatory power.",
        r2 * 100
      ))
    } else if (r2 >= 0.50) {
      recs <- c(recs, sprintf(
        "The model has good explanatory power (R²=%.0f%%). Results are reliable for strategic decision-making.",
        r2 * 100
      ))
    }
  }

  # --- Recommendation 3: Bottom drivers ---
  if (!is.null(imp_col) && nrow(importance_df) >= 4) {
    ordered_df <- importance_df[order(-importance_df[[imp_col]]), , drop = FALSE]
    bottom_drivers <- ordered_df[ordered_df[[imp_col]] < 5, , drop = FALSE]
    if (nrow(bottom_drivers) > 0) {
      bottom_labels <- vapply(seq_len(min(3, nrow(bottom_drivers))), function(i) {
        lbl <- bottom_drivers[[label_col]][i]
        if (is.na(lbl) || !nzchar(lbl)) lbl <- bottom_drivers$Driver[i]
        lbl
      }, character(1))
      recs <- c(recs, sprintf(
        "De-prioritise low-impact drivers (%s) - they each contribute less than 5%% to the outcome.",
        paste(bottom_labels, collapse = ", ")
      ))
    }
  }

  # Ensure at least 2 recommendations
  if (length(recs) < 2) {
    recs <- c(recs,
      "Review results with stakeholders to validate whether the statistical importance aligns with business knowledge."
    )
  }

  # Cap at 3 recommendations
  if (length(recs) > 3) {
    recs <- recs[1:3]
  }

  recs
}


# ==============================================================================
# FORMATTER
# ==============================================================================

#' Format Executive Summary for Output
#'
#' Formats the structured summary list into either plain text (for console
#' and Excel output) or HTML (for Turas report hub integration).
#'
#' @param summary_list List returned by \code{generate_executive_summary()}.
#' @param format Output format: \code{"text"} (default) or \code{"html"}.
#'
#' @return For \code{"text"}: a character vector where each element is one
#'   line of the formatted summary. For \code{"html"}: a single character
#'   string containing styled HTML.
#'
#' @examples
#' \dontrun{
#'   summary <- generate_executive_summary(results)
#'   text_lines <- format_executive_summary(summary, format = "text")
#'   cat(paste(text_lines, collapse = "\n"))
#' }
#'
#' @export
format_executive_summary <- function(summary_list, format = "text") {

  if (is.null(summary_list) || !is.list(summary_list)) {
    keydriver_refuse(
      code = "DATA_INVALID_SUMMARY",
      title = "Invalid Summary Object",
      problem = "The 'summary_list' argument is NULL or not a list.",
      why_it_matters = "Cannot format a summary that does not exist.",
      how_to_fix = "Pass the list returned by generate_executive_summary() to this function."
    )
  }

  format <- match.arg(format, choices = c("text", "html"))

  if (format == "text") {
    .format_text(summary_list)
  } else {
    .format_html(summary_list)
  }
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Build Headline Finding
#'
#' Constructs a single-sentence headline from the importance table and
#' model R-squared.
#'
#' @param importance_df Importance data frame.
#' @param r_squared Numeric R-squared value.
#' @param n_obs Integer number of observations.
#' @return Single character string.
#' @keywords internal
.build_headline <- function(importance_df, r_squared, n_obs) {

  imp_col <- .pick_importance_column(importance_df)
  label_col <- if ("Label" %in% names(importance_df)) "Label" else "Driver"

  if (is.null(imp_col)) {
    return("Key driver analysis complete.")
  }

  # Find top driver
  ordered_df <- importance_df[order(-importance_df[[imp_col]]), , drop = FALSE]
  top_label <- ordered_df[[label_col]][1]
  if (is.na(top_label) || !nzchar(top_label)) top_label <- ordered_df$Driver[1]
  top_pct <- ordered_df[[imp_col]][1]

  # Determine descriptor based on importance magnitude
  descriptor <- if (top_pct >= 40) {
    "the dominant driver"
  } else if (top_pct >= 25) {
    "the leading driver"
  } else {
    "the most important driver"
  }

  # Use outcome variable label if available
  outcome_label <- "the outcome"
  if (!is.null(importance_df) && "config" %in% names(attributes(importance_df))) {
    cfg <- attr(importance_df, "config")
    if (!is.null(cfg$outcome_var)) outcome_label <- cfg$outcome_var
  }

  sprintf(
    "%s is %s of %s, accounting for %.0f%% of driver importance (R\u00b2=%.0f%%, n=%d).",
    top_label, descriptor, outcome_label, top_pct, r_squared * 100, n_obs
  )
}


#' Pick Best Available Importance Column
#'
#' Selects the most appropriate importance column from the data frame,
#' preferring Shapley, then Relative Weight, then others.
#'
#' @param importance_df Data frame with importance scores.
#' @return Column name string, or NULL if no recognised column found.
#' @keywords internal
.pick_importance_column <- function(importance_df) {

  preference_order <- c(
    "Shapley_Value", "SHAP_Importance", "Relative_Weight",
    "Beta_Weight", "Importance"
  )

  for (col in preference_order) {
    if (col %in% names(importance_df)) {
      return(col)
    }
  }
  NULL
}


#' Check Whether Top Driver is Consistent Across Methods
#'
#' Examines ranking columns to see if the same driver is ranked #1 by all
#' methods.
#'
#' @param importance_df Importance data frame.
#' @param rank_cols Character vector of ranking column names present in the df.
#' @return Character string note, or NULL.
#' @keywords internal
.check_top_driver_consensus <- function(importance_df, rank_cols) {

  if (length(rank_cols) < 2 || nrow(importance_df) < 2) return(NULL)

  label_col <- if ("Label" %in% names(importance_df)) "Label" else "Driver"

  top_drivers <- vapply(rank_cols, function(rc) {
    ranks <- importance_df[[rc]]
    if (all(is.na(ranks))) return(NA_character_)
    idx <- which.min(ranks)
    lbl <- importance_df[[label_col]][idx]
    if (is.na(lbl) || !nzchar(lbl)) lbl <- importance_df$Driver[idx]
    lbl
  }, character(1))

  top_drivers <- top_drivers[!is.na(top_drivers)]

  if (length(top_drivers) < 2) return(NULL)

  if (length(unique(top_drivers)) == 1) {
    sprintf("All methods agree that %s is the #1 driver.", top_drivers[1])
  } else {
    sprintf(
      "Top driver varies by method (%s) - examine results carefully.",
      paste(unique(top_drivers), collapse = " vs. ")
    )
  }
}


#' Extract Effect Sizes from Results
#'
#' Pulls out key numeric summaries used by the recommendation generator.
#'
#' @param importance_df Importance data frame.
#' @param r_squared Model R-squared.
#' @return Named list with effect size information.
#' @keywords internal
.extract_effect_sizes <- function(importance_df, r_squared) {

  imp_col <- .pick_importance_column(importance_df)
  top_driver_pct <- if (!is.null(imp_col)) {
    max(importance_df[[imp_col]], na.rm = TRUE)
  } else {
    NA_real_
  }

  list(
    r_squared = r_squared,
    top_driver_pct = top_driver_pct
  )
}


#' Format Summary as Plain Text
#'
#' @param summary_list Summary list from generate_executive_summary().
#' @return Character vector of text lines.
#' @keywords internal
.format_text <- function(summary_list) {

  lines <- character(0)

  # Headline
  lines <- c(lines, "EXECUTIVE SUMMARY")
  lines <- c(lines, paste(rep("=", 60), collapse = ""))
  lines <- c(lines, "")
  lines <- c(lines, summary_list$headline %||% "")
  lines <- c(lines, "")

  # Key Findings
  lines <- c(lines, "KEY FINDINGS:")
  lines <- c(lines, paste(rep("-", 40), collapse = ""))
  for (finding in summary_list$key_findings) {
    lines <- c(lines, paste0("  * ", finding))
  }
  lines <- c(lines, "")

  # Method Agreement
  lines <- c(lines, "METHOD AGREEMENT:")
  lines <- c(lines, paste(rep("-", 40), collapse = ""))
  lines <- c(lines, paste0("  ", summary_list$method_agreement %||% "Not assessed."))
  lines <- c(lines, "")

  # Model Quality
  lines <- c(lines, "MODEL QUALITY:")
  lines <- c(lines, paste(rep("-", 40), collapse = ""))
  lines <- c(lines, paste0("  ", summary_list$model_quality %||% "Not assessed."))
  lines <- c(lines, "")

  # Warnings (if any)
  if (length(summary_list$warnings) > 0) {
    lines <- c(lines, "WARNINGS:")
    lines <- c(lines, paste(rep("-", 40), collapse = ""))
    for (w in summary_list$warnings) {
      lines <- c(lines, paste0("  ! ", w))
    }
    lines <- c(lines, "")
  }

  # Recommendations
  lines <- c(lines, "RECOMMENDATIONS:")
  lines <- c(lines, paste(rep("-", 40), collapse = ""))
  for (i in seq_along(summary_list$recommendations)) {
    lines <- c(lines, sprintf("  %d. %s", i, summary_list$recommendations[i]))
  }
  lines <- c(lines, "")
  lines <- c(lines, paste(rep("=", 60), collapse = ""))

  lines
}


#' Format Summary as HTML
#'
#' Generates styled HTML matching the Turas design system: muted colour
#' palette, clean typography, no gradients or shadows.
#'
#' @param summary_list Summary list from generate_executive_summary().
#' @return Single character string of HTML.
#' @keywords internal
.format_html <- function(summary_list) {

  # Turas design tokens
  heading_color <- "#1e293b"
  text_color <- "#334155"
  muted_color <- "#64748b"
  accent_color <- "#4472C4"
  warning_color <- "#d97706"
  bg_color <- "#f8fafc"
  border_color <- "#e2e8f0"

  html <- paste0(
    '<div style="font-family: \'Segoe UI\', Arial, sans-serif; color: ', text_color, '; ',
    'max-width: 700px; padding: 24px; background: ', bg_color, '; ',
    'border: 1px solid ', border_color, '; border-radius: 8px;">',
    '\n'
  )

  # Headline
  html <- paste0(html,
    '<h2 style="color: ', heading_color, '; font-size: 18px; font-weight: 600; ',
    'margin: 0 0 8px 0; padding-bottom: 8px; border-bottom: 2px solid ', accent_color, ';">',
    'Executive Summary</h2>\n',
    '<p style="font-size: 15px; font-weight: 500; margin: 0 0 20px 0; line-height: 1.5;">',
    .html_escape(summary_list$headline %||% ""),
    '</p>\n'
  )

  # Key Findings
  html <- paste0(html,
    '<h3 style="color: ', heading_color, '; font-size: 14px; font-weight: 600; ',
    'margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 0.5px;">',
    'Key Findings</h3>\n',
    '<ul style="margin: 0 0 20px 0; padding-left: 20px; line-height: 1.7;">\n'
  )
  for (finding in summary_list$key_findings) {
    html <- paste0(html,
      '<li style="font-size: 13px; margin-bottom: 4px;">', .html_escape(finding), '</li>\n'
    )
  }
  html <- paste0(html, '</ul>\n')

  # Model Quality
  html <- paste0(html,
    '<h3 style="color: ', heading_color, '; font-size: 14px; font-weight: 600; ',
    'margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 0.5px;">',
    'Model Quality</h3>\n',
    '<p style="font-size: 13px; margin: 0 0 20px 0; color: ', muted_color, '; line-height: 1.5;">',
    .html_escape(summary_list$model_quality %||% "Not assessed."),
    '</p>\n'
  )

  # Warnings (if any)
  if (length(summary_list$warnings) > 0) {
    html <- paste0(html,
      '<div style="background: #fffbeb; border: 1px solid ', warning_color, '; ',
      'border-radius: 4px; padding: 12px 16px; margin-bottom: 20px;">\n',
      '<h3 style="color: ', warning_color, '; font-size: 14px; font-weight: 600; ',
      'margin: 0 0 8px 0;">Warnings</h3>\n',
      '<ul style="margin: 0; padding-left: 20px;">\n'
    )
    for (w in summary_list$warnings) {
      html <- paste0(html,
        '<li style="font-size: 13px; color: ', text_color, '; margin-bottom: 4px;">',
        .html_escape(w), '</li>\n'
      )
    }
    html <- paste0(html, '</ul>\n</div>\n')
  }

  # Recommendations
  html <- paste0(html,
    '<h3 style="color: ', heading_color, '; font-size: 14px; font-weight: 600; ',
    'margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 0.5px;">',
    'Recommendations</h3>\n',
    '<ol style="margin: 0 0 12px 0; padding-left: 20px; line-height: 1.7;">\n'
  )
  for (rec in summary_list$recommendations) {
    html <- paste0(html,
      '<li style="font-size: 13px; margin-bottom: 4px;">', .html_escape(rec), '</li>\n'
    )
  }
  html <- paste0(html, '</ol>\n')

  # Close container
  html <- paste0(html, '</div>\n')

  html
}


#' HTML-Escape a String
#'
#' Escapes \code{&}, \code{<}, \code{>}, and \code{"} characters for safe
#' inclusion in HTML output.
#'
#' @param x Character string to escape.
#' @return Escaped character string.
#' @keywords internal
.html_escape <- function(x) {
  if (is.null(x) || length(x) == 0) return("")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}


# ==============================================================================
# NULL-COALESCING OPERATOR (guarded definition)
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
