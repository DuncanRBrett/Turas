# ==============================================================================
# Tests for the demographics matrix renderer (table + chart) and the synthetic
# Buyer status / Heaviness questions appended in the per-category dispatcher.
# ==============================================================================
library(testthat)

source(file.path("..", "..", "R", "11_demographics.R"))
source(file.path("..", "..", "R", "11a_demographics_panel_data.R"))
source(file.path("..", "..", "lib", "html_report", "panels",
                  "11_demographics_panel.R"))
source(file.path("..", "..", "lib", "html_report", "panels",
                  "11_demographics_panel_table.R"))
source(file.path("..", "..", "lib", "html_report", "panels",
                  "11_demographics_panel_chart.R"))


# ------------------------------------------------------------------------------
# Helper: build a tiny known-answer payload
# ------------------------------------------------------------------------------
# 10 respondents, two options A/B, two brands BR_A and BR_B with non-overlapping
# buyer sets. With these inputs the brand_cut matrix is hand-verifiable.

.demo_test_payload <- function(focal = "BR_A") {
  values <- c(rep("A", 6), rep("B", 4))                   # cat: 60% A, 40% B
  pen <- matrix(c(rep(1L, 6), rep(0L, 4),                  # BR_A buys: rows 1-6
                  rep(0L, 6), rep(1L, 4)), ncol = 2L)      # BR_B buys: rows 7-10
  colnames(pen) <- c("BR_A", "BR_B")
  res <- run_demographic_question(
    values        = values,
    option_codes  = c("A", "B"),
    option_labels = c("Opt A", "Opt B"),
    pen_mat       = pen,
    brand_codes   = c("BR_A", "BR_B"),
    brand_labels  = c("Brand A", "Brand B")
  )
  build_demographics_panel_data(
    questions = list(list(
      role = "demo.test", column = "X",
      question_text = "Test", short_label = "Test",
      variable_type = "Single_Response",
      codes = c("A", "B"),
      labels = c("Opt A", "Opt B"),
      result = res)),
    focal_brand = focal,
    brand_codes = c("BR_A", "BR_B"),
    brand_labels = c("Brand A", "Brand B"),
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000")
  )
}


# ------------------------------------------------------------------------------
# build_demographics_matrix_table — known-answer rendering
# ------------------------------------------------------------------------------

test_that("matrix table places focal brand in column 2 and lists all brands", {
  pd <- .demo_test_payload(focal = "BR_A")
  html <- build_demographics_matrix_table(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)

  # Column order: Option | <focal-brand-name> | Cat avg | Brand A (with focal class) | Brand B
  # Focal column header now carries the actual brand label (the test
  # fixture maps BR_A -> "Brand A") plus a small "focal" subtitle.
  expect_match(html, '<th class="demo-col-focal" data-demo-col="focal">Brand A<span class="demo-th-sub">focal</span></th>',
               fixed = TRUE)
  expect_match(html, '<th class="demo-col-catavg" data-demo-col="catavg">Cat avg</th>')
  expect_match(html, 'data-demo-brand="BR_A"', fixed = TRUE)
  expect_match(html, 'data-demo-brand="BR_B"', fixed = TRUE)
})


test_that("matrix table cell percentages match engine output", {
  pd <- .demo_test_payload(focal = "BR_A")
  html <- build_demographics_matrix_table(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)

  # Cat avg row for "A" should be 60%, for "B" 40%
  expect_match(html, "60%", fixed = TRUE)
  expect_match(html, "40%", fixed = TRUE)
  # Brand A buyers are 100% in option A, 0% in option B
  expect_match(html, "100%", fixed = TRUE)
})


test_that("each option renders TWO rows — Buyer + Non-buyer — with role classes", {
  pd <- .demo_test_payload(focal = "BR_A")
  html <- build_demographics_matrix_table(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)
  # Two options × two rows = 4 <tr> elements in the body. Count the role
  # markers explicitly so a regression that strips one role class fails fast.
  expect_equal(length(gregexpr('class="demo-row-buyer"',    html, fixed = TRUE)[[1]]), 2L)
  expect_equal(length(gregexpr('class="demo-row-nonbuyer"', html, fixed = TRUE)[[1]]), 2L)
  # Non-buyer label sits in column 1 of the comparison row.
  expect_match(html, "demo-row-nonbuyer-label", fixed = TRUE)
  expect_match(html, "non-buyer",               fixed = TRUE)
})


test_that("buyer row carries the brand's buyer pct; non-buyer row the non-buyer pct", {
  # Fixture: BR_A buyers are rows 1-6 (all option A), non-buyers rows 7-10
  # (all option B). Option-A Buyer row in BR_A column should show 100%.
  # Option-A Non-buyer row in BR_A column should show 0%.
  pd <- .demo_test_payload(focal = "BR_A")
  html <- build_demographics_matrix_table(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)
  # Use (?s) for DOTALL — cell content can span newlines in the HTML.
  buyer_rows <- regmatches(html,
    gregexpr('(?s)<tr class="demo-row-buyer">.*?</tr>', html, perl = TRUE))[[1]]
  nonbuyer_rows <- regmatches(html,
    gregexpr('(?s)<tr class="demo-row-nonbuyer">.*?</tr>', html, perl = TRUE))[[1]]
  expect_true(any(grepl("100%", buyer_rows, fixed = TRUE)))    # buyer in option A
  expect_true(any(grepl("0%",   nonbuyer_rows, fixed = TRUE))) # non-buyer in option A
})


test_that("focal brand is NOT duplicated in the per-brand column block", {
  pd <- .demo_test_payload(focal = "BR_A")
  html <- build_demographics_matrix_table(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)
  # focal brand BR_A should NOT appear in any per-brand <td>; it only appears
  # in the pinned column 2 (data-demo-col="focal").
  td_focal_in_brand <- gregexpr(
    '<td[^>]*data-demo-col="brand" data-demo-brand="BR_A"',
    html, perl = TRUE)[[1]]
  expect_equal(length(td_focal_in_brand[td_focal_in_brand != -1L]), 0L)
  # BR_B (non-focal) should appear once per cell: 2 options × 2 rows = 4 td's.
  # (The column header is a <th>, not a <td>, so this doesn't count it.)
  td_brB <- gregexpr(
    '<td[^>]*data-demo-col="brand" data-demo-brand="BR_B"',
    html, perl = TRUE)[[1]]
  expect_equal(length(td_brB[td_brB != -1L]), 4L)
})


test_that("matrix table emits hidden n spans for the JS counts toggle to reveal", {
  pd <- .demo_test_payload()
  html <- build_demographics_matrix_table(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)
  expect_match(html, '<span class="demo-cell-n" hidden>n=', fixed = TRUE)
  # CI ranges were dropped — Demographics tab is a quick comparison only.
  expect_false(grepl('demo-cell-ci', html, fixed = TRUE))
})


test_that("matrix table shades buyer cells vs each brand's cat-wide penetration", {
  # Fixture (.demo_test_payload):
  #   Option A has 6 respondents, all buy BR_A, none buy BR_B.
  #   Option B has 4 respondents, none buy BR_A, all buy BR_B.
  #   BR_A total pen = 60%; BR_B total pen = 40%.
  # Cell shading per brand cell = (cell pct - that brand's total pen).
  #   Option A, BR_A buyer = 100% vs baseline 60% → +40pp clipped to +30 → blue
  #   Option B, BR_A buyer =   0% vs baseline 60% → -60pp clipped to -30 → red
  pd <- .demo_test_payload()
  html <- build_demographics_matrix_table(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)
  expect_match(html, 'data-demo-heat="rgba\\(37,99,171,0\\.',  perl = TRUE)
  expect_match(html, 'data-demo-heat="rgba\\(192,57,43,0\\.',  perl = TRUE)
})


test_that("buyer cell shows within-demo penetration; non-buyer cell shows its complement", {
  # Option A has 6 respondents, all buying BR_A.
  # BR_A buyer cell in option A = 100% (all 6 of 6 buy BR_A).
  # BR_A non-buyer cell in option A = 0% (none of 6 are non-buyers of BR_A).
  # Option A has 6 respondents, none buying BR_B.
  # BR_B buyer cell in option A = 0%. Non-buyer cell = 100%.
  pd <- .demo_test_payload(focal = "BR_A")
  html <- build_demographics_matrix_table(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)

  buyer_rows <- regmatches(html,
    gregexpr('(?s)<tr class="demo-row-buyer">.*?</tr>', html, perl = TRUE))[[1]]
  nonbuyer_rows <- regmatches(html,
    gregexpr('(?s)<tr class="demo-row-nonbuyer">.*?</tr>', html, perl = TRUE))[[1]]

  # First option (A) — buyer row shows 100% for BR_A and 0% for BR_B
  expect_match(buyer_rows[1], "100%", fixed = TRUE)
  expect_match(buyer_rows[1], "0%",   fixed = TRUE)
  # First option (A) — non-buyer row shows 0% for BR_A and 100% for BR_B
  # (complements of the buyer cells)
  expect_match(nonbuyer_rows[1], "100%", fixed = TRUE)
  expect_match(nonbuyer_rows[1], "0%",   fixed = TRUE)
})


# ------------------------------------------------------------------------------
# build_demographics_matrix_chart — focal bar + cat-avg marker
# ------------------------------------------------------------------------------

test_that("matrix chart renders one row per option with focal bar fill", {
  pd <- .demo_test_payload(focal = "BR_A")
  html <- build_demographics_matrix_chart(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)
  expect_match(html, "demo-chart-row", fixed = TRUE)
  # Two rows: A and B
  expect_equal(length(gregexpr("demo-chart-row\"", html, fixed = TRUE)[[1]]), 2L)
  # Focal colour appears in fill
  expect_match(html, "#1A5276", fixed = TRUE)
})


test_that("matrix chart marker reflects cat-avg %", {
  pd <- .demo_test_payload(focal = "BR_A")
  html <- build_demographics_matrix_chart(
    pd$questions[[1]], focal_brand = "BR_A",
    brand_colours = list(BR_A = "#1A5276", BR_B = "#A04000"),
    panel_data = pd, decimal_places = 0L)
  # Cat avg 60% on option A — chart_max = 100 → marker at 60.0%
  expect_match(html, "left:60\\.0%", perl = TRUE)
})


# ------------------------------------------------------------------------------
# Empty-state handling
# ------------------------------------------------------------------------------

test_that("matrix table returns empty notice when no rows", {
  q <- list(total = list(rows = list()), brand_cut = list())
  html <- build_demographics_matrix_table(q, focal_brand = "BR_A",
                                            brand_colours = list(),
                                            panel_data = list(brands = list(codes = character(0))),
                                            decimal_places = 0L)
  expect_match(html, "demo-empty", fixed = TRUE)
  expect_match(html, "No responses for this question.", fixed = TRUE)
})


test_that("matrix chart returns empty notice when no rows", {
  q <- list(total = list(rows = list()), brand_cut = list())
  html <- build_demographics_matrix_chart(q, focal_brand = "BR_A",
                                            brand_colours = list(),
                                            panel_data = list(meta = list()),
                                            decimal_places = 0L)
  expect_match(html, "demo-empty", fixed = TRUE)
})


# ------------------------------------------------------------------------------
# Synthetic question constructors (.demo_synthetic_buyer_status / heaviness)
# ------------------------------------------------------------------------------
# The synthetic constructors live in 00_main.R and are called from
# .run_demographics_for_category. Source 00_main.R indirectly by sourcing the
# brand module through its loader. We isolate by calling the helpers directly.

source(file.path("..", "..", "R", "00_main.R"))

test_that("synthetic buyer-status question yields BUYER + NON_BUYER rows", {
  set.seed(99)
  pen <- matrix(c(rep(1L, 4), rep(0L, 6),
                  rep(0L, 4), rep(1L, 6)), ncol = 2L)
  colnames(pen) <- c("FOC", "OTH")
  bv <- list(status = "PASS", pen_mat = pen, m_vec = rep(2L, 10))
  buyer_info <- .demo_buyer_for_category(bv, NULL, focal_brand = "FOC")
  bmat_info  <- .demo_brand_matrix_for_category(bv, NULL)
  q <- .demo_synthetic_buyer_status(
    cat_data = data.frame(x = 1:10), cat_weights = NULL,
    buyer_info = buyer_info, bmat_info = bmat_info,
    focal_brand = "FOC")
  expect_false(is.null(q))
  expect_equal(q$synthetic_kind, "buyer_status")
  expect_equal(q$codes, c("BUYER", "NON_BUYER"))
  expect_equal(q$result$status, "PASS")
  # 4 of 10 rows are FOC buyers => 40%, 6 are non-buyers => 60%
  expect_equal(q$result$total$Pct, c(40, 60))
})


test_that("synthetic heaviness question yields LIGHT/MED/HEAVY rows", {
  pen <- matrix(c(rep(1L, 9), 0L), ncol = 1L)
  colnames(pen) <- "FOC"
  m   <- c(1, 2, 2, 3, 4, 5, 6, 7, 9, NA_integer_)
  bv  <- list(status = "PASS", pen_mat = pen, m_vec = m)
  bh  <- list(status = "PASS",
              tertile_bounds = list(light = c(0, 3), medium = c(3, 6),
                                     heavy = c(6, Inf)))
  buyer_info <- .demo_buyer_for_category(bv, bh, focal_brand = "FOC")
  bmat_info  <- .demo_brand_matrix_for_category(bv, NULL)
  q <- .demo_synthetic_heaviness(
    cat_data = data.frame(x = 1:10), cat_weights = NULL,
    buyer_info = buyer_info, bmat_info = bmat_info)
  expect_false(is.null(q))
  expect_equal(q$synthetic_kind, "heaviness")
  expect_equal(q$codes, c("LIGHT", "MEDIUM", "HEAVY"))
  expect_equal(q$result$status, "PASS")
  # m <= 3 → LIGHT (4 rows: 1,2,2,3)
  # 3 < m <= 6 → MEDIUM (3 rows: 4,5,6)
  # m > 6 → HEAVY (2 rows: 7,9)
  # base = 9 buyers (NA respondent excluded)
  expect_equal(q$result$total$n, c(4, 3, 2))
})


test_that("synthetic buyer-status returns NULL when focal pen unavailable", {
  bmat_info  <- list(pen_mat = NULL, brand_codes = character(0),
                     brand_labels = character(0), brand_colours = list())
  buyer_info <- list(focal_buyer = NULL, tiers = NULL)
  expect_null(.demo_synthetic_buyer_status(
    cat_data = data.frame(x = 1:5), cat_weights = NULL,
    buyer_info = buyer_info, bmat_info = bmat_info, focal_brand = "FOC"))
})


test_that("synthetic heaviness returns NULL when no tier classifications", {
  bmat_info  <- list(pen_mat = NULL, brand_codes = character(0),
                     brand_labels = character(0), brand_colours = list())
  buyer_info <- list(focal_buyer = c(1L, 0L, 1L), tiers = c(NA, NA, NA))
  expect_null(.demo_synthetic_heaviness(
    cat_data = data.frame(x = 1:3), cat_weights = NULL,
    buyer_info = buyer_info, bmat_info = bmat_info))
})
