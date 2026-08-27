# check_vas_structure.R
# ------------------------------------------------------------------------------
# Structure gate for the VAS derived-variable code: no source file over 300
# active lines, no function over 50 active lines. Active lines exclude blanks,
# comments and lines that are only a closing brace.
#
#   Rscript modules/vas/check_vas_structure.R
#
# Exits 1 if anything is over, so it can be used as a pre-commit check. The
# same check runs in the test suite (test-vas_structure.R), which calls
# check_vas_structure() directly.
#
# The gate covers the derived-variable set it was written for (July 2026), not
# every file in the module - extending it is a policy decision, not a default.
# A file may carry a "SIZE-EXCEPTION" comment to be exempt from the file limit;
# there is no exception for the function limit.
# ------------------------------------------------------------------------------

VAS_MAX_FILE_LINES <- 300L
VAS_MAX_FUNCTION_LINES <- 50L

VAS_SOURCE_FILES <- c(
  "vas_amount_parser.R", "vas_frequency.R", "vas_read_source.R",
  "vas_derive_category.R", "vas_derive.R", "vas_sense_check.R",
  "vas_data_dictionary.R", "vas_data_dictionary_headline.R", "vas_write_excel.R",
  "vas_pipeline.R",
  "run_vas_derive.R", "vas_derived_config.R"
)

#' Count the active lines in a block of R source
#'
#' @param lines A character vector of source lines.
#'
#' @return An integer count.
count_active_lines <- function(lines) {
  trimmed <- trimws(lines)
  is_blank <- !nzchar(trimmed)
  is_comment <- grepl("^#", trimmed)
  # "]" first in the class: TRE treats a backslash inside [] as literal, so the
  # July wording "[})\\]]" never matched anything and braces counted as active.
  is_brace_only <- grepl("^[]})]+[,;]?$", trimmed)
  return(sum(!(is_blank | is_comment | is_brace_only)))
}

#' Find each top-level function and measure it
#'
#' Functions are located by the "name <- function(" idiom at column one, and
#' run to the next such line or the end of the file.
#'
#' @param lines A character vector of source lines.
#'
#' @return A data frame of \code{name} and \code{active_lines}.
measure_functions <- function(lines) {
  starts <- grep("^[A-Za-z._][A-Za-z0-9._]*\\s*<-\\s*function\\s*\\(", lines)
  if (!length(starts)) {
    return(data.frame(name = character(0), active_lines = integer(0),
                      stringsAsFactors = FALSE))
  }
  ends <- c(starts[-1] - 1L, length(lines))
  return(data.frame(
    name = sub("\\s*<-.*$", "", lines[starts]),
    active_lines = vapply(seq_along(starts),
                          function(i) count_active_lines(lines[starts[i]:ends[i]]),
                          integer(1)),
    stringsAsFactors = FALSE
  ))
}

#' Run the structure check over the gated files
#'
#' @param code_dir The directory holding the vas_*.R files.
#' @param quiet TRUE to suppress the per-file table (the test suite's mode).
#'
#' @return A character vector of breaches, empty when everything is under.
check_vas_structure <- function(code_dir = ".", quiet = FALSE) {
  breaches <- character(0)
  if (!quiet) {
    cat(sprintf("%-32s %6s %6s  %s\n", "file", "lines", "active", "longest function"))
    cat(strrep("-", 78), "\n")
  }
  for (name in VAS_SOURCE_FILES) {
    path <- file.path(code_dir, name)
    if (!file.exists(path)) {
      breaches <- c(breaches, sprintf("%s is missing", name))
      next
    }
    lines <- readLines(path, warn = FALSE)
    active <- count_active_lines(lines)
    functions <- measure_functions(lines)
    worst <- if (nrow(functions)) functions[which.max(functions$active_lines), ] else
      data.frame(name = "-", active_lines = 0L)
    if (!quiet) {
      cat(sprintf("%-32s %6d %6d  %s (%d)\n", name, length(lines), active,
                  worst$name, worst$active_lines))
    }
    if (active > VAS_MAX_FILE_LINES && !any(grepl("SIZE-EXCEPTION", lines))) {
      breaches <- c(breaches, sprintf("%s: %d active lines, limit %d",
                                      name, active, VAS_MAX_FILE_LINES))
    }
    over <- functions[functions$active_lines > VAS_MAX_FUNCTION_LINES, ]
    for (i in seq_len(nrow(over))) {
      breaches <- c(breaches, sprintf("%s: %s() is %d active lines, limit %d",
                                      name, over$name[i], over$active_lines[i],
                                      VAS_MAX_FUNCTION_LINES))
    }
  }
  if (!quiet) {
    cat(strrep("-", 78), "\n")
  }
  return(breaches)
}

main <- function() {
  script_dir <- local({
    file_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
    if (length(file_argument)) {
      dirname(normalizePath(sub("^--file=", "", file_argument[1])))
    } else {
      "."
    }
  })
  breaches <- check_vas_structure(script_dir)
  if (length(breaches)) {
    cat(sprintf("\n%d structure breach(es):\n", length(breaches)))
    for (breach in breaches) {
      cat(sprintf("  %s\n", breach))
    }
    quit(status = 1L)
  }
  cat(sprintf("\nAll files under %d active lines, all functions under %d.\n",
              VAS_MAX_FILE_LINES, VAS_MAX_FUNCTION_LINES))
  return(invisible(NULL))
}

if (sys.nframe() == 0L && !interactive()) {
  main()
}
