# ==============================================================================
# TURAS PRICING - ADVERSARIAL CASES (robustness gate 3)
# ==============================================================================
#
# The hard inputs a real data file brings: prices read as text, segment
# columns with blanks, labels that start with a formula character, and so on.
# Each case either reproduces the reference answer or refuses by name.
# ==============================================================================

quiet <- function(expr) { capture.output(r <- suppressWarnings(expr)); r }

adv_mon_cfg <- function() {
  list(weight_var = NA_character_, unit_cost = NA_real_, currency_symbol = "R",
       monadic = list(price_column = "price", intent_column = "buy",
                      intent_type = "binary", model_type = "logistic",
                      prediction_points = 100, confidence_intervals = FALSE))
}

adv_mon_data <- function() {
  set.seed(7)
  price <- rep(c(20, 30, 40, 50, 60, 70), each = 40)
  data.frame(price = price, buy = rbinom(240, 1, plogis(3 - 0.05 * price)))
}

test_that("a monadic price column read as text gives the numeric answer", {
  # A CSV or an Excel column with one stray text cell arrives as character.
  # "20", "30"... must fit the same model as 20, 30...: glm on a character
  # predictor fits a factor, and the prediction step then died on
  # "variable 'prices' was fitted with type character".
  d <- adv_mon_data()
  num <- quiet(run_monadic_analysis(d, adv_mon_cfg()))
  d_txt <- d
  d_txt$price <- as.character(d$price)
  txt <- quiet(run_monadic_analysis(d_txt, adv_mon_cfg()))
  expect_equal(unname(txt$model_summary$coefficients[, 1]),
               unname(num$model_summary$coefficients[, 1]), tolerance = 1e-10)
  expect_equal(txt$optimal_price$price, num$optimal_price$price)
})

test_that("a monadic price that is not a number refuses by name", {
  d <- adv_mon_data()
  d$price <- paste0("R", d$price)
  err <- tryCatch(quiet(run_monadic_analysis(d, adv_mon_cfg())),
                  turas_refusal = function(e) e, error = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_MONADIC_PRICE_NOT_NUMERIC")
  expect_match(err$problem, "R20")
})

# ------------------------------------------------------------------------------
# A segment column with blanks
# ------------------------------------------------------------------------------
source(file.path((function() {
  d <- normalizePath(getwd())
  for (i in 1:10) { if (file.exists(file.path(d, "launch_turas.R"))) return(d); d <- dirname(d) }
  getwd()
})(), "modules", "pricing", "tests", "testthat", "helper_pipeline_fixture.R"))

test_that("blank segment cells leave every other segment's results intact", {
  # 15 Premium respondents lose their segment code. Each segment must still be
  # the respondents coded to it, analysed as usual: psm_analysis_weighted on
  # that subset, n equal to its count. `data[data$Segment == s, ]` added an
  # all-NA row per blank to EVERY segment, and every segment then refused.
  root <- pricing_repo_root()
  skip_if_not(file.exists(file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx")),
              "examples/pricing/Karoo_Pricing_Data.xlsx is missing")
  d <- openxlsx::read.xlsx(file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx"))
  set.seed(1)
  d$Segment[sample(which(d$Segment == "Premium"), 15)] <- NA
  csv <- tempfile(fileext = ".csv")
  utils::write.csv(d, csv, row.names = FALSE, na = "")
  r <- pricing_pipeline_run("Karoo_Pricing_Config.xlsx", data_file = csv,
                            edits = c("cfg$van_westendorp$bootstrap_iterations <- 20",
                                      "cfg$gabor_granger$bootstrap_iterations <- 20",
                                      "cfg$generate_simulator <- FALSE"))
  sc <- pricing_sheet(r$workbook, "Segment_Comparison")
  sc <- sc[!is.na(sc$n) & sc$segment != "Total", ]
  expect_setequal(sc$segment, c("Budget", "New Customer", "Premium", "Standard"))

  vw <- d[, c("VW_TooCheap", "VW_Cheap", "VW_Expensive", "VW_TooExpensive")]
  keep <- stats::complete.cases(vw) & vw[[1]] < vw[[2]] & vw[[2]] < vw[[3]] & vw[[3]] < vw[[4]] &
    apply(vw, 1, function(x) all(x >= 5 & x <= 500)) & d$Weight > 0
  for (s in sc$segment) {
    k <- d[keep & !is.na(d$Segment) & d$Segment == s, ]
    des <- survey::svydesign(ids = ~1, weights = ~Weight,
                             data = data.frame(tc = k$VW_TooCheap, ch = k$VW_Cheap,
                                               ex = k$VW_Expensive, te = k$VW_TooExpensive,
                                               Weight = k$Weight))
    p <- suppressWarnings(pricesensitivitymeter::psm_analysis_weighted(
      toocheap = "tc", cheap = "ch", expensive = "ex", tooexpensive = "te",
      design = des, validate = TRUE, interpolate = TRUE, interpolation_steps = 0.1))
    row <- sc[sc$segment == s, ]
    expect_equal(as.numeric(row$n), nrow(k), info = s)
    expect_equal(as.numeric(unlist(row[c("PMC", "OPP", "IDP", "PME")])),
                 round(c(p$pricerange_lower, p$opp, p$idp, p$pricerange_upper), 2),
                 tolerance = 1e-9, info = s)
  }
  expect_false(any(grepl("PRICE_SEGMENT_REFUSED", r$log)))
})

# ------------------------------------------------------------------------------
# Monadic designs the pre-flight guard warns about
# ------------------------------------------------------------------------------
karoo_monadic_variant <- function(d) {
  csv <- tempfile(fileext = ".csv")
  utils::write.csv(d, csv, row.names = FALSE, na = "")
  pricing_pipeline_run("Karoo_Pricing_Config_Monadic.xlsx", data_file = csv,
                       edits = "cfg$monadic$bootstrap_iterations <- 20")
}

karoo_monadic_ref <- function(d) {
  d <- d[d$Weight > 0 & !is.na(d$MON_Price) & !is.na(d$MON_Intent), ]
  d$buy <- as.numeric(d$MON_Intent >= 4)
  g <- suppressWarnings(glm(buy ~ MON_Price, family = binomial, data = d,
                            weights = Weight / mean(Weight)))
  grid <- seq(min(d$MON_Price), max(d$MON_Price), length.out = 100)
  list(n = nrow(d), opt = grid[which.max(grid * plogis(coef(g)[1] + coef(g)[2] * grid))])
}

test_that("a two-cell monadic design (an A/B price test) runs and matches glm", {
  # Fewer than three prices is a pre-flight warning, not a refusal. Printing
  # that warning crashed the run: the shared guard_warn() stores plain
  # strings and the pricing printer read w$category.
  root <- pricing_repo_root()
  skip_if_not(file.exists(file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx")),
              "examples/pricing/Karoo_Pricing_Data.xlsx is missing")
  d <- openxlsx::read.xlsx(file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx"))
  d <- d[d$MON_Price %in% c(70, 130), ]
  r <- karoo_monadic_variant(d)
  expect_equal(r$status, "PASS", info = paste(tail(r$log, 8), collapse = "\n"))
  ref <- karoo_monadic_ref(d)
  op <- pricing_sheet(r$workbook, "Mon_Optimal_Price", colNames = FALSE)
  expect_equal(as.numeric(op$X2[which(op$X1 == "Revenue-Maximizing Price")]), ref$opt, tolerance = 1e-9)
  expect_true(any(grepl("Only 2 distinct prices", r$log, fixed = TRUE)))
})

test_that("a monadic cell of 10 to 29 respondents runs with its warning printed", {
  root <- pricing_repo_root()
  skip_if_not(file.exists(file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx")),
              "examples/pricing/Karoo_Pricing_Data.xlsx is missing")
  d <- openxlsx::read.xlsx(file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx"))
  drop <- which(d$MON_Price == 130)[-(1:20)]          # the R130 cell keeps 20
  d <- d[-drop, ]
  r <- karoo_monadic_variant(d)
  expect_equal(r$status, "PASS", info = paste(tail(r$log, 8), collapse = "\n"))
  ob <- pricing_sheet(r$workbook, "Mon_Observed_Data")
  expect_equal(ob$n[ob$price == 130], 20)
  expect_true(any(grepl("Monadic cell n=20 below minimum 30", r$log, fixed = TRUE)))
})

test_that("a monadic design with one price refuses by name instead of crashing", {
  # One price has no slope to estimate; glm returns no price coefficient and
  # the run died on "coefs[2, 4]: subscript out of bounds".
  d <- adv_mon_data()
  d$price <- 45
  err <- tryCatch(quiet(run_monadic_analysis(d, adv_mon_cfg())),
                  turas_refusal = function(e) e, error = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_MONADIC_ONE_PRICE")
  # The same when the valid-answer filter is what leaves one price.
  d2 <- adv_mon_data()
  d2$buy[d2$price != 20] <- NA
  err2 <- tryCatch(quiet(run_monadic_analysis(d2, adv_mon_cfg())),
                   turas_refusal = function(e) e, error = function(e) e)
  expect_equal(err2$code, "DATA_MONADIC_ONE_PRICE")
})

test_that("a DK code on a monadic scale intent is missing, not a purchase", {
  # Karoo's monadic intent is a 1-5 scale, 4+ = would buy. Forty answers are
  # recoded to 99 = don't know and DK_Codes = 99 is set. DK codes were
  # recoded in the Van Westendorp and Gabor-Granger columns only, so 99 >= 4
  # counted every don't-know as a purchase. Reference: glm and cell means on
  # the 360 respondents who gave an answer.
  root <- pricing_repo_root()
  skip_if_not(file.exists(file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx")),
              "examples/pricing/Karoo_Pricing_Data.xlsx is missing")
  d <- openxlsx::read.xlsx(file.path(root, "examples", "pricing", "Karoo_Pricing_Data.xlsx"))
  set.seed(2)
  d$MON_Intent[sample(nrow(d), 40)] <- 99
  csv <- tempfile(fileext = ".csv")
  utils::write.csv(d, csv, row.names = FALSE, na = "")
  r <- pricing_pipeline_run("Karoo_Pricing_Config_Monadic.xlsx", data_file = csv,
                            edits = c("cfg$monadic$bootstrap_iterations <- 20", "cfg$dk_codes <- 99"))
  expect_equal(r$status, "PASS", info = paste(tail(r$log, 8), collapse = "\n"))
  answered <- d[d$MON_Intent != 99, ]
  ref <- karoo_monadic_ref(answered)
  ms <- pricing_kv(r$workbook, "Mon_Model_Summary")
  expect_equal(as.numeric(ms["Observations"]), 360)
  answered$buy <- as.numeric(answered$MON_Intent >= 4)
  cells <- vapply(split(answered, answered$MON_Price),
                  function(s) sum(s$Weight * s$buy) / sum(s$Weight), numeric(1))
  ob <- pricing_sheet(r$workbook, "Mon_Observed_Data")
  expect_equal(ob$observed_intent, unname(cells), tolerance = 1e-9)
  op <- pricing_sheet(r$workbook, "Mon_Optimal_Price", colNames = FALSE)
  expect_equal(as.numeric(op$X2[which(op$X1 == "Revenue-Maximizing Price")]), ref$opt, tolerance = 1e-9)
})
