# ==============================================================================
# TURAS PRICING - A SKIPPED OR REFUSED STEP SHOWS AS PARTIAL (robustness)
# ==============================================================================
#
# Segments, the price ladder and the recommendation each run inside a
# tryCatch so that one failure does not lose the whole workbook. The catch
# must still leave a mark: the Run_Status sheet a client or analyst opens has
# to say PARTIAL and name what is missing, not PASS. Read back from the
# workbook the child run wrote.
# ==============================================================================

source(file.path((function() {
  d <- normalizePath(getwd())
  for (i in 1:10) { if (file.exists(file.path(d, "launch_turas.R"))) return(d); d <- dirname(d) }
  getwd()
})(), "modules", "pricing", "tests", "testthat", "helper_pipeline_fixture.R"))

skip_if_not(file.exists(file.path(pricing_repo_root(), "examples", "pricing", "Karoo_Pricing_Data.xlsx")),
            "examples/pricing/Karoo_Pricing_Data.xlsx is missing")

FAST <- c("cfg$van_westendorp$bootstrap_iterations <- 20",
          "cfg$gabor_granger$bootstrap_iterations <- 20",
          "cfg$monadic$bootstrap_iterations <- 20",
          "cfg$generate_simulator <- FALSE")

run_status <- function(run) {
  x <- pricing_sheet(run$workbook, "Run_Status", colNames = FALSE)
  status <- x$X2[which(x$X1 == "Status")]
  hdr <- which(x$X1 == "Level")
  events <- if (length(hdr)) {
    ev <- x[(hdr + 1):nrow(x), , drop = FALSE]
    ev <- ev[!is.na(ev$X1) & ev$X1 %in% c("PARTIAL", "REFUSE", "INFO"), , drop = FALSE]
    data.frame(level = ev$X1, code = ev$X2, title = ev$X3, problem = ev$X9,
               stringsAsFactors = FALSE)
  } else data.frame(level = character(0), code = character(0), title = character(0),
                    problem = character(0))
  list(status = status, events = events)
}

test_that("a clean run's Run_Status says PASS with no events (control)", {
  r <- pricing_pipeline_run("Karoo_Pricing_Config.xlsx", edits = FAST)
  rs <- run_status(r)
  expect_equal(rs$status, "PASS")
  expect_equal(nrow(rs$events), 0L)
})

test_that("a monadic run given a segment column says PARTIAL and why", {
  # Segments support Van Westendorp and Gabor-Granger only, so the segment
  # step refuses CFG_INVALID_SEGMENT_METHOD inside its catch. The workbook
  # carries no Segment_Comparison sheet; Run_Status must say so.
  r <- pricing_pipeline_run("Karoo_Pricing_Config_Monadic.xlsx",
                            edits = c(FAST, "cfg$segmentation$segment_column <- 'Segment'"))
  expect_false("Segment_Comparison" %in% openxlsx::getSheetNames(r$workbook))
  rs <- run_status(r)
  expect_equal(rs$status, "PARTIAL")
  expect_true(any(rs$events$code == "CFG_INVALID_SEGMENT_METHOD"))
  expect_equal(r$status, "PARTIAL")
})

test_that("a segment below Min_Segment_N says PARTIAL and names the segment", {
  # Karoo after validation: Budget 66, New Customer 52, Premium 87,
  # Standard 151. Min_Segment_N = 60 leaves New Customer out.
  r <- pricing_pipeline_run("Karoo_Pricing_Config.xlsx",
                            edits = c(FAST, "cfg$segmentation$min_segment_n <- 60"))
  sc <- pricing_sheet(r$workbook, "Segment_Comparison")
  expect_false("New Customer" %in% sc$segment)
  rs <- run_status(r)
  expect_equal(rs$status, "PARTIAL")
  hit <- rs$events[rs$events$code == "PRICE_SEGMENTS_SKIPPED", ]
  expect_equal(nrow(hit), 1L)
  expect_match(hit$problem, "New Customer (n=52)", fixed = TRUE)
})

test_that("a segment whose analysis refuses says PARTIAL and names the segment", {
  # A 20-respondent segment passes Min_Segment_N = 10 and then refuses inside
  # the segment loop (Van Westendorp needs 30 complete cases). Its row on the
  # sheet is blank; Run_Status must carry the reason.
  root <- pricing_repo_root()
  d <- openxlsx::read.xlsx(file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx"))
  d$Segment[d$Segment == "New Customer"][1:20] <- "Tiny"
  csv <- tempfile(fileext = ".csv")
  utils::write.csv(d, csv, row.names = FALSE)
  r <- pricing_pipeline_run("Karoo_Pricing_Config.xlsx", data_file = csv,
                            edits = c(FAST, "cfg$segmentation$min_segment_n <- 10"))
  rs <- run_status(r)
  expect_equal(rs$status, "PARTIAL")
  hit <- rs$events[rs$events$code == "PRICE_SEGMENT_REFUSED", ]
  expect_gte(nrow(hit), 1L)
  expect_true(any(grepl("Tiny", hit$problem, fixed = TRUE)))
})

test_that("a refused price ladder says PARTIAL", {
  r <- pricing_pipeline_run("Karoo_Pricing_Config.xlsx",
                            edits = c(FAST, "cfg$price_ladder$n_tiers <- 5L"))
  expect_false("Price_Ladder" %in% openxlsx::getSheetNames(r$workbook))
  rs <- run_status(r)
  expect_equal(rs$status, "PARTIAL")
  expect_true(any(rs$events$code == "CFG_INVALID_N_TIERS"))
})
