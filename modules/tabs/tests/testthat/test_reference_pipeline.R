# ==============================================================================
# TABS. REFERENCE AND PIPELINE GATES (robustness programme, session 2)
# ==============================================================================
#
# Every other tabs suite either calls a function and checks what it returned,
# or compares the R engine with the JS engine. Neither proves a published number
# is RIGHT. This file does, at the level Duncan and the client consume:
#
#   * PIPELINE. The parity project is generated into a temp folder and run
#     through run_tabs_analysis(), the entry launch_turas() uses, in a CHILD
#     Rscript. The numbers are then read back from the files that run wrote:
#     the Crosstabs sheet of the workbook and the data island of the v2 HTML
#     report. Nothing is taken from a function's return value.
#
#   * REFERENCE. Every published percentage, base and letter below is compared
#     with a calculation that does not share Turas code: survey::svymean for
#     weighted percentages and means, the Kish formula written out for the
#     effective base, the FPC multipliers the generator header derives by hand,
#     and stats::prop.test for the proportion letters.
#
#   * CONSISTENCY. The island is compared with the workbook cell by cell: every
#     percentage, frequency, base and letter the report shows must be the one
#     the workbook shows.
#
# Three runs. Weighted (FPC on), unweighted (FPC on), and unweighted with no
# Population sheet, the one whose letters are a plain prop.test.
#
# Decimal places are raised to 2 (percent) and 3 (ratings, numeric) for these runs so a
# reference comparison at display precision still means something.
# ==============================================================================

library(testthat)

.rp_root <- local({
  home <- Sys.getenv("TURAS_HOME", "")
  cands <- c(home, getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."),
             file.path(getwd(), "../../../.."))
  hit <- NULL
  for (cd in cands) {
    if (nzchar(cd) && dir.exists(file.path(cd, "modules", "tabs"))) {
      hit <- normalizePath(cd); break
    }
  }
  hit
})

skip_if(is.null(.rp_root), "Turas root not found (set TURAS_HOME)")
skip_if_not_installed("survey")
skip_if_not_installed("jsonlite")
skip_if_not_installed("openxlsx")

`%||%` <- function(a, b) if (is.null(a)) b else a

.rp_fixture <- file.path(.rp_root, "modules/tabs/tests/fixtures/parity_project")
.rp_env <- new.env(parent = emptyenv())

# ------------------------------------------------------------------------------
# Running the pipeline and reading its output back
# ------------------------------------------------------------------------------

.rp_overrides <- c("html_report_v2=TRUE", "decimal_places_percent=2",
                   "decimal_places_ratings=3", "decimal_places_index=3",
                   "decimal_places_numeric=3")

.rp_run <- function(config_name) {
  key <- config_name
  if (!is.null(.rp_env[[key]])) return(.rp_env[[key]])
  proj <- file.path(tempfile("tabs_pipeline_"), "proj")
  dir.create(proj, recursive = TRUE)
  log <- file.path(dirname(proj), "child.log")
  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(.rp_fixture, "run_pipeline_child.R")), shQuote(.rp_root),
      shQuote(proj), shQuote(config_name), .rp_overrides),
    stdout = log, stderr = log,
    env = paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep))
  )
  out_dir <- file.path(proj, "Output")
  xlsx <- list.files(out_dir, pattern = "^Parity_Crosstabs.*[.]xlsx$", full.names = TRUE)
  xlsx <- xlsx[!grepl("stats_pack", xlsx)]
  html <- list.files(out_dir, pattern = "_report[.]html$", full.names = TRUE)
  res <- list(status = status, log = log, proj = proj,
              xlsx = if (length(xlsx)) xlsx[1] else NA_character_,
              html = if (length(html)) html[1] else NA_character_)
  .rp_env[[key]] <- res
  res
}

# The Crosstabs sheet as blocks: code -> data frame(label, type, owner, v1..vk).
# Frequency and Column % rows share the label printed on the Frequency row; a
# Sig row belongs to the last row above it that is not a Standard Deviation
# row (the writer appends a mean's Sig row after its SD row).
.rp_read_workbook <- function(path) {
  x <- openxlsx::read.xlsx(path, sheet = "Crosstabs", colNames = FALSE,
                           skipEmptyRows = FALSE, skipEmptyCols = FALSE)
  ncols <- ncol(x) - 2
  blocks <- list()
  code <- NULL; label <- NULL; owner <- NULL
  for (i in seq_len(nrow(x))) {
    c1 <- x[i, 1]; c2 <- x[i, 2]
    c1 <- if (is.na(c1)) "" else trimws(as.character(c1))
    c2 <- if (is.na(c2)) "" else trimws(as.character(c2))
    if (!nzchar(c2)) {
      m <- regmatches(c1, regexec("^([A-Za-z0-9_]+) - ", c1))[[1]]
      if (length(m) == 2) { code <- m[2]; label <- NULL; owner <- NULL }
      next
    }
    if (is.null(code)) next
    vals <- vapply(seq_len(ncols), function(j) {
      v <- x[i, 2 + j]; if (is.na(v)) "" else trimws(as.character(v))
    }, character(1))
    if (grepl("^(Base|Effective base)", c2)) {
      row_label <- ""
    } else if (c2 %in% c("Sig.", "Sig.2")) {
      row_label <- owner
    } else {
      if (nzchar(c1)) label <- c1
      row_label <- label
      if (c2 != "StdDev") owner <- paste0(label, "\u001f", c2)
    }
    blocks[[code]] <- rbind(blocks[[code]], data.frame(
      label = if (c2 %in% c("Sig.", "Sig.2")) NA_character_ else row_label,
      type = c2, owner = if (c2 %in% c("Sig.", "Sig.2")) row_label else NA_character_,
      t(vals), stringsAsFactors = FALSE))
  }
  blocks
}

.rp_cells <- function(block, label, type) {
  hit <- block[!is.na(block$label) & block$label == label & block$type == type, , drop = FALSE]
  if (nrow(hit) != 1) return(NULL)
  unname(unlist(hit[1, grep("^X", names(hit))]))
}

.rp_sig <- function(block, label, type, sig_type = "Sig.") {
  own <- paste0(label, "\u001f", type)
  hit <- block[!is.na(block$owner) & block$owner == own & block$type == sig_type, , drop = FALSE]
  if (nrow(hit) != 1) return(NULL)
  unname(unlist(hit[1, grep("^X", names(hit))]))
}

.rp_read_island <- function(path) {
  html <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  m <- regmatches(html, regexec('<script[^>]*id="data-agg"[^>]*>(.*?)</script>', html))[[1]]
  if (length(m) != 2) return(NULL)
  jsonlite::fromJSON(m[2], simplifyVector = FALSE)
}

.rp_data <- function() {
  if (is.null(.rp_env$data)) {
    run <- .rp_run("Parity_Crosstab_Config_Weighted.xlsx")
    .rp_env$data <- openxlsx::read.xlsx(file.path(run$proj, "Parity_Survey_Data.xlsx"),
                                        skipEmptyRows = FALSE)
  }
  .rp_env$data
}

# ------------------------------------------------------------------------------
# References that share no Turas code
# ------------------------------------------------------------------------------

.rp_cols <- c("Total", "Alpha", "Beta", "Gamma", "Delta")

.rp_in_col <- function(d, col) if (col == "Total") rep(TRUE, nrow(d)) else d$Cohort == col

# Weighted percentage of `hit` among `rows`, from survey::svymean.
.rp_svy_pct <- function(d, rows, hit, weighted) {
  sub <- data.frame(y = as.numeric(hit[rows]),
                    w = if (weighted) d$Weight[rows] else rep(1, sum(rows)))
  des <- survey::svydesign(ids = ~1, weights = ~w, data = sub)
  100 * unname(coef(survey::svymean(~y, des)))
}

# Kish effective base, written out: (sum w)^2 / sum(w^2).
.rp_kish <- function(w) sum(w)^2 / sum(w^2)

# FPC multiplier as the generator header derives it by hand:
#   N unknown -> 1; n >= N -> Inf (census); n/N <= 0.05 -> 1; else (N-1)/(N-n).
.rp_fpc_mul <- function(n, N) {
  if (is.na(N) || N <= 1) return(1)
  if (n >= N) return(Inf)
  if (n / N <= 0.05) return(1)
  (N - 1) / (N - n)
}
.rp_population <- c(Total = 5000, Alpha = 40, Beta = 150, Gamma = 5000, Delta = NA)

# Two-proportion pooled z letters, Bonferroni over choose(4, 2), minimum base
# 30 on the corrected base, n*p >= 5 precondition. The published rule, written
# from its specification (weighting.R roxygen and the generator header), and
# validated against stats::prop.test below.
.rp_prop_letters <- function(x, b, n, alpha, min_base = 30) {
  k <- length(x) - 1
  a <- alpha / choose(k, 2)
  letters_out <- rep("", k + 1)
  for (i in 2:(k + 1)) for (j in 2:(k + 1)) {
    if (i == j) next
    if (!is.finite(n[i]) || !is.finite(n[j])) next
    if (n[i] < min_base || n[j] < min_base) next
    if (b[i] == 0 || b[j] == 0) next
    p1 <- x[i] / b[i]; p2 <- x[j] / b[j]
    pp <- (x[i] + x[j]) / (b[i] + b[j])
    if (pp == 0 || pp == 1) next
    if (min(n[i] * pp, n[i] * (1 - pp), n[j] * pp, n[j] * (1 - pp)) < 5) next
    z <- (p1 - p2) / sqrt(pp * (1 - pp) * (1 / n[i] + 1 / n[j]))
    if (2 * pnorm(-abs(z)) < a && p1 > p2) letters_out[i] <- paste0(letters_out[i], LETTERS[j - 1])
  }
  letters_out
}

# Per-column sufficient statistics for one indicator on a question's answered
# rows: weighted count, weighted base, and the base the test rides (Kish n_eff
# when weighted, raw n when not, times the FPC multiplier when a population is
# configured).
.rp_prop_inputs <- function(d, answered, hit, weighted, with_population) {
  out <- lapply(.rp_cols, function(col) {
    rows <- answered & .rp_in_col(d, col)
    w <- if (weighted) d$Weight[rows] else rep(1, sum(rows))
    n_raw <- sum(rows)
    n_test <- if (weighted) .rp_kish(w) else n_raw
    if (with_population) n_test <- n_test * .rp_fpc_mul(n_raw, .rp_population[[col]])
    c(x = sum(w[hit[rows]]), b = sum(w), n = n_test)
  })
  m <- do.call(rbind, out)
  list(x = m[, "x"], b = m[, "b"], n = m[, "n"])
}

# The questions whose rows are proportion rows, with each row's indicator.
.rp_prop_rows <- function(d) {
  q1_ok <- !is.na(d$Q1)
  q3_ok <- !is.na(d$Q3) & d$Q1 == "Yes"
  rows <- list(
    list(q = "Q1", label = "Yes", answered = q1_ok, hit = d$Q1 == "Yes"),
    list(q = "Q1", label = "No", answered = q1_ok, hit = d$Q1 == "No"),
    list(q = "Q3", label = "Agree", answered = q3_ok, hit = d$Q3 %in% "Agree"),
    list(q = "Q3", label = "Disagree", answered = q3_ok, hit = d$Q3 %in% "Disagree"),
    list(q = "Q2", label = "Top 2 Box", answered = !is.na(d$Q2), hit = d$Q2 %in% 4:5),
    list(q = "Q5", label = "Top 2 Box", answered = !is.na(d$Q5), hit = d$Q5 %in% 4:5),
    list(q = "Q5", label = "Bottom 2 Box", answered = !is.na(d$Q5), hit = d$Q5 %in% 1:2)
  )
  for (s in 1:5) {
    rows[[length(rows) + 1]] <- list(q = "Q2", label = as.character(s),
                                     answered = !is.na(d$Q2), hit = d$Q2 %in% s)
    rows[[length(rows) + 1]] <- list(q = "Q5", label = as.character(s),
                                     answered = !is.na(d$Q5), hit = d$Q5 %in% s)
  }
  for (s in c(10, 8, 5)) {
    rows[[length(rows) + 1]] <- list(q = "Q4", label = as.character(s),
                                     answered = !is.na(d$Q4), hit = d$Q4 %in% s)
  }
  rows
}

.rp_configs <- list(
  weighted   = list(file = "Parity_Crosstab_Config_Weighted.xlsx", weighted = TRUE,  pop = TRUE),
  unweighted = list(file = "Parity_Crosstab_Config.xlsx",          weighted = FALSE, pop = TRUE),
  nopop      = list(file = "Parity_Crosstab_Config_NoPop.xlsx",    weighted = FALSE, pop = FALSE)
)

.rp_blank <- function(v) ifelse(is.na(v) | v == "-", "", v)

# ==============================================================================
# PIPELINE: each config runs end to end and writes a workbook and a report
# ==============================================================================

for (nm in names(.rp_configs)) local({
  cfg <- .rp_configs[[nm]]
  test_that(sprintf("pipeline (%s): run_tabs_analysis writes the workbook and the v2 report", nm), {
    run <- .rp_run(cfg$file)
    expect_equal(run$status, 0L, info = paste(readLines(run$log, warn = FALSE), collapse = "\n"))
    expect_true(file.exists(run$xlsx))
    expect_true(file.exists(run$html))
    expect_false(is.null(.rp_read_island(run$html)))
  })
})

# ==============================================================================
# REFERENCE: bases
# ==============================================================================
#
# Weighted Alpha, hand check of the Kish formula: 40 respondents at 1.6, every
# third (13 of them) bumped to 2.8. Sum w = 27*1.6 + 13*2.8 = 79.6; sum w^2 =
# 27*2.56 + 13*7.84 = 171.04; n_eff = 79.6^2 / 171.04 = 37.0449.

test_that("reference: the Kish formula matches the hand value for weighted Alpha", {
  d <- .rp_data()
  w <- d$Weight[d$Cohort == "Alpha"]
  expect_equal(sum(w), 79.6, tolerance = 1e-12)
  expect_equal(.rp_kish(w), 79.6^2 / 171.04, tolerance = 1e-12)
})

for (nm in names(.rp_configs)) local({
  cfg <- .rp_configs[[nm]]
  test_that(sprintf("reference (%s): unweighted, weighted and effective bases", nm), {
    run <- .rp_run(cfg$file)
    d <- .rp_data()
    wb <- .rp_read_workbook(run$xlsx)
    isl <- .rp_read_island(run$html)
    for (q in c("Q1", "Q2", "Q3", "Q4", "Q5")) {
      answered <- if (q == "Q3") !is.na(d$Q3) & d$Q1 == "Yes" else !is.na(d[[q]])
      ref_n <- vapply(.rp_cols, function(col) sum(answered & .rp_in_col(d, col)), numeric(1))
      ref_w <- vapply(.rp_cols, function(col) sum(d$Weight[answered & .rp_in_col(d, col)]), numeric(1))
      ref_e <- vapply(.rp_cols, function(col) .rp_kish(d$Weight[answered & .rp_in_col(d, col)]), numeric(1))
      qi <- Filter(function(z) z$code == q, isl$questions)[[1]]
      expect_equal(vapply(qi$bases, function(b) b$n, numeric(1)), unname(ref_n), info = q)
      if (cfg$weighted) {
        expect_equal(as.numeric(.rp_cells(wb[[q]], "", "Base (unweighted)")), unname(ref_n), info = q)
        expect_equal(as.numeric(.rp_cells(wb[[q]], "", "Base (weighted)")), round(unname(ref_w)), info = q)
        expect_equal(as.numeric(.rp_cells(wb[[q]], "", "Effective base")), round(unname(ref_e)), info = q)
        expect_equal(vapply(qi$bases, function(b) b$nWeighted, numeric(1)), unname(ref_w),
                     tolerance = 1e-6, info = q)
        expect_equal(vapply(qi$bases, function(b) b$nEff, numeric(1)), unname(ref_e),
                     tolerance = 1e-6, info = q)
      } else {
        expect_equal(as.numeric(.rp_cells(wb[[q]], "", "Base (n=)")), unname(ref_n), info = q)
      }
    }
  })
})

# ==============================================================================
# REFERENCE: column percentages against survey::svymean
# ==============================================================================

for (nm in names(.rp_configs)) local({
  cfg <- .rp_configs[[nm]]
  test_that(sprintf("reference (%s): every proportion row matches survey::svymean", nm), {
    run <- .rp_run(cfg$file)
    d <- .rp_data()
    wb <- .rp_read_workbook(run$xlsx)
    for (r in .rp_prop_rows(d)) {
      ref <- vapply(.rp_cols, function(col) {
        .rp_svy_pct(d, r$answered & .rp_in_col(d, col), r$hit, cfg$weighted)
      }, numeric(1))
      got <- as.numeric(.rp_cells(wb[[r$q]], r$label, "Column %"))
      expect_equal(got, round(unname(ref), 2), tolerance = 1e-9,
                   info = sprintf("%s %s", r$q, r$label))
    }
  })
})

test_that("reference (weighted): Q2 mean, Q4 NPS and Q5 NET POSITIVE match survey::svymean", {
  run <- .rp_run(.rp_configs$weighted$file)
  d <- .rp_data()
  wb <- .rp_read_workbook(run$xlsx)
  svy <- function(rows, y) {
    des <- survey::svydesign(ids = ~1, weights = ~w,
                             data = data.frame(y = y[rows], w = d$Weight[rows]))
    unname(coef(survey::svymean(~y, des)))
  }
  q2 <- vapply(.rp_cols, function(col) svy(.rp_in_col(d, col) & !is.na(d$Q2), d$Q2), numeric(1))
  expect_equal(as.numeric(.rp_cells(wb$Q2, "Mean", "Average")), round(unname(q2), 3), tolerance = 1e-9)

  # NPS: +100 at 9-10, 0 at 7-8, -100 at 0-6, so its mean is %promoters - %detractors.
  bucket <- ifelse(d$Q4 >= 9, 100, ifelse(d$Q4 >= 7, 0, -100))
  q4 <- vapply(.rp_cols, function(col) svy(.rp_in_col(d, col), bucket), numeric(1))
  # The Score row prints at the percent precision (format_output_value "percent").
  expect_equal(as.numeric(.rp_cells(wb$Q4, "NPS Score", "Score")), round(unname(q4), 2),
               tolerance = 1e-9)

  # NET POSITIVE = top-box % minus bottom-box % = mean of (+100 top, -100 bottom, 0 else).
  np <- ifelse(d$Q5 %in% 4:5, 100, ifelse(d$Q5 %in% 1:2, -100, 0))
  q5 <- vapply(.rp_cols, function(col) svy(.rp_in_col(d, col), np), numeric(1))
  expect_equal(as.numeric(.rp_cells(wb$Q5, "NET POSITIVE (Top 2 Box - Bottom 2 Box)", "Column %")),
               round(unname(q5), 2), tolerance = 1e-9)

  # Q6 allocation means (printed at decimal_places_numeric).
  for (item in list(c("Q6_1", "Bank"), c("Q6_2", "Retailer"), c("Q6_3", "Other"))) {
    m <- vapply(.rp_cols, function(col) svy(.rp_in_col(d, col), d[[item[1]]]), numeric(1))
    expect_equal(as.numeric(.rp_cells(wb$Q6, item[2], "Average")), round(unname(m), 3),
                 tolerance = 1e-9, info = item[2])
  }
})

# Standard deviation rows against stats::cov.wt(method = "unbiased"), the
# reliability-weighted SD: population variance times n_eff / (n_eff - 1).
test_that("reference (weighted): Standard Deviation rows match stats::cov.wt unbiased", {
  run <- .rp_run(.rp_configs$weighted$file)
  d <- .rp_data()
  wb <- .rp_read_workbook(run$xlsx)
  sd_ref <- function(rows, y) {
    w <- d$Weight[rows]
    sqrt(stats::cov.wt(matrix(y[rows], ncol = 1), wt = w / sum(w), method = "unbiased")$cov[1, 1])
  }
  q2 <- vapply(.rp_cols, function(col) sd_ref(.rp_in_col(d, col), d$Q2), numeric(1))
  expect_equal(as.numeric(.rp_cells(wb$Q2, "Standard Deviation", "StdDev")),
               round(unname(q2), 3), tolerance = 1e-9)
  bucket <- ifelse(d$Q4 >= 9, 100, ifelse(d$Q4 >= 7, 0, -100))
  q4 <- vapply(.rp_cols, function(col) sd_ref(.rp_in_col(d, col), bucket), numeric(1))
  expect_equal(as.numeric(.rp_cells(wb$Q4, "Standard Deviation", "StdDev")),
               round(unname(q4), 3), tolerance = 1e-9)
})

# ==============================================================================
# REFERENCE: proportion letters
# ==============================================================================
#
# First the reference itself is checked against an outside implementation: with
# no weights and no FPC the pooled z is prop.test(correct = FALSE), whose X^2 is
# z^2. Hand anchor from the generator header: Q1 Beta 39/60 vs Gamma 20/50,
# p = 0.008842 without FPC.

test_that("reference: the pooled z letters rule agrees with stats::prop.test", {
  expect_equal(suppressWarnings(prop.test(c(39, 20), c(60, 50), correct = FALSE)$p.value),
               0.008842, tolerance = 1e-3)
  d <- .rp_data()
  for (r in .rp_prop_rows(d)) {
    inp <- .rp_prop_inputs(d, r$answered, r$hit, weighted = FALSE, with_population = FALSE)
    for (i in 2:5) for (j in 2:5) {
      if (i >= j) next
      pp <- (inp$x[i] + inp$x[j]) / (inp$b[i] + inp$b[j])
      if (pp %in% c(0, 1)) next
      z <- (inp$x[i] / inp$b[i] - inp$x[j] / inp$b[j]) /
        sqrt(pp * (1 - pp) * (1 / inp$n[i] + 1 / inp$n[j]))
      pt <- suppressWarnings(prop.test(c(inp$x[i], inp$x[j]), c(inp$b[i], inp$b[j]),
                                       correct = FALSE)$p.value)
      expect_equal(2 * pnorm(-abs(z)), pt, tolerance = 1e-10,
                   info = sprintf("%s %s %d-%d", r$q, r$label, i, j))
    }
  }
})

for (nm in names(.rp_configs)) local({
  cfg <- .rp_configs[[nm]]
  test_that(sprintf("reference (%s): proportion letters at both alphas", nm), {
    run <- .rp_run(cfg$file)
    d <- .rp_data()
    wb <- .rp_read_workbook(run$xlsx)
    for (r in .rp_prop_rows(d)) {
      inp <- .rp_prop_inputs(d, r$answered, r$hit, cfg$weighted, cfg$pop)
      for (lv in list(c("Sig.", 0.05), c("Sig.2", 0.20))) {
        ref <- .rp_prop_letters(inp$x, inp$b, inp$n, as.numeric(lv[2]))
        got <- .rp_blank(.rp_sig(wb[[r$q]], r$label, "Column %", lv[1]))
        expect_equal(got, ref, info = sprintf("%s %s %s", r$q, r$label, lv[1]))
      }
    }
  })
})

# Hand anchor, generator header: with FPC Beta's base becomes 60 * 149/90 =
# 99.33 and Q1 Beta vs Gamma crosses the 95% line (uppercase C on Beta).
test_that("reference (unweighted): the FPC puts C on Q1 Yes Beta at 95%", {
  run <- .rp_run(.rp_configs$unweighted$file)
  wb <- .rp_read_workbook(run$xlsx)
  expect_equal(.rp_fpc_mul(60, 150), 149 / 90)
  expect_equal(.rp_blank(.rp_sig(wb$Q1, "Yes", "Column %", "Sig."))[3], "C")
  run0 <- .rp_run(.rp_configs$nopop$file)
  wb0 <- .rp_read_workbook(run0$xlsx)
  expect_equal(.rp_blank(.rp_sig(wb0$Q1, "Yes", "Column %", "Sig."))[3], "")
  expect_equal(.rp_blank(.rp_sig(wb0$Q1, "Yes", "Column %", "Sig.2"))[3], "C")
})

# ==============================================================================
# REFERENCE: mean letters (Mean, NPS Score, NET POSITIVE, allocation items)
# ==============================================================================
#
# Welch's t: each column's variance is the unbiased reliability-weighted
# variance (stats::cov.wt, method "unbiased"), sized on the base the test
# rides (Kish n_eff, times the FPC multiplier when a population is set), with
# Welch-Satterthwaite df. Bonferroni over choose(4, 2); a column under 30 on
# its corrected base, or a census column, takes and gives no letters. With no
# weights and no population this is stats::t.test(var.equal = FALSE), which
# the nopop run is checked against directly.

.rp_mean_letters <- function(d, score, answered, cfg, alpha) {
  a <- alpha / choose(4, 2)
  st <- lapply(.rp_cols, function(col) {
    rows <- answered & .rp_in_col(d, col)
    w <- if (cfg$weighted) d$Weight[rows] else rep(1, sum(rows))
    y <- score[rows]
    n <- .rp_kish(w)
    if (cfg$pop) n <- n * .rp_fpc_mul(sum(rows), .rp_population[[col]])
    v <- stats::cov.wt(matrix(y, ncol = 1), wt = w / sum(w), method = "unbiased")$cov[1, 1]
    list(y = y, m = sum(w * y) / sum(w), v = v, n = n)
  })
  out <- rep("", 5)
  for (i in 2:5) for (j in 2:5) {
    if (i == j) next
    s1 <- st[[i]]; s2 <- st[[j]]
    if (!is.finite(s1$n) || !is.finite(s2$n) || s1$n < 30 || s2$n < 30) next
    if (!cfg$weighted && !cfg$pop) {
      p <- stats::t.test(s1$y, s2$y, var.equal = FALSE)$p.value
    } else {
      e1 <- s1$v / s1$n; e2 <- s2$v / s2$n
      t <- (s1$m - s2$m) / sqrt(e1 + e2)
      df <- (e1 + e2)^2 / (e1^2 / (s1$n - 1) + e2^2 / (s2$n - 1))
      p <- 2 * stats::pt(-abs(t), df)
    }
    if (p < a && s1$m > s2$m) out[i] <- paste0(out[i], LETTERS[j - 1])
  }
  out
}

.rp_mean_rows <- function(d) {
  all <- rep(TRUE, nrow(d))
  list(
    list(q = "Q2", label = "Mean", type = "Average", score = d$Q2, answered = !is.na(d$Q2)),
    list(q = "Q4", label = "NPS Score", type = "Score", answered = all,
         score = ifelse(d$Q4 >= 9, 100, ifelse(d$Q4 >= 7, 0, -100))),
    list(q = "Q5", label = "NET POSITIVE (Top 2 Box - Bottom 2 Box)", type = "Column %",
         answered = all, score = ifelse(d$Q5 %in% 4:5, 100, ifelse(d$Q5 %in% 1:2, -100, 0))),
    list(q = "Q6", label = "Bank", type = "Average", score = d$Q6_1, answered = all),
    list(q = "Q6", label = "Retailer", type = "Average", score = d$Q6_2, answered = all),
    list(q = "Q6", label = "Other", type = "Average", score = d$Q6_3, answered = all)
  )
}

for (nm in names(.rp_configs)) local({
  cfg <- .rp_configs[[nm]]
  test_that(sprintf("reference (%s): mean, NPS, NET POSITIVE and allocation letters are Welch t", nm), {
    run <- .rp_run(cfg$file)
    d <- .rp_data()
    wb <- .rp_read_workbook(run$xlsx)
    for (r in .rp_mean_rows(d)) {
      for (lv in list(c("Sig.", 0.05), c("Sig.2", 0.20))) {
        ref <- .rp_mean_letters(d, r$score, r$answered, cfg, as.numeric(lv[2]))
        got <- .rp_blank(.rp_sig(wb[[r$q]], r$label, r$type, lv[1]))
        expect_equal(got, ref, info = sprintf("%s %s %s", r$q, r$label, lv[1]))
      }
    }
  })
})

# ==============================================================================
# CONSISTENCY: the v2 island against the workbook, cell by cell
# ==============================================================================

for (nm in names(.rp_configs)) local({
  cfg <- .rp_configs[[nm]]
  test_that(sprintf("consistency (%s): every island cell equals its workbook cell", nm), {
    run <- .rp_run(cfg$file)
    wb <- .rp_read_workbook(run$xlsx)
    isl <- .rp_read_island(run$html)
    expect_equal(vapply(isl$columns, function(cc) cc$label, character(1)), .rp_cols)
    n_checked <- 0L
    n_rows <- sum(vapply(isl$questions, function(q) length(q$rows), integer(1)))
    for (q in isl$questions) {
      block <- wb[[q$code]]
      expect_false(is.null(block), info = q$code)
      if (is.null(block)) next
      for (r in q$rows) {
        type <- if (identical(r$kind, "mean")) {
          hit <- block[!is.na(block$label) & block$label == r$label, , drop = FALSE]
          hit$type[1]
        } else "Column %"
        cells <- .rp_cells(block, r$label, type)
        expect_false(is.null(cells), info = paste(q$code, r$label))
        if (is.null(cells)) next
        isl_pct <- vapply(r$pct, function(v) if (is.null(v)) NA_real_ else as.numeric(v), numeric(1))
        expect_equal(suppressWarnings(as.numeric(cells)), isl_pct, tolerance = 1e-9,
                     info = paste(q$code, r$label, "pct"))
        if (!identical(r$kind, "mean") && !all(vapply(r$n, is.null, logical(1)))) {
          freq <- .rp_cells(block, r$label, "Frequency")
          isl_n <- vapply(r$n, function(v) if (is.null(v)) NA_real_ else as.numeric(v), numeric(1))
          expect_equal(suppressWarnings(as.numeric(freq)), isl_n, tolerance = 1e-9,
                       info = paste(q$code, r$label, "n"))
        }
        for (lv in list(c("sig", "Sig."), c("sig2", "Sig.2"))) {
          isl_sig <- vapply(r[[lv[1]]] %||% list(), function(v) if (is.null(v)) "" else v, character(1))
          wb_sig <- .rp_sig(block, r$label, type, lv[2])
          if (is.null(wb_sig)) wb_sig <- rep("", length(isl_sig))
          if (length(isl_sig) == 0) isl_sig <- rep("", length(wb_sig))
          expect_equal(.rp_blank(wb_sig), isl_sig, info = paste(q$code, r$label, lv[1]))
        }
        n_checked <- n_checked + 1L
      }
    }
    # Every island row found its workbook row; a silent zero would pass otherwise.
    expect_equal(n_checked, n_rows)
    expect_gt(n_rows, 30L)
  })
})
