# ==============================================================================
# BRAND MODULE TESTS - HTML REPORT GENERATION
# ==============================================================================

.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
TURAS_ROOT <- .find_turas_root_for_test()
Sys.setenv(TURAS_ROOT = TURAS_ROOT)

shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}

# Source design system
ds_dir <- file.path(TURAS_ROOT, "modules", "shared", "lib", "design_system")
if (dir.exists(ds_dir)) {
  for (f in c("design_tokens.R", "font_embed.R", "base_css.R")) {
    fp <- file.path(ds_dir, f)
    if (file.exists(fp)) tryCatch(source(fp, local = FALSE), error = function(e) NULL)
  }
}

source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "lib", "html_report",
                 "99_html_report_main.R"))


# --- Mock results reused from test_output.R ---
.create_mock_results <- function() {
  list(
    status = "PASS",
    config = list(
      project_name = "Test Project", client_name = "Client",
      focal_brand = "IPK", wave = 1, study_type = "cross-sectional",
      colour_focal = "#1A5276", colour_focal_accent = "#2E86C1",
      report_title = "IPK Brand Health", report_subtitle = "Wave 1 Baseline",
      show_about_section = TRUE
    ),
    results = list(
      categories = list(
        "Frozen Veg" = list(
          category = "Frozen Veg",
          mental_availability = list(
            status = "PASS",
            mms = data.frame(BrandCode = c("IPK", "MC"),
                             MMS = c(0.6, 0.4), Total_Links = c(60, 40),
                             stringsAsFactors = FALSE),
            mpen = data.frame(BrandCode = c("IPK", "MC"),
                              MPen = c(0.7, 0.5), stringsAsFactors = FALSE),
            ns = data.frame(BrandCode = c("IPK", "MC"),
                            NS = c(3.2, 2.1), NS_Base = c(70, 50),
                            stringsAsFactors = FALSE),
            cep_brand_matrix = data.frame(CEPCode = c("C1", "C2"),
                                          IPK = c(45, 30), MC = c(35, 25),
                                          stringsAsFactors = FALSE),
            cep_penetration = data.frame(CEPCode = c("C1", "C2"),
                                          Penetration_Pct = c(65, 50),
                                          Rank = 1:2, stringsAsFactors = FALSE),
            cep_turf = list(
              incremental_table = data.frame(
                Step = 1:2, Item_ID = c("C1", "C2"),
                Item_Label = c("CEP 1", "CEP 2"),
                Reach_Pct = c(65, 85), Incremental_Pct = c(65, 20),
                Frequency = c(1.0, 1.3), stringsAsFactors = FALSE
              )
            ),
            metrics_summary = list(
              focal_brand = "IPK", focal_mms = 0.6, focal_mpen = 0.7,
              focal_ns = 3.2, mms_rank = 1, n_brands = 2
            ),
            n_respondents = 200
          ),
          funnel = list(
            status = "PASS",
            stage_metrics = data.frame(
              BrandCode = c("IPK", "MC"),
              Aware_Pct = c(85, 70), Positive_Pct = c(55, 40),
              Love_Pct = c(20, 15), Prefer_Pct = c(25, 20),
              Ambivalent_Pct = c(10, 5), Reject_Pct = c(5, 8),
              NoOpinion_Pct = c(25, 27),
              Bought_Pct = c(45, 30), Primary_Pct = c(20, 15),
              Base_n = c(200, 200), stringsAsFactors = FALSE
            ),
            conversion_metrics = data.frame(
              BrandCode = c("IPK", "MC"),
              Aware_to_Positive = c(64.7, 57.1),
              Positive_to_Bought = c(81.8, 75.0),
              Bought_to_Primary = c(44.4, 50.0),
              stringsAsFactors = FALSE
            ),
            metrics_summary = list(
              focal_brand = "IPK", focal_aware = 85, focal_positive = 55,
              focal_bought = 45, focal_reject = 5
            ),
            n_respondents = 200
          ),
          repertoire = list(
            status = "PASS",
            repertoire_size = data.frame(
              Brands_Bought = c("1", "2"), Count = c(80, 60),
              Percentage = c(57.1, 42.9), stringsAsFactors = FALSE
            ),
            mean_repertoire = 1.4,
            sole_loyalty = data.frame(
              BrandCode = c("IPK", "MC"),
              SoleLoyalty_Pct = c(25, 30), Brand_Buyers_n = c(90, 60),
              stringsAsFactors = FALSE
            ),
            brand_overlap = data.frame(
              BrandCode = "MC", Overlap_Pct = 45, stringsAsFactors = FALSE
            ),
            n_respondents = 200, n_buyers = 140
          )
        )
      ),
      wom = list(
        status = "PASS",
        wom_metrics = data.frame(
          BrandCode = c("IPK", "MC"),
          ReceivedPos_Pct = c(15, 12), ReceivedNeg_Pct = c(3, 5),
          SharedPos_Pct = c(10, 8), SharedNeg_Pct = c(1, 2),
          SharedPosFreq_Mean = c(2.5, 2.1), SharedNegFreq_Mean = c(1.5, 1.2),
          stringsAsFactors = FALSE
        ),
        net_balance = data.frame(
          BrandCode = c("IPK", "MC"),
          Net_Received = c(12, 7), Net_Shared = c(9, 6),
          stringsAsFactors = FALSE
        )
      )
    )
  )
}


# ==============================================================================
# TESTS
# ==============================================================================

test_that("generate_brand_html_report creates valid HTML file", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  output <- generate_brand_html_report(results, tmp, results$config)

  expect_equal(output$status, "PASS")
  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 1000)  # Should be substantial
})

test_that("HTML contains DOCTYPE and meta tags", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("<!DOCTYPE html>", html))
  expect_true(grepl('turas-report-type.*content="brand"', html))
  expect_true(grepl("<title>", html))
})

test_that("HTML contains report header with project info", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("IPK Brand Health", html))
  expect_true(grepl("Wave 1 Baseline", html))
  expect_true(grepl("Client", html))
  expect_true(grepl("IPK", html))
})

test_that("HTML contains Mental Availability section", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("Mental Availability", html))
  expect_true(grepl("Mental Market Share", html))
  expect_true(grepl("Mental Penetration", html))
  expect_true(grepl("Network Size", html))
  expect_true(grepl("CEP.*Brand.*Linkage", html))
})

test_that("HTML contains Funnel section", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("Brand Funnel", html))
  expect_true(grepl("Aided Awareness", html))
  expect_true(grepl("Positive Disposition", html))
  expect_true(grepl("Conversion", html))
})

test_that("HTML contains WOM section", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("Word-of-Mouth", html))
  expect_true(grepl("Net WOM Balance", html))
})

test_that("HTML contains About section", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("About.*Methodology", html))
  expect_true(grepl("Romaniuk", html))
  expect_true(grepl("Ehrenberg-Bass", html))
})

test_that("HTML contains TurasPins data container", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("pinned-views-data", html))
})

test_that("HTML highlights focal brand rows", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("focal-row", html))
})

test_that("HTML creates output directory if needed", {
  tmp_dir <- file.path(tempdir(), "brand_html_subdir")
  tmp <- file.path(tmp_dir, "report.html")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  results <- .create_mock_results()
  output <- generate_brand_html_report(results, tmp, results$config)

  expect_equal(output$status, "PASS")
  expect_true(dir.exists(tmp_dir))
})

test_that("HTML report refuses NULL results", {
  result <- generate_brand_html_report(NULL, tempfile())
  expect_equal(result$status, "REFUSED")
})

test_that("HTML report refuses REFUSED results", {
  result <- generate_brand_html_report(
    list(status = "REFUSED"), tempfile()
  )
  expect_equal(result$status, "REFUSED")
})

test_that("HTML contains valid CSS styles", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  expect_true(grepl("<style>", html))
  expect_true(grepl("metric-card", html))
  expect_true(grepl("element-section", html))
})

test_that("HTML uses brand colour from config", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_html_report(results, tmp, results$config)

  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  # Brand colour should appear in CSS
  expect_true(grepl("#1A5276", html))
})
