# ==============================================================================
# TEST SUITE: Tracker pipeline, config to workbooks, read back and checked
# ==============================================================================
# Robustness programme, 24 Sep 2026 (TURAS_ROBUSTNESS_BRIEF.md, Tracker):
#   Pipeline gate     run_tracker() on a synthetic two-wave project, in a
#                     child Rscript so nothing it sets leaks into the runner;
#                     every number is read back FROM THE WORKBOOKS
#   Reference gate    each value compared with survey::svymean or a hand
#                     calculation made here from the wave CSVs, sharing no
#                     Turas code
#   Consistency gate  the detailed sheet, wave history, Trend Dashboard, Sig
#                     Matrix and tracking crosstab agree with each other and
#                     with the same hand-computed tests
#   Adversarial gate  design-effect weights, W2 grossed to 2.4 million, a
#                     numeric don't-know code, a routed multi-mention, a
#                     composite, a code present in one wave only, a label
#                     starting with "-", a non-ASCII label, a question in W2
#                     only, and a banner segment whose effective base is under
#                     minimum_base
# The fixture is helper_pipeline_fixture.R.
# ==============================================================================

library(testthat)

context("Pipeline: run_tracker() to workbooks")

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

source(file.path(turas_root, "modules", "shared", "lib", "turas_save_workbook_atomic.R"))
source(file.path(test_dir, "helper_pipeline_fixture.R"))

skip_if_not(requireNamespace("survey", quietly = TRUE), "survey package not installed")
skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not installed")


# ------------------------------------------------------------------------------
# Run the real pipeline once per mode, in a child process
# ------------------------------------------------------------------------------

run_tracker_child <- function(fixture, use_banners) {
  script <- tempfile(fileext = ".R")
  writeLines(c(
    sprintf("setwd(%s)", deparse(turas_root)),
    "source('modules/tracker/run_tracker.R')",
    sprintf("invisible(run_tracker(%s, data_dir = %s, use_banners = %s))",
            deparse(fixture$config_path), deparse(fixture$dir), use_banners)
  ), script)
  on.exit(unlink(script), add = TRUE)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), shQuote(script),
    stdout = TRUE, stderr = TRUE,
    env = c(paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep)),
            "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE")))
  status <- attr(out, "status")
  list(status = if (is.null(status)) 0L else status, log = out)
}

output_file <- function(dir, kind) {
  f <- list.files(dir, pattern = paste0("_", kind, "_.*\\.xlsx$"), full.names = TRUE)
  if (length(f) == 1) f else NA_character_
}

read_sheet <- function(file, sheet) {
  openxlsx::read.xlsx(file, sheet = sheet, colNames = FALSE, skipEmptyRows = FALSE)
}

pipeline_runs <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) return(cache)
    base <- file.path(tempdir(), paste0("tracker_pipeline_", Sys.getpid()))
    unlink(base, recursive = TRUE)
    flat <- pipeline_fixture_write(file.path(base, "flat"))
    banner <- pipeline_fixture_write(file.path(base, "banner"))
    cache <<- list(
      flat = c(flat, run = list(run_tracker_child(flat, FALSE))),
      banner = c(banner, run = list(run_tracker_child(banner, TRUE))),
      base = base)
    cache
  }
})


# ------------------------------------------------------------------------------
# Reference numbers from the CSVs (no Turas code)
# ------------------------------------------------------------------------------

wave_csv <- function(fx, wid) {
  utils::read.csv(file.path(fx$dir, paste0(wid, ".csv")), stringsAsFactors = FALSE,
                  fileEncoding = "UTF-8", check.names = FALSE)
}

kish <- function(w) sum(w)^2 / sum(w^2)
svy <- function(df) survey::svydesign(ids = ~1, weights = ~w, data = df)
svy_mean <- function(x, w) unname(stats::coef(survey::svymean(~x, svy(data.frame(x = x, w = w)))))
svy_share <- function(hit, w) 100 * svy_mean(as.numeric(hit), w)
wsd <- function(x, w) sqrt(stats::cov.wt(matrix(x), wt = w / sum(w), method = "unbiased")$cov[1, 1])

# Pooled t on Kish effective bases, and pooled two-proportion z, written out
t_p <- function(m1, s1, n1, m2, s2, n2) {
  pooled <- ((n1 - 1) * s1^2 + (n2 - 1) * s2^2) / (n1 + n2 - 2)
  t <- (m2 - m1) / sqrt(pooled * (1 / n1 + 1 / n2))
  2 * stats::pt(-abs(t), n1 + n2 - 2)
}
z_p <- function(p1, n1, p2, n2) {
  pp <- (p1 * n1 + p2 * n2) / (n1 + n2)
  z <- (p2 - p1) / sqrt(pp * (1 - pp) * (1 / n1 + 1 / n2))
  2 * stats::pnorm(-abs(z))
}
nps_p <- function(a, b) {
  v <- function(r) 10000 * ((r$pp + r$pd) - (r$pp - r$pd)^2) / r$n
  2 * stats::pnorm(-abs(b$nps - a$nps) / sqrt(v(a) + v(b)))
}

ref_wave <- function(df) {
  w <- df$wt
  sat_ok <- df$Q10 != 99
  sat <- df$Q10[sat_ok]; w_sat <- w[sat_ok]
  sc <- ifelse(df$Q15 >= 9, 100, ifelse(df$Q15 <= 6, -100, 0))
  answered <- rowSums(!is.na(df[, c("Q30_1", "Q30_2", "Q30_3")])) > 0
  mm <- df[answered, ]; w_mm <- w[answered]
  cx <- rowMeans(cbind(ifelse(sat_ok, df$Q10, NA), df$Q11), na.rm = TRUE)
  list(
    sat = list(mean = svy_mean(sat, w_sat), sd = wsd(sat, w_sat), n = length(sat),
               eff = kish(w_sat), top2 = svy_share(sat >= 4, w_sat)),
    rec = list(nps = svy_mean(sc, w), pp = svy_mean(as.numeric(df$Q15 >= 9), w),
               pd = svy_mean(as.numeric(df$Q15 <= 6), w), pas = svy_share(df$Q15 %in% 7:8, w),
               n = kish(w), n_raw = nrow(df)),
    aware = lapply(stats::setNames(nm = c("Yes", "No", "Café", "- None of these")),
                   function(code) svy_share(df$Q20 == code, w)),
    aware_eff = kish(w),
    chan = list(q1 = svy_share(mm$Q30_1 == 1, w_mm), q2 = svy_share(mm$Q30_2 == 1, w_mm),
                q3 = svy_share(mm$Q30_3 == 1, w_mm),
                any = svy_share(rowSums(mm[, c("Q30_1", "Q30_2", "Q30_3")] == 1, na.rm = TRUE) > 0, w_mm),
                n = nrow(mm), eff = kish(w_mm)),
    cx = list(mean = svy_mean(cx, w), sd = wsd(cx, w), eff = kish(w),
              r45 = svy_share(cx >= 4 & cx <= 5, w)),
    newq = if ("Q40" %in% names(df)) svy_mean(df$Q40, w) else NA_real_
  )
}

references <- function(fx) {
  list(W1 = ref_wave(wave_csv(fx, "W1")), W2 = ref_wave(wave_csv(fx, "W2")))
}

# Hand verdicts for W1 -> W2 at alpha 0.05, minimum base 30
hand_verdicts <- function(r) {
  a <- r$W1; b <- r$W2
  verdict <- function(p, d) if (p < 0.05) (if (d > 0) "↑" else "↓") else "→"
  list(
    SAT = verdict(t_p(a$sat$mean, a$sat$sd, a$sat$eff, b$sat$mean, b$sat$sd, b$sat$eff),
                  b$sat$mean - a$sat$mean),
    REC = verdict(nps_p(list(nps = a$rec$nps, pp = a$rec$pp, pd = a$rec$pd, n = a$rec$n),
                        list(nps = b$rec$nps, pp = b$rec$pp, pd = b$rec$pd, n = b$rec$n)),
                  b$rec$nps - a$rec$nps),
    CHAN = verdict(z_p(a$chan$q1 / 100, a$chan$eff, b$chan$q1 / 100, b$chan$eff),
                   b$chan$q1 - a$chan$q1),
    CX = verdict(t_p(a$cx$mean, a$cx$sd, a$cx$eff, b$cx$mean, b$cx$sd, b$cx$eff),
                 b$cx$mean - a$cx$mean),
    AWARE_Yes = verdict(z_p(a$aware$Yes / 100, a$aware_eff, b$aware$Yes / 100, b$aware_eff),
                        b$aware$Yes - a$aware$Yes)
  )
}

row_values <- function(df, label, cols) {
  r <- which(df[[1]] == label)[1]
  if (is.na(r)) return(rep(NA_real_, length(cols)))
  suppressWarnings(as.numeric(unlist(df[r, cols])))
}


# ==============================================================================
# TESTS: the run itself
# ==============================================================================

test_that("run_tracker() finishes and writes all five workbooks, flat and with banners", {
  runs <- pipeline_runs()
  for (mode in c("flat", "banner")) {
    run <- runs[[mode]]$run
    expect_equal(run$status, 0L, info = paste(mode, tail(run$log, 15), collapse = "\n"))
    for (kind in c("Tracker", "WaveHistory", "Dashboard", "SigMatrix", "TrackingCrosstab")) {
      expect_false(is.na(output_file(runs[[mode]]$dir, kind)), info = paste(mode, kind))
    }
  }
})


# ==============================================================================
# TESTS: detailed trend sheets against the reference
# ==============================================================================

test_that("detailed sheets match survey::svymean and hand counts, wave by wave", {
  runs <- pipeline_runs()
  fx <- runs$flat
  r <- references(fx)
  f <- output_file(fx$dir, "Tracker")
  cols <- 2:3
  ref2 <- function(get) round(c(get(r$W1), get(r$W2)), 2)

  sat <- read_sheet(f, "SAT")
  expect_equal(row_values(sat, "Mean", cols), ref2(function(x) x$sat$mean))
  expect_equal(row_values(sat, "Top 2 Box %", cols), ref2(function(x) x$sat$top2))
  expect_equal(row_values(sat, "Sample Size (n)", cols), c(r$W1$sat$n, r$W2$sat$n))

  rec <- read_sheet(f, "REC")
  expect_equal(row_values(rec, "NPS Score", cols), ref2(function(x) x$rec$nps))
  expect_equal(row_values(rec, "% Promoters (9-10)", cols), ref2(function(x) 100 * x$rec$pp))
  expect_equal(row_values(rec, "% Passives (7-8)", cols), ref2(function(x) x$rec$pas))
  expect_equal(row_values(rec, "% Detractors (0-6)", cols), ref2(function(x) 100 * x$rec$pd))

  aware <- read_sheet(f, "AWARE")
  for (code in c("Yes", "No", "Café", "- None of these")) {
    expect_equal(row_values(aware, code, cols), ref2(function(x) x$aware[[code]]), info = code)
  }

  chan <- read_sheet(f, "CHAN")
  expect_equal(row_values(chan, "Q30_1", cols), ref2(function(x) x$chan$q1))
  expect_equal(row_values(chan, "Q30_2", cols), ref2(function(x) x$chan$q2))
  expect_equal(row_values(chan, "Q30_3", cols), ref2(function(x) x$chan$q3))
  expect_equal(row_values(chan, "% Mentioning Any", cols), ref2(function(x) x$chan$any))
  expect_equal(row_values(chan, "Sample Size (n)", cols), c(r$W1$chan$n, r$W2$chan$n))

  cx <- read_sheet(f, "CX")
  expect_equal(row_values(cx, "Mean", cols), ref2(function(x) x$cx$mean))
  expect_equal(row_values(cx, "% 4-5", cols), ref2(function(x) x$cx$r45))

  newq <- read_sheet(f, "NEWQ")
  vals <- row_values(newq, "Mean", cols)
  expect_true(is.na(vals[1]))
  expect_equal(vals[2], round(r$W2$newq, 2))
})


# ==============================================================================
# TESTS: every other workbook agrees with the detailed sheets and the hand tests
# ==============================================================================

test_that("wave history carries the same numbers as the detailed sheets", {
  runs <- pipeline_runs()
  fx <- runs$flat
  r <- references(fx)
  wh <- read_sheet(output_file(fx$dir, "WaveHistory"), "Total")
  pick <- function(code, type) {
    i <- which(wh[[1]] == code & wh[[3]] == type)[1]
    suppressWarnings(as.numeric(unlist(wh[i, 4:5])))
  }
  expect_equal(pick("SAT", "Mean"), round(c(r$W1$sat$mean, r$W2$sat$mean), 2))
  expect_equal(pick("SAT", "Top 2 Box"), round(c(r$W1$sat$top2, r$W2$sat$top2), 2))
  expect_equal(pick("REC", "NPS"), round(c(r$W1$rec$nps, r$W2$rec$nps), 2))
  expect_equal(pick("CHAN", "% Q30_1"), round(c(r$W1$chan$q1, r$W2$chan$q1), 2))
  expect_equal(pick("CX", "% 4-5"), round(c(r$W1$cx$r45, r$W2$cx$r45), 2))
})

dashboard_body <- function(file) {
  df <- read_sheet(file, "Trend_Dashboard")
  hdr <- which(df[[1]] == "Code")[1]
  body <- df[(hdr + 1):nrow(df), ]
  names(body) <- make.unique(as.character(unlist(df[hdr, ])))
  body[!is.na(body$Code) & nzchar(body$Code) & !grepl("^(Legend|Status)", body$Code), ]
}

test_that("Trend Dashboard values and arrows match the hand-computed tests", {
  runs <- pipeline_runs()
  fx <- runs$flat
  r <- references(fx)
  hv <- hand_verdicts(r)
  body <- dashboard_body(output_file(fx$dir, "Dashboard"))
  row <- function(q) body[body$Code == q, ]
  expect_equal(as.numeric(row("SAT")$W2), round(r$W2$sat$mean, 2))
  expect_equal(as.numeric(row("CHAN")$W2), round(r$W2$chan$q1, 2))
  for (q in c("SAT", "REC", "CHAN", "CX")) {
    expect_identical(row(q)$Sig, hv[[q]], info = q)       # vs previous
    expect_identical(row(q)$Sig.1, hv[[q]], info = q)     # vs base (W1)
  }
  # The fixture moves enough that some arrows are significant and some not
  expect_true(any(unlist(hv) != "→"))
  expect_true(any(unlist(hv) == "→"))
  expect_identical(row("NEWQ")$Status, "Not tested")
})

test_that("Sig Matrix cells match the Dashboard and the hand-computed tests", {
  runs <- pipeline_runs()
  fx <- runs$flat
  hv <- hand_verdicts(references(fx))
  f <- output_file(fx$dir, "SigMatrix")
  for (q in c("SAT", "REC", "CHAN", "CX")) {
    m <- read_sheet(f, paste0(q, "_SigMatrix"))
    r1 <- which(grepl("^W1 \\(", m[[1]]))[1]
    cell <- m[r1, 3]
    expect_identical(substring(cell, nchar(cell)), hv[[q]], info = q)
  }
})

# Row labels are matched case-insensitively: the crosstab writes option
# labels in lower case ("yes"), a display issue logged for Duncan
crosstab_row <- function(ct, question, label) {
  q <- which(ct[[1]] == question)[1]
  q + which(tolower(ct[[2]][(q + 1):nrow(ct)]) == tolower(label))[1]
}
crosstab_cell <- function(ct, question, label, col) ct[crosstab_row(ct, question, label), col]

test_that("tracking crosstab values and significance marks match the reference", {
  runs <- pipeline_runs()
  fx <- runs$flat
  r <- references(fx)
  hv <- hand_verdicts(r)
  ct <- read_sheet(output_file(fx$dir, "TrackingCrosstab"), "Tracking Crosstab")
  num <- function(x) suppressWarnings(as.numeric(x))
  expect_equal(num(crosstab_cell(ct, "Satisfaction", "Mean", 3)), r$W1$sat$mean, tolerance = 1e-9)
  expect_equal(num(crosstab_cell(ct, "Satisfaction", "Mean", 4)), r$W2$sat$mean, tolerance = 1e-9)
  expect_equal(num(crosstab_cell(ct, "Recommend", "NPS", 4)), r$W2$rec$nps, tolerance = 1e-9)
  expect_equal(num(crosstab_cell(ct, "CX index", "Mean", 4)), r$W2$cx$mean, tolerance = 1e-9)

  # vs Prev carries "*" exactly when the hand test is significant
  starred <- function(question, label) grepl("\\*", ct[crosstab_row(ct, question, label) + 1, 4])
  expect_identical(starred("Satisfaction", "Mean"), hv$SAT != "→")
  expect_identical(starred("Recommend", "NPS"), hv$REC != "→")
  expect_identical(starred("CX index", "Mean"), hv$CX != "→")
  expect_identical(starred("Aware of us", "Yes"), hv$AWARE_Yes != "→")
  expect_equal(num(crosstab_cell(ct, "Aware of us", "Yes", 4)), r$W2$aware$Yes, tolerance = 1e-9)
})


# ==============================================================================
# TESTS: banner run
# ==============================================================================

test_that("banner segments match the reference computed on each segment's rows", {
  runs <- pipeline_runs()
  fx <- runs$banner
  sub_ref <- function(region) {
    lapply(c(W1 = "W1", W2 = "W2"), function(wid) {
      df <- wave_csv(fx, wid)
      ref_wave(df[df$Region == region, ])
    })
  }
  f <- output_file(fx$dir, "Tracker")
  sat <- read_sheet(f, "SAT")
  hdr <- which(sat[[1]] == "Metric")[1]
  col_of <- function(name) which(unlist(sat[hdr, ]) == name)
  for (region in c("North", "South")) {
    r <- sub_ref(region)
    got <- row_values(sat, "Mean", c(col_of(paste0("W1_Region_", region)),
                                     col_of(paste0("W2_Region_", region))))
    expect_equal(got, round(c(r$W1$sat$mean, r$W2$sat$mean), 2), info = region)
  }
})

test_that("a segment under the minimum effective base is never marked significant", {
  runs <- pipeline_runs()
  fx <- runs$banner
  south <- lapply(c(W1 = "W1", W2 = "W2"), function(wid) {
    df <- wave_csv(fx, wid); ref_wave(df[df$Region == "South", ])
  })
  # The fixture's point: South's Kish base is under 30 in both waves
  expect_lt(south$W1$aware_eff, 30)
  expect_lt(south$W2$aware_eff, 30)
  ct <- read_sheet(output_file(fx$dir, "TrackingCrosstab"), "Tracking Crosstab")
  # The segment header is merged over its W1 and W2 columns
  south_cols <- which(unlist(ct[1, ]) == "Region_South")[1] + 0:1
  prev_rows <- which(ct[[2]] == "vs Prev")
  expect_false(any(grepl("\\*", unlist(ct[prev_rows, south_cols]))))
  # ...although on raw n = 40 South's "Yes" jump would be significant
  # (26% to 68%, p about 0.0002), so a gate on raw n would star it
  z_raw <- z_p(south$W1$aware$Yes / 100, 40, south$W2$aware$Yes / 100, 40)
  expect_lt(z_raw, 0.05)
  expect_match(ct[crosstab_row(ct, "Aware of us", "Yes") + 1, south_cols[2]], "^\\+")
})

test_that("with banners the Dashboard and Sig Matrix report the Total segment", {
  runs <- pipeline_runs()
  flat_body <- dashboard_body(output_file(runs$flat$dir, "Dashboard"))
  banner_body <- dashboard_body(output_file(runs$banner$dir, "Dashboard"))
  expect_setequal(banner_body$Code, c("SAT", "REC", "AWARE", "CHAN", "CX", "NEWQ"))
  expect_identical(banner_body$W2, flat_body$W2)
  expect_identical(banner_body$Sig, flat_body$Sig)
  sheets <- openxlsx::getSheetNames(output_file(runs$banner$dir, "SigMatrix"))
  expect_true(all(paste0(c("SAT", "REC", "AWARE", "CHAN", "CX", "NEWQ"), "_SigMatrix") %in% sheets))
})
