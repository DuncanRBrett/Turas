# ==============================================================================
# STATS DIAGNOSTICS
# ==============================================================================
# Assembles the diagnostic payload for a Tabs run (data received & used, the
# statistical assumptions applied, TRS events, reproducibility) and shapes a
# curated, JSON-friendly copy for the interactive v2 report's Report tab.
#
# The SAME payload feeds two deliverables, so they can never drift:
#   - the Excel stats pack  (turas_write_stats_pack, all six sheets)
#   - the in-report panel   (diagnostics_for_island, a curated subset)
#
# The Excel pack stays gated on Generate_Stats_Pack; the in-report panel is
# always attached to the data island (project$diagnostics) so every v2 report
# is self-documenting and carries the diagnostics inside saved copies.
# ==============================================================================

#' Build the Tabs diagnostic payload
#'
#' Pure assembly (no file I/O, no writer dependency): gathers the run's
#' data receipt, data used, statistical assumptions, TRS run result and
#' reproducibility info into one payload list. Consumed by both the Excel
#' stats-pack writer and the report-island shaper.
#'
#' @param config_result Config load result (carries $config_obj, $output_path)
#' @param data_result Data load result (survey_data, effective_n)
#' @param analysis_result Analysis result (all_results, skipped/partial questions)
#' @param workbook_result Workbook result (run_result, project_name)
#' @param start_time POSIXct run start (for duration + timestamp)
#' @param script_version Character Turas/Tabs version string
#' @return A named list payload (see turas_write_stats_pack for the schema)
#' @keywords internal
build_tabs_diagnostics <- function(config_result, data_result,
                                   analysis_result, workbook_result,
                                   start_time, script_version) {

  config_obj <- config_result$config_obj

  # Data receipt
  data_receipt <- list(
    file_name = basename(config_obj$data_file %||% "unknown"),
    n_rows    = nrow(data_result$survey_data),
    n_cols    = ncol(data_result$survey_data)
  )

  # Data used
  n_questions <- length(analysis_result$all_results)
  n_skipped   <- length(analysis_result$skipped_questions)
  n_partial   <- length(analysis_result$partial_questions)

  data_used <- list(
    n_respondents      = nrow(data_result$survey_data),
    n_excluded         = 0L,
    questions_total    = n_questions + n_skipped,
    questions_analysed = n_questions,
    questions_skipped  = n_skipped,
    questions_partial  = n_partial
  )

  # Weight diagnostics
  is_weighted <- isTRUE(config_obj$apply_weighting)
  weight_var  <- if (is_weighted) config_obj$weight_variable else NULL
  eff_n_val   <- data_result$effective_n %||% NA

  # Significance testing parameters
  sig_enabled  <- isTRUE(config_obj$enable_significance_testing)
  alpha_val    <- config_obj$alpha %||% 0.05
  min_base_val <- config_obj$min_base %||% 30

  # TRS summary
  run_result <- workbook_result$run_result
  n_events   <- length(run_result$events %||% list())
  n_refusals <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "REFUSE"), logical(1)))
  n_partials <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "PARTIAL"), logical(1)))
  trs_summary <- if (n_events == 0) {
    "No events — ran cleanly"
  } else {
    parts <- character(0)
    if (n_refusals > 0) parts <- c(parts, sprintf("%d refusal(s)", n_refusals))
    if (n_partials > 0) parts <- c(parts, sprintf("%d partial(s)", n_partials))
    remainder <- n_events - n_refusals - n_partials
    if (remainder > 0) parts <- c(parts, sprintf("%d info event(s)", remainder))
    paste(parts, collapse = ", ")
  }

  duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  assumptions <- list(
    "Analysis Type"              = "Cross-tabulation",
    "Questions Processed"        = as.character(n_questions),
    "Questions Skipped"          = as.character(n_skipped),
    "Weighting"                  = if (is_weighted) sprintf("Yes — %s", weight_var) else "No",
    "Effective N"                = if (!is.na(eff_n_val)) format(round(eff_n_val), big.mark = ",") else "—",
    "Significance Testing"       = if (sig_enabled) "Enabled" else "Disabled",
    "Alpha (p-value threshold)"  = if (sig_enabled) sprintf("%.3f", alpha_val) else "—",
    "Minimum Base Size"          = as.character(min_base_val),
    "Bonferroni Correction"      = if (sig_enabled && isTRUE(config_obj$bonferroni_correction)) "Applied" else "Not applied",
    "Interactive Report"         = if (isTRUE(config_obj$html_report_v2)) "Generated" else "Not requested",
    "Classic HTML Report"        = if (isTRUE(config_obj$html_report)) "Generated" else "Not requested",
    "AI Insights"                = if (isTRUE(config_obj$ai_insights)) "Enabled" else "Disabled",
    "TRS Status"                 = run_result$status %||% "PASS",
    "TRS Events"                 = trs_summary
  )

  config_echo <- list(
    data_file      = config_obj$data_file,
    structure_file = config_obj$structure_file,
    output_file    = config_result$output_path,
    apply_weighting = config_obj$apply_weighting,
    weight_variable = config_obj$weight_variable,
    enable_significance_testing = config_obj$enable_significance_testing
  )

  list(
    module           = "TABS",
    project_name     = workbook_result$project_name   %||% NULL,
    analyst_name     = config_obj$analyst_name         %||% NULL,
    research_house   = config_obj$research_house       %||% NULL,
    run_timestamp    = start_time,
    turas_version    = script_version,
    r_version        = R.version$version.string,
    status           = run_result$status %||% "PASS",
    duration_seconds = if (duration_secs > 0 && duration_secs < 86400) duration_secs else NA,
    data_receipt     = data_receipt,
    data_used        = data_used,
    assumptions      = assumptions,
    run_result       = run_result,
    packages         = c("openxlsx", "readxl"),
    config_echo      = config_echo
  )
}


#' Shape a curated diagnostics object for the report data island
#'
#' Pure transform of a stats-pack payload into a compact, JSON-friendly object
#' the Report tab renders (project$diagnostics). Curated per the operator
#' decision: identity, data received & used, assumptions/parameters, TRS
#' warnings and reproducibility — the raw config echo is left to the Excel pack.
#'
#' Sections are ordered [label, value] rows so key order is deterministic in the
#' island (never relies on JSON object key ordering).
#'
#' @param payload A payload from build_tabs_diagnostics()
#' @return A list \code{{ generated_by, status, sections[], warnings }}, or NULL
#'   when the payload is unusable.
#' @keywords internal
diagnostics_for_island <- function(payload) {
  if (is.null(payload) || !is.list(payload)) return(NULL)

  # Coerce a scalar to a clean display string; NULL/NA/empty -> em dash.
  disp <- function(x) {
    if (is.null(x) || length(x) == 0) return("—")
    x <- x[[1]]
    if (length(x) == 0 || is.na(x) || !nzchar(as.character(x))) return("—")
    as.character(x)
  }
  row <- function(label, value) c(as.character(label), disp(value))

  fmt_ts <- function(ts) {
    if (is.null(ts) || length(ts) == 0) return(NULL)
    if (inherits(ts, "POSIXct")) return(format(ts, "%Y-%m-%d %H:%M %Z"))
    as.character(ts)[1]
  }

  dr <- payload$data_receipt %||% list()
  du <- payload$data_used    %||% list()

  rc <- if (!is.null(dr$n_rows) && !is.null(dr$n_cols)) {
    paste0(format(dr$n_rows, big.mark = ","), " × ", format(dr$n_cols, big.mark = ","))
  } else NULL

  dur <- payload$duration_seconds
  dur_disp <- if (!is.null(dur) && length(dur) == 1 && !is.na(dur)) {
    sprintf("%.1f s", as.numeric(dur))
  } else NULL

  declaration <- list(
    row("Project",        payload$project_name),
    row("Analyst",        payload$analyst_name),
    row("Research house", payload$research_house),
    row("Run",            fmt_ts(payload$run_timestamp)),
    row("Status",         payload$status)
  )

  data_rows <- list(
    row("Source file",          dr$file_name),
    row("Rows × columns",       rc),
    row("Respondents analysed", du$n_respondents),
    row("Excluded",             du$n_excluded),
    row("Questions analysed",   du$questions_analysed),
    row("Questions skipped",    du$questions_skipped),
    row("Questions partial",    du$questions_partial)
  )

  # The assumptions list is already display-ready (labels + values); keep order.
  assum <- payload$assumptions %||% list()
  assum_rows <- if (length(assum)) {
    unname(Map(function(nm, v) c(as.character(nm), disp(v)), names(assum), assum))
  } else list()

  repro_rows <- list(
    row("Turas version", payload$turas_version),
    row("R version",     payload$r_version),
    row("Packages",      if (!is.null(payload$packages)) paste(payload$packages, collapse = ", ") else NULL),
    row("Run timestamp", fmt_ts(payload$run_timestamp)),
    row("Duration",      dur_disp)
  )

  sections <- list(
    list(title = "Declaration",              rows = declaration),
    list(title = "Data received & used",     rows = data_rows),
    list(title = "Assumptions & parameters", rows = assum_rows),
    list(title = "Reproducibility",          rows = repro_rows)
  )

  # Warnings mirror the Excel Warnings sheet: one row per TRS event.
  events_raw <- payload$run_result$events %||% list()
  events <- lapply(events_raw, function(e) {
    list(
      level   = disp(e$level),
      code    = disp(e$code),
      title   = disp(e$title),
      message = disp(e$detail %||% e$problem %||% e$error)
    )
  })
  summary_txt <- if (length(events_raw) == 0) {
    "No events — analysis ran cleanly"
  } else {
    sprintf("%d event(s) recorded", length(events_raw))
  }

  list(
    generated_by = payload$module %||% "TABS",
    status       = payload$status %||% "PASS",
    sections     = sections,
    warnings     = list(summary = summary_txt, events = events)
  )
}
