# ==============================================================================
# KEYDRIVER. V2 REPORT ISLAND (TR.KD)
# ==============================================================================
# A keydriver run writes `{output}_kd_island.json`; a later tabs run for the
# same project embeds it when its `keydriver_island` setting names the file.
# The two modules meet through one file and neither has to know how the other
# works. The same arrangement conjoint, maxdiff and pricing use, and the
# tracker before them.
#
# WHY A SEPARATE ISLAND RATHER THAN CROSSTAB ROWS. The migration plan assumed
# keydriver would ride in on the existing row machinery. It cannot. Every AGG
# question in the data layer shares the banner's column list, and keydriver's
# axes are drivers by methods and drivers by segments, not banner columns. And
# there is no microdata to recompute from: nothing per-respondent survives a
# keydriver run. So this island is FROZEN, like tracking's and pricing's. The
# view says so and the filter bar is hidden while it is open.
#
# WHAT TRAVELS, AND WHY (the curated list, logged against V2_MIGRATION_PLAN
# section 7):
#   IN   importance per driver per method, with ranks and direction
#   IN   bootstrap intervals for the three methods that have them
#   IN   model fit, VIF, and the base the whole thing rests on
#   IN   quadrant coordinates, thresholds, and which importance source made them
#   IN   the segment matrix, its bases, and the classifications
#   OUT  elastic net, NCA, dominance and GAM sheets, effect sizes, and the
#        method-comparison detail. They stay in the Excel deliverable. They are
#        opt-in analyses whose audience is the analyst, not the report reader.
#
# NO INTERVAL IS NOT A ZERO INTERVAL. The bootstrap covers correlation, beta
# and relative weights. It does not cover Shapley, which would need 2^k refits
# per iteration. Shapley therefore carries an explicit "no interval available"
# stamp rather than an absent or an empty one, so the view cannot draw a
# whisker that means nothing.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' The island schema this module writes
#' @keywords internal
KD_ISLAND_SCHEMA_VERSION <- 1L

#' The importance methods the island carries, in display order
#'
#' `interval` says whether the bootstrap reaches this method. Shapley's FALSE
#' is the reason the view stamps it rather than drawing an empty whisker.
#' @keywords internal
KD_ISLAND_METHODS <- list(
  list(key = "shapley",         column = "Shapley_Value",    rank_column = "Shapley_Rank",
       label = "Shapley value",     unit = "pct", interval = FALSE,
       ci_method = NA_character_),
  list(key = "relative_weight", column = "Relative_Weight",  rank_column = "RelWeight_Rank",
       label = "Relative weight",   unit = "pct", interval = TRUE,
       ci_method = "Relative_Weight"),
  list(key = "beta",            column = "Beta_Weight",      rank_column = "Beta_Rank",
       label = "Standardised beta", unit = "pct", interval = TRUE,
       ci_method = "Beta_Weight"),
  list(key = "correlation",     column = "Correlation",      rank_column = "Corr_Rank",
       label = "Correlation",       unit = "r",   interval = TRUE,
       ci_method = "Correlation")
)


# ==============================================================================
# ENTRY POINTS
# ==============================================================================

#' Serialise Keydriver Results As A V2 Report Island
#'
#' @param results The list a keydriver run returns, with `importance`, `model`,
#'   `config`, and optionally `bootstrap_ci`, `quadrant`, `segment_comparisons`
#'   and `run_status`.
#' @param config The loaded keydriver configuration.
#' @param data_info Optional list with `n_respondents`, `n_complete` and
#'   `n_missing` from the loader, used for the base block.
#' @param verbose Logical, print progress.
#'
#' @return A list ready for `jsonlite::toJSON()`, or NULL when the run produced
#'   no importance table, which is the only block the view cannot do without.
#'
#' @export
serialize_keydriver_layer <- function(results, config, data_info = NULL, verbose = TRUE) {

  imp <- results$importance
  if (is.null(imp) || !is.data.frame(imp) || nrow(imp) == 0) return(NULL)

  if (verbose) cat("  Serialising key driver results for the interactive report...\n")

  # One label per driver, so the quadrant and the segment matrix say the same
  # thing the importance table says. A reader must not meet "Digital banking"
  # in one panel and "digital_banking" in the next.
  labels <- .kd_island_labels(imp)

  importance_block <- .kd_island_importance(imp)
  ci_block         <- .kd_island_ci(results$bootstrap_ci, config)
  fit_block        <- .kd_island_fit(results$model, imp)
  quadrant_block   <- .kd_island_quadrant(results$quadrant, labels)
  segments_block   <- .kd_island_segments(results$segment_comparisons %||%
                                            results$segment_comparison, config, labels)

  meta <- .kd_island_meta(results, config, data_info,
                          n_drivers = nrow(imp),
                          has_ci = !is.null(ci_block),
                          has_quadrant = !is.null(quadrant_block),
                          n_segment_vars = length(segments_block))

  out <- .kd_island_drop_null(list(
    meta       = meta,
    importance = importance_block,
    ci         = ci_block,
    fit        = fit_block,
    quadrant   = quadrant_block,
    segments   = if (length(segments_block) > 0) segments_block else NULL
  ))

  if (verbose) {
    cat(sprintf("  Key driver island: %d driver(s), %d method(s)%s%s\n",
                nrow(imp), length(importance_block$methods),
                if (!is.null(ci_block)) ", bootstrap intervals" else "",
                if (!is.null(quadrant_block)) ", quadrant" else ""))
  }
  out
}


#' Write The Keydriver Island Contribution File
#'
#' @param results As `serialize_keydriver_layer()`.
#' @param config The loaded keydriver configuration.
#' @param output_file Path for the JSON. Defaults to the run's output workbook
#'   with `_kd_island.json` in place of `.xlsx`.
#' @param data_info Optional loader counts, as `serialize_keydriver_layer()`.
#' @param verbose Logical.
#'
#' @return A list with `status`, and `output_file` when one was written.
#'
#' @export
write_keydriver_island <- function(results, config, output_file = NULL,
                                   data_info = NULL, verbose = TRUE) {

  island <- serialize_keydriver_layer(results, config, data_info = data_info,
                                      verbose = verbose)

  # No refusal here. A run with no importance table has already said why, and
  # a missing Key drivers tab is not worth failing an otherwise good run over.
  if (is.null(island)) {
    if (verbose) {
      cat(paste0("  [NOTE] No importance table, so no contribution to the ",
                 "interactive report was written.\n"))
    }
    return(list(status = "SKIPPED", output_file = NULL))
  }

  if (is.null(output_file)) {
    base <- results$config$output_file %||% config$output_file %||% "keydriver_results.xlsx"
    output_file <- sub("[.]xlsx$", "_kd_island.json", base)
    if (identical(output_file, base)) output_file <- paste0(base, "_kd_island.json")
  }

  ok <- tryCatch({
    jsonlite::write_json(.kd_island_keep_arrays(island), output_file,
                         auto_unbox = TRUE, na = "null", digits = 6, pretty = FALSE)
    TRUE
  }, error = function(e) {
    cat(sprintf("  [WARN] Could not write the interactive-report contribution: %s\n",
                conditionMessage(e)))
    FALSE
  })
  if (!isTRUE(ok)) return(list(status = "FAILED", output_file = NULL))

  if (verbose) {
    cat(sprintf("  Interactive-report contribution: %s\n", basename(output_file)))
  }
  list(status = "PASS", output_file = output_file)
}


# ==============================================================================
# INTERNALS
# ==============================================================================

#' jsonlite writes a NULL list element as {}, which is truthy in JavaScript.
#' A block the run did not produce must be ABSENT, at every level.
#' @keywords internal
.kd_island_drop_null <- function(x) Filter(Negate(is.null), x)

#' Numeric coercion that turns every non-finite value into NA
#' @keywords internal
.kd_island_num <- function(x) {
  v <- suppressWarnings(as.numeric(x))
  v[!is.finite(v)] <- NA_real_
  v
}

#' One scalar out of a list or vector, as a number
#' @keywords internal
.kd_island_scalar <- function(x) {
  if (is.null(x) || length(x) == 0) return(NULL)
  v <- .kd_island_num(x[[1]])
  if (length(v) != 1 || is.na(v)) return(NULL)
  v
}

#' A column of a data frame as numbers, or NULL when the frame has no such column
#' @keywords internal
.kd_island_col <- function(df, col) {
  if (is.null(df) || !is.data.frame(df) || !col %in% names(df)) return(NULL)
  .kd_island_num(df[[col]])
}

#' Single-element vectors that must stay arrays in JSON
#'
#' auto_unbox turns a length-one vector into a scalar, so a study with one
#' bootstrapped method would ship `"methods": "beta"` and a view that maps
#' over it would break. Every atomic list here is marked, including the ones
#' that happen to have more than one element on the example: the whole point
#' is the study that does not.
#' @keywords internal
.kd_island_keep_arrays <- function(x) {
  mark <- function(v) if (is.null(v) || length(v) == 0) NULL else I(v)

  if (!is.null(x$ci)) {
    x$ci$methods     <- mark(x$ci$methods)
    x$ci$no_interval <- mark(x$ci$no_interval)
  }
  if (!is.null(x$segments)) {
    x$segments <- lapply(x$segments, function(blk) {
      blk$insights <- mark(blk$insights)
      blk
    })
  }
  x
}


#' Driver name to display label, from the importance table
#' @keywords internal
.kd_island_labels <- function(imp) {
  out <- list()
  if (is.null(imp) || !is.data.frame(imp) || !"Driver" %in% names(imp)) return(out)
  has_label <- "Label" %in% names(imp)
  for (i in seq_len(nrow(imp))) {
    drv <- as.character(imp$Driver[i])
    lbl <- if (has_label) as.character(imp$Label[i]) else NA_character_
    out[[drv]] <- if (!is.na(lbl) && nzchar(lbl)) lbl else drv
  }
  out
}


#' The importance block: one row per driver, one value per method
#'
#' `direction` is the sign of the unstandardised coefficient, so the view can
#' say whether a driver pushes the outcome up or down. Importance shares are
#' magnitudes and carry no sign of their own, which is exactly the thing a
#' reader assumes wrongly when nothing says otherwise.
#' @keywords internal
.kd_island_importance <- function(imp) {

  present <- Filter(function(m) m$column %in% names(imp), KD_ISLAND_METHODS)
  if (length(present) == 0) return(NULL)

  coefs <- .kd_island_col(imp, "Beta_Coefficient")
  avg   <- .kd_island_col(imp, "Average_Rank")
  labels <- if ("Label" %in% names(imp)) as.character(imp$Label) else NULL

  drivers <- lapply(seq_len(nrow(imp)), function(i) {
    values <- list(); ranks <- list()
    for (m in present) {
      v <- .kd_island_num(imp[[m$column]][i])
      values[[m$key]] <- if (is.na(v)) NULL else v
      if (!is.null(m$rank_column) && m$rank_column %in% names(imp)) {
        rv <- .kd_island_num(imp[[m$rank_column]][i])
        ranks[[m$key]] <- if (is.na(rv)) NULL else rv
      }
    }
    lbl <- if (!is.null(labels) && !is.na(labels[i]) && nzchar(labels[i])) {
      labels[i]
    } else {
      as.character(imp$Driver[i])
    }
    dir <- if (!is.null(coefs) && !is.na(coefs[i])) sign(coefs[i]) else NULL

    .kd_island_drop_null(list(
      driver    = as.character(imp$Driver[i]),
      label     = lbl,
      values    = if (length(values)) values else NULL,
      ranks     = if (length(ranks)) ranks else NULL,
      direction = dir,
      avg_rank  = if (!is.null(avg) && !is.na(avg[i])) avg[i] else NULL
    ))
  })

  list(
    methods = lapply(present, function(m) .kd_island_drop_null(list(
      key = m$key, label = m$label, unit = m$unit, interval = m$interval,
      note = if (isTRUE(m$interval)) NULL else "no interval available"
    ))),
    drivers = drivers
  )
}


#' The bootstrap interval block
#'
#' One row per driver per method that the bootstrap actually reached. A method
#' with no rows is absent rather than empty, and Shapley is named in
#' `no_interval` so the view stamps it instead of guessing.
#' @keywords internal
.kd_island_ci <- function(boot, config) {
  df <- if (is.data.frame(boot)) boot else boot$result
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) return(NULL)
  if (!all(c("Driver", "Method") %in% names(df))) return(NULL)

  est <- .kd_island_col(df, "Point_Estimate")
  lo  <- .kd_island_col(df, "CI_Lower")
  hi  <- .kd_island_col(df, "CI_Upper")
  se  <- .kd_island_col(df, "SE")
  if (is.null(est) || is.null(lo) || is.null(hi)) return(NULL)

  # The island speaks in the view's method keys, not the engine's column names.
  by_col <- list()
  for (m in KD_ISLAND_METHODS) {
    if (!is.na(m$ci_method)) by_col[[m$ci_method]] <- m$key
  }

  rows <- list()
  for (i in seq_len(nrow(df))) {
    key <- by_col[[as.character(df$Method[i])]]
    if (is.null(key)) next
    if (is.na(est[i]) || is.na(lo[i]) || is.na(hi[i])) next
    rows[[length(rows) + 1L]] <- .kd_island_drop_null(list(
      driver   = as.character(df$Driver[i]),
      method   = key,
      estimate = est[i],
      lo       = lo[i],
      hi       = hi[i],
      se       = if (!is.null(se) && !is.na(se[i])) se[i] else NULL
    ))
  }
  if (length(rows) == 0) return(NULL)

  iters <- if (exists("kd_bootstrap_iterations", mode = "function")) {
    kd_bootstrap_iterations(config)
  } else {
    .kd_island_scalar(config$settings$bootstrap_iterations)
  }
  level <- .kd_island_scalar(config$settings$bootstrap_ci_level) %||% 0.95

  .kd_island_drop_null(list(
    rows        = rows,
    methods     = unique(vapply(rows, function(r) r$method, character(1))),
    no_interval = vapply(Filter(function(m) !isTRUE(m$interval), KD_ISLAND_METHODS),
                         function(m) m$key, character(1)),
    iterations  = if (is.null(iters)) NULL else as.numeric(iters),
    level       = level,
    note        = paste0("Point_Estimate is the mean of the bootstrap distribution ",
                         "and will not equal the headline importance column.")
  ))
}


#' Model fit and multicollinearity
#' @keywords internal
.kd_island_fit <- function(model, imp) {
  if (is.null(model)) return(NULL)
  s <- tryCatch(summary(model), error = function(e) NULL)
  if (is.null(s)) return(NULL)

  f <- s$fstatistic
  p_value <- if (!is.null(f) && length(f) == 3) {
    tryCatch(stats::pf(f[1], f[2], f[3], lower.tail = FALSE), error = function(e) NULL)
  } else NULL

  vif_block <- NULL
  if (exists("calculate_vif", mode = "function")) {
    vif_vals <- tryCatch(calculate_vif(model), error = function(e) NULL)
    if (!is.null(vif_vals) && length(vif_vals) > 0) {
      vif_block <- lapply(seq_along(vif_vals), function(i) list(
        term = names(vif_vals)[i],
        vif  = .kd_island_num(vif_vals[[i]])
      ))
    }
  }

  .kd_island_drop_null(list(
    r2      = .kd_island_scalar(s$r.squared),
    adj_r2  = .kd_island_scalar(s$adj.r.squared),
    f       = if (!is.null(f)) .kd_island_scalar(f[1]) else NULL,
    df1     = if (!is.null(f)) .kd_island_scalar(f[2]) else NULL,
    df2     = if (!is.null(f)) .kd_island_scalar(f[3]) else NULL,
    p       = .kd_island_scalar(p_value),
    n_model = .kd_island_scalar(tryCatch(stats::nobs(model), error = function(e) NULL)),
    vif     = vif_block,
    vif_thresholds = list(moderate = 5, high = 10)
  ))
}


#' The quadrant block: coordinates, thresholds, and which source made them
#' @keywords internal
.kd_island_quadrant <- function(quad, labels = list()) {
  if (is.null(quad)) return(NULL)
  d <- quad$data
  if (is.null(d) || !is.data.frame(d) || nrow(d) == 0) return(NULL)
  if (!all(c("driver", "x", "y") %in% names(d))) return(NULL)

  x <- .kd_island_col(d, "x"); y <- .kd_island_col(d, "y")
  q <- if ("quadrant" %in% names(d)) .kd_island_num(d$quadrant) else NULL
  ql <- if ("quadrant_label" %in% names(d)) as.character(d$quadrant_label) else NULL
  gap <- .kd_island_col(d, "gap")
  pri <- .kd_island_col(d, "priority_score")

  points <- lapply(seq_len(nrow(d)), function(i) .kd_island_drop_null(list(
    driver         = as.character(d$driver[i]),
    label          = labels[[as.character(d$driver[i])]] %||% NULL,
    x              = if (is.na(x[i])) NULL else x[i],
    y              = if (is.na(y[i])) NULL else y[i],
    quadrant       = if (is.null(q) || is.na(q[i])) NULL else q[i],
    quadrant_label = if (is.null(ql)) NULL else ql[i],
    gap            = if (is.null(gap) || is.na(gap[i])) NULL else gap[i],
    priority       = if (is.null(pri) || is.na(pri[i])) NULL else pri[i]
  )))

  .kd_island_drop_null(list(
    points     = points,
    thresholds = .kd_island_drop_null(list(
      x = .kd_island_scalar(d$x_threshold),
      y = .kd_island_scalar(d$y_threshold)
    )),
    axes = list(x = "Performance", y = "Importance"),
    # Which source was asked for against the one that produced these points.
    # It is recorded on the result and, until this island, reached nobody.
    importance_source = .kd_island_drop_null(list(
      requested = attr(quad, "importance_source_requested"),
      used      = attr(quad, "importance_source_used")
    ))
  ))
}


#' The segment matrix, one block per segment variable, bases carried
#'
#' A cell whose segment did not clear `min_segment_n` is not here at all: the
#' engine never analysed it. What this block adds is the base beside every
#' segment that IS here, and the threshold, so a reader can see both.
#' @keywords internal
.kd_island_segments <- function(comparisons, config, labels = list()) {
  if (is.null(comparisons)) return(list())

  # One variable's comparison, or the named list of them.
  if (!is.null(comparisons$comparison_matrix)) {
    comparisons <- list(segment = comparisons)
  }
  if (!is.list(comparisons) || length(comparisons) == 0) return(list())

  out <- list()
  for (var_name in names(comparisons)) {
    cmp <- comparisons[[var_name]]
    m <- cmp$comparison_matrix
    if (is.null(m) || !is.data.frame(m) || nrow(m) == 0) next
    if (!"Driver" %in% names(m)) next

    seg_names <- names(cmp$segment_results %||% list())
    if (length(seg_names) == 0) {
      seg_names <- sub("_Pct$", "", grep("_Pct$", names(m), value = TRUE))
      seg_names <- setdiff(seg_names, "Mean")
    }
    if (length(seg_names) == 0) next

    bases <- cmp$segment_bases %||% list()
    cls <- cmp$classifications

    rows <- lapply(seq_len(nrow(m)), function(i) {
      drv <- as.character(m$Driver[i])
      values <- list(); ranks <- list()
      for (sn in seg_names) {
        pc <- .kd_island_col(m, paste0(sn, "_Pct"))
        rk <- .kd_island_col(m, paste0(sn, "_Rank"))
        if (!is.null(pc) && !is.na(pc[i])) values[[sn]] <- pc[i]
        if (!is.null(rk) && !is.na(rk[i])) ranks[[sn]] <- rk[i]
      }
      crow <- if (!is.null(cls) && is.data.frame(cls) && "Driver" %in% names(cls)) {
        cls[cls$Driver == drv, , drop = FALSE]
      } else NULL
      mean_pct <- .kd_island_col(m, "Mean_Pct")

      .kd_island_drop_null(list(
        driver         = drv,
        label          = labels[[drv]] %||% NULL,
        values         = if (length(values)) values else NULL,
        ranks          = if (length(ranks)) ranks else NULL,
        mean           = if (!is.null(mean_pct) && !is.na(mean_pct[i])) mean_pct[i] else NULL,
        classification = if (!is.null(crow) && nrow(crow) > 0 &&
                             "Classification" %in% names(crow)) {
          as.character(crow$Classification[1])
        } else NULL,
        description    = if (!is.null(crow) && nrow(crow) > 0 &&
                             "Description" %in% names(crow)) {
          as.character(crow$Description[1])
        } else NULL
      ))
    })

    out[[length(out) + 1L]] <- .kd_island_drop_null(list(
      variable = var_name,
      segments = lapply(seg_names, function(sn) .kd_island_drop_null(list(
        name = sn,
        n    = .kd_island_scalar(bases[[sn]])
      ))),
      min_base = .kd_island_scalar(cmp$min_segment_n %||% config$settings$min_segment_n),
      rows     = rows,
      insights = if (!is.null(cmp$insights) && length(cmp$insights) > 0) {
        as.character(cmp$insights)
      } else NULL
    ))
  }
  out
}


#' The meta block: what ran, on what base, and how to read it
#' @keywords internal
.kd_island_meta <- function(results, config, data_info, n_drivers,
                            has_ci, has_quadrant, n_segment_vars) {

  weight_var <- config$weight_var
  weighted <- !is.null(weight_var) && nzchar(as.character(weight_var %||% ""))

  n_complete <- .kd_island_scalar(data_info$n_complete)
  n_missing  <- .kd_island_scalar(data_info$n_missing)

  analysis_name <- config$settings$analysis_name
  if (is.null(analysis_name) || !nzchar(trimws(as.character(analysis_name)[1]))) {
    analysis_name <- "Key Driver Analysis"
  }

  outcome_label <- NULL
  vars <- config$variables
  if (!is.null(vars) && is.data.frame(vars) && all(c("VariableName", "Label") %in% names(vars))) {
    hit <- match(config$outcome_var, vars$VariableName)
    if (!is.na(hit)) outcome_label <- as.character(vars$Label[hit])
  }

  .kd_island_drop_null(list(
    schema_version = KD_ISLAND_SCHEMA_VERSION,
    kind           = "keydriver",
    generated      = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    analysis_name  = as.character(analysis_name)[1],
    outcome        = .kd_island_drop_null(list(
      var   = config$outcome_var,
      label = if (!is.null(outcome_label) && nzchar(outcome_label)) outcome_label else NULL
    )),
    run_status     = results$run_status %||% NULL,
    primary_method = if (exists(".kd_primary_method", mode = "function")) {
      tryCatch(.kd_primary_method(list(importance = results$importance)),
               error = function(e) NULL)
    } else NULL,
    random_seed    = if (exists("kd_seed_value", mode = "function")) {
      tryCatch(.kd_island_scalar(kd_seed_value(config)), error = function(e) NULL)
    } else NULL,
    base = .kd_island_drop_null(list(
      n           = n_complete,
      n_excluded  = n_missing,
      weighted    = weighted,
      weight_var  = if (weighted) as.character(weight_var) else NULL,
      n_eff       = .kd_island_scalar(results$kd_effective_n),
      design_effect = .kd_island_scalar(results$kd_design_effect)
    )),
    n_drivers      = n_drivers,
    has_ci         = isTRUE(has_ci),
    has_quadrant   = isTRUE(has_quadrant),
    n_segment_vars = n_segment_vars,
    # The tab is frozen. Everything here was estimated once, on the whole
    # sample, and no filter can recompute it.
    frozen         = TRUE,
    filter_note    = paste0("Report filters do not apply here. These figures were ",
                            "estimated once, on the whole sample.")
  ))
}
