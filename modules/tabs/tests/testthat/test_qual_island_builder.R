# ==============================================================================
# TABS MODULE — DATA_QUAL ISLAND BUILDER TESTS
# ==============================================================================
#
# Known-answer tests for qual_island_builder.R: record assembly (id -> anonymous
# index, theme label -> id remap, tier carried), and the three verbatim-text
# confidentiality modes (hidden / redacted / full) with the PII scrub.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_island_builder.R")
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
  stop("Could not locate Turas root for sourcing qual_island_builder.R")
}

turas_root <- detect_turas_root()
source(file.path(turas_root, "modules/tabs/lib/qual_workbook_reader.R"))
source(file.path(turas_root, "modules/tabs/lib/qual_island_builder.R"))

# ---- Fixtures (shape mirrors reader output) ----------------------------------

mk_theme <- function(label) list(col = NA_integer_, label = label)
mk_rec <- function(id, text, tier = 1L, sentiment = NA_integer_, rating = NA_real_,
                   themeVals = list()) {
  list(id = id, text = text, noteworthy = tier >= 1L, noteworthy_tier = tier,
       sentiment = sentiment, rating = rating, themeVals = themeVals)
}
themed_question <- function(records) {
  list(code = "QUAL_OVERALL", title = "Why?", type = "themed",
       roles = list(themes = list(mk_theme("Service"), mk_theme("Price"))),
       records = records, meta = list(dropped_codes = 1L))
}
master <- list(id_to_idx = stats::setNames(c(0L, 1L), c("1", "2")), n = 2L)

records <- list(
  mk_rec("1", "Email me at bob@example.com", tier = 2L, sentiment = 1L,
         themeVals = list(Service = 1L)),
  mk_rec("2", "Call 082 123 4567 please", tier = 1L, sentiment = 3L,
         themeVals = list(Price = 3L))
)

first_record <- function(island_q, idx) {
  for (r in island_q$records) if (identical(r$idx, idx)) return(r)
  NULL
}

# ==============================================================================
# RECORD ASSEMBLY — index, theme remap, tier
# ==============================================================================

test_that("records map id -> anon index, remap theme labels to ids, and carry the tier", {
  island <- qual_build_data_qual(list(themed_question(records)), master,
                                 list(text_mode = "full"))
  q <- island$questions[[1]]
  expect_equal(q$type, "themed")
  expect_equal(q$base$answered, 2L)
  expect_equal(vapply(q$themes, function(t) t$label, character(1)), c("Service", "Price"))
  expect_equal(vapply(q$themes, function(t) t$id, integer(1)), c(0L, 1L))

  r0 <- first_record(q, 0L)
  expect_equal(r0$tier, 2L)                            # must-read carried
  expect_equal(r0$sentiment, 1L)
  expect_equal(r0$themeVals[["0"]], 1L)                # "Service" -> id 0
  r1 <- first_record(q, 1L)
  expect_equal(r1$tier, 1L)
  expect_equal(r1$themeVals[["1"]], 3L)                # "Price" -> id 1
})

test_that("a record whose id is not in the master is skipped", {
  extra <- c(records, list(mk_rec("999", "ghost", tier = 1L)))
  island <- qual_build_data_qual(list(themed_question(extra)), master, list(text_mode = "full"))
  expect_equal(island$questions[[1]]$base$answered, 2L)   # ghost dropped
})

# ==============================================================================
# CONFIDENTIALITY — three verbatim-text modes
# ==============================================================================

test_that("FULL mode ships the exact verbatim, no scrubbing", {
  island <- qual_build_data_qual(list(themed_question(records)), master, list(text_mode = "full"))
  q <- island$questions[[1]]
  expect_equal(island$textMode, "full")
  expect_equal(first_record(q, 0L)$text, "Email me at bob@example.com")
  expect_false(q$meta$pii_scrubbed)
})

test_that("HIDDEN mode nulls every verbatim (numbers still ship)", {
  island <- qual_build_data_qual(list(themed_question(records)), master, list(text_mode = "hidden"))
  q <- island$questions[[1]]
  expect_equal(island$textMode, "hidden")
  expect_true(is.na(first_record(q, 0L)$text))         # -> JSON null -> "[quote hidden]"
  expect_equal(first_record(q, 0L)$tier, 2L)           # numbers/tier still present
  expect_false(q$meta$pii_scrubbed)
})

test_that("REDACTED mode scrubs direct identifiers and flags the scrub", {
  island <- qual_build_data_qual(list(themed_question(records)), master,
                                 list(text_mode = "redacted"))
  q <- island$questions[[1]]
  expect_equal(island$textMode, "redacted")
  expect_equal(first_record(q, 0L)$text, "Email me at [redacted]")   # email gone
  expect_equal(first_record(q, 1L)$text, "Call [redacted] please")    # phone gone
  expect_true(q$meta$pii_scrubbed)
  expect_gte(q$meta$redactions, 2L)
})

test_that("qual_scrub_text catches email, url and phone; leaves clean text alone", {
  expect_equal(qual_scrub_text("see www.foo.co.za now")$text, "see [redacted] now")
  expect_equal(qual_scrub_text("visit https://x.io/p")$text, "visit [redacted]")
  expect_equal(qual_scrub_text("nothing to redact")$redactions, 0L)
})

# ==============================================================================
# ISLAND-LEVEL FLAGS — dial defaults validated safely
# ==============================================================================

test_that("demographics ride the island + records when allowed; omitted when blocked", {
  m2 <- list(id_to_idx = stats::setNames(c(0L, 1L), c("1", "2")), n = 2L,
             banner_dims = list(list(label = "Group", values = c("A", "B"))))
  recs <- records
  recs[[1]]$demos <- list(Group = "A")
  recs[[2]]$demos <- list(Group = "B")
  q <- themed_question(recs)

  allowed <- qual_build_data_qual(list(q), m2, list(text_mode = "full", demographic_cuts = "allow"))
  expect_equal(length(allowed$demographics), 1L)
  expect_equal(allowed$demographics[[1]]$label, "Group")
  expect_equal(allowed$demographics[[1]]$values, c("A", "B"))
  expect_equal(first_record(allowed$questions[[1]], 0L)$demos$Group, "A")

  blocked <- qual_build_data_qual(list(q), m2, list(text_mode = "full", demographic_cuts = "block"))
  expect_null(blocked$demographics)                        # no demo leak when blocked
  expect_null(first_record(blocked$questions[[1]], 0L)$demos)
})

test_that("invalid text mode falls back to hidden; dials and defaults carried", {
  island <- qual_build_data_qual(list(themed_question(records)), master,
                                 list(text_mode = "bogus", demographic_cuts = "block",
                                      noteworthy_default = "nonsense"))
  expect_equal(island$textMode, "hidden")              # safe default
  expect_equal(island$demographicCuts, "block")        # carried for the JS
  expect_equal(island$noteworthyDefault, "all")        # invalid default -> all
  expect_equal(island$n, 2L)
})
