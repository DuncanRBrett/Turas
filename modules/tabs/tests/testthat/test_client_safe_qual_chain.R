# ==============================================================================
# TABS. THE CLIENT-SAFE COMMENT CHAIN, END TO END
# ==============================================================================
# Three pieces have to agree for a client-safe file to be what it says it is:
# the delivery floor decides the dials, the island builder honours them, and the
# release audit refuses the build if the file that comes out does not match. Each
# has its own tests. This file runs the three in sequence on one config, because
# a chain is exactly the thing three passing unit suites can still get wrong.
#
# The build it is written against: SACS 2025, where a client-safe file shipped
# 678 comments each tagged with its author's Campus, Department and Tenure, and
# 57 of the 144 tagged commenters were the only person in their combination.
# ==============================================================================

turas_root <- local({
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "tabs"))) return(normalizePath(path))
    path <- dirname(path)
  }
  stop("Cannot detect the Turas project root")
})
source(file.path(turas_root, "modules/tabs/lib/qual_island_builder.R"))
# The serialiser the real pipeline uses, lifted rather than sourced: qual_report.R
# pulls in the workbook reader and the whole report writer, and the subject here is
# the island's SHAPE on its way to the audit.
serialize_data_qual <- function(island) {
  if (is.null(island)) return("null")
  jsonlite::toJSON(island, na = "null", null = "null", auto_unbox = TRUE, digits = NA)
}
source(file.path(turas_root, "modules/tabs/lib/delivery_manifest.R"))
source(file.path(turas_root, "modules/shared/lib/turas_release_audit.R"))

# Six people. Cohort A holds five of them and Cohort B holds one, so the tag that
# names Cohort B names a person, which is the whole subject of this file.
chain_rec <- function(id, text) {
  list(id = id, text = text, noteworthy = TRUE, noteworthy_tier = 1L, hidden = FALSE,
       sentiment = 1L, rating = NA_real_, themeVals = list(Service = 1L))
}
chain_question <- function(code, ids) {
  list(code = code, title = "Why?", type = "themed",
       roles = list(themes = list(list(label = "Service", id = 0L))),
       records = lapply(ids, function(i) chain_rec(i, paste0("comment from ", i))),
       meta = list(dropped_codes = 0L))
}
chain_master <- function() {
  list(id_to_idx = stats::setNames(0:5, as.character(1:6)), n = 6L)
}
# Two questions, and respondent 2 wrote in both. That is the person a
# cross-question key would expose.
chain_questions <- function() list(chain_question("Q_A", c("1", "2", "3", "4", "5", "6")),
                                   chain_question("Q_B", c("2", "3")))
chain_levels <- function() list(Cohort = c(1L, 1L, 1L, 1L, 1L, 2L))

# A cube that agrees with those levels, built as a real one is: Cohort 1 holds
# five people and ships, Cohort 2 holds one and is withheld, so the cube keeps its
# own rule. A comment still wearing a Cohort 2 tag therefore names a group the
# cube will not even report, which is exactly what the audit has to catch.
CHAIN_CUBE <- paste0(
  '{"k":5,"n":6,"order":2,"vars":{"Cohort":{"kind":"banner","levels":[1,2]}},',
  '"slices":{"Cohort":{"cells":{"1":{"a":[5,5,5]}},"q":{}}}}')

chain_page <- function(qual_json) {
  paste0("<html><body>",
         sprintf('<script type="application/json" id="data-qual">%s</script>', qual_json),
         sprintf('<script type="application/json" id="data-cube">%s</script>', CHAIN_CUBE),
         "</body></html>")
}

chain_build <- function(config_obj) {
  qual_build_data_qual(chain_questions(), chain_master(), list(
    text_mode = config_obj$qual_confidentiality_mode,
    demographic_cuts = config_obj$qual_demographic_cuts,
    min_reporting_base = config_obj$min_reporting_base,
    comment_key = config_obj$qual_comment_key,
    manual_review = config_obj$qual_manual_review),
    rid_map = c("1" = "t1", "2" = "t2", "3" = "t3", "4" = "t4", "5" = "t5", "6" = "t6"),
    cut_levels = chain_levels())
}

raw_config <- function() list(
  qual_demographic_cuts = "allow", qual_confidentiality_mode = "full",
  qual_comment_key = "respondent", min_reporting_base = 5)


test_that("the config as written would ship a file the audit refuses", {
  # No floor applied. This is the build that went out, and the audit is the thing
  # that should have stopped it.
  island <- chain_build(raw_config())
  a <- turas_release_audit(chain_page(serialize_data_qual(island)),
                           client_safe = TRUE, refuse = FALSE)
  expect_true(a$client_safe_violation)
  msg <- paste(a$qual$violations, collapse = " ")
  expect_match(msg, "join")                       # the cross-question key
  expect_match(msg, "reader token")               # and the token itself
  expect_match(msg, "demographicCuts = 'allow'")  # every tag against every comment
  expect_match(msg, "textMode = 'full'")          # raw text
  expect_match(msg, "smaller than k=5")           # the tag that names one person
})


test_that("the same config through the floor ships a file the audit passes", {
  cfg <- raw_config()
  dials <- tabs_delivery_qual_dials(cfg, "client_safe_interactive")
  cfg <- tabs_apply_qual_floor(cfg, dials)
  island <- chain_build(cfg)
  a <- turas_release_audit(chain_page(serialize_data_qual(island)),
                           client_safe = TRUE, refuse = FALSE)
  expect_length(a$qual$violations, 0)
  expect_false(a$client_safe_violation)
  expect_equal(a$qual$comment_key, "question")
  expect_equal(a$qual$records, 8L)
})


test_that("the person who wrote in both questions is not identifiable as such", {
  cfg <- tabs_apply_qual_floor(raw_config(),
    tabs_delivery_qual_dials(raw_config(), "client_safe_interactive"))
  island <- chain_build(cfg)
  # Respondent 2 wrote the second comment of Q_A and the first of Q_B. Their keys
  # are 1 and 0, which are also the keys of two other people's comments.
  qa <- island$questions[[1]]; qb <- island$questions[[2]]
  expect_equal(vapply(qa$records, function(r) r$idx, integer(1)), 0:5)
  expect_equal(vapply(qb$records, function(r) r$idx, integer(1)), 0:1)
  for (q in island$questions) for (r in q$records) expect_null(r$rid)
})


test_that("the tag that named one person is gone, and the safe one remains", {
  cfg <- tabs_apply_qual_floor(raw_config(),
    tabs_delivery_qual_dials(raw_config(), "client_safe_interactive"))
  island <- chain_build(cfg)
  cuts <- unlist(lapply(island$questions, function(q)
    lapply(q$records, function(r) if (is.null(r$cut)) NA_integer_ else r$cut$Cohort)))
  # Cohort 1 holds five people and k is five, so it survives. Cohort 2 holds one
  # and does not, so respondent 6's comment carries no cohort at all.
  expect_true(all(cuts[!is.na(cuts)] == 1L))
  expect_true(any(is.na(cuts)))
})


test_that("a full report is left alone, and the audit does not judge it", {
  cfg <- raw_config()
  dials <- tabs_delivery_qual_dials(cfg, "full")
  cfg <- tabs_apply_qual_floor(cfg, dials)
  expect_equal(cfg$qual_comment_key, "respondent")
  expect_equal(cfg$qual_demographic_cuts, "allow")
  island <- chain_build(cfg)
  a <- turas_release_audit(chain_page(serialize_data_qual(island)),
                           client_safe = FALSE, refuse = FALSE)
  expect_false(a$client_safe_violation)
})
