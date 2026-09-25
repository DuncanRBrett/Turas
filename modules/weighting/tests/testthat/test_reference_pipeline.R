# ==============================================================================
# WEIGHTING - PIPELINE AND CONSISTENCY GATES (robustness programme, 25 Sep 2026)
# ==============================================================================
# One config workbook, run through run_weighting.R in a fresh Rscript exactly as
# the CLI does, and every headline number read back FROM THE FILES Duncan hands
# on: the lookup file, the diagnostics workbook, the stats pack and the HTML
# report. Each is checked against the hand references in
# helper_reference_fixture.R, and against the other places the same number
# appears (consistency gate).
#
# Weights in the config:
#   dw   design, normalised      0.6 / 4/3 / 1.5
#   dwg  design, grossed         300 / 2000/3 / 750
#   rw   rim, default bounds     = hand raking loop (bounds do not bind here)
#   cw   cell                    0.4 / 16/15 / 19/15 / 1.4 / 1.4 / 1.6
#   dwt  design, cap 1.4         East capped 1.5 -> 1.4, sum 196, rescaled x 200/196:
#                                North 120/196, South 800/588, East 280/196
# ==============================================================================

source(file.path(MODULE_DIR, "tests", "testthat", "helper_reference_fixture.R"),
       local = FALSE)

skip_if_not_installed("survey")
skip_if_not_installed("openxlsx")

pipe_dir <- file.path(tempdir(), "wref_pipeline")
unlink(pipe_dir, recursive = TRUE)

pipe_paths <- ref_build_config(
  pipe_dir,
  specs = rbind(
    ref_spec("dw", "design"),
    ref_spec("dwg", "design"),
    ref_spec("rw", "rim"),
    ref_spec("cw", "cell"),
    ref_spec("dwt", "design", trim_method = "cap", trim_value = 1.4)
  ),
  design_targets = rbind(ref_design_targets("dw"), ref_design_targets("dwg"),
                         ref_design_targets("dwt")),
  rim_targets = ref_rim_target_rows("rw"),
  cell_targets = cbind(weight_name = "cw", ref_cell_targets()),
  advanced = data.frame(weight_name = "dwg", grossing = "Y")
)

pipe_run <- ref_run_child(pipe_paths$config, TURAS_ROOT)
pipe_console <- paste(pipe_run$console, collapse = "\n")

# ---- The references --------------------------------------------------------
pipe_data <- ref_survey()
pipe_expected <- list(
  dw  = ref_design_weight(pipe_data$Region),
  dwg = ref_design_weight_grossed(pipe_data$Region),
  rw  = ref_hand_rake(pipe_data, ref_rim_targets()),
  cw  = ref_cell_weight(pipe_data$Region, pipe_data$Gender),
  dwt = unname(c(North = 120 / 196, South = 800 / 588, East = 280 / 196)[pipe_data$Region])
)
# Kish from the reference weights: (sum w)^2 / sum w^2. For dw that is
# 120000/698 = 171.92 (worked in test_reference_weights.R).
pipe_kish <- vapply(pipe_expected, ref_kish, numeric(1))
pipe_deff <- 200 / pipe_kish


test_that("the CLI run finishes PASS and writes every deliverable", {
  expect_equal(pipe_run$status, 0L, info = pipe_console)
  expect_true(grepl("ANALYSIS COMPLETED SUCCESSFULLY", pipe_console, fixed = TRUE),
              info = pipe_console)
  for (p in c("lookup", "diagnostics", "html", "stats_pack")) {
    expect_true(file.exists(pipe_paths[[p]]), info = p)
  }
})


# ==============================================================================
# Lookup file: the weights tabs will merge
# ==============================================================================

test_that("the lookup file carries the hand-calculated weights", {
  skip_if_not(file.exists(pipe_paths$lookup), "run did not write the lookup file")
  lk <- openxlsx::read.xlsx(pipe_paths$lookup, sheet = "Weights", skipEmptyRows = FALSE)

  expect_equal(names(lk), c("id", "dw", "dwg", "rw", "cw", "dwt"))
  expect_equal(lk$id, pipe_data$id)
  for (w in names(pipe_expected)) {
    expect_equal(lk[[w]], pipe_expected[[w]], tolerance = 1e-6, info = w)
  }
  # Each sample-scale column sums to n; the grossed one to the population.
  for (w in c("dw", "rw", "cw", "dwt")) expect_equal(sum(lk[[w]]), 200, tolerance = 1e-6, info = w)
  expect_equal(sum(lk$dwg), 100000, tolerance = 1e-6)
})

test_that("the rim margins recomputed from the lookup file hit every target", {
  skip_if_not(file.exists(pipe_paths$lookup), "run did not write the lookup file")
  lk <- openxlsx::read.xlsx(pipe_paths$lookup, sheet = "Weights", skipEmptyRows = FALSE)
  merged <- merge(pipe_data, lk, by = "id")
  targets <- ref_rim_targets()
  for (v in names(targets)) {
    for (k in names(targets[[v]])) {
      share <- sum(merged$rw[merged[[v]] == k]) / sum(merged$rw)
      expect_equal(share, targets[[v]][[k]], tolerance = 1e-6, info = paste(v, k))
    }
  }
})


# ==============================================================================
# Diagnostics workbook
# ==============================================================================

diag_summary_table <- function() {
  s <- ref_read_sheet(pipe_paths$diagnostics, "Summary")
  hdr <- which(s[[1]] == "weight_name")[1]
  tbl <- s[(hdr + 1):nrow(s), , drop = FALSE]
  names(tbl) <- as.character(unlist(s[hdr, ]))
  tbl <- tbl[!is.na(tbl$weight_name) & nzchar(tbl$weight_name), , drop = FALSE]
  tbl
}

test_that("the Summary sheet carries the hand Kish figures for every weight", {
  skip_if_not(file.exists(pipe_paths$diagnostics), "run did not write diagnostics")
  tbl <- diag_summary_table()
  expect_equal(tbl$weight_name, names(pipe_expected))
  for (w in names(pipe_expected)) {
    row <- tbl[tbl$weight_name == w, ]
    expect_equal(as.numeric(row$effective_n), round(pipe_kish[[w]]), info = w)
    expect_equal(as.numeric(row$design_effect), pipe_deff[[w]], tolerance = 1e-8, info = w)
    expect_equal(as.numeric(row$efficiency), 100 / pipe_deff[[w]], tolerance = 1e-8, info = w)
    expect_equal(as.numeric(row$min), min(pipe_expected[[w]]), tolerance = 1e-8, info = w)
    expect_equal(as.numeric(row$max), max(pipe_expected[[w]]), tolerance = 1e-8, info = w)
    expect_equal(as.numeric(row$n_valid), 200, info = w)
  }
})

test_that("each per-weight sheet agrees with the Summary sheet and the reference", {
  skip_if_not(file.exists(pipe_paths$diagnostics), "run did not write diagnostics")
  for (w in names(pipe_expected)) {
    s <- ref_read_sheet(pipe_paths$diagnostics, w)
    expect_equal(as.numeric(ref_kv(s, "Effective N")), round(pipe_kish[[w]]), info = w)
    expect_equal(as.numeric(ref_kv(s, "Design Effect (DEFF)")), round(pipe_deff[[w]], 2), info = w)
    expect_equal(ref_kv(s, "Weighting Efficiency"),
                 paste0(round(100 / pipe_deff[[w]], 1), "%"), info = w)
    expect_equal(as.numeric(ref_kv(s, "Mean")), mean(pipe_expected[[w]]), tolerance = 1e-8, info = w)
  }
})

test_that("the Stratum Details carry the applied weight beside the raw N/n", {
  skip_if_not(file.exists(pipe_paths$diagnostics), "run did not write diagnostics")
  s <- ref_read_sheet(pipe_paths$diagnostics, "dw")
  hdr <- which(s[[1]] == "stratum")[1]
  strata <- s[(hdr + 1):(hdr + 3), 1:5]
  names(strata) <- c("stratum", "population_size", "sample_size", "weight", "raw")
  expect_equal(strata$stratum, c("North", "South", "East"))
  expect_equal(as.numeric(strata$sample_size), c(100, 60, 40))
  expect_equal(as.numeric(strata$weight), c(0.6, 4 / 3, 1.5), tolerance = 1e-8)
  expect_equal(as.numeric(strata$raw), c(300, 2000 / 3, 750), tolerance = 1e-8)
})

test_that("the Rim Target Achievement sheet matches the targets", {
  skip_if_not(file.exists(pipe_paths$diagnostics), "run did not write diagnostics")
  s <- ref_read_sheet(pipe_paths$diagnostics, "rw")
  hdr <- which(s[[1]] == "variable")[1]
  m <- s[(hdr + 1):(hdr + 5), 1:5]
  names(m) <- c("variable", "category", "target_pct", "achieved_pct", "diff_pct")
  expect_equal(m$category, c("North", "South", "East", "Male", "Female"))
  expect_equal(as.numeric(m$target_pct), c(30, 40, 30, 48, 52))
  expect_equal(as.numeric(m$achieved_pct), c(30, 40, 30, 48, 52), tolerance = 1e-5)
})


# ==============================================================================
# Stats pack
# ==============================================================================

test_that("the stats pack headline and per-weight line carry the hand figures", {
  skip_if_not(file.exists(pipe_paths$stats_pack), "run did not write the stats pack")
  a <- ref_read_sheet(pipe_paths$stats_pack, "Assumptions")

  # The headline names the first weight in config order.
  expect_equal(ref_kv(a, "Effective N after weighting"),
               sprintf("%s (dw)", format(round(pipe_kish[["dw"]]), big.mark = ",")))
  expect_equal(ref_kv(a, "DEFF"), sprintf("%.3f (dw)", pipe_deff[["dw"]]))

  per_weight <- ref_kv(a, "Per-weight diagnostics")
  for (w in names(pipe_expected)) {
    expect_true(grepl(sprintf("%s: eff_n=%s, DEFF=%.3f", w,
                              format(round(pipe_kish[[w]]), big.mark = ","),
                              pipe_deff[[w]]),
                      per_weight, fixed = TRUE), info = w)
  }

  d <- ref_read_sheet(pipe_paths$stats_pack, "Declaration")
  expect_equal(ref_kv(d, "Respondents Analysed"), "200  (no respondents excluded)")
})


# ==============================================================================
# HTML report
# ==============================================================================

html_text <- function() paste(readLines(pipe_paths$html, warn = FALSE, encoding = "UTF-8"),
                              collapse = "\n")

html_summary_row <- function(html, weight) {
  pat <- sprintf('<td class="wt-label-col">%s</td>\\s*<td>[^<]*</td>((\\s*<td class="wt-num">[^<]*</td>){7})',
                 weight)
  hit <- regmatches(html, regexec(pat, html, perl = TRUE))[[1]]
  if (length(hit) == 0) return(NULL)
  cells <- regmatches(hit[2], gregexpr('(?<=<td class="wt-num">)[^<]*', hit[2], perl = TRUE))[[1]]
  setNames(cells, c("n", "eff_n", "min", "max", "mean", "deff", "efficiency")[seq_along(cells)])
}

test_that("the HTML summary table carries the hand figures for every weight", {
  skip_if_not(file.exists(pipe_paths$html), "run did not write the HTML report")
  html <- html_text()
  for (w in names(pipe_expected)) {
    row <- html_summary_row(html, w)
    expect_false(is.null(row), info = w)
    if (is.null(row)) next
    expect_equal(row[["n"]], "200", info = w)
    expect_equal(row[["eff_n"]], sprintf("%.0f", pipe_kish[[w]]), info = w)
    expect_equal(row[["min"]], sprintf("%.4f", min(pipe_expected[[w]])), info = w)
    expect_equal(row[["max"]], sprintf("%.4f", max(pipe_expected[[w]])), info = w)
    expect_equal(row[["mean"]], sprintf("%.4f", mean(pipe_expected[[w]])), info = w)
    expect_equal(row[["deff"]], sprintf("%.2f", pipe_deff[[w]]), info = w)
    expect_equal(row[["efficiency"]], sprintf("%.1f%%", 100 / pipe_deff[[w]]), info = w)
  }
})

test_that("each HTML diagnostics panel repeats the summary figures", {
  skip_if_not(file.exists(pipe_paths$html), "run did not write the HTML report")
  html <- html_text()
  eff <- regmatches(html, gregexpr('<td>Effective N</td><td class="wt-num">[^<]*', html))[[1]]
  eff <- sub('.*>', '', eff)
  deff <- regmatches(html, gregexpr('<td>Design Effect</td><td class="wt-num">[^<]*', html))[[1]]
  deff <- sub('.*>', '', deff)
  # One panel per weight, in config order.
  expect_equal(eff, unname(sprintf("%.0f", pipe_kish)))
  expect_equal(deff, unname(sprintf("%.2f", pipe_deff)))
})


# ==============================================================================
# Consistency: the same number wherever it appears
# ==============================================================================

test_that("grossed and normalised copies of one design weight carry one effective n", {
  skip_if_not(file.exists(pipe_paths$lookup), "run did not write the lookup file")
  lk <- openxlsx::read.xlsx(pipe_paths$lookup, sheet = "Weights", skipEmptyRows = FALSE)

  # Kish is scale-free, and it is what tabs prints as the effective base. The
  # shared definition tabs uses must give the diagnostics' figure for both.
  source(file.path(TURAS_ROOT, "modules", "shared", "lib", "effective_n.R"), local = TRUE)
  expect_equal(calculate_effective_n(lk$dw), 120000 / 698, tolerance = 1e-9)
  expect_equal(calculate_effective_n(lk$dwg), 120000 / 698, tolerance = 1e-9)

  tbl <- diag_summary_table()
  expect_identical(tbl$effective_n[tbl$weight_name == "dw"],
                   tbl$effective_n[tbl$weight_name == "dwg"])
  expect_equal(as.numeric(tbl$design_effect[tbl$weight_name == "dw"]),
               as.numeric(tbl$design_effect[tbl$weight_name == "dwg"]), tolerance = 1e-10)
})

test_that("the console summary agrees with the files", {
  # The console table prints each weight's effective n and DEFF.
  for (w in names(pipe_expected)) {
    line <- grep(sprintf("^%s\\s+(design|rim|cell)\\s", w), pipe_run$console, value = TRUE)
    expect_length(line, 1)
    if (length(line) != 1) next
    parts <- strsplit(trimws(line), "\\s+")[[1]]
    expect_equal(as.numeric(gsub(",", "", parts[3])), pipe_kish[[w]], tolerance = 1e-4, info = w)
    expect_equal(parts[4], sprintf("%.2f", pipe_deff[[w]]), info = w)
  }
})
