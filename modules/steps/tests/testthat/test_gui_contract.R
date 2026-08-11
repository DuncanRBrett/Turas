# ==============================================================================
# TESTS - GUI contract
# ==============================================================================
# The GUI itself is verified by Duncan through launch_turas(). What is testable
# here is the contract the launcher depends on: run_steps_gui() must RETURN a
# Shiny app object (the launcher does `app <- run_steps_gui(); runApp(app)`), so
# a runApp() call inside the function would break the tile.
# ==============================================================================

test_that("run_steps_gui() returns a shiny app object without starting a server", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyFiles")
  skip_if_not_installed("processx")

  old_root <- Sys.getenv("TURAS_ROOT", unset = NA)
  Sys.setenv(TURAS_ROOT = TURAS_ROOT)
  on.exit({
    if (is.na(old_root)) Sys.unsetenv("TURAS_ROOT") else Sys.setenv(TURAS_ROOT = old_root)
  }, add = TRUE)

  gui_env <- new.env(parent = globalenv())
  sys.source(file.path(TURAS_ROOT, "modules", "steps", "run_steps_gui.R"),
             envir = gui_env)
  expect_true(is.function(gui_env$run_steps_gui))

  app <- suppressMessages(gui_env$run_steps_gui())
  expect_s3_class(app, "shiny.appobj")
})

test_that("the launcher registers the Steps tile with a matching script and icon", {
  launcher <- readLines(file.path(TURAS_ROOT, "launch_turas.R"), warn = FALSE)
  joined <- paste(launcher, collapse = "\n")

  expect_true(grepl('id = "steps"', joined, fixed = TRUE))
  expect_true(grepl('modules/steps/run_steps_gui.R', joined, fixed = TRUE))
  # launch_module() calls run_<id>_gui(), so the id and the function must agree.
  expect_true(grepl("steps = '<svg", joined, fixed = TRUE))
  expect_true(file.exists(file.path(TURAS_ROOT, "modules", "steps", "run_steps_gui.R")))
})
