# ==============================================================================
# TABS MODULE - AUDIT STATS FIXES REGRESSION TESTS
# ==============================================================================
#
# Known-answer regression tests pinning five already-applied audit fixes:
#   1. weighting.R run_net_difference_tests — Bonferroni divisor is PER BANNER
#      GROUP (choose(cols-in-group, 2)), not choose(all columns, 2)
#   2. composite_processor.R test_composite_significance — pairs tested only
#      WITHIN a banner group (never vs Total, never cross-group), per-group
#      Bonferroni divisor
#   3. cell_calculator.R create_percentage_row — percentages honour the
#      configured decimal_places (were pre-rounded to integers)
#   4. standard_processor.R process_standard_question — loud console diagnostic
#      (DATA_UNMATCHED_OPTION_VALUES) when answered values match no configured
#      OptionText
#   5. data_layer_writer.R — build_dl_project emits alpha_secondary/bonferroni;
#      .validate_column_populations drops impossible populations
#      (CFG_POPULATION_BELOW_BASE)
#
# All fixtures are deterministic (no randomness) with hand-calculated values.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_audit_stats_fixes.R")
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

# Source shared infrastructure
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
source(file.path(turas_root, "modules/tabs/lib/composite_processor.R"))

# Shared utility functions (from shared_functions.R), sourced inline to avoid
# the module orchestrator side effects (same convention as sibling test files)
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

source(file.path(turas_root, "modules/tabs/lib/standard_processor.R"))
source(file.path(turas_root, "modules/tabs/lib/data_layer_writer.R"))


# ==============================================================================
# 1. run_net_difference_tests — PER-GROUP Bonferroni divisor
# ==============================================================================

context("run_net_difference_tests per-group Bonferroni")

# Two banner groups: BG1 has 2 columns, BG2 has 4 columns (all with data).
# The only real difference sits in BG1 (60/100 vs 45/100):
#   pooled p = 0.525, se = sqrt(0.525*0.475*(1/100+1/100)) = 0.0706222
#   z = 0.15/0.0706222 = 2.1240, two-tailed p = 0.033664
# Per-group divisor: choose(2, 2) = 1  -> adjusted alpha = 0.05     -> LETTERED
# Old global divisor: choose(6, 2) = 15 -> adjusted alpha = 0.003333 -> blocked
make_net_test_fixture <- function() {
  bg1_keys <- c("BG1::Yes", "BG1::No")
  bg2_keys <- c("BG2::W", "BG2::X", "BG2::Y", "BG2::Z")
  internal_keys <- c("TOTAL::Total", bg1_keys, bg2_keys)

  banner_info <- list(
    banner_info = list(
      BG1 = list(internal_keys = bg1_keys, letters = c("A", "B")),
      BG2 = list(internal_keys = bg2_keys, letters = c("A", "B", "C", "D"))
    )
  )

  test_data <- list(
    "BG1::Yes" = list(count1 = 60, count2 = 30, base = 100, eff_n = 100),
    "BG1::No"  = list(count1 = 45, count2 = 30, base = 100, eff_n = 100),
    "BG2::W"   = list(count1 = 50, count2 = 30, base = 100, eff_n = 100),
    "BG2::X"   = list(count1 = 50, count2 = 30, base = 100, eff_n = 100),
    "BG2::Y"   = list(count1 = 50, count2 = 30, base = 100, eff_n = 100),
    "BG2::Z"   = list(count1 = 50, count2 = 30, base = 100, eff_n = 100)
  )

  list(test_data = test_data, banner_info = banner_info,
       internal_keys = internal_keys)
}

test_that("fixture p-value sits between per-group and old global thresholds", {
  # Documents WHY the fixture discriminates: 60/100 vs 45/100 is significant at
  # alpha/choose(2,2) = 0.05 but NOT at the old global alpha/choose(6,2) = 0.003333
  r <- weighted_z_test_proportions(60, 100, 45, 100,
                                   eff_n1 = 100, eff_n2 = 100,
                                   is_weighted = FALSE, min_base = 30,
                                   alpha = 0.05)
  expect_equal(r$p_value, 0.0336637, tolerance = 1e-4)
  expect_true(r$p_value < 0.05)          # passes per-group threshold
  expect_true(r$p_value > 0.05 / 15)     # fails the old global threshold
  expect_true(r$higher)
})

test_that("net letter IS granted under the per-group divisor (2-col group)", {
  fx <- make_net_test_fixture()

  res <- run_net_difference_tests(
    test_data = fx$test_data,
    banner_info = fx$banner_info,
    internal_keys = fx$internal_keys,
    alpha = 0.05,
    bonferroni_correction = TRUE,
    min_base = 30,
    is_weighted = FALSE
  )

  expect_false(is.null(res))
  # The letter that ONLY survives a per-group divisor (old global 1/15 blocked it)
  expect_identical(unname(res$net1["BG1::Yes"]), "B")
  expect_identical(unname(res$net1["BG1::No"]), "")
  # Total column is never tested
  expect_identical(unname(res$net1["TOTAL::Total"]), "-")
  # The equal 4-column group letters nothing
  for (k in c("BG2::W", "BG2::X", "BG2::Y", "BG2::Z")) {
    expect_identical(unname(res$net1[k]), "")
  }
  # net2 counts are identical everywhere -> no letters anywhere (Total keeps "-")
  expect_identical(unname(res$net2["TOTAL::Total"]), "-")
  for (k in names(fx$test_data)) {
    expect_identical(unname(res$net2[k]), "")
  }
})


# ==============================================================================
# 2. test_composite_significance — within-group only + per-group divisor
# ==============================================================================

context("test_composite_significance group isolation")

# Config used by both composite scenarios
make_composite_config <- function() {
  list(
    alpha = 0.05,
    bonferroni_correction = TRUE,
    significance_min_base = 30,
    apply_weighting = FALSE,
    enable_significance_testing = TRUE
  )
}

test_that("composite sig never letters Total or cross-group columns", {
  # 200 rows. Gender: rows 1-100 Male (values 8.9/9.1), 101-200 Female (0.9/1.1)
  # Region deliberately ALIASES gender (North = Male rows, South = Female rows)
  # so every cross-group pair (e.g. Gender::Male vs Region::South) has a HUGE
  # difference (t ~ 565, p ~ 0). Distinct letters per group (A/B vs C/D) make
  # any cross-group leakage visible: Male must letter exactly "B", never "BD".
  n_half <- 100
  data <- data.frame(
    Gender = c(rep("Male", n_half), rep("Female", n_half)),
    Q1 = c(rep(c(8.9, 9.1), n_half / 2), rep(c(0.9, 1.1), n_half / 2)),
    stringsAsFactors = FALSE
  )

  internal_keys <- c("TOTAL::Total",
                     "Gender::Male", "Gender::Female",
                     "Region::North", "Region::South")
  banner_info <- list(
    internal_keys = internal_keys,
    letters = c("-", "A", "B", "C", "D"),
    subsets = list(
      "TOTAL::Total"   = seq_len(2 * n_half),
      "Gender::Male"   = 1:100,
      "Gender::Female" = 101:200,
      "Region::North"  = 1:100,
      "Region::South"  = 101:200
    )
  )

  sig_row <- test_composite_significance(
    data = data,
    composite_code = "COMP1",
    source_questions = "Q1",
    calculation_type = "Mean",
    calc_weights = NULL,
    banner_info = banner_info,
    config = make_composite_config()
  )

  expect_false(is.null(sig_row))
  expect_identical(sig_row$RowType, "Sig.")

  # (a) Total is never a test column
  expect_identical(sig_row[["TOTAL::Total"]], "")

  # (c) Within-group letters as expected: Male > Female -> Male gets "B";
  #     North > South -> North gets "D"
  expect_identical(sig_row[["Gender::Male"]], "B")
  expect_identical(sig_row[["Region::North"]], "D")
  expect_identical(sig_row[["Gender::Female"]], "")
  expect_identical(sig_row[["Region::South"]], "")

  # (b) No cross-group leakage despite huge cross-group differences:
  #     Region letters (C/D) never appear in Gender columns and vice versa
  expect_false(grepl("[CD]", sig_row[["Gender::Male"]]))
  expect_false(grepl("[CD]", sig_row[["Gender::Female"]]))
  expect_false(grepl("[AB]", sig_row[["Region::North"]]))
  expect_false(grepl("[AB]", sig_row[["Region::South"]]))
})

test_that("composite Bonferroni divisor is per banner group, not global", {
  # 192 rows, two banner groups: Var1 (2 columns) + Var2 (4 columns).
  # Var1: P = rows 1-96 (values 4.34/6.34, mean 5.34), Q = rows 97-192
  # (values 4.0/6.0, mean 5.0). t ~ 2.36, p ~ 0.02:
  #   per-group divisor choose(2,2) = 1  -> adjusted alpha 0.05     -> LETTERED
  #   old global divisor choose(6,2) = 15 -> adjusted alpha 0.003333 -> blocked
  # Var2: rows dealt in blocks of 8 (a,a,b,b,c,c,d,d) over the alternating
  # low/high values, so all four columns have IDENTICAL means (5.17) -> no letters.
  n_half <- 96
  v1 <- c(rep(c(4.34, 6.34), n_half / 2), rep(c(4.0, 6.0), n_half / 2))
  data <- data.frame(Q1 = v1, stringsAsFactors = FALSE)

  var2_block <- c("a", "a", "b", "b", "c", "c", "d", "d")
  var2 <- rep(var2_block, times = (2 * n_half) / length(var2_block))

  internal_keys <- c("TOTAL::Total",
                     "Var1::P", "Var1::Q",
                     "Var2::a", "Var2::b", "Var2::c", "Var2::d")
  banner_info <- list(
    internal_keys = internal_keys,
    letters = c("-", "A", "B", "A", "B", "C", "D"),
    subsets = list(
      "TOTAL::Total" = seq_len(2 * n_half),
      "Var1::P" = 1:96,
      "Var1::Q" = 97:192,
      "Var2::a" = which(var2 == "a"),
      "Var2::b" = which(var2 == "b"),
      "Var2::c" = which(var2 == "c"),
      "Var2::d" = which(var2 == "d")
    )
  )

  # Fixture sanity: the P-vs-Q p-value sits BETWEEN the per-group threshold
  # (0.05/1) and the old global threshold (0.05/15) — so a granted letter
  # proves the divisor is choose(2,2), not choose(6,2)
  raw <- weighted_t_test_means(values1 = v1[1:96], values2 = v1[97:192],
                               min_base = 30, alpha = 0.05)
  expect_true(raw$p_value < 0.05)
  expect_true(raw$p_value > 0.05 / 15)
  expect_true(raw$higher)

  sig_row <- test_composite_significance(
    data = data,
    composite_code = "COMP2",
    source_questions = "Q1",
    calculation_type = "Mean",
    calc_weights = NULL,
    banner_info = banner_info,
    config = make_composite_config()
  )

  expect_false(is.null(sig_row))
  # Letter granted at alpha/choose(2,2) — the old global alpha/15 blocked it
  expect_identical(sig_row[["Var1::P"]], "B")
  expect_identical(sig_row[["Var1::Q"]], "")
  # Identical-mean 4-column group letters nothing
  for (k in c("Var2::a", "Var2::b", "Var2::c", "Var2::d")) {
    expect_identical(sig_row[[k]], "")
  }
  expect_identical(sig_row[["TOTAL::Total"]], "")
})


# ==============================================================================
# 3. create_percentage_row — honours decimal_places
# ==============================================================================

context("create_percentage_row decimal places")

test_that("percentage row keeps configured decimals (457/1000 = 45.7)", {
  internal_keys <- c("TOTAL::Total", "D::X")
  row_counts <- c("TOTAL::Total" = 457, "D::X" = 457)
  banner_bases <- list(
    "TOTAL::Total" = list(unweighted = 1000),
    "D::X"         = list(weighted = 1000, unweighted = 999)
  )

  row_1dp <- create_percentage_row(row_counts, banner_bases, internal_keys,
                                   "Option A", show_label = TRUE,
                                   decimal_places = 1)
  # Pre-fix the 0-dp default inside the calculation pre-rounded to 46 before
  # the final rounding, so 45.7 could never appear
  expect_equal(row_1dp[["TOTAL::Total"]], 45.7)
  expect_equal(row_1dp[["D::X"]], 45.7)
  expect_false(isTRUE(all.equal(row_1dp[["TOTAL::Total"]], 46)))
  expect_identical(row_1dp$RowLabel, "Option A")
  expect_identical(row_1dp$RowType, "Column %")

  row_0dp <- create_percentage_row(row_counts, banner_bases, internal_keys,
                                   "Option A", show_label = TRUE,
                                   decimal_places = 0)
  expect_equal(row_0dp[["TOTAL::Total"]], 46)
  expect_equal(row_0dp[["D::X"]], 46)
})

test_that("percentage row rounds (not truncates) at configured precision", {
  # 137/300 = 45.6667% -> 45.7 at 1dp, 46 at 0dp
  internal_keys <- c("TOTAL::Total")
  row_counts <- c("TOTAL::Total" = 137)
  banner_bases <- list("TOTAL::Total" = list(unweighted = 300))

  row_1dp <- create_percentage_row(row_counts, banner_bases, internal_keys,
                                   "Option B", show_label = TRUE,
                                   decimal_places = 1)
  expect_equal(row_1dp[["TOTAL::Total"]], 45.7)

  row_2dp <- create_percentage_row(row_counts, banner_bases, internal_keys,
                                   "Option B", show_label = TRUE,
                                   decimal_places = 2)
  expect_equal(row_2dp[["TOTAL::Total"]], 45.67)

  row_0dp <- create_percentage_row(row_counts, banner_bases, internal_keys,
                                   "Option B", show_label = TRUE,
                                   decimal_places = 0)
  expect_equal(row_0dp[["TOTAL::Total"]], 46)
})


# ==============================================================================
# 4. process_standard_question — unmatched-value diagnostic
# ==============================================================================

context("process_standard_question unmatched-value diagnostic")

# Banner (Total + Gender), mirroring test_standard_processor.R conventions
make_audit_banner <- function(data) {
  selection_df <- data.frame(
    QuestionCode = "Gender",
    Include = "N",
    UseBanner = "Y",
    BannerBoxCategory = "N",
    DisplayOrder = 1,
    stringsAsFactors = FALSE
  )
  survey_structure <- list(
    questions = data.frame(
      QuestionCode = "Gender",
      QuestionText = "Gender?",
      Variable_Type = "Single_Response",
      Columns = "Gender",
      stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = c("Gender", "Gender"),
      OptionText = c("Male", "Female"),
      DisplayText = c("Male", "Female"),
      ShowInOutput = c("Y", "Y"),
      stringsAsFactors = FALSE
    )
  )
  banner <- create_banner_structure(selection_df, survey_structure)
  indices_result <- create_banner_row_indices(data, banner)
  weights <- rep(1, nrow(data))
  bases <- calculate_banner_bases(indices_result, weights, is_weighted = FALSE)
  list(banner = banner, indices = indices_result$row_indices,
       weights = weights, bases = bases)
}

make_audit_config <- function() {
  list(
    show_frequency = TRUE,
    show_percent_column = TRUE,
    show_percent_row = FALSE,
    decimal_places_percent = 0,
    enable_significance_testing = FALSE,
    zero_division_as_blank = TRUE
  )
}

make_audit_question <- function() {
  list(
    info = data.frame(
      QuestionCode = "Q1",
      QuestionText = "Registration status?",
      Variable_Type = "Single_Response",
      Columns = "Q1",
      stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = "Q1",
      OptionText = "I reregistered",
      DisplayText = "I reregistered",
      ShowInOutput = "Y",
      stringsAsFactors = FALSE
    )
  )
}

test_that("unmatched answered values trigger the boxed console diagnostic", {
  # Data says "I re-registered" (hyphen) 3 times; the structure only knows
  # "I reregistered" — exactly the silent zero-count bug the diagnostic catches
  data <- data.frame(
    Gender = c(rep("Male", 5), rep("Female", 5)),
    Q1 = c(rep("I reregistered", 7), rep("I re-registered", 3)),
    stringsAsFactors = FALSE
  )
  b <- make_audit_banner(data)
  q <- make_audit_question()

  out <- paste(capture.output(
    result <- process_standard_question(
      data = data,
      question_info = q$info,
      question_options = q$options,
      banner_info = b$banner,
      banner_row_indices = b$indices,
      master_weights = b$weights,
      banner_bases = b$bases,
      config = make_audit_config(),
      is_weighted = FALSE
    )
  ), collapse = "\n")

  expect_match(out, "DATA_UNMATCHED_OPTION_VALUES", fixed = TRUE)
  expect_match(out, '3 x "I re-registered"', fixed = TRUE)
  expect_match(out, "Question: Q1", fixed = TRUE)
  # The question still processes (respondents stay in the base)
  expect_false(is.null(result))
})

test_that("no unmatched-value warning when every answer matches an option", {
  data <- data.frame(
    Gender = c(rep("Male", 5), rep("Female", 5)),
    Q1 = rep("I reregistered", 10),
    stringsAsFactors = FALSE
  )
  b <- make_audit_banner(data)
  q <- make_audit_question()

  # expect_silent is too strict (the function may cat other progress output):
  # capture everything and assert the diagnostic code string is absent
  out <- paste(capture.output(
    result <- process_standard_question(
      data = data,
      question_info = q$info,
      question_options = q$options,
      banner_info = b$banner,
      banner_row_indices = b$indices,
      master_weights = b$weights,
      banner_bases = b$bases,
      config = make_audit_config(),
      is_weighted = FALSE
    )
  ), collapse = "\n")

  expect_false(grepl("DATA_UNMATCHED_OPTION_VALUES", out, fixed = TRUE))
  expect_false(is.null(result))
})


# ==============================================================================
# 5a. build_dl_project — alpha_secondary + bonferroni emission
# ==============================================================================

context("build_dl_project alpha_secondary and bonferroni")

test_that("build_dl_project emits defaults: alpha_secondary 0.20, bonferroni TRUE", {
  proj <- build_dl_project(list(project_title = "Audit Test"))
  expect_equal(proj$alpha, 0.05)
  expect_equal(proj$alpha_secondary, 0.20)
  expect_true(proj$bonferroni)
})

test_that("build_dl_project honours configured bonferroni FALSE (logical and string)", {
  proj_lgl <- build_dl_project(list(project_title = "T",
                                    bonferroni_correction = FALSE))
  expect_false(proj_lgl$bonferroni)

  proj_str <- build_dl_project(list(project_title = "T",
                                    bonferroni_correction = "FALSE"))
  expect_false(proj_str$bonferroni)

  proj_no <- build_dl_project(list(project_title = "T",
                                   bonferroni_correction = "NO"))
  expect_false(proj_no$bonferroni)

  proj_true <- build_dl_project(list(project_title = "T",
                                     bonferroni_correction = TRUE))
  expect_true(proj_true$bonferroni)
})

test_that("build_dl_project alpha_secondary: valid values kept, junk falls back to 0.20", {
  # NOTE: alpha is set explicitly (as real configs always do) — an alpha-less
  # list would let R's $ partial matching resolve config_obj$alpha to
  # alpha_secondary and distort the fixture
  proj_num <- build_dl_project(list(project_title = "T", alpha = 0.05,
                                    alpha_secondary = 0.10))
  expect_equal(proj_num$alpha_secondary, 0.10)

  proj_str <- build_dl_project(list(project_title = "T", alpha = 0.05,
                                    alpha_secondary = "0.15"))
  expect_equal(proj_str$alpha_secondary, 0.15)

  # The config loader stringifies empty cells to "NA" — must fall back to 0.20
  proj_na_str <- build_dl_project(list(project_title = "T", alpha = 0.05,
                                       alpha_secondary = "NA"))
  expect_equal(proj_na_str$alpha_secondary, 0.20)

  # A secondary level at or below the primary alpha is invalid -> default
  proj_low <- build_dl_project(list(project_title = "T", alpha = 0.05,
                                    alpha_secondary = 0.02))
  expect_equal(proj_low$alpha_secondary, 0.20)
})


# ==============================================================================
# 5b. .validate_column_populations — impossible populations dropped
# ==============================================================================

context(".validate_column_populations")

make_population_fixture <- function(total_pop) {
  columns <- list(
    list(id = "total", label = "Total", population = total_pop),
    list(id = "male", label = "Male", population = 5000)
  )
  # Achieved bases: column 1 max n = 120, column 2 max n = 60
  questions <- list(
    list(bases = list(list(n = 120), list(n = 60))),
    list(bases = list(list(n = 100), list(n = 40)))
  )
  list(columns = columns, questions = questions)
}

test_that("population below achieved base is dropped with a loud console warning", {
  fx <- make_population_fixture(total_pop = 50)  # 50 < achieved 120 -> impossible

  out <- paste(capture.output(
    res <- .validate_column_populations(fx$columns, fx$questions)
  ), collapse = "\n")

  expect_match(out, "CFG_POPULATION_BELOW_BASE", fixed = TRUE)
  expect_match(out, "Column: Total", fixed = TRUE)
  # Offending population removed; valid column keeps its population
  expect_null(res[[1]]$population)
  expect_equal(res[[2]]$population, 5000)
  # Everything else about the columns is untouched
  expect_identical(res[[1]]$label, "Total")
  expect_identical(res[[2]]$label, "Male")
})

test_that("valid populations pass through unchanged with no warning", {
  fx <- make_population_fixture(total_pop = 500)  # 500 >= achieved 120 -> valid

  out <- paste(capture.output(
    res <- .validate_column_populations(fx$columns, fx$questions)
  ), collapse = "\n")

  expect_false(grepl("CFG_POPULATION_BELOW_BASE", out, fixed = TRUE))
  expect_identical(res, fx$columns)
  expect_equal(res[[1]]$population, 500)
  expect_equal(res[[2]]$population, 5000)
})
