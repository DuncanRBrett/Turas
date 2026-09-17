# ==============================================================================
# KEYDRIVER - WHAT THE CONFIG SAYS REACHES THE REPORT (review B3)
# ==============================================================================
# The report layer reads thirteen fields off its config object. The pipeline
# handed it a five-field list, so the CustomSlides sheet, the Insights sheet
# and the analysis name were read from the workbook, announced on the console,
# and then dropped. Nothing failed and nothing said so, which is the exact
# shape of silent failure this module is being lifted out of.
#
# The custom slides had a second problem behind the first: the builder made
# the cards and then returned a panel that did not reference them.
#
# This runs the whole pipeline and then looks in the generated HTML, because
# every part of this chain already had a passing unit test around it.
# ==============================================================================

example_script <- file.path(project_root, "examples", "keydriver",
                            "create_keydriver_example.R")
skip_if(!file.exists(example_script), "example generator not present")

# Load the pipeline here rather than skipping when another file has not
# already loaded it, so this runs standalone as well as under test_dir.
if (!exists("run_keydriver_analysis_impl", mode = "function")) {
  Sys.setenv(TURAS_ROOT = project_root)
  assign("TURAS_ROOT", project_root, envir = .GlobalEnv)
  for (f in list.files(file.path(project_root, "modules", "shared", "lib"),
                       pattern = "\\.R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
  for (d in c(file.path(module_dir, "R"),
              file.path(module_dir, "R", "kda_quadrant"),
              file.path(module_dir, "R", "kda_shap"))) {
    # Not lib/html_report: the pipeline sources that itself, with
    # .keydriver_lib_dir set, and sourcing it here makes its guard
    # report every file missing against a working directory of ".".
    if (!dir.exists(d)) next
    for (f in list.files(d, pattern = "\\.R$", full.names = TRUE)) {
      tryCatch(source(f), error = function(e) NULL)
    }
  }
}
skip_if(!exists("run_keydriver_analysis_impl", mode = "function"), "pipeline not loaded")
skip_if_not_installed("readxl")
skip_if_not_installed("htmltools")

old_opt_b3 <- getOption("turas.example.no_run")
options(turas.example.no_run = TRUE)
source(example_script, local = FALSE)
options(turas.example.no_run = old_opt_b3)

# Strings that exist nowhere else in the codebase, so finding one in the
# report proves it travelled from the workbook and not from a default.
KD_B3_SLIDE_TITLE <- "Suiderland board briefing note"
KD_B3_SLIDE_BODY  <- "Digital is the lever, branch service is the hygiene factor."
KD_B3_INSIGHT     <- "Fees clarity is the cheapest win available this year."
KD_B3_LABEL       <- "Digital banking experience (config label)"
KD_B3_NAME        <- "Suiderland Driver Review 2026"

b3_dir <- file.path(tempdir(), "kd_b3_plumbing")
unlink(b3_dir, recursive = TRUE)
invisible(capture.output(
  b3_ex <- build_keydriver_example(out_dir = b3_dir, verbose = FALSE)))

# Rebuild the example config with the optional sheets present. Read and
# rewrite rather than loadWorkbook and save, which collapses each sheet's
# declared dimension to A1.
b3_build_config <- function(path) {
  src <- b3_ex$config
  settings <- as.data.frame(readxl::read_excel(src, sheet = "Settings"))
  set_value <- function(df, key, value) {
    if (key %in% df$Setting) df$Value[df$Setting == key] <- value
    else df <- rbind(df, data.frame(Setting = key, Value = value))
    df
  }
  settings <- set_value(settings, "enable_html_report", "TRUE")
  settings <- set_value(settings, "analysis_name", KD_B3_NAME)
  # Off, to keep this test about the plumbing rather than the engines.
  settings <- set_value(settings, "enable_shap", "FALSE")
  settings <- set_value(settings, "enable_quadrant", "FALSE")
  settings <- set_value(settings, "enable_bootstrap", "FALSE")

  variables <- as.data.frame(readxl::read_excel(src, sheet = "Variables"))
  variables$Label[variables$VariableName == "digital_banking"] <- KD_B3_LABEL

  wb <- openxlsx::createWorkbook()
  add <- function(name, df) {
    openxlsx::addWorksheet(wb, name)
    openxlsx::writeData(wb, name, df)
  }
  add("Settings", settings)
  add("Variables", variables)
  add("Segments", as.data.frame(readxl::read_excel(src, sheet = "Segments")))
  add("StatedImportance", as.data.frame(readxl::read_excel(src, sheet = "StatedImportance")))
  add("CustomSlides", data.frame(
    slide_title = KD_B3_SLIDE_TITLE,
    slide_content = KD_B3_SLIDE_BODY,
    stringsAsFactors = FALSE))
  add("Insights", data.frame(
    section = "importance",
    insight_text = KD_B3_INSIGHT,
    stringsAsFactors = FALSE))

  if (exists("turas_saveWorkbook", mode = "function")) {
    turas_saveWorkbook(wb, path, overwrite = TRUE)
  } else {
    openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  }
  path
}

b3_config <- b3_build_config(file.path(b3_dir, "Suiderland_B3_Config.xlsx"))
invisible(capture.output(
  b3_result <- suppressWarnings(run_keydriver_analysis_impl(b3_config))))
b3_html_path <- sub("\\.xlsx$", ".html", b3_result$config$output_file %||% "")
b3_html <- if (nzchar(b3_html_path) && file.exists(b3_html_path)) {
  paste(readLines(b3_html_path, warn = FALSE), collapse = "\n")
} else ""

test_that("the run produces an HTML report at all (B3)", {
  expect_equal(b3_result$run_status, "PASS")
  expect_true(nzchar(b3_html_path))
  expect_true(file.exists(b3_html_path))
  expect_gt(nchar(b3_html), 10000)
})

test_that("a CustomSlides row reaches the report (B3)", {
  # The loader prints "Loaded 1 custom slide(s) from config" either way. The
  # card builder was unreachable because config$custom_slides never arrived.
  expect_true(grepl(KD_B3_SLIDE_TITLE, b3_html, fixed = TRUE))
  expect_true(grepl(KD_B3_SLIDE_BODY, b3_html, fixed = TRUE))
})

test_that("an Insights row pre-populates its section (B3)", {
  expect_true(grepl(KD_B3_INSIGHT, b3_html, fixed = TRUE))
})

# Deliberately not tested here: the Variables sheet Label. It reaches the
# report either way, because 03_analysis.R writes Label into the importance
# table before the report ever sees it, and .kd_resolve_label() prefers that
# column. The transformer's config$variables read is a fallback that the
# pipeline never reaches, not a fix.

test_that("analysis_name reaches the report header (B3)", {
  expect_true(grepl(KD_B3_NAME, b3_html, fixed = TRUE))
})

test_that("the report config carries every field the report layer reads (B3)", {
  # A guard on the shape of the object, so a future edit that goes back to
  # hand-listing a few fields is caught here rather than in a client's report.
  main <- readLines(file.path(module_dir, "R", "00_main.R"), warn = FALSE)
  code <- main[!grepl("^\\s*#", main)]
  expect_true(any(grepl("html_config <- config", code, fixed = TRUE)))

  read_fields <- unique(unlist(lapply(
    list.files(file.path(module_dir, "lib", "html_report"),
               pattern = "\\.R$", full.names = TRUE),
    function(f) {
      src <- paste(readLines(f, warn = FALSE), collapse = "\n")
      m <- regmatches(src, gregexpr("config\\$[A-Za-z_][A-Za-z0-9_.]*", src))[[1]]
      sub("^config\\$", "", m)
    })))
  expect_gt(length(read_fields), 10)

  hoist_block <- paste(code, collapse = "\n")
  for (f in read_fields) {
    # Either the loaded config carries it, or 00_main hoists it by name.
    in_config <- f %in% names(b3_result$config %||% list())
    # (b3_result$config is the loaded config object, which is what
    #  html_config is now built from.)
    named <- grepl(paste0('"', f, '"'), hoist_block, fixed = TRUE) ||
      grepl(paste0("html_config$", f), hoist_block, fixed = TRUE)
    expect_true(in_config || named,
                info = sprintf("report reads config$%s and nothing supplies it", f))
  }
})
