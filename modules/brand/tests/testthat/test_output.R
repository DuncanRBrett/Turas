# ==============================================================================
# BRAND MODULE TESTS - OUTPUT GENERATION
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
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "99_output.R"))


# --- Create mock results for output testing ---
.create_mock_results <- function() {
  list(
    status = "PASS",
    config = list(
      project_name = "Test Project",
      client_name = "Client",
      focal_brand = "IPK",
      wave = 1,
      study_type = "cross-sectional"
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
                              MPen = c(0.7, 0.5),
                              stringsAsFactors = FALSE),
            ns = data.frame(BrandCode = c("IPK", "MC"),
                            NS = c(3.2, 2.1), NS_Base = c(70, 50),
                            stringsAsFactors = FALSE),
            cep_brand_matrix = data.frame(CEPCode = c("C1", "C2"),
                                          IPK = c(45, 30), MC = c(35, 25),
                                          stringsAsFactors = FALSE),
            cep_penetration = data.frame(CEPCode = c("C1", "C2"),
                                          Penetration_Pct = c(65, 50),
                                          Rank = 1:2,
                                          stringsAsFactors = FALSE),
            cep_turf = list(
              incremental_table = data.frame(
                Step = 1:2, Item_ID = c("C1", "C2"),
                Item_Label = c("CEP 1", "CEP 2"),
                Reach_Pct = c(65, 85),
                Incremental_Pct = c(65, 20),
                Frequency = c(1.0, 1.3),
                stringsAsFactors = FALSE
              )
            )
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
              Base_n = c(200, 200),
              stringsAsFactors = FALSE
            ),
            conversion_metrics = data.frame(
              BrandCode = c("IPK", "MC"),
              Aware_to_Positive = c(64.7, 57.1),
              Positive_to_Bought = c(81.8, 75.0),
              Bought_to_Primary = c(44.4, 50.0),
              stringsAsFactors = FALSE
            )
          ),
          repertoire = list(
            status = "PASS",
            repertoire_size = data.frame(
              Brands_Bought = c("1", "2", "3+"),
              Count = c(80, 60, 40),
              Percentage = c(44.4, 33.3, 22.2),
              stringsAsFactors = FALSE
            ),
            sole_loyalty = data.frame(
              BrandCode = c("IPK", "MC"),
              SoleLoyalty_Pct = c(25, 30),
              Brand_Buyers_n = c(90, 60),
              stringsAsFactors = FALSE
            ),
            brand_overlap = data.frame(
              BrandCode = "MC", Overlap_Pct = 45,
              stringsAsFactors = FALSE
            )
          )
        )
      ),
      wom = list(
        status = "PASS",
        wom_metrics = data.frame(
          BrandCode = c("IPK", "MC"),
          ReceivedPos_Pct = c(15, 12),
          ReceivedNeg_Pct = c(3, 5),
          SharedPos_Pct = c(10, 8),
          SharedNeg_Pct = c(1, 2),
          SharedPosFreq_Mean = c(2.5, 2.1),
          SharedNegFreq_Mean = c(1.5, 1.2),
          stringsAsFactors = FALSE
        ),
        net_balance = data.frame(
          BrandCode = c("IPK", "MC"),
          Net_Received = c(12, 7),
          Net_Shared = c(9, 6),
          stringsAsFactors = FALSE
        ),
        amplification = data.frame(
          BrandCode = c("IPK", "MC"),
          Amplification_Ratio = c(0.67, 0.67),
          stringsAsFactors = FALSE
        )
      )
    )
  )
}


# ==============================================================================
# EXCEL OUTPUT TESTS
# ==============================================================================

test_that("generate_brand_excel creates valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  output <- generate_brand_excel(results, tmp, results$config)

  expect_equal(output$status, "PASS")
  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
})

test_that("Excel output has expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_excel(results, tmp, results$config)

  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Project_Info" %in% sheets)
  # Per-category sheets (prefix from category name)
  expect_true(any(grepl("MMS", sheets)))
  expect_true(any(grepl("Funnel", sheets)))
  expect_true(any(grepl("Rep_Size", sheets)))
  # Brand-level sheets
  expect_true("WOM_Metrics" %in% sheets)
})

test_that("Excel MMS sheet has correct data", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  results <- .create_mock_results()
  generate_brand_excel(results, tmp, results$config)

  mms_sheet <- openxlsx::getSheetNames(tmp)
  mms_sheet <- mms_sheet[grepl("MMS", mms_sheet)][1]
  mms_data <- openxlsx::read.xlsx(tmp, sheet = mms_sheet, startRow = 3)

  expect_true(nrow(mms_data) >= 2)
  expect_true("BrandCode" %in% names(mms_data))
  expect_true("MMS" %in% names(mms_data))
})

test_that("Excel creates output directory if needed", {
  tmp_dir <- file.path(tempdir(), "brand_excel_subdir")
  tmp <- file.path(tmp_dir, "output.xlsx")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  results <- .create_mock_results()
  output <- generate_brand_excel(results, tmp, results$config)

  expect_equal(output$status, "PASS")
  expect_true(dir.exists(tmp_dir))
  expect_true(file.exists(tmp))
})


# ==============================================================================
# CSV OUTPUT TESTS
# ==============================================================================

test_that("generate_brand_csv creates CSV files", {
  tmp_dir <- file.path(tempdir(), "brand_csv_test")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  results <- .create_mock_results()
  output <- generate_brand_csv(results, tmp_dir, results$config)

  expect_equal(output$status, "PASS")
  expect_true(output$n_files > 0)
  expect_true(dir.exists(tmp_dir))

  # Should have per-category files
  csv_files <- list.files(tmp_dir, pattern = "\\.csv$")
  expect_true(length(csv_files) > 0)
  expect_true(any(grepl("mms", csv_files)))
  expect_true(any(grepl("funnel", csv_files)))
})

test_that("CSV files are valid and readable", {
  tmp_dir <- file.path(tempdir(), "brand_csv_valid")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  results <- .create_mock_results()
  output <- generate_brand_csv(results, tmp_dir)

  # Read back a CSV and verify
  for (f in output$files_written[1:min(3, length(output$files_written))]) {
    df <- read.csv(f, stringsAsFactors = FALSE)
    expect_true(nrow(df) > 0)
    expect_true(ncol(df) > 0)
  }
})

test_that("CSV output includes WOM file", {
  tmp_dir <- file.path(tempdir(), "brand_csv_wom")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  results <- .create_mock_results()
  output <- generate_brand_csv(results, tmp_dir)

  csv_files <- list.files(tmp_dir, pattern = "\\.csv$")
  expect_true(any(grepl("wom", csv_files)))
})
