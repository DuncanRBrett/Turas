# ==============================================================================
# TESTS: release audit (modules/shared/lib/turas_release_audit.R)
# ==============================================================================
# The audit is the last thing between a build and a client. These tests hold it
# to two properties: it must not miss a populated respondent island, and it must
# not cry wolf on a clean one. A noisy audit gets ignored, which is the same as
# no audit.
# ==============================================================================

if (!exists("turas_release_audit", mode = "function")) {
  .root <- rprojroot::find_root(rprojroot::has_dir("modules"))
  source(file.path(.root, "modules", "shared", "lib", "turas_release_audit.R"))
}

island <- function(id, body) {
  sprintf('<script type="application/json" id="%s">%s</script>', id, body)
}

page <- function(...) {
  paste0("<html><head><title>R</title></head><body>", paste0(..., collapse = ""),
         "<script>var x=1;</script></body></html>")
}

MICRO_BODY <- '{"n":600,"answers":{"Q001":[7,7,9]},"weights":[1,1,1]}'


test_that("a populated microdata island is found, with its respondent count", {
  a <- turas_release_audit(page(island("data-micro", MICRO_BODY)))
  expect_true(a$microdata$present)
  expect_equal(a$microdata$n, 600L)
  expect_true(a$microdata$weights)
  expect_equal(a$status, "FLAGGED")
  expect_match(paste(a$lines, collapse = "\n"), "PRESENT \\(600 respondents\\)")
})


test_that("a null island is absent, not present-but-empty", {
  a <- turas_release_audit(page(island("data-micro", "null")))
  expect_false(a$microdata$present)
  expect_false(a$microdata$weights)
  expect_match(paste(a$lines, collapse = "\n"), "Respondent-level island\\s*: absent")
})


test_that("no island at all is absent, and does not error", {
  a <- turas_release_audit(page(island("data-agg", '{"questions":[]}')))
  expect_false(a$microdata$present)
  expect_true(is.na(a$microdata$n))
})


test_that("a clean minified deliverable audits PASS with nothing flagged", {
  clean <- paste0("<html><body>",
                  island("data-agg", '{"questions":[]}'),
                  island("data-micro", "null"),
                  "<script>var _0x1=function(){return 1};</script></body></html>")
  a <- turas_release_audit(clean)
  expect_equal(a$status, "PASS")
  expect_length(a$identifiers, 0L)
  expect_length(a$ip, 0L)
  expect_match(paste(a$lines, collapse = "\n"), "Engineering detail readable\\s*: none found")
})


test_that("client_safe REFUSES when the island survived, and is silent when it did not", {
  bad <- page(island("data-micro", MICRO_BODY))
  # refuse = FALSE reports the violation without raising, which is how the tests
  # and any dry run see it.
  a <- turas_release_audit(bad, client_safe = TRUE, refuse = FALSE)
  expect_true(a$client_safe_violation)
  expect_match(paste(a$lines, collapse = "\n"), "Declared delivery mode\\s*: CLIENT SAFE")
  # ...and with refuse on, it stops the delivery.
  expect_error(turas_release_audit(bad, client_safe = TRUE, refuse = TRUE))

  good <- page(island("data-micro", "null"))
  ok <- turas_release_audit(good, client_safe = TRUE, refuse = TRUE)
  expect_false(ok$client_safe_violation)
})


test_that("a full build declaring nothing never refuses, however much it carries", {
  bad <- page(island("data-micro", MICRO_BODY))
  expect_silent(a <- turas_release_audit(bad, client_safe = FALSE, refuse = TRUE))
  expect_false(a$client_safe_violation)
  expect_match(paste(a$lines, collapse = "\n"), "respondent data permitted")
})


test_that("identifier keys are caught in the respondent islands", {
  with_id <- page(island("data-qual",
    '{"records":[{"ResponseID":"R123","text":"hello"}]}'))
  expect_true("ResponseID" %in% turas_release_audit(with_id)$identifiers)
  in_micro <- page(island("data-micro", '{"n":2,"contact_id":["a","b"]}'))
  expect_true("contact_id" %in% turas_release_audit(in_micro)$identifiers)
})


test_that("the audit does not cry wolf, which is the property that keeps it read", {
  # 1. The same word in the renderer's own code or inside a verbatim is not a key.
  innocent <- paste0("<html><body>",
    island("data-qual", '{"records":[{"text":"they never answered my email"}]}'),
    "<script>var label = \"email\";</script></body></html>")
  expect_length(turas_release_audit(innocent)$identifiers, 0L)

  # 2. data-agg carries report_meta.email / .phone, which are the ANALYST's own
  #    contact details for the About page. Real reports have them and they are
  #    not a disclosure. Flagging them made every clean build look dirty.
  analyst <- page(island("data-agg",
    '{"project":{"report_meta":{"analyst":"D Brett","email":"d@trl.co.za","phone":"021 555 0000"}}}'),
    island("data-micro", "null"))
  expect_length(turas_release_audit(analyst)$identifiers, 0L)

  # 3. An empty or null field is not an identifier either.
  blank <- page(island("data-qual", '{"records":[{"email":"","ResponseID":null}]}'))
  expect_length(turas_release_audit(blank)$identifiers, 0L)
})


test_that("IP patterns are counted on a dev build and absent from a clean one", {
  dev <- paste0("<html><body><script>\n",
    "/** the stats engine. unit-tested in node. */\n",
    "// TODO: revisit after review 2026-08\n",
    "// mirrors weighting.R and build_thing.py\n",
    "//# sourceMappingURL=app.js.map\n",
    "var a=1;</script></body></html>")
  a <- turas_release_audit(dev)
  expect_true(length(a$ip) >= 5L)
  expect_true("TODO / FIXME notes" %in% names(a$ip))
  expect_true("source map reference" %in% names(a$ip))
  expect_true("R or Python source filename" %in% names(a$ip))
  expect_true("internal review reference" %in% names(a$ip))
  expect_true("JSDoc block comment" %in% names(a$ip))
  expect_match(paste(a$lines, collapse = "\n"), "did not run, or ran without the obfuscator")

  # IP findings are never fatal, even under a client-safe declaration: a build
  # can be perfectly safe for respondents and still be a dev build.
  expect_silent(turas_release_audit(dev, client_safe = TRUE, refuse = FALSE))
})


test_that("the extractor pulls the right island when several are present", {
  html <- page(island("data-agg", '{"a":1}'),
               island("data-micro", MICRO_BODY),
               island("data-qual", '{"q":2}'))
  expect_equal(release_island_body(html, "data-agg"), '{"a":1}')
  expect_equal(release_island_body(html, "data-qual"), '{"q":2}')
  expect_true(is.na(release_island_body(html, "data-nope")))
  expect_true(turas_release_audit(html)$microdata$present)
})


test_that("the audit refuses a non-string argument rather than guessing", {
  expect_error(turas_release_audit(NULL), "single string")
  expect_error(turas_release_audit(c("a", "b")), "single string")
})


# ==============================================================================
# THE COMMENT ISLAND
# ==============================================================================
# The cube audit asks whether the quantitative payload keeps its word. These ask
# the same of the qualitative one, which is where the SACS 2025 client-safe build
# was naming individuals while its crosstabs refused any group under ten. The
# audit runs BEFORE the islands are encoded (turas_minify step 8b), so the bodies
# here are plain JSON, exactly as it sees them.

qual_body <- function(comment_key = "question", cuts = "safe", text = "redacted",
                      rid = FALSE, cut = '{"Q1":1}') {
  rec <- sprintf('{"idx":0,"text":"a"%s%s}',
                 if (rid) ',"rid":"abc123"' else "",
                 if (nzchar(cut)) paste0(',"cut":', cut) else "")
  sprintf(paste0('{"textMode":"%s","demographicCuts":"%s"%s,',
                 '"n":40,"questions":[{"code":"QUAL1","records":[%s]}]}'),
          text, cuts,
          if (nzchar(comment_key)) sprintf(',"commentKey":"%s"', comment_key) else "",
          rec)
}

# One declared variable. Both cells clear k, so the cube answers for itself and a
# violation in these tests can only have come from the comment island.
CUBE_FOR_QUAL <- paste0(
  '{"k":10,"n":40,"order":2,"vars":{"Q1":{"kind":"banner","levels":[1,2]}},',
  '"slices":{"Q1":{"cells":{"1":{"a":[30,30,30]},"2":{"a":[10,10,10]}},"q":{}}}}')

# The same cube with level 2 down to three people. Its own rule flags it too, and
# that is the point: the small cell has to exist for a comment to be tagged to it.
CUBE_WITH_SMALL_CELL <- paste0(
  '{"k":10,"n":40,"order":2,"vars":{"Q1":{"kind":"banner","levels":[1,2]}},',
  '"slices":{"Q1":{"cells":{"1":{"a":[30,30,30]},"2":{"a":[3,3,3]}},"q":{}}}}')

qual_page <- function(..., cube = CUBE_FOR_QUAL) page(island("data-qual", qual_body(...)),
                                                      island("data-cube", cube))


test_that("a client-safe comment island that keeps its promises passes", {
  a <- turas_release_audit(qual_page(), client_safe = TRUE, refuse = FALSE)
  expect_length(a$qual$violations, 0)
  expect_false(a$client_safe_violation)
  expect_equal(a$qual$comment_key, "question")
  expect_equal(a$qual$records, 1L)
  expect_match(paste(a$lines, collapse = "\n"), "keyed by question")
})


test_that("comments keyed one per respondent are refused on a client-safe build", {
  # The finding this exists for: one comment can be anonymous while six from the
  # same person are a profile.
  a <- turas_release_audit(qual_page(comment_key = ""), client_safe = TRUE, refuse = FALSE)
  expect_true(a$client_safe_violation)
  expect_match(paste(a$qual$violations, collapse = " "), "join")
  expect_equal(a$status, "FLAGGED")
})


test_that("a reader token is caught even when the island declares itself safe", {
  # The declaration and the payload disagreeing is exactly what a check on the
  # declaration alone would wave through.
  a <- turas_release_audit(qual_page(comment_key = "question", rid = TRUE),
                           client_safe = TRUE, refuse = FALSE)
  expect_true(a$client_safe_violation)
  expect_match(paste(a$qual$violations, collapse = " "), "reader token")
})


test_that("un-anonymised tags and raw text are each refused", {
  a <- turas_release_audit(qual_page(cuts = "allow"), client_safe = TRUE, refuse = FALSE)
  expect_match(paste(a$qual$violations, collapse = " "), "demographicCuts = 'allow'")
  b <- turas_release_audit(qual_page(text = "full"), client_safe = TRUE, refuse = FALSE)
  expect_match(paste(b$qual$violations, collapse = " "), "textMode = 'full'")
})


test_that("a tag naming a group the cube itself calls small is refused", {
  # The check that takes nothing on trust: level 2 holds three people and the
  # cube says so, so a comment wearing that tag is refused however the dials are
  # set. This is what catches a k-anonymiser that ran against the wrong universe.
  a <- turas_release_audit(qual_page(cut = '{"Q1":2}', cube = CUBE_WITH_SMALL_CELL),
                           client_safe = TRUE, refuse = FALSE)
  expect_true(a$client_safe_violation)
  expect_match(paste(a$qual$violations, collapse = " "), "smaller than k=10")
  # And the same tag against the same cube's LARGE cell passes, so the check is
  # reading the base rather than refusing every tag it sees.
  b <- turas_release_audit(qual_page(cut = '{"Q1":1}', cube = CUBE_WITH_SMALL_CELL),
                           client_safe = TRUE, refuse = FALSE)
  expect_length(b$qual$violations, 0)
})


test_that("a tag the cube cannot price is counted and said, not passed over", {
  # Three variables against an order-2 cube. A check that could not run is not a
  # check that passed, so it reaches the face of the audit.
  a <- turas_release_audit(qual_page(cut = '{"Q1":1,"Q2":1,"Q3":1}'),
                           client_safe = TRUE, refuse = FALSE)
  expect_equal(a$qual$unverifiable, 1L)
  expect_match(paste(a$lines, collapse = "\n"), "not priceable")
})


test_that("a FULL build is not judged by the client-safe comment rules", {
  # Every dial at its most permissive, and no client-safe declaration: nothing to
  # answer for. An audit that cries wolf on a correct file gets skipped.
  a <- turas_release_audit(qual_page(comment_key = "", cuts = "allow", text = "full",
                                     rid = TRUE), client_safe = FALSE, refuse = FALSE)
  expect_false(a$client_safe_violation)
})


test_that("no comment island at all is absent, and answers for nothing", {
  a <- turas_release_audit(page(island("data-cube", CUBE_FOR_QUAL)),
                           client_safe = TRUE, refuse = FALSE)
  expect_false(a$qual$present)
  expect_length(a$qual$violations, 0)
  expect_match(paste(a$lines, collapse = "\n"), "Comment island\\s*: absent")
})


# ==============================================================================
# THE PUBLISHED MARGIN, AND WHAT "CANNOT BE PRICED" MEANS
# ==============================================================================
# Both of these were found on 6 September 2026 by running the audit by hand
# against a delivered SACS build. It reported 168 cube violations and 9 comment
# violations on a file that was correct, which is the failure mode the audit's
# own header warns about: one that fires on a good file gets skipped.

# A banner variable, its margin shipped column by column, with one small column
# suppressed exactly as the writer does it.
MARGIN_CUBE <- paste0(
  '{"k":10,"n":40,"order":2,"vars":{"Dept":{"kind":"banner","levels":[1,2]}},',
  '"slices":{"Dept":{"cells":{"1":{"a":[37,37,37]},"2":{"a":[3,3,3]}},',
  '"q":{"Q1":{"1":{"b":[37,37,37]},"2":{"b":[3,3,3],"sup":true}}}}}}')

test_that("a published banner margin may carry a column smaller than k", {
  # The crosstab already prints that column and its base. The cube suppresses
  # the CELL there rather than the cut, which is the writer's own rule.
  a <- turas_release_audit(page(island("data-cube", MARGIN_CUBE)),
                           client_safe = TRUE, refuse = FALSE)
  expect_length(a$cube$violations, 0)
  expect_false(a$client_safe_violation)
})

test_that("a small cell on a margin that is NOT suppressed is still a violation", {
  # The exemption is on the suppression marker, never on the slice: a margin cell
  # under k that still carries its answers is the thing k exists to stop.
  loose <- sub('"b":\\[3,3,3\\],"sup":true', '"b":[3,3,3]', MARGIN_CUBE)
  a <- turas_release_audit(page(island("data-cube", loose)),
                           client_safe = TRUE, refuse = FALSE)
  expect_true(length(a$cube$violations) > 0)
  expect_match(paste(a$cube$violations, collapse = " "), "between 1 and k - 1")
})

test_that("a crossing nobody published is still judged by the whole-block rule", {
  # Two variables is a crossing the workbook never printed, so there is no
  # published base to appeal to and the exemption must not reach it.
  crossed <- paste0(
    '{"k":10,"n":40,"order":2,',
    '"vars":{"Dept":{"kind":"banner","levels":[1,2]},"Q9":{"kind":"question","levels":[0,1]}},',
    '"slices":{"Dept*Q9":{"cells":{"1|0":{"a":[3,3,3]}},"q":{}}}}')
  a <- turas_release_audit(page(island("data-cube", crossed)),
                           client_safe = TRUE, refuse = FALSE)
  expect_match(paste(a$cube$violations, collapse = " "), "between 1 and k - 1")
})

test_that("a tag whose crossing the cube refused is unpriceable, not a violation", {
  # SACS 2025 refuses all three of its two-variable slices, and reading those as
  # groups of nobody accused nine safe tags of naming one person.
  refused <- paste0(
    '{"k":10,"n":40,"order":2,',
    '"vars":{"Q1":{"kind":"banner","levels":[1,2]},"Q2":{"kind":"banner","levels":[7,8]}},',
    '"slices":{"Q1":{"cells":{"1":{"a":[30,30,30]}},"q":{}},"Q1*Q2":null}}')
  a <- turas_release_audit(
    page(island("data-qual", qual_body(cut = '{"Q1":1,"Q2":7}')),
         island("data-cube", refused)),
    client_safe = TRUE, refuse = FALSE)
  expect_length(a$qual$violations, 0)
  expect_equal(a$qual$unverifiable, 1L)
  expect_false(a$client_safe_violation)
})

test_that("a cell missing from a slice the cube DID publish is also unpriceable", {
  # Same rule, one level down: the slice shipped but this cell is not in it.
  partial <- paste0(
    '{"k":10,"n":40,"order":2,"vars":{"Q1":{"kind":"banner","levels":[1,2]}},',
    '"slices":{"Q1":{"cells":{"1":{"a":[30,30,30]}},"q":{}}}}')
  a <- turas_release_audit(
    page(island("data-qual", qual_body(cut = '{"Q1":2}')),
         island("data-cube", partial)),
    client_safe = TRUE, refuse = FALSE)
  expect_length(a$qual$violations, 0)
  expect_equal(a$qual$unverifiable, 1L)
})


# ==============================================================================
# THE WHAT IF ISLAND
# ==============================================================================
# The review of 24 Sep 2026 found the audit trusting a hard-coded 0, missing
# need counts that difference across groups, missing whole-sample counts, and
# refusing a clean study of about 106 or fewer on its refit lists. Bodies here
# are the client-safe cut, as .read_whatif_contribution embeds it.

wi_body <- function(n = 100, k = 5, n_fits = 101, groups = NULL, audit = NULL, meta_extra = list(),
                    model_extra = list(), safe_extra = list()) {
  arr <- function(x) I(unname(x))
  if (is.null(groups)) groups <- list(
    list(id = "all", def = list(), n = n, need = arr(c(40, 30)), est = list(arr(c(1, 2)), arr(c(1, 2)))),
    list(id = "campus=North", def = list(campus = "North"), n = 60, need = arr(c(25, 20)), est = list(arr(c(1, 2)), arr(c(1, 2)))),
    list(id = "campus=South", def = list(campus = "South"), n = 40, need = arr(c(15, 10)), est = list(arr(c(1, 2)), arr(c(1, 2)))))
  if (is.null(audit)) audit <- list(k = k, line_failures = 0, differencing_failures = 0, recoverable_failures = 0,
                                    exact = TRUE, need_checked = TRUE, effects_checked = TRUE)
  meta <- utils::modifyList(list(kind = "whatif", mode = "safe", n = n, min_group = k,
                                 warnings = arr("Sign check: admin points the wrong way in more than 10% of refits.")),
                            meta_extra)
  model <- utils::modifyList(list(
    levers = list(list(key = "teach", label = "Teaching"), list(key = "admin", label = "Admin")),
    design = list(list(lever = "teach", part = "value", context = FALSE)),
    fits = lapply(seq_len(n_fits), function(i) list(b = arr(0.5), theta = arr(c(-1, 1)))),
    ctx_offset = arr(rep(0, n_fits)),
    notes = arr("Who the student is enters the model as a baseline.")), model_extra)
  for (nm in names(model_extra)) model[[nm]] <- model_extra[[nm]]   # replace, never merge, unnamed lists
  safe <- utils::modifyList(list(min_group = k, groups = groups, audit = audit,
                                 profile = list(keys = list(list(key = "campus", levels = arr(c("North", "South")))),
                                                fits = lapply(seq_len(n_fits), function(i) list(theta = arr(0))))),
                            safe_extra)
  as.character(jsonlite::toJSON(list(meta = meta, model = model, safe = safe), auto_unbox = TRUE, null = "null", na = "null", digits = NA))
}

test_that("a clean client-safe What if island of 100 respondents with 101 refits passes", {
  a <- release_audit_whatif(wi_body())
  expect_true(a$present)
  expect_equal(a$groups, 3L)
  expect_length(a$violations, 0)
})

test_that("the refit lists are not mistaken for respondent lists, but a respondent-length list still is", {
  a <- release_audit_whatif(wi_body(n = 100, n_fits = 101, safe_extra = list(extra = I(seq_len(97)))))
  expect_true(any(grepl("about as long as the study", a$violations)))
  b <- release_audit_whatif(wi_body(n = 100, n_fits = 96))
  expect_length(b$violations, 0)
})

test_that("the island must say its need counts and effects were checked, and that the group check was exact", {
  audit <- list(k = 5, line_failures = 0, differencing_failures = 0, recoverable_failures = 0, exact = TRUE)
  a <- release_audit_whatif(wi_body(audit = audit))
  expect_true(any(grepl("need counts and effects were checked", a$violations)))
  audit2 <- list(k = 5, line_failures = 0, differencing_failures = 0, recoverable_failures = 0,
                 need_checked = TRUE, effects_checked = TRUE)
  b <- release_audit_whatif(wi_body(audit = audit2))
  expect_true(any(grepl("did not check exactly", b$violations)))
  audit3 <- c(audit2, list(exact = TRUE, recovery_hidden = 3, nesting_hidden = 1, candidates_checked = 40))
  d <- release_audit_whatif(wi_body(audit = audit3))
  expect_true(any(grepl("counts the small cells", d$violations)))
})

test_that("need counts that difference across nested definitions are caught", {
  arr <- function(x) I(unname(x))
  groups <- list(
    list(id = "all", def = list(), n = 100, need = arr(c(40, 30)), est = list()),
    list(id = "course=MSc", def = list(course = "MSc"), n = 28, need = arr(c(9, 14)), est = list()),
    list(id = "course=MSc|year=Masters", def = list(course = "MSc", year = "Masters"), n = 17, need = arr(c(5, 9)), est = list()))
  a <- release_audit_whatif(wi_body(groups = groups))
  expect_true(any(grepl("differ between nested groups by fewer than 5", a$violations)))
  groups[[3]]$need <- arr(c(NA, 9))
  b <- release_audit_whatif(wi_body(groups = groups))
  expect_false(any(grepl("differ between nested groups", b$violations)))
  # The complement leaks too: 28 minus 9 need is 19 not needing; 17 minus 5 is 12; 19 minus 12 is 7, fine;
  # but 14 and 9 not needing on the second lever leave 14 and 8 needing, a difference of 6, fine, while
  # the second lever's complements 14 - 8 = 6 pass. Make one small.
  groups[[3]]$need <- arr(c(NA, 12))
  d <- release_audit_whatif(wi_body(groups = groups))
  expect_true(any(grepl("differ between nested groups", d$violations)))
})

test_that("whole-sample counts under the minimum are caught in meta, the levers and the text", {
  a <- release_audit_whatif(wi_body(meta_extra = list(n_by_outcome = I(c(2, 49, 49)))))
  expect_true(any(grepl("outcome category has fewer than 5", a$violations)))
  b <- release_audit_whatif(wi_body(model_extra = list(levers = list(list(key = "admin", missing = 1)))))
  expect_true(any(grepl("Don't know", b$violations)))
  d <- release_audit_whatif(wi_body(meta_extra = list(warnings = I("Only 2 respondents are Detractor."))))
  expect_true(any(grepl("count from 1 to 4", d$violations)))
  e <- release_audit_whatif(wi_body(model_extra = list(notes = I("\"Don't know\" answers were set to the median rating: Admin 1."))))
  expect_true(any(grepl("count from 1 to 4", e$violations)))
  # Percentages, decimals and numbers at or above k are not counts under k.
  f <- release_audit_whatif(wi_body(meta_extra = list(warnings = I(c(
    "Sign check: admin points the wrong way in more than 10% of refits.",
    "They correlate at 0.82. Consider averaging them.",
    "The chosen baseline penalty (100) is at the edge of the grid.",
    "Few students are Detractor. Effects at that end rest on very few people.")))))
  expect_length(f$violations, 0)
})
