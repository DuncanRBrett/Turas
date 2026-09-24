# ==============================================================================
# WHAT IF - EXCEL OUTPUT
# ==============================================================================
#
# {output_name}.xlsx, for the analyst:
#
#   Run_Status          status, warnings, counts, files (always first)
#   Effort              every lever for all respondents: slip and fix with 90%
#                       ranges, who needs it, net gain per 100 reached
#   Effort_unweighted   the same from the unweighted version, when the run
#                       also fitted a weighted one (the other sheets show the
#                       weighted version)
#   Groups              the same for every group a client-safe file publishes
#   Calibration         held-out predicted against actual by group, with and
#                       without context baselines
#   Preflight           findings that need judgement
#   Proposed_Structure  structural combinations nobody has, to confirm
#   Model               lever and baseline coefficients with refit ranges
#   Profile             "Build a ..." coefficients
#   Symptoms            apparent effects of rows marked Include = Symptom
#   Privacy             groups refused, crossing cells hidden and profile
#                       levels pooled for the client-safe file (never in it)
#
# Saved with turas_saveWorkbook() (never openxlsx::saveWorkbook: CLAUDE.md,
# Excel I/O).
#
# ==============================================================================

#' Write the What if Workbook
#'
#' @param run Run list from run_whatif_impl()
#' @param log Preflight log
#' @param proposed Proposed Structure rules
#' @param path Output path
#' @return The path, invisibly
#' @keywords internal
whatif_write_excel <- function(run, log, proposed, path, other = NULL) {
  model <- run$model
  spec <- model$spec
  s <- run$cfg$settings
  wb <- openxlsx::createWorkbook()
  head_style <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#323367", fontColour = "#FFFFFF")
  sheet <- function(name, df) {
    openxlsx::addWorksheet(wb, name)
    if (is.null(df) || !NROW(df)) df <- data.frame(Note = "Nothing to report.")
    df[] <- lapply(df, function(x) if (is.character(x)) turas_excel_escape_safe(x) else x)
    openxlsx::writeData(wb, name, df, headerStyle = head_style)
    openxlsx::setColWidths(wb, name, cols = seq_len(ncol(df)), widths = "auto")
    openxlsx::freezePane(wb, name, firstRow = TRUE)
  }
  labels <- stats::setNames(vapply(spec$levers, `[[`, "", "label"), vapply(spec$levers, `[[`, "", "key"))

  sheet("Run_Status", data.frame(
    Item = c("Status", "Study", "Respondents modelled", "Weighted", "Outcome", "Held-out pseudo R2",
             "Baseline penalty", "Minimum group", "Groups published client-safe", "Contribution file", "Run at",
             paste("Warning", seq_along(run$warnings))),
    Value = c(run$run_status, s$study_title, length(spec$y), if (isTRUE(spec$weighted)) "Yes" else "No",
              s$outcome_text, sprintf("%.3f", model$cv_r2),
              if (is.na(model$baseline_penalty)) "no baselines" else format(model$baseline_penalty),
              s$min_group, nrow(run$publish$groups), paste0(s$output_name, "_whatif_island.json"),
              format(Sys.time(), "%Y-%m-%d %H:%M"), run$warnings),
    stringsAsFactors = FALSE))

  effort_rows <- function(res, group_id = NULL, group_label = NULL, sign = model$sign) {
    lv <- res$levers
    keys <- unique(lv$key)
    do.call(rbind, lapply(keys, function(key) {
      r <- lv[lv$key == key, ]
      kind <- spec$levers[[match(key, names(labels))]]$kind
      slip <- r[r$move == (if (kind == "coverage") "withdraw" else "slip1"), ]
      fix <- r[r$move == (if (kind == "coverage") "extend" else "floor"), ]
      data.frame(
        Group = group_label %||% paste("All", s$units_noun), N = res$n,
        Actual = round(res$actual, 1), Lever = labels[[key]], Kind = kind, Need = fix$need,
        If_slips = round(slip$est, 1), Slip_lo = round(slip$lo, 1), Slip_hi = round(slip$hi, 1),
        If_fixed = round(fix$est, 1), Fix_lo = round(fix$lo, 1), Fix_hi = round(fix$hi, 1),
        Per_100_reached = round(fix$per_100, 1),
        Wrong_sign_share = sign$wrong_share[sign$key == key],
        stringsAsFactors = FALSE)
    }))
  }
  all_res <- run$safe_results[["all"]]
  sheet("Effort", effort_rows(all_res))
  if (!is.null(other)) {
    # The unweighted version, for a report built unweighted.
    sheet("Effort_unweighted", effort_rows(other$safe_results[["all"]], sign = other$model$sign))
  }
  grp <- run$publish$groups
  sheet("Groups", do.call(rbind, lapply(seq_len(nrow(grp)), function(i) {
    df <- effort_rows(run$safe_results[[grp$id[i]]], grp$id[i], paste0(grp$family[i], ": ", grp$label[i]))
    df$Need[df$Need < s$min_group] <- NA
    df
  })))

  cal <- merge(run$calibration_ratings_only$table[, c("variable", "level", "n", "actual", "predicted", "z")],
               run$calibration$table[, c("variable", "level", "predicted", "z")],
               by = c("variable", "level"), suffixes = c("_ratings_only", "_model"), sort = FALSE)
  num <- vapply(cal, is.numeric, logical(1))
  cal[num] <- lapply(cal[num], round, 2)
  sheet("Calibration", cal)
  sheet("Preflight", log)
  sheet("Proposed_Structure", proposed)

  fits <- c(list(model$main), model$boot)
  B <- sapply(fits, function(f) f$b)
  if (!is.matrix(B)) B <- matrix(B, nrow = 1)
  cols <- model$design$cols
  sheet("Model", data.frame(
    Term = ifelse(cols$is_context, paste0(cols$lever, " = ", cols$part),
                  paste0(labels[cols$lever] %||% cols$lever, if_else_part(cols$part))),
    Coefficient = round(B[, 1], 4),
    Refit_5 = if (ncol(B) > 1) round(apply(B[, -1, drop = FALSE], 1, stats::quantile, 0.05), 4) else NA,
    Refit_95 = if (ncol(B) > 1) round(apply(B[, -1, drop = FALSE], 1, stats::quantile, 0.95), 4) else NA,
    Penalty = model$penalty, stringsAsFactors = FALSE))
  if (!is.null(model$profile)) {
    pm <- model$profile
    sheet("Profile", data.frame(Trait = pm$cols$key, Level = pm$cols$level,
                                Coefficient = round(pm$fits[[1]]$b, 4),
                                Reference = vapply(pm$cols$key, function(k) pm$levels[[k]][1], ""),
                                stringsAsFactors = FALSE))
  }
  sheet("Symptoms", if (NROW(run$symptoms)) transform(run$symptoms, effect = round(effect, 1)) else NULL)

  # What the client-safe file leaves out, and why. For the analyst only: the
  # contribution file never names these.
  pub <- run$publish
  pooled <- attr(run$safe_profile, "pooled")
  privacy <- rbind(
    if (NROW(pub$refused)) data.frame(What = "Group not published", Detail = pub$refused$group,
                                      Why = pub$refused$why, stringsAsFactors = FALSE),
    if (NROW(pub$hidden)) data.frame(What = "Crossing cell hidden", Detail = paste0(pub$hidden$family, ": ",
                                     pub$hidden$level1, ", ", pub$hidden$level2),
                                     Why = "under the minimum, or hidden to protect one that is",
                                     stringsAsFactors = FALSE),
    if (length(pooled)) do.call(rbind, lapply(names(pooled), function(k) data.frame(
      What = "Build a ... level pooled", Detail = paste0(k, ": ", names(pooled[[k]]), " counted as ", unlist(pooled[[k]])),
      Why = paste("under", s$min_group, "respondents"), stringsAsFactors = FALSE))))
  sheet("Privacy", privacy)

  res <- turas_save_workbook_atomic(wb, path, module = "WHATIF", verbose = FALSE)
  if (!isTRUE(res$success)) {
    whatif_refuse("IO_EXCEL_WRITE_FAILED", "Could not write the What if workbook",
      sprintf("Saving %s failed: %s", basename(path), res$error %||% "unknown error"),
      "The analyst workbook would be missing.",
      "Close the file if it is open in Excel, check the folder is writable, and run again.")
  }
  invisible(path)
}


#' @keywords internal
if_else_part <- function(part) ifelse(part == "has", " (has it)", "")


#' Escape Text Against Formula Injection, If the Shared Helper Is Loaded
#' @keywords internal
turas_excel_escape_safe <- function(x) {
  if (exists("turas_excel_escape", mode = "function")) turas_excel_escape(x) else x
}
