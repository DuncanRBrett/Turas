# ==============================================================================
# TEST: Double Jeopardy scatter labels do not sit on top of each other
# ==============================================================================
# Wiring the scatter up made a pre-existing defect visible: two brands close
# together on the plot drew their labels at the same fixed offset, so on the
# IPK fixture "Hinds" and "Checkers House Brand" overlapped by about 230
# square pixels. The scatter now routes its labels through the shared
# collision-aware placer that build_scatter() already used.
#
# This file sources 04_chart_builder.R as well as the panel, because the
# renderer falls back to the old fixed offset when the placer is absent and a
# panel-only test would pass either way.
# ==============================================================================

library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "launch_turas.R")) ||
          file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  root <- find_root()
  rdir <- file.path(root, "modules", "brand", "lib", "html_report")
  source(file.path(rdir, "04_chart_builder.R"), local = FALSE)
  source(file.path(rdir, "panels", "08_cat_buying_panel_chart.R"), local = FALSE)
})


#' Two off-line brands almost on top of each other, both with long labels.
.djlc_norms <- function() {
  data.frame(
    BrandCode           = c("FOC", "NEAR1", "NEAR2", "FAR"),
    Penetration_Obs_Pct = c(45.0, 8.0, 8.4, 30.0),
    SCR_Obs_Pct         = c(70.0, 46.0, 46.3, 40.0),
    BuyRate_Obs         = c(7.2, 4.5, 4.6, 5.0),
    DJ_Flag             = c("on_line", "over", "over", "on_line"),
    stringsAsFactors    = FALSE
  )
}

.djlc_curve <- function() {
  list(x_grid    = seq(0.05, 0.5, length.out = 20),
       y_fit_scr = seq(35, 55, length.out = 20),
       y_fit_w   = seq(3.5, 5.5, length.out = 20))
}

.djlc_labels <- c(FOC   = "Ina Paarman's Kitchen",
                  NEAR1 = "Checkers House Brand",
                  NEAR2 = "Hinds",
                  FAR   = "Robertsons")

#' Label boxes as the browser will lay them out, mirroring the renderer's
#' font-size 9 and the placer's own width approximation.
.djlc_boxes <- function(svg) {
  m <- gregexpr(
    '<text class="cb-brand-label" x="([0-9.]+)" y="([0-9.]+)" text-anchor="([a-z]+)"[^>]*>([^<]*)</text>',
    svg, perl = TRUE)
  hits <- regmatches(svg, m)[[1]]
  if (!length(hits)) return(list())
  lapply(hits, function(h) {
    x <- as.numeric(sub('.*x="([0-9.]+)".*', "\\1", h))
    y <- as.numeric(sub('.*y="([0-9.]+)".*', "\\1", h))
    a <- sub('.*text-anchor="([a-z]+)".*', "\\1", h)
    t <- sub('.*>([^<]*)</text>$', "\\1", h)
    w <- 9 * 0.55 * nchar(t)
    hgt <- 9 * 1.15
    x0 <- if (a == "start") x else if (a == "end") x - w else x - w / 2
    list(label = t, x0 = x0, y0 = y - hgt * 0.7, x1 = x0 + w, y1 = y + hgt * 0.3)
  })
}

.djlc_overlaps <- function(boxes) {
  n <- length(boxes)
  if (n < 2) return(0L)
  count <- 0L
  for (i in seq_len(n - 1)) for (j in seq(i + 1, n)) {
    a <- boxes[[i]]; b <- boxes[[j]]
    w <- min(a$x1, b$x1) - max(a$x0, b$x0)
    h <- min(a$y1, b$y1) - max(a$y0, b$y0)
    if (w > 0 && h > 0) count <- count + 1L
  }
  count
}


test_that("two brands close together do not draw overlapping labels", {
  svg <- cb_dj_scatter_svg(.djlc_norms(), .djlc_curve(),
                           focal_brand  = "FOC",
                           brand_labels = .djlc_labels)
  boxes <- .djlc_boxes(svg)
  # Focal plus the two "over" brands.
  expect_equal(length(boxes), 3L)
  expect_true("Checkers House Brand" %in% vapply(boxes, `[[`, "", "label"))
  expect_true("Hinds" %in% vapply(boxes, `[[`, "", "label"))
  expect_equal(.djlc_overlaps(boxes), 0L)
})


test_that("the same is true on the buy-rate view", {
  svg <- cb_dj_scatter_svg(.djlc_norms(), .djlc_curve(),
                           focal_brand  = "FOC",
                           y_axis       = "w",
                           brand_labels = .djlc_labels)
  expect_equal(.djlc_overlaps(.djlc_boxes(svg)), 0L)
})


test_that("a label pushed clear of its dot gets a leader line", {
  svg <- cb_dj_scatter_svg(.djlc_norms(), .djlc_curve(),
                           focal_brand  = "FOC",
                           brand_labels = .djlc_labels)
  # At least one of the two crowded labels has to move far enough to need one.
  expect_true(grepl('stroke="#cbd5e1"', svg, fixed = TRUE))
})


#' Dot centres and radii, so a label can be checked against them.
.djlc_dots <- function(svg) {
  m <- gregexpr(
    '<circle class="cb-brand-dot" cx="([0-9.]+)" cy="([0-9.]+)" r="([0-9]+)"',
    svg, perl = TRUE)
  hits <- regmatches(svg, m)[[1]]
  lapply(hits, function(h) list(
    x = as.numeric(sub('.*cx="([0-9.]+)".*', "\\1", h)),
    y = as.numeric(sub('.*cy="([0-9.]+)".*', "\\1", h)),
    r = as.numeric(sub('.*r="([0-9]+)".*',   "\\1", h))))
}


test_that("a dot with no label is still an obstacle, and draws no label", {
  # NEAR2 goes on the line, so it keeps its dot but loses its label. The
  # remaining labels must not be drawn across that dot, and the empty label
  # must not itself be emitted.
  n_quiet <- .djlc_norms()
  n_quiet$DJ_Flag <- c("on_line", "over", "on_line", "on_line")
  svg <- cb_dj_scatter_svg(n_quiet, .djlc_curve(),
                           focal_brand = "FOC", brand_labels = .djlc_labels)

  boxes <- .djlc_boxes(svg)
  expect_equal(length(boxes), 2L)
  expect_false("Hinds" %in% vapply(boxes, `[[`, "", "label"))
  expect_false(grepl('cb-brand-label[^>]*></text>', svg))

  # No drawn label covers any dot.
  for (b in boxes) for (d in .djlc_dots(svg)) {
    nearest_x <- max(b$x0, min(d$x, b$x1))
    nearest_y <- max(b$y0, min(d$y, b$y1))
    expect_gte(sqrt((nearest_x - d$x)^2 + (nearest_y - d$y)^2), d$r)
  }
})


test_that("the scatter still renders when the placer is not loaded", {
  # The panel files can be sourced without 04_chart_builder.R, and the
  # renderer must fall back to the old fixed offset rather than error.
  hidden <- new.env(parent = environment(cb_dj_scatter_svg))
  assign(".place_scatter_labels", NULL, envir = hidden)
  fn <- cb_dj_scatter_svg
  environment(fn) <- hidden
  svg <- fn(.djlc_norms(), .djlc_curve(),
            focal_brand = "FOC", brand_labels = .djlc_labels)
  expect_true(grepl("cb-brand-label", svg, fixed = TRUE))
  expect_equal(length(.djlc_boxes(svg)), 3L)
})
