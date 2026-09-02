# ==============================================================================
# TABS MODULE. WAVE VALUES FROM MICRODATA TESTS (v2 aggregate tracking)
# ==============================================================================
#
# Locks wave_values_from_microdata() / reconcile_wave_values()
# (tracking_wave_values.R): a wave's respondent-level data -> the long values
# table tracking_aggregate_bridge.R consumes. The upstream twin of
# test_tracking_aggregate_bridge.R.
#
# The contract these tests defend, each rule verified against the renderer or
# against a real published figure:
#   mean        DK/NA (ExcludeFromIndex=Y) dropped; base = valid numeric count;
#               sd = sdOfScores() in 22w_waves.js, incl. the Kish effective base
#   proportion  base = ALL non-missing responses. DK/NA stay IN the base
#   nps         per-respondent +100/0/-100, sd recorded
#   multi       "any of" NET over member columns; base = answered at all
#   honest      an unresolvable metric is SKIPPED AND NAMED, never guessed
#
# Run with:
#   Rscript -e 'testthat::test_file("modules/tabs/tests/testthat/test_tracking_wave_values.R")'
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))              # tabs_refuse (TRS)
source(file.path(turas_root, "modules/tabs/lib/tracking_island.R"))       # tracking_norm, %||%
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))          # apply_base_filter
source(file.path(turas_root, "modules/tabs/lib/tracking_wave_values.R"))

# ---- fixture ------------------------------------------------------------
# 10 respondents. RATE is a 1-10 rating with one DK and one NA (both excluded
# from the mean, both KEPT in a proportion base). FREQ is a 4-category single
# response with a two-member NET. YN is a plain category. NPS is 0-10.
# MM_1..MM_3 is a Multi_Mention whose third option is the "none" member.
fx <- data.frame(
  RATE = c("10", "9", "8", "10", "7", "9", "10", "6", "DK", "NA"),
  FREQ = c("Weekly", "Monthly", "Weekly", "Less than monthly", "Not at all",
           "Weekly", "Monthly", "Weekly", "Less than monthly", "Weekly"),
  YN   = c("Yes", "No", "Yes", "Yes", "No", "Yes", "No", "Yes", "No", "Yes"),
  NPS  = c(10, 9, 8, 10, 6, 9, 10, 0, 7, 10),
  ARM  = c("A", "A", "B", "A", "B", "A", "A", "B", "A", "B"),
  MM_1 = c("Mon", NA, "Mon", NA, NA, "Mon", NA, NA, NA, NA),
  MM_2 = c(NA, "Tue", NA, NA, NA, NA, "Tue", NA, NA, NA),
  MM_3 = c(NA, NA, NA, "None", NA, NA, NA, "None", NA, NA),
  WT   = c(2, 1, 1, 2, 1, 1, 2, 1, 1, 1),
  stringsAsFactors = FALSE)

opts <- data.frame(
  QuestionCode = c(rep("RATE", 2), rep("FREQ", 4), rep("YN", 2),
                   "MM_1", "MM_2", "MM_3"),
  OptionText   = c("DK", "NA",
                   "Weekly", "Monthly", "Less than monthly", "Not at all",
                   "Yes", "No", "Mon", "Tue", "None"),
  ExcludeFromIndex = c("Y", "Y", rep(NA, 9)),
  BoxCategory  = c(NA, NA, "Monthly or better", "Monthly or better", NA, NA,
                   NA, NA, "Any day", "Any day", NA),
  stringsAsFactors = FALSE)

mapping <- data.frame(
  QuestionCode  = c("RATE", "FREQ", "YN", "NPS", "MM"),
  TrackingSpecs = c("mean", "category:Monthly or better", "category:Yes",
                    "nps_score", "category:Any day"),
  stringsAsFactors = FALSE)

res <- wave_values_from_microdata(fx, mapping, opts, wave = "2025")
val <- function(r, id) r$result[r$result$metric_id == id, ]


test_that("every mapped metric computes, and the table is the bridge's shape", {
  expect_equal(res$status, "PASS")
  expect_equal(nrow(res$result), 5)
  expect_equal(res$result$wave, rep("2025", 5))
  expect_true(all(c("metric_id", "wave", "metric_type", "value", "base", "sd", "n")
                  %in% names(res$result)))
})


test_that("mean drops DK/NA, bases on the valid numeric count, and matches base R", {
  m <- val(res, "RATE")
  scores <- c(10, 9, 8, 10, 7, 9, 10, 6)          # the DK and the NA are gone
  expect_equal(m$metric_type, "mean")
  expect_equal(m$base, 8)                          # NOT 10
  expect_equal(m$value, mean(scores))
  expect_equal(m$sd, sd(scores))                   # unweighted => plain sample sd
})


test_that("the sd is sdOfScores() from 22w_waves.js, Kish base and all", {
  # Recreate the renderer's formula independently and demand agreement, so a
  # drift in either implementation breaks this test rather than the report.
  js_sd <- function(s, w) {
    m <- sum(w * s) / sum(w)
    eff <- sum(w)^2 / sum(w * w)
    sqrt((sum(w * (s - m)^2) / sum(w)) * eff / (eff - 1))
  }
  scores <- c(10, 9, 8, 10, 7, 9, 10, 6)
  wts    <- c(2, 1, 1, 2, 1, 1, 2, 1)

  unweighted <- wave_values_from_microdata(fx, mapping, opts, wave = "2025")
  expect_equal(val(unweighted, "RATE")$sd, js_sd(scores, rep(1, 8)))

  weighted <- wave_values_from_microdata(fx, mapping, opts, wave = "2025", weights = "WT")
  wm <- val(weighted, "RATE")
  expect_equal(wm$value, sum(wts * scores) / sum(wts))
  expect_equal(wm$sd, js_sd(scores, wts))
  expect_false(isTRUE(all.equal(wm$sd, sd(scores))))   # weighting really did something
  expect_equal(wm$base, 8)                             # base stays the respondent count
})


test_that("a proportion KEEPS DK/NA in its base (the CCPB Q11 rule)", {
  # YN has no excluded options, so use RATE's shape: the rule under test is that
  # a proportion's base is every non-missing response, not the mean's base.
  m <- wave_values_from_microdata(
    fx, data.frame(QuestionCode = "RATE", TrackingSpecs = "category:10",
                   stringsAsFactors = FALSE), opts, wave = "2025")
  r <- val(m, "RATE")
  expect_equal(r$metric_type, "proportion")
  expect_equal(r$base, 10)        # all ten answered. DK and NA included
  expect_equal(r$n, 3)            # three 10s
  expect_equal(r$value, 30)
  expect_true(is.na(r$sd))        # proportions never carry an sd
})


test_that("a NET sums its BoxCategory members; a plain category does not need one", {
  net <- val(res, "FREQ")                    # Weekly (5) + Monthly (2) = 7 of 10
  expect_equal(net$n, 7)
  expect_equal(net$base, 10)
  expect_equal(net$value, 70)

  plain <- val(res, "YN")                    # "Yes" carries no BoxCategory
  expect_equal(plain$n, 6)
  expect_equal(plain$value, 60)
})


test_that("NPS is the mean of per-respondent +100/0/-100 and carries an sd", {
  n <- val(res, "NPS")
  per <- c(100, 100, 0, 100, -100, 100, 100, -100, 0, 100)
  expect_equal(n$metric_type, "nps")
  expect_equal(n$value, mean(per))           # 6 promoters, 2 detractors => 40
  expect_equal(n$value, 40)
  expect_equal(n$base, 10)
  expect_equal(n$sd, sd(per))
})


test_that("a Multi_Mention NET is 'any member column', based on answering at all", {
  mm <- val(res, "MM")
  # answered = any of MM_1..MM_3 -> rows 1,2,3,4,6,7,8 = 7; members are MM_1/MM_2
  # ("None" is not a member) -> rows 1,2,3,6,7 = 5
  expect_equal(mm$base, 7)
  expect_equal(mm$n, 5)
  expect_equal(mm$value, 5 / 7 * 100)
})


test_that("a base filter narrows the base, and weights follow the filtered rows", {
  filtered <- wave_values_from_microdata(fx, mapping, opts, wave = "2025",
                                         base_filters = list(YN = 'ARM == "A"'))
  y <- val(filtered, "YN")
  # arm A is rows 1,2,4,6,7,9; YN is "Yes" on rows 1, 4 and 6 of those
  expect_equal(y$base, 6)
  expect_equal(y$n, sum(fx$ARM == "A" & fx$YN == "Yes"))
  expect_equal(y$n, 3)
  expect_equal(val(filtered, "FREQ")$base, 10)   # untouched metrics keep the full base

  # weights must be subset to the SAME rows, or the mean silently uses the wrong ones
  wf <- wave_values_from_microdata(fx, mapping, opts, wave = "2025", weights = "WT",
                                   base_filters = list(RATE = 'ARM == "A"'))
  keep <- fx$ARM == "A" & !(fx$RATE %in% c("DK", "NA"))
  s <- as.numeric(fx$RATE[keep]); w <- fx$WT[keep]
  expect_equal(val(wf, "RATE")$value, sum(w * s) / sum(w))
})


test_that("an unresolvable metric is SKIPPED AND NAMED, never guessed", {
  m2 <- rbind(mapping, data.frame(QuestionCode = "GHOST", TrackingSpecs = "mean",
                                  stringsAsFactors = FALSE))
  out <- wave_values_from_microdata(fx, m2, opts, wave = "2025")
  expect_equal(out$status, "PARTIAL")
  expect_false("GHOST" %in% out$result$metric_id)      # no invented row
  expect_true("GHOST" %in% out$skipped$metric_id)
  expect_match(out$skipped$reason[out$skipped$metric_id == "GHOST"], "not in the data")
})


test_that("bad inputs refuse with TRS codes rather than stopping or guessing", {
  expect_equal(wave_values_from_microdata(fx[0, ], mapping, opts, wave = "2025")$code,
               "DATA_MISSING")
  expect_equal(wave_values_from_microdata(fx, data.frame(x = 1), opts, wave = "2025")$code,
               "CFG_MAPPING_INVALID")
  expect_equal(wave_values_from_microdata(fx, mapping, opts, wave = "")$code,
               "CFG_WAVE_MISSING")
  expect_equal(wave_values_from_microdata(fx, mapping, opts, wave = "2025",
                                          weights = "NOPE")$code, "DATA_WEIGHT_MISSING")
  ghost <- data.frame(QuestionCode = "GHOST", TrackingSpecs = "mean",
                      stringsAsFactors = FALSE)
  expect_equal(wave_values_from_microdata(fx, ghost, opts, wave = "2025")$status, "REFUSED")
})


test_that("options are optional: without them nothing is excluded and NETs are literal", {
  bare <- wave_values_from_microdata(
    fx, data.frame(QuestionCode = "RATE", TrackingSpecs = "mean",
                   stringsAsFactors = FALSE), options = NULL, wave = "2025")
  # DK/NA are not numeric, so they still leave the mean - but via coercion, not
  # via a rule. The base is the same 8; this pins that the fallback is safe.
  expect_equal(val(bare, "RATE")$base, 8)
})


# ---- reconciliation ------------------------------------------------------

test_that("reconcile PASSES when every metric lands on its published figure", {
  pub <- c(RATE = 8.6, FREQ = 70, YN = 60, NPS = 40, MM = 71)
  rec <- reconcile_wave_values(res$result, pub)
  expect_equal(rec$status, "PASS")
  expect_true(all(rec$result$reconciles))
})


test_that("reconcile FLAGS a metric that misses, and names it", {
  pub <- c(RATE = 8.6, FREQ = 55, YN = 60, NPS = 40, MM = 71)   # FREQ is wrong
  rec <- reconcile_wave_values(res$result, pub)
  expect_equal(rec$status, "PARTIAL")
  expect_false(rec$result$reconciles[rec$result$metric_id == "FREQ"])
  expect_true(all(rec$result$reconciles[rec$result$metric_id != "FREQ"]))
})


test_that("reconcile uses one rounding step, so published rounding is not a failure", {
  # a mean published at 1dp and a percentage published whole must both pass
  vals <- data.frame(metric_id = c("A", "B"), wave = "2025",
                     metric_type = c("mean", "proportion"),
                     value = c(9.332, 32.49), base = c(750, 764),
                     sd = c(1.15, NA), n = c(NA, 248), stringsAsFactors = FALSE)
  expect_equal(reconcile_wave_values(vals, c(A = 9.3, B = 32))$status, "PASS")
  # but a real disagreement still fails
  expect_equal(reconcile_wave_values(vals, c(A = 9.3, B = 30))$status, "PARTIAL")
})


test_that("reconcile accepts a data frame and reports metrics with no published figure", {
  pub <- data.frame(metric_id = c("RATE", "FREQ"), value = c(8.6, 70),
                    stringsAsFactors = FALSE)
  rec <- reconcile_wave_values(res$result, pub)
  expect_equal(rec$status, "PASS")                       # the comparable ones agree
  expect_equal(sum(is.na(rec$result$published)), 3)      # YN, NPS, MM had none
})


# ==============================================================================
# C5 (production review 2026-08): reconcile must not pass vacuously; the splice
# must insert a wave the table has never held; a single missing publish must
# not crash reconcile.
# ==============================================================================

test_that("reconcile goes PARTIAL, not PASS, when NO metric has a published figure", {
  vals <- data.frame(metric_id = c("A", "B"), wave = "2019",
                     metric_type = c("mean", "proportion"),
                     value = c(9.3, 32.5), base = c(750, 764),
                     sd = c(1.15, NA), stringsAsFactors = FALSE)
  # empty published slice. Exactly what the recovery script passes for a wave
  # absent from the values table
  pub <- data.frame(metric_id = character(0), value = numeric(0),
                    stringsAsFactors = FALSE)
  rec <- reconcile_wave_values(vals, pub)
  expect_equal(rec$status, "PARTIAL")
  expect_match(rec$message, "nothing was cross-checked")
})

test_that("reconcile survives exactly ONE metric with no published figure", {
  # A single NA name used to become data.frame row names and abort with
  # "row names contain missing values"; multiple NAs collided and were
  # discarded, which is why the existing 3-missing test never caught it.
  vals <- data.frame(metric_id = c("A", "B"), wave = "2025",
                     metric_type = c("mean", "mean"),
                     value = c(9.3, 8.1), base = c(750, 750),
                     sd = c(1.1, 1.2), stringsAsFactors = FALSE)
  rec <- reconcile_wave_values(vals, c(A = 9.3))
  expect_equal(rec$status, "PASS")
  expect_equal(sum(is.na(rec$result$published)), 1)
})

test_that("splice INSERTS rows for a wave the values table has never held", {
  values <- data.frame(metric_id = c("A", "B"), wave = "2024",
                       metric_type = c("mean", "mean"),
                       value = c(9.0, 8.0), base = c(NA, NA),
                       sd = c(NA, NA), stringsAsFactors = FALSE)
  computed <- data.frame(metric_id = c("A", "B"), wave = "2025",
                         metric_type = c("mean", "mean"),
                         value = c(9.3, 8.2), base = c(750, 750),
                         sd = c(1.1, 1.3), n = c(750, 750),
                         stringsAsFactors = FALSE)
  sp <- splice_wave_values(values, computed, "2025")
  expect_equal(sp$status, "PASS")
  expect_equal(sp$inserted, 2L)
  expect_equal(sp$replaced, 0L)
  new_rows <- sp$values[as.character(sp$values$wave) == "2025", , drop = FALSE]
  expect_equal(nrow(new_rows), 2L)
  expect_equal(new_rows$value[new_rows$metric_id == "A"], 9.3)
  expect_equal(new_rows$sd[new_rows$metric_id == "B"], 1.3)
  # history untouched
  expect_equal(sp$values$value[sp$values$metric_id == "A" & sp$values$wave == "2024"], 9.0)
})

test_that("splice REPLACES existing rows and leaves other waves alone", {
  values <- data.frame(metric_id = c("A", "A", "B"), wave = c("2024", "2025", "2025"),
                       metric_type = "mean",
                       value = c(9.0, 9.9, 7.7), base = NA, sd = NA,
                       stringsAsFactors = FALSE)
  computed <- data.frame(metric_id = "A", wave = "2025", metric_type = "mean",
                         value = 9.3, base = 750, sd = 1.1, n = 750,
                         stringsAsFactors = FALSE)
  sp <- splice_wave_values(values, computed, "2025")
  expect_equal(sp$replaced, 1L)
  expect_equal(sp$inserted, 0L)
  expect_equal(sp$values$value[sp$values$metric_id == "A" & sp$values$wave == "2025"], 9.3)
  expect_equal(sp$values$base[sp$values$metric_id == "A" & sp$values$wave == "2025"], 750)
  expect_equal(sp$values$value[sp$values$metric_id == "A" & sp$values$wave == "2024"], 9.0)
  expect_equal(sp$values$value[sp$values$metric_id == "B" & sp$values$wave == "2025"], 7.7)
})

test_that("splice refuses on a values table without the contract columns", {
  bad <- data.frame(x = 1)
  computed <- data.frame(metric_id = "A", wave = "2025", metric_type = "mean",
                         value = 9.3, base = 750, sd = 1.1,
                         stringsAsFactors = FALSE)
  expect_equal(splice_wave_values(bad, computed, "2025")$status, "REFUSED")
})


# ==============================================================================
# I22 (production review 2026-08): NA weights refuse; proportions weight;
# an unresolvable category skips by name.
# ==============================================================================

test_that("an NA in the weight column REFUSES - never NA-under-PASS (I22)", {
  d <- data.frame(RATE = c(9, 8, 10, 7), W = c(1, NA, 1.2, 0.8),
                  stringsAsFactors = FALSE)
  m <- wave_values_from_microdata(
    d, data.frame(QuestionCode = "RATE", TrackingSpecs = "mean",
                  stringsAsFactors = FALSE), NULL, wave = "2025", weights = "W")
  expect_equal(m$status, "REFUSED")
  expect_equal(m$code, "DATA_WEIGHT_INVALID")
})

test_that("proportions honour weights (they were silently ignored - I22)", {
  d <- data.frame(YN = c("Yes", "Yes", "No", "No"), W = c(10, 10, 1, 1),
                  stringsAsFactors = FALSE)
  m <- wave_values_from_microdata(
    d, data.frame(QuestionCode = "YN", TrackingSpecs = "category:Yes",
                  stringsAsFactors = FALSE), NULL, wave = "2025", weights = "W")
  expect_equal(m$status, "PASS")
  r <- NULL; for (i in seq_len(nrow(m$result))) if (m$result$metric_id[i] == "YN") r <- m$result[i, ]
  expect_equal(r$value, 20 / 22 * 100, tolerance = 1e-9)   # 90.9 weighted, not 50 raw
  expect_equal(r$base, 4)                                  # base stays the respondent count
})

test_that("an unresolvable category SKIPS AND NAMES instead of computing 0% (I22)", {
  d <- data.frame(Q1 = c("Agree", "Neutral", "Disagree"), stringsAsFactors = FALSE)
  opts <- data.frame(QuestionCode = "Q1",
                     OptionText = c("Agree", "Neutral", "Disagree"),
                     BoxCategory = c("", "", ""), stringsAsFactors = FALSE)
  m <- wave_values_from_microdata(
    d, data.frame(QuestionCode = "Q1", TrackingSpecs = "category:NET POSITIVE",
                  stringsAsFactors = FALSE), opts, wave = "2025")
  expect_false(identical(m$status, "PASS"))
  expect_true("Q1" %in% m$skipped$metric_id)
  expect_true(any(grepl("NET POSITIVE", m$skipped$reason)))
})

test_that("a genuine 0% category (option exists, nobody chose it) still computes (I22)", {
  d <- data.frame(Q1 = c("Agree", "Neutral"), stringsAsFactors = FALSE)
  opts <- data.frame(QuestionCode = "Q1",
                     OptionText = c("Agree", "Neutral", "Disagree"),
                     BoxCategory = c("", "", ""), stringsAsFactors = FALSE)
  m <- wave_values_from_microdata(
    d, data.frame(QuestionCode = "Q1", TrackingSpecs = "category:Disagree",
                  stringsAsFactors = FALSE), opts, wave = "2025")
  expect_equal(m$status, "PASS")
  r <- NULL; for (i in seq_len(nrow(m$result))) if (m$result$metric_id[i] == "Q1") r <- m$result[i, ]
  expect_equal(r$value, 0)
  expect_equal(r$base, 2)
})


# ==============================================================================
# M14 (review 2026-08): a recovered wave's multi-mention COLUMNS are resolved
# through that wave's OWN structure. Which option texts make up the NET is the
# tracking definition's business (net_options); which data column carries which
# option text is a fact about this wave's data. Reading the column map from
# net_options meant a wave whose options were renumbered counted the wrong
# mentions, silently and under PASS.
# ==============================================================================

test_that("multi-mention member columns follow THIS wave's structure, not the NET's (M14)", {
  # This wave's data: MM_1 holds Tue, MM_2 holds Mon. The tracking NET
  # ("Weekday start" = Mon only) is declared against the CURRENT wave, where the
  # numbering is the other way round.
  d <- data.frame(
    MM_1 = c("Tue", "Tue", "Tue", NA),
    MM_2 = c(NA, "Mon", NA, NA),
    MM_3 = c(NA, NA, NA, "None"),
    stringsAsFactors = FALSE)
  this_wave <- data.frame(
    QuestionCode = c("MM_1", "MM_2", "MM_3"),
    OptionText   = c("Tue", "Mon", "None"),
    BoxCategory  = c("", "Weekday start", ""), stringsAsFactors = FALSE)
  net_defs <- data.frame(                       # the CURRENT wave's numbering
    QuestionCode = c("MM_1", "MM_2", "MM_3"),
    OptionText   = c("Mon", "Tue", "None"),
    BoxCategory  = c("Weekday start", "", ""), stringsAsFactors = FALSE)
  map <- data.frame(QuestionCode = "MM", TrackingSpecs = "category:Weekday start",
                    stringsAsFactors = FALSE)
  m <- wave_values_from_microdata(d, map, this_wave, wave = "2024",
                                  net_options = net_defs)
  expect_equal(m$status, "PASS")
  r <- NULL; for (i in seq_len(nrow(m$result))) if (m$result$metric_id[i] == "MM") r <- m$result[i, ]
  expect_equal(r$base, 4)                       # answered any of MM_1..MM_3
  # Mon lives in MM_2 in THIS wave -> 1 of 4. Resolving the columns through
  # net_defs would have counted MM_1 (Tue) and reported 3 of 4.
  expect_equal(r$value, 25)
})

test_that("the NET's MEMBERSHIP still comes from the tracking definition (M14)", {
  # Same data, but this wave's own structure tags a DIFFERENT option as the NET.
  # Membership must follow net_options (Mon), not this wave's tag (Tue): that
  # is the whole point of declaring the NET against one wave's structure.
  d <- data.frame(
    MM_1 = c("Tue", "Tue", "Tue", NA),
    MM_2 = c(NA, "Mon", NA, NA),
    MM_3 = c(NA, NA, NA, "None"),
    stringsAsFactors = FALSE)
  this_wave <- data.frame(
    QuestionCode = c("MM_1", "MM_2", "MM_3"),
    OptionText   = c("Tue", "Mon", "None"),
    BoxCategory  = c("Weekday start", "", ""), stringsAsFactors = FALSE)
  net_defs <- data.frame(
    QuestionCode = c("MM_1", "MM_2", "MM_3"),
    OptionText   = c("Mon", "Tue", "None"),
    BoxCategory  = c("Weekday start", "", ""), stringsAsFactors = FALSE)
  map <- data.frame(QuestionCode = "MM", TrackingSpecs = "category:Weekday start",
                    stringsAsFactors = FALSE)
  m <- wave_values_from_microdata(d, map, this_wave, wave = "2024",
                                  net_options = net_defs)
  expect_equal(m$status, "PASS")
  r <- NULL; for (i in seq_len(nrow(m$result))) if (m$result$metric_id[i] == "MM") r <- m$result[i, ]
  expect_equal(r$value, 25)                     # still Mon, still MM_2 in this wave
})

test_that("with no structure of its own, a recovery run falls back to the NET's (M14)", {
  d <- data.frame(
    MM_1 = c("Mon", "Mon", NA, NA),
    MM_2 = c(NA, "Tue", "Tue", NA),
    MM_3 = c(NA, NA, NA, "None"),
    stringsAsFactors = FALSE)
  net_defs <- data.frame(
    QuestionCode = c("MM_1", "MM_2", "MM_3"),
    OptionText   = c("Mon", "Tue", "None"),
    BoxCategory  = c("Weekday start", "", ""), stringsAsFactors = FALSE)
  map <- data.frame(QuestionCode = "MM", TrackingSpecs = "category:Weekday start",
                    stringsAsFactors = FALSE)
  m <- wave_values_from_microdata(d, map, NULL, wave = "2024", net_options = net_defs)
  expect_equal(m$status, "PASS")
  r <- NULL; for (i in seq_len(nrow(m$result))) if (m$result$metric_id[i] == "MM") r <- m$result[i, ]
  expect_equal(r$base, 4)
  expect_equal(r$value, 50)                     # Mon in MM_1: rows 1 and 2
})
