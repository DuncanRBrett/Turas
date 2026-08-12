# ==============================================================================
# Tests: Patterns config echo (patterns_echo.R)
# ==============================================================================
# The echo mirrors the JS engine's matching rules, so these fixtures encode the
# same semantics the report will apply: a declaration the echo marks ✓ must be
# one the engine binds, and every ⚠ is a declaration the engine silently drops.
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home)) return(normalizePath(turas_home, mustWork = FALSE))
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}
turas_root <- detect_turas_root()

`%||%` <- function(a, b) if (is.null(a)) b else a
source(file.path(turas_root, "modules/tabs/lib/patterns_echo.R"))

# ---- fixture -----------------------------------------------------------------

mk_rated <- function(code, title = code, category = "", theme = "",
                     area_summary = FALSE, scale_max = 10) {
  q <- list(code = code, title = title, category = category, theme = theme,
            key_share = "", type = "scale", scale_max = scale_max,
            rows = list(list(kind = "mean", label = "Mean")))
  if (isTRUE(area_summary)) q$area_summary <- TRUE
  q
}

mk_share <- function(code, key_share, labels = c("Always", "Sometimes", "Never"),
                     net = "Always or often", category = "", net_diff = FALSE) {
  rows <- lapply(labels, function(l) list(kind = "category", label = l))
  rows <- c(rows, list(list(kind = "net", label = net)))
  q <- list(code = code, title = code, category = category, theme = "",
            key_share = key_share, type = "single", rows = rows)
  if (net_diff) q$net_diffs <- stats::setNames(
    list(list(plus = 1, minus = 2)), as.character(length(rows) - 1))
  q
}

mk_dl <- function(questions, project = list()) {
  list(project = project, questions = questions,
       banner_groups = list(list(id = "S01", name = "Centre"),
                            list(id = "S10", name = "Interviewer")))
}

val_of <- function(audit, label) {
  hits <- Filter(function(r) r[1] == label, audit$rows)
  if (!length(hits)) NA_character_ else hits[[1]][2]
}

# ---- activation --------------------------------------------------------------

test_that("no Patterns lever declared -> inactive, data layer untouched", {
  dl <- mk_dl(list(mk_rated("Q1", category = "Deliveries")))
  audit <- audit_patterns_config(dl)
  expect_false(audit$active)
  expect_identical(attach_patterns_echo(dl), dl)
})

# ---- banners -----------------------------------------------------------------

test_that("excluded banners: label, id and case/space variants match; typos flagged", {
  dl <- mk_dl(list(mk_rated("Q1")), project = list(
    patterns_exclude_banners = c("  interviewer ", "S01", "Intervewer")))
  audit <- audit_patterns_config(dl)
  vals <- vapply(Filter(function(r) r[1] == "Banner excluded", audit$rows),
                 function(r) r[2], character(1))
  expect_length(vals, 3)
  expect_true(grepl("^✓", vals[1]) && grepl("S10", vals[1]))      # label, any case/space
  expect_true(grepl("^✓", vals[2]) && grepl("S01", vals[2]))      # id
  expect_true(grepl("^⚠", vals[3]) && grepl("Centre, Interviewer", vals[3]))
  expect_equal(audit$n_check, 1L)
})

# ---- headline ----------------------------------------------------------------

test_that("headline codes: found+rated ✓, unknown code ⚠, non-rated ⚠", {
  share <- mk_share("Q29", key_share = "")            # not rated, no KeyShare
  dl <- mk_dl(list(mk_rated("Q78", title = "Overall performance"), share),
              project = list(takeout_headline = c("Q78", "Q99", "Q29")))
  audit <- audit_patterns_config(dl)
  vals <- vapply(Filter(function(r) r[1] == "Headline KPI", audit$rows),
                 function(r) r[2], character(1))
  expect_true(grepl("^✓ Q78 — Overall performance", vals[1]))
  expect_true(grepl("^⚠ 'Q99' matches no question code", vals[2]))
  expect_true(grepl("^⚠ Q29 is not a rated question", vals[3]))
})

# ---- KeyShare ----------------------------------------------------------------

test_that("KeyShare: NET preferred over same-named option; NBSP/case forgiven; typo flagged", {
  ok_net  <- mk_share("Q11", key_share = "Always or often")
  ok_opt  <- mk_share("Q12", key_share = paste0("always", intToUtf8(160)))  # case + NBSP
  typo    <- mk_share("Q13", key_share = "Alwys")
  dl <- mk_dl(list(ok_net, ok_opt, typo))
  audit <- audit_patterns_config(dl)
  expect_true(grepl("^✓ 'Always or often' \\(net row\\)", val_of(audit, "KeyShare Q11")))
  expect_true(grepl("^✓ 'Always' \\(category row\\)", val_of(audit, "KeyShare Q12")))
  expect_true(grepl("^⚠ 'Alwys' matches no option", val_of(audit, "KeyShare Q13")))
  expect_equal(audit$n_check, 1L)
})

test_that("KeyShare: score-difference NETs never bind; rated + classification flagged as ignored", {
  diffnet <- mk_share("Q14", key_share = "Net positive", net = "Net positive", net_diff = TRUE)
  rated   <- mk_rated("Q15"); rated$key_share <- "Always"
  classed <- mk_share("Q16", key_share = "Always", category = "Demographics")
  dl <- mk_dl(list(diffnet, rated, classed))
  audit <- audit_patterns_config(dl)
  expect_true(grepl("^⚠ 'Net positive' matches no option", val_of(audit, "KeyShare Q14")))
  expect_true(grepl("^⚠ ignored — rated question", val_of(audit, "KeyShare Q15")))
  expect_true(grepl("^⚠ ignored — classification category 'Demographics'",
                    val_of(audit, "KeyShare Q16")))
})

# ---- areas / AreaSummary -----------------------------------------------------

test_that("areas retired: AreaSummary declarations are named as no longer acting", {
  qs <- list(
    mk_rated("Q46", category = "Coolers", area_summary = TRUE),
    mk_rated("Q44", category = "Coolers"),
    mk_rated("Q27", category = "Salesperson", area_summary = TRUE)
  )
  audit <- audit_patterns_config(mk_dl(qs))
  expect_true(grepl("RETIRED", val_of(audit, "AreaSummary")))
  expect_true(grepl("2 question", val_of(audit, "AreaSummary")))
  # and no per-area race rows are echoed any more
  labels <- vapply(audit$rows, function(r) r[1], character(1))
  expect_false(any(grepl("^Area '", labels)))
})

test_that("patterns_banner: a matching selection echoes ✓; a typo warns with the fallback named", {
  qs <- list(mk_rated("Q1"))
  dl <- mk_dl(qs, project = list(patterns_banner = I(c("Centre"))))
  dl$banner_groups <- list(list(id = "S03", name = "Centre"),
                           list(id = "S09", name = "Channel"))
  audit <- audit_patterns_config(dl)
  expect_true(grepl("^✓ 'Centre'", val_of(audit, "Banner selected")))

  dl2 <- mk_dl(qs, project = list(patterns_banner = I(c("Centres"))))
  dl2$banner_groups <- dl$banner_groups
  audit2 <- audit_patterns_config(dl2)
  expect_true(grepl("falls back to ALL banners", val_of(audit2, "Banner selected")))
})

# ---- attach ------------------------------------------------------------------

test_that("attach appends a diagnostics section (creating the panel when absent) and prints", {
  dl <- mk_dl(list(mk_rated("Q78")),
              project = list(patterns_banner = "Centre", takeout_headline = "Q78"))
  out <- capture.output(dl2 <- attach_patterns_echo(dl))
  expect_true(any(grepl("GROUP OVERVIEW CONFIG", out)))
  expect_true(any(grepl("all declarations resolved", out)))
  secs <- dl2$project$diagnostics$sections
  expect_equal(secs[[length(secs)]]$title, "Group overview configuration")

  # existing diagnostics keep their sections; the echo appends after them
  dl$project$diagnostics <- list(sections = list(list(title = "Run", rows = list())),
                                 status = "PASS")
  out <- capture.output(dl3 <- attach_patterns_echo(dl))
  secs <- dl3$project$diagnostics$sections
  expect_length(secs, 2)
  expect_equal(secs[[2]]$title, "Group overview configuration")
  expect_equal(dl3$project$diagnostics$status, "PASS")

  # a ⚠ shows in the console tally
  dlw <- mk_dl(list(mk_rated("Q1")), project = list(takeout_headline = "Q99"))
  out <- capture.output(attach_patterns_echo(dlw))
  expect_true(any(grepl("1 declaration to check", out)))
})

# The console is the analyst's check and keeps every declaration. The panel that
# travels inside the report names ONE thing: which banner the overview is of
# (Duncan, 2026-08-11). CCPB W2026 shipped 30 rows of exclusions, KPIs and
# KeyShare bindings to a client who has no use for any of them.
test_that("the report panel names the selected banner and nothing else", {
  dl <- mk_dl(
    list(mk_rated("Q78"), mk_share("Q11", "Always")),
    project = list(patterns_banner = "Centre",
                   patterns_exclude_banners = c("Interviewer", "Nonesuch"),
                   takeout_headline = "Q78"))
  out <- capture.output(dl2 <- attach_patterns_echo(dl))

  # console: the full audit, warning included
  expect_true(any(grepl("Banner excluded", out, fixed = TRUE)))
  expect_true(any(grepl("Headline KPI", out, fixed = TRUE)))
  expect_true(any(grepl("KeyShare Q11", out, fixed = TRUE)))
  expect_true(any(grepl("Nonesuch", out, fixed = TRUE)))

  # panel: the selected banner only
  rows <- dl2$project$diagnostics$sections[[1]]$rows
  expect_length(rows, 1)
  expect_equal(rows[[1]][1], "Banner selected")
  expect_match(rows[[1]][2], "Centre", fixed = TRUE)
})

test_that("a selection that binds no banner still reaches the reader", {
  # Not a config note: it says the overview fell back to every banner, which
  # describes what the reader is actually looking at.
  dl <- mk_dl(list(mk_rated("Q78")), project = list(patterns_banner = "Cntre"))
  suppressWarnings(out <- capture.output(dl2 <- attach_patterns_echo(dl)))
  rows <- dl2$project$diagnostics$sections[[1]]$rows
  expect_length(rows, 1)
  expect_match(rows[[1]][2], "falls back to ALL banners")
})

test_that("a config that only excludes banners attaches no panel section", {
  dl <- mk_dl(list(mk_rated("Q78")),
              project = list(patterns_exclude_banners = "Interviewer",
                             takeout_headline = "Q78"))
  out <- capture.output(dl2 <- attach_patterns_echo(dl))
  expect_null(dl2$project$diagnostics)
  # the console still audited it
  expect_true(any(grepl("Banner excluded", out, fixed = TRUE)))
})
