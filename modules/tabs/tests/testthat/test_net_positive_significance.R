# ==============================================================================
# TABS MODULE - NET POSITIVE SIGNIFICANCE (review 2026-08, finding I5)
# ==============================================================================
#
# The NET POSITIVE row prints top box MINUS bottom box. Until this change its
# letters came from a z-test of the TOP BOX alone, so the row tested a quantity
# it did not print. Decision (docs/tabs_production_review_2026-08/
# NET_POSITIVE_SIG_DECISION.md): score each respondent +100 in the top box,
# -100 in the bottom box, 0 otherwise, and test the weighted MEAN of that score
# — which IS the printed net, and whose variance already carries the multinomial
# covariance between the two boxes.
#
# The two failure modes this file pins are the ones the decision brief named,
# built here as one banner so both are visible on the same table:
#
#   Grp     n    top    bottom   NET      what it demonstrates
#   ---------------------------------------------------------------------------
#   A      60   20%      0%     +20      -
#   B      50   60%     40%     +20      SAME net as A, top box 40pp apart
#   C      50   20%     80%     -60      SAME top box as A, net 80pp apart
#
#   A vs C — the false negative. Identical top boxes, so the old test could
#            never letter them; they print 80 points apart.
#   A vs B — the false positive. Identical printed nets, but a 40pp top-box gap
#            the old test lettered.
#
# Hand-derived expectations are in the comment above each assertion. Every
# figure below is derivable with a calculator from the table above.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_net_positive_significance.R")
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
# alpha_to_confidence_label — the dual-alpha Sig row labels come from here.
source(file.path(turas_root, "modules/tabs/lib/crosstabs/crosstabs_config.R"))
source(file.path(turas_root, "modules/tabs/lib/cell_calculator.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))
source(file.path(turas_root, "modules/tabs/lib/report_shared.R"))

safe_execute <- function(expr, default = NA, error_msg = "Operation failed", silent = FALSE) {
  tryCatch(expr, error = function(e) {
    if (!silent) cat(sprintf("  [WARNING] %s: %s\n", error_msg, conditionMessage(e)))
    return(default)
  })
}
assign("safe_execute", safe_execute, envir = globalenv())

batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  all_cols <- unique(unlist(lapply(row_list, names)))
  row_list <- lapply(row_list, function(df) {
    missing_cols <- setdiff(all_cols, names(df))
    for (col in missing_cols) df[[col]] <- NA
    df[, all_cols, drop = FALSE]
  })
  do.call(rbind, row_list)
}
assign("batch_rbind", batch_rbind, envir = globalenv())

if (!exists("SIG_ROW_TYPE", envir = globalenv()))
  assign("SIG_ROW_TYPE", "Sig.", envir = globalenv())
if (!exists("SIG2_ROW_TYPE", envir = globalenv()))
  assign("SIG2_ROW_TYPE", "Sig.2", envir = globalenv())
if (!exists("DEFAULT_ALPHA", envir = globalenv()))
  assign("DEFAULT_ALPHA", 0.05, envir = globalenv())
if (!exists("DEFAULT_MIN_BASE", envir = globalenv()))
  assign("DEFAULT_MIN_BASE", 30, envir = globalenv())

# add_significance_row / run_significance_tests_for_row live in the orchestrator;
# extract them by text exactly as test_standard_processor.R does.
.rc_lines <- readLines(file.path(turas_root, "modules/tabs/lib/run_crosstabs.R"))
.rc_start <- grep("^run_significance_tests_for_row <- function", .rc_lines)
.rc_end   <- grep("^add_significance_row <- function", .rc_lines)
.rc_next  <- grep("^(#' Write question table|write_question_table_fast)", .rc_lines)
.rc_next  <- .rc_next[.rc_next > .rc_end[1]][1] - 1
eval(parse(text = .rc_lines[.rc_start[1]:.rc_next]), envir = globalenv())
rm(.rc_lines, .rc_start, .rc_end, .rc_next)

source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/standard_processor.R"))

# ==============================================================================
# FIXTURE — the three-column table described in the header
# ==============================================================================

# Scores 1..5. Bottom 2 Box = {1, 2}; Top 2 Box = {4, 5}; 3 is unboxed middle.
np_counts <- list(
  # c(ones, twos, threes, fours, fives)
  A = c(0L,  0L, 48L,  6L,  6L),   # n=60  top 12 (20%)  bottom  0 ( 0%)  NET +20
  B = c(10L, 10L, 0L, 15L, 15L),   # n=50  top 30 (60%)  bottom 20 (40%)  NET +20
  C = c(20L, 20L, 0L,  5L,  5L)    # n=50  top 10 (20%)  bottom 40 (80%)  NET -60
)

make_np_data <- function() {
  grp <- unlist(lapply(names(np_counts), function(g) rep(g, sum(np_counts[[g]]))),
                use.names = FALSE)
  score <- unlist(lapply(names(np_counts), function(g) rep(1:5, times = np_counts[[g]])),
                  use.names = FALSE)
  data.frame(Grp = grp, Q = score, stringsAsFactors = FALSE)
}

make_np_banner <- function(data, weights = NULL) {
  selection_df <- data.frame(
    QuestionCode = "Grp", Include = "N", UseBanner = "Y",
    BannerBoxCategory = "N", DisplayOrder = 1, stringsAsFactors = FALSE
  )
  survey_structure <- list(
    questions = data.frame(
      QuestionCode = "Grp", QuestionText = "Group?",
      Variable_Type = "Single_Response", Columns = "Grp", stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = rep("Grp", 3), OptionText = c("A", "B", "C"),
      DisplayText = c("A", "B", "C"), ShowInOutput = rep("Y", 3),
      stringsAsFactors = FALSE
    )
  )
  banner <- create_banner_structure(selection_df, survey_structure)
  indices_result <- create_banner_row_indices(data, banner)
  if (is.null(weights)) weights <- rep(1, nrow(data))
  is_w <- !all(weights == 1)
  bases <- calculate_banner_bases(indices_result, weights, is_weighted = is_w)
  list(banner = banner, indices = indices_result$row_indices,
       weights = weights, bases = bases, is_weighted = is_w)
}

np_question_info <- data.frame(
  QuestionCode = "Q", Variable_Type = "Rating", Columns = "Q",
  stringsAsFactors = FALSE
)

np_question_options <- data.frame(
  OptionText   = as.character(1:5),
  DisplayText  = as.character(1:5),
  ShowInOutput = rep("Y", 5),
  DisplayOrder = 1:5,
  BoxCategory  = c("Bottom 2 Box", "Bottom 2 Box", NA, "Top 2 Box", "Top 2 Box"),
  stringsAsFactors = FALSE
)

np_config <- function(...) {
  cfg <- list(
    show_frequency = TRUE, show_percent_column = TRUE, show_percent_row = FALSE,
    decimal_places_percent = 0, decimal_places_ratings = 1, decimal_places_index = 1,
    boxcategory_frequency = TRUE, boxcategory_percent_column = TRUE,
    boxcategory_percent_row = FALSE, show_standard_deviation = FALSE,
    enable_significance_testing = TRUE, test_net_differences = FALSE,
    show_net_positive = TRUE, alpha = 0.05,
    bonferroni_correction = FALSE, significance_min_base = 30,
    enable_chi_square = FALSE, show_chi_square = FALSE,
    zero_division_as_blank = TRUE, verbose = FALSE, apply_weighting = FALSE,
    show_unweighted_n = FALSE, show_effective_n = FALSE
  )
  modifyList(cfg, list(...))
}

# Build the table and return the NET POSITIVE row plus its Sig row(s), keyed by
# the banner's own internal keys so nothing here depends on key spelling.
np_run <- function(config = np_config(), weights = NULL, data = make_np_data()) {
  b <- make_np_banner(data, weights)
  box <- add_boxcategory_summaries(
    data, np_question_info, np_question_options,
    b$banner, b$indices, b$weights, b$bases, config,
    is_weighted = b$is_weighted
  )
  tbl <- add_net_positive_row(
    box, data, np_question_info, np_question_options,
    b$banner, b$indices, b$weights, b$bases, config,
    is_weighted = b$is_weighted
  )
  np <- tbl[!is.na(tbl$RowSource) & tbl$RowSource == "net_positive", , drop = FALSE]
  keys <- b$banner$internal_keys
  grp_key <- function(g) keys[grepl(paste0("::", g, "$"), keys)][1]
  list(
    table = tbl,
    value = np[np$RowType == "Column %", , drop = FALSE],
    sig   = np[np$RowType == "Sig.", , drop = FALSE],
    sig2  = np[np$RowType == "Sig.2", , drop = FALSE],
    key   = grp_key,
    letter = function(g) {
      bi <- b$banner$banner_info[["Grp"]]
      bi$letters[match(grp_key(g), bi$internal_keys)]
    }
  )
}

# ==============================================================================
# 1. THE PRINTED ROW — unchanged by this work
# ==============================================================================

context("NET POSITIVE value is unchanged")

test_that("the printed net is still top box minus bottom box", {
  r <- np_run()
  # A: 12/60 - 0/60 = +20   B: 30/50 - 20/50 = +20   C: 10/50 - 40/50 = -60
  expect_equal(as.numeric(r$value[[r$key("A")]]), 20)
  expect_equal(as.numeric(r$value[[r$key("B")]]), 20)
  expect_equal(as.numeric(r$value[[r$key("C")]]), -60)
})

# ==============================================================================
# 2. THE SCORE — the per-respondent quantity the letters now test
# ==============================================================================

context("net_positive_scores")

test_that("the score is +100 top box, -100 bottom box, 0 otherwise", {
  data <- make_np_data()
  s <- net_positive_scores(data, np_question_info, np_question_options,
                           "Top 2 Box", "Bottom 2 Box")
  expect_equal(length(s), nrow(data))
  expect_equal(unname(s[data$Q == 5][1]), 100)
  expect_equal(unname(s[data$Q == 4][1]), 100)
  expect_equal(unname(s[data$Q == 3][1]), 0)
  expect_equal(unname(s[data$Q == 2][1]), -100)
  expect_equal(unname(s[data$Q == 1][1]), -100)
})

test_that("a respondent outside every box scores 0, so the mean IS the printed net", {
  # This is the whole argument for the method: the score's weighted mean over
  # the column's base equals (top - bottom) / base, the published figure.
  # Non-answerers score 0 because the published row percentages them into the
  # denominator too (banner bases are the base-filtered column, not the
  # answered base) — score and printed row must share one denominator.
  data <- make_np_data()
  data$Q[data$Grp == "A"][1:5] <- NA          # five A respondents did not answer
  r <- np_run(data = data)
  s <- net_positive_scores(data, np_question_info, np_question_options,
                           "Top 2 Box", "Bottom 2 Box")
  a_rows <- which(data$Grp == "A")
  expect_true(all(s[a_rows][1:5] == 0))
  # A now: top 12, bottom 0, base still 60 -> +20.0; mean of scores = 1200/60 = 20
  expect_equal(mean(s[a_rows]), as.numeric(r$value[[r$key("A")]]))
})

# ==============================================================================
# 3. THE TWO FAILURE MODES THE DECISION EXISTS TO FIX
# ==============================================================================

context("NET POSITIVE letters test the printed net")

test_that("columns with the SAME top box and different nets now letter (A vs C)", {
  # A and C both have a 20% top box, so the old top-box z-test saw z = 0 and
  # could never letter them — while the page showed +20 against -60.
  #
  # Score means: A = +20, C = -60.  Population variances on the +-100 scale are
  # (t + b - (t-b)^2) * 100^2:
  #   A: (0.20 + 0.00 - 0.20^2) * 10000 = 1600     Bessel: 1600 * 60/59 = 1627.1186
  #   C: (0.20 + 0.80 - 0.60^2) * 10000 = 6400     Bessel: 6400 * 50/49 = 6530.6122
  #   SE = sqrt(1627.1186/60 + 6530.6122/50) = sqrt(157.7308) = 12.5591
  #   t  = (20 - (-60)) / 12.5591 = 6.370  ->  p far below 0.05
  r <- np_run()
  expect_true(grepl(r$letter("C"), r$sig[[r$key("A")]], fixed = TRUE),
              info = paste0("A's NET POSITIVE cell should letter against C, got '",
                            r$sig[[r$key("A")]], "'"))
  # and not the other way round: C is the lower net
  expect_false(grepl(r$letter("A"), r$sig[[r$key("C")]], fixed = TRUE))
})

test_that("columns with the SAME net no longer letter (A vs B)", {
  # A and B both print +20. The old test compared top boxes (20% vs 60%,
  # pooled z = -4.30) and lettered B over A under two identical numbers.
  # Score means are both exactly +20, so the difference is 0 and no letter is
  # earned in either direction.
  r <- np_run()
  expect_false(grepl(r$letter("A"), r$sig[[r$key("B")]], fixed = TRUE),
               info = paste0("B's NET POSITIVE cell must not letter against A, got '",
                             r$sig[[r$key("B")]], "'"))
  expect_false(grepl(r$letter("B"), r$sig[[r$key("A")]], fixed = TRUE))
})

# ==============================================================================
# 4. THE MACHINERY THE ROW HAS TO KEEP LIVING INSIDE
# ==============================================================================

context("NET POSITIVE significance machinery")

test_that("the Total column is marked '-' and never tested", {
  r <- np_run()
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  expect_equal(r$sig[[total_key]], "-")
})

test_that("dual alpha emits a second Sig row labelled by confidence", {
  r <- np_run(np_config(alpha_secondary = 0.20))
  expect_equal(nrow(r$sig), 1)
  expect_equal(nrow(r$sig2), 1)
  expect_equal(r$sig$RowLabel, alpha_to_confidence_label(0.05))
  expect_equal(r$sig2$RowLabel, alpha_to_confidence_label(0.20))
  # Every 95% letter is also an 80% letter.
  a95 <- strsplit(r$sig[[r$key("A")]], "")[[1]]
  a80 <- strsplit(r$sig2[[r$key("A")]], "")[[1]]
  expect_true(all(a95 %in% a80))
})

test_that("both sig rows are tagged net_positive for downstream classification", {
  r <- np_run(np_config(alpha_secondary = 0.20))
  expect_equal(unique(c(r$sig$RowSource, r$sig2$RowSource)), "net_positive")
})

test_that("a column below significance_min_base earns no letter", {
  # min_base 200 is above every column's base, so nothing can be tested.
  r <- np_run(np_config(significance_min_base = 200))
  expect_equal(r$sig[[r$key("A")]], "")
  expect_equal(r$sig[[r$key("B")]], "")
  expect_equal(r$sig[[r$key("C")]], "")
})

test_that("Bonferroni divides by the banner group's own choose(k, 2)", {
  # 3 non-Total columns -> 3 pairs -> alpha 0.05/3 = 0.01667. A vs C's t of
  # 6.37 clears that comfortably, so the letter survives the correction; the
  # point of the test is that the corrected run still letters and the divisor
  # is the group's, not a global one.
  r <- np_run(np_config(bonferroni_correction = TRUE))
  expect_true(grepl(r$letter("C"), r$sig[[r$key("A")]], fixed = TRUE))
})

test_that("weighted runs test the weighted net on the effective base", {
  # Weight every respondent 2.0: the weighted net is identical to the
  # unweighted one and Kish n_eff == n, so the letters must not move.
  data <- make_np_data()
  plain <- np_run()
  w <- np_run(weights = rep(2, nrow(data)))
  expect_equal(as.numeric(w$value[[w$key("A")]]), as.numeric(plain$value[[plain$key("A")]]))
  expect_equal(w$sig[[w$key("A")]], plain$sig[[plain$key("A")]])
  expect_equal(w$sig[[w$key("C")]], plain$sig[[plain$key("C")]])
})

test_that("an EMPTY banner column drops out without shifting anyone's letters", {
  # A crossbreak with no respondents used to enter the test data anyway. It now
  # drops out — and the letters of the columns that remain must be the ones they
  # had before, not shifted by the gap (the letter-subsetting trap the final
  # 2026-08 review fixed in add_significance_row).
  data <- make_np_data()
  data <- rbind(data, data.frame(Grp = "D", Q = NA_integer_,
                                 stringsAsFactors = FALSE)[0, ])
  b_opts <- c("A", "B", "C")
  r <- np_run(data = data)
  # Rebuild with a 4th declared group that no respondent belongs to.
  selection_df <- data.frame(
    QuestionCode = "Grp", Include = "N", UseBanner = "Y",
    BannerBoxCategory = "N", DisplayOrder = 1, stringsAsFactors = FALSE
  )
  survey_structure <- list(
    questions = data.frame(
      QuestionCode = "Grp", QuestionText = "Group?",
      Variable_Type = "Single_Response", Columns = "Grp", stringsAsFactors = FALSE),
    options = data.frame(
      QuestionCode = rep("Grp", 4), OptionText = c(b_opts, "Z"),
      DisplayText = c(b_opts, "Z"), ShowInOutput = rep("Y", 4),
      stringsAsFactors = FALSE)
  )
  banner <- create_banner_structure(selection_df, survey_structure)
  idx <- create_banner_row_indices(data, banner)
  weights <- rep(1, nrow(data))
  bases <- calculate_banner_bases(idx, weights, is_weighted = FALSE)
  config <- np_config()
  box <- add_boxcategory_summaries(data, np_question_info, np_question_options,
                                   banner, idx$row_indices, weights, bases, config)
  tbl <- add_net_positive_row(box, data, np_question_info, np_question_options,
                              banner, idx$row_indices, weights, bases, config)
  np <- tbl[!is.na(tbl$RowSource) & tbl$RowSource == "net_positive", , drop = FALSE]
  sig <- np[np$RowType == "Sig.", , drop = FALSE]
  keys <- banner$internal_keys
  kA <- keys[grepl("::A$", keys)][1]; kC <- keys[grepl("::C$", keys)][1]
  kZ <- keys[grepl("::Z$", keys)][1]
  # A still letters C, and the empty column earns and attracts nothing.
  bi <- banner$banner_info[["Grp"]]
  lC <- bi$letters[match(kC, bi$internal_keys)]
  lZ <- bi$letters[match(kZ, bi$internal_keys)]
  expect_true(grepl(lC, sig[[kA]], fixed = TRUE))
  expect_equal(sig[[kZ]], "")
  expect_false(any(grepl(lZ, unlist(sig[keys]), fixed = TRUE)))
})

test_that("a full-census column is excluded from pairing, not tested", {
  # fpc_mul Inf (a column whose base IS its universe) has no sampling error
  # left; weighted_t_test_means returns not-significant rather than NaN.
  res <- weighted_t_test_means(
    values1 = rep(c(100, 0), c(12, 48)), values2 = rep(c(100, -100), c(10, 40)),
    min_base = 30, alpha = 0.05, fpc_mul1 = Inf, fpc_mul2 = 1
  )
  expect_false(res$significant)
  expect_true(is.na(res$p_value))
})

# ==============================================================================
# 5. THE INVARIANT — what is tested is what is printed
# ==============================================================================

context("NET POSITIVE tests what it prints")

test_that("the score mean equals the printed net in every column", {
  data <- make_np_data()
  r <- np_run(data = data)
  s <- net_positive_scores(data, np_question_info, np_question_options,
                           "Top 2 Box", "Bottom 2 Box")
  for (g in c("A", "B", "C")) {
    rows <- which(data$Grp == g)
    expect_equal(mean(s[rows]), as.numeric(r$value[[r$key(g)]]),
                 info = paste("column", g))
  }
})
