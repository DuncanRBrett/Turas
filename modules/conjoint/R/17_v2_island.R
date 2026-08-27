# ==============================================================================
# CONJOINT ANALYSIS - V2 REPORT DATA ISLAND
# ==============================================================================
#
# Module: Conjoint Analysis - contribution to the interactive (v2) report
# Purpose: Serialise the decision-grade conjoint results into a JSON island the
#          tabs v2 report reads, so conjoint appears as a tab in the client's
#          own report rather than as a second HTML file.
#
# WHY THIS SHAPE, AND NOT NEW ROW KINDS:
#   The V2 migration plan (§4) and the conjoint review (§6) both specify
#   `cj_utility` / `cj_importance` / `cj_fit` row kinds added to
#   build_dl_question() and classify_row_labels(). That premise does not hold.
#   Those functions serialise CROSSTABS: rows keyed by (RowLabel, RowSource),
#   with pct[] / n[] / sig[] arrays indexed by banner column, and bases carrying
#   n / nWeighted / nEff. A part-worth utility has no banner, no base and no
#   percentage. Forcing it through that socket would mean inventing all three.
#
#   The keydriver, catdriver and segment reviews - written the same day as
#   conjoint's - each reached this conclusion independently for their own
#   module and converged on a frozen island plus the module's own view, with
#   zero new row kinds. This is that route, and it supersedes conjoint's §4.
#
# FROZEN, NOT LIVE:
#   The island carries pre-aggregated results only. The v2 reader recomputes
#   crosstabs from microdata under a filter; conjoint results cannot be
#   recomputed that way, because the model was fitted once on the whole sample.
#   So the conjoint tab shows what was estimated and does not respond to the
#   audience filter - the same contract as the Tracking tab.
#
#   No per-respondent betas. The curated bar (programme decision D1) keeps HB
#   diagnostics, individual utilities and MCMC detail in the Excel deliverable.
#
# ==============================================================================

CONJOINT_ISLAND_VERSION <- "1.0.0"
CONJOINT_ISLAND_SCHEMA <- 1L


#' Serialise Conjoint Results as a V2 Report Island
#'
#' @param results The list returned by `run_conjoint_analysis()`.
#' @param verbose Logical, print progress.
#'
#' @return A list ready for `jsonlite::toJSON()`, or NULL when there is nothing
#'   decision-grade to show.
#'
#' @export
serialize_conjoint_layer <- function(results, verbose = TRUE) {

  utilities <- results$utilities
  importance <- results$importance
  model_result <- results$model_result
  config <- results$config

  if (is.null(utilities) || !is.data.frame(utilities) || nrow(utilities) == 0) {
    return(NULL)
  }

  log_verbose("  -> Serialising conjoint results for the interactive report...", verbose)

  method <- model_result$method %||% "unknown"

  num <- function(x) {
    if (is.null(x)) return(NULL)
    x <- suppressWarnings(as.numeric(x))
    x[!is.finite(x)] <- NA_real_
    x
  }

  # jsonlite writes a NULL list element as {} — truthy in JavaScript, and
  # worse than absent: an MNL island (which has no Heterogeneity_SD column)
  # would hand the view "heterogeneity": {} where it expects an array. A
  # field the run did not produce is dropped, at every level.
  drop_null <- function(x) Filter(Negate(is.null), x)

  # --- Utilities, by attribute ---------------------------------------------
  # Zero-centred level utilities with the post-A4 honest intervals: se is the
  # posterior SE of the population mean, NOT the between-respondent spread,
  # which travels separately as heterogeneity so nobody mistakes one for the
  # other.
  attrs <- unique(utilities$Attribute)
  utility_blocks <- lapply(attrs, function(a) {
    rows <- utilities[utilities$Attribute == a, , drop = FALSE]
    drop_null(list(
      attribute = a,
      levels = as.character(rows$Level),
      utility = num(rows$Utility),
      se = num(rows$Std_Error),
      ciLower = num(rows$CI_Lower),
      ciUpper = num(rows$CI_Upper),
      heterogeneity = num(rows$Heterogeneity_SD),
      pValue = num(rows$p_value),
      isBaseline = as.logical(rows$is_baseline)
    ))
  })

  # --- Importance -----------------------------------------------------------
  importance_block <- NULL
  if (!is.null(importance) && is.data.frame(importance) && nrow(importance) > 0) {
    ord <- order(-num(importance$Importance))
    imp <- importance[ord, , drop = FALSE]
    importance_block <- drop_null(list(
      # Named so the reader knows what they are looking at: "individual" means
      # each respondent's own importance was computed before averaging.
      method = attr(importance, "importance_method") %||% "aggregate",
      attribute = as.character(imp$Attribute),
      importance = num(imp$Importance),
      sd = if ("SD" %in% names(imp)) num(imp$SD) else NULL
    ))
  }

  # --- Model fit ------------------------------------------------------------
  fit <- results$diagnostics$fit_statistics %||% NULL
  fit_block <- if (!is.null(fit)) {
    drop_null(list(
      mcFaddenR2 = num(fit$mcfadden_r2),
      adjMcFaddenR2 = num(fit$adj_mcfadden_r2),
      hitRate = num(fit$hit_rate),
      chanceRate = num(fit$chance_rate),
      logLikelihoodFitted = num(fit$log_likelihood_fitted),
      logLikelihoodNull = num(fit$log_likelihood_null),
      nObservations = num(fit$n_obs),
      nParameters = num(fit$n_parameters)
    ))
  } else NULL

  # --- Willingness to pay (optional) ----------------------------------------
  wtp <- results$wtp %||% results$wtp_result %||% NULL
  wtp_block <- NULL
  if (!is.null(wtp) && !is.null(wtp$wtp_table) && nrow(wtp$wtp_table) > 0) {
    w <- wtp$wtp_table
    wtp_block <- drop_null(list(
      priceAttribute = wtp$price_attribute %||% NA_character_,
      currency = config$currency_symbol %||% "$",
      attribute = as.character(w$Attribute),
      level = as.character(w$Level),
      wtp = num(w$WTP),
      ciLower = num(w$WTP_Lower),
      ciUpper = num(w$WTP_Upper),
      isBaseline = as.logical(w$is_baseline),
      # The interval is a delta-method approximation on a price slope fitted
      # through a handful of estimated utilities. The reader is told, in the
      # island, so the view cannot forget to say it.
      intervalNote = paste0(
        "Approximate: the delta method applied to a price slope fitted ",
        "through the estimated price utilities, not a sampling interval."
      )
    ))
  }

  # --- Provenance -----------------------------------------------------------
  meta <- list(
    schema = CONJOINT_ISLAND_SCHEMA,
    kind = "conjoint",
    islandVersion = CONJOINT_ISLAND_VERSION,
    moduleVersion = get_conjoint_version(),
    projectName = config$project_name %||% "",
    method = method,
    methodLabel = .conjoint_island_method_label(method),
    nRespondents = model_result$n_respondents %||% NA,
    nChoiceSets = model_result$n_choice_sets %||% NA,
    nAttributes = length(attrs),
    zeroCentred = isTRUE(config$zero_center_utilities %||% TRUE),
    converged = if (!is.null(model_result$convergence)) {
      isTRUE(model_result$convergence$converged)
    } else NA,
    seMethod = model_result$se_method %||% NA_character_,
    # Frozen, and the view says so: the audience filter cannot apply, because
    # the model was fitted once on the whole sample.
    frozen = TRUE,
    filterNote = paste0(
      "Conjoint results are estimated once on the whole sample. They do not ",
      "respond to the audience filter. To break importance by audience, use ",
      "the crosstab export (generate_tabs_export)."
    ),
    unweightedNote = "The conjoint model is estimated unweighted.",
    # The simulator is a separate file, by decision: it is a tool, not report
    # content, and embedding it would put a second copy of the engine in every
    # report. Named here so the view can link to it when it exists.
    simulatorFile = if (isTRUE(config$generate_html_simulator)) {
      basename(sub("[.]xlsx$", "_simulator.html",
                   config$output_file %||% "conjoint_results.xlsx"))
    } else NA_character_,
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )

  out <- list(
    meta = meta,
    utilities = utility_blocks,
    importance = importance_block,
    fit = fit_block,
    wtp = wtp_block
  )

  # An absent block must be ABSENT in the JSON, not an empty object: jsonlite
  # writes a NULL list element as {}, and {} is truthy in JavaScript — an HB
  # run (which has no mlogit-style fit statistics) rendered a Model fit panel
  # of seven em-dashes that way (C-delta review, finding 2).
  out <- Filter(Negate(is.null), out)

  log_verbose(sprintf("  OK Conjoint island: %d attributes, %d levels",
                      length(attrs), nrow(utilities)), verbose)

  out
}


#' Write the Conjoint Island Contribution File
#'
#' A conjoint run writes its contribution; a later tabs run for the same
#' project embeds it. This is the pattern the tracker already uses for wave
#' contributions - no pipeline is re-run, and neither module has to know how
#' the other works beyond this file.
#'
#' @param results The list returned by `run_conjoint_analysis()`.
#' @param output_file Path for the JSON. Defaults to the main output file's name
#'   with `_cj_island.json` in place of `.xlsx`.
#' @param verbose Logical.
#'
#' @return A list with `status`, `output_file` and `n_attributes`.
#'
#' @export
write_conjoint_island <- function(results, output_file = NULL, verbose = TRUE) {

  island <- serialize_conjoint_layer(results, verbose = verbose)

  if (is.null(island)) {
    conjoint_refuse(
      code = "CALC_NO_ISLAND_CONTENT",
      title = "Nothing To Contribute To The Interactive Report",
      problem = "The analysis produced no utilities table, so there is nothing to serialise.",
      why_it_matters = "An empty island would add a Conjoint tab with nothing in it.",
      how_to_fix = "Check the console above - the analysis did not complete."
    )
  }

  if (is.null(output_file)) {
    base <- results$config$output_file %||% "conjoint_results.xlsx"
    output_file <- sub("[.]xlsx$", "_cj_island.json", base)
    if (identical(output_file, base)) output_file <- paste0(base, "_cj_island.json")
  }

  jsonlite::write_json(island, output_file, auto_unbox = TRUE,
                       na = "null", digits = 6, pretty = FALSE)

  log_verbose(sprintf("  OK Interactive-report contribution: %s",
                      basename(output_file)), verbose)

  list(
    status = "PASS",
    output_file = output_file,
    n_attributes = length(island$utilities)
  )
}


#' Read a Conjoint Contribution and Return It as Island JSON
#'
#' Called by the tabs pipeline. Returns NULL - not an error - when no
#' contribution is configured or the file is absent, so a tabs run without
#' conjoint is unaffected.
#'
#' @param path Path to a `_cj_island.json` written by `write_conjoint_island()`.
#' @return A single JSON string, or NULL.
#'
#' @export
read_conjoint_island_json <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) return(NULL)

  txt <- tryCatch(paste(readLines(path, warn = FALSE), collapse = ""),
                  error = function(e) NULL)
  if (is.null(txt) || !nzchar(trimws(txt))) return(NULL)

  parsed <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE),
                     error = function(e) NULL)
  if (is.null(parsed) || !identical(parsed$meta$kind, "conjoint")) {
    cat(sprintf(
      "[TRS WARNING] CONJ_ISLAND_UNREADABLE: %s is not a conjoint contribution file; the Conjoint tab will not appear.\n",
      basename(path)
    ))
    return(NULL)
  }

  txt
}


#' @keywords internal
.conjoint_island_method_label <- function(method) {
  switch(
    method,
    "hierarchical_bayes" = "Hierarchical Bayes",
    "latent_class" = "Latent class",
    "mlogit" = "Multinomial logit",
    "clogit" = "Conditional logit",
    "best_worst_sequential" = "Best-worst (sequential)",
    "ols_rating" = "Rating-based (OLS)",
    method
  )
}


message(sprintf("TURAS>Conjoint v2 island loaded (v%s)", CONJOINT_ISLAND_VERSION))
