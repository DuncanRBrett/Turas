# ==============================================================================
# Gate: the synthetic example generators still call functions that exist, and
# still emit rows that match the sheet headers they are written under
# ==============================================================================
# The three brand examples (1brand, 3cat, 9cat) are the fixtures the report's
# configuration variants are checked against. They broke silently twice over.
#
# Failure 1, loud but late: the shared column builders were renamed
# (.build_questions_columns became .build_unified_questions_columns) and the
# example callers were not updated, so every generator died partway through
# with "could not find function". Nothing in the suite ran them, so the break
# sat unnoticed.
#
# Failure 2, silent: write_table_sheet() writes the sheet header from the
# columns definition and then looks each header name up in the row list,
# writing an empty cell when the name is absent. A row builder that still
# emits the old field name (VariableType rather than Variable_Type) therefore
# produces a full-looking sheet with a blank column, and no error anywhere.
#
# This file guards both. It sources each example's dependency chain, replaces
# the two sheet writers and the workbook saver with recorders, and runs the
# real config and structure generators. A missing function raises. A row whose
# fields do not cover the required headers is reported by sheet and column.
#
# The recorders keep the gate fast: no workbook is built and no file is
# written. A separate, slower test builds the smallest example for real, so
# the end-to-end path is covered too.
# ------------------------------------------------------------------------------
library(testthat)

.turas_root <- function() {
  root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(root)) root <- file.path("..", "..", "..", "..")
  normalizePath(root, mustWork = FALSE)
}

.examples_root <- function() {
  file.path(.turas_root(), "modules", "brand", "examples")
}

.example_specs <- function() {
  list(
    list(name = "1brand",
         sourcer = ".source_1brand_sources",
         config = "generate_1brand_config",
         structure = "generate_1brand_structure"),
    list(name = "3cat",
         sourcer = ".source_3cat_deps",
         config = "generate_3cat_config",
         structure = "generate_3cat_structure"),
    list(name = "9cat",
         sourcer = ".source_9cat_deps",
         config = "generate_9cat_config",
         structure = "generate_9cat_structure")
  )
}

#' Source one example's dependency chain into the global environment
#'
#' The generators are written as free functions that source their own
#' dependencies with local = FALSE, so they resolve every helper through the
#' global environment. The gate follows that, rather than fighting it.
#'
#' @return TRUE when the chain sourced, FALSE when the example is not on disk.
#' @keywords internal
.source_example <- function(spec) {
  build_all <- file.path(.examples_root(), spec$name, "00_build_all.R")
  if (!file.exists(build_all)) return(FALSE)
  suppressMessages(source(build_all, local = FALSE))
  sourcer <- get(spec$sourcer, envir = globalenv())
  # The sourcers resolve their siblings relative to the project root, so run
  # them from there rather than from the testthat directory.
  withr::with_dir(.turas_root(), suppressMessages(sourcer()))
  TRUE
}

#' Run one generator with the sheet writers replaced by recorders
#'
#' @param generator Name of the generator function, e.g. generate_3cat_structure.
#' @return List of records: one per table sheet, each with sheet, columns
#'   (the required header names) and rows (the emitted row lists).
#' @keywords internal
.record_sheets <- function(generator) {
  g <- globalenv()
  recorded <- list()

  saved <- list()
  for (nm in c("write_table_sheet", "write_settings_sheet",
               "turas_saveWorkbook")) {
    saved[[nm]] <- if (exists(nm, envir = g, inherits = FALSE)) {
      get(nm, envir = g)
    } else NULL
  }
  on.exit({
    for (nm in names(saved)) {
      if (is.null(saved[[nm]])) {
        if (exists(nm, envir = g, inherits = FALSE)) rm(list = nm, envir = g)
      } else {
        assign(nm, saved[[nm]], envir = g)
      }
    }
  }, add = TRUE)

  assign("write_table_sheet", function(wb, sheet_name, columns_def, title,
                                       subtitle, example_rows = NULL,
                                       num_blank_rows = 50) {
    required <- vapply(
      Filter(function(cd) isTRUE(cd$required), columns_def),
      function(cd) cd$name, character(1)
    )
    recorded[[length(recorded) + 1L]] <<- list(
      sheet = sheet_name,
      all_columns = vapply(columns_def, function(cd) cd$name, character(1)),
      required = required,
      rows = example_rows
    )
    invisible(NULL)
  }, envir = g)

  assign("write_settings_sheet", function(wb, sheet_name, settings_def, title,
                                          subtitle) invisible(NULL), envir = g)
  assign("turas_saveWorkbook", function(wb, file, overwrite = TRUE, ...) {
    invisible(NULL)
  }, envir = g)

  fn <- get(generator, envir = globalenv())
  # The generators announce each file they write. Nothing is written here, so
  # swallow the announcement rather than scattering it through the test output.
  invisible(capture.output(fn(file.path(tempdir(), "never_written.xlsx"))))
  recorded
}

#' Header names a recorded sheet's rows fail to supply
#'
#' Only required headers are checked. An optional header may legitimately be
#' absent from a row; write_table_sheet leaves that cell empty on purpose.
#'
#' @keywords internal
.missing_required_fields <- function(record) {
  if (is.null(record$rows) || length(record$rows) == 0L) return(character(0))
  missing <- character(0)
  for (row in record$rows) {
    gap <- setdiff(record$required, names(row))
    if (length(gap) > 0L) missing <- unique(c(missing, gap))
  }
  missing
}

#' Row field names that match no header on the sheet they are written to
#'
#' A leftover field (Battery, VariableType) is dropped in silence by
#' write_table_sheet, so it is worth naming even though it writes no wrong
#' value on its own. It is the tell that a row builder was left behind by a
#' schema change.
#'
#' @keywords internal
.orphan_fields <- function(record) {
  if (is.null(record$rows) || length(record$rows) == 0L) return(character(0))
  seen <- unique(unlist(lapply(record$rows, names)))
  setdiff(seen, record$all_columns)
}


test_that("the gate can find the example generators it is meant to run", {
  root <- .examples_root()
  skip_if_not(dir.exists(root), "brand examples directory not on disk")
  for (spec in .example_specs()) {
    expect_true(
      file.exists(file.path(root, spec$name, "00_build_all.R")),
      info = sprintf("%s/00_build_all.R is missing", spec$name)
    )
  }
})


for (.spec in .example_specs()) {
  local({
    spec <- .spec

    test_that(sprintf(
      "%s config and structure generators run and match their sheet headers",
      spec$name), {

      skip_if_not(dir.exists(.examples_root()),
                  "brand examples directory not on disk")
      skip_if_not(.source_example(spec),
                  sprintf("%s example not on disk", spec$name))

      for (generator in c(spec$config, spec$structure)) {
        expect_true(
          exists(generator, envir = globalenv(), mode = "function"),
          info = sprintf("%s is not defined after sourcing %s",
                         generator, spec$name)
        )

        # Running the generator is the gate on missing functions: a renamed
        # shared builder raises "could not find function" right here.
        records <- .record_sheets(generator)
        expect_gt(length(records), 0L)

        for (record in records) {
          missing <- .missing_required_fields(record)
          if (length(missing) > 0L) {
            cat("\n=== BRAND EXAMPLE SCHEMA GATE ===\n")
            cat(sprintf("Example:  %s\n", spec$name))
            cat(sprintf("Generator: %s\n", generator))
            cat(sprintf("Sheet:    %s\n", record$sheet))
            cat(sprintf("Rows do not supply required header(s): %s\n",
                        paste(missing, collapse = ", ")))
            cat("How to fix: rename the field in the row builder, or add it.\n")
            cat("=================================\n\n")
          }
          expect_equal(
            missing, character(0),
            info = sprintf("%s / %s / sheet %s: required header(s) absent
 from the emitted rows", spec$name, generator, record$sheet)
          )

          orphans <- .orphan_fields(record)
          if (length(orphans) > 0L) {
            cat("\n=== BRAND EXAMPLE SCHEMA GATE ===\n")
            cat(sprintf("Example:  %s\n", spec$name))
            cat(sprintf("Generator: %s\n", generator))
            cat(sprintf("Sheet:    %s\n", record$sheet))
            cat(sprintf("Row field(s) match no header and are dropped: %s\n",
                        paste(orphans, collapse = ", ")))
            cat("How to fix: drop the field, or add it to the column set.\n")
            cat("=================================\n\n")
          }
          expect_equal(
            orphans, character(0),
            info = sprintf("%s / %s / sheet %s: row field(s) match no header",
                           spec$name, generator, record$sheet)
          )
        }
      }
    })
  })
}


test_that("the smallest example builds all three files end to end", {
  skip_if_not(dir.exists(.examples_root()),
              "brand examples directory not on disk")

  spec <- .example_specs()[[1]]
  skip_if_not(.source_example(spec), "1brand example not on disk")

  out <- file.path(tempdir(), "brand_1brand_gate")
  unlink(out, recursive = TRUE)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)

  builder <- get("build_1brand_synthetic_example", envir = globalenv())
  invisible(withr::with_dir(.turas_root(), suppressMessages(
    capture.output(res <- builder(output_dir = out), type = "output")
  )))
  expect_true(file.exists(res$config))
  expect_true(file.exists(res$structure))
  expect_true(file.exists(res$data))
  expect_gt(file.size(res$data), 0)
})
