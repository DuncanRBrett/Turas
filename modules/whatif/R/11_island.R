# ==============================================================================
# WHAT IF - THE CONTRIBUTION FILE FOR THE TABS REPORT
# ==============================================================================
#
# One run writes one file, {output_name}_whatif_island.json. At the top: meta
# (kind, schema, versions) and variants, one per weighting the run fitted
# ("unweighted" always, "weighted" when the config names a weight column).
# Each variant holds every block either delivery mode could need. The tabs
# build picks the variant matching its own weighting, then the blocks its
# "Who is this file for?" choice allows (run_crosstabs.R,
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
#             allows, with need counts and effects withheld where fewer than
#             the minimum group could be worked out (whatif_safe_suppression),
#             the client-safe model and meta fields, the client-safe profile
#             model (small levels pooled) and the combinations it may offer,
#             and a pass or fail audit
#
# The file on disk carries respondent IDs and rows, so it is an internal
# working file like the survey data itself: never send it to a client.
#
# ==============================================================================

# 2: the file holds one version per weighting (variants), 24 Sep 2026.
WHATIF_ISLAND_SCHEMA <- 2L

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
#'   suppress, run_status, warnings, warnings_safe, notes, notes_safe
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
    weighted = isTRUE(spec$weighted), weight_variable = if (isTRUE(spec$weighted)) s$weight_variable else NULL,
    n = n,
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
    # Each lever's fix effect fitted alone against its partial effect, both
    # for the whole sample; the tab says "caught in the halo" under the
    # ratio. Whole-sample averages, so the client-safe block keeps them.
    halo = stats::setNames(lapply(seq_len(nrow(model$halo)), function(i) list(
      single = round(model$halo$single[i], 2), partial = round(model$halo$partial[i], 2),
      ratio = if (is.na(model$halo$ratio[i])) NULL else round(model$halo$ratio[i], 3),
      flag = isTRUE(model$halo$halo[i]))), model$halo$key),
    halo_ratio = WHATIF_HALO_RATIO,
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
    # 1 where the respondent gave no rating for the lever (the value is a
    # fill): the live tab leaves them out of the need count and the moves,
    # as the R engine does.
    dk = lapply(levers, function(lv) whatif_arr(as.integer(lv$dk %||% rep(FALSE, n)))),
    ctx_levels = lapply(ctx_levels, whatif_arr),
    ctx = lapply(names(spec$context), function(k) whatif_arr(match(spec$context[[k]]$values, ctx_levels[[k]]) - 1L))
  )
  names(open$ctx) <- names(spec$context)
  names(open$val) <- keys
  names(open$dk) <- keys

  list(meta = meta, model = model_block, profile = profile, open = open,
       safe = whatif_safe_block(run, keys, model_block))
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
#' one more number a determined reader could combine. A need count or an
#' effect that whatif_safe_suppression() withholds is published as null.
#'
#' @keywords internal
whatif_safe_block <- function(run, keys, model_block) {
  k <- run$cfg$settings$min_group
  pub <- run$publish
  res <- run$safe_results
  sup <- run$suppress
  spec <- run$model$spec
  moves <- WHATIF_MOVES
  groups <- lapply(seq_len(nrow(pub$groups)), function(i) {
    g <- pub$groups[i, ]
    r <- res[[g$id]]
    lv <- r$levers
    gi <- match(g$id, rownames(sup$need))
    grid <- function(col) lapply(seq_along(keys), function(j) {
      whatif_arr(vapply(moves, function(mv) {
        if (!isTRUE(sup$effect[gi, j, mv])) return(NA_real_)
        x <- lv[[col]][lv$key == keys[j] & lv$move == mv]
        if (length(x)) round(x, 2) else NA_real_
      }, numeric(1)))
    })
    need <- vapply(keys, function(key) lv$need[lv$key == key][1], numeric(1))
    need[!sup$need[gi, ]] <- NA
    def <- list()
    if (!is.na(g$key1)) def[[g$key1]] <- g$level1
    if (!is.na(g$key2)) def[[g$key2]] <- g$level2
    list(id = g$id, family = g$family, label = g$label, def = def, n = g$n,
         actual = round(r$actual, 2),
         need = whatif_arr(as.integer(need)),
         est = grid("est"), lo = grid("lo"), hi = grid("hi"),
         bundles = lapply(seq_len(NROW(r$bundles)), function(b) {
           if (!isTRUE(sup$bundle[gi, b])) return(whatif_arr(rep(NA_real_, 3)))
           whatif_arr(round(unlist(r$bundles[b, c("est", "lo", "hi")]), 2))
         }))
  })
  counts <- tabulate(spec$y, spec$n_cat)
  list(
    min_group = k,
    # Whole-sample facts the client-safe cut must state differently: outcome
    # counts only when every category clears k, and warnings without counts.
    meta = list(n_by_outcome = if (all(counts >= k)) whatif_arr(counts) else NULL,
                warnings = whatif_arr(run$warnings_safe %||% character(0))),
    model = whatif_safe_model(model_block, k, length(spec$y), run$notes_safe),
    filters = lapply(run$filter_keys, function(key) list(
      key = key, label = spec$context[[key]]$label)),
    crossings = lapply(seq_len(NROW(pub$crossings)), function(i)
      list(family = pub$crossings$family[i], shown = pub$crossings$shown[i])),
    declared = lapply(run$crossings, whatif_arr),
    groups = groups,
    # Pass or fail only. The full audit, with its counts of small cells and
    # of what was hidden, stays in the run for the analyst.
    audit = list(k = k, line_failures = pub$audit$line_failures,
                 differencing_failures = pub$audit$differencing_failures,
                 recoverable_failures = pub$audit$recoverable_failures,
                 exact = isTRUE(pub$audit$exact),
                 need_checked = isTRUE(sup$need_checked), effects_checked = isTRUE(sup$effects_checked)),
    profile = run$safe_profile
  )
  # Deliberately absent: which levels were refused, which cells were hidden,
  # which profile levels were pooled, and how many small cells the checks
  # looked at. Naming or counting them tells a client that a campus or course
  # had fewer than the minimum respondents, which for a list study can point
  # at people. They are listed in the analyst workbook's Privacy sheet instead.
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


#' The Model Block a Client-Safe Report Carries
#'
#' Without the context baselines: each context level has its own coefficient,
#' and a level with few respondents would ship something close to their
#' average (and its name). Client-safe views never need them: group results
#' are precomputed, and Rate as one uses ctx_offset, the average baseline. A
#' symptom whose flagged or unflagged side is under k is dropped, as are the
#' per-lever "Don't know" counts and the note that lists them: whole-sample
#' counts under k are still counts under k.
#'
#' @keywords internal
whatif_safe_model <- function(mb, k, n, notes = NULL) {
  keep <- !vapply(mb$design, function(c) isTRUE(c$context), logical(1))
  mb$design <- mb$design[keep]
  mb$fits <- lapply(mb$fits, function(f) { f$b <- whatif_arr(unlist(f$b)[keep]); f })
  levers_col <- cumsum(keep) - 1L
  mb$levers <- lapply(mb$levers, function(lv) { lv$col <- levers_col[lv$col + 1L]; lv$missing <- NULL; lv })
  mb$symptoms <- Filter(function(sm) sm$n >= k && (n - sm$n) >= k, mb$symptoms)
  mb$baselines$penalty <- NULL
  mb$notes <- whatif_arr(notes %||% character(0))
  mb
}


#' Which Need Counts and Effects the Client-Safe Block May Show
#'
#' A need count is the size of the group's members who need the fix. An
#' effect is an average over the group's members the move changes, everyone
#' else contributing exactly zero, so est times n is those members' summed
#' change. Either is a statistic about a subset of the group, and subsets
#' difference across groups just as memberships do (review of 24 Sep 2026,
#' findings 2 and 3). Each is checked with the shared exact engine on atoms
#' refined by the attribute:
#'
#'   need     the published sets are every group's membership and, for the
#'            groups whose count is shown, their members who need the fix;
#'            the count starts hidden where it or its complement is under k,
#'            then the smallest group in each recovering combination loses
#'            its count until nothing under k can be worked out
#'   effects  the published sets are the members each move changes, for the
#'            groups whose effect is shown, over the changed respondents only;
#'            a group with 1 to k-1 movers starts hidden, then the same loop
#'   bundles  as effects, on the union of the bundle's moves
#'
#' Moves depend on lever values, never on weights, so one decision serves the
#' weighted and the unweighted version alike.
#'
#' @param model The unweighted model (need masks and deltas)
#' @param publish From disclosure_publish_groups()
#' @param context The context the groups were formed on
#' @param k Minimum group
#' @return List: need (logical, groups by levers, TRUE = shown), effect
#'   (logical array, groups by levers by moves, NA where the move does not
#'   apply), bundle (logical, groups by bundles), need_checked and
#'   effects_checked (TRUE), and the counts hidden: need_hidden,
#'   need_hidden_by_recovery, effects_hidden, effects_hidden_thin,
#'   effects_hidden_by_recovery
#' @keywords internal
whatif_safe_suppression <- function(model, publish, context, k) {
  spec <- model$spec
  levers <- spec$levers
  keys <- vapply(levers, `[[`, "", "key")
  members <- publish$members
  G <- ncol(members)
  ids <- colnames(members)
  n_g <- colSums(members)
  member_cols <- lapply(seq_len(G), function(g) members[, g])
  stuck <- function(what) {
    whatif_refuse("CALC_DISCLOSURE_RECOVERABLE", "A small group could still be worked out",
      sprintf("%s can be worked out from the published groups, and nothing more can be hidden.", what),
      "A client could recover a statistic about fewer than the minimum group.",
      c("Declare fewer crossings, or raise the minimum group.", "Report this case."))
  }
  smallest <- function(candidates) candidates[which.min(n_g[candidates])]

  need <- matrix(TRUE, G, length(keys), dimnames = list(ids, keys))
  need_rec <- 0L
  for (j in seq_along(keys)) {
    mask <- whatif_need_mask(levers[[j]])
    cnt <- colSums(members & mask)
    shown <- cnt >= k & (n_g - cnt) >= k
    atoms <- disclosure_atoms(context, list(need = mask))
    repeat {
      sh <- which(shown)
      A <- disclosure_atom_sets(atoms, c(member_cols, lapply(sh, function(g) members[, g] & mask)))
      rc <- disclosure_small_recoverable(atoms$n, A, k)
      if (!length(rc$sets)) break
      new <- integer(0)
      for (st in rc$sets) {
        used <- which(abs(st$coef[G + seq_along(sh)]) > 1e-8)
        if (length(used)) new <- c(new, smallest(sh[used]))
      }
      new <- unique(new)
      if (!length(new)) stuck(sprintf("A set of under %d respondents", k))
      shown[new] <- FALSE
      need_rec <- need_rec + length(new)
    }
    need[, j] <- shown
  }

  moves <- WHATIF_MOVES
  effect <- array(NA, c(G, length(keys), length(moves)), dimnames = list(ids, keys, moves))
  eff_thin <- 0L
  eff_rec <- 0L
  cache <- list()
  decide <- function(moved) {
    sig <- paste(which(moved), collapse = ",")
    if (!is.null(cache[[sig]])) return(cache[[sig]])
    movers <- colSums(members & moved)
    shown <- !(movers > 0 & movers < k)
    thin <- sum(!shown)
    rec <- 0L
    atoms <- disclosure_atoms(context, list(moved = moved))
    keep <- atoms$attributes[, "moved"]
    repeat {
      sh <- which(shown)
      if (!length(sh) || !any(keep)) break
      A <- disclosure_atom_sets(atoms, lapply(sh, function(g) members[, g] & moved))[keep, , drop = FALSE]
      rc <- disclosure_small_recoverable(atoms$n[keep], A, k)
      if (!length(rc$sets)) break
      new <- integer(0)
      for (st in rc$sets) {
        used <- which(abs(st$coef) > 1e-8)
        if (length(used)) new <- c(new, smallest(sh[used]))
      }
      new <- unique(new)
      if (!length(new)) stuck(sprintf("A set of under %d changed respondents", k))
      shown[new] <- FALSE
      rec <- rec + length(new)
    }
    out <- list(shown = shown, thin = thin, rec = rec)
    cache[[sig]] <<- out
    out
  }
  for (j in seq_along(keys)) for (mv in moves) {
    dx <- model$deltas[[keys[j]]][[mv]]
    if (is.null(dx)) next
    d <- decide(dx != 0)
    effect[, j, mv] <- d$shown
    eff_thin <- eff_thin + d$thin
    eff_rec <- eff_rec + d$rec
  }
  bundles <- spec$bundles %||% list()
  bundle <- matrix(TRUE, G, length(bundles), dimnames = list(ids, NULL))
  for (b in seq_along(bundles)) {
    moved <- rep(FALSE, nrow(members))
    for (key in names(bundles[[b]]$moves)) {
      moved <- moved | model$deltas[[key]][[bundles[[b]]$moves[[key]]]] != 0
    }
    d <- decide(moved)
    bundle[, b] <- d$shown
    eff_thin <- eff_thin + d$thin
    eff_rec <- eff_rec + d$rec
  }
  list(need = need, effect = effect, bundle = bundle,
       need_checked = TRUE, effects_checked = TRUE,
       need_hidden = sum(!need), need_hidden_by_recovery = need_rec,
       effects_hidden = sum(!effect, na.rm = TRUE) + sum(!bundle),
       effects_hidden_thin = eff_thin, effects_hidden_by_recovery = eff_rec)
}


#' Warnings the Client-Safe Part Carries: the Same Facts Without Counts
#'
#' The open part's warnings say how many respondents sit in a thin outcome
#' category or gave "Don't know". Those are whole-sample counts and can be
#' under k, so the client-safe part carries each warning reworded without its
#' number. Percentages stay: a share of the sample is not a count.
#'
#' @param model_warnings From the fitted model
#' @param log The preflight log, with the after-fit rows
#' @param s Settings
#' @param spec The model spec (lever labels)
#' @return Character vector
#' @keywords internal
whatif_safe_warnings <- function(model_warnings, log, s, spec) {
  labels <- stats::setNames(vapply(spec$levers, `[[`, "", "label"), vapply(spec$levers, `[[`, "", "key"))
  out <- vapply(model_warnings, function(w) {
    if (grepl("bootstrap refits did not converge", w, fixed = TRUE)) "Some bootstrap refits did not converge." else w
  }, character(1), USE.NAMES = FALSE)
  rows <- log[log$Severity == "Warning" & !log$Check %in% c("Sign check", "Model"), , drop = FALSE]
  for (i in seq_len(NROW(rows))) {
    out <- c(out, switch(rows$Check[i],
      "Outcome" = sprintf("Few %s are %s. Effects at that end of the outcome rest on very few people.",
                          s$units_noun, rows$Field[i]),
      "Don't know" = sprintf("More than a tenth of the answers on %s were \"Don't know\" and were set to the %s rating.",
                             labels[rows$Field[i]] %||% rows$Field[i], s$dont_know),
      rows$Message[i]))
  }
  unname(out)
}
