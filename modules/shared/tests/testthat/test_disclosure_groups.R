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

# ---------------------------------------------------------- exact recoverability
# The independent review of 24 Sep 2026 (docs/v2_lift/REVIEW_WHATIF_DISCLOSURE_
# 2026_09_24.md) broke the single-level and two-way candidate list: a union of
# small cells across rows and columns, and a three-way cell reached through a
# nested level, were both recoverable. Its study generator is reproduced here.
review_gen <- function(seed) {
  set.seed(seed)
  n <- sample(60:300, 1); nv <- sample(3:4, 1)
  ctx <- list()
  for (v in seq_len(nv)) {
    L <- sample(2:5, 1); p <- rgamma(L, 0.8); p <- p / sum(p)
    vals <- sample(paste0("L", seq_len(L)), n, TRUE, p)
    if (v == 2 && runif(1) < 0.5) {
      only <- ctx[[1]]$values == ctx[[1]]$values[1]
      vals[!only & vals == "L1"] <- "L2"
    }
    ctx[[paste0("v", v)]] <- list(label = paste0("V", v), values = vals)
  }
  pairs <- combn(names(ctx), 2, simplify = FALSE)
  cr <- pairs[sample(length(pairs), sample(1:min(3, length(pairs)), 1))]
  list(ctx = ctx, cr = cr)
}
review_gen2 <- function(seed) {
  set.seed(seed); st <- review_gen(seed); n <- length(st$ctx[[1]]$values)
  L <- sample(2:4, 1)
  st$ctx$v5 <- list(label = "V5", values = sample(paste0("L", 1:L), n, TRUE, {p <- rgamma(L, .8); p / sum(p)}))
  pairs <- combn(names(st$ctx), 2, simplify = FALSE)
  st$cr <- pairs[sample(length(pairs), sample(2:5, 1))]
  st
}
defs_of <- function(groups) lapply(seq_len(nrow(groups)), function(i) {
  g <- groups[i, ]; d <- character(0)
  if (!is.na(g$key1)) d[g$key1] <- g$level1
  if (!is.na(g$key2)) d[g$key2] <- g$level2
  d
})

# A brute force that shares nothing with the engine: explicit candidate sets
# tested one by one against the published groups' span by least squares, over
# atoms. Every atom, every three-way cell, every union of two small atoms, and
# every union of three or four small atoms when there are at most `budget` of
# them (the count is returned so a test can say what it covered).
brute_force <- function(context, defs, k, budget = 150000) {
  keys <- names(context)
  combo <- do.call(paste, c(lapply(keys, function(kk) context[[kk]]$values), sep = "\r"))
  atoms <- unique(combo)
  atom_n <- as.integer(table(combo)[atoms])
  parts <- do.call(rbind, strsplit(atoms, "\r", fixed = TRUE))
  colnames(parts) <- keys
  ind <- function(def) {
    m <- rep(TRUE, length(atoms))
    for (kk in names(def)) m <- m & parts[, kk] == def[[kk]]
    as.numeric(m)
  }
  A <- vapply(defs, ind, numeric(length(atoms)))
  if (!is.matrix(A)) A <- matrix(A, ncol = length(defs))
  q <- qr(A, tol = 1e-10)
  in_span <- function(M) {
    res <- qr.resid(q, M)
    if (!is.matrix(res)) res <- matrix(res, ncol = ncol(M))
    apply(abs(res), 2, max) < 1e-8
  }
  cands <- list()
  small <- which(atom_n < k)
  for (i in small) cands[[length(cands) + 1]] <- i
  if (length(keys) >= 3) for (trip in combn(keys, 3, simplify = FALSE)) {
    cell <- do.call(paste, c(lapply(trip, function(kk) parts[, kk]), sep = "\r"))
    for (cl in unique(cell)) {
      idx <- which(cell == cl)
      if (sum(atom_n[idx]) < k && length(idx) > 1) cands[[length(cands) + 1]] <- idx
    }
  }
  sizes <- 2
  if (length(small) >= 2) for (pr in combn(small, 2, simplify = FALSE)) {
    if (sum(atom_n[pr]) < k) cands[[length(cands) + 1]] <- pr
  }
  for (sz in 3:(k - 1)) {
    if (sz > length(small) || choose(length(small), sz) > budget) break
    sizes <- sz
    for (st in combn(small, sz, simplify = FALSE)) if (sum(atom_n[st]) < k) cands[[length(cands) + 1]] <- st
  }
  hits <- 0L
  chunk <- 5000
  for (from in seq(1, length(cands), by = chunk)) {
    to <- min(from + chunk - 1, length(cands))
    M <- vapply(cands[from:to], function(idx) { v <- numeric(length(atoms)); v[idx] <- 1; v }, numeric(length(atoms)))
    if (!is.matrix(M)) M <- matrix(M, ncol = to - from + 1)
    hits <- hits + sum(in_span(M))
  }
  list(hits = hits, candidates = length(cands), union_size = sizes, small_atoms = length(small))
}

test_that("a union of small cells across rows and columns cannot be worked out (review counterexample A)", {
  st <- review_gen(1035)
  p <- disclosure_publish_groups(st$ctx, st$cr, 5)
  expect_equal(brute_force(st$ctx, defs_of(p$groups), 5)$hits, 0L)
  expect_equal(p$audit$recoverable_failures, 0L)
  expect_true(disclosure_audit_groups(p$members, 5, st$ctx, defs_of(p$groups))$ok)
})

test_that("a three-way cell reached through a nested level cannot be worked out (review counterexample B)", {
  st <- review_gen2(5020)
  p <- disclosure_publish_groups(st$ctx, st$cr, 5)
  expect_equal(brute_force(st$ctx, defs_of(p$groups), 5)$hits, 0L)
  expect_true(disclosure_audit_groups(p$members, 5, st$ctx, defs_of(p$groups))$ok)
})

test_that("the audit finds the review's two counterexamples in the groups the old rules published", {
  # The group sets the single-level and two-way candidate list let through.
  # Counterexample A: all minus v1=L2 minus v2=L3 minus v2=L5 plus (L2,L3)
  # plus (L2,L5) leaves 2 people. B: (v1=L1,v3=L3) + (v2=L2,v3=L3) - (v3=L3)
  # is one three-way cell of 2.
  st <- review_gen(1035)
  defs <- list(character(0), c(v1 = "L2"), c(v2 = "L3"), c(v2 = "L5"), c(v1 = "L2", v2 = "L3"), c(v1 = "L2", v2 = "L5"))
  members <- vapply(defs, function(d) {
    m <- rep(TRUE, length(st$ctx$v1$values))
    for (kk in names(d)) m <- m & st$ctx[[kk]]$values == d[[kk]]
    m
  }, logical(length(st$ctx$v1$values)))
  expect_equal(colSums(members), c(137, 114, 90, 28, 75, 22))
  a <- disclosure_audit_groups(members, 5, st$ctx, defs)
  expect_false(a$ok)
  expect_true(length(a$recoverable) >= 1)
  st2 <- review_gen2(5020)
  defs2 <- list(character(0), c(v3 = "L3"), c(v1 = "L1", v3 = "L3"), c(v2 = "L2", v3 = "L3"))
  members2 <- vapply(defs2, function(d) {
    m <- rep(TRUE, 205)
    for (kk in names(d)) m <- m & st2$ctx[[kk]]$values == d[[kk]]
    m
  }, logical(205))
  a2 <- disclosure_audit_groups(members2, 5, st2$ctx, defs2)
  expect_false(a2$ok)
  expect_true(any(grepl("v1=L1", a2$recoverable) & grepl("v2=L2", a2$recoverable) & grepl("v3=L3", a2$recoverable)))
})

test_that("across the review's 250 random studies nothing under the minimum can be worked out", {
  # Before the exact engine the review's own brute force (atoms, three-way
  # cells, unions of two atoms) found 23 of 150 and 22 of 100. The brute force
  # here is stronger where it can afford to be; the coverage it reached is
  # reported so a shortfall is visible, never silent.
  leaks <- 0L; runs <- 0L; full <- 0L
  for (seed in c(1001:1150, 5001:5100)) {
    st <- if (seed < 5000) review_gen(seed) else review_gen2(seed)
    p <- disclosure_publish_groups(st$ctx, st$cr, 5)
    expect_true(all(p$groups$n >= 5))
    expect_equal(p$audit$recoverable_failures, 0L)
    expect_true(isTRUE(p$audit$exact))
    bf <- brute_force(st$ctx, defs_of(p$groups), 5)
    runs <- runs + 1L
    leaks <- leaks + (bf$hits > 0)
    full <- full + (bf$union_size == 4 || bf$small_atoms < 4)
    a <- disclosure_audit_groups(p$members, 5, st$ctx, defs_of(p$groups))
    expect_true(a$ok, info = paste("seed", seed))
  }
  expect_equal(runs, 250L)
  expect_equal(leaks, 0L)
  cat(sprintf("\n[disclosure] brute force covered unions of up to four small atoms in %d of %d studies\n", full, runs))
  expect_gte(full, 200L)
})

test_that("the engine reports what it found and refuses past its work cap rather than passing silently", {
  # Four atoms of one each, published only as pairs {1,2} and {3,4} and the
  # whole: the pairs themselves are recoverable sets of 2.
  A <- cbind(all = c(1, 1, 1, 1), p12 = c(1, 1, 0, 0), p34 = c(0, 0, 1, 1))
  r <- disclosure_small_recoverable(c(1L, 1L, 1L, 1L), A, 5)
  expect_length(r$sets, 2)
  expect_setequal(lapply(r$sets, `[[`, "atoms"), list(1:2, 3:4))
  expect_true(all(vapply(r$sets, function(s) s$n, 0) == 2))
  expect_equal(r$sets[[1]]$coef[abs(r$sets[[1]]$coef) > 1e-8], 1)
  # Twenty singleton atoms, twelve published sets: the search has thousands
  # of subsets, so a cap of 20 is passed.
  set.seed(2)
  A2 <- matrix(rbinom(20 * 12, 1, 0.5), 20, 12)
  expect_error(disclosure_small_recoverable(rep(1L, 20), A2, 5, max_work = 20), class = "turas_refusal")
  # Nothing published beyond the whole sample: nothing to combine.
  r0 <- disclosure_small_recoverable(c(2L, 3L, 40L), matrix(1, 3, 1), 5)
  expect_length(r0$sets, 0)
  # A pure function: the caller's random stream is where it was.
  set.seed(77); before <- .Random.seed
  invisible(disclosure_small_recoverable(c(1L, 1L, 1L, 1L), A, 5))
  expect_identical(.Random.seed, before)
  expect_equal(stats::runif(1), { set.seed(77); stats::runif(1) })
})
