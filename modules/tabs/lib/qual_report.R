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
  read_result <- qual_read_workbook(qual_workbook, module)        # TRS-refuses on bad file
  master <- qual_build_respondent_master(read_result$questions)

  quant <- qual_build_quant_layer(read_result$questions, master, list(
    demographic_cuts = config_obj$qual_demographic_cuts,
    significance_min_base = config_obj$significance_min_base,
    project_name = config_obj$project_name))
  if (is.null(quant$agg)) qual_refuse_no_themes(qual_workbook, module)

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
