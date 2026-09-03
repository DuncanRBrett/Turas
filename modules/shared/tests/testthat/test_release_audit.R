# ==============================================================================
# TESTS: release audit (modules/shared/lib/turas_release_audit.R)
# ==============================================================================
# The audit is the last thing between a build and a client. These tests hold it
# to two properties: it must not miss a populated respondent island, and it must
# not cry wolf on a clean one. A noisy audit gets ignored, which is the same as
# no audit.
# ==============================================================================

if (!exists("turas_release_audit", mode = "function")) {
  .root <- rprojroot::find_root(rprojroot::has_dir(".git"))
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
