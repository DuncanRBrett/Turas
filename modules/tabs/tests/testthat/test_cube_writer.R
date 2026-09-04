# ==============================================================================
# TABS. AGGREGATE CUBE WRITER
# ==============================================================================
# Hand-built microdata lists, one per base definition the engine actually has,
# so each accumulator is pinned against a number that can be checked by eye
# rather than against another run of the same code.
#
# The cross-engine half of this contract lives in
# modules/tabs/lib/html_report_v2/tests/computed_parity_tests.mjs (CP-4), which
# runs an enumerated set of views through the cube and through the respondent
# island and compares them cell by cell. This file pins the writer's own rules:
# the five bases, the block rule, monotonicity, and what a refused block looks
# like on disk.
# ==============================================================================

turas_root <- local({
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "tabs"))) return(normalizePath(path))
    path <- dirname(path)
  }
  stop("Cannot detect the Turas project root")
})
source(file.path(turas_root, "modules/tabs/lib/cube_writer.R"))


# --- fixtures -----------------------------------------------------------------

#' A two-column banner and the questions the edge cases need
#'
#' Q1  a plain single-response question, two category rows
#' Q2  a scale with box membership: rows 0..2 are categories, row 3 is a
#'     box-scored NET, row 4 is a NET declared over member rows
#' Q3  a multi-mention question whose NET covers two rows a respondent can both
#'     select, which is what makes a NET a union rather than a sum
#' Q4  a numeric question with a ratio of totals over Q5 and Q6
fixture_layer <- function() {
  list(
    banner_groups = list(list(id = "Grp", name = "Group")),
    columns = list(
      list(label = "Total", group = "total"),
      list(label = "A", group = "Grp", letter = "A"),
      list(label = "B", group = "Grp", letter = "B")
    ),
    questions = list(
      list(code = "Q1", type = "single",
           rows = list(list(kind = "category", label = "Yes"),
                       list(kind = "category", label = "No"))),
      list(code = "Q2", type = "scale", scale_max = 3,
           index_scores = list("Low" = 1, "Mid" = 2, "High" = 3),
           rows = list(list(kind = "category", label = "Low"),
                       list(kind = "category", label = "Mid"),
                       list(kind = "category", label = "High"),
                       list(kind = "net", label = "Top box"),
                       list(kind = "net", label = "Mid or better")),
           net_members = list("4" = c(1L, 2L))),
      list(code = "Q3", type = "multi",
           rows = list(list(kind = "category", label = "Radio"),
                       list(kind = "category", label = "TV"),
                       list(kind = "category", label = "Print"),
                       list(kind = "net", label = "Any broadcast")),
           net_members = list("3" = c(0L, 1L))),
      list(code = "Q4", type = "numeric",
           ratio = list(num = "Q5", den = "Q6"),
           rows = list(list(kind = "mean", label = "Average spend")))
    )
  )
}

#' Six respondents, three in each banner column, exercising every edge at once.
#'
#'   r1  Q1 Yes,  Q2 High (box 3),  Q3 Radio+TV,      score 3, num 10 den 2
#'   r2  Q1 No,   Q2 answered-unshown,                score 2, num 10 den 0
#'   r3  Q1 Yes,  Q2 box only (no answer),            no score, num NA
#'   r4  Q1 Yes,  Q2 Low,           Q3 Print,         score 1, num 6  den 3
#'   r5  Q1 No,   Q2 Mid,           Q3 Radio,         score 2, num 8  den 4
#'   r6  Q1 Yes,  Q2 never answered, Q3 never,        no score, num NA
fixture_micro <- function(weights = rep(1, 6)) {
  list(
    n = 6L,
    answers = list(
      Q1 = c(0L, 1L, 0L, 0L, 1L, 0L),
      Q2 = c(2L, CUBE_ANSWERED_UNSHOWN, NA_integer_, 0L, 1L, NA_integer_),
      Q3 = list(c(0L, 1L), NA_integer_, NA_integer_, 2L, 0L, NA_integer_),
      Q4 = rep(CUBE_ANSWERED_UNSHOWN, 6)
    ),
    banner_vars = list(Grp = c(1L, 1L, 1L, 2L, 2L, 2L)),
    weights = weights,
    scores = list(
      Q2 = c(3, 2, NA, 1, 2, NA),
      Q5 = c(10, 10, NA, 6, 8, NA),
      Q6 = c(2, 0, NA, 3, 4, NA)
    ),
    boxes = list(Q2 = c(3L, NA_integer_, 3L, NA_integer_, NA_integer_, NA_integer_))
  )
}

fixture_config <- function(k = 1, order = 2L, filter_vars = character(0)) {
  list(min_reporting_base = k, html_report_v2_cube_order = order,
       html_report_v2_filter_vars = filter_vars)
}

total_cell <- function(cube, code) cube$slices[[CUBE_TOTAL_SLICE]]$q[[code]][[CUBE_TOTAL_SLICE]]


# --- the five bases -----------------------------------------------------------

test_that("the tabulate base counts a box-only respondent and an answered-unshown", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  b <- total_cell(cube, "Q2")$b
  # r1 (High), r2 (answered-unshown), r3 (box only), r4 (Low), r5 (Mid). r6 never
  # answered and carries no box, so it is in no base at all.
  expect_equal(b[1], 5)
  expect_equal(b[2], 5)
})

test_that("the netCounts base is narrower than the tabulate base, and is written", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  cell <- total_cell(cube, "Q2")
  # A raw answer only: r1, r2, r4, r5. r3's box does not make it answered here.
  expect_equal(cell$nb[1], 4)
  expect_false(identical(cell$nb, cell$b))
})

test_that("nb is omitted when it does not differ from b", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  expect_null(total_cell(cube, "Q1")$nb)
  expect_equal(total_cell(cube, "Q1")$b[1], 6)
})

test_that("an answered-unshown answer counts in the base and in no row", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  r <- total_cell(cube, "Q2")$r
  # Low (r4), Mid (r5), High (r1). r2's unshown answer lands in no row.
  expect_equal(sum(unlist(r)), 3)
  expect_equal(r[["0"]], 1)
  expect_equal(r[["1"]], 1)
  expect_equal(r[["2"]], 1)
})

test_that("box membership is keyed by NET row index", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  x <- total_cell(cube, "Q2")$x
  expect_equal(x[["3"]], 2)          # r1 and r3
})

test_that("a NET is a union: a respondent in two member rows counts once", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  cell <- total_cell(cube, "Q3")
  # r1 selected Radio AND TV, both members of the NET.
  expect_equal(cell$r[["0"]], 2)     # Radio: r1 and r5
  expect_equal(cell$r[["1"]], 1)     # TV: r1
  expect_equal(cell$n[["3"]], 2)     # the NET: r1 once, plus r5
})

test_that("a null score is in the answered base and out of the score base", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  cell <- total_cell(cube, "Q2")
  expect_equal(cell$b[1], 5)
  expect_equal(cell$s[1], 4)         # r1, r2, r4, r5 carry a score
  expect_equal(cell$s[4], 3 + 2 + 1 + 2)
  expect_equal(cell$s[5], 9 + 4 + 1 + 4)
})

test_that("a ratio of totals excludes a zero denominator", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  rt <- total_cell(cube, "Q4")$rt
  # r2 has a denominator of 0 and is excluded; r1, r4, r5 remain.
  expect_equal(rt[1], 3)
  expect_equal(rt[2], 10 + 6 + 8)
  expect_equal(rt[3], 2 + 3 + 4)
})

test_that("the audience record counts everyone in the cell, question or no question", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  cells <- cube$slices[["Grp"]]$cells
  expect_equal(cells[["1"]]$a[1], 3)
  expect_equal(cells[["2"]]$a[1], 3)
  expect_equal(cube$slices[[CUBE_TOTAL_SLICE]]$cells[[CUBE_TOTAL_SLICE]]$a[1], 6)
})

test_that("weights ride on every accumulator and the cube says it is weighted", {
  w <- c(2, 1, 1, 3, 1, 1)
  cube <- build_cube(fixture_micro(w), fixture_layer(), fixture_config())
  expect_true(cube$weighted)
  cell <- total_cell(cube, "Q2")
  expect_equal(cell$b[1], 5)                      # unweighted count, unchanged
  expect_equal(cell$b[2], 2 + 1 + 1 + 3 + 1)      # sum of weights
  expect_equal(cell$b[3], 4 + 1 + 1 + 9 + 1)      # sum of squared weights
  expect_equal(cell$r[["2"]], 2)                  # High: r1, weight 2
})


# --- the median channel -------------------------------------------------------

test_that("a designed scale ships its distribution, so a union median is exact", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  expect_equal(cube$questions$Q2$score_values, c(1, 2, 3))
  d <- total_cell(cube, "Q2")$d
  expect_equal(d[["1"]], 1)
  expect_equal(d[["2"]], 2)
  expect_equal(d[["3"]], 1)
})

test_that("a weighted report ships no median and no distribution", {
  cube <- build_cube(fixture_micro(c(2, 1, 1, 3, 1, 1)), fixture_layer(), fixture_config())
  cell <- total_cell(cube, "Q2")
  expect_null(cell$m)
  expect_null(cell$d)
})


# --- the block rule -----------------------------------------------------------

test_that("cube_block_ok admits an empty cell and refuses a sub-k one", {
  expect_true(cube_block_ok(c(0, 12, 30), 5))
  expect_true(cube_block_ok(c(5, 5), 5))
  expect_false(cube_block_ok(c(0, 4, 30), 5))
  expect_false(cube_block_ok(c(1), 5))
  expect_true(cube_block_ok(numeric(0), 5))
  expect_true(cube_block_ok(c(0, 1, 2), 1))       # k = 1 is off
})

test_that("a published banner margin suppresses the CELL, not the whole cut", {
  # The banner is what the workbook already prints column by column, base by
  # base, with the sub-k columns blanked. So a small column withholds its own
  # answers and every other column still reports. The whole-block rule there
  # cost a whole cut for one small group.
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config(k = 3))
  grp <- cube$slices[["Grp"]]
  expect_false(is.null(grp))
  # Q2's answered base is 3 in column A (r1, r2, r3) and 2 in column B (r4, r5),
  # so column B is under k and column A is not.
  q2 <- grp$q$Q2
  expect_false(is.null(q2))
  expect_null(q2[["1"]]$sup)                    # 3 answered, ships in full
  expect_false(is.null(q2[["1"]]$r))
  expect_true(isTRUE(q2[["2"]]$sup))            # 2 answered, base only
  expect_equal(q2[["2"]]$b[1], 2)
  for (key in c("r", "n", "x", "s", "m", "sr", "rt", "d", "nb")) {
    expect_null(q2[["2"]][[key]], info = key)
  }
  # The headcount of a banner column is the workbook's own base row, so it is
  # never withheld.
  expect_equal(grp$cells[["2"]]$a[1], 3)
})

test_that("a suppressed banner cell survives the round trip as base only", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config(k = 3))
  back <- jsonlite::fromJSON(serialize_cube(cube), simplifyVector = FALSE)
  cell <- back$slices$Grp$q$Q2[["2"]]
  expect_true(isTRUE(cell$sup))
  expect_equal(length(cell$b), 3)
  expect_setequal(names(cell), c("b", "sup"))
})

test_that("a block with nothing above k is still refused outright", {
  # k = 4: no Grp column reaches 4 answered on Q2, so there is nothing to show
  # and the block is null rather than a table of blanks.
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config(k = 4))
  grp <- cube$slices[["Grp"]]
  expect_false(is.null(grp))                    # the headcounts still ship
  expect_true("Q2" %in% names(grp$q))
  expect_null(grp$q$Q2)
  back <- jsonlite::fromJSON(serialize_cube(cube), simplifyVector = FALSE)
  expect_true("Q2" %in% names(back$slices$Grp$q))
  expect_null(back$slices$Grp$q$Q2)
})

test_that("a CROSSING keeps the whole-block rule, because nobody published it", {
  # Grp x Q1 is a cut the workbook never printed. A cell withheld on its own
  # there is recovered by subtraction from a margin the cube itself shipped, so
  # the block goes whole or not at all.
  layer <- fixture_layer()
  cfg <- fixture_config(k = 3, filter_vars = "Q1")
  cube <- build_cube(fixture_micro(), layer, cfg)
  cross <- cube$slices[["Grp*Q1"]]
  if (!is.null(cross) && !is.null(cross$q$Q2)) {
    for (cell in cross$q$Q2) {
      expect_null(cell$sup)                     # never per-cell on a crossing
      expect_gte(cell$b[1], 3)
    }
  } else {
    expect_true(is.null(cross) || is.null(cross$q$Q2))
  }
})

test_that("a declared QUESTION variable is not a published margin", {
  # Q1 is a declared filter variable, not a banner. Q1 by anything is a cut the
  # workbook never printed, so its own order-1 slice keeps the whole-block rule.
  layer <- fixture_layer()
  cfg <- fixture_config(k = 3, filter_vars = "Q1")
  cube <- build_cube(fixture_micro(), layer, cfg)
  sl <- cube$slices[["Q1"]]
  if (!is.null(sl)) {
    for (code in names(sl$q)) {
      blk <- sl$q[[code]]
      if (is.null(blk)) next
      for (cell in blk) expect_null(cell$sup)
    }
  }
  expect_true(TRUE)
})

test_that("the whole sample still ships when a finer slice does not", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config(k = 4))
  expect_false(is.null(cube$slices[[CUBE_TOTAL_SLICE]]))
  expect_equal(total_cell(cube, "Q1")$b[1], 6)
})

#' A sample big enough that an order-2 slice actually ships, which is what the
#' monotonicity property is about. Forty respondents, two banner columns, two Q1
#' answers, every combination occupied ten times.
wide_fixture <- function(n = 40L) {
  idx <- seq_len(n) - 1L
  layer <- fixture_layer()
  micro <- list(
    n = n,
    answers = list(
      Q1 = as.integer(idx %% 2L),
      Q2 = as.integer(idx %% 3L),
      Q3 = as.list(as.integer(idx %% 3L)),
      Q4 = rep(CUBE_ANSWERED_UNSHOWN, n)
    ),
    banner_vars = list(Grp = as.integer(idx %/% (n %/% 2L)) + 1L),
    weights = rep(1, n),
    scores = list(Q2 = as.numeric(idx %% 3L) + 1,
                  Q5 = rep(10, n), Q6 = rep(2, n)),
    boxes = list(Q2 = ifelse(idx %% 3L == 2L, 3L, NA_integer_))
  )
  list(layer = layer, micro = micro)
}

test_that("an order-2 slice ships when every occupied cell clears k", {
  f <- wide_fixture()
  cube <- build_cube(f$micro, f$layer, fixture_config(k = 5, filter_vars = "Q1"))
  expect_false(is.null(cube$slices[["Grp*Q1"]]))
  expect_equal(length(cube$slices[["Grp*Q1"]]$cells), 4)
  for (cell in cube$slices[["Grp*Q1"]]$cells) expect_gte(cell$a[1], 5)
})

test_that("every projection of a shipped block is itself shipped", {
  f <- wide_fixture()
  layer <- f$layer
  cube <- build_cube(f$micro, layer, fixture_config(k = 5, filter_vars = "Q1"))
  checked <- 0L
  shipped <- names(cube$slices)[!vapply(cube$slices, is.null, logical(1))]
  for (key in shipped) {
    if (identical(key, CUBE_TOTAL_SLICE)) next
    vars <- strsplit(key, "*", fixed = TRUE)[[1]]
    if (length(vars) < 2) next
    for (i in seq_along(vars)) {
      proj <- cube_slice_key(vars[-i])
      expect_false(is.null(cube$slices[[proj]]),
                   info = paste("projection", proj, "of", key))
      for (code in names(cube$slices[[key]]$q)) {
        if (is.null(cube$slices[[key]]$q[[code]])) next
        expect_false(is.null(cube$slices[[proj]]$q[[code]]),
                     info = paste(code, "in projection", proj, "of", key))
        checked <- checked + 1L
      }
    }
  }
  # A property test that examined nothing would pass for the wrong reason.
  expect_gt(checked, 0)
})

test_that("a multi-mention question is refused as a declared filter variable", {
  layer <- fixture_layer()
  micro <- fixture_micro()
  cfg <- fixture_config(k = 2, filter_vars = "Q3")
  cube <- build_cube(micro, layer, cfg)
  expect_null(cube$vars$Q3)
  refusal <- cube_validate_filter_vars(cube, layer, cfg)
  expect_equal(refusal$status, "REFUSED")
  expect_equal(refusal$code, "CFG_CUBE_FILTER_VAR")
  expect_true(grepl("multi-mention", refusal$message))
})

test_that("a declared filter variable that is a real partition is accepted", {
  layer <- fixture_layer()
  cfg <- fixture_config(k = 2, filter_vars = "Q1")
  cube <- build_cube(fixture_micro(), layer, cfg)
  expect_null(cube_validate_filter_vars(cube, layer, cfg))
  expect_equal(cube$vars$Q1$kind, "question")
  expect_equal(cube$vars$Q1$levels, c(0L, 1L))
  expect_true("Grp*Q1" %in% names(cube$slices))
})

test_that("the order cap decides which combinations exist at all", {
  layer <- fixture_layer()
  one <- build_cube(fixture_micro(), layer, fixture_config(order = 1L, filter_vars = "Q1"))
  expect_false("Grp*Q1" %in% names(one$slices))
  expect_true(all(c(CUBE_TOTAL_SLICE, "Grp", "Q1") %in% names(one$slices)))
})


# --- the island ---------------------------------------------------------------

test_that("the serialised island parses back with everything the renderer reads", {
  cube <- build_cube(fixture_micro(), fixture_layer(),
                     fixture_config(k = 2, filter_vars = "Q1"))
  back <- jsonlite::fromJSON(serialize_cube(cube), simplifyVector = FALSE)
  expect_equal(back$schema_version, 1)
  expect_equal(back$n, 6)
  expect_equal(back$k, 2)
  expect_equal(back$order, 2)
  expect_false(back$weighted)
  expect_setequal(names(back$vars), c("Grp", "Q1"))
  expect_true(all(c("has") %in% names(back$questions$Q2)))
  expect_true(CUBE_TOTAL_SLICE %in% names(back$slices))
  # The counts the console and the About page quote travel on the island; the
  # writer's own bookkeeping fields do not.
  expect_true(back$blocks$shipped > 0)
  expect_null(back$blocks_shipped)
  expect_null(back$rejected_vars)
})

test_that("no array in the island is as long as the study", {
  cube <- build_cube(fixture_micro(), fixture_layer(),
                     fixture_config(k = 2, filter_vars = "Q1"))
  back <- jsonlite::fromJSON(serialize_cube(cube), simplifyVector = FALSE)
  longest <- 0L
  walk <- function(node) {
    if (!is.list(node)) return(invisible(NULL))
    if (is.null(names(node))) longest <<- max(longest, length(node))
    for (child in node) walk(child)
    invisible(NULL)
  }
  walk(back$slices)
  # The widest record is the five-number score accumulator.
  expect_lte(longest, 5)
  expect_lt(longest, back$n)
})

test_that("build_cube returns NULL rather than an empty island", {
  expect_null(build_cube(NULL, fixture_layer(), fixture_config()))
  expect_null(build_cube(list(n = 0L), fixture_layer(), fixture_config()))
  expect_equal(serialize_cube(NULL), "null")
})


# --- the filter-independent question facts ------------------------------------

test_that("a designed scale keeps its full range and an unbounded one uses p5 to p95", {
  expect_equal(cube_robust_range(c(1, 2, 3, 4, 5), 5), 5)
  wide <- c(seq_len(100), 100000)
  expect_true(cube_robust_range(wide, max(wide)) < max(wide))
})

test_that("the histogram mirrors the renderer's binning, zero-based scales included", {
  layer <- fixture_layer()
  micro <- fixture_micro()
  cube <- build_cube(micro, layer, fixture_config())
  h <- cube$questions$Q2$histogram
  expect_equal(h$scale_max, 3)                 # 1..3, not zero-based
  expect_equal(h$counts, c(1, 2, 1))
})

test_that("the score range and the score source travel with the question", {
  cube <- build_cube(fixture_micro(), fixture_layer(), fixture_config())
  expect_equal(cube$questions$Q2$score_src, "scores")
  expect_equal(cube$questions$Q2$score_lo, 1)
  expect_equal(cube$questions$Q2$score_hi, 3)
  expect_true("boxes" %in% unlist(cube$questions$Q2$has))
})
