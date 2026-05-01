# ==============================================================================
# BRAND MODULE TESTS — FUNNEL PANEL TABLE RENDERER — v2 port
# ==============================================================================
# Covers the HTML contract for the table-polish pass:
#   - Base row as first tbody row (with small-base warning)
#   - Focal + Category-average rows locked (data-locked="1")
#   - Sort buttons on every stage header AND brand header
#   - Per-column heatmap shading (deeper colour on larger value within column)
#   - In-cell ▲/▼ when sig_vs_avg is higher/lower
#   - data-fn-sort-<stage> + data-fn-sort-brand on every competitor row
#   - Stage column headers render for every stage (data-fn-stage attribute)
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
source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(ROOT, "modules", "brand", "R", "03b_funnel_metrics.R"))
source(file.path(ROOT, "modules", "brand", "R", "03_funnel.R"))
source(file.path(ROOT, "modules", "brand", "R", "03c_funnel_panel_data.R"))
source(file.path(ROOT, "modules", "brand", "lib", "html_report", "panels",
                 "03_funnel_panel_table.R"))


# ==============================================================================
# Shared fixture helpers
# ==============================================================================

.pack_mm <- function(picks, root) {
  n_slots <- max(vapply(picks, length, integer(1)), 1L)
  as.data.frame(
    setNames(
      lapply(seq_len(n_slots), function(j)
        vapply(picks, function(p)
          if (j <= length(p)) p[j] else NA_character_,
          character(1))),
      paste0(root, "_", seq_len(n_slots))),
    stringsAsFactors = FALSE)
}

.mm_entry <- function(role, cat, client, column_root, n_slots, qtext = "") {
  list(role = role, category = cat, client_code = client,
       variable_type = "Multi_Mention",
       column_root = column_root, per_brand = FALSE,
       columns = paste0(column_root, "_", seq_len(n_slots)),
       applicable_brands = NULL,
       question_text = qtext, option_scale = NA,
       option_map = NULL, notes = "")
}

.att_entry <- function(cat, brands) {
  colroot <- paste0("BRANDATT1_", cat)
  named_cols <- setNames(paste0(colroot, "_", brands), brands)
  list(role = "funnel.attitude", category = cat, client_code = "BRANDATT1",
       variable_type = "Single_Response_Brand",
       column_root = colroot, per_brand = TRUE,
       columns = named_cols,
       applicable_brands = brands,
       question_text = "Attitude?", option_scale = NA,
       option_map = NULL, notes = "")
}

.trans_data <- function() {
  aware <- list(
    c("IPK","ROB","CART"), c("IPK","ROB","CART"), c("IPK","CART"),
    c("IPK","ROB","CART"), c("ROB"),              c("IPK","ROB","CART"),
    c("IPK"),              c("IPK","ROB","CART"), c("IPK","ROB","CART"),
    c("IPK","ROB"))
  pen1 <- list(
    c("IPK","ROB"), c("IPK","ROB"), c("IPK","CART"), c("ROB","CART"),
    c("ROB"),       c("IPK","CART"), character(0),   c("IPK","CART"),
    c("ROB","CART"), c("IPK","ROB"))
  pen2 <- list(
    c("IPK","ROB"), c("IPK","ROB"), c("CART"),       c("ROB","CART"),
    character(0),   c("IPK"),       character(0),    c("IPK","CART"),
    c("CART"),      c("IPK","ROB"))
  data <- cbind(
    data.frame(Respondent_ID = 1:10, Weight = 1, stringsAsFactors = FALSE),
    .pack_mm(aware, "BRANDAWARE_TSX"),
    .pack_mm(pen1,  "BRANDPEN1_TSX"),
    .pack_mm(pen2,  "BRANDPEN2_TSX"))
  data$BRANDATT1_TSX_IPK  <- c(1, 2, 3, 4, 5, 1, 3, 2, 5, 1)
  data$BRANDATT1_TSX_ROB  <- c(3, 1, 5, 2, 3, 4, 5, 4, 2, 1)
  data$BRANDATT1_TSX_CART <- c(5, 4, 2, 1, 5, 3, 5, 2, 1, 5)
  data
}

.trans_brands <- function() {
  data.frame(BrandCode  = c("IPK","ROB","CART"),
             BrandLabel = c("IPK","Robertsons","Cartwright"),
             stringsAsFactors = FALSE)
}

.trans_rm <- function() {
  aw <- .mm_entry("funnel.awareness", "TSX", "BRANDAWARE",
                  "BRANDAWARE_TSX", 3, "Heard of?")
  at <- .att_entry("TSX", c("IPK","ROB","CART"))
  pl <- .mm_entry("funnel.penetration_long", "TSX", "BRANDPEN1",
                  "BRANDPEN1_TSX", 2, "Bought in 12m?")
  pt <- .mm_entry("funnel.penetration_target", "TSX", "BRANDPEN2",
                  "BRANDPEN2_TSX", 2, "Bought last month?")
  list(
    "funnel.awareness"                   = aw,
    "funnel.attitude"                    = at,
    "funnel.penetration_long"            = pl,
    "funnel.penetration_target"          = pt,
    "funnel.transactional.bought_long"   = pl,
    "funnel.transactional.bought_target" = pt
  )
}

.render_table <- function() {
  res <- run_funnel(.trans_data(), .trans_rm(), .trans_brands(), list(
    `category.type` = "transactional", focal_brand = "IPK",
    `funnel.conversion_metric` = "ratio",
    `funnel.warn_base` = 0, `funnel.suppress_base` = 0))
  pd <- build_funnel_panel_data(res, .trans_brands(), list())
  build_funnel_table_section(pd)
}

.flatten_html <- function(html) {
  gsub("\\s+", " ", html)
}


# ==============================================================================
# Tests: presence of the new chrome
# ==============================================================================

test_that("table renders with non-empty HTML", {
  html <- .render_table()
  expect_true(is.character(html) && nzchar(html))
  expect_true(grepl("<table", html))
})


test_that("Base row is present with n= values per stage", {
  html <- .render_table()
  expect_true(grepl('ct-row-base', html))
  expect_true(grepl('Base \\(n=\\)', html))
  expect_true(grepl('ct-low-base|ct-base-n', html))
})


test_that("Focal + category-average rows are locked (data-locked=\"1\")", {
  html <- .render_table()
  expect_true(grepl('fn-row-focal[^>]*data-locked="1"', html))
  expect_true(grepl('fn-row-avg-all[^>]*data-locked="1"', html))
  expect_true(grepl('fn-row-base[^>]*data-locked="1"', html))
})


test_that("Sort buttons exist on every stage header AND brand header", {
  html <- .render_table()
  expect_true(grepl('data-fn-action="sort-brand"', html))
  stage_sort_count <- length(
    gregexpr('data-fn-action="sort-stage"', html)[[1]])
  expect_equal(stage_sort_count, 4)
})


test_that("Stage column headers render for every stage", {
  html <- .render_table()
  for (k in c("aware", "consideration", "bought_long", "bought_target")) {
    expect_true(grepl(sprintf('data-fn-stage="%s"', k), html),
                info = sprintf("stage header for %s", k))
  }
})


# ==============================================================================
# Tests: per-column heatmap
# ==============================================================================

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


# ==============================================================================
# Tests: sort attributes on competitor rows
# ==============================================================================

test_that("Every competitor row carries data-fn-sort-<stage> + data-fn-sort-brand", {
  html <- .render_table()
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


# ==============================================================================
# Tests: sig-vs-avg inline badges
# ==============================================================================

test_that("Inline sig badge renders ▲ when brand is sig-higher than cat avg", {
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
  expect_true(grepl("fn-sig-up", flat))
  expect_true(grepl("fn-sig-down", flat))
  cons_cells <- regmatches(flat, gregexpr(
    '<td [^>]*data-fn-stage="consideration".*?</td>', flat,
    perl = TRUE))[[1]]
  expect_true(length(cons_cells) >= 2)
  for (c in cons_cells) {
    expect_false(grepl("fn-sig-up|fn-sig-down", c), info = c)
  }
})


# ==============================================================================
# Tests: small-base warning
# ==============================================================================

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
  expect_true(grepl("ct-low-base-dim", html))
  expect_true(grepl("ct-low-base", html))
  expect_true(grepl("⚠", html))
})
