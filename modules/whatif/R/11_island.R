# ==============================================================================
# WHAT IF - THE CONTRIBUTION FILE FOR THE TABS REPORT
# ==============================================================================
#
# One run writes one file, {output_name}_whatif_island.json, with every block
# either delivery mode could need. The tabs build decides which blocks go into
# the report from its "Who is this file for?" choice (run_crosstabs.R,
# .read_whatif_contribution):
#
#   meta      study, outcome, scale, minimum group, run status
#   model     levers, design, fits (main + refits), sign check, bundles,
#             symptoms, calibration summary, notes. No respondent data.
#   profile   the open "Build a ..." model, every level, Structure rules
#   open      ONE ROW PER RESPONDENT: ids, outcome, weights, lever values,
#             context codes. For open reports only. The tabs build lines the
#             rows up with its own respondent records by id and then drops the
#             ids; a client-safe build drops this block entirely.
#   safe      precomputed results for the groups disclosure_publish_groups()
#             allows, the client-safe profile model (small levels pooled) and
#             the combinations it may offer, and the audit
#
# The file on disk carries respondent IDs and rows, so it is an internal
# working file like the survey data itself: never send it to a client.
#
# ==============================================================================

WHATIF_ISLAND_SCHEMA <- 1L

#' @keywords internal
whatif_arr <- function(x) I(unname(x))


#' Pack a Lever Model Fit for JSON
#' @keywords internal
whatif_pack_fit <- function(f) {
  list(b = whatif_arr(round(unname(f$b), 6)), theta = whatif_arr(round(f$theta, 6)))
}


#' Pack a Profile Model for JSON
#' @keywords internal
whatif_pack_profile <- function(pm, context, sentence, order, level_n) {
  keys <- lapply(pm$keys, function(k) {
    list(key = k, label = context[[k]]$label, levels = whatif_arr(pm$levels[[k]]),
         structural = k %in% pm$structural, n = whatif_arr(level_n[[k]]),
         order = order[[k]] %||% NA_character_)
  })
  fits <- lapply(pm$fits, function(f) {
    b <- lapply(pm$keys, function(k) {
      idx <- which(pm$cols$key == k)
      whatif_arr(round(c(0, unname(f$b[idx])), 6))
    })
    names(b) <- pm$keys
    list(b = b, theta = whatif_arr(round(f$theta, 6)))
  })
  rules <- if (NROW(pm$rules)) lapply(seq_len(nrow(pm$rules)), function(i) whatif_arr(unlist(pm$rules[i, ]))) else list()
  list(keys = keys, sentence = sentence, rules = rules, fits = fits, penalty = pm$penalty,
       cv_r2 = round(pm$cv_r2, 4), spread = whatif_arr(round(pm$spread, 2)))
}


#' Build the Contribution Payload
#'
#' @param run List assembled by run_whatif: cfg, prep, model, calibration,
#'   calibration_ratings_only, symptoms, publish, safe_results, safe_profile,
#'   run_status, warnings
#' @return Nested list ready for jsonlite
#' @keywords internal
whatif_island_payload <- function(run) {
  cfg <- run$cfg
  s <- cfg$settings
  model <- run$model
  spec <- model$spec
  levers <- spec$levers
  keys <- vapply(levers, `[[`, "", "key")
  n <- length(spec$y)
  w <- spec$weights
  score <- spec$outcome$score
  fits <- c(list(model$main), model$boot)
  is_ctx <- model$design$cols$is_context
  X <- model$design$X
  ctx_offset <- vapply(fits, function(f) {
    if (!any(is_ctx)) return(0)
    stats::weighted.mean(drop(X[, is_ctx, drop = FALSE] %*% f$b[is_ctx]), w)
  }, numeric(1))
  actual <- sum(whatif_category_shares(spec$y, w, spec$n_cat) * score)

  meta <- list(
    kind = "whatif", schema_version = WHATIF_ISLAND_SCHEMA,
    generated = format(Sys.time(), "%Y-%m-%d %H:%M"),
    title = s$study_title, brand = s$brand_name, unit = s$unit_noun, units = s$units_noun,
    outcome_text = s$outcome_text, score_label = spec$outcome$score_label,
    outcome_levels = whatif_arr(spec$outcome$levels), scores = whatif_arr(score),
    weighted = isTRUE(spec$weighted), n = n,
    n_by_outcome = whatif_arr(tabulate(spec$y, spec$n_cat)),
    actual = round(actual, 2),
    min_group = s$min_group, reliability_floor = s$reliability_floor, range_level = WHATIF_RANGE_LEVEL,
    id_variable = s$id_variable,
    scale = list(min = spec$scale$min, max = spec$scale$max, centre = spec$scale$centre,
                 good = spec$scale$good, step = s$scale_step,
                 labels = whatif_arr(run$scale_labels %||% character(0))),
    run_status = run$run_status, warnings = whatif_arr(run$warnings)
  )

  design <- model$design$cols
  model_block <- list(
    levers = lapply(levers, function(lv) list(
      key = lv$key, label = lv$label, kind = lv$kind, sub = lv$sub %||% "",
      has_label = lv$has_label %||% NA_character_, col = model$design$lever_col[[lv$key]] - 1L,
      expected = lv$expected, target = lv$target %||% NA_real_, missing = lv$missing %||% 0L)),
    design = lapply(seq_len(nrow(design)), function(i) list(lever = design$lever[i], part = design$part[i],
                                                            context = design$is_context[i])),
    fits = lapply(fits, whatif_pack_fit),
    ctx_offset = whatif_arr(round(ctx_offset, 6)),
    sign = stats::setNames(as.list(round(model$sign$wrong_share, 3)), model$sign$key),
    unclear_share = WHATIF_SIGN_UNCLEAR,
    cv_r2 = round(model$cv_r2, 4),
    baselines = list(keys = whatif_arr(spec$baselines), penalty = model$baseline_penalty),
    moves = whatif_arr(WHATIF_MOVES),
    bundles = lapply(spec$bundles %||% list(), function(b) list(name = b$name, text = b$text %||% "",
                                                              moves = as.list(b$moves))),
    symptoms = lapply(seq_len(nrow(run$symptoms)), function(i) as.list(run$symptoms[i, ])),
    calibration = list(model = whatif_cal_summary(run$calibration),
                       ratings_only = whatif_cal_summary(run$calibration_ratings_only)),
    notes = whatif_arr(run$notes)
  )

  profile <- NULL
  if (!is.null(model$profile)) {
    level_n <- lapply(model$profile$keys, function(k) as.integer(table(factor(spec$context[[k]]$values,
                                                                              model$profile$levels[[k]]))))
    names(level_n) <- model$profile$keys
    profile <- whatif_pack_profile(model$profile, spec$context, run$sentence, run$prep$context_order, level_n)
  }

  ctx_levels <- lapply(spec$context, function(cx) whatif_levels_by_frequency(cx$values))
  open <- list(
    n = n,
    ids = whatif_arr(as.character(run$prep$ids)),
    y = whatif_arr(spec$y),
    w = whatif_arr(round(w, 6)),
    val = lapply(levers, function(lv) {
      v <- if (lv$kind == "nested") ifelse(lv$has, lv$values, NA) else lv$values
      whatif_arr(round(v, 4))
    }),
    ctx_levels = lapply(ctx_levels, whatif_arr),
    ctx = lapply(names(spec$context), function(k) whatif_arr(match(spec$context[[k]]$values, ctx_levels[[k]]) - 1L))
  )
  names(open$ctx) <- names(spec$context)
  names(open$val) <- keys

  list(meta = meta, model = model_block, profile = profile, open = open,
       safe = whatif_safe_block(run, keys))
}


#' @keywords internal
whatif_cal_summary <- function(cal) {
  if (is.null(cal)) return(NULL)
  list(cv_r2 = round(cal$cv_r2, 4), outside = cal$n_outside, groups = cal$n_groups,
       median_error = round(cal$median_abs_error, 2))
}


#' The Client-Safe Block
#'
#' Nothing in it names a level that is not itself published (see the note at
#' the end of the function).
#'
#' Group results carry est, lo and hi only, never the refit draws: 291 groups
#' by 8 levers by 7 moves by 101 draws would be about 6 MB, and every draw is
#' one more number a determined reader could combine. A counted "need" under
#' the minimum group is published as null.
#'
#' @keywords internal
whatif_safe_block <- function(run, keys) {
  k <- run$cfg$settings$min_group
  pub <- run$publish
  res <- run$safe_results
  moves <- WHATIF_MOVES
  groups <- lapply(seq_len(nrow(pub$groups)), function(i) {
    g <- pub$groups[i, ]
    r <- res[[g$id]]
    lv <- r$levers
    grid <- function(col) lapply(keys, function(key) {
      whatif_arr(vapply(moves, function(mv) {
        x <- lv[[col]][lv$key == key & lv$move == mv]
        if (length(x)) round(x, 2) else NA_real_
      }, numeric(1)))
    })
    need <- vapply(keys, function(key) lv$need[lv$key == key][1], numeric(1))
    def <- list()
    if (!is.na(g$key1)) def[[g$key1]] <- g$level1
    if (!is.na(g$key2)) def[[g$key2]] <- g$level2
    list(id = g$id, family = g$family, label = g$label, def = def, n = g$n,
         actual = round(r$actual, 2),
         need = whatif_arr(ifelse(need < k, NA_integer_, as.integer(need))),
         est = grid("est"), lo = grid("lo"), hi = grid("hi"),
         bundles = lapply(seq_len(NROW(r$bundles)), function(b)
           whatif_arr(round(unlist(r$bundles[b, c("est", "lo", "hi")]), 2))))
  })
  list(
    min_group = k,
    filters = lapply(run$filter_keys, function(key) list(
      key = key, label = run$model$spec$context[[key]]$label)),
    crossings = lapply(seq_len(NROW(pub$crossings)), function(i) as.list(pub$crossings[i, ])),
    declared = lapply(run$crossings, whatif_arr),
    groups = groups,
    audit = pub$audit,
    profile = run$safe_profile
  )
  # Deliberately absent: which levels were refused, which cells were hidden,
  # and which profile levels were pooled. Naming them tells a client that a
  # campus or course had fewer than the minimum respondents, which for a list
  # study can point at people. They are listed in the analyst workbook's
  # Privacy sheet instead.
}


#' Write the Contribution File
#'
#' @param payload From whatif_island_payload()
#' @param path Output path
#' @return The path, invisibly
#' @keywords internal
whatif_write_island <- function(payload, path) {
  txt <- jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", null = "null", digits = NA)
  writeLines(txt, path, useBytes = TRUE)
  invisible(path)
}
