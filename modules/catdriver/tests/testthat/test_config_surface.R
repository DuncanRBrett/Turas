# ==============================================================================
# CATDRIVER - THE CONFIG SURFACE (H9, H10)
# ==============================================================================
# H9. README, the user manual, the example workflows and the technical docs all
#     told the reader to source R/00_main.R and call the entry point. That has
#     never worked: 00_main.R loads the TRS infrastructure and nothing else, so
#     the call died with `could not find function "with_refusal_handler"`. Only
#     the GUI's own file sequence produced a working session, and that sequence
#     lived in three places free to drift apart.
# H10. The template's dropdowns offered values the guards refuse, so a user
#      could pick one from a list and have the run refuse.
# ==============================================================================

test_that("the documented entry point loads a working module", {
  rscript <- file.path(R.home("bin"), "Rscript")
  skip_if(!file.exists(rscript), "Rscript not found")

  script <- tempfile(fileext = ".R")
  writeLines(c(
    sprintf('setwd("%s")', turas_root),
    'source("modules/catdriver/source_catdriver.R")',
    'cat("ENTRY:", exists("run_categorical_keydriver", mode = "function"), "\\n")',
    'cat("HANDLER:", exists("with_refusal_handler", mode = "function"), "\\n")',
    'cat("GUARD:", exists("guard_pre_analysis", mode = "function"), "\\n")',
    'cat("MAPPER:", exists("extract_odds_ratios_mapped", mode = "function"), "\\n")',
    'cat("LIBDIR:", exists(".catdriver_lib_dir", envir = globalenv()), "\\n")',
    # the call the docs actually tell a reader to make
    'r <- with_refusal_handler(run_categorical_keydriver("does_not_exist.xlsx"))',
    'cat("REFUSES_CLEANLY:", !is.null(catdriver_result_status(r)$code), "\\n")'
  ), script)
  out <- suppressWarnings(system2(rscript, shQuote(script), stdout = TRUE, stderr = TRUE))
  unlink(script)
  info <- paste(out, collapse = "\n")

  expect_true(any(grepl("^ENTRY: TRUE", out)), info = info)
  expect_true(any(grepl("^HANDLER: TRUE", out)), info = info)
  expect_true(any(grepl("^GUARD: TRUE", out)), info = info)
  expect_true(any(grepl("^MAPPER: TRUE", out)), info = info)
  expect_true(any(grepl("^LIBDIR: TRUE", out)), info = info)
  expect_true(any(grepl("^REFUSES_CLEANLY: TRUE", out)), info = info)
  expect_false(any(grepl("could not find function", out, fixed = TRUE)), info = info)
})

test_that("the loader works from a different working directory and from inside a function", {
  rscript <- file.path(R.home("bin"), "Rscript")
  skip_if(!file.exists(rscript), "Rscript not found")

  loader <- file.path(turas_root, "modules", "catdriver", "source_catdriver.R")
  script <- tempfile(fileext = ".R")
  writeLines(c(
    sprintf('setwd("%s")', tempdir()),
    # a Shiny observer sources it from inside a function, where the outermost
    # frame has no ofile: the trap the shared loader carried until Sep 2026
    sprintf('f <- function() source("%s")', loader),
    'f()',
    'cat("NESTED:", exists("run_categorical_keydriver", mode = "function"), "\\n")'
  ), script)
  out <- suppressWarnings(system2(rscript, shQuote(script), stdout = TRUE, stderr = TRUE))
  unlink(script)
  expect_true(any(grepl("^NESTED: TRUE", out)), info = paste(out, collapse = "\n"))
})

test_that("the GUI and the demo runner load through the same list", {
  gui <- readLines(file.path(turas_root, "modules", "catdriver", "run_catdriver_gui.R"),
                   warn = FALSE)
  demo <- readLines(file.path(turas_root, "modules", "catdriver", "examples", "demo",
                              "run_demo.R"), warn = FALSE)

  expect_true(any(grepl("source_catdriver.R", gui, fixed = TRUE)))
  expect_true(any(grepl("source_catdriver.R", demo, fixed = TRUE)))

  # Neither may keep its own copy of the order. The demo runner used to source
  # R/ in ALPHABETICAL order, which is the test helper's order and the opposite
  # of the GUI's, and that divergence is what hid the refusal-signature clash.
  code <- c(gui, demo)
  code <- code[!grepl("^\\s*#", code)]
  expect_false(any(grepl('source\\(file\\.path\\(.*"modules/catdriver/R"', code)))
  expect_false(any(grepl('list\\.files\\(r_dir', code)))
})

test_that("every value the template offers is a value the code accepts", {
  source(file.path(turas_root, "modules/catdriver/lib/generate_config_templates.R"),
         local = TRUE)

  sections <- build_catdriver_settings_def()
  fields <- unlist(lapply(sections, function(s) s$fields), recursive = FALSE)
  dropdown_of <- function(name) {
    f <- Filter(function(x) identical(x$name, name), fields)
    if (length(f) == 0) NULL else f[[1]]$dropdown
  }

  # outcome_type: the guard accepts exactly these three
  expect_setequal(dropdown_of("outcome_type"), c("binary", "ordinal", "multinomial"))

  # driver type: the guard accepts these four. The template offered "nominal",
  # which is refused, and omitted "binary", which is accepted.
  driver_cols <- build_catdriver_driver_settings_columns()
  type_col <- Filter(function(x) identical(x$name, "type"), driver_cols)[[1]]
  expect_setequal(type_col$dropdown,
                  c("categorical", "ordinal", "binary", "control_only"))
  expect_false("nominal" %in% type_col$dropdown)

  # and the guard really does refuse what the template no longer offers
  cfg <- list(driver_vars = "d",
              driver_settings = data.frame(driver = "d", type = "nominal",
                                           stringsAsFactors = FALSE))
  expect_error(guard_require_driver_settings(cfg), "CFG_DRIVER_TYPE_INVALID|INVALID DRIVER TYPE")
})

test_that("no document still tells the reader to source 00_main.R alone", {
  docs <- c(
    file.path(turas_root, "modules", "catdriver", "README.md"),
    list.files(file.path(turas_root, "modules", "catdriver", "docs"),
               pattern = "\\.md$", full.names = TRUE)
  )
  offenders <- character(0)
  for (d in docs) {
    lines <- readLines(d, warn = FALSE)
    hits <- grep('source\\("modules/catdriver/R/00_main\\.R"\\)', lines)
    # a line that explains the defect is fine; an instruction is not
    hits <- hits[!grepl("does NOT work|never has|fails with", lines[hits])]
    if (length(hits) > 0) offenders <- c(offenders, paste0(basename(d), ":", hits))
  }
  expect_length(offenders, 0)
})

# ==============================================================================
# The controls that did nothing (M7, M9, M10)
# ==============================================================================

test_that("a setting value nobody can parse falls back to the default, out loud", {
  # M9. "YES!" returned FALSE whatever default the caller passed, so a setting
  # the user had switched on was silently off.
  expect_output(res <- as_logical_setting("YES!", TRUE), "not a yes/no value")
  expect_true(res)
  expect_output(res2 <- as_logical_setting("maybe", FALSE), "not a yes/no value")
  expect_false(res2)

  # the values that ARE understood stay silent and stay right
  expect_silent(expect_true(as_logical_setting("Yes", FALSE)))
  expect_silent(expect_false(as_logical_setting("no", TRUE)))
  expect_silent(expect_true(as_logical_setting(TRUE, FALSE)))

  # and the numeric twin
  expect_output(n <- as_numeric_setting("95%", 0.95), "not a number")
  expect_equal(n, 0.95)
  expect_silent(expect_equal(as_numeric_setting("0.9", 0.95), 0.9))
})

test_that("a Settings row the loader never reads is reported", {
  skip_if_not_installed("openxlsx")

  # M9. A misspelled setting is simply never looked at, so the run uses the
  # default and the user believes their setting took effect.
  cfg <- tempfile(fileext = ".xlsx")
  on.exit(unlink(cfg), add = TRUE)
  data_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(data_csv), add = TRUE)
  utils::write.csv(data.frame(outcome = c("a", "b"), d1 = c("x", "y")),
                   data_csv, row.names = FALSE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("data_file", "output_file", "outcome_type",
                "bootstrap_resp", "colour_scheme"),
    Value = c(basename(data_csv), "out.xlsx", "binary", "500", "blue"),
    stringsAsFactors = FALSE
  ))
  openxlsx::addWorksheet(wb, "Variables")
  openxlsx::writeData(wb, "Variables", data.frame(
    VariableName = c("outcome", "d1"), Type = c("outcome", "driver"),
    Label = c("Outcome", "Driver one"), stringsAsFactors = FALSE
  ))
  openxlsx::addWorksheet(wb, "Driver_Settings")
  openxlsx::writeData(wb, "Driver_Settings", data.frame(
    driver = "d1", type = "categorical", stringsAsFactors = FALSE
  ))
  openxlsx::saveWorkbook(wb, cfg, overwrite = TRUE)

  out <- utils::capture.output(
    cfg_obj <- tryCatch(load_catdriver_config(cfg), turas_refusal = function(e) NULL)
  )
  text <- paste(out, collapse = "\n")

  expect_true(grepl("bootstrap_resp", text))
  expect_true(grepl("colour_scheme", text))
  expect_true(grepl("do not read|does not read|no effect", text))
  # and the spelling that IS read is not reported
  expect_false(grepl("\\bdata_file\\b", sub(".*Check the spelling.*", "", text)))
})

test_that("the stats pack setting has three honest states", {
  # M7. The setting defaulted to "Y" and the caller option was OR'd in, so the
  # config could never switch the pack off and the GUI checkbox could never
  # switch it on or off either.
  main <- readLines(file.path(turas_root, "modules", "catdriver", "R", "00_main.R"),
                    warn = FALSE)
  block <- grep("generate_stats_pack_flag", main)
  expect_true(length(block) > 0)
  code <- paste(main[seq(min(block), min(block) + 14)], collapse = " ")

  expect_false(grepl('%\\|\\|% "Y"', code))          # no silent default-on
  expect_false(grepl("\\|\\| isTRUE\\(getOption", code))  # no OR with the option
  expect_true(grepl("as_logical_setting", code))     # the config is parsed, not compared
})

test_that("the GUI sends only the branding the user edited", {
  gui <- readLines(file.path(turas_root, "modules", "catdriver", "run_catdriver_gui.R"),
                   warn = FALSE)
  code <- gui[!grepl("^\\s*#", gui)]

  # M10. Prefilled inputs were sent whenever non-empty, so an untouched form
  # overrode the config file's own branding on every run.
  expect_true(any(grepl("CATDRIVER_GUI_PREFILL", code)))
  expect_true(any(grepl('edited\\("brand_colour"', code)))
  expect_true(any(grepl('edited\\("accent_colour"', code)))
  expect_true(any(grepl('edited\\("report_title"', code)))

  # the prefill values in the comparison must match the ones the inputs carry
  prefill_block <- paste(gui[grep("CATDRIVER_GUI_PREFILL <- list", gui) + 0:4], collapse = " ")
  for (v in c("#323367", "#CC9900", "Categorical Key Driver Analysis")) {
    expect_true(grepl(v, prefill_block, fixed = TRUE), info = v)
    expect_true(any(grepl(v, gui, fixed = TRUE)))
  }
})
