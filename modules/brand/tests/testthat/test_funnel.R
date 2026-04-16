# ==============================================================================
# BRAND MODULE TESTS - FUNNEL ELEMENT
# ==============================================================================

# --- Setup ---
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
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03_funnel.R"))


# --- Test data generator ---
generate_funnel_test_data <- function(n_resp = 200, n_brands = 5, seed = 42) {
  set.seed(seed)

  brand_codes <- paste0("B", seq_len(n_brands))
  # Double Jeopardy: bigger brands have higher awareness AND conversion
  brand_size <- sort(runif(n_brands, 0.2, 0.9), decreasing = TRUE)

  data <- data.frame(Respondent_ID = seq_len(n_resp))

  for (b in seq_along(brand_codes)) {
    brand <- brand_codes[b]
    size <- brand_size[b]

    # Awareness (binary)
    aware <- rbinom(n_resp, 1, size)
    data[[paste0("AWARE_", brand)]] <- aware

    # Attitude (1-5, conditional on awareness)
    att <- rep(NA_integer_, n_resp)
    for (r in which(aware == 1)) {
      # Probabilities: Love, Prefer, Ambivalent, Reject, NoOpinion
      probs <- c(size * 0.3, 0.25, 0.20, 0.05 + (1 - size) * 0.1,
                 0.10 + (1 - size) * 0.15)
      probs <- probs / sum(probs)
      att[r] <- sample(1:5, 1, prob = probs)
    }
    data[[paste0("ATT_", brand)]] <- att

    # Penetration (binary, correlated with positive attitude)
    pen <- rep(0L, n_resp)
    for (r in seq_len(n_resp)) {
      if (aware[r] == 1 && !is.na(att[r]) && att[r] <= 3) {
        pen[r] <- rbinom(1, 1, size * 0.6)
      }
    }
    data[[paste0("PEN_", brand)]] <- pen
  }

  brands <- data.frame(
    BrandCode = brand_codes,
    BrandLabel = paste("Brand", LETTERS[seq_len(n_brands)]),
    DisplayOrder = seq_len(n_brands),
    IsFocal = c("Y", rep("N", n_brands - 1)),
    stringsAsFactors = FALSE
  )

  list(data = data, brands = brands, brand_codes = brand_codes)
}


# ==============================================================================
# derive_funnel_stages TESTS
# ==============================================================================

test_that("derive_funnel_stages returns correct structure", {
  td <- generate_funnel_test_data()

  stages <- derive_funnel_stages(
    td$data, td$brands,
    awareness_prefix = "AWARE",
    attitude_prefix = "ATT",
    penetration_prefix = "PEN"
  )

  expect_equal(ncol(stages$awareness), 5)
  expect_equal(nrow(stages$awareness), 200)
  expect_true(is.logical(stages$awareness))
  expect_true(is.logical(stages$positive_disposition))
  expect_true(is.logical(stages$love))
  expect_true(is.logical(stages$reject))
  expect_true(is.logical(stages$bought))
  expect_true(is.logical(stages$primary))
  expect_equal(length(stages$brand_codes), 5)
})

test_that("derive_funnel_stages attitude decomposition is exhaustive", {
  td <- generate_funnel_test_data()

  stages <- derive_funnel_stages(
    td$data, td$brands,
    awareness_prefix = "AWARE",
    attitude_prefix = "ATT",
    penetration_prefix = "PEN"
  )

  # For each respondent-brand pair with an attitude code,
  # exactly one of the 5 decomposition categories should be TRUE
  for (b in 1:5) {
    has_att <- !is.na(stages$attitude[, b])
    decomp_sum <- stages$love[has_att, b] +
                  stages$prefer[has_att, b] +
                  stages$ambivalent[has_att, b] +
                  stages$reject[has_att, b] +
                  stages$no_opinion[has_att, b]
    expect_true(all(decomp_sum == 1),
                info = sprintf("Brand %d has respondents with != 1 attitude code", b))
  }
})

test_that("derive_funnel_stages positive = love + prefer + ambivalent", {
  td <- generate_funnel_test_data()

  stages <- derive_funnel_stages(
    td$data, td$brands,
    awareness_prefix = "AWARE",
    attitude_prefix = "ATT",
    penetration_prefix = "PEN"
  )

  for (b in 1:5) {
    expected_positive <- stages$love[, b] | stages$prefer[, b] |
                         stages$ambivalent[, b]
    expect_equal(stages$positive_disposition[, b], expected_positive)
  }
})

test_that("derive_funnel_stages primary = love when attitudinal method", {
  td <- generate_funnel_test_data()

  stages <- derive_funnel_stages(
    td$data, td$brands,
    awareness_prefix = "AWARE",
    attitude_prefix = "ATT",
    penetration_prefix = "PEN",
    primary_method = "attitudinal"
  )

  for (b in 1:5) {
    expect_equal(stages$primary[, b], stages$love[, b])
  }
})

test_that("derive_funnel_stages handles missing columns gracefully", {
  data <- data.frame(
    AWARE_B1 = c(1, 0, 1),
    ATT_B1 = c(1, NA, 3)
    # No PEN_B1 column
  )
  brands <- data.frame(BrandCode = "B1", stringsAsFactors = FALSE)

  stages <- derive_funnel_stages(data, brands,
                                  awareness_prefix = "AWARE",
                                  attitude_prefix = "ATT",
                                  penetration_prefix = "PEN")

  # Awareness should work
  expect_equal(stages$awareness[, 1], c(TRUE, FALSE, TRUE))

  # Attitude should work
  expect_equal(stages$love[, 1], c(TRUE, FALSE, FALSE))
  expect_equal(stages$ambivalent[, 1], c(FALSE, FALSE, TRUE))

  # Penetration should be all FALSE (column not found)
  expect_true(all(!stages$bought[, 1]))
})


# ==============================================================================
# calculate_funnel_metrics TESTS
# ==============================================================================

test_that("calculate_funnel_metrics produces correct percentages", {
  # 4 respondents, 1 brand
  stages <- list(
    awareness = matrix(c(TRUE, TRUE, TRUE, FALSE), ncol = 1),
    positive_disposition = matrix(c(TRUE, TRUE, FALSE, FALSE), ncol = 1),
    love = matrix(c(TRUE, FALSE, FALSE, FALSE), ncol = 1),
    prefer = matrix(c(FALSE, TRUE, FALSE, FALSE), ncol = 1),
    ambivalent = matrix(c(FALSE, FALSE, FALSE, FALSE), ncol = 1),
    reject = matrix(c(FALSE, FALSE, TRUE, FALSE), ncol = 1),
    no_opinion = matrix(c(FALSE, FALSE, FALSE, FALSE), ncol = 1),
    bought = matrix(c(TRUE, TRUE, FALSE, FALSE), ncol = 1),
    primary = matrix(c(TRUE, FALSE, FALSE, FALSE), ncol = 1),
    brand_codes = "A",
    n_respondents = 4
  )
  colnames(stages$awareness) <- colnames(stages$bought) <- "A"

  metrics <- calculate_funnel_metrics(stages)

  expect_equal(metrics$stage_metrics$Aware_Pct, 75)      # 3/4
  expect_equal(metrics$stage_metrics$Positive_Pct, 50)    # 2/4
  expect_equal(metrics$stage_metrics$Love_Pct, 25)        # 1/4
  expect_equal(metrics$stage_metrics$Prefer_Pct, 25)      # 1/4
  expect_equal(metrics$stage_metrics$Reject_Pct, 25)      # 1/4
  expect_equal(metrics$stage_metrics$Bought_Pct, 50)      # 2/4
  expect_equal(metrics$stage_metrics$Primary_Pct, 25)     # 1/4
})

test_that("calculate_funnel_metrics conversion ratios correct", {
  stages <- list(
    awareness = matrix(c(TRUE, TRUE, TRUE, TRUE), ncol = 1),      # 100%
    positive_disposition = matrix(c(TRUE, TRUE, FALSE, FALSE), ncol = 1),  # 50%
    love = matrix(c(TRUE, FALSE, FALSE, FALSE), ncol = 1),
    prefer = matrix(c(FALSE, TRUE, FALSE, FALSE), ncol = 1),
    ambivalent = matrix(FALSE, nrow = 4, ncol = 1),
    reject = matrix(FALSE, nrow = 4, ncol = 1),
    no_opinion = matrix(c(FALSE, FALSE, TRUE, TRUE), ncol = 1),
    bought = matrix(c(TRUE, FALSE, FALSE, FALSE), ncol = 1),      # 25%
    primary = matrix(c(TRUE, FALSE, FALSE, FALSE), ncol = 1),     # 25%
    brand_codes = "A",
    n_respondents = 4
  )

  metrics <- calculate_funnel_metrics(stages)

  # Aware → Positive: 50/100 = 50%
  expect_equal(metrics$conversion_metrics$Aware_to_Positive, 50)
  # Positive → Bought: 25/50 = 50%
  expect_equal(metrics$conversion_metrics$Positive_to_Bought, 50)
  # Bought → Primary: 25/25 = 100%
  expect_equal(metrics$conversion_metrics$Bought_to_Primary, 100)
})

test_that("calculate_funnel_metrics with weights", {
  stages <- list(
    awareness = matrix(c(TRUE, FALSE), ncol = 1),
    positive_disposition = matrix(c(TRUE, FALSE), ncol = 1),
    love = matrix(c(TRUE, FALSE), ncol = 1),
    prefer = matrix(FALSE, nrow = 2, ncol = 1),
    ambivalent = matrix(FALSE, nrow = 2, ncol = 1),
    reject = matrix(FALSE, nrow = 2, ncol = 1),
    no_opinion = matrix(c(FALSE, FALSE), ncol = 1),
    bought = matrix(c(TRUE, FALSE), ncol = 1),
    primary = matrix(c(TRUE, FALSE), ncol = 1),
    brand_codes = "A",
    n_respondents = 2
  )

  # Unweighted: aware = 50%
  metrics_unw <- calculate_funnel_metrics(stages)
  expect_equal(metrics_unw$stage_metrics$Aware_Pct, 50)

  # Weighted: resp 1 weight=3, resp 2 weight=1 -> aware = 75%
  metrics_wtd <- calculate_funnel_metrics(stages, weights = c(3, 1))
  expect_equal(metrics_wtd$stage_metrics$Aware_Pct, 75)
})

test_that("calculate_funnel_metrics flags low base correctly", {
  stages <- list(
    awareness = matrix(TRUE, nrow = 50, ncol = 1),
    positive_disposition = matrix(TRUE, nrow = 50, ncol = 1),
    love = matrix(TRUE, nrow = 50, ncol = 1),
    prefer = matrix(FALSE, nrow = 50, ncol = 1),
    ambivalent = matrix(FALSE, nrow = 50, ncol = 1),
    reject = matrix(FALSE, nrow = 50, ncol = 1),
    no_opinion = matrix(FALSE, nrow = 50, ncol = 1),
    bought = matrix(TRUE, nrow = 50, ncol = 1),
    primary = matrix(TRUE, nrow = 50, ncol = 1),
    brand_codes = "A",
    n_respondents = 50
  )

  # n=50 is above min_base (30) but below low_base_warning (75)
  metrics <- calculate_funnel_metrics(stages, min_base = 30,
                                       low_base_warning = 75)
  expect_false(metrics$flags$Suppress[1])
  expect_true(metrics$flags$LowBase[1])
})


# ==============================================================================
# run_funnel INTEGRATION TESTS
# ==============================================================================

test_that("run_funnel produces complete output", {
  td <- generate_funnel_test_data()

  result <- run_funnel(
    td$data, td$brands,
    awareness_prefix = "AWARE",
    attitude_prefix = "ATT",
    penetration_prefix = "PEN",
    focal_brand = "B1"
  )

  expect_equal(result$status, "PASS")
  expect_true(is.data.frame(result$stage_metrics))
  expect_true(is.data.frame(result$conversion_metrics))
  expect_true(is.data.frame(result$flags))
  expect_true(is.list(result$metrics_summary))
  expect_equal(result$n_brands, 5)
})

test_that("run_funnel metrics_summary has focal brand data", {
  td <- generate_funnel_test_data()

  result <- run_funnel(
    td$data, td$brands,
    awareness_prefix = "AWARE",
    attitude_prefix = "ATT",
    penetration_prefix = "PEN",
    focal_brand = "B1"
  )

  ms <- result$metrics_summary
  expect_equal(ms$focal_brand, "B1")
  expect_true(is.numeric(ms$focal_aware))
  expect_true(is.numeric(ms$focal_positive))
  expect_true(is.numeric(ms$focal_reject))
  expect_true(is.numeric(ms$focal_bought))
  expect_true(is.numeric(ms$cat_avg_aware))
  expect_true(is.character(ms$highest_rejection_brand))
})

test_that("run_funnel refuses empty data", {
  result <- run_funnel(data.frame(), data.frame(),
                       "AWARE", "ATT", "PEN")
  expect_equal(result$status, "REFUSED")
})

test_that("run_funnel warns on missing awareness columns", {
  # Data with no matching awareness columns
  data <- data.frame(x = 1:10)
  brands <- data.frame(BrandCode = "B1", stringsAsFactors = FALSE)

  result <- run_funnel(data, brands,
                       awareness_prefix = "NONEXISTENT",
                       attitude_prefix = "ATT",
                       penetration_prefix = "PEN")

  expect_equal(result$status, "PARTIAL")
  expect_true(length(result$warnings) > 0)
})

test_that("run_funnel Double Jeopardy: bigger brands tend to have higher awareness", {
  td <- generate_funnel_test_data(n_resp = 500, seed = 42)

  result <- run_funnel(
    td$data, td$brands,
    awareness_prefix = "AWARE",
    attitude_prefix = "ATT",
    penetration_prefix = "PEN",
    focal_brand = "B1"
  )

  metrics <- result$stage_metrics
  # B1 should be in top 2 by awareness (biggest brand, some randomness)
  top_2 <- metrics$BrandCode[order(-metrics$Aware_Pct)][1:2]
  expect_true("B1" %in% top_2)

  # Bottom brand should have lower awareness than top brand
  expect_true(min(metrics$Aware_Pct) < max(metrics$Aware_Pct))
})

test_that("run_funnel with weights produces valid output", {
  td <- generate_funnel_test_data(n_resp = 100)
  weights <- runif(100, 0.5, 2.0)

  result <- run_funnel(
    td$data, td$brands,
    awareness_prefix = "AWARE",
    attitude_prefix = "ATT",
    penetration_prefix = "PEN",
    focal_brand = "B1",
    weights = weights
  )

  expect_equal(result$status, "PASS")
  # All percentages should be in valid range
  expect_true(all(result$stage_metrics$Aware_Pct >= 0 &
                  result$stage_metrics$Aware_Pct <= 100))
})
