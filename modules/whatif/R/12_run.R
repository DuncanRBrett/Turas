# ==============================================================================
# WHAT IF - RUN A STUDY FROM ITS CONFIG
# ==============================================================================
#
# run_whatif(config_file) is the module's entry point:
#
#   1. read the config and build the engine spec from the data (08, 09)
#   2. preflight: findings that need judgement (10)
#   3. fit the lever model, refits and profile model (00_main)
#   4. calibration with and without context baselines, symptom effects (07)
#   5. the groups a client-safe file may publish, and their results (shared
#      disclosure_groups.R, 05)
#   6. write {output_name}.xlsx and {output_name}_whatif_island.json (11, 13)
#
# Point the tabs setting whatif_island at the .json to add the What if tab to
# the report. The tabs build embeds the open or the client-safe part
# according to its "Who is this file for?" choice.
#
# ==============================================================================

#' Run a What if Study
#'
#' @param config_file Path to the What if config workbook
#' @param verbose Print progress to the console
#' @return List with status ("PASS" or "PARTIAL"), warnings, files (excel,
#'   island), model, preflight; or a structured refusal printed to the console
#' @examples
#' \dontrun{
#'   res <- run_whatif("SACAP_2025_WhatIf_Config.xlsx")
#'   res$files$island   # set the tabs setting whatif_island to this path
#' }
#' @export
run_whatif <- function(config_file, verbose = TRUE) {
  with_refusal_handler(run_whatif_impl(config_file, verbose), module = "WHATIF")
}


#' @keywords internal
run_whatif_impl <- function(config_file, verbose = TRUE) {
  t0 <- Sys.time()
  whatif_say("reading ", basename(config_file), verbose = verbose)
  cfg <- whatif_read_config(config_file)
  s <- cfg$settings
  prep <- whatif_prepare(cfg, verbose)
  pf <- whatif_preflight(prep, cfg)
  whatif_print_preflight(pf$log, verbose)

  model <- whatif_run_engine_impl(prep$spec, verbose)
  model$spec$penalty_levers <- model$spec$penalty_levers %||% WHATIF_LEVER_PENALTY
  after <- whatif_preflight_after_fit(model)
  log <- rbind(pf$log, after)

  cal <- whatif_calibration(model)
  cal_ratings <- if (length(prep$spec$baselines)) {
    ro <- prep$spec
    ro$baselines <- character(0)
    ro$profile <- NULL
    ro$n_boot <- 0L
    whatif_calibration(whatif_run_engine_impl(ro, verbose = FALSE))
  } else cal
  whatif_say(sprintf("calibration: held-out pseudo R2 %.3f, %d of %d groups of 30+ outside their 95%% band (ratings only: %.3f, %d of %d)",
                     cal$cv_r2, cal$n_outside, cal$n_groups, cal_ratings$cv_r2, cal_ratings$n_outside,
                     cal_ratings$n_groups), verbose = verbose)
  symptoms <- whatif_symptom_effects(model, prep$symptoms)

  filter_keys <- cfg$context$Key[whatif_flag(cfg$context$Filter)]
  if (!length(filter_keys)) filter_keys <- cfg$context$Key
  crossings <- lapply(seq_len(nrow(cfg$crossings)), function(i) c(cfg$crossings$Key1[i], cfg$crossings$Key2[i]))
  bad_cross <- setdiff(unlist(crossings), filter_keys)
  if (length(bad_cross)) {
    whatif_refuse("CFG_CROSSING_NOT_FILTER", "Crossing uses a variable that is not a filter",
      sprintf("Crossings name %s, which Filter = N on the Context sheet.", paste(bad_cross, collapse = ", ")),
      "A published crossing is a filter combination; its variables must be filters.",
      "Set Filter = Y for those variables or remove the crossing.")
  }
  publish <- disclosure_publish_groups(model$spec$context[filter_keys], crossings, s$min_group,
                                       paste("All", s$units_noun))
  masks <- lapply(seq_len(ncol(publish$members)), function(j) publish$members[, j])
  names(masks) <- colnames(publish$members)
  safe_results <- whatif_group_results_impl(model, masks)
  whatif_say(sprintf("client-safe: %d groups published at a minimum of %d (%d crossing cells hidden, %d groups hidden by the nesting check)",
                     nrow(publish$groups), s$min_group, nrow(publish$hidden), publish$audit$nesting_hidden),
             verbose = verbose)
  sentence <- whatif_sentence(cfg, model)
  safe_profile <- if (!is.null(model$profile)) whatif_safe_profile(model, s$min_group, prep, sentence, verbose) else NULL

  warnings <- c(model$warnings, log$Message[log$Severity == "Warning" & log$Check != "Sign check" & log$Check != "Model"])
  run_status <- if (length(warnings)) "PARTIAL" else "PASS"
  notes <- whatif_notes(model, prep, s)

  run <- list(cfg = cfg, prep = prep, model = model, calibration = cal, calibration_ratings_only = cal_ratings,
              symptoms = symptoms, publish = publish, safe_results = safe_results, safe_profile = safe_profile,
              filter_keys = filter_keys, crossings = crossings, run_status = run_status, warnings = warnings,
              notes = notes, sentence = sentence, scale_labels = whatif_scale_labels(prep))

  out_dir <- whatif_resolve(cfg$project_root, s$output_folder)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  island_path <- file.path(out_dir, paste0(s$output_name, "_whatif_island.json"))
  excel_path <- file.path(out_dir, paste0(s$output_name, ".xlsx"))
  payload <- whatif_island_payload(run)
  whatif_write_island(payload, island_path)
  whatif_write_excel(run, log, pf$proposed_structure, excel_path)
  whatif_say(sprintf("wrote %s (%.0f kb) and %s. %s in %.0f s.", basename(island_path),
                     file.size(island_path) / 1024, basename(excel_path), run_status,
                     as.numeric(difftime(Sys.time(), t0, units = "secs"))), verbose = verbose)
  if (run_status == "PARTIAL" && verbose) {
    cat("\n[What if] PARTIAL: see the Preflight sheet. Warnings:\n")
    for (w in unique(warnings)) cat("  -", w, "\n")
  }
  list(status = run_status, warnings = warnings,
       files = list(excel = excel_path, island = island_path),
       model = model, preflight = log, proposed_structure = pf$proposed_structure,
       publish = publish, calibration = cal, calibration_ratings_only = cal_ratings,
       prep = prep, payload = payload)
}


#' Print the Preflight Log
#' @keywords internal
whatif_print_preflight <- function(log, verbose = TRUE) {
  if (!verbose || is.null(log) || !nrow(log)) return(invisible(NULL))
  cat("\n┌─── WHAT IF PREFLIGHT ─────────────────────────────────────┐\n")
  for (i in seq_len(nrow(log))) {
    cat(sprintf("│ [%s] %s%s: %s\n", log$Severity[i], log$Check[i],
                if (nzchar(log$Field[i])) paste0(" (", log$Field[i], ")") else "", log$Message[i]))
  }
  cat("└───────────────────────────────────────────────────────────┘\n\n")
  invisible(NULL)
}


#' The Client-Safe Profile Model
#'
#' Brief decision 7: every level entering the profile model must clear the
#' minimum group, and the builder offers only combinations at least that many
#' respondents share. Levels under the minimum are pooled into the trait's most
#' common level before a separate fit, so no coefficient is the near-average of
#' a handful of people.
#'
#' @keywords internal
whatif_safe_profile <- function(model, k, prep, sentence = NULL, verbose = TRUE) {
  spec <- model$spec
  pm <- model$profile
  pooled <- list()
  ctx <- spec$context
  keys <- character(0)
  for (key in pm$keys) {
    v <- ctx[[key]]$values
    tab <- table(v)
    top <- names(tab)[which.max(tab)]
    small <- names(tab)[tab < k]
    if (length(small)) {
      v[v %in% small] <- top
      pooled[[key]] <- stats::setNames(as.list(rep(top, length(small))), small)
    }
    ctx[[key]]$values <- v
    if (length(unique(v)) > 1) keys <- c(keys, key)
  }
  if (!length(keys)) return(NULL)
  s2 <- spec
  s2$context <- ctx
  s2$profile <- list(keys = keys, structural = intersect(pm$structural, keys),
                     rules = pm$rules[pm$rules$key1 %in% keys & pm$rules$key2 %in% keys, , drop = FALSE])
  spm <- whatif_fit_profile(s2, model$folds, verbose = FALSE)
  combo <- do.call(paste, c(lapply(keys, function(key) ctx[[key]]$values), sep = "\r"))
  tab <- table(combo)
  ok <- names(tab)[tab >= k]
  combos <- lapply(strsplit(ok, "\r", fixed = TRUE), function(parts) {
    whatif_arr(vapply(seq_along(keys), function(i) match(parts[i], spm$levels[[keys[i]]]) - 1L, integer(1)))
  })
  if (NROW(s2$profile$rules)) {
    blocked <- vapply(combos, function(cb) {
      prof <- stats::setNames(vapply(seq_along(keys), function(i) spm$levels[[keys[i]]][cb[i] + 1], ""), keys)
      any(prof[s2$profile$rules$key1] == s2$profile$rules$level1 & prof[s2$profile$rules$key2] == s2$profile$rules$level2)
    }, logical(1))
    combos <- combos[!blocked]
  }
  whatif_say(sprintf("client-safe profile: %d traits, %d level(s) pooled, %d combinations with %d or more respondents",
                     length(keys), sum(lengths(pooled)), length(combos), k), verbose = verbose)
  level_n <- lapply(keys, function(key) as.integer(table(factor(ctx[[key]]$values, spm$levels[[key]]))))
  names(level_n) <- keys
  packed <- whatif_pack_profile(spm, ctx, sentence, prep$context_order, level_n)
  packed$combos <- combos
  attr(packed, "pooled") <- pooled
  packed
}


#' Notes Shown in the Tab's Diagnostics
#' @keywords internal
whatif_notes <- function(model, prep, s) {
  dk <- vapply(model$spec$levers, function(lv) lv$missing %||% 0L, numeric(1))
  labs <- vapply(model$spec$levers, `[[`, "", "label")
  notes <- character(0)
  if (any(dk > 0)) {
    notes <- c(notes, sprintf("\"Don't know\" answers were set to the %s rating for that question: %s.",
                              if (s$dont_know == "centre") "middle" else "median",
                              paste(sprintf("%s %d", labs[dk > 0], dk[dk > 0]), collapse = ", ")))
  }
  if (length(model$spec$baselines)) {
    notes <- c(notes, sprintf("Who the %s is (%s) enters the model as a baseline, shrunk towards the average, so group levels are right while each area's effect is estimated within groups.",
                              s$unit_noun,
                              paste(tolower(vapply(model$spec$context[model$spec$baselines], `[[`, "", "label")),
                                    collapse = ", ")))
  }
  notes
}


#' The "Build a ..." Sentence for the Island
#' @keywords internal
whatif_sentence <- function(cfg, model) {
  if (is.null(model$profile)) return(NULL)
  se <- cfg$sentence
  if (!nrow(se)) {
    return(lapply(model$profile$keys, function(k) list(key = k, text = "", style = "")))
  }
  lapply(seq_len(nrow(se)), function(i) list(key = if (is.na(se$Key[i])) "" else se$Key[i],
                                             text = se$Text[i] %||% "",
                                             style = if (is.na(se$Style[i])) "" else se$Style[i]))
}


#' Scale Labels from the Survey_Structure, When the Levers Are Labelled
#' @keywords internal
whatif_scale_labels <- function(prep) {
  for (lv in prep$spec$levers) {
    if (lv$kind == "coverage") next
    q <- prep$lever_info[[lv$key]]$items[1]
    o <- prep$options[[q]]
    if (!is.null(o) && any(!o$excluded) && suppressWarnings(all(is.na(as.numeric(o$text[!o$excluded]))))) {
      return(o$text[!o$excluded])
    }
  }
  character(0)
}
