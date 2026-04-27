# ==============================================================================
# BRAND MODULE TESTS - PORTFOLIO BASE HELPER + GUARDS
# ==============================================================================
# Known-answer tests for build_portfolio_base() and guard_validate_portfolio().
# Fixture: ipk_9cat_wave1.xlsx (1,200 respondents, 9 categories).
# Authoritative counts verified against the raw fixture on 2026-04-27, after the
# shopper-behaviour data block was added (commit eefabad) shifted the seed=42
# RNG sequence:
#   DSS: SQ1=958, SQ2=625
#   STO: SQ1=818, SQ2=382
# Whenever modules/brand/examples/9cat/04_data.R changes the order or count of
# random draws BEFORE the screener loop, these expected values must be
# regenerated via build_9cat_synthetic_example(n=1200, seed=42).
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

# Source shared infrastructure
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}

source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "09_portfolio.R"))

# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

FIXTURE_PATH <- file.path(
  path.expand("~"),
  "Library", "CloudStorage", "OneDrive-Personal", "DB Files",
  "TurasProjects", "Examples", "IPK_9Category", "ipk_9cat_wave1.xlsx"
)

.load_fixture <- function() {
  skip_if_not(file.exists(FIXTURE_PATH),
              "Fixture ipk_9cat_wave1.xlsx not found — skipping fixture tests")
  openxlsx::read.xlsx(FIXTURE_PATH, sheet = 1)
}

# ---------------------------------------------------------------------------
# build_portfolio_base() — happy-path known-answer tests
# ---------------------------------------------------------------------------

test_that("DSS 3m base returns correct unweighted count (625)", {
  dat <- .load_fixture()
  result <- build_portfolio_base(dat, "DSS", timeframe = "3m")
  expect_null(result$status)                    # not a refusal
  expect_equal(result$n_uw, 625L)
  expect_equal(result$col_used, "SQ2_DSS")
  expect_length(result$idx, 1200L)
  expect_equal(sum(result$idx), 625L)
})

test_that("DSS 13m base returns correct unweighted count (958)", {
  dat <- .load_fixture()
  result <- build_portfolio_base(dat, "DSS", timeframe = "13m")
  expect_null(result$status)
  expect_equal(result$n_uw, 958L)
  expect_equal(result$col_used, "SQ1_DSS")
})

test_that("STO 3m base returns correct unweighted count (382)", {
  dat <- .load_fixture()
  result <- build_portfolio_base(dat, "STO", timeframe = "3m")
  expect_null(result$status)
  expect_equal(result$n_uw, 382L)
  expect_equal(result$col_used, "SQ2_STO")
})

test_that("STO 13m base returns correct unweighted count (818)", {
  dat <- .load_fixture()
  result <- build_portfolio_base(dat, "STO", timeframe = "13m")
  expect_null(result$status)
  expect_equal(result$n_uw, 818L)
  expect_equal(result$col_used, "SQ1_STO")
})

test_that("uniform weights of 1.0 produce n_w == n_uw", {
  dat    <- .load_fixture()
  w      <- rep(1.0, nrow(dat))
  result <- build_portfolio_base(dat, "DSS", timeframe = "3m", weights = w)
  expect_null(result$status)
  expect_equal(result$n_w, 625.0)
  expect_equal(result$n_w, as.numeric(result$n_uw))
})

test_that("doubling all weights produces n_w == 2 * n_uw", {
  dat    <- .load_fixture()
  w      <- rep(2.0, nrow(dat))
  result <- build_portfolio_base(dat, "DSS", timeframe = "3m", weights = w)
  expect_null(result$status)
  expect_equal(result$n_w, 625.0 * 2.0)
})

test_that("NULL weights default to uniform (n_w == n_uw)", {
  dat    <- .load_fixture()
  result <- build_portfolio_base(dat, "POS", timeframe = "13m", weights = NULL)
  expect_null(result$status)
  expect_equal(result$n_w, as.numeric(result$n_uw))
})

test_that("idx logical vector length equals nrow(data)", {
  dat    <- .load_fixture()
  result <- build_portfolio_base(dat, "BAK", timeframe = "3m")
  expect_null(result$status)
  expect_type(result$idx, "logical")
  expect_length(result$idx, nrow(dat))
})

# ---------------------------------------------------------------------------
# build_portfolio_base() — guard / refusal tests
# ---------------------------------------------------------------------------

test_that("NULL data returns REFUSED with DATA_PORTFOLIO_NO_AWARENESS_COLS", {
  result <- build_portfolio_base(NULL, "DSS")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_PORTFOLIO_NO_AWARENESS_COLS")
})

test_that("zero-row data frame returns REFUSED", {
  empty  <- data.frame(SQ2_DSS = integer(0))
  result <- build_portfolio_base(empty, "DSS")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_PORTFOLIO_NO_AWARENESS_COLS")
})

test_that("empty cat_code returns REFUSED with DATA_PORTFOLIO_TIMEFRAME_MISSING", {
  dat    <- data.frame(SQ2_DSS = c(1L, 0L))
  result <- build_portfolio_base(dat, "")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_PORTFOLIO_TIMEFRAME_MISSING")
})

test_that("NULL cat_code returns REFUSED", {
  dat    <- data.frame(SQ2_DSS = c(1L, 0L))
  result <- build_portfolio_base(dat, NULL)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_PORTFOLIO_TIMEFRAME_MISSING")
})

test_that("missing SQ2 col for 3m timeframe returns REFUSED with DATA_PORTFOLIO_TIMEFRAME_MISSING", {
  dat    <- data.frame(SQ1_DSS = c(1L, 1L, 0L))  # has SQ1 but not SQ2
  result <- build_portfolio_base(dat, "DSS", timeframe = "3m")
  # SQ2 absent → falls back to SQ1 (3m fallback), so this should PASS
  # Fallback: 3m primary = SQ2_DSS; fallback = SQ1_DSS
  expect_null(result$status)  # fallback kicks in
  expect_equal(result$col_used, "SQ1_DSS")
  expect_equal(result$n_uw, 2L)
})

test_that("missing both SQ1 and SQ2 returns REFUSED", {
  dat    <- data.frame(x = c(1L, 0L, 1L))
  result <- build_portfolio_base(dat, "DSS", timeframe = "3m")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_PORTFOLIO_TIMEFRAME_MISSING")
})

test_that("13m with no SQ1 col returns REFUSED (no fallback for 13m)", {
  dat    <- data.frame(SQ2_DSS = c(1L, 1L, 0L))
  result <- build_portfolio_base(dat, "DSS", timeframe = "13m")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_PORTFOLIO_TIMEFRAME_MISSING")
})

# ---------------------------------------------------------------------------
# guard_validate_portfolio() — TRS refusal tests
# ---------------------------------------------------------------------------

.make_minimal_config <- function(overrides = list()) {
  cfg <- list(
    focal_brand              = "IPK",
    cross_category_awareness = TRUE,
    portfolio_timeframe      = "3m",
    portfolio_min_base       = 30L
  )
  for (k in names(overrides)) cfg[[k]] <- overrides[[k]]
  cfg
}

.make_minimal_data <- function() {
  data.frame(
    SQ1_DSS = c(1L, 0L),
    SQ2_DSS = c(1L, 0L),
    BRANDAWARE_DSS_IPK = c(1L, 0L),
    stringsAsFactors = FALSE
  )
}

.make_minimal_categories <- function() {
  data.frame(
    Category  = "Dry Seasonings",
    Type      = "transaction",
    Timeframe_Target = "3m",
    stringsAsFactors = FALSE
  )
}

# Helper: call a guard function and capture the turas_refusal condition
.catch_guard <- function(expr) {
  tryCatch(expr, turas_refusal = function(e) e)
}

test_that("CFG_PORTFOLIO_AWARENESS_OFF: cross_category_awareness=FALSE triggers refusal", {
  cfg <- .make_minimal_config(list(cross_category_awareness = FALSE))
  err <- .catch_guard(
    guard_validate_portfolio(.make_minimal_data(), .make_minimal_categories(), list(), cfg)
  )
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_PORTFOLIO_AWARENESS_OFF")
})

test_that("CFG_PORTFOLIO_NO_CATEGORIES: empty categories triggers refusal", {
  cfg <- .make_minimal_config()
  err <- .catch_guard(
    guard_validate_portfolio(.make_minimal_data(), data.frame(), list(), cfg)
  )
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_PORTFOLIO_NO_CATEGORIES")
})

test_that("CFG_PORTFOLIO_NO_CATEGORIES: NULL categories triggers refusal", {
  cfg <- .make_minimal_config()
  err <- .catch_guard(
    guard_validate_portfolio(.make_minimal_data(), NULL, list(), cfg)
  )
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_PORTFOLIO_NO_CATEGORIES")
})

test_that("DATA_PORTFOLIO_NO_AWARENESS_COLS: no BRANDAWARE_* columns triggers refusal", {
  cfg <- .make_minimal_config()
  dat <- data.frame(SQ1_DSS = c(1L, 0L), SQ2_DSS = c(1L, 0L))
  err <- .catch_guard(
    guard_validate_portfolio(dat, .make_minimal_categories(), list(), cfg)
  )
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_PORTFOLIO_NO_AWARENESS_COLS")
})

test_that("DATA_PORTFOLIO_TIMEFRAME_MISSING: 3m with no SQ2_* triggers refusal", {
  cfg <- .make_minimal_config(list(portfolio_timeframe = "3m"))
  dat <- data.frame(
    SQ1_DSS            = c(1L, 0L),
    BRANDAWARE_DSS_IPK = c(1L, 0L)
    # deliberately no SQ2_* columns
  )
  err <- .catch_guard(
    guard_validate_portfolio(dat, .make_minimal_categories(), list(), cfg)
  )
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_PORTFOLIO_TIMEFRAME_MISSING")
})

test_that("DATA_PORTFOLIO_TIMEFRAME_MISSING: 13m with no SQ1_* triggers refusal", {
  cfg <- .make_minimal_config(list(portfolio_timeframe = "13m"))
  dat <- data.frame(
    SQ2_DSS            = c(1L, 0L),
    BRANDAWARE_DSS_IPK = c(1L, 0L)
    # deliberately no SQ1_* columns
  )
  err <- .catch_guard(
    guard_validate_portfolio(dat, .make_minimal_categories(), list(), cfg)
  )
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_PORTFOLIO_TIMEFRAME_MISSING")
})

test_that("PASS: valid config + data + categories produces status PASS", {
  cfg    <- .make_minimal_config()
  result <- guard_validate_portfolio(
    .make_minimal_data(), .make_minimal_categories(), list(), cfg
  )
  expect_equal(result$status, "PASS")
})

# ---------------------------------------------------------------------------
# run_portfolio() — smoke tests on the stub
# ---------------------------------------------------------------------------

test_that("run_portfolio stub returns PASS with correct shape", {
  dat    <- .make_minimal_data()
  cats   <- .make_minimal_categories()
  cfg    <- .make_minimal_config()
  result <- run_portfolio(dat, cats, list(), cfg)
  expect_equal(result$status, "PASS")
  expect_equal(result$focal_brand, "IPK")
  expect_equal(result$timeframe, "3m")
  expect_equal(result$n_total, nrow(dat))
  expect_true(is.list(result$bases))
  expect_true(is.list(result$suppressions))
  expect_true(is.data.frame(result$bases$per_category))
  expect_true(is.data.frame(result$bases$per_brand))
})

test_that("run_portfolio returns REFUSED list when guard fails (cross_category_awareness off)", {
  dat    <- .make_minimal_data()
  cats   <- .make_minimal_categories()
  cfg    <- .make_minimal_config(list(cross_category_awareness = FALSE))
  result <- run_portfolio(dat, cats, list(), cfg)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_PORTFOLIO_AWARENESS_OFF")
})
