# ==============================================================================
# TABS. ADVERSARIAL GATE (robustness programme, session 2, 24 Sep 2026)
# ==============================================================================
#
# The hard cases, run end to end: fixtures/adversarial_project is generated into
# a temp folder, each config runs through run_tabs_analysis() in a child
# Rscript, and the numbers are read back from the workbook and the v2 island.
#
#   design effect exactly 2 (W2), the same weights grossed x1000 (WG), and
#   unweighted; a rating and an NPS with a don't-know coded 99 and flagged
#   ExcludeFromIndex; a multi-mention with non-mentioners; labels starting with
#   - + = @ and non-ASCII; a base filter that empties a column; columns under
#   the low-base threshold (on the EFFECTIVE base when weighted).
#
# References share no Turas code: survey::svymean, stats::cov.wt, the Kish
# formula and hand values in the comments.
# ==============================================================================

library(testthat)

.av_root <- local({
  home <- Sys.getenv("TURAS_HOME", "")
  cands <- c(home, getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."),
             file.path(getwd(), "../../../.."))
  hit <- NULL
  for (cd in cands) {
    if (nzchar(cd) && dir.exists(file.path(cd, "modules", "tabs"))) { hit <- normalizePath(cd); break }
  }
  hit
})
skip_if(is.null(.av_root), "Turas root not found (set TURAS_HOME)")
skip_if_not_installed("survey")
skip_if_not_installed("jsonlite")

.av_fx <- file.path(.av_root, "modules/tabs/tests/fixtures/adversarial_project")
local({
  e <- environment()
  sys.source(file.path(.av_root, "modules/tabs/tests/fixtures/parity_project/pipeline_readers.R"), envir = e)
  for (nm in ls(e, all.names = TRUE)) assign(nm, get(nm, envir = e), envir = parent.frame(2))
})
source(file.path(.av_fx, "generate_adversarial_project.R"), local = TRUE)

.av_env <- new.env(parent = emptyenv())

.av_project <- function() {
  if (is.null(.av_env$dir)) {
    d <- file.path(tempfile("tabs_adversarial_"), "proj")
    generate_adversarial_project(d)
    .av_env$dir <- d
    .av_env$data <- build_adversarial_data()
  }
  .av_env$dir
}

.av_run <- function(which) {
  key <- paste0("run_", which)
  if (!is.null(.av_env[[key]])) return(.av_env[[key]])
  d <- .av_project()
  log <- file.path(dirname(d), paste0(which, ".log"))
  status <- system2(file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(.av_fx, "run_config_child.R")), shQuote(.av_root),
      shQuote(file.path(d, paste0("Adv_Config_", which, ".xlsx")))),
    stdout = log, stderr = log,
    env = paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep)))
  out <- file.path(d, "Output")
  res <- list(status = status, log = log,
              xlsx = file.path(out, paste0("Adv_", which, ".xlsx")),
              html = file.path(out, paste0("Adv_", which, "_report.html")))
  .av_env[[key]] <- res
  res
}

.av_cols <- c("Total", "North", "South", "East", "West")
.av_in <- function(d, col) if (col == "Total") rep(TRUE, nrow(d)) else d$Region == col
.av_w <- function(d, which) switch(which, Unweighted = rep(1, nrow(d)), W2 = d$W2, WG = d$WG)
.av_svy <- function(y, w) {
  des <- survey::svydesign(ids = ~1, weights = ~w, data = data.frame(y = y, w = w))
  unname(coef(survey::svymean(~y, des)))
}
.av_num <- function(v) suppressWarnings(as.numeric(v))

# ==============================================================================
# PIPELINE + CONSISTENCY
# ==============================================================================

for (which in c("Unweighted", "W2", "WG")) local({
  w <- which
  test_that(sprintf("adversarial (%s): runs end to end; every island cell equals the workbook", w), {
    run <- .av_run(w)
    expect_equal(run$status, 0L, info = paste(readLines(run$log, warn = FALSE), collapse = "\n"))
    cons <- .rp_consistency(run$xlsx, run$html)
    expect_equal(cons$bad, character(0))
    expect_equal(cons$n_checked, cons$n_rows)
    # Every question reached both outputs (a dropped question is not a pass).
    expect_setequal(vapply(cons$island$questions, function(q) q$code, character(1)),
                    c("Region", "QR", "QN", "QM", "QL", "QF"))
    expect_true(all(c("Region", "QR", "QN", "QM", "QL", "QF") %in% names(cons$workbook)))
  })
})

# ==============================================================================
# DESIGN EFFECT 2: effective bases by hand, and the min-base gate rides them
# ==============================================================================
#
# One in five at 3.0, the rest 0.5: sum w = n, sum w^2 = 2n, n_eff = n / 2.
# North 50 -> 25, South 40 -> 20, East 20 -> 10, West 10 -> 5, Total 60. Every
# region's EFFECTIVE base is under 30, so a weighted run letters nothing, even
# though North (50) and South (40) clear 30 on the raw count.

test_that("adversarial (W2): effective bases are n / 2 by hand", {
  wb <- .rp_read_workbook(.av_run("W2")$xlsx)
  isl <- .rp_read_island(.av_run("W2")$html)
  expect_equal(.av_num(.rp_cells(wb$QR, "", "Effective base")), c(60, 25, 20, 10, 5))
  qr <- Filter(function(q) q$code == "QR", isl$questions)[[1]]
  expect_equal(vapply(qr$bases, function(b) b$nEff, numeric(1)), c(60, 25, 20, 10, 5),
               tolerance = 1e-9)
})

test_that("adversarial (W2): no letter anywhere, every effective base is under 30", {
  wb <- .rp_read_workbook(.av_run("W2")$xlsx)
  for (q in names(wb)) {
    sig <- wb[[q]][wb[[q]]$type %in% c("Sig.", "Sig.2"), grep("^X", names(wb[[q]])), drop = FALSE]
    expect_true(all(.rp_blank(unlist(sig)) == ""), info = q)
  }
})

test_that("adversarial (Unweighted): East (20) and West (10) never take or give a letter", {
  wb <- .rp_read_workbook(.av_run("Unweighted")$xlsx)
  for (q in names(wb)) {
    sig <- wb[[q]][wb[[q]]$type %in% c("Sig.", "Sig.2"), , drop = FALSE]
    if (!nrow(sig)) next
    vals <- as.matrix(sig[, grep("^X", names(sig)), drop = FALSE])
    expect_true(all(.rp_blank(vals[, 4:5]) == ""), info = paste(q, "East/West carry a letter"))
    expect_false(any(grepl("[CDcd]", vals)), info = paste(q, "a letter cites East or West"))
  }
})

# ==============================================================================
# GROSSED WEIGHTS: nothing but the weighted base may move
# ==============================================================================

test_that("adversarial (WG): grossed x1000 prints the same percentages, means, SDs and letters", {
  a <- .rp_read_workbook(.av_run("W2")$xlsx)
  b <- .rp_read_workbook(.av_run("WG")$xlsx)
  expect_setequal(names(a), names(b))
  for (q in names(a)) {
    keep <- !(a[[q]]$type %in% c("Frequency", "Base (weighted)"))
    xa <- a[[q]][keep, , drop = FALSE]; xb <- b[[q]][!(b[[q]]$type %in% c("Frequency", "Base (weighted)")), , drop = FALSE]
    expect_equal(xb, xa, info = q)
  }
  # The weighted base is the one figure that scales; compare it unrounded, from
  # the island (the workbook prints it at 0 dp, 88.5 -> 88 against 88500).
  ia <- .rp_read_island(.av_run("W2")$html); ib <- .rp_read_island(.av_run("WG")$html)
  # An emptied column (QF / East) carries no weighted base at all: read as NA.
  field <- function(bs, f) vapply(bs, function(x) if (is.null(x[[f]])) NA_real_ else x[[f]], numeric(1))
  for (i in seq_along(ia$questions)) {
    expect_equal(field(ib$questions[[i]]$bases, "nWeighted"),
                 field(ia$questions[[i]]$bases, "nWeighted") * 1000,
                 tolerance = 1e-9, info = ia$questions[[i]]$code)
    expect_equal(field(ib$questions[[i]]$bases, "nEff"), field(ia$questions[[i]]$bases, "nEff"),
                 tolerance = 1e-9, info = ia$questions[[i]]$code)
  }
})

# ==============================================================================
# DON'T KNOW (99, ExcludeFromIndex): out of means and NPS, in the % base
# ==============================================================================

for (which in c("Unweighted", "W2")) local({
  w <- which
  test_that(sprintf("adversarial (%s): QR mean and SD leave the 99 out; NET POSITIVE and %% keep it in the base", w), {
    d <- build_adversarial_data(); wt <- .av_w(d, w)
    wb <- .rp_read_workbook(.av_run(w)$xlsx)
    ok <- d$QR != 99
    mean_ref <- vapply(.av_cols, function(col) {
      r <- .av_in(d, col) & ok; .av_svy(d$QR[r], wt[r]) }, numeric(1))
    sd_ref <- vapply(.av_cols, function(col) {
      r <- .av_in(d, col) & ok
      sqrt(stats::cov.wt(matrix(d$QR[r], ncol = 1), wt = wt[r] / sum(wt[r]), method = "unbiased")$cov[1, 1])
    }, numeric(1))
    expect_equal(.av_num(.rp_cells(wb$QR, "Mean", "Average")), round(unname(mean_ref), 3), tolerance = 1e-9)
    expect_equal(.av_num(.rp_cells(wb$QR, "Standard Deviation", "StdDev")), round(unname(sd_ref), 3),
                 tolerance = 1e-9)
    np <- ifelse(d$QR %in% 4:5, 100, ifelse(d$QR %in% 1:2, -100, 0))   # DK answered, scores 0
    np_ref <- vapply(.av_cols, function(col) { r <- .av_in(d, col); .av_svy(np[r], wt[r]) }, numeric(1))
    expect_equal(.av_num(.rp_cells(wb$QR, "NET POSITIVE (Top 2 Box - Bottom 2 Box)", "Column %")),
                 round(unname(np_ref), 2), tolerance = 1e-9)
    dk_ref <- vapply(.av_cols, function(col) { r <- .av_in(d, col); 100 * .av_svy(as.numeric(d$QR[r] == 99), wt[r]) }, numeric(1))
    expect_equal(.av_num(.rp_cells(wb$QR, "Don't know", "Column %")), round(unname(dk_ref), 2), tolerance = 1e-9)
  })

  test_that(sprintf("adversarial (%s): QN NPS leaves the 99 out", w), {
    d <- build_adversarial_data(); wt <- .av_w(d, w)
    wb <- .rp_read_workbook(.av_run(w)$xlsx)
    # Hand, every region (the pattern repeats in tens): of 10 answers, 3 are 99;
    # promoters 10, 9, 10, 9 = 4 of 7... per ten: 10,9,8,7,99,6,0,10,5,9 ->
    # promoters 4, passives 2, detractors 3 (6, 0, 5) of 9 non-DK: NPS = 1/9.
    ok <- d$QN != 99
    b <- ifelse(d$QN >= 9, 100, ifelse(d$QN >= 7, 0, -100))
    ref <- vapply(.av_cols, function(col) { r <- .av_in(d, col) & ok; .av_svy(b[r], wt[r]) }, numeric(1))
    expect_equal(.av_num(.rp_cells(wb$QN, "NPS Score", "Score")), round(unname(ref), 2), tolerance = 1e-9)
  })

  test_that(sprintf("adversarial (%s): QM percentages are mentions over people who mentioned anything", w), {
    d <- build_adversarial_data(); wt <- .av_w(d, w)
    wb <- .rp_read_workbook(.av_run(w)$xlsx)
    any_m <- !is.na(d$QM_1) | !is.na(d$QM_2) | !is.na(d$QM_3)
    expect_equal(.av_num(.rp_cells(wb$QM, "", if (w == "Unweighted") "Base (n=)" else "Base (unweighted)")),
                 unname(vapply(.av_cols, function(col) sum(any_m & .av_in(d, col)), numeric(1))))
    for (m in list(c("QM_1", "Bank"), c("QM_2", "Retailer"), c("QM_3", "Other"))) {
      ref <- vapply(.av_cols, function(col) {
        r <- .av_in(d, col) & any_m; 100 * .av_svy(as.numeric(!is.na(d[[m[1]]][r])), wt[r]) }, numeric(1))
      expect_equal(.av_num(.rp_cells(wb$QM, m[2], "Column %")), round(unname(ref), 2), tolerance = 1e-9,
                   info = m[2])
    }
  })

  test_that(sprintf("adversarial (%s): labels starting - + = @ and non-ASCII survive both outputs", w), {
    d <- build_adversarial_data(); wt <- .av_w(d, w)
    run <- .av_run(w)
    wb <- .rp_read_workbook(run$xlsx)
    isl <- .rp_read_island(run$html)
    ql <- Filter(function(q) q$code == "QL", isl$questions)[[1]]
    expect_equal(vapply(ql$rows, function(r) r$label, character(1)), ADV_LABELS)
    expect_equal(unique(wb$QL$label[wb$QL$type == "Frequency"]), ADV_LABELS)
    for (lab in ADV_LABELS) {
      ref <- vapply(.av_cols, function(col) { r <- .av_in(d, col); 100 * .av_svy(as.numeric(d$QL[r] == lab), wt[r]) }, numeric(1))
      expect_equal(.av_num(.rp_cells(wb$QL, lab, "Column %")), round(unname(ref), 2), tolerance = 1e-9, info = lab)
    }
  })

  test_that(sprintf("adversarial (%s): a filter that empties East leaves a blank column, not a crash", w), {
    wb <- .rp_read_workbook(.av_run(w)$xlsx)
    base_type <- if (w == "Unweighted") "Base (n=)" else "Base (unweighted)"
    expect_equal(.av_num(.rp_cells(wb$QF, "", base_type)), c(100, 50, 40, 0, 10))
    expect_true(is.na(.av_num(.rp_cells(wb$QF, "Yes", "Column %"))[4]))
    expect_equal(.rp_blank(.rp_sig(wb$QF, "Yes", "Column %"))[4], "")
  })
})
