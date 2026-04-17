# ==============================================================================
# BRAND MODULE - FUNNEL STAGE DERIVATION
# ==============================================================================
# Builds per-respondent × per-brand logical matrices for every funnel stage
# declared by the category type (transactional / durable / service). Each
# stage's derivation ANDs the previous stage's matrix, so nesting is
# guaranteed by construction. validate_nesting() then verifies the
# invariant and refuses loud on violation (§3.4 of FUNNEL_SPEC v2).
#
# This file is sourced by modules/brand/R/03_funnel.R alongside
# 03b_funnel_metrics.R. All three together implement run_funnel().
#
# VERSION: 2.0
# ==============================================================================

BRAND_FUNNEL_DERIVE_VERSION <- "2.0"


# ==============================================================================
# CONSTANTS
# ==============================================================================

# Category type -> ordered stage list. Every stage shares a derivation key
# which is looked up in .STAGE_DERIVATIONS below.
.FUNNEL_STAGE_PLAN <- list(
  transactional = c("aware", "consideration",
                    "bought_long", "bought_target", "preferred"),
  durable       = c("aware", "consideration",
                    "current_owner_d", "long_tenured_d"),
  service       = c("aware", "consideration",
                    "current_customer_s", "long_tenured_s")
)

# Default stage labels shown in the report. Operator can override at
# runtime via config$funnel.stage_labels_override.
.FUNNEL_DEFAULT_LABELS <- list(
  aware              = "Aware",
  consideration      = "Consideration",
  bought_long        = "Bought",
  bought_target      = "Frequent",
  preferred          = "Preferred",
  current_owner_d    = "Current owner",
  long_tenured_d     = "Long-tenured owner",
  current_customer_s = "Current customer",
  long_tenured_s     = "Long-tenured customer"
)

# Positive attitude role set (Consideration membership).
.FUNNEL_POSITIVE_ATTITUDE_ROLES <- c(
  "attitude.love", "attitude.prefer", "attitude.ambivalent"
)


# ==============================================================================
# PUBLIC: derive_funnel_stages
# ==============================================================================

#' Derive per-respondent × per-brand logical matrices for every funnel stage
#'
#' Walks the ordered stage list for the category type, computing a matrix
#' (rows = respondents, cols = brands) for each stage. Every stage after
#' the first ANDs the previous stage's matrix, so nesting is guaranteed by
#' construction. Stages whose required role is absent from the role map
#' are dropped silently with a warning recorded in the return value.
#'
#' @param data Data frame. Survey data (one row per respondent).
#' @param role_map Named list from load_role_map().
#' @param category_type Character. One of "transactional", "durable",
#'   "service".
#' @param brand_list Data frame with BrandCode column.
#' @param tenure_threshold Character. Value from the tenure OptionMap at or
#'   above which "long-tenured" is TRUE. NULL disables the tenure stage.
#'
#' @return List with:
#'   \item{stages}{Named list of stage entries, each a list with \code{key},
#'     \code{label}, \code{matrix} (logical, respondents × brands).}
#'   \item{warnings}{Character vector. Reasons for dropped stages.}
#'   \item{category_type}{Echoed.}
#'
#' @export
derive_funnel_stages <- function(data, role_map, category_type,
                                 brand_list, tenure_threshold = NULL) {

  .check_category_type(category_type)
  .require_role(role_map, "funnel.awareness")
  .require_role(role_map, "funnel.attitude")

  plan    <- .FUNNEL_STAGE_PLAN[[category_type]]
  brands  <- as.character(brand_list$BrandCode)
  n_resp  <- nrow(data)

  stages_out <- list()
  warns      <- character(0)
  prev_mat   <- NULL

  for (key in plan) {
    mat <- .derive_stage_matrix(
      key, data, role_map, brands, n_resp, category_type, tenure_threshold)
    if (is.null(mat$matrix)) {
      warns <- c(warns, mat$warning)
      next
    }
    combined <- if (is.null(prev_mat)) mat$matrix else mat$matrix & prev_mat
    prev_mat <- combined

    stages_out[[key]] <- list(
      key    = key,
      label  = .FUNNEL_DEFAULT_LABELS[[key]],
      matrix = combined
    )
  }

  list(stages = stages_out, warnings = warns, category_type = category_type)
}


# ==============================================================================
# PUBLIC: validate_nesting
# ==============================================================================

#' Validate that every stage is a subset of the previous
#'
#' Refuses loud with CALC_NESTING_VIOLATED on any (brand, stage) cell where
#' the count exceeds the previous stage's count. The derivation ANDs each
#' stage into the next by construction, so a violation indicates a logic
#' bug, never operator error.
#'
#' @param stages Named list from derive_funnel_stages()$stages.
#' @param weights Numeric vector of respondent weights, or NULL.
#'
#' @return TRUE invisibly when the invariant holds. Otherwise throws a TRS
#'   refusal.
#'
#' @export
validate_nesting <- function(stages, weights = NULL) {
  if (length(stages) < 2) return(invisible(TRUE))
  w <- weights %||% rep(1, nrow(stages[[1]]$matrix))

  keys <- names(stages)
  for (i in seq(2, length(keys))) {
    prev_counts <- colSums(stages[[keys[i - 1]]]$matrix * w, na.rm = TRUE)
    curr_counts <- colSums(stages[[keys[i]]]$matrix * w, na.rm = TRUE)
    if (any(curr_counts > prev_counts + 1e-9)) {
      bad <- which(curr_counts > prev_counts + 1e-9)
      brand_refuse(
        code = "CALC_NESTING_VIOLATED",
        title = "Funnel Stage Nesting Violated",
        problem = sprintf(
          "Stage '%s' count exceeds stage '%s' for brand(s): %s.",
          keys[i], keys[i - 1],
          paste(names(curr_counts)[bad], collapse = ", ")),
        why_it_matters = paste(
          "Every funnel stage must be a subset of the previous stage so",
          "conversion ratios are honest. A violation indicates a logic",
          "bug in the derivation layer."
        ),
        how_to_fix = c(
          "Report this to the module maintainer.",
          "Do not rely on the resulting percentages."
        ),
        details = sprintf("Offending stages: %s > %s.",
                          keys[i], keys[i - 1])
      )
    }
  }
  invisible(TRUE)
}


# ==============================================================================
# INTERNAL: ARG CHECKS
# ==============================================================================

.check_category_type <- function(category_type) {
  if (!(category_type %in% names(.FUNNEL_STAGE_PLAN))) {
    brand_refuse(
      code = "CFG_CATEGORY_TYPE_INVALID",
      title = "Unrecognised category.type",
      problem = sprintf("category.type = '%s' is not valid.", category_type),
      why_it_matters = paste(
        "The funnel's stage shape is determined by category type. Only",
        "transactional, durable, and service are defined."
      ),
      how_to_fix = paste(
        "Set category.type in Brand_Config.xlsx Settings to one of:",
        paste(names(.FUNNEL_STAGE_PLAN), collapse = ", ")
      ),
      expected = paste(names(.FUNNEL_STAGE_PLAN), collapse = ", "),
      observed = category_type
    )
  }
}


.require_role <- function(role_map, role_name) {
  if (!is.null(role_map[[role_name]])) return(invisible(TRUE))
  brand_refuse(
    code = "CFG_ROLE_MISSING",
    title = sprintf("Funnel Needs Role '%s'", role_name),
    problem = sprintf(
      "The funnel derivation requires role '%s', which is not declared in QuestionMap.",
      role_name),
    why_it_matters = paste(
      "Every funnel stage begins with awareness and attitude. Without these",
      "two roles, no stage can be derived."
    ),
    how_to_fix = c(
      sprintf("Add a QuestionMap row for role '%s'.", role_name),
      "See modules/brand/docs/ROLE_REGISTRY.md §4."
    ),
    missing = role_name
  )
}


# ==============================================================================
# INTERNAL: PER-STAGE DERIVATION
# ==============================================================================

#' Derive a single stage's per-respondent × per-brand matrix
#'
#' Returns either \code{list(matrix = <logical matrix>)} or
#' \code{list(matrix = NULL, warning = "...")} when the stage's required
#' role is absent. Callers decide what to do (the public entry drops the
#' stage and keeps going).
#'
#' @keywords internal
.derive_stage_matrix <- function(key, data, role_map, brands, n_resp,
                                 category_type, tenure_threshold) {

  switch(key,
    aware = list(matrix = .per_brand_binary_matrix(
      role_map, "funnel.awareness", data, brands, n_resp)),
    consideration = list(matrix = .attitude_positive_matrix(
      role_map, "funnel.attitude", data, brands, n_resp)),

    bought_long = .optional_per_brand_stage(
      role_map, "funnel.transactional.bought_long",
      data, brands, n_resp, "Bought (longer timeframe)"),
    bought_target = .optional_per_brand_stage(
      role_map, "funnel.transactional.bought_target",
      data, brands, n_resp, "Frequent (target timeframe)"),
    preferred = .preferred_stage(role_map, data, brands, n_resp),

    current_owner_d = .single_response_brand_match_stage(
      role_map, "funnel.durable.current_owner",
      data, brands, n_resp, "Current owner"),
    long_tenured_d = .tenure_stage(
      role_map, "funnel.durable.tenure", data, brands, n_resp,
      tenure_threshold, "Long-tenured (durable)"),

    current_customer_s = .single_response_brand_match_stage(
      role_map, "funnel.service.current_customer",
      data, brands, n_resp, "Current customer"),
    long_tenured_s = .tenure_stage(
      role_map, "funnel.service.tenure", data, brands, n_resp,
      tenure_threshold, "Long-tenured (service)"),

    stop(sprintf("[BUG] Unknown funnel stage key '%s'", key))
  )
}


#' Per-brand binary role -> logical matrix (respondents × brands)
#' @keywords internal
.per_brand_binary_matrix <- function(role_map, role_name, data, brands, n_resp) {
  entry <- role_map[[role_name]]
  mat <- matrix(FALSE, nrow = n_resp, ncol = length(brands),
                dimnames = list(NULL, brands))
  for (b in brands) {
    col <- .column_for_brand(entry, b)
    if (!is.null(col) && col %in% names(data)) {
      vals <- suppressWarnings(as.numeric(data[[col]]))
      mat[, b] <- !is.na(vals) & vals == 1
    }
  }
  mat
}


#' Attitude role -> logical matrix of "positive" attitude respondents
#' @keywords internal
.attitude_positive_matrix <- function(role_map, role_name, data, brands, n_resp) {
  entry <- role_map[[role_name]]
  pos_codes <- .attitude_codes_matching(entry, .FUNNEL_POSITIVE_ATTITUDE_ROLES)

  mat <- matrix(FALSE, nrow = n_resp, ncol = length(brands),
                dimnames = list(NULL, brands))
  for (b in brands) {
    col <- .column_for_brand(entry, b)
    if (!is.null(col) && col %in% names(data)) {
      vals <- suppressWarnings(as.character(data[[col]]))
      mat[, b] <- !is.na(vals) & vals %in% pos_codes
    }
  }
  mat
}


#' Optional per-brand stage helper (wraps the binary matrix builder, returns
#' a warning instead of failing when the role is absent).
#' @keywords internal
.optional_per_brand_stage <- function(role_map, role_name, data, brands,
                                      n_resp, label) {
  if (is.null(role_map[[role_name]])) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: role '%s' absent.",
                                  label, role_name)))
  }
  list(matrix = .per_brand_binary_matrix(role_map, role_name, data, brands, n_resp))
}


#' Preferred stage — frequency argmax with ties
#' @keywords internal
.preferred_stage <- function(role_map, data, brands, n_resp) {
  entry <- role_map[["funnel.transactional.frequency"]]
  if (is.null(entry)) {
    return(list(matrix = NULL,
                warning = "Stage 'Preferred' dropped: frequency role absent."))
  }

  freq_mat <- matrix(NA_real_, nrow = n_resp, ncol = length(brands),
                     dimnames = list(NULL, brands))
  for (b in brands) {
    col <- .column_for_brand(entry, b)
    if (!is.null(col) && col %in% names(data)) {
      freq_mat[, b] <- suppressWarnings(as.numeric(data[[col]]))
    }
  }

  row_max <- suppressWarnings(apply(freq_mat, 1, max, na.rm = TRUE))
  row_max[!is.finite(row_max) | row_max <= 0] <- NA_real_

  preferred <- matrix(FALSE, nrow = n_resp, ncol = length(brands),
                      dimnames = list(NULL, brands))
  for (i in seq_len(n_resp)) {
    if (!is.na(row_max[i])) {
      preferred[i, ] <- !is.na(freq_mat[i, ]) &
                       freq_mat[i, ] == row_max[i] &
                       freq_mat[i, ] > 0
    }
  }
  list(matrix = preferred)
}


#' Single-response respondent-level role where value is a brand code
#' @keywords internal
.single_response_brand_match_stage <- function(role_map, role_name,
                                               data, brands, n_resp, label) {
  entry <- role_map[[role_name]]
  if (is.null(entry)) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: role '%s' absent.",
                                  label, role_name)))
  }
  col <- entry$columns[1]
  if (!(col %in% names(data))) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: column '%s' not in data.",
                                  label, col)))
  }
  vals <- as.character(data[[col]])
  mat <- matrix(FALSE, nrow = n_resp, ncol = length(brands),
                dimnames = list(NULL, brands))
  for (b in brands) {
    mat[, b] <- !is.na(vals) & vals == b
  }
  list(matrix = mat)
}


#' Tenure stage (durable/service) — respondent's tenure ≥ threshold
#' @keywords internal
.tenure_stage <- function(role_map, role_name, data, brands, n_resp,
                          tenure_threshold, label) {
  entry <- role_map[[role_name]]
  if (is.null(entry) || is.null(tenure_threshold) ||
      !nzchar(trimws(as.character(tenure_threshold)))) {
    return(list(matrix = NULL,
                warning = sprintf(
                  "Stage '%s' dropped: role '%s' or tenure_threshold absent.",
                  label, role_name)))
  }
  col <- entry$columns[1]
  if (!(col %in% names(data))) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: column '%s' not in data.",
                                  label, col)))
  }

  vals <- suppressWarnings(as.numeric(data[[col]]))
  thr <- suppressWarnings(as.numeric(tenure_threshold))
  long <- !is.na(vals) & !is.na(thr) & vals >= thr

  mat <- matrix(FALSE, nrow = n_resp, ncol = length(brands),
                dimnames = list(NULL, brands))
  for (b in brands) {
    mat[, b] <- long
  }
  list(matrix = mat)
}


# ==============================================================================
# INTERNAL: SMALL HELPERS
# ==============================================================================

#' Find the data column for one brand within a per-brand role
#' @keywords internal
.column_for_brand <- function(entry, brand_code) {
  if (is.null(entry) || length(entry$columns) == 0) return(NULL)
  suffix <- paste0("_", brand_code)
  hits <- entry$columns[endsWith(entry$columns, suffix)]
  if (length(hits) == 0) return(NULL)
  hits[1]
}


#' Return the ClientCode values in OptionMap that map to any of target_roles
#' @keywords internal
.attitude_codes_matching <- function(attitude_entry, target_roles) {
  om <- attitude_entry$option_map
  if (is.null(om)) return(character(0))
  sub <- om[!is.na(om$Role) & om$Role %in% target_roles, , drop = FALSE]
  if (nrow(sub) == 0) return(character(0))
  trimws(as.character(sub$ClientCode))
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand funnel derive loaded (v%s)",
                  BRAND_FUNNEL_DERIVE_VERSION))
}
