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
                   themeVals = list(), hidden = FALSE) {
  list(id = id, text = text, noteworthy = tier >= 1L, noteworthy_tier = tier,
       hidden = hidden, sentiment = sentiment, rating = rating, themeVals = themeVals)
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

# ==============================================================================
# DISCLOSURE INDEPENDENCE — the threshold does NOT silently re-tag comments
# ==============================================================================

test_that("min_reporting_base does not override the tagging dial (independent by design)", {
  m2 <- list(id_to_idx = stats::setNames(c(0L, 1L), c("1", "2")), n = 2L,
             banner_dims = list(list(label = "Group", values = c("A", "B"))))
  recs <- records
  recs[[1]]$demos <- list(Group = "A")
  recs[[2]]$demos <- list(Group = "B")
  q <- themed_question(recs)

  # allow + a threshold: tags + full text STILL ride the island. k gates the on-screen /
  # quant drill-down, not the island payload; the orchestrator warns (it does not re-tag).
  allowed <- qual_build_data_qual(list(q), m2,
    list(text_mode = "full", demographic_cuts = "allow", min_reporting_base = 10))
  expect_equal(allowed$demographicCuts, "allow")
  expect_equal(first_record(allowed$questions[[1]], 0L)$demos$Group, "A")
  expect_equal(first_record(allowed$questions[[1]], 0L)$text, "Email me at bob@example.com")

  # block is the source-side de-identification: no demos enter the island, at ANY k.
  blocked <- qual_build_data_qual(list(q), m2,
    list(text_mode = "full", demographic_cuts = "block", min_reporting_base = 10))
  expect_null(blocked$demographics)
  expect_null(first_record(blocked$questions[[1]], 0L)$demos)
})

test_that("qual_kanon_tags keeps broad tags, drops fine crossings below k", {
  # 3 Admin (one <1yr, two 5yr), 1 Finance 5yr. Admin=3, Finance=1, <1yr=1, 5yr=3,
  # Admin&<1yr=1, Admin&5yr=2, Finance&5yr=1.
  rows <- list(list(Dept = "Admin", Tenure = "<1yr"), list(Dept = "Admin", Tenure = "5yr"),
               list(Dept = "Admin", Tenure = "5yr"), list(Dept = "Finance", Tenure = "5yr"))
  res <- qual_kanon_tags(rows, c("Dept", "Tenure"), 2)
  expect_equal(res[[1]]$Dept, "Admin"); expect_true(is.na(res[[1]]$Tenure))  # <1yr crossing=1 dropped
  expect_equal(res[[2]]$Dept, "Admin"); expect_equal(res[[2]]$Tenure, "5yr")  # crossing=2 -> both kept
  expect_true(is.na(res[[4]]$Dept)); expect_equal(res[[4]]$Tenure, "5yr")      # Finance=1 dropped
  # k = 1 (off) returns the rows unchanged.
  same <- qual_kanon_tags(rows, c("Dept", "Tenure"), 1)
  expect_equal(same[[1]]$Tenure, "<1yr")
})

test_that("demographic_cuts='safe' k-anonymises comment tags against min_reporting_base", {
  m <- list(id_to_idx = stats::setNames(0:3, as.character(1:4)), n = 4L,
            banner_dims = list(list(label = "Dept", values = c("Admin", "Finance")),
                               list(label = "Tenure", values = c("<1yr", "5yr"))))
  mkr <- function(id, dept, ten) {
    r <- mk_rec(id, paste0("c", id), themeVals = list(Service = 1L))
    r$demos <- list(Dept = dept, Tenure = ten); r
  }
  q <- themed_question(list(mkr("1", "Admin", "<1yr"), mkr("2", "Admin", "5yr"),
                            mkr("3", "Admin", "5yr"), mkr("4", "Finance", "5yr")))
  island <- qual_build_data_qual(list(q), m,
    list(text_mode = "full", demographic_cuts = "safe", min_reporting_base = 2))
  expect_equal(island$demographicCuts, "safe")
  r1 <- first_record(island$questions[[1]], 0L)          # Admin,<1yr -> Admin kept, <1yr suppressed
  expect_equal(r1$demos$Dept, "Admin")
  expect_true(is.na(r1$demos$Tenure))
  r2 <- first_record(island$questions[[1]], 1L)          # Admin,5yr  -> both kept
  expect_equal(r2$demos$Dept, "Admin")
  expect_equal(r2$demos$Tenure, "5yr")
  r4 <- first_record(island$questions[[1]], 3L)          # Finance,5yr -> Finance suppressed
  expect_true(is.na(r4$demos$Dept))
  expect_equal(r4$demos$Tenure, "5yr")
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

# ==============================================================================
# VERBATIM SCOPE — which comments ship their text (all-except-hide / noteworthy)
# ==============================================================================

# A four-record master: one priority (tier 3), one plain noteworthy (tier 1),
# one un-noteworthy (tier 0), one explicitly hidden — every comment is themed, so
# the distribution must count all four regardless of which text ships.
scope_master <- list(id_to_idx = stats::setNames(0:3, c("1", "2", "3", "4")), n = 4L)
scope_records <- list(
  mk_rec("1", "priority quote", tier = 3L, sentiment = 1L, themeVals = list(Service = 1L)),
  mk_rec("2", "noteworthy quote", tier = 1L, sentiment = 1L, themeVals = list(Service = 1L)),
  mk_rec("3", "ordinary quote", tier = 0L, sentiment = 3L, themeVals = list(Price = 3L)),
  mk_rec("4", "hidden quote", tier = 0L, sentiment = 2L, themeVals = list(Price = 2L), hidden = TRUE)
)
scope_island <- function(scope) {
  qual_build_data_qual(list(themed_question(scope_records)), scope_master,
                       list(text_mode = "full", verbatim_scope = scope))$questions[[1]]
}

test_that("scope 'all' ships every verbatim except hide-marked ones", {
  q <- scope_island("all")
  expect_equal(first_record(q, 0L)$text, "priority quote")
  expect_equal(first_record(q, 1L)$text, "noteworthy quote")
  expect_equal(first_record(q, 2L)$text, "ordinary quote")     # tier 0 still shows under 'all'
  expect_true(is.na(first_record(q, 3L)$text))                 # hide -> text withheld
  expect_true(isTRUE(first_record(q, 3L)$suppressed))          # and flagged for the list
  # The other three are shown, so carry no suppressed flag.
  expect_null(first_record(q, 0L)$suppressed)
  expect_null(first_record(q, 2L)$suppressed)
})

test_that("scope 'noteworthy' ships only tier >= 1; ordinary + hidden are withheld", {
  q <- scope_island("noteworthy")
  expect_equal(first_record(q, 0L)$text, "priority quote")     # tier 3 shows
  expect_equal(first_record(q, 1L)$text, "noteworthy quote")   # tier 1 shows
  expect_true(is.na(first_record(q, 2L)$text))                 # tier 0 withheld
  expect_true(isTRUE(first_record(q, 2L)$suppressed))
  expect_true(is.na(first_record(q, 3L)$text))                 # hide withheld too
  expect_true(isTRUE(first_record(q, 3L)$suppressed))
})

test_that("withheld comments still count: all records, themes, sentiment survive the scope", {
  for (scope in c("all", "noteworthy")) {
    q <- scope_island(scope)
    expect_equal(length(q$records), 4L)                        # every record emitted
    expect_equal(q$base$answered, 4L)                          # base counts all four
    # Theme codes + sentiment ride even on a withheld record (idx 3, the hidden one).
    hidden_rec <- first_record(q, 3L)
    expect_equal(hidden_rec$sentiment, 2L)
    expect_equal(hidden_rec$themeVals[["1"]], 2L)              # Price = theme id 1
  }
})

test_that("verbatim scope is validated and carried on the island; invalid -> all", {
  expect_equal(qual_build_data_qual(list(themed_question(records)), master,
                                    list(verbatim_scope = "noteworthy"))$verbatimScope, "noteworthy")
  expect_equal(qual_build_data_qual(list(themed_question(records)), master,
                                    list(verbatim_scope = "bogus"))$verbatimScope, "all")
  expect_equal(qual_build_data_qual(list(themed_question(records)), master,
                                    list())$verbatimScope, "all")   # default
})

test_that("qual_verbatim_shows encodes the gate (hide always wins; scope picks the rest)", {
  note <- list(noteworthy_tier = 1L, hidden = FALSE)
  ord  <- list(noteworthy_tier = 0L, hidden = FALSE)
  hid  <- list(noteworthy_tier = 1L, hidden = TRUE)   # marked hide despite a tier
  expect_true(qual_verbatim_shows(note, "all"))
  expect_true(qual_verbatim_shows(ord,  "all"))
  expect_false(qual_verbatim_shows(hid, "all"))       # hide wins under 'all'
  expect_true(qual_verbatim_shows(note, "noteworthy"))
  expect_false(qual_verbatim_shows(ord, "noteworthy"))
  expect_false(qual_verbatim_shows(hid, "noteworthy"))
})
