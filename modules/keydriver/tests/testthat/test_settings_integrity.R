# ==============================================================================
# KEYDRIVER - THE SETTINGS SHEET IS READ, NOT GUESSED AT (review M13)
# ==============================================================================
# Three ways a Settings sheet could mislead: a typo'd name was ignored without
# a word, a duplicated name silently took the first value, and a sheet with no
# Setting/Value columns fell through to a refusal about a missing data file,
# which sends the analyst looking at the wrong thing entirely.
# ==============================================================================

# Loaded rather than skipped, and globally rather than into this file's
# environment, so keydriver_refuse() and the rest resolve the way they do in a
# run.
if (!exists("load_keydriver_config", mode = "function")) {
  Sys.setenv(TURAS_ROOT = project_root)
  assign("TURAS_ROOT", project_root, envir = .GlobalEnv)
  for (f in list.files(file.path(project_root, "modules", "shared", "lib"),
                       pattern = "[.]R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
  for (f in list.files(file.path(module_dir, "R"),
                       pattern = "[.]R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}
expect_true(exists("load_keydriver_config", mode = "function"))

make_config <- function(settings, path = tempfile(fileext = ".xlsx"),
                        variables = NULL) {
  if (is.null(variables)) {
    variables <- data.frame(
      VariableName = c("y", "x1", "x2"),
      Type = c("Outcome", "Driver", "Driver"),
      Label = c("Outcome", "Driver one", "Driver two"),
      DriverType = c(NA, "continuous", "continuous"),
      stringsAsFactors = FALSE)
  }
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", settings)
  openxlsx::addWorksheet(wb, "Variables")
  openxlsx::writeData(wb, "Variables", variables)
  if (exists("turas_saveWorkbook", mode = "function")) {
    turas_saveWorkbook(wb, path, overwrite = TRUE)
  } else {
    openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  }
  path
}

base_settings <- function(...) {
  extra <- list(...)
  s <- data.frame(
    Setting = c("data_file", "output_file"),
    Value = c("data.xlsx", "out.xlsx"),
    stringsAsFactors = FALSE)
  if (length(extra)) {
    s <- rbind(s, data.frame(Setting = names(extra),
                             Value = unlist(lapply(extra, as.character)),
                             stringsAsFactors = FALSE))
  }
  s
}

test_that("a duplicated Setting is refused, not silently halved (M13)", {
  p <- make_config(rbind(base_settings(),
                         data.frame(Setting = c("enable_shap", "enable_shap"),
                                    Value = c("TRUE", "FALSE"),
                                    stringsAsFactors = FALSE)))
  on.exit(unlink(p), add = TRUE)

  err <- tryCatch({
    suppressMessages(invisible(capture.output(load_keydriver_config(p))))
    "NO REFUSAL"
  }, error = function(e) conditionMessage(e))

  expect_match(err, "CFG_SETTINGS_DUPLICATED")
  expect_match(err, "enable_shap")
  # And it says why it matters, not just that it happened.
  expect_match(err, "not necessarily")
})

test_that("a Settings sheet with no Setting/Value columns says so (M13)", {
  # This used to fall through to CFG_DATA_FILE_MISSING.
  p <- make_config(data.frame(Name = c("data_file"), Val = c("data.xlsx"),
                              stringsAsFactors = FALSE))
  on.exit(unlink(p), add = TRUE)

  err <- tryCatch({
    suppressMessages(invisible(capture.output(load_keydriver_config(p))))
    "NO REFUSAL"
  }, error = function(e) conditionMessage(e))

  expect_match(err, "CFG_SETTINGS_MALFORMED")
  expect_false(grepl("CFG_DATA_FILE_MISSING", err))
  # The refusal names what it found, so the analyst can see the spelling.
  expect_match(err, "Name")
})

test_that("an unrecognised Setting is named on the console (M13)", {
  p <- make_config(base_settings(enabel_shap = "TRUE", my_note = "ignore me"))
  on.exit(unlink(p), add = TRUE)

  out <- capture.output(
    tryCatch(suppressMessages(load_keydriver_config(p)),
             error = function(e) invisible(NULL)))
  txt <- paste(out, collapse = "\n")

  # The typo is named, so a config that asks for a feature and runs without
  # it no longer does so in silence.
  expect_true(grepl("not read by this module", txt, fixed = TRUE))
  expect_true(grepl("enabel_shap", txt, fixed = TRUE))
  expect_true(grepl("my_note", txt, fixed = TRUE))
  # A correctly spelled setting is not named. Checked on the warning line
  # itself, since the run also refuses later about the missing data file and
  # that refusal legitimately mentions it.
  warn_line <- grep("not read by this module", out, value = TRUE, fixed = TRUE)
  expect_equal(length(warn_line), 1L)
  expect_false(grepl("data_file", warn_line[1], fixed = TRUE))
  expect_false(grepl("output_file", warn_line[1], fixed = TRUE))
})

test_that("a correctly spelled config warns about nothing (M13)", {
  p <- make_config(base_settings(enable_shap = "FALSE", random_seed = "2026",
                                 html_show_guide = "TRUE"))
  on.exit(unlink(p), add = TRUE)

  out <- capture.output(
    tryCatch(suppressMessages(load_keydriver_config(p)),
             error = function(e) invisible(NULL)))
  expect_false(any(grepl("not read by this module", out, fixed = TRUE)))
})

test_that("the known-settings list matches the template (M13)", {
  # The list and the template are two statements of the same contract. Bound
  # here, so a key added to one and not the other fails the suite rather than
  # drifting until an analyst finds it.
  skip_if_not_installed("openxlsx")
  styles <- file.path(project_root, "modules", "shared", "template_styles.R")
  gen <- file.path(module_dir, "lib", "generate_config_templates.R")
  skip_if(!file.exists(styles) || !file.exists(gen), "template generator not present")
  source(styles, local = TRUE)
  source(gen, local = TRUE)

  defs <- build_keydriver_settings_def()
  template_keys <- sort(unique(unlist(lapply(defs, function(sec) {
    vapply(sec$fields, function(f) f$name, character(1))
  }))))

  expect_equal(setdiff(template_keys, KD_KNOWN_SETTINGS), character(0))
  expect_equal(setdiff(KD_KNOWN_SETTINGS, template_keys), character(0))
  expect_gt(length(KD_KNOWN_SETTINGS), 50)
})
