# ==============================================================================
# TABS MODULE. READER-KEY (rid) TESTS
# ==============================================================================
#
# Gates the I20 fix: reader marks key on an opaque per-respondent token instead of
# the positional index, so a re-export can no longer silently re-attach a
# shortlist star / highlighted passage / hub membership to a DIFFERENT
# respondent's comment.
#
# The token lives in a sidecar beside the config that never ships. The rules that
# matter, and are gated here:
#   - append-only: an id that drops out of one export KEEPS its entry, so a
#     respondent who returns re-attaches to their old marks;
#   - never re-mint over a corrupt sidecar (that would orphan every mark);
#   - a missing config path or a corrupt sidecar degrades LOUDLY to the pre-I20
#     island shape (no rids) rather than shipping a wrong key.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_reader_keys.R")
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Could not locate Turas root for sourcing qual_reader_keys.R")
}

turas_root <- detect_turas_root()
suppressWarnings(suppressMessages(library(jsonlite)))
source(file.path(turas_root, "modules/tabs/lib/qual_workbook_reader.R"))
source(file.path(turas_root, "modules/tabs/lib/qual_island_builder.R"))
source(file.path(turas_root, "modules/tabs/lib/qual_reader_keys.R"))
source(file.path(turas_root, "modules/tabs/lib/qual_report.R"))   # serialize_data_qual

# ---- Fixtures ----------------------------------------------------------------

# A throwaway project folder + config path per test, so no test can see another's
# sidecar (the path IS the sidecar's identity).
new_config <- function() {
  dir <- file.path(tempdir(), paste0("rk_", paste0(sample(letters, 8L, TRUE), collapse = "")))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  list(config_file_path = file.path(dir, "project_config.xlsx"))
}
sidecar_of <- function(cfg) qual_reader_keys_path(cfg$config_file_path)

mk_theme <- function(label) list(col = NA_integer_, label = label)
mk_rec <- function(id, text, tier = 1L, themeVals = list()) {
  list(id = id, text = text, noteworthy = tier >= 1L, noteworthy_tier = tier,
       hidden = FALSE, sentiment = NA_integer_, rating = NA_real_, themeVals = themeVals)
}
question_of <- function(code, records) {
  list(code = code, title = "Why?", type = "themed",
       roles = list(themes = list(mk_theme("Service"))),
       records = records, meta = list(dropped_codes = 0L))
}
master2 <- list(id_to_idx = stats::setNames(c(0L, 1L), c("1", "2")), n = 2L)

quiet <- function(expr) invisible(utils::capture.output(force(expr)))

# ==============================================================================
# 1. FRESH MINT
# ==============================================================================

test_that("a first run mints one 16-hex token per unique id and writes the sidecar", {
  cfg <- new_config()
  res <- qual_reader_keys(c("A", "B", "C", "B"), cfg)   # duplicate id present

  expect_equal(res$status, "PASS")
  expect_equal(res$minted, 3L)                          # de-duplicated
  expect_equal(sort(names(res$map)), c("A", "B", "C"))
  expect_true(all(grepl("^[0-9a-f]{16}$", unname(res$map))))
  expect_equal(length(unique(unname(res$map))), 3L)     # all distinct

  expect_true(file.exists(sidecar_of(cfg)))
  on_disk <- jsonlite::fromJSON(sidecar_of(cfg), simplifyVector = FALSE)
  expect_equal(on_disk$version, 1L)
  expect_equal(sort(names(on_disk$keys)), c("A", "B", "C"))
  expect_equal(as.character(on_disk$keys[["A"]]), unname(res$map[["A"]]))
})

test_that("blank and NA ids are dropped rather than keyed", {
  cfg <- new_config()
  res <- qual_reader_keys(c("A", "", NA_character_), cfg)
  expect_equal(names(res$map), "A")
})

test_that("minting leaves the global RNG state exactly as it found it", {
  cfg <- new_config()
  set.seed(4242)
  before <- .Random.seed
  qual_reader_keys(c("A", "B"), cfg)
  expect_identical(.Random.seed, before)   # a seeded bootstrap elsewhere must not shift
})

# ==============================================================================
# 2. STABILITY
# ==============================================================================

test_that("a second run over the same ids returns the same map and does not rewrite", {
  cfg <- new_config()
  first <- qual_reader_keys(c("A", "B"), cfg)

  # Stamp the file so a rewrite is detectable regardless of clock resolution.
  stamped <- jsonlite::fromJSON(sidecar_of(cfg), simplifyVector = FALSE)
  stamped$built <- "SENTINEL"
  jsonlite::write_json(stamped, sidecar_of(cfg), pretty = TRUE, auto_unbox = TRUE)

  second <- qual_reader_keys(c("A", "B"), cfg)
  expect_equal(second$status, "PASS")
  expect_equal(second$minted, 0L)
  expect_identical(second$map[c("A", "B")], first$map[c("A", "B")])
  expect_equal(jsonlite::fromJSON(sidecar_of(cfg), simplifyVector = FALSE)$built, "SENTINEL")
})

# ==============================================================================
# 3. GROWTH
# ==============================================================================

test_that("a new id appends one token and leaves every existing token alone", {
  cfg <- new_config()
  first <- qual_reader_keys(c("A", "B"), cfg)
  grown <- qual_reader_keys(c("A", "B", "C"), cfg)

  expect_equal(grown$minted, 1L)
  expect_identical(grown$map[["A"]], first$map[["A"]])
  expect_identical(grown$map[["B"]], first$map[["B"]])
  expect_true(grepl("^[0-9a-f]{16}$", grown$map[["C"]]))
  expect_false(grown$map[["C"]] %in% unname(first$map))

  on_disk <- jsonlite::fromJSON(sidecar_of(cfg), simplifyVector = FALSE)
  expect_equal(sort(names(on_disk$keys)), c("A", "B", "C"))
})

# ==============================================================================
# 4. SHRINK + RETURN (append-only: an entry is never deleted)
# ==============================================================================

test_that("an id absent from an export keeps its entry and re-attaches when it returns", {
  cfg <- new_config()
  first <- qual_reader_keys(c("A", "B", "C"), cfg)

  shrunk <- qual_reader_keys(c("A"), cfg)                       # B and C dropped out
  expect_equal(shrunk$minted, 0L)                              # nothing re-minted
  expect_true(all(c("A", "B", "C") %in% names(shrunk$map)))    # nothing deleted
  expect_equal(sort(names(jsonlite::fromJSON(sidecar_of(cfg), simplifyVector = FALSE)$keys)),
               c("A", "B", "C"))

  returned <- qual_reader_keys(c("A", "B", "C"), cfg)          # B and C come back
  expect_equal(returned$minted, 0L)
  expect_identical(returned$map[["B"]], first$map[["B"]])      # their OLD marks still fit
  expect_identical(returned$map[["C"]], first$map[["C"]])
})

# ==============================================================================
# 5. THE ISLAND CARRIES rid
# ==============================================================================

test_that("records carry the rid from the map, stable across questions", {
  cfg <- new_config()
  keys <- qual_reader_keys(c("1", "2"), cfg)
  island <- qual_build_data_qual(
    list(question_of("QA", list(mk_rec("1", "alpha"), mk_rec("2", "bravo"))),
         question_of("QB", list(mk_rec("1", "charlie")))),
    master2, list(text_mode = "full"), rid_map = keys$map)

  qa <- island$questions[[1]]$records
  qb <- island$questions[[2]]$records
  expect_equal(qa[[1]]$rid, unname(keys$map[["1"]]))
  expect_equal(qa[[2]]$rid, unname(keys$map[["2"]]))
  expect_equal(qb[[1]]$rid, unname(keys$map[["1"]]))   # one respondent, one token
  expect_false(identical(qa[[1]]$rid, qa[[2]]$rid))
  expect_equal(qa[[1]]$idx, 0L)                        # idx itself is unchanged
})

test_that("rid is absent without a map. The pre-I20 island shape (regression)", {
  island <- qual_build_data_qual(
    list(question_of("QA", list(mk_rec("1", "alpha")))), master2, list(text_mode = "full"))
  r <- island$questions[[1]]$records[[1]]
  expect_null(r$rid)
  expect_false("rid" %in% names(r))
})

test_that("an id the sidecar has never seen simply gets no rid", {
  island <- qual_build_data_qual(
    list(question_of("QA", list(mk_rec("1", "alpha"), mk_rec("2", "bravo")))),
    master2, list(text_mode = "full"),
    rid_map = c("1" = "00000000000000ab"))          # only respondent 1 is keyed
  recs <- island$questions[[1]]$records
  expect_equal(recs[[1]]$rid, "00000000000000ab")
  expect_false("rid" %in% names(recs[[2]]))
})

test_that("rid ships under every privacy dial. It discloses nothing", {
  for (mode in c("hidden", "redacted", "full")) {
    for (cuts in c("block", "safe", "allow")) {
      island <- qual_build_data_qual(
        list(question_of("QA", list(mk_rec("1", "alpha")))), master2,
        list(text_mode = mode, demographic_cuts = cuts), rid_map = c("1" = "00000000000000ab"))
      expect_equal(island$questions[[1]]$records[[1]]$rid, "00000000000000ab",
                   info = paste(mode, cuts))
    }
  }
})

# ==============================================================================
# 6. NO_PATH. No config path, no rids, said out loud
# ==============================================================================

test_that("a missing config path refuses to key, warns, and builds the legacy island", {
  out <- utils::capture.output(res <- qual_reader_keys(c("1", "2"), list()))
  expect_equal(res$status, "NO_PATH")
  expect_null(res$map)
  expect_true(any(grepl("READER-KEY WARNING", out)))
  expect_true(any(grepl("No config file path", out)))

  island <- qual_build_data_qual(list(question_of("QA", list(mk_rec("1", "alpha")))),
                                 master2, list(text_mode = "full"), rid_map = res$map)
  expect_false("rid" %in% names(island$questions[[1]]$records[[1]]))
})

test_that("a blank config path is treated as no path", {
  out <- utils::capture.output(res <- qual_reader_keys("1", list(config_file_path = "   ")))
  expect_equal(res$status, "NO_PATH")
  expect_true(any(grepl("READER-KEY WARNING", out)))
})

# ==============================================================================
# 7. CORRUPT, never re-mint over a sidecar we cannot read
# ==============================================================================

test_that("a corrupt sidecar is never overwritten and no rids ship", {
  cfg <- new_config()
  quiet(qual_reader_keys(c("A", "B"), cfg))
  writeLines("{ this is not json", sidecar_of(cfg))
  bytes <- readLines(sidecar_of(cfg), warn = FALSE)

  out <- utils::capture.output(res <- qual_reader_keys(c("A", "B", "C"), cfg))
  expect_equal(res$status, "CORRUPT")
  expect_null(res$map)
  expect_true(any(grepl("READER-KEY WARNING", out)))
  expect_true(any(grepl("unreadable", out)))
  expect_true(any(grepl("NOT rewritten", out)))
  expect_identical(readLines(sidecar_of(cfg), warn = FALSE), bytes)   # untouched

  island <- qual_build_data_qual(list(question_of("QA", list(mk_rec("1", "alpha")))),
                                 master2, list(text_mode = "full"), rid_map = res$map)
  expect_false("rid" %in% names(island$questions[[1]]$records[[1]]))
})

test_that("a well-formed JSON file with no keys block also reads as corrupt", {
  cfg <- new_config()
  jsonlite::write_json(list(version = 1L, built = "x"), sidecar_of(cfg), auto_unbox = TRUE)
  out <- utils::capture.output(res <- qual_reader_keys("A", cfg))
  expect_equal(res$status, "CORRUPT")
  expect_null(res$map)
  expect_true(any(grepl("READER-KEY WARNING", out)))
})

# ==============================================================================
# 8. SERIALISATION ROUND-TRIP
# ==============================================================================

test_that("rid survives serialize_data_qual", {
  cfg <- new_config()
  keys <- qual_reader_keys(c("1", "2"), cfg)
  island <- qual_build_data_qual(
    list(question_of("QA", list(mk_rec("1", "alpha"), mk_rec("2", "bravo")))),
    master2, list(text_mode = "full"), rid_map = keys$map)

  back <- jsonlite::fromJSON(serialize_data_qual(island), simplifyVector = FALSE)
  recs <- back$questions[[1]]$records
  expect_equal(recs[[1]]$rid, unname(keys$map[["1"]]))
  expect_equal(recs[[2]]$rid, unname(keys$map[["2"]]))
  expect_equal(recs[[1]]$idx, 0L)
})

test_that("an island without rids serialises without the field", {
  json <- serialize_data_qual(qual_build_data_qual(
    list(question_of("QA", list(mk_rec("1", "alpha")))), master2, list(text_mode = "full")))
  expect_false(grepl('"rid"', json, fixed = TRUE))
})
