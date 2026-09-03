# ==============================================================================
# PRICING - V2 REPORT DATA ISLAND
# ==============================================================================
#
# Module: Pricing - contribution to the interactive (v2) report
# Purpose: Serialise the decision-grade pricing results into a JSON island the
#          tabs v2 report reads, so pricing appears as a tab in the client's
#          own report rather than as a second HTML file.
#
# WHY AN ISLAND AND NOT NEW ROW KINDS:
#   The tabs data layer serialises CROSSTABS: rows keyed by (RowLabel,
#   RowSource) with pct[] / n[] / sig[] arrays indexed by banner column. A Van
#   Westendorp price point has no banner and no percentage of a base, and a
#   Gabor-Granger demand curve runs along a price axis, not a banner axis.
#   Conjoint and MaxDiff each reached the same conclusion for their own
#   module. This file follows that precedent: a frozen island plus the
#   module's own view, zero new row kinds.
#
# FROZEN, NOT LIVE:
#   The island carries pre-aggregated results only. The v2 reader recomputes
#   crosstabs from microdata under the audience filter; the price points were
#   estimated once on the whole sample and cannot be recomputed that way. The
#   tab shows what was estimated and says so. Breaking acceptance by audience
#   is the tabs export's job (15_tabs_export.R), where the Gabor-Granger grid
#   becomes a Multi_Mention question the reader CAN filter.
#
# CURATED (programme decision D1):
#   The four VW price points with their intervals, the GG demand and revenue
#   curves, the monadic cells and fitted curve, and the recommendation's
#   numbers travel. The module's own segmentation, the price ladder tiers and
#   the generated recommendation prose stay in the Excel deliverable
#   (decisions 9 and 10). Segment cuts are the crosstab's job via the export.
#
# ==============================================================================

PRICING_ISLAND_VERSION <- "1.0.0"
PRICING_ISLAND_SCHEMA <- 1L

# The curve arrays are for drawing, not for reading off. A psm interpolated
# grid can run to several hundred points; more than this adds file size and
# no visible detail.
PRICING_ISLAND_MAX_CURVE_POINTS <- 120L


#' Serialise Pricing Results As A V2 Report Island
#'
#' @param results A list describing one pricing run, with elements:
#'   `method` (the analysis method), `van_westendorp`, `gabor_granger`,
#'   `monadic` (the per-method result objects, any of them NULL), `synthesis`,
#'   `validation` (the object from `validate_pricing_data()`) and
#'   `output_path` (the Excel file this run wrote).
#' @param config The loaded pricing configuration (the flat settings list).
#' @param verbose Logical, print progress.
#'
#' @return A list ready for `jsonlite::toJSON()`, or NULL when no method
#'   produced anything to show.
#'
#' @export
serialize_pricing_layer <- function(results, config, verbose = TRUE) {

  vw <- results$van_westendorp
  gg <- results$gabor_granger
  mon <- results$monadic

  has_vw <- .pricing_island_has_vw(vw)
  has_gg <- .pricing_island_has_gg(gg)
  has_mon <- .pricing_island_has_monadic(mon)
  if (!has_vw && !has_gg && !has_mon) return(NULL)

  if (verbose) cat("  Serialising pricing results for the interactive report...\n")

  vw_block <- if (has_vw) .pricing_island_vw(vw, config$van_westendorp) else NULL
  gg_block <- if (has_gg) .pricing_island_gg(gg, config$gabor_granger) else NULL
  mon_block <- if (has_mon) .pricing_island_monadic(mon) else NULL
  rec_block <- .pricing_island_recommendation(results$synthesis)

  meta <- .pricing_island_meta(results, config,
                               has_vw = has_vw, has_gg = has_gg, has_mon = has_mon)

  out <- .pricing_drop_null(list(
    meta = meta,
    vw = vw_block,
    gg = gg_block,
    monadic = mon_block,
    recommendation = rec_block
  ))

  if (verbose) {
    cat(sprintf("  Pricing island: %s\n", paste(meta$methods, collapse = ", ")))
  }
  out
}


#' Write The Pricing Island Contribution File
#'
#' A pricing run writes its contribution; a later tabs run for the same
#' project embeds it (the tabs config's `pricing_island` setting). The same
#' arrangement conjoint and maxdiff use, and the tracker before them.
#'
#' @param results As `serialize_pricing_layer()`.
#' @param config The loaded pricing configuration.
#' @param output_file Path for the JSON. Defaults to the main output file's
#'   name with `_pr_island.json` in place of `.xlsx`.
#' @param verbose Logical.
#'
#' @return A list with `status`, `output_file` and `methods`.
#'
#' @export
write_pricing_island <- function(results, config, output_file = NULL, verbose = TRUE) {

  island <- serialize_pricing_layer(results, config, verbose = verbose)

  if (is.null(island)) {
    pricing_refuse(
      code = "MODEL_NO_ISLAND_CONTENT",
      title = "Nothing To Contribute To The Interactive Report",
      problem = "The run produced no price points, no demand curve and no monadic model, so there is nothing to serialise.",
      why_it_matters = "An empty island would add a Pricing tab with nothing in it.",
      how_to_fix = "Check the console above; the analysis did not complete."
    )
  }

  if (is.null(output_file)) {
    base <- results$output_path %||% "pricing_results.xlsx"
    output_file <- sub("[.]xlsx$", "_pr_island.json", base)
    if (identical(output_file, base)) output_file <- paste0(base, "_pr_island.json")
  }

  jsonlite::write_json(.pricing_island_keep_arrays(island), output_file,
                       auto_unbox = TRUE, na = "null", digits = 6, pretty = FALSE)

  if (verbose) cat(sprintf("  Interactive-report contribution: %s\n", basename(output_file)))

  list(
    status = "PASS",
    output_file = output_file,
    methods = island$meta$methods
  )
}


# ==============================================================================
# INTERNALS
# ==============================================================================

#' jsonlite writes a NULL list element as {}, which is truthy in JavaScript.
#' A block the run did not produce must be ABSENT, at every level.
#' @keywords internal
.pricing_drop_null <- function(x) Filter(Negate(is.null), x)

#' Numeric coercion that turns every non-finite value into NA
#' @keywords internal
.pricing_num <- function(x) {
  if (is.null(x)) return(NULL)
  x <- suppressWarnings(as.numeric(x))
  x[!is.finite(x)] <- NA_real_
  x
}

#' A column of a data frame as numbers, or NULL when the frame has no such column
#' @keywords internal
.pricing_col <- function(df, col) {
  if (is.null(df) || !is.data.frame(df) || !col %in% names(df)) return(NULL)
  .pricing_num(df[[col]])
}

#' As `.pricing_col()`, but an all-missing column stays out of the island
#' rather than arriving as an array of nulls the view has to guess about.
#' @keywords internal
.pricing_col_present <- function(df, col) {
  v <- .pricing_col(df, col)
  if (is.null(v) || all(is.na(v))) return(NULL)
  v
}

#' One scalar out of a list, as a number
#' @keywords internal
.pricing_scalar <- function(x) {
  if (is.null(x) || length(x) == 0) return(NULL)
  v <- .pricing_num(x[[1]])
  if (length(v) == 0 || is.na(v)) return(NULL)
  v
}

#' Even indices across a vector, first and last always kept
#'
#' The curve arrays are for drawing. A psm interpolated grid can run to
#' several hundred points; the view draws a path, so beyond a couple of
#' hundred points the extra detail is invisible and the island is bigger for
#' nothing.
#'
#' @param n Length of the vector to sample.
#' @param max_points Maximum points to keep.
#' @return An integer index vector.
#' @keywords internal
.pricing_downsample_idx <- function(n, max_points = PRICING_ISLAND_MAX_CURVE_POINTS) {
  if (n <= max_points) return(seq_len(n))
  idx <- unique(round(seq(1, n, length.out = max_points)))
  as.integer(idx)
}

#' Did the Van Westendorp path produce price points?
#' @keywords internal
.pricing_island_has_vw <- function(vw) {
  !is.null(vw) && !is.null(vw$price_points) &&
    any(vapply(vw$price_points[c("PMC", "OPP", "IDP", "PME")],
               function(p) length(p) == 1 && is.finite(suppressWarnings(as.numeric(p))),
               logical(1)))
}

#' Did the Gabor-Granger path produce a demand curve?
#' @keywords internal
.pricing_island_has_gg <- function(gg) {
  !is.null(gg) && is.data.frame(gg$demand_curve) && nrow(gg$demand_curve) > 0
}

#' Did the monadic path produce a model and cells?
#' @keywords internal
.pricing_island_has_monadic <- function(mon) {
  !is.null(mon) && is.data.frame(mon$observed_data) && nrow(mon$observed_data) > 0
}


#' The Van Westendorp block
#'
#' The four price points, each with the bootstrap interval that brackets it
#' (the A3-coherent bootstrap: the table's `estimate` column IS the headline
#' point), the two ranges, and the four curves on the estimator's own grid.
#'
#' @keywords internal
.pricing_island_vw <- function(vw, vw_cfg = NULL) {

  keys <- c("PMC", "OPP", "IDP", "PME")
  labels <- c(
    PMC = "Point of marginal cheapness",
    OPP = "Optimal price point",
    IDP = "Indifference price point",
    PME = "Point of marginal expensiveness"
  )
  values <- vapply(keys, function(k) {
    v <- .pricing_num(vw$price_points[[k]])
    if (length(v) != 1) NA_real_ else v
  }, numeric(1))

  ci <- vw$confidence_intervals
  ci_lower <- ci_upper <- NULL
  ci_level <- ci_policy <- ci_iterations <- NULL
  if (is.data.frame(ci) && nrow(ci) > 0 && "metric" %in% names(ci)) {
    m <- match(keys, as.character(ci$metric))
    lo <- .pricing_num(ci$ci_lower)[m]
    hi <- .pricing_num(ci$ci_upper)[m]
    if (!all(is.na(lo))) ci_lower <- lo
    if (!all(is.na(hi))) ci_upper <- hi
    ci_level <- .pricing_scalar(vw_cfg$confidence_level)
    ci_iterations <- .pricing_scalar(unique(.pricing_num(ci$n_successful)))
    pol <- attr(ci, "policy")
    if (!is.null(pol) && nzchar(as.character(pol)[1])) ci_policy <- as.character(pol)[1]
  }

  curves <- vw$curves
  curve_block <- NULL
  if (is.data.frame(curves) && nrow(curves) > 0) {
    idx <- .pricing_downsample_idx(nrow(curves))
    take <- function(col) {
      v <- .pricing_col(curves, col)
      if (is.null(v)) return(NULL)
      v[idx]
    }
    curve_block <- .pricing_drop_null(list(
      price = take("price"),
      tooCheap = take("too_cheap"),
      cheap = take("cheap"),
      expensive = take("expensive"),
      tooExpensive = take("too_expensive"),
      nPoints = length(idx),
      downsampledFrom = if (length(idx) < nrow(curves)) nrow(curves) else NULL
    ))
  }

  d <- vw$diagnostics %||% list()

  .pricing_drop_null(list(
    point = keys,
    pointLabel = unname(labels[keys]),
    value = unname(values),
    ciLower = ci_lower,
    ciUpper = ci_upper,
    ciLevel = ci_level,
    ciIterations = ci_iterations,
    ciPolicy = ci_policy,
    acceptableLower = .pricing_scalar(vw$acceptable_range$lower),
    acceptableUpper = .pricing_scalar(vw$acceptable_range$upper),
    optimalLower = .pricing_scalar(vw$optimal_range$lower),
    optimalUpper = .pricing_scalar(vw$optimal_range$upper),
    nAnalysed = .pricing_scalar(d$n_analysed %||% d$n_valid),
    nComplete = .pricing_scalar(d$n_valid),
    # The engine's own violation count is recomputed on data the `drop`
    # behaviour has already cleaned, so it reads 0 on a run that excluded
    # respondents for exactly that reason (the Session A review's F5). It
    # stays out of the island until that fix lands; the Excel Validation
    # sheet carries the real figure.
    monotonicityBehavior = as.character(d$monotonicity_behavior %||% NA_character_),
    curves = curve_block
  ))
}


#' The Gabor-Granger block
#'
#' One row per rung: base, weighted base, the acceptance actually observed,
#' the published (smoothed) curve, the revenue index, the interval, and the
#' arc elasticity of the step that ends at this rung.
#'
#' @keywords internal
.pricing_island_gg <- function(gg, gg_cfg = NULL) {

  dc <- gg$demand_curve
  rc <- gg$revenue_curve
  prices <- .pricing_col(dc, "price")

  # The raw column exists only when smoothing ran; when it did not, the
  # published curve IS the observed acceptance.
  raw <- .pricing_col(dc, "purchase_intent_raw")
  smoothed <- .pricing_col(dc, "purchase_intent")
  if (is.null(raw)) raw <- smoothed

  pct <- function(v) if (is.null(v)) NULL else v * 100

  # The interval is estimated on the same rungs, but match on price rather
  # than assume the row order.
  ci <- gg$confidence_intervals
  ci_lower <- ci_upper <- NULL
  if (is.data.frame(ci) && nrow(ci) > 0 && "price" %in% names(ci)) {
    m <- match(prices, .pricing_num(ci$price))
    lo <- .pricing_col(ci, "ci_lower")[m]
    hi <- .pricing_col(ci, "ci_upper")[m]
    if (!all(is.na(lo))) ci_lower <- pct(lo)
    if (!all(is.na(hi))) ci_upper <- pct(hi)
  }
  ci_level <- if (!is.null(ci_lower)) .pricing_scalar(gg_cfg$confidence_level) else NULL

  # Arc elasticity describes the step BETWEEN two rungs. It is carried on the
  # rung the step ends at, so the first rung has none.
  el <- gg$elasticity
  elasticity <- NULL
  if (is.data.frame(el) && nrow(el) > 0 && "price_to" %in% names(el)) {
    m <- match(prices, .pricing_num(el$price_to))
    v <- .pricing_col(el, "arc_elasticity")[m]
    if (!all(is.na(v))) elasticity <- v
  }

  bases <- gg$rung_bases
  n_missing <- NULL
  if (is.data.frame(bases) && "n_missing" %in% names(bases)) {
    m <- match(prices, .pricing_num(bases$price))
    v <- .pricing_col(bases, "n_missing")[m]
    if (any(v > 0, na.rm = TRUE)) n_missing <- v
  }

  d <- gg$diagnostics %||% list()

  .pricing_drop_null(list(
    price = prices,
    baseN = .pricing_col(dc, "n_respondents"),
    weightedN = .pricing_col_present(dc, "weighted_n"),
    missingN = n_missing,
    acceptancePct = pct(raw),
    smoothedPct = if (!identical(raw, smoothed)) pct(smoothed) else NULL,
    revenueIndex = .pricing_col(rc, "revenue_index"),
    profitIndex = .pricing_col_present(rc, "profit_index"),
    ciLowerPct = ci_lower,
    ciUpperPct = ci_upper,
    ciLevel = ci_level,
    arcElasticity = elasticity,
    smoothing = as.character(d$smoothing %||% "none"),
    optimalRevenuePrice = .pricing_scalar(gg$optimal_price$price),
    optimalRevenueIntentPct = {
      v <- .pricing_scalar(gg$optimal_price$purchase_intent)
      if (is.null(v)) NULL else v * 100
    },
    optimalProfitPrice = .pricing_scalar(gg$optimal_price_profit$price)
  ))
}


#' The monadic block
#'
#' The observed cells as measured, and the fitted curve the model draws
#' through them, kept apart so the reader can see the fit rather than take
#' it on trust.
#'
#' @keywords internal
.pricing_island_monadic <- function(mon) {

  obs <- mon$observed_data
  fit <- mon$demand_curve
  ms <- mon$model_summary %||% list()

  fit_block <- NULL
  if (is.data.frame(fit) && nrow(fit) > 0) {
    idx <- .pricing_downsample_idx(nrow(fit))
    fit_block <- .pricing_drop_null(list(
      price = .pricing_col(fit, "price")[idx],
      intentPct = {
        v <- .pricing_col(fit, "predicted_intent")
        if (is.null(v)) NULL else v[idx] * 100
      },
      revenueIndex = {
        v <- .pricing_col(fit, "revenue_index")
        if (is.null(v)) NULL else v[idx]
      }
    ))
  }

  .pricing_drop_null(list(
    cellPrice = .pricing_col(obs, "price"),
    cellN = .pricing_col(obs, "n"),
    cellWeightedN = .pricing_col_present(obs, "weighted_n"),
    cellIntentPct = {
      v <- .pricing_col(obs, "observed_intent")
      if (is.null(v)) NULL else v * 100
    },
    fitted = fit_block,
    modelType = as.character(ms$model_type %||% NA_character_),
    pseudoR2 = .pricing_scalar(ms$pseudo_r2),
    pValue = .pricing_scalar(ms$price_coefficient_p),
    pValueCaveat = if (!is.null(ms$p_value_caveat)) as.character(ms$p_value_caveat) else NULL,
    optimalPrice = .pricing_scalar(mon$optimal_price$price),
    optimalIntentPct = {
      v <- .pricing_scalar(mon$optimal_price$predicted_intent)
      if (is.null(v)) NULL else v * 100
    },
    optimalProfitPrice = .pricing_scalar(mon$optimal_price_profit$price)
  ))
}


#' The recommendation block: numbers only
#'
#' Decision 9: the generated prose stays out of the tab. The recommended
#' price, the two ranges, the confidence the module assessed and the spread
#' across methods travel; the sentences do not.
#'
#' @keywords internal
.pricing_island_recommendation <- function(synthesis) {
  if (is.null(synthesis) || is.null(synthesis$recommendation)) return(NULL)
  r <- synthesis$recommendation
  price <- .pricing_scalar(r$price)
  if (is.null(price)) return(NULL)

  cv <- .pricing_scalar(synthesis$method_price_cv)

  .pricing_drop_null(list(
    price = price,
    source = as.character(r$source %||% NA_character_),
    confidence = as.character(r$confidence %||% NA_character_),
    confidenceScore = .pricing_scalar(r$confidence_score),
    acceptableLower = .pricing_scalar(synthesis$acceptable_range$lower),
    acceptableUpper = .pricing_scalar(synthesis$acceptable_range$upper),
    optimalLower = .pricing_scalar(synthesis$optimal_zone$lower),
    optimalUpper = .pricing_scalar(synthesis$optimal_zone$upper),
    methodSpreadPct = if (is.null(cv)) NULL else cv * 100,
    # How many method price points the spread was taken across. Four on a
    # both-methods run (two VW points, GG, the ladder), not four methods.
    nMethodPrices = {
      mp <- synthesis$method_prices
      if (is.null(mp)) NULL else length(mp)
    }
  ))
}


#' The provenance block
#'
#' Every field here comes from what the engines recorded on the run
#' (`diagnostics$estimator`, `n_analysed`, `response_coding`, `imputation`,
#' `smoothing`, the monadic weight caveat). The island does not recompute
#' anything to describe the run.
#'
#' @keywords internal
.pricing_island_meta <- function(results, config, has_vw, has_gg, has_mon) {

  vw <- results$van_westendorp
  gg <- results$gabor_granger
  mon <- results$monadic
  validation <- results$validation

  methods <- c(if (has_vw) "van_westendorp", if (has_gg) "gabor_granger",
               if (has_mon) "monadic")
  method_labels <- c(van_westendorp = "Van Westendorp price sensitivity meter",
                     gabor_granger = "Gabor-Granger",
                     monadic = "Monadic cell test")

  weight_var <- config$weight_var %||% NA_character_
  weighted <- !is.na(weight_var) && nzchar(as.character(weight_var))

  effective_n <- NULL
  if (weighted && exists("calculate_effective_n", mode = "function") &&
      is.data.frame(validation$clean_data) &&
      as.character(weight_var) %in% names(validation$clean_data)) {
    effective_n <- .pricing_scalar(
      suppressWarnings(calculate_effective_n(validation$clean_data[[as.character(weight_var)]])))
  }

  # Which estimates the weights actually reached. VW and GG carry them into
  # the estimator; the monadic glm normalises them and its p-value does not
  # account for the design, which is the caveat H4 added.
  weighting_note <- if (!weighted) {
    "Unweighted. Every figure on this tab is a raw respondent count or share."
  } else {
    parts <- c(
      if (has_vw) "the Van Westendorp curves are estimated on a survey design built from the weights",
      if (has_gg) "Gabor-Granger acceptance is a weighted mean at each rung",
      if (has_mon) "the monadic model is fitted with the weights normalised to mean 1")
    paste0("Weighted by ", as.character(weight_var), ": ",
           paste(parts, collapse = "; "), ".")
  }

  notes <- list()
  if (has_vw) {
    d <- vw$diagnostics %||% list()
    behaviour <- as.character(d$monotonicity_behavior %||% "drop")
    handling <- switch(behaviour,
      "drop" = "respondents whose four prices are not in ascending order were excluded",
      "flag_only" = "respondents whose four prices are not in ascending order were kept and flagged",
      "fix" = "respondents whose four prices are not in ascending order had them sorted",
      paste0("intransitive respondents handled as '", behaviour, "'"))
    notes$vw <- sprintf(
      paste0("Price points are the curve intersections computed by pricesensitivitymeter ",
             "(%s) on %s respondents; %s."),
      as.character(d$estimator %||% "psm_analysis (unweighted)"),
      format(d$n_analysed %||% d$n_valid %||% NA_integer_), handling)
  }
  if (has_gg) {
    d <- gg$diagnostics %||% list()
    bits <- sprintf("Acceptance is the share saying they would buy at each rung, coded %s.",
                    as.character(d$response_coding %||% "binary"))
    smoothing <- as.character(d$smoothing %||% "none")
    if (!identical(smoothing, "none")) {
      bits <- paste(bits, sprintf(
        paste0("The published curve is smoothed (%s) so it never rises with price; ",
               "the observed acceptance is shown beside it."), smoothing))
    }
    imputation <- as.character(d$imputation %||% "none")
    if (!identical(imputation, "none")) bits <- paste(bits, paste0("Imputation: ", imputation, "."))
    notes$gg <- bits
  }
  if (has_mon) {
    ms <- mon$model_summary %||% list()
    form <- if (identical(as.character(ms$model_type %||% "logistic"), "log_logistic")) {
      "a logistic regression of purchase intent on log(price)"
    } else {
      "a logistic regression of purchase intent on price"
    }
    bits <- sprintf("The fitted curve is %s across %s price cells.",
                    form, format(mon$diagnostics$n_cells %||% NA_integer_))
    if (!is.null(ms$p_value_caveat)) bits <- paste(bits, as.character(ms$p_value_caveat))
    notes$monadic <- bits
  }

  n_analysed <- .pricing_drop_null(list(
    vw = if (has_vw) .pricing_scalar(vw$diagnostics$n_analysed %||% vw$diagnostics$n_valid) else NULL,
    gg = if (has_gg) .pricing_scalar(gg$diagnostics$n_respondents) else NULL,
    monadic = if (has_mon) .pricing_scalar(mon$diagnostics$n_valid) else NULL
  ))

  .pricing_drop_null(list(
    schema = PRICING_ISLAND_SCHEMA,
    kind = "pricing",
    islandVersion = PRICING_ISLAND_VERSION,
    moduleVersion = if (exists("PRICING_VERSION")) PRICING_VERSION else NA_character_,
    projectName = as.character(config$project_name %||% ""),
    currency = as.character(config$currency_symbol %||% ""),
    # I() so a one-method run still writes an array; auto_unbox would make
    # `"methods": "monadic"` and the view's array check would miss it.
    methods = I(methods),
    methodLabels = I(unname(method_labels[methods])),
    nRespondents = .pricing_scalar(validation$n_total),
    nValid = .pricing_scalar(validation$n_valid),
    nAnalysed = if (length(n_analysed)) n_analysed else NULL,
    weighted = weighted,
    weightVariable = if (weighted) as.character(weight_var) else NULL,
    effectiveN = effective_n,
    weightingNote = weighting_note,
    estimationNote = if (length(notes)) notes else NULL,
    frozen = TRUE,
    filterNote = paste0(
      "Pricing results are estimated once on the whole sample. They do not ",
      "respond to the audience filter. To break acceptance by audience, use ",
      "the crosstab export (Generate_Tabs_Export)."
    ),
    simulatorFile = .pricing_island_simulator_file(results, config),
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  ))
}


#' The standalone simulator's file name, when this run wrote one
#'
#' Naming a file that was never written would put a dead link on the tab, so
#' this follows the same condition step 9 uses. The classic HTML report the
#' simulator used to be embedded in is retired, so `Generate_Simulator` alone
#' decides.
#'
#' @keywords internal
.pricing_island_simulator_file <- function(results, config) {
  if (!isTRUE(config$generate_simulator) || is.null(results$output_path)) return(NULL)
  basename(sub("[.]xlsx$", "_simulator.html", results$output_path))
}


#' Keep the island's per-row vectors as JSON arrays whatever their length
#'
#' `auto_unbox = TRUE` writes every length-1 vector as a scalar. A
#' Gabor-Granger ladder with one rung, or a monadic test with one cell, would
#' then arrive as `"price": 80` and the view's array check would treat the
#' whole block as absent (the maxdiff review's F2). Every per-row field is
#' wrapped in `I()`, which jsonlite honours as "always an array"; the named
#' scalars in those blocks, and everything in `meta`, stay unboxed.
#'
#' @param island The list from `serialize_pricing_layer()`.
#' @return The same list with per-row vectors marked `AsIs`.
#' @keywords internal
.pricing_island_keep_arrays <- function(island) {
  scalars <- list(
    vw = c("ciLevel", "ciIterations", "ciPolicy", "acceptableLower", "acceptableUpper",
           "optimalLower", "optimalUpper", "nAnalysed", "nComplete",
           "monotonicityBehavior", "curves"),
    gg = c("smoothing", "ciLevel", "optimalRevenuePrice", "optimalRevenueIntentPct",
           "optimalProfitPrice"),
    monadic = c("fitted", "modelType", "pseudoR2", "pValue", "pValueCaveat",
                "optimalPrice", "optimalIntentPct", "optimalProfitPrice"),
    recommendation = c("price", "source", "confidence", "confidenceScore",
                       "acceptableLower", "acceptableUpper", "optimalLower",
                       "optimalUpper", "methodSpreadPct", "nMethodPrices")
  )
  nested <- list(
    vw = list(curves = c("nPoints", "downsampledFrom")),
    monadic = list(fitted = character(0))
  )

  for (block in names(scalars)) {
    b <- island[[block]]
    if (is.null(b)) next
    for (field in names(b)) {
      if (field %in% scalars[[block]]) next
      if (is.atomic(b[[field]]) && !inherits(b[[field]], "AsIs")) b[[field]] <- I(b[[field]])
    }
    # One level down, for the curve sub-blocks.
    inner <- nested[[block]]
    for (sub in names(inner)) {
      s <- b[[sub]]
      if (is.null(s)) next
      for (field in names(s)) {
        if (field %in% inner[[sub]]) next
        if (is.atomic(s[[field]]) && !inherits(s[[field]], "AsIs")) s[[field]] <- I(s[[field]])
      }
      b[[sub]] <- s
    }
    island[[block]] <- b
  }
  island
}
