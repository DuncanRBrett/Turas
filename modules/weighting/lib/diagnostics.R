# ==============================================================================
# WEIGHTING MODULE - DIAGNOSTICS
# ==============================================================================
# Comprehensive weight quality diagnostics and reporting
# Part of TURAS Weighting Module v1.0
#
# METRICS:
# - Basic statistics (min, max, mean, median, SD, CV)
# - Sample size metrics (effective N, design effect, efficiency)
# - Distribution (quartiles, percentiles, extreme weights)
# - Rim weighting specific (convergence, margin achievement)
# ==============================================================================

#' Generate Weight Diagnostics
#'
#' Comprehensive diagnostics for a weight vector.
#'
#' @param weights Numeric vector of weights
#' @param label Character, name for this weight (default: "Weight Diagnostics")
#' @param rim_result List, optional rim weighting result for convergence info
#' @param trimming_result List, optional trimming result
#' @param save_to_file Character, optional path to save diagnostics
#' @param verbose Logical, print to console (default: TRUE)
#' @return List with all diagnostic metrics
#' @export
diagnose_weights <- function(weights,
                             label = "Weight Diagnostics",
                             rim_result = NULL,
                             trimming_result = NULL,
                             save_to_file = NULL,
                             verbose = TRUE) {

  # Initialize results
  results <- list(
    label = label,
    timestamp = Sys.time()
  )

  # ============================================================================
  # Basic Sample Size
  # ============================================================================
  n_total <- length(weights)
  n_na <- sum(is.na(weights))
  n_zero <- sum(!is.na(weights) & weights == 0)
  n_negative <- sum(!is.na(weights) & weights < 0)
  n_infinite <- sum(!is.na(weights) & is.infinite(weights))
  n_valid <- sum(!is.na(weights) & is.finite(weights) & weights > 0)

  results$sample_size <- list(
    n_total = n_total,
    n_valid = n_valid,
    n_na = n_na,
    n_zero = n_zero,
    n_negative = n_negative,
    n_infinite = n_infinite,
    pct_valid = 100 * n_valid / n_total
  )

  # Get valid weights for further analysis
  valid_weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]

  if (length(valid_weights) == 0) {
    results$valid = FALSE
    results$message = "No valid weights to analyze"

    if (verbose) {
      print_diagnostics_console(results)
    }

    return(results)
  }

  # ============================================================================
  # Distribution Statistics
  # ============================================================================
  mean_w <- mean(valid_weights)
  sd_w <- sd(valid_weights)
  results$distribution <- list(
    min = min(valid_weights),
    q1 = unname(quantile(valid_weights, 0.25)),
    median = median(valid_weights),
    q3 = unname(quantile(valid_weights, 0.75)),
    max = max(valid_weights),
    mean = mean_w,
    sd = sd_w,
    cv = if (mean_w > 0) sd_w / mean_w else NA_real_,  # Guard against div/0
    sum = sum(valid_weights)
  )

  # Percentiles
  results$percentiles <- list(
    p5 = unname(quantile(valid_weights, 0.05)),
    p10 = unname(quantile(valid_weights, 0.10)),
    p90 = unname(quantile(valid_weights, 0.90)),
    p95 = unname(quantile(valid_weights, 0.95)),
    p99 = unname(quantile(valid_weights, 0.99))
  )

  # ============================================================================
  # Effective Sample Size
  # ============================================================================
  sum_w <- sum(valid_weights)
  sum_w2 <- sum(valid_weights^2)

  effective_n <- (sum_w^2) / sum_w2
  design_effect <- n_valid / effective_n
  efficiency <- 100 * effective_n / n_valid

  results$effective_sample <- list(
    effective_n = round(effective_n),
    design_effect = design_effect,
    efficiency = efficiency
  )

  # ============================================================================
  # Extreme Weights
  # ============================================================================
  results$extreme_weights <- list(
    n_gt_3 = sum(valid_weights > 3),
    n_gt_5 = sum(valid_weights > 5),
    n_gt_10 = sum(valid_weights > 10),
    pct_gt_3 = 100 * sum(valid_weights > 3) / n_valid,
    pct_gt_5 = 100 * sum(valid_weights > 5) / n_valid,
    pct_gt_10 = 100 * sum(valid_weights > 10) / n_valid
  )

  # ============================================================================
  # Trimming Info (if available)
  # ============================================================================
  if (!is.null(trimming_result)) {
    results$trimming <- list(
      applied = isTRUE(trimming_result$trimming_applied),
      method = trimming_result$method,
      threshold = trimming_result$threshold,
      n_trimmed = trimming_result$n_trimmed,
      pct_trimmed = trimming_result$pct_trimmed,
      original_max = trimming_result$original_max,
      new_max = trimming_result$new_max
    )
  } else {
    results$trimming <- list(applied = FALSE)
  }

  # ============================================================================
  # Rim Weighting Info (if available)
  # ============================================================================
  if (!is.null(rim_result)) {
    results$rim_weighting <- list(
      converged = rim_result$converged,
      iterations = rim_result$iterations,
      margins = rim_result$margins
    )
  }

  # ============================================================================
  # Quality Assessment
  # ============================================================================
  quality <- assess_weight_quality(results)
  results$quality <- quality

  results$valid <- TRUE

  # ============================================================================
  # Output
  # ============================================================================
  if (verbose) {
    print_diagnostics_console(results)
  }

  if (!is.null(save_to_file)) {
    save_diagnostics_to_file(results, save_to_file)
  }

  return(results)
}

#' Assess Weight Quality
#'
#' Provides overall quality assessment with recommendations.
#'
#' @param diagnostics List, diagnostic results from diagnose_weights
#' @return List with quality assessment
#' @keywords internal
assess_weight_quality <- function(diagnostics) {
  issues <- character(0)
  status <- "GOOD"

  # Check design effect
  if (diagnostics$effective_sample$design_effect > 3) {
    status <- "POOR"
    issues <- c(issues, sprintf(
      "High design effect (%.2f > 3). Effective sample size substantially reduced.",
      diagnostics$effective_sample$design_effect
    ))
  } else if (diagnostics$effective_sample$design_effect > 2) {
    if (status == "GOOD") status <- "ACCEPTABLE"
    issues <- c(issues, sprintf(
      "Moderate design effect (%.2f). Some precision loss.",
      diagnostics$effective_sample$design_effect
    ))
  }

  # Check CV
  if (diagnostics$distribution$cv > 1.0) {
    if (status == "GOOD") status <- "ACCEPTABLE"
    issues <- c(issues, sprintf(
      "High weight variability (CV = %.2f). Consider trimming.",
      diagnostics$distribution$cv
    ))
  }

  # Check extreme weights
  if (diagnostics$extreme_weights$pct_gt_5 > 5) {
    if (status == "GOOD") status <- "ACCEPTABLE"
    issues <- c(issues, sprintf(
      "%.1f%% of weights exceed 5. Consider applying weight cap.",
      diagnostics$extreme_weights$pct_gt_5
    ))
  }

  # Check rim convergence (if applicable)
  if (!is.null(diagnostics$rim_weighting) && !diagnostics$rim_weighting$converged) {
    status <- "POOR"
    issues <- c(issues, "Rim weighting did not converge. Targets may not be achieved.")
  }

  # Check NA/zero rates (guard against division by zero)
  n_total <- diagnostics$sample_size$n_total
  if (n_total > 0) {
    na_zero_pct <- 100 * (diagnostics$sample_size$n_na + diagnostics$sample_size$n_zero) / n_total
    if (na_zero_pct > 5) {
      if (status == "GOOD") status <- "ACCEPTABLE"
      issues <- c(issues, sprintf(
        "%.1f%% of cases have NA or zero weights.",
        na_zero_pct
      ))
    }
  }

  # Build recommendations
  recommendations <- character(0)

  if (diagnostics$effective_sample$design_effect > 2) {
    recommendations <- c(recommendations, "Consider trimming extreme weights (e.g., cap at 5)")
  }

  if (!is.null(diagnostics$rim_weighting) && !diagnostics$rim_weighting$converged) {
    recommendations <- c(recommendations,
      "Increase max_iterations or relax convergence_tolerance",
      "Consider reducing number of rim variables"
    )
  }

  if (diagnostics$distribution$max > 10) {
    recommendations <- c(recommendations, "Apply weight trimming to reduce maximum weight")
  }

  return(list(
    status = status,
    issues = issues,
    recommendations = recommendations
  ))
}

#' Print Diagnostics to Console
#'
#' Formats and prints diagnostic results.
#'
#' @param diag List, diagnostic results
#' @keywords internal
print_diagnostics_console <- function(diag) {
  cat("\n")
  cat(strrep("=", 80), "\n")
  cat("WEIGHT DIAGNOSTICS: ", diag$label, "\n")
  cat(strrep("=", 80), "\n")

  if (!isTRUE(diag$valid)) {
    cat("\nSTATUS: INVALID - ", diag$message, "\n")
    return(invisible(NULL))
  }

  # Method info
  if (!is.null(diag$rim_weighting)) {
    cat("\nMETHOD: Rim Weighting\n")
    if (diag$rim_weighting$converged) {
      cat("CONVERGENCE: Converged in ", diag$rim_weighting$iterations, " iterations\n")
    } else {
      cat("CONVERGENCE: NOT CONVERGED after ", diag$rim_weighting$iterations, " iterations\n")
    }
  }

  # Sample size section
  cat("\nSAMPLE SIZE:\n")
  cat(sprintf("  Total cases:              %s\n",
              format(diag$sample_size$n_total, big.mark = ",")))
  cat(sprintf("  Valid weights:            %s (%.1f%%)\n",
              format(diag$sample_size$n_valid, big.mark = ","),
              diag$sample_size$pct_valid))

  if (diag$sample_size$n_na > 0 || diag$sample_size$n_zero > 0) {
    cat(sprintf("  Zero/NA weights:          %d (%.1f%%)\n",
                diag$sample_size$n_na + diag$sample_size$n_zero,
                100 * (diag$sample_size$n_na + diag$sample_size$n_zero) / diag$sample_size$n_total))
  }

  # Distribution section
  cat("\nWEIGHT DISTRIBUTION:\n")
  cat(sprintf("  Min:                      %.4f\n", diag$distribution$min))
  cat(sprintf("  Q1:                       %.4f\n", diag$distribution$q1))
  cat(sprintf("  Median:                   %.4f\n", diag$distribution$median))
  cat(sprintf("  Q3:                       %.4f\n", diag$distribution$q3))
  cat(sprintf("  Max:                      %.4f\n", diag$distribution$max))
  cat(sprintf("  Mean:                     %.4f\n", diag$distribution$mean))
  cat(sprintf("  SD:                       %.4f\n", diag$distribution$sd))
  cat(sprintf("  CV:                       %.4f\n", diag$distribution$cv))

  # Effective sample size section
  cat("\nEFFECTIVE SAMPLE SIZE:\n")
  cat(sprintf("  Effective N:              %s\n",
              format(diag$effective_sample$effective_n, big.mark = ",")))
  cat(sprintf("  Design effect:            %.2f\n", diag$effective_sample$design_effect))
  cat(sprintf("  Efficiency:               %.1f%%",
              diag$effective_sample$efficiency))

  # Quality indicator for efficiency
  if (diag$effective_sample$efficiency >= 80) {
    cat(" GOOD\n")
  } else if (diag$effective_sample$efficiency >= 60) {
    cat(" ACCEPTABLE\n")
  } else {
    cat(" POOR\n")
  }

  # Extreme weights section
  cat("\nEXTREME WEIGHTS:\n")
  cat(sprintf("  Weights > 3:              %d (%.1f%%)\n",
              diag$extreme_weights$n_gt_3, diag$extreme_weights$pct_gt_3))
  cat(sprintf("  Weights > 5:              %d (%.1f%%)\n",
              diag$extreme_weights$n_gt_5, diag$extreme_weights$pct_gt_5))

  # Trimming section (if applied)
  if (isTRUE(diag$trimming$applied)) {
    cat(sprintf("  Trimming applied:         Yes (%s at %.2f)\n",
                diag$trimming$method, diag$trimming$threshold))
    cat(sprintf("  Weights trimmed:          %d (%.1f%%)\n",
                diag$trimming$n_trimmed, diag$trimming$pct_trimmed))
  } else {
    cat("  Trimming applied:         No\n")
  }

  # Rim targets section (if applicable)
  if (!is.null(diag$rim_weighting) && !is.null(diag$rim_weighting$margins)) {
    cat("\nTARGET ACHIEVEMENT:\n")
    cat(sprintf("  %-12s %-15s %8s %8s %8s\n",
                "Variable", "Category", "Target%", "Achieved%", "Diff%"))
    cat(strrep("-", 55), "\n")

    margins <- diag$rim_weighting$margins
    for (i in seq_len(nrow(margins))) {
      row <- margins[i, ]
      cat(sprintf("  %-12s %-15s %8.1f %8.1f %+8.1f\n",
                  row$variable, row$category,
                  row$target_pct, row$achieved_pct, row$diff_pct))
    }
  }

  # Quality assessment section
  cat("\nQUALITY ASSESSMENT: ", diag$quality$status, "\n")

  if (length(diag$quality$issues) > 0) {
    cat("  Issues:\n")
    for (issue in diag$quality$issues) {
      cat("    - ", issue, "\n")
    }
  }

  if (length(diag$quality$recommendations) > 0) {
    cat("  Recommendations:\n")
    for (rec in diag$quality$recommendations) {
      cat("    - ", rec, "\n")
    }
  }

  cat("\n", strrep("=", 80), "\n")
}

#' Save Diagnostics to File
#'
#' Saves diagnostic report to a text file.
#'
#' @param diag List, diagnostic results
#' @param file_path Character, path to output file
#' @keywords internal
save_diagnostics_to_file <- function(diag, file_path) {
  # Capture console output
  output <- capture.output(print_diagnostics_console(diag))

  # Add header
  header <- c(
    paste("TURAS Weighting Module - Diagnostic Report"),
    paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    ""
  )

  # Write to file
  writeLines(c(header, output), con = file_path)

  message("Diagnostics saved to: ", file_path)
}

#' Compare Multiple Weights
#'
#' Compares diagnostics across multiple weight columns.
#'
#' @param weight_list Named list of weight vectors
#' @param verbose Logical, print comparison
#' @return Data frame with comparative metrics
#' @export
compare_weights <- function(weight_list, verbose = TRUE) {

  if (!is.list(weight_list) || length(weight_list) < 2) {
    stop("weight_list must be a list with at least 2 weight vectors", call. = FALSE)
  }

  comparison <- data.frame(
    weight_name = character(0),
    n_valid = integer(0),
    mean = numeric(0),
    cv = numeric(0),
    effective_n = integer(0),
    design_effect = numeric(0),
    efficiency = numeric(0),
    max = numeric(0),
    pct_gt_5 = numeric(0),
    stringsAsFactors = FALSE
  )

  for (name in names(weight_list)) {
    w <- weight_list[[name]]
    diag <- diagnose_weights(w, label = name, verbose = FALSE)

    if (isTRUE(diag$valid)) {
      comparison <- rbind(comparison, data.frame(
        weight_name = name,
        n_valid = diag$sample_size$n_valid,
        mean = round(diag$distribution$mean, 3),
        cv = round(diag$distribution$cv, 3),
        effective_n = diag$effective_sample$effective_n,
        design_effect = round(diag$effective_sample$design_effect, 2),
        efficiency = round(diag$effective_sample$efficiency, 1),
        max = round(diag$distribution$max, 2),
        pct_gt_5 = round(diag$extreme_weights$pct_gt_5, 1),
        stringsAsFactors = FALSE
      ))
    }
  }

  if (verbose && nrow(comparison) > 0) {
    cat("\nWeight Comparison Summary:\n")
    cat(strrep("-", 100), "\n")
    print(comparison, row.names = FALSE)
    cat(strrep("-", 100), "\n")
  }

  return(comparison)
}

#' Get Weight Distribution Histogram Data
#'
#' Prepares data for histogram visualization.
#'
#' @param weights Numeric vector of weights
#' @param bins Integer, number of bins (default: 50)
#' @return Data frame with bin data for plotting
#' @export
get_weight_histogram_data <- function(weights, bins = 50) {
  valid_weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]

  if (length(valid_weights) == 0) {
    return(NULL)
  }

  hist_data <- hist(valid_weights, breaks = bins, plot = FALSE)

  data.frame(
    bin_start = hist_data$breaks[-length(hist_data$breaks)],
    bin_end = hist_data$breaks[-1],
    bin_mid = hist_data$mids,
    count = hist_data$counts,
    density = hist_data$density
  )
}
