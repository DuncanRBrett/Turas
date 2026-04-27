# ==============================================================================
# BRAND MODULE TESTS - MENTAL AVAILABILITY ELEMENT
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

# Source shared infrastructure
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}

# Source TURF engine
source(file.path(TURAS_ROOT, "modules", "shared", "lib", "turf_engine.R"))

# Source brand module files
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "02b_mental_advantage.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "02_mental_availability.R"))


# --- Test data generator ---

#' Generate synthetic CEP linkage data for testing
#'
#' Creates realistic-looking brand x CEP linkage data with Double Jeopardy
#' patterns: bigger brands have higher linkage rates.
#'
#' @param n_resp Number of respondents
#' @param n_brands Number of brands
#' @param n_ceps Number of CEPs
#' @param seed Random seed
generate_ma_test_data <- function(n_resp = 200, n_brands = 5, n_ceps = 10,
                                   seed = 42) {
  set.seed(seed)

  brand_codes <- paste0("B", seq_len(n_brands))
  cep_codes <- paste0("CEP", sprintf("%02d", seq_len(n_ceps)))

  # Brand-specific base linkage rates (Double Jeopardy pattern)
  brand_base_rates <- sort(runif(n_brands, 0.08, 0.35), decreasing = TRUE)
  names(brand_base_rates) <- brand_codes

  # CEP-specific variation
  cep_variation <- runif(n_ceps, 0.7, 1.3)

  # Build linkage tensor
  linkage_tensor <- list()
  for (b in seq_along(brand_codes)) {
    brand_mat <- matrix(0L, nrow = n_resp, ncol = n_ceps)
    colnames(brand_mat) <- cep_codes
    for (j in seq_len(n_ceps)) {
      prob <- min(1, brand_base_rates[b] * cep_variation[j])
      brand_mat[, j] <- rbinom(n_resp, 1, prob)
    }
    linkage_tensor[[brand_codes[b]]] <- brand_mat
  }

  # Respondent-level CEP reach (any brand linked = 1)
  resp_cep_mat <- matrix(0L, nrow = n_resp, ncol = n_ceps)
  colnames(resp_cep_mat) <- cep_codes
  for (j in seq_len(n_ceps)) {
    any_linked <- rep(0L, n_resp)
    for (brand in brand_codes) {
      any_linked <- pmax(any_linked, linkage_tensor[[brand]][, j])
    }
    resp_cep_mat[, j] <- any_linked
  }

  cep_labels <- data.frame(
    CEPCode = cep_codes,
    CEPText = paste0("When I ", c(
      "want something quick", "need to feed family",
      "want healthy option", "am on a budget",
      "am entertaining", "want comfort food",
      "am in a hurry", "want something different",
      "cook from scratch", "want a treat"
    )[seq_len(n_ceps)]),
    stringsAsFactors = FALSE
  )

  list(
    linkage = list(
      linkage_tensor = linkage_tensor,
      respondent_cep_matrix = resp_cep_mat,
      brand_codes = brand_codes,
      cep_codes = cep_codes,
      n_respondents = n_resp
    ),
    cep_labels = cep_labels,
    brand_base_rates = brand_base_rates
  )
}


# ==============================================================================
# build_cep_linkage_from_matrix TESTS
# ==============================================================================

test_that("build_cep_linkage_from_matrix constructs correct tensor", {
  cep_codes <- c("CEP01", "CEP02")
  brand_codes <- c("A", "B")

  # 3 respondents, columns: CEP01_A, CEP01_B, CEP02_A, CEP02_B
  data <- data.frame(
    CEP01_A = c(1, 0, 1),
    CEP01_B = c(0, 1, 0),
    CEP02_A = c(1, 1, 0),
    CEP02_B = c(0, 0, 1)
  )

  result <- build_cep_linkage_from_matrix(data, cep_codes, brand_codes)

  # Check tensor structure
  expect_equal(length(result$linkage_tensor), 2)
  expect_true("A" %in% names(result$linkage_tensor))
  expect_true("B" %in% names(result$linkage_tensor))

  # Brand A linkage
  expect_equal(result$linkage_tensor[["A"]][, "CEP01"], c(1, 0, 1))
  expect_equal(result$linkage_tensor[["A"]][, "CEP02"], c(1, 1, 0))

  # Brand B linkage
  expect_equal(result$linkage_tensor[["B"]][, "CEP01"], c(0, 1, 0))
  expect_equal(result$linkage_tensor[["B"]][, "CEP02"], c(0, 0, 1))

  # Respondent CEP matrix (any brand)
  # CEP01: resp 1 (A), resp 2 (B), resp 3 (A) -> all have linkage
  expect_equal(result$respondent_cep_matrix[, "CEP01"], c(1, 1, 1))
  # CEP02: resp 1 (A), resp 2 (A), resp 3 (B) -> all have linkage
  expect_equal(result$respondent_cep_matrix[, "CEP02"], c(1, 1, 1))
})


# ==============================================================================
# MMS TESTS
# ==============================================================================

test_that("calculate_mms produces correct shares", {
  # Simple case: brand A has 6 links, brand B has 4 links
  tensor <- list(
    A = matrix(c(1, 1, 1, 1, 0, 0,
                 1, 1, 0, 0, 0, 0), nrow = 6, ncol = 2),
    B = matrix(c(0, 0, 0, 1, 1, 0,
                 0, 0, 1, 0, 0, 1), nrow = 6, ncol = 2)
  )
  colnames(tensor$A) <- colnames(tensor$B) <- c("C1", "C2")

  mms <- calculate_mms(tensor)

  expect_equal(nrow(mms), 2)
  expect_true("A" %in% mms$BrandCode)
  expect_true("B" %in% mms$BrandCode)

  total_a <- sum(tensor$A)  # 6
  total_b <- sum(tensor$B)  # 4
  total <- total_a + total_b  # 10

  expect_equal(mms$MMS[mms$BrandCode == "A"], round(total_a / total, 4))
  expect_equal(mms$MMS[mms$BrandCode == "B"], round(total_b / total, 4))

  # MMS should sum to 1
  expect_equal(sum(mms$MMS), 1)
})

test_that("calculate_mms with weights", {
  tensor <- list(
    A = matrix(c(1, 0, 0, 1), nrow = 2, ncol = 2),
    B = matrix(c(0, 1, 1, 0), nrow = 2, ncol = 2)
  )
  colnames(tensor$A) <- colnames(tensor$B) <- c("C1", "C2")

  # Unweighted: A has 2 links, B has 2 links -> MMS = 0.5 each
  mms_unw <- calculate_mms(tensor)
  expect_equal(mms_unw$MMS[mms_unw$BrandCode == "A"], 0.5)

  # Weighted: resp 1 weight=3, resp 2 weight=1
  # A: weighted links = 3*1 + 1*1 = 4 (resp1:C1 + resp2:C2)
  # B: weighted links = 3*0 + 1*1 + 3*0 + 1*0 -> wait...
  # Let me recalculate:
  # A[1,] = c(1,0), A[2,] = c(0,1) -> rowSums = c(1,1)
  # weighted A = 3*1 + 1*1 = 4
  # B[1,] = c(0,1), B[2,] = c(1,0) -> rowSums = c(1,1)
  # weighted B = 3*1 + 1*1 = 4
  # So MMS should still be 0.5 each
  weights <- c(3, 1)
  mms_wtd <- calculate_mms(tensor, weights)
  expect_equal(mms_wtd$MMS[mms_wtd$BrandCode == "A"], 0.5)
})

test_that("calculate_mms handles zero links", {
  tensor <- list(
    A = matrix(0L, nrow = 5, ncol = 3),
    B = matrix(0L, nrow = 5, ncol = 3)
  )
  colnames(tensor$A) <- colnames(tensor$B) <- c("C1", "C2", "C3")

  mms <- calculate_mms(tensor)
  expect_true(all(mms$MMS == 0))
})


# ==============================================================================
# MPen TESTS
# ==============================================================================

test_that("calculate_mpen produces correct penetration", {
  tensor <- list(
    A = matrix(c(1, 0, 0, 0,
                 0, 0, 0, 0), nrow = 4, ncol = 2),
    B = matrix(c(0, 1, 1, 0,
                 0, 0, 1, 0), nrow = 4, ncol = 2)
  )
  colnames(tensor$A) <- colnames(tensor$B) <- c("C1", "C2")

  mpen <- calculate_mpen(tensor)

  # A: resp 1 links to C1 -> 1 out of 4 = 0.25
  expect_equal(mpen$MPen[mpen$BrandCode == "A"], 0.25)

  # B: resp 2 links C1, resp 3 links C1+C2 -> 2 out of 4 = 0.50
  expect_equal(mpen$MPen[mpen$BrandCode == "B"], 0.50)
})

test_that("calculate_mpen with weights", {
  tensor <- list(
    A = matrix(c(1, 0, 0, 0), nrow = 2, ncol = 2)
  )
  colnames(tensor$A) <- c("C1", "C2")

  # Unweighted: resp 1 has linkage -> 0.5
  mpen_unw <- calculate_mpen(tensor)
  expect_equal(mpen_unw$MPen[1], 0.5)

  # Weighted: resp 1 weight=3, resp 2 weight=1 -> 3/4 = 0.75
  mpen_wtd <- calculate_mpen(tensor, weights = c(3, 1))
  expect_equal(mpen_wtd$MPen[1], 0.75)
})


# ==============================================================================
# NS TESTS
# ==============================================================================

test_that("calculate_ns produces correct network size", {
  tensor <- list(
    A = matrix(c(1, 0, 0,
                 1, 0, 0,
                 1, 0, 0), nrow = 3, ncol = 3)
  )
  colnames(tensor$A) <- c("C1", "C2", "C3")

  # Resp 1 links to 3 CEPs, resp 2 links to 0, resp 3 links to 0
  # NS = 3 (only 1 linker, with 3 CEPs)
  ns <- calculate_ns(tensor)
  expect_equal(ns$NS[1], 3)
  expect_equal(ns$NS_Base[1], 1)
})

test_that("calculate_ns with multiple linkers", {
  tensor <- list(
    A = matrix(c(1, 1, 0,
                 1, 0, 0,
                 0, 0, 0), nrow = 3, ncol = 3)
  )
  colnames(tensor$A) <- c("C1", "C2", "C3")

  # Resp 1: 2 CEPs linked, Resp 2: 1 CEP linked, Resp 3: 0
  # NS = mean(2, 1) = 1.5, base = 2
  ns <- calculate_ns(tensor)
  expect_equal(ns$NS[1], 1.5)
  expect_equal(ns$NS_Base[1], 2)
})

test_that("calculate_ns handles zero linkers", {
  tensor <- list(
    A = matrix(0L, nrow = 5, ncol = 3)
  )
  colnames(tensor$A) <- c("C1", "C2", "C3")

  ns <- calculate_ns(tensor)
  expect_equal(ns$NS[1], 0)
  expect_equal(ns$NS_Base[1], 0)
})


# ==============================================================================
# CEP x BRAND MATRIX TESTS
# ==============================================================================

test_that("calculate_cep_brand_matrix produces correct percentages", {
  tensor <- list(
    A = matrix(c(1, 0, 1, 0,
                 0, 1, 0, 0), nrow = 4, ncol = 2),
    B = matrix(c(0, 1, 0, 1,
                 1, 0, 0, 0), nrow = 4, ncol = 2)
  )
  colnames(tensor$A) <- colnames(tensor$B) <- c("C1", "C2")

  mat <- calculate_cep_brand_matrix(tensor, c("C1", "C2"))

  expect_true("CEPCode" %in% names(mat))
  expect_true("A" %in% names(mat))
  expect_true("B" %in% names(mat))

  # C1 linkage for A: 2 out of 4 = 50%
  expect_equal(mat$A[mat$CEPCode == "C1"], 50)
  # C2 linkage for A: 1 out of 4 = 25%
  expect_equal(mat$A[mat$CEPCode == "C2"], 25)
  # C1 linkage for B: 2 out of 4 = 50%
  expect_equal(mat$B[mat$CEPCode == "C1"], 50)
})


# ==============================================================================
# CEP PENETRATION TESTS
# ==============================================================================

test_that("calculate_cep_penetration ranks correctly", {
  resp_mat <- matrix(c(
    1, 0, 1,
    1, 0, 0,
    1, 1, 0,
    0, 1, 0
  ), nrow = 4, ncol = 3)
  colnames(resp_mat) <- c("C1", "C2", "C3")

  pen <- calculate_cep_penetration(resp_mat, c("C1", "C2", "C3"))

  # C1: 3/4 = 75%, C2: 2/4 = 50%, C3: 1/4 = 25%
  expect_equal(pen$Penetration_Pct[pen$CEPCode == "C1"], 75)
  expect_equal(pen$Penetration_Pct[pen$CEPCode == "C2"], 50)
  expect_equal(pen$Penetration_Pct[pen$CEPCode == "C3"], 25)

  # Should be ranked: C1, C2, C3
  expect_equal(pen$CEPCode[1], "C1")
  expect_equal(pen$Rank[pen$CEPCode == "C1"], 1)
})


# ==============================================================================
# run_mental_availability INTEGRATION TESTS
# ==============================================================================

test_that("run_mental_availability produces complete output", {
  td <- generate_ma_test_data()

  result <- run_mental_availability(
    linkage = td$linkage,
    cep_labels = td$cep_labels,
    focal_brand = "B1",
    run_cep_turf = TRUE,
    turf_max_items = 5
  )

  expect_equal(result$status, "PASS")

  # All components present
  expect_true(is.data.frame(result$mms))
  expect_true(is.data.frame(result$mpen))
  expect_true(is.data.frame(result$ns))
  expect_true(is.data.frame(result$cep_brand_matrix))
  expect_true(is.data.frame(result$cep_penetration))
  expect_true(is.list(result$cep_turf))
  expect_true(is.list(result$metrics_summary))

  # Correct number of brands and CEPs
  expect_equal(nrow(result$mms), 5)
  expect_equal(nrow(result$mpen), 5)
  expect_equal(nrow(result$ns), 5)
  expect_equal(result$n_brands, 5)
  expect_equal(result$n_ceps, 10)
})

test_that("run_mental_availability MMS sums to 1", {
  td <- generate_ma_test_data()
  result <- run_mental_availability(td$linkage, focal_brand = "B1",
                                    run_cep_turf = FALSE)

  mms_sum <- sum(result$mms$MMS)
  expect_equal(mms_sum, 1, tolerance = 0.001)
})

test_that("run_mental_availability Double Jeopardy pattern holds", {
  td <- generate_ma_test_data(n_resp = 500, seed = 42)
  result <- run_mental_availability(td$linkage, focal_brand = "B1",
                                    run_cep_turf = FALSE)

  # Bigger brands (higher MMS) should tend to have higher MPen
  mms_order <- order(-result$mms$MMS)
  mpen_order <- order(-result$mpen$MPen)

  # Top brand by MMS should be in top 2 by MPen (not exact due to randomness)
  top_mms_brand <- result$mms$BrandCode[mms_order[1]]
  top_mpen_brands <- result$mpen$BrandCode[mpen_order[1:2]]
  expect_true(top_mms_brand %in% top_mpen_brands)
})

test_that("run_mental_availability metrics_summary populated correctly", {
  td <- generate_ma_test_data()
  result <- run_mental_availability(td$linkage, td$cep_labels,
                                    focal_brand = "B1",
                                    run_cep_turf = TRUE, turf_max_items = 5)

  ms <- result$metrics_summary
  expect_equal(ms$focal_brand, "B1")
  expect_true(is.numeric(ms$focal_mms))
  expect_true(ms$focal_mms >= 0 && ms$focal_mms <= 1)
  expect_true(is.numeric(ms$focal_mpen))
  expect_true(is.numeric(ms$focal_ns))
  expect_true(is.character(ms$mms_leader))
  expect_equal(ms$n_brands, 5)
  expect_equal(ms$n_ceps, 10)
  expect_true(is.character(ms$top_cep))
})

test_that("run_mental_availability with weights", {
  td <- generate_ma_test_data(n_resp = 100)
  weights <- runif(100, 0.5, 2.0)

  result_unw <- run_mental_availability(td$linkage, focal_brand = "B1",
                                        run_cep_turf = FALSE)
  result_wtd <- run_mental_availability(td$linkage, focal_brand = "B1",
                                        weights = weights,
                                        run_cep_turf = FALSE)

  expect_equal(result_unw$status, "PASS")
  expect_equal(result_wtd$status, "PASS")

  # Both should sum MMS to 1
  expect_equal(sum(result_unw$mms$MMS), 1, tolerance = 0.001)
  expect_equal(sum(result_wtd$mms$MMS), 1, tolerance = 0.001)
})

test_that("run_mental_availability CEP TURF runs correctly", {
  td <- generate_ma_test_data()
  result <- run_mental_availability(td$linkage, td$cep_labels,
                                    focal_brand = "B1",
                                    run_cep_turf = TRUE, turf_max_items = 5)

  expect_true(!is.null(result$cep_turf))
  expect_equal(result$cep_turf$status, "PASS")
  expect_true(nrow(result$cep_turf$incremental_table) > 0)
  expect_true(nrow(result$cep_turf$incremental_table) <= 5)

  # Reach should be monotonically increasing
  reaches <- result$cep_turf$incremental_table$Reach_Pct
  expect_true(all(diff(reaches) >= 0))
})

test_that("run_mental_availability without CEP TURF", {
  td <- generate_ma_test_data()
  result <- run_mental_availability(td$linkage, focal_brand = "B1",
                                    run_cep_turf = FALSE)

  expect_equal(result$status, "PASS")
  expect_null(result$cep_turf)
})

test_that("run_mental_availability refuses NULL linkage", {
  result <- run_mental_availability(NULL)
  expect_equal(result$status, "REFUSED")
})

test_that("run_mental_availability handles single brand", {
  td <- generate_ma_test_data(n_brands = 1, n_ceps = 5)
  result <- run_mental_availability(td$linkage, focal_brand = "B1",
                                    run_cep_turf = TRUE)

  expect_equal(result$status, "PASS")
  expect_equal(result$mms$MMS[1], 1)  # Only brand gets 100% MMS
  expect_equal(result$n_brands, 1)
})

test_that("run_mental_availability handles many CEPs efficiently", {
  skip_on_cran()
  td <- generate_ma_test_data(n_resp = 300, n_brands = 8, n_ceps = 20)

  time_start <- proc.time()["elapsed"]
  result <- run_mental_availability(td$linkage, td$cep_labels,
                                    focal_brand = "B1",
                                    run_cep_turf = TRUE, turf_max_items = 10)
  elapsed <- proc.time()["elapsed"] - time_start

  expect_equal(result$status, "PASS")
  expect_true(elapsed < 10)
})
