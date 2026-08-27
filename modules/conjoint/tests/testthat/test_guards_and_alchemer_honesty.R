# ==============================================================================
# TESTS: GUARD LAYER WIRING AND ALCHEMER IMPORT HONESTY (H11, M6, M7)
# ==============================================================================

root <- Sys.getenv("TURAS_ROOT")
read_src <- function(...) paste(readLines(file.path(root, ...), warn = FALSE), collapse = "\n")

# ---------------------------------------------------------------------------
# H11 — the guard layer had no production caller
# ---------------------------------------------------------------------------

test_that("H11: the config and data guards are called by the pipeline", {
  main <- read_src("modules", "conjoint", "R", "00_main.R")

  for (fn in c("validate_conjoint_config(config)",
               "validate_conjoint_attributes(config$attributes)",
               "validate_wtp_config(config, config$attributes)",
               "validate_html_config(config)",
               "guard_check_data_exists(data_list$data)")) {
    expect_true(grepl(fn, main, fixed = TRUE), info = fn)
  }
})

test_that("H11: the attribute guard counts levels the way the loader stores them", {
  # It counted rows per attribute, which assumes a long-format Attributes
  # sheet. The loader builds it wide, so every valid config was reported as
  # having one level per attribute.
  wide <- data.frame(
    AttributeName = c("Brand", "Price"),
    NumLevels = c(3L, 2L),
    LevelNames = c("Alpha, Beta, Gamma", "$10, $20"),
    stringsAsFactors = FALSE
  )
  expect_true(validate_conjoint_attributes(wide))

  # And with the parsed list column the loader also provides.
  wide$levels_list <- list(c("Alpha", "Beta", "Gamma"), c("$10", "$20"))
  expect_true(validate_conjoint_attributes(wide))
})

test_that("H11: an attribute with one level is still caught", {
  bad <- data.frame(
    AttributeName = c("Brand", "Price"),
    NumLevels = c(1L, 2L),
    LevelNames = c("Alpha", "$10, $20"),
    stringsAsFactors = FALSE
  )

  cond <- tryCatch({ validate_conjoint_attributes(bad); NULL },
                   turas_refusal = function(e) e)

  expect_false(is.null(cond))
  expect_equal(cond$code, "CFG_INSUFFICIENT_LEVELS")
})

test_that("H11: the WTP guard tolerates an unset price attribute", {
  # is.na(NULL) is logical(0) and if (logical(0)) is an error, so this guard
  # would have crashed on every config that leaves the setting blank.
  attrs <- data.frame(AttributeName = c("Brand", "Price"),
                      stringsAsFactors = FALSE)

  expect_true(validate_wtp_config(list(wtp_price_attribute = NULL), attrs))
  expect_true(validate_wtp_config(list(wtp_price_attribute = ""), attrs))
  expect_true(validate_wtp_config(list(wtp_price_attribute = "Price"), attrs))
})

test_that("H11: the HTML guard tolerates unset colours and still catches bad ones", {
  expect_true(validate_html_config(list()))
  expect_true(validate_html_config(list(brand_colour = "#323367",
                                        accent_colour = "#CC9900")))

  cond <- tryCatch({ validate_html_config(list(brand_colour = "navy")); NULL },
                   turas_refusal = function(e) e)
  expect_false(is.null(cond))
  expect_equal(cond$code, "CFG_HTML_INVALID_COLOUR")
})

test_that("H11: the dead design guard is gone", {
  # It validated a Design sheet this module has no concept of, and had neither
  # a caller nor a test.
  expect_false(exists("validate_conjoint_design", mode = "function"))
})

# ---------------------------------------------------------------------------
# M6 — Alchemer import
# ---------------------------------------------------------------------------

test_that("M6: the score scale that was chosen is reported", {
  out01 <- capture.output(normalize_score_column(c(0, 1, 0, 1)), type = "output")
  expect_true(any(grepl("0/1 indicator", out01, fixed = TRUE)))

  out100 <- capture.output(normalize_score_column(c(0, 100, 0, 100)), type = "output")
  expect_true(any(grepl("0-100 scale", out100, fixed = TRUE)))

  outodd <- capture.output(normalize_score_column(c(0, 7, 0, 3)), type = "output")
  expect_true(any(grepl("matches no known Alchemer scale", outodd, fixed = TRUE)))
})

test_that("M6: a -1/0/1 best-worst coding refuses rather than discarding the worsts", {
  cond <- tryCatch({ normalize_score_column(c(-1, 0, 1, 0)); NULL },
                   turas_refusal = function(e) e)

  expect_false(is.null(cond))
  expect_equal(cond$code, "DATA_ALCHEMER_SIGNED_SCORES")
  expect_true(any(grepl("best-worst", cond$how_to_fix, fixed = TRUE)))
})

test_that("M6: normal 0/1 scores still normalise correctly", {
  expect_equal(suppressWarnings(capture.output(
    r <- normalize_score_column(c(0, 1, 1, 0)), type = "output")) |> length() > 0, TRUE)
  expect_equal(r, c(0L, 1L, 1L, 0L))
})

test_that("M6: level cleaning reports the old-to-new mapping, not just a count", {
  src <- read_src("modules", "conjoint", "R", "05_alchemer_import.R")
  expect_true(grepl("CONJ_ALCH_LEVELS_CLEANED", src, fixed = TRUE))
  expect_true(grepl("CONJ_ALCH_LEVELS_COLLAPSED", src, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# M7 — default_customers
# ---------------------------------------------------------------------------

test_that("M7: default_customers reaches the config object", {
  cfg <- read_src("modules", "conjoint", "R", "01_config.R")
  expect_true(grepl("default_customers = safe_numeric(settings_list$default_customers",
                    cfg, fixed = TRUE))

  # The report transformer and the revenue panel's JS already read it.
  tr <- read_src("modules", "conjoint", "lib", "html_report", "01_data_transformer.R")
  expect_true(grepl("config$default_customers", tr, fixed = TRUE))
})
