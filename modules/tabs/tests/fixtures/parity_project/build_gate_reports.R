# ==============================================================================
# RENDER GATE FIXTURE. Three v2 reports, one per delivery mode
# ==============================================================================
#
# The minification render gate needs a v2 report it can render twice, once as
# built and once minified, and compare cell for cell. It must not depend on
# examples/ output, which is gitignored, rebuilt by hand and was stale by two
# template changes when this was written.
#
# So the reports are built here from the COMMITTED parity fixture islands, the
# ones regenerate_parity_island.R writes from a real pipeline run. No pipeline
# run is needed at gate time and the islands are the same bytes the cross-engine
# parity suites suite already trusts.
#
# Three modes, because they are three different files at runtime:
#   records   respondent island present, live filters recompute from it
#   cube      respondent island absent, the aggregate cube answers filters
#   plain     neither, the published tables only
#   contrib   every contribution island present (conjoint, maxdiff, pricing,
#             qualitative), which is what exercises renderer inclusion. The
#             other three carry none, so they exercise stripping.
#
# Usage:
#   source("modules/tabs/tests/fixtures/parity_project/build_gate_reports.R")
#   paths <- build_gate_reports(tempdir())
# ==============================================================================

#' Source the v2 report bundler and everything it needs
#'
#' @param turas_root Absolute path to the Turas checkout.
#' @keywords internal
gate_load_report_v2 <- function(turas_root) {
  files <- c(
    "modules/shared/lib/trs_refusal.R",
    "modules/tabs/lib/00_guard.R", "modules/tabs/lib/validation_utils.R",
    "modules/tabs/lib/path_utils.R", "modules/tabs/lib/type_utils.R",
    "modules/tabs/lib/logging_utils.R", "modules/tabs/lib/config_utils.R",
    "modules/tabs/lib/excel_utils.R", "modules/tabs/lib/filter_utils.R",
    "modules/tabs/lib/report_shared.R", "modules/tabs/lib/score_utils.R",
    "modules/tabs/lib/data_layer_writer.R",
    "modules/tabs/lib/html_report_v2/build_report_v2.R"
  )
  for (f in files) suppressWarnings(source(file.path(turas_root, f)))
  invisible(TRUE)
}

#' Build the three gate reports
#'
#' @param out_dir Directory to write into. Created if absent.
#' @param turas_root Absolute path to the Turas checkout.
#' @return Named character vector: records, cube, plain. Each an HTML path.
#' @export
build_gate_reports <- function(out_dir,
                               turas_root = Sys.getenv("TURAS_HOME", getwd())) {
  fixture_dir <- file.path(turas_root, "modules", "tabs", "tests", "fixtures",
                           "parity_project")
  read_island <- function(name) {
    paste(readLines(file.path(fixture_dir, name), warn = FALSE), collapse = "\n")
  }
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  if (!exists("write_html_report_v2", mode = "function")) {
    gate_load_report_v2(turas_root)
  }

  agg <- read_island("parity_island.json")
  micro <- read_island("parity_micro.json")
  cube <- read_island("parity_cube.json")

  # The contribution islands, lifted from the synthetic Karoo demo so the gate
  # has a report that needs the conjoint, maxdiff, pricing and qualitative
  # renderers. Without one, module stripping would only ever be tested in the
  # direction that removes things.
  contrib <- jsonlite::fromJSON(
    file.path(fixture_dir, "contribution_islands.json"), simplifyVector = TRUE)
  qual_path <- file.path(turas_root, "modules", "tabs", "tests", "fixtures",
                         "qual_island", "qual_island.json")
  qual <- if (file.exists(qual_path)) {
    paste(readLines(qual_path, warn = FALSE), collapse = "\n")
  } else NULL

  config_obj <- list(
    project_title = "Render gate fixture",
    client_name = "Gate", wave = "Wave 1",
    brand_colour = "#0d8a8a", accent_colour = "#CC9900",
    alpha = 0.05, significance_min_base = 30,
    sampling_method = "Not_Specified", apply_weighting = FALSE
  )

  # Explicit, absolute. report_v2_assets_dir() falls back to a path relative to
  # the working directory, and testthat runs each file from its own directory.
  assets_dir <- file.path(turas_root, "modules", "tabs", "lib", "html_report_v2",
                          "assets")

  build_one <- function(file, ...) {
    path <- file.path(out_dir, file)
    res <- write_html_report_v2(agg, config_obj, path, assets_dir = assets_dir, ...)
    if (!identical(res$status, "PASS")) {
      stop(sprintf("[IO_GATE_FIXTURE] %s did not build: %s", file,
                   res$message %||% res$status))
    }
    path
  }
  if (!exists("%||%", mode = "function")) {
    `%||%` <- function(a, b) if (is.null(a)) b else a
  }

  c(records = build_one("gate_records.html", micro_json = micro),
    cube    = build_one("gate_cube.html", cube_json = cube),
    plain   = build_one("gate_plain.html"),
    contrib = build_one("gate_contrib.html", micro_json = micro,
                        cj_json = contrib$cj, md_json = contrib$md,
                        pr_json = contrib$pr, qual_json = qual))
}
