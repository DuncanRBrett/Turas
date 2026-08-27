# ==============================================================================
# TESTS: WTP IS ANCHORED ON THE BASELINE (review finding H9, M8)
# ==============================================================================
#
# The file's own methodology note, and calculate_individual_wtp, define WTP
# against the baseline level. calculate_aggregate_wtp divided the ZERO-CENTRED
# utilities by the price slope, so it was anchored on the attribute mean
# instead: baseline rows carried a spurious non-zero WTP, and the two tables in
# one workbook answered different questions.
#
# Also covered: a positive price slope (which reverses the sign of every WTP
# figure) refuses instead of publishing, and "leave blank to skip WTP" was
# false — blank auto-detects a price/cost/fee attribute.
# ==============================================================================

wtp_utilities <- function(zero_centred = TRUE) {
  # Raw, baseline-relative part-worths.
  raw <- data.frame(
    Attribute = c("Brand", "Brand", "Brand", "Price", "Price", "Price"),
    Level     = c("Alpha", "Beta", "Gamma", "$10", "$20", "$30"),
    Utility   = c(0, 0.8, -0.4, 0, -0.5, -1.2),
    Std_Error = c(0, 0.15, 0.15, 0, 0.12, 0.14),
    is_baseline = c(TRUE, FALSE, FALSE, TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  raw$SE <- raw$Std_Error

  if (!zero_centred) return(raw)

  # What the module actually hands to WTP: centred within attribute.
  for (a in unique(raw$Attribute)) {
    mask <- raw$Attribute == a
    raw$Utility[mask] <- raw$Utility[mask] - mean(raw$Utility[mask])
  }
  raw
}

wtp_config <- function() {
  attributes <- list(
    Brand = c("Alpha", "Beta", "Gamma"),
    Price = c("$10", "$20", "$30")
  )
  attr_df <- data.frame(
    AttributeName = names(attributes),
    NumLevels = sapply(attributes, length),
    stringsAsFactors = FALSE
  )
  attr_df$levels_list <- unname(attributes)
  list(
    attributes = attr_df,
    wtp_price_attribute = "Price",
    wtp_method = "marginal",
    confidence_level = 0.95
  )
}

test_that("H9: baseline levels have exactly zero WTP", {
  res <- calculate_wtp(wtp_utilities(zero_centred = TRUE), wtp_config(), verbose = FALSE)

  tbl <- res$wtp_table
  baselines <- tbl[tbl$is_baseline, ]

  expect_gt(nrow(baselines), 0)
  expect_true(all(baselines$WTP == 0))
  expect_true(all(is.na(baselines$WTP_Lower)))
})

test_that("H9: WTP is the same whether or not the utilities arrived zero-centred", {
  centred <- calculate_wtp(wtp_utilities(TRUE), wtp_config(), verbose = FALSE)$wtp_table
  raw     <- calculate_wtp(wtp_utilities(FALSE), wtp_config(), verbose = FALSE)$wtp_table

  expect_equal(centred$WTP, raw$WTP, tolerance = 1e-9)
})

test_that("H9: aggregate WTP agrees in sign with the underlying part-worths", {
  res <- calculate_wtp(wtp_utilities(TRUE), wtp_config(), verbose = FALSE)
  tbl <- res$wtp_table

  # Beta is preferred to the Alpha baseline, Gamma is not.
  beta  <- tbl$WTP[tbl$Level == "Beta"]
  gamma <- tbl$WTP[tbl$Level == "Gamma"]

  expect_gt(beta, 0)
  expect_lt(gamma, 0)

  # And the reported utility-vs-baseline column is the anchor that was used.
  expect_equal(tbl$Utility_vs_Baseline[tbl$Level == "Beta"], 0.8, tolerance = 1e-9)
  expect_equal(tbl$Utility_vs_Baseline[tbl$Level == "Alpha"], 0, tolerance = 1e-9)
})

test_that("H9: a price slope that rises with price refuses", {
  u <- wtp_utilities(FALSE)
  # Reverse the price utilities: higher price now has higher utility.
  u$Utility[u$Attribute == "Price"] <- c(0, 0.5, 1.2)

  cond <- tryCatch(
    { calculate_wtp(u, wtp_config(), verbose = FALSE); NULL },
    turas_refusal = function(e) e
  )

  expect_false(is.null(cond))
  expect_equal(cond$code, "CALC_WTP_POSITIVE_PRICE_SLOPE")
  expect_match(cond$problem, "increases as price increases")
})

test_that("H9: the WTP interval is labelled approximate where the reader sees it", {
  # This used to check the retired report's table builder. The note now travels
  # in the island itself, so the view cannot forget to print it, and the view
  # renders it as the column heading.
  root <- Sys.getenv("TURAS_ROOT")

  island_src <- paste(readLines(file.path(root, "modules", "conjoint", "R",
                                          "17_v2_island.R"), warn = FALSE),
                      collapse = "\n")
  expect_true(grepl("intervalNote", island_src, fixed = TRUE))
  expect_true(grepl("not a sampling interval", island_src, fixed = TRUE))

  view <- file.path(root, "modules", "tabs", "lib", "html_report_v2",
                    "assets", "js", "27x_conjoint.js")
  skip_if(!file.exists(view), "v2 conjoint view not present")
  view_src <- paste(readLines(view, warn = FALSE), collapse = "\n")
  expect_true(grepl("intervalNote", view_src, fixed = TRUE))
  expect_true(grepl("Interval (approx.)", view_src, fixed = TRUE))
})

test_that("M8: wtp_enabled is the off switch and the template says so", {
  root <- Sys.getenv("TURAS_ROOT")

  tpl <- paste(readLines(file.path(root, "modules", "conjoint", "R",
                                   "12_config_template.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl("wtp_enabled", tpl, fixed = TRUE))
  expect_false(grepl("(leave blank to skip WTP)", tpl, fixed = TRUE))

  main <- paste(readLines(file.path(root, "modules", "conjoint", "R",
                                    "00_main.R"), warn = FALSE), collapse = "\n")
  expect_true(grepl("isTRUE(config$wtp_enabled)", main, fixed = TRUE))

  guard <- paste(readLines(file.path(root, "modules", "conjoint", "R",
                                     "00_guard.R"), warn = FALSE), collapse = "\n")
  expect_true(grepl("Leaving it blank does NOT skip WTP", guard, fixed = TRUE))
})
