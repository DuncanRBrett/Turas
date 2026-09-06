# ==============================================================================
# BRAND MODULE TESTS: the nested funnel is the default view
# ==============================================================================
# The funnel used to open on the absolute view, where each stage sits on its
# own survey response and nothing is chained. On real data that let a later
# stage read higher than an earlier one (IPK Baking: aware 34%, prefer 48%),
# while the stage definition text claimed the later stage was gated on the
# earlier one. The number and the words under it contradicted each other.
#
# The default is now the nested chain: at each stage, the respondents who
# passed that stage and every earlier one, over the weighted respondent
# total. The arithmetic is asserted here rather than eyeballed:
#
#     nested % at stage k  ==  base_chain_filtered[k] / meta$n_weighted
#
# Both fields were already in the panel payload, so no engine number moved.
#
# Also covered: the four base labels, the collapsed explainer, the absence of
# a significance mark in the nested view, and the summary cards following the
# same base as the table below them.
# ==============================================================================
library(testthat)

.fnd_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT_FND <- .fnd_root()

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

source(file.path(ROOT_FND, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(ROOT_FND, "modules", "brand", "lib", "html_report", "panels",
                 "03_funnel_panel_table.R"))
source(file.path(ROOT_FND, "modules", "brand", "lib", "html_report", "panels",
                 "03_funnel_panel.R"))
source(file.path(ROOT_FND, "modules", "brand", "lib", "html_report", "panels",
                 "03_funnel_panel_styling.R"))

.fnd_flat <- function(x) gsub("[\r\n]+", " ", paste(x, collapse = " "))


# ------------------------------------------------------------------------------
# Fixture. The chain counts and absolute percentages are the IPK fixture's
# own, read off a generated report on 6 September 2026: focal brand IPK in
# Dry Seasonings and Spices, n_weighted 438. A second brand is added so the
# category-average row has more than one value to average.
# ------------------------------------------------------------------------------
.FND_N_W <- 438
.FND_STAGES <- c("aware", "consideration", "bought_long", "bought_target")
.FND_CHAIN <- list(IPK = c(405, 293, 195, 142), ROB = c(300, 120, 90, 40))
.FND_ABS   <- list(IPK = c(0.924658, 0.668950, 0.623288, 0.449772),
                   ROB = c(0.684932, 0.300000, 0.250000, 0.120000))

.fnd_cells <- function() {
  out <- list()
  for (b in names(.FND_CHAIN)) {
    for (i in seq_along(.FND_STAGES)) {
      out[[length(out) + 1]] <- list(
        stage_key = .FND_STAGES[i], brand_code = b,
        pct_absolute = .FND_ABS[[b]][i],
        pct_nested = if (i == 1) 1 else
          .FND_CHAIN[[b]][i] / .FND_CHAIN[[b]][i - 1],
        pct_aware = 0.5,
        base_weighted = .FND_ABS[[b]][i] * .FND_N_W,
        base_unweighted = round(.FND_ABS[[b]][i] * .FND_N_W),
        base_chain_filtered = .FND_CHAIN[[b]][i],
        base_chain_unweighted = .FND_CHAIN[[b]][i],
        base_aware_filtered = .FND_CHAIN[[b]][1],
        base_aware_unweighted = .FND_CHAIN[[b]][1],
        base_stage_aware_filtered = .FND_CHAIN[[b]][i],
        base_stage_aware_unweighted = .FND_CHAIN[[b]][i],
        sig_vs_focal = if (b == "IPK") "focal" else "lower",
        sig_vs_avg = if (b == "IPK") "higher" else "lower",
        warning_flag = "none")
    }
  }
  out
}

.fnd_panel <- function() {
  cells <- .fnd_cells()
  list(
    meta = list(focal_brand_code = "IPK", focal_brand_name = "IPK",
                n_weighted = .FND_N_W, n_unweighted = .FND_N_W,
                stage_definitions = .FUNNEL_DEFAULT_DEFINITIONS[.FND_STAGES]),
    cards = list(
      funnel = lapply(seq_along(.FND_STAGES), function(i) list(
        stage_index = i, stage_key = .FND_STAGES[i],
        stage_label = .FND_STAGES[i],
        focal_pct = .FND_ABS$IPK[i],
        focal_base_weighted = .FND_ABS$IPK[i] * .FND_N_W,
        focal_base_unweighted = round(.FND_ABS$IPK[i] * .FND_N_W),
        cat_avg_pct = .FND_ABS$ROB[i],
        cat_avg_base = .FND_ABS$ROB[i] * .FND_N_W,
        sig_vs_avg = "higher", warning_flag = "none")),
      relationship = list()),
    table = list(
      stage_keys = .FND_STAGES, stage_labels = .FND_STAGES,
      brand_codes = c("IPK", "ROB"), brand_names = c("IPK", "Robertsons"),
      cells = cells,
      avg_all_brands = lapply(seq_along(.FND_STAGES), function(i) list(
        stage_key = .FND_STAGES[i],
        pct_absolute = mean(c(.FND_ABS$IPK[i], .FND_ABS$ROB[i])),
        pct_nested = 0.5, pct_aware = 0.5,
        ci_lo = NA_real_, ci_hi = NA_real_))
    )
  )
}

.fnd_cell_attr <- function(html, brand, stage, attr) {
  pat <- sprintf('<td[^>]*data-fn-stage="%s"[^>]*data-fn-brand="%s"[^>]*>',
                 stage, brand)
  m <- regmatches(html, regexpr(pat, html, perl = TRUE))
  if (length(m) == 0) return(NA_character_)
  v <- regmatches(m, regexpr(sprintf('%s="[^"]*"', attr), m, perl = TRUE))
  if (length(v) == 0) return(NA_character_)
  sub('^[^"]*"', "", sub('"$', "", v))
}


# ==============================================================================
# The arithmetic
# ==============================================================================

test_that("every cell's nested figure is its chain count over the base", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  for (b in names(.FND_CHAIN)) {
    for (i in seq_along(.FND_STAGES)) {
      got <- as.numeric(.fnd_cell_attr(html, b, .FND_STAGES[i],
                                       "data-fn-pct-chn"))
      want <- .FND_CHAIN[[b]][i] / .FND_N_W
      expect_equal(got, want, tolerance = 1e-6,
                   info = sprintf("%s at %s", b, .FND_STAGES[i]))
    }
  }
})

test_that("the first stage's nested figure equals its absolute figure", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  for (b in names(.FND_CHAIN)) {
    chn <- as.numeric(.fnd_cell_attr(html, b, "aware", "data-fn-pct-chn"))
    abs_ <- as.numeric(.fnd_cell_attr(html, b, "aware", "data-fn-pct-abs"))
    expect_equal(chn, abs_, tolerance = 1e-5, info = b)
  }
})

test_that("the nested chain never rises from one stage to the next", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  for (b in names(.FND_CHAIN)) {
    vals <- vapply(.FND_STAGES, function(k)
      as.numeric(.fnd_cell_attr(html, b, k, "data-fn-pct-chn")), numeric(1))
    expect_true(all(diff(vals) <= 1e-9), info = paste(b, paste(vals, collapse = " ")))
  }
})

test_that("the rendered cell text is the nested figure, not the absolute one", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  # bought_long is where the two diverge: 195/438 = 45%, against 62% absolute.
  cell <- regmatches(html, regexpr(
    '<td[^>]*data-fn-stage="bought_long"[^>]*data-fn-brand="IPK".*?</td>',
    html, perl = TRUE))
  expect_length(cell, 1)
  expect_true(grepl(">45%<", cell), info = cell)
  expect_false(grepl(">62%<", cell), info = cell)
})

test_that("the count under a cell is the chain count, not the stage count", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  cell <- regmatches(html, regexpr(
    '<td[^>]*data-fn-stage="bought_long"[^>]*data-fn-brand="IPK".*?</td>',
    html, perl = TRUE))
  expect_true(grepl("n=195", cell), info = cell)
  expect_false(grepl("n=273", cell), info = cell)
})

test_that("the category average is the per-brand figure averaged, not a ratio", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  avg_row <- regmatches(html, regexpr(
    '<tr class="ct-row fn-row-avg-all".*?</tr>', html, perl = TRUE))
  expect_length(avg_row, 1)
  for (i in seq_along(.FND_STAGES)) {
    k <- .FND_STAGES[i]
    td <- regmatches(avg_row, regexpr(
      sprintf('<td[^>]*data-fn-stage="%s"[^>]*>', k), avg_row, perl = TRUE))
    v <- as.numeric(sub('.*data-fn-pct-chn="([^"]*)".*', "\\1", td))
    want <- mean(c(.FND_CHAIN$IPK[i], .FND_CHAIN$ROB[i]) / .FND_N_W)
    expect_equal(v, want, tolerance = 1e-6, info = k)
    # And not the pooled chain over one base, which is what a reader gets
    # if the counts are summed before the division.
    pooled <- sum(c(.FND_CHAIN$IPK[i], .FND_CHAIN$ROB[i])) / .FND_N_W
    expect_false(isTRUE(all.equal(v, pooled, tolerance = 1e-6)), info = k)
  }
})

test_that("every competitor row carries a sort value for the nested view", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  row <- regmatches(html, regexpr(
    '<tr class="ct-row fn-row-competitor"[^>]*>', html, perl = TRUE))
  expect_length(row, 1)
  for (i in seq_along(.FND_STAGES)) {
    k <- .FND_STAGES[i]
    v <- as.numeric(sub(sprintf('.*data-fn-sort-%s-chn="([^"]*)".*', k),
                        "\\1", row))
    expect_equal(v, .FND_CHAIN$ROB[i] / .FND_N_W, tolerance = 1e-6, info = k)
  }
})

test_that("a cell with no chain count falls back rather than blanking", {
  pd <- .fnd_panel()
  pd$table$cells <- lapply(pd$table$cells, function(cl) {
    cl$base_chain_filtered <- NULL
    cl$base_chain_unweighted <- NULL
    cl
  })
  html <- .fnd_flat(build_funnel_table_section(pd))
  chn <- as.numeric(.fnd_cell_attr(html, "IPK", "bought_long",
                                   "data-fn-pct-chn"))
  expect_equal(chn, .FND_ABS$IPK[3], tolerance = 1e-6)
  expect_true(grepl(">62%<", html))
})

test_that("a panel with no weighted total falls back to the absolute view", {
  pd <- .fnd_panel()
  pd$meta$n_weighted <- NULL
  html <- .fnd_flat(build_funnel_table_section(pd))
  chn <- as.numeric(.fnd_cell_attr(html, "IPK", "bought_long",
                                   "data-fn-pct-chn"))
  expect_equal(chn, .FND_ABS$IPK[3], tolerance = 1e-6)
})


# ==============================================================================
# No significance mark in the nested view
# ==============================================================================

test_that("the default render carries no significance badge", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  # Every cell in the fixture is flagged higher or lower by the engine, so a
  # badge would render here if the default view still emitted one.
  expect_false(grepl("ct-sig", html))
  expect_false(grepl("fn-sig-up", html))
  expect_false(grepl("fn-sig-down", html))
})

test_that("the direction rides on the cell so the JS can put it back", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  expect_equal(.fnd_cell_attr(html, "IPK", "aware", "data-fn-sig-avg"),
               "higher")
  expect_equal(.fnd_cell_attr(html, "ROB", "aware", "data-fn-sig-avg"),
               "lower")
})

test_that("the JS restores the badge only outside the nested view", {
  js <- paste(readLines(file.path(ROOT_FND, "modules", "brand", "lib",
                                  "html_report", "js",
                                  "brand_funnel_panel.js"),
                        warn = FALSE), collapse = "\n")
  expect_true(grepl('var show = (mode !== "chain");', js, fixed = TRUE))
  expect_true(grepl('if (mode === "chain") return;', js, fixed = TRUE))
  expect_true(grepl("function applySigBadges", js, fixed = TRUE))
})


# ==============================================================================
# The base toggle and its explainer
# ==============================================================================

test_that("the nested view is the default toggle in the emitted HTML", {
  html <- .fnd_flat(.fn_table_controls(.fnd_panel()))
  active <- regmatches(html, regexpr(
    '<button[^>]*sig-btn-active[^>]*data-fn-action="pctmode"[^>]*>', html,
    perl = TRUE))
  expect_length(active, 1)
  expect_true(grepl('data-fn-pctmode="chain"', active), info = active)
  expect_true(grepl('aria-pressed="true"', active), info = active)
})

test_that("the JS default agrees with what R rendered", {
  js <- paste(readLines(file.path(ROOT_FND, "modules", "brand", "lib",
                                  "html_report", "js",
                                  "brand_funnel_panel.js"),
                        warn = FALSE), collapse = "\n")
  expect_true(grepl('pctMode: "chain"', js, fixed = TRUE))
})

test_that("all four views are reachable and each names its computation", {
  html <- .fnd_flat(.fn_table_controls(.fnd_panel()))
  modes <- regmatches(html, gregexpr('data-fn-pctmode="[^"]*"', html))[[1]]
  expect_setequal(modes, c('data-fn-pctmode="chain"',
                           'data-fn-pctmode="total"',
                           'data-fn-pctmode="previous"',
                           'data-fn-pctmode="aware"'))
  expect_true(grepl("Funnel, % of all", html, fixed = TRUE))
  expect_true(grepl("Each stage on its own", html, fixed = TRUE))
  expect_true(grepl("% of previous stage", html, fixed = TRUE))
  expect_true(grepl("% of those aware", html, fixed = TRUE))
})

test_that("the word funnel labels only the view that is genuinely nested", {
  html <- .fnd_flat(.fn_table_controls(.fnd_panel()))
  btns <- regmatches(html, gregexpr('<button[^>]*data-fn-action="pctmode"[^>]*>[^<]*</button>',
                                    html, perl = TRUE))[[1]]
  expect_length(btns, 4)
  for (b in btns) {
    label <- sub(".*>([^<]*)</button>", "\\1", b)
    is_chain <- grepl('data-fn-pctmode="chain"', b)
    has_word <- grepl("[Ff]unnel", label)
    expect_equal(has_word, is_chain, info = label)
  }
})

test_that("the explainer is present, collapsed, and states the missing mark", {
  html <- .fnd_flat(.fn_base_howto())
  expect_true(grepl("How this works", html, fixed = TRUE))
  expect_true(grepl('class="fn-base-howto-body" hidden', html, fixed = TRUE))
  expect_true(grepl('aria-expanded="false"', html, fixed = TRUE))
  # It names every view.
  expect_true(grepl("Funnel, % of all", html, fixed = TRUE))
  expect_true(grepl("Each stage on its own", html, fixed = TRUE))
  expect_true(grepl("% of previous stage", html, fixed = TRUE))
  expect_true(grepl("% of those aware", html, fixed = TRUE))
  # And says why the nested view shows no significance mark.
  expect_true(grepl("Significance marks", html, fixed = TRUE))
  expect_true(grepl("In the nested view neither is shown", html, fixed = TRUE))
})

test_that("no string a reader sees carries an em dash", {
  bad <- "—"
  expect_false(grepl(bad, .fn_base_howto(), fixed = TRUE))
  expect_false(grepl(bad, .fn_table_controls(.fnd_panel()), fixed = TRUE))
  expect_false(grepl(bad, paste(unlist(.FUNNEL_DEFAULT_DEFINITIONS),
                                collapse = " "), fixed = TRUE))
})


# ==============================================================================
# The summary cards follow the same base
# ==============================================================================

test_that("the summary cards render the nested figure, not the absolute one", {
  html <- .fnd_flat(.fn_cards_section(.fnd_panel(), "#1A5276"))
  card <- regmatches(html, regexpr(
    '<div class="tk-hero-card fn-card fn-card-funnel"[^>]*data-fn-stage="bought_long".*?Category avg: <strong>[^<]*</strong>',
    html, perl = TRUE))
  expect_length(card, 1)
  expect_true(grepl(">45%<", card), info = card)   # 195 / 438
  expect_false(grepl(">62%<", card), info = card)  # the absolute figure
  expect_true(grepl("<strong>21%</strong>", card), info = card)  # 90 / 438
})

test_that("the card strip says which base it is drawn on", {
  html <- .fnd_flat(.fn_cards_section(.fnd_panel(), "#1A5276"))
  expect_true(grepl("Base: the nested funnel, % of all respondents", html,
                    fixed = TRUE))
})

test_that("the cards carry no significance badge in the default view", {
  html <- .fnd_flat(.fn_cards_section(.fnd_panel(), "#1A5276"))
  expect_false(grepl("fn-sig fn-sig-up", html, fixed = TRUE))
  expect_true(grepl('data-fn-sig-avg="higher"', html, fixed = TRUE))
})

test_that("the card count is the chain count", {
  html <- .fnd_flat(.fn_cards_section(.fnd_panel(), "#1A5276"))
  expect_true(grepl("Focal n = 195", html, fixed = TRUE))
})


# ==============================================================================
# The stage definitions
# ==============================================================================

test_that("no stage definition claims a gating the derivation does not do", {
  d <- .FUNNEL_DEFAULT_DEFINITIONS
  expect_false(grepl("^Aware respondents", d$consideration))
  expect_true(grepl("not gated on awareness", d$consideration, fixed = TRUE))
  expect_false(grepl("Those who prefer the brand", d$bought_long, fixed = TRUE))
  expect_false(grepl("Long-period buyers", d$bought_target, fixed = TRUE))
  expect_false(grepl("Those who prefer the brand", d$current_owner_d,
                     fixed = TRUE))
  expect_false(grepl("Those who prefer the brand", d$current_customer_s,
                     fixed = TRUE))
})

test_that("each definition points the reader at the control that combines stages", {
  d <- .FUNNEL_DEFAULT_DEFINITIONS
  for (k in c("consideration", "bought_long", "bought_target",
              "current_owner_d", "long_tenured_d", "current_customer_s",
              "long_tenured_s")) {
    expect_true(grepl("base toggle above the table", d[[k]], fixed = TRUE),
                info = k)
  }
})

test_that("the tenure stages still state the gate they really have", {
  d <- .FUNNEL_DEFAULT_DEFINITIONS
  expect_true(grepl("gated on current ownership", d$long_tenured_d,
                    fixed = TRUE))
  expect_true(grepl("gated on being a current customer", d$long_tenured_s,
                    fixed = TRUE))
})

test_that("no definition carries a digit", {
  # The reachability gate compares the numeric content of every JSON island
  # and these strings ride in the funnel payload. A digit in one of them
  # would read as a changed number.
  for (k in names(.FUNNEL_DEFAULT_DEFINITIONS)) {
    expect_false(grepl("[0-9]", .FUNNEL_DEFAULT_DEFINITIONS[[k]]), info = k)
  }
})


# ==============================================================================
# Weighted data
# ==============================================================================
# The fixture is unweighted, so every chain count in the tests above is a head
# count and the denominator is the sample size. The formula is a weighted
# count over sum(weights), and that pair has to hold when the weights are not
# all one. This drives the engine itself rather than a hand-built payload.

source(file.path(ROOT_FND, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT_FND, "modules", "brand", "R", "03b_funnel_metrics.R"))

test_that("the nested figure is a weighted proportion when weights are real", {
  n <- 8
  brands <- c("A", "B")
  mk <- function(v) {
    m <- matrix(v, nrow = n, ncol = length(brands), dimnames = list(NULL, brands))
    m
  }
  # Respondent 1..8. Brand A: aware for 1-6, prefers 1-4, bought 1-3 but also
  # 7 (who never said they were aware). Brand B: aware 1-3, prefers 1-2,
  # bought 1-2.
  aware  <- mk(c(rep(TRUE, 6), FALSE, FALSE))
  aware[, "B"] <- c(rep(TRUE, 3), rep(FALSE, 5))
  prefer <- mk(c(rep(TRUE, 4), rep(FALSE, 4)))
  prefer[, "B"] <- c(TRUE, TRUE, rep(FALSE, 6))
  bought <- mk(c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE))
  bought[, "B"] <- c(TRUE, TRUE, rep(FALSE, 6))

  stages <- list(
    aware = list(key = "aware", label = "Aware", matrix = aware),
    consideration = list(key = "consideration", label = "Prefer",
                         matrix = prefer),
    bought_target = list(key = "bought_target", label = "Bought",
                         matrix = bought))

  w <- c(2.5, 0.5, 1.5, 1, 1, 1, 3, 0.5)
  sum_w <- sum(w)
  df <- calculate_stage_metrics(stages, weights = w, warn_base = 0)

  get <- function(b, k, col) df[[col]][df$brand_code == b & df$stage_key == k]

  # Brand A. The chain is aware, then aware AND prefer, then all three.
  expect_equal(get("A", "aware", "base_chain_filtered"), sum(w[1:6]))
  expect_equal(get("A", "consideration", "base_chain_filtered"), sum(w[1:4]))
  expect_equal(get("A", "bought_target", "base_chain_filtered"), sum(w[1:3]))

  # Respondent 7 bought brand A on their own say-so and is in the absolute
  # count for that stage, but never named it as known, so the chain drops
  # them. This is the whole point of the nested view.
  expect_equal(get("A", "bought_target", "base_weighted"), sum(w[c(1, 2, 3, 7)]))
  expect_true(get("A", "bought_target", "base_weighted") >
              get("A", "bought_target", "base_chain_filtered"))

  # The nested figure, which is what .fn_chain_pct() computes.
  nested <- vapply(c("aware", "consideration", "bought_target"),
                   function(k) get("A", k, "base_chain_filtered") / sum_w,
                   numeric(1))
  expect_equal(unname(nested), c(sum(w[1:6]), sum(w[1:4]), sum(w[1:3])) / sum_w)
  expect_true(all(nested >= 0 & nested <= 1))
  expect_true(all(diff(nested) <= 0))

  # It is not the unweighted head count over n, which is what a reader would
  # get if the weights were dropped.
  expect_false(isTRUE(all.equal(unname(nested[3]), 3 / n)))

  # And the first stage still agrees with the absolute figure.
  expect_equal(unname(nested[1]), get("A", "aware", "pct_weighted"),
               tolerance = 1e-12)

  # The panel helper reads the same thing off a cell.
  cell <- list(base_chain_filtered = get("A", "bought_target",
                                         "base_chain_filtered"))
  expect_equal(.fn_chain_pct(cell, sum_w), unname(nested[3]),
               tolerance = 1e-12)
})


# ==============================================================================
# The category-average row's range bar is drawn at the same base as its figure
# ==============================================================================
# The first cut of this stage rendered the cat-avg figure at the chain base
# and left the bar, the tick and the lo/hi labels under it at the absolute
# base, so on the fixture a mean of 6% sat inside a band of 8% to 17%. The
# JS redraws all three on every toggle; the file as written has to be right
# too, for the first paint and for print.

test_that("the category-average band is computed at the nested base", {
  html <- .fnd_flat(build_funnel_table_section(.fnd_panel()))
  avg_row <- regmatches(html, regexpr(
    '<tr class="ct-row fn-row-avg-all".*?</tr>', html, perl = TRUE))
  expect_length(avg_row, 1)

  for (i in seq_along(.FND_STAGES)) {
    k <- .FND_STAGES[i]
    td <- regmatches(avg_row, regexpr(
      sprintf('<td[^>]*data-fn-stage="%s".*?</td>', k), avg_row, perl = TRUE))
    expect_length(td, 1)
    shown <- as.numeric(sub("%", "", sub(
      '.*<span class="ct-val fn-pct-primary">([0-9]+)%</span>.*', "\\1", td)))
    # A lower bound can be negative on two brands with a wide spread, and
    # the cell prints it as written rather than clamping it to zero.
    limits <- as.numeric(gsub("%", "", regmatches(td, gregexpr(
      '(?<=<span>)-?[0-9]+%(?=</span>)', td, perl = TRUE))[[1]]))
    expect_length(limits, 2)

    vals <- c(.FND_CHAIN$IPK[i], .FND_CHAIN$ROB[i]) / .FND_N_W
    m  <- mean(vals)
    se <- stats::sd(vals) / sqrt(length(vals))
    expect_equal(shown, round(100 * m), info = k)
    expect_equal(limits[1], round(100 * (m - 1.96 * se)), info = k)
    expect_equal(limits[2], round(100 * (m + 1.96 * se)), info = k)
    # The figure sits inside its own band, which is the thing that broke.
    expect_true(shown >= limits[1] && shown <= limits[2], info = k)
  }
})

test_that("the JS redraws that band once at init, not only on a click", {
  js <- paste(readLines(file.path(ROOT_FND, "modules", "brand", "lib",
                                  "html_report", "js",
                                  "brand_funnel_panel.js"),
                        warn = FALSE), collapse = "\n")
  init <- sub(".*function initPanel\\(panel\\) \\{", "", js)
  init <- sub("\n  \\}\n.*", "", init)
  expect_true(grepl("updateAvgRowRangeBars(panel)", init, fixed = TRUE))
})

test_that("the bar chart reads the active base, not the absolute figure", {
  js <- paste(readLines(file.path(ROOT_FND, "modules", "brand", "lib",
                                  "html_report", "js",
                                  "brand_funnel_panel.js"),
                        warn = FALSE), collapse = "\n")
  bar <- sub(".*function buildBarChart\\(panel\\) \\{", "", js)
  bar <- substr(bar, 1, 4000)
  expect_true(grepl("cellValueForMode(c, barMode", bar, fixed = TRUE))
  expect_false(grepl("valMap[c.brand_code] = c.pct_absolute", bar,
                     fixed = TRUE))
  # And the toggle repaints whichever chart view is on screen.
  expect_true(grepl("applyChartVisibility(panel);", js, fixed = TRUE))
})
