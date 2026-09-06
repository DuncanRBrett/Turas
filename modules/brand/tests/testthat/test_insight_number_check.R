# ==============================================================================
# BRAND MODULE TESTS: the authored-insight number check
# ==============================================================================
# Insights typed into the Section_Insights sheet are written once and survive
# every re-run. That is the point of them and also the risk. On a real IPK
# report the funnel moved to the nested chain, so the Dry Seasonings table
# read aware 42, prefer 35, past 12m 22, past 3m 16, while the note above it
# still read:
#
#   "Aware 42%, prefer 59%, past 12m 31%, past 3m 20%. Below category average
#    (47% / 64% / 39% / 27%) at every stage. Prefer (59%) exceeds aware (42%)
#    by 17pp."
#
# Every figure past the first was the old absolute view, and the last sentence
# asserted something the table below it visibly contradicted. That exact
# sentence, against a funnel whose nested chain is 42 / 35 / 22 / 16, is the
# first test in this file, and it must flag 59, 31 and 20.
#
# The two properties that make the check usable are asserted alongside it:
# it never refuses a run, and it does not fire on a note whose figures are
# right, proved on the IPK fixture's own Section_Insights entries.
# ==============================================================================
library(testthat)

.inc_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT_INC <- .inc_root()
Sys.setenv(TURAS_ROOT = ROOT_INC)

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

shared_lib_inc <- file.path(ROOT_INC, "modules", "shared", "lib")
if (dir.exists(shared_lib_inc)) {
  for (f in sort(list.files(shared_lib_inc, pattern = "\\.R$", full.names = TRUE)))
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
# ai_verify.R is in an ai/ subdirectory, which the loop above does not recurse
# into. It is the file that holds deterministic_number_check().
source(file.path(shared_lib_inc, "ai", "ai_verify.R"))
tryCatch(source(file.path(ROOT_INC, "modules", "shared", "template_styles.R"),
                local = FALSE), error = function(e) NULL)

brand_r_dir_inc <- file.path(ROOT_INC, "modules", "brand", "R")
assign("brand_script_dir_override", brand_r_dir_inc, envir = globalenv())
for (f in c("00_guard.R", "01_config.R", "01b_section_insights.R",
            "02_mental_availability.R", "03_funnel.R", "03a_funnel_derive.R",
            "03c_funnel_panel_data.R", "04_repertoire.R", "05_wom.R",
            "00_main.R")) {
  fp <- file.path(brand_r_dir_inc, f)
  if (file.exists(fp)) tryCatch(source(fp, local = FALSE), error = function(e) NULL)
}
source(file.path(ROOT_INC, "modules", "brand", "lib", "html_report", "panels",
                 "03_funnel_panel_table.R"))
source(file.path(ROOT_INC, "modules", "brand", "lib", "html_report",
                 "03_page_builder.R"))
source(file.path(ROOT_INC, "modules", "brand", "lib", "html_report", "panels",
                 "09_portfolio_panel.R"))
source(file.path(ROOT_INC, "modules", "brand", "lib", "html_report",
                 "03b_insight_number_check.R"))


# ------------------------------------------------------------------------------
# The real case, rebuilt. Focal brand nested 42 / 35 / 22 / 16, which is what
# the table shows, and absolute 42 / 59 / 31 / 20, which is what the stale
# sentence quotes. A weighted total of 1000 makes the chain counts exact, so
# the nested figures are 42.0, 35.0, 22.0 and 16.0 with nothing to round.
# A second brand gives the category-average row something to average.
# ------------------------------------------------------------------------------
.INC_N_W <- 1000
.INC_STAGES <- c("aware", "consideration", "bought_long", "bought_target")
.INC_CHAIN <- list(IPK = c(420, 350, 220, 160), ROB = c(300, 240, 140, 90))
.INC_ABS <- list(IPK = c(0.42, 0.59, 0.31, 0.20),
                 ROB = c(0.30, 0.25, 0.15, 0.10))

.inc_stages_df <- function(chain = .INC_CHAIN, abs_pct = .INC_ABS,
                           n_w = .INC_N_W) {
  rows <- list()
  for (b in names(chain)) {
    for (i in seq_along(.INC_STAGES)) {
      rows[[length(rows) + 1]] <- data.frame(
        brand_code = b, stage_key = .INC_STAGES[i],
        pct_weighted = abs_pct[[b]][i], pct_unweighted = abs_pct[[b]][i],
        base_weighted = abs_pct[[b]][i] * n_w,
        base_unweighted = round(abs_pct[[b]][i] * n_w),
        n_effective = n_w, warning_flag = "none",
        pct_aware_filtered = 0.5,
        pct_nested_filtered = if (i == 1) 1 else
          chain[[b]][i] / chain[[b]][i - 1],
        base_aware_filtered = chain[[b]][1],
        base_stage_aware_filtered = chain[[b]][i],
        base_chain_filtered = chain[[b]][i],
        base_aware_unweighted = chain[[b]][1],
        base_stage_aware_unweighted = chain[[b]][i],
        base_chain_unweighted = chain[[b]][i],
        stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}

.inc_funnel <- function(...) {
  list(status = "PASS", stages = .inc_stages_df(...),
       meta = list(category_type = "transactional", focal_brand = "IPK",
                   wave = 1, n_unweighted = .INC_N_W, n_weighted = .INC_N_W,
                   n_effective = .INC_N_W, stage_count = length(.INC_STAGES),
                   stage_keys = .INC_STAGES))
}

.inc_results <- function(funnel = .inc_funnel()) {
  list(results = list(categories = list(
    "Dry Seasonings & Spices" = list(
      category = "Dry Seasonings & Spices", cat_code = "DSS",
      funnel = funnel))))
}

.INC_STALE <- paste(
  "Aware 42%, prefer 59%, past 12m 31%, past 3m 20%.",
  "Below category average (47% / 64% / 39% / 27%) at every stage.",
  "Prefer (59%) exceeds aware (42%) by 17pp.")


# ==============================================================================
# The case this check exists for
# ==============================================================================

context("insight number check: the stale funnel sentence")

test_that("the sentence that contradicted the table flags 59, 31 and 20", {
  chk <- check_brand_section_insights(c(`funnel-dss` = .INC_STALE),
                                      .inc_results())
  expect_true("funnel-dss" %in% chk$checked)
  expect_length(chk$findings, 1L)
  figs <- chk$findings[["funnel-dss"]]$figures
  expect_true(all(c("59", "31", "20") %in% figs))
})

test_that("42, the one figure that is still right, is not flagged", {
  chk <- check_brand_section_insights(c(`funnel-dss` = .INC_STALE),
                                      .inc_results())
  expect_false("42" %in% chk$findings[["funnel-dss"]]$figures)
})

test_that("the same note written on the nested figures does not fire", {
  good <- paste(
    "IPK is known to 42% of the sample and holds 35% at preference,",
    "22% at past 12 months and 16% at past 3 months.",
    "The category average at the first stage is 36%.")
  chk <- check_brand_section_insights(c(`funnel-dss` = good), .inc_results())
  expect_true("funnel-dss" %in% chk$checked)
  expect_length(chk$findings, 0L)
})

test_that("the pool is the view the page opens on, not every view", {
  # 59 is a real figure on this funnel: it is the focal brand's absolute
  # percentage at the preference stage. It is not a figure the reader can
  # see, because the page opens on the nested chain. Matching any view would
  # have passed the sentence that started this.
  pool <- .bin_funnel_pool(.inc_funnel())
  expect_true(any(abs(pool - 42) < 0.6))   # nested aware
  expect_true(any(abs(pool - 35) < 0.6))   # nested preference
  expect_false(any(abs(pool - 59) < 0.6))  # absolute preference, not on screen
  expect_false(any(abs(pool - 31) < 0.6))
  expect_false(any(abs(pool - 20) < 0.6))
})

test_that("the finding names the view it was read against", {
  chk <- check_brand_section_insights(c(`funnel-dss` = .INC_STALE),
                                      .inc_results())
  expect_match(chk$findings[["funnel-dss"]]$view, "nested funnel")
})


# ==============================================================================
# It reports, it never refuses
# ==============================================================================

context("insight number check: reports, never refuses")

test_that("a flagged run produces a warning naming the section and figures", {
  chk <- check_brand_section_insights(c(`funnel-dss` = .INC_STALE),
                                      .inc_results())
  w <- brand_insight_check_warnings(chk)
  expect_length(w, 1L)
  expect_match(w, "funnel-dss", fixed = TRUE)
  expect_match(w, "59", fixed = TRUE)
  # several figures take a plural verb; one takes the singular
  expect_match(w, "do not appear", fixed = TRUE)
  one <- list(findings = list(`funnel-dss` = list(
    anchor = "funnel-dss", figures = "59", view = "")))
  expect_match(brand_insight_check_warnings(one), "does not appear",
               fixed = TRUE)
})

test_that("a clean run produces no warning and prints no console box", {
  chk <- check_brand_section_insights(list(), .inc_results())
  expect_length(brand_insight_check_warnings(chk), 0L)
  expect_output(brand_insight_check_console(chk), NA)
})

test_that("the console box names the section, the figures and the fix", {
  chk <- check_brand_section_insights(c(`funnel-dss` = .INC_STALE),
                                      .inc_results())
  out <- paste(capture.output(brand_insight_check_console(chk)),
               collapse = "\n")
  expect_match(out, "=== TURAS BRAND: AUTHORED INSIGHT NUMBER CHECK ===",
               fixed = TRUE)
  expect_match(out, "funnel-dss", fixed = TRUE)
  expect_match(out, "59", fixed = TRUE)
  expect_match(out, "Section_Insights", fixed = TRUE)
  expect_match(out, "The report was still written", fixed = TRUE)
})

test_that("a broken results object is skipped, not thrown", {
  expect_silent(chk <- check_brand_section_insights(
    c(`funnel-dss` = .INC_STALE), list(results = list(categories = "nonsense"))))
  expect_length(chk$findings, 0L)
})

test_that("a funnel whose panel table cannot be built yields no pool", {
  broken <- .inc_funnel()
  broken$stages$base_chain_filtered <- NA_real_
  broken$meta$n_weighted <- NA_real_
  expect_length(.bin_funnel_pool(broken), 0L)
  chk <- check_brand_section_insights(c(`funnel-dss` = .INC_STALE),
                                      .inc_results(broken))
  expect_true("funnel-dss" %in% chk$skipped)
  expect_length(chk$findings, 0L)
})

test_that("a REFUSED funnel is skipped rather than reported", {
  ref <- .inc_funnel(); ref$status <- "REFUSED"
  chk <- check_brand_section_insights(c(`funnel-dss` = .INC_STALE),
                                      .inc_results(ref))
  expect_true("funnel-dss" %in% chk$skipped)
})


# ==============================================================================
# Which numbers are claims, and which are not
# ==============================================================================

context("insight number check: what counts as a claim")

test_that("thousands separators are read as one number", {
  expect_equal(.bin_prepare_text("A base of 1,200 and a total of 1,234,567."),
               "A base of nn and a total of 1234567.")
  # and the shared extractor then sees 1234567, not 1 and 234 and 567
  expect_true(deterministic_number_check(
    .bin_prepare_text("The panel carried 1,234,567 links."), c(1234567))$pass)
  expect_false(deterministic_number_check(
    .bin_prepare_text("The panel carried 1,234,567 links."), c(1234))$pass)
})

test_that("a difference carrying its unit is not checked as a level", {
  for (txt in c("up 17pp", "up 17 pp", "down 17 ppt", "17 pts", "17 points",
                "17 percentage points", "down -7pp")) {
    expect_false(grepl("17|-7", .bin_prepare_text(txt)),
                 info = txt)
  }
  # but the levels either side of the difference are still checked
  chk <- deterministic_number_check(
    .bin_prepare_text("Preference at 59% is 17pp above awareness at 42%."),
    c(42))
  expect_false(chk$pass)
  expect_equal(.bin_parse_issue_figures(chk$issues), "59")
})

test_that("a year is not read as a figure from the section", {
  expect_equal(.bin_prepare_text("The 2026 wave, up on 2023."),
               "The yyyy wave, up on yyyy.")
  expect_equal(.bin_prepare_text("Measured in 2026."), "Measured in yyyy.")
  # a decimal that starts with a year-shaped number is left alone
  expect_equal(.bin_prepare_text("A mean of 1999.5 units."),
               "A mean of 1999.5 units.")
  expect_equal(.bin_prepare_text("21999 respondents"), "21999 respondents")
})

test_that("a timeframe carrying its unit is not checked as a figure", {
  # the funnel's own stage is labelled "Past 12 months", so naming the stage
  # is not a claim about a figure in it. Without this, every funnel insight
  # that names its stages fires on any report where no brand sits within
  # tolerance of 12.
  expect_equal(
    .bin_prepare_text("22% at past 12 months and 16% at past 3m"),
    "22% at past tt months and 16% at past ttm")
  expect_true(deterministic_number_check(
    .bin_prepare_text("Holds 22% at past 12 months."), c(22))$pass)
  expect_true(deterministic_number_check(
    .bin_prepare_text("Over the last 26 weeks it held 22%."), c(22))$pass)
  # a word that merely starts with a unit letter is not a unit
  expect_equal(.bin_prepare_text("A spend of 16 million."),
               "A spend of 16 million.")
  expect_equal(.bin_prepare_text("Read in 12 minutes."), "Read in 12 minutes.")
})

test_that("an inline base is not checked", {
  expect_equal(.bin_prepare_text("Base n=1,200 respondents."),
               "Base n=nn respondents.")
  expect_equal(.bin_prepare_text("On a base of 438."), "On a base of nn.")
})

test_that("small numbers and 100 stay unchecked, inherited from the shared helper", {
  expect_true(deterministic_number_check(
    .bin_prepare_text("The top 3 brands take 100% of the shelf."),
    c(42))$pass)
})

test_that("a decimal reading is matched, and a percent sign does not break it", {
  expect_true(deterministic_number_check(
    .bin_prepare_text("Its strongest entry point reaches 16.7%."),
    c(16.7))$pass)
})


# ==============================================================================
# Tolerance: rounding to the displayed precision
# ==============================================================================

context("insight number check: tolerance")

test_that("a figure rounded to the displayed integer passes", {
  # the tables print sprintf("%.0f%%", ...), so 41.7 is displayed as 42
  expect_true(deterministic_number_check(
    .bin_prepare_text("Awareness sits at 42%."), c(41.7))$pass)
  expect_true(deterministic_number_check(
    .bin_prepare_text("Awareness sits at 42%."), c(42.4))$pass)
  # 44.5 displays as 45 (R rounds half to even here, and either way the
  # analyst is reading a 45 off the page), so 45 has to pass
  expect_true(deterministic_number_check(
    .bin_prepare_text("The target stage sits at 45%."), c(44.5))$pass)
})

test_that("a figure a whole point out is not a rounding difference", {
  expect_false(deterministic_number_check(
    .bin_prepare_text("Awareness sits at 42%."), c(41.0))$pass)
  expect_false(deterministic_number_check(
    .bin_prepare_text("Awareness sits at 42%."), c(43.0))$pass)
})


# ==============================================================================
# The shared helper's message, parsed back
# ==============================================================================

context("insight number check: the shared issues string")

test_that("the figures are read back out of the shared helper's message", {
  chk <- deterministic_number_check("Figures of 59, 31 and 20.", c(42))
  expect_false(chk$pass)
  expect_equal(.bin_parse_issue_figures(chk$issues), c("59", "31", "20"))
})

test_that("a message in another shape yields no figures rather than nonsense", {
  expect_length(.bin_parse_issue_figures("something else entirely"), 0L)
  expect_length(.bin_parse_issue_figures(NULL), 0L)
  expect_length(.bin_parse_issue_figures(character(0)), 0L)
})

test_that("a finding with no parsed figures still reports and marks", {
  f <- list(anchor = "funnel-dss", figures = character(0), view = "")
  chk <- list(findings = list(`funnel-dss` = f))
  expect_match(brand_insight_check_warnings(chk), "one or more figures")
  expect_match(brand_insight_check_note(chk, "funnel-dss"),
               "A figure in this note")
})


# ==============================================================================
# Anchors: which sections are checked
# ==============================================================================

context("insight number check: anchor scope")

test_that("cross-cutting anchors are not checked", {
  for (a in c("_EXECUTIVE_SUMMARY", "_BACKGROUND", "summary-cards")) {
    got <- brand_insight_pool_for(a, .inc_results())
    expect_false(got$checked, info = a)
  }
})

test_that("an anchor with no data behind it is skipped, not flagged", {
  chk <- check_brand_section_insights(
    c(`something-made-up` = "A figure of 512."), .inc_results())
  expect_equal(chk$skipped, "something-made-up")
  expect_length(chk$findings, 0L)
})

test_that("an anchor for a category that is not in the results is skipped", {
  got <- brand_insight_pool_for("funnel-zzz", .inc_results())
  expect_false(got$checked)
})

test_that("an anchor splits into its element and its category id", {
  expect_equal(.bin_split_anchor("funnel-dss"),
               list(element = "funnel", cat_id = "dss"))
  expect_equal(.bin_split_anchor("branded_reach-pas"),
               list(element = "branded_reach", cat_id = "pas"))
  expect_equal(.bin_split_anchor("_BACKGROUND"),
               list(element = "_BACKGROUND", cat_id = ""))
})

test_that("a section pool never carries a non-finite value", {
  # deterministic_number_check does any(abs(pool - n) < tol); one NA in the
  # pool makes that NA and the check throws. Same trap reader_ai_prose.R
  # filters for.
  expect_true(all(is.finite(.bin_funnel_pool(.inc_funnel()))))
  expect_true(all(is.finite(.bin_generic_pool(
    list(a = c(1, NA, 3), b = list(c = NaN, d = "7", e = "not a number"))))))
})

test_that("a proportion in the results is matched as a percentage", {
  pool <- .bin_generic_pool(list(focal_mpen = 0.838))
  expect_true(any(abs(pool - 84) < 0.6))
})


# ==============================================================================
# The marker in the HTML
# ==============================================================================

context("insight number check: the report marker")

test_that("a flagged section renders a marker naming the figures", {
  chk <- check_brand_section_insights(c(`funnel-dss` = .INC_STALE),
                                      .inc_results())
  note <- brand_insight_check_note(chk, "funnel-dss")
  expect_match(note, "br-insight-check", fixed = TRUE)
  expect_match(note, "59", fixed = TRUE)
  expect_match(note, "nested funnel", fixed = TRUE)
  # neutral wording: it says what it could not find, it does not call the
  # analyst wrong, and no em dash reaches a client-facing string
  expect_false(grepl("—", note, fixed = TRUE))
  expect_false(grepl("wrong|stale|error", note, ignore.case = TRUE))
})

test_that("a section that was not flagged renders nothing", {
  chk <- check_brand_section_insights(c(`funnel-dss` = .INC_STALE),
                                      .inc_results())
  expect_equal(brand_insight_check_note(chk, "ceps-dss"), "")
  expect_equal(brand_insight_check_note(NULL, "funnel-dss"), "")
  expect_equal(brand_insight_check_note(chk, ""), "")
})

test_that("the marker sits beside the rendered view, never inside the editor", {
  # the panel pin dropdowns capture .br-insight-editor. A marker inside the
  # textarea would be pinned and exported as part of the analyst's own words.
  html <- build_br_section_toolbar("funnel-dss", prefill_text = "A note.",
                                   check_note = "<div class=\"br-insight-check\">M</div>")
  expect_match(html, "br-insight-check", fixed = TRUE)
  editor <- regmatches(html, regexpr("(?s)<textarea.*?</textarea>", html,
                                     perl = TRUE))
  expect_length(editor, 1L)
  expect_false(grepl("br-insight-check", editor, fixed = TRUE))
  # and it lands inside the insight container, after the rendered view
  expect_lt(regexpr("br-insight-rendered", html, fixed = TRUE),
            regexpr("br-insight-check", html, fixed = TRUE))
  expect_lt(regexpr("br-insight-check", html, fixed = TRUE),
            regexpr("br-insight-dismiss", html, fixed = TRUE))
})

test_that("a toolbar with no marker is byte-identical to the old one", {
  a <- build_br_section_toolbar("wom-dss", prefill_text = "A note.")
  b <- build_br_section_toolbar("wom-dss", prefill_text = "A note.",
                                check_note = "")
  expect_equal(a, b)
  expect_false(grepl("br-insight-check", a, fixed = TRUE))
})

test_that("the page builder's accessor is safe when the check never ran", {
  expect_equal(.br_insight_check_note(list(), "funnel-dss"), "")
  expect_equal(.br_insight_check_note(list(section_insight_checks = NULL),
                                      "funnel-dss"), "")
})


# ==============================================================================
# On the IPK fixture, end to end
# ==============================================================================

context("insight number check: the IPK fixture")

.INC_FIXTURE_DIR <- file.path(ROOT_INC, "modules", "brand", "tests",
                              "fixtures", "ipk_wave1")

# The fixture workbooks are gitignored: they are generated locally from
# 00_generate.R, so the Brand_Config.xlsx sitting in the fixture directory may
# predate the Section_Insights sheet this file needs. Write a fresh config
# into tempdir() from the fixture's own writer instead, and point run_brand at
# the fixture directory for the data and the survey structure, which
# load_brand_config() resolves against project_root. Nothing is written into
# the repo.
.INC_TMP_CFG <- NULL
.inc_fixture_config <- function() {
  if (!is.null(.INC_TMP_CFG)) return(.INC_TMP_CFG)
  gen <- file.path(.INC_FIXTURE_DIR, "00_generate.R")
  if (!file.exists(gen)) return(NA_character_)
  source(gen, local = FALSE)
  assign("ipk_fixture_dir", function() .INC_FIXTURE_DIR, envir = globalenv())
  ipk_source_fixture_helpers()
  path <- file.path(tempdir(), "inc_Brand_Config.xlsx")
  ipk_write_brand_config(path)
  .INC_TMP_CFG <<- path
  path
}

# run_brand() on the fixture takes a few seconds, so run it once and reuse it.
.INC_RES_CACHE <- NULL
.inc_fixture_results <- function() {
  if (!is.null(.INC_RES_CACHE)) return(.INC_RES_CACHE)
  res <- run_brand(.inc_fixture_config(), project_root = .INC_FIXTURE_DIR,
                   verbose = FALSE)
  .INC_RES_CACHE <<- res
  res
}

.inc_have_fixture <- function() {
  file.exists(file.path(.INC_FIXTURE_DIR, "ipk_wave1_data.xlsx")) &&
    file.exists(file.path(.INC_FIXTURE_DIR, "Survey_Structure.xlsx")) &&
    file.exists(file.path(.INC_FIXTURE_DIR, "00_generate.R"))
}

test_that("the fixture config carries authored insights on real sections", {
  skip_if_not(.inc_have_fixture(), "IPK Wave 1 fixture not built; run 00_generate.R")
  cfg <- .inc_fixture_config()
  expect_true("Section_Insights" %in% openxlsx::getSheetNames(cfg))
  si <- load_section_insights_sheet(cfg)
  expect_true(all(c("funnel-dss", "ceps-dss", "wom-dss") %in% names(si)))
})

test_that("the fixture's own insights pass the check on a real run", {
  skip_if_not(.inc_have_fixture(), "IPK Wave 1 fixture not built; run 00_generate.R")
  skip_if_not(exists("run_brand", mode = "function"))

  res <- .inc_fixture_results()
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  si <- res$config$section_insights
  expect_false(is.null(si))

  chk <- check_brand_section_insights(si, res)
  # the three data-backed anchors are actually checked, not quietly skipped
  expect_true(all(c("funnel-dss", "ceps-dss", "wom-dss") %in% chk$checked))
  # the executive summary is cross-cutting, so it is skipped by design
  expect_true("_EXECUTIVE_SUMMARY" %in% chk$skipped)
  # and nothing fires
  expect_length(chk$findings, 0L)
  expect_length(brand_insight_check_warnings(chk), 0L)
})

test_that("a stale sentence on the fixture funnel is caught and reported", {
  skip_if_not(.inc_have_fixture(), "IPK Wave 1 fixture not built; run 00_generate.R")
  skip_if_not(exists("run_brand", mode = "function"))

  res <- .inc_fixture_results()
  si <- res$config$section_insights
  # The fixture funnel opens on IPK at 92 / 67 / 45 / 32. A note claiming 88%
  # awareness quotes a figure no brand on this table carries at any stage.
  # 88 is chosen deliberately: with fifteen brands and four stages the section
  # pool is dense, so a stale figure can land on a real figure belonging to
  # another brand. That limit is recorded in the implementation log; it does
  # not weaken the case this check exists for, where the stale figures came
  # from a different view of the same brand.
  si[["funnel-dss"]] <- "IPK is known to 88% of the sample."
  chk <- check_brand_section_insights(si, res)
  expect_true("funnel-dss" %in% names(chk$findings))
  expect_equal(chk$findings[["funnel-dss"]]$figures, "88")
  expect_length(brand_insight_check_warnings(chk), 1L)
  expect_match(brand_insight_check_note(chk, "funnel-dss"), "88", fixed = TRUE)
})


# ==============================================================================
# The Brand Attitude sub-tab, and the portfolio sub-tabs
# ==============================================================================

context("insight number check: the other anchored sections")

test_that("the attitude sub-tab is read against its decomposition, not the stages", {
  f <- .inc_funnel()
  f$attitude_decomposition <- data.frame(
    brand_code = c("IPK", "ROB"), love_pct = c(0.18, 0.11),
    prefer_pct = c(0.24, 0.19), stringsAsFactors = FALSE)
  got <- brand_insight_pool_for("attitude-dss", .inc_results(f))
  expect_true(got$checked)
  expect_true(any(abs(got$pool - 18) < 0.6))
  # 59 is the funnel's absolute preference figure. The attitude sub-tab never
  # shows it, so it must not be in this pool.
  expect_false(any(abs(got$pool - 59) < 0.6))
})

test_that("a portfolio sub-tab is checked against the portfolio results", {
  res <- .inc_results()
  res$results$portfolio <- list(reach = list(any_brand_pct = 63.2))
  got <- brand_insight_pool_for("pf-overview", res)
  expect_true(got$checked)
  expect_true(any(abs(got$pool - 63) < 0.6))
  expect_false(any(abs(got$pool - 88) < 0.6))
})

test_that("the portfolio toolbar carries the marker for a flagged sub-tab", {
  skip_if_not(exists(".pf_section_toolbar", mode = "function"))
  chk <- list(findings = list(`pf-overview` = list(
    anchor = "pf-overview", figures = "88", view = "")))
  .pf_set_section_insights(c(`pf-overview` = "Reach of 88%."))
  .pf_set_insight_checks(chk)
  on.exit({ .pf_set_section_insights(NULL); .pf_set_insight_checks(NULL) },
          add = TRUE)
  html <- .pf_section_toolbar("pf-overview")
  expect_match(html, "br-insight-check", fixed = TRUE)
  expect_match(html, "88", fixed = TRUE)
  editor <- regmatches(html, regexpr("(?s)<textarea.*?</textarea>", html,
                                     perl = TRUE))
  expect_false(grepl("br-insight-check", editor, fixed = TRUE))
})

test_that("the portfolio toolbar is unchanged when nothing was flagged", {
  skip_if_not(exists(".pf_section_toolbar", mode = "function"))
  .pf_set_section_insights(c(`pf-overview` = "Reach of 63%."))
  .pf_set_insight_checks(NULL)
  on.exit(.pf_set_section_insights(NULL), add = TRUE)
  expect_false(grepl("br-insight-check", .pf_section_toolbar("pf-overview"),
                     fixed = TRUE))
})
