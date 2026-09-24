# ==============================================================================
# PIPELINE GATE - Confidence Module, config workbook to output files
# ==============================================================================
# Runs run_confidence_analysis() from a config workbook in a child Rscript and
# reads every number back FROM THE FILES: the results workbook, the stats pack
# and the HTML report. Each is compared with a reference written here (hand
# Kish arithmetic, qbeta, cov.wt), and the files are compared with each other.
# Robustness programme gates 2 (pipeline), 3 (adversarial) and 4
# (consistency), 24 Sep 2026.
#
# Before this file no test ran the module end to end. The probe that preceded
# it found the Excel proportions sheet had never shown the normal interval and
# the HTML report failed outright on any weighted mean.
# ==============================================================================

library(testthat)

skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not installed")

source(file.path(TURAS_ROOT, "modules", "confidence", "tests", "testthat",
                 "helper_pipeline_fixture.R"), local = TRUE)

pipeline_dir <- file.path(tempdir(), "confidence_pipeline_a")
unlink(pipeline_dir, recursive = TRUE)
fx <- build_confidence_pipeline_fixture(pipeline_dir)
child <- run_confidence_child(TURAS_ROOT, fx$config_path)

read_detail <- function(sheet) {
  openxlsx::read.xlsx(file.path(fx$dir, "out.xlsx"), sheet = sheet,
                      startRow = 3, skipEmptyRows = FALSE)
}
row_for <- function(df, id) df[df$Question_ID %in% id, , drop = FALSE]

# References use the 90 rows with a usable weight; rows 91 and 92 (weight 0
# and missing) are excluded by every analysis.
d <- fx$data[!is.na(fx$data$w) & fx$data$w > 0, ]
z <- qnorm(0.975)
kish <- function(w) sum(w)^2 / sum(w^2)

test_that("the run completes, writes all three files, and is PARTIAL", {
  if (child$status != 0) cat(tail(child$log, 40), sep = "\n")
  expect_equal(child$status, 0L)
  expect_true(file.exists(file.path(fx$dir, "out.xlsx")))
  expect_true(file.exists(file.path(fx$dir, "out.html")))
  expect_true(file.exists(file.path(fx$dir, "out_stats_pack.xlsx")))
  res <- readRDS(file.path(fx$dir, "child_result.rds"))
  expect_equal(res$html, "PASS")
  expect_equal(res$run, "PARTIAL")        # allna was skipped
})

test_that("Run_Status says PARTIAL and names the skipped question", {
  rs <- openxlsx::read.xlsx(file.path(fx$dir, "out.xlsx"), sheet = "Run_Status",
                            colNames = FALSE, skipEmptyRows = FALSE)
  cells <- unlist(rs, use.names = FALSE)
  status_row <- which(rs[[1]] == "Status")
  expect_equal(rs[[2]][status_row], "PARTIAL")
  expect_true(any(grepl("Question allna", cells, fixed = TRUE)))
})

test_that("Proportions_Detail matches Kish arithmetic, Wilson and the Beta posterior", {
  r <- row_for(read_detail("Proportions_Detail"), "aware")
  expect_equal(nrow(r), 1)
  p <- sum(d$w[d$aware == 1]) / sum(d$w)
  ne <- kish(d$w)
  se <- sqrt(p * (1 - p) / ne)
  expect_equal(r$Proportion, p, tolerance = 1e-9)
  expect_equal(r$Sample_Size, 90)
  expect_equal(r$Effective_n, round(ne))
  expect_equal(r$MOE, z * se, tolerance = 1e-9)
  expect_equal(r$MOE_Normal_Lower, p - z * se, tolerance = 1e-9)
  expect_equal(r$MOE_Normal_Upper, p + z * se, tolerance = 1e-9)
  centre <- (p + z^2 / (2 * ne)) / (1 + z^2 / ne)
  half <- z * sqrt(p * (1 - p) / ne + z^2 / (4 * ne^2)) / (1 + z^2 / ne)
  expect_equal(r$Wilson_Lower, centre - half, tolerance = 1e-9)
  expect_equal(r$Wilson_Upper, centre + half, tolerance = 1e-9)
  expect_equal(r$Bayesian_Lower, qbeta(0.025, 1 + p * ne, 1 + (1 - p) * ne), tolerance = 1e-9)
  expect_equal(r$Bayesian_Upper, qbeta(0.975, 1 + p * ne, 1 + (1 - p) * ne), tolerance = 1e-9)
  expect_true(r$Bootstrap_Lower < p && p < r$Bootstrap_Upper)
})

test_that("a filtered question is computed on its subset only", {
  r <- row_for(read_detail("Proportions_Detail"), "aware2")
  sub <- d[d$region == 1, ]
  p <- sum(sub$w[sub$aware2 == 1]) / sum(sub$w)
  expect_equal(r$Sample_Size, 45)
  expect_equal(r$Proportion, p, tolerance = 1e-9)
  expect_equal(r$Effective_n, round(kish(sub$w)))
  expect_equal(r$MOE, z * sqrt(p * (1 - p) / kish(sub$w)), tolerance = 1e-9)
})

test_that("Means_Detail matches weighted.mean, cov.wt and the Kish t interval", {
  r <- row_for(read_detail("Means_Detail"), "sat")
  ok <- !is.na(d$sat)
  x <- d$sat[ok]; w <- d$w[ok]
  m <- weighted.mean(x, w)
  s <- sqrt(cov.wt(matrix(x), wt = w / sum(w), method = "unbiased")$cov[1, 1])
  ne <- kish(w)
  se <- s / sqrt(ne)
  tc <- qt(0.975, ne - 1)
  expect_equal(r$Sample_Size, 88)
  expect_equal(r$Mean, m, tolerance = 1e-9)
  expect_equal(r$SD, s, tolerance = 1e-9)
  expect_equal(r$SE, se, tolerance = 1e-9)
  expect_equal(r$DF, ne - 1, tolerance = 1e-9)
  expect_equal(r$tDist_Lower, m - tc * se, tolerance = 1e-9)
  expect_equal(r$tDist_Upper, m + tc * se, tolerance = 1e-9)
  expect_equal(r$Bayesian_Lower, m - z * se, tolerance = 1e-9)   # flat prior
})

test_that("NPS_Detail matches the closed-form SE with the covariance", {
  r <- row_for(read_detail("NPS_Detail"), "nps")
  pp <- sum(d$w[d$nps >= 9]) / sum(d$w)
  pd <- sum(d$w[d$nps <= 6]) / sum(d$w)
  ne <- kish(d$w)
  se <- 100 * sqrt(((pp + pd) - (pp - pd)^2) / ne)
  expect_equal(r$NPS_Score, 100 * (pp - pd), tolerance = 1e-9)
  expect_equal(r$SE, se, tolerance = 1e-9)
  expect_equal(r$Normal_Lower, 100 * (pp - pd) - z * se, tolerance = 1e-9)
  # Posterior mean under the default N(0, 50^2) prior
  tau0 <- 1 / 50^2; taud <- 1 / se^2
  expect_equal(r$Bayesian_Mean, taud * 100 * (pp - pd) / (tau0 + taud), tolerance = 1e-9)
})

test_that("Study_Level is Kish by hand and agrees with every question on the full sample", {
  st <- openxlsx::read.xlsx(file.path(fx$dir, "out.xlsx"), sheet = "Study_Level",
                            startRow = 3, skipEmptyRows = FALSE)[1, ]
  ne <- kish(d$w)
  expect_equal(st$Actual_n, 90)
  expect_equal(st$Effective_n, round(ne))
  expect_equal(st$DEFF, round(90 / ne, 2))
  # Consistency: the questions with no missing data carry the study n_eff
  expect_equal(row_for(read_detail("Proportions_Detail"), "aware")$Effective_n, st$Effective_n)
  expect_equal(row_for(read_detail("NPS_Detail"), "nps")$Effective_n, st$Effective_n)
})

test_that("the stats pack agrees with Study_Level and names the methods that ran", {
  sp <- openxlsx::read.xlsx(file.path(fx$dir, "out_stats_pack.xlsx"), sheet = "Assumptions",
                            skipEmptyRows = FALSE)
  val <- function(k) sp$Value[sp$Parameter == k]
  st <- openxlsx::read.xlsx(file.path(fx$dir, "out.xlsx"), sheet = "Study_Level",
                            startRow = 3, skipEmptyRows = FALSE)[1, ]
  expect_equal(as.numeric(gsub(",", "", val("Effective N"))), st$Effective_n)
  expect_equal(as.numeric(val("Design Effect (DEFF)")), st$DEFF)
  expect_match(val("NPS method"), "covariance")
  expect_false(grepl("Wilson", val("NPS method")))
  expect_match(val("Means method"), "sqrt\\(n_eff\\)")
  expect_match(val("Proportions method"), "Wilson score on the Kish effective n \\(2 questions\\)")
})

test_that("Representativeness margins match a hand calculation", {
  rep <- openxlsx::read.xlsx(file.path(fx$dir, "out.xlsx"), sheet = "Representativeness_Weights",
                             colNames = FALSE, skipEmptyRows = FALSE)
  cells <- unlist(rep, use.names = FALSE)
  # Region 1 holds the odd rows, weights 0.5, 1.5, 3.7, 1, 2 repeating: 8.7 per
  # 10 rows, the same as region 2. So each is 50% weighted against targets of
  # 45% and 55%: North +5pp, South -5pp, both RED (|diff| >= 5).
  north <- 100 * sum(d$w[d$region == 1]) / sum(d$w)
  expect_equal(north, 50)
  expect_true("RED" %in% cells)
  expect_true(any(abs(suppressWarnings(as.numeric(cells)) - 5) < 1e-9, na.rm = TRUE))
  expect_true(any(abs(suppressWarnings(as.numeric(cells)) + 5) < 1e-9, na.rm = TRUE))
})

test_that("the HTML detail tables print the workbook's numbers", {
  html <- paste(readLines(file.path(fx$dir, "out.html"), warn = FALSE), collapse = "\n")
  pr <- row_for(read_detail("Proportions_Detail"), "aware")
  h <- html_detail_rows(html, "aware")
  expect_false(is.null(h))
  expect_equal(h$lower[h$method == "Normal Approximation"], round(pr$MOE_Normal_Lower * 100, 1))
  expect_equal(h$upper[h$method == "Wilson Score"], round(pr$Wilson_Upper * 100, 1))
  expect_equal(h$lower[h$method == "Bayesian Credible"], round(pr$Bayesian_Lower * 100, 1))
  expect_equal(h$upper[h$method == "Bootstrap"], round(pr$Bootstrap_Upper * 100, 1))

  mr <- row_for(read_detail("Means_Detail"), "sat")
  hm <- html_detail_rows(html, "sat")
  expect_equal(hm$lower[hm$method == "t-Distribution"], round(mr$tDist_Lower, 2))
  expect_equal(hm$upper[hm$method == "Bayesian Credible"], round(mr$Bayesian_Upper, 2))
  expect_true(grepl(sprintf("df = %s,", format(round(mr$DF, 1))), html, fixed = TRUE))

  nr <- row_for(read_detail("NPS_Detail"), "nps")
  hn <- html_detail_rows(html, "nps")
  expect_equal(hn$lower[hn$method == "Normal Approximation"], round(nr$Normal_Lower, 1))
  expect_equal(hn$upper[hn$method == "Bootstrap"], round(nr$Bootstrap_Upper, 1))
})

test_that("a formula-like, non-ASCII label reaches the HTML escaped", {
  html <- paste(readLines(file.path(fx$dir, "out.html"), warn = FALSE, encoding = "UTF-8"),
                collapse = "\n")
  expect_true(grepl("=SUM(A1) Café &amp; &lt;b&gt;aware&lt;/b&gt;", html, fixed = TRUE))
  expect_false(grepl("<b>aware</b>", html, fixed = TRUE))
})

test_that("the same random_seed gives the same bootstrap intervals on a second run", {
  dir_b <- file.path(tempdir(), "confidence_pipeline_b")
  unlink(dir_b, recursive = TRUE)
  fb <- build_confidence_pipeline_fixture(dir_b)
  cb <- run_confidence_child(TURAS_ROOT, fb$config_path)
  expect_equal(cb$status, 0L)
  a <- read_detail("Proportions_Detail")
  b <- openxlsx::read.xlsx(file.path(dir_b, "out.xlsx"), sheet = "Proportions_Detail",
                           startRow = 3, skipEmptyRows = FALSE)
  expect_identical(row_for(a, "aware")$Bootstrap_Lower, row_for(b, "aware")$Bootstrap_Lower)
  na <- read_detail("NPS_Detail")
  nb <- openxlsx::read.xlsx(file.path(dir_b, "out.xlsx"), sheet = "NPS_Detail",
                            startRow = 3, skipEmptyRows = FALSE)
  expect_identical(row_for(na, "nps")$Bootstrap_Upper, row_for(nb, "nps")$Bootstrap_Upper)
  unlink(dir_b, recursive = TRUE)
})

test_that("client-facing method text states the formulas the code uses", {
  # Documentation gate (review 2026-09-24). The HTML notes said proportions
  # used a Jeffreys Beta(0.5, 0.5) prior (the code uses Beta(1, 1)) and means
  # a Normal-Inverse-Gamma model (the code is normal-normal with z); both
  # the notes and the Methodology sheet said the Wald interval can go below
  # 0% (the code cuts it at 0% and 100%); the sheet's DEFF line and MOE
  # formula ignored n_eff, and it gave no NPS standard error.
  html <- paste(readLines(file.path(fx$dir, "out.html"), warn = FALSE), collapse = "\n")
  expect_false(grepl("Jeffreys", html, fixed = TRUE))
  expect_false(grepl("Normal-Inverse-Gamma", html, fixed = TRUE))
  expect_true(grepl("Beta(1,&nbsp;1)", html, fixed = TRUE))
  expect_false(grepl("extend below 0%", html, fixed = TRUE))

  meth <- openxlsx::read.xlsx(file.path(fx$dir, "out.xlsx"), sheet = "Methodology",
                              colNames = FALSE, skipEmptyRows = FALSE)[[1]]
  meth <- paste(meth[!is.na(meth)], collapse = "\n")
  expect_true(grepl("MOE = z * sqrt(p*(1-p)/n_eff)", meth, fixed = TRUE))
  expect_true(grepl("DEFF = n / n_eff = 1 + CV^2", meth, fixed = TRUE))
  expect_true(grepl("SE = 100 * sqrt((p_p + p_d - (p_p - p_d)^2) / n_eff)", meth, fixed = TRUE))
  expect_false(grepl("Can produce impossible results", meth, fixed = TRUE))
})

test_that("the stats pack counts the respondents analysed and excluded", {
  # 92 rows arrive; the zero and missing weights are excluded, as the loader
  # announces (CONF_WEIGHT_ZEROS, CONF_WEIGHT_NAS). The stats pack said
  # "92 (no respondents excluded)" beside a Study_Level Actual_n of 90
  # (review 2026-09-24).
  dec <- openxlsx::read.xlsx(file.path(fx$dir, "out_stats_pack.xlsx"), sheet = "Declaration",
                             colNames = FALSE, skipEmptyRows = FALSE)
  cells <- apply(dec, 1, function(r) paste(r[!is.na(r)], collapse = " | "))
  resp <- cells[grepl("^Respondents Analysed", cells)]
  expect_length(resp, 1)
  expect_match(resp, "Respondents Analysed | 90  (2 excluded", fixed = TRUE)
  st <- openxlsx::read.xlsx(file.path(fx$dir, "out.xlsx"), sheet = "Study_Level",
                            startRow = 3, skipEmptyRows = FALSE)[1, ]
  expect_equal(st$Actual_n, 90)
})

test_that("small-base notes reach the Warnings sheet without changing the run status", {
  # aware2 is region 1 only: 45 rows, n_eff = 45 x 8.7^2 / 5 / 21.19 = 32.1,
  # under 50, so a "Small base" note. Notes are not run events: Run_Status
  # carries only the real warnings.
  ws <- openxlsx::read.xlsx(file.path(fx$dir, "out.xlsx"), sheet = "Warnings",
                            colNames = FALSE, skipEmptyRows = FALSE)
  cells <- unlist(ws, use.names = FALSE)
  expect_true(any(grepl("^NOTES", cells)))
  expect_true(any(grepl("Question aware2: Small base (n=32.1)", cells, fixed = TRUE)))
  rs <- openxlsx::read.xlsx(file.path(fx$dir, "out.xlsx"), sheet = "Run_Status",
                            colNames = FALSE, skipEmptyRows = FALSE)
  expect_false(any(grepl("Small base", unlist(rs, use.names = FALSE), fixed = TRUE)))
})
