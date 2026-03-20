# ==============================================================================
# TURAS PRICING MODULE - SEGMENT ANALYSIS WRAPPER
# ==============================================================================
#
# Purpose: Run any pricing method across segments and produce comparison output
# Version: 12.0
# Date: 2025-12-11
#
# ==============================================================================

#' Run Pricing Analysis Across Segments
#'
#' Executes specified pricing method for each segment and compiles
#' comparison table with insight flags.
#'
#' @param data Data frame containing pricing data with segment column
#' @param config Configuration list (must include segmentation settings)
#' @param method Analysis method: "van_westendorp" or "gabor_granger"
#'
#' @return List containing total_results, segment_results, comparison_table,
#'         insights, diagnostics
#'
#' @export
run_segmented_analysis <- function(data, config, method) {

  # ============================================================================
  # STEP 1: Validate inputs
  # ============================================================================

  seg_config <- config$segmentation

  if (is.null(seg_config$segment_column) || is.na(seg_config$segment_column)) {
    pricing_refuse(
      code = "CFG_MISSING_SEGMENT_COLUMN",
      title = "Segment Column Not Specified",
      problem = "No segment_column specified in segmentation configuration",
      why_it_matters = "Cannot run segmented analysis without knowing which column contains segment definitions",
      how_to_fix = "Add 'segment_column' to the Segmentation sheet in your configuration",
      expected = "segment_column setting"
    )
  }

  seg_col <- seg_config$segment_column

  if (!seg_col %in% names(data)) {
    pricing_refuse(
      code = "DATA_SEGMENT_COLUMN_MISSING",
      title = "Segment Column Not Found",
      problem = sprintf("Segment column '%s' not found in data", seg_col),
      why_it_matters = "Cannot segment data without the specified segment variable",
      how_to_fix = c(
        "Verify segment_column name matches data exactly (case-sensitive)",
        "Check that the column exists in your data file"
      ),
      observed = names(data),
      expected = seg_col
    )
  }

  min_n <- seg_config$min_segment_n %||% 50
  include_total <- seg_config$include_total %||% TRUE

  # Validate method
  valid_methods <- c("van_westendorp", "gabor_granger")
  if (!method %in% valid_methods) {
    pricing_refuse(
      code = "CFG_INVALID_SEGMENT_METHOD",
      title = "Invalid Segmentation Method",
      problem = sprintf("Method '%s' is not recognized", method),
      why_it_matters = "Cannot run segmented analysis with unknown methodology",
      how_to_fix = c(
        "Specify method as one of:",
        "  - 'van_westendorp' for price sensitivity meter",
        "  - 'gabor_granger' for demand curve analysis"
      ),
      observed = method,
      expected = valid_methods
    )
  }

  # ============================================================================
  # STEP 2: Get segment information
  # ============================================================================

  segments <- unique(data[[seg_col]])
  segments <- segments[!is.na(segments)]

  segment_counts <- table(data[[seg_col]])

  # Identify segments to skip
  skip_segments <- names(segment_counts)[segment_counts < min_n]
  run_segments <- names(segment_counts)[segment_counts >= min_n]

  if (length(run_segments) == 0) {
    pricing_refuse(
      code = "DATA_NO_VALID_SEGMENTS",
      title = "No Segments Meet Minimum Size",
      problem = sprintf("No segments have at least %d respondents", min_n),
      why_it_matters = "Cannot run analysis on segments that are too small for reliable results",
      how_to_fix = c(
        "Lower min_segment_n in Segmentation configuration",
        "Combine small segments into larger groups",
        "Collect more data to increase segment sizes"
      ),
      observed = sprintf("Segment counts: %s", paste(names(segment_counts), segment_counts, sep = "=", collapse = ", ")),
      expected = sprintf("At least one segment with n >= %d", min_n)
    )
  }

  if (length(skip_segments) > 0) {
    warning(sprintf("Skipping segments with n < %d: %s",
                    min_n, paste(skip_segments, collapse = ", ")),
            call. = FALSE)
  }

  # ============================================================================
  # STEP 3: Run analysis for total sample
  # ============================================================================

  total_results <- NULL

  if (include_total) {
    total_results <- run_pricing_method(data, config, method)
  }

  # ============================================================================
  # STEP 4: Run analysis for each segment
  # ============================================================================

  segment_results <- list()

  for (seg in run_segments) {
    seg_data <- data[data[[seg_col]] == seg, , drop = FALSE]

    tryCatch({
      segment_results[[seg]] <- run_pricing_method(seg_data, config, method)
      segment_results[[seg]]$segment_name <- seg
      segment_results[[seg]]$segment_n <- nrow(seg_data)
    }, error = function(e) {
      warning(sprintf("Error in segment '%s': %s", seg, e$message), call. = FALSE)
      segment_results[[seg]] <<- list(
        error = e$message,
        segment_name = seg,
        segment_n = nrow(seg_data)
      )
    })
  }

  # ============================================================================
  # STEP 5: Build comparison table
  # ============================================================================

  comparison_table <- build_segment_comparison(
    total_results = total_results,
    segment_results = segment_results,
    method = method,
    include_total = include_total
  )

  # ============================================================================
  # STEP 6: Generate insights
  # ============================================================================

  insights <- generate_segment_insights(
    comparison_table = comparison_table,
    method = method
  )

  # ============================================================================
  # STEP 7: Compile diagnostics
  # ============================================================================

  diagnostics <- list(
    segment_column = seg_col,
    segments_analyzed = run_segments,
    segments_skipped = skip_segments,
    segment_counts = as.list(segment_counts),
    min_n_threshold = min_n,
    method = method
  )

  # ============================================================================
  # STEP 8: Return results
  # ============================================================================

  list(
    total_results = total_results,
    segment_results = segment_results,
    comparison_table = comparison_table,
    insights = insights,
    diagnostics = diagnostics
  )
}


#' Run Specified Pricing Method
#'
#' @param data Data frame
#' @param config Configuration
#' @param method Method name
#' @return Method results
#' @keywords internal
run_pricing_method <- function(data, config, method) {
  switch(method,
    van_westendorp = run_van_westendorp(data, config),
    gabor_granger = run_gabor_granger(data, config),
    pricing_refuse(
      code = "CFG_INVALID_METHOD",
      title = "Unknown Analysis Method",
      problem = sprintf("Method '%s' is not recognized", method),
      why_it_matters = "Cannot run analysis with unknown methodology",
      how_to_fix = c(
        "Use 'van_westendorp' or 'gabor_granger'"
      ),
      observed = method,
      expected = c("van_westendorp", "gabor_granger")
    )
  )
}


#' Build Segment Comparison Table
#'
#' @param total_results Results for total sample (or NULL)
#' @param segment_results Named list of segment results
#' @param method Analysis method
#' @param include_total Include total row
#' @return Data frame with comparison metrics
#' @keywords internal
build_segment_comparison <- function(total_results, segment_results,
                                     method, include_total) {

  # Define extraction function based on method
  if (method == "van_westendorp") {
    extract_row <- function(res, label) {
      if (!is.null(res$error)) {
        return(data.frame(
          segment = label,
          n = res$segment_n,
          PMC = NA, OPP = NA, IDP = NA, PME = NA,
          range_width = NA, optimal_width = NA,
          stringsAsFactors = FALSE
        ))
      }

      data.frame(
        segment = label,
        n = res$diagnostics$n_valid,
        PMC = round(res$price_points$PMC, 2),
        OPP = round(res$price_points$OPP, 2),
        IDP = round(res$price_points$IDP, 2),
        PME = round(res$price_points$PME, 2),
        range_width = round(res$acceptable_range$width, 2),
        optimal_width = round(res$optimal_range$width, 2),
        stringsAsFactors = FALSE
      )
    }
  } else if (method == "gabor_granger") {
    extract_row <- function(res, label) {
      if (!is.null(res$error)) {
        return(data.frame(
          segment = label,
          n = res$segment_n,
          optimal_price = NA, purchase_intent = NA,
          revenue_index = NA, elasticity_avg = NA,
          stringsAsFactors = FALSE
        ))
      }

      # Calculate average elasticity
      avg_elast <- NA
      if (!is.null(res$elasticity)) {
        avg_elast <- round(mean(res$elasticity$arc_elasticity, na.rm = TRUE), 2)
      }

      data.frame(
        segment = label,
        n = res$diagnostics$n_respondents,
        optimal_price = round(res$optimal_price$price, 2),
        purchase_intent = round(res$optimal_price$purchase_intent * 100, 1),
        revenue_index = round(res$optimal_price$revenue_index, 2),
        elasticity_avg = avg_elast,
        stringsAsFactors = FALSE
      )
    }
  }

  # Build table
  rows <- list()

  if (include_total && !is.null(total_results)) {
    rows[["Total"]] <- extract_row(total_results, "Total")
  }

  for (seg_name in names(segment_results)) {
    rows[[seg_name]] <- extract_row(segment_results[[seg_name]], seg_name)
  }

  do.call(rbind, rows)
}


#' Generate Segment Insights
#'
#' Automatically flags notable differences between segments.
#'
#' @param comparison_table Comparison data frame
#' @param method Analysis method
#' @return Character vector of insight statements
#' @keywords internal
generate_segment_insights <- function(comparison_table, method) {

  insights <- character(0)

  # Remove total row for comparisons
  seg_data <- comparison_table[comparison_table$segment != "Total", ]

  if (nrow(seg_data) < 2) {
    return("Only one segment analyzed - no comparison possible.")
  }

  if (method == "van_westendorp") {

    # Check for non-overlapping ranges
    for (i in 1:(nrow(seg_data) - 1)) {
      for (j in (i + 1):nrow(seg_data)) {
        seg_i <- seg_data$segment[i]
        seg_j <- seg_data$segment[j]

        # Check if acceptable ranges overlap
        range_i <- c(seg_data$PMC[i], seg_data$PME[i])
        range_j <- c(seg_data$PMC[j], seg_data$PME[j])

        if (!any(is.na(range_i)) && !any(is.na(range_j))) {
          overlap <- min(range_i[2], range_j[2]) - max(range_i[1], range_j[1])

          if (overlap < 0) {
            insights <- c(insights, sprintf(
              "%s and %s have non-overlapping acceptable ranges - distinct pricing tiers warranted.",
              seg_i, seg_j
            ))
          }
        }
      }
    }

    # Identify highest and lowest optimal prices
    if (!all(is.na(seg_data$OPP))) {
      max_seg <- seg_data$segment[which.max(seg_data$OPP)]
      min_seg <- seg_data$segment[which.min(seg_data$OPP)]
      max_opp <- max(seg_data$OPP, na.rm = TRUE)
      min_opp <- min(seg_data$OPP, na.rm = TRUE)

      if (max_opp > min_opp * 1.2) {  # >20% difference
        insights <- c(insights, sprintf(
          "%s supports %.0f%% higher pricing than %s ($%.2f vs $%.2f optimal).",
          max_seg, (max_opp / min_opp - 1) * 100, min_seg, max_opp, min_opp
        ))
      }
    }

    # Check range width variation
    if (!all(is.na(seg_data$range_width))) {
      max_width <- max(seg_data$range_width, na.rm = TRUE)
      min_width <- min(seg_data$range_width, na.rm = TRUE)

      if (max_width > min_width * 1.5) {  # >50% difference
        narrow_seg <- seg_data$segment[which.min(seg_data$range_width)]
        insights <- c(insights, sprintf(
          "%s has narrow price tolerance - pricing requires precision.",
          narrow_seg
        ))
      }
    }

  } else if (method == "gabor_granger") {

    # Compare elasticity
    if (!all(is.na(seg_data$elasticity_avg))) {
      for (i in 1:nrow(seg_data)) {
        elast <- seg_data$elasticity_avg[i]
        seg <- seg_data$segment[i]

        if (!is.na(elast)) {
          if (elast > -1) {
            insights <- c(insights, sprintf(
              "%s shows inelastic demand (E=%.1f) - can sustain higher prices.",
              seg, elast
            ))
          } else if (elast < -2) {
            insights <- c(insights, sprintf(
              "%s is highly price-sensitive (E=%.1f) - price increases risky.",
              seg, elast
            ))
          }
        }
      }
    }

    # Compare optimal prices
    if (!all(is.na(seg_data$optimal_price))) {
      max_seg <- seg_data$segment[which.max(seg_data$optimal_price)]
      min_seg <- seg_data$segment[which.min(seg_data$optimal_price)]
      max_price <- max(seg_data$optimal_price, na.rm = TRUE)
      min_price <- min(seg_data$optimal_price, na.rm = TRUE)

      if (max_price > min_price * 1.15) {  # >15% difference
        insights <- c(insights, sprintf(
          "Optimal price for %s ($%.2f) is %.0f%% higher than %s ($%.2f).",
          max_seg, max_price, (max_price / min_price - 1) * 100, min_seg, min_price
        ))
      }
    }
  }

  if (length(insights) == 0) {
    insights <- "Segments show similar price sensitivity - uniform pricing may be appropriate."
  }

  return(insights)
}


#' Statistical Tests for Segment Price Differences
#'
#' Tests whether pricing metrics differ significantly between segments
#' using permutation tests (non-parametric, no distributional assumptions).
#'
#' @param data Data frame with respondent-level data
#' @param config Configuration list (must include segmentation settings)
#' @param metric Column name to test (e.g., "cheap", "expensive", "wtp")
#' @param method Test method: "permutation" (default) or "bootstrap_ci"
#' @param n_perm Number of permutations for permutation test (default 1000)
#' @param conf_level Confidence level for bootstrap CIs (default 0.95)
#'
#' @return List with:
#'   \item{pairwise}{Data frame of pairwise comparisons with p-values}
#'   \item{overall}{Overall test result (Kruskal-Wallis p-value)}
#'   \item{summary}{Summary with segment means and CIs}
#'   \item{significant_pairs}{Character vector of significantly different pairs}
#'
#' @details
#' For each pair of segments, a two-sided permutation test compares the
#' difference in weighted means against the null distribution obtained by
#' randomly reassigning segment labels. This avoids parametric assumptions
#' that are often violated in pricing data (skewed WTP distributions, etc.).
#'
#' An overall Kruskal-Wallis test is also reported as a global significance
#' check. P-values are adjusted for multiple comparisons using the
#' Holm-Bonferroni method.
#'
#' @export
test_segment_differences <- function(data,
                                     config,
                                     metric,
                                     method = c("permutation", "bootstrap_ci"),
                                     n_perm = 1000,
                                     conf_level = 0.95) {

  method <- match.arg(method)

  # --- Validate inputs ---
  seg_col <- config$segmentation$segment_column
  if (is.null(seg_col) || is.na(seg_col)) {
    pricing_refuse(
      code = "CFG_MISSING_SEGMENT_COLUMN",
      title = "Segment Column Not Specified",
      problem = "No segment_column specified in segmentation configuration",
      why_it_matters = "Cannot test segment differences without segment definitions",
      how_to_fix = "Add 'segment_column' to the Segmentation sheet in your configuration",
      expected = "segment_column setting"
    )
  }

  if (!seg_col %in% names(data)) {
    pricing_refuse(
      code = "DATA_SEGMENT_COLUMN_MISSING",
      title = "Segment Column Not Found",
      problem = sprintf("Segment column '%s' not found in data", seg_col),
      why_it_matters = "Cannot segment data without the specified segment variable",
      how_to_fix = "Verify segment_column name matches data exactly (case-sensitive)",
      observed = names(data),
      expected = seg_col
    )
  }

  if (!metric %in% names(data)) {
    pricing_refuse(
      code = "DATA_METRIC_COLUMN_MISSING",
      title = "Metric Column Not Found",
      problem = sprintf("Metric column '%s' not found in data", metric),
      why_it_matters = "Cannot test differences on a variable that doesn't exist",
      how_to_fix = sprintf("Ensure '%s' exists in the data", metric),
      observed = names(data),
      expected = metric
    )
  }

  # --- Prepare data ---
  weight_col <- config$weight_var %||% config$segmentation$weight_var
  has_weights <- !is.null(weight_col) && !is.na(weight_col) && weight_col %in% names(data)

  # Subset to non-NA metric values
  df <- data[!is.na(data[[metric]]) & !is.na(data[[seg_col]]), , drop = FALSE]
  df$.metric <- as.numeric(df[[metric]])
  df$.segment <- as.character(df[[seg_col]])
  df$.weight <- if (has_weights) df[[weight_col]] else rep(1, nrow(df))

  segments <- sort(unique(df$.segment))
  if (length(segments) < 2) {
    pricing_refuse(
      code = "DATA_INSUFFICIENT_SEGMENTS",
      title = "Not Enough Segments",
      problem = sprintf("Need at least 2 segments, found %d", length(segments)),
      why_it_matters = "Cannot compare segments without at least two groups",
      how_to_fix = "Ensure data contains at least 2 distinct segment values",
      expected = "2+ segments"
    )
  }

  # --- Weighted mean helper ---
  wmean <- function(x, w) {
    valid <- !is.na(x) & !is.na(w)
    sum(x[valid] * w[valid]) / sum(w[valid])
  }

  # --- Overall test: Kruskal-Wallis ---
  kw_result <- tryCatch({
    kruskal.test(df$.metric, factor(df$.segment))
  }, error = function(e) NULL)

  overall_p <- if (!is.null(kw_result)) kw_result$p.value else NA_real_

  # --- Pairwise permutation tests ---
  pairs <- combn(segments, 2, simplify = FALSE)
  pairwise_results <- vector("list", length(pairs))

  set.seed(42)  # Reproducibility

  for (k in seq_along(pairs)) {
    seg_a <- pairs[[k]][1]
    seg_b <- pairs[[k]][2]

    da <- df[df$.segment == seg_a, ]
    db <- df[df$.segment == seg_b, ]

    mean_a <- wmean(da$.metric, da$.weight)
    mean_b <- wmean(db$.metric, db$.weight)
    observed_diff <- mean_a - mean_b

    if (method == "permutation") {
      # Pool the two segments and permute labels
      pooled <- rbind(da, db)
      n_a <- nrow(da)
      n_total <- nrow(pooled)

      perm_diffs <- numeric(n_perm)
      for (p in seq_len(n_perm)) {
        perm_idx <- sample.int(n_total, n_a)
        perm_a <- pooled[perm_idx, ]
        perm_b <- pooled[-perm_idx, ]
        perm_diffs[p] <- wmean(perm_a$.metric, perm_a$.weight) -
          wmean(perm_b$.metric, perm_b$.weight)
      }

      # Two-sided p-value
      p_value <- mean(abs(perm_diffs) >= abs(observed_diff))

      pairwise_results[[k]] <- data.frame(
        segment_a = seg_a,
        segment_b = seg_b,
        mean_a = round(mean_a, 2),
        mean_b = round(mean_b, 2),
        diff = round(observed_diff, 2),
        p_value = round(p_value, 4),
        stringsAsFactors = FALSE
      )

    } else {
      # Bootstrap CI for difference in means
      boot_diffs <- numeric(n_perm)
      for (b in seq_len(n_perm)) {
        idx_a <- sample.int(nrow(da), replace = TRUE)
        idx_b <- sample.int(nrow(db), replace = TRUE)
        boot_diffs[b] <- wmean(da$.metric[idx_a], da$.weight[idx_a]) -
          wmean(db$.metric[idx_b], db$.weight[idx_b])
      }

      alpha <- 1 - conf_level
      ci_lo <- quantile(boot_diffs, alpha / 2)
      ci_hi <- quantile(boot_diffs, 1 - alpha / 2)
      # Significant if CI excludes zero
      significant <- !(ci_lo <= 0 && ci_hi >= 0)

      pairwise_results[[k]] <- data.frame(
        segment_a = seg_a,
        segment_b = seg_b,
        mean_a = round(mean_a, 2),
        mean_b = round(mean_b, 2),
        diff = round(observed_diff, 2),
        ci_lower = round(ci_lo, 2),
        ci_upper = round(ci_hi, 2),
        significant = significant,
        stringsAsFactors = FALSE
      )
    }
  }

  pairwise <- do.call(rbind, pairwise_results)

  # Adjust p-values for multiple comparisons (Holm-Bonferroni)
  if ("p_value" %in% names(pairwise)) {
    pairwise$p_adjusted <- round(p.adjust(pairwise$p_value, method = "holm"), 4)
    pairwise$significant <- pairwise$p_adjusted < (1 - conf_level)
  }

  # --- Segment summary with bootstrap CIs ---
  summary_rows <- lapply(segments, function(seg) {
    d <- df[df$.segment == seg, ]
    seg_mean <- wmean(d$.metric, d$.weight)

    # Bootstrap CI for segment mean
    boot_means <- numeric(n_perm)
    for (b in seq_len(n_perm)) {
      idx <- sample.int(nrow(d), replace = TRUE)
      boot_means[b] <- wmean(d$.metric[idx], d$.weight[idx])
    }

    alpha <- 1 - conf_level
    data.frame(
      segment = seg,
      n = nrow(d),
      mean = round(seg_mean, 2),
      ci_lower = round(quantile(boot_means, alpha / 2), 2),
      ci_upper = round(quantile(boot_means, 1 - alpha / 2), 2),
      sd = round(sqrt(sum(d$.weight * (d$.metric - seg_mean)^2) / sum(d$.weight)), 2),
      stringsAsFactors = FALSE
    )
  })
  summary_df <- do.call(rbind, summary_rows)

  # --- Significant pairs ---
  sig_pairs <- character(0)
  if ("significant" %in% names(pairwise)) {
    sig_rows <- pairwise[pairwise$significant, ]
    if (nrow(sig_rows) > 0) {
      sig_pairs <- sprintf("%s vs %s", sig_rows$segment_a, sig_rows$segment_b)
    }
  }

  list(
    pairwise = pairwise,
    overall = list(
      test = "Kruskal-Wallis",
      p_value = round(overall_p, 4),
      significant = !is.na(overall_p) && overall_p < (1 - conf_level)
    ),
    summary = summary_df,
    significant_pairs = sig_pairs,
    metric = metric,
    method = method,
    n_permutations = n_perm,
    conf_level = conf_level
  )
}


# Helper operator for default values (if not already defined)
if (!exists("%||%")) {
  `%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
  }
}
