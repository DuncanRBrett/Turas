# ==============================================================================
# TESTS: no module skips the stats pack silently
# ==============================================================================
# Every module that offers generate_stats_pack guards its writer call with
# exists("turas_write_stats_pack", ...). If that guard returns without telling
# anyone, the config asked for an output and did not get one while the run still
# reports success — the silent failure CLAUDE.md forbids.
#
# Behavioural cover lives in the modules whose test context loads the function
# (conjoint, catdriver). This file is the structural sweep: it asserts that every
# such guard, in every module, prints the warning code before it returns. It is
# deliberately source-level, because the thing being protected is the presence of
# a specific guard at sites that are unreachable in normal operation.
# ==============================================================================

library(testthat)

find_turas_root <- function() {
  p <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(p, "modules", "shared", "lib"))) return(normalizePath(p))
    p <- dirname(p)
  }
  NULL
}

TURAS_ROOT <- find_turas_root()
WARNING_CODE <- "PKG_STATS_PACK_WRITER_UNAVAILABLE"
GUARD <- 'exists("turas_write_stats_pack"'

# How far after the guard the warning code may appear. The guard block is short;
# this is generous enough for comments and the boxed message.
LOOKAHEAD <- 20

collect_guard_sites <- function(root) {
  files <- list.files(file.path(root, "modules"), pattern = "[.]R$",
                      recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("/tests/|/worktrees/", files)]
  sites <- list()
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    hits <- grep(GUARD, lines, fixed = TRUE)
    for (h in hits) {
      sites[[length(sites) + 1]] <- list(
        file = sub(paste0("^", root, "/"), "", f),
        line = h,
        window = lines[h:min(length(lines), h + LOOKAHEAD)]
      )
    }
  }
  sites
}

test_that("the Turas root is found", {
  expect_false(is.null(TURAS_ROOT))
})

test_that("stats pack guard sites still exist to be checked", {
  skip_if(is.null(TURAS_ROOT), "Turas root not found")

  sites <- collect_guard_sites(TURAS_ROOT)
  # If this drops to zero the sweep below silently passes while testing nothing.
  expect_gt(length(sites), 0)
})

test_that("every stats pack guard announces itself before returning", {
  skip_if(is.null(TURAS_ROOT), "Turas root not found")

  sites <- collect_guard_sites(TURAS_ROOT)

  silent <- Filter(function(s) !any(grepl(WARNING_CODE, s$window, fixed = TRUE)), sites)
  offenders <- vapply(silent, function(s) sprintf("%s:%d", s$file, s$line), character(1))

  expect_identical(
    offenders, character(0),
    info = paste0(
      "These guards skip the stats pack without printing ", WARNING_CODE, ":\n  ",
      paste(offenders, collapse = "\n  ")
    )
  )
})
