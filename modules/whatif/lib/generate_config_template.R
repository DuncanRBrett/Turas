# ==============================================================================
# WHAT IF - CONFIG TEMPLATE
# ==============================================================================
#
# generate_whatif_config_template(path) writes a blank What if config in the
# house template style (modules/shared/template_styles.R). Pass settings and
# sheet contents to write a filled config instead, for example from a study
# script:
#
#   generate_whatif_config_template("SACAP_2025_WhatIf_Config.xlsx",
#     settings = list(data_file = "...", id_variable = "ID", ...),
#     levers = data.frame(Key = ..., Label = ..., Kind = ..., Questions = ...))
#
# Saved with turas_saveWorkbook(), never openxlsx::saveWorkbook().
# ==============================================================================

#' Settings Definition for the Template
#' @keywords internal
whatif_settings_def <- function() {
  f <- function(name, default, required, description, valid = "", dropdown = NULL) {
    list(name = name, default = default, required = required, description = description,
         valid_values_text = valid, dropdown = dropdown)
  }
  yn <- c("Y", "N")
  list(
    list(section_name = "STUDY", fields = list(
      f("project_name", "", FALSE, "Project name, for the output files.", "Text"),
      f("study_title", "", FALSE, "Title shown at the top of the What if tab.", "Text"),
      f("brand_name", "", FALSE, "The client's name as respondents know it (\"Rate SACAP as one student\").", "Text"),
      f("unit_noun", "respondent", FALSE, "One respondent, in the tab's words: student, outlet, customer.", "Text"),
      f("units_noun", "respondents", FALSE, "The plural.", "Text"))),
    list(section_name = "FILES", fields = list(
      f("data_file", "", TRUE, "The survey data. Use the same file as the tabs report.", "Path; relative paths are read from this config's folder"),
      f("structure_file", "", FALSE, "The project's Survey_Structure. Labelled ratings become scale points from its Options sheet.", "Path"),
      f("output_folder", ".", FALSE, "Where the workbook and the contribution file are written.", "Path"),
      f("output_name", "whatif", FALSE, "Base name of the outputs: {output_name}.xlsx and {output_name}_whatif_island.json.", "Text"))),
    list(section_name = "RESPONDENTS", fields = list(
      f("id_variable", "", TRUE, "One unique ID per respondent. The open report lines up What if rows with its respondents by this ID.", "Column name"),
      f("weight_variable", "", FALSE, "Weight column. Leave blank for an unweighted run. Must match how the study's report is weighted.", "Column name or blank"),
      f("base_filter_variable", "", FALSE, "Keep only respondents whose answer to this question is in base_filter_values (for example completes only).", "Column name or blank"),
      f("base_filter_values", "", FALSE, "Answers to keep, separated by semicolons.", "e.g. Complete; Converted"))),
    list(section_name = "OUTCOME", fields = list(
      f("outcome_question", "", TRUE, "The outcome question (for NPS, the 0 to 10 recommend question).", "Column name"),
      f("outcome_text", "", FALSE, "The outcome as the tab names it.", "e.g. Would you recommend SACAP? (Q017)"),
      f("outcome_bands", "0-6; 7-8; 9-10", FALSE, "Bands of the outcome's value, lowest first. Labelled answers use their position in the Options sheet.", "Ranges separated by semicolons"),
      f("outcome_labels", "Detractor; Passive; Promoter", FALSE, "One label per band.", "Text; semicolons"),
      f("outcome_scores", "-100; 0; 100", FALSE, "What each band adds to the headline number. NPS: -100; 0; 100. Top-two-box share: 0; 0; 100.", "Numbers; semicolons"),
      f("outcome_score_label", "NPS", FALSE, "Name of the headline number.", "Text"))),
    list(section_name = "RATING SCALE", fields = list(
      f("scale_min", "1", FALSE, "Lowest point of the rating levers' scale.", "Number"),
      f("scale_max", "5", FALSE, "Highest point.", "Number"),
      f("scale_centre", "3", FALSE, "Middle point. Ratings enter the model as value minus centre.", "Number"),
      f("scale_good", "4", FALSE, "The fix target: 'If fixed' lifts everyone below this point up to it. A lever's Target overrides it.", "Number"),
      f("scale_step", "point", FALSE, "What one step is called in the tab.", "point or notch", c("point", "notch")),
      f("dont_know", "median", FALSE, "What a don't-know answer to a rating becomes. The count is reported.", "median or centre", c("median", "centre")))),
    list(section_name = "PRIVACY AND RELIABILITY", fields = list(
      f("min_group", "5", FALSE, "Smallest group a client-safe file publishes, counted on respondents.", "Whole number, 2 or more"),
      f("reliability_floor", "30", FALSE, "Groups smaller than this are flagged as thin.", "Whole number"),
      f("profile_builder", "Y", FALSE, "Show 'Build a ...'. Switch off for staff surveys and any study where the client manages the respondents.", "Y or N", yn))),
    list(section_name = "MODEL", fields = list(
      f("n_boot", "100", FALSE, "Bootstrap refits for the ranges.", "Whole number"),
      f("seed", "20260923", FALSE, "Random seed, so a rerun gives the same ranges.", "Whole number"),
      f("structure_min_side", "20", FALSE, "Preflight proposes a Structure rule for a structural combination nobody has when one side has at least this many respondents.", "Whole number"),
      f("correlation_flag", "0.7", FALSE, "Preflight flags two levers that correlate above this.", "0 to 1")))
  )
}


#' Columns of Each Table Sheet
#' @keywords internal
whatif_table_defs <- function() {
  col <- function(name, width, required, description, dropdown = NULL) {
    list(name = name, width = width, required = required, description = description, dropdown = dropdown)
  }
  list(
    Levers = list(
      col("Key", 14, TRUE, "Short unique key, usually the question code."),
      col("Label", 30, TRUE, "The area as the tab names it."),
      col("Kind", 11, TRUE, "rating: a score everyone gave. nested: a score only some could give (has the service). coverage: has the service or not.", c("rating", "nested", "coverage")),
      col("Questions", 18, TRUE, "Question code(s). Several codes are averaged into one lever; separate with semicolons."),
      col("HasQuestion", 14, FALSE, "Nested only: the question that says who has the service. Blank: those who gave the rating."),
      col("HasValues", 18, FALSE, "Nested only: answers to HasQuestion that mean 'has it'. Blank: any answer."),
      col("CoverageValues", 20, FALSE, "Coverage and symptoms: answers that mean 'has it' (e.g. Yes)."),
      col("Target", 9, FALSE, "Fix target for this lever. Blank: scale_good."),
      col("Expected", 9, FALSE, "1 if a higher value should raise the outcome, -1 if lower. Blank: 1."),
      col("Include", 10, FALSE, "Y: a lever. N: left out. Symptom: shown only as 'looks like a lever, isn't one'.", c("Y", "N", "Symptom")),
      col("Note", 40, FALSE, "Shown under the lever's name, and for a symptom as the reason."),
      col("HasLabel", 24, FALSE, "Nested only: how 'has the service' reads in Rate as one.")),
    Context = list(
      col("Key", 12, TRUE, "Short unique key."),
      col("Question", 12, TRUE, "Question code."),
      col("Label", 22, TRUE, "The variable as the tab names it."),
      col("Levels", 10, FALSE, "as is; display to use the Options sheet's DisplayText; box to use its BoxCategory.", c("as is", "display", "box")),
      col("CollapseUnder", 12, FALSE, "Levels with fewer respondents than this merge into CollapseLabel."),
      col("CollapseLabel", 16, FALSE, "Name of the merged level (default Other)."),
      col("MissingLabel", 16, FALSE, "Level for respondents with no answer (default Not said)."),
      col("Order", 24, FALSE, "Order of levels in Build a ...: numeric, or the levels separated by semicolons. Blank: most common first."),
      col("Filter", 8, FALSE, "Y: a group filter in client-safe files.", c("Y", "N")),
      col("Baseline", 9, FALSE, "Y: enters the lever model as a shrunk baseline (fixes group calibration).", c("Y", "N")),
      col("Profile", 8, FALSE, "Y: a trait in Build a ... (if the Sentence sheet is empty).", c("Y", "N")),
      col("Structural", 10, FALSE, "Y: set by how the programme or business is organised (course, year, campus). Only these may have Structure rules.", c("Y", "N"))),
    Recodes = list(
      col("Key", 12, TRUE, "Context key."),
      col("From", 34, TRUE, "Answer as it is in the data. Leave blank to recode missing answers."),
      col("To", 24, TRUE, "Level it becomes.")),
    Sentence = list(
      col("Text", 30, FALSE, "Words before the dropdown (include spaces)."),
      col("Key", 12, FALSE, "Context key of the dropdown. Blank for a final piece of text."),
      col("Style", 10, FALSE, "lower: show the level in lower case.", c("lower", ""))),
    Structure = list(
      col("Key1", 12, TRUE, "Structural context key."),
      col("Level1", 30, TRUE, "Its level."),
      col("Key2", 12, TRUE, "Another structural context key."),
      col("Level2", 30, TRUE, "The level that cannot go with Level1. Build a ... never offers this combination.")),
    Crossings = list(
      col("Key1", 12, TRUE, "Filter key."),
      col("Key2", 12, TRUE, "Another filter key. Client-safe files publish this two-way breakdown, with small cells protected.")),
    Bundles = list(
      col("Name", 20, TRUE, "Bundle name."),
      col("Description", 50, FALSE, "What it does, in words."),
      col("Moves", 40, TRUE, "Lever key = move, separated by semicolons. Moves: slip2, slip1, up1, up2, floor, withdraw, extend."))
  )
}


#' Write a What if Config Workbook
#'
#' @param output_path Where to write the .xlsx
#' @param settings Optional named list of setting values (blank template if empty)
#' @param levers,context,recodes,sentence,structure,crossings,bundles Optional
#'   data frames with the sheets' columns
#' @param title Title row text
#' @return list(status = "PASS", path) or a TRS-style refusal list
#' @export
generate_whatif_config_template <- function(output_path, settings = list(), levers = NULL, context = NULL,
                                            recodes = NULL, sentence = NULL, structure = NULL,
                                            crossings = NULL, bundles = NULL,
                                            title = "What if simulator: configuration") {
  if (!dir.exists(dirname(output_path))) {
    cat("\n[What if] Output folder does not exist:", dirname(output_path), "\n")
    return(list(status = "REFUSED", code = "IO_OUTPUT_DIR_MISSING",
                message = sprintf("Folder '%s' does not exist.", dirname(output_path)),
                how_to_fix = "Create the folder or choose another path."))
  }
  if (!exists("write_settings_sheet", mode = "function")) {
    root <- normalizePath(file.path(.whatif_module_dir, "..", ".."), mustWork = FALSE)
    source(file.path(root, "modules", "shared", "template_styles.R"))
  }
  def <- whatif_settings_def()
  unknown <- setdiff(names(settings), WHATIF_KNOWN_SETTINGS)
  if (length(unknown)) {
    cat("\n[What if] Settings not known to the module:", paste(unknown, collapse = ", "), "\n")
    return(list(status = "REFUSED", code = "CFG_UNKNOWN_SETTING",
                message = paste("Unknown settings:", paste(unknown, collapse = ", ")),
                how_to_fix = "Use the names in WHATIF_KNOWN_SETTINGS."))
  }
  for (si in seq_along(def)) for (fi in seq_along(def[[si]]$fields)) {
    nm <- def[[si]]$fields[[fi]]$name
    if (!is.null(settings[[nm]])) def[[si]]$fields[[fi]]$default <- as.character(settings[[nm]])
  }
  wb <- openxlsx::createWorkbook()
  write_settings_sheet(wb, "Settings", def, title,
                       "One outcome, the levers that might move it, and who the respondents are.")
  tables <- whatif_table_defs()
  content <- list(Levers = levers, Context = context, Recodes = recodes, Sentence = sentence,
                  Structure = structure, Crossings = crossings, Bundles = bundles)
  for (nm in names(tables)) {
    rows <- NULL
    df <- content[[nm]]
    if (!is.null(df) && nrow(df)) {
      cols <- vapply(tables[[nm]], `[[`, "", "name")
      for (m in setdiff(cols, names(df))) df[[m]] <- NA
      rows <- lapply(seq_len(nrow(df)), function(i) {
        r <- lapply(cols, function(cc) { v <- df[[cc]][i]; if (is.na(v)) "" else as.character(v) })
        stats::setNames(r, cols)
      })
    }
    write_table_sheet(wb, nm, tables[[nm]], paste(nm, "sheet"), whatif_sheet_subtitle(nm),
                      example_rows = rows, num_blank_rows = 30)
    # A filled config's rows are the study's settings, not examples: style
    # them as input rows so they do not read as placeholders.
    if (length(rows)) {
      openxlsx::addStyle(wb, nm, make_input_style(), rows = 4 + seq_along(rows),
                         cols = seq_along(tables[[nm]]), gridExpand = TRUE)
    }
  }
  turas_saveWorkbook(wb, output_path, overwrite = TRUE)
  list(status = "PASS", path = output_path)
}


#' @keywords internal
whatif_sheet_subtitle <- function(nm) {
  c(Levers = "One row per area the client can act on. Include = Symptom for things that move with the outcome but are not levers.",
    Context = "Who the respondents are: filters, baselines and the Build a ... traits.",
    Recodes = "Exact answer-to-level mappings, applied before small levels are collapsed.",
    Sentence = "The Build a ... sentence, one piece per row, in order.",
    Structure = "Combinations Build a ... must never offer. Structural traits only. The preflight proposes candidates.",
    Crossings = "Two-way breakdowns published in client-safe files.",
    Bundles = "Named combinations of moves, worked out exactly.")[[nm]]
}
