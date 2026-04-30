# ==============================================================================
# Tests for .place_scatter_labels() — collision-aware label placement
# ==============================================================================
# Used by the Category Context (clutter) and Extension (strength) scatters
# in the brand portfolio panel. When two categories sit at the same (x, y)
# their bubbles are drawn at the same place — the placement algorithm
# moves the *labels* off in different directions so the chart stays
# readable without distorting the data.
# ==============================================================================
library(testthat)

.find_root_lp <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_lp()

source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "04_chart_builder.R"))


# ------------------------------------------------------------------------------
# Shape + invariants
# ------------------------------------------------------------------------------

test_that(".place_scatter_labels: returns one placement per point", {
  points <- list(
    list(svgx = 100, svgy = 100, r = 8, label = "A", is_focal = FALSE),
    list(svgx = 200, svgy = 200, r = 8, label = "B", is_focal = FALSE),
    list(svgx = 300, svgy = 300, r = 8, label = "C", is_focal = FALSE)
  )
  out <- .place_scatter_labels(points,
                                plot_left = 0, plot_right = 500,
                                plot_top  = 0, plot_bot   = 500)
  expect_equal(length(out), 3L)
  for (pl in out) {
    expect_true(all(c("cx", "cy", "anchor", "leader") %in% names(pl)))
    expect_true(pl$anchor %in% c("start", "middle", "end"))
    expect_true(is.logical(pl$leader))
  }
})


test_that(".place_scatter_labels: empty input returns empty list", {
  out <- .place_scatter_labels(list(),
                                plot_left = 0, plot_right = 500,
                                plot_top  = 0, plot_bot   = 500)
  expect_equal(length(out), 0L)
})


# ------------------------------------------------------------------------------
# The IPK overlap case — three categories at exactly the same (x, y)
# should get labels in three DIFFERENT positions.
# ------------------------------------------------------------------------------

test_that(".place_scatter_labels: stacked points get distinct anchors", {
  # Three categories at the same coordinate — exactly the IPK Wave 1
  # Salad Dressings / Stock Powder / Cook-in Sauces situation.
  points <- list(
    list(svgx = 200, svgy = 200, r = 10, label = "Salad Dressings",
         is_focal = FALSE),
    list(svgx = 200, svgy = 200, r = 10, label = "Stock Powder / Liquid",
         is_focal = FALSE),
    list(svgx = 200, svgy = 200, r = 10, label = "Cook-in Sauces",
         is_focal = FALSE)
  )
  out <- .place_scatter_labels(points,
                                plot_left = 0, plot_right = 720,
                                plot_top  = 0, plot_bot   = 520)

  # Different points in 2D — no two labels share an anchor coordinate.
  centres <- lapply(out, function(p) c(p$cx, p$cy))
  uniq <- unique(centres)
  expect_equal(length(uniq), 3L,
               info = sprintf("Got duplicate label centres: %s",
                              paste(sapply(centres, paste, collapse = ","),
                                    collapse = " | ")))

  # All centres must lie outside the bubble + pad.
  for (i in seq_along(out)) {
    pt <- points[[i]]; pl <- out[[i]]
    d <- sqrt((pl$cx - pt$svgx)^2 + (pl$cy - pt$svgy)^2)
    expect_gt(d, pt$r)
  }
})


test_that(".place_scatter_labels: well-separated points keep east anchor", {
  # Points spaced far apart — no collision — should pick the cheap
  # default east position with no leader line.
  points <- list(
    list(svgx = 100, svgy = 100, r = 8, label = "A", is_focal = FALSE),
    list(svgx = 400, svgy = 100, r = 8, label = "B", is_focal = FALSE),
    list(svgx = 100, svgy = 400, r = 8, label = "C", is_focal = FALSE),
    list(svgx = 400, svgy = 400, r = 8, label = "D", is_focal = FALSE)
  )
  out <- .place_scatter_labels(points,
                                plot_left = 0, plot_right = 500,
                                plot_top  = 0, plot_bot   = 500)
  for (pl in out) {
    expect_equal(pl$anchor, "start")
    expect_false(pl$leader)
  }
})


test_that(".place_scatter_labels: focal point processed first (gets default east)", {
  # Focal at (200, 200), two non-focal stacked at the same place.
  # Focal should get the default east position; the rest fan out.
  points <- list(
    list(svgx = 200, svgy = 200, r = 10, label = "FOCAL", is_focal = TRUE),
    list(svgx = 200, svgy = 200, r = 10, label = "rival1", is_focal = FALSE),
    list(svgx = 200, svgy = 200, r = 10, label = "rival2", is_focal = FALSE)
  )
  out <- .place_scatter_labels(points,
                                plot_left = 0, plot_right = 720,
                                plot_top  = 0, plot_bot   = 520)
  expect_equal(out[[1]]$anchor, "start")
  # Focal gets the no-leader east slot
  expect_false(out[[1]]$leader)
  # Rivals get pushed elsewhere
  expect_true(out[[2]]$leader || out[[2]]$anchor != "start" ||
              abs(out[[2]]$cx - 200 - 14) > 1)
})


test_that(".place_scatter_labels: respects chart edges (leftmost point)", {
  # Point hard against the left edge — should NOT pick a left/west anchor
  # that would push the label off the chart.
  points <- list(
    list(svgx = 10, svgy = 200, r = 8, label = "Left-edge label that is wide",
         is_focal = FALSE),
    list(svgx = 100, svgy = 200, r = 8, label = "Centre",
         is_focal = FALSE)
  )
  out <- .place_scatter_labels(points,
                                plot_left = 0, plot_right = 500,
                                plot_top  = 0, plot_bot   = 500)
  # Edge point's label should stay inside the chart (x range 0..500).
  pl1 <- out[[1]]
  expect_gte(pl1$cx, -10)  # cx is anchor, not left edge — small margin OK
  # The corresponding label box's right edge should not exceed plot_right
  char_w <- 10 * 0.55
  label_w <- char_w * nchar(points[[1]]$label)
  bx_right <- if (pl1$anchor == "start") pl1$cx + label_w
              else if (pl1$anchor == "end") pl1$cx
              else pl1$cx + label_w / 2
  expect_lte(bx_right, 510)  # small tolerance
})


# ------------------------------------------------------------------------------
# Determinism — same inputs → same outputs
# ------------------------------------------------------------------------------

test_that(".place_scatter_labels: deterministic", {
  points <- list(
    list(svgx = 200, svgy = 200, r = 10, label = "AAAA", is_focal = FALSE),
    list(svgx = 200, svgy = 200, r = 10, label = "BBBB", is_focal = FALSE),
    list(svgx = 250, svgy = 250, r = 10, label = "CCCC", is_focal = FALSE)
  )
  o1 <- .place_scatter_labels(points, 0, 500, 0, 500)
  o2 <- .place_scatter_labels(points, 0, 500, 0, 500)
  expect_equal(o1, o2)
})
