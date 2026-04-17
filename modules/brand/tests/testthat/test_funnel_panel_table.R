# ==============================================================================
# BRAND MODULE TESTS - FUNNEL PANEL TABLE RENDERER (POLISH)
# ==============================================================================
# Covers the new HTML contract introduced in the table-polish pass:
#   - Base row as first tbody row (with small-base warning)
#   - Focal + Category-average rows locked (data-locked="1")
#   - Sort buttons on every stage header AND brand header
#   - Help ? buttons on every stage header
#   - Popover <template> blocks with stage definitions
#   - Per-column heatmap shading (deeper colour on larger value within column)
#   - In-cell ▲/▼ when sig_vs_avg is higher/lower
#   - data-fn-sort-<stage> + data-fn-sort-brand on every competitor row
# ==============================================================================

.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) {
      return(dir)
    }
    dir <- dirname(dir)
  }
  getwd()
}
TURAS_ROOT <- .find_turas_root_for_test()
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard_role_map.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03b_funnel_metrics.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03_funnel.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "03c_funnel_panel_data.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "lib", "html_report", "panels",
                 "03_funnel_panel_table.R"))


# --- Shared fixture helpers --------------------------------------------------

.brand_list <- function() {
  data.frame(BrandCode = c("IPK", "ROB", "CART"),
             BrandLabel = c("IPK", "Robertsons", "Cartwright"),
             stringsAsFactors = FALSE)
}

.optionmap_attitude <- function() {
  data.frame(Scale = rep("attitude_scale", 5),
             ClientCode = as.character(1:5),
             Role = c("attitude.love","attitude.prefer",
                      "attitude.ambivalent","attitude.reject",
                      "attitude.no_opinion"),
             ClientLabel = c("L","P","A","R","N"),
             OrderIndex = 1:5,
             stringsAsFactors = FALSE)
}

.structure <- function() {
  qm <- data.frame(
    Role = c("funnel.awareness","funnel.attitude",
             "funnel.transactional.bought_long",
             "funnel.transactional.bought_target",
             "funnel.transactional.frequency",
             "system.respondent.id","system.respondent.weight"),
    ClientCode = c("BRANDAWARE","QBRANDATT1",
                   "BRANDPENTRANS1","BRANDPENTRANS2","BRANDPENTRANS3",
                   "Respondent_ID","Weight"),
    QuestionText = c("Aware","Att","BL","BT","FR","RID","W"),
    QuestionTextShort = NA_character_,
    Variable_Type = c("Multi_Mention","Single_Response",
                      "Multi_Mention","Multi_Mention","Numeric",
                      "Single_Response","Numeric"),
    ColumnPattern = c("{code}_{brand_code}","{code}_{brand_code}",
                      "{code}_{brand_code}","{code}_{brand_code}",
                      "{code}_{brand_code}","{code}","{code}"),
    OptionMapScale = c("","attitude_scale","","","","",""),
    Notes = NA_character_, stringsAsFactors = FALSE)
  list(questionmap = qm, optionmap = .optionmap_attitude(),
       brands = .brand_list(), ceps = data.frame(), dba_assets = data.frame())
}

.fixture <- function() {
  read.csv(file.path(TURAS_ROOT, "modules", "brand", "tests", "fixtures",
                     "funnel_transactional_10resp.csv"),
           stringsAsFactors = FALSE)
}

.render_table <- function() {
  data <- .fixture()
  rm <- load_role_map(.structure())
  res <- run_funnel(data, rm, .brand_list(), list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0))
  pd <- build_funnel_panel_data(res, .brand_list(), list())
  build_funnel_table_section(pd)
}


#' Collapse whitespace (newlines + runs of spaces) so regexes can match
#' across the multi-line attributes the renderer emits inside <td> tags.
.flatten_html <- function(html) {
  gsub("\\s+", " ", html)
}


# --- Tests: presence of the new chrome --------------------------------------

test_that("table renders with non-empty HTML", {
  html <- .render_table()
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("<table", html))
})


test_that("Base row is present with n= values per stage", {
  html <- .render_table()
  # Uses tabs' ct-row-base pattern; n < 30 gets tabs' ct-low-base red/bold span
  expect_true(grepl('ct-row-base', html))
  expect_true(grepl('Base \\(n=\\)', html))
  expect_true(grepl('ct-low-base|ct-base-n', html))
})


test_that("Focal + category-average rows are locked (data-locked=\"1\")", {
  html <- .render_table()
  # Extract row classes with data-locked set
  expect_true(grepl('fn-row-focal[^>]*data-locked="1"', html))
  expect_true(grepl('fn-row-avg-all[^>]*data-locked="1"', html))
  expect_true(grepl('fn-row-base[^>]*data-locked="1"', html))
})


test_that("Sort buttons exist on every stage header AND brand header", {
  html <- .render_table()
  # Brand header sort button
  expect_true(grepl('data-fn-action="sort-brand"', html))
  # Stage sort buttons — should appear for each of the 4 stages
  stage_sort_count <- length(
    gregexpr('data-fn-action="sort-stage"', html)[[1]])
  expect_equal(stage_sort_count, 4)
})


test_that("Help buttons + popover templates cover every stage", {
  html <- .render_table()
  help_count <- length(gregexpr('data-fn-action="help"', html)[[1]])
  expect_equal(help_count, 4)
  tpl_count <- length(gregexpr('class="fn-help-template"', html)[[1]])
  expect_equal(tpl_count, 4)
  # Every stage key appears in a template
  for (k in c("aware", "consideration", "bought_long", "bought_target")) {
    expect_true(grepl(sprintf('fn-help-template[^>]*data-fn-stage="%s"', k),
                      html), info = sprintf("template for %s", k))
  }
})


# --- Tests: per-column heatmap ----------------------------------------------

test_that("Per-column heatmap: two cells at the same value get the same shade", {
  html <- .flatten_html(.render_table())
  # IPK/ROB both 60% at bought_long → same column max → same rgba in data-heatmap
  rgx <- 'data-heatmap="rgba\\(37,99,171,([0-9.]+)\\)"[^>]*data-fn-stage="bought_long" data-fn-brand="(IPK|ROB)"'
  hits <- regmatches(html, gregexpr(rgx, html))[[1]]
  expect_gte(length(hits), 2)
  opacities <- regmatches(hits, regexpr('rgba\\(37,99,171,[0-9.]+\\)', hits))
  expect_true(length(unique(opacities)) == 1)
})


test_that("Per-column heatmap: max-of-column always hits the top alpha", {
  html <- .flatten_html(.render_table())
  # Tabs-parity alpha range is 0.08..0.65. Column max -> 0.08 + 0.57 = 0.65.
  extract_alpha_for <- function(stage, brand) {
    pat <- sprintf(
      'data-heatmap="rgba\\(37,99,171,([0-9.]+)\\)"[^>]*data-fn-stage="%s" data-fn-brand="%s"',
      stage, brand)
    m <- regmatches(html, regexpr(pat, html))
    if (length(m) == 0 || !nzchar(m)) return(NA_real_)
    as.numeric(sub('.*rgba\\(37,99,171,([0-9.]+)\\).*', '\\1', m))
  }
  expect_equal(extract_alpha_for("aware", "IPK"), 0.65, tolerance = 0.01)
  expect_equal(extract_alpha_for("bought_long", "IPK"), 0.65, tolerance = 0.01)
})


# --- Tests: sort attributes on competitor rows ------------------------------

test_that("Every competitor row carries data-fn-sort-<stage> + data-fn-sort-brand", {
  html <- .render_table()
  # Class list is now "ct-row fn-row-competitor"
  row_matches <- regmatches(html, gregexpr(
    '<tr[^>]*class="ct-row fn-row-competitor"[^>]*>', html))[[1]]
  expect_true(length(row_matches) >= 2)
  for (row in row_matches) {
    expect_true(grepl('data-fn-sort-brand="', row), info = row)
    for (k in c("aware","consideration","bought_long","bought_target")) {
      expect_true(grepl(sprintf('data-fn-sort-%s="', k), row),
                  info = sprintf("row missing %s sort attr: %s", k, row))
    }
  }
})


# --- Tests: sig-vs-avg inline badges ----------------------------------------

test_that("Inline sig badge renders ▲ when brand is sig-higher than cat avg", {
  # Synthesise a panel payload with a single higher cell to force the badge
  # without depending on the sig tester (which requires the tabs module).
  fake_panel <- list(
    meta = list(focal_brand_code = "IPK",
                focal_brand_name = "IPK",
                stage_definitions = c(aware = "Aware defn",
                                      consideration = "Cons defn")),
    table = list(
      stage_keys = c("aware", "consideration"),
      stage_labels = c("Aware", "Consider"),
      brand_codes = c("IPK", "ROB"),
      brand_names = c("IPK", "Robertsons"),
      cells = list(
        list(stage_key = "aware", brand_code = "IPK",
             pct_absolute = 0.9, pct_nested = 0.9,
             base_weighted = 90, base_unweighted = 90,
             sig_vs_focal = "focal", sig_vs_avg = "higher",
             warning_flag = "none"),
        list(stage_key = "aware", brand_code = "ROB",
             pct_absolute = 0.5, pct_nested = 0.5,
             base_weighted = 50, base_unweighted = 50,
             sig_vs_focal = "lower", sig_vs_avg = "lower",
             warning_flag = "none"),
        list(stage_key = "consideration", brand_code = "IPK",
             pct_absolute = 0.7, pct_nested = 0.78,
             base_weighted = 70, base_unweighted = 70,
             sig_vs_focal = "focal", sig_vs_avg = "not_sig",
             warning_flag = "none"),
        list(stage_key = "consideration", brand_code = "ROB",
             pct_absolute = 0.3, pct_nested = 0.6,
             base_weighted = 30, base_unweighted = 30,
             sig_vs_focal = "lower", sig_vs_avg = "not_sig",
             warning_flag = "none")
      ),
      avg_all_brands = list()
    )
  )
  html <- build_funnel_table_section(fake_panel)
  flat <- .flatten_html(html)
  # IPK Aware (higher) should carry ▲; ROB Aware (lower) should carry ▼
  expect_true(grepl("fn-sig-up", flat))
  expect_true(grepl("fn-sig-down", flat))
  # Consideration cells have sig_vs_avg = not_sig. Extract each consideration
  # <td> block including inner spans (perl=TRUE, non-greedy).
  cons_cells <- regmatches(flat, gregexpr(
    '<td [^>]*data-fn-stage="consideration".*?</td>', flat,
    perl = TRUE))[[1]]
  expect_true(length(cons_cells) >= 2)
  for (c in cons_cells) {
    expect_false(grepl("fn-sig-up|fn-sig-down", c), info = c)
  }
})


# --- Tests: small-base warning ----------------------------------------------

test_that("Small base (n < 30) triggers ⚠ warning on cell + base row", {
  fake_panel <- list(
    meta = list(focal_brand_code = "IPK", focal_brand_name = "IPK",
                stage_definitions = c(aware = "Aware")),
    table = list(
      stage_keys = "aware", stage_labels = "Aware",
      brand_codes = c("IPK"), brand_names = c("IPK"),
      cells = list(
        list(stage_key = "aware", brand_code = "IPK",
             pct_absolute = 0.5, pct_nested = 0.5,
             base_weighted = 15, base_unweighted = 15,
             sig_vs_focal = "focal", sig_vs_avg = "na",
             warning_flag = "warn")
      ),
      avg_all_brands = list()
    )
  )
  html <- build_funnel_table_section(fake_panel)
  # Cell-level: ct-low-base-dim applied to data cells when base is below the
  # 30-threshold; base row itself uses ct-low-base with the ⚠ glyph appended.
  expect_true(grepl("ct-low-base-dim", html))
  expect_true(grepl("ct-low-base", html))
  expect_true(grepl("\u26A0", html))
})
