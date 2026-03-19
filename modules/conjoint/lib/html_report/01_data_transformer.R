# ==============================================================================
# CONJOINT HTML REPORT - DATA TRANSFORMER
# ==============================================================================
# Transforms conjoint results into HTML-ready data structures for:
#   - Overview panel (KPIs, importance)
#   - Utilities panel (per-attribute charts/tables)
#   - Diagnostics panel (model fit, convergence)
#   - WTP panel (willingness to pay, demand curves)
#   - Simulator panel (JSON data for in-browser simulation)
#   - Latent class panel (class comparison, sizes)
#   - About panel (analyst info, closing notes)
#   - Insight seeds (per-tab pre-populated insights)
# ==============================================================================

#' Transform Conjoint Results for HTML Report
#'
#' @param conjoint_results List with utilities, importance, model_result, etc.
#' @param config Report config (brand_colour, insight_*, analyst_*, etc.)
#' @return List with all data needed by page builder
#' @keywords internal
transform_conjoint_for_html <- function(conjoint_results, config = list()) {

  model_result <- conjoint_results$model_result
  utilities    <- conjoint_results$utilities
  importance   <- conjoint_results$importance
  diagnostics  <- conjoint_results$diagnostics
  module_config <- conjoint_results$config

  # --- Summary ---
  summary <- .build_summary(model_result, utilities, importance, config, module_config)

  # --- Utilities by attribute ---
  utilities_by_attr <- if (!is.null(utilities)) split(utilities, utilities$Attribute) else list()

  # --- HB data ---
  hb_data <- .extract_hb_data(model_result)

  # --- Latent class data ---
  lc_data <- .extract_lc_data(model_result)

  # --- WTP data ---
  wtp_data <- .extract_wtp_data(conjoint_results$wtp)

  # --- Simulator data (JSON-ready) ---
  simulator_data <- .build_simulator_data(utilities, importance, model_result, module_config, config)

  # --- Insight seeds ---
  insights <- .extract_insights(config)

  # --- About page ---
  about <- .extract_about(config)

  # --- Sidebar navigation ---
  sidebar_nav <- .build_sidebar_nav(utilities)

  list(
    summary          = summary,
    utilities        = utilities,
    utilities_by_attr = utilities_by_attr,
    importance       = importance,
    diagnostics      = diagnostics,
    hb_data          = hb_data,
    lc_data          = lc_data,
    wtp_data         = wtp_data,
    simulator_data   = simulator_data,
    insights         = insights,
    about            = about,
    sidebar_nav      = sidebar_nav,
    model_result     = model_result,
    warnings         = character()
  )
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' @keywords internal
.build_summary <- function(model_result, utilities, importance, config, module_config) {
  method <- if (!is.null(model_result$method)) model_result$method else "unknown"
  list(
    project_name     = config$project_name %||% module_config$project_name %||% "Conjoint Analysis",
    generated        = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    estimation_method = method,
    n_respondents    = model_result$n_respondents %||% NA,
    n_attributes     = if (!is.null(utilities)) length(unique(utilities$Attribute)) else 0L,
    n_levels         = if (!is.null(utilities)) nrow(utilities) else 0L,
    n_choice_sets    = model_result$n_choice_sets %||% NA,
    converged        = if (!is.null(model_result$convergence)) model_result$convergence$converged else NA
  )
}

#' @keywords internal
.extract_hb_data <- function(model_result) {
  if (is.null(model_result)) return(NULL)
  method <- model_result$method %||% ""
  if (!method %in% c("hierarchical_bayes", "hb")) return(NULL)

  hb <- list(
    has_individual = !is.null(model_result$individual_betas),
    n_draws    = model_result$hb_settings$n_draws_retained %||% NA,
    iterations = model_result$hb_settings$iterations %||% NA,
    burnin     = model_result$hb_settings$burnin %||% NA,
    convergence = model_result$convergence
  )

  if (!is.null(model_result$respondent_quality)) {
    hb$quality <- list(
      mean_rlh   = model_result$respondent_quality$mean_rlh,
      n_flagged  = model_result$respondent_quality$n_flagged,
      chance_rlh = model_result$respondent_quality$chance_rlh
    )
  }
  hb
}

#' @keywords internal
.extract_lc_data <- function(model_result) {
  if (is.null(model_result$latent_class)) return(NULL)
  lc <- model_result$latent_class
  list(
    optimal_k        = lc$optimal_k,
    class_sizes      = lc$class_sizes,
    class_proportions = lc$class_proportions,
    entropy_r2       = lc$entropy_r2,
    comparison       = lc$comparison,
    class_importance = lc$class_importance
  )
}

#' @keywords internal
.extract_wtp_data <- function(wtp) {
  if (is.null(wtp)) return(NULL)
  if (is.null(wtp$wtp_table)) return(NULL)

  result <- list(
    wtp_table         = wtp$wtp_table,
    price_coefficient = wtp$price_coefficient %||% NA,
    price_attribute   = wtp$price_attribute %||% "Price"
  )

  # Demand curve data if available
  if (!is.null(wtp$demand_curve)) {
    result$demand_curve <- wtp$demand_curve
  }

  result
}

#' Build simulator JSON-ready data from utilities and config
#' @keywords internal
.build_simulator_data <- function(utilities, importance, model_result, config, report_config = list()) {
  if (is.null(utilities)) return(NULL)

  # Build attribute list with levels and utilities
  attr_names <- unique(utilities$Attribute)
  attributes <- lapply(attr_names, function(attr) {
    attr_utils <- utilities[utilities$Attribute == attr, , drop = FALSE]
    levels_list <- lapply(seq_len(nrow(attr_utils)), function(i) {
      list(
        name    = as.character(attr_utils$Level[i]),
        utility = as.numeric(attr_utils$Utility[i])
      )
    })
    imp_val <- if (!is.null(importance)) {
      imp_row <- importance[importance$Attribute == attr, ]
      if (nrow(imp_row) > 0) imp_row$Importance[1] else 0
    } else 0

    list(name = attr, levels = levels_list, importance = imp_val)
  })

  sim_data <- list(
    meta = list(
      project_name      = config$project_name %||% "Conjoint Simulator",
      estimation_method = model_result$method %||% "mlogit",
      n_respondents     = model_result$n_respondents %||% NA,
      generated         = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    ),
    attributes = attributes,
    individual = list(),
    classes    = list()
  )

  # Default products from config (pre-defined simulator products)
  sim_products <- report_config$simulator_products %||% config$simulator_products %||% NULL
  if (!is.null(sim_products) && is.list(sim_products) && length(sim_products) > 0) {
    default_products <- lapply(sim_products, function(prod) {
      levels <- as.list(prod[setdiff(names(prod), "name")])
      list(name = prod$name %||% "Product", levels = levels)
    })
    sim_data$defaultProducts <- default_products
  }

  # Individual betas for RFC (if HB)
  if (!is.null(model_result$individual_betas)) {
    sim_data$individual <- list(has_data = TRUE)
    # Individual betas can be very large; include summary statistics only
    # to keep file size manageable
  }

  # Latent class data
  if (!is.null(model_result$latent_class)) {
    lc <- model_result$latent_class
    sim_data$classes <- list(
      n_classes = lc$optimal_k %||% 0,
      sizes     = lc$class_sizes %||% list()
    )
  }

  sim_data
}

#' Convert simulator data to JSON string
#' @keywords internal
simulator_data_to_json <- function(sim_data) {
  if (is.null(sim_data)) return("{}")
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::toJSON(sim_data, auto_unbox = TRUE, pretty = FALSE, digits = 6)
  } else {
    # Minimal fallback: just utilities
    "{}"
  }
}

#' @keywords internal
.extract_insights <- function(config) {
  fields <- c("insight_overview", "insight_utilities", "insight_diagnostics",
               "insight_simulator", "insight_wtp")
  insights <- list()
  for (f in fields) {
    tab_name <- sub("^insight_", "", f)
    val <- config[[f]]
    if (!is.null(val) && is.character(val) && nzchar(trimws(val))) {
      insights[[tab_name]] <- trimws(val)
    }
  }
  insights
}

#' @keywords internal
.extract_about <- function(config) {
  about_fields <- c("analyst_name", "analyst_email", "analyst_phone",
                     "client_name", "company_name", "closing_notes",
                     "researcher_logo_base64")
  about <- list()
  for (f in about_fields) {
    val <- config[[f]]
    if (!is.null(val) && is.character(val) && nzchar(trimws(val))) {
      about[[f]] <- trimws(val)
    }
  }
  # Check if any content exists (compute before adding to list)
  has_content <- length(about) > 0
  about$has_content <- has_content
  about
}

#' @keywords internal
.build_sidebar_nav <- function(utilities) {
  if (is.null(utilities)) return(list())
  attr_names <- unique(utilities$Attribute)
  lapply(seq_along(attr_names), function(i) {
    attr <- attr_names[i]
    n_levels <- sum(utilities$Attribute == attr)
    list(
      name     = attr,
      n_levels = n_levels,
      index    = i - 1L,
      active   = (i == 1L)
    )
  })
}
