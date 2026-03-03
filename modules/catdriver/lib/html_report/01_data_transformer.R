# ==============================================================================
# CATDRIVER HTML REPORT - DATA TRANSFORMER
# ==============================================================================
# Restructures analysis results into HTML-friendly format.
# Pure data transformation — no HTML generation here.
# ==============================================================================

#' Transform Catdriver Results for HTML Rendering
#'
#' Converts the raw results list into a structured format optimised for
#' HTML table and chart generation.
#'
#' @param results Analysis results from run_categorical_keydriver()
#' @param config Configuration list
#' @return List with transformed data for each report section
#' @keywords internal
transform_catdriver_for_html <- function(results, config) {

  # Executive summary text
  summary_lines <- generate_executive_summary(results, config)

  # Transform importance data
  imp_df <- results$importance
  importance <- lapply(seq_len(nrow(imp_df)), function(i) {
    row <- imp_df[i, ]
    list(
      rank = row$rank,
      variable = row$variable,
      label = row$label,
      importance_pct = if (is.na(row$importance_pct)) 0 else as.numeric(row$importance_pct),
      chi_square = if (is.na(row$chi_square)) 0 else round(row$chi_square, 2),
      p_value = row$p_value,
      p_formatted = if (is.na(row$p_value)) "n/a" else format_pvalue(row$p_value),
      significance = if (is.null(row$significance) || is.na(row$significance)) "" else row$significance,
      effect_size = if (is.null(row$effect_size) || is.na(row$effect_size)) "" else row$effect_size
    )
  })

  # Transform factor patterns
  patterns <- list()
  for (var_name in config$driver_vars) {
    pat <- results$factor_patterns[[var_name]]
    if (is.null(pat)) next

    pat_df <- pat$patterns
    outcome_cols <- grep("^pct_", names(pat_df), value = TRUE)
    outcome_names <- sub("^pct_", "", outcome_cols)

    categories <- lapply(seq_len(nrow(pat_df)), function(i) {
      r <- pat_df[i, ]
      outcome_pcts <- setNames(
        as.numeric(pat_df[i, outcome_cols]),
        outcome_names
      )
      list(
        category = r$category,
        n = r$n,
        pct_of_total = as.numeric(r$pct_of_total),
        is_reference = r$is_reference,
        outcome_pcts = outcome_pcts,
        odds_ratio = if (r$is_reference) 1.0 else r$odds_ratio,
        or_lower = if (r$is_reference) NA else r$or_lower,
        or_upper = if (r$is_reference) NA else r$or_upper,
        effect = r$effect %||% ""
      )
    })

    patterns[[var_name]] <- list(
      label = pat$label,
      variable = var_name,
      reference = pat$reference,
      outcome_categories = outcome_names,
      categories = categories
    )
  }

  # Transform odds ratios
  or_df <- results$odds_ratios
  has_bootstrap <- "boot_median_or" %in% names(or_df) && any(!is.na(or_df$boot_median_or))

  odds_ratios <- lapply(seq_len(nrow(or_df)), function(i) {
    r <- or_df[i, ]
    entry <- list(
      factor_label = r$factor_label,
      comparison = r$comparison,
      reference = r$reference,
      or_value = suppressWarnings(as.numeric(gsub("[^0-9.]", "", r$or_formatted))),
      or_formatted = r$or_formatted,
      ci_formatted = r$ci_formatted,
      p_formatted = r$p_formatted,
      significance = r$significance %||% "",
      effect = r$effect %||% ""
    )
    if (has_bootstrap) {
      entry$boot_median_or <- r$boot_median_or
      entry$boot_ci_lower <- r$boot_ci_lower
      entry$boot_ci_upper <- r$boot_ci_upper
      entry$sign_stability <- r$sign_stability
    }
    if ("outcome_level" %in% names(or_df)) {
      entry$outcome_level <- r$outcome_level
    }
    entry
  })

  # Transform diagnostics
  diag <- results$diagnostics
  diagnostics <- list(
    original_n = diag$original_n,
    complete_n = diag$complete_n,
    analysis_n = diag$analysis_n %||% diag$complete_n,
    pct_complete = diag$pct_complete,
    convergence = results$model_result$convergence,
    has_small_cells = length(diag$small_cells) > 0,
    n_small_cell_vars = length(diag$small_cells),
    warnings = diag$warnings %||% character(0),
    missing_summary = diag$missing_summary
  )

  # Model info
  model_info <- list(
    outcome_type = results$model_result$outcome_type %||% results$prep_data$outcome_info$type,
    outcome_label = config$outcome_label,
    outcome_categories = results$prep_data$outcome_info$categories,
    n_categories = results$prep_data$outcome_info$n_categories,
    n_drivers = length(config$driver_vars),
    n_terms = results$prep_data$n_terms,
    fit_statistics = results$model_result$fit_statistics,
    has_bootstrap = has_bootstrap,
    weight_var = config$weight_var,
    weight_diagnostics = results$weight_diagnostics
  )

  list(
    summary_lines = summary_lines,
    importance = importance,
    patterns = patterns,
    odds_ratios = odds_ratios,
    diagnostics = diagnostics,
    model_info = model_info,
    has_bootstrap = has_bootstrap,
    analysis_name = config$analysis_name %||% "Categorical Key Driver Analysis",
    run_status = results$run_status %||% "PASS",
    degraded = isTRUE(results$degraded),
    degraded_reasons = results$degraded_reasons %||% character(0)
  )
}
