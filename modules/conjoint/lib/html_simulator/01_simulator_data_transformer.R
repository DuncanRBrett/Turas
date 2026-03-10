# ==============================================================================
# CONJOINT HTML SIMULATOR - DATA TRANSFORMER
# ==============================================================================
# Builds JSON data structure to embed in HTML
# ==============================================================================

#' Transform Conjoint Data for HTML Simulator
#'
#' Creates the JSON data structure embedded in the simulator HTML.
#' Includes attributes, levels, utilities, individual betas (if HB),
#' class memberships (if LC), and products.
#'
#' @param utilities Data frame with Attribute, Level, Utility
#' @param importance Data frame with Attribute, Importance
#' @param model_result Optional model result for HB/LC
#' @param config Configuration
#' @return JSON-ready list
#' @keywords internal
build_simulator_data <- function(utilities, importance, model_result = NULL, config) {

  # Build attribute structure
  attributes <- lapply(config$attributes$AttributeName, function(attr) {
    levels <- get_attribute_levels(config, attr)
    utils <- utilities[utilities$Attribute == attr, ]

    level_data <- lapply(levels, function(lev) {
      u_row <- utils[utils$Level == lev, ]
      list(
        name = lev,
        utility = if (nrow(u_row) > 0) round(u_row$Utility[1], 4) else 0
      )
    })

    list(
      name = attr,
      levels = level_data,
      importance = round(importance$Importance[importance$Attribute == attr][1], 2)
    )
  })

  # Meta info
  meta <- list(
    project_name = config$project_name %||% "Conjoint Simulator",
    estimation_method = if (!is.null(model_result$method)) model_result$method else "aggregate",
    n_respondents = model_result$n_respondents %||% NA,
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )

  # Individual betas for RFC simulation (optional)
  individual_data <- NULL
  if (!is.null(model_result$individual_betas)) {
    individual_data <- list(
      n_respondents = nrow(model_result$individual_betas),
      col_names = model_result$col_names,
      betas = as.list(as.data.frame(t(model_result$individual_betas))),
      attribute_map = lapply(model_result$attribute_map, function(m) list(attribute = m$attribute, level = m$level))
    )
  }

  # LC class data (optional)
  class_data <- NULL
  if (!is.null(model_result$latent_class)) {
    lc <- model_result$latent_class
    class_data <- list(
      optimal_k = lc$optimal_k,
      class_sizes = lc$class_sizes,
      class_proportions = round(lc$class_proportions, 4),
      class_betas = as.list(as.data.frame(t(lc$class_betas))),
      class_assignment = lc$class_assignment
    )
  }

  list(
    meta = meta,
    attributes = attributes,
    individual = individual_data,
    classes = class_data
  )
}


#' Convert Simulator Data to JSON String
#' @keywords internal
simulator_data_to_json <- function(sim_data) {
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::toJSON(sim_data, auto_unbox = TRUE, digits = 6, pretty = FALSE)
  } else {
    # Minimal JSON fallback for utilities only
    attrs_json <- vapply(sim_data$attributes, function(attr) {
      levels_json <- vapply(attr$levels, function(l) {
        sprintf('{"name":"%s","utility":%s}', l$name, l$utility)
      }, character(1))
      sprintf('{"name":"%s","importance":%s,"levels":[%s]}',
              attr$name, attr$importance, paste(levels_json, collapse = ","))
    }, character(1))

    sprintf('{"meta":{"project_name":"%s","generated":"%s"},"attributes":[%s]}',
            sim_data$meta$project_name, sim_data$meta$generated,
            paste(attrs_json, collapse = ","))
  }
}
