# ==============================================================================
# BRAND MODULE TESTS: DID THE QUESTIONNAIRE GATE THE FUNNEL QUESTIONS?
# ==============================================================================
# Turas must not draw a nested funnel from ungated questions: the picture
# would assert an ordering the survey never enforced. detect_instrument_gating()
# decides which of the two modes the report is entitled to, from the
# respondent rows rather than the aggregate totals.
#
# Two fixtures, identical in every other respect:
#   .gt_data("gated")   attitude and both purchase questions routed on
#                       awareness, and the target window routed on the longer
#                       one, exactly as ALCHEMER_GATING_GUIDE.md prescribes
#   .gt_data("ungated") every question asked about every brand, which is what
#                       ALCHEMER_PROGRAMMING_SPEC.md section 4a currently says
#                       to do
#
# Covered:
#   - the gated fixture reports gated, mode nested, no breaches
#   - the ungated fixture reports ungated, mode separate, and names the
#     stages that breached
#   - the aggregate rule alone would have missed the ungated fixture
#   - purchase is not checked against consideration
#   - the panel renders the statement on the page in both modes
#   - the nested base toggle exists only in the gated mode, and the table
#     renders each stage on its own in the ungated one
# ==============================================================================
library(testthat)

.find_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root()

shared_lib <- file.path(ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
for (f in c("00_guard.R", "00_data_access.R", "00_role_inference.R",
            "00_role_map.R", "03a_funnel_derive.R", "03b_funnel_metrics.R",
            "03_funnel.R", "03c_funnel_panel_data.R")) {
  source(file.path(ROOT, "modules", "brand", "R", f))
}
for (f in c("panels/03_funnel_panel.R", "panels/03_funnel_panel_table.R")) {
  source(file.path(ROOT, "modules", "brand", "lib", "html_report", f))
}


# ==============================================================================
# Fixtures
# ==============================================================================

.gt_brands <- function() {
  data.frame(BrandCode = c("IPK", "ROB", "CART"),
             BrandLabel = c("IPK", "Robertsons", "Cartwrights"),
             stringsAsFactors = FALSE)
}

.gt_pack_mm <- function(picks, root, n_slots = 3L) {
  as.data.frame(
    setNames(
      lapply(seq_len(n_slots), function(j)
        vapply(picks, function(p)
          if (j <= length(p)) p[j] else NA_character_, character(1))),
      paste0(root, "_", seq_len(n_slots))),
    stringsAsFactors = FALSE)
}

.gt_mm_entry <- function(role, column_root) {
  list(role = role, category = "DSS",
       client_code = sub("_DSS$", "", column_root),
       variable_type = "Multi_Mention", column_root = column_root,
       per_brand = FALSE, columns = paste0(column_root, "_", 1:3),
       applicable_brands = NULL, question_text = "", option_scale = NA,
       option_map = NULL, notes = "")
}

.gt_role_map <- function() {
  brands <- c("IPK", "ROB", "CART")
  list(
    "funnel.awareness" = .gt_mm_entry("funnel.awareness", "BRANDAWARE_DSS"),
    "funnel.attitude" = list(
      role = "funnel.attitude", category = "DSS", client_code = "BRANDATT1",
      variable_type = "Single_Response_Brand",
      column_root = "BRANDATT1_DSS", per_brand = TRUE,
      columns = setNames(paste0("BRANDATT1_DSS_", brands), brands),
      applicable_brands = brands, question_text = "Attitude?",
      option_scale = NA, option_map = NULL, notes = ""),
    "funnel.penetration_long" = .gt_mm_entry("funnel.penetration_long",
                                             "BRANDPEN1_DSS"),
    "funnel.penetration_target" = .gt_mm_entry("funnel.penetration_target",
                                               "BRANDPEN2_DSS")
  )
}

# Ten respondents. Awareness is the same in both fixtures. The gated fixture
# routes everything else on it; the ungated fixture does not.
#
# Awareness, by respondent:
#   1 IPK ROB CART | 2 IPK ROB | 3 IPK | 4 IPK CART | 5 ROB
#   6 IPK ROB CART | 7 IPK     | 8 IPK ROB | 9 CART  | 10 IPK ROB CART
.GT_AWARE <- list(
  c("IPK", "ROB", "CART"), c("IPK", "ROB"), c("IPK"), c("IPK", "CART"),
  c("ROB"), c("IPK", "ROB", "CART"), c("IPK"), c("IPK", "ROB"),
  c("CART"), c("IPK", "ROB", "CART"))

# Attitudes as they would come off an UNGATED instrument: an answer for every
# brand from every respondent, including brands the respondent never named.
# Positive is code one or two on the five-level convention.
#
# Deliberately built so that NO brand's aggregate count rises between stages.
# Positives: IPK at respondents 1, 2, 3, 4, 6 and 9, which is six against an
# aware count of eight; ROB at 1, 2, 5, 8 and 10, five against six; CART at
# 1, 4 and 6, three against five. Respondent 9 never named IPK, and that one
# row is the whole of the evidence the aggregate view cannot see.
.GT_ATT_UNGATED <- list(
  IPK  = c("1", "2", "1", "2", "3", "1", "3", "3", "2", "3"),
  ROB  = c("2", "1", "3", "3", "2", "3", "3", "1", "3", "2"),
  CART = c("1", "3", "3", "2", "3", "1", "3", "3", "3", "3"))

# Purchase as it would come off an ungated instrument. Same construction: no
# aggregate count rises, and the evidence is two respondent rows. Respondent 9
# bought IPK without ever naming it; respondent 10 bought IPK in the target
# window without buying it in the longer one, which routing makes impossible.
#   IPK long   1, 2, 3, 6, 7, 9   six against an aware count of eight
#   ROB long   1, 5, 8            three against six
#   CART long  4, 9               two against five
#   IPK target 1, 2, 6, 10        four against a long count of six
#   ROB target 1, 5               two against three
#   CART target 4                 one against two
.GT_PEN1_UNGATED <- list(
  c("IPK", "ROB"), c("IPK"), c("IPK"), c("CART"), c("ROB"),
  c("IPK"), c("IPK"), c("ROB"), c("IPK", "CART"), character(0))
.GT_PEN2_UNGATED <- list(
  c("IPK", "ROB"), c("IPK"), character(0), c("CART"), c("ROB"),
  c("IPK"), character(0), character(0), character(0), c("IPK"))

.gt_gate_picks <- function(picks, within) {
  lapply(seq_along(picks), function(i) intersect(picks[[i]], within[[i]]))
}

.gt_data <- function(mode = c("gated", "ungated")) {
  mode <- match.arg(mode)
  aware <- .GT_AWARE
  if (mode == "gated") {
    pen1 <- .gt_gate_picks(.GT_PEN1_UNGATED, aware)
    pen2 <- .gt_gate_picks(.GT_PEN2_UNGATED, pen1)
  } else {
    pen1 <- .GT_PEN1_UNGATED
    pen2 <- .GT_PEN2_UNGATED
  }
  data <- cbind(
    data.frame(Respondent_ID = 1:10, Weight = 1, stringsAsFactors = FALSE),
    .gt_pack_mm(aware, "BRANDAWARE_DSS"),
    .gt_pack_mm(pen1, "BRANDPEN1_DSS"),
    .gt_pack_mm(pen2, "BRANDPEN2_DSS"))
  for (b in c("IPK", "ROB", "CART")) {
    v <- .GT_ATT_UNGATED[[b]]
    if (mode == "gated") {
      # Routing means the question was never shown, so the cell is empty, not
      # a coded answer. NA is what the export carries for a skipped question.
      seen <- vapply(aware, function(a) b %in% a, logical(1))
      v[!seen] <- NA_character_
    }
    data[[paste0("BRANDATT1_DSS_", b)]] <- v
  }
  data
}

.gt_cfg <- function(...) {
  modifyList(list(`category.type` = "transactional", focal_brand = "IPK",
                  cat_code = "DSS", `funnel.conversion_metric` = "ratio",
                  `funnel.warn_base` = 0, `funnel.suppress_base` = 0),
             list(...))
}

.gt_run <- function(mode) {
  run_funnel(.gt_data(mode), .gt_role_map(), .gt_brands(), .gt_cfg())
}

.gt_panel <- function(mode) {
  build_funnel_panel_data(.gt_run(mode), .gt_brands(), .gt_cfg())
}

.gt_flat <- function(x) gsub("[\r\n]+", " ", paste(x, collapse = ""))


# ==============================================================================
# A gated instrument
# ==============================================================================

test_that("A gated instrument reports gated, with no breaches", {
  res <- .gt_run("gated")
  g <- res$meta$gating
  expect_true(g$gated)
  expect_equal(g$mode, "nested")
  expect_length(g$breach_stages, 0L)
  expect_true(grepl("routed these questions", g$statement, fixed = TRUE))
})


test_that("The gated fixture nests everywhere the routing makes it nest", {
  res <- .gt_run("gated")
  s <- res$stages
  n <- function(b, k) s$base_unweighted[s$brand_code == b & s$stage_key == k]
  for (b in c("IPK", "ROB", "CART")) {
    # The three relations the template's routing enforces. Purchase is not
    # among them: buying is routed on awareness, not on attitude.
    expect_lte(n(b, "consideration"), n(b, "aware"), label = b)
    expect_lte(n(b, "bought_long"), n(b, "aware"), label = b)
    expect_lte(n(b, "bought_target"), n(b, "bought_long"), label = b)
  }
})


# ==============================================================================
# An ungated instrument
# ==============================================================================

test_that("An ungated instrument reports ungated and names the stages", {
  res <- .gt_run("ungated")
  g <- res$meta$gating
  expect_false(g$gated)
  expect_equal(g$mode, "separate")
  expect_true("consideration" %in% g$breach_stages)
  expect_true(any(c("bought_long", "bought_target") %in% g$breach_stages))
  # The statement reports what was observed. It must not claim the
  # questionnaire asked every question about every brand: one impossible row
  # is enough to reach this branch, and that is not evidence of an
  # instrument. See .funnel_gating_sentence().
  expect_true(grepl("which routing would have made impossible", g$statement,
                    fixed = TRUE))
  expect_false(grepl("asked every one of them about every brand", g$statement,
                     fixed = TRUE))
  expect_true(grepl("nested funnel view is not offered", g$statement,
                    fixed = TRUE))
})


test_that("The respondent-level rule catches what the aggregate rule misses", {
  res <- .gt_run("ungated")
  s <- res$stages
  n <- function(b, k) s$base_unweighted[s$brand_code == b & s$stage_key == k]
  # Not one aggregate count rises anywhere, on any of the three relations the
  # routing would enforce. An aggregate test sees a perfectly nested funnel.
  rose <- FALSE
  for (b in c("IPK", "ROB", "CART")) {
    if (n(b, "consideration") > n(b, "aware")) rose <- TRUE
    if (n(b, "bought_long") > n(b, "aware")) rose <- TRUE
    if (n(b, "bought_target") > n(b, "bought_long")) rose <- TRUE
  }
  expect_false(rose)
  # The instrument is ungated all the same, and the respondent-level test
  # says so, on all three relations.
  expect_false(res$meta$gating$gated)
  expect_setequal(res$meta$gating$breach_stages,
                  c("consideration", "bought_long", "bought_target"))
})


test_that("Purchase is not checked against consideration", {
  res <- .gt_run("gated")
  # The gated fixture routes purchase on awareness, not on attitude, so
  # respondents buy brands they are lukewarm about. That is not a gating
  # breach and must not be reported as one.
  d <- derive_funnel_stages(.gt_data("gated"), .gt_role_map(),
                            "transactional", .gt_brands(), cat_code = "DSS")
  cons <- d$stages$consideration$matrix
  long <- d$stages$bought_long$matrix
  expect_gt(sum(long & !cons, na.rm = TRUE), 0)
  expect_true(res$meta$gating$gated)
  expect_false("bought_long" %in% res$meta$gating$breach_stages)
})


test_that("A single impossible row is enough to report ungated", {
  data <- .gt_data("gated")
  # Respondent 5 named ROB only. Give them an attitude for IPK.
  data$BRANDATT1_DSS_IPK[5] <- "1"
  res <- run_funnel(data, .gt_role_map(), .gt_brands(), .gt_cfg())
  expect_false(res$meta$gating$gated)
  expect_equal(res$meta$gating$breach_stages, "consideration")
})


# ==============================================================================
# The report says which mode it is in
# ==============================================================================

test_that("The panel carries the gating finding to the report", {
  for (mode in c("gated", "ungated")) {
    pd <- .gt_panel(mode)
    expect_false(is.null(pd$meta$gating), info = mode)
    expect_true(nzchar(pd$meta$gating$statement), info = mode)
  }
})


test_that("The statement is on the face of the report in both modes", {
  gated_html <- .gt_flat(.fn_gating_notice(.gt_panel("gated")))
  ungated_html <- .gt_flat(.fn_gating_notice(.gt_panel("ungated")))
  expect_true(grepl('data-fn-gating="gated"', gated_html, fixed = TRUE))
  expect_true(grepl("Nested funnel", gated_html, fixed = TRUE))
  expect_true(grepl("routed these questions", gated_html, fixed = TRUE))

  expect_true(grepl('data-fn-gating="ungated"', ungated_html, fixed = TRUE))
  expect_true(grepl("Separate measures", ungated_html, fixed = TRUE))
  expect_true(grepl("which routing would have made impossible", ungated_html,
                    fixed = TRUE))
  expect_false(grepl("asked every one of them about every brand",
                     ungated_html, fixed = TRUE))
})


test_that("The statement describes each kind of breach in its own terms", {
  st <- .gt_run("ungated")$meta$gating$statement
  # The ungated fixture breaches all three ways. An awareness breach and a
  # purchase-window breach are different facts and must not share a phrase.
  expect_true(grepl(
    "an answer at the Consider stage for a brand they did not name as known",
    st, fixed = TRUE))
  expect_true(grepl(
    "a purchase in the shorter window without one in the longer window",
    st, fixed = TRUE))
  # The stage names read as names, not as lowercased fragments.
  expect_false(grepl("reached consider", st, fixed = TRUE))
  expect_false(grepl(" consider for brands", st, fixed = TRUE))
  # The ratios are behind the base toggle, not printed beside the figures.
  expect_true(grepl("available through the base toggle above the table", st,
                    fixed = TRUE))
  expect_false(grepl("beside them", st, fixed = TRUE))
})


test_that("A lone awareness breach does not mention purchase windows", {
  data <- .gt_data("gated")
  data$BRANDATT1_DSS_IPK[5] <- "1"
  st <- run_funnel(data, .gt_role_map(), .gt_brands(),
                   .gt_cfg())$meta$gating$statement
  expect_true(grepl("did not name as known", st, fixed = TRUE))
  expect_false(grepl("shorter window", st, fixed = TRUE))
})


test_that("One breaching pair says so, and does not indict the instrument", {
  # Review finding F3. One cleared cell in twelve hundred reaches this
  # branch. The reader is owed the scale of what was found, so the sentence
  # says the other pairs nested and stops claiming anything about how the
  # questionnaire was written.
  data <- .gt_data("gated")
  data$BRANDATT1_DSS_IPK[5] <- "1"
  st <- run_funnel(data, .gt_role_map(), .gt_brands(),
                   .gt_cfg())$meta$gating$statement
  expect_true(grepl("Every other pair of stages nested cleanly", st,
                    fixed = TRUE))
  expect_false(grepl("asked every one of them about every brand", st,
                     fixed = TRUE))
  expect_false(grepl("[0-9]", st))
})


test_that("The clean-pairs clause counts pairs, and vanishes when none is clean", {
  # The ungated fixture breaches three of the four checked pairs, so exactly
  # one is left and the clause reads in the singular.
  st <- .gt_run("ungated")$meta$gating$statement
  expect_true(grepl("The other pair of stages nested cleanly", st,
                    fixed = TRUE))
  # With every checked pair breaching there is nothing clean to report.
  none_clean <- list(
    gated = FALSE,
    checked = data.frame(stage_key = c("consideration", "bought_long"),
                         against = c("aware", "aware"),
                         stringsAsFactors = FALSE),
    breaches = data.frame(stage_key = c("consideration", "bought_long"),
                          against = c("aware", "aware"),
                          brand_code = c("IPK", "IPK"),
                          n_respondents = c(3L, 4L),
                          stringsAsFactors = FALSE))
  expect_identical(.funnel_clean_pairs_clause(none_clean), "")
  expect_false(grepl("nested cleanly",
                     .funnel_gating_sentence(none_clean), fixed = TRUE))
})


test_that("The statement carries no digits, so the island gate stays exact", {
  for (mode in c("gated", "ungated")) {
    st <- .gt_panel(mode)$meta$gating$statement
    expect_false(grepl("[0-9]", st), info = paste(mode, st))
  }
})


test_that("The nested base toggle exists only when the survey routed", {
  gated_html <- .gt_flat(.fn_table_controls(.gt_panel("gated")))
  ungated_html <- .gt_flat(.fn_table_controls(.gt_panel("ungated")))

  expect_true(grepl('data-fn-pctmode="chain"', gated_html, fixed = TRUE))
  expect_false(grepl('data-fn-pctmode="chain"', ungated_html, fixed = TRUE))

  active_gated <- regmatches(gated_html, regexpr(
    '<button[^>]*sig-btn-active[^>]*data-fn-action="pctmode"[^>]*>',
    gated_html, perl = TRUE))
  active_ungated <- regmatches(ungated_html, regexpr(
    '<button[^>]*sig-btn-active[^>]*data-fn-action="pctmode"[^>]*>',
    ungated_html, perl = TRUE))
  expect_true(grepl('data-fn-pctmode="chain"', active_gated))
  expect_true(grepl('data-fn-pctmode="total"', active_ungated))

  # The two conversion ratios stay reachable in both modes: consideration
  # among the aware, and each stage over the one before it.
  for (h in list(gated_html, ungated_html)) {
    expect_true(grepl('data-fn-pctmode="aware"', h, fixed = TRUE))
    expect_true(grepl('data-fn-pctmode="previous"', h, fixed = TRUE))
  }
})


test_that("The how-this-works drawer explains the missing view", {
  ungated <- .gt_flat(.fn_base_howto(.gt_panel("ungated")))
  gated   <- .gt_flat(.fn_base_howto(.gt_panel("gated")))
  expect_true(grepl("is not offered on this survey", ungated, fixed = TRUE))
  expect_false(grepl("is not offered on this survey", gated, fixed = TRUE))
})


test_that("The ungated table renders each stage on its own, not the chain", {
  gated_tbl <- .gt_flat(build_funnel_table_section(.gt_panel("gated")))
  ungated_tbl <- .gt_flat(build_funnel_table_section(.gt_panel("ungated")))

  .first_cell <- function(html, stage, brand) {
    m <- regmatches(html, regexpr(sprintf(
      '<td[^>]*data-fn-stage="%s" data-fn-brand="%s"[^>]*>.*?</td>',
      stage, brand), html, perl = TRUE))
    m[1]
  }
  chn_of <- function(cell) as.numeric(sub(
    '.*data-fn-pct-chn="([0-9.]+)".*', "\\1", cell))
  abs_of <- function(cell) as.numeric(sub(
    '.*data-fn-pct-abs="([0-9.]+)".*', "\\1", cell))

  # Ungated: at every stage and every brand the chain attribute falls back to
  # the stage's own figure, so nothing on the page asserts a chain the survey
  # never enforced.
  for (k in c("aware", "consideration", "bought_long", "bought_target")) {
    for (b in c("IPK", "ROB", "CART")) {
      cell <- .first_cell(ungated_tbl, k, b)
      expect_equal(chn_of(cell), abs_of(cell), info = paste(k, b))
    }
  }
  # Gated: the chain is a real, separate number. IPK's long-window buyers
  # include one respondent who is not in the chain at that stage.
  g_cell <- .first_cell(gated_tbl, "bought_long", "IPK")
  expect_lt(chn_of(g_cell), abs_of(g_cell))
})


test_that("The About methodology note states the mode rather than refusing", {
  for (mode in c("gated", "ungated")) {
    note <- .gt_panel(mode)$about$methodology_note
    expect_false(grepl("refuses to render", note, fixed = TRUE), info = mode)
    # "routed" when gated, "routing" when not: the note explains the routing
    # question in both modes rather than refusing to say anything.
    expect_true(grepl("rout", note, fixed = TRUE), info = mode)
  }
})
