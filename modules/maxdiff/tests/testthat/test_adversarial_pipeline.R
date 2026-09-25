# ==============================================================================
# MAXDIFF - ADVERSARIAL GATE
# ==============================================================================
# One pipeline run (helper_pipeline_fixture.R) carrying the hard cases:
#   - weights grossed to integer population totals (500 / 1000 / 2500)
#   - item labels starting with = - + @ and labels with non-ASCII text
#   - one task with no best choice, one with no worst choice
#   - 60 respondents against Min_Respondents_Per_Segment = 30, so most
#     segment levels fall under the base
# It runs on the empirical-Bayes path (cmdstanr hidden) so it needs no Stan.
# Every number is checked against the same hand references as the pipeline
# gate, computed from the data and design files.
# ==============================================================================

source(file.path(TURAS_ROOT, "modules", "maxdiff", "tests", "testthat",
                 "helper_pipeline_fixture.R"), local = TRUE)
source(file.path(TURAS_ROOT, "modules", "maxdiff", "tests", "testthat",
                 "helper_reference_fixture.R"), local = TRUE)

.no_cmdstanr <- function() {
  lib <- tempfile("no_cmdstanr_")
  dir.create(file.path(lib, "cmdstanr"), recursive = TRUE)
  writeLines(c("Package: cmdstanr", "Version: 0.0.0"), file.path(lib, "cmdstanr", "DESCRIPTION"))
  lib
}

ADV_LABELS <- c(FRESH = "=Fresh roast", ORIGIN = "-Origin named", PRICE = "+Price cut",
                DELIVERY = "@Home delivery", SUBSCRIBE = "Café crème subscription",
                GRIND = "Grind für Filter – fine")

PA <- md_pipe_run(n = 60, weighted = TRUE, weight_scale = 1000,
                  item_labels = ADV_LABELS, lib_prepend = .no_cmdstanr(),
                  output_settings = c(TURF_Threshold = "TOP_3"),
                  data_edits = "dat$T1_Best[1] <- NA; dat$T2_Worst[2] <- NA")
PA_LONG <- md_pipe_long(PA$build, weighted = TRUE)

test_that("the adversarial run completes and writes its deliverables", {
  expect_true(file.exists(PA$workbook), info = paste(tail(PA$log, 40), collapse = "\n"))
  expect_true(file.exists(PA$island))
  expect_true(file.exists(PA$simulator))
  expect_equal(range(PA_LONG$data$Wt), c(500, 2500))
})

test_that("grossed integer weights: counts equal hand tallies, logit SEs stay design-based", {
  sc <- md_pipe_sheet(PA$workbook, "ITEM_SCORES")
  sc <- sc[!is.na(sc$Item_ID), ]
  long <- PA_LONG$long
  for (id in sc$Item_ID) {
    d <- long[long$item_id == id, ]
    expect_equal(sc$Best_Pct[sc$Item_ID == id], 100 * sum(d$weight * d$is_best) / sum(d$weight),
                 tolerance = 1e-9, info = id)
    expect_equal(sc$Worst_Pct[sc$Item_ID == id], 100 * sum(d$weight * d$is_worst) / sum(d$weight),
                 tolerance = 1e-9, info = id)
  }
  # The logit drops the two tasks lacking one best and one worst.
  key <- paste(long$resp_id, long$task)
  ok <- ave(long$is_best, key, FUN = sum) == 1 & ave(long$is_worst, key, FUN = sum) == 1
  anchor <- sc$Item_ID[!is.na(sc$Logit_Utility) & sc$Logit_Utility == 0 & is.na(sc$Logit_SE)]
  ref <- md_ref_clogit(long[ok, ], anchor)
  got <- setNames(sc$Logit_Utility, sc$Item_ID)[names(ref$coef)]
  got_se <- setNames(sc$Logit_SE, sc$Item_ID)[names(ref$coef)]
  expect_equal(unname(got), unname(ref$coef), tolerance = 1e-4)
  expect_equal(unname(got_se), unname(ref$se_sandwich), tolerance = 1e-3)
  expect_gt(min(got_se), 0.05)
})

test_that("labels starting with = - + @ and non-ASCII labels survive every deliverable", {
  island <- jsonlite::fromJSON(PA$island)$scores
  for (id in names(ADV_LABELS)) {
    expect_equal(island$label[island$itemId == id], unname(ADV_LABELS[id]), info = id)
  }
  h <- paste(readLines(PA$simulator, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  m <- regmatches(h, regexpr('(?s)<script type="application/json" id="sim-data">.*?</script>', h, perl = TRUE))
  sim <- jsonlite::fromJSON(sub("(?s)^<script[^>]*>", "", sub("</script>$", "", m), perl = TRUE))
  for (id in names(ADV_LABELS)) {
    expect_equal(sim$items$label[sim$items$id == id], unname(ADV_LABELS[id]), info = id)
  }
  # Workbook: the text is the label (the shared escape may prefix one
  # apostrophe to a leading = - + @, a platform-wide display matter parked
  # for Duncan), and no ITEM_SCORES cell is a formula.
  sc <- md_pipe_sheet(PA$workbook, "ITEM_SCORES")
  for (id in names(ADV_LABELS)) {
    expect_equal(sub("^'", "", sc$Item_Label[sc$Item_ID %in% id]), unname(ADV_LABELS[id]), info = id)
  }
  parts <- utils::unzip(PA$workbook, list = TRUE)$Name
  expect_false(any(vapply(grep("^xl/worksheets/sheet[0-9]+[.]xml$", parts, value = TRUE), function(sx)
    grepl("<f>", paste(readLines(unz(PA$workbook, sx), warn = FALSE), collapse = ""), fixed = TRUE),
    logical(1))))
})

test_that("segment levels under the minimum base are left out, and the rest are hand-correct", {
  seg <- md_pipe_sheet(PA$workbook, "SEGMENT_SCORES")
  seg <- seg[!is.na(seg$Item_ID), ]
  expect_true(all(seg$Segment_N >= 30))
  data <- PA_LONG$data
  long <- PA_LONG$long
  for (k in seq_len(nrow(seg))) {
    who <- data$RespID[data[[seg$Segment_ID[k]]] == seg$Segment_Value[k]]
    d <- long[long$resp_id %in% who & long$item_id == seg$Item_ID[k], ]
    expect_equal(seg$Best_Pct[k], 100 * sum(d$weight * d$is_best) / sum(d$weight), tolerance = 1e-9)
  }
})
