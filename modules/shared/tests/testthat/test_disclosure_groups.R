# ==============================================================================
# TESTS: SHARED DISCLOSURE, PUBLISHABLE GROUPS
# ==============================================================================
#
# Secondary suppression within a crossing, the nesting check between groups,
# and the independent audit. Synthetic data only. The SACAP 2025 counts the
# port reproduces (291 groups, 103 hidden cells, 3 hidden by the nesting
# check) were checked with client data outside the suite; see
# docs/v2_lift/NOTES_WHATIF_SESSIONS_2_4.md.
# ==============================================================================

root <- Sys.getenv("TURAS_ROOT", unset = "")
if (!nzchar(root)) {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    if (file.exists(file.path(dir, "modules", "shared", "lib", "disclosure_groups.R"))) {
      root <- dir
      break
    }
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }
}
source(file.path(root, "modules", "shared", "lib", "trs_refusal.R"), local = TRUE)
source(file.path(root, "modules", "shared", "lib", "disclosure_groups.R"), local = TRUE)

# A row or column is safe when it hides nothing, hides at least k, or hides
# every non-empty cell it has (then its total is its own single group, under k
# and unpublished, so nothing can be subtracted from it).
line_ok <- function(tab, hide, k) {
  ok <- function(counts, hidden) {
    tot <- sum(counts[hidden])
    tot == 0 || tot >= k || all(hidden[counts > 0])
  }
  all(vapply(seq_len(nrow(tab)), function(i) ok(tab[i, ], hide[i, ]), logical(1))) &&
    all(vapply(seq_len(ncol(tab)), function(j) ok(tab[, j], hide[, j]), logical(1)))
}

test_that("one small cell forces a partner in its row and its column", {
  tab <- matrix(c(40, 3, 30,
                  25, 50, 20,
                  10, 15, 60), 3, byrow = TRUE, dimnames = list(c("a", "b", "c"), c("x", "y", "z")))
  hide <- disclosure_secondary_suppression(tab, 5)
  expect_true(hide["a", "y"])
  expect_true(line_ok(tab, hide, 5))
  expect_equal(disclosure_line_failures(tab, hide, 5), 0L)
  expect_gte(sum(hide), 3)
})

test_that("a table with no small cell hides nothing", {
  tab <- matrix(c(10, 20, 30, 40), 2, dimnames = list(c("a", "b"), c("x", "y")))
  expect_false(any(disclosure_secondary_suppression(tab, 5)))
})

test_that("after suppression no row or column can give a hidden cell back, on random tables", {
  # Includes sparse tables (mean 2 per cell) where whole rows are small.
  set.seed(5)
  for (r in 1:40) {
    nr <- sample(2:6, 1); nc <- sample(2:6, 1)
    tab <- matrix(rpois(nr * nc, sample(c(2, 6, 15), 1)), nr, dimnames = list(letters[1:nr], LETTERS[1:nc]))
    hide <- disclosure_secondary_suppression(tab, 5)
    expect_true(all(hide[tab > 0 & tab < 5]))
    expect_true(line_ok(tab, hide, 5))
    expect_equal(disclosure_line_failures(tab, hide, 5), 0L)
  }
})

test_that("a seeded cell stays hidden and is protected", {
  tab <- matrix(c(40, 30, 25, 50), 2, dimnames = list(c("a", "b"), c("x", "y")))
  seed <- matrix(c(TRUE, FALSE, FALSE, FALSE), 2, dimnames = dimnames(tab))
  hide <- disclosure_secondary_suppression(tab, 5, seed)
  expect_true(hide["a", "x"])
  expect_true(line_ok(tab, hide, 5))
})

test_that("differencing pairs find a group inside another that differs by fewer than k", {
  members <- cbind(outer = c(rep(TRUE, 12), rep(FALSE, 8)), inner = c(rep(TRUE, 10), rep(FALSE, 10)),
                   apart = c(rep(FALSE, 12), rep(TRUE, 8)))
  p <- disclosure_differencing_pairs(members, 5)
  expect_equal(nrow(p), 1)
  expect_equal(colnames(members)[p$inner], "inner")
  expect_equal(p$diff, 2)
  expect_false(disclosure_audit_groups(members, 5)$ok)
})

make_context <- function(n = 400, seed = 3) {
  set.seed(seed)
  site <- sample(c("North", "South", "East", "West"), n, TRUE, c(0.4, 0.3, 0.2, 0.1))
  level <- sample(c("L1", "L2", "L3"), n, TRUE, c(0.5, 0.35, 0.15))
  sex <- sample(c("F", "M"), n, TRUE, c(0.7, 0.3))
  list(site = list(label = "Site", values = site), level = list(label = "Level", values = level),
       sex = list(label = "Sex", values = sex))
}

test_that("published groups all clear the minimum and none can be worked out by subtraction", {
  ctx <- make_context()
  p <- disclosure_publish_groups(ctx, list(c("site", "level"), c("site", "sex"), c("level", "sex")), 10, "All")
  expect_true(all(p$groups$n >= 10))
  a <- disclosure_audit_groups(p$members, 10)
  expect_true(a$ok)
  expect_equal(p$audit$line_failures, 0L)
  expect_equal(p$audit$differencing_failures, 0L)
  expect_equal(p$groups$id[1], "all")
  expect_equal(p$groups$n[1], 400L)
  expect_equal(sum(p$crossings$cells), sum(p$crossings$shown) + nrow(p$hidden))
})

test_that("the nesting check hides a group that sits inside another and differs by two people", {
  # Honours year has 12 people; the honours course, 10 of them. Publishing both
  # would give 2 people away by subtraction (the SACAP "Online Access" case).
  n <- 300
  campus <- c(rep("X", 60), rep("Y", n - 60))
  year <- c(rep("Honours", 12), rep("Undergrad", n - 12))
  course <- c(rep("Honours course", 10), rep("Degree", n - 10))
  ctx <- list(campus = list(label = "Campus", values = campus), year = list(label = "Year", values = year),
              course = list(label = "Course", values = course))
  p <- disclosure_publish_groups(ctx, list(c("campus", "year"), c("campus", "course")), 5, "All")
  expect_gte(p$audit$nesting_hidden, 1L)
  expect_true(disclosure_audit_groups(p$members, 5)$ok)
  expect_false(all(c("year=Honours", "course=Honours course") %in% p$groups$id))
  expect_true(any(grepl("subtraction", p$refused$why)))
})

test_that("levels under the minimum are refused, not published", {
  ctx <- list(g = list(label = "G", values = c(rep("x", 50), rep("y", 3))))
  p <- disclosure_publish_groups(ctx, list(), 5, "All")
  expect_false("g=y" %in% p$groups$id)
  expect_true(any(grepl("G: y", p$refused$group)))
})

test_that("the result does not depend on the order respondents arrive in", {
  ctx <- make_context()
  cr <- list(c("site", "level"), c("site", "sex"))
  p1 <- disclosure_publish_groups(ctx, cr, 8, "All")
  o <- sample(400)
  ctx2 <- lapply(ctx, function(x) { x$values <- x$values[o]; x })
  p2 <- disclosure_publish_groups(ctx2, cr, 8, "All")
  expect_setequal(p1$groups$id, p2$groups$id)
})

test_that("levels sort the same way everywhere (byte order, not the locale)", {
  expect_equal(disclosure_levels(c("b", "B", "a", "A")), c("A", "B", "a", "b"))
})

# ---------------------------------------------------------------- recoverability
# An attack written independently of the code under test: projection onto the
# published groups' span by singular value decomposition, over respondents
# (not atoms), on every single level and every two-way cell under k.
attack <- function(context, groups_df, members, k) {
  keys <- names(context)
  sv <- svd(members * 1)
  keep <- sv$d > 1e-9 * max(sv$d)
  U <- sv$u[, keep, drop = FALSE]
  in_span <- function(v) max(abs(v - U %*% crossprod(U, v))) < 1e-7
  hits <- character(0)
  for (key in keys) for (lv in unique(context[[key]]$values)) {
    m <- context[[key]]$values == lv
    if (sum(m) > 0 && sum(m) < k && in_span(as.numeric(m))) hits <- c(hits, paste0(key, "=", lv))
  }
  for (i in seq_along(keys)) for (j in seq_along(keys)) if (i < j) {
    for (a in unique(context[[keys[i]]]$values)) for (b in unique(context[[keys[j]]]$values)) {
      m <- context[[keys[i]]]$values == a & context[[keys[j]]]$values == b
      if (sum(m) > 0 && sum(m) < k && in_span(as.numeric(m))) hits <- c(hits, paste0(keys[i], "=", a, "|", keys[j], "=", b))
    }
  }
  hits
}

test_that("a small level cannot be recovered as the whole sample minus the other levels", {
  set.seed(8)
  n <- 300
  campus <- c(rep("East", 3), sample(c("North", "South", "West"), n - 3, TRUE))
  year <- sample(c("Y1", "Y2", "Y3"), n, TRUE)
  ctx <- list(campus = list(label = "Campus", values = campus), year = list(label = "Year", values = year))
  p <- disclosure_publish_groups(ctx, list(c("campus", "year")), 10, "All")
  expect_length(attack(ctx, p$groups, p$members, 10), 0)
  expect_false("campus=East" %in% p$groups$id)
  expect_gte(p$audit$recovery_hidden, 1L)
  published_campus <- sum(p$groups$n[!is.na(p$groups$key1) & p$groups$key1 == "campus" & is.na(p$groups$key2)])
  expect_true(n - published_campus == 0 || n - published_campus >= 10)
})

test_that("a chain of subtractions across a crossing cannot recover a small cell", {
  # The reviewer's case: a row total minus its shown cells gives a hidden cell
  # of k or more, which then solves a column down to a small cell.
  set.seed(3)
  fails <- 0
  for (it in 1:60) {
    n <- sample(150:400, 1)
    mk <- function(L) sample(paste0("L", 1:L), n, TRUE, prob = rexp(L) + 0.3)
    ctx <- list(a = list(label = "A", values = mk(sample(3:5, 1))), b = list(label = "B", values = mk(sample(3:5, 1))),
                c = list(label = "C", values = mk(3)))
    p <- disclosure_publish_groups(ctx, list(c("a", "b"), c("b", "c")), 10, "All")
    fails <- fails + length(attack(ctx, p$groups, p$members, 10))
  }
  expect_equal(fails, 0)
})

test_that("the reviewer's fuzz: 150 random studies publish nothing a small group can be recovered from", {
  set.seed(1)
  leaks <- 0
  runs <- 0
  for (it in 1:150) {
    n <- sample(150:400, 1)
    mk <- function(L) sample(paste0("L", 1:L), n, TRUE, prob = rexp(L)^2)
    ctx <- list(a = list(label = "A", values = mk(sample(3:6, 1))), b = list(label = "B", values = mk(sample(3:5, 1))),
                c = list(label = "C", values = mk(sample(2:4, 1))))
    p <- disclosure_publish_groups(ctx, list(c("a", "b"), c("b", "c")), 10, "All")
    runs <- runs + 1
    leaks <- leaks + (length(attack(ctx, p$groups, p$members, 10)) > 0)
    a <- disclosure_audit_groups(p$members, 10, ctx,
      lapply(seq_len(nrow(p$groups)), function(i) {
        g <- p$groups[i, ]; d <- character(0)
        if (!is.na(g$key1)) d[g$key1] <- g$level1
        if (!is.na(g$key2)) d[g$key2] <- g$level2
        d
      }))
    expect_true(a$ok)
  }
  expect_equal(runs, 150)
  expect_equal(leaks, 0)
})

test_that("the audit finds a recoverable group the publisher would have hidden", {
  n <- 100
  ctx <- list(g = list(label = "G", values = c(rep("tiny", 3), rep("x", 50), rep("y", 47))))
  members <- cbind(all = rep(TRUE, n), x = ctx$g$values == "x", y = ctx$g$values == "y")
  a <- disclosure_audit_groups(members, 5, ctx, list(character(0), c(g = "x"), c(g = "y")))
  expect_false(a$ok)
  expect_equal(a$recoverable, "g=tiny")
})
