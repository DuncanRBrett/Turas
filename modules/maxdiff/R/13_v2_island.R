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
# CURATED (programme decision D1, widened by section 6 on 18 Sep 2026):
#   Item scores, preference shares, the estimator's provenance, TURF, anchor
#   must-haves, the discrimination classes, model diagnostics, head-to-head
#   win rates, the per-segment item scores and the per-item utility
#   distributions all travel. The tab is being brought to parity with the
#   classic HTML report so that report can be retired; the checklist for that
#   is docs/v2_lift/MAXDIFF_PARITY_CHECKLIST.md.
#
#   Only the PER-RESPONDENT utilities stay in the Excel deliverable. They are
#   one row per respondent per item, which is what the Excel file is for and
#   far too large for an island that ships inside a client's report. The
#   distributions block carries their shape, not their rows.
#
#   An earlier version of this comment said HB diagnostics and the per-segment
#   tables stayed in Excel on purpose. That stopped being true with section 6.
#
#   Segment cuts under an audience filter remain the crosstab's job via the
#   tabs export. The per-segment scores here are the frozen ones the module
#   estimated, not something the reader can re-cut.
#
# ==============================================================================

# 1.1.0 added the diagnostics, headToHead, segments and distributions blocks
# (section 6). Purely additive, so the schema number does not move.
MAXDIFF_ISLAND_VERSION <- "1.1.0"
MAXDIFF_ISLAND_SCHEMA <- 1L


#' Model Diagnostics For The Island
#'
#' The classic HTML report's diagnostics panel shows four groups of stat cards.
#' Two of its groups never rendered: `transform_diagnostics_section()` read the
#' logit fit from `results$logit_results$fit_stats`, a key nothing in the module
#' writes (it writes `model_fit`), and `build_diagnostics_table()` was never
#' called by any panel. This reads the key that exists.
#'
#' @param results The maxdiff results list.
#' @param config The loaded configuration.
#' @param n_items Integer, the number of items in the island.
#'
#' @return A flat list of scalars, or NULL when there is nothing to describe.
#'
#' @keywords internal
.maxdiff_island_diagnostics <- function(results, config, n_items) {

  # A single finite number or nothing. A fit statistic that arrived as NA, a
  # vector or a character belongs out of the island, not in it as null.
  num1 <- function(x) {
    if (is.null(x) || length(x) != 1L) return(NULL)
    x <- suppressWarnings(as.numeric(x))
    if (!is.finite(x)) return(NULL)
    x
  }

  n_segments <- if (is.data.frame(config$segment_settings)) {
    nrow(config$segment_settings)
  } else {
    0L
  }

  mf <- results$logit_results$model_fit
  fit <- list(
    logLikelihood = num1(mf$log_likelihood),
    aic = num1(mf$aic),
    bic = num1(mf$bic),
    pseudoR2 = num1(mf$mcfadden_r2 %||% mf$pseudo_r2)
  )

  util_stats <- list()
  indiv <- results$hb_results$individual_utilities
  if (!is.null(indiv)) {
    indiv <- .md_drop_id_cols(indiv)
    mat <- NULL
    if (is.data.frame(indiv)) {
      keep <- vapply(indiv, is.numeric, logical(1))
      if (sum(keep) >= 2L) mat <- as.matrix(indiv[, keep, drop = FALSE])
    } else if (is.matrix(indiv) && ncol(indiv) >= 2L) {
      mat <- indiv
    }

    if (!is.null(mat) && nrow(mat) > 0L) {
      k <- ncol(mat)
      item_means <- colMeans(mat, na.rm = TRUE)
      item_sds <- apply(mat, 2, stats::sd, na.rm = TRUE)
      util_range <- max(item_means) - min(item_means)

      # Softmax preference share per respondent. The rows are centred on their
      # own maximum first: exp() of a large utility overflows to Inf and takes
      # every share in that row with it. Centring cancels in the ratio, so the
      # shares are identical to the uncentred form wherever that one survives.
      centred <- mat - apply(mat, 1, max, na.rm = TRUE)
      exp_mat <- exp(centred)
      share_mat <- exp_mat / rowSums(exp_mat, na.rm = TRUE)
      max_shares <- apply(share_mat, 1, max, na.rm = TRUE)
      mean_max_share <- mean(max_shares, na.rm = TRUE)
      chance <- 1 / k

      # Entropy relative to a flat distribution: 0 is a respondent who wants
      # one item, 1 is one who is indifferent across all of them.
      row_entropy <- -rowSums(share_mat * log(share_mat + 1e-10), na.rm = TRUE)
      resp_ranges <- apply(mat, 1, function(r) {
        max(r, na.rm = TRUE) - min(r, na.rm = TRUE)
      })

      util_stats <- list(
        utilityRange = round(util_range, 3),
        meanUtility = round(mean(item_means, na.rm = TRUE), 3),
        # utilitySd and heterogeneity are the same statistic, the mean of the
        # per-item standard deviations. The classic report shows it twice,
        # under "Population spread" and "Avg SD from population", in two
        # different card groups. Both travel so the panel can keep both
        # groups intact and so the two can diverge later without a schema
        # change.
        utilitySd = round(mean(item_sds, na.rm = TRUE), 3),
        discrimination = if (n_items > 0L) round(util_range / n_items, 3) else NULL,
        meanMaxShare = round(mean_max_share * 100, 1),
        chanceLevel = round(chance * 100, 1),
        sharpnessRatio = round(mean_max_share / chance, 1),
        entropyRatio = round(mean(row_entropy, na.rm = TRUE) / log(k), 3),
        heterogeneity = round(mean(item_sds, na.rm = TRUE), 3),
        meanRespondentRange = round(mean(resp_ranges, na.rm = TRUE), 2),
        minRespondentRange = round(min(resp_ranges, na.rm = TRUE), 2),
        maxRespondentRange = round(max(resp_ranges, na.rm = TRUE), 2)
      )
    }
  }

  out <- Filter(
    Negate(is.null),
    c(list(nSegments = as.integer(n_segments)), fit, util_stats)
  )
  # Absent, not empty. A block holding only the segment count says nothing the
  # meta block does not already say, and an empty object is truthy in the view.
  if (length(out) <= 1L) return(NULL)
  out
}


#' Head-To-Head Win Probabilities For The Island
#'
#' The classic report draws an n by n matrix of `compute_head_to_head()` calls,
#' one per ordered pair. P(j beats i) is exactly 1 minus P(i beats j), so the
#' island carries the UPPER TRIANGLE only, in island item order, and the tab
#' derives the mirror. That halves the payload and guarantees a pair sums to
#' 100, which two independently rounded cells do not.
#'
#' Computed in one vectorised pass rather than n squared calls, each of which
#' re-strips and re-matrixes the whole utilities frame.
#'
#' @param results The maxdiff results list.
#' @param ids Character vector of item ids, in island order.
#'
#' @return A list of parallel vectors plus two scalars, or NULL.
#'
#' @keywords internal
.maxdiff_island_head_to_head <- function(results, ids) {

  if (length(ids) < 2L) return(NULL)

  # --- Preferred: one comparison per respondent, averaged ---------------------
  mat <- NULL
  indiv <- results$hb_results$individual_utilities
  if (!is.null(indiv)) {
    indiv <- .md_drop_id_cols(indiv)
    if (is.data.frame(indiv)) {
      keep <- vapply(indiv, is.numeric, logical(1))
      if (any(keep)) mat <- as.matrix(indiv[, keep, drop = FALSE])
    } else if (is.matrix(indiv)) {
      mat <- indiv
    }
    if (!is.null(mat) && (is.null(colnames(mat)) || nrow(mat) == 0L)) mat <- NULL
  }

  # --- Fallback: the population utilities, one notional respondent ------------
  agg <- NULL
  if (is.null(mat)) {
    pop <- results$hb_results$population_utilities
    lu <- results$logit_results$utilities
    if (is.data.frame(pop) && all(c("Item_ID", "HB_Utility_Mean") %in% names(pop))) {
      agg <- stats::setNames(suppressWarnings(as.numeric(pop$HB_Utility_Mean)),
                             as.character(pop$Item_ID))
    } else if (is.data.frame(lu) && all(c("Item_ID", "Logit_Utility") %in% names(lu))) {
      agg <- stats::setNames(suppressWarnings(as.numeric(lu$Logit_Utility)),
                             as.character(lu$Item_ID))
    }
    if (is.null(agg)) return(NULL)
  }

  present <- if (is.null(mat)) ids[ids %in% names(agg)] else ids[ids %in% colnames(mat)]
  present <- present[!is.na(present)]
  if (length(present) < 2L) return(NULL)

  n <- length(present)
  pairs <- utils::combn(n, 2L)
  row_item <- present[pairs[1L, ]]
  col_item <- present[pairs[2L, ]]

  prob <- vapply(seq_len(ncol(pairs)), function(k) {
    a <- present[pairs[1L, k]]
    b <- present[pairs[2L, k]]
    if (is.null(mat)) {
      p <- 1 / (1 + exp(-(agg[[a]] - agg[[b]])))
    } else {
      d <- mat[, a] - mat[, b]
      p <- mean(1 / (1 + exp(-d)), na.rm = TRUE)
    }
    if (!is.finite(p)) return(NA_real_)
    round(p * 100, 1)
  }, numeric(1))

  source <- if (is.null(mat)) "aggregate" else "individual"
  note <- if (is.null(mat)) {
    paste0("There are no individual utilities, so each win rate is computed ",
           "from the population mean utilities as a single notional ",
           "respondent. It answers what the average preference implies, not ",
           "what share of people would choose the item.")
  } else {
    paste0("Each win rate is the average, across respondents, of the ",
           "probability that this respondent would choose the row item over ",
           "the column item.")
  }

  list(
    rowItem = row_item,
    colItem = col_item,
    prob = prob,
    source = source,
    note = note
  )
}


#' Per-Segment Item Scores For The Island
#'
#' `08_segments.R` returns long-format count scores, one row per item per
#' segment level, carrying the level's base. The island carries that shape as
#' parallel vectors, restricted to the island's items and ordered to match
#' them inside each level so the tab can lay the levels out side by side.
#'
#' This is a build, not a port. The classic report's Segments panel never
#' worked: `build_segment_table()` is handed the two-element results list and
#' prints its internal names, "segment_scores" and "segment_summary", as the
#' headings, with Times_Shown, Times_Best, Times_Worst, Rank, Segment_N and N
#' as its columns and no segment level anywhere. `build_segment_chart()` looks
#' for wide `BW_Score_<level>` columns, which nothing produces, and returns an
#' empty string. Both were run against the real shape on 18 Sep 2026.
#'
#' @param results The maxdiff results list.
#' @param config The loaded configuration.
#' @param ids Character vector of item ids, in island order.
#'
#' @return A list of parallel vectors plus two scalars, or NULL.
#'
#' @keywords internal
.maxdiff_island_segments <- function(results, config, ids) {

  seg <- results$segment_results$segment_scores
  if (!is.data.frame(seg) || nrow(seg) == 0L) return(NULL)

  need <- c("Item_ID", "Segment_Label", "Segment_Value")
  if (!all(need %in% names(seg))) return(NULL)

  seg <- seg[as.character(seg$Item_ID) %in% ids, , drop = FALSE]
  if (nrow(seg) == 0L) return(NULL)

  num <- function(x) {
    if (is.null(x)) return(rep(NA_real_, nrow(seg)))
    x <- suppressWarnings(as.numeric(x))
    x[!is.finite(x)] <- NA_real_
    x
  }

  variable <- as.character(seg$Segment_Label)
  level <- as.character(seg$Segment_Value)
  # Order: variable, then level as the config listed it, then island item
  # order inside the level. A level's items must line up with the scores
  # table above them, not with whatever order the segment frame was built in.
  ord <- order(
    match(variable, unique(variable)),
    match(level, unique(level)),
    match(as.character(seg$Item_ID), ids)
  )
  seg <- seg[ord, , drop = FALSE]
  variable <- variable[ord]
  level <- level[ord]

  min_base <- suppressWarnings(as.numeric(
    config$output_settings$Min_Respondents_Per_Segment %||% NA
  ))
  if (length(min_base) != 1L || !is.finite(min_base)) min_base <- NULL

  out <- list(
    variable = variable,
    segmentId = if ("Segment_ID" %in% names(seg)) as.character(seg$Segment_ID) else NULL,
    level = level,
    base = num(seg$Segment_N),
    itemId = as.character(seg$Item_ID),
    netScore = num(seg$Net_Score),
    bestPct = num(seg$Best_Pct),
    worstPct = num(seg$Worst_Pct),
    minBase = min_base,
    note = paste0(
      "Segment scores are count-based: the share of times an item was picked ",
      "best and worst within that group. They are not the model's utilities, ",
      "which were estimated once on the whole sample."
    )
  )
  Filter(Negate(is.null), out)
}


#' Per-Item Utility Distributions For The Island
#'
#' Feeds the violin the classic report draws from `density(vals, n = 32)`. The
#' summary statistics and the density grid both travel as FLAT vectors in
#' island item order: `densityX` and `densityY` hold nItems * nPoints values
#' and the tab slices them with the `nPoints` stride. Nothing in the block is
#' nested, so the whitelist treats it like every other block and there is no
#' nested structure for jsonlite to serialise a way the view does not expect.
#'
#' @param results The maxdiff results list.
#' @param ids Character vector of item ids, in island order.
#' @param ref_pos Integer position of the reference item in `ids`, or NA.
#' @param n_points Integer, points on the density grid.
#'
#' @return A list of parallel vectors plus two scalars, or NULL.
#'
#' @keywords internal
.maxdiff_island_distributions <- function(results, ids, ref_pos = NA_integer_,
                                          n_points = 32L) {

  indiv <- results$hb_results$individual_utilities
  if (is.null(indiv)) return(NULL)
  indiv <- .md_drop_id_cols(indiv)

  mat <- NULL
  if (is.data.frame(indiv)) {
    keep <- vapply(indiv, is.numeric, logical(1))
    if (any(keep)) mat <- as.matrix(indiv[, keep, drop = FALSE])
  } else if (is.matrix(indiv)) {
    mat <- indiv
  }
  if (is.null(mat) || is.null(colnames(mat)) || nrow(mat) == 0L) return(NULL)
  if (!any(ids %in% colnames(mat))) return(NULL)

  n <- length(ids)
  blank <- rep(NA_real_, n)
  summ <- list(mean = blank, median = blank, sd = blank, q25 = blank,
               q75 = blank, min = blank, max = blank)
  dens_x <- rep(NA_real_, n * n_points)
  dens_y <- rep(NA_real_, n * n_points)

  for (i in seq_len(n)) {
    # The reference item is fixed at zero for every respondent on the Stan
    # path, so its distribution is a point mass the model imposed, not
    # something the data showed. Blanked here for the same reason F6 blanks
    # its spread in scores and discrimination.
    if (!is.na(ref_pos) && i == ref_pos) next
    if (!(ids[i] %in% colnames(mat))) next

    v <- suppressWarnings(as.numeric(mat[, ids[i]]))
    v <- v[is.finite(v)]
    if (length(v) < 3L) next

    q <- stats::quantile(v, c(0.25, 0.75), na.rm = TRUE, names = FALSE)
    summ$mean[i] <- mean(v)
    summ$median[i] <- stats::median(v)
    summ$sd[i] <- stats::sd(v)
    summ$q25[i] <- q[1L]
    summ$q75[i] <- q[2L]
    summ$min[i] <- min(v)
    summ$max[i] <- max(v)

    # density() needs spread to pick a bandwidth. An item every respondent
    # scored identically has none, and a violin of it would be a lie anyway.
    if (length(unique(v)) < 3L || !is.finite(stats::sd(v)) || stats::sd(v) <= 0) next
    d <- tryCatch(stats::density(v, n = n_points), error = function(e) NULL)
    if (is.null(d) || length(d$x) != n_points) next
    span <- ((i - 1L) * n_points + 1L):(i * n_points)
    dens_x[span] <- d$x
    dens_y[span] <- d$y
  }

  if (all(is.na(summ$mean))) return(NULL)

  c(
    list(itemId = ids),
    summ,
    list(
      nPoints = as.integer(n_points),
      densityX = dens_x,
      densityY = dens_y,
      note = paste0(
        "Each shape is the spread of one item's utility across respondents, ",
        "estimated from the individual utilities. A wide shape means people ",
        "disagreed about the item; a narrow one means they agreed."
      )
    )
  )
}


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
  # Blank one position of a per-item vector, for the reference item's
  # structural zeros. NULL in, NULL out; no reference item, unchanged.
  .md_blank_ref <- function(v, pos) {
    if (is.null(v) || is.na(pos)) return(v)
    v[pos] <- NA
    v
  }
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

  # --- The item the Stan model fixed at zero ---------------------------------
  # Every utility is relative to this one, so its spread across respondents and
  # its Mean SE are exactly 0 by construction, and classify_item_discrimination()
  # filed it from that zero as Low Priority. A structural zero is not a finding
  # (review M3). Taken from the fit, which knows which slot it anchored;
  # prepare_stan_data moves the designated anchor there, so it is not simply the
  # last item in the config.
  reference_item <- if (identical(method, "stan_hb")) {
    ri <- hb$model_fit$reference_item
    if (is.character(ri) && length(ri) == 1 && ri %in% ids) ri else NULL
  } else NULL
  ref_pos <- if (!is.null(reference_item)) match(reference_item, ids) else NA_integer_

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

  # The reference item's spread and Mean SE are structurally 0, not measured.
  # Blank them so the view shows a dash rather than a confident zero.
  if (!is.na(ref_pos)) {
    if (!is.null(scores$hbSpread)) scores$hbSpread[ref_pos] <- NA_real_
    if (!is.null(scores$hbMeanSe)) scores$hbMeanSe[ref_pos] <- NA_real_
  }

  # --- Discrimination classes (HB runs only) ----------------------------------
  disc <- results$discrimination_data
  disc_block <- if (!is.null(disc) && is.data.frame(disc) && nrow(disc) > 0) {
    drop_null(list(
      itemId = ids,
      # The reference item is classified from a spread that is 0 by
      # construction, so it has no class here: NA, shown as a dash.
      classification = .md_blank_ref(
        as.character(disc$Classification[match(ids, disc$Item_ID)]), ref_pos),
      label = .md_blank_ref(
        as.character(disc$Classification_Label[match(ids, disc$Item_ID)]), ref_pos),
      meanUtility = pick(disc, "Mean_Utility", ids),
      sdUtility = .md_blank_ref(pick(disc, "SD_Utility", ids), ref_pos),
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
    # F5 ruling, and review F1 of this branch: the spread column is the
    # spread across respondents on both paths; the precision of the mean is
    # its own column and is only named here, never as "the spread".
    "stan_hb" = paste0("Individual utilities are posterior means from the Stan ",
                       "model. Spread (SD) is how far those utilities vary ",
                       "across respondents; Mean SE is the precision of the ",
                       "population mean (its posterior standard deviation)."),
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
    # Sampler diagnostics, Stan path only: the island used to carry the
    # estimator's name and nothing about whether the fit behaved (review F6).
    # Absent on every other path, where there is no sampler to diagnose.
    nDivergences = if (identical(method, "stan_hb")) num(hb$diagnostics$n_divergences) else NULL,
    maxTreedepthExceeded = if (identical(method, "stan_hb")) num(hb$diagnostics$max_treedepth_exceeded) else NULL,
    meanRhat = if (identical(method, "stan_hb")) num(hb$diagnostics$mean_rhat) else NULL,
    minEss = if (identical(method, "stan_hb")) num(hb$diagnostics$min_ess) else NULL,
    referenceItem = reference_item,
    referenceItemLabel = if (!is.na(ref_pos)) labels[ref_pos] else NULL,
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
    # Step 12 writes a standalone simulator only when the classic HTML report
    # is OFF; with it on, the simulator is embedded in that report and no
    # file of this name exists (review F3). Same condition as 00_main.R.
    simulatorFile = if (parse_yes_no(config$output_settings$Generate_Simulator %||% FALSE) &&
                        !parse_yes_no(config$output_settings$Generate_HTML_Report %||% FALSE) &&
                        !is.null(results$output_path)) {
      basename(sub("[.]xlsx$", "_simulator.html", results$output_path))
    } else NULL,
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  ))

  diagnostics_block <- .maxdiff_island_diagnostics(results, config, n_items = length(ids))
  h2h_block <- .maxdiff_island_head_to_head(results, ids)
  segments_block <- .maxdiff_island_segments(results, config, ids)
  dist_block <- .maxdiff_island_distributions(results, ids, ref_pos)

  out <- drop_null(list(
    meta = meta,
    scores = scores,
    discrimination = disc_block,
    turf = turf_block,
    anchor = anchor_block,
    diagnostics = diagnostics_block,
    headToHead = h2h_block,
    segments = segments_block,
    distributions = dist_block
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

  jsonlite::write_json(.maxdiff_island_keep_arrays(island), output_file,
                       auto_unbox = TRUE, na = "null", digits = 6, pretty = FALSE)

  if (verbose) cat(sprintf("  Interactive-report contribution: %s\n", basename(output_file)))

  list(
    status = "PASS",
    output_file = output_file,
    n_items = length(island$scores$itemId)
  )
}


#' Keep the island's per-row vectors as JSON arrays whatever their length
#'
#' `auto_unbox = TRUE` writes every length-1 vector as a scalar. A TURF that
#' stops after one item (Karoo under Stan: FRESH reaches 100% at step 1) then
#' arrives as `"step": 1`, and the view's array check treats the whole block
#' as absent (review F2). Every per-row field in the four table blocks is
#' wrapped in `I()`, which jsonlite honours as "always an array"; the named
#' scalars in those blocks, and everything in `meta`, stay unboxed.
#'
#' @param island The list from `serialize_maxdiff_layer()`.
#' @return The same list with per-row vectors marked `AsIs`.
#' @keywords internal
.maxdiff_island_keep_arrays <- function(island) {
  scalars <- list(
    scores = "rescaleMethod",
    turf = c("thresholdMethod", "nRespondents", "maxItems", "note"),
    anchor = c("variable", "threshold"),
    discrimination = "note",
    # Every diagnostics field is a single number. The list is inverted: a
    # field NOT named here is wrapped in I() and ships as a one-element array.
    diagnostics = c(
      "nSegments", "logLikelihood", "aic", "bic", "pseudoR2",
      "utilityRange", "meanUtility", "utilitySd", "discrimination",
      "meanMaxShare", "chanceLevel", "sharpnessRatio", "entropyRatio",
      "heterogeneity", "meanRespondentRange", "minRespondentRange",
      "maxRespondentRange"
    ),
    headToHead = c("source", "note"),
    segments = c("minBase", "note"),
    distributions = c("nPoints", "note")
  )
  for (block in names(scalars)) {
    b <- island[[block]]
    if (is.null(b)) next
    for (field in names(b)) {
      if (field %in% scalars[[block]]) next
      if (is.atomic(b[[field]]) && !inherits(b[[field]], "AsIs")) b[[field]] <- I(b[[field]])
    }
    island[[block]] <- b
  }
  island
}
