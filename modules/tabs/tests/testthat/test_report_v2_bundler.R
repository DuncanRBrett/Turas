# ==============================================================================
# TABS MODULE - DATA-CENTRIC REPORT v2 BUNDLER TESTS
# ==============================================================================
#
# Tests the inliner (modules/tabs/lib/html_report_v2/build_report_v2.R):
#   - bundle_report_v2_js() ordering + safety
#   - build_report_v2_html() token filling, island escaping, self-containment
#   - write_html_report_v2() end-to-end on a real data layer
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_report_v2_bundler.R")
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

.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report/99_html_report_main.R"))
source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_layer_writer.R"))
source(file.path(turas_root, "modules/tabs/lib/html_report_v2/build_report_v2.R"))

assets_dir <- file.path(turas_root, "modules/tabs/lib/html_report_v2/assets")

# ==============================================================================
# FIXTURES (self-contained, matching the house test pattern)
# ==============================================================================

make_dl_banner_info <- function() {
  list(
    columns = c("Total", "Male", "Female"),
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("-", "A", "B"),
    column_to_banner = c("TOTAL::Total" = "TOTAL",
                         "Gender::Male" = "Gender", "Gender::Female" = "Gender"),
    key_to_display = c("TOTAL::Total" = "Total",
                       "Gender::Male" = "Male", "Gender::Female" = "Female"),
    banner_headers = data.frame(
      label = c("Total", "Gender"), start_col = c(1, 2), end_col = c(1, 3),
      stringsAsFactors = FALSE),
    banner_info = list(Gender = list(
      internal_keys = c("Gender::Male", "Gender::Female"),
      columns = c("Male", "Female"), letters = c("A", "B"),
      question = data.frame(QuestionCode = "Gender", QuestionText = "Gender",
                            stringsAsFactors = FALSE))))
}

make_dl_q_single <- function() {
  list(
    question_code = "Q1", question_text = "Are you aware?",
    question_type = "Single_Choice", category = "Awareness",
    table = data.frame(
      RowLabel  = c("Yes", "Yes", "Yes", "No", "No", "No"),
      RowType   = c("Frequency", "Column %", "Sig.", "Frequency", "Column %", "Sig."),
      RowSource = rep("individual", 6),
      "TOTAL::Total"   = c("60", "60.0", "", "40", "40.0", ""),
      "Gender::Male"   = c("35", "70.0", "B", "15", "30.0", ""),
      "Gender::Female" = c("25", "50.0", "", "25", "50.0", "A"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 100, weighted = 100, effective = 100),
      "Gender::Male"   = list(unweighted = 50,  weighted = 50,  effective = 50),
      "Gender::Female" = list(unweighted = 50,  weighted = 50,  effective = 50)))
}

make_dl_results <- function() list(Q1 = make_dl_q_single())

make_dl_config <- function(...) {
  modifyList(list(
    project_title = "Test Survey", client_name = "Acme", wave = "Wave 1",
    brand_colour = "#323367", accent_colour = "#CC9900",
    alpha = 0.05, significance_min_base = 30,
    sampling_method = "Not_Specified", apply_weighting = FALSE), list(...))
}

# ==============================================================================
# 1. JS bundle
# ==============================================================================

context("report_v2_bundler: JS bundle")

test_that("bundles all 29 modules with the engine first and no </script", {
  js <- bundle_report_v2_js(assets_dir)
  expect_true(nchar(js) > 50000)
  expect_false(grepl("</script", js, fixed = TRUE))
  # 00_namespace (engine) must precede 20_data (v2)
  expect_true(regexpr("TR.CONST", js, fixed = TRUE) <
              regexpr("d2.validate", js, fixed = TRUE))
})

# ==============================================================================
# 2. HTML build
# ==============================================================================

context("report_v2_bundler: HTML build")

test_that("fills every token and embeds the data island", {
  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(),
                         make_dl_config(project_title = "Acme Wave 1"))
  json <- serialize_data_layer(dl)
  html <- build_report_v2_html(json, make_dl_config(project_title = "Acme Wave 1"),
                               assets_dir, generated = "2026-06-13 00:00 SAST")

  expect_false(grepl("\\{\\{[A-Z_]+\\}\\}", html))       # no leftover tokens
  expect_true(grepl("Acme Wave 1", html, fixed = TRUE))  # title
  expect_true(grepl("data-agg", html, fixed = TRUE))     # island present
  expect_true(grepl("\"schema_version\":2", html, fixed = TRUE))
  # empty islands inlined as null
  expect_true(grepl('id="data-micro">\nnull', html) || grepl("null", html, fixed = TRUE))
  # self-contained — no external resources
  expect_false(grepl('(src|href)="https?://', html))
})

test_that("escapes </ inside the embedded JSON so it cannot break the script", {
  q <- make_dl_q_single()
  q$question_text <- "Closing tag </script> attempt"
  dl <- build_data_layer(list(Q1 = q), make_dl_banner_info(), make_dl_config())
  json <- serialize_data_layer(dl)
  html <- build_report_v2_html(json, make_dl_config(), assets_dir)
  # the literal </script must not survive inside the data island
  expect_false(grepl("</script> attempt", html, fixed = TRUE))
  expect_true(grepl("<\\/script", html, fixed = TRUE))
})

# ==============================================================================
# 3. write end-to-end
# ==============================================================================

context("report_v2_bundler: write")

test_that("writes a self-contained report file", {
  out <- file.path(tempdir(), "test_report_v2.html")
  if (file.exists(out)) unlink(out)

  dl <- build_data_layer(make_dl_results(), make_dl_banner_info(), make_dl_config())
  res <- write_html_report_v2(serialize_data_layer(dl), make_dl_config(), out, assets_dir)

  expect_equal(res$status, "PASS")
  expect_true(file.exists(out))
  expect_true(res$file_size_mb > 0)

  written <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_true(grepl("data-agg", written, fixed = TRUE))
  expect_true(grepl("TR.CONST", written, fixed = TRUE))    # engine inlined
  expect_false(grepl('(src|href)="https?://', written))    # offline
  unlink(out)
})

test_that("refuses an empty data layer", {
  res <- write_html_report_v2("", make_dl_config(),
                              file.path(tempdir(), "x.html"), assets_dir)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_LAYER_EMPTY")
})

# ==============================================================================
# 4. additive-only contract — v2 never clobbers the classic outputs
# ==============================================================================

context("report_v2_bundler: additive-only output paths")

test_that("v2 output paths can never collide with the classic outputs", {
  # Mirrors run_crosstabs Step 4d / 4b path derivation from one base .xlsx
  output_path  <- "/proj/MyStudy.xlsx"
  classic_xlsx <- output_path
  classic_html <- sub("\\.xlsx$", ".html", output_path)
  v2_report    <- sub("\\.xlsx$", "_report_v2.html", output_path)
  v2_json      <- sub("\\.xlsx$", "_data.json", output_path)

  paths <- c(classic_xlsx, classic_html, v2_report, v2_json)
  expect_equal(length(unique(paths)), 4)             # all distinct
  expect_false(v2_report %in% c(classic_xlsx, classic_html))
  expect_false(v2_json %in% c(classic_xlsx, classic_html))
})

# ==============================================================================
# question_mapping resolution (tabs-tracker)
# ==============================================================================

context("report_v2_bundler: question_mapping resolution")

test_that("resolve_question_mapping finds an explicit path and auto-detects a folder", {
  dir <- tempfile("qm_"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  qm <- file.path(dir, "Proj_Question_Mapping.xlsx"); file.create(qm)
  # explicit absolute path
  expect_equal(normalizePath(resolve_question_mapping(qm, "", dirname(dir),
                                                      file.path(dir, "c.xlsx"))),
               normalizePath(qm))
  # blank -> auto-detected in waves_source
  expect_equal(normalizePath(resolve_question_mapping("", dir, "/nope", "/nope/c.xlsx")),
               normalizePath(qm))
  # nothing configured and nothing to find
  expect_equal(resolve_question_mapping("", "/no/dir", "/no/dir", "/no/dir/c.xlsx"), "")
})
