# ==============================================================================
# TESTS - GUI server logic (headless, no browser)
# ==============================================================================
# shiny::testServer drives the reactive graph directly. This covers the wiring
# the non-Shiny tests cannot reach: the form rendered from a manifest, the run
# button, the polling observer that streams output while the tool is alive, and
# the PASS / REFUSED banner.
#
# It does NOT verify what the page looks like. That remains Duncan's gate, via
# launch_turas().
# ==============================================================================

load_steps_app <- function() {
  Sys.setenv(TURAS_ROOT = TURAS_ROOT)
  gui_env <- new.env(parent = globalenv())
  sys.source(file.path(TURAS_ROOT, "modules", "steps", "run_steps_gui.R"),
             envir = gui_env)
  suppressMessages(gui_env$run_steps_gui())
}

arg_input <- function(tool_id, arg_id) paste0("arg__", tool_id, "__", arg_id)


test_that("choosing a tool renders a form with a field per manifest argument", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")

  app <- load_steps_app()
  shiny::testServer(app, {
    session$setInputs(select_tool = "comment_appendix_build")
    expect_equal(rv$tool_id, "comment_appendix_build")

    html <- as.character(output$tool_form$html)
    for (arg in steps_find_tool("comment_appendix_build")$args) {
      expect_true(grepl(arg_input("comment_appendix_build", arg$id), html, fixed = TRUE),
                  info = arg$id)
    }
    # File arguments get a picker; the flag does not.
    expect_true(grepl("browse__comment_appendix_build__data", html, fixed = TRUE))
    expect_false(grepl("browse__comment_appendix_build__dry_run", html, fixed = TRUE))
  })
})


test_that("a blank required field refuses without starting a process", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")

  app <- load_steps_app()
  shiny::testServer(app, {
    session$setInputs(select_tool = "comment_appendix_build")
    session$setInputs(
      `arg__comment_appendix_build__data`         = "",
      `arg__comment_appendix_build__appendix`     = "",
      `arg__comment_appendix_build__columns_file` = "",
      `arg__comment_appendix_build__pattern`      = "",
      `arg__comment_appendix_build__dry_run`      = FALSE
    )
    suppressMessages(session$setInputs(run_step = 1))

    expect_equal(rv$result$status, "REFUSED")
    expect_equal(rv$result$code, "CFG_STEP_ARG_MISSING")
    expect_false(isTRUE(rv$running))
    expect_null(rv$proc)

    # The refusal reaches the page, not just the console.
    card <- as.character(output$output_card$html)
    expect_true(grepl("CFG_STEP_ARG_MISSING", card, fixed = TRUE))
  })
})


test_that("running a tool streams its output and reports PASS", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")
  skip_if_not_installed("openxlsx")
  if (!appendix_env_ready()) {
    skip("python3 with openpyxl + pandas is not available on this machine")
  }

  dir <- tempfile("gui_run_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  openxlsx::write.xlsx(
    data.frame(ResponseID = 1:2,
               Q1Comment = c("first verbatim", "second verbatim"),
               stringsAsFactors = FALSE),
    file.path(dir, "survey.xlsx"))
  appendix <- file.path(dir, "appendix.xlsx")

  app <- load_steps_app()
  shiny::testServer(app, {
    session$setInputs(select_tool = "comment_appendix_build")
    session$setInputs(
      `arg__comment_appendix_build__data`         = file.path(dir, "survey.xlsx"),
      `arg__comment_appendix_build__appendix`     = appendix,
      `arg__comment_appendix_build__columns_file` = "",
      `arg__comment_appendix_build__pattern`      = "Comment",
      `arg__comment_appendix_build__dry_run`      = FALSE
    )
    suppressMessages(session$setInputs(run_step = 1))
    expect_true(isTRUE(rv$running))

    # session$elapse() advances Shiny's clock, not the wall clock the tool runs
    # on, so each tick waits for real time too.
    for (i in seq_len(60)) {
      Sys.sleep(0.25)
      suppressMessages(session$elapse(300))
      if (!isTRUE(rv$running)) break
    }

    expect_false(isTRUE(rv$running))
    expect_null(rv$proc)
    expect_equal(rv$result$status, "PASS")
    expect_true(file.exists(appendix))

    # The script's preview - resolved columns and per-column counts - is a
    # feature of this step; it must reach the page, never be swallowed.
    joined <- paste(rv$lines, collapse = "\n")
    expect_true(grepl("Comment columns (1, via pattern)", joined, fixed = TRUE))
    expect_true(grepl("Q1Comment", joined, fixed = TRUE))
    expect_true(grepl("2 comment rows added", joined, fixed = TRUE))

    card <- as.character(output$output_card$html)
    expect_true(grepl("finished successfully", card, fixed = TRUE))
  })
})


# ---- runbook checklist -------------------------------------------------------

make_runbook <- function(dir, data_file, appendix) {
  steps <- data.frame(
    Order = c(1, 2, 3),
    Step  = c("Export the survey from Alchemer, completes only",
              "Build/update the comment appendix",
              "Run the crosstabs"),
    Type  = c("manual", "tool", "module"),
    Tool  = c("", "comment_appendix_build", "tabs"),
    Notes = c("Save over the export path", "Columns come from the pattern", ""),
    `arg:data`     = c("", data_file, ""),
    `arg:appendix` = c("", appendix, ""),
    `arg:pattern`  = c("", "Comment", ""),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  path <- file.path(dir, "Test Runbook.xlsx")
  res <- steps_runbook_write_template(path, project_name = "Test", steps = steps,
                                      provenance = list(ai_insights_narrative = "off"))
  expect_equal(res$status, "PASS")
  path
}


test_that("opening a runbook lists its steps and shows its provenance", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")
  skip_unless_xlsx()

  dir <- tempfile("gui_runbook_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- make_runbook(dir, "/tmp/survey.xlsx", "/tmp/appendix.xlsx")

  app <- load_steps_app()
  shiny::testServer(app, {
    session$setInputs(runbook_path = path)
    suppressMessages(session$setInputs(load_runbook = 1))

    expect_equal(length(rv$runbook$steps), 3L)
    html <- as.character(output$checklist_card$html)
    expect_true(grepl("Build/update the comment appendix", html, fixed = TRUE))
    expect_true(grepl("Export the survey from Alchemer", html, fixed = TRUE))
    expect_true(grepl("ai_insights_narrative: off", html, fixed = TRUE))
    # Only the tool row is runnable.
    expect_equal(length(gregexpr("open_runbook_step", html)[[1]]), 1L)
  })
})

test_that("a broken runbook refuses on the card and loads nothing", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")
  skip_unless_xlsx()

  dir <- tempfile("gui_runbook_bad_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  steps <- data.frame(Order = 1, Step = "Do a thing", Type = "tool",
                      Tool = "not_a_registered_tool", Notes = "",
                      stringsAsFactors = FALSE)
  path <- file.path(dir, "Bad Runbook.xlsx")
  steps_runbook_write_template(path, project_name = "Bad", steps = steps)

  app <- load_steps_app()
  shiny::testServer(app, {
    session$setInputs(runbook_path = path)
    suppressMessages(session$setInputs(load_runbook = 1))

    expect_null(rv$runbook)
    expect_equal(rv$runbook_msg$code, "CFG_RUNBOOK_INVALID")
    expect_null(output$checklist_card)
    status <- as.character(output$runbook_status$html)
    expect_true(grepl("not_a_registered_tool", status, fixed = TRUE))
  })
})

test_that("opening a step selects its tool and prefills the form", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")
  skip_unless_xlsx()

  dir <- tempfile("gui_runbook_open_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- make_runbook(dir, "/tmp/survey.xlsx", "/tmp/appendix.xlsx")

  app <- load_steps_app()
  shiny::testServer(app, {
    session$setInputs(runbook_path = path)
    suppressMessages(session$setInputs(load_runbook = 1))
    suppressMessages(session$setInputs(open_runbook_step = 2))

    expect_equal(rv$tool_id, "comment_appendix_build")
    expect_equal(rv$prefill$data, "/tmp/survey.xlsx")
    expect_false(is.null(rv$step_key))

    form <- as.character(output$tool_form$html)
    expect_true(grepl('value="/tmp/survey.xlsx"', form, fixed = TRUE))
    expect_true(grepl('value="Comment"', form, fixed = TRUE))
  })
})

test_that("choosing a tool directly clears any runbook prefill", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")
  skip_unless_xlsx()

  dir <- tempfile("gui_runbook_clear_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- make_runbook(dir, "/tmp/survey.xlsx", "/tmp/appendix.xlsx")

  app <- load_steps_app()
  shiny::testServer(app, {
    session$setInputs(runbook_path = path)
    suppressMessages(session$setInputs(load_runbook = 1))
    suppressMessages(session$setInputs(open_runbook_step = 2))
    suppressMessages(session$setInputs(select_tool = "comment_appendix_build"))

    expect_equal(length(rv$prefill), 0L)
    expect_null(rv$step_key)
    form <- as.character(output$tool_form$html)
    expect_false(grepl("/tmp/survey.xlsx", form, fixed = TRUE))
  })
})

test_that("marking a non-tool step done records it in the sidecar", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")
  skip_unless_xlsx()

  dir <- tempfile("gui_runbook_mark_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- make_runbook(dir, "/tmp/survey.xlsx", "/tmp/appendix.xlsx")
  before <- file.info(path)$mtime

  app <- load_steps_app()
  shiny::testServer(app, {
    session$setInputs(runbook_path = path)
    suppressMessages(session$setInputs(load_runbook = 1))
    suppressMessages(session$setInputs(mark_runbook_step = 1))

    expect_equal(length(rv$state), 1L)
    expect_equal(rv$state[[1]]$last_status, "PASS")
    html <- as.character(output$checklist_card$html)
    expect_true(grepl("Last run:", html, fixed = TRUE))
  })

  # The workbook itself is never written to.
  expect_equal(file.info(path)$mtime, before)
  expect_true(file.exists(steps_runbook_state_path(path)))
})

test_that("running a step from the runbook records the outcome against it", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")
  skip_unless_xlsx()
  if (!appendix_env_ready()) {
    skip("python3 with openpyxl + pandas is not available on this machine")
  }

  dir <- tempfile("gui_runbook_run_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  data_file <- file.path(dir, "survey.xlsx")
  appendix  <- file.path(dir, "appendix.xlsx")
  openxlsx::write.xlsx(
    data.frame(ResponseID = 1:2,
               Q1Comment = c("first verbatim", "second verbatim"),
               stringsAsFactors = FALSE), data_file)
  path <- make_runbook(dir, data_file, appendix)

  app <- load_steps_app()
  shiny::testServer(app, {
    session$setInputs(runbook_path = path)
    suppressMessages(session$setInputs(load_runbook = 1))
    suppressMessages(session$setInputs(open_runbook_step = 2))

    # The prefill is baked into the rendered inputs, and a real browser sends
    # those values back as input$... on init. testServer has no client, so the
    # sync is done here - the form's own prefilling is asserted separately.
    expect_true(grepl(data_file, as.character(output$tool_form$html), fixed = TRUE))
    session$setInputs(
      `arg__comment_appendix_build__data`         = rv$prefill$data,
      `arg__comment_appendix_build__appendix`     = rv$prefill$appendix,
      `arg__comment_appendix_build__columns_file` = "",
      `arg__comment_appendix_build__pattern`      = rv$prefill$pattern,
      `arg__comment_appendix_build__dry_run`      = FALSE
    )
    suppressMessages(session$setInputs(run_step = 1))

    for (i in seq_len(60)) {
      Sys.sleep(0.25)
      suppressMessages(session$elapse(300))
      if (!isTRUE(rv$running)) break
    }

    expect_equal(rv$result$status, "PASS")
    expect_true(file.exists(appendix))

    st <- rv$state[[rv$step_key]]
    expect_equal(st$last_status, "PASS")
    expect_equal(st$last_args$data, data_file)

    # And it survives a reload of the runbook.
    suppressMessages(session$setInputs(load_runbook = 2))
    expect_equal(rv$state[[rv$step_key]]$last_status, "PASS")
  })
})
