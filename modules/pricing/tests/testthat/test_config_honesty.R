# ==============================================================================
# TURAS PRICING MODULE - CONFIG HONESTY TESTS (review H1, H2, M6, M7, M8, M9, M11)
# ==============================================================================
# The shipped template could not run either headline method because the
# VanWestendorp and GaborGranger loaders never mapped Title_Case names onto
# the lowercase names the engine reads; list separators disagreed three ways;
# unknown and duplicated settings were swallowed. Every test here fails on
# the code as it stood on 2026-09-03 before Session A.
# ==============================================================================

skip_if(!exists("load_pricing_config", mode = "function"), "config loader not available")

.saver <- function() {
  if (exists("turas_saveWorkbook", mode = "function")) return(turas_saveWorkbook)
  function(wb, file, overwrite = TRUE) openxlsx::saveWorkbook(wb, file, overwrite = overwrite)
}

# A config workbook from named Setting/Value sheets, headers in row 1.
write_config_wb <- function(path, sheets) {
  wb <- openxlsx::createWorkbook()
  for (nm in names(sheets)) {
    df <- sheets[[nm]]
    openxlsx::addWorksheet(wb, nm)
    openxlsx::writeData(wb, nm, df)
  }
  .saver()(wb, path, overwrite = TRUE)
  path
}

sv <- function(...) {
  kv <- c(...)
  data.frame(Setting = names(kv), Value = unname(kv), stringsAsFactors = FALSE)
}

base_settings <- function(method = "both", ...) {
  sv(Project_Name = "T", Analysis_Method = method, Data_File = "x.csv",
     Output_File = "out.xlsx", Currency_Symbol = "R", ...)
}
vw_sheet <- function() sv(Col_Too_Cheap = "tc", Col_Cheap = "ch", Col_Expensive = "ex",
                          Col_Too_Expensive = "te", Calculate_Confidence = "FALSE")
gg_sheet <- function(prices = "60;80;100", cols = "g60;g80;g100") {
  sv(Data_Format = "wide", Price_Sequence = prices, Response_Columns = cols,
     Response_Type = "binary")
}

# ------------------------------------------------------------------------------
# H1: template-style names reach the engine
# ------------------------------------------------------------------------------

test_that("a template-shaped config populates the lowercase VW and GG keys (H1)", {
  tmp <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp))
  write_config_wb(tmp, list(Settings = base_settings(), VanWestendorp = vw_sheet(),
                            GaborGranger = gg_sheet()))
  cfg <- load_pricing_config(tmp)
  expect_equal(cfg$van_westendorp$col_too_cheap, "tc")
  expect_equal(cfg$van_westendorp$col_too_expensive, "te")
  expect_false(isTRUE(cfg$van_westendorp$calculate_confidence))
  expect_equal(cfg$gabor_granger$data_format, "wide")
  expect_equal(cfg$gabor_granger$price_sequence, c(60, 80, 100))
  expect_equal(cfg$gabor_granger$response_columns, c("g60", "g80", "g100"))
})

test_that("the generated template loads and every VW/GG key is lowercase (H1 round trip)", {
  shared_styles <- file.path(TURAS_ROOT, "modules", "shared", "template_styles.R")
  gen <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "generate_config_templates.R")
  skip_if(!file.exists(shared_styles) || !file.exists(gen), "template generator not available")
  source(shared_styles)
  gen_code <- readLines(gen)
  gen_code <- sub('^\\.find_shared_template_styles <- function\\(\\) \\{',
                  sprintf('.find_shared_template_styles <- function() { return("%s")',
                          gsub("\\\\", "/", shared_styles)), gen_code)
  tmp_gen <- tempfile(fileext = ".R"); writeLines(gen_code, tmp_gen)
  source(tmp_gen, local = FALSE); unlink(tmp_gen)

  tmp <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp))
  capture.output(generate_pricing_config_template(tmp))

  out <- capture.output(cfg <- load_pricing_config(tmp))
  # Nothing the template writes is unknown to the loader, and nothing retired.
  expect_false(any(grepl("does not read", out, fixed = TRUE)), info = paste(out, collapse = "\n"))
  expect_true(all(c("col_too_cheap", "col_cheap", "col_expensive", "col_too_expensive") %in%
                    names(cfg$van_westendorp)))
  # The template defaults to van_westendorp, so the GG sheet is not loaded;
  # load it directly to prove its names map too.
  gg <- load_gabor_granger_config(tmp)
  expect_true(all(c("data_format", "response_type", "smoothing_method", "binary_coding") %in% names(gg)))
  expect_false("Interpolation_Method" %in% openxlsx::read.xlsx(tmp, "VanWestendorp", skipEmptyRows = FALSE)[[1]])
  # The example rows never load as content (M11).
  expect_length(load_simulator_config(tmp), 0)
  expect_null(load_added_slides(tmp))
})

# ------------------------------------------------------------------------------
# H2: one list parser
# ------------------------------------------------------------------------------

test_that("semicolons and commas both parse, in every list (H2)", {
  expect_equal(.pricing_parse_list("60;80;100", numeric = TRUE), c(60, 80, 100))
  expect_equal(.pricing_parse_list("60, 80, 100", numeric = TRUE), c(60, 80, 100))
  expect_equal(.pricing_parse_list(" a ; b,c "), c("a", "b", "c"))
  expect_equal(.pricing_parse_list(c("Value", "Standard")), c("Value", "Standard"))
  expect_length(.pricing_parse_list(NA), 0)
  expect_length(.pricing_parse_list(NULL, numeric = TRUE), 0)

  tmp <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp))
  write_config_wb(tmp, list(Settings = base_settings(), VanWestendorp = vw_sheet(),
                            GaborGranger = gg_sheet(prices = "60,80,100", cols = "g60, g80, g100")))
  cfg <- load_pricing_config(tmp)
  expect_equal(cfg$gabor_granger$price_sequence, c(60, 80, 100))
  expect_equal(cfg$gabor_granger$response_columns, c("g60", "g80", "g100"))
})

test_that("a Price_Sequence that is not numbers refuses by name", {
  tmp <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp))
  write_config_wb(tmp, list(Settings = base_settings("gabor_granger"),
                            GaborGranger = gg_sheet(prices = "sixty;eighty")))
  expect_error(load_pricing_config(tmp), "CFG_GG_PRICE_SEQUENCE")
})

test_that("tier names accept commas as well as semicolons (H2, the ladder)", {
  skip_if(!exists("build_price_ladder", mode = "function"))
  expect_equal(.pricing_parse_list("Value, Standard, Premium"), c("Value", "Standard", "Premium"))
})

# ------------------------------------------------------------------------------
# M6: names are checked
# ------------------------------------------------------------------------------

test_that("a duplicated setting refuses instead of first-value-wins (M6)", {
  tmp <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp))
  s <- rbind(base_settings(), sv(Project_Name = "Second"))
  write_config_wb(tmp, list(Settings = s, VanWestendorp = vw_sheet(), GaborGranger = gg_sheet()))
  expect_error(load_pricing_config(tmp), "CFG_DUPLICATE_SETTING")
})

test_that("a retired setting is refused by name (M7, M9)", {
  tmp <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp))
  write_config_wb(tmp, list(Settings = base_settings("van_westendorp"),
                            VanWestendorp = rbind(vw_sheet(), sv(Interpolation_Method = "spline"))))
  expect_error(load_pricing_config(tmp), "CFG_RETIRED_SETTING")

  tmp2 <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp2), add = TRUE)
  write_config_wb(tmp2, list(Settings = base_settings("van_westendorp"), VanWestendorp = vw_sheet(),
                             Validation = sv(Min_Sample = "30", Flag_Outliers = "TRUE")))
  expect_error(load_pricing_config(tmp2), "CFG_RETIRED_SETTING")
})

test_that("an unknown setting name prints a warning naming it (M6)", {
  tmp <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp))
  write_config_wb(tmp, list(Settings = base_settings("van_westendorp", Colour_Of_Bike = "red"),
                            VanWestendorp = vw_sheet()))
  out <- capture.output(cfg <- load_pricing_config(tmp))
  expect_true(any(grepl("does not read", out) & grepl("Colour_Of_Bike", out)))
})

test_that("a section divider with a parenthetical note is not read as a setting (M6)", {
  df <- data.frame(
    Setting = c("WIDE FORMAT SETTINGS (use if Data_Format = wide)", "SEGMENTATION",
                "Price_Sequence", "N_Tiers"),
    Value = c(NA, NA, "60;80", NA),
    stringsAsFactors = FALSE
  )
  out <- .clean_settings_df(df)
  expect_equal(out$Setting, c("Price_Sequence", "N_Tiers"))
})

# ------------------------------------------------------------------------------
# Behaviour settings validate their values
# ------------------------------------------------------------------------------

test_that("VW_Monotonicity_Behavior defaults to drop and refuses an unknown value (H3)", {
  cfg <- apply_pricing_defaults(list(analysis_method = "van_westendorp"))
  expect_equal(cfg$vw_monotonicity_behavior, "drop")
  expect_error(apply_pricing_defaults(list(analysis_method = "van_westendorp",
                                           vw_monotonicity_behavior = "ignore")),
               "CFG_VW_MONOTONICITY_BEHAVIOR")
})

test_that("GG_Stop_Early_Imputation accepts NONE and NO_AFTER_STOP only (C2)", {
  expect_equal(apply_pricing_defaults(list(analysis_method = "gabor_granger"))$gg_stop_early_imputation, "NONE")
  expect_equal(apply_pricing_defaults(list(analysis_method = "gabor_granger",
                                           gg_stop_early_imputation = "no_after_stop"))$gg_stop_early_imputation,
               "NO_AFTER_STOP")
  expect_error(apply_pricing_defaults(list(analysis_method = "gabor_granger",
                                           gg_stop_early_imputation = "guess")),
               "CFG_GG_STOP_EARLY_IMPUTATION")
})

test_that("the tabs export settings are accepted, and still need an id to join on", {
  # Session B built the exporter (15_tabs_export.R), so these settings now do
  # what they say. What they will not do is join on row order: without
  # ID_Variable the config refuses before any file is written.
  expect_error(apply_pricing_defaults(list(analysis_method = "gabor_granger", generate_tabs_export = "Y")),
               "CFG_TABS_EXPORT_NO_ID")
  expect_error(apply_pricing_defaults(list(analysis_method = "gabor_granger", export_wtp = "Y")),
               "CFG_TABS_EXPORT_NO_ID")
  on <- apply_pricing_defaults(list(analysis_method = "gabor_granger",
                                    generate_tabs_export = "Y", id_var = "RespID"))
  expect_true(on$generate_tabs_export)
  expect_equal(on$tabs_question_code, "GGACC")
  expect_false(apply_pricing_defaults(list(analysis_method = "gabor_granger"))$generate_tabs_export)
})

test_that("Generate_Stats_Pack reaches the flat config (H8)", {
  cfg <- .normalize_setting_names(list(Generate_Stats_Pack = "N"))
  expect_equal(cfg$generate_stats_pack, "N")
  expect_equal(apply_pricing_defaults(list(analysis_method = "van_westendorp"))$generate_stats_pack, "Y")
})

# ------------------------------------------------------------------------------
# M8: Min_Sample is enforced. M2: violations are returned.
# ------------------------------------------------------------------------------

vw_config <- function(behavior = "drop", min_sample = NA) {
  list(
    analysis_method = "van_westendorp", weight_var = NA_character_, dk_codes = numeric(0),
    van_westendorp = list(col_too_cheap = "too_cheap", col_cheap = "cheap",
                          col_expensive = "expensive", col_too_expensive = "too_expensive",
                          validate_monotonicity = TRUE, violation_threshold = 0.5),
    vw_monotonicity_behavior = behavior,
    validation = list(min_completeness = 0.8, min_sample = min_sample,
                      price_min = 0, price_max = 10000)
  )
}

test_that("Min_Sample refuses a run with too few valid respondents (M8)", {
  d <- generate_vw_data(n = 12)
  expect_error(validate_pricing_data(d, vw_config(min_sample = 30)), "DATA_MIN_SAMPLE")
  expect_silent_ish <- validate_pricing_data(d, vw_config(min_sample = 5))
  expect_true(expect_silent_ish$n_valid >= 5)
})

test_that("validate_pricing_data returns monotonicity_violations so the Excel block renders (M2)", {
  d <- generate_vw_data(n = 100)  # 10% swapped by the generator
  v <- validate_pricing_data(d, vw_config("flag_only"))
  expect_false(is.null(v$monotonicity_violations))
  expect_true(v$monotonicity_violations$n_violations > 0)
  expect_equal(v$monotonicity_violations$behavior, "flag_only")
  expect_true(any(grepl("retained in the curves", unlist(v$warnings))))
  expect_false(any(grepl("flagged but retained", unlist(v$warnings))))
})

test_that("the monotonicity rule is strict, as pricesensitivitymeter's is (H3)", {
  r <- check_vw_monotonicity(too_cheap = c(10, 10), cheap = c(10, 20),
                             expensive = c(30, 30), too_expensive = c(40, 40))
  expect_equal(r$count, 1L)
  expect_equal(r$violation_indices, 1L)
})
