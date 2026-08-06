# ==============================================================================
# TABS MODULE - CROSS-ENGINE STATISTICS PARITY HARNESS
# ==============================================================================
#
# The R engine (Excel workbook + the letters carried into the v2 island) and the
# v2 JS engine (live filters / custom banners, plus what the published view
# renders) must not disagree on the same deliverable. This file is the R half of
# a permanent parity gate; the JS half is
# modules/tabs/lib/html_report_v2/tests/parity_stats_tests.mjs.
#
# Spec: docs/tabs_production_review_2026-08/CROSS_ENGINE_STATS_SPEC.md
#
# Sections, in the order the spec's stages landed them:
#   R-4  Fractional n_eff (D3) — means and proportions gate on the same base
#
# Every expected value below is hand-derived in the comment above it. A parity
# gate that re-blesses whatever the code produced is a tautology, not a gate.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_cross_engine_stats.R")
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

PARITY_DIR <- file.path(turas_root, "modules/tabs/tests/fixtures/parity_project")

# The whole tabs pipeline, in the same order test_e2e_integration.R loads it.
# Shared with the island regenerator so the harness and the committed island
# can never be built by different code. The loader sources the lib files into
# the global environment (they must be visible to each other), so turas_root has
# to be there too — under testthat this file's top level is NOT globalenv.
assign("turas_root", turas_root, envir = globalenv())

# The fixture workbooks are gitignored (*.xlsx across the repo); the generator
# that writes them is what lives in git, and it is deterministic. Write them if
# this is a fresh checkout.
source(file.path(PARITY_DIR, "generate_parity_project.R"))
ensure_parity_project(PARITY_DIR)

source(file.path(PARITY_DIR, "load_tabs_pipeline.R"))


# ==============================================================================
# THE PARITY FIXTURE, RUN ONCE
# ==============================================================================
#
# See generate_parity_project.R for the fixture's design and every hand-derived
# number in it. Running the pipeline is the slow part, so each config runs once
# and every test reads the cached result.

.parity_cache <- new.env(parent = emptyenv())

parity_run <- function(config_name = "Parity_Crosstab_Config.xlsx") {
  if (!is.null(.parity_cache[[config_name]])) return(.parity_cache[[config_name]])
  config_result <- load_crosstabs_config(file.path(PARITY_DIR, config_name))
  data_result   <- load_crosstabs_data(config_result)
  analysis      <- run_crosstabs_analysis(
    config_result, data_result,
    checkpoint_frequency = 10, total_column = "Total"
  )
  results <- setNames(
    analysis$all_results,
    vapply(analysis$all_results, function(r) r$question_code, character(1))
  )
  island <- build_data_layer(results, analysis$banner_info, config_result$config_obj,
                             survey_structure = data_result$survey_structure)
  out <- list(config = config_result, data = data_result,
              analysis = analysis, results = results, island = island)
  .parity_cache[[config_name]] <- out
  out
}


# ==============================================================================
# R-4. FRACTIONAL n_eff (D3)
# ==============================================================================
#
# THE BUG THIS PINS. calculate_effective_n() (weighting.R) used to return
# as.integer(round(n_effective)); calculate_effective_base() (cell_calculator.R)
# has always returned the raw fraction. Proportion tests ride the latter via
# banner_bases[[key]]$effective; the mean test recomputes its own n_eff through
# the former. So on the very same column, an n_eff of 29.63 FAILED a min_base of
# 30 for proportions and PASSED it for means — one table, two bases.
#
# THE FIXTURE WEIGHTS, hand-derived. 26 respondents at weight 1 and 7 at
# weight 2 (n = 33):
#     Sum(w)   = 26*1 + 7*2  = 40
#     Sum(w^2) = 26*1 + 7*4  = 54
#     n_eff    = 40^2 / 54   = 1600 / 54 = 29.6296...
# Chosen because it sits in [29.5, 30): it rounds UP to 30, so the old integer
# return crossed min_base and the fractional one does not. That crossing is the
# whole behaviour change, so the test has to sit exactly on it.

context("R-4: fractional n_eff")

# 26 at weight 1, 7 at weight 2 -> n_eff = 1600/54 = 29.6296...
NEFF_WEIGHTS <- c(rep(1, 26), rep(2, 7))
NEFF_EXPECTED <- 1600 / 54

test_that("calculate_effective_n returns the fraction, not the rounded integer", {
  eff <- calculate_effective_n(NEFF_WEIGHTS)

  expect_equal(eff, NEFF_EXPECTED, tolerance = 1e-9)
  # The specific regression: it must NOT be 30. (round(29.6296) == 30.)
  expect_false(isTRUE(all.equal(eff, 30)))
  expect_lt(eff, 30)
  expect_gt(eff, 29.5)
})

test_that("means and proportions are sized on the SAME effective base", {
  # weighting.R's calculate_effective_n (mean path) and cell_calculator.R's
  # calculate_effective_base (proportion path) must agree cell for cell.
  expect_equal(
    calculate_effective_n(NEFF_WEIGHTS),
    calculate_effective_base(NEFF_WEIGHTS),
    tolerance = 1e-12
  )

  # And on a second, differently-shaped weight vector: 10 at weight 1, 10 at
  # weight 3 -> Sum(w) = 40, Sum(w^2) = 10 + 90 = 100, n_eff = 1600/100 = 16.
  w2 <- c(rep(1, 10), rep(3, 10))
  expect_equal(calculate_effective_n(w2), 16, tolerance = 1e-12)
  expect_equal(calculate_effective_base(w2), 16, tolerance = 1e-12)
})

test_that("n_eff 29.63 does NOT test at min_base 30 for MEANS", {
  # Two groups sharing the fixture weights, with a large mean gap (1 vs 5) that
  # would be significant on any base big enough to test. The only thing standing
  # between these values and a letter is the min_base gate.
  values1 <- rep(c(1, 1, 1, 1, 2), length.out = 33)
  values2 <- rep(c(5, 5, 5, 5, 4), length.out = 33)

  res <- weighted_t_test_means(
    values1, values2,
    weights1 = NEFF_WEIGHTS, weights2 = NEFF_WEIGHTS,
    min_base = 30, alpha = 0.05
  )

  expect_false(res$significant)
  expect_true(is.na(res$p_value))   # NA = "refused to test", not "tested, p >= alpha"
})

test_that("n_eff 29.63 does NOT test at min_base 30 for PROPORTIONS either", {
  # Same base, same gate — the point of D3 is that these two agree. A 10%/60%
  # split across weighted bases of 40 would be significant if it were tested.
  res <- weighted_z_test_proportions(
    count1 = 4,  base1 = 40,
    count2 = 24, base2 = 40,
    eff_n1 = calculate_effective_base(NEFF_WEIGHTS),
    eff_n2 = calculate_effective_base(NEFF_WEIGHTS),
    is_weighted = TRUE, min_base = 30, alpha = 0.05
  )

  expect_false(res$significant)
  expect_true(is.na(res$p_value))
})

test_that("the same pair DOES test once the effective base clears min_base", {
  # Guard against a false pass: prove the refusals above come from the base
  # gate and nothing else. 52 at weight 1 and 14 at weight 2 (n = 66) doubles
  # the fixture: Sum(w) = 80, Sum(w^2) = 108, n_eff = 6400/108 = 59.259 > 30.
  big_w <- c(rep(1, 52), rep(2, 14))
  expect_equal(calculate_effective_n(big_w), 6400 / 108, tolerance = 1e-9)

  values1 <- rep(c(1, 1, 1, 1, 2), length.out = 66)
  values2 <- rep(c(5, 5, 5, 5, 4), length.out = 66)

  res_mean <- weighted_t_test_means(
    values1, values2,
    weights1 = big_w, weights2 = big_w,
    min_base = 30, alpha = 0.05
  )
  expect_true(res_mean$significant)
  expect_false(is.na(res_mean$p_value))

  res_prop <- weighted_z_test_proportions(
    count1 = 8,  base1 = 80,
    count2 = 48, base2 = 80,
    eff_n1 = calculate_effective_base(big_w),
    eff_n2 = calculate_effective_base(big_w),
    is_weighted = TRUE, min_base = 30, alpha = 0.05
  )
  expect_true(res_prop$significant)
  expect_false(is.na(res_prop$p_value))
})

test_that("unit weights still return exactly n (no design effect)", {
  expect_equal(calculate_effective_n(rep(1, 100)), 100)
  expect_equal(calculate_effective_n(rep(2.5, 40)), 40)   # constant, any scale
  expect_equal(calculate_effective_n(numeric(0)), 0)
  expect_equal(calculate_effective_n(c(NA, NA)), 0)
})


# ==============================================================================
# R-2. CARRIAGE INTEGRITY (D4)
# ==============================================================================
#
# The island must carry R's letters, not a paraphrase of them. For every
# question, every row's `sig` has to equal that row's Sig. row in the crosstab
# table and `sig2` its Sig.2 row, cell for cell. If the writer ever drifts —
# picks the wrong row, drops the Total placeholder differently, silently blanks
# a column — this fails.

context("R-2: carriage integrity")

# The Sig-style row that belongs to a given (label, source) in the raw table.
# Mirrors the writer's own resolution, including the summary-block special case
# documented in data_layer_writer.R's mean_sig_for(): a summary block's Sig. row
# is appended AFTER the Std Dev row, so the label forward-fill labels it
# "Standard Deviation" — it still tests the headline statistic.
expected_sig_cells <- function(table, keys, lbl, src, kind, rtype, sig_type) {
  blank <- rep("", length(keys))
  row_src <- if ("RowSource" %in% names(table)) {
    s <- trimws(as.character(table$RowSource)); ifelse(is.na(s), "", s)
  } else rep("", nrow(table))

  if (identical(kind, "mean") && identical(src, "summary")) {
    if (!rtype %in% c("Average", "Index", "Score")) return(blank)
    sel <- table[!is.na(table$RowType) & row_src == "summary" &
                 table$RowType == sig_type, , drop = FALSE]
  } else {
    sel <- table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                 table$RowLabel == lbl & row_src == src &
                 table$RowType == sig_type, , drop = FALSE]
  }
  if (nrow(sel) != 1) return(blank)
  vapply(keys, function(k) {
    if (!k %in% names(table)) return("")
    v <- as.character(sel[1, k])
    if (is.na(v) || v == "" || v == "-") "" else v
  }, character(1), USE.NAMES = FALSE)
}

# The RowType a mean row was built from — the writer's mrt[1].
mean_rtype_for <- function(table, lbl, src) {
  mean_types <- c("Average", "Index", "Score", "Std Dev", "StdDev", "ChiSquare")
  row_src <- if ("RowSource" %in% names(table)) {
    s <- trimws(as.character(table$RowSource)); ifelse(is.na(s), "", s)
  } else rep("", nrow(table))
  types <- unique(table$RowType[!is.na(table$RowLabel) &
                                table$RowLabel == lbl & row_src == src])
  intersect(types, mean_types)[1]
}

test_that("the fixture produces the shape the parity harness assumes", {
  run <- parity_run()
  expect_equal(run$analysis$run_status, "PASS")
  expect_equal(sort(names(run$results)), c("Q1", "Q2", "Q3"))
  # Dual alpha is on: 0.05 primary, 0.20 secondary.
  expect_equal(run$config$config_obj$alpha, 0.05)
  expect_equal(run$config$config_obj$alpha_secondary, 0.20)
  # Four cohort columns plus Total, in the documented order.
  expect_equal(vapply(run$island$columns, function(c) c$label, character(1)),
               c("Total", "Alpha", "Beta", "Gamma", "Delta"))
  # Column universes: Alpha a full census, Beta correctable, Gamma below the
  # 5% floor, Delta unresolved (no Population row -> no field at all).
  pop <- lapply(run$island$columns, function(c) c$population)
  expect_equal(pop[[2]], 40)
  expect_equal(pop[[3]], 150)
  expect_equal(pop[[4]], 5000)
  expect_null(pop[[5]])
  # Q3 is routed, so its bases are Q1's Yes counts.
  q3 <- Filter(function(q) q$code == "Q3", run$island$questions)[[1]]
  expect_equal(vapply(q3$bases, function(b) b$n, numeric(1)), c(113, 24, 39, 20, 30))
})

test_that("every row's sig equals its Sig. row, cell for cell", {
  run <- parity_run()
  keys <- run$analysis$banner_info$internal_keys
  checked <- 0L
  for (q in run$island$questions) {
    tbl <- normalize_question_table(run$results[[q$code]]$table)
    for (r in q$rows) {
      src <- if (identical(r$kind, "mean")) "summary" else NULL
      # Resolve the row's source from the table rather than assuming it.
      srcs <- unique(trimws(as.character(
        tbl$RowSource[!is.na(tbl$RowLabel) & tbl$RowLabel == r$label])))
      src <- srcs[1]
      rtype <- if (identical(r$kind, "mean")) mean_rtype_for(tbl, r$label, src) else NA_character_
      expected <- expected_sig_cells(tbl, keys, r$label, src, r$kind, rtype, "Sig.")
      expect_equal(unlist(r$sig), expected,
                   info = paste(q$code, r$label, "Sig."))
      checked <- checked + 1L
    }
  }
  expect_gt(checked, 10L)   # the fixture really did produce rows to check
})

test_that("every row's sig2 equals its Sig.2 row, cell for cell", {
  run <- parity_run()
  keys <- run$analysis$banner_info$internal_keys
  for (q in run$island$questions) {
    tbl <- normalize_question_table(run$results[[q$code]]$table)
    for (r in q$rows) {
      expect_false(is.null(r$sig2),
                   info = paste(q$code, r$label, "carries sig2 on a dual-alpha run"))
      srcs <- unique(trimws(as.character(
        tbl$RowSource[!is.na(tbl$RowLabel) & tbl$RowLabel == r$label])))
      src <- srcs[1]
      rtype <- if (identical(r$kind, "mean")) mean_rtype_for(tbl, r$label, src) else NA_character_
      expected <- expected_sig_cells(tbl, keys, r$label, src, r$kind, rtype, "Sig.2")
      expect_equal(unlist(r$sig2), expected,
                   info = paste(q$code, r$label, "Sig.2"))
    }
  }
})

test_that("Sig.2 is a superset of Sig. on every row", {
  # Excel's secondary row is tested at the looser alpha from the SAME p-value,
  # so a 95% letter is always also an 80% letter. The JS derives the lowercase
  # set as sig2 minus sig, which is only meaningful if that holds.
  run <- parity_run()
  for (q in run$island$questions) {
    for (r in q$rows) {
      for (i in seq_along(r$sig)) {
        hi <- strsplit(as.character(r$sig[[i]]), "")[[1]]
        lo <- strsplit(as.character(r$sig2[[i]]), "")[[1]]
        expect_true(all(hi %in% lo),
                    info = paste(q$code, r$label, "col", i, "-",
                                 r$sig[[i]], "not within", r$sig2[[i]]))
      }
    }
  }
})

test_that("a summary block's letters land on the mean, never on Std Dev", {
  # standard_processor emits [Average, Standard Deviation, Sig., Sig.2], so the
  # label forward-fill labels both sig rows "Standard Deviation". Matching on
  # label alone would hang the mean's letters on a row that is never tested.
  run <- parity_run()
  q2 <- Filter(function(q) q$code == "Q2", run$island$questions)[[1]]
  mean_row <- Filter(function(r) r$label == "Mean", q2$rows)[[1]]
  sd_row   <- Filter(function(r) r$label == "Standard Deviation", q2$rows)[[1]]

  # Hand-check against the fixture's own table: the Sig. row of Q2's summary
  # block carries "C" under Beta (Beta's mean is significantly above Gamma's).
  expect_equal(unlist(mean_row$sig),  c("", "", "C", "", ""))
  expect_equal(unlist(mean_row$sig2), c("", "C", "C", "", "C"))
  expect_equal(unlist(sd_row$sig),  rep("", 5))
  expect_equal(unlist(sd_row$sig2), rep("", 5))
})

test_that("the committed island matches a fresh rebuild", {
  # The JS half of this harness renders the committed parity_island.json. If the
  # writer changes and the island is not regenerated, the two engines are being
  # tested against different data — so pin them together here.
  skip_if_not(requireNamespace("jsonlite", quietly = TRUE), "jsonlite not available")
  committed_path <- file.path(PARITY_DIR, "parity_island.json")
  skip_if_not(file.exists(committed_path), "committed island not found")

  run <- parity_run()
  fresh <- jsonlite::fromJSON(
    jsonlite::toJSON(run$island, auto_unbox = TRUE, digits = 8, null = "null", na = "null"),
    simplifyVector = FALSE)
  committed <- jsonlite::fromJSON(readLines(committed_path, warn = FALSE),
                                  simplifyVector = FALSE)

  expect_equal(committed$questions, fresh$questions,
    info = paste("Regenerate with:",
                 "Rscript modules/tabs/tests/fixtures/parity_project/regenerate_parity_island.R"))
  expect_equal(committed$columns, fresh$columns)
})
