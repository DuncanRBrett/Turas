# ==============================================================================
# TABS MODULE - WHAT IF ISLAND: THE DELIVERY CHOICE, THE BUILD, THE AUDIT
# ==============================================================================
#
# The whatif module writes one contribution file with an open part (a row per
# respondent) and a client-safe part (published groups). The tabs build keeps
# the part this report's delivery mode allows (.read_whatif_contribution in
# run_crosstabs.R). These tests pin that choice, the line-up of open rows with
# the report's own records, the build of a real report with the island in it,
# and the release audit's refusal of a client-safe file that still carries the
# open part.
#
# Fixture: modules/tabs/tests/fixtures/whatif/synthetic_whatif_island.json,
# synthetic data only (modules/whatif/dev/make_tabs_fixture.R).
# ==============================================================================

library(testthat)

detect_root <- function() {
  home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(home) && dir.exists(file.path(home, "modules"))) return(normalizePath(home))
  d <- normalizePath(getwd(), mustWork = FALSE)
  for (i in 1:8) {
    if (dir.exists(file.path(d, "modules", "tabs"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("cannot find the Turas root")
}
root <- detect_root()

suppressWarnings(suppressMessages({
  for (f in sort(list.files(file.path(root, "modules", "shared", "lib"),
                            pattern = "[.]R$", full.names = TRUE))) {
    try(source(f), silent = TRUE)
  }
  source(file.path(root, "modules", "tabs", "lib", "html_report_v2", "build_report_v2.R"))
}))

# The two reader functions, sourced on their own (run_crosstabs.R is large).
extract_fn <- function(name) {
  src <- readLines(file.path(root, "modules", "tabs", "lib", "run_crosstabs.R"), warn = FALSE)
  start <- grep(paste0("^\\", name, " <- function"), src)
  stopifnot(length(start) == 1)
  end <- start
  depth <- 0L
  repeat {
    depth <- depth + lengths(regmatches(src[end], gregexpr("\\{", src[end]))) -
      lengths(regmatches(src[end], gregexpr("\\}", src[end])))
    if (depth <= 0 && end > start) break
    end <- end + 1L
  }
  eval(parse(text = paste(src[start:end], collapse = "\n")), envir = globalenv())
}
extract_fn(".read_whatif_contribution")
extract_fn(".whatif_open_payload")

FIXTURE <- file.path(root, "modules", "tabs", "tests", "fixtures", "whatif", "synthetic_whatif_island.json")
fx <- jsonlite::fromJSON(FIXTURE, simplifyVector = FALSE)
ids <- vapply(fx$open$ids, as.character, "")

# A tabs data frame holding the What if respondents in another order, plus two
# the What if run left out (partial interviews), the way SACAP 2025 arrives.
survey_data <- data.frame(ID = c(rev(ids), "P0001", "P0002"), Q1 = "x", stringsAsFactors = FALSE)

read_wi <- function(mode, data = survey_data, cfg = list(whatif_island = FIXTURE)) {
  out <- NULL
  utils::capture.output(out <- .read_whatif_contribution(cfg, mode, data))
  if (is.null(out)) NULL else jsonlite::fromJSON(out, simplifyVector = FALSE)
}

test_that("an ordinary tabs run reads no What if contribution", {
  expect_null(.read_whatif_contribution(list(), "records", survey_data))
  expect_null(.read_whatif_contribution(list(whatif_island = ""), "records", survey_data))
})

test_that("a missing or foreign file warns and carries on without the tab", {
  out <- capture.output(res <- .read_whatif_contribution(list(whatif_island = "/no/such.json"), "records", survey_data))
  expect_null(res)
  expect_true(any(grepl("without the What if tab", out)))
  f <- tempfile(fileext = ".json")
  writeLines('{"meta":{"kind":"catdriver"}}', f)
  out <- capture.output(res <- .read_whatif_contribution(list(whatif_island = f), "records", survey_data))
  expect_null(res)
  expect_true(any(grepl("not a What if contribution", out)))
})

test_that("a full report gets the open part, lined up with its own records, and no IDs", {
  wi <- read_wi("records")
  expect_equal(wi$meta$mode, "open")
  expect_null(wi$meta$id_variable)
  expect_null(wi$safe)
  expect_null(wi$open$ids)
  expect_equal(wi$open$n, nrow(survey_data))
  expect_equal(wi$open$modelled, length(ids))
  # Row i of the embedded arrays is row i of the report's data.
  y_fix <- vapply(fx$open$y, as.numeric, 0)
  y_emb <- vapply(wi$open$y, function(v) if (is.null(v)) NA_real_ else as.numeric(v), 0)
  expect_equal(y_emb[seq_along(ids)], rev(y_fix))
  expect_true(all(is.na(y_emb[length(ids) + 1:2])))
  k1 <- names(fx$open$val)[1]
  v_emb <- vapply(wi$open$val[[k1]], function(v) if (is.null(v)) NA_real_ else as.numeric(v), 0)
  v_fix <- vapply(fx$open$val[[k1]], function(v) if (is.null(v)) NA_real_ else as.numeric(v), 0)
  expect_equal(v_emb[seq_along(ids)], rev(v_fix))
})

test_that("a client-safe report gets only the published groups and the client-safe model", {
  for (mode in c("cube", "none")) {
    wi <- read_wi(mode)
    expect_equal(wi$meta$mode, "safe")
    expect_null(wi$open)
    expect_null(wi$profile)
    expect_null(wi$meta$id_variable)
    expect_null(wi$safe$model)
    expect_false(any(vapply(wi$model$design, function(c) isTRUE(c$context), logical(1))))
    expect_true(any(vapply(fx$model$design, function(c) isTRUE(c$context), logical(1))))
    expect_equal(length(wi$safe$groups), length(fx$safe$groups))
    expect_false(any(vapply(wi$safe$profile$keys, function(k) !is.null(k$n), logical(1))))
  }
})

test_that("a contribution file from before the client-safe model block is not embedded", {
  old <- fx
  old$safe$model <- NULL
  f <- tempfile(fileext = ".json")
  writeLines(as.character(jsonlite::toJSON(old, auto_unbox = TRUE, null = "null", na = "null", digits = NA)), f)
  out <- capture.output(res <- .read_whatif_contribution(list(whatif_island = f), "cube", survey_data))
  expect_null(res)
})

test_that("open rows that cannot be lined up fall back to the client-safe part", {
  no_id <- data.frame(Other = ids, stringsAsFactors = FALSE)
  expect_equal(read_wi("records", no_id)$meta$mode, "safe")
  short <- survey_data[-1, , drop = FALSE]
  expect_equal(read_wi("records", short)$meta$mode, "safe")
  dup <- rbind(survey_data, survey_data[1, , drop = FALSE])
  expect_equal(read_wi("records", dup)$meta$mode, "safe")
  bom <- survey_data
  names(bom)[1] <- "﻿ID"
  expect_equal(read_wi("records", bom)$meta$mode, "open")
})

test_that("a client-safe report whose minimum is stricter than the What if file leaves the tab out", {
  out <- capture.output(res <- .read_whatif_contribution(
    list(whatif_island = FIXTURE, min_reporting_base = 10), "cube", survey_data))
  expect_null(res)
  expect_true(any(grepl("DISCLOSURE WARNING", out)))
  expect_false(is.null(read_wi("cube", cfg = list(whatif_island = FIXTURE, min_reporting_base = 5))))
})

V2_ASSETS <- file.path(root, "modules", "tabs", "lib", "html_report_v2", "assets")
build_probe <- function(wi_json = NULL) {
  build_report_v2_html('{"questions":[]}', list(project_title = "What if island test"),
                       assets_dir = V2_ASSETS, wi_json = wi_json)
}

test_that("a report without a What if study carries a null island and no renderer", {
  html <- build_probe(NULL)
  expect_match(html, 'id="data-wi"[^>]*>\\s*null', perl = TRUE)
  expect_false(grepl("TR.whatif = {}", html, fixed = TRUE))
})

test_that("a report with one carries the island and its renderer, and a hostile label stays inert", {
  wi <- fx
  wi$model$levers[[1]]$label <- "</script><script>alert(1)</script>"
  txt <- as.character(jsonlite::toJSON(wi, auto_unbox = TRUE, null = "null", na = "null", digits = NA))
  html <- build_probe(txt)
  expect_true(grepl("TR.whatif = {}", html, fixed = TRUE))
  expect_false(grepl("</script><script>alert(1)", html, fixed = TRUE))
  expect_match(html, 'id="data-wi" data-island="v2"', fixed = TRUE)
})

test_that("the release audit refuses a client-safe file that carries the open part", {
  open_txt <- as.character(jsonlite::toJSON(read_wi("records"), auto_unbox = TRUE, null = "null", na = "null", digits = NA))
  html <- build_probe(open_txt)
  a <- turas_release_audit(html, client_safe = TRUE, refuse = FALSE)
  expect_true(a$client_safe_violation)
  expect_true(any(grepl("one row per respondent", a$whatif$violations)))
  expect_error(utils::capture.output(turas_release_audit(html, client_safe = TRUE, refuse = TRUE)),
               class = "turas_refusal")
  a_full <- turas_release_audit(html, client_safe = FALSE, refuse = FALSE)
  expect_false(a_full$client_safe_violation)
})

test_that("the release audit passes the client-safe part and catches a planted small group", {
  safe <- read_wi("cube")
  safe_txt <- as.character(jsonlite::toJSON(safe, auto_unbox = TRUE, null = "null", na = "null", digits = NA))
  a <- turas_release_audit(build_probe(safe_txt), client_safe = TRUE, refuse = FALSE)
  expect_true(a$whatif$present)
  expect_length(a$whatif$violations, 0)
  expect_false(a$client_safe_violation)
  safe$safe$groups[[2]]$n <- 3
  bad <- as.character(jsonlite::toJSON(safe, auto_unbox = TRUE, null = "null", na = "null", digits = NA))
  a2 <- turas_release_audit(build_probe(bad), client_safe = TRUE, refuse = FALSE)
  expect_true(a2$client_safe_violation)
  expect_true(any(grepl("under the minimum", a2$whatif$violations)))
  safe$safe$groups[[2]]$n <- 30
  safe$safe$refused <- list(list(group = "Campus: Tiny", why = "under 5"))
  named <- as.character(jsonlite::toJSON(safe, auto_unbox = TRUE, null = "null", na = "null", digits = NA))
  a3 <- turas_release_audit(build_probe(named), client_safe = TRUE, refuse = FALSE)
  expect_true(any(grepl("names the groups", a3$whatif$violations)))
})

test_that("the release audit catches leaks it can see from the island alone", {
  base <- read_wi("cube")
  audit_of <- function(w) {
    txt <- as.character(jsonlite::toJSON(w, auto_unbox = TRUE, null = "null", na = "null", digits = NA))
    turas_release_audit(build_probe(txt), client_safe = TRUE, refuse = FALSE)$whatif$violations
  }
  expect_length(audit_of(base), 0)
  # A hidden level of 3: the whole sample is 3 more than one variable's
  # published levels.
  w <- base
  defs <- lapply(w$safe$groups, function(g) unlist(g$def))
  key <- names(defs[[which(lengths(defs) == 1)[1]]])
  singles_n <- sum(vapply(seq_along(defs), function(i)
    if (length(defs[[i]]) == 1 && names(defs[[i]]) == key) w$safe$groups[[i]]$n else 0, 0))
  w$safe$groups[[which(lengths(defs) == 0)]]$n <- singles_n + 3
  expect_true(any(grepl("leaves fewer than", audit_of(w))))
  # A context-baseline coefficient back in the model.
  w <- base
  w$model$design[[length(w$model$design) + 1]] <- list(lever = "campus", part = "Tiny", context = TRUE)
  expect_true(any(grepl("context-baseline", audit_of(w))))
  # A need count of 3.
  w <- base
  w$safe$groups[[1]]$need[[1]] <- 3
  expect_true(any(grepl("need count", audit_of(w))))
  # Per-level counts in Build a ... .
  w <- base
  w$safe$profile$keys[[1]]$n <- list(3, 100)
  expect_true(any(grepl("per-level counts", audit_of(w))))
  # A list about as long as the study.
  w <- base
  w$safe$extra <- as.list(seq_len(w$meta$n - 1))
  expect_true(any(grepl("about as long as the study", audit_of(w))))
})
