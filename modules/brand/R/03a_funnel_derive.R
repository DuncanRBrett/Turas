# SIZE-EXCEPTION: Stage plan + per-stage builders + nesting validator form a
# coherent sequential pipeline; splitting them across files would fragment
# the funnel derivation flow without improving readability.
#
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

BRAND_FUNNEL_DERIVE_VERSION <- "3.0"

# Default attitude codes considered "positive" for consideration. Matches the
# IPK convention: 1 = Love, 2 = Prefer, 3 = Ambivalent. 4 = Reject and
# 5 = No opinion are explicitly excluded. Caller can override per project.
.FUNNEL_POSITIVE_ATTITUDE_CODES <- c("1", "2", "3")


# ==============================================================================
# CONSTANTS
# ==============================================================================

# Category type -> ordered stage list. Transactional funnels are 4 stages
# (Aware → Consider → Long Period → Target Period). Heavy-buyer / frequency
# analysis lives in the Repertoire / Frequency element, not here — the
# funnel is a leakage story with unambiguous binary stages (FUNNEL_SPEC_v2 §3).
.FUNNEL_STAGE_PLAN <- list(
  transactional = c("aware", "consideration",
                    "bought_long", "bought_target"),
  durable       = c("aware", "consideration",
                    "current_owner_d", "long_tenured_d"),
  service       = c("aware", "consideration",
                    "current_customer_s", "long_tenured_s")
)

# Default stage labels shown in the report. Operator can override at
# runtime via config$funnel.stage_labels_override.
.FUNNEL_DEFAULT_LABELS <- list(
  aware              = "Aware",
  consideration      = "Consider",
  bought_long        = "Long Period",
  bought_target      = "Target Period",
  current_owner_d    = "Current owner",
  long_tenured_d     = "Long-tenured owner",
  current_customer_s = "Current customer",
  long_tenured_s     = "Long-tenured customer"
)

# Stage definitions — shown as clickable ? popovers in the HTML report
# and exported to the About drawer / Excel metadata sheet. Operator can
# override per project via config$funnel.stage_definitions.
.FUNNEL_DEFAULT_DEFINITIONS <- list(
  aware              = "Respondents who recognise the brand (stated aided awareness).",
  consideration      = "Aware respondents holding a positive or non-rejecting attitude (Love, Prefer, or Ambivalent — not Reject or No opinion).",
  bought_long        = "Considerers who have bought the brand in the longer timeframe asked on the survey.",
  bought_target      = "Long-period buyers who also bought the brand in the target (shorter) timeframe.",
  current_owner_d    = "Considerers who currently own this brand in the category.",
  long_tenured_d     = "Current owners whose tenure meets or exceeds the configured tenure threshold.",
  current_customer_s = "Considerers who are current customers of this brand.",
  long_tenured_s     = "Current customers whose tenure meets or exceeds the configured tenure threshold."
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
                                 brand_list, tenure_threshold = NULL,
                                 cat_code = NULL,
                                 positive_attitude_codes =
                                   .FUNNEL_POSITIVE_ATTITUDE_CODES) {

  .check_category_type(category_type)
  .require_role_lookup(role_map, "funnel.awareness", cat_code)
  .require_role_lookup(role_map, "funnel.attitude", cat_code)

  plan    <- .FUNNEL_STAGE_PLAN[[category_type]]
  brands  <- as.character(brand_list$BrandCode)
  n_resp  <- nrow(data)

  stages_out <- list()
  warns      <- character(0)
  prev_mat   <- NULL

  for (key in plan) {
    mat <- .derive_stage_matrix(
      key, data, role_map, brands, n_resp, category_type,
      tenure_threshold, cat_code, positive_attitude_codes)
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


#' Look up an entry in a role map, preferring per-category keys
#'
#' For v2 role maps, awareness for DSS lives at \code{funnel.awareness.DSS}.
#' This helper accepts the base role (\code{funnel.awareness}) plus a
#' category code and returns the per-category entry if present, else the
#' base entry (legacy compatibility), else NULL.
#'
#' @keywords internal
.lookup_role <- function(role_map, base_role, cat_code) {
  if (!is.null(cat_code) && nzchar(cat_code)) {
    keyed <- paste0(base_role, ".", cat_code)
    if (!is.null(role_map[[keyed]])) return(role_map[[keyed]])
  }
  role_map[[base_role]]
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


#' Refuse if neither base role nor per-category role is present
#' @keywords internal
.require_role_lookup <- function(role_map, base_role, cat_code) {
  if (!is.null(.lookup_role(role_map, base_role, cat_code))) {
    return(invisible(TRUE))
  }
  keyed <- if (!is.null(cat_code) && nzchar(cat_code)) {
    paste0(base_role, ".", cat_code)
  } else base_role
  brand_refuse(
    code = "CFG_ROLE_MISSING",
    title = sprintf("Funnel Needs Role '%s'", keyed),
    problem = sprintf(
      "The funnel derivation requires role '%s', not present in role map.",
      keyed),
    why_it_matters = paste(
      "Every funnel stage begins with awareness and attitude. Without these",
      "two roles, no stage can be derived."
    ),
    how_to_fix = c(
      sprintf("Confirm '%s' question root is registered in Survey_Structure.",
              gsub("\\.", "_", keyed)),
      "Convention-first inference resolves this automatically when the",
      "Questions sheet contains the canonical naming.",
      "See modules/brand/templates/README.md for the convention table."
    ),
    missing = keyed
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
                                 category_type, tenure_threshold,
                                 cat_code, positive_attitude_codes) {

  switch(key,
    aware = list(matrix = .stage_awareness(
      role_map, data, brands, n_resp, cat_code)),
    consideration = list(matrix = .stage_consideration(
      role_map, data, brands, n_resp, cat_code, positive_attitude_codes)),

    bought_long = .stage_penetration_long(
      role_map, data, brands, n_resp, cat_code),
    bought_target = .stage_penetration_target(
      role_map, data, brands, n_resp, cat_code),

    current_owner_d = .single_response_brand_match_stage(
      role_map, "funnel.durable.current_owner",
      data, brands, n_resp, "Current owner", cat_code),
    long_tenured_d = .tenure_stage(
      role_map, "funnel.durable.tenure", data, brands, n_resp,
      tenure_threshold, "Long-tenured (durable)", cat_code),

    current_customer_s = .single_response_brand_match_stage(
      role_map, "funnel.service.current_customer",
      data, brands, n_resp, "Current customer", cat_code),
    long_tenured_s = .tenure_stage(
      role_map, "funnel.service.tenure", data, brands, n_resp,
      tenure_threshold, "Long-tenured (service)", cat_code),

    stop(sprintf("[BUG] Unknown funnel stage key '%s'", key))
  )
}


# ==============================================================================
# STAGE BUILDERS — V2 (use 00_data_access.R helpers)
# ==============================================================================

#' Awareness stage — slot-indexed Multi_Mention root
#' @keywords internal
.stage_awareness <- function(role_map, data, brands, n_resp, cat_code) {
  entry <- .lookup_role(role_map, "funnel.awareness", cat_code)
  .multi_mention_or_empty(entry, data, brands, n_resp)
}

#' Consideration stage — per-brand attitude in positive code set
#' @keywords internal
.stage_consideration <- function(role_map, data, brands, n_resp, cat_code,
                                 pos_codes) {
  entry <- .lookup_role(role_map, "funnel.attitude", cat_code)
  if (is.null(entry)) return(.empty_brand_matrix(brands, n_resp))
  if (isTRUE(entry$per_brand)) {
    mat <- single_response_brand_matrix(data, entry$client_code,
                                        entry$category, brands)
    out <- matrix(FALSE, n_resp, length(brands),
                  dimnames = list(NULL, brands))
    pos_codes_chr <- as.character(pos_codes)
    for (b in brands) {
      vals <- mat[, b]
      out[, b] <- !is.na(vals) & as.character(vals) %in% pos_codes_chr
    }
    out
  } else {
    # Fallback: single-response per-category attitude — rare in IPK
    .empty_brand_matrix(brands, n_resp)
  }
}

#' Penetration long-window — slot-indexed Multi_Mention
#' @keywords internal
.stage_penetration_long <- function(role_map, data, brands, n_resp, cat_code) {
  entry <- .lookup_role(role_map, "funnel.penetration_long", cat_code)
  if (is.null(entry)) {
    return(list(matrix = NULL,
                warning = sprintf(
                  "Stage 'Long Period' dropped: penetration_long role for %s absent.",
                  cat_code %||% "(no cat)")))
  }
  list(matrix = .multi_mention_or_empty(entry, data, brands, n_resp))
}

#' Penetration target window — slot-indexed Multi_Mention
#' @keywords internal
.stage_penetration_target <- function(role_map, data, brands, n_resp,
                                      cat_code) {
  entry <- .lookup_role(role_map, "funnel.penetration_target", cat_code)
  if (is.null(entry)) {
    return(list(matrix = NULL,
                warning = sprintf(
                  "Stage 'Target Period' dropped: penetration_target role for %s absent.",
                  cat_code %||% "(no cat)")))
  }
  list(matrix = .multi_mention_or_empty(entry, data, brands, n_resp))
}

#' Resolve a Multi_Mention entry to a respondent × brand logical matrix
#' @keywords internal
.multi_mention_or_empty <- function(entry, data, brands, n_resp) {
  if (is.null(entry) || is.null(entry$column_root)) {
    return(.empty_brand_matrix(brands, n_resp))
  }
  multi_mention_brand_matrix(data, entry$column_root, brands)
}

.empty_brand_matrix <- function(brands, n_resp) {
  matrix(FALSE, nrow = n_resp, ncol = length(brands),
         dimnames = list(NULL, brands))
}


#' Single-response respondent-level role where value is a brand code
#'
#' Used for durable / service "current owner / customer" stages where a single
#' column holds the respondent's chosen brand. Reads entry$columns[1] for v2
#' entries (column_root for per-category single-response) or falls back to
#' the legacy entry$columns[1] semantics.
#'
#' @keywords internal
.single_response_brand_match_stage <- function(role_map, role_name,
                                               data, brands, n_resp, label,
                                               cat_code = NULL) {
  entry <- .lookup_role(role_map, role_name, cat_code)
  if (is.null(entry)) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: role '%s' absent.",
                                  label, role_name)))
  }
  col <- if (length(entry$columns) > 0) entry$columns[1] else entry$column_root
  if (is.null(col) || !(col %in% names(data))) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: column '%s' not in data.",
                                  label, col %||% "(NULL)")))
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
                          tenure_threshold, label, cat_code = NULL) {
  entry <- .lookup_role(role_map, role_name, cat_code)
  if (is.null(entry) || is.null(tenure_threshold) ||
      !nzchar(trimws(as.character(tenure_threshold)))) {
    return(list(matrix = NULL,
                warning = sprintf(
                  "Stage '%s' dropped: role '%s' or tenure_threshold absent.",
                  label, role_name)))
  }
  col <- if (length(entry$columns) > 0) entry$columns[1] else entry$column_root
  if (is.null(col) || !(col %in% names(data))) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: column '%s' not in data.",
                                  label, col %||% "(NULL)")))
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
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand funnel derive loaded (v%s)",
                  BRAND_FUNNEL_DERIVE_VERSION))
}
