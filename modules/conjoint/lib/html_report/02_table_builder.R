# ==============================================================================
# CONJOINT HTML REPORT - TABLE BUILDER
# ==============================================================================
# Builds plain HTML tables (no external deps)
# ==============================================================================

.html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


#' Build Importance Summary Table
#' @keywords internal
build_importance_table <- function(importance) {

  rows <- vapply(seq_len(nrow(importance)), function(i) {
    imp <- importance$Importance[i]
    bar_width <- min(imp, 100)
    sprintf(
      '<tr><td class="cj-label-col">%s</td><td class="cj-num">%.1f%%</td><td><div class="cj-bar-cell"><div class="cj-bar" style="width:%.1f%%"></div></div></td></tr>',
      .html_escape(importance$Attribute[i]), imp, bar_width
    )
  }, character(1))

  paste0(
    '<table class="cj-table"><thead><tr><th>Attribute</th><th>Importance</th><th></th></tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build Utilities Table for an Attribute
#' @keywords internal
build_utilities_table <- function(utilities) {

  rows <- vapply(seq_len(nrow(utilities)), function(i) {
    u <- utilities$Utility[i]
    class <- if (u > 0) "cj-positive" else if (u < 0) "cj-negative" else ""
    baseline <- if (!is.null(utilities$is_baseline) && utilities$is_baseline[i]) ' <span class="cj-baseline">(baseline)</span>' else ""
    sprintf(
      '<tr><td class="cj-label-col">%s%s</td><td class="cj-num %s">%.3f</td></tr>',
      .html_escape(utilities$Level[i]), baseline, class, u
    )
  }, character(1))

  paste0(
    '<table class="cj-table"><thead><tr><th>Level</th><th>Utility</th></tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build Model Fit Table
#' @keywords internal
build_model_fit_table <- function(diagnostics, model_result) {

  metrics <- list()

  if (!is.null(diagnostics$fit_statistics)) {
    fs <- diagnostics$fit_statistics
    metrics[["McFadden R\u00b2"]] <- sprintf("%.4f", fs$mcfadden_r2 %||% NA)
    metrics[["Hit Rate"]] <- sprintf("%.1f%%", (fs$hit_rate %||% 0) * 100)
    metrics[["Log-Likelihood"]] <- sprintf("%.2f", fs$log_likelihood %||% NA)
  }

  metrics[["Method"]] <- model_result$method %||% "N/A"
  metrics[["Observations"]] <- as.character(model_result$n_obs %||% "N/A")
  metrics[["Converged"]] <- if (!is.null(model_result$convergence$converged))
    ifelse(model_result$convergence$converged, "Yes", "No") else "N/A"

  rows <- vapply(names(metrics), function(m) {
    sprintf('<tr><td class="cj-label-col">%s</td><td class="cj-num">%s</td></tr>', m, metrics[[m]])
  }, character(1))

  paste0(
    '<table class="cj-table"><thead><tr><th>Metric</th><th>Value</th></tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build HB Convergence Table
#' @keywords internal
build_convergence_table <- function(convergence) {

  if (is.null(convergence$geweke_z)) return("")

  param_names <- names(convergence$geweke_z)
  rows <- vapply(seq_along(param_names), function(i) {
    gz <- convergence$geweke_z[i]
    ess <- convergence$effective_sample_size[i]
    gz_class <- if (abs(gz) < 1.96) "cj-positive" else "cj-negative"
    ess_class <- if (ess > 100) "cj-positive" else "cj-negative"
    sprintf(
      '<tr><td class="cj-label-col">%s</td><td class="cj-num %s">%.2f</td><td class="cj-num %s">%.0f</td></tr>',
      .html_escape(param_names[i]), gz_class, gz, ess_class, ess
    )
  }, character(1))

  paste0(
    '<table class="cj-table"><thead><tr><th>Parameter</th><th>Geweke z</th><th>ESS</th></tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}


#' Build LC Comparison Table
#' @keywords internal
build_lc_comparison_table <- function(comparison, optimal_k) {

  if (is.null(comparison) || nrow(comparison) == 0) return("")

  rows <- vapply(seq_len(nrow(comparison)), function(i) {
    k <- comparison$K[i]
    highlight <- if (k == optimal_k) ' class="cj-highlight-row"' else ""
    sprintf(
      '<tr%s><td class="cj-num">%d</td><td class="cj-num">%.1f</td><td class="cj-num">%.1f</td><td class="cj-num">%.3f</td></tr>',
      highlight, k, comparison$AIC[i], comparison$BIC[i], comparison$Entropy_R2[i]
    )
  }, character(1))

  paste0(
    '<table class="cj-table"><thead><tr><th>K</th><th>AIC</th><th>BIC</th><th>Entropy R\u00b2</th></tr></thead><tbody>',
    paste(rows, collapse = "\n"),
    '</tbody></table>'
  )
}
