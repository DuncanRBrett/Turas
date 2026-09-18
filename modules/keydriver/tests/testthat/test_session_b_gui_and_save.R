# ==============================================================================
# KEYDRIVER SESSION B - THE GUI AND SAVE REPORT TELL THE TRUTH
# ==============================================================================

gui_path <- file.path(module_dir, "run_keydriver_gui.R")
skip_if(!file.exists(gui_path), "GUI not present")
gui_src <- readLines(gui_path, warn = FALSE)

test_that("the GUI reads the run's own verdict, not just whether R threw (H2)", {
  # A TRS refusal returns an object and the process carries on, so
  # captured$has_error is FALSE. The GUI printed "Analysis complete!" over a
  # run that produced nothing.
  expect_true(any(grepl(".kd_gui_verdict", gui_src, fixed = TRUE)))
  expect_true(any(grepl("turas_refusal_result", gui_src, fixed = TRUE)))
  expect_true(any(grepl("Analysis REFUSED", gui_src, fixed = TRUE)))
  expect_true(any(grepl("DEGRADED OUTPUTS", gui_src, fixed = TRUE)))
  # The success line now exists only as the "ok" branch of the verdict, never
  # as an unconditional else.
  code <- gui_src[!grepl("^\\s*#", gui_src)]
  idx <- grep("Analysis complete!", code, fixed = TRUE)
  expect_length(idx, 1)
  expect_true(grepl("level = \"ok\"", code[idx], fixed = TRUE))
})

test_that("the verdict helper classifies each outcome (H2)", {
  # Lift the helper out of the GUI file and exercise it directly.
  start <- grep("^  \\.kd_gui_verdict <- function", gui_src)
  expect_length(start, 1)
  ends <- grep("^  \\}$", gui_src)
  stop_at <- min(ends[ends > start])
  eval(parse(text = paste(gui_src[start:stop_at], collapse = "\n")), envir = environment())

  clean <- list(has_error = FALSE, has_warnings = FALSE)
  expect_equal(.kd_gui_verdict(list(run_status = "PASS"), clean)$level, "ok")
  expect_equal(.kd_gui_verdict(list(run_status = "PARTIAL"), clean)$level, "partial")
  expect_equal(.kd_gui_verdict(list(run_status = "REFUSED"), clean)$level, "refused")
  # An R error still counts, whatever the object says.
  expect_equal(.kd_gui_verdict(list(run_status = "PASS"),
                               list(has_error = TRUE, has_warnings = FALSE))$level, "refused")
  # A refusal object with no status field is still a refusal.
  refusal <- structure(list(), class = "turas_refusal_result")
  expect_equal(.kd_gui_verdict(refusal, clean)$level, "refused")
  # A degraded run names what degraded.
  partial <- list(run_status = "PARTIAL",
                  status = list(degraded_reasons = c("Bootstrap CI failed", "NCA failed")))
  expect_match(.kd_gui_verdict(partial, clean)$message, "Bootstrap CI failed")
})

test_that("the HTML checkbox no longer overrides a config that asked for a report (M7)", {
  # The checkbox starts FALSE and its value was always passed, so a config
  # saying enable_html_report = Yes never produced one from the GUI. The
  # pipeline already documents NULL as "the config decides".
  expect_false(any(grepl("html_report <- isTRUE(input$enable_html_report)",
                         gui_src, fixed = TRUE)))
  expect_true(any(grepl("if (isTRUE(input$enable_html_report)) TRUE else NULL",
                        gui_src, fixed = TRUE)))
  main <- readLines(file.path(module_dir, "R", "00_main.R"), warn = FALSE)
  expect_true(any(grepl("If NULL (default), reads from config", main, fixed = TRUE)))
})

test_that("one bootstrap default, read everywhere (M8)", {
  # Sourced here rather than skipped when absent: a skip would let the old
  # two-defaults code back in without the suite saying a word.
  source(file.path(module_dir, "R", "01_config.R"), local = TRUE)
  # The run used 500 and the stats pack reported 1000, so the figure a client
  # read was not the figure that produced their intervals.
  expect_equal(kd_bootstrap_iterations(list()), KD_DEFAULT_BOOTSTRAP_ITERATIONS)
  expect_equal(kd_bootstrap_iterations(list(settings = list(bootstrap_iterations = 250))), 250L)
  expect_equal(kd_bootstrap_iterations(list(settings = list(bootstrap_iterations = "250"))), 250L)
  # Nonsense falls back rather than reaching the bootstrap as NA.
  expect_equal(kd_bootstrap_iterations(list(settings = list(bootstrap_iterations = "many"))),
               KD_DEFAULT_BOOTSTRAP_ITERATIONS)

  main <- readLines(file.path(module_dir, "R", "00_main.R"), warn = FALSE)
  code <- main[!grepl("^\\s*#", main)]
  expect_false(any(grepl("bootstrap_iterations %||% 500", code, fixed = TRUE)))
  expect_false(any(grepl('bootstrap_iterations %||% "500"', code, fixed = TRUE)))
  expect_false(any(grepl("bootstrap_iterations %||% 1000", code, fixed = TRUE)))
  expect_gte(sum(grepl("kd_bootstrap_iterations(config)", code, fixed = TRUE)), 3)
})

test_that("typed commentary survives Save Report (H10)", {
  js <- readLines(file.path(module_dir, "lib", "html_report", "js", "kd_utils.js"),
                  warn = FALSE)
  src <- paste(js, collapse = "\n")
  # The commentary boxes are textareas. A textarea's typed content is in
  # .value, which is not serialised when the page is saved, and the sync
  # function was an empty stub whose comment claimed otherwise.
  expect_false(grepl("Nothing extra needed", src, fixed = TRUE))
  expect_true(grepl("kd-qual-md-editor", src, fixed = TRUE))
  expect_true(grepl("kd-qual-img-store", src, fixed = TRUE))
  expect_true(grepl("el.textContent = el.value", src, fixed = TRUE))

  # The markup really is a textarea, which is what makes this necessary.
  builders <- readLines(file.path(module_dir, "lib", "html_report",
                                  "03c_section_builders.R"), warn = FALSE)
  tag_line <- grep("kd-qual-md-editor", builders)
  expect_gt(length(tag_line), 0)
  expect_true(any(grepl("tags\\$textarea", builders[seq(max(1, min(tag_line) - 2), min(tag_line))])))

  # And Save Report calls the sync before it serialises.
  nav <- paste(readLines(file.path(module_dir, "lib", "html_report", "js",
                                   "kd_navigation.js"), warn = FALSE), collapse = "\n")
  expect_true(grepl("kdSyncAllInsights", nav, fixed = TRUE))
})
