# ==============================================================================
# CONJOINT - PIPELINE GATE: CONFIG WORKBOOK TO OUTPUT FILES
# ==============================================================================
# run_conjoint_analysis() runs in a child Rscript on a config workbook
# (helper_pipeline_fixture.R). Every number is read back from the files the
# run wrote and checked against a reference computed here from the data:
#
#   part-worths, SEs, CIs   hand MNL (helper_reference_mnl.R), centred by hand
#   importance              range / sum of ranges of the hand part-worths
#   McFadden R2, hit rate   hand log-likelihoods and hand argmax predictions
#   WTP                     delta method on the hand covariance
#   HB tabs export          per-respondent range / sum of ranges of the
#                           Individual Utilities sheet
#
# and the consistency gate: island against workbook, simulator data against
# workbook, Excel simulator data against the part-worth sheet.
# ==============================================================================

source(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "testthat",
                 "helper_pipeline_fixture.R"), local = TRUE)
source(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "testthat",
                 "helper_reference_mnl.R"), local = TRUE)

skip_if_not(requireNamespace("mlogit", quietly = TRUE), "mlogit not installed")

SIM <- generate_synthetic_cbc(n_respondents = 300, n_tasks = 8, n_alts = 3, seed = 3)
PM <- cj_pipe_run(SIM$data, SIM$attributes, settings = list(generate_tabs_export = "N"))
REF <- cj_ref_mnl(SIM$data, SIM$attributes, "task_id")

.pw <- function(p) {
  x <- cj_pipe_sheet(p$workbook, "Part-Worth Utilities")
  x[!is.na(x$Attribute), ]
}

test_that("the mlogit run completes PASS and writes its deliverables", {
  expect_equal(PM$result$status, "PASS", info = paste(tail(PM$log, 25), collapse = "\n"))
  for (f in c(PM$workbook, PM$island, PM$simulator, PM$stats_pack)) expect_true(file.exists(f), info = f)
})

test_that("Part-Worth Utilities equal the hand MNL, centred, with their own SE and CI", {
  pw <- .pw(PM)
  z <- qnorm(0.975)
  for (a in names(SIM$attributes)) {
    lv <- SIM$attributes[[a]]
    r <- cj_ref_centred(REF$coef, REF$vcov, a, lv)
    rows <- pw[pw$Attribute == a, ][match(lv, pw$Level[pw$Attribute == a]), ]
    expect_equal(rows$Utility, unname(r$utility), tolerance = 1e-4, info = a)
    expect_equal(rows$Std_Error, unname(r$se), tolerance = 1e-4, info = a)
    expect_equal(rows$CI_Lower, unname(r$utility - z * r$se), tolerance = 1e-4, info = a)
    expect_equal(rows$SE_vs_Baseline[-1], unname(REF$se[paste0(a, lv[-1])]), tolerance = 1e-4, info = a)
  }
})

test_that("Attribute Importance is range over sum of ranges of the hand part-worths", {
  imp <- cj_pipe_sheet(PM$workbook, "Attribute Importance")
  imp <- imp[!is.na(imp$Attribute), ]
  ranges <- vapply(names(SIM$attributes), function(a) {
    u <- cj_ref_centred(REF$coef, REF$vcov, a, SIM$attributes[[a]])$utility
    max(u) - min(u)
  }, numeric(1))
  hand <- 100 * ranges / sum(ranges)
  expect_equal(as.numeric(imp$Importance), unname(hand[imp$Attribute]), tolerance = 1e-4)
})

test_that("Model Fit: McFadden R-squared and hit rate equal hand values", {
  mf <- openxlsx::read.xlsx(PM$workbook, "Model Fit", colNames = FALSE, skipEmptyRows = FALSE)
  val <- function(m) mf[[2]][which(mf[[1]] == m)[1]]
  expect_equal(as.numeric(val("McFadden R²")), 1 - REF$loglik / REF$loglik_null, tolerance = 1e-4)
  X <- cj_ref_design(SIM$data, SIM$attributes)
  v <- drop(X %*% REF$coef)
  hit <- mean(vapply(split(seq_len(nrow(SIM$data)), SIM$data$task_id),
                     function(ix) SIM$data$chosen[ix][which.max(v[ix])] == 1, logical(1)))
  expect_equal(as.numeric(sub("%", "", val("Hit Rate"))), round(100 * hit, 1), tolerance = 1e-9)
})

test_that("island part-worths, importance and WTP equal the workbook and the hand delta method", {
  j <- jsonlite::fromJSON(PM$island)
  pw <- .pw(PM)
  for (k in seq_len(nrow(j$utilities))) {
    a <- j$utilities$attribute[k]
    rows <- pw[pw$Attribute == a, ][match(j$utilities$levels[[k]], pw$Level[pw$Attribute == a]), ]
    expect_equal(as.numeric(j$utilities$utility[[k]]), rows$Utility, tolerance = 1e-6, info = a)
    expect_equal(as.numeric(j$utilities$se[[k]]), rows$Std_Error, tolerance = 1e-6, info = a)
  }
  imp <- cj_pipe_sheet(PM$workbook, "Attribute Importance")
  expect_equal(as.numeric(j$importance$importance[match(imp$Attribute[!is.na(imp$Attribute)],
                                                        j$importance$attribute)]),
               as.numeric(imp$Importance[!is.na(imp$Attribute)]), tolerance = 1e-6)
  # WTP of Brand Beta against the hand delta method (price $10 / $20 / $30).
  x <- c(10, 20, 30); cc <- (x - mean(x)) / sum((x - mean(x))^2)
  pn <- c("Price$20", "Price$30")
  slope <- sum(cc[-1] * REF$coef[pn])
  b <- unname(REF$coef["BrandBeta"]); V <- REF$vcov
  se <- sqrt(V["BrandBeta", "BrandBeta"] / slope^2 +
             b^2 * drop(t(cc[-1]) %*% V[pn, pn] %*% cc[-1]) / slope^4 -
             2 * b * drop(V["BrandBeta", pn] %*% cc[-1]) / slope^3)
  k <- which(j$wtp$attribute == "Brand" & j$wtp$level == "Beta")
  expect_equal(j$wtp$wtp[k], -b / slope, tolerance = 1e-3)
  expect_equal(j$wtp$ciUpper[k] - j$wtp$wtp[k], qnorm(0.975) * unname(se), tolerance = 1e-3)
})

test_that("the simulator and the Excel simulator carry the workbook's part-worths", {
  pw <- .pw(PM)
  key <- paste(pw$Attribute, pw$Level, sep = "|")
  sd <- cj_pipe_sheet(PM$workbook, "Simulator Data")
  expect_equal(as.numeric(sd$Utility[match(key, sd$Key)]), pw$Utility, tolerance = 1e-9)
  h <- paste(readLines(PM$simulator, warn = FALSE), collapse = "\n")
  m <- regmatches(h, regexpr('(?s)<script type="application/json" id="cj-simulator-data">.*?</script>', h, perl = TRUE))
  d <- jsonlite::fromJSON(sub("(?s)^<script[^>]*>", "", sub("</script>$", "", m), perl = TRUE),
                          simplifyVector = FALSE)
  for (at in d$attributes) for (lv in at$levels) {
    k <- which(pw$Attribute == at$name & pw$Level == lv$name)
    expect_equal(lv$utility, pw$Utility[k], tolerance = 1e-4, info = paste(at$name, lv$name))
  }
})

# ------------------------------------------------------------------------------
# HB run with the tabs export on
# ------------------------------------------------------------------------------

PH <- cj_pipe_run(SIM$data, SIM$attributes,
                  settings = list(estimation_method = "hb", hb_iterations = "4000", hb_burnin = "2000"))

test_that("HB run: the tabs export is each respondent's importance from Individual Utilities", {
  skip_if_not(requireNamespace("bayesm", quietly = TRUE), "bayesm not installed")
  expect_equal(PH$result$status, "PASS", info = paste(tail(PH$log, 25), collapse = "\n"))
  # Two title rows and a blank row, then "Respondent", "Brand: Beta", ...
  # holding each respondent's contrasts with the baseline (baseline = 0).
  iu <- openxlsx::read.xlsx(PH$workbook, sheet = "Individual Utilities", startRow = 4,
                            check.names = FALSE, sep.names = " ", skipEmptyRows = FALSE)
  iu <- iu[!is.na(iu$Respondent), ]
  te <- openxlsx::read.xlsx(PH$tabs_export, sheet = "DATA", skipEmptyRows = FALSE)
  attrs <- names(SIM$attributes)
  hand <- t(vapply(seq_len(nrow(iu)), function(i) {
    r <- vapply(attrs, function(a) {
      cols <- paste0(a, ": ", SIM$attributes[[a]][-1])
      u <- c(0, as.numeric(iu[i, cols]))
      max(u) - min(u)
    }, numeric(1))
    100 * r / sum(r)
  }, numeric(length(attrs))))
  colnames(hand) <- attrs
  expect_equal(nrow(te), nrow(iu))
  expect_equal(as.character(te$resp_id), as.character(iu$Respondent))
  # CJIMP_k is the k-th OptionText in the export's Options rows.
  qm <- openxlsx::read.xlsx(PH$tabs_export, sheet = "QUESTIONMAP_SNIPPET", colNames = FALSE,
                            skipEmptyRows = FALSE)
  opt_rows <- which(qm[[1]] == "CJIMP" & grepl("^[0-9]+$", qm[[2]]))
  opt_attr <- setNames(qm[[3]][opt_rows], paste0("CJIMP_", qm[[2]][opt_rows]))
  expect_setequal(unname(opt_attr), attrs)
  for (cc in names(opt_attr)) {
    expect_equal(as.numeric(te[[cc]]), unname(hand[, opt_attr[[cc]]]), tolerance = 1e-6, info = cc)
  }
  imp <- cj_pipe_sheet(PH$workbook, "Attribute Importance")
  imp <- imp[!is.na(imp$Attribute), ]
  expect_equal(as.numeric(imp$Importance), unname(colMeans(hand)[imp$Attribute]), tolerance = 1e-6)
})

# ------------------------------------------------------------------------------
# The shipped example, unchanged
# ------------------------------------------------------------------------------

test_that("the shipped example finishes PARTIAL on its two data warnings, not on convergence", {
  ex <- file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "examples")
  d <- tempfile("cj_example_"); dir.create(file.path(d, "output"), recursive = TRUE)
  file.copy(file.path(ex, c("example_config.xlsx", "sample_cbc_data.csv")), d)
  script <- file.path(d, "run.R")
  writeLines(c(sprintf("setwd(%s)", deparse(Sys.getenv("TURAS_ROOT"))),
               "suppressMessages(source('modules/conjoint/R/00_main.R'))",
               sprintf("res <- run_conjoint_analysis(%s, output_file = %s)",
                       deparse(file.path(d, "example_config.xlsx")),
                       deparse(file.path(d, "output", "example_results.xlsx"))),
               sprintf("saveRDS(res$run_result, %s)", deparse(file.path(d, "rr.rds")))), script)
  log <- system2(file.path(R.home("bin"), "Rscript"), script, stdout = TRUE, stderr = TRUE,
                 env = c(paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep)),
                         "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE"))
  rr <- readRDS(file.path(d, "rr.rds"))
  expect_equal(rr$status, "PARTIAL")
  problems <- vapply(rr$events, function(e) e$problem %||% "", "")
  expect_length(problems, 2)
  expect_true(any(grepl("never chosen", problems)))
  expect_true(any(grepl("Sample size (50 respondents)", problems, fixed = TRUE)))
  expect_false(any(grepl("onverge", problems)))
})

test_that("the island's WTP note describes the interval the code computes", {
  # Since the delta method uses the model's covariance, the interval IS a
  # sampling interval; the note used to say it was not.
  note <- jsonlite::fromJSON(PM$island)$wtp$intervalNote
  expect_false(grepl("not a sampling interval", note, fixed = TRUE))
  expect_match(note, "covariance", fixed = TRUE)
  expect_match(note, "linear", fixed = TRUE)
})

test_that("the rendered v2 Conjoint tab shows the workbook's part-worths, SEs and CIs", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")
  renderer <- file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "js",
                        "render_conjoint_island.mjs")
  html <- paste(system2(node, c(shQuote(renderer), shQuote(PM$island)), stdout = TRUE), collapse = "\n")
  pw <- .pw(PM)
  blocks <- regmatches(html, gregexpr('<div class="cj-attr"><h4>.*?</table></div>', html, perl = TRUE))[[1]]
  expect_equal(length(blocks), length(SIM$attributes))
  cell <- function(r) regmatches(r, gregexpr("(?<=<td class=\"cj-num\">)[^<]*", r, perl = TRUE))[[1]]
  for (b in blocks) {
    a <- sub('^<div class="cj-attr"><h4>([^<]*)</h4>.*$', "\\1", b)
    rows <- regmatches(b, gregexpr("<tr><td>.*?</tr>", b, perl = TRUE))[[1]]
    for (r in rows) {
      lv <- trimws(sub("^<tr><td>([^<]*).*$", "\\1", r))
      k <- which(pw$Attribute == a & pw$Level == lv)
      expect_length(k, 1)
      v <- cell(r)  # Utility, Std. error, CI "lo to hi"
      expect_equal(as.numeric(v[1]), round(pw$Utility[k], 2), tolerance = 0.0051, info = paste(a, lv))
      # Every centred level, the baseline included, has an SE and an interval
      # (Duncan's ruling of 25 Sep 2026); the tab must show them.
      expect_equal(suppressWarnings(as.numeric(v[2])), round(pw$Std_Error[k], 2), tolerance = 0.0051,
                   info = paste(a, lv, "SE"))
      ci <- suppressWarnings(as.numeric(strsplit(v[3], " to ", fixed = TRUE)[[1]]))
      expect_equal(ci, round(c(pw$CI_Lower[k], pw$CI_Upper[k]), 2), tolerance = 0.0051,
                   info = paste(a, lv, "CI"))
    }
  }
})
