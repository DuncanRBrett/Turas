# ==============================================================================
# MAXDIFF - V2 REPORT DATA ISLAND
# ==============================================================================
#
# Module: MaxDiff - contribution to the interactive (v2) report
# Purpose: Serialise the decision-grade MaxDiff results into a JSON island the
#          tabs v2 report reads, so MaxDiff appears as a tab in the client's
#          own report rather than as a second HTML file.
#
# WHY AN ISLAND AND NOT NEW ROW KINDS:
#   The maxdiff handover (Session C) specified md_utility / md_share / md_bw /
#   md_anchor / md_turf_step row kinds through build_dl_question(). Conjoint
#   Session C established, and its notes record, that those functions
#   serialise CROSSTABS: rows keyed by (RowLabel, RowSource) with pct[] / n[]
#   / sig[] arrays indexed by banner column. A MaxDiff utility has no banner
#   and no percentage of a base. Keydriver, catdriver and segment each
#   reached the same conclusion for their own module. This file follows the
#   conjoint precedent: a frozen island plus the module's own view, zero new
#   row kinds.
#
# FROZEN, NOT LIVE:
#   The island carries pre-aggregated results only. The v2 reader recomputes
#   crosstabs from microdata under the audience filter; MaxDiff results were
#   estimated once on the whole sample and cannot be recomputed that way. The
#   tab shows what was estimated and says so. Breaking shares by audience is
#   the tabs export's job (12_tabs_export.R), where they become an Allocation
#   question the reader CAN filter.
#
# CURATED (programme decision D1):
#   Item scores, preference shares, the estimator's provenance, TURF, anchor
#   must-haves and the discrimination classes travel. HB diagnostics, the
#   per-respondent utilities and the per-segment tables stay in the Excel
#   deliverable. Segment cuts are the crosstab's job via the tabs export.
#
# ==============================================================================

MAXDIFF_ISLAND_VERSION <- "1.0.0"
MAXDIFF_ISLAND_SCHEMA <- 1L


#' Serialise MaxDiff Results As A V2 Report Island
#'
#' @param results The results list built in `run_maxdiff_generate_outputs()`.
#' @param config The loaded maxdiff configuration.
#' @param verbose Logical, print progress.
#'
#' @return A list ready for `jsonlite::toJSON()`, or NULL when there is nothing
#'   decision-grade to show (no item scored).
#'
#' @export
serialize_maxdiff_layer <- function(results, config, verbose = TRUE) {

  counts <- results$count_scores
  logit <- results$logit_results
  hb <- results$hb_results
  items <- config$items

  if (is.null(items) || !is.data.frame(items) || nrow(items) == 0) return(NULL)
  included <- items[items$Include == 1, , drop = FALSE]
  if ("Display_Order" %in% names(included)) {
    included <- included[order(included$Display_Order), , drop = FALSE]
  }
  if (nrow(included) == 0) return(NULL)

  has_counts <- !is.null(counts) && is.data.frame(counts) && nrow(counts) > 0
  has_logit <- !is.null(logit) && is.data.frame(logit$utilities) && nrow(logit$utilities) > 0
  has_hb <- !is.null(hb) && is.data.frame(hb$population_utilities) &&
    nrow(hb$population_utilities) > 0
  if (!has_counts && !has_logit && !has_hb) return(NULL)

  if (verbose) cat("  Serialising MaxDiff results for the interactive report...\n")

  num <- function(x) {
    if (is.null(x)) return(NULL)
    x <- suppressWarnings(as.numeric(x))
    x[!is.finite(x)] <- NA_real_
    x
  }
  # jsonlite writes a NULL list element as {} (truthy in JavaScript). A block
  # the run did not produce must be ABSENT, at every level.
  drop_null <- function(x) Filter(Negate(is.null), x)
  # A column pulled out of a frame in the island's item order, or NULL.
  pick <- function(df, col, ids) {
    if (is.null(df) || !col %in% names(df)) return(NULL)
    num(df[[col]][match(ids, df$Item_ID)])
  }
  # As pick(), but a column that is entirely missing stays out of the island
  # rather than arriving as an array of nulls the view has to guess about.
  pick_present <- function(df, col, ids) {
    v <- pick(df, col, ids)
    if (is.null(v) || all(is.na(v))) return(NULL)
    v
  }

  ids <- as.character(included$Item_ID)
  labels <- as.character(included$Item_Label %||% included$Item_ID)
  groups <- if ("Item_Group" %in% names(included)) as.character(included$Item_Group) else NULL
  if (!is.null(groups) && all(is.na(groups) | groups == "")) groups <- NULL

  # --- Which estimator the headline scores come from -------------------------
  hb_method <- hb$model_fit$method %||% hb$diagnostics$method %||% NA_character_
  method <- if (has_hb && identical(hb_method, "cmdstanr")) {
    "stan_hb"
  } else if (has_hb) {
    "empirical_bayes"
  } else if (has_logit) {
    "aggregate_logit"
  } else {
    "counts"
  }

  # --- Preference shares -----------------------------------------------------
  # From individual utilities when there are any (mean of per-respondent
  # softmax), else from the aggregate utilities, else absent.
  shares <- NULL
  if (has_hb && is.data.frame(hb$individual_utilities) && nrow(hb$individual_utilities) > 0) {
    s <- tryCatch(compute_preference_shares(individual_utils = hb$individual_utilities),
                  error = function(e) numeric(0))
    if (length(s) > 0) shares <- num(s[ids])
  } else if (has_logit) {
    lu <- logit$utilities
    agg <- setNames(num(lu$Logit_Utility), as.character(lu$Item_ID))
    s <- tryCatch(compute_preference_shares(aggregate_utils = agg[ids]),
                  error = function(e) numeric(0))
    if (length(s) > 0) shares <- num(s[ids])
  }

  # --- The headline utility the Excel ITEM_SCORES sheet rescales -------------
  headline <- if (has_hb) pick(hb$population_utilities, "HB_Utility_Mean", ids)
              else if (has_logit) pick(logit$utilities, "Logit_Utility", ids)
              else pick(counts, "Net_Score", ids)
  rescale_method <- config$output_settings$Score_Rescale_Method %||% "0_100"
  rescaled <- if (!is.null(headline) && exists("rescale_utilities", mode = "function")) {
    num(tryCatch(rescale_utilities(headline, rescale_method), error = function(e) NULL))
  } else NULL

  # --- Scores block: parallel arrays in item order ------------------------------
  scores <- drop_null(list(
    itemId = ids,
    label = labels,
    group = groups,
    timesShown = pick(counts, "Times_Shown", ids),
    timesBest = pick(counts, "Times_Best", ids),
    timesWorst = pick(counts, "Times_Worst", ids),
    bestPct = pick(counts, "Best_Pct", ids),
    worstPct = pick(counts, "Worst_Pct", ids),
    netScore = pick(counts, "Net_Score", ids),
    logitUtility = pick(logit$utilities, "Logit_Utility", ids),
    logitSe = pick(logit$utilities, "Logit_SE", ids),
    hbUtility = pick(hb$population_utilities, "HB_Utility_Mean", ids),
    # One meaning on both paths, per Duncan's F5 ruling: the spread of the
    # shipped individual utilities across respondents, a heterogeneity. The
    # precision of the population mean is a separate column, and exists only
    # where there is a posterior to take it from.
    hbSpread = pick(hb$population_utilities, "HB_Utility_SD", ids),
    hbMeanSe = pick_present(hb$population_utilities, "HB_Mean_SE", ids),
    share = shares,
    rescaled = rescaled,
    rescaleMethod = if (!is.null(rescaled)) rescale_method else NULL
  ))

  # --- Discrimination classes (HB runs only) ----------------------------------
  disc <- results$discrimination_data
  disc_block <- if (!is.null(disc) && is.data.frame(disc) && nrow(disc) > 0) {
    drop_null(list(
      itemId = ids,
      classification = as.character(disc$Classification[match(ids, disc$Item_ID)]),
      label = as.character(disc$Classification_Label[match(ids, disc$Item_ID)]),
      meanUtility = pick(disc, "Mean_Utility", ids),
      sdUtility = pick(disc, "SD_Utility", ids),
      note = paste0("Classes come from median splits on the mean and the ",
                    "spread of individual utilities: a universal favourite is ",
                    "high and agreed on, a polarising item is one respondents ",
                    "disagree about.")
    ))
  } else NULL

  # --- TURF -------------------------------------------------------------------
  turf <- results$turf_results
  turf_block <- NULL
  if (!is.null(turf) && is.data.frame(turf$incremental_table) &&
      nrow(turf$incremental_table) > 0) {
    it <- turf$incremental_table
    turf_block <- drop_null(list(
      thresholdMethod = as.character(turf$threshold_method %||% NA_character_),
      nRespondents = num(turf$n_respondents),
      maxItems = num(turf$max_items_evaluated),
      step = num(it$Step),
      itemId = as.character(it$Item_ID),
      label = as.character(it$Item_Label %||% it$Item_ID),
      reachPct = num(it$Reach_Pct),
      incrementalPct = num(it$Incremental_Pct),
      frequency = if ("Frequency" %in% names(it)) num(it$Frequency) else NULL,
      note = paste0("Reach is the share of respondents for whom at least one ",
                    "item in the portfolio is appealing, added greedily one ",
                    "item at a time. Appeal is judged per respondent from ",
                    "individual utilities.")
    ))
  }

  # --- Anchor (must-have) ------------------------------------------------------
  anchor <- results$anchor_data
  anchor_block <- NULL
  if (!is.null(anchor) && is.data.frame(anchor) && nrow(anchor) > 0) {
    anchor_block <- drop_null(list(
      variable = as.character(config$output_settings$Anchor_Variable %||% NA_character_),
      threshold = num(config$output_settings$Anchor_Threshold),
      itemId = as.character(anchor$Item_ID),
      label = as.character(anchor$Item_Label %||% anchor$Item_ID),
      rate = num(anchor$Anchor_Rate),
      count = num(anchor$Anchor_Count),
      isMustHave = as.logical(anchor$Is_Must_Have)
    ))
  }

  # --- Provenance ---------------------------------------------------------------
  ss <- results$study_summary
  weighted <- isTRUE(ss$weighted)
  ps <- config$project_settings
  # Items per task: from the long data when it is there (one row per item
  # shown), else from a wide design file's Item{n}_ID columns.
  items_per_task <- NA_integer_
  ld <- results$long_data
  if (is.data.frame(ld) && all(c("resp_id", "task", "item_id") %in% names(ld)) && nrow(ld) > 0) {
    ver <- if ("version" %in% names(ld)) ld$version else 1
    items_per_task <- as.integer(max(table(paste(ld$resp_id, ver, ld$task))))
  } else if (is.data.frame(results$design)) {
    n_cols <- length(grep("^Item[0-9]+_ID$", names(results$design)))
    if (n_cols > 0) items_per_task <- n_cols
  }

  method_label <- switch(method,
    "stan_hb" = "Stan hierarchical Bayes",
    "empirical_bayes" = "Empirical Bayes fallback (count-based)",
    "aggregate_logit" = "Aggregate conditional logit",
    "counts" = "Count scores")
  estimation_note <- switch(method,
    "stan_hb" = paste0("Individual utilities are posterior means from the Stan ",
                       "model; the spread column is the posterior SD of the ",
                       "population mean."),
    "empirical_bayes" = paste0("cmdstanr was not available, so the utilities are ",
                               "empirical-Bayes shrunken best-minus-worst counts, ",
                               "not Bayesian posterior estimates. The spread column ",
                               "is the population spread of those scores, not ",
                               "posterior uncertainty."),
    "aggregate_logit" = paste0("One conditional logit fitted to the whole sample; ",
                               "the anchor item is fixed at zero and the standard ",
                               "errors treat each task as independent."),
    "counts" = "Best and worst counts only; no model was fitted.")

  meta <- drop_null(list(
    schema = MAXDIFF_ISLAND_SCHEMA,
    kind = "maxdiff",
    islandVersion = MAXDIFF_ISLAND_VERSION,
    moduleVersion = if (exists("MAXDIFF_VERSION")) MAXDIFF_VERSION else NA_character_,
    projectName = ps$Project_Name %||% "",
    method = method,
    methodLabel = method_label,
    estimationNote = estimation_note,
    nRespondents = num(ss$n_respondents),
    nTasks = num(ss$n_tasks),
    nItems = length(ids),
    itemsPerTask = num(items_per_task),
    weighted = weighted,
    effectiveN = if (weighted) num(ss$effective_n) else NULL,
    weightingNote = if (weighted) {
      paste0("Count scores are weighted by ", ps$Weight_Variable %||% "the weight variable",
             ". The utilities are estimated unweighted.")
    } else "Unweighted.",
    frozen = TRUE,
    filterNote = paste0(
      "MaxDiff results are estimated once on the whole sample. They do not ",
      "respond to the audience filter. To break preference shares by audience, ",
      "use the crosstab export (Generate_Tabs_Export)."
    ),
    simulatorFile = if (isTRUE(config$output_settings$Generate_Simulator) &&
                        !is.null(results$output_path)) {
      basename(sub("[.]xlsx$", "_simulator.html", results$output_path))
    } else NULL,
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  ))

  out <- drop_null(list(
    meta = meta,
    scores = scores,
    discrimination = disc_block,
    turf = turf_block,
    anchor = anchor_block
  ))

  if (verbose) cat(sprintf("  MaxDiff island: %d items, method %s\n", length(ids), method))
  out
}


#' Write The MaxDiff Island Contribution File
#'
#' A maxdiff run writes its contribution; a later tabs run for the same
#' project embeds it (the tabs config's `maxdiff_island` setting). The same
#' arrangement conjoint uses, and the tracker before it.
#'
#' @param results The results list from `run_maxdiff_generate_outputs()`.
#' @param config The loaded maxdiff configuration.
#' @param output_file Path for the JSON. Defaults to the main output file's name
#'   with `_md_island.json` in place of `.xlsx`.
#' @param verbose Logical.
#'
#' @return A list with `status`, `output_file` and `n_items`.
#'
#' @export
write_maxdiff_island <- function(results, config, output_file = NULL, verbose = TRUE) {

  island <- serialize_maxdiff_layer(results, config, verbose = verbose)

  if (is.null(island)) {
    maxdiff_refuse(
      code = "MODEL_NO_ISLAND_CONTENT",
      title = "Nothing To Contribute To The Interactive Report",
      problem = "The run scored no items, so there is nothing to serialise.",
      why_it_matters = "An empty island would add a MaxDiff tab with nothing in it.",
      how_to_fix = "Check the console above; the analysis did not complete."
    )
  }

  if (is.null(output_file)) {
    base <- results$output_path %||% "maxdiff_results.xlsx"
    output_file <- sub("[.]xlsx$", "_md_island.json", base)
    if (identical(output_file, base)) output_file <- paste0(base, "_md_island.json")
  }

  jsonlite::write_json(island, output_file, auto_unbox = TRUE,
                       na = "null", digits = 6, pretty = FALSE)

  if (verbose) cat(sprintf("  Interactive-report contribution: %s\n", basename(output_file)))

  list(
    status = "PASS",
    output_file = output_file,
    n_items = length(island$scores$itemId)
  )
}
