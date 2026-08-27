# run_vas_derive.R
# ------------------------------------------------------------------------------
# Produce the VAS derived-variable table: one row per respondent, carrying
# transactions per month, monthly spend and spend per transaction for every
# category and base, the two headline totals, value received, and share of
# wallet on both the income midpoint and the income upper boundary.
#
# One of the two entry points named in vas_pipeline.R - this one reads the
# Alchemer API (or an export) and writes timestamped files; the other,
# run_vas_fieldwork.R in the OneDrive fieldwork folder, drives the live chain.
#
# Usage, from any directory:
#
#   Rscript modules/vas/run_vas_derive.R                          # read the Alchemer API
#   Rscript modules/vas/run_vas_derive.R export "~/Downloads/VAS Export.xlsx"
#
# Outputs, all written to output/ UNDER THE CURRENT DIRECTORY with a timestamp:
#   vas_derived_<stamp>.xlsx       the deliverable - four sheets, self-documenting
#   vas_derived_<stamp>.csv        the same wide table, for scripting against
#   vas_derived_audit_<stamp>.csv  one row per respondent, category and base
#
# and, regenerated in place each run:
#   docs/VAS_DERIVED_CALCULATIONS.md (beside this script) - the calculation for
#   every column, in markdown
# ------------------------------------------------------------------------------

VAS_SURVEY_ID <- 8912114
VAS_OUTPUT_DIR <- "output"
VAS_DEFAULT_EXPORT <- "~/Downloads/VAS Export.xlsx"

# The script's own directory: the code library and the calculations doc live
# beside it, wherever it is run from.
vas_script_dir <- local({
  file_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_argument)) {
    dirname(normalizePath(sub("^--file=", "", file_argument[1])))
  } else {
    "."
  }
})
VAS_CALCULATIONS_DOC <- file.path(vas_script_dir, "docs", "VAS_DERIVED_CALCULATIONS.md")

source(file.path(vas_script_dir, "vas_pipeline.R"))
load_vas_library(vas_script_dir)

#' Choose and read the data source named on the command line
#'
#' @param arguments The character vector from \code{commandArgs(TRUE)}.
#'
#' @return A vas_source object.
read_requested_source <- function(arguments) {
  origin <- if (length(arguments) >= 1L) tolower(arguments[1]) else "api"
  if (identical(origin, "export")) {
    path <- if (length(arguments) >= 2L) arguments[2] else VAS_DEFAULT_EXPORT
    cat(sprintf("Reading the Alchemer export: %s\n", path))
    return(read_vas_export(path))
  }
  if (!identical(origin, "api")) {
    stop(structure(class = c("vas_bad_argument", "error", "condition"), list(
      message = sprintf("Unknown source '%s'. Use 'api' or 'export'.", origin),
      call = NULL)))
  }
  cat(sprintf("Reading the Alchemer API: survey %s\n", VAS_SURVEY_ID))
  return(read_vas_api(VAS_SURVEY_ID))
}

#' Write the workbook, the two CSVs and the markdown documentation
#'
#' @param result The list returned by \code{derive_vas()}.
#' @param dictionary The data frame from \code{build_data_dictionary()}.
#' @param source_origin "api" or "export".
#' @param stamp A timestamp string for the file names.
#'
#' @return A named character vector of the paths written.
write_outputs <- function(result, dictionary, source_origin, stamp) {
  if (!dir.exists(VAS_OUTPUT_DIR)) {
    dir.create(VAS_OUTPUT_DIR, recursive = TRUE)
  }
  paths <- c(
    workbook = file.path(VAS_OUTPUT_DIR, sprintf("vas_derived_%s.xlsx", stamp)),
    wide     = file.path(VAS_OUTPUT_DIR, sprintf("vas_derived_%s.csv", stamp)),
    audit    = file.path(VAS_OUTPUT_DIR, sprintf("vas_derived_audit_%s.csv", stamp)),
    markdown = VAS_CALCULATIONS_DOC
  )
  write_vas_workbook(result, dictionary, VAS_CONFIG, source_origin, paths[["workbook"]])
  utils::write.csv(result$wide, paths[["wide"]], row.names = FALSE, na = "")
  utils::write.csv(result$audit, paths[["audit"]], row.names = FALSE, na = "")
  write_dictionary_markdown(dictionary, paths[["markdown"]])
  return(paths)
}

main <- function() {
  category_map <- read_category_map(vas_script_dir)
  source_data <- read_requested_source(commandArgs(trailingOnly = TRUE))
  derived <- derive_and_report(source_data, category_map, VAS_CONFIG)
  result <- derived$result
  failures <- derived$failures

  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  paths <- write_outputs(result, derived$dictionary, source_data$origin, stamp)
  print_heading("8. Files written")
  cat(sprintf("  %s\n      4 sheets: Derived (%d x %d), Dictionary (%d), Settings, Audit (%d)\n",
              paths[["workbook"]], nrow(result$wide), ncol(result$wide),
              nrow(derived$dictionary), nrow(result$audit)))
  cat(sprintf("  %s  (%d rows x %d columns)\n", paths[["wide"]], nrow(result$wide),
              ncol(result$wide)))
  cat(sprintf("  %s  (%d rows)\n", paths[["audit"]], nrow(result$audit)))
  cat(sprintf("  %s  (every column documented)\n", paths[["markdown"]]))

  if (length(failures)) {
    cat(sprintf("\nFINISHED WITH %d CONSISTENCY FAILURE(S) - see section 7.\n",
                length(failures)))
    quit(status = 1L)
  }
  cat("\nFinished. All consistency checks passed.\n")
  return(invisible(result))
}

if (sys.nframe() == 0L && !interactive()) {
  main()
}
