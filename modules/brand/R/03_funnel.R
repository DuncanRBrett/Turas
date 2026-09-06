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
  # The Consider stage is named by role. funnel.positive_attitude_codes is
  # the pre-2026-09-06 raw-code knob, still honoured, resolved through the
  # same OptionMap path and reported as deprecated on the console.
  cons_roles <- config[["funnel.consideration_roles"]]
  pos_codes  <- config[["funnel.positive_attitude_codes"]]

  derived <- derive_funnel_stages(
    data          = data,
    role_map      = role_map,
    category_type = category_type,
    brand_list    = brand_list,
    tenure_threshold = tenure_thr,
    cat_code      = cat_code,
    consideration_roles = cons_roles,
    positive_attitude_codes = pos_codes
  )
  # v3 aggregate funnel: validate_nesting returns structured warnings rather
  # than refusing. Non-monotonic brands are reported as recorded; warnings
  # are surfaced via the funnel result so the operator can investigate.
  nesting_check <- validate_nesting(derived$stages, weights = weights)
  if (is.list(nesting_check) && length(nesting_check$warnings) > 0) {
    derived$warnings <- c(derived$warnings, nesting_check$warnings)
  }

  # Did the questionnaire route these questions, or ask them all of everyone?
  # The answer decides whether the report may draw a nested funnel at all.
  gating <- detect_instrument_gating(derived$stages)
  .funnel_report_gating(gating, cat_code)

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
    meta = .funnel_meta(config, focal_brand, data, weights, derived, gating),
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


#' Stage labels used in the gating sentence, without the report's overrides
#' @keywords internal
.funnel_plain_stage_label <- function(key) {
  tolower(.FUNNEL_DEFAULT_LABELS[[key]] %||% key)
}


#' The gating finding in plain words, for the face of the report
#'
#' Digit free on purpose. The reachability gate in
#' modules/brand/tests/qa/reachability_check.py compares the numeric content
#' of every JSON island, and this sentence rides in the funnel payload. The
#' counts behind it go to the console and to the meta the operator reads, not
#' into the island.
#' @keywords internal
.funnel_gating_sentence <- function(gating) {
  if (isTRUE(gating$gated)) {
    return(paste(
      "The questionnaire routed these questions, so the stages nest and the",
      "funnel is drawn as a funnel. No respondent reached a later stage",
      "without the one before it."))
  }
  stages <- unique(gating$breaches$stage_key)
  labels <- paste(vapply(stages, .funnel_plain_stage_label, character(1)),
                  collapse = " and ")
  paste0(
    "The questionnaire did not route these questions: it asked every one of ",
    "them about every brand. Respondents reached ", labels, " for brands ",
    "they did not name as known, which routing would have made impossible. ",
    "So the stages are reported as separate measures, each on its own base, ",
    "with the conversion ratios beside them. The nested funnel view is not ",
    "available here, because a nested picture would show an ordering the ",
    "survey never enforced.")
}


.funnel_meta <- function(config, focal_brand, data, weights, derived,
                         gating = NULL) {
  n_u <- nrow(data)
  n_w <- if (is.null(weights)) n_u else sum(weights, na.rm = TRUE)
  # Kish effective n: the base every CI in the panel is computed on (H2)
  n_e <- if (is.null(weights)) n_u else .brand_effective_n(weights)
  list(
    category_type = config[["category.type"]] %||% "transactional",
    focal_brand   = focal_brand,
    wave          = config$wave %||% NA,
    n_unweighted  = n_u,
    n_weighted    = n_w,
    n_effective   = n_e,
    stage_count   = length(derived$stages),
    stage_keys    = names(derived$stages),
    # How the Consider stage was defined on this run: which scale positions
    # it accepted, which named position the scale did not carry, and whether
    # the definition came from role names or from a deprecated code list.
    consideration = list(
      roles_used    = derived$consideration$roles_used %||% character(0),
      roles_dropped = derived$consideration$roles_dropped %||% character(0),
      source        = derived$consideration$source %||% "roles",
      notes         = derived$consideration$notes %||% character(0)
    ),
    # Whether the instrument gated the questions, and therefore whether the
    # report may draw a nested funnel. See detect_instrument_gating().
    gating = list(
      gated         = isTRUE(gating$gated %||% TRUE),
      mode          = gating$mode %||% "nested",
      breach_stages = gating$breach_stages %||% character(0),
      statement     = .funnel_gating_sentence(
        gating %||% list(gated = TRUE))
    )
  )
}


#' Print the gating finding to the console
#'
#' The counts live here rather than in the payload: the reachability gate
#' compares island numbers, and the on-page statement is deliberately digit
#' free.
#' @keywords internal
.funnel_report_gating <- function(gating, cat_code) {
  if (isTRUE(gating$gated)) return(invisible(FALSE))
  cat("\n=== TURAS BRAND: FUNNEL NOT GATED ===\n")
  cat("Category:", cat_code %||% "(single category)", "\n")
  cat("The questionnaire asked the funnel questions of everyone, so the",
      "stages do not nest.\n")
  cat("Respondents at a later stage without the earlier one:\n")
  b <- gating$breaches
  agg <- stats::aggregate(b$n_respondents,
                          by = list(stage = b$stage_key, against = b$against),
                          FUN = sum)
  for (i in seq_len(nrow(agg))) {
    cat(sprintf("  %-16s not %-16s %d respondent rows across %d brands\n",
                agg$stage[i], agg$against[i], agg$x[i],
                sum(b$stage_key == agg$stage[i] &
                      b$against == agg$against[i])))
  }
  cat("The report shows the stages as separate measures with conversion",
      "ratios, not a nested funnel.\n")
  cat("=====================================\n\n")
  invisible(TRUE)
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
