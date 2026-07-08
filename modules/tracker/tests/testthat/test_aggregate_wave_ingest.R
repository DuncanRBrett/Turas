# ==============================================================================
# TEST SUITE: Aggregate Wave Ingest (Step 2 — config + values loader)
# ==============================================================================
# Functions tested:
#   - resolve_wave_types()        (tracker_config_loader.R)
#   - load_aggregate_values()     (aggregate_wave_loader.R)
#   - get_aggregate_metric()      (aggregate_wave_loader.R)
#
# See docs/AGGREGATE_WAVE_INGEST_PLAN.md for the design.
# ==============================================================================

library(testthat)

context("Aggregate Wave Ingest")

# ------------------------------------------------------------------------------
# SETUP: source modules in dependency order (mirrors test_config_validation.R)
# ------------------------------------------------------------------------------
test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root   <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)
source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "trend_significance.R"))
source(file.path(tracker_root, "lib", "aggregate_wave_loader.R"))
source(file.path(tracker_root, "lib", "question_mapper.R"))
# wave_loader.R pulls in shared weight utilities via a working-dir-relative
# fallback path; pre-source them (absolute) so it resolves from the testthat dir.
source(file.path(turas_root, "modules", "shared", "lib", "weights_utils.R"))
source(file.path(tracker_root, "lib", "wave_loader.R"))

# ------------------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------------------
valid_values_df <- function() {
  data.frame(
    metric_id   = c("Q64", "Q64", "Q65", "Q7"),
    year        = c(2024, 2023, 2024, 2024),
    metric_type = c("mean", "mean", "nps", "proportion"),
    value       = c(9.054, 9.003, 77, 58),
    base        = c(750, 740, 750, NA),   # blank base on the proportion row
    sd          = c(NA_real_, NA_real_, NA_real_, NA_real_),
    stringsAsFactors = FALSE
  )
}
write_values_csv <- function(df) {
  tmp <- tempfile(fileext = ".csv")
  write.csv(df, tmp, row.names = FALSE)
  tmp
}
waves_df <- function(...) {
  data.frame(..., stringsAsFactors = FALSE)
}

# ==============================================================================
# resolve_wave_types()
# ==============================================================================

test_that("resolve_wave_types defaults every wave to 'data' when WaveType absent (back-compat)", {
  w <- waves_df(WaveID = c("W1", "W2"), WaveName = c("A", "B"),
                DataFile = c("a.csv", "b.csv"))
  out <- resolve_wave_types(w)
  expect_equal(out$WaveType, c("data", "data"))
  expect_true("AggregateFile" %in% names(out))
  expect_true(all(is.na(out$AggregateFile)))
})

test_that("resolve_wave_types normalises case and blanks to 'data'", {
  w <- waves_df(WaveID = c("W1", "W2", "W3"), WaveName = c("A", "B", "C"),
                WaveType = c("DATA", "", NA), DataFile = c("a.csv", "b.csv", "c.csv"))
  out <- resolve_wave_types(w)
  expect_equal(out$WaveType, c("data", "data", "data"))
})

test_that("resolve_wave_types accepts a valid mixed data + aggregate config", {
  w <- waves_df(WaveID = c("W2012", "W2025"), WaveName = c("2012", "2025"),
                WaveType = c("aggregate", "data"),
                DataFile = c(NA, "wave2025.csv"),
                AggregateFile = c("history.csv", NA))
  out <- resolve_wave_types(w)
  expect_equal(out$WaveType, c("aggregate", "data"))
  expect_equal(out$AggregateFile[1], "history.csv")
})

test_that("resolve_wave_types refuses an invalid WaveType", {
  w <- waves_df(WaveID = "W1", WaveName = "A", WaveType = "banana", DataFile = "a.csv")
  expect_error(resolve_wave_types(w), class = "turas_refusal")
})

test_that("resolve_wave_types refuses an aggregate wave with no AggregateFile", {
  w <- waves_df(WaveID = "W2012", WaveName = "2012", WaveType = "aggregate",
                DataFile = NA, AggregateFile = NA)
  expect_error(resolve_wave_types(w), class = "turas_refusal")
})

test_that("resolve_wave_types refuses an aggregate wave with a blank AggregateFile string", {
  w <- waves_df(WaveID = "W2012", WaveName = "2012", WaveType = "aggregate",
                DataFile = "", AggregateFile = "   ")
  expect_error(resolve_wave_types(w), class = "turas_refusal")
})

# ==============================================================================
# load_aggregate_values() — happy paths
# ==============================================================================

test_that("load_aggregate_values loads a valid table with correct counts and types", {
  f <- write_values_csv(valid_values_df())
  on.exit(unlink(f), add = TRUE)
  res <- load_aggregate_values(f)

  expect_equal(res$status, "PASS")
  expect_equal(res$n_rows, 4)
  expect_equal(res$n_metrics, 3)     # Q64, Q65, Q7
  expect_equal(res$n_waves, 2)       # 2024, 2023
  expect_true(is.numeric(res$values$value))
  expect_equal(res$values$value[res$values$metric_id == "Q65"], 77)
  # blank base on the proportion row stays NA (not invented)
  expect_true(is.na(res$values$base[res$values$metric_id == "Q7"]))
})

test_that("load_aggregate_values accepts 'wave' as the wave column (not just 'year')", {
  df <- valid_values_df()
  names(df)[names(df) == "year"] <- "wave"
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  res <- load_aggregate_values(f)
  expect_equal(res$status, "PASS")
  expect_setequal(unique(res$values$wave), c("2024", "2023"))
})

test_that("load_aggregate_values normalises 'proportions' to 'proportion'", {
  df <- valid_values_df()
  df$metric_type[df$metric_type == "proportion"] <- "proportions"
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  res <- load_aggregate_values(f)
  expect_true("proportion" %in% res$values$metric_type)
  expect_false("proportions" %in% res$values$metric_type)
})

test_that("load_aggregate_values reads base and sd when supplied", {
  df <- valid_values_df()
  df$sd <- c(1.2, 1.3, NA, NA)
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  res <- load_aggregate_values(f)
  expect_equal(res$values$base[res$values$metric_id == "Q65"], 750)
  expect_equal(res$values$sd[res$values$metric_id == "Q64" & res$values$wave == "2024"], 1.2)
})

test_that("load_aggregate_values reads an .xlsx values table", {
  df <- valid_values_df()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::write.xlsx(df, tmp)
  res <- load_aggregate_values(tmp)
  expect_equal(res$status, "PASS")
  expect_equal(res$n_rows, 4)
})

test_that("load_aggregate_values ignores extra descriptive columns (section/question/source)", {
  df <- valid_values_df()
  df$section   <- c("Overall", "Overall", "Overall", "Deliveries")
  df$who_asked <- "All"
  df$question  <- c("Overall perf", "Overall perf", "NPS", "Rotate stock")
  df$source    <- "sheet"
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  res <- load_aggregate_values(f)
  expect_equal(res$status, "PASS")
  expect_equal(res$n_rows, 4)
  expect_setequal(names(res$values), c("metric_id", "wave", "metric_type", "value", "base", "sd"))
})

test_that("load_aggregate_values warns (not refuses) on out-of-range proportion", {
  df <- valid_values_df()
  df$value[df$metric_id == "Q7"] <- 150   # impossible %, but keep it as a warning
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  res <- load_aggregate_values(f)
  expect_equal(res$status, "PASS")
  expect_true(length(res$warnings) >= 1)
})

# ==============================================================================
# load_aggregate_values() — refusals
# ==============================================================================

test_that("load_aggregate_values refuses a missing file", {
  expect_error(load_aggregate_values(tempfile(fileext = ".csv")), class = "turas_refusal")
})

test_that("load_aggregate_values refuses a missing required column", {
  df <- valid_values_df()
  df$value <- NULL
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  expect_error(load_aggregate_values(f), class = "turas_refusal")
})

test_that("load_aggregate_values refuses an invalid metric_type", {
  df <- valid_values_df()
  df$metric_type[1] <- "banana"
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  expect_error(load_aggregate_values(f), class = "turas_refusal")
})

test_that("load_aggregate_values refuses a non-numeric value", {
  df <- valid_values_df()
  df$value <- as.character(df$value)
  df$value[2] <- "n/a"
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  expect_error(load_aggregate_values(f), class = "turas_refusal")
})

test_that("load_aggregate_values refuses a duplicate (metric_id, wave)", {
  df <- valid_values_df()
  df <- rbind(df, df[1, ])   # duplicate Q64 / 2024
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  expect_error(load_aggregate_values(f), class = "turas_refusal")
})

test_that("load_aggregate_values refuses a non-numeric base", {
  df <- valid_values_df()
  df$base <- as.character(df$base)
  df$base[1] <- "lots"
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  expect_error(load_aggregate_values(f), class = "turas_refusal")
})

test_that("load_aggregate_values refuses a negative base", {
  df <- valid_values_df()
  df$base[1] <- -5
  f <- write_values_csv(df)
  on.exit(unlink(f), add = TRUE)
  expect_error(load_aggregate_values(f), class = "turas_refusal")
})

# ==============================================================================
# get_aggregate_metric()
# ==============================================================================

# ==============================================================================
# load_all_waves() — aggregate wave plumbing
# ==============================================================================

test_that("load_all_waves loads aggregate waves into the store and marks them", {
  vals <- data.frame(
    metric_id   = c("Q1", "Q1", "Q2"),
    wave        = c("W2012", "W2013", "W2012"),   # wave value must equal WaveID
    metric_type = c("mean", "mean", "nps"),
    value       = c(8.7, 8.9, 60),
    stringsAsFactors = FALSE
  )
  af <- tempfile(fileext = ".csv")
  write.csv(vals, af, row.names = FALSE)
  on.exit(unlink(af), add = TRUE)

  config <- list(
    waves = data.frame(
      WaveID = c("W2012", "W2013"), WaveName = c("2012", "2013"),
      WaveType = c("aggregate", "aggregate"), AggregateFile = c(af, af),
      stringsAsFactors = FALSE
    ),
    tracked_questions = data.frame(QuestionCode = c("Q1", "Q2"), stringsAsFactors = FALSE),
    banner = data.frame(BreakVariable = character(0), BreakLabel = character(0), stringsAsFactors = FALSE),
    settings = list()
  )

  res <- load_all_waves(config, data_dir = NULL, question_mapping = NULL)

  expect_true(all(c("W2012", "W2013") %in% names(res$wave_data)))   # marker entries present
  expect_false(is.null(res$aggregate_store$index))
  hit <- get_aggregate_metric(res$aggregate_store, "Q1", "W2012")
  expect_false(is.null(hit))
  expect_equal(hit$value, 8.7)
  expect_equal(get_aggregate_metric(res$aggregate_store, "Q2", "W2012")$value, 60)
})

# ==============================================================================
# is_aggregate_wave() + result builders
# ==============================================================================

test_that("is_aggregate_wave detects aggregate waves and is safe when WaveType absent", {
  cfg <- list(waves = data.frame(WaveID = c("W1", "W2"),
                                 WaveType = c("aggregate", "data"), stringsAsFactors = FALSE))
  expect_true(is_aggregate_wave(cfg, "W1"))
  expect_false(is_aggregate_wave(cfg, "W2"))
  expect_false(is_aggregate_wave(cfg, "W9"))                                  # unknown wave
  expect_false(is_aggregate_wave(list(waves = data.frame(WaveID = "W1")), "W1"))  # no WaveType col
})

test_that("builders carry the value and leave dispersion NA; blank base -> eff_n 0", {
  r <- build_aggregate_rating_result(list(value = 8.7, base = 100, metric_type = "mean"))
  expect_equal(r$metrics$mean, 8.7)
  expect_true(is.na(r$metrics$sd))
  expect_equal(r$eff_n, 100)

  n <- build_aggregate_nps_result(list(value = 70, base = 100, metric_type = "nps"))
  expect_equal(n$nps, 70)
  expect_true(is.na(n$promoters_pct))

  p <- build_aggregate_proportion_result(list(value = 55, base = NA, metric_type = "proportion"), "value")
  expect_equal(unname(p$proportions["value"]), 55)
  expect_equal(p$eff_n, 0)   # blank base becomes 0 so the min-base gate skips cleanly
})

# ==============================================================================
# HONEST SIGNIFICANCE — the core claim: aggregate figures feed the SAME sig
# tests; means/NPS without dispersion return "no test", proportions with a base
# get a real z-test. (Builder output -> real trend_significance.R functions.)
# ==============================================================================

test_that("aggregate mean: t-test returns no significant result (sd unknown), no crash", {
  cfg <- list(settings = list(minimum_base = 5, alpha = 0.05))
  wr <- list(W1 = build_aggregate_rating_result(list(value = 8.7, base = 200, metric_type = "mean")),
             W2 = build_aggregate_rating_result(list(value = 9.3, base = 210, metric_type = "mean")))
  sig <- perform_significance_tests_means(wr, c("W1", "W2"), cfg)
  expect_false(isTRUE(sig[["W1_vs_W2"]]$significant))   # never a fabricated arrow
})

test_that("aggregate NPS: no test (promoter/detractor split unknown), no crash", {
  cfg <- list(settings = list(minimum_base = 5, alpha = 0.05))
  wr <- list(W1 = build_aggregate_nps_result(list(value = 60, base = 200, metric_type = "nps")),
             W2 = build_aggregate_nps_result(list(value = 75, base = 200, metric_type = "nps")))
  sig <- perform_significance_tests_nps(wr, c("W1", "W2"), cfg)
  expect_false(isTRUE(sig[["W1_vs_W2"]]$significant))
})

test_that("aggregate proportion WITH base gets a real z-test (40% vs 60% at n=200 is significant)", {
  cfg <- list(settings = list(minimum_base = 5, alpha = 0.05))
  wr <- list(W1 = build_aggregate_proportion_result(list(value = 40, base = 200, metric_type = "proportion"), "value"),
             W2 = build_aggregate_proportion_result(list(value = 60, base = 200, metric_type = "proportion"), "value"))
  sig <- perform_significance_tests_proportions(wr, c("W1", "W2"), cfg, "value")
  expect_true(isTRUE(sig[["W1_vs_W2"]]$significant))
  expect_false(is.null(sig[["W1_vs_W2"]]$p_value))
})

test_that("aggregate proportion with BLANK base -> no test (eff_n 0 skips the gate)", {
  cfg <- list(settings = list(minimum_base = 30, alpha = 0.05))
  wr <- list(W1 = build_aggregate_proportion_result(list(value = 40, base = NA, metric_type = "proportion"), "value"),
             W2 = build_aggregate_proportion_result(list(value = 60, base = NA, metric_type = "proportion"), "value"))
  sig <- perform_significance_tests_proportions(wr, c("W1", "W2"), cfg, "value")
  expect_false(isTRUE(sig[["W1_vs_W2"]]$significant))
  expect_match(sig[["W1_vs_W2"]]$reason, "insufficient")
})

test_that("get_aggregate_metric returns the row for a known key and NULL otherwise", {
  f <- write_values_csv(valid_values_df())
  on.exit(unlink(f), add = TRUE)
  res <- load_aggregate_values(f)

  hit <- get_aggregate_metric(res, "Q64", "2024")
  expect_false(is.null(hit))
  expect_equal(hit$value, 9.054)
  expect_equal(hit$metric_type, "mean")

  expect_null(get_aggregate_metric(res, "Q999", "2024"))
  expect_null(get_aggregate_metric(res, "Q64", "1999"))
})
