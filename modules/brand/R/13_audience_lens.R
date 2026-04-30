# ==============================================================================
# BRAND MODULE - AUDIENCE LENS (per-category focal-brand audience analysis)
# ==============================================================================
# Romaniuk-style audience lens: shows the focal brand's KPI scores across
# pre-defined audience cuts (demographic + brand-buyer pairs), with a
# side-by-side scorecard for each pair audience and an auto-classified
# GROW / FIX / DEFEND chip.
#
# Inputs come from the per-category run already completed by run_brand():
#   - cat_data           (focal-category respondents)
#   - cat_weights
#   - cat_brands         (Brands sheet rows for this category)
#   - cat_code           (e.g. "DSS")
#   - results          (already-computed funnel / MA / branded reach / cat
#                       buying / WOM blocks for this category)
# Plus a parsed audience definition list (built from the AudienceLens sheet
# in Survey_Structure.xlsx + the Categories sheet AudienceLens_Use opt-in
# column in Brand_Config.xlsx).
#
# All 14 KPIs are recomputed inside this engine for each audience subset so
# the audience lens stands on its own — no leakage from filtered upstream
# blocks. The KPI definitions live in 11b_al_metrics.R and intentionally
# mirror (not call) the upstream engines' definitions: this keeps the lens
# tolerant of partial failures upstream and makes the Romaniuk metrics
# replicable from the audience lens result alone.
#
# VERSION: 1.0
# ==============================================================================

BRAND_AUDIENCE_LENS_VERSION <- "1.0"


#' Run audience-lens analysis for one category
#'
#' @param data Data frame. Already filtered to focal-category respondents.
#' @param weights Numeric vector or NULL. Length must equal nrow(data).
#' @param cat_brands Data frame of category brands (BrandCode, BrandLabel).
#' @param cat_code Character. Category code (e.g. "DSS").
#' @param cat_name Character. Display name (e.g. "Dishwash Soap").
#' @param focal_brand Character. Focal brand code.
#' @param audiences List. Parsed audience definitions for this category from
#'   \code{parse_audience_lens_definitions()}. Empty list -> no panel.
#' @param structure List. Loaded survey structure (used to discover roles).
#' @param config List. Brand config (sources thresholds + alpha).
#' @param category_results List. Per-category results already computed by the
#'   parent run_brand() loop (funnel, mental_availability, branded_reach,
#'   wom, repertoire, cat_buying_frequency). Optional but enables full KPI
#'   coverage; the engine recomputes from raw data when a block is missing
#'   or REFUSED.
#'
#' @return List with status, meta, banner_table, cards (per-audience cards),
#'   pair_cards, and a JSON-ready payload. TRS refusal when essential
#'   inputs are missing or all audiences fall below the suppression threshold.
#'
#' @examples
#' \dontrun{
#'   res <- run_audience_lens(
#'     data = cat_data, weights = cat_weights,
#'     cat_brands = cat_brands, cat_code = "DSS", cat_name = "Dishwash",
#'     focal_brand = config$focal_brand,
#'     audiences = parse_audience_lens_definitions(structure, config, "DSS"),
#'     structure = structure, config = config,
#'     category_results = cat_result)
#' }
#'
#' @export
run_audience_lens <- function(data, weights = NULL, cat_brands, cat_code,
                              cat_name, focal_brand, audiences,
                              structure, config,
                              category_results = NULL) {

  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    return(.al_refuse("DATA_MISSING",
      "Audience lens: empty data",
      "Pass the focal-category-filtered survey data frame"))
  }
  if (is.null(audiences) || length(audiences) == 0) {
    return(list(
      status = "PASS",
      meta = list(cat_code = cat_code, cat_name = cat_name,
                  focal_brand = focal_brand,
                  n_audiences = 0L, n_total = nrow(data),
                  note = "No audiences declared for this category"),
      banner_table = NULL,
      cards = list(),
      pair_cards = list()
    ))
  }
  if (is.null(focal_brand) || !nzchar(trimws(as.character(focal_brand)))) {
    return(.al_refuse("CFG_FOCAL_BRAND_MISSING",
      "Audience lens requires focal_brand from Brand_Config",
      "Set focal_brand in Brand_Config Settings sheet"))
  }

  thresholds <- .al_resolve_thresholds(config)
  w <- .al_normalise_weights(weights, nrow(data))

  # 1) Compute the metric set on TOTAL (the comparison frame for every
  #    audience).
  metrics_total <- compute_al_metrics_for_subset(
    data = data, weights = w,
    keep_idx = rep(TRUE, nrow(data)),
    cat_brands = cat_brands, cat_code = cat_code,
    focal_brand = focal_brand,
    structure = structure, category_results = category_results,
    config = config)

  # 2) Resolve each audience to a respondent index, compute metrics,
  #    apply base-size discipline.
  audience_blocks <- lapply(audiences, function(a) {
    idx <- resolve_audience_index(a, data)
    n_unweighted <- sum(idx, na.rm = TRUE)
    n_weighted   <- sum(w[idx], na.rm = TRUE)
    base_state   <- .al_base_state(n_unweighted, thresholds)
    if (identical(base_state, "suppressed")) {
      return(list(audience = a, n_unweighted = n_unweighted,
                  n_weighted = n_weighted, base_state = base_state,
                  metrics = NULL))
    }
    metrics <- compute_al_metrics_for_subset(
      data = data, weights = w, keep_idx = idx,
      cat_brands = cat_brands, cat_code = cat_code,
      focal_brand = focal_brand,
      structure = structure, category_results = category_results,
      config = config)
    list(audience = a, n_unweighted = n_unweighted,
         n_weighted = n_weighted, base_state = base_state,
         metrics = metrics)
  })

  # 3) Drop fully-suppressed audiences from the rendered set; the meta
  #    block still records them so the panel can show "audience suppressed".
  rendered <- Filter(function(b) !is.null(b$metrics), audience_blocks)
  suppressed <- Filter(function(b) is.null(b$metrics), audience_blocks)

  if (length(rendered) == 0) {
    return(list(
      status = "PARTIAL",
      code = "DATA_ALL_AUDIENCES_SUPPRESSED",
      message = sprintf(
        "All %d declared audiences fell below the n=%d base threshold for %s",
        length(audiences), thresholds$suppress, cat_name),
      meta = list(cat_code = cat_code, cat_name = cat_name,
                  focal_brand = focal_brand,
                  n_audiences = length(audiences),
                  n_total = nrow(data), n_total_weighted = sum(w),
                  thresholds = thresholds,
                  suppressed = suppressed),
      banner_table = NULL,
      cards = list(),
      pair_cards = list()
    ))
  }

  # 4) Pair classification: every pair (rows linked by PairID) gets
  #    side-by-side metrics + GROW / FIX / DEFEND per row.
  pair_groups <- .al_extract_pairs(rendered)
  pair_cards  <- lapply(pair_groups, function(pg) {
    classify_audience_pair(
      pair_a       = pg$a, pair_b = pg$b,
      total        = list(metrics = metrics_total,
                          n_unweighted = nrow(data),
                          n_weighted = sum(w)),
      focal_brand  = focal_brand,
      thresholds   = thresholds)
  })

  list(
    status = "PASS",
    meta = list(
      cat_code = cat_code, cat_name = cat_name,
      focal_brand = focal_brand,
      n_total = nrow(data), n_total_weighted = sum(w),
      n_audiences = length(audiences),
      n_rendered = length(rendered),
      n_suppressed = length(suppressed),
      thresholds = thresholds,
      weighted = !is.null(weights)
    ),
    total = list(metrics = metrics_total,
                 n_unweighted = nrow(data),
                 n_weighted = sum(w)),
    audiences = rendered,
    suppressed = suppressed,
    pair_cards = pair_cards
  )
}


# ==============================================================================
# Internals
# ==============================================================================

.al_resolve_thresholds <- function(config) {
  list(
    warn      = as.integer(config$audience_lens_warn_base    %||% 100L),
    suppress  = as.integer(config$audience_lens_suppress_base %||% 50L),
    gap_pp    = as.numeric(config$audience_lens_gap_threshold %||% 0.10),
    alpha     = as.numeric(config$audience_lens_alpha %||% 0.10),
    max_audiences = as.integer(config$audience_lens_max %||% 6L)
  )
}


.al_base_state <- function(n_unweighted, thresholds) {
  if (is.na(n_unweighted) || n_unweighted < thresholds$suppress) return("suppressed")
  if (n_unweighted < thresholds$warn) return("low_base")
  "ok"
}


.al_normalise_weights <- function(weights, n) {
  if (is.null(weights)) return(rep(1, n))
  if (length(weights) != n) {
    msg <- sprintf("Audience lens: weights length (%d) != data rows (%d)", length(weights), n)
    cat(sprintf(
      "\n=== TURAS BRAND ERROR ===\n[DATA_AL_WEIGHTS_LENGTH_MISMATCH] %s\nHow to fix: Ensure the weights vector has one value per respondent row (length == nrow(data)).\n=========================\n\n",
      msg
    ))
    stop(msg, call. = FALSE)
  }
  w <- as.numeric(weights)
  w[is.na(w)] <- 0
  w
}


.al_extract_pairs <- function(rendered) {
  ids <- vapply(rendered, function(b) b$audience$pair_id %||% "", character(1))
  out <- list()
  for (pid in unique(ids[nzchar(ids)])) {
    members <- rendered[ids == pid]
    if (length(members) < 2) next
    roles <- vapply(members, function(b)
      toupper(b$audience$pair_role %||% ""), character(1))
    a <- members[which(roles == "A")[1]]
    b <- members[which(roles == "B")[1]]
    if (length(a) == 0 || length(b) == 0) {
      a <- members[1]; b <- members[2]
    }
    out[[pid]] <- list(a = a[[1]], b = b[[1]])
  }
  out
}


.al_refuse <- function(code, problem, how_to_fix) {
  res <- list(
    status = "REFUSED",
    code = code,
    message = problem,
    how_to_fix = how_to_fix
  )
  cat(sprintf("\n[AUDIENCE LENS] %s: %s\n  Fix: %s\n",
              code, problem, how_to_fix))
  res
}


# ==============================================================================
# SIZE-EXCEPTION: v1 + v2 coexist during IPK rebuild migration window.
# v1 deletion at cutover restores this file under the 300-line guideline.
# ==============================================================================

# ==============================================================================
# V2: ROLE-MAP-DRIVEN ENTRY (slot-indexed data access)
# ==============================================================================
# v2 wraps the same orchestration shape as run_audience_lens() but reads
# respondent data via the data-access layer (00_data_access.R) and the v2
# role registry (00_role_map_v2.R). It delegates KPI computation to the v2
# metric block in 13b_al_metrics.R. Audience parsing (13a_al_audiences.R),
# pair classification (13c_al_classify.R) and panel-data shaping
# (13d_al_panel_data.R) work unchanged on the v2 result shape — those files
# operate on the metric output, not the data layer underneath.
#
# Tracker-friendliness note (per memory entry
# feedback_brand_metrics_tracker_friendly): every per-respondent KPI value
# is derivable here from a single data-access helper call. Audience Lens
# v3 (post-cutover, Tabs-as-engine) will materialise these as named per-
# respondent columns so the tracker module can read them directly.
# ==============================================================================

#' Run audience-lens analysis for one category (v2 role-map driven)
#'
#' v2 alternative to \code{run_audience_lens()}. Reads respondent data
#' via the slot-indexed data-access layer using the role map produced by
#' \code{build_brand_role_map()}.
#'
#' Required role-map entries (per category \code{cat_code}):
#' \itemize{
#'   \item \code{funnel.awareness.\{cat\}} — BRANDAWARE root (Multi_Mention)
#'   \item \code{funnel.attitude.\{cat\}} — BRANDATT1 per-brand compound
#'   \item \code{funnel.penetration_target.\{cat\}} — BRANDPEN2 root
#'   \item \code{funnel.frequency.\{cat\}} — BRANDPEN3 root (optional)
#'   \item \code{mental_avail.cep.\{cat\}.*} — BRANDATTR CEPs (optional;
#'         block is skipped when no CEP roles are present)
#'   \item \code{wom.pos_rec.\{cat\}} / \code{wom.neg_rec.\{cat\}} /
#'         \code{wom.pos_share.\{cat\}} / \code{wom.neg_share.\{cat\}} —
#'         WOM mention sets (optional)
#' }
#'
#' @param data Data frame. Already filtered to focal-category respondents.
#' @param role_map Named list from \code{build_brand_role_map()}.
#' @param cat_code Character. Category code (e.g. "DSS").
#' @param cat_name Character. Display name (e.g. "Dishwash Soap").
#' @param cat_brands Data frame with \code{BrandCode} (and ideally
#'   \code{BrandLabel}) columns.
#' @param focal_brand Character. Focal brand code.
#' @param audiences List from \code{parse_audience_lens_definitions()}.
#'   Empty list -> no panel.
#' @param structure List. Loaded survey structure (used for MarketingReach
#'   sheet only; role lookups go via role_map).
#' @param config List. Brand config (sources thresholds + alpha).
#' @param weights Numeric vector of length \code{nrow(data)} or NULL.
#' @param category_results Optional per-category result block (passed
#'   through unchanged for any future enrichment hooks).
#'
#' @return Same shape as \code{run_audience_lens()} (status, meta, total,
#'   audiences, suppressed, pair_cards). v2 status carries an extra
#'   \code{engine = "v2"} marker on the meta block.
#' @export
run_audience_lens_v2 <- function(data, role_map, cat_code, cat_name,
                                 cat_brands, focal_brand, audiences,
                                 structure, config,
                                 weights = NULL,
                                 category_results = NULL) {

  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    return(.al_refuse("DATA_MISSING",
      "Audience lens v2: empty data",
      "Pass the focal-category-filtered survey data frame"))
  }
  if (is.null(focal_brand) || !nzchar(trimws(as.character(focal_brand)))) {
    return(.al_refuse("CFG_FOCAL_BRAND_MISSING",
      "Audience lens v2 requires focal_brand",
      "Set focal_brand in Brand_Config Settings sheet"))
  }
  if (is.null(role_map) || length(role_map) == 0L) {
    return(.al_refuse("CFG_ROLE_MAP_EMPTY",
      "Audience lens v2 requires a non-empty role map",
      "Build role_map via build_brand_role_map() before calling v2"))
  }

  if (is.null(audiences) || length(audiences) == 0) {
    return(list(
      status = "PASS",
      meta = list(cat_code = cat_code, cat_name = cat_name,
                  focal_brand = focal_brand,
                  n_audiences = 0L, n_total = nrow(data),
                  engine = "v2",
                  note = "No audiences declared for this category"),
      banner_table = NULL,
      cards = list(),
      pair_cards = list()
    ))
  }

  thresholds <- .al_resolve_thresholds(config)
  w <- .al_normalise_weights(weights, nrow(data))

  # Compute total + per-audience metrics via the v2 engine.
  metrics_total <- compute_al_metrics_for_subset_v2(
    data = data, role_map = role_map, weights = w,
    keep_idx = rep(TRUE, nrow(data)),
    cat_brands = cat_brands, cat_code = cat_code,
    focal_brand = focal_brand,
    structure = structure, category_results = category_results,
    config = config)

  audience_blocks <- lapply(audiences, function(a) {
    idx <- resolve_audience_index(a, data)
    n_unweighted <- sum(idx, na.rm = TRUE)
    n_weighted   <- sum(w[idx], na.rm = TRUE)
    base_state   <- .al_base_state(n_unweighted, thresholds)
    if (identical(base_state, "suppressed")) {
      return(list(audience = a, n_unweighted = n_unweighted,
                  n_weighted = n_weighted, base_state = base_state,
                  metrics = NULL))
    }
    metrics <- compute_al_metrics_for_subset_v2(
      data = data, role_map = role_map, weights = w, keep_idx = idx,
      cat_brands = cat_brands, cat_code = cat_code,
      focal_brand = focal_brand,
      structure = structure, category_results = category_results,
      config = config)
    list(audience = a, n_unweighted = n_unweighted,
         n_weighted = n_weighted, base_state = base_state,
         metrics = metrics)
  })

  rendered <- Filter(function(b) !is.null(b$metrics), audience_blocks)
  suppressed <- Filter(function(b) is.null(b$metrics), audience_blocks)

  if (length(rendered) == 0) {
    return(list(
      status = "PARTIAL",
      code = "DATA_ALL_AUDIENCES_SUPPRESSED",
      message = sprintf(
        "All %d declared audiences fell below the n=%d base threshold for %s",
        length(audiences), thresholds$suppress, cat_name),
      meta = list(cat_code = cat_code, cat_name = cat_name,
                  focal_brand = focal_brand,
                  n_audiences = length(audiences),
                  n_total = nrow(data), n_total_weighted = sum(w),
                  engine = "v2",
                  thresholds = thresholds,
                  suppressed = suppressed),
      banner_table = NULL,
      cards = list(),
      pair_cards = list()
    ))
  }

  pair_groups <- .al_extract_pairs(rendered)
  pair_cards  <- lapply(pair_groups, function(pg) {
    classify_audience_pair(
      pair_a       = pg$a, pair_b = pg$b,
      total        = list(metrics = metrics_total,
                          n_unweighted = nrow(data),
                          n_weighted = sum(w)),
      focal_brand  = focal_brand,
      thresholds   = thresholds)
  })

  list(
    status = "PASS",
    meta = list(
      cat_code = cat_code, cat_name = cat_name,
      focal_brand = focal_brand,
      n_total = nrow(data), n_total_weighted = sum(w),
      n_audiences = length(audiences),
      n_rendered = length(rendered),
      n_suppressed = length(suppressed),
      thresholds = thresholds,
      weighted = !is.null(weights),
      engine = "v2"
    ),
    total = list(metrics = metrics_total,
                 n_unweighted = nrow(data),
                 n_weighted = sum(w)),
    audiences = rendered,
    suppressed = suppressed,
    pair_cards = pair_cards
  )
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Audience lens engine loaded (v%s)",
                  BRAND_AUDIENCE_LENS_VERSION))
}
