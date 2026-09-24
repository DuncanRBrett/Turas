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
top <- jsonlite::fromJSON(FIXTURE, simplifyVector = FALSE)
fx <- top$variants$weighted      # the fixture has a weight column W
ids <- vapply(fx$open$ids, as.character, "")

# A tabs data frame holding the What if respondents in another order, plus two
# the What if run left out (partial interviews), the way SACAP 2025 arrives.
survey_data <- data.frame(ID = c(rev(ids), "P0001", "P0002"), Q1 = "x", stringsAsFactors = FALSE)

WEIGHTED <- list(whatif_island = FIXTURE, apply_weighting = TRUE, weight_variable = "W")
read_wi <- function(mode, data = survey_data, cfg = WEIGHTED) {
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

test_that("a client-safe report takes the client-safe meta fields: warnings without counts, outcome counts only when all clear the minimum", {
  wi <- read_wi("cube")
  expect_null(wi$safe$meta)
  expect_equal(unlist(wi$meta$warnings), unlist(fx$safe$meta$warnings))
  expect_false(identical(unlist(wi$meta$warnings), unlist(fx$meta$warnings)))
  expect_false(any(grepl("[0-9]+ answers", unlist(wi$meta$warnings))))
  expect_true(all(vapply(wi$model$levers, function(lv) is.null(lv$missing), logical(1))))
  expect_false(any(grepl("Don't know", unlist(wi$model$notes), fixed = TRUE)))
  expect_true(any(grepl("Don't know", unlist(fx$model$notes), fixed = TRUE)))
  # The fixture's outcome counts all clear the minimum, so they ship; cut one
  # to three and the safe part says null, which the reader passes on.
  small <- top
  small$variants$weighted$safe$meta$n_by_outcome <- NULL
  f <- tempfile(fileext = ".json")
  writeLines(as.character(jsonlite::toJSON(small, auto_unbox = TRUE, null = "null", na = "null", digits = NA)), f)
  wi2 <- read_wi("cube", cfg = modifyList(WEIGHTED, list(whatif_island = f)))
  expect_null(wi2$meta$n_by_outcome)
  expect_false(is.null(read_wi("records")$meta$n_by_outcome))
  # A full report keeps the open meta.
  expect_equal(unlist(read_wi("records")$meta$warnings), unlist(fx$meta$warnings))
})

test_that("a contribution file from before the client-safe meta block is not embedded", {
  old <- top
  old$variants$weighted$safe$meta <- NULL
  f <- tempfile(fileext = ".json")
  writeLines(as.character(jsonlite::toJSON(old, auto_unbox = TRUE, null = "null", na = "null", digits = NA)), f)
  out <- capture.output(res <- .read_whatif_contribution(modifyList(WEIGHTED, list(whatif_island = f)), "cube", survey_data))
  expect_null(res)
  expect_true(any(grepl("not a complete", out)))
})

test_that("a contribution file from before the client-safe model block is not embedded", {
  old <- top
  old$variants$weighted$safe$model <- NULL
  f <- tempfile(fileext = ".json")
  writeLines(as.character(jsonlite::toJSON(old, auto_unbox = TRUE, null = "null", na = "null", digits = NA)), f)
  out <- capture.output(res <- .read_whatif_contribution(modifyList(WEIGHTED, list(whatif_island = f)), "cube", survey_data))
  expect_null(res)
})

test_that("the tab follows the report's weighting: weighted, unweighted, or left out", {
  u <- read_wi("records", cfg = list(whatif_island = FIXTURE, apply_weighting = FALSE))
  expect_false(u$meta$weighted)
  expect_equal(unlist(u$model$fits[[1]]$b), unlist(top$variants$unweighted$model$fits[[1]]$b))
  w <- read_wi("records")
  expect_true(w$meta$weighted)
  expect_equal(unlist(w$model$fits[[1]]$b), unlist(top$variants$weighted$model$fits[[1]]$b))
  out <- capture.output(res <- .read_whatif_contribution(
    list(whatif_island = FIXTURE, apply_weighting = TRUE, weight_variable = "other_weight"), "records", survey_data))
  expect_null(res)
  expect_true(any(grepl("left out", out)))
  only_u <- top
  only_u$variants$weighted <- NULL
  f <- tempfile(fileext = ".json")
  writeLines(as.character(jsonlite::toJSON(only_u, auto_unbox = TRUE, null = "null", na = "null", digits = NA)), f)
  out <- capture.output(res <- .read_whatif_contribution(modifyList(WEIGHTED, list(whatif_island = f)), "cube", survey_data))
  expect_null(res)
  expect_false(is.null(read_wi("cube", cfg = list(whatif_island = f, apply_weighting = FALSE))))
  old <- fx
  f2 <- tempfile(fileext = ".json")
  writeLines(as.character(jsonlite::toJSON(old, auto_unbox = TRUE, null = "null", na = "null", digits = NA)), f2)
  out <- capture.output(res <- .read_whatif_contribution(list(whatif_island = f2), "records", survey_data))
  expect_null(res)
  expect_true(any(grepl("earlier What if version", out)))
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
    modifyList(WEIGHTED, list(min_reporting_base = 10)), "cube", survey_data))
  expect_null(res)
  expect_true(any(grepl("DISCLOSURE WARNING", out)))
  expect_false(is.null(read_wi("cube", cfg = modifyList(WEIGHTED, list(min_reporting_base = 5)))))
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
  # The refit lists are as long as the fits, never mistaken for respondents.
  expect_equal(length(base$model$ctx_offset), length(base$model$fits))
  # An outcome category under the minimum, a "Don't know" count, a count in a
  # warning, and an audit that does not record the need and effect checks.
  w <- base
  w$meta$n_by_outcome <- list(3, 80, 77)
  expect_true(any(grepl("outcome category", audit_of(w))))
  w <- base
  w$model$levers[[1]]$missing <- 2
  expect_true(any(grepl("Don't know", audit_of(w))))
  w <- base
  w$meta$warnings <- list("Only 2 respondents are Detractor.")
  expect_true(any(grepl("count from 1 to", audit_of(w))))
  w <- base
  w$safe$audit$effects_checked <- FALSE
  expect_true(any(grepl("need counts and effects were checked", audit_of(w))))
  # Two nested definitions whose shown need counts differ by three.
  w <- base
  defs <- lapply(w$safe$groups, function(g) unlist(g$def))
  outer <- which(lengths(defs) == 1)[1]
  inner <- which(vapply(defs, function(d) length(d) == 2 && names(defs[[outer]]) %in% names(d) &&
                          d[[names(defs[[outer]])]] == defs[[outer]][[1]], logical(1)))[1]
  expect_false(is.na(inner))
  w$safe$groups[[outer]]$need[[1]] <- 40
  w$safe$groups[[inner]]$need[[1]] <- 37
  expect_true(any(grepl("differ between nested groups", audit_of(w))))
})

test_that("a full report carries the don't-know flags, lined up like every other open row", {
  wi <- read_wi("records")
  expect_equal(names(wi$open$dk), names(fx$open$val))
  d_fix <- vapply(fx$open$dk$admin, as.numeric, 0)
  d_emb <- vapply(wi$open$dk$admin, function(v) if (is.null(v)) NA_real_ else as.numeric(v), 0)
  expect_equal(d_emb[seq_along(ids)], rev(d_fix))
  expect_true(all(is.na(d_emb[length(ids) + 1:2])))
  expect_equal(sum(d_fix), 20)
  for (mode in c("cube", "none")) expect_null(read_wi(mode)$open)
})

test_that("both model blocks carry the halo check", {
  expect_equal(names(fx$model$halo), vapply(fx$model$levers, `[[`, "", "key"))
  wi <- read_wi("cube")
  expect_equal(names(wi$model$halo), names(fx$model$halo))
  expect_true(any(vapply(wi$model$halo, function(h) isTRUE(h$flag), logical(1))))
})
