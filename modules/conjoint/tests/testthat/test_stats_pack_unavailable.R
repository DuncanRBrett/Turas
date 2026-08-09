# ==============================================================================
# TESTS: a missing stats pack writer is never silent
# ==============================================================================
# generate_stats_pack defaults to Y, so a run that cannot write a stats pack has
# failed to produce something the config asked for. That must reach the console.
# Turas runs inside a Shiny app, so console output is the only place a user can
# see it.
#
# The guard is the first statement in the function, so it returns before touching
# any of its arguments — NULL placeholders are safe here.
# ==============================================================================

test_that("generate_conjoint_stats_pack warns loudly when the writer is missing", {
  skip_if(!exists("generate_conjoint_stats_pack", mode = "function"),
          "generate_conjoint_stats_pack not available")
  skip_if(!exists("turas_write_stats_pack", envir = .GlobalEnv, inherits = FALSE),
          "turas_write_stats_pack not in global env, cannot hide it")

  original <- get("turas_write_stats_pack", envir = .GlobalEnv)
  rm("turas_write_stats_pack", envir = .GlobalEnv)
  on.exit(assign("turas_write_stats_pack", original, envir = .GlobalEnv), add = TRUE)

  out <- capture.output(
    result <- generate_conjoint_stats_pack(NULL, NULL, NULL, NULL, Sys.time(), FALSE)
  )

  expect_null(result)
  expect_true(any(grepl("PKG_STATS_PACK_WRITER_UNAVAILABLE", out, fixed = TRUE)))
  expect_true(any(grepl("TURAS WARNING", out, fixed = TRUE)))
})

test_that("the warning is printed even when verbose is FALSE", {
  skip_if(!exists("generate_conjoint_stats_pack", mode = "function"),
          "generate_conjoint_stats_pack not available")
  skip_if(!exists("turas_write_stats_pack", envir = .GlobalEnv, inherits = FALSE),
          "turas_write_stats_pack not in global env, cannot hide it")

  original <- get("turas_write_stats_pack", envir = .GlobalEnv)
  rm("turas_write_stats_pack", envir = .GlobalEnv)
  on.exit(assign("turas_write_stats_pack", original, envir = .GlobalEnv), add = TRUE)

  # verbose = FALSE used to suppress the note entirely. A missing deliverable is
  # not something the verbose flag should be able to hide.
  out <- capture.output(
    generate_conjoint_stats_pack(NULL, NULL, NULL, NULL, Sys.time(), verbose = FALSE)
  )

  expect_true(any(grepl("PKG_STATS_PACK_WRITER_UNAVAILABLE", out, fixed = TRUE)))
})
