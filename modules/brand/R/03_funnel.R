# ==============================================================================
# BRAND MODULE - FUNNEL ELEMENT (public entry + metrics summary)
# ==============================================================================
# Derived brand funnel against the role-registry architecture.
# Stages are derived from core CBM data (no dedicated funnel questions) by
# 03a_funnel_derive.R. Metrics / conversions / attitude decomposition /
# significance are computed by 03b_funnel_metrics.R. This file wires the
# three layers into a single public call and assembles the condensed
# metrics summary consumed by the HTML panel and AI callouts.
#
# Reference:
# - modules/brand/docs/FUNNEL_SPEC_v2.md §5
# - modules/brand/docs/ROLE_REGISTRY.md §4
#
# VERSION: 2.0
# ==============================================================================

BRAND_FUNNEL_VERSION <- "2.0"


# ==============================================================================
# PUBLIC ENTRY: run_funnel
# ==============================================================================

#' Run the brand funnel element
#'
#' Orchestrates stage derivation, metric calculation, conversions, attitude
#' decomposition, and optional significance tests against a pre-built role
#' map. The caller is responsible for loading the role map
#' (\code{load_role_map()}) and validating it against the data
#' (\code{guard_validate_role_map()}); this entry point assumes both
#' steps have already succeeded.
#'
#' @param data Data frame. Survey data (one row per respondent).
#' @param role_map Named list from \code{load_role_map()}.
#' @param brand_list Data frame with columns BrandCode, BrandLabel (at minimum).
#' @param config List of funnel.* settings:
#'   \code{category.type}, \code{funnel.conversion_metric},
#'   \code{funnel.warn_base}, \code{funnel.suppress_base},
#'   \code{funnel.tenure_threshold}, \code{funnel.significance_level},
#'   \code{focal_brand}, \code{wave}.
#' @param weights Numeric vector, or NULL for unweighted analysis.
#' @param sig_tester Two-proportion z-test closure from the tabs module,
#'   or NULL to skip significance testing.
#'
#' @return List with \code{status} (PASS / PARTIAL / REFUSED),
#'   \code{stages} (long-format data frame), \code{conversions},
#'   \code{attitude_decomposition}, \code{sig_results},
#'   \code{metrics_summary} (condensed list for AI callouts + About),
#'   \code{warnings}, \code{meta}.
#'
#' @export
run_funnel <- function(data, role_map, brand_list, config,
                       weights = NULL, sig_tester = NULL) {

  .funnel_require_args(data, role_map, brand_list, config)

  category_type <- config[["category.type"]] %||% "transactional"
  focal_brand   <- config$focal_brand
  conv_metric   <- config[["funnel.conversion_metric"]] %||% "ratio"
  warn_base     <- .numeric_or_default(config[["funnel.warn_base"]], 75)
  suppress_base <- .numeric_or_default(config[["funnel.suppress_base"]], 0)
  alpha         <- .numeric_or_default(config[["funnel.significance_level"]], 0.05)
  tenure_thr    <- config[["funnel.tenure_threshold"]]

  cat_code <- config$cat_code  # may be NULL for legacy single-cat callers
  pos_codes <- config[["funnel.positive_attitude_codes"]] %||%
    .FUNNEL_POSITIVE_ATTITUDE_CODES

  derived <- derive_funnel_stages(
    data          = data,
    role_map      = role_map,
    category_type = category_type,
    brand_list    = brand_list,
    tenure_threshold = tenure_thr,
    cat_code      = cat_code,
    positive_attitude_codes = pos_codes
  )
  validate_nesting(derived$stages, weights = weights)

  stage_df <- calculate_stage_metrics(
    stages        = derived$stages,
    weights       = weights,
    warn_base     = warn_base,
    suppress_base = suppress_base
  )
  conv_df <- calculate_conversions(stage_df, method = conv_metric)

  aware_matrix <- if (!is.null(derived$stages$aware)) {
    derived$stages$aware$matrix
  } else {
    NULL
  }
  att_df <- if (!is.null(aware_matrix)) {
    calculate_attitude_decomposition(
      attitude_entry   = .lookup_role(role_map, "funnel.attitude", cat_code),
      awareness_matrix = aware_matrix,
      data             = data,
      brand_list       = brand_list,
      weights          = weights,
      positive_attitude_codes = pos_codes
    )
  } else {
    data.frame()
  }

  sig_df <- run_significance_tests(stage_df, focal_brand, sig_tester, alpha)

  summary_list <- build_metrics_summary(stage_df, conv_df, att_df, focal_brand)

  status <- if (length(derived$warnings) > 0) "PARTIAL" else "PASS"
  list(
    status = status,
    stages = stage_df,
    conversions = conv_df,
    attitude_decomposition = att_df,
    sig_results = sig_df,
    metrics_summary = summary_list,
    warnings = derived$warnings,
    meta = .funnel_meta(config, focal_brand, data, weights, derived),
    # Role map retained so downstream writers (Excel + CSV) can carry
    # ClientCode + QuestionText onto every row without re-resolving.
    role_map = role_map
  )
}


# ==============================================================================
# build_metrics_summary
# ==============================================================================

#' Condensed named list of headline numbers for callouts + About drawer
#'
#' Designed to feed into the AI callouts pipeline and the HTML About
#' drawer. Structure is intentionally shallow so downstream consumers need
#' not rebuild it.
#'
#' @keywords internal
build_metrics_summary <- function(stage_df, conv_df, att_df, focal_brand) {
  if (is.null(stage_df) || nrow(stage_df) == 0) return(list())
  f_rows <- stage_df[stage_df$brand_code == focal_brand, , drop = FALSE]
  focal_by_stage <- stats::setNames(
    as.list(f_rows$pct_weighted), f_rows$stage_key)

  cat_avg_by_stage <- tapply(
    stage_df$pct_weighted[stage_df$brand_code != focal_brand],
    stage_df$stage_key[stage_df$brand_code != focal_brand],
    mean, na.rm = TRUE
  )

  biggest_drop <- .biggest_drop_for_focal(conv_df, focal_brand)
  top_attitude <- .top_attitude_position_for_focal(att_df, focal_brand)

  list(
    focal_brand = focal_brand,
    focal_by_stage = focal_by_stage,
    category_avg_by_stage = as.list(cat_avg_by_stage),
    biggest_drop = biggest_drop,
    top_attitude_position = top_attitude
  )
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

.funnel_require_args <- function(data, role_map, brand_list, config) {
  .funnel_check_data(data)
  .funnel_check_role_map(role_map)
  .funnel_check_brand_list(brand_list)
  .funnel_check_focal_brand(config$focal_brand, brand_list)
  invisible(TRUE)
}


.funnel_check_data <- function(data) {
  if (is.data.frame(data) && nrow(data) > 0) return(invisible(TRUE))
  brand_refuse(
    code = "DATA_EMPTY",
    title = "Funnel Requires Non-Empty Data",
    problem = "run_funnel() received NULL or zero-row data.",
    why_it_matters = paste(
      "Without respondents the funnel cannot compute any stage metric.",
      "This is an upstream loader issue, not a user configuration bug."
    ),
    how_to_fix = "Verify the data loader step; ensure the CSV/XLSX has rows."
  )
}


.funnel_check_role_map <- function(role_map) {
  if (!is.null(role_map) && length(role_map) > 0) return(invisible(TRUE))
  brand_refuse(
    code = "CFG_ROLE_MAP_EMPTY",
    title = "Funnel Requires a Role Map",
    problem = "run_funnel() received a NULL or empty role_map.",
    why_it_matters = paste(
      "Every stage derivation reads data by role. Without a role map the",
      "funnel cannot resolve a single column."
    ),
    how_to_fix = "Call load_role_map(structure) before run_funnel()."
  )
}


.funnel_check_brand_list <- function(brand_list) {
  if (!is.null(brand_list) && is.data.frame(brand_list) &&
      nrow(brand_list) > 0 && "BrandCode" %in% names(brand_list)) {
    return(invisible(TRUE))
  }
  brand_refuse(
    code = "CFG_BRAND_LIST_EMPTY",
    title = "Funnel Requires a Brand List",
    problem = "run_funnel() received no brand list with a BrandCode column.",
    why_it_matters = paste(
      "Stage matrices are indexed by brand. Without a brand list the",
      "funnel cannot decide which columns represent which brand."
    ),
    how_to_fix = "Populate the Brands sheet in Survey_Structure.xlsx."
  )
}


.funnel_check_focal_brand <- function(focal_brand, brand_list) {
  if (!is.null(focal_brand) && focal_brand %in% brand_list$BrandCode) {
    return(invisible(TRUE))
  }
  brand_refuse(
    code = "CFG_FOCAL_BRAND_INVALID",
    title = "Focal Brand Not in Brand List",
    problem = sprintf("focal_brand '%s' is not one of the declared brands.",
                       as.character(focal_brand %||% "<NULL>")),
    why_it_matters = paste(
      "The focal brand drives colour, significance pairs, and the",
      "metrics summary. Unknown focal = meaningless report."
    ),
    how_to_fix = c(
      "Set focal_brand in Brand_Config.xlsx Settings.",
      sprintf("Allowed values: %s.",
              paste(as.character(brand_list$BrandCode), collapse = ", "))
    ),
    expected = as.character(brand_list$BrandCode),
    observed = focal_brand
  )
}


.funnel_meta <- function(config, focal_brand, data, weights, derived) {
  n_u <- nrow(data)
  n_w <- if (is.null(weights)) n_u else sum(weights, na.rm = TRUE)
  list(
    category_type = config[["category.type"]] %||% "transactional",
    focal_brand   = focal_brand,
    wave          = config$wave %||% NA,
    n_unweighted  = n_u,
    n_weighted    = n_w,
    stage_count   = length(derived$stages),
    stage_keys    = names(derived$stages)
  )
}


.biggest_drop_for_focal <- function(conv_df, focal_brand) {
  if (is.null(conv_df) || nrow(conv_df) == 0) return(NULL)
  sub <- conv_df[conv_df$brand_code == focal_brand, , drop = FALSE]
  if (nrow(sub) == 0) return(NULL)
  if (all(is.na(sub$value))) return(NULL)
  worst <- which.min(sub$value)
  list(from_stage = sub$from_stage[worst],
       to_stage = sub$to_stage[worst],
       value = sub$value[worst],
       method = sub$method[worst])
}


.top_attitude_position_for_focal <- function(att_df, focal_brand) {
  if (is.null(att_df) || nrow(att_df) == 0) return(NULL)
  sub <- att_df[att_df$brand_code == focal_brand, , drop = FALSE]
  if (nrow(sub) == 0) return(NULL)
  best <- which.max(sub$pct)
  list(attitude_role = sub$attitude_role[best],
       pct = sub$pct[best])
}


.numeric_or_default <- function(x, default) {
  if (is.null(x) || (is.character(x) && !nzchar(trimws(x)))) return(default)
  val <- suppressWarnings(as.numeric(x))
  if (is.na(val)) default else val
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand funnel loaded (v%s)", BRAND_FUNNEL_VERSION))
}
