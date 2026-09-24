# ==============================================================================
# WHAT IF - CONFIG WORKBOOK
# ==============================================================================
#
# Reads a What if config workbook into a plain list. The workbook has these
# sheets (lib/generate_config_template.R writes a blank one):
#
#   Settings    Setting / Value pairs (WHATIF_KNOWN_SETTINGS)
#   Levers      one row per lever: Key, Label, Kind, Questions, HasQuestion,
#               HasValues, CoverageValues, Target, Expected, Include, Note,
#               HasLabel
#   Context     one row per descriptive variable: Key, Question, Label,
#               Levels, CollapseUnder, CollapseLabel, MissingLabel, Order,
#               Filter, Baseline, Profile, Structural
#   Recodes     Key, From, To: exact value mappings applied to a context
#               variable before small levels are collapsed
#   Sentence    the "Build a ..." sentence, one row per piece: Text, Key, Style
#   Structure   Key1, Level1, Key2, Level2: combinations Build a ... must
#               never offer (structural traits only)
#   Crossings   Key1, Key2: two-way breakdowns published in client-safe mode
#   Bundles     Name, Description, Moves ("Q025=up1; Q026=up1")
#
# Every sheet is read as text; this file coerces types itself, so a level
# named "2025" or a code "01" arrives exactly as typed. Only Settings, Levers
# and Context are required; the others may be absent or empty.
#
# ==============================================================================

#' Settings the What if Config Understands
#'
#' tests/testthat/test_config.R ties this list to the template generator, so a
#' setting added to one and not the other fails the suite.
WHATIF_KNOWN_SETTINGS <- c(
  "project_name", "study_title", "brand_name", "unit_noun", "units_noun",
  "data_file", "structure_file", "output_folder", "output_name",
  "id_variable", "weight_variable", "base_filter_variable", "base_filter_values",
  "outcome_question", "outcome_text", "outcome_bands", "outcome_labels",
  "outcome_scores", "outcome_score_label",
  "scale_min", "scale_max", "scale_centre", "scale_good", "scale_step",
  "dont_know", "min_group", "reliability_floor", "profile_builder",
  "n_boot", "seed", "structure_min_side", "correlation_flag"
)

WHATIF_REQUIRED_SETTINGS <- c("data_file", "id_variable", "outcome_question")


#' Read a What if Config Workbook
#'
#' @param config_file Path to the .xlsx config
#' @return List with settings (named list, typed), levers, context, recodes,
#'   sentence, structure, crossings, bundles (data frames of text), config_file,
#'   project_root. Refuses on a missing file, sheet or required column.
#' @keywords internal
whatif_read_config <- function(config_file) {
  if (!is.character(config_file) || length(config_file) != 1 || !file.exists(config_file)) {
    whatif_refuse("IO_CONFIG_NOT_FOUND", "Config file not found",
      sprintf("The What if config '%s' does not exist.", paste(config_file, collapse = " ")),
      "Without the config there is no outcome, no levers and no data file.",
      "Check the path, or create a config with generate_whatif_config_template().")
  }
  sheets <- readxl::excel_sheets(config_file)
  need_sheet <- function(name) {
    if (!name %in% sheets) {
      whatif_refuse("CFG_SHEET_MISSING", sprintf("Sheet '%s' missing", name),
        sprintf("The config has no '%s' sheet.", name),
        "The What if run cannot be defined without it.",
        "Start from the What if config template, which has every sheet.",
        details = paste("Sheets found:", paste(sheets, collapse = ", ")))
    }
  }
  for (s in c("Settings", "Levers", "Context")) need_sheet(s)

  settings <- whatif_read_settings(config_file)
  table <- function(name, cols, required = FALSE) {
    if (!name %in% sheets) {
      if (required) need_sheet(name)
      return(whatif_empty_table(cols))
    }
    df <- suppressMessages(load_config_table_sheet(config_file, name, required_cols = cols[1:min(2, length(cols))],
                                                   col_types = "text"))
    df <- as.data.frame(df, stringsAsFactors = FALSE)
    missing_cols <- setdiff(cols, names(df))
    for (m in missing_cols) df[[m]] <- rep(NA_character_, nrow(df))
    df <- df[, cols, drop = FALSE]
    df[] <- lapply(df, function(x) {
      x <- trimws(as.character(x))
      x[!is.na(x) & x == ""] <- NA_character_
      x
    })
    keep <- !is.na(df[[1]])
    df[keep, , drop = FALSE]
  }

  cfg <- list(
    settings = settings,
    levers = table("Levers", c("Key", "Label", "Kind", "Questions", "HasQuestion", "HasValues",
                               "CoverageValues", "Target", "Expected", "Include", "Note", "HasLabel"),
                   required = TRUE),
    context = table("Context", c("Key", "Question", "Label", "Levels", "CollapseUnder", "CollapseLabel",
                                 "MissingLabel", "Order", "Filter", "Baseline", "Profile", "Structural"),
                    required = TRUE),
    recodes = table("Recodes", c("Key", "From", "To")),
    sentence = table("Sentence", c("Text", "Key", "Style")),
    structure = table("Structure", c("Key1", "Level1", "Key2", "Level2")),
    crossings = table("Crossings", c("Key1", "Key2")),
    bundles = table("Bundles", c("Name", "Description", "Moves")),
    config_file = normalizePath(config_file, winslash = "/"),
    project_root = dirname(normalizePath(config_file, winslash = "/"))
  )
  # The Sentence sheet's first column is often blank (a piece with no text
  # before a dropdown), so it is re-read keeping rows with either Text or Key.
  if ("Sentence" %in% sheets) {
    s <- suppressMessages(load_config_table_sheet(config_file, "Sentence", required_cols = c("Text", "Key"),
                                                  col_types = "text"))
    s <- as.data.frame(s, stringsAsFactors = FALSE)
    for (m in setdiff(c("Text", "Key", "Style"), names(s))) s[[m]] <- rep(NA_character_, nrow(s))
    s <- s[, c("Text", "Key", "Style"), drop = FALSE]
    s[] <- lapply(s, function(x) as.character(x))
    s$Key <- trimws(s$Key)
    s$Key[!is.na(s$Key) & s$Key == ""] <- NA_character_
    s$Style <- trimws(s$Style)
    s <- s[!(is.na(s$Text) & is.na(s$Key)), , drop = FALSE]
    s$Text[is.na(s$Text)] <- ""
    cfg$sentence <- s
  }
  whatif_check_config_tables(cfg)
  cfg
}


#' @keywords internal
whatif_empty_table <- function(cols) {
  df <- as.data.frame(matrix(character(0), 0, length(cols)), stringsAsFactors = FALSE)
  names(df) <- cols
  df
}


#' Read and Type the Settings Sheet
#' @keywords internal
whatif_read_settings <- function(config_file) {
  df <- suppressMessages(load_config_table_sheet(config_file, "Settings", required_cols = c("Setting", "Value"),
                                                 col_types = "text"))
  if (!all(c("Setting", "Value") %in% names(df))) {
    whatif_refuse("CFG_SETTINGS_COLUMNS", "Settings sheet has no Setting and Value columns",
      "The Settings sheet must have a header row with 'Setting' and 'Value'.",
      "Settings are read by name from those two columns.",
      "Use the template's Settings sheet.")
  }
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  key <- trimws(gsub("[ ​]", " ", as.character(df$Setting)))
  val <- trimws(as.character(df$Value))
  keep <- !is.na(key) & key != "" & !is.na(val) & val != ""
  key <- key[keep]
  val <- val[keep]
  if (anyDuplicated(key)) {
    whatif_refuse("CFG_DUPLICATE_SETTINGS", "Setting given twice",
      sprintf("These settings appear more than once: %s.", paste(unique(key[duplicated(key)]), collapse = ", ")),
      "Two values for one setting leave the run ambiguous.",
      "Delete the extra row.")
  }
  unknown <- setdiff(key, WHATIF_KNOWN_SETTINGS)
  # Section headers from the template carry no value and were dropped above,
  # so anything left over is a setting the module does not read.
  if (length(unknown)) {
    cat("\n┌─── TURAS WARNING (What if) ───────────────────────────────┐\n")
    cat("│ Unrecognised settings, ignored:", paste(unknown, collapse = ", "), "\n")
    cat("│ Check the spelling against the template.\n")
    cat("└───────────────────────────────────────────────────────────┘\n")
  }
  s <- stats::setNames(as.list(val), key)
  miss <- setdiff(WHATIF_REQUIRED_SETTINGS, names(s))
  if (length(miss)) {
    whatif_refuse("CFG_REQUIRED_SETTING", "Required setting missing",
      sprintf("These settings are required and have no value: %s.", paste(miss, collapse = ", ")),
      "The run needs a data file, a respondent ID and an outcome question.",
      "Fill them in on the Settings sheet.")
  }
  num <- function(name, default, min = -Inf, max = Inf, integer = FALSE) {
    v <- s[[name]]
    if (is.null(v)) return(default)
    x <- suppressWarnings(as.numeric(v))
    if (is.na(x) || x < min || x > max || (integer && x != round(x))) {
      whatif_refuse("CFG_SETTING_NOT_NUMBER", sprintf("Setting '%s' is not a valid number", name),
        sprintf("'%s' is '%s'; it must be a %s from %s to %s.", name, v,
                if (integer) "whole number" else "number", min, max),
        "A wrong value here changes the model or the privacy rules silently.",
        sprintf("Set %s to a number in range, or clear it to use the default (%s).", name, format(default)))
    }
    x
  }
  yes <- function(name, default) {
    v <- s[[name]]
    if (is.null(v)) return(default)
    tolower(v) %in% c("y", "yes", "true", "1", "on")
  }
  list_of <- function(name, default) {
    v <- s[[name]]
    if (is.null(v)) return(default)
    trimws(strsplit(v, ";", fixed = TRUE)[[1]])
  }
  out <- list(
    project_name = s$project_name %||% "What if",
    study_title = s$study_title %||% s$project_name %||% "What if",
    brand_name = s$brand_name %||% "the organisation",
    unit_noun = s$unit_noun %||% "respondent",
    units_noun = s$units_noun %||% paste0(s$unit_noun %||% "respondent", "s"),
    data_file = s$data_file,
    structure_file = s$structure_file,
    output_folder = s$output_folder %||% ".",
    output_name = s$output_name %||% "whatif",
    id_variable = s$id_variable,
    weight_variable = s$weight_variable,
    base_filter_variable = s$base_filter_variable,
    base_filter_values = list_of("base_filter_values", NULL),
    outcome_question = s$outcome_question,
    outcome_text = s$outcome_text %||% s$outcome_question,
    outcome_bands = list_of("outcome_bands", c("0-6", "7-8", "9-10")),
    outcome_labels = list_of("outcome_labels", c("Detractor", "Passive", "Promoter")),
    outcome_scores = suppressWarnings(as.numeric(list_of("outcome_scores", c("-100", "0", "100")))),
    outcome_score_label = s$outcome_score_label %||% "NPS",
    scale_min = num("scale_min", 1),
    scale_max = num("scale_max", 5),
    scale_centre = num("scale_centre", 3),
    scale_good = num("scale_good", 4),
    scale_step = s$scale_step %||% "point",
    dont_know = tolower(s$dont_know %||% "median"),
    min_group = num("min_group", 5, 2, 1000, integer = TRUE),
    reliability_floor = num("reliability_floor", 30, 1, 100000, integer = TRUE),
    profile_builder = yes("profile_builder", TRUE),
    n_boot = num("n_boot", 100, 0, 2000, integer = TRUE),
    seed = num("seed", 20260923, integer = TRUE),
    structure_min_side = num("structure_min_side", 20, 1, 100000, integer = TRUE),
    correlation_flag = num("correlation_flag", 0.7, 0, 1),
    raw = s
  )
  if (!out$dont_know %in% c("median", "centre")) {
    whatif_refuse("CFG_DONT_KNOW", "Unknown don't-know rule",
      sprintf("dont_know is '%s'.", out$dont_know),
      "Don't-know answers must be set to a value before the model sees them, and the rule is reported.",
      "Use 'median' (the question's median rating) or 'centre' (the scale's middle).")
  }
  if (length(out$outcome_bands) != length(out$outcome_labels) ||
      length(out$outcome_bands) != length(out$outcome_scores) || anyNA(out$outcome_scores) ||
      length(out$outcome_bands) < 2) {
    whatif_refuse("CFG_OUTCOME_BANDS", "Outcome bands, labels and scores do not line up",
      sprintf("outcome_bands has %d entries, outcome_labels %d, outcome_scores %d (all numeric).",
              length(out$outcome_bands), length(out$outcome_labels), length(out$outcome_scores)),
      "Each band needs a label and a score for the headline number.",
      "Give the same number of entries in each, separated by semicolons, lowest band first.")
  }
  out
}


#' Check the Config Tables Against Each Other
#' @keywords internal
whatif_check_config_tables <- function(cfg) {
  lv <- cfg$levers
  if (nrow(lv) == 0) {
    whatif_refuse("CFG_NO_LEVERS", "Levers sheet is empty",
      "The Levers sheet has no rows.",
      "The What if model needs at least one lever.",
      "Add a row per lever: Key, Label, Kind and Questions.")
  }
  bad_kind <- lv$Key[!tolower(lv$Kind) %in% WHATIF_LEVER_KINDS]
  if (length(bad_kind)) {
    whatif_refuse("CFG_LEVER_KIND", "Lever kind not recognised",
      sprintf("Levers with no valid Kind: %s.", paste(bad_kind, collapse = ", ")),
      "The kind decides how the lever enters the model.",
      "Set Kind to rating, nested or coverage.")
  }
  no_q <- lv$Key[is.na(lv$Questions)]
  if (length(no_q)) {
    whatif_refuse("CFG_LEVER_NO_QUESTION", "Lever has no question",
      sprintf("Levers with no Questions: %s.", paste(no_q, collapse = ", ")),
      "The lever's values come from its questions.",
      "List the question code(s), separated by semicolons.")
  }
  inc <- toupper(substr(ifelse(is.na(lv$Include), "Y", lv$Include), 1, 1))
  if (any(!inc %in% c("Y", "N", "S"))) {
    whatif_refuse("CFG_LEVER_INCLUDE", "Include must be Y, N or Symptom",
      sprintf("Levers with another Include value: %s.", paste(lv$Key[!inc %in% c("Y", "N", "S")], collapse = ", ")),
      "Include decides whether a row is a lever, left out, or reported as a symptom.",
      "Use Y, N or Symptom.")
  }
  cx <- cfg$context
  if (nrow(cx) == 0) {
    whatif_refuse("CFG_NO_CONTEXT", "Context sheet is empty",
      "The Context sheet has no rows.",
      "Groups, filters and the calibration check are all built on context variables.",
      "Add at least one descriptive variable such as campus or region.")
  }
  if (anyDuplicated(cx$Key) || anyDuplicated(lv$Key)) {
    whatif_refuse("CFG_DUPLICATE_KEYS", "Repeated key",
      "Keys on the Levers sheet and on the Context sheet must each be unique.",
      "Rows are found by key; a repeated key hides one of them.",
      "Rename the repeated key.",
      details = paste("Repeated:", paste(c(cx$Key[duplicated(cx$Key)], lv$Key[duplicated(lv$Key)]), collapse = ", ")))
  }
  no_cq <- cx$Key[is.na(cx$Question)]
  if (length(no_cq)) {
    whatif_refuse("CFG_CONTEXT_NO_QUESTION", "Context variable has no question",
      sprintf("Context rows with no Question: %s.", paste(no_cq, collapse = ", ")),
      "The variable's values come from that question.",
      "Give the question code.")
  }
  known <- cx$Key
  refs <- c(cfg$recodes$Key, cfg$sentence$Key[!is.na(cfg$sentence$Key)],
            cfg$structure$Key1, cfg$structure$Key2, cfg$crossings$Key1, cfg$crossings$Key2)
  bad <- setdiff(unique(refs), known)
  if (length(bad)) {
    whatif_refuse("CFG_UNKNOWN_CONTEXT_KEY", "A sheet names an unknown context key",
      sprintf("Keys used on Recodes, Sentence, Structure or Crossings but not on Context: %s.",
              paste(bad, collapse = ", ")),
      "Rows that point at a missing variable would be ignored without notice.",
      "Add the variable to Context or correct the key.")
  }
  invisible(TRUE)
}


#' Flag Column as TRUE/FALSE
#' @keywords internal
whatif_flag <- function(x) {
  !is.na(x) & toupper(substr(x, 1, 1)) %in% c("Y", "T", "1")
}
