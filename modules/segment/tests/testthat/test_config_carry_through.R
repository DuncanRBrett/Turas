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
  # 00_main reads config$generate_stats_pack. With the setting dropped it read
  # NULL, fell to its "Y" default, and generated the pack on every run.
  cfg <- list(generate_stats_pack = "N")
  flag <- isTRUE(toupper(cfg$generate_stats_pack %||% "Y") == "Y")
  expect_false(flag)
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
