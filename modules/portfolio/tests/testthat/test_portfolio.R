# ==============================================================================
# PORTFOLIO MODULE TESTS
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
source(file.path(TURAS_ROOT, "modules", "shared", "lib", "turf_engine.R"))
source(file.path(TURAS_ROOT, "modules", "portfolio", "R", "00_main.R"))


# ==============================================================================
# CORE TESTS
# ==============================================================================

test_that("run_portfolio produces complete output with 4 categories", {
  cat_metrics <- data.frame(
    Category = c("Frozen Veg", "Ready Meals", "Sauces", "Snacks"),
    Awareness_Pct = c(85, 70, 60, 50),
    Penetration_Pct = c(45, 30, 25, 15),
    MMS = c(0.20, 0.15, 0.10, 0.08),
    stringsAsFactors = FALSE
  )

  set.seed(42)
  n_resp <- 200
  cat_pen_mat <- matrix(0L, nrow = n_resp, ncol = 4)
  colnames(cat_pen_mat) <- cat_metrics$Category
  for (j in 1:4) {
    cat_pen_mat[, j] <- rbinom(n_resp, 1, cat_metrics$Penetration_Pct[j] / 100)
  }

  result <- run_portfolio(
    cat_metrics, focal_brand = "IPK",
    category_penetration_matrix = cat_pen_mat,
    run_category_turf = TRUE
  )

  expect_equal(result$status, "PASS")
  expect_true(is.data.frame(result$portfolio_map))
  expect_true(is.data.frame(result$priority_quadrants))
  expect_true(is.list(result$category_turf))
  expect_true(is.list(result$metrics_summary))
  expect_equal(result$n_categories, 4)
  expect_equal(nrow(result$portfolio_map), 4)
})

test_that("portfolio quadrants classify correctly", {
  cat_metrics <- data.frame(
    Category = c("A", "B", "C", "D"),
    Penetration_Pct = c(60, 60, 20, 20),  # A,B high; C,D low
    MMS = c(0.25, 0.08, 0.22, 0.05),      # A,C high; B,D low
    stringsAsFactors = FALSE
  )

  result <- run_portfolio(cat_metrics)

  quads <- result$priority_quadrants
  expect_equal(quads$Quadrant[quads$Category == "A"], "Defend")
  expect_equal(quads$Quadrant[quads$Category == "B"], "Improve")
  expect_equal(quads$Quadrant[quads$Category == "C"], "Expand")
  expect_equal(quads$Quadrant[quads$Category == "D"], "Evaluate")
})

test_that("portfolio refuses single category", {
  cat_metrics <- data.frame(
    Category = "Only One",
    Penetration_Pct = 50,
    MMS = 0.20,
    stringsAsFactors = FALSE
  )

  result <- run_portfolio(cat_metrics)
  expect_equal(result$status, "REFUSED")
})

test_that("portfolio refuses NULL input", {
  result <- run_portfolio(NULL)
  expect_equal(result$status, "REFUSED")
})

test_that("portfolio Category TURF finds optimal combination", {
  set.seed(42)
  n_resp <- 300
  # 4 categories with different reach profiles
  cat_pen <- matrix(0L, nrow = n_resp, ncol = 4)
  colnames(cat_pen) <- c("A", "B", "C", "D")
  cat_pen[, 1] <- rbinom(n_resp, 1, 0.6)   # A: highest reach
  cat_pen[, 2] <- rbinom(n_resp, 1, 0.4)
  cat_pen[, 3] <- rbinom(n_resp, 1, 0.3)
  cat_pen[, 4] <- rbinom(n_resp, 1, 0.2)

  cat_metrics <- data.frame(
    Category = c("A", "B", "C", "D"),
    Penetration_Pct = c(60, 40, 30, 20),
    MMS = c(0.2, 0.15, 0.1, 0.08),
    stringsAsFactors = FALSE
  )

  result <- run_portfolio(cat_metrics, category_penetration_matrix = cat_pen)

  expect_true(!is.null(result$category_turf))
  expect_equal(result$category_turf$status, "PASS")

  # First selected category should have highest individual reach
  first_cat <- result$category_turf$incremental_table$Item_ID[1]
  expect_equal(first_cat, "A")

  # Reach should be monotonically increasing
  reaches <- result$category_turf$incremental_table$Reach_Pct
  expect_true(all(diff(reaches) >= 0))
})

test_that("portfolio without TURF still works", {
  cat_metrics <- data.frame(
    Category = c("A", "B"),
    Penetration_Pct = c(50, 30),
    MMS = c(0.2, 0.1),
    stringsAsFactors = FALSE
  )

  result <- run_portfolio(cat_metrics, run_category_turf = FALSE)

  expect_equal(result$status, "PASS")
  expect_null(result$category_turf)
  expect_equal(nrow(result$portfolio_map), 2)
})

test_that("portfolio metrics_summary populated", {
  cat_metrics <- data.frame(
    Category = c("A", "B", "C"),
    Penetration_Pct = c(50, 30, 10),
    MMS = c(0.25, 0.15, 0.05),
    stringsAsFactors = FALSE
  )

  result <- run_portfolio(cat_metrics, focal_brand = "IPK",
                          run_category_turf = FALSE)

  ms <- result$metrics_summary
  expect_equal(ms$focal_brand, "IPK")
  expect_equal(ms$n_categories, 3)
  expect_true(ms$n_defend + ms$n_improve + ms$n_expand +
              ms$n_evaluate == 3)
})

test_that("portfolio custom axes work", {
  cat_metrics <- data.frame(
    Category = c("A", "B"),
    Awareness_Pct = c(80, 60),
    Penetration_Pct = c(50, 30),
    MMS = c(0.2, 0.1),
    stringsAsFactors = FALSE
  )

  result <- run_portfolio(cat_metrics,
                          x_axis = "Awareness_Pct",
                          y_axis = "Penetration_Pct",
                          run_category_turf = FALSE)

  expect_equal(result$status, "PASS")
  expect_equal(result$portfolio_map$X_Value, c(80, 60))
  expect_equal(result$portfolio_map$Y_Value, c(50, 30))
  expect_equal(result$metrics_summary$x_axis, "Awareness_Pct")
})

test_that("portfolio handles missing MMS gracefully", {
  cat_metrics <- data.frame(
    Category = c("A", "B"),
    Penetration_Pct = c(50, 30),
    # No MMS column
    stringsAsFactors = FALSE
  )

  result <- run_portfolio(cat_metrics,
                          x_axis = "Penetration_Pct",
                          y_axis = "MMS",
                          run_category_turf = FALSE)

  expect_equal(result$status, "PASS")
  # Y values should be NA since MMS doesn't exist
  expect_true(all(is.na(result$portfolio_map$Y_Value)))
})
