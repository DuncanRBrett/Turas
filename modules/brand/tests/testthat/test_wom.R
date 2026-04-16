# ==============================================================================
# BRAND MODULE TESTS - WOM ELEMENT
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
source(file.path(TURAS_ROOT, "modules", "brand", "R", "05_wom.R"))


# --- Test data generator ---
generate_wom_test_data <- function(n_resp = 100, n_brands = 4, seed = 42) {
  set.seed(seed)
  brand_codes <- paste0("B", seq_len(n_brands))
  data <- data.frame(Respondent_ID = seq_len(n_resp))

  for (brand in brand_codes) {
    data[[paste0("WOMPR_", brand)]] <- rbinom(n_resp, 1, 0.15)
    data[[paste0("WOMNR_", brand)]] <- rbinom(n_resp, 1, 0.05)
    data[[paste0("WOMPS_", brand)]] <- rbinom(n_resp, 1, 0.10)
    data[[paste0("WOMNS_", brand)]] <- rbinom(n_resp, 1, 0.03)
    # Frequency (1-5 for sharers, 0 for non-sharers)
    shared_pos <- data[[paste0("WOMPS_", brand)]]
    data[[paste0("WOMPF_", brand)]] <- ifelse(shared_pos == 1,
                                               sample(1:5, n_resp, replace = TRUE),
                                               0)
    shared_neg <- data[[paste0("WOMNS_", brand)]]
    data[[paste0("WOMNF_", brand)]] <- ifelse(shared_neg == 1,
                                               sample(1:3, n_resp, replace = TRUE),
                                               0)
  }

  list(data = data, brand_codes = brand_codes)
}


# ==============================================================================
# CORE TESTS
# ==============================================================================

test_that("run_wom produces complete output structure", {
  td <- generate_wom_test_data()

  result <- run_wom(
    td$data, td$brand_codes,
    received_pos_prefix = "WOMPR",
    received_neg_prefix = "WOMNR",
    shared_pos_prefix = "WOMPS",
    shared_neg_prefix = "WOMNS",
    shared_pos_freq_prefix = "WOMPF",
    shared_neg_freq_prefix = "WOMNF",
    focal_brand = "B1"
  )

  expect_equal(result$status, "PASS")
  expect_true(is.data.frame(result$wom_metrics))
  expect_true(is.data.frame(result$net_balance))
  expect_true(is.data.frame(result$amplification))
  expect_true(is.list(result$metrics_summary))
  expect_equal(result$n_brands, 4)
})

test_that("run_wom known data: percentages correct", {
  data <- data.frame(
    WOMPR_A = c(1, 1, 0, 0, 0),   # 40% received positive
    WOMNR_A = c(0, 0, 1, 0, 0),   # 20% received negative
    WOMPS_A = c(1, 0, 0, 0, 0),   # 20% shared positive
    WOMNS_A = c(0, 0, 0, 0, 0)    # 0% shared negative
  )

  result <- run_wom(data, "A",
                    received_pos_prefix = "WOMPR",
                    received_neg_prefix = "WOMNR",
                    shared_pos_prefix = "WOMPS",
                    shared_neg_prefix = "WOMNS")

  expect_equal(result$wom_metrics$ReceivedPos_Pct, 40)
  expect_equal(result$wom_metrics$ReceivedNeg_Pct, 20)
  expect_equal(result$wom_metrics$SharedPos_Pct, 20)
  expect_equal(result$wom_metrics$SharedNeg_Pct, 0)
})

test_that("run_wom net balance correct", {
  data <- data.frame(
    WOMPR_A = c(1, 1, 1, 0, 0),   # 60% received pos
    WOMNR_A = c(0, 0, 1, 1, 0),   # 40% received neg
    WOMPS_A = c(1, 0, 0, 0, 0),
    WOMNS_A = c(0, 0, 0, 0, 0)
  )

  result <- run_wom(data, "A",
                    received_pos_prefix = "WOMPR",
                    received_neg_prefix = "WOMNR",
                    shared_pos_prefix = "WOMPS",
                    shared_neg_prefix = "WOMNS")

  # Net received: 60 - 40 = 20
  expect_equal(result$net_balance$Net_Received, 20)
})

test_that("run_wom amplification ratio correct", {
  data <- data.frame(
    WOMPR_A = c(1, 1, 1, 1, 0),   # 80% received pos
    WOMNR_A = c(0, 0, 0, 0, 0),
    WOMPS_A = c(1, 1, 0, 0, 0),   # 40% shared pos
    WOMNS_A = c(0, 0, 0, 0, 0)
  )

  result <- run_wom(data, "A",
                    received_pos_prefix = "WOMPR",
                    received_neg_prefix = "WOMNR",
                    shared_pos_prefix = "WOMPS",
                    shared_neg_prefix = "WOMNS")

  # Amplification: 40/80 = 0.5
  expect_equal(result$amplification$Amplification_Ratio, 0.5)
})

test_that("run_wom metrics_summary identifies negative brands", {
  data <- data.frame(
    WOMPR_A = c(0, 0, 0),  # 0% pos
    WOMNR_A = c(1, 1, 0),  # 67% neg
    WOMPS_A = c(0, 0, 0),
    WOMNS_A = c(0, 0, 0),
    WOMPR_B = c(1, 1, 1),  # 100% pos
    WOMNR_B = c(0, 0, 0),  # 0% neg
    WOMPS_B = c(1, 0, 0),
    WOMNS_B = c(0, 0, 0)
  )

  result <- run_wom(data, c("A", "B"),
                    received_pos_prefix = "WOMPR",
                    received_neg_prefix = "WOMNR",
                    shared_pos_prefix = "WOMPS",
                    shared_neg_prefix = "WOMNS",
                    focal_brand = "A")

  expect_true(result$metrics_summary$any_net_negative)
  expect_equal(result$metrics_summary$most_negative_brand, "A")
  expect_equal(result$metrics_summary$most_positive_brand, "B")
})

test_that("run_wom refuses empty data", {
  result <- run_wom(data.frame(), "A", "P", "N", "SP", "SN")
  expect_equal(result$status, "REFUSED")
})

test_that("run_wom with weights", {
  data <- data.frame(
    WOMPR_A = c(1, 0),
    WOMNR_A = c(0, 0),
    WOMPS_A = c(0, 0),
    WOMNS_A = c(0, 0)
  )

  # Unweighted: 50% received positive
  result_unw <- run_wom(data, "A", "WOMPR", "WOMNR", "WOMPS", "WOMNS")
  expect_equal(result_unw$wom_metrics$ReceivedPos_Pct, 50)

  # Weighted: resp 1 weight=3, resp 2 weight=1 -> 75%
  result_wtd <- run_wom(data, "A", "WOMPR", "WOMNR", "WOMPS", "WOMNS",
                        weights = c(3, 1))
  expect_equal(result_wtd$wom_metrics$ReceivedPos_Pct, 75)
})

test_that("run_wom frequency mean only among sharers", {
  data <- data.frame(
    WOMPR_A = c(1, 1, 0),
    WOMNR_A = c(0, 0, 0),
    WOMPS_A = c(1, 1, 0),    # 2 sharers
    WOMNS_A = c(0, 0, 0),
    WOMPF_A = c(3, 5, 0),    # freq: 3 and 5 among sharers -> mean 4
    WOMNF_A = c(0, 0, 0)
  )

  result <- run_wom(data, "A", "WOMPR", "WOMNR", "WOMPS", "WOMNS",
                    shared_pos_freq_prefix = "WOMPF",
                    shared_neg_freq_prefix = "WOMNF")

  expect_equal(result$wom_metrics$SharedPosFreq_Mean, 4)
})
