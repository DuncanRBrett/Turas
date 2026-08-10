# vas_turas_build.R
# ------------------------------------------------------------------------------
# Assemble the combined Turas dataset: the kept survey content (from the
# column plan) joined with the derived variables (from the engine), one row
# per respondent, and the generated Survey_Structure + Crosstab_Config beside
# it.
#
# The register is the gate: Exclude rows are dropped, and any row still on
# Review REFUSES the build (allow_review = TRUE overrides that for smoke
# tests only, loudly).
# ------------------------------------------------------------------------------

VAS_TURAS_DATA_FILE <- "VAS_Turas_Data.xlsx"
VAS_TURAS_STRUCTURE_FILE <- "VAS_Survey_Structure.xlsx"
VAS_TURAS_CONFIG_FILE <- "VAS_Crosstab_Config.xlsx"

#' Normalise a header fragment for matching (NBSP, stray spacing)
#'
#' @param text A character vector.
#'
#' @return The normalised vector.
normalise_title <- function(text) {
  return(trimws(gsub("\\s+", " ", gsub(" ", " ", text))))
}

#' Refuse when the register still has undecided rows
#'
#' @param register The register data frame.
#' @param response_ids The Response IDs actually in the export.
#' @param allow_review TRUE only for smoke tests.
#'
#' @return Invisibly TRUE.
#'
#' @throws Stops with class "vas_register_undecided".
verify_register_decided <- function(register, response_ids, allow_review = FALSE) {
  # A response the register has never seen would otherwise sail through: it has
  # no Disposition to be "Review", so nothing refuses it and nothing drops it.
  # That happens whenever this runs against an export newer than the register.
  unknown <- setdiff(as.character(response_ids), register[[VAS_REGISTER_KEY]])
  if (length(unknown)) {
    stop(structure(class = c("vas_register_stale", "error", "condition"), list(
      message = sprintf(paste0(
        "%d response(s) in the export are not in the register at all: %s\n",
        "The register is older than the export, so these have been through no\n",
        "gate. Run the derived numbers first - that refreshes the register - \n",
        "then run this again."),
        length(unknown), paste(utils::head(unknown, 15), collapse = ", ")), call = NULL)))
  }

  relevant <- register[register[[VAS_REGISTER_KEY]] %in% as.character(response_ids), ]
  review <- relevant[[VAS_REGISTER_KEY]][!is.na(relevant$Disposition) &
                                           relevant$Disposition == "Review"]
  if (length(review) && !allow_review) {
    stop(structure(class = c("vas_register_undecided", "error", "condition"), list(
      message = sprintf(paste0(
        "%d response(s) are still on Review in the register: %s\n",
        "The Turas dataset ships only decided records. Open the register, set\n",
        "each to Include or Exclude with a reason, and run this again."),
        length(review), paste(utils::head(review, 15), collapse = ", ")), call = NULL)))
  }
  if (length(review) && allow_review) {
    cat(sprintf("\n*** SMOKE TEST BUILD: %d Review row(s) included. NOT a deliverable. ***\n\n",
                length(review)))
  }
  return(invisible(TRUE))
}

#' Assemble the member columns of one Multi_Mention question
#'
#' Members are ordered by the survey's option order. An option with no export
#' column (never offered in this build) becomes an all-blank column, so the
#' structure and the data always agree on the member count.
#'
#' @param source The filtered vas_source.
#' @param alias The question alias.
#' @param alias_options The snapshot options for this alias.
#'
#' @return A named list of character vectors.
assemble_multi_columns <- function(source, alias, alias_options) {
  columns <- list()
  headers <- names(source$data)
  for (i in seq_len(nrow(alias_options))) {
    wanted <- normalise_title(sprintf("%s:%s", alias_options$title[i], alias))
    position <- match(wanted, normalise_title(headers))
    columns[[sprintf("%s_%d", alias, i)]] <- if (is.na(position)) {
      rep(NA_character_, length(source$response_id))
    } else {
      as.character(source$data[[position]])
    }
  }
  return(columns)
}

#' Coalesce the per-province town questions into one Town column
#'
#' @param source The filtered vas_source.
#' @param town_headers The scalar town headers, from the plan.
#'
#' @return A character vector, one element per respondent.
assemble_town_column <- function(source, town_headers) {
  town <- rep(NA_character_, length(source$response_id))
  for (header in town_headers) {
    values <- as.character(source$data[[header]])
    town <- ifelse(is.na(town) & !is.na(values) & nzchar(trimws(values)),
                   values, town)
  }
  return(town)
}

#' Assemble the full Turas data frame
#'
#' @param source The filtered vas_source.
#' @param plan The column plan.
#' @param options The snapshot options data frame.
#' @param wide The derived wide table.
#'
#' @return A data frame, one row per respondent.
assemble_turas_data <- function(source, plan, options, wide) {
  data <- list(ResponseID = as.character(source$response_id),
               ResponseStatus = as.character(source$status))
  added_multi <- character(0)

  for (i in seq_len(nrow(plan))) {
    action <- plan$action[i]
    if (action == "keep" && !identical(plan$export_header[i], "Status")) {
      data[[plan$question_code[i]]] <- as.character(source$data[[plan$export_header[i]]])
    } else if (action == "multi" && !plan$alias[i] %in% added_multi) {
      alias <- plan$alias[i]
      added_multi <- c(added_multi, alias)
      data <- c(data, assemble_multi_columns(
        source, alias, options[options$alias == alias, , drop = FALSE]))
    }
  }
  town_headers <- plan$export_header[plan$action == "merge_town"]
  if (length(town_headers)) {
    data$Town <- assemble_town_column(source, town_headers)
  }

  derived <- wide[match(as.character(source$response_id), as.character(wide$ResponseID)),
                  setdiff(names(wide), c("ResponseID", "ResponseStatus")), drop = FALSE]
  for (column in names(derived)) {
    values <- derived[[column]]
    data[[column]] <- if (is.logical(values)) {
      ifelse(is.na(values), NA_character_, ifelse(values, "Yes", "No"))
    } else {
      values
    }
  }
  return(as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE))
}

#' Report data values that do not match their question's option list
#'
#' Non-fatal: an NBSP or a relabelled option shows up here rather than as a
#' silently empty crosstab row in Turas.
#'
#' @param data The assembled data frame.
#' @param structure The list from \code{content_structure_rows()} merged with
#'   the derived rows.
#'
#' @return The number of mismatching values, invisibly.
report_option_mismatches <- function(data, structure) {
  singles <- structure$questions$QuestionCode[
    structure$questions$Variable_Type == "Single_Response"]
  mismatches <- 0L
  for (code in intersect(singles, names(data))) {
    allowed <- structure$options$OptionText[structure$options$QuestionCode == code]
    values <- unique(stats::na.omit(data[[code]]))
    bad <- setdiff(values, allowed)
    if (length(bad)) {
      mismatches <- mismatches + length(bad)
      cat(sprintf("  option mismatch  %-24s %s\n", code,
                  paste(utils::head(bad, 3), collapse = " | ")))
    }
  }
  if (!mismatches) {
    cat("  every single-response data value matches its option list\n")
  }
  return(invisible(mismatches))
}

#' Check that an existing structure workbook still fits the data
#'
#' Once generated, the Survey_Structure and Crosstab_Config belong to Duncan
#' (bands, selections, banners, comments), so a rebuild must never overwrite
#' them. This guard catches the one thing that would silently break instead:
#' the dataset's columns drifting away from the kept structure.
#'
#' @param structure_path The existing Survey_Structure workbook.
#' @param data The freshly assembled data frame.
#'
#' @return Invisibly TRUE when aligned.
#'
#' @throws Stops with class "vas_structure_stale" naming the drift.
verify_structure_alignment <- function(structure_path, data) {
  questions <- openxlsx::read.xlsx(structure_path, sheet = "Questions")
  declared <- unlist(lapply(seq_len(nrow(questions)), function(i) {
    if (identical(questions$Variable_Type[i], "Multi_Mention")) {
      sprintf("%s_%d", questions$QuestionCode[i], seq_len(questions$Columns[i]))
    } else {
      questions$QuestionCode[i]
    }
  }))
  missing <- setdiff(declared, names(data))
  unknown <- setdiff(names(data), c(declared, "ResponseID"))
  if (length(missing) || length(unknown)) {
    stop(structure(class = c("vas_structure_stale", "error", "condition"), list(
      message = sprintf(paste0(
        "The kept Survey_Structure no longer matches the dataset.\n",
        "  declared but absent from the data (%d): %s\n",
        "  in the data but undeclared (%d): %s\n\n",
        "If the column plan changed deliberately, delete the Survey_Structure\n",
        "and Crosstab_Config workbooks and rebuild to regenerate them - then\n",
        "re-apply any hand curation."),
        length(missing), paste(utils::head(missing, 8), collapse = ", "),
        length(unknown), paste(utils::head(unknown, 8), collapse = ", ")),
      call = NULL)))
  }
  return(invisible(TRUE))
}

#' Build the Turas dataset and its configuration, end to end
#'
#' @param export_path The Alchemer export.
#' @param register_path The report register (must already exist).
#' @param output_dir Where the three workbooks land.
#' @param code_dir The repo, for the plan, map and snapshot.
#' @param allow_review Smoke tests only.
#'
#' @return A list of the paths written and the row/column counts.
build_turas_dataset <- function(export_path, register_path, output_dir,
                                code_dir = ".", allow_review = FALSE,
                                snapshot_dir = file.path(code_dir, "backups")) {
  source_data <- read_vas_export(export_path)
  register <- read_report_register(register_path)
  if (is.null(register)) {
    stop(structure(class = c("vas_register_missing", "error", "condition"), list(
      message = "No report register was found. Run the derived numbers first - that creates and refreshes the register.",
      call = NULL)))
  }
  verify_register_decided(register, source_data$response_id, allow_review)
  filtered <- filter_source_by_register(source_data, register)

  # The survey-structure snapshots are project DATA, not engine code, so they
  # do not travel with this module. Without a clear message here an empty glob
  # reaches read.csv as character(0) and R only says "invalid 'description'
  # argument", which says nothing about what is actually missing.
  index_path <- tail(sort(Sys.glob(file.path(snapshot_dir,
                                             "survey_8929162_*_index.csv"))), 1)
  if (!length(index_path) || !nzchar(index_path) || !file.exists(index_path)) {
    stop(structure(class = c("vas_snapshot_missing", "error", "condition"), list(
      message = sprintf(paste0(
        "No survey-structure snapshot (survey_8929162_*_index.csv) was found in:\n  %s\n",
        "The Turas dataset needs one to map question ids to aliases.\n",
        "Point snapshot_dir at the folder holding the survey snapshots."),
        snapshot_dir),
      call = NULL)))
  }
  json_path <- sub("_index\\.csv$", ".json", index_path)
  index <- utils::read.csv(index_path, stringsAsFactors = FALSE)
  options <- read_snapshot_options(json_path)

  category_map <- read_category_map(code_dir)
  plan <- read_or_create_column_plan(file.path(code_dir, VAS_TURAS_PLAN_FILE),
                                     names(source_data$data), category_map, index)
  verify_plan_covers_export(names(source_data$data), plan)

  derived <- derive_vas(filtered$source, category_map, VAS_CONFIG)
  dictionary <- build_data_dictionary(category_map, VAS_CONFIG)
  data <- assemble_turas_data(filtered$source, plan, options, derived$wide)

  # Town's options are every town the SURVEY offers, not merely the ones seen so
  # far. Taking them from the data froze the list at whatever the first batch
  # happened to contain, so a province reached later in fieldwork would answer
  # with a town the structure never declared - and a respondent answering an
  # undeclared option is a respondent quietly dropped from that table. The
  # observed values are unioned in as well, so a hand-added town still counts.
  town_declared <- options$value[grepl(VAS_PLAN_TOWN_PATTERN, options$alias)]
  town_values <- sort(unique(c(trimws(town_declared),
                               trimws(stats::na.omit(data$Town)))))
  town_values <- town_values[nzchar(town_values)]

  content <- content_structure_rows(plan, index, options, town_values)
  derived_rows <- derived_structure_rows(dictionary, VAS_CONFIG)
  structure <- list(questions = rbind(content$questions, derived_rows$questions),
                    options = rbind(content$options, derived_rows$options))

  # An asked question carries its Alchemer title and a derived column carries
  # its dictionary description. Neither was written for a report reader, so
  # vas_report_labels.csv gets the last word on the text.
  structure$questions <- apply_report_labels(structure$questions, code_dir)

  cat(sprintf("\nTuras dataset: %d respondents x %d columns (%d excluded by the register)\n",
              nrow(data), ncol(data), length(filtered$excluded)))
  report_option_mismatches(data, structure)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  data_path <- file.path(output_dir, VAS_TURAS_DATA_FILE)
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data", data, headerStyle = excel_header_style())
  openxlsx::saveWorkbook(wb, data_path, overwrite = TRUE)

  # the data regenerates every build; the structure and config are generated
  # ONCE and then belong to Duncan - report curation must survive rebuilds
  structure_path <- file.path(output_dir, VAS_TURAS_STRUCTURE_FILE)
  config_path <- file.path(output_dir, VAS_TURAS_CONFIG_FILE)
  if (file.exists(structure_path)) {
    verify_structure_alignment(structure_path, data)
    cat(sprintf("  %s kept (hand-curated; alignment with the data verified)\n",
                VAS_TURAS_STRUCTURE_FILE))
  } else {
    write_turas_structure(structure$questions, structure$options,
                          VAS_TURAS_DATA_FILE, structure_path)
  }
  if (file.exists(config_path)) {
    cat(sprintf("  %s kept (hand-curated)\n", VAS_TURAS_CONFIG_FILE))
  } else {
    write_turas_config(structure$questions, VAS_TURAS_STRUCTURE_FILE, config_path)
  }
  return(list(data = data_path, structure = structure_path, config = config_path,
              respondents = nrow(data), columns = ncol(data),
              excluded = filtered$excluded))
}
