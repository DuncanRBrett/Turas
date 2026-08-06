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

# ==============================================================================
# CONFIG HONESTY (production review 2026-08, I2 / I3 / I4)
# ==============================================================================
#
# The class these pin: a Settings cell the loader could not read became the
# DEFAULT, silently. Three shapes of it —
#   I2  population_size = "5,000" parsed to NULL, so the finite population
#       correction switched off on a census project; every interval widened and
#       letters could change, with nothing printed anywhere.
#   I3  apply_weighting = junk warned one scrollback line and ran the whole
#       study unweighted (and every weight preflight check skipped, because they
#       gate on the parsed FALSE); generate_stats_pack = "TRUE" failed the
#       consumer's exact `== "Y"` test and dropped a contractual deliverable;
#       junk alpha_secondary switched dual significance off.
#   I4  the qualitative dials are compared with identical(), so an unrecognised
#       token fell through to the PERMISSIVE branch: "Block" meant allow,
#       "Noteworthy" meant show every verbatim. A dial set to close a gate
#       opened it. And "safe" with the default min_reporting_base = 1
#       anonymises nothing, while reading as protected.
#
# The contract: a blank cell still means "use the default", silently; anything
# else is either canonical or refuses at load, naming the cell.
# ==============================================================================

context("config honesty — population_size (I2)")

test_that("junk population_size refuses instead of silently disabling the FPC", {
  raw <- list(population_size = "5,000")
  obj <- suppressWarnings(build_config_object(raw))
  # The silent substitution that makes this invisible without validation:
  expect_null(obj$population_size)
  err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
  expect_false(is.null(err))
  expect_match(conditionMessage(err), "population_size")
  expect_match(conditionMessage(err), "5,000", fixed = TRUE)
})

test_that("a population_size of 1 or below refuses (the template says > 1)", {
  for (v in list(1, 0, -20)) {
    raw <- list(population_size = v)
    obj <- build_config_object(raw)
    expect_null(obj$population_size)
    expect_error(validate_config_settings(obj, raw), class = "turas_refusal",
                 info = paste("population_size", v, "did not refuse"))
  }
})

test_that("a real population_size validates and reaches config_obj", {
  raw <- list(population_size = 5000)
  obj <- build_config_object(raw)
  expect_true(validate_config_settings(obj, raw))
  expect_equal(obj$population_size, 5000)
  # A string cell (every Settings cell arrives as one) parses the same way.
  raw2 <- list(population_size = "5000")
  obj2 <- build_config_object(raw2)
  expect_true(validate_config_settings(obj2, raw2))
  expect_equal(obj2$population_size, 5000)
})

test_that("blank/absent population_size stays NULL without complaint", {
  for (raw in list(list(), list(population_size = ""),
                   list(population_size = "  "), list(population_size = "NA"))) {
    obj <- build_config_object(raw)
    expect_null(obj$population_size)
    expect_true(validate_config_settings(obj, raw))
  }
})

context("config honesty — Y/N toggles refuse instead of defaulting (I3)")

test_that("junk apply_weighting refuses rather than running the study unweighted", {
  raw <- list(apply_weighting = "Yes please")
  obj <- suppressWarnings(build_config_object(raw))
  # The silent substitution: a weighted study runs unweighted, and every weight
  # preflight check skips because it gates on this FALSE.
  expect_false(obj$apply_weighting)
  err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
  expect_false(is.null(err))
  expect_match(conditionMessage(err), "apply_weighting")
  expect_match(conditionMessage(err), "Yes please", fixed = TRUE)
})

test_that("every safe_logical setting is covered, and each refuses on junk", {
  # Drift guard: a toggle added to build_config_object without joining
  # .TABS_LOGICAL_SETTINGS would silently default again.
  src <- readLines(CONFIG_SRC)
  start <- grep("^build_config_object <- function", src)
  end <- grep("^#' Is a raw Settings cell blank", src)[1]
  body <- paste(src[start:(end - 1)], collapse = "\n")
  m <- gregexpr('safe_logical\\(\\s*(raw|get_config_value\\(config, "[a-z_0-9]+")', body)
  hits <- regmatches(body, m)[[1]]
  named <- unique(gsub('.*get_config_value\\(config, "([a-z_0-9]+)".*', "\\1",
                       grep("get_config_value", hits, value = TRUE)))
  expect_gt(length(named), 30)
  expect_equal(setdiff(named, .TABS_LOGICAL_SETTINGS), character(0),
               info = "read through safe_logical but not in .TABS_LOGICAL_SETTINGS")

  for (key in .TABS_LOGICAL_SETTINGS) {
    raw <- setNames(list("sometimes"), key)
    obj <- suppressWarnings(build_config_object(raw))
    err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
    expect_false(is.null(err), info = paste(key, "did not refuse"))
    expect_match(conditionMessage(err), key)
  }
})

test_that("the whole yes/no vocabulary is accepted, in any case", {
  for (v in c("Y", "y", "Yes", "TRUE", "true", "T", "1", " YES ")) {
    raw <- list(apply_weighting = v)
    obj <- build_config_object(raw)
    expect_true(obj$apply_weighting, info = paste("value:", v))
    expect_true(validate_config_settings(obj, raw), info = paste("value:", v))
  }
  for (v in c("N", "n", "No", "FALSE", "false", "F", "0")) {
    raw <- list(apply_weighting = v)
    obj <- build_config_object(raw)
    expect_false(obj$apply_weighting, info = paste("value:", v))
    expect_true(validate_config_settings(obj, raw), info = paste("value:", v))
  }
  # A real logical (the internal callers pass these) is not a Settings cell typo.
  raw <- list(apply_weighting = TRUE, show_frequency = FALSE)
  expect_true(validate_config_settings(build_config_object(raw), raw))
})

test_that("blank toggles take the default silently", {
  for (v in list("", "  ", "NA", NA)) {
    raw <- list(html_report_v2_microdata = v, apply_weighting = v)
    obj <- suppressWarnings(build_config_object(raw))
    expect_true(validate_config_settings(obj, raw),
                info = paste("blank-ish value refused:", format(v)))
    # The confidentiality default holds: only an explicit no drops the island.
    expect_true(obj$html_report_v2_microdata)
  }
})

test_that("junk in a confidentiality toggle refuses rather than defaulting ON", {
  raw <- list(html_report_v2_microdata = "aggregates only")
  obj <- suppressWarnings(build_config_object(raw))
  expect_true(obj$html_report_v2_microdata)   # the silent default it used to take
  expect_error(validate_config_settings(obj, raw), class = "turas_refusal")
})

context("config honesty — generate_stats_pack and create_index_summary (I3)")

test_that("generate_stats_pack = TRUE no longer switches the stats pack off", {
  # The consumer (run_crosstabs.R) tests toupper(...) == "Y" exactly, so "TRUE"
  # used to mean "no stats pack" — a contractual deliverable dropped in silence.
  obj <- build_config_object(list(generate_stats_pack = "TRUE"))
  expect_equal(obj$generate_stats_pack, "Y")
  expect_true(toupper(obj$generate_stats_pack %||% "Y") == "Y")
  expect_true(validate_config_settings(obj))
  for (v in c("yes", "y", "1", "T")) {
    expect_equal(build_config_object(list(generate_stats_pack = v))$generate_stats_pack, "Y")
  }
  for (v in c("N", "no", "FALSE", "0")) {
    expect_equal(build_config_object(list(generate_stats_pack = v))$generate_stats_pack, "N")
  }
})

test_that("an unreadable generate_stats_pack refuses, naming the cell", {
  raw <- list(generate_stats_pack = "if time allows")
  obj <- build_config_object(raw)
  err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
  expect_false(is.null(err))
  expect_match(conditionMessage(err), "generate_stats_pack")
  expect_match(conditionMessage(err), "if time allows", fixed = TRUE)
})

test_that("generate_stats_pack defaults to Y and create_index_summary to NULL", {
  obj <- build_config_object(list())
  expect_equal(obj$generate_stats_pack, "Y")
  expect_null(obj$create_index_summary)
  expect_true(validate_config_settings(obj, list()))
  # create_index_summary canonicalises the same way when it is set.
  expect_equal(build_config_object(list(create_index_summary = "true"))$create_index_summary, "Y")
  expect_equal(build_config_object(list(create_index_summary = "n"))$create_index_summary, "N")
  raw <- list(create_index_summary = "only if composites")
  expect_error(validate_config_settings(build_config_object(raw), raw),
               class = "turas_refusal")
})

context("config honesty — numeric settings refuse instead of defaulting (I3)")

test_that("junk alpha_secondary refuses rather than disabling dual significance", {
  raw <- list(alpha_secondary = "ten percent")
  obj <- suppressWarnings(build_config_object(raw))
  # The silent substitution: NULL reads exactly like "feature not requested",
  # and validate_dual_significance_config returns early on NULL.
  expect_null(obj$alpha_secondary)
  expect_true(validate_dual_significance_config(obj))
  err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
  expect_false(is.null(err))
  expect_match(conditionMessage(err), "alpha_secondary")
})

test_that("a real alpha_secondary still enables the feature", {
  raw <- list(alpha_secondary = 0.10)
  obj <- build_config_object(raw)
  expect_equal(obj$alpha_secondary, 0.10)
  expect_true(validate_config_settings(obj, raw))
})

test_that("junk ranking thresholds and decimal_places refuse", {
  for (key in c("ranking_tie_threshold_pct", "ranking_gap_threshold_pct",
                "ranking_completeness_threshold_pct", "ranking_min_base",
                "decimal_places", "index_summary_decimal_places", "wave_order")) {
    raw <- setNames(list("about five"), key)
    obj <- suppressWarnings(build_config_object(raw))
    err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
    expect_false(is.null(err), info = paste(key, "did not refuse"))
    expect_match(conditionMessage(err), key)
  }
})

test_that("every safe_numeric setting is covered by .TABS_NUMERIC_SETTINGS", {
  src <- readLines(CONFIG_SRC)
  start <- grep("^build_config_object <- function", src)
  end <- grep("^#' Is a raw Settings cell blank", src)[1]
  body <- src[start:(end - 1)]
  named <- unique(unlist(lapply(grep("safe_numeric\\(get_config_value", body, value = TRUE),
                                function(l) gsub('.*get_config_value\\(config, "([a-z_0-9]+)".*', "\\1", l))))
  expect_gt(length(named), 10)
  expect_equal(setdiff(named, .TABS_NUMERIC_SETTINGS), character(0),
               info = "read through safe_numeric but not in .TABS_NUMERIC_SETTINGS")
})

context("config honesty — qualitative confidentiality dials (I4)")

test_that("a mis-cased dial no longer means the opposite of what it says", {
  # "Block" used to fall through every identical() test to "allow", shipping
  # every demographic tag on a report configured to ship none.
  obj <- build_config_object(list(qual_demographic_cuts = "Block",
                                  qual_verbatim_scope = "Noteworthy",
                                  qual_confidentiality_mode = "Redacted",
                                  qual_noteworthy_default = "Must Read"))
  expect_equal(obj$qual_demographic_cuts, "block")
  expect_equal(obj$qual_verbatim_scope, "noteworthy")
  expect_equal(obj$qual_confidentiality_mode, "redacted")
  expect_equal(obj$qual_noteworthy_default, "must_read")
  expect_true(validate_config_settings(obj))
})

test_that("an unknown dial token refuses rather than opening the gate", {
  for (raw in list(list(qual_demographic_cuts = "blocked"),
                   list(qual_verbatim_scope = "curated"),
                   list(qual_confidentiality_mode = "anonymised"),
                   list(qual_noteworthy_default = "top"))) {
    obj <- build_config_object(raw)
    err <- tryCatch({ validate_config_settings(obj, raw); NULL }, error = function(e) e)
    expect_false(is.null(err), info = paste(names(raw), "did not refuse"))
    expect_match(conditionMessage(err), names(raw)[1])
  }
})

test_that("the dials default to today's values and validate clean", {
  obj <- build_config_object(list())
  expect_equal(obj$qual_confidentiality_mode, "hidden")
  expect_equal(obj$qual_demographic_cuts, "allow")
  expect_equal(obj$qual_noteworthy_default, "all")
  expect_equal(obj$qual_verbatim_scope, "all")
  expect_true(validate_config_settings(obj))
  # A blank cell is not a typo.
  obj2 <- build_config_object(list(qual_demographic_cuts = "", qual_verbatim_scope = "NA"))
  expect_equal(obj2$qual_demographic_cuts, "allow")
  expect_equal(obj2$qual_verbatim_scope, "all")
  expect_true(validate_config_settings(obj2))
})

test_that("the dial tokens match the island builder's own constants", {
  # Drift guard: the config refuses against .TABS_QUAL_ENUMS, the island builds
  # against QUAL_TEXT_MODES / QUAL_VERBATIM_SCOPES / QUAL_NOTEWORTHY_DEFAULTS.
  # If they part company the config would refuse a token the island accepts.
  src <- readLines(file.path(tabs_lib, "qual_island_builder.R"))
  tokens_of <- function(const) {
    line <- grep(paste0("^", const, " <- c\\("), src, value = TRUE)
    expect_equal(length(line), 1L, info = const)
    unlist(strsplit(gsub('.*c\\((.*)\\).*', "\\1", line), ",\\s*"))
  }
  strip <- function(x) gsub('"', "", trimws(x))
  expect_equal(strip(tokens_of("QUAL_TEXT_MODES")), .TABS_QUAL_ENUMS$qual_confidentiality_mode)
  expect_equal(strip(tokens_of("QUAL_VERBATIM_SCOPES")), .TABS_QUAL_ENUMS$qual_verbatim_scope)
  expect_equal(strip(tokens_of("QUAL_NOTEWORTHY_DEFAULTS")), .TABS_QUAL_ENUMS$qual_noteworthy_default)
})

test_that("'safe' with the default k=1 warns that it is anonymising nothing", {
  raw <- list(qual_demographic_cuts = "safe", qual_workbook = "02 Data/Comments.xlsx")
  obj <- build_config_object(raw)
  out <- paste(capture.output(expect_true(validate_config_settings(obj, raw))),
               collapse = " ")
  expect_match(out, "min_reporting_base")
  expect_match(out, "anonymises nothing")
})

test_that("the warning is silent when k protects, when the dial is off, or with no workbook", {
  quiet <- function(raw) {
    obj <- build_config_object(raw)
    paste(capture.output(expect_true(validate_config_settings(obj, raw))), collapse = " ")
  }
  expect_equal(quiet(list(qual_demographic_cuts = "safe", min_reporting_base = 10,
                          qual_workbook = "02 Data/Comments.xlsx")), "")
  expect_equal(quiet(list(qual_demographic_cuts = "block",
                          qual_workbook = "02 Data/Comments.xlsx")), "")
  # No comment workbook -> the dial is inert, so the warning would be noise.
  expect_equal(quiet(list(qual_demographic_cuts = "safe")), "")
})
