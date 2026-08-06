# ==============================================================================
# TABS MODULE - STATISTICAL SEMANTICS (review 2026-08, I1 / I5 / I6)
# ==============================================================================
#
# Three findings about what the significance machinery is actually testing, as
# opposed to what the row above it prints.
#
#   I1  NPS rows stored raw 0-10 ratings as their test values, so the Sig. row
#       answered "is the mean RATING different" while the row printed the NET of
#       promoters and detractors. Excel and the v2 JS engine (which has always
#       used +-100 buckets) could letter the same NPS row differently.
#   I5  The finite population correction reached the category rows and the NET
#       difference rows but not NET POSITIVE or composites, so on a census
#       project one table carried two universes.
#   I6  The chi-square row read its counts back out of the FORMATTED Frequency
#       rows — the one place a display rounding fed a statistical decision — and
#       had no design correction, so population-projected weights manufactured
#       significance without limit. It was also the only significance path in
#       the module with no known-answer test.
#
# Every expected value below is hand-derived in the comment above it, or checked
# against an independent computation (base R's own chisq.test / pnorm) rather
# than against the code under test.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_stats_semantics.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))
source(file.path(turas_root, "modules/tabs/lib/cell_calculator.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))
# score_utils supplies nps_bucket_score(), the module's single definition of the
# NPS bucket; report_shared supplies the FPC helpers.
source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/report_shared.R"))
source(file.path(turas_root, "modules/tabs/lib/composite_processor.R"))

# standard_processor.R needs a few run_crosstabs.R constants and the shared
# rbind helper, the same way test_standard_processor.R sets them up.
if (!exists("TOTAL_COLUMN")) assign("TOTAL_COLUMN", "Total", envir = globalenv())
if (!exists("batch_rbind")) {
  assign("batch_rbind", function(row_list) {
    if (length(row_list) == 0) return(data.frame())
    all_cols <- unique(unlist(lapply(row_list, names)))
    row_list <- lapply(row_list, function(df) {
      for (col in setdiff(all_cols, names(df))) df[[col]] <- NA
      df[, all_cols, drop = FALSE]
    })
    do.call(rbind, row_list)
  }, envir = globalenv())
}
# add_net_positive_significance routes through add_significance_row (the same
# wrapper every mean row uses) since review 2026-08 I5; extract it and its test
# runner out of the orchestrator by text, as test_standard_processor.R does.
if (!exists("SIG_ROW_TYPE")) assign("SIG_ROW_TYPE", "Sig.", envir = globalenv())
if (!exists("SIG2_ROW_TYPE")) assign("SIG2_ROW_TYPE", "Sig.2", envir = globalenv())
if (!exists("DEFAULT_ALPHA")) assign("DEFAULT_ALPHA", 0.05, envir = globalenv())
if (!exists("DEFAULT_MIN_BASE")) assign("DEFAULT_MIN_BASE", 30, envir = globalenv())
if (!exists("add_significance_row")) {
  .rc_lines <- readLines(file.path(turas_root, "modules/tabs/lib/run_crosstabs.R"))
  .rc_start <- grep("^run_significance_tests_for_row <- function", .rc_lines)
  .rc_end   <- grep("^add_significance_row <- function", .rc_lines)
  .rc_next  <- grep("^(#' Write question table|write_question_table_fast)", .rc_lines)
  .rc_next  <- .rc_next[.rc_next > .rc_end[1]][1] - 1
  eval(parse(text = .rc_lines[.rc_start[1]:.rc_next]), envir = globalenv())
  rm(.rc_lines, .rc_start, .rc_end, .rc_next)
}
source(file.path(turas_root, "modules/tabs/lib/standard_processor.R"))
source(file.path(turas_root, "modules/tabs/lib/numeric_processor.R"))
# ranking.R resolves its own sub-files through .tabs_lib_dir
assign(".tabs_lib_dir", file.path(turas_root, "modules/tabs/lib"), envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/ranking.R"))
source(file.path(turas_root, "modules/tabs/lib/allocation_processor.R"))
source(file.path(turas_root, "modules/tabs/lib/question_orchestrator.R"))
if (!exists("safe_execute")) {
  assign("safe_execute", function(expr, default = NA, error_msg = "Operation failed",
                                  silent = FALSE) {
    tryCatch(expr, error = function(e) {
      if (!silent) cat(sprintf("  [WARNING] %s: %s\n", error_msg, conditionMessage(e)))
      default
    })
  }, envir = globalenv())
}


# ==============================================================================
# I1. NPS ROWS TEST THE NPS, NOT THE MEAN RATING
# ==============================================================================

context("I1: NPS significance rides +-100 bucket scores")

test_that("calculate_nps_score stores +-100 buckets, not raw ratings", {
  # 9 and 10 are promoters (+100), 7 and 8 passives (0), 0-6 detractors (-100).
  data <- data.frame(Q = c(10, 9, 8, 7, 6, 0), stringsAsFactors = FALSE)
  res <- calculate_nps_score(data, "Q", rep(1, 6))

  expect_equal(res$values, c(100, 100, 0, 0, -100, -100))
  # The regression: the raw ratings must NOT be what the row carries.
  expect_false(isTRUE(all.equal(res$values, c(10, 9, 8, 7, 6, 0))))
})

test_that("every 0-10 answer buckets exactly as nps_bucket_score does", {
  # One definition of the bucket for the whole module: the Excel engine, the
  # microdata writer and the v2 JS engine must agree answer by answer.
  data <- data.frame(Q = 0:10, stringsAsFactors = FALSE)
  res <- calculate_nps_score(data, "Q", rep(1, 11))
  expect_equal(res$values, vapply(0:10, nps_bucket_score, numeric(1)))
})

test_that("the published NPS is the weighted mean of the values it tests", {
  # If these two ever part company, the Sig. row and the Standard Deviation row
  # stop describing the number printed above them.
  data <- data.frame(Q = c(10, 10, 9, 8, 7, 6, 3, 0), stringsAsFactors = FALSE)
  w <- c(2.5, 1, 1, 3, 1, 1, 0.5, 2)
  res <- calculate_nps_score(data, "Q", w)

  expect_equal(res$value,
               sum(res$values * res$weights) / sum(res$weights),
               tolerance = 1e-12)

  # And it is still promoters minus detractors, hand-derived:
  #   promoters (10,10,9) = 2.5 + 1 + 1 = 4.5
  #   detractors (6,3,0)  = 1 + 0.5 + 2 = 3.5
  #   total               = 12
  #   NPS = (4.5 - 3.5)/12 * 100 = 8.3333...
  expect_equal(res$value, (4.5 - 3.5) / 12 * 100, tolerance = 1e-9)
})

test_that("two columns with the SAME NPS earn no letter (I1's repro)", {
  # Both columns score NPS 0 — 10 promoters against 10 detractors — but out of
  # very different ratings, so their mean RATINGS are 5.0 and 7.5.
  #   A: ten 10s and ten 0s      B: ten 9s and ten 6s
  # Before the fix the summary Sig. row t-tested those raw ratings and called
  # the pair significant at p = 0.043, printing a letter on two identical NPS
  # scores. Executed against the pre-fix code.
  a <- data.frame(Q = c(rep(10, 10), rep(0, 10)), stringsAsFactors = FALSE)
  b <- data.frame(Q = c(rep(9, 10), rep(6, 10)), stringsAsFactors = FALSE)

  ra <- calculate_nps_score(a, "Q", rep(1, 20))
  rb <- calculate_nps_score(b, "Q", rep(1, 20))
  expect_equal(ra$value, 0)
  expect_equal(rb$value, 0)

  res <- weighted_t_test_means(ra$values, rb$values, ra$weights, rb$weights,
                               min_base = 10, alpha = 0.05)
  expect_false(res$significant)
  expect_equal(res$p_value, 1)   # identical bucket distributions
})

test_that("a genuine NPS gap is still detected", {
  # Guard against a false pass: prove the refusal above is the statistic and not
  # a test that stopped working. Column A is 30 promoters / 10 detractors
  # (NPS +50), column B is 10 promoters / 30 detractors (NPS -50).
  a <- data.frame(Q = c(rep(10, 30), rep(2, 10)), stringsAsFactors = FALSE)
  b <- data.frame(Q = c(rep(10, 10), rep(2, 30)), stringsAsFactors = FALSE)
  ra <- calculate_nps_score(a, "Q", rep(1, 40))
  rb <- calculate_nps_score(b, "Q", rep(1, 40))
  expect_equal(ra$value, 50)
  expect_equal(rb$value, -50)

  res <- weighted_t_test_means(ra$values, rb$values, ra$weights, rb$weights,
                               min_base = 30, alpha = 0.05)
  expect_true(res$significant)
  expect_true(res$higher)
})

test_that("KNOWN LIMIT: two uniform NPS columns are not tested (M-B)", {
  # Recorded, not fixed here. weighted_t_test_means returns p = 1 when both
  # groups have zero variance (open finding M-B), so a column where everyone is
  # a promoter against one where everyone is a detractor — NPS +100 vs -100,
  # the widest gap the metric allows — draws no letter.
  #
  # The +-100 buckets make that case reachable on real data in a way the raw
  # 0-10 ratings did not: "every respondent in this column is a promoter" is an
  # ordinary small-column outcome, while "every respondent gave exactly the same
  # rating" is rare. M-B therefore bites NPS rows harder after this fix than
  # before it. This test exists so the behaviour is pinned and visible rather
  # than discovered in a deliverable.
  a <- data.frame(Q = rep(10, 40), stringsAsFactors = FALSE)
  b <- data.frame(Q = rep(0, 40), stringsAsFactors = FALSE)
  ra <- calculate_nps_score(a, "Q", rep(1, 40))
  rb <- calculate_nps_score(b, "Q", rep(1, 40))
  expect_equal(ra$value, 100)
  expect_equal(rb$value, -100)

  res <- weighted_t_test_means(ra$values, rb$values, ra$weights, rb$weights,
                               min_base = 30, alpha = 0.05)
  expect_false(res$significant)
  expect_equal(res$p_value, 1)
})

test_that("the Standard Deviation row is the SD of the tested values", {
  # Ten promoters and ten detractors: buckets are ten +100s and ten -100s, so
  # the sample SD is sqrt(sum((x - 0)^2)/19) = sqrt(20 * 10000 / 19) = 102.598.
  # The raw ratings (ten 10s, ten 0s) would give 5.1299 — the number this row
  # used to print under an NPS of 0.
  data <- data.frame(Q = c(rep(10, 10), rep(0, 10)), stringsAsFactors = FALSE)
  res <- calculate_nps_score(data, "Q", rep(1, 20))

  expect_equal(sd(res$values), sqrt(20 * 10000 / 19), tolerance = 1e-9)
  expect_equal(sd(res$values), 102.5978, tolerance = 1e-4)
  expect_false(isTRUE(all.equal(sd(res$values), 5.1299, tolerance = 1e-4)))
})

test_that("published NPS values are unchanged for real 0-10 data", {
  # The behaviour change is confined to the TEST values. Every NPS a shipped
  # deliverable has ever printed came from integer 0-10 answers, and those are
  # identical before and after.
  expect_equal(calculate_nps_score(
    data.frame(Q = c(9, 10, 9, 10, 10)), "Q", rep(1, 5))$value, 100)
  expect_equal(calculate_nps_score(
    data.frame(Q = c(0, 1, 2, 3, 4)), "Q", rep(1, 5))$value, -100)
  # 3 promoters, 2 detractors, 1 passive -> (3-2)/6*100
  expect_equal(calculate_nps_score(
    data.frame(Q = c(9, 10, 10, 0, 3, 8)), "Q", rep(1, 6))$value,
    (3 - 2) / 6 * 100, tolerance = 1e-9)
  # DK / blank / non-numeric still leave the base
  expect_equal(calculate_nps_score(
    data.frame(Q = c("9", "10", "DK", "Don't know", "", "0"),
               stringsAsFactors = FALSE), "Q", rep(1, 6))$value,
    (2 - 1) / 3 * 100, tolerance = 1e-9)
})


# ==============================================================================
# I5. THE FPC REACHES NET POSITIVE AND COMPOSITES
# ==============================================================================
#
# THE FIXTURE. Four cohorts, the parity project's universes, so the same
# hand-derivation covers both files:
#
#   Column   n    Universe N   apply_fpc(1, n, N)      what it exercises
#   ------   --   ----------   ---------------------   ------------------
#   Alpha    40   40           Inf                     full census
#   Beta     60   150          149/90 = 1.6555556      a real correction
#   Gamma    50   (none)       1                       no universe
#   Delta    50   (none)       1                       no universe
#
# Four testable columns, so the Bonferroni divisor is choose(4, 2) = 6 and the
# adjusted alpha is 0.05/6 = 0.008333333 — the same divisor the category rows
# above the NET use.

context("I5: FPC through NET POSITIVE and composites")

FPC_COHORTS <- c(Alpha = 40L, Beta = 60L, Gamma = 50L, Delta = 50L)

make_fpc_banner <- function(data) {
  selection_df <- data.frame(
    QuestionCode = "Cohort", Include = "N", UseBanner = "Y",
    BannerBoxCategory = "N", BannerLabel = "Cohort", DisplayOrder = 1,
    stringsAsFactors = FALSE
  )
  survey_structure <- list(
    questions = data.frame(
      QuestionCode = "Cohort", QuestionText = "Cohort",
      Variable_Type = "Single_Response", Columns = "Cohort",
      stringsAsFactors = FALSE),
    options = data.frame(
      QuestionCode = rep("Cohort", 4),
      OptionText = names(FPC_COHORTS),
      DisplayText = names(FPC_COHORTS),
      ShowInOutput = rep("Y", 4),
      stringsAsFactors = FALSE)
  )
  banner <- create_banner_structure(selection_df, survey_structure)
  idx <- create_banner_row_indices(data, banner)
  list(banner = banner,
       indices = idx$row_indices,
       bases = calculate_banner_bases(idx, rep(1, nrow(data)), is_weighted = FALSE))
}

# Population sheet: Alpha is a full census, Beta a real correction, Gamma and
# Delta have no declared universe.
FPC_POP_FRAME <- data.frame(
  banner = c("Cohort", "Cohort"),
  group = c("Alpha", "Beta"),
  population = c(40, 150),
  stringsAsFactors = FALSE
)

fpc_config <- function(with_population) {
  cfg <- list(alpha = 0.05, bonferroni_correction = TRUE,
              significance_min_base = 30, alpha_secondary = NULL,
              apply_weighting = FALSE)
  if (with_population) cfg$population_frame <- FPC_POP_FRAME
  cfg
}

fpc_cohort_column <- function() {
  rep(names(FPC_COHORTS), times = unname(FPC_COHORTS))
}

test_that("the fixture's universes resolve to the multipliers claimed above", {
  data <- data.frame(Cohort = fpc_cohort_column(), stringsAsFactors = FALSE)
  fx <- make_fpc_banner(data)
  muls <- build_fpc_multipliers(
    fx$bases, resolve_column_populations(fx$banner, fpc_config(TRUE)),
    fx$banner$internal_keys)

  expect_true(is.infinite(muls[["Cohort::Alpha"]]))
  expect_equal(unname(muls[["Cohort::Beta"]]), 149 / 90, tolerance = 1e-9)
  expect_equal(unname(muls[["Cohort::Gamma"]]), 1)
  expect_equal(unname(muls[["Cohort::Delta"]]), 1)
})

test_that("NET POSITIVE letters take the same FPC as the rows above them", {
  # Box counts, chosen so that ONE letter appears and ONE disappears:
  #
  #   Column   n    top   bottom   middle   NET POSITIVE
  #   ------   --   ---   ------   ------   ------------
  #   Alpha    40    30      8        2      +55.0
  #   Beta     60    37     12       11      +41.666667
  #   Gamma    50    20     20       10        0.0
  #   Delta    50    25     10       15      +30.0
  #
  # Since review 2026-08 (I5) these letters test the printed net through the
  # per-respondent +-100 score, so the pairs are Welch t-tests of those score
  # means, not z-tests of the top box. Each column's score variance is the
  # Bessel-corrected sample variance of its own +-100 vector:
  #
  #   population variance = (t + b - (t - b)^2) * 100^2, x n/(n-1)
  #   Alpha (0.75 + 0.20 - 0.55^2) * 1e4 * 40/39 = 6641.0256
  #   Beta  (0.616667 + 0.20 - 0.416667^2) * 1e4 * 60/59 = 6539.5480
  #   Gamma (0.40 + 0.40 - 0)  * 1e4 * 50/49 = 8163.2653
  #   Delta (0.50 + 0.20 - 0.30^2) * 1e4 * 50/49 = 6224.4898
  #
  # Alpha vs Gamma, uncorrected:
  #   SE = sqrt(6641.0256/40 + 8163.2653/50) = 18.146378
  #   t  = 55 / 18.146378 = 3.030903, df = 86.69  ->  p = 0.003214 < 0.00833333
  #   So without the correction Alpha prints "C" — on a column where every
  #   member of the universe was interviewed and there is no sampling error to
  #   test. With the FPC, Alpha's multiplier is Inf and the pair is not tested.
  #
  # Beta vs Gamma, uncorrected:
  #   SE = sqrt(6539.5480/60 + 8163.2653/50) = 16.500229
  #   t  = 41.666667 / 16.500229 = 2.525217, df = 99.45 -> p = 0.013143 (no letter)
  #   Corrected, Beta's effective base is 60 * 149/90 = 99.333333:
  #   SE = sqrt(6539.5480/99.333333 + 8163.2653/50) = 15.136040
  #   t  = 41.666667 / 15.136040 = 2.752843, df = 89.25 -> p = 0.007157  ("C")
  #
  # Every other pair is comfortably non-significant either way (the widest is
  # Delta vs Gamma at p = 0.080). The two p-values that straddle the threshold
  # are confirmed below against base R's pt(), not against the function under
  # test.
  alpha_adj <- 0.05 / 6
  welch_p <- function(m1, v1, n1, m2, v2, n2) {
    se2 <- v1 / n1 + v2 / n2
    tt <- (m1 - m2) / sqrt(se2)
    df <- se2^2 / ((v1 / n1)^2 / (n1 - 1) + (v2 / n2)^2 / (n2 - 1))
    2 * pt(-abs(tt), df)
  }
  V <- c(Alpha = 6641.025641, Beta = 6539.547980,
         Gamma = 8163.265306, Delta = 6224.489796)
  p_alpha_gamma <- welch_p(55, V[["Alpha"]], 40, 0, V[["Gamma"]], 50)
  p_beta_plain  <- welch_p(125 / 3, V[["Beta"]], 60, 0, V[["Gamma"]], 50)
  p_beta_fpc    <- welch_p(125 / 3, V[["Beta"]], 60 * 149 / 90, 0, V[["Gamma"]], 50)
  expect_equal(p_alpha_gamma, 0.003214, tolerance = 1e-4)
  expect_lt(p_alpha_gamma, alpha_adj)
  expect_gt(p_beta_plain, alpha_adj)
  expect_lt(p_beta_fpc, alpha_adj)

  data <- data.frame(Cohort = fpc_cohort_column(), stringsAsFactors = FALSE)
  fx <- make_fpc_banner(data)
  keys <- fx$banner$internal_keys

  # The +-100 score vector, laid out in the same row order as fpc_cohort_column()
  # (Alpha's 40 rows, then Beta's 60, Gamma's 50, Delta's 50).
  box_scores <- function(n, top, bot) c(rep(100, top), rep(-100, bot),
                                        rep(0, n - top - bot))
  net_scores <- c(box_scores(40, 30,  8), box_scores(60, 37, 12),
                  box_scores(50, 20, 20), box_scores(50, 25, 10))
  weights <- rep(1, nrow(data))

  with_pop <- add_net_positive_significance(
    net_scores, fx$indices, weights, fx$bases, keys, fx$banner,
    fpc_config(TRUE), is_weighted = FALSE)
  no_pop <- add_net_positive_significance(
    net_scores, fx$indices, weights, fx$bases, keys, fx$banner,
    fpc_config(FALSE), is_weighted = FALSE)

  # No universe configured: the pre-fix letters, unchanged. This is the
  # guarantee that reports without a Population sheet are untouched.
  expect_equal(no_pop[["Cohort::Alpha"]], "C")
  expect_equal(no_pop[["Cohort::Beta"]], "")
  expect_equal(no_pop[["Cohort::Gamma"]], "")
  expect_equal(no_pop[["Cohort::Delta"]], "")

  # Universes configured: the census column stops lettering, the corrected
  # column starts.
  expect_equal(with_pop[["Cohort::Alpha"]], "")
  expect_equal(with_pop[["Cohort::Beta"]], "C")
  expect_equal(with_pop[["Cohort::Gamma"]], "")
  expect_equal(with_pop[["Cohort::Delta"]], "")
})

test_that("composite letters take the same FPC as the rows above them", {
  # A composite over one numeric source, so its value is that source. Alpha
  # (the census) is given a mean far enough above Gamma to letter without the
  # correction; with it, Alpha is excluded from pairing entirely.
  set.seed(11)
  cohort <- fpc_cohort_column()
  score <- ifelse(cohort == "Alpha", 8, ifelse(cohort == "Beta", 6, 5))
  # A little within-column spread, deterministic across platforms.
  score <- score + rep(c(-0.5, 0, 0.5, 0), length.out = length(score))
  data <- data.frame(Cohort = cohort, S1 = score, stringsAsFactors = FALSE)

  fx <- make_fpc_banner(data)
  questions_df <- data.frame(
    QuestionCode = "S1", QuestionText = "S1", Variable_Type = "Numeric",
    stringsAsFactors = FALSE)

  run <- function(with_population) {
    test_composite_significance(
      data = data, composite_code = "CMP", source_questions = "S1",
      calculation_type = "Mean", calc_weights = NULL,
      banner_info = fx$banner, config = fpc_config(with_population),
      questions_df = questions_df, options_df = NULL)
  }

  no_pop   <- run(FALSE)
  with_pop <- run(TRUE)

  # Alpha's mean (8.0) is well above Gamma's and Delta's (5.0): uncorrected it
  # letters both. Confirmed independently below by calling the shared t-test.
  expect_true(nchar(no_pop[["Cohort::Alpha"]]) > 0)

  # A full census has no sampling error left, so it neither earns a letter nor
  # grants one to anybody else.
  expect_equal(with_pop[["Cohort::Alpha"]], "")
  expect_false(grepl("A", with_pop[["Cohort::Beta"]], fixed = TRUE))
  expect_false(grepl("A", with_pop[["Cohort::Gamma"]], fixed = TRUE))
  expect_false(grepl("A", with_pop[["Cohort::Delta"]], fixed = TRUE))

  # And the wiring reaches weighted_t_test_means, not just the letter string:
  # the same pair, called directly, agrees with each version of the row.
  a <- score[cohort == "Alpha"]; g <- score[cohort == "Gamma"]
  plain <- weighted_t_test_means(a, g, min_base = 30, alpha = 0.05 / 6)
  census <- weighted_t_test_means(a, g, min_base = 30, alpha = 0.05 / 6,
                                  fpc_mul1 = Inf, fpc_mul2 = 1)
  expect_true(plain$significant)
  expect_false(census$significant)
  expect_true(is.na(census$p_value))
})

test_that("composite subset resolution falls back to the banner key", {
  # banner_info$subsets is absent here (create_banner_structure does not build
  # it), so both the bases the FPC reads and the rows each test reads come from
  # the key parser — one helper, so they cannot disagree.
  data <- data.frame(Cohort = fpc_cohort_column(), stringsAsFactors = FALSE)
  fx <- make_fpc_banner(data)

  expect_length(composite_subset_indices(fx$banner, data, "Cohort::Beta"), 60)
  expect_length(composite_subset_indices(fx$banner, data, "TOTAL::Total"), 200)
  expect_length(composite_subset_indices(fx$banner, data, "Cohort::Missing"), 0)
  # An explicit subset wins over the parser.
  b2 <- fx$banner
  b2$subsets <- list("Cohort::Beta" = 1:7)
  expect_equal(composite_subset_indices(b2, data, "Cohort::Beta"), 1:7)
})


# ==============================================================================
# I6. CHI-SQUARE READS THE COUNTS IT COMPUTED, ON THE DESIGN'S OWN SCALE
# ==============================================================================

context("I6: chi-square inputs")

chi_banner <- list(internal_keys = c("TOTAL::Total", "G::Male", "G::Female"))
chi_config <- list(alpha = 0.05)

# A display frame carrying whatever counts we hand it, in the shape
# add_boxcategory_summaries produces.
chi_frame <- function(male, female) {
  data.frame(
    RowLabel = c("Top 2 Box", "Bottom 2 Box"),
    RowType = c("Frequency", "Frequency"),
    RowSource = c("boxcategory", "boxcategory"),
    "TOTAL::Total" = male + female,
    "G::Male" = male,
    "G::Female" = female,
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

chi_counts <- function(male, female) {
  matrix(c(male[1], female[1], male[2], female[2]), nrow = 2, byrow = TRUE,
         dimnames = list(c("Top 2 Box", "Bottom 2 Box"), c("G::Male", "G::Female")))
}

# Pull chi^2, df and p back out of the row's message.
chi_parse <- function(row) {
  stopifnot(!is.null(row))
  m <- regmatches(row$RowLabel,
                  regexec("χ²=([0-9.]+), df=([0-9]+), p=([0-9.]+)", row$RowLabel))[[1]]
  list(stat = as.numeric(m[2]), df = as.integer(m[3]), p = as.numeric(m[4]))
}

test_that("KNOWN ANSWER: the 2x2 matches base R's chisq.test", {
  # The module's only significance path with no known-answer test anywhere in
  # the suite (I12d). Pearson, no continuity correction:
  #   observed  70 30 / 30 70,  every expected = 50
  #   X2 = 4 * (20^2 / 50) = 32,  df = (2-1)(2-1) = 1
  obs <- matrix(c(70, 30, 30, 70), nrow = 2)
  ref <- chisq.test(obs, correct = FALSE)
  expect_equal(unname(ref$statistic), 32, tolerance = 1e-9)
  expect_equal(unname(ref$parameter), 1)

  got <- chi_parse(calculate_chi_square_row(
    chi_frame(c(70, 30), c(30, 70)), chi_banner, chi_config,
    box_counts = chi_counts(c(70, 30), c(30, 70))))

  expect_equal(got$stat, 32, tolerance = 0.005)
  expect_equal(got$df, 1L)
  expect_equal(got$p, unname(ref$p.value), tolerance = 1e-4)
})

test_that("KNOWN ANSWER: a 3x2 matches base R's chisq.test", {
  # Three categories, two columns. Hand-checked against chisq.test rather than
  # re-deriving the sum: the point is that Turas and base R agree exactly.
  male <- c(40, 35, 25); female <- c(20, 30, 50)
  obs <- cbind(male, female)
  ref <- chisq.test(obs, correct = FALSE)

  frame <- data.frame(
    RowLabel = c("Top", "Middle", "Bottom"),
    RowType = rep("Frequency", 3), RowSource = rep("boxcategory", 3),
    "TOTAL::Total" = male + female, "G::Male" = male, "G::Female" = female,
    check.names = FALSE, stringsAsFactors = FALSE)
  counts <- matrix(c(male, female), ncol = 2,
                   dimnames = list(c("Top", "Middle", "Bottom"),
                                   c("G::Male", "G::Female")))

  got <- chi_parse(calculate_chi_square_row(frame, chi_banner, chi_config,
                                            box_counts = counts))
  expect_equal(got$stat, unname(ref$statistic), tolerance = 0.005)
  expect_equal(got$df, unname(ref$parameter))
  expect_equal(got$p, unname(ref$p.value), tolerance = 1e-4)
})

test_that("the test reads the computed counts, not the rounded display row", {
  # A weighted table whose true counts are 28.4 / 21.6 (and the mirror). The
  # published Frequency row rounds those to 28 / 22 — and before the fix that
  # rounded pair was the matrix the test read.
  #   unrounded: X2 = 4 * (3.4^2 / 25) = 1.8496  ->  p = 0.17381
  #   rounded:   X2 = 4 * (3.0^2 / 25) = 1.44    ->  p = 0.23014
  raw_male <- c(28.4, 21.6); raw_female <- c(21.6, 28.4)
  expect_equal(unname(chisq.test(cbind(raw_male, raw_female),
                                 correct = FALSE)$statistic), 1.8496, tolerance = 1e-6)

  frame <- chi_frame(round(raw_male), round(raw_female))    # what the workbook shows
  got_rounded <- chi_parse(calculate_chi_square_row(frame, chi_banner, chi_config))
  got_raw <- chi_parse(calculate_chi_square_row(
    frame, chi_banner, chi_config, box_counts = chi_counts(raw_male, raw_female)))

  expect_equal(got_rounded$stat, 1.44, tolerance = 0.005)
  expect_equal(got_raw$stat, 1.85, tolerance = 0.005)
  expect_equal(got_raw$p, 0.1738, tolerance = 1e-3)
})

test_that("the p-value is invariant to the SCALE of the weights", {
  # The defect the review executed: population-projected weights (a design that
  # sums to the universe rather than to n) manufacture significance without
  # limit. Same design, weights multiplied by 10.
  #   30/20 vs 20/30 at n = 100 -> X2 = 4.0,  p = 0.0455
  #   the same at x10           -> X2 = 40.0, p = 2.5e-10 before the fix
  # Scaling each column to its effective base removes the dependence entirely.
  bases_1x <- list("G::Male"   = list(weighted = 50,  effective = 50,  unweighted = 50),
                   "G::Female" = list(weighted = 50,  effective = 50,  unweighted = 50))
  bases_10x <- list("G::Male"   = list(weighted = 500, effective = 50, unweighted = 50),
                    "G::Female" = list(weighted = 500, effective = 50, unweighted = 50))

  one <- chi_parse(calculate_chi_square_row(
    chi_frame(c(30, 20), c(20, 30)), chi_banner, chi_config,
    box_counts = chi_counts(c(30, 20), c(20, 30)), banner_bases = bases_1x))
  ten <- chi_parse(calculate_chi_square_row(
    chi_frame(c(300, 200), c(200, 300)), chi_banner, chi_config,
    box_counts = chi_counts(c(300, 200), c(200, 300)), banner_bases = bases_10x))

  expect_equal(one$stat, 4.0, tolerance = 0.005)
  expect_equal(ten$stat, one$stat, tolerance = 0.005)
  expect_equal(ten$p, one$p, tolerance = 1e-6)

  # Without the bases, the x10 table is the runaway the review found.
  runaway <- chi_parse(calculate_chi_square_row(
    chi_frame(c(300, 200), c(200, 300)), chi_banner, chi_config,
    box_counts = chi_counts(c(300, 200), c(200, 300))))
  expect_equal(runaway$stat, 40.0, tolerance = 0.005)
})

test_that("a design effect spends the precision it actually cost", {
  # Weighted bases of 100 per column but Kish effective bases of 50: the test
  # must read 50 people per column, not 100. Same split, half the evidence.
  bases <- list("G::Male"   = list(weighted = 100, effective = 50, unweighted = 100),
                "G::Female" = list(weighted = 100, effective = 50, unweighted = 100))
  full <- chi_parse(calculate_chi_square_row(
    chi_frame(c(60, 40), c(40, 60)), chi_banner, chi_config,
    box_counts = chi_counts(c(60, 40), c(40, 60))))
  eff <- chi_parse(calculate_chi_square_row(
    chi_frame(c(60, 40), c(40, 60)), chi_banner, chi_config,
    box_counts = chi_counts(c(60, 40), c(40, 60)), banner_bases = bases))

  # X2 scales linearly with the table total: 8.0 at n=200, 4.0 at n=100.
  expect_equal(full$stat, 8.0, tolerance = 0.005)
  expect_equal(eff$stat, 4.0, tolerance = 0.005)
  expect_gt(eff$p, full$p)
})

test_that("an unweighted run is exactly unchanged", {
  # effective == weighted == unweighted, so every multiplier is 1 and the
  # counts are already whole people. This is what keeps unweighted workbooks
  # byte-identical.
  bases <- list("G::Male"   = list(weighted = 100, effective = 100, unweighted = 100),
                "G::Female" = list(weighted = 100, effective = 100, unweighted = 100))
  expect_equal(unname(chi_square_design_scales(bases, names(bases))), c(1, 1))

  args <- list(chi_frame(c(70, 30), c(30, 70)), chi_banner, chi_config)
  before <- do.call(calculate_chi_square_row, args)
  after <- do.call(calculate_chi_square_row,
                   c(args, list(box_counts = chi_counts(c(70, 30), c(30, 70)),
                                banner_bases = bases)))
  expect_identical(before$RowLabel, after$RowLabel)
})

test_that("chi_square_design_scales is inert on anything it cannot read", {
  keys <- c("a", "b")
  expect_equal(unname(chi_square_design_scales(NULL, keys)), c(1, 1))
  expect_equal(unname(chi_square_design_scales(list(), keys)), c(1, 1))
  # Missing, zero and negative bases fall back to no scaling rather than
  # dividing by zero or flipping the sign of the table.
  odd <- list(a = list(weighted = 0, effective = 10),
              b = list(weighted = 10, effective = NA_real_))
  expect_equal(unname(chi_square_design_scales(odd, keys)), c(1, 1))
  # An unweighted-only base list reads effective == unweighted == weighted.
  plain <- list(a = list(unweighted = 40), b = list(unweighted = 60))
  expect_equal(unname(chi_square_design_scales(plain, keys)), c(1, 1))
})

test_that("boxcategory_count_matrix returns the counts before rounding", {
  # 3 respondents in one box carrying fractional weights: the matrix must hold
  # 2.4, which format_output_value(..., \"frequency\") would show as 2.
  data <- data.frame(
    Cohort = c("Alpha", "Alpha", "Alpha", "Beta"),
    Q = c("5", "5", "4", "1"),
    stringsAsFactors = FALSE
  )
  question_info <- data.frame(QuestionCode = "Q", Variable_Type = "Rating",
                              Columns = 1L, stringsAsFactors = FALSE)
  question_options <- data.frame(
    QuestionCode = rep("Q", 3), OptionText = c("5", "4", "1"),
    DisplayText = c("5", "4", "1"), ShowInOutput = rep("Y", 3),
    BoxCategory = c("Top 2 Box", "Top 2 Box", "Bottom Box"),
    stringsAsFactors = FALSE)
  keys <- c("TOTAL::Total", "C::Alpha", "C::Beta")
  row_idx <- list("TOTAL::Total" = 1:4, "C::Alpha" = 1:3, "C::Beta" = 4L)
  weights <- c(0.8, 0.8, 0.8, 2)

  m <- boxcategory_count_matrix(data, question_info, question_options,
                                row_idx, weights, keys)

  expect_equal(dim(m), c(2L, 3L))
  expect_equal(rownames(m), c("Top 2 Box", "Bottom Box"))
  expect_equal(unname(m["Top 2 Box", "C::Alpha"]), 2.4, tolerance = 1e-9)
  expect_equal(unname(m["Bottom Box", "C::Beta"]), 2, tolerance = 1e-9)
  # Not the rounded number the Frequency row prints.
  expect_false(isTRUE(all.equal(unname(m["Top 2 Box", "C::Alpha"]), 2)))
})

test_that("END TO END: the engine's chi-square row is the corrected one", {
  # The tests above pin the function; this one pins the WIRING, through the
  # orchestrator that actually builds the workbook row. Without it the fix could
  # be perfect and never reach a deliverable.
  #
  # 40 respondents, two banner columns, a 1-5 rating with Top 2 Box / Bottom 2
  # Box, and weights that vary within each column so the Kish effective base is
  # genuinely below n. What the row must NOT be is the number the pre-fix path
  # produces: the rounded display counts on the weighted scale.
  n_per <- 20L
  data <- data.frame(
    G = rep(c("Male", "Female"), each = n_per),
    Q = c(rep("5", 13), rep("2", 7),      # Male:   13 top, 7 bottom
          rep("5", 7),  rep("2", 13)),    # Female:  7 top, 13 bottom
    W = rep(c(1.8, 0.2), length.out = 2 * n_per),
    stringsAsFactors = FALSE
  )

  selection_df <- data.frame(
    QuestionCode = "G", Include = "N", UseBanner = "Y",
    BannerBoxCategory = "N", BannerLabel = "Gender", DisplayOrder = 1,
    stringsAsFactors = FALSE)
  survey_structure <- list(
    questions = data.frame(
      QuestionCode = c("G", "Q"),
      QuestionText = c("Gender", "Rating"),
      Variable_Type = c("Single_Response", "Rating"),
      Columns = c(1L, 1L), stringsAsFactors = FALSE),
    options = data.frame(
      QuestionCode = c("G", "G", "Q", "Q"),
      OptionText = c("Male", "Female", "5", "2"),
      DisplayText = c("Male", "Female", "5", "2"),
      ShowInOutput = rep("Y", 4),
      DisplayOrder = c(1L, 2L, 1L, 2L),
      BoxCategory = c(NA, NA, "Top 2 Box", "Bottom 2 Box"),
      ExcludeFromIndex = rep(NA_character_, 4),
      stringsAsFactors = FALSE)
  )
  banner <- create_banner_structure(selection_df, survey_structure)

  config <- list(
    show_frequency = TRUE, show_percent_column = TRUE, show_percent_row = FALSE,
    boxcategory_frequency = TRUE, boxcategory_percent_column = TRUE,
    boxcategory_percent_row = FALSE,
    decimal_places_percent = 0, decimal_places_ratings = 1, decimal_places_index = 1,
    enable_significance_testing = FALSE, enable_chi_square = TRUE,
    test_net_differences = FALSE,
    alpha = 0.05, bonferroni_correction = TRUE, significance_min_base = 30,
    zero_division_as_blank = TRUE, show_standard_deviation = FALSE,
    show_net_positive = FALSE, apply_weighting = TRUE, weight_variable = "W"
  )

  prepared <- prepare_question_data("Q", NA, data, survey_structure, banner, data$W)
  result <- process_single_question("Q", prepared, banner, config,
                                    is_weighted = TRUE,
                                    question_row = data.frame(
                                      QuestionCode = "Q", CreateIndex = "N",
                                      stringsAsFactors = FALSE))
  chi_row <- result$table[result$table$RowType == "ChiSquare", , drop = FALSE]
  expect_equal(nrow(chi_row), 1L)
  got <- chi_parse(chi_row)

  # Hand-derived. Weights alternate 1.8 / 0.2 across each column of 20, and Q's
  # answers run in blocks, so the weighted counts are not whole numbers:
  wt <- data$W
  male <- c(sum(wt[1:13]), sum(wt[14:20]))
  female <- c(sum(wt[21:27]), sum(wt[28:40]))
  expect_equal(male, c(13.8, 6.2), tolerance = 1e-9)      # published as 14 / 6
  expect_equal(female, c(7.8, 12.2), tolerance = 1e-9)    # published as  8 / 12
  # Each column's weighted base is 20 and its Kish effective base is
  #   (sum w)^2 / sum w^2 = 20^2 / (10*1.8^2 + 10*0.2^2) = 400 / 32.8 = 12.1951,
  # so every count is scaled by 12.1951/20 = 0.6097561.
  scale <- (20^2 / (10 * 1.8^2 + 10 * 0.2^2)) / 20
  expect_equal(scale, 0.6097561, tolerance = 1e-6)
  expected <- unname(chisq.test(cbind(male, female) * scale,
                                correct = FALSE)$statistic)
  expect_equal(got$stat, expected, tolerance = 0.005)

  # And it is NOT what the pre-fix path produced: the display-rounded counts on
  # the weighted scale, with no design correction. Both corrections move the
  # number, and the design correction can only ever move it DOWN — a weighted
  # design never carries more information than the people it interviewed.
  pre_fix <- unname(chisq.test(round(cbind(male, female)),
                               correct = FALSE)$statistic)
  unrounded_unscaled <- unname(chisq.test(cbind(male, female),
                                          correct = FALSE)$statistic)
  expect_false(isTRUE(all.equal(pre_fix, unrounded_unscaled, tolerance = 1e-3)))
  expect_lt(got$stat, pre_fix)
  expect_gt(pre_fix - got$stat, 1)
})

test_that("the chi-square row no longer depends on a display toggle", {
  # Recomputing the counts has a third consequence, found in the adversarial
  # pass and kept: the row no longer needs boxcategory_frequency switched on.
  # Reading the published Frequency rows meant a display setting decided whether
  # a statistical result appeared at all — the same defect M8 fixed for the
  # proportion letters. Executed: with the toggle off the pre-fix engine printed
  # no chi-square row; it now prints the same one it prints with the toggle on.
  #
  # The behaviour change to note: a config with boxcategory_frequency = N and
  # enable_chi_square = Y GAINS a row it never had.
  counts <- chi_counts(c(13, 7), c(7, 13))

  with_freq <- calculate_chi_square_row(
    chi_frame(c(13, 7), c(7, 13)), chi_banner, chi_config, box_counts = counts)

  # The shape add_boxcategory_summaries emits with boxcategory_frequency = N:
  # percentage rows only, no Frequency row anywhere.
  pct_only <- data.frame(
    RowLabel = c("Top 2 Box", "Bottom 2 Box"),
    RowType = c("Column %", "Column %"),
    RowSource = c("boxcategory", "boxcategory"),
    "TOTAL::Total" = c(50, 50), "G::Male" = c(65, 35), "G::Female" = c(35, 65),
    check.names = FALSE, stringsAsFactors = FALSE)

  expect_null(calculate_chi_square_row(pct_only, chi_banner, chi_config))
  without_freq <- calculate_chi_square_row(pct_only, chi_banner, chi_config,
                                           box_counts = counts)
  expect_false(is.null(without_freq))
  expect_identical(without_freq$RowLabel, with_freq$RowLabel)
})

test_that("a question with no BoxCategory has no count matrix", {
  question_options <- data.frame(
    QuestionCode = c("Q", "Q"), OptionText = c("Yes", "No"),
    DisplayText = c("Yes", "No"), ShowInOutput = c("Y", "Y"),
    BoxCategory = c(NA_character_, NA_character_), stringsAsFactors = FALSE)
  expect_null(boxcategory_count_matrix(
    data.frame(Q = c("Yes", "No")),
    data.frame(QuestionCode = "Q", Variable_Type = "Single_Response",
               Columns = 1L, stringsAsFactors = FALSE),
    question_options, list("TOTAL::Total" = 1:2), c(1, 1), "TOTAL::Total"))
})
