# ==============================================================================
# CONJOINT HTML REPORT - DATA TRANSFORMER
# ==============================================================================
# Transforms conjoint results into HTML-ready data structure
# ==============================================================================

#' Transform Conjoint Results for HTML Report
#'
#' @param conjoint_results List with utilities, importance, model_result, config, etc.
#' @param config Report config
#' @return List with summary, utilities_data, importance_data, diagnostics_data, etc.
#' @keywords internal
transform_conjoint_for_html <- function(conjoint_results, config = list()) {

  model_result <- conjoint_results$model_result
  utilities <- conjoint_results$utilities
  importance <- conjoint_results$importance
  diagnostics <- conjoint_results$diagnostics
  module_config <- conjoint_results$config

  method <- if (!is.null(model_result$method)) model_result$method else "unknown"
  n_respondents <- model_result$n_respondents %||% NA
  n_attributes <- length(unique(utilities$Attribute))
  n_levels <- nrow(utilities)

  # Summary
  summary <- list(
    project_name = config$project_name %||% module_config$project_name %||% "Conjoint Analysis",
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    estimation_method = method,
    n_respondents = n_respondents,
    n_attributes = n_attributes,
    n_levels = n_levels,
    n_choice_sets = model_result$n_choice_sets %||% NA,
    converged = if (!is.null(model_result$convergence)) model_result$convergence$converged else NA
  )

  # Utilities by attribute (for grouped charts)
  utilities_by_attr <- split(utilities, utilities$Attribute)

  # HB-specific data
  hb_data <- NULL
  if (method %in% c("hierarchical_bayes", "latent_class")) {
    hb_data <- list(
      has_individual = !is.null(model_result$individual_betas),
      n_draws = model_result$hb_settings$n_draws_retained %||% NA,
      iterations = model_result$hb_settings$iterations %||% NA,
      burnin = model_result$hb_settings$burnin %||% NA,
      convergence = model_result$convergence
    )

    if (!is.null(model_result$respondent_quality)) {
      hb_data$quality <- list(
        mean_rlh = model_result$respondent_quality$mean_rlh,
        n_flagged = model_result$respondent_quality$n_flagged,
        chance_rlh = model_result$respondent_quality$chance_rlh
      )
    }
  }

  # Latent class data
  lc_data <- NULL
  if (!is.null(model_result$latent_class)) {
    lc <- model_result$latent_class
    lc_data <- list(
      optimal_k = lc$optimal_k,
      class_sizes = lc$class_sizes,
      class_proportions = lc$class_proportions,
      entropy_r2 = lc$entropy_r2,
      comparison = lc$comparison,
      class_importance = lc$class_importance
    )
  }

  list(
    summary = summary,
    utilities = utilities,
    utilities_by_attr = utilities_by_attr,
    importance = importance,
    diagnostics = diagnostics,
    hb_data = hb_data,
    lc_data = lc_data,
    model_result = model_result,
    warnings = character()
  )
}
