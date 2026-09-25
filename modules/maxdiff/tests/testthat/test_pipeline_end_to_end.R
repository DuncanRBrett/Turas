# ==============================================================================
# MAXDIFF - PIPELINE GATE: CONFIG WORKBOOK TO OUTPUT FILES
# ==============================================================================
# run_maxdiff() runs in a child Rscript on a config workbook built by the
# shipped example's own generator (helper_pipeline_fixture.R). Every number
# below is read back from the files the run wrote, and checked against a
# reference computed here from the data and design FILES, never from the
# module's return value:
#
#   counts         hand weighted tallies of the rebuilt long data
#   logit          md_ref_clogit() (hand likelihood + respondent sandwich)
#   rescaled       min-max of the HB means on ITEM_SCORES
#   shares         mean per-respondent softmax of INDIVIDUAL_UTILS
#   tabs export    per-respondent softmax of INDIVIDUAL_UTILS, x 100
#   TURF           a greedy TOP_3 search written below, on INDIVIDUAL_UTILS
#   segments       hand weighted tallies per segment level
#
# The Stan runs use 500 warmup + 500 sampling draws on 2 chains, set on
# OUTPUT_SETTINGS where the module reads them. They skip without cmdstanr.
# ==============================================================================

source(file.path(TURAS_ROOT, "modules", "maxdiff", "tests", "testthat",
                 "helper_pipeline_fixture.R"), local = TRUE)
source(file.path(TURAS_ROOT, "modules", "maxdiff", "tests", "testthat",
                 "helper_reference_fixture.R"), local = TRUE)

FAST_HB <- c(HB_Iterations = "500", HB_Warmup = "500", HB_Chains = "2",
             TURF_Threshold = "TOP_3")

.softmax100 <- function(u) { e <- exp(u - max(u)); 100 * e / sum(e) }

# Greedy TURF on top-3 appeal, ties to the earlier column. Written from the
# definition, sharing no code with modules/shared/lib/turf_engine.R.
.hand_turf_top3 <- function(U, w, max_items) {
  appeal <- t(apply(U, 1, function(u) rank(-u, ties.method = "first") <= 3))
  chosen <- integer(0); out <- list()
  for (s in seq_len(max_items)) {
    cand <- setdiff(seq_len(ncol(U)), chosen)
    reach <- vapply(cand, function(j) {
      hit <- rowSums(appeal[, c(chosen, j), drop = FALSE]) > 0
      sum(w * hit) / sum(w)
    }, numeric(1))
    j <- cand[which.max(reach)]
    chosen <- c(chosen, j)
    out[[s]] <- data.frame(Item_ID = colnames(U)[j], Reach_Pct = round(100 * max(reach), 1))
    if (max(reach) >= 0.999) break
  }
  do.call(rbind, out)
}

.item_scores <- function(p) {
  x <- md_pipe_sheet(p$workbook, "ITEM_SCORES")
  x[!is.na(x$Item_ID), ]
}

.turf_steps <- function(p) {
  x <- md_pipe_sheet(p$workbook, "TURF_RESULTS")
  x[!is.na(suppressWarnings(as.integer(x$Step))), ]
}

# ------------------------------------------------------------------------------
# Weighted Stan run
# ------------------------------------------------------------------------------

skip_if_not(md_pipe_stan_ready(), "cmdstanr or CmdStan not installed")

PW <- md_pipe_run(n = 90, weighted = TRUE, output_settings = FAST_HB)
PW_LONG <- md_pipe_long(PW$build, weighted = TRUE)

test_that("weighted Stan pipeline run completes and writes every deliverable", {
  expect_equal(PW$status, "PASS", info = paste(tail(PW$log, 30), collapse = "\n"))
  for (f in c(PW$workbook, PW$island, PW$simulator, PW$stats_pack, PW$tabs_export)) {
    expect_true(file.exists(f), info = f)
  }
  expect_equal(jsonlite::fromJSON(PW$island)$meta$method, "stan_hb")
})

test_that("ITEM_SCORES counts equal hand weighted tallies from the data file", {
  sc <- .item_scores(PW)
  long <- PW_LONG$long
  for (id in sc$Item_ID) {
    d <- long[long$item_id == id, ]
    shown <- sum(d$weight)
    expect_equal(sc$Times_Shown[sc$Item_ID == id], shown, info = id)
    expect_equal(sc$Best_Pct[sc$Item_ID == id], 100 * sum(d$weight * d$is_best) / shown,
                 tolerance = 1e-9, info = id)
    expect_equal(sc$Worst_Pct[sc$Item_ID == id], 100 * sum(d$weight * d$is_worst) / shown,
                 tolerance = 1e-9, info = id)
  }
  expect_equal(sc$Net_Score, sc$Best_Pct - sc$Worst_Pct, tolerance = 1e-9)
})

test_that("ITEM_SCORES logit utilities and SEs equal the hand weighted conditional logit", {
  sc <- .item_scores(PW)
  anchor <- sc$Item_ID[!is.na(sc$Logit_Utility) & sc$Logit_Utility == 0 & is.na(sc$Logit_SE)]
  expect_length(anchor, 1)
  ref <- md_ref_clogit(PW_LONG$long, anchor)
  got <- setNames(sc$Logit_Utility, sc$Item_ID)[names(ref$coef)]
  got_se <- setNames(sc$Logit_SE, sc$Item_ID)[names(ref$coef)]
  expect_equal(unname(got), unname(ref$coef), tolerance = 1e-4)
  expect_equal(unname(got_se), unname(ref$se_sandwich), tolerance = 1e-3)
})

test_that("Rescaled_Score is min-max of the HB means and Rank follows it", {
  sc <- .item_scores(PW)
  u <- sc$HB_Utility_Mean
  expect_equal(sc$Rescaled_Score, 100 * (u - min(u)) / (max(u) - min(u)), tolerance = 1e-9)
  expect_equal(sc$Rank, rank(-u, ties.method = "min"))
})

test_that("island scores equal the workbook, and shares equal the hand softmax", {
  sc <- .item_scores(PW)
  iu <- md_pipe_sheet(PW$workbook, "INDIVIDUAL_UTILS")
  j <- jsonlite::fromJSON(PW$island)
  s <- j$scores
  m <- match(s$itemId, sc$Item_ID)
  expect_false(anyNA(m))
  for (pair in list(c("bestPct", "Best_Pct"), c("worstPct", "Worst_Pct"),
                    c("netScore", "Net_Score"), c("logitUtility", "Logit_Utility"),
                    c("hbUtility", "HB_Utility_Mean"), c("rescaled", "Rescaled_Score"))) {
    expect_equal(as.numeric(s[[pair[1]]]), sc[[pair[2]]][m], tolerance = 1e-6, info = pair[1])
  }
  U <- as.matrix(iu[, s$itemId])
  hand_share <- colMeans(t(apply(U, 1, .softmax100)))
  expect_equal(as.numeric(s$share), unname(hand_share), tolerance = 1e-6)
  expect_equal(sum(s$share), 100, tolerance = 1e-6)
})

test_that("the tabs export carries each respondent's softmax share of INDIVIDUAL_UTILS", {
  iu <- md_pipe_sheet(PW$workbook, "INDIVIDUAL_UTILS")
  te <- openxlsx::read.xlsx(PW$tabs_export, sheet = "DATA", skipEmptyRows = FALSE)
  items <- setdiff(names(iu), "resp_id")
  expect_equal(nrow(te), nrow(iu))
  U <- as.matrix(iu[match(te$RespID, iu$resp_id), items])
  hand <- t(apply(U, 1, .softmax100))
  share_cols <- paste0("MDSHARE_", seq_along(items))
  expect_equal(unname(as.matrix(te[, share_cols])), unname(hand), tolerance = 1e-6)
})

test_that("TURF_RESULTS equals a hand greedy TOP_3 search with the respondent weights", {
  iu <- md_pipe_sheet(PW$workbook, "INDIVIDUAL_UTILS")
  items <- setdiff(names(iu), "resp_id")
  w <- PW_LONG$data$Wt[match(iu$resp_id, PW_LONG$data$RespID)]
  hand <- .hand_turf_top3(as.matrix(iu[, items]), w, max_items = 5)
  got <- .turf_steps(PW)
  expect_equal(got$Item_ID, hand$Item_ID)
  expect_equal(as.numeric(got$Reach_Pct), hand$Reach_Pct)
  jt <- jsonlite::fromJSON(PW$island)$turf
  expect_equal(as.numeric(jt$reachPct), hand$Reach_Pct)
})

test_that("SEGMENT_SCORES equal hand weighted tallies per segment level", {
  seg <- md_pipe_sheet(PW$workbook, "SEGMENT_SCORES")
  seg <- seg[!is.na(seg$Item_ID), ]
  long <- PW_LONG$long
  data <- PW_LONG$data
  for (k in seq_len(nrow(seg))) {
    who <- data$RespID[data[[seg$Segment_ID[k]]] == seg$Segment_Value[k]]
    d <- long[long$resp_id %in% who & long$item_id == seg$Item_ID[k], ]
    expect_equal(seg$Segment_N[k], length(who))
    expect_equal(seg$Best_Pct[k], 100 * sum(d$weight * d$is_best) / sum(d$weight),
                 tolerance = 1e-9)
    expect_equal(seg$Worst_Pct[k], 100 * sum(d$weight * d$is_worst) / sum(d$weight),
                 tolerance = 1e-9)
  }
})

test_that("the simulator carries the same individual utilities as INDIVIDUAL_UTILS", {
  iu <- md_pipe_sheet(PW$workbook, "INDIVIDUAL_UTILS")
  h <- paste(readLines(PW$simulator, warn = FALSE), collapse = "\n")
  m <- regmatches(h, regexpr('(?s)<script type="application/json" id="sim-data">.*?</script>', h, perl = TRUE))
  js <- sub("(?s)^<script[^>]*>", "", sub("</script>$", "", m), perl = TRUE)
  d <- jsonlite::fromJSON(js, simplifyVector = FALSE)
  ids <- vapply(d$items, `[[`, "", "id")
  sim_ids <- vapply(d$individual_utils, `[[`, "", "id")
  expect_setequal(sim_ids, iu$resp_id)
  # utilities are positional, in the order of d$items.
  sim <- t(vapply(d$individual_utils, function(r) as.numeric(unlist(r$utilities)), numeric(length(ids))))
  ref <- as.matrix(iu[match(sim_ids, iu$resp_id), ids])
  expect_equal(unname(sim), unname(ref), tolerance = 1e-3)
})

test_that("the stats pack reports the Stan fit's convergence, not NOT CONVERGED", {
  # The run's island carries the sampler's own numbers; the stats pack must
  # agree with them. Before, the pack read fields the Stan extractor never
  # wrote, so every Stan run said NOT CONVERGED with R-hat and ESS "N/A".
  meta <- jsonlite::fromJSON(PW$island)$meta
  expect_equal(meta$nDivergences, 0)
  expect_equal(md_pipe_stats_value(PW$stats_pack, "Convergence Status"), "CONVERGED")
  rhat <- as.numeric(md_pipe_stats_value(PW$stats_pack, "R-hat Max"))
  ess <- as.numeric(md_pipe_stats_value(PW$stats_pack, "ESS Min"))
  expect_true(is.finite(rhat) && rhat >= 1 && rhat < 1.05)
  expect_true(is.finite(ess) && ess >= 100)
  expect_lte(ess, meta$minEss + 1)
  expect_gte(ess, meta$minEss - 1)
  expect_match(md_pipe_stats_value(PW$stats_pack, "Quality Score"), "^[0-9]+/100$")
})

test_that("the simulator's TURF panel says how its rule differs from TURF_RESULTS", {
  # The simulator counts each respondent's top K items, unweighted. This run's
  # workbook TURF is TOP_3 weighted by Wt, so the two can differ, and the
  # panel has to say so rather than leave two reach figures to disagree.
  h <- paste(readLines(PW$simulator, warn = FALSE), collapse = "\n")
  note <- regmatches(h, regexpr('<p class="sim-turf-method-note">[^<]*</p>', h))
  expect_length(note, 1)
  expect_match(note, "unweighted", fixed = TRUE)
  expect_match(note, "TURF_RESULTS", fixed = TRUE)
  expect_match(note, "weighted by Wt", fixed = TRUE)
})

# ------------------------------------------------------------------------------
# Consistency: the v2 MaxDiff tab and the simulator against the workbook
# ------------------------------------------------------------------------------

.node <- unname(Sys.which("node"))

.sim_data_file <- function(p) {
  h <- paste(readLines(p$simulator, warn = FALSE), collapse = "\n")
  m <- regmatches(h, regexpr('(?s)<script type="application/json" id="sim-data">.*?</script>', h, perl = TRUE))
  f <- tempfile(fileext = ".json")
  writeLines(sub("(?s)^<script[^>]*>", "", sub("</script>$", "", m), perl = TRUE), f)
  f
}

test_that("the rendered v2 MaxDiff tab shows the workbook's numbers", {
  skip_if(!nzchar(.node), "node not on PATH")
  renderer <- file.path(TURAS_ROOT, "modules", "tabs", "tests", "js", "render_maxdiff_island.mjs")
  html <- paste(system2(.node, c(shQuote(renderer), shQuote(PW$island)), stdout = TRUE), collapse = "\n")
  sc <- .item_scores(PW)
  share <- setNames(jsonlite::fromJSON(PW$island)$scores$share,
                    jsonlite::fromJSON(PW$island)$scores$itemId)
  rows <- regmatches(html, gregexpr("<tr><td>[^<]*<span class=\"md-tag\">.*?</tr>", html, perl = TRUE))[[1]]
  expect_equal(length(rows), nrow(sc))
  # The reference item prints a dash for its spread and SE; those read as NA.
  num <- function(r) suppressWarnings(as.numeric(gsub("[%,]", "", regmatches(r, gregexpr('(?<=<td class="md-num">)[^<]*', r, perl = TRUE))[[1]])))
  for (r in rows) {
    label <- trimws(sub("^<tr><td>([^<]*)<span.*$", "\\1", r))
    k <- match(label, sc$Item_Label)
    expect_false(is.na(k), info = label)
    v <- num(r)  # Share, Best, Worst, Net, Utility, Spread, Mean SE, Score
    expect_equal(v[1], round(share[[sc$Item_ID[k]]], 1), tolerance = 0.051, info = label)
    expect_equal(v[2], sc$Best_Pct[k], tolerance = 0.051, info = label)
    expect_equal(v[3], sc$Worst_Pct[k], tolerance = 0.051, info = label)
    expect_equal(v[4], sc$Net_Score[k], tolerance = 0.051, info = label)
    expect_equal(v[5], sc$HB_Utility_Mean[k], tolerance = 0.0051, info = label)
    expect_equal(v[8], sc$Rescaled_Score[k], tolerance = 0.51, info = label)
  }
})

# An unweighted TOP_3 run: here the simulator's rule and the workbook's
# coincide, so the shipped engine must reproduce TURF_RESULTS and the shares.
PU <- md_pipe_run(n = 60, weighted = FALSE, output_settings = FAST_HB)

test_that("the simulator engine reproduces TURF_RESULTS and the shares when the rules coincide", {
  skip_if(!nzchar(.node), "node not on PATH")
  expect_equal(PU$status, "PASS", info = paste(tail(PU$log, 30), collapse = "\n"))
  runner <- file.path(TURAS_ROOT, "modules", "maxdiff", "tests", "js", "run_engine_on_simdata.mjs")
  js <- jsonlite::fromJSON(paste(system2(.node, c(shQuote(runner), shQuote(.sim_data_file(PU)), "5", "3"),
                                         stdout = TRUE), collapse = ""))
  turf <- .turf_steps(PU)
  expect_equal(js$turf$itemId, turf$Item_ID)
  expect_equal(js$turf$reach, as.numeric(turf$Reach_Pct))
  island <- jsonlite::fromJSON(PU$island)$scores
  expect_equal(js$shares$share[match(island$itemId, js$shares$itemId)],
               as.numeric(island$share), tolerance = 1e-3)
})

test_that("the weighting disclosures say which numbers are weighted", {
  # Counts, the logit and TURF are weighted; the HB utilities and the shares
  # built on them are not. The island note used to say "The utilities are
  # estimated unweighted" beside a weighted logit, and the SUMMARY sheet
  # called the logit a frequency-weight approximation after its SEs became
  # the respondent-clustered sandwich.
  note <- jsonlite::fromJSON(PW$island)$meta$weightingNote
  expect_match(note, "logit utilities", fixed = TRUE)
  expect_match(note, "TURF", fixed = TRUE)
  expect_match(note, "HB utilities", fixed = TRUE)
  expect_false(grepl("The utilities are estimated unweighted", note, fixed = TRUE))
  sm <- openxlsx::read.xlsx(PW$workbook, sheet = "SUMMARY", colNames = FALSE, skipEmptyRows = FALSE)
  txt <- paste(unlist(sm)[!is.na(unlist(sm))], collapse = "\n")
  expect_match(txt, "clustered by respondent", fixed = TRUE)
  expect_false(grepl("frequency-weight approximation", txt, fixed = TRUE))
})
