# Session 2 and 4: a whole run from a config, the preflight, the outputs and
# the client-safe block of the contribution file.

proj <- test_project()
res <- quietly(run_whatif(proj$config, verbose = FALSE))

test_that("a run from a config writes the workbook and the contribution file", {
  expect_false(is_refusal(res))
  expect_false(is_error(res))
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  expect_true(file.exists(res$files$excel))
  expect_true(file.exists(res$files$island))
  sheets <- readxl::excel_sheets(res$files$excel)
  expect_equal(sheets[1], "Run_Status")
  expect_true(all(c("Effort", "Groups", "Calibration", "Preflight", "Proposed_Structure", "Model",
                    "Profile", "Symptoms") %in% sheets))
})

test_that("the run matches the engine run on the same spec", {
  m <- quietly(whatif_run_engine(res$prep$spec, verbose = FALSE))
  expect_equal(unname(m$main$b), unname(res$model$main$b))
})

test_that("preflight finds the planted problems", {
  log <- res$preflight
  expect_true(any(log$Check == "Don't know" & log$Field == "admin"))
  expect_true(any(log$Check == "Possible symptom or outcome" & grepl("complain", log$Message)) ||
                !any(res$prep$spec$levers[[1]]$key == "called"))
  expect_true(any(log$Check == "Sign check" & log$Field == "noise"))
  expect_true(all(c("Component", "Check", "Field", "Message", "Severity") %in% names(log)))
})

test_that("proposed Structure rules list structural combinations nobody has, never personal traits", {
  ps <- res$proposed_structure
  expect_true(nrow(ps) > 0)
  expect_false(any(c(ps$Key1, ps$Key2) == "gender"))
  msc <- ps[ps$Key1 == "course" & ps$Level1 == "MSc" & ps$Key2 == "year" & ps$Level2 == "1st", ]
  expect_equal(nrow(msc), 1)
  ba <- ps[ps$Key1 == "course" & ps$Level1 == "BA" & ps$Key2 == "year" & ps$Level2 == "Masters", ]
  expect_true(ba$AlreadyRule)
})

test_that("the contribution file has every block, and meta says what it is", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)$variants$weighted
  expect_equal(j$meta$kind, "whatif")
  expect_equal(j$meta$n, 500)
  expect_equal(j$meta$id_variable, "ID")
  expect_true(all(c("meta", "model", "profile", "open", "safe") %in% names(j)))
  expect_length(j$model$fits, 21)
  expect_length(j$open$ids, 500)
  expect_length(j$open$val$teach, 500)
  expect_equal(unlist(j$open$ids)[1:3], sprintf("R%04d", 1:3))
})

longest_list <- function(o) {
  if (is.list(o) && is.null(names(o))) return(max(c(length(o), vapply(o, longest_list, numeric(1)))))
  if (is.list(o)) return(max(c(0, vapply(o, longest_list, numeric(1)))))
  length(o)
}

test_that("the client-safe block holds no respondent-length list and no group under the minimum", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)$variants$weighted
  safe <- list(meta = j$meta, model = j$model, safe = j$safe)
  expect_lt(longest_list(safe), 500)
  ns <- vapply(j$safe$groups, `[[`, 0, "n")
  expect_true(all(ns >= 5))
  needs <- unlist(lapply(j$safe$groups, function(g) unlist(g$need)))
  expect_true(all(is.na(needs) | needs >= 5))
  expect_equal(j$safe$audit$differencing_failures, 0)
  expect_equal(j$safe$audit$line_failures, 0)
})

test_that("published group results equal the engine's for the same group", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)$variants$weighted
  g <- j$safe$groups[[which(vapply(j$safe$groups, `[[`, "", "id") == "campus=North")]]
  mask <- res$model$spec$context$campus$values == "North"
  r <- whatif_group_results(res$model, list(north = mask))$north
  expect_equal(g$n, sum(mask))
  keys <- vapply(res$model$spec$levers, `[[`, "", "key")
  j_teach <- unlist(g$est[[match("teach", keys)]])
  expect_equal(j_teach[match("floor", WHATIF_MOVES)], round(r$levers$est[r$levers$key == "teach" & r$levers$move == "floor"], 2))
})

test_that("the client-safe profile offers only combinations shared by the minimum", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)$variants$weighted
  sp <- j$safe$profile
  keys <- vapply(sp$keys, `[[`, "", "key")
  ctx <- res$model$spec$context
  combo <- do.call(paste, c(lapply(keys, function(k) ctx[[k]]$values), sep = "|"))
  for (cb in sp$combos) {
    lv <- vapply(seq_along(keys), function(i) sp$keys[[i]]$levels[[unlist(cb)[i] + 1]], "")
    expect_gte(sum(combo == paste(lv, collapse = "|")), 5)
  }
  counts <- unlist(lapply(sp$keys, function(k) unlist(k$n)))
  expect_true(all(counts >= 5))
})

test_that("the profile builder switch removes Build a ... from every block", {
  p2 <- test_project(config = list(profile_builder = "N"), n = 300)
  r2 <- quietly(run_whatif(p2$config, verbose = FALSE))
  j <- jsonlite::fromJSON(r2$files$island, simplifyVector = FALSE)$variants$weighted
  expect_null(j$profile)
  expect_null(j$safe$profile)
})

test_that("symptom effects are reported and never enter the model", {
  expect_length(res$payload$variants$weighted$model$symptoms, 1)
  expect_false("called" %in% vapply(res$model$spec$levers, `[[`, "", "key"))
})

test_that("the client-safe block never names a level it does not publish", {
  p3 <- test_project(n = 160, seed = 4)
  r3 <- quietly(run_whatif(p3$config, verbose = FALSE))
  j <- jsonlite::fromJSON(r3$files$island, simplifyVector = FALSE)$variants$weighted
  expect_false(any(c("refused", "hidden", "hidden_cells") %in% names(j$safe)))
  expect_null(j$safe$profile$pooled)
  refused <- r3$publish$refused$group
  expect_true(length(refused) > 0 || nrow(r3$publish$hidden) > 0)
  published <- unique(unlist(lapply(j$safe$groups, function(g) unlist(g$def))))
  safe_text <- jsonlite::toJSON(j$safe, auto_unbox = TRUE)
  small_levels <- sub("^[^:]+: ", "", refused[grepl("under", r3$publish$refused$why)])
  for (lv in setdiff(small_levels, c(published, unlist(lapply(j$safe$profile$keys, function(k) unlist(k$levels)))))) {
    expect_false(grepl(paste0('"', lv, '"'), safe_text, fixed = TRUE), info = lv)
  }
  expect_true("Privacy" %in% readxl::excel_sheets(r3$files$excel))
})

test_that("a weight column gives both versions; the unweighted one equals a run with no weights", {
  top <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)
  expect_setequal(names(top$variants), c("unweighted", "weighted"))
  expect_equal(top$meta$weight_variable, "W")
  expect_true(top$variants$weighted$meta$weighted)
  expect_false(top$variants$unweighted$meta$weighted)
  expect_equal(top$variants$weighted$meta$weight_variable, "W")
  bw <- unlist(top$variants$weighted$model$fits[[1]]$b)
  bu <- unlist(top$variants$unweighted$model$fits[[1]]$b)
  expect_gt(max(abs(bw - bu)), 1e-3)
  p0 <- test_project(config = list(weight_variable = ""))
  r0 <- quietly(run_whatif(p0$config, verbose = FALSE))
  t0 <- jsonlite::fromJSON(r0$files$island, simplifyVector = FALSE)
  expect_equal(names(t0$variants), "unweighted")
  expect_null(t0$meta$weight_variable)
  expect_equal(unlist(t0$variants$unweighted$model$fits[[1]]$b), bu, tolerance = 1e-9)
  expect_true("Effort_unweighted" %in% readxl::excel_sheets(res$files$excel))
  expect_false("Effort_unweighted" %in% readxl::excel_sheets(r0$files$excel))
})

# ==============================================================================
# The client-safe leaks found by the independent review of 24 Sep 2026
# (docs/v2_lift/REVIEW_WHATIF_DISCLOSURE_2026_09_24.md). Each attack below is
# written from the published numbers alone, the way a reader would work.
# ==============================================================================

if (!exists("release_audit_whatif", mode = "function")) {
  source(file.path(dirname(dirname(normalizePath(file.path(testthat::test_path(), "..", "..")))),
                   "modules", "shared", "lib", "turas_release_audit.R"))
}

# The review's proj1: n = 300, seed 11, then A1's don't-knows cut to one and
# the detractors cut to two.
review_project <- function() {
  p <- test_project(n = 300, seed = 11)
  d <- utils::read.csv(file.path(p$dir, "data.csv"), stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  dk <- which(d$A1 == "DK")
  d$A1[dk[-1]] <- "Good"
  det <- which(d$Status == "Complete" & d$NPS <= 6)
  d$NPS[det[-(1:2)]] <- 8
  utils::write.csv(d, file.path(p$dir, "data.csv"), row.names = FALSE, na = "")
  p
}
rp <- review_project()
rres <- quietly(run_whatif(rp$config, verbose = FALSE))
rvar <- jsonlite::fromJSON(rres$files$island, simplifyVector = FALSE)$variants$unweighted

# The cut the tabs build makes for a client-safe report (.read_whatif_contribution).
safe_cut <- function(v) {
  meta <- v$meta
  for (nm in names(v$safe$meta)) meta[[nm]] <- v$safe$meta[[nm]]
  meta$mode <- "safe"; meta$id_variable <- NULL
  safe <- v$safe; model <- safe$model; safe$model <- NULL; safe$meta <- NULL
  list(meta = meta, model = model, safe = safe)
}
in_span <- function(cols, target) {
  q <- qr(cols * 1, tol = 1e-10)
  max(abs(qr.resid(q, target * 1))) < 1e-8
}
nested_pairs <- function(members) {
  m <- members * 1; n <- colSums(m); ov <- crossprod(m)
  hit <- which(sweep(ov, 2, n, `==`) & outer(n, n, `>`), arr.ind = TRUE)
  data.frame(outer = hit[, 1], inner = hit[, 2])
}
small <- function(x, k) !is.na(x) & x > 0 & x < k

test_that("the review's project has the planted small counts, so the attacks below have something to find", {
  expect_false(is_refusal(rres))
  expect_equal(unlist(rvar$meta$n_by_outcome)[1], 2)
  expect_equal(rvar$model$levers[[which(vapply(rvar$model$levers, `[[`, "", "key") == "admin")]]$missing, 1)
})

test_that("no hidden need count can be rebuilt from the published ones, and no shown pair differs by a small one", {
  k <- rvar$safe$min_group
  keys <- vapply(rvar$model$levers, `[[`, "", "key")
  members <- rres$publish$members
  ids <- colnames(members)
  gid <- vapply(rvar$safe$groups, `[[`, "", "id")
  expect_setequal(gid, ids)
  need_shown <- t(vapply(rvar$safe$groups, function(g) vapply(g$need, function(v) !is.null(v), logical(1)), logical(length(keys))))
  rownames(need_shown) <- gid
  need_shown <- need_shown[ids, , drop = FALSE]
  pairs <- nested_pairs(members)
  rebuilt <- 0L; pair_leaks <- 0L; hidden <- 0L
  for (j in seq_along(keys)) {
    lv <- rres$model$spec$levers[[which(vapply(rres$model$spec$levers, `[[`, "", "key") == keys[j])]]
    need <- whatif_need_mask(lv)
    shown <- which(need_shown[, j])
    cols <- cbind(members, members[, shown, drop = FALSE] & need)
    for (h in which(!need_shown[, j])) {
      hidden <- hidden + 1L
      cnt <- sum(members[, h] & need)
      if (small(cnt, k) && in_span(cols, members[, h] & need)) rebuilt <- rebuilt + 1L
      if (small(sum(members[, h]) - cnt, k) && in_span(cols, members[, h] & !need)) rebuilt <- rebuilt + 1L
    }
    for (pr in seq_len(nrow(pairs))) {
      o <- pairs$outer[pr]; i <- pairs$inner[pr]
      if (!(need_shown[o, j] && need_shown[i, j])) next
      d_need <- sum(members[, o] & need) - sum(members[, i] & need)
      d_not <- sum(members[, o] & !need) - sum(members[, i] & !need)
      if (small(d_need, k) || small(d_not, k)) pair_leaks <- pair_leaks + 1L
    }
  }
  cat(sprintf("\n[whatif] need attack: %d hidden counts, %d rebuilt, %d shown nested pairs leak\n", hidden, rebuilt, pair_leaks))
  expect_gte(hidden, 1L)
  expect_equal(rebuilt, 0L)
  expect_equal(pair_leaks, 0L)
})

test_that("no published effect rests on fewer than the minimum, alone or against a nested group", {
  k <- rvar$safe$min_group
  keys <- vapply(rvar$model$levers, `[[`, "", "key")
  moves <- unlist(rvar$model$moves)
  members <- rres$publish$members
  ids <- colnames(members)
  gid <- vapply(rvar$safe$groups, `[[`, "", "id")
  groups <- rvar$safe$groups[match(ids, gid)]
  pairs <- nested_pairs(members)
  shown_total <- 0L; thin <- 0L; pair_thin <- 0L; hidden <- 0L
  for (j in seq_along(keys)) for (mv in moves) {
    dx <- rres$model$deltas[[keys[j]]][[mv]]
    if (is.null(dx)) next
    moved <- dx != 0
    est <- vapply(groups, function(g) { v <- g$est[[j]][[match(mv, moves)]]; if (is.null(v)) NA_real_ else as.numeric(v) }, 0)
    shown <- !is.na(est)
    shown_total <- shown_total + sum(shown); hidden <- hidden + sum(!shown)
    movers <- colSums(members & moved)
    thin <- thin + sum(shown & small(movers, k))
    for (pr in seq_len(nrow(pairs))) {
      o <- pairs$outer[pr]; i <- pairs$inner[pr]
      if (shown[o] && shown[i] && small(movers[o] - movers[i], k)) pair_thin <- pair_thin + 1L
    }
  }
  # Bundles: the union of their moves.
  bundles <- rvar$model$bundles
  for (b in seq_along(bundles)) {
    moved <- rep(FALSE, nrow(members))
    for (key in names(bundles[[b]]$moves)) moved <- moved | rres$model$deltas[[key]][[bundles[[b]]$moves[[key]]]] != 0
    est <- vapply(groups, function(g) { v <- g$bundles[[b]][[1]]; if (is.null(v)) NA_real_ else as.numeric(v) }, 0)
    shown <- !is.na(est)
    shown_total <- shown_total + sum(shown); hidden <- hidden + sum(!shown)
    movers <- colSums(members & moved)
    thin <- thin + sum(shown & small(movers, k))
    for (pr in seq_len(nrow(pairs))) {
      o <- pairs$outer[pr]; i <- pairs$inner[pr]
      if (shown[o] && shown[i] && small(movers[o] - movers[i], k)) pair_thin <- pair_thin + 1L
    }
  }
  cat(sprintf("\n[whatif] effect attack: %d effects shown, %d hidden; %d rest on 1 to %d movers, %d nested pairs differ by that few\n",
              shown_total, hidden, thin, k - 1, pair_thin))
  expect_gte(shown_total, 500L)
  expect_equal(thin, 0L)
  expect_equal(pair_thin, 0L)
})

test_that("the effects a hidden need count would explain are hidden with it, and the suppression is the same in both versions", {
  w <- jsonlite::fromJSON(rres$files$island, simplifyVector = FALSE)$variants$weighted
  for (i in seq_along(rvar$safe$groups)) {
    gu <- rvar$safe$groups[[i]]; gw <- w$safe$groups[[i]]
    expect_identical(vapply(gu$need, is.null, logical(1)), vapply(gw$need, is.null, logical(1)))
    for (j in seq_along(gu$est)) {
      expect_identical(vapply(gu$est[[j]], is.null, logical(1)), vapply(gw$est[[j]], is.null, logical(1)))
      expect_identical(vapply(gu$est[[j]], is.null, logical(1)), vapply(gu$lo[[j]], is.null, logical(1)))
      expect_identical(vapply(gu$est[[j]], is.null, logical(1)), vapply(gu$hi[[j]], is.null, logical(1)))
    }
    for (b in seq_along(gu$bundles)) {
      expect_identical(is.null(gu$bundles[[b]][[1]]), is.null(gw$bundles[[b]][[1]]))
    }
  }
  a <- rvar$safe$audit
  expect_true(isTRUE(a$need_checked))
  expect_true(isTRUE(a$effects_checked))
  expect_equal(a$recoverable_failures, 0)
})

test_that("the client-safe cut carries no whole-sample count under the minimum", {
  k <- rvar$safe$min_group
  cut <- safe_cut(rvar)
  expect_null(cut$meta$n_by_outcome)
  expect_true(all(vapply(cut$model$levers, function(lv) is.null(lv$missing), logical(1))))
  expect_false(any(grepl("Don't know", unlist(cut$model$notes), fixed = TRUE)))
  txt <- c(unlist(cut$meta$warnings), unlist(cut$model$notes))
  nums <- as.numeric(unlist(regmatches(txt, gregexpr("[0-9]+", txt))))
  expect_false(any(nums >= 1 & nums < k), info = paste(txt, collapse = " | "))
  expect_false(any(grepl("Only [0-9]+ respondents", unlist(cut$meta$warnings))))
  # The open part keeps all of it, for the analyst.
  expect_equal(unlist(rvar$meta$n_by_outcome)[1], 2)
  expect_true(any(grepl("Only 2 respondents are Detractor", unlist(rvar$meta$warnings))))
  # The shipped audit is pass or fail, not a count of small cells.
  expect_false(any(c("candidates_checked", "nesting_hidden", "recovery_hidden", "small_atoms", "rounds") %in% names(cut$safe$audit)))
  expect_length(release_audit_whatif(as.character(jsonlite::toJSON(cut, auto_unbox = TRUE, null = "null", na = "null", digits = NA)))$violations, 0)
})

test_that("a small study passes the release audit when clean, and a pooled level is not named by the shipped rules", {
  # The review's proj2: n = 100, seed 7, the default 100 refits, Masters cut
  # to three respondents. Before the fix the audit failed it on the refit
  # lists (101 long against 100 respondents) and the rules named Masters.
  p <- test_project(n = 100, seed = 7, config = list(n_boot = 100))
  d <- utils::read.csv(file.path(p$dir, "data.csv"), stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  ms <- which(d$YEAR == "Masters")
  expect_gte(length(ms), 4)
  d$YEAR[ms[-(1:3)]] <- "Honours"
  utils::write.csv(d, file.path(p$dir, "data.csv"), row.names = FALSE, na = "")
  r <- quietly(run_whatif(p$config, verbose = FALSE))
  expect_false(is_refusal(r))
  v <- jsonlite::fromJSON(r$files$island, simplifyVector = FALSE)$variants$unweighted
  expect_equal(v$meta$n, 100)
  expect_length(v$model$fits, 101)
  cut <- safe_cut(v)
  a <- release_audit_whatif(as.character(jsonlite::toJSON(cut, auto_unbox = TRUE, null = "null", na = "null", digits = NA)))
  expect_length(a$violations, 0)
  offered <- unlist(lapply(cut$safe$profile$keys, function(kk) unlist(kk$levels)))
  expect_false("Masters" %in% offered)
  named <- unlist(lapply(cut$safe$profile$rules, unlist))
  expect_false("Masters" %in% named)
})

test_that("the open part flags don't-know respondents, and the need count leaves them out", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)$variants$weighted
  dk <- unlist(j$open$dk$admin)
  expect_length(dk, 500)
  expect_equal(sum(dk), 20)
  admin <- res$model$spec$levers[[2]]
  expect_equal(admin$key, "admin")
  expect_equal(which(dk == 1), which(admin$dk))
  expect_false(any(unlist(j$open$dk$teach) == 1))
  # The whole-sample need count is those below the target with a rating of their own.
  keys <- vapply(j$model$levers, `[[`, "", "key")
  all_g <- Filter(function(g) g$id == "all", j$safe$groups)[[1]]
  need_admin <- unlist(all_g$need)[keys == "admin"]
  if (!is.null(need_admin) && !is.na(need_admin)) {
    expect_equal(need_admin, sum(admin$values < admin$target & !admin$dk))
  }
  lv_all <- res$variants[[res$primary]]$safe_results$all$levers
  expect_equal(lv_all$need[lv_all$key == "admin"][1], sum(admin$values < admin$target & !admin$dk))
})

test_that("the halo check ships in both model blocks, and the workbook carries it with the relative importance", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)$variants$weighted
  keys <- vapply(j$model$levers, `[[`, "", "key")
  expect_equal(names(j$model$halo), keys)
  expect_equal(j$model$halo_ratio, 1 / 3)
  h <- j$model$halo$teach
  expect_true(all(c("single", "partial", "flag") %in% names(h)))
  expect_true(is.logical(h$flag))
  expect_equal(names(j$safe$model$halo), keys)
  expect_equal(j$safe$model$halo$teach$single, h$single)
  eff <- openxlsx::read.xlsx(res$files$excel, sheet = "Effort", skipEmptyRows = FALSE)
  expect_true(all(c("Fixed_alone", "Halo_ratio", "Halo") %in% names(eff)))
  expect_false(any(is.na(eff$Fixed_alone)))
  ri <- openxlsx::read.xlsx(res$files$excel, sheet = "Relative_importance", skipEmptyRows = FALSE)
  expect_equal(nrow(ri), length(keys))
  expect_equal(sum(ri$LMG_share_of_R2), 100, tolerance = 0.5)
})
