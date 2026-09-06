# ==============================================================================
# TEST: JSON data islands are markup-safe (review 2026-07-12, M3)
# ==============================================================================
library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  ROOT <<- find_root()
  source(file.path(ROOT, "modules", "brand", "lib", "html_report", "panels",
                   "00_json_island.R"), local = FALSE)
})

test_that(".br_json_island makes </script, <!-- and <script unformable and JSON.parse-identical", {
  payload <- list(label = "Brand </script><!--<script>alert(1)</script>",
                  note  = "a < b and <b>bold</b>")
  raw <- as.character(jsonlite::toJSON(payload, auto_unbox = TRUE))
  esc <- .br_json_island(raw)
  expect_false(grepl("</", esc, fixed = TRUE))
  expect_false(grepl("<!--", esc, fixed = TRUE))
  expect_false(grepl("<script", esc, fixed = TRUE))
  expect_false(grepl("<", esc, fixed = TRUE))
  back <- jsonlite::fromJSON(esc)
  expect_identical(back$label, payload$label)
  expect_identical(back$note, payload$note)
  expect_identical(.br_json_island(NULL), "")
  expect_identical(.br_json_island("[]"), "[]")
})

test_that("every application/json island in the brand panels goes through .br_json_island", {
  panel_dir <- file.path(ROOT, "modules", "brand", "lib", "html_report", "panels")
  files <- list.files(panel_dir, pattern = "\\.R$", full.names = TRUE)
  offenders <- character(0)
  n_sites <- 0L
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    hits <- grep('type="application/json"', lines, fixed = TRUE)
    hits <- hits[!grepl("^\\s*#", lines[hits])]   # comments are not sites
    for (h in hits) {
      # a static island literal ("[]") carries no payload; skip those
      window <- paste(lines[h:min(length(lines), h + 3)], collapse = "\n")
      if (grepl('>\\[\\]</script>', lines[h])) next
      n_sites <- n_sites + 1L
      if (!grepl(".br_json_island(", window, fixed = TRUE) &&
          !grepl(".pfo_escape_json(", window, fixed = TRUE)) {
        offenders <- c(offenders, sprintf("%s:%d", basename(f), h))
      }
    }
  }
  expect_gte(n_sites, 15L)
  expect_length(offenders, 0L)
})
