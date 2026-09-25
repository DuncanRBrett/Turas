# ==============================================================================
# TURAS PRICING - RECOMMENDATION, CONFIDENCE AND LADDER REFERENCES (gate 1)
# ==============================================================================
#
# The recommended price, its confidence score and the price ladder, each
# against a hand calculation written out here from the documented rules.
# ==============================================================================

quiet <- function(expr) { capture.output(r <- suppressWarnings(expr)); r }

syn_vw_cfg <- function(behavior = "drop") {
  list(
    analysis_method = "van_westendorp", weight_var = NA_character_, dk_codes = numeric(0),
    currency_symbol = "R",
    van_westendorp = list(col_too_cheap = "tc", col_cheap = "ch",
                          col_expensive = "ex", col_too_expensive = "te",
                          validate_monotonicity = TRUE, violation_threshold = 0.5,
                          calculate_confidence = FALSE),
    vw_monotonicity_behavior = behavior,
    validation = list(min_completeness = 0.8, min_sample = 5, price_min = 0, price_max = 10000)
  )
}

# The 60-respondent set from test_reference_vw.R: 8 intransitive rows
# (13.3%). Price points after drop: PMC 50.00, OPP 61.50, IDP 64.00,
# PME 77.25 (checked against psm_analysis in that file).
syn_vw_data <- function(seed = 11) {
  set.seed(seed)
  n <- 60
  base <- sample(40:80, n, replace = TRUE)
  d <- data.frame(id = 1:n,
                  tc = base - sample(15:25, n, replace = TRUE),
                  ch = base - sample(3:12, n, replace = TRUE),
                  ex = base + sample(3:12, n, replace = TRUE),
                  te = base + sample(15:30, n, replace = TRUE),
                  w = round(runif(n, 0.4, 2.2), 2))
  d$ch[1] <- d$tc[1]
  d$ex[2] <- d$ch[2]
  d[3, c("ch", "ex")] <- d[3, c("ex", "ch")]
  d[4, c("tc", "ch", "ex", "te")] <- rev(d[4, c("tc", "ch", "ex", "te")])
  d$te[5] <- d$ex[5] - 1
  d$tc[6] <- d$te[6] + 5
  d[7, c("tc", "ch")] <- d[7, c("ch", "tc")]
  d$ex[8] <- d$te[8]
  d
}

syn_vw_run <- function(behavior = "drop") {
  cfg <- syn_vw_cfg(behavior)
  v <- quiet(validate_pricing_data(syn_vw_data(), cfg))
  quiet(run_van_westendorp(v$clean_data, cfg, validation = v))
}

test_that("round_to_psychological follows its documented rule in every branch", {
  # Under 10: floor + 0.99, unless that moves the price more than 10%.
  expect_equal(round_to_psychological(7.30), 7.99)     # +0.69, 9.5%
  expect_equal(round_to_psychological(5.10), 5.10)     # 5.99 would be +17%
  # 10 to 99: base = floor(p / 5) * 5; below base + 2.5 -> base - 0.01,
  # otherwise base + 4.99.
  expect_equal(round_to_psychological(62.75), 64.99)   # base 60, +2.75
  expect_equal(round_to_psychological(61.20), 59.99)   # base 60, +1.20
  expect_equal(round_to_psychological(10.40), 9.99)
  expect_equal(round_to_psychological(99.00), 99.99)   # base 95, +4
  # 100 and up: nearest multiple of 5, minus 0.01.
  expect_equal(round_to_psychological(147), 144.99)
  expect_equal(round_to_psychological(148), 149.99)
  expect_true(is.na(round_to_psychological(NA_real_)))
})

test_that("the data-quality factor scores the violations found, not the ones left after dropping", {
  # 8 of 60 respondents (13.3%) gave intransitive answers. Under the default
  # "drop" they leave before the engine runs, so the rate on the data the
  # engine saw is 0 by construction; the sample's rate is 13.3%, which the
  # rule scores 0.7 ("Acceptable data quality", 5% to 15%).
  #
  # Hand score for this VW-only run:
  #   method agreement  one method, CV 0            1.0
  #   sample size       n = 52 (< 100)              0.4
  #   data quality      13.3% violations            0.7
  #   zone fit          judged on the unrounded anchor
  #                     R62.75, inside OPP R61.50 to
  #                     IDP R64.00 (Duncan, 25 Sep:
  #                     rounding is presentation;
  #                     the R64.99 shown is above
  #                     IDP and scored 0.6 before)   1.0
  #   method coverage   one method                  0.4
  #   mean = 3.5 / 5 = 0.70 -> MEDIUM
  r <- syn_vw_run("drop")
  s <- quiet(synthesize_recommendation(vw_results = r, config = syn_vw_cfg("drop")))
  expect_equal(s$recommendation$price, 64.99)
  expect_equal(s$recommendation$anchor_price, 62.75)
  conf <- assess_recommendation_confidence(s$method_prices, s$recommendation$price, r, NULL,
                                           zone_price = s$recommendation$anchor_price)
  expect_match(conf$factors$data_quality, "Acceptable data quality \\(13% violations\\)")
  expect_equal(conf$factors$zone_fit, "Recommended price within optimal zone")
  expect_equal(s$recommendation$confidence_score, 0.70)
  expect_equal(s$recommendation$confidence, "MEDIUM")
  # The same rate reaches the risks: over 10% adds the reliability caveat.
  expect_true(any(grepl("^13% of respondents gave inconsistent prices", s$risks$assumptions)))
})

test_that("flag_only and fix score the same 13.3% as drop", {
  for (b in c("flag_only", "fix")) {
    r <- syn_vw_run(b)
    s <- quiet(synthesize_recommendation(vw_results = r, config = syn_vw_cfg(b)))
    conf <- assess_recommendation_confidence(s$method_prices, s$recommendation$price, r, NULL)
    expect_match(conf$factors$data_quality, "13% violations", info = b)
  }
})

test_that("the price ladder equals the hand calculation from the VW points", {
  # VW-only, 3 tiers (Value, Standard, Premium), anchor Standard.
  #   anchor  = OPP-IDP midpoint = (61.50 + 64.00) / 2 = 62.75
  #   floor   = PMC = 50.00,  ceiling = PME = 77.25
  #   Value   = 62.75 - (62.75 - 50.00) / 1.5 = 54.25   (>= 1.05 x 50 = 52.50)
  #   Premium = 62.75 + (77.25 - 62.75) / 1.5 = 72.4167 (<= 0.95 x 77.25 = 73.39)
  #   ".99" ending on the whole rand for the other tiers: 54.99, 72.99
  #   Standard, the anchor tier, shows the recommended price: 62.75 under the
  #   recommendation's rounding rule is 64.99 (Duncan, 25 Sep 2026: one
  #   number for one anchor; it printed 62.99 beside a R64.99 recommendation)
  #   gaps: 64.99 / 54.99 - 1 = 18.19%, 72.99 / 64.99 - 1 = 12.31%
  r <- syn_vw_run("drop")
  lad <- quiet(build_price_ladder(vw_results = r, config = syn_vw_cfg("drop")))
  expect_equal(lad$tier_table$tier, c("Value", "Standard", "Premium"))
  expect_equal(lad$tier_table$price, c(54.99, 64.99, 72.99))
  expect_equal(lad$tier_table$gap_to_next_pct[1:2],
               c((64.99 / 54.99 - 1) * 100, (72.99 / 64.99 - 1) * 100), tolerance = 1e-9)
  s <- quiet(synthesize_recommendation(vw_results = r, ladder_results = lad, config = syn_vw_cfg("drop")))
  expect_equal(lad$tier_table$price[lad$tier_table$tier == "Standard"], s$recommendation$price)
})

test_that("ladder rounding keeps its 10% guard on a low-priced product", {
  # floor(p) + 0.99 moves R0.60 to R0.99 (+65%) and R2.05 to R2.99 (+46%).
  # The documented guard ("more than 10% change") then keeps the price to the
  # cent. R54.25 -> R54.99 is +1.4% and keeps its ending.
  expect_equal(apply_price_rounding(c(0.60, 2.05, 54.25), "0.99"), c(0.60, 2.05, 54.99))
  expect_equal(apply_price_rounding(c(0.60, 54.25), "0.95"), c(0.60, 54.95))
})
