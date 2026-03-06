# ==============================================================================
# WEIGHTING HTML REPORT - DATA TRANSFORMER
# ==============================================================================

#' Transform Weighting Results for HTML
#'
#' Converts run_weighting() output into HTML-ready structures.
#'
#' @param weighting_results List from run_weighting()
#' @param config List, report config (brand_colour, accent_colour, etc.)
#' @return List with $summary, $weight_details, $notes
#' @keywords internal
transform_for_html <- function(weighting_results, config = list()) {

  # Build summary data
  summary <- list(
    project_name = weighting_results$config$general$project_name %||% "Weighting Report",
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    n_records = nrow(weighting_results$data),
    n_weights = length(weighting_results$weight_names),
    weight_names = weighting_results$weight_names
  )

  # Build per-weight detail data
  weight_details <- list()
  for (wn in weighting_results$weight_names) {
    wr <- weighting_results$weight_results[[wn]]
    spec <- weighting_results$config$weight_specifications
    method <- spec$method[spec$weight_name == wn]

    detail <- list(
      weight_name = wn,
      method = method,
      diagnostics = wr$diagnostics,
      weights = wr$weights
    )

    # Rim-specific data
    if (!is.null(wr$rim_result)) {
      detail$margins <- wr$rim_result$margins
      detail$rim_variables <- wr$rim_result$rim_variables
    }

    # Design-specific data
    if (!is.null(wr$design_result)) {
      detail$stratum_summary <- wr$design_result$stratum_summary
      detail$stratum_variable <- wr$design_result$stratum_variable
    }

    # Cell-specific data
    if (!is.null(wr$cell_result)) {
      detail$cell_summary <- wr$cell_result$cell_summary
      detail$cell_variables <- wr$cell_result$cell_variables
    }

    # Trimming data
    if (!is.null(wr$trimming_result) && isTRUE(wr$trimming_result$trimming_applied)) {
      detail$trimming <- wr$trimming_result
    }

    weight_details[[wn]] <- detail
  }

  # Notes
  notes <- weighting_results$config$notes

  return(list(
    summary = summary,
    weight_details = weight_details,
    notes = notes
  ))
}

#' Build Weight Distribution Data for SVG Chart
#'
#' @param weights Numeric vector of weights
#' @param n_bins Integer, number of histogram bins (default: 20)
#' @return Data frame with bin_start, bin_end, count, pct
#' @keywords internal
build_histogram_data <- function(weights, n_bins = 20) {
  valid <- weights[!is.na(weights) & is.finite(weights)]
  if (length(valid) < 2) return(NULL)

  breaks <- seq(min(valid), max(valid), length.out = n_bins + 1)
  h <- hist(valid, breaks = breaks, plot = FALSE)

  data.frame(
    bin_start = h$breaks[-length(h$breaks)],
    bin_end = h$breaks[-1],
    bin_mid = h$mids,
    count = h$counts,
    pct = round(100 * h$counts / sum(h$counts), 1),
    stringsAsFactors = FALSE
  )
}
