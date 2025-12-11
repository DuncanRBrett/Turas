# ==============================================================================
# TURAS PRICING MODULE - SEGMENT ANALYSIS WRAPPER
# ==============================================================================
#
# Purpose: Run any pricing method across segments and produce comparison output
# Version: 1.0.0
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
    stop("segment_column must be specified in configuration", call. = FALSE)
  }

  seg_col <- seg_config$segment_column

  if (!seg_col %in% names(data)) {
    stop(sprintf("Segment column '%s' not found. Available: %s",
                 seg_col, paste(names(data), collapse = ", ")),
         call. = FALSE)
  }

  min_n <- seg_config$min_segment_n %||% 50
  include_total <- seg_config$include_total %||% TRUE

  # Validate method
  valid_methods <- c("van_westendorp", "gabor_granger")
  if (!method %in% valid_methods) {
    stop(sprintf("Method must be one of: %s", paste(valid_methods, collapse = ", ")),
         call. = FALSE)
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
    stop(sprintf("No segments have n >= %d. Counts: %s",
                 min_n,
                 paste(names(segment_counts), segment_counts, sep = "=", collapse = ", ")),
         call. = FALSE)
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
    stop(sprintf("Unknown method: %s", method), call. = FALSE)
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


# Helper operator for default values (if not already defined)
if (!exists("%||%")) {
  `%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
  }
}
