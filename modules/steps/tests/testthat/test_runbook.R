# ==============================================================================
# TESTS - Runbook parsing, validation, template, sidecar state
# ==============================================================================

#' Write a Steps sheet (and optionally a Provenance sheet) to a temp workbook
write_runbook <- function(steps, provenance = NULL, sheet_name = "Steps") {
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, sheet_name)
  openxlsx::writeData(wb, sheet_name, steps)
  if (!is.null(provenance)) {
    openxlsx::addWorksheet(wb, "Provenance")
    openxlsx::writeData(wb, "Provenance", provenance)
  }
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

good_steps <- function() {
  data.frame(
    Order = c(1, 2, 3),
    Step  = c("Export the survey from Alchemer",
              "Build the comment appendix",
              "Run the crosstabs"),
    Type  = c("manual", "tool", "module"),
    Tool  = c("", "comment_appendix_build", "tabs"),
    Notes = c("Completes only", "", "Via launch_turas"),
    `arg:data` = c("", "/tmp/survey.xlsx", ""),
    `arg:appendix` = c("", "/tmp/appendix.xlsx", ""),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}


test_that("a good runbook reads back in order with its arguments", {
  skip_unless_xlsx()
  path <- write_runbook(good_steps())
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "PASS")
  expect_equal(length(res$result$steps), 3L)

  s2 <- res$result$steps[[2]]
  expect_equal(s2$type, "tool")
  expect_equal(s2$tool, "comment_appendix_build")
  expect_equal(s2$args$data, "/tmp/survey.xlsx")
  expect_equal(s2$args$appendix, "/tmp/appendix.xlsx")
  expect_equal(s2$row, 3L)   # sheet row, header included - matches Excel

  # Blank argument cells are not passed at all.
  expect_equal(length(res$result$steps[[1]]$args), 0L)
})

test_that("steps are sorted by Order, not by sheet position", {
  skip_unless_xlsx()
  s <- good_steps()
  s$Order <- c(3, 1, 2)
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "PASS")
  expect_equal(vapply(res$result$steps, function(x) x$order, character(1)),
               c("1", "2", "3"))
})

test_that("non-numeric Order values leave the sheet order alone", {
  skip_unless_xlsx()
  s <- good_steps()
  s$Order <- c("1", "2a", "2b")
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "PASS")
  expect_equal(vapply(res$result$steps, function(x) x$order, character(1)),
               c("1", "2a", "2b"))
})

test_that("blank spacer rows are skipped rather than refused", {
  skip_unless_xlsx()
  s <- good_steps()
  s[4, ] <- list(NA, NA, NA, NA, NA, NA, NA)
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "PASS")
  expect_equal(length(res$result$steps), 3L)
})

test_that("step types are accepted however a human types them", {
  skip_unless_xlsx()
  s <- good_steps()
  s$Type <- c("Manual", "TOOL", "AI assisted")
  s$Tool <- c("", "comment_appendix_build", "")
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "PASS")
  expect_equal(vapply(res$result$steps, function(x) x$type, character(1)),
               c("manual", "tool", "ai-assisted"))
})


# ---- refusals, each naming the row -------------------------------------------

test_that("a missing file refuses", {
  res <- steps_runbook_read(file.path(tempdir(), "no_such_runbook.xlsx"))
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "IO_RUNBOOK_NOT_FOUND")
})

test_that("a workbook with no Steps sheet refuses and lists what it found", {
  skip_unless_xlsx()
  path <- write_runbook(good_steps(), sheet_name = "Sequence")
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_RUNBOOK_INVALID")
  expect_true(grepl("no 'Steps' sheet", res$message, fixed = TRUE))
  expect_true("Sequence" %in% res$context$sheets_found)
})

test_that("a missing required column refuses and names it", {
  skip_unless_xlsx()
  s <- good_steps()
  s$Type <- NULL
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_RUNBOOK_INVALID")
  expect_true(grepl("Type", res$message, fixed = TRUE))
})

test_that("an unknown tool id refuses, naming the row and the step", {
  skip_unless_xlsx()
  s <- good_steps()
  s$Tool[2] <- "no_such_tool"
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_RUNBOOK_INVALID")
  expect_true(grepl("Row 3", res$message, fixed = TRUE))
  expect_true(grepl("no_such_tool", res$message, fixed = TRUE))
  expect_true(grepl("Build the comment appendix", res$message, fixed = TRUE))
  # The fix names the ids that would work.
  expect_true(any(grepl("comment_appendix_build", res$how_to_fix, fixed = TRUE)))
})

test_that("a tool row with no Tool id refuses", {
  skip_unless_xlsx()
  s <- good_steps()
  s$Tool[2] <- ""
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "REFUSED")
  expect_true(grepl("names no Tool", res$message, fixed = TRUE))
})

test_that("an unknown step type refuses, naming the row and the value", {
  skip_unless_xlsx()
  s <- good_steps()
  s$Type[3] <- "automatic"
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "REFUSED")
  expect_true(grepl("Row 4", res$message, fixed = TRUE))
  expect_true(grepl("automatic", res$message, fixed = TRUE))
})

test_that("a step with no description refuses", {
  skip_unless_xlsx()
  s <- good_steps()
  s$Step[1] <- ""
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "REFUSED")
  expect_true(grepl("Row 2", res$message, fixed = TRUE))
})

test_that("a runbook with no steps refuses", {
  skip_unless_xlsx()
  s <- good_steps()[0, ]
  path <- write_runbook(s)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "REFUSED")
  expect_true(grepl("no steps in it", res$message, fixed = TRUE))
})


# ---- provenance --------------------------------------------------------------

test_that("the Provenance sheet reads back as parameter/value", {
  skip_unless_xlsx()
  prov <- data.frame(
    Parameter = c("ai_insights_narrative", "verbatim_theming", "client_approval_reference"),
    Value = c("off", "none", "Proposal s4, 13 May 2026"),
    stringsAsFactors = FALSE
  )
  path <- write_runbook(good_steps(), provenance = prov)
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "PASS")
  expect_equal(res$result$provenance$ai_insights_narrative, "off")
  expect_equal(res$result$provenance$client_approval_reference, "Proposal s4, 13 May 2026")
})

test_that("a runbook with no Provenance sheet still reads", {
  skip_unless_xlsx()
  path <- write_runbook(good_steps())
  on.exit(unlink(path), add = TRUE)

  res <- steps_runbook_read(path)
  expect_equal(res$status, "PASS")
  expect_equal(length(res$result$provenance), 0L)
})


# ---- sidecar state -----------------------------------------------------------

test_that("state round-trips beside the workbook, never inside it", {
  skip_unless_xlsx()
  dir <- tempfile("runbook_state_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  path <- file.path(dir, "ASSA Runbook.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Steps")
  openxlsx::writeData(wb, "Steps", good_steps())
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  before <- file.info(path)$mtime

  expect_equal(steps_runbook_state_read(path), list())

  key <- steps_runbook_key(list(order = "2", step = "Build the comment appendix"))
  when <- as.POSIXct("2026-08-11 09:00:00", tz = "UTC")
  steps_runbook_state_write(path, key, "PASS",
                            args = list(data = "/tmp/survey.xlsx"), when = when)

  state <- steps_runbook_state_read(path)
  expect_equal(state[[key]]$last_status, "PASS")
  expect_equal(state[[key]]$last_args$data, "/tmp/survey.xlsx")
  expect_equal(state[[key]]$last_run, when)

  # The sidecar sits beside the workbook, hidden, and the workbook is untouched.
  expect_true(file.exists(file.path(dir, ".ASSA Runbook_runbook_state.rds")))
  expect_equal(file.info(path)$mtime, before)
})

test_that("the step key changes when the step does, so history cannot migrate", {
  a <- steps_runbook_key(list(order = "2", step = "Build the comment appendix"))
  b <- steps_runbook_key(list(order = "2", step = "Build the appendix"))
  c <- steps_runbook_key(list(order = "3", step = "Build the comment appendix"))
  expect_false(a == b)
  expect_false(a == c)
})

test_that("unreadable state is treated as no state", {
  dir <- tempfile("runbook_badstate_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- file.path(dir, "R.xlsx")
  writeLines("not an rds", steps_runbook_state_path(path))
  expect_equal(steps_runbook_state_read(path), list())
})


# ---- template ----------------------------------------------------------------

test_that("the template writes and reads back through the parser", {
  skip_unless_xlsx()
  dir <- tempfile("runbook_tpl_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- file.path(dir, "Template Runbook.xlsx")

  res <- steps_runbook_write_template(path, project_name = "Demo",
                                      steps = good_steps())
  expect_equal(res$status, "PASS")
  expect_true(file.exists(path))
  expect_true(all(c("Steps", "Provenance", "Guide") %in% openxlsx::getSheetNames(path)))

  back <- steps_runbook_read(path)
  expect_equal(back$status, "PASS")
  expect_equal(length(back$result$steps), 3L)
  # Provenance keys are present even when unset, so the block prompts for them.
  expect_true("verbatim_theming" %in% names(back$result$provenance))
})

test_that("the template refuses to overwrite an existing runbook", {
  skip_unless_xlsx()
  dir <- tempfile("runbook_tpl2_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- file.path(dir, "R.xlsx")

  expect_equal(steps_runbook_write_template(path)$status, "PASS")
  res <- steps_runbook_write_template(path)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "IO_RUNBOOK_EXISTS")

  expect_equal(steps_runbook_write_template(path, overwrite = TRUE)$status, "PASS")
})

test_that("an empty template is a valid workbook that refuses only for being empty", {
  skip_unless_xlsx()
  dir <- tempfile("runbook_tpl3_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- file.path(dir, "Blank Runbook.xlsx")

  expect_equal(steps_runbook_write_template(path, project_name = "Blank")$status, "PASS")
  back <- steps_runbook_read(path)
  expect_equal(back$status, "REFUSED")
  expect_true(grepl("no steps in it", back$message, fixed = TRUE))
})

test_that("writing into a folder that does not exist refuses rather than throwing", {
  skip_unless_xlsx()
  res <- steps_runbook_write_template(
    file.path(tempdir(), "no_such_folder_xyz", "R.xlsx"))
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "IO_RUNBOOK_WRITE_FAILED")
})
