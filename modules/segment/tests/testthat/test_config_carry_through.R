# H3 - settings that vanished between the config sheet and the run.
#
# validate_segment_config rebuilds its output from explicit lists, so any key
# not enumerated there disappears silently. Two documented controls were dead
# because of it: generate_stats_pack (so the stats pack always generated,
# whatever the template or the GUI checkbox said) and research_house (so the
# Declaration sheet never got the name the user typed).
#
# The mechanism matters more than the two settings. Any future knob added to
# the template and not to the enumeration goes the same way, silently, which
# is why the last test here is about the warning rather than about a setting.

.carry_through_config <- function(...) {
  d <- data.frame(respondent_id = 1:40, q1 = rnorm(40), q2 = rnorm(40), q3 = rnorm(40))
  path <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(d, path)
  utils::modifyList(
    list(data_file = path, id_variable = "respondent_id",
         clustering_vars = "q1,q2,q3", k_fixed = "3", method = "kmeans"),
    list(...)
  )
}

test_that("generate_stats_pack survives validation and can say N (H3a)", {
  v <- suppressWarnings(capture.output(
    cfg <- validate_segment_config(.carry_through_config(generate_stats_pack = "N"))))

  expect_false(is.null(cfg$generate_stats_pack))
  expect_equal(toupper(as.character(cfg$generate_stats_pack)), "N")
})

test_that("generate_stats_pack defaults to Y when unset (H3a)", {
  capture.output(cfg <- validate_segment_config(.carry_through_config()))
  expect_equal(toupper(as.character(cfg$generate_stats_pack %||% "Y")), "Y")
})

test_that("the N in the config actually switches the stats pack off (H3a)", {
  # Through the real parser and the real decision helper, with no GUI option
  # set: the earlier version of this test evaluated a copied expression
  # against a hand-built list and called no module code at all (independent
  # review 2026-09-21, F7).
  old <- getOption("turas.generate_stats_pack", NULL)
  on.exit(options(turas.generate_stats_pack = old), add = TRUE)
  options(turas.generate_stats_pack = NULL)

  capture.output(cfg <- validate_segment_config(.carry_through_config(generate_stats_pack = "N")))
  expect_false(segment_should_write_stats_pack(cfg))

  capture.output(cfg_y <- validate_segment_config(.carry_through_config(generate_stats_pack = "Y")))
  expect_true(segment_should_write_stats_pack(cfg_y))
})

test_that("research_house survives validation (H3b)", {
  capture.output(
    cfg <- validate_segment_config(.carry_through_config(research_house = "The Research LampPost")))

  expect_equal(cfg$research_house, "The Research LampPost")
})

test_that("a setting that does not survive validation is named on the console (H3)", {
  # The systemic half. A key the enumeration does not know about must not
  # disappear in silence, whatever it is.
  out <- capture.output(
    suppressWarnings(validate_segment_config(.carry_through_config(a_knob_nobody_wired = "7"))))

  joined <- paste(out, collapse = " ")
  expect_true(grepl("a_knob_nobody_wired", joined))
})

test_that("a clean config warns about nothing (H3)", {
  out <- capture.output(cfg <- validate_segment_config(.carry_through_config()))
  joined <- paste(out, collapse = " ")
  expect_false(grepl("did not survive|not carried|ignored setting", joined, ignore.case = TRUE))
})

test_that("an unticked GUI checkbox can switch the stats pack off (H3a)", {
  # The GUI sets options(turas.generate_stats_pack = ...) on every run. Read
  # with a FALSE default and OR'd against the config, an unticked box could
  # only ever be ignored: the config's "Y" default won, and the pack
  # generated anyway. Whoever set the option last is the person who just
  # clicked something, so when it is set it decides.
  old <- getOption("turas.generate_stats_pack", NULL)
  on.exit(options(turas.generate_stats_pack = old), add = TRUE)

  options(turas.generate_stats_pack = FALSE)
  expect_false(segment_should_write_stats_pack(list(generate_stats_pack = "Y")))

  options(turas.generate_stats_pack = TRUE)
  expect_true(segment_should_write_stats_pack(list(generate_stats_pack = "N")))

  options(turas.generate_stats_pack = NULL)
  expect_false(segment_should_write_stats_pack(list(generate_stats_pack = "N")))
  expect_true(segment_should_write_stats_pack(list(generate_stats_pack = "Y")))
  expect_true(segment_should_write_stats_pack(list()))
})


# ------------------------------------------------------------------------------
# D12: a config key carrying an invisible character silently did nothing.
#
# Keys were taken from the cell exactly as typed. A zero-width space or a
# non-breaking space looks identical to a correct key in Excel and in every
# message printed about it, but it does not match, so get_config_value() fell
# through to the default and the setting did nothing. The unused-settings
# warning then named a key that looked perfectly spelled, which is how this
# was found (independent review 2026-09-22).
# ------------------------------------------------------------------------------

.d12_config_with_key <- function(key, value = "Y") {
  n <- 300
  set.seed(1)
  g <- rep(1:3, length.out = n)
  d <- data.frame(respondent_id = sprintf("R%03d", seq_len(n)),
                  q1 = rnorm(n, g), q2 = rnorm(n, -g), q3 = rnorm(n, g * 2),
                  stringsAsFactors = FALSE)
  dpath <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(d, dpath, sheetName = "Data")

  base <- list(data_file = dpath, data_sheet = "Data", id_variable = "respondent_id",
               clustering_vars = "q1,q2,q3", k_fixed = "3", method = "kmeans")
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Config")
  openxlsx::writeData(wb, "Config", data.frame(
    Setting = c(names(base), key),
    Value = c(unlist(lapply(base, as.character)), value),
    stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

test_that("an invisible character in a config key does not silently disable it", {
  # Each of these prints as "tabs_export" and used to read as N.
  keys <- c("tabs_export​",   # zero-width space at the end
            "​tabs_export",   # zero-width space at the front
            "tabs_​export",   # zero-width space in the middle
            "tabs_export ",   # non-breaking space, which trimws leaves
            " tabs_export",
            "﻿tabs_export")   # byte-order mark

  for (k in keys) {
    path <- .d12_config_with_key(k, "Y")
    raw <- read_segment_config(path)
    capture.output(cfg <- validate_segment_config(raw))

    expect_equal(toupper(as.character(cfg$tabs_export)), "Y",
                 info = sprintf("key with codepoints %s",
                                paste(utf8ToInt(k), collapse = ",")))
    capture.output(unused <- segment_warn_unused_settings(raw, cfg))
    expect_length(unused, 0L)
  }
})

test_that("a key that is genuinely wrong is still named, and its near match given", {
  # Case is left alone on purpose: a key that differs in case is a real
  # mistake, and the warning should say so rather than quietly accept it.
  path <- .d12_config_with_key("Tabs_Export", "Y")
  raw <- read_segment_config(path)
  capture.output(cfg <- validate_segment_config(raw))

  # It did not take effect.
  expect_equal(toupper(as.character(cfg$tabs_export)), "N")
  out <- capture.output(unused <- segment_warn_unused_settings(raw, cfg))
  expect_equal(unused, "Tabs_Export")
  expect_true(any(grepl("did you mean 'tabs_export'", out, fixed = TRUE)))
})

test_that("the key cleaner leaves a correct key untouched", {
  expect_equal(.turas_clean_config_key("tabs_export"), "tabs_export")
  expect_equal(.turas_clean_config_key("k_fixed"), "k_fixed")
  expect_equal(.turas_clean_config_key("Tabs_Export"), "Tabs_Export")
  # And it does not merge two genuinely different keys.
  expect_false(identical(.turas_clean_config_key("tabs-export"),
                         .turas_clean_config_key("tabs_export")))
})
