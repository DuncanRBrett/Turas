# ==============================================================================
# TABS MODULE - CONFIG CONTRACT TESTS (production review 2026-08, I7-I11 + I5)
# ==============================================================================
#
# The config contract: every Settings key the loader reads is whitelisted (so
# the typo warning never fires on a working setting), every whitelisted key is
# actually read somewhere (so the whitelist never blesses a dead setting), the
# template only writes recognised keys, junk cells cannot silently flip
# defaults, and the statistical settings refuse loudly on junk.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_config_contract.R")
#
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
tabs_lib <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", tabs_lib, envir = globalenv())
source(file.path(tabs_lib, "crosstabs", "crosstabs_config.R"))

CONFIG_SRC <- file.path(tabs_lib, "crosstabs", "crosstabs_config.R")

# Every Settings key build_config_object reads, parsed from the source.
builder_read_keys <- function() {
  src <- readLines(CONFIG_SRC)
  start <- grep("^build_config_object <- function", src)
  end <- grep("^validate_config_settings <- function|^#' Validate the statistical settings", src)[1]
  body <- paste(src[start:(end - 1)], collapse = "\n")
  m <- gregexpr('get_config_value\\(config, "([a-z_0-9]+)"', body)
  keys <- regmatches(body, m)[[1]]
  unique(gsub('get_config_value\\(config, "([a-z_0-9]+)".*', "\\1", keys))
}

context("config contract — whitelist agreement (I7)")

test_that("every Settings key the builder reads is in TABS_KNOWN_SETTINGS", {
  keys <- builder_read_keys()
  expect_gt(length(keys), 50)  # sanity: the parse found the builder
  missing <- setdiff(keys, TABS_KNOWN_SETTINGS)
  expect_equal(missing, character(0),
               info = paste("Read by build_config_object but not whitelisted:",
                            paste(missing, collapse = ", ")))
})

test_that("the 8 settings the whitelist commits missed are now recognised", {
  for (k in c("show_dashboard", "show_patterns", "show_differences",
              "show_tracking", "show_qualitative", "patterns_headline",
              "patterns_exclude_banners", "sampling_note")) {
    expect_true(k %in% TABS_KNOWN_SETTINGS, info = k)
  }
})

test_that("dead settings are no longer blessed by the whitelist (I9)", {
  for (k in c("significance_level", "weight_na_threshold",
              "weight_zero_threshold", "weight_deff_warning",
              "default_weight", "weight_column_exists")) {
    expect_false(k %in% TABS_KNOWN_SETTINGS, info = k)
  }
})

test_that("the shipped template writes only whitelisted settings", {
  tmpl <- file.path(turas_root, "modules/tabs/templates/Crosstab_Config_Template.xlsx")
  skip_if_not(file.exists(tmpl), "template not present")
  s <- openxlsx::read.xlsx(tmpl, sheet = "Settings", colNames = FALSE, skipEmptyRows = FALSE)
  n <- as.character(s[[1]])
  # setting rows are lowercase_with_underscores; section headers are UPPERCASE
  setting_rows <- n[!is.na(n) & grepl("^[a-z][a-z_0-9]*$", n)]
  unknown <- setdiff(setting_rows, TABS_KNOWN_SETTINGS)
  expect_equal(unknown, character(0),
               info = paste("Template writes unrecognised settings:",
                            paste(unknown, collapse = ", ")))
})

context("config contract — junk cannot flip defaults (I10)")

test_that("a literal-'NA' cell keeps a default-TRUE toggle TRUE", {
  cfg <- list(enable_significance_testing = "NA", bonferroni_correction = "junk",
              structure_file = "x.xlsx")
  obj <- suppressWarnings(build_config_object(cfg))
  expect_true(obj$enable_significance_testing)
  expect_true(obj$bonferroni_correction)
})

test_that("a junk cell keeps a default-FALSE toggle FALSE and a valid cell still works", {
  obj <- suppressWarnings(build_config_object(list(apply_weighting = "garbage")))
  expect_false(obj$apply_weighting)
  obj2 <- suppressWarnings(build_config_object(list(apply_weighting = "TRUE",
                                                    enable_significance_testing = "N")))
  expect_true(obj2$apply_weighting)
  expect_false(obj2$enable_significance_testing)
})

context("config contract — statistical junk refuses at load (I11)")

test_that("junk alpha refuses with CFG_INVALID_SETTING naming the cell", {
  obj <- suppressWarnings(build_config_object(list(alpha = "0,05")))
  err <- tryCatch({ validate_config_settings(obj, list(alpha = "0,05")); NULL },
                  error = function(e) e)
  expect_false(is.null(err))
  expect_match(conditionMessage(err), "alpha")
  expect_match(conditionMessage(err), "0,05", fixed = TRUE)
})

test_that("junk min_reporting_base refuses (it must not silently disable the k-gate)", {
  obj <- suppressWarnings(build_config_object(list(min_reporting_base = "ten")))
  expect_error(validate_config_settings(obj), class = "turas_refusal")
})

test_that("junk decimal places refuse instead of blanking every cell", {
  obj <- suppressWarnings(build_config_object(list(decimal_places_percent = "one")))
  expect_error(validate_config_settings(obj), class = "turas_refusal")
})

test_that("a clean default config validates", {
  obj <- build_config_object(list(structure_file = "x.xlsx"))
  expect_true(validate_config_settings(obj))
})

context("config contract — dashboard scales and thresholds (M9)")

# M9 (production review 2026-08). The dashboard numerics take the safe_numeric
# path with a fallback: junk in the cell became the DEFAULT, silently. A 0-5
# project that typed "five" got a scale maximum of 10 and every gauge read at
# half strength, with nothing anywhere saying so. These settings are statistical
# settings — they decide what colour the client sees — so they refuse at load
# like their siblings above.

test_that("junk dashboard_scale_mean refuses instead of silently becoming 10", {
  raw <- list(dashboard_scale_mean = "five")
  obj <- suppressWarnings(build_config_object(raw))
  # The silent substitution that makes this invisible without validation:
  expect_equal(obj$dashboard_scale_mean, 10)
  err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
  expect_false(is.null(err))
  expect_match(conditionMessage(err), "dashboard_scale_mean")
  expect_match(conditionMessage(err), "five", fixed = TRUE)
})

test_that("junk gauge thresholds refuse, naming the cell", {
  for (key in c("dashboard_green_mean", "dashboard_amber_mean",
                "dashboard_green_index", "dashboard_amber_index",
                "dashboard_green_net", "dashboard_amber_net",
                "dashboard_green_custom", "dashboard_amber_custom",
                "dashboard_scale_index")) {
    raw <- setNames(list("seven-ish"), key)
    obj <- suppressWarnings(build_config_object(raw))
    err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
    expect_false(is.null(err), info = paste(key, "did not refuse"))
    expect_match(conditionMessage(err), key)
  }
})

test_that("a scale maximum of zero or below refuses (it normalises every gauge)", {
  for (v in list(0, -5)) {
    raw <- list(dashboard_scale_mean = v)
    obj <- build_config_object(raw)
    expect_error(validate_config_settings(obj, raw), class = "turas_refusal",
                 info = paste("scale", v, "did not refuse"))
  }
})

test_that("blank and absent dashboard cells still take the default without complaint", {
  # A cleared cell means "use the default", not "refuse" — these settings are
  # optional and most configs never carry them.
  expect_true(validate_config_settings(build_config_object(list()), list()))
  for (v in list("", "  ", NA)) {
    raw <- list(dashboard_scale_mean = v, dashboard_green_mean = v)
    obj <- suppressWarnings(build_config_object(raw))
    expect_true(validate_config_settings(obj, raw),
                info = paste("blank-ish value refused:", format(v)))
    expect_equal(obj$dashboard_scale_mean, 10)
  }
})

test_that("real dashboard values validate and reach config_obj intact", {
  raw <- list(dashboard_scale_mean = 5, dashboard_green_mean = 4,
              dashboard_amber_mean = 3, dashboard_amber_net = -10)
  obj <- build_config_object(raw)
  expect_true(validate_config_settings(obj, raw))
  expect_equal(obj$dashboard_scale_mean, 5)
  expect_equal(obj$dashboard_green_mean, 4)
  # A NET threshold is a percentage-point difference and may legitimately be
  # negative — the range rule applies to scale maxima only.
  expect_equal(obj$dashboard_amber_net, -10)
})

test_that("junk significance_min_base refuses, so low_base_threshold is never null", {
  # The island's low_base_threshold is read straight off this setting
  # (data_layer_writer.R build_dl_project). A junk cell would carry NA into it
  # and silently disarm every low-base flag in the v2 report; the refusal here
  # is what makes that unreachable.
  raw <- list(significance_min_base = "thirty")
  obj <- suppressWarnings(build_config_object(raw))
  expect_true(is.na(obj$significance_min_base))
  err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
  expect_false(is.null(err))
  expect_match(conditionMessage(err), "significance_min_base")
  # A valid setting reaches config_obj as a usable number.
  ok <- build_config_object(list(significance_min_base = 50))
  expect_true(validate_config_settings(ok))
  expect_equal(ok$significance_min_base, 50)
})

context("config contract — sampling_method (I5)")

test_that("case slips normalise to the canonical token", {
  obj <- build_config_object(list(sampling_method = "stratified"))
  expect_equal(obj$sampling_method, "Stratified")
  expect_true(validate_config_settings(obj))
  obj2 <- build_config_object(list(sampling_method = " CENSUS "))
  expect_equal(obj2$sampling_method, "Census")
  obj3 <- build_config_object(list(sampling_method = "online panel"))
  expect_equal(obj3$sampling_method, "Online_Panel")
})

test_that("an unrecognised sampling_method refuses rather than softening the vocabulary", {
  obj <- build_config_object(list(sampling_method = "Simple Random"))
  expect_error(validate_config_settings(obj), class = "turas_refusal")
})

test_that("blank/absent stays Not_Specified without complaint", {
  expect_equal(build_config_object(list())$sampling_method, "Not_Specified")
  expect_equal(build_config_object(list(sampling_method = ""))$sampling_method, "Not_Specified")
})

context("config contract — formerly dead settings now act (I9)")

test_that("index summary and ranking settings carry into config_obj", {
  cfg <- list(create_index_summary = "N", index_summary_decimal_places = 2,
              ranking_tie_threshold_pct = 7, decimal_places = 3,
              project_name = "My Study")
  obj <- build_config_object(cfg)
  expect_equal(obj$create_index_summary, "N")
  expect_equal(obj$index_summary_decimal_places, 2)
  expect_equal(obj$ranking_tie_threshold_pct, 7)
  expect_equal(obj$decimal_places, 3)
  expect_equal(obj$project_name, "My Study")
})

test_that("absent optional settings stay NULL so consumer defaults hold", {
  obj <- build_config_object(list())
  expect_null(obj$create_index_summary)
  expect_null(obj$index_summary_show_composites)
  expect_null(obj$ranking_tie_threshold_pct)
  expect_null(obj$decimal_places)
})

context("config contract — explicit v2 opt-out (I16)")

test_that("html_report_v2_explicit marks whether the sheet set the value", {
  expect_true(build_config_object(list(html_report_v2 = "FALSE"))$html_report_v2_explicit)
  expect_false(build_config_object(list())$html_report_v2_explicit)
  expect_false(build_config_object(list(html_report_v2 = "FALSE"))$html_report_v2)
})

context("config contract — retired settings are named, not ignored (classic report)")

test_that("a config still carrying html_report is answered by name", {
  out <- capture.output(announce_retired_settings(list(html_report = "TRUE")))
  txt <- paste(out, collapse = " ")
  expect_match(txt, "SETTING RETIRED")
  expect_match(txt, "html_report")
  expect_match(txt, "html_report_v2", fixed = TRUE)
})

test_that("case and whitespace do not hide a retired setting", {
  expect_equal(announce_retired_settings(list(` HTML_Report ` = "Y")), "html_report")
})

test_that("a config without the retired setting prints nothing", {
  expect_equal(capture.output(announce_retired_settings(list(alpha = 0.05))), character(0))
})

test_that("the retired setting is out of the whitelist but never reported as a typo", {
  # It must not be blessed as a working setting...
  expect_false("html_report" %in% TABS_KNOWN_SETTINGS)
  # ...and must not fall into the unrecognised-typo list while retirement runs.
  unknown <- setdiff("html_report",
                     c(TABS_KNOWN_SETTINGS, names(TABS_RETIRED_SETTINGS)))
  expect_equal(unknown, character(0))
})

test_that("the retired setting no longer reaches config_obj", {
  obj <- suppressWarnings(build_config_object(list(html_report = "TRUE")))
  expect_null(obj$html_report)
})
