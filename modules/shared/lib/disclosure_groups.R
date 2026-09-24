# ==============================================================================
# SHARED DISCLOSURE: PUBLISHABLE GROUPS
# ==============================================================================
#
# Which groups of respondents may a client-safe file publish results for, when
# the client knows who is in the population? Three rules, applied together:
#
#   1. Minimum group. No published group, and no cell of a published crossing,
#      has fewer than k respondents (counted on respondents, never weights).
#   2. Secondary suppression. In a two-way crossing, hiding the small cells is
#      not enough: a row or column total minus the cells still shown gives the
#      hidden total back. So the smallest shown cells in that row or column are
#      hidden too, until every row and column hides either nothing or at least
#      k respondents.
#   3. Nesting check. Two published groups where one contains the other and
#      they differ by fewer than k respondents give that difference away by
#      subtraction (for example "Online Access, Honours year" against "Online
#      Access, BSocSci Honours"). The inner group is hidden.
#   4. Recoverability check. Rules 2 and 3 look at one table or one pair at a
#      time; subtraction can chain across them (the whole sample minus every
#      other level gives a small level back; a row total minus its shown cells
#      gives a hidden cell, which then solves a column). A group can be worked
#      out exactly when its membership is a linear combination of the published
#      groups' memberships, so every small candidate (each single level and
#      each cell of every two-way crossing of the variables, declared or not,
#      with 1 to k-1 respondents) is tested against the published groups by
#      least squares. When one is recoverable, the smallest published group in
#      its combination is hidden, and everything repeats until none is. This is
#      a practical bound, not a proof: a small set of any other shape (a
#      three-way cell, a union of cells from different rows) is not tested.
#
# Rule 4 was added after an independent review on 24 Sep 2026: with rules 1
# to 3 only, 117 of 150 random studies leaked a count of 1 to 9.
#
# First built for the What if simulator (modules/whatif), in the shared layer
# so the tabs cube can adopt it: the same differencing problem is the known
# cube margin hole (memory reference_cube_margin_differencing). Ported from
# prototypes/nps-simulator/whatif_engine.py; the SACAP 2025 group counts it
# produced are the test targets.
#
# Pure functions: sourcing this file has no side effects (three tabs tests
# source every file in modules/shared/lib).
#
# ==============================================================================

#' Distinct Levels in a Fixed, Locale-Free Order
#'
#' Byte order, so a table's row order (and so which cell secondary suppression
#' picks on a tie) is the same on every machine.
#'
#' @param x Character vector
#' @return Sorted distinct values
#' @export
disclosure_levels <- function(x) {
  sort(unique(as.character(x)), method = "radix")
}


#' Secondary Suppression for One Two-Way Table
#'
#' Starts from the cells in \code{seed} (by default every cell with 1 to k-1
#' respondents), then, for every row and column whose hidden total is between
#' 1 and k-1, hides the smallest non-empty shown cell in it, repeating until
#' no row or column is left in that state.
#'
#' @param tab Integer matrix of counts with dimnames
#' @param k Minimum group
#' @param seed Optional logical matrix of cells that must be hidden
#' @return Logical matrix, TRUE where a cell is hidden
#' @export
disclosure_secondary_suppression <- function(tab, k, seed = NULL) {
  hide <- if (is.null(seed)) (tab > 0 & tab < k) else seed
  changed <- TRUE
  while (changed) {
    changed <- FALSE
    for (axis in 1:2) {
      lines <- if (axis == 1) seq_len(nrow(tab)) else seq_len(ncol(tab))
      for (ln in lines) {
        repeat {
          row <- if (axis == 1) tab[ln, ] else tab[, ln]
          h <- if (axis == 1) hide[ln, ] else hide[, ln]
          tot <- sum(row[h])
          if (!(tot > 0 && tot < k)) break
          cand <- which(!h & row > 0)
          if (!length(cand)) break
          pick <- cand[which.min(row[cand])]
          if (axis == 1) hide[ln, pick] <- TRUE else hide[pick, ln] <- TRUE
          changed <- TRUE
        }
      }
    }
  }
  hide
}


#' Rows and Columns Whose Hidden Total Could Still Be Worked Out
#'
#' A row or column gives its hidden cells away when they total 1 to k-1 and
#' at least one non-empty cell in it is still shown: its margin minus the
#' shown cells is the hidden total. A row whose every non-empty cell is hidden
#' gives nothing away, because its total is the size of its own single group,
#' which is then under k and never published either.
#'
#' @param tab Count matrix
#' @param hide Logical matrix from disclosure_secondary_suppression()
#' @param k Minimum group
#' @return Integer count of rows plus columns that could be worked out
#' @export
disclosure_line_failures <- function(tab, hide, k) {
  fails <- function(counts, hidden) {
    tot <- sum(counts[hidden])
    tot > 0 && tot < k && any(counts > 0 & !hidden)
  }
  sum(vapply(seq_len(nrow(tab)), function(i) fails(tab[i, ], hide[i, ]), logical(1))) +
    sum(vapply(seq_len(ncol(tab)), function(j) fails(tab[, j], hide[, j]), logical(1)))
}


#' Small Groups a Reader Might Try to Recover
#'
#' Every single level and every cell of every two-way crossing of the context
#' variables (declared or not) with 1 to k-1 respondents.
#'
#' @param context Named list of list(label, values)
#' @param k Minimum group
#' @return List of candidate definitions list(id, def = named character, n)
#' @export
disclosure_candidates <- function(context, k) {
  out <- list()
  keys <- names(context)
  for (key in keys) {
    tab <- table(context[[key]]$values)
    for (lev in names(tab)[tab > 0 & tab < k]) {
      out[[length(out) + 1]] <- list(id = paste0(key, "=", lev), def = stats::setNames(lev, key), n = tab[[lev]])
    }
  }
  if (length(keys) > 1) for (i in seq_len(length(keys) - 1)) for (j in (i + 1):length(keys)) {
    tab <- table(context[[keys[i]]]$values, context[[keys[j]]]$values)
    hit <- which(tab > 0 & tab < k, arr.ind = TRUE)
    for (r in seq_len(nrow(hit))) {
      a <- rownames(tab)[hit[r, 1]]
      b <- colnames(tab)[hit[r, 2]]
      out[[length(out) + 1]] <- list(id = paste0(keys[i], "=", a, "|", keys[j], "=", b),
                                     def = stats::setNames(c(a, b), keys[c(i, j)]), n = tab[a, b])
    }
  }
  out
}


#' Which Small Candidates Can Be Worked Out From the Published Groups
#'
#' Works on atoms (the distinct combinations of every context variable), where
#' every group is a union of atoms. A candidate is recoverable when its atom
#' indicator lies in the span of the published groups' indicators (least
#' squares residual under 1e-8).
#'
#' @param context Named list of list(label, values)
#' @param published List of named character definitions (empty = everyone)
#' @param candidates From disclosure_candidates()
#' @return List: recoverable (logical per candidate), coef (matrix, published by
#'   recoverable candidates; the combination that recovers each)
#' @export
disclosure_recoverable <- function(context, published, candidates) {
  if (!length(candidates)) return(list(recoverable = logical(0), coef = NULL))
  keys <- names(context)
  combo <- do.call(paste, c(lapply(keys, function(k) context[[k]]$values), sep = "\r"))
  atoms <- unique(combo)
  parts <- do.call(rbind, strsplit(atoms, "\r", fixed = TRUE))
  if (!is.matrix(parts)) parts <- matrix(parts, ncol = length(keys))
  colnames(parts) <- keys
  indicator <- function(def) {
    m <- rep(TRUE, length(atoms))
    for (k in names(def)) m <- m & parts[, k] == def[[k]]
    as.numeric(m)
  }
  A <- vapply(published, indicator, numeric(length(atoms)))
  if (!is.matrix(A)) A <- matrix(A, ncol = length(published))
  Tm <- vapply(candidates, function(cn) indicator(cn$def), numeric(length(atoms)))
  if (!is.matrix(Tm)) Tm <- matrix(Tm, ncol = length(candidates))
  q <- qr(A, tol = 1e-10)
  res <- qr.resid(q, Tm)
  if (!is.matrix(res)) res <- matrix(res, ncol = length(candidates))
  rec <- apply(abs(res), 2, max) < 1e-8
  coef <- NULL
  if (any(rec)) {
    coef <- qr.coef(q, Tm[, rec, drop = FALSE])
    if (!is.matrix(coef)) coef <- matrix(coef, ncol = sum(rec))
    coef[is.na(coef)] <- 0
  }
  list(recoverable = rec, coef = coef)
}


#' Pairs of Groups That Give Away a Small Difference
#'
#' @param members Logical matrix, respondents by groups
#' @param k Minimum group
#' @return Data frame outer, inner, diff (column indices of members)
#' @export
disclosure_differencing_pairs <- function(members, k) {
  m <- members * 1
  n <- colSums(m)
  overlap <- crossprod(m)
  contains <- sweep(overlap, 2, n, `==`)          # [a, b]: group b lies inside group a
  diff <- outer(n, n, `-`)
  hit <- which(contains & diff > 0 & diff < k, arr.ind = TRUE)
  data.frame(outer = hit[, 1], inner = hit[, 2], diff = diff[hit], stringsAsFactors = FALSE)
}


#' Decide Which Groups a Client-Safe File May Publish
#'
#' Groups are the whole sample, every level of every context variable, and
#' every cell of each declared two-way crossing, subject to the three rules in
#' the file header.
#'
#' @param context Named list; each element list(label, values) with one value
#'   per respondent
#' @param crossings List of length-2 character vectors naming context keys
#' @param k Minimum group, counted on respondents
#' @param all_label Label for the whole sample (for example "All students")
#' @return List with
#'   \item{groups}{data frame id, family, label, n, key1, level1, key2, level2}
#'   \item{members}{logical matrix, respondents by published groups}
#'   \item{hidden}{data frame family, key1, level1, key2, level2 (crossing cells hidden)}
#'   \item{refused}{data frame group, why (single levels not published)}
#'   \item{crossings}{data frame family, cells, shown, small, protecting}
#'   \item{audit}{list line_failures (diagnostic only), differencing_failures,
#'     recoverable_failures, candidates_checked, nesting_hidden, recovery_hidden,
#'     rounds, k}
#' @export
disclosure_publish_groups <- function(context, crossings, k, all_label = "All respondents") {
  n <- length(context[[1]]$values)
  lower_first <- function(s) paste0(tolower(substr(s, 1, 1)), substr(s, 2, nchar(s)))

  singles_all <- list(list(id = "all", family = all_label, label = all_label,
                           key1 = NA_character_, level1 = NA_character_,
                           key2 = NA_character_, level2 = NA_character_))
  refused <- list()
  for (key in names(context)) {
    v <- context[[key]]$values
    tab <- table(v)
    for (lev in names(sort(tab, decreasing = TRUE))) {
      if (tab[[lev]] >= k) {
        singles_all[[length(singles_all) + 1]] <- list(
          id = paste0(key, "=", lev), family = context[[key]]$label, label = lev,
          key1 = key, level1 = lev, key2 = NA_character_, level2 = NA_character_)
      } else {
        refused[[length(refused) + 1]] <- data.frame(
          group = paste0(context[[key]]$label, ": ", lev), why = paste("under", k), stringsAsFactors = FALSE)
      }
    }
  }

  build_crossings <- function(forced) {
    pub <- list(); hid <- list(); summ <- list(); fails <- 0L
    for (cr in crossings) {
      k1 <- cr[1]; k2 <- cr[2]
      v1 <- context[[k1]]$values; v2 <- context[[k2]]$values
      tab <- table(factor(v1, disclosure_levels(v1)), factor(v2, disclosure_levels(v2)))
      tab <- matrix(as.integer(tab), nrow(tab), dimnames = dimnames(tab))
      seed <- tab > 0 & tab < k
      for (a in rownames(tab)) for (b in colnames(tab)) {
        if (paste0(k1, "=", a, "|", k2, "=", b) %in% forced) seed[a, b] <- TRUE
      }
      hide <- disclosure_secondary_suppression(tab, k, seed)
      fails <- fails + disclosure_line_failures(tab, hide, k)
      fam <- paste(context[[k1]]$label, "by", lower_first(context[[k2]]$label))
      n_cells <- 0L
      for (a in rownames(tab)) for (b in colnames(tab)) {
        if (tab[a, b] == 0) next
        n_cells <- n_cells + 1L
        if (hide[a, b]) {
          hid[[length(hid) + 1]] <- data.frame(family = fam, key1 = k1, level1 = a, key2 = k2, level2 = b,
                                               stringsAsFactors = FALSE)
        } else {
          pub[[length(pub) + 1]] <- list(id = paste0(k1, "=", a, "|", k2, "=", b), family = fam,
                                         label = paste0(a, ", ", b), key1 = k1, level1 = a,
                                         key2 = k2, level2 = b)
        }
      }
      small <- sum(tab > 0 & tab < k)
      summ[[length(summ) + 1]] <- data.frame(family = fam, cells = n_cells, shown = n_cells - sum(hide),
                                             small = small, protecting = sum(hide) - small,
                                             stringsAsFactors = FALSE)
    }
    list(pub = pub, hid = hid, summ = summ, fails = fails)
  }

  member_of <- function(g) {
    m <- rep(TRUE, n)
    if (!is.na(g$key1)) m <- m & context[[g$key1]]$values == g$level1
    if (!is.na(g$key2)) m <- m & context[[g$key2]]$values == g$level2
    m
  }

  def_of <- function(g) {
    d <- character(0)
    if (!is.na(g$key1)) d[g$key1] <- g$level1
    if (!is.na(g$key2)) d[g$key2] <- g$level2
    d
  }
  candidates <- disclosure_candidates(context, k)
  stuck <- function(problem) {
    turas_refuse(
      code = "CALC_DISCLOSURE_RECOVERABLE", title = "A small group could still be worked out",
      problem = problem,
      why_it_matters = "A client could recover a group smaller than the minimum from the published ones.",
      how_to_fix = c("Declare fewer crossings, or raise the minimum group.", "Report this case."),
      module = "DISCLOSURE")
  }
  forced <- character(0)
  by_nesting <- character(0)
  by_recovery <- character(0)
  rounds <- 0L
  repeat {
    rounds <- rounds + 1L
    if (rounds > 2000L) stuck("The groups to publish were still changing after 2000 rounds of checks.")
    singles <- Filter(function(g) !g$id %in% forced, singles_all)
    cx <- build_crossings(forced)
    published <- c(singles, cx$pub)
    ids <- vapply(published, `[[`, "", "id")
    members <- vapply(published, member_of, logical(n))
    if (!is.matrix(members)) members <- matrix(members, nrow = n)
    sizes <- colSums(members)
    pairs <- disclosure_differencing_pairs(members, k)
    new <- setdiff(setdiff(unique(ids[pairs$inner]), "all"), forced)
    if (length(new)) {
      by_nesting <- c(by_nesting, new)
      forced <- c(forced, new)
      next
    }
    rc <- disclosure_recoverable(context, lapply(published, def_of), candidates)
    if (!any(rc$recoverable)) break
    for (j in seq_len(ncol(rc$coef))) {
      used <- which(abs(rc$coef[, j]) > 1e-8 & ids != "all" & !ids %in% forced)
      if (length(used)) new <- c(new, ids[used[which.min(sizes[used])]])
    }
    new <- setdiff(unique(new), forced)
    if (!length(new)) {
      stuck(sprintf("%d group(s) under %d respondents can be worked out and nothing more can be hidden.",
                    sum(rc$recoverable), k))
    }
    by_recovery <- c(by_recovery, new)
    forced <- c(forced, new)
  }
  for (g in singles_all) {
    if (g$id %in% forced) {
      refused[[length(refused) + 1]] <- data.frame(
        group = paste0(g$family, ": ", g$label),
        why = "hidden so another group cannot be worked out by subtraction", stringsAsFactors = FALSE)
    }
  }
  groups <- do.call(rbind, lapply(published, function(g) as.data.frame(g, stringsAsFactors = FALSE)))
  groups$n <- as.integer(colSums(members))
  colnames(members) <- groups$id
  empty_hidden <- data.frame(family = character(0), key1 = character(0), level1 = character(0),
                             key2 = character(0), level2 = character(0), stringsAsFactors = FALSE)
  list(
    groups = groups,
    members = members,
    hidden = if (length(cx$hid)) do.call(rbind, cx$hid) else empty_hidden,
    refused = if (length(refused)) do.call(rbind, refused) else data.frame(group = character(0), why = character(0)),
    crossings = if (length(cx$summ)) do.call(rbind, cx$summ) else data.frame(),
    audit = list(line_failures = cx$fails, differencing_failures = nrow(pairs),
                 recoverable_failures = 0L, candidates_checked = length(candidates),
                 nesting_hidden = length(by_nesting), recovery_hidden = length(by_recovery),
                 rounds = rounds, k = k)
  )
}


#' Audit a Set of Published Groups
#'
#' Independent re-check of what disclosure_publish_groups() promises, for use
#' before a file is released: every group at or above k, no pair of groups that
#' differ by 1 to k-1 respondents with one inside the other, and, when the
#' context is given, no small candidate recoverable from the groups.
#'
#' @param members Logical matrix, respondents by groups
#' @param k Minimum group
#' @param context Optional named context list, for the recoverability check
#' @param defs Optional list of named character definitions, one per column of
#'   members (needed with context)
#' @return List ok (logical), small (group ids under k), pairs (differencing
#'   pairs), recoverable (candidate ids that can be worked out)
#' @export
disclosure_audit_groups <- function(members, k, context = NULL, defs = NULL) {
  n <- colSums(members)
  pairs <- disclosure_differencing_pairs(members, k)
  recoverable <- character(0)
  if (!is.null(context) && !is.null(defs)) {
    cand <- disclosure_candidates(context, k)
    rc <- disclosure_recoverable(context, defs, cand)
    recoverable <- vapply(cand, `[[`, "", "id")[rc$recoverable]
  }
  list(ok = all(n >= k) && nrow(pairs) == 0 && !length(recoverable),
       small = colnames(members)[n < k],
       pairs = pairs,
       recoverable = recoverable)
}
