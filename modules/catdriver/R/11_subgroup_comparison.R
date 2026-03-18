# ==============================================================================
# CATEGORICAL KEY DRIVER - SUBGROUP COMPARISON
# ==============================================================================
#
# Compares catdriver analysis results across subgroups (e.g., age groups,
# segments, regions). Takes a named list of per-subgroup results and produces
# comparison metrics: importance rankings, OR differences, model fit,
# driver classification (universal / segment-specific / mixed), and
# auto-generated management insights.
#
# Used by:
#   - 00_main.R (when subgroup_var is set in config)
#   - 06c_sheets_subgroup.R (Excel output)
#   - 08_subgroup_report.R (HTML report section)
#
# Version: 1.0
# ==============================================================================


#' Build Subgroup Comparison
#'
#' Master function that takes per-subgroup catdriver results and produces
#' a structured comparison object for reporting.
#'
#' @param subgroup_results Named list of per-group result objects. Each entry
#'   must have at minimum: `status` ("PASS" or "PARTIAL"), `importance` (data frame),
#'   `model_result` (list with `fit_statistics`), and `group_n` (integer).
#' @param config Configuration list (for labels, subgroup_var name, etc.)
#' @return A list with:
#'   \item{importance_matrix}{Data frame of driver ranks/pcts across groups}
#'   \item{or_comparison}{Data frame of top-driver OR values across groups}
#'   \item{model_fit}{Data frame of per-group model fit statistics}
#'   \item{insights}{Character vector of management-ready findings}
#'   \item{subgroup_var}{Name of the subgroup variable}
#'   \item{group_names}{Character vector of group names (including Total if present)}
#'   \item{n_groups}{Number of groups with successful results}
#' @export
build_subgroup_comparison <- function(subgroup_results, config = NULL) {

  # Filter to successful groups only
  successful <- Filter(function(r) {
    !is.null(r$status) && r$status %in% c("PASS", "PARTIAL")
  }, subgroup_results)

  group_names <- names(successful)

  if (length(successful) < 2) {
    return(list(
      importance_matrix = NULL,
      or_comparison = NULL,
      model_fit = NULL,
      insights = "Fewer than 2 subgroups produced results. Comparison not possible.",
      subgroup_var = config$subgroup_var %||% "subgroup",
      group_names = group_names,
      n_groups = length(successful)
    ))
  }

  # --- Build importance comparison matrix ---
  importance_matrix <- build_importance_matrix(successful)

  # --- Classify drivers ---
  importance_matrix <- classify_drivers(importance_matrix, group_names)

  # --- Build OR comparison ---
  or_comparison <- build_or_comparison(successful)

  # --- Build model fit summary ---
  model_fit <- build_model_fit_summary(successful)

  # --- Generate insights ---
  insights <- generate_subgroup_insights(importance_matrix, model_fit, group_names)

  list(
    importance_matrix = importance_matrix,
    or_comparison = or_comparison,
    model_fit = model_fit,
    insights = insights,
    subgroup_var = config$subgroup_var %||% "subgroup",
    group_names = group_names,
    n_groups = length(successful)
  )
}


# ==============================================================================
# IMPORTANCE MATRIX
# ==============================================================================

#' Build Importance Comparison Matrix
#'
#' Creates a data frame with one row per driver variable and columns for each
#' subgroup's importance rank and percentage. Collects all drivers across all
#' groups (handles cases where a driver appears in some groups but not others),
#' and adds summary columns for average rank and maximum rank difference.
#'
#' @param successful Named list of successful subgroup result objects, each
#'   containing an \code{importance} data frame with variable, label, and
#'   importance_pct columns.
#' @return Data frame with columns: variable, label, {group}_rank (integer),
#'   {group}_pct (numeric), avg_rank, max_rank_diff, n_groups_present.
#'   Sorted by avg_rank ascending.
#' @keywords internal
build_importance_matrix <- function(successful) {

  group_names <- names(successful)

  # Collect all drivers across all groups
  all_drivers <- list()

  for (grp in group_names) {
    imp_df <- successful[[grp]]$importance
    if (!is.data.frame(imp_df) || nrow(imp_df) == 0) next

    for (i in seq_len(nrow(imp_df))) {
      var_name <- imp_df$variable[i]
      label <- imp_df$label[i] %||% var_name

      if (!var_name %in% names(all_drivers)) {
        all_drivers[[var_name]] <- list(
          variable = var_name,
          label = label,
          ranks = list(),
          pcts = list()
        )
      }

      all_drivers[[var_name]]$ranks[[grp]] <- i
      all_drivers[[var_name]]$pcts[[grp]] <- as.numeric(imp_df$importance_pct[i])
    }
  }

  if (length(all_drivers) == 0) {
    return(data.frame(
      variable = character(0),
      label = character(0),
      avg_rank = numeric(0),
      max_rank_diff = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  # Build matrix rows
  rows <- lapply(all_drivers, function(drv) {
    row <- data.frame(
      variable = drv$variable,
      label = drv$label,
      stringsAsFactors = FALSE
    )

    # Add per-group rank and pct columns
    for (grp in group_names) {
      rank_col <- paste0(grp, "_rank")
      pct_col <- paste0(grp, "_pct")
      row[[rank_col]] <- drv$ranks[[grp]] %||% NA_integer_
      row[[pct_col]] <- drv$pcts[[grp]] %||% NA_real_
    }

    # Summary columns
    ranks_vec <- unlist(drv$ranks)
    row$avg_rank <- if (length(ranks_vec) > 0) mean(ranks_vec, na.rm = TRUE) else NA_real_
    row$max_rank_diff <- if (length(ranks_vec) >= 2) {
      max(ranks_vec, na.rm = TRUE) - min(ranks_vec, na.rm = TRUE)
    } else {
      0L
    }
    row$n_groups_present <- length(ranks_vec)

    row
  })

  # Combine into data frame
  result <- do.call(rbind, rows)
  rownames(result) <- NULL


  # Sort by average rank ascending
  result <- result[order(result$avg_rank), , drop = FALSE]

  result
}


# ==============================================================================
# DRIVER CLASSIFICATION
# ==============================================================================

#' Classify Drivers as Universal, Segment-Specific, or Mixed
#'
#' Adds a \code{classification} column to the importance matrix based on
#' how consistently a driver ranks across subgroups. Classification rules:
#' Universal = rank <= 3 in ALL groups AND max_rank_diff <= 2;
#' Segment-Specific = rank <= 3 in exactly 1 group AND rank > 5 in all
#' others; Mixed = everything else; Insufficient Data = fewer than 2 groups.
#'
#' @param importance_matrix Data frame from build_importance_matrix() with
#'   columns {group}_rank for each subgroup.
#' @param group_names Character vector of subgroup names matching the column
#'   name prefixes.
#' @return The input data frame with an added \code{classification} column
#'   (character: "Universal", "Segment-Specific", "Mixed", or
#'   "Insufficient Data").
#' @keywords internal
classify_drivers <- function(importance_matrix, group_names) {

  if (is.null(importance_matrix) || nrow(importance_matrix) == 0) {
    return(importance_matrix)
  }

  rank_cols <- paste0(group_names, "_rank")

  importance_matrix$classification <- vapply(seq_len(nrow(importance_matrix)), function(i) {
    ranks <- as.integer(unlist(importance_matrix[i, rank_cols, drop = FALSE]))
    ranks <- ranks[!is.na(ranks)]

    if (length(ranks) < 2) return("Insufficient Data")

    all_top3 <- all(ranks <= 3)
    max_diff <- max(ranks) - min(ranks)
    n_top3 <- sum(ranks <= 3)
    n_below5 <- sum(ranks > 5)

    if (all_top3 && max_diff <= 2) {
      "Universal"
    } else if (n_top3 == 1 && n_below5 == (length(ranks) - 1)) {
      "Segment-Specific"
    } else {
      "Mixed"
    }
  }, character(1))

  importance_matrix
}


# ==============================================================================
# OR COMPARISON
# ==============================================================================

#' Build Odds Ratio Comparison Across Subgroups
#'
#' For each driver-level combination present in any subgroup, collects the
#' odds ratio, confidence interval, and p-value from each group. Computes
#' the OR ratio (max/min across groups) to identify notable differences.
#' Results are sorted by OR ratio descending to surface the most different
#' effects first.
#'
#' @param successful Named list of successful subgroup result objects, each
#'   containing an \code{odds_ratios} data frame with driver, label, level,
#'   or, or_ci_lower, or_ci_upper, and p_value columns.
#' @return Data frame with columns: driver, label, level,
#'   {group}_or (numeric), {group}_ci (character), {group}_p (numeric),
#'   or_ratio (numeric, max/min OR), notable (character, "Yes"/"No"/"-").
#' @keywords internal
build_or_comparison <- function(successful) {

  group_names <- names(successful)

  # Collect all driver-level combinations
  all_or <- list()
  for (grp in group_names) {
    or_df <- successful[[grp]]$odds_ratios
    if (!is.data.frame(or_df) || nrow(or_df) == 0) next

    for (i in seq_len(nrow(or_df))) {
      driver <- or_df$driver[i]
      level <- or_df$level[i]
      key <- paste0(driver, "||", level)

      if (!key %in% names(all_or)) {
        all_or[[key]] <- list(
          driver = driver,
          label = or_df$label[i] %||% driver,
          level = level,
          ors = list(),
          cis = list(),
          ps = list()
        )
      }

      or_val <- or_df$or[i]
      ci_lower <- or_df$or_ci_lower[i]
      ci_upper <- or_df$or_ci_upper[i]
      p_val <- or_df$p_value[i]

      all_or[[key]]$ors[[grp]] <- or_val
      all_or[[key]]$cis[[grp]] <- if (!is.na(ci_lower) && !is.na(ci_upper)) {
        sprintf("%.2f-%.2f", ci_lower, ci_upper)
      } else {
        "-"
      }
      all_or[[key]]$ps[[grp]] <- p_val
    }
  }

  if (length(all_or) == 0) {
    return(data.frame(
      driver = character(0), label = character(0), level = character(0),
      or_ratio = numeric(0), notable = character(0),
      stringsAsFactors = FALSE
    ))
  }

  # Build rows
  rows <- lapply(all_or, function(entry) {
    row <- data.frame(
      driver = entry$driver,
      label = entry$label,
      level = entry$level,
      stringsAsFactors = FALSE
    )

    for (grp in group_names) {
      row[[paste0(grp, "_or")]] <- entry$ors[[grp]] %||% NA_real_
      row[[paste0(grp, "_ci")]] <- entry$cis[[grp]] %||% "-"
      row[[paste0(grp, "_p")]] <- entry$ps[[grp]] %||% NA_real_
    }

    # OR ratio = max / min across groups
    or_vals <- unlist(entry$ors)
    or_vals <- or_vals[!is.na(or_vals) & or_vals > 0]
    if (length(or_vals) >= 2) {
      row$or_ratio <- round(max(or_vals) / min(or_vals), 2)
      row$notable <- if (row$or_ratio > 2.0) "Yes" else "No"
    } else {
      row$or_ratio <- NA_real_
      row$notable <- "-"
    }

    row
  })

  result <- do.call(rbind, rows)
  rownames(result) <- NULL

  # Sort by or_ratio descending (most different first)
  if (nrow(result) > 0 && "or_ratio" %in% names(result)) {
    result <- result[order(-result$or_ratio, na.last = TRUE), , drop = FALSE]
  }

  result
}


# ==============================================================================
# MODEL FIT SUMMARY
# ==============================================================================

#' Build Model Fit Summary Across Subgroups
#'
#' Creates a summary data frame with one row per subgroup containing key
#' model statistics for comparison. Useful for identifying subgroups where
#' the model performs notably better or worse.
#'
#' @param successful Named list of successful subgroup result objects, each
#'   containing \code{model_result} (with fit_statistics, convergence,
#'   engine_used) and \code{group_n}.
#' @return Data frame with columns: subgroup (character), n (integer),
#'   mcfadden_r2 (numeric), aic (numeric), convergence (character "Yes"/"No"),
#'   status (character), engine_used (character).
#' @keywords internal
build_model_fit_summary <- function(successful) {

  rows <- lapply(names(successful), function(grp) {
    res <- successful[[grp]]
    mr <- res$model_result

    fit <- mr$fit_statistics %||% list()

    data.frame(
      subgroup = grp,
      n = res$group_n %||% NA_integer_,
      mcfadden_r2 = round(fit$mcfadden_r2 %||% NA_real_, 4),
      aic = round(fit$aic %||% NA_real_, 1),
      convergence = if (isTRUE(mr$convergence)) "Yes" else "No",
      status = res$status %||% "UNKNOWN",
      engine_used = mr$engine_used %||% "-",
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}


# ==============================================================================
# INSIGHT GENERATION
# ==============================================================================

#' Generate Subgroup Comparison Insights
#'
#' Produces plain-language bullet points summarising key differences and
#' similarities across subgroups, suitable for management reporting. Covers
#' universal drivers, segment-specific drivers, biggest rank movers, and
#' model fit variation.
#'
#' @param importance_matrix Data frame from build_importance_matrix() with
#'   classification column and per-group rank columns.
#' @param model_fit Data frame from build_model_fit_summary() with subgroup
#'   and mcfadden_r2 columns.
#' @param group_names Character vector of subgroup names.
#' @return Character vector of insight strings (one per insight bullet point).
#' @keywords internal
generate_subgroup_insights <- function(importance_matrix, model_fit, group_names) {

  insights <- character(0)

  if (is.null(importance_matrix) || nrow(importance_matrix) == 0) {
    return("No importance data available for comparison.")
  }

  rank_cols <- paste0(group_names, "_rank")

  # --- Universal drivers ---
  universal <- importance_matrix[importance_matrix$classification == "Universal", , drop = FALSE]
  if (nrow(universal) > 0) {
    for (i in seq_len(nrow(universal))) {
      ranks <- as.integer(unlist(universal[i, rank_cols, drop = FALSE]))
      ranks <- ranks[!is.na(ranks)]
      rank_str <- paste0("#", ranks, collapse = ", ")
      insights <- c(insights, sprintf(
        "%s is a universal driver across all subgroups (ranks: %s).",
        universal$label[i], rank_str
      ))
    }
  }

  # --- Segment-specific drivers ---
  seg_specific <- importance_matrix[importance_matrix$classification == "Segment-Specific", , drop = FALSE]
  if (nrow(seg_specific) > 0) {
    for (i in seq_len(nrow(seg_specific))) {
      ranks <- as.integer(unlist(seg_specific[i, rank_cols, drop = FALSE]))
      names(ranks) <- group_names
      ranks <- ranks[!is.na(ranks)]

      top_group <- names(which.min(ranks))
      top_rank <- min(ranks)
      other_ranks <- ranks[names(ranks) != top_group]

      insights <- c(insights, sprintf(
        "%s is segment-specific: #%d for %s but ranked #%s in other groups.",
        seg_specific$label[i],
        top_rank,
        top_group,
        paste0(other_ranks, collapse = "/#")
      ))
    }
  }

  # --- Biggest rank movers ---
  mixed <- importance_matrix[importance_matrix$classification == "Mixed", , drop = FALSE]
  if (nrow(mixed) > 0) {
    # Show top 2 biggest rank differences
    mixed_sorted <- mixed[order(-mixed$max_rank_diff), , drop = FALSE]
    n_show <- min(2, nrow(mixed_sorted))
    for (i in seq_len(n_show)) {
      if (mixed_sorted$max_rank_diff[i] >= 3) {
        ranks <- as.integer(unlist(mixed_sorted[i, rank_cols, drop = FALSE]))
        names(ranks) <- group_names
        ranks <- ranks[!is.na(ranks)]
        best_grp <- names(which.min(ranks))
        worst_grp <- names(which.max(ranks))
        insights <- c(insights, sprintf(
          "%s varies in importance: #%d for %s vs #%d for %s (rank diff: %d).",
          mixed_sorted$label[i],
          min(ranks), best_grp,
          max(ranks), worst_grp,
          mixed_sorted$max_rank_diff[i]
        ))
      }
    }
  }

  # --- Model fit comparison ---
  if (!is.null(model_fit) && nrow(model_fit) >= 2) {
    r2_vals <- model_fit$mcfadden_r2
    names(r2_vals) <- model_fit$subgroup
    r2_vals <- r2_vals[!is.na(r2_vals)]

    if (length(r2_vals) >= 2) {
      best_grp <- names(which.max(r2_vals))
      worst_grp <- names(which.min(r2_vals))
      if (max(r2_vals) - min(r2_vals) >= 0.05) {
        insights <- c(insights, sprintf(
          "Model fit varies across subgroups: %s has strongest explanatory power (R-squared=%.2f) while %s has weakest (R-squared=%.2f).",
          best_grp, max(r2_vals), worst_grp, min(r2_vals)
        ))
      }
    }
  }

  # --- Fallback if no insights generated ---
  if (length(insights) == 0) {
    insights <- "Driver importance rankings are similar across subgroups, with no major differences detected."
  }

  insights
}
