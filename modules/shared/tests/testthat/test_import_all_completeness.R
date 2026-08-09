# ==============================================================================
# TESTS: import_all.R loads everything a module can rely on
# ==============================================================================
# Regression cover for a defect seen on a real run (Electrum VAS 2024 weighting):
# stats_pack_writer.R was not sourced by import_all.R. It was only loaded inside
# the weighting module's load_shared_infrastructure(), which is skipped whenever
# a caller has already sourced the shared infrastructure. The config asked for a
# stats pack, none was written, and the run still reported PASS.
#
# These tests run import_all.R in a clean environment and assert that the
# functions modules source it for are actually defined.
# ==============================================================================

library(testthat)

find_turas_root <- function() {
  p <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(p, "modules", "shared", "lib", "import_all.R"))) {
      return(normalizePath(p))
    }
    p <- dirname(p)
  }
  NULL
}

TURAS_ROOT <- find_turas_root()
SHARED_LIB <- if (is.null(TURAS_ROOT)) NULL else {
  file.path(TURAS_ROOT, "modules", "shared", "lib")
}

# import_all.R sources everything with local = FALSE, so its functions always
# land in the global environment of whichever session loaded it. The only honest
# way to ask "does a clean session that sources import_all.R get function X?" is
# to start a clean session and ask it. Returns the names it could not find.
missing_after_import_all <- function(fns) {
  script <- sprintf(
    'setwd("%s"); source("modules/shared/lib/import_all.R"); cat(paste(Filter(function(f) !exists(f, mode = "function"), c(%s)), collapse = "|"))',
    TURAS_ROOT,
    paste(sprintf('"%s"', fns), collapse = ", ")
  )
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    args = c("-e", shQuote(script)),
    stdout = TRUE, stderr = FALSE
  ))
  out <- paste(out[nzchar(out)], collapse = "")
  if (!nzchar(out)) character(0) else strsplit(out, "|", fixed = TRUE)[[1]]
}

# Functions that import_all.R must provide. Each is sourced by at least one
# module on the assumption that loading the shared infrastructure is enough.
REQUIRED_FUNCTIONS <- c(
  "turas_refuse",                 # trs_refusal.R
  "turas_run_state_new",          # trs_run_state.R
  "turas_print_start_banner",     # trs_banner.R
  "turas_save_workbook_atomic",   # turas_save_workbook_atomic.R
  "turas_excel_escape",           # turas_excel_escape.R
  "turas_write_stats_pack"        # stats_pack_writer.R
)

test_that("import_all.R can be located", {
  expect_false(is.null(SHARED_LIB))
})

test_that("import_all.R defines every function modules rely on", {
  skip_if(is.null(TURAS_ROOT), "Turas root not found")

  missing <- missing_after_import_all(REQUIRED_FUNCTIONS)

  expect_identical(
    missing, character(0),
    info = sprintf("import_all.R did not define: %s",
                   paste(missing, collapse = ", "))
  )
})

test_that("turas_write_stats_pack is available after import_all.R", {
  skip_if(is.null(TURAS_ROOT), "Turas root not found")

  # The specific regression: a caller sources import_all.R and nothing else,
  # then asks for a stats pack.
  expect_identical(missing_after_import_all("turas_write_stats_pack"),
                   character(0))
})

test_that("the import_all.R header lists stats_pack_writer.R", {
  skip_if(is.null(SHARED_LIB), "shared lib not found")

  txt <- readLines(file.path(SHARED_LIB, "import_all.R"), warn = FALSE)
  expect_true(any(grepl("stats_pack_writer.R", txt, fixed = TRUE)))
})
