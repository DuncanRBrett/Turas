# ==============================================================================
# BRAND MODULE TESTS - DRIVERS & BARRIERS ELEMENT
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
source(file.path(TURAS_ROOT, "modules", "brand", "R", "02_mental_availability.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "06_drivers_barriers.R"))


# ==============================================================================
# DIFFERENTIAL IMPORTANCE TESTS
# ==============================================================================

test_that("differential importance: buyers link more = positive differential", {
  # 6 respondents: 3 buyers, 3 non-buyers
  # CEP01: all buyers link, no non-buyers link -> big positive differential
  # CEP02: no buyers link, all non-buyers link -> big negative differential
  tensor <- list(
    FOCAL = matrix(c(
      1, 0,   # resp 1 (buyer): CEP01=yes, CEP02=no
      1, 0,   # resp 2 (buyer)
      1, 0,   # resp 3 (buyer)
      0, 1,   # resp 4 (non-buyer)
      0, 1,   # resp 5 (non-buyer)
      0, 1    # resp 6 (non-buyer)
    ), nrow = 6, ncol = 2, byrow = TRUE)
  )
  colnames(tensor$FOCAL) <- c("CEP01", "CEP02")
  pen <- c(1, 1, 1, 0, 0, 0)

  result <- calculate_differential_importance(
    tensor, pen, "FOCAL", c("CEP01", "CEP02")
  )

  expect_equal(nrow(result), 2)
  # CEP01: buyers=100%, non-buyers=0% -> diff=100
  cep01 <- result[result$Code == "CEP01", ]
  expect_equal(cep01$Buyer_Pct, 100)
  expect_equal(cep01$NonBuyer_Pct, 0)
  expect_equal(cep01$Differential, 100)

  # CEP02: buyers=0%, non-buyers=100% -> diff=-100
  cep02 <- result[result$Code == "CEP02", ]
  expect_equal(cep02$Buyer_Pct, 0)
  expect_equal(cep02$NonBuyer_Pct, 100)
  expect_equal(cep02$Differential, -100)
})

test_that("differential importance ranked by absolute differential", {
  tensor <- list(
    A = matrix(c(
      1, 1, 0,
      1, 0, 1,
      0, 1, 0,
      0, 0, 1
    ), nrow = 4, ncol = 3, byrow = TRUE)
  )
  colnames(tensor$A) <- c("C1", "C2", "C3")
  pen <- c(1, 1, 0, 0)

  result <- calculate_differential_importance(tensor, pen, "A",
                                               c("C1", "C2", "C3"))

  # Should be ranked by |differential|
  expect_true(abs(result$Differential[1]) >= abs(result$Differential[2]))
  expect_true(abs(result$Differential[2]) >= abs(result$Differential[3]))
})

test_that("differential importance with weights", {
  tensor <- list(
    A = matrix(c(1, 0, 0, 0), nrow = 2, ncol = 2, byrow = TRUE)
  )
  colnames(tensor$A) <- c("C1", "C2")
  pen <- c(1, 0)

  # Unweighted
  result_unw <- calculate_differential_importance(tensor, pen, "A", c("C1", "C2"))
  expect_equal(result_unw$Buyer_Pct[result_unw$Code == "C1"], 100)

  # Weighted: doesn't change much with 1 buyer and 1 non-buyer
  result_wtd <- calculate_differential_importance(tensor, pen, "A", c("C1", "C2"),
                                                   weights = c(3, 1))
  expect_equal(result_wtd$Buyer_Pct[result_wtd$Code == "C1"], 100)
})


# ==============================================================================
# I x P QUADRANT TESTS
# ==============================================================================

test_that("IxP quadrants classify correctly", {
  importance <- data.frame(
    Code = c("C1", "C2", "C3", "C4"),
    Differential = c(20, 15, 5, 3),  # C1,C2 high imp; C3,C4 low imp
    stringsAsFactors = FALSE
  )
  performance <- data.frame(
    Code = c("C1", "C2", "C3", "C4"),
    Focal_Linkage_Pct = c(10, 40, 8, 45),  # C2,C4 high perf; C1,C3 low perf
    stringsAsFactors = FALSE
  )

  result <- classify_ixp_quadrants(importance, performance)

  # C1: high importance, low performance -> Strengthen
  expect_equal(result$Quadrant[result$Code == "C1"], "Strengthen")
  # C2: high importance, high performance -> Maintain
  expect_equal(result$Quadrant[result$Code == "C2"], "Maintain")
  # C3: low importance, low performance -> Deprioritise
  expect_equal(result$Quadrant[result$Code == "C3"], "Deprioritise")
  # C4: low importance, high performance -> Monitor
  expect_equal(result$Quadrant[result$Code == "C4"], "Monitor")
})


# ==============================================================================
# COMPETITIVE ADVANTAGE TESTS
# ==============================================================================

test_that("competitive advantage identifies leaders correctly", {
  cep_mat <- data.frame(
    CEPCode = c("C1", "C2"),
    FOCAL = c(40, 30),
    COMP_A = c(50, 20),
    COMP_B = c(35, 25),
    stringsAsFactors = FALSE
  )

  result <- calculate_competitive_advantage(cep_mat, "FOCAL")

  # C1: FOCAL=40, leader=COMP_A at 50 -> gap = -10, focal lags
  c1 <- result[result$Code == "C1", ]
  expect_equal(c1$Focal_Pct, 40)
  expect_equal(c1$Leader_Brand, "COMP_A")
  expect_equal(c1$Leader_Pct, 50)
  expect_equal(c1$Gap_pp, -10)
  expect_false(c1$Focal_Leads)

  # C2: FOCAL=30, leader=COMP_B at 25 -> gap = +5, focal leads
  c2 <- result[result$Code == "C2", ]
  expect_true(c2$Focal_Leads)
  expect_equal(c2$Gap_pp, 5)
})


# ==============================================================================
# run_drivers_barriers INTEGRATION TESTS
# ==============================================================================

test_that("run_drivers_barriers produces complete output", {
  set.seed(42)
  n_resp <- 100
  ceps <- paste0("C", 1:5)
  brands <- c("FOCAL", "COMP")

  linkage <- build_cep_linkage_from_matrix(
    data.frame(
      C1_FOCAL = rbinom(n_resp, 1, 0.3),
      C2_FOCAL = rbinom(n_resp, 1, 0.2),
      C3_FOCAL = rbinom(n_resp, 1, 0.25),
      C4_FOCAL = rbinom(n_resp, 1, 0.15),
      C5_FOCAL = rbinom(n_resp, 1, 0.1),
      C1_COMP = rbinom(n_resp, 1, 0.25),
      C2_COMP = rbinom(n_resp, 1, 0.3),
      C3_COMP = rbinom(n_resp, 1, 0.15),
      C4_COMP = rbinom(n_resp, 1, 0.2),
      C5_COMP = rbinom(n_resp, 1, 0.2)
    ), ceps, brands
  )

  cep_mat <- calculate_cep_brand_matrix(linkage$linkage_tensor, ceps)
  pen <- rbinom(n_resp, 1, 0.4)

  result <- run_drivers_barriers(
    linkage, cep_mat, pen, "FOCAL",
    cep_labels = data.frame(
      CEPCode = ceps,
      CEPText = paste("CEP", 1:5),
      stringsAsFactors = FALSE
    )
  )

  expect_equal(result$status, "PASS")
  expect_true(is.data.frame(result$importance))
  expect_true(is.data.frame(result$ixp_quadrants))
  expect_true(is.data.frame(result$competitive_advantage))
  expect_true(is.list(result$metrics_summary))
  expect_equal(nrow(result$importance), 5)
})

test_that("run_drivers_barriers with rejection data", {
  linkage <- build_cep_linkage_from_matrix(
    data.frame(C1_A = c(1, 0, 1), C1_B = c(0, 1, 0)),
    "C1", c("A", "B")
  )
  cep_mat <- calculate_cep_brand_matrix(linkage$linkage_tensor, "C1")
  pen <- c(1, 0, 1)

  rej <- data.frame(
    BrandCode = c("A", "A", "A", "B"),
    Reason = c("Too expensive", "Bad quality", "Too expensive", "Boring"),
    stringsAsFactors = FALSE
  )

  result <- run_drivers_barriers(linkage, cep_mat, pen, "A",
                                  rejection_data = rej)

  expect_true(!is.null(result$rejection_themes))
  expect_equal(result$rejection_themes$Reason[1], "Too expensive")
  expect_equal(result$rejection_themes$Count[1], 2)
})

test_that("run_drivers_barriers refuses NULL linkage", {
  result <- run_drivers_barriers(NULL, NULL, NULL, "A")
  expect_equal(result$status, "REFUSED")
})
