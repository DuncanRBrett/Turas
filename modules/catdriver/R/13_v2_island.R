# ==============================================================================
# CATDRIVER. V2 REPORT ISLAND (TR.CD)
# ==============================================================================
# A catdriver run writes `{output}_cd_island.json`; a later tabs run for the
# same project embeds it when its `catdriver_island` setting names the file.
# The two modules meet through one file and neither has to know how the other
# works. The arrangement conjoint, maxdiff, pricing and keydriver use.
#
# WHY A SEPARATE ISLAND RATHER THAN CROSSTAB ROWS. The migration plan assumed
# the analytical modules would ride in on the existing row machinery. They
# cannot. Every AGG question in the data layer shares the banner's column list,
# and catdriver's axes are drivers by levels and drivers by subgroups, not
# banner columns. An odds ratio has no base and no percentage; a driver level
# has no banner. And there is no microdata to recompute from: the fitted
# probabilities a run produces are model estimates of a tabs-native outcome
# column, smoothed and with artificially reduced variance, so exporting them as
# respondent data would invite a reader to cross-tabulate a model. So this
# island is FROZEN, like tracking's, pricing's and keydriver's. The view says
# so and the filter bar is hidden while it is open.
#
# WHAT TRAVELS, AND WHY (the curated list, logged against V2_MIGRATION_PLAN
# section 7):
#   IN   importance per driver, with the method that computed it
#   IN   odds ratios per driver level, with Wald intervals, bootstrap intervals
#        and sign stability where a bootstrap ran
#   IN   probability lifts, with the outcome level they describe
#   IN   factor patterns: the raw picture behind each driver
#   IN   model fit, the base, the weighting statement and the assumption checks
#   IN   the subgroup importance matrix and its odds-ratio comparison
#   OUT  the per-level coefficient tables, the full missing-data report, the
#        collapse report and the bootstrap resample matrix. They stay in the
#        Excel deliverable, whose audience is the analyst.
#
# NO SIGNIFICANCE LETTERS. Importance and odds ratios are model estimates. The
# crosstab significance engine tests proportions and means on counts, and
# borrowing its letters for a regression coefficient would dress one kind of
# uncertainty in another kind's clothes. The interval is the uncertainty
# statement here, and the view carries no letters.
#
# AN ABSENT INTERVAL IS NOT A ZERO INTERVAL. The bootstrap is optional and does
# not run for multinomial outcomes at all. Where it did not run, the island
# carries the Wald interval and says the bootstrap is absent, rather than
# shipping an empty field the view might draw as a whisker of width nothing.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' The island schema this module writes
#' @keywords internal
CD_ISLAND_SCHEMA_VERSION <- 1L


# ==============================================================================
# ENTRY POINTS
# ==============================================================================

#' Serialise CatDriver Results As A V2 Report Island
#'
#' @param results The list a catdriver run returns: `importance`, `odds_ratios`,
#'   `probability_lift`, `factor_patterns`, `model_result`, `diagnostics`,
#'   `weight_diagnostics`, `bootstrap_results`, `subgroup_comparison`,
#'   `run_status` and `degraded_reasons`.
#' @param config The loaded catdriver configuration.
#' @param verbose Logical, print progress.
#'
#' @return A list ready for `jsonlite::toJSON()`, or NULL when the run produced
#'   no importance table, which is the only block the view cannot do without.
#'
#' @export
serialize_catdriver_layer <- function(results, config, verbose = TRUE) {

  imp <- results$importance
  if (is.null(imp) || !is.data.frame(imp) || nrow(imp) == 0) return(NULL)

  if (verbose) cat("  Serialising categorical driver results for the interactive report...\n")

  labels <- .cd_island_labels(imp, config)

  importance_block <- .cd_island_importance(imp)
  or_block         <- .cd_island_odds_ratios(results$odds_ratios, labels)
  lift_block       <- .cd_island_lifts(results$probability_lift)
  patterns_block   <- .cd_island_patterns(results$factor_patterns, labels)
  fit_block        <- .cd_island_fit(results)
  subgroups_block  <- .cd_island_subgroups(results$subgroup_comparison)

  meta <- .cd_island_meta(results, config,
                          n_drivers = nrow(imp),
                          has_or = !is.null(or_block),
                          has_lifts = !is.null(lift_block),
                          has_subgroups = !is.null(subgroups_block))

  out <- .cd_island_drop_null(list(
    meta        = meta,
    importance  = importance_block,
    odds_ratios = or_block,
    lifts       = lift_block,
    patterns    = patterns_block,
    fit         = fit_block,
    subgroups   = subgroups_block
  ))

  if (verbose) {
    cat(sprintf("  Categorical driver island: %d driver(s)%s%s%s\n",
                nrow(imp),
                if (!is.null(or_block)) sprintf(", %d odds ratio(s)", length(or_block$rows)) else "",
                if (!is.null(lift_block)) ", probability lifts" else "",
                if (!is.null(subgroups_block)) ", subgroups" else ""))
  }
  out
}


#' Write The CatDriver Island Contribution File
#'
#' @param results As `serialize_catdriver_layer()`.
#' @param config The loaded catdriver configuration.
#' @param output_file Path for the JSON. Defaults to the run's output workbook
#'   with `_cd_island.json` in place of `.xlsx`.
#' @param verbose Logical.
#'
#' @return A list with `status`, and `output_file` when one was written.
#'
#' @export
write_catdriver_island <- function(results, config, output_file = NULL,
                                   verbose = TRUE) {

  island <- serialize_catdriver_layer(results, config, verbose = verbose)

  # No refusal here. A run with no importance table has already said why, and
  # a missing tab is not worth failing an otherwise good run over.
  if (is.null(island)) {
    if (verbose) {
      cat(paste0("  [NOTE] No importance table, so no contribution to the ",
                 "interactive report was written.\n"))
    }
    return(list(status = "SKIPPED", output_file = NULL))
  }

  if (is.null(output_file)) {
    base <- config$output_file %||% "catdriver_results.xlsx"
    output_file <- sub("[.]xlsx$", "_cd_island.json", base)
    if (identical(output_file, base)) output_file <- paste0(base, "_cd_island.json")
  }

  ok <- tryCatch({
    jsonlite::write_json(.cd_island_keep_arrays(island), output_file,
                         auto_unbox = TRUE, na = "null", digits = 6, pretty = FALSE)
    TRUE
  }, error = function(e) {
    cat(sprintf("  [WARN] Could not write the interactive-report contribution: %s\n",
                conditionMessage(e)))
    FALSE
  })
  if (!isTRUE(ok)) return(list(status = "FAILED", output_file = NULL))

  if (verbose) cat(sprintf("  + Interactive report contribution: %s\n", basename(output_file)))
  list(status = "OK", output_file = output_file)
}


# ==============================================================================
# BLOCKS
# ==============================================================================

#' One label per driver, so every panel says the same thing
#' @keywords internal
.cd_island_labels <- function(imp, config) {
  labels <- list()
  if (!is.null(imp$variable)) {
    for (i in seq_len(nrow(imp))) {
      labels[[as.character(imp$variable[i])]] <-
        as.character(imp$label[i] %||% imp$variable[i])
    }
  }
  labels
}

#' Importance, with the method that produced it (D5)
#' @keywords internal
.cd_island_importance <- function(imp) {
  rows <- lapply(seq_len(nrow(imp)), function(i) {
    .cd_island_drop_null(list(
      driver     = as.character(imp$variable[i]),
      label      = as.character(imp$label[i] %||% imp$variable[i]),
      pct        = .cd_island_scalar(imp$importance_pct[i]),
      statistic  = .cd_island_scalar(imp$chi_square[i]),
      df         = .cd_island_scalar(imp$df[i]),
      p          = .cd_island_scalar(imp$p_value[i]),
      rank       = .cd_island_scalar(imp$rank[i]),
      effect     = as.character(imp$effect_size[i] %||% NA_character_),
      stability  = as.character(imp$stability_flag[i] %||% NA_character_)
    ))
  })
  methods <- unique(as.character(imp$method %||% character(0)))
  methods <- methods[!is.na(methods) & nzchar(methods)]
  .cd_island_drop_null(list(
    method = if (length(methods) > 0) paste(methods, collapse = "; ") else NULL,
    rows   = rows
  ))
}

#' Odds ratios per driver level, with whatever interval actually exists
#' @keywords internal
.cd_island_odds_ratios <- function(or_df, labels) {
  if (is.null(or_df) || !is.data.frame(or_df) || nrow(or_df) == 0) return(NULL)
  if (!"factor" %in% names(or_df)) return(NULL)

  has_boot <- all(c("boot_ci_lower", "boot_ci_upper") %in% names(or_df)) &&
    any(is.finite(suppressWarnings(as.numeric(or_df$boot_ci_lower))))

  rows <- lapply(seq_len(nrow(or_df)), function(i) {
    .cd_island_drop_null(list(
      driver        = as.character(or_df$factor[i]),
      label         = as.character(or_df$factor_label[i] %||%
                                     labels[[as.character(or_df$factor[i])]] %||%
                                     or_df$factor[i]),
      level         = as.character(or_df$comparison[i]),
      reference     = as.character(or_df$reference[i] %||% NA_character_),
      outcome_level = as.character(or_df$outcome_level[i] %||% NA_character_),
      vs_outcome    = as.character(or_df$reference_outcome[i] %||% NA_character_),
      or            = .cd_island_scalar(or_df$odds_ratio[i]),
      lo            = .cd_island_scalar(or_df$or_lower[i]),
      hi            = .cd_island_scalar(or_df$or_upper[i]),
      p             = .cd_island_scalar(or_df$p_value[i]),
      boot_lo       = if (has_boot) .cd_island_scalar(or_df$boot_ci_lower[i]) else NULL,
      boot_hi       = if (has_boot) .cd_island_scalar(or_df$boot_ci_upper[i]) else NULL,
      sign_stability = if ("sign_stability" %in% names(or_df)) {
        .cd_island_scalar(or_df$sign_stability[i])
      } else NULL
    ))
  })

  .cd_island_drop_null(list(
    interval_kind = if (has_boot) "wald_and_bootstrap" else "wald",
    # Said out loud so the view never draws a bootstrap whisker that did not run
    bootstrap     = has_boot,
    rows          = rows
  ))
}

#' Probability lifts, which name the outcome level they describe
#' @keywords internal
.cd_island_lifts <- function(lift_df) {
  if (is.null(lift_df) || !is.data.frame(lift_df) || nrow(lift_df) == 0) return(NULL)

  outcome_levels <- unique(as.character(lift_df$outcome_level %||% character(0)))
  outcome_levels <- outcome_levels[!is.na(outcome_levels) & nzchar(outcome_levels)]

  rows <- lapply(seq_len(nrow(lift_df)), function(i) {
    .cd_island_drop_null(list(
      driver       = as.character(lift_df$driver[i]),
      label        = as.character(lift_df$driver_label[i] %||% lift_df$driver[i]),
      level        = as.character(lift_df$level[i]),
      is_reference = isTRUE(lift_df$is_reference[i]),
      prob         = .cd_island_scalar(lift_df$mean_predicted_prob[i]),
      ref_prob     = .cd_island_scalar(lift_df$reference_prob[i]),
      lift         = .cd_island_scalar(lift_df$prob_lift[i]),
      lift_pp      = .cd_island_scalar(lift_df$prob_lift_pct[i])
    ))
  })

  .cd_island_drop_null(list(
    outcome_level = if (length(outcome_levels) == 1) outcome_levels else NULL,
    # Not a marginal effect, and the view must not imply one.
    basis = paste0("Difference in mean fitted probability between a category's ",
                   "respondents and the reference category's. Not an average ",
                   "marginal effect: the groups differ in other ways too."),
    rows = rows
  ))
}

#' Factor patterns: the raw picture behind each driver
#' @keywords internal
.cd_island_patterns <- function(patterns, labels) {
  if (is.null(patterns) || length(patterns) == 0) return(NULL)

  blocks <- list()
  for (var_name in names(patterns)) {
    pat <- patterns[[var_name]]
    tab <- pat$patterns
    if (is.null(tab) || !is.data.frame(tab) || nrow(tab) == 0) next

    # Which outcome level each pct_ column describes. The engine names them
    # pct_<level>, so the view can label a column without being told the
    # outcome's levels twice.
    pct_cols <- setdiff(grep("^pct_", names(tab), value = TRUE), "pct_of_total")
    outcome_levels <- sub("^pct_", "", pct_cols)

    rows <- lapply(seq_len(nrow(tab)), function(i) {
      shares <- lapply(seq_along(pct_cols), function(j) {
        .cd_island_drop_null(list(
          level = outcome_levels[j],
          pct   = .cd_island_scalar(tab[[pct_cols[j]]][i])
        ))
      })
      .cd_island_drop_null(list(
        level        = as.character(tab$category[i]),
        n            = .cd_island_scalar(tab$n[i]),
        pct_of_total = .cd_island_scalar(tab$pct_of_total[i]),
        is_reference = isTRUE(tab$is_reference[i]),
        shares       = shares
      ))
    })

    blocks[[var_name]] <- .cd_island_drop_null(list(
      driver         = var_name,
      label          = as.character(pat$label %||% labels[[var_name]] %||% var_name),
      reference      = as.character(pat$reference %||% NA_character_),
      outcome_levels = as.character(outcome_levels),
      rows           = rows
    ))
  }
  if (length(blocks) == 0) return(NULL)
  unname(blocks)
}


#' Model fit, the base, the weighting statement and the assumption checks
#' @keywords internal
.cd_island_fit <- function(results) {
  model <- results$model_result
  fit <- model$fit_statistics
  diag <- results$diagnostics
  wd <- results$weight_diagnostics

  po <- model$proportional_odds
  vif <- results$multicollinearity

  .cd_island_drop_null(list(
    engine        = as.character(model$engine_used %||% model$model_type %||% NA_character_),
    model_type    = as.character(model$model_type %||% NA_character_),
    outcome_type  = as.character(model$outcome_type %||% NA_character_),
    mcfadden_r2   = .cd_island_scalar(fit$mcfadden_r2),
    aic           = .cd_island_scalar(fit$aic),
    lr            = .cd_island_scalar(fit$lr_statistic),
    lr_df         = .cd_island_scalar(fit$lr_df),
    lr_p          = .cd_island_scalar(fit$lr_pvalue),
    accuracy      = .cd_island_scalar(model$classification$accuracy),
    converged     = isTRUE(model$convergence),
    n             = .cd_island_scalar(diag$analysis_n %||% model$n_observations),
    n_original    = .cd_island_scalar(diag$original_n),
    n_excluded    = .cd_island_scalar(
      if (!is.null(diag$original_n) && !is.null(diag$analysis_n)) {
        max(0, diag$original_n - diag$analysis_n)
      } else NULL),
    # nEff comes from the platform's one Kish definition (shared effective_n.R),
    # never recomputed here.
    n_eff         = .cd_island_scalar(wd$effective_n),
    design_effect = .cd_island_scalar(wd$design_effect),
    weighting     = as.character(wd$inference_stamp %||% NA_character_),
    proportional_odds = if (!is.null(po)) .cd_island_drop_null(list(
      checked        = isTRUE(po$checked),
      status         = as.character(po$status %||% NA_character_),
      method         = as.character(po$method %||% NA_character_),
      interpretation = as.character(po$interpretation %||% NA_character_)
    )) else NULL,
    multicollinearity = if (!is.null(vif)) .cd_island_drop_null(list(
      checked        = isTRUE(vif$checked),
      status         = as.character(vif$status %||% NA_character_),
      method         = as.character(vif$method %||% NA_character_),
      interpretation = as.character(vif$interpretation %||% NA_character_)
    )) else NULL
  ))
}

#' The subgroup matrix and its odds-ratio comparison
#' @keywords internal
.cd_island_subgroups <- function(comparison) {
  if (is.null(comparison)) return(NULL)
  imp <- comparison$importance_matrix
  if (is.null(imp) || !is.data.frame(imp) || nrow(imp) == 0) return(NULL)

  groups <- as.character(comparison$group_names %||% character(0))
  if (length(groups) == 0) return(NULL)

  imp_rows <- lapply(seq_len(nrow(imp)), function(i) {
    per_group <- lapply(groups, function(g) {
      .cd_island_drop_null(list(
        group = g,
        rank  = .cd_island_scalar(imp[[paste0(g, "_rank")]][i]),
        pct   = .cd_island_scalar(imp[[paste0(g, "_pct")]][i])
      ))
    })
    .cd_island_drop_null(list(
      driver         = as.character(imp$variable[i]),
      label          = as.character(imp$label[i] %||% imp$variable[i]),
      classification = as.character(imp$classification[i] %||% NA_character_),
      groups         = per_group
    ))
  })

  fit <- comparison$model_fit
  fit_rows <- if (!is.null(fit) && is.data.frame(fit) && nrow(fit) > 0) {
    lapply(seq_len(nrow(fit)), function(i) .cd_island_drop_null(list(
      group            = as.character(fit$subgroup[i]),
      n                = .cd_island_scalar(fit$n[i]),
      n_before_missing = .cd_island_scalar(fit$n_before_missing[i]),
      mcfadden_r2      = .cd_island_scalar(fit$mcfadden_r2[i]),
      status           = as.character(fit$status[i] %||% NA_character_)
    )))
  } else NULL

  oc <- comparison$or_comparison
  or_rows <- if (!is.null(oc) && is.data.frame(oc) && nrow(oc) > 0) {
    lapply(seq_len(nrow(oc)), function(i) {
      per_group <- lapply(groups, function(g) .cd_island_drop_null(list(
        group = g,
        or    = .cd_island_scalar(oc[[paste0(g, "_or")]][i]),
        ci    = as.character(oc[[paste0(g, "_ci")]][i] %||% NA_character_),
        p     = .cd_island_scalar(oc[[paste0(g, "_p")]][i])
      )))
      .cd_island_drop_null(list(
        driver        = as.character(oc$driver[i]),
        label         = as.character(oc$label[i] %||% oc$driver[i]),
        level         = as.character(oc$level[i]),
        outcome_level = as.character(oc$outcome_level[i] %||% NA_character_),
        ratio         = .cd_island_scalar(oc$or_ratio[i]),
        notable       = as.character(oc$notable[i] %||% NA_character_),
        groups        = per_group
      ))
    })
  } else NULL

  .cd_island_drop_null(list(
    variable   = as.character(comparison$subgroup_var %||% NA_character_),
    groups     = groups,
    n_groups   = .cd_island_scalar(comparison$n_groups),
    importance = imp_rows,
    fit        = fit_rows,
    odds_ratios = or_rows,
    insights   = as.character(comparison$insights %||% character(0))
  ))
}

#' What ran, on what base
#' @keywords internal
.cd_island_meta <- function(results, config, n_drivers, has_or, has_lifts,
                            has_subgroups) {

  wd <- results$weight_diagnostics
  weighted <- !is.null(wd)

  analysis_name <- config$analysis_name
  if (is.null(analysis_name) || !nzchar(trimws(as.character(analysis_name)[1]))) {
    analysis_name <- "Categorical Key Driver Analysis"
  }

  .cd_island_drop_null(list(
    schema_version = CD_ISLAND_SCHEMA_VERSION,
    kind           = "catdriver",
    generated      = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    analysis_name  = as.character(analysis_name)[1],
    outcome        = .cd_island_drop_null(list(
      var    = as.character(config$outcome_var %||% NA_character_),
      label  = as.character(config$outcome_label %||% config$outcome_var %||% NA_character_),
      type   = as.character(config$outcome_type %||% NA_character_),
      levels = as.character(results$prep_data$outcome_info$categories %||% character(0))
    )),
    run_status       = as.character(results$run_status %||% NA_character_),
    degraded_reasons = as.character(results$degraded_reasons %||% character(0)),
    weighted         = weighted,
    weight_var       = if (weighted) as.character(config$weight_var) else NULL,
    n_drivers        = n_drivers,
    has_odds_ratios  = isTRUE(has_or),
    has_lifts        = isTRUE(has_lifts),
    has_subgroups    = isTRUE(has_subgroups),
    # The tab is frozen. Everything here was estimated once, on the whole
    # sample, and no filter can recompute it.
    frozen           = TRUE,
    filter_note      = paste0("Report filters do not apply here. These figures were ",
                              "estimated once, on the whole sample."),
    # Said in the island rather than typed into the view, so a study run at 90%
    # is never labelled 95% by a renderer that assumed one.
    confidence_level = .cd_island_scalar(config$confidence_level)
  ))
}


# ==============================================================================
# HELPERS
# ==============================================================================

#' Drop NULL and empty entries, so the island carries no hollow fields
#' @keywords internal
.cd_island_drop_null <- function(x) {
  keep <- vapply(x, function(v) {
    if (is.null(v)) return(FALSE)
    if (length(v) == 0) return(FALSE)
    if (length(v) == 1 && is.atomic(v) && is.na(v)) return(FALSE)
    TRUE
  }, logical(1))
  x[keep]
}

#' A single finite number, or NULL
#' @keywords internal
.cd_island_scalar <- function(x) {
  if (is.null(x) || length(x) == 0) return(NULL)
  v <- suppressWarnings(as.numeric(x[1]))
  if (!is.finite(v)) return(NULL)
  v
}

#' Keep one-element vectors as JSON arrays where the view expects a list
#' @keywords internal
.cd_island_keep_arrays <- function(island) {
  force_array <- function(x) {
    if (is.null(x)) return(NULL)
    if (is.list(x) && is.null(names(x))) return(x)
    list(x)
  }
  if (!is.null(island$meta$degraded_reasons)) {
    island$meta$degraded_reasons <- as.list(island$meta$degraded_reasons)
  }
  if (!is.null(island$meta$outcome$levels)) {
    island$meta$outcome$levels <- as.list(island$meta$outcome$levels)
  }
  if (!is.null(island$subgroups$groups)) {
    island$subgroups$groups <- as.list(island$subgroups$groups)
  }
  if (!is.null(island$subgroups$insights)) {
    island$subgroups$insights <- as.list(island$subgroups$insights)
  }
  for (key in c("importance", "odds_ratios", "lifts")) {
    if (!is.null(island[[key]]$rows)) island[[key]]$rows <- force_array(island[[key]]$rows)
  }
  if (!is.null(island$patterns)) {
    island$patterns <- force_array(island$patterns)
    island$patterns <- lapply(island$patterns, function(b) {
      if (!is.null(b$outcome_levels)) b$outcome_levels <- as.list(b$outcome_levels)
      b
    })
  }
  island
}
