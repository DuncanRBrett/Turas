# ==============================================================================
# TABS MODULE — QUALITATIVE COMMENT REPORT (orchestration)
# ==============================================================================
#
# Self-contained Phase-1 entry: a coded-comment workbook -> a v2 HTML comment
# report. Reads + classifies the workbook, builds the respondent master + banner,
# serialises the themes into DATA_AGG/DATA_MICRO via the existing engine, builds
# the DATA_QUAL verbatim island, and writes a single self-contained *_qual_report.html.
#
# This is additive: it writes a SEPARATE file and never touches the main Excel/HTML/v2
# outputs. The Phase-2 join (themes into the host survey's report) reuses everything
# here; only the banner/index source (qual_assemble.R) would change.
#
# Depends on (sourced by the pipeline): qual_workbook_io.R, qual_assemble.R,
# qual_island_builder.R, qual_quant_layer.R, data_layer_writer.R, microdata_writer.R,
# html_report_v2/build_report_v2.R, trs_refusal.R, jsonlite.
#
# Run the tests with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_report.R")
# ==============================================================================

#' Serialise the DATA_QUAL island to JSON (hidden verbatims -> JSON null).
#' @param island The island list from `qual_build_data_qual()` (or NULL).
#' @return A JSON string; "null" when the island is NULL.
serialize_data_qual <- function(island) {
  if (is.null(island)) return("null")
  jsonlite::toJSON(island, na = "null", null = "null", auto_unbox = TRUE, digits = NA)
}

#' Resolve a qual_workbook path the way structure_file resolves: a relative path is
#' joined to the config's project root, an absolute path passes through. Falls back to
#' the raw path when no config root is known (e.g. a direct/standalone call).
#' @param qual_workbook The configured path (relative or absolute).
#' @param config_obj The tabs config object (carries config_file_path after loading).
#' @return The resolved path.
qual_resolve_workbook_path <- function(qual_workbook, config_obj) {
  config_path <- config_obj$config_file_path
  if (is.null(config_path) || !nzchar(config_path) ||
      !exists("resolve_path", mode = "function") ||
      !exists("get_project_root", mode = "function")) {
    return(qual_workbook)
  }
  root <- tryCatch(get_project_root(config_path), error = function(e) NULL)
  if (is.null(root) || !nzchar(root)) return(qual_workbook)
  tryCatch(resolve_path(root, qual_workbook), error = function(e) qual_workbook)
}

#' Refuse: the comment workbook has no themed (coded) questions.
qual_refuse_no_themes <- function(qual_workbook, module) {
  turas_refuse(
    code = "DATA_QUAL_NO_THEMES", title = "No themed questions in the comment workbook",
    problem = sprintf("'%s' has only verbatim-only questions, so there is no theme crosstab to build.",
                      basename(qual_workbook)),
    why_it_matters = paste("The Phase-1 qualitative report is built around coded themes;",
                           "a verbatim-only browser-only report is a planned follow-up."),
    how_to_fix = c("Use a comment workbook with at least one coded (themed) question.",
                   "A verbatim-only browser report is a later phase."),
    module = module)
}

#' Build the DATA_QUAL island joined to the host survey (Phase-2 integrated path).
#'
#' Reads + classifies the comment workbook, joins its respondents to the host survey
#' by ResponseID so the island shares the main report's anonymous MICRO row index (and
#' therefore the main banner + the live-filter masks the closed<->open jump relies on),
#' then builds the DATA_QUAL island honouring the confidentiality dials. Unlike the
#' standalone report this does NOT need themed questions — it ships the verbatim/record
#' island only; the prevalence board computes from the records in the JS.
#'
#' @param qual_workbook Path to the coded-comment .xlsx (relative paths resolve against
#'   the config folder, like structure_file).
#' @param config_obj The tabs config object (the qual_* dials + qual_join_id_column).
#' @param survey_data The host survey data frame (the main report's respondents).
#' @param module Module label for refusal display.
#' @return list(status, json, island, matched, total, id_column). `status` is "PASS"
#'   (json populated), "NO_ID_COLUMN" (no response-id column resolved) or "NO_MATCHES"
#'   (id column found but no workbook respondent joined — likely a wrong id column).
#'   The caller falls back to the standalone *_qual_report.html on a non-PASS status.
#' @export
build_integrated_qual_island <- function(qual_workbook, config_obj, survey_data, module = "TABS") {
  qual_path <- qual_resolve_workbook_path(qual_workbook, config_obj)
  read_result <- qual_read_workbook(qual_path, module)          # TRS-refuses on a bad file
  joined <- qual_resolve_against_survey(read_result$questions, survey_data,
                                        id_col = config_obj$qual_join_id_column)
  if (!identical(joined$status, "PASS")) {
    return(list(status = "NO_ID_COLUMN", json = NULL, island = NULL,
                matched = 0L, total = 0L, id_column = NA_character_))
  }
  if (isTRUE(joined$matched == 0L)) {
    return(list(status = "NO_MATCHES", json = NULL, island = NULL,
                matched = 0L, total = joined$total, id_column = joined$id_column))
  }
  island <- qual_build_data_qual(read_result$questions, joined$master, list(
    text_mode = config_obj$qual_confidentiality_mode,
    demographic_cuts = config_obj$qual_demographic_cuts,
    noteworthy_default = config_obj$qual_noteworthy_default))
  list(status = "PASS", json = serialize_data_qual(island), island = island,
       matched = joined$matched, total = joined$total, id_column = joined$id_column)
}

#' Resolve the closed<->open jump links from the Selection sheet (V12).
#'
#' Each open-end row (Include=N) may carry two columns: `CommentSheet` (the comment-
#' workbook sheet that codes this open-end) and `CommentLink` (the closed question or
#' composite it explains). This builds a map keyed by the LINK TARGET so the JS can
#' place a "comments" affordance on that card and jump to the open-end's comments:
#'   { <targetCode>: { qcode, sheet, openEnd, title } }
#' The resolver is composite-agnostic on the R side: it just emits the target code; the
#' JS shows the affordance wherever a card with that code renders (Crosstabs for closed
#' questions, the Dashboard for composites). Rows with a CommentSheet but no CommentLink
#' are generic (reachable in the qual tab rail only). A CommentSheet that does not match
#' any island question is reported as unresolved so the caller can warn.
#'
#' @param selection_df The full Selection sheet (all rows, as character).
#' @param island The DATA_QUAL island; its `$questions` carry the resolved sheet codes.
#' @param valid_targets Optional character vector of the codes that actually render a
#'   card (closed-question codes + composite codes). When supplied, a `CommentLink`
#'   whose target is not among them is collected in `unlinked_targets` so the caller can
#'   warn — this catches a mistyped target (e.g. `Q_Values` when the composite is
#'   `Q_Value`), which would otherwise just silently never show the jump affordance.
#' @return list(links, generic, unresolved, unlinked_targets). `links` is the target-keyed
#'   map; `generic` are qcodes coded but not linked; `unresolved` are CommentSheet values
#'   with no matching island question; `unlinked_targets` are CommentLink targets that
#'   match no rendered card (each `list(target, openEnd, sheet)`).
#' @export
qual_build_links <- function(selection_df, island, valid_targets = NULL) {
  empty <- list(links = list(), generic = character(0), unresolved = character(0),
                unlinked_targets = list())
  if (is.null(island) || is.null(island$questions) || !length(island$questions)) return(empty)
  if (is.null(selection_df) || !nrow(selection_df) || !("CommentSheet" %in% names(selection_df))) {
    return(empty)
  }
  q_by_code <- list()
  for (q in island$questions) q_by_code[[q$code]] <- q
  blank <- function(v) { v <- trimws(as.character(v)); is.na(v) || !nzchar(v) || v == "NA" }
  check_targets <- !is.null(valid_targets) && length(valid_targets)

  links <- list(); generic <- character(0); unresolved <- character(0); unlinked <- list()
  has_link_col <- "CommentLink" %in% names(selection_df)
  for (i in seq_len(nrow(selection_df))) {
    sheet <- selection_df$CommentSheet[i]
    if (blank(sheet)) next
    sheet <- trimws(as.character(sheet))
    qcode <- qual_sheet_code(sheet)
    if (is.null(q_by_code[[qcode]])) { unresolved <- c(unresolved, sheet); next }
    target <- if (has_link_col) selection_df$CommentLink[i] else NA
    open_end <- trimws(as.character(selection_df$QuestionCode[i]))
    if (!blank(target)) {
      target <- trimws(as.character(target))
      links[[target]] <- list(qcode = qcode, sheet = sheet, openEnd = open_end,
                              title = q_by_code[[qcode]]$title)
      if (check_targets && !(target %in% valid_targets)) {
        unlinked[[length(unlinked) + 1L]] <- list(target = target, openEnd = open_end, sheet = sheet)
      }
    } else {
      generic <- c(generic, qcode)
    }
  }
  list(links = links, generic = unique(generic), unresolved = unique(unresolved),
       unlinked_targets = unlinked)
}

#' Build a self-contained v2 comment report from a coded-comment workbook.
#'
#' @param qual_workbook Path to the coded-comment .xlsx.
#' @param output_path Destination .html path.
#' @param config_obj The tabs config object (carries the qual_* dials + branding).
#' @param module Module label for refusal display.
#' @return The `write_html_report_v2` result list (status / output_file / file_size_mb).
#' @examples
#' \dontrun{
#'   build_qual_report_v2("comments.xlsx", "comments_qual_report.html", config_obj)
#' }
#' @export
build_qual_report_v2 <- function(qual_workbook, output_path, config_obj, module = "TABS") {
  qual_path <- qual_resolve_workbook_path(qual_workbook, config_obj)   # project-relative like structure_file
  read_result <- qual_read_workbook(qual_path, module)           # TRS-refuses on bad file
  master <- qual_build_respondent_master(read_result$questions)

  quant <- qual_build_quant_layer(read_result$questions, master, list(
    demographic_cuts = config_obj$qual_demographic_cuts,
    significance_min_base = config_obj$significance_min_base,
    project_name = config_obj$project_name))
  if (is.null(quant$agg)) qual_refuse_no_themes(qual_path, module)

  island <- qual_build_data_qual(read_result$questions, master, list(
    text_mode = config_obj$qual_confidentiality_mode,
    demographic_cuts = config_obj$qual_demographic_cuts,
    noteworthy_default = config_obj$qual_noteworthy_default))

  # The quant run used a minimal unweighted/dual-sig config; re-brand the project
  # from the user's config (logos, colours, the show_* tab flags) and mark it as
  # the comment report. The Qualitative tab gates on project + the DATA_QUAL island.
  quant$agg$project <- build_dl_project(config_obj, tracking_enabled = FALSE)
  quant$agg$project$name <- paste0(quant$agg$project$name, " — Comments")

  write_html_report_v2(serialize_data_layer(quant$agg), config_obj, output_path,
                       micro_json = serialize_microdata(quant$micro),
                       qual_json = serialize_data_qual(island))
}
