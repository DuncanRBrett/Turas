# ==============================================================================
# MAXDIFF - REFERENCE GATE: AGGREGATE LOGIT
# ==============================================================================
# fit_aggregate_logit() is checked against two implementations that share no
# code with it: a conditional logit written from the likelihood and maximised
# with optim() (helper_reference_fixture.R), and mlogit fed the same best and
# worst choice sets. The model, written out:
#
#   best:  P(best = i | shown S)  = exp(b_i)  / sum_{j in S} exp(b_j)
#   worst: P(worst = i | shown S) = exp(-b_i) / sum_{j in S} exp(-b_j)
#
# with the anchor item's b fixed at 0. Each task is two choice sets and the
# worst set keeps the item already picked best.
# ==============================================================================

source(file.path(TURAS_ROOT, "modules", "maxdiff", "tests", "testthat",
                 "helper_reference_fixture.R"), local = TRUE)

REF_UTILS <- c(A = 1.4, B = 0.8, C = 0.2, D = -0.3, E = -0.8, F = 0)
REF_ANCHOR <- "F"

.ref_long <- function(seed = 21, n_resp = 40) {
  md_ref_simulate(REF_UTILS, n_resp = n_resp, n_tasks = 6,
                  items_per_task = 4, seed = seed)$long
}

test_that("unweighted logit utilities and SEs equal the hand-written conditional logit", {
  skip_if_not(requireNamespace("survival", quietly = TRUE), "survival not installed")
  long <- .ref_long()
  ref <- md_ref_clogit(long, REF_ANCHOR)
  mod <- md_module_logit(long, md_ref_items(names(REF_UTILS)), REF_ANCHOR, weighted = FALSE)

  expect_equal(mod$coef[names(ref$coef)], ref$coef, tolerance = 1e-5)
  expect_equal(mod$se[names(ref$coef)], ref$se_model, tolerance = 1e-4)
})

test_that("unweighted logit utilities and SEs equal mlogit on the same choice sets", {
  skip_if_not(requireNamespace("mlogit", quietly = TRUE), "mlogit not installed")
  skip_if_not(requireNamespace("dfidx", quietly = TRUE), "dfidx not installed")
  long <- .ref_long(seed = 22)
  items <- setdiff(names(REF_UTILS), REF_ANCHOR)

  # One mlogit choice situation per best set and per worst set. Alternatives
  # are the display positions; the item dummies are generic regressors, with
  # no alternative-specific constants (the "| 0" in the formula).
  key <- paste(long$resp_id, long$task, sep = "_")
  rows <- list()
  chid <- 0L
  for (ix in split(seq_len(nrow(long)), key)) {
    for (side in c("best", "worst")) {
      chid <- chid + 1L
      sgn <- if (side == "best") 1 else -1
      d <- data.frame(chid = chid, pos = long$position[ix],
                      choice = (if (side == "best") long$is_best[ix] else long$is_worst[ix]) == 1)
      for (i in items) d[[paste0("x", i)]] <- sgn * as.numeric(long$item_id[ix] == i)
      rows[[chid]] <- d
    }
  }
  md <- do.call(rbind, rows)
  md <- dfidx::dfidx(md, idx = c("chid", "pos"))
  fml <- as.formula(paste("choice ~", paste0("x", items, collapse = " + "), "| 0"))
  ml <- mlogit::mlogit(fml, data = md)
  ml_coef <- setNames(coef(ml)[paste0("x", items)], items)
  ml_se <- setNames(sqrt(diag(vcov(ml)))[paste0("x", items)], items)

  mod <- md_module_logit(long, md_ref_items(names(REF_UTILS)), REF_ANCHOR, weighted = FALSE)
  expect_equal(mod$coef[items], ml_coef, tolerance = 1e-5)
  expect_equal(mod$se[items], ml_se, tolerance = 1e-4)
})

test_that("weighted logit utilities maximise the weighted likelihood", {
  skip_if_not(requireNamespace("survival", quietly = TRUE), "survival not installed")
  long <- .ref_long(seed = 23)
  set.seed(5)
  w <- setNames(runif(40, 0.3, 3), paste0("R", 1:40))
  long$weight <- unname(w[long$resp_id])
  ref <- md_ref_clogit(long, REF_ANCHOR)
  mod <- md_module_logit(long, md_ref_items(names(REF_UTILS)), REF_ANCHOR, weighted = TRUE)
  expect_equal(mod$coef[names(ref$coef)], ref$coef, tolerance = 1e-5)
})

test_that("the anchor item sits at exactly 0 with no SE", {
  skip_if_not(requireNamespace("survival", quietly = TRUE), "survival not installed")
  res <- fit_aggregate_logit(.ref_long(), md_ref_items(names(REF_UTILS)),
                             weighted = FALSE, anchor_item = REF_ANCHOR, verbose = FALSE)
  a <- res$utilities[res$utilities$Item_ID == REF_ANCHOR, ]
  expect_identical(a$Logit_Utility, 0)
  expect_true(is.na(a$Logit_SE))
})
