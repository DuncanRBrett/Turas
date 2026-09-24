# ==============================================================================
# TABS MODULE - MODULE CONTRIBUTION FILE PATHS (conjoint_island ... whatif_island)
# ==============================================================================
#
# The six *_island settings used to reach file.exists() as raw text, after the
# launcher had changed the working directory to modules/tabs/lib. A relative
# path was therefore looked for inside the engine and the module's tab was
# silently left out of the report. A relative path now means relative to the
# config file's folder, the same rule as narrative_file.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_island_paths.R")
#
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))
source(file.path(turas_root, "modules/tabs/lib/crosstabs/crosstabs_config.R"))
source(file.path(turas_root, "modules/tabs/lib/crosstabs/narrative_reader.R"))
assign(".tabs_lib_dir", file.path(turas_root, "modules/tabs/lib"), envir = globalenv())

norm <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)


# ==============================================================================
# THE RESOLVER
# ==============================================================================

test_that("every island setting is covered, and all are whitelisted", {
  expect_setequal(TABS_ISLAND_SETTINGS,
                  c("conjoint_island", "maxdiff_island", "pricing_island",
                    "keydriver_island", "catdriver_island", "whatif_island"))
  expect_true(all(TABS_ISLAND_SETTINGS %in% TABS_KNOWN_SETTINGS))
})

test_that("a relative path resolves against the config's folder", {
  root <- tempfile("islroot"); dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  cfg <- resolve_island_paths(
    list(whatif_island = "04 Whatif/Study_whatif_island.json",
         conjoint_island = "./cj/Study_cj_island.json"),
    root)
  expect_identical(cfg$whatif_island, norm(file.path(root, "04 Whatif/Study_whatif_island.json")))
  expect_identical(cfg$conjoint_island, norm(file.path(root, "cj/Study_cj_island.json")))
})

test_that("an absolute path is used as given", {
  abs <- file.path(tempdir(), "elsewhere", "Study_kd_island.json")
  cfg <- resolve_island_paths(list(keydriver_island = abs), "/some/other/project")
  expect_identical(cfg$keydriver_island, norm(abs))
})

test_that("wrapping quotes from Copy as path are stripped", {
  root <- tempfile("islq"); dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  cfg <- resolve_island_paths(list(pricing_island = "\"Study_pr_island.json\" "), root)
  expect_identical(cfg$pricing_island, norm(file.path(root, "Study_pr_island.json")))
})

test_that("blank, absent and NA settings are left exactly as they were", {
  cfg <- resolve_island_paths(list(maxdiff_island = "", catdriver_island = NA,
                                   apply_weighting = TRUE), "/p")
  expect_identical(cfg$maxdiff_island, "")
  expect_true(is.na(cfg$catdriver_island))
  expect_null(cfg$whatif_island)
  expect_true(cfg$apply_weighting)
})


# ==============================================================================
# THROUGH THE REAL CONFIG LOADER
# ==============================================================================

test_that("the real loader resolves a relative island path whatever the working directory", {
  demo_dir <- file.path(turas_root, "examples/tabs/demo_survey")
  skip_if_not(file.exists(file.path(demo_dir, "Demo_Crosstab_Config.xlsx")),
              "Demo survey fixture not found")

  d <- tempfile("isle2e"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  file.copy(list.files(demo_dir, full.names = TRUE), d, recursive = TRUE)
  dir.create(file.path(d, "04 Whatif"))
  writeLines("{}", file.path(d, "04 Whatif", "Demo_whatif_island.json"))
  cfg <- file.path(d, "Demo_Crosstab_Config.xlsx")

  settings <- openxlsx::read.xlsx(cfg, sheet = "Settings", colNames = FALSE,
                                  skipEmptyRows = FALSE)
  wb <- openxlsx::loadWorkbook(cfg)
  openxlsx::writeData(wb, "Settings",
    data.frame(a = "whatif_island", b = "04 Whatif/Demo_whatif_island.json"),
    startRow = nrow(settings) + 1, colNames = FALSE)
  openxlsx::saveWorkbook(wb, cfg, overwrite = TRUE)

  # The launchers run the engine from modules/tabs/lib. Do the same, so a
  # path resolved against the working directory would miss.
  old <- setwd(file.path(turas_root, "modules/tabs/lib"))
  on.exit(setwd(old), add = TRUE)

  capture.output(res <- suppressMessages(load_crosstabs_config(cfg)))
  expect_identical(res$config_obj$whatif_island,
                   norm(file.path(d, "04 Whatif", "Demo_whatif_island.json")))
  expect_true(file.exists(res$config_obj$whatif_island))
  # the other five stay blank
  for (key in setdiff(TABS_ISLAND_SETTINGS, "whatif_island")) {
    expect_identical(res$config_obj[[key]], "", info = key)
  }
})
