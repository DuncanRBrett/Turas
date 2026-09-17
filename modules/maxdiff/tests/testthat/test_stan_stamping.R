# ==============================================================================
# MAXDIFF - THE STAN PATH STAMPS ITS DIAGNOSTICS AND NAMES ITS REFERENCE ITEM
# ==============================================================================
# F6 and M3 of the v2 independent review.
#
# F6: the tabs export gate keys on the estimator alone, so a divergent or
# non-converged fit shipped with nothing on its face to say so. 07_hb.R has
# computed n_divergences, max_treedepth_exceeded, mean_rhat and min_ess all
# along and only logged them.
#
# M3: the Stan model fixes one item at zero, so that item's spread across
# respondents and its Mean SE are exactly 0 by construction, and
# classify_item_discrimination() filed it from that zero as Low Priority. A
# structural zero is not a finding.
# ==============================================================================

# A self-contained island fixture. test_v2_island.R has one of its own; this
# file does not source that one, because sourcing a test file re-runs its tests.
N_RESP <- 20L
N_ITEMS <- 6L

stan_items <- function() {
  data.frame(
    Item_ID = sprintf("ITEM%02d", seq_len(N_ITEMS)),
    Item_Label = c("Fresh", "Cheap", "Local", "Strong", "Smooth", "Rewards"),
    Item_Group = "All", Display_Order = seq_len(N_ITEMS),
    Include = 1L, Anchor_Item = 0L, stringsAsFactors = FALSE
  )
}

island_fixture <- function(method = "cmdstanr") {
  items <- stan_items()
  ids <- items$Item_ID
  set.seed(42)
  indiv_mat <- matrix(rnorm(N_RESP * N_ITEMS), nrow = N_RESP,
                      dimnames = list(NULL, ids))
  indiv_mat[, N_ITEMS] <- 0   # the model's fixed slot
  counts <- data.frame(
    Item_ID = ids, Item_Label = items$Item_Label, Item_Group = items$Item_Group,
    Times_Shown = 60, Times_Best = c(30, 20, 15, 10, 5, 3),
    Times_Worst = c(2, 4, 8, 12, 20, 30),
    Best_Pct = c(50, 33.3, 25, 16.7, 8.3, 5),
    Worst_Pct = c(3.3, 6.7, 13.3, 20, 33.3, 50),
    Net_Score = c(46.7, 26.7, 11.7, -3.3, -25, -45),
    Rank = 1:6, stringsAsFactors = FALSE
  )
  hb <- list(
    population_utilities = data.frame(
      Item_ID = ids, HB_Utility_Mean = colMeans(indiv_mat),
      HB_Utility_SD = apply(indiv_mat, 2, sd),
      HB_Mean_SE = c(.11, .10, .12, .09, .13, 0),
      stringsAsFactors = FALSE),
    individual_utilities = cbind(
      resp_id = sprintf("R%03d", seq_len(N_RESP)),
      as.data.frame(indiv_mat), stringsAsFactors = FALSE),
    diagnostics = list(method = method),
    model_fit = list(method = method)
  )
  os <- get_default_output_settings()
  os$Generate_HTML_Report <- FALSE
  config <- list(
    project_settings = list(Project_Name = "StanStamp", Weight_Variable = NULL),
    items = items, output_settings = os
  )
  out_dir <- file.path(tempdir(), paste0("md_stamp_", as.integer(runif(1) * 1e6)))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  results <- list(
    count_scores = counts, logit_results = NULL, hb_results = hb,
    turf_results = NULL, anchor_data = NULL, discrimination_data = NULL,
    design = data.frame(Version = 1L, Task_Number = 1:6,
                        Item1_ID = ids[c(1, 2, 3, 4, 5, 6)],
                        Item2_ID = ids[c(2, 3, 4, 5, 6, 1)],
                        Item3_ID = ids[c(3, 4, 5, 6, 1, 2)], stringsAsFactors = FALSE),
    study_summary = list(n_respondents = N_RESP, n_tasks = 6, n_items = N_ITEMS,
                         weighted = FALSE),
    output_path = file.path(out_dir, "StanStamp_MaxDiff_Results.xlsx")
  )
  list(results = results, config = config, items = items)
}

stan_fixture <- function(diagnostics = NULL, reference_item = NULL,
                         with_discrimination = FALSE) {
  fx <- island_fixture("cmdstanr")
  ids <- fx$items$Item_ID
  if (is.null(diagnostics)) {
    diagnostics <- list(method = "cmdstanr", n_divergences = 0L,
                        max_treedepth_exceeded = 0L, mean_rhat = 1.0009,
                        min_ess = 8675)
  }
  fx$results$hb_results$diagnostics <- diagnostics
  fx$results$hb_results$model_fit$reference_item <- reference_item %||% ids[length(ids)]
  if (with_discrimination) {
    fx$results$discrimination_data <- data.frame(
      Item_ID = ids,
      Classification = c("UNIVERSAL", "POLARISING", "NICHE", "NICHE",
                         "LOW_PRIORITY", "LOW_PRIORITY"),
      Classification_Label = c("Universal favourite", "Polarising", "Niche",
                               "Niche", "Low priority", "Low priority"),
      Mean_Utility = c(1.5, 1.0, .5, .2, -.4, 0),
      SD_Utility = c(.8, 1.4, .6, .5, .3, 0),
      stringsAsFactors = FALSE
    )
  }
  fx
}

# ---- F6: the METHOD sheet ----------------------------------------------------

method_rows <- function(diagnostics) {
  fx <- stan_fixture(diagnostics = diagnostics)
  .maxdiff_tabs_method_sheet(
    config = fx$config, hb = fx$results$hb_results, method = "hb",
    method_label = "Stan hierarchical Bayes", approximate = FALSE,
    question_code = "MD", n_exported = 20, n_excluded = 0,
    item_labels = fx$items$Item_Label
  )
}

test_that("the METHOD sheet carries all four sampler diagnostics on a Stan fit", {
  skip_if(!exists(".maxdiff_tabs_method_sheet", mode = "function"))
  df <- method_rows(list(method = "cmdstanr", n_divergences = 3L,
                         max_treedepth_exceeded = 12L, mean_rhat = 1.014,
                         min_ess = 421.7))
  expect_true("Mean R-hat" %in% df$Item)
  expect_true("Divergences" %in% df$Item)
  expect_true("Max treedepth exceeded" %in% df$Item)
  expect_true("Min ESS" %in% df$Item)
  expect_equal(df$Value[df$Item == "Divergences"], "3")
  expect_equal(df$Value[df$Item == "Max treedepth exceeded"], "12")
  expect_equal(df$Value[df$Item == "Min ESS"], "422")
  expect_equal(df$Value[df$Item == "Mean R-hat"], "1.014")
})

test_that("a clean fit stamps its zeros rather than omitting the rows", {
  skip_if(!exists(".maxdiff_tabs_method_sheet", mode = "function"))
  df <- method_rows(list(method = "cmdstanr", n_divergences = 0L,
                         max_treedepth_exceeded = 0L, mean_rhat = 1.0,
                         min_ess = 8675))
  expect_equal(df$Value[df$Item == "Divergences"], "0")
  expect_equal(df$Value[df$Item == "Max treedepth exceeded"], "0")
})

test_that("a diagnostics list without the numbers omits their rows", {
  skip_if(!exists(".maxdiff_tabs_method_sheet", mode = "function"))
  df <- method_rows(list(method = "cmdstanr"))
  expect_false("Divergences" %in% df$Item)
  expect_false("Min ESS" %in% df$Item)
})

# ---- F6: the island ----------------------------------------------------------

test_that("the island meta carries the sampler diagnostics on the Stan path", {
  fx <- stan_fixture()
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$meta$method, "stan_hb")
  expect_equal(isl$meta$nDivergences, 0)
  expect_equal(isl$meta$maxTreedepthExceeded, 0)
  expect_equal(round(isl$meta$meanRhat, 4), 1.0009)
  expect_equal(isl$meta$minEss, 8675)
})

test_that("the sampler diagnostics are absent on the empirical-Bayes path", {
  fx <- island_fixture("empirical_bayes_shrinkage")
  fx$results$hb_results$diagnostics <- list(
    method = "empirical_bayes", n_divergences = 0L,
    max_treedepth_exceeded = 0L, mean_rhat = 1.0, min_ess = 8675
  )
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$meta$method, "empirical_bayes")
  expect_null(isl$meta$nDivergences)
  expect_null(isl$meta$meanRhat)
  expect_null(isl$meta$minEss)
})

test_that("the view renders the sampler sentence from meta", {
  js <- readLines(file.path(TURAS_ROOT, "modules", "tabs", "lib", "html_report_v2",
                            "assets", "js", "27y_maxdiff.js"), warn = FALSE)
  src <- paste(js, collapse = "\n")
  expect_match(src, "meta.meanRhat", fixed = TRUE)
  expect_match(src, "divergence", fixed = TRUE)
  expect_match(src, "min ESS", fixed = TRUE)
  expect_match(src, "Sampler: ", fixed = TRUE)
})

# ---- M3: the reference item --------------------------------------------------

test_that("the island nulls the reference item's structural zeros on the Stan path", {
  fx <- stan_fixture()
  ref <- fx$results$hb_results$model_fit$reference_item
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  pos <- match(ref, isl$scores$itemId)
  expect_false(is.na(pos))
  expect_true(is.na(isl$scores$hbSpread[pos]))
  expect_equal(sum(is.na(isl$scores$hbSpread)), 1L)
  expect_equal(isl$meta$referenceItem, ref)
  expect_equal(isl$meta$referenceItemLabel, isl$scores$label[pos])
})

test_that("the reference item is taken from the fit, not assumed to be last", {
  fx <- stan_fixture(reference_item = NULL)
  ids <- fx$items$Item_ID
  fx$results$hb_results$model_fit$reference_item <- ids[2]
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_equal(isl$meta$referenceItem, ids[2])
  expect_true(is.na(isl$scores$hbSpread[2]))
  expect_false(is.na(isl$scores$hbSpread[length(ids)]))
})

test_that("no item is nulled on the empirical-Bayes path", {
  fx <- island_fixture("empirical_bayes_shrinkage")
  fx$results$hb_results$model_fit$reference_item <- fx$items$Item_ID[1]
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  expect_null(isl$meta$referenceItem)
  expect_equal(sum(is.na(isl$scores$hbSpread)), 0L)
})

test_that("the discrimination block does not classify the reference item", {
  fx <- stan_fixture(with_discrimination = TRUE)
  ref <- fx$results$hb_results$model_fit$reference_item
  isl <- serialize_maxdiff_layer(fx$results, fx$config, verbose = FALSE)
  pos <- match(ref, isl$discrimination$itemId)
  expect_false(is.na(pos))
  expect_true(is.na(isl$discrimination$classification[pos]))
  expect_true(is.na(isl$discrimination$label[pos]))
  expect_true(is.na(isl$discrimination$sdUtility[pos]))
  # every other item keeps its class
  expect_equal(sum(is.na(isl$discrimination$classification)), 1L)
})

test_that("the view explains the dash rather than leaving it to be read as missing", {
  src <- paste(readLines(file.path(TURAS_ROOT, "modules", "tabs", "lib",
                                   "html_report_v2", "assets", "js", "27y_maxdiff.js"),
                         warn = FALSE), collapse = "\n")
  expect_match(src, "meta.referenceItem", fixed = TRUE)
  expect_match(src, "is the reference item, fixed at zero", fixed = TRUE)
})

test_that("07_hb.R records which item the model fixed at zero", {
  src <- paste(readLines(file.path(TURAS_ROOT, "modules", "maxdiff", "R", "07_hb.R"),
                         warn = FALSE), collapse = "\n")
  expect_match(src, "reference_item = as.character(stan_data$item_ids[stan_data$J])",
               fixed = TRUE)
})
