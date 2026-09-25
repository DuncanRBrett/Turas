# ==============================================================================
# WEIGHTING - ADVERSARIAL GATE (robustness programme, 25 Sep 2026)
# ==============================================================================
# The reference checks again, on the hard cases, end to end: each config runs
# through run_weighting.R in a fresh Rscript and the numbers are read back from
# the files. Hand references are written out beside each case.
#
#   DEFF exactly 2, at sample scale and grossed
#   missing strata left unweighted (allow_unmatched), with labels that start
#     with - + = @ and non-ASCII text
#   a failed weight inside a multi-weight run
#   a base under 30
# ==============================================================================

source(file.path(MODULE_DIR, "tests", "testthat", "helper_reference_fixture.R"),
       local = FALSE)

skip_if_not_installed("survey")
skip_if_not_installed("openxlsx")

adv_run <- function(tag, ...) {
  dir <- file.path(tempdir(), paste0("wadv_", tag))
  unlink(dir, recursive = TRUE)
  paths <- ref_build_config(dir, ...)
  run <- ref_run_child(paths$config, TURAS_ROOT)
  c(paths, list(status = run$status, console = paste(run$console, collapse = "\n")))
}

adv_lookup <- function(run) {
  openxlsx::read.xlsx(run$lookup, sheet = "Weights", skipEmptyRows = FALSE)
}


# ==============================================================================
# DEFF exactly 2
# ==============================================================================

test_that("a design weight with DEFF exactly 2 reports it everywhere, grossed or not", {
  # 160 respondents in A and 40 in B, populations 80,000 and 120,000.
  # Raw N/n: A 500, B 3000. Normalised by 200/200,000: A 0.5, B 3.
  # sum w = 80 + 120 = 200; sum w^2 = 160 x 0.25 + 40 x 9 = 400;
  # n_eff = 200^2 / 400 = 100; DEFF = 200 / 100 = 2; efficiency 50%.
  data <- data.frame(id = 1:200, Stratum = rep(c("A", "B"), c(160, 40)),
                     stringsAsFactors = FALSE)
  pops <- data.frame(stratum_variable = "Stratum", stratum_category = c("A", "B"),
                     population_size = c(80000, 120000), stringsAsFactors = FALSE)
  run <- adv_run("deff2", data = data,
                 specs = rbind(ref_spec("w2", "design"), ref_spec("wg", "design")),
                 design_targets = rbind(cbind(weight_name = "w2", pops),
                                        cbind(weight_name = "wg", pops)),
                 advanced = data.frame(weight_name = "wg", grossing = "Y"))
  expect_equal(run$status, 0L, info = run$console)

  lk <- adv_lookup(run)
  expect_equal(lk$w2, rep(c(0.5, 3), c(160, 40)), tolerance = 1e-12)
  expect_equal(lk$wg, rep(c(500, 3000), c(160, 40)), tolerance = 1e-9)

  for (w in c("w2", "wg")) {
    s <- ref_read_sheet(run$diagnostics, w)
    expect_equal(ref_kv(s, "Effective N"), "100", info = w)
    expect_equal(ref_kv(s, "Design Effect (DEFF)"), "2", info = w)
    expect_equal(ref_kv(s, "Weighting Efficiency"), "50%", info = w)
  }
  a <- ref_read_sheet(run$stats_pack, "Assumptions")
  per_weight <- ref_kv(a, "Per-weight diagnostics")
  expect_true(grepl("w2: eff_n=100, DEFF=2.000", per_weight, fixed = TRUE))
  expect_true(grepl("wg: eff_n=100, DEFF=2.000", per_weight, fixed = TRUE))
})


# ==============================================================================
# Missing strata, awkward labels, non-ASCII
# ==============================================================================

test_that("unweighted respondents and - = + @ and non-ASCII labels survive the whole run", {
  # The reference survey relabelled: North -> "Nörth", South -> "=South",
  # East -> "-1"; Male -> "Mâle", Female -> "+F". Region is blanked for the
  # first five respondents (all North Male) and allow_unmatched = Y.
  #
  # Design, normalised to the 195 who carry a weight:
  #   Nörth  30000/95 x 195/100000 = 58.5/95 = 0.615789...
  #   =South 40000/60 x 195/100000 = 78/60   = 1.3
  #   -1     30000/40 x 195/100000 = 58.5/40 = 1.4625
  #   sum 58.5 + 78 + 58.5 = 195
  # Rim and cell on Gender alone, 48/52 against 120/80:
  #   Mâle 0.48 x 200/120 = 0.8, +F 0.52 x 200/80 = 1.3
  data <- ref_survey()
  data$Region <- unname(c(North = "Nörth", South = "=South", East = "-1")[data$Region])
  data$Gender <- unname(c(Male = "Mâle", Female = "+F")[data$Gender])
  data$Region[1:5] <- NA

  run <- adv_run(
    "labels", data = data,
    specs = rbind(ref_spec("dw", "design"), ref_spec("rw", "rim"), ref_spec("cw", "cell")),
    design_targets = ref_design_targets("dw", c(`Nörth` = 30000, `=South` = 40000, `-1` = 30000)),
    rim_targets = ref_rim_target_rows("rw", list(Gender = c(`Mâle` = 0.48, `+F` = 0.52))),
    cell_targets = data.frame(weight_name = "cw", Gender = c("Mâle", "+F"),
                              target_percent = c(48, 52), stringsAsFactors = FALSE),
    advanced = data.frame(weight_name = "dw", allow_unmatched = "Y")
  )
  expect_equal(run$status, 0L, info = run$console)

  lk <- adv_lookup(run)
  expected_dw <- unname(c(`Nörth` = 58.5 / 95, `=South` = 1.3, `-1` = 1.4625)[data$Region])
  expect_true(all(is.na(lk$dw[1:5])))
  expect_equal(lk$dw[-(1:5)], expected_dw[-(1:5)], tolerance = 1e-12)
  expect_equal(sum(lk$dw, na.rm = TRUE), 195, tolerance = 1e-9)
  expected_g <- unname(c(`Mâle` = 0.8, `+F` = 1.3)[data$Gender])
  expect_equal(lk$rw, expected_g, tolerance = 1e-6)
  expect_equal(lk$cw, expected_g, tolerance = 1e-12)

  # Diagnostics: counts, Kish over the 195, labels written as typed.
  s <- ref_read_sheet(run$diagnostics, "dw")
  expect_equal(ref_kv(s, "NA weights"), "5")
  expect_equal(ref_kv(s, "Valid weights"), "195")
  expect_equal(as.numeric(ref_kv(s, "Effective N")), round(ref_kish(expected_dw)))
  # DEFF is n / n_eff over the 195 who carry a weight, not the 200 in the file.
  expect_equal(as.numeric(ref_kv(s, "Design Effect (DEFF)")),
               round(195 / ref_kish(expected_dw), 2))
  hdr <- which(s[[1]] == "stratum")[1]
  expect_equal(s[[1]][(hdr + 1):(hdr + 3)], c("Nörth", "=South", "-1"))
  expect_equal(as.numeric(s[[3]][(hdr + 1):(hdr + 3)]), c(95, 60, 40))

  rs <- ref_read_sheet(run$diagnostics, "rw")
  hdr <- which(rs[[1]] == "variable")[1]
  expect_equal(rs[[2]][(hdr + 1):(hdr + 2)], c("Mâle", "+F"))

  # The stats pack counts the five respondents the design weight leaves out.
  d <- ref_read_sheet(run$stats_pack, "Declaration")
  expect_match(ref_kv(d, "Respondents Analysed"), "^200  \\(5 excluded", perl = TRUE)

  # The HTML report carries the labels, escaped where they must be.
  html <- paste(readLines(run$html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  for (lbl in c("Nörth", "=South", "-1", "Mâle", "+F")) {
    expect_true(grepl(sprintf("<td>%s</td>", lbl), html, fixed = TRUE), info = lbl)
  }
})


# ==============================================================================
# A failed weight inside a multi-weight run
# ==============================================================================

test_that("a failed weight is PARTIAL, absent from the lookup, and named in the stats pack", {
  # 'bad' rakes on a variable the data does not have, so it refuses; 'dw'
  # still has to come out exactly as in the reference.
  run <- adv_run(
    "failed",
    specs = rbind(ref_spec("dw", "design"), ref_spec("bad", "rim")),
    design_targets = ref_design_targets("dw"),
    rim_targets = data.frame(weight_name = "bad", variable = "Income",
                             category = c("Low", "High"), target_percent = c(50, 50),
                             stringsAsFactors = FALSE)
  )
  expect_true(grepl("COMPLETED WITH", run$console, fixed = TRUE), info = run$console)

  lk <- adv_lookup(run)
  expect_equal(names(lk), c("id", "dw"))
  expect_equal(lk$dw, ref_design_weight(ref_survey()$Region), tolerance = 1e-12)

  a <- ref_read_sheet(run$stats_pack, "Assumptions")
  expect_true(grepl("bad (failed, not written)", ref_kv(a, "Weights Calculated"), fixed = TRUE))
  expect_equal(ref_kv(a, "TRS Status"), "PARTIAL")
  # The headline still describes the weight that was written.
  expect_equal(ref_kv(a, "Effective N after weighting"), "172")
})


# ==============================================================================
# A cap below the mean weight (grossed design weight)
# ==============================================================================

test_that("a cap below the mean weight is refused, not applied as a flattening", {
  # Grossed design weights are 300, 666.67 and 750, mean 500. A cap of 5 is
  # below every weight, so capping sets all 200 to 5 and the rescale to the
  # original 100,000 sets all 200 to 500: the design weighting is erased and
  # every weighted figure reverts to unweighted. After the rescale the mean is
  # unchanged, so no cap below the mean can hold; this must be refused.
  run <- adv_run(
    "grossed_cap",
    specs = ref_spec("dwg", "design", trim_method = "cap", trim_value = 5),
    design_targets = ref_design_targets("dwg"),
    advanced = data.frame(weight_name = "dwg", grossing = "Y")
  )
  expect_true(grepl("CFG_TRIM_CAP_BELOW_MEAN", run$console, fixed = TRUE), info = run$console)
  expect_false(file.exists(run$lookup))
})

test_that("a cap above the mean weight still trims as before", {
  # Grossed weights 300 / 666.67 / 750 capped at 700: East 750 -> 700, sum
  # 100000 - 40 x 50 = 98000, rescaled by 100000/98000:
  # North 300 x 100/98, South 2000/3 x 100/98, East 700 x 100/98.
  run <- adv_run(
    "grossed_cap_ok",
    specs = ref_spec("dwg", "design", trim_method = "cap", trim_value = 700),
    design_targets = ref_design_targets("dwg"),
    advanced = data.frame(weight_name = "dwg", grossing = "Y")
  )
  expect_equal(run$status, 0L, info = run$console)
  lk <- adv_lookup(run)
  region <- ref_survey()$Region
  expect_equal(lk$dwg, unname(c(North = 300, South = 2000 / 3, East = 700)[region]) * 100 / 98,
               tolerance = 1e-9)
})


# ==============================================================================
# cap_weights in Advanced_Settings
# ==============================================================================

test_that("cap_weights in Advanced_Settings is refused, because nothing reads it", {
  # The README, RUNBOOK, TEMPLATE_REFERENCE and the CFG_TRIM_USE_CAP refusal
  # all told operators to cap rim weights with cap_weights. The config path
  # only ever read weight_bounds, so any cap_weights value ran on the default
  # 0.3,3.0 bounds and said nothing. On the fixture the hand raking weights
  # run to 1.7475, so a cap of 1.6 binds; ignoring it ships weights above the
  # cap the operator set.
  run <- adv_run(
    "cap_weights",
    specs = ref_spec("rw", "rim"),
    rim_targets = ref_rim_target_rows("rw"),
    advanced = data.frame(weight_name = "rw", cap_weights = 1.6)
  )
  expect_true(grepl("CFG_CAP_WEIGHTS_NOT_READ", run$console, fixed = TRUE), info = run$console)
  expect_true(grepl("weight_bounds", run$console, fixed = TRUE))
  expect_false(file.exists(run$lookup))
})

test_that("weight_bounds is the setting that caps rim weights", {
  # weight_bounds = 0.3,1.6 with logit: every rim weight lands inside
  # [0.3, 1.6], below the unbounded 1.7475.
  run <- adv_run(
    "weight_bounds",
    specs = ref_spec("rw", "rim"),
    rim_targets = ref_rim_target_rows("rw"),
    advanced = data.frame(weight_name = "rw", weight_bounds = "0.3,1.6",
                          calibration_method = "logit")
  )
  lk <- adv_lookup(run)
  expect_equal(run$status, 0L, info = run$console)
  expect_true(max(lk$rw) <= 1.6 + 1e-8)
  expect_true(min(lk$rw) >= 0.3 - 1e-8)
})


# ==============================================================================
# A rim variable with a single category
# ==============================================================================

test_that("a single-category rim variable at 100% is met, not a crash", {
  # Every respondent is Country = ZA, target 100%, alongside Gender 48/52.
  # model.matrix() cannot build contrasts for a one-level factor, so the run
  # died as BUG_INTERNAL_ERROR and wrote nothing. The 100% target is met by
  # every respondent by construction, so the weights are the Gender rake
  # alone: Male 0.48 x 200/120 = 0.8, Female 0.52 x 200/80 = 1.3.
  data <- ref_survey()
  data$Country <- "ZA"
  run <- adv_run(
    "single_category", data = data,
    specs = ref_spec("rw", "rim"),
    rim_targets = ref_rim_target_rows("rw", list(Country = c(ZA = 1),
                                                 Gender = c(Male = 0.48, Female = 0.52)))
  )
  expect_equal(run$status, 0L, info = run$console)
  expect_false(grepl("BUG_INTERNAL_ERROR", run$console, fixed = TRUE))
  skip_if_not(file.exists(run$lookup), "no lookup file written")

  lk <- adv_lookup(run)
  expect_equal(lk$rw, unname(c(Male = 0.8, Female = 1.3)[data$Gender]), tolerance = 1e-6)

  # The margins table still reports the single category, achieved at 100%.
  s <- ref_read_sheet(run$diagnostics, "rw")
  hdr <- which(s[[1]] == "variable")[1]
  m <- s[(hdr + 1):(hdr + 3), 1:4]
  expect_equal(m[[2]], c("ZA", "Male", "Female"))
  expect_equal(as.numeric(m[[4]]), c(100, 48, 52), tolerance = 1e-5)
})


# ==============================================================================
# Rim variable names that are not R names
# ==============================================================================

test_that("rim variables named with spaces, hyphens or a leading digit rake by hand", {
  # The calibration formula was pasted from the variable names, so
  # "Home Region" was a parse error, "Age-Band" parsed as Age minus Band, and
  # "2024 Gender" a parse error: BUG_INTERNAL_ERROR and no files. Excel data
  # keeps such headers verbatim (read.csv would have renamed them first).
  # The weights must equal the hand raking loop on the same data.
  data <- ref_survey()
  hand <- ref_hand_rake(data, ref_rim_targets())
  names(data)[names(data) == "Region"] <- "Home-Region Now"
  names(data)[names(data) == "Gender"] <- "2024 Gender"
  targets <- ref_rim_targets()
  names(targets) <- c("Home-Region Now", "2024 Gender")

  run <- adv_run("odd_names", data = data, data_ext = "xlsx",
                 specs = ref_spec("rw", "rim"),
                 rim_targets = ref_rim_target_rows("rw", targets))
  expect_equal(run$status, 0L, info = run$console)
  expect_false(grepl("BUG_INTERNAL_ERROR", run$console, fixed = TRUE))
  skip_if_not(file.exists(run$lookup), "no lookup file written")

  expect_equal(adv_lookup(run)$rw, hand, tolerance = 1e-6)
  s <- ref_read_sheet(run$diagnostics, "rw")
  hdr <- which(s[[1]] == "variable")[1]
  expect_equal(s[[1]][(hdr + 1):(hdr + 5)],
               c(rep("Home-Region Now", 3), rep("2024 Gender", 2)))
})


# ==============================================================================
# A base under 30
# ==============================================================================

test_that("a base of 20 weights by hand", {
  # 14 in A and 6 in B, populations 50/50. Raw 50/14 and 50/6; normalised to
  # 20 by 20/100: A 10/14 = 0.714286, B 10/6 = 1.666667. sum 10 + 10 = 20.
  # sum w^2 = 14 x 100/196 + 6 x 100/36 = 7.142857 + 16.666667 = 23.809524;
  # n_eff = 400 / 23.809524 = 16.8; DEFF = 20 / 16.8 = 1.190476.
  data <- data.frame(id = 1:20, Stratum = rep(c("A", "B"), c(14, 6)),
                     stringsAsFactors = FALSE)
  run <- adv_run("n20", data = data, specs = ref_spec("dw", "design"),
                 design_targets = data.frame(weight_name = "dw", stratum_variable = "Stratum",
                                             stratum_category = c("A", "B"),
                                             population_size = c(50, 50),
                                             stringsAsFactors = FALSE))
  expect_equal(run$status, 0L, info = run$console)
  lk <- adv_lookup(run)
  expect_equal(lk$dw, rep(c(10 / 14, 10 / 6), c(14, 6)), tolerance = 1e-12)

  s <- ref_read_sheet(run$diagnostics, "dw")
  expect_equal(ref_kv(s, "Effective N"), "17")
  expect_equal(ref_kv(s, "Design Effect (DEFF)"), "1.19")
})
