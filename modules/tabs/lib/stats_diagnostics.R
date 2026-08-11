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

  # Data receipt. The data file is declared on the STRUCTURE workbook's
  # Project sheet (data_setup.R), not in Settings — read it from where the run
  # actually found it, falling back to a Settings override (review 2026-08, I4).
  project_data_file <- tryCatch(
    get_config_value(data_result$survey_structure$project, "data_file", NULL),
    error = function(e) NULL)
  data_receipt <- list(
    file_name = basename(config_obj$data_file %||% project_data_file %||% "unknown"),
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
  # real key: significance_min_base ("min_base" was never populated -> the
  # contractual Declaration always printed 30; review 2026-08, I4)
  min_base_val <- config_obj$significance_min_base %||% 30

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
    "AI Insights"                = if (isTRUE(config_obj$enable_ai_insights)) "Enabled" else "Disabled",
    "TRS Status"                 = run_result$status %||% "PASS",
    "TRS Events"                 = trs_summary
  )

  # Finite population correction. Stated only when a universe is actually
  # configured, so a sample study's Declaration is unchanged. Reads the real
  # config keys (population_size, the Population sheet) rather than a flag that
  # might not reflect what the engine did — the lesson of review finding I4.
  pop_size <- suppressWarnings(as.numeric(config_obj$population_size))
  pop_size <- if (length(pop_size) == 1L && !is.na(pop_size) && pop_size > 1) pop_size else NULL
  pop_frame <- config_obj$population_frame
  n_subgroups <- if (!is.null(pop_frame) && is.data.frame(pop_frame)) nrow(pop_frame) else 0L

  if (!is.null(pop_size) || n_subgroups > 0) {
    if (!is.null(pop_size)) {
      assumptions[["Universe size"]] <- format(round(pop_size), big.mark = ",")
      n_resp <- suppressWarnings(as.numeric(data_used$n_respondents))
      if (length(n_resp) == 1L && !is.na(n_resp) && n_resp > 0) {
        assumptions[["Coverage of universe"]] <- sprintf("%.1f%%", 100 * n_resp / pop_size)
      }
    }
    if (n_subgroups > 0) {
      assumptions[["Subgroup universes"]] <-
        sprintf("%d declared on the Population sheet", n_subgroups)
    }
    assumptions[["Finite population correction"]] <- sprintf(
      paste0("Applied — significance and intervals use finite-population-",
             "corrected effective bases. Coverage at or below %.0f%% is left ",
             "uncorrected; a fully counted column is reported without ",
             "significance letters."),
      100 * FPC_MIN_COVERAGE)
  }

  # Method notes for the two statistics whose basis changed in the 2026-08
  # review (I1, I6). Each is stated only when the run actually contains that
  # statistic, so a study with neither has a Declaration identical to before.
  question_types <- tryCatch(
    as.character(data_result$survey_structure$questions$Variable_Type),
    error = function(e) character(0))
  if (any(!is.na(question_types) & question_types == "NPS")) {
    assumptions[["NPS significance"]] <- paste0(
      "Tested on the per-respondent Net Promoter score (+100 promoter, ",
      "0 passive, -100 detractor), whose weighted mean is the published NPS. ",
      "The Standard Deviation row for an NPS question is on the same scale. ",
      "Letters therefore answer 'do these NPS scores differ', not 'do the ",
      "underlying 0-10 ratings differ'.")
  }
  if (isTRUE(safe_logical(config_obj$show_net_positive, default = FALSE))) {
    assumptions[["NET POSITIVE significance"]] <- paste0(
      "Tested on a per-respondent net score (+100 top box, -100 bottom box, ",
      "0 otherwise), whose weighted mean is the published NET POSITIVE. ",
      "Letters therefore answer 'do these nets differ', not 'do the top boxes ",
      "differ'.")
  }
  if (isTRUE(safe_logical(config_obj$enable_chi_square, default = FALSE))) {
    assumptions[["Chi-square test"]] <- paste0(
      "Pearson's chi-square on the BoxCategory counts as computed, without ",
      "the rounding applied for display",
      if (is_weighted) {
        paste0(". Each column's counts are scaled to its Kish effective base, ",
               "so the test is sized on the people interviewed and is ",
               "unaffected by the scale of the weights.")
      } else ".")
  }

  config_echo <- list(
    data_file      = config_obj$data_file %||% project_data_file,
    structure_file = config_obj$structure_file %||% config_result$structure_file_path,
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
    # Naming R alone understated where the arithmetic happens. R computes the
    # published figures; every COMPUTED view the reader makes — filters, custom
    # banners, wave-on-wave comparisons and their significance — is recomputed
    # by Turas's own engine inside this file, in the browser. Both are Turas and
    # both are deterministic, but a reader told only "R" is told half of it.
    row("Compute engines", paste0(
      "R for the published figures; Turas's JavaScript engine, embedded in this ",
      "HTML file, for every view the reader recomputes (filters, custom banners, ",
      "wave-on-wave comparisons and their significance). No third-party ",
      "statistical library and no server.")),
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
