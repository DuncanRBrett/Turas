# vas_pipeline.R
# ------------------------------------------------------------------------------
# Shared setup for every entry point that runs the VAS derived-variable
# calculation.
#
# There are two runners - run_vas_derive.R here in the repo, and
# run_vas_fieldwork.R in the OneDrive fieldwork folder. They write their output
# to different places, but they must load the same code and run the same
# sequence, so both of those live here rather than being written out twice.
# ------------------------------------------------------------------------------

# Sourced in this order. alchemer_survey_tools.R first, because the API reader
# depends on it.
VAS_LIBRARY_FILES <- c(
  "alchemer_survey_tools.R", "vas_derived_config.R", "vas_amount_parser.R",
  "vas_frequency.R", "vas_read_source.R", "vas_derive_category.R",
  "vas_derive.R", "vas_sense_check.R", "vas_data_dictionary.R",
  "vas_data_dictionary_headline.R", "vas_write_excel.R",
  # after vas_write_excel.R - the register borrows its header style
  "vas_register.R"
)

VAS_CATEGORY_MAP_FILE <- "vas_category_map.csv"

# Reporting labels: the question text a reader should see, where the survey's
# own wording or the dictionary's description is not it. Optional — a study
# without the file simply has no overrides.
VAS_REPORT_LABELS_FILE <- "vas_report_labels.csv"

#' Load the calculation library from a code directory
#'
#' @param code_dir The directory holding the vas_*.R files.
#'
#' @return The code directory, invisibly.
#'
#' @throws Stops with class "vas_code_missing" naming every file it could not
#'   find, rather than failing on the first one.
load_vas_library <- function(code_dir = ".") {
  code_dir <- path.expand(code_dir)
  paths <- file.path(code_dir, c(VAS_LIBRARY_FILES, VAS_CATEGORY_MAP_FILE))
  absent <- paths[!file.exists(paths)]
  if (length(absent)) {
    stop(structure(class = c("vas_code_missing", "error", "condition"), list(
      message = sprintf(
        "The VAS calculation code was not found in '%s'.\nMissing:\n  %s\nCheck the code directory setting at the top of the script that called this.",
        code_dir, paste(basename(absent), collapse = "\n  ")),
      call = NULL)))
  }
  for (file in VAS_LIBRARY_FILES) {
    source(file.path(code_dir, file))
  }
  return(invisible(code_dir))
}

#' Read the category map from a code directory
#'
#' @param code_dir The directory holding vas_category_map.csv.
#'
#' @return The category map data frame, empty cells as NA.
read_category_map <- function(code_dir = ".") {
  return(utils::read.csv(file.path(path.expand(code_dir), VAS_CATEGORY_MAP_FILE),
                         stringsAsFactors = FALSE, na.strings = ""))
}

#' Derive, sense-check and document, in one call
#'
#' @param source_data A vas_source object.
#' @param category_map The category map data frame.
#' @param config The VAS_CONFIG list.
#'
#' @return A list with \code{result} (from derive_vas), \code{dictionary} and
#'   \code{failures} (empty when every consistency check passed).
derive_and_report <- function(source_data, category_map, config) {
  result <- derive_vas(source_data, category_map, config)
  failures <- run_sense_check(source_data, result, category_map, config)
  return(list(result = result,
              dictionary = build_data_dictionary(category_map, config),
              failures = failures))
}

#' Locate the newest Alchemer export in a folder
#'
#' Matches on a NAME PATTERN rather than taking the newest workbook in the
#' folder. A fieldwork folder holds checklists, sample frames and monitoring
#' sheets as well as exports, and picking the most recently touched one of
#' those would quietly derive numbers from the wrong file.
#'
#' Excel lock files and anything this pipeline wrote itself are ignored, so the
#' folder cannot feed on its own output.
#'
#' @param folder The folder to search.
#' @param pattern A glob for the export's file name.
#' @param output_prefix The basename prefix this pipeline writes, to exclude.
#'
#' @return The path to the most recently modified match.
#'
#' @throws Stops with class "vas_no_export", listing the workbooks it did see.
find_latest_export <- function(folder, pattern = "VAS Export*.xlsx",
                               output_prefix = "VAS Derived") {
  folder <- path.expand(folder)
  usable <- function(paths) {
    names_only <- basename(paths)
    paths[!startsWith(names_only, "~$") & !startsWith(names_only, output_prefix)]
  }
  candidates <- usable(Sys.glob(file.path(folder, pattern)))
  if (!length(candidates)) {
    seen <- basename(usable(Sys.glob(file.path(folder, "*.xlsx"))))
    stop(structure(class = c("vas_no_export", "error", "condition"), list(
      message = sprintf(
        "No file matching '%s' was found in:\n  %s\n\nThe workbooks in that folder are:\n  %s\n\nSave the Alchemer export there with a name starting \"VAS Export\", then run this again.",
        pattern, folder,
        if (length(seen)) paste(seen, collapse = "\n  ") else "(none)"),
      call = NULL)))
  }
  return(candidates[which.max(file.info(candidates)$mtime)])
}
