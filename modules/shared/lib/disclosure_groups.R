# ==============================================================================
# SHARED DISCLOSURE: PUBLISHABLE GROUPS
# ==============================================================================
#
# Which groups of respondents may a client-safe file publish results for, when
# the client knows who is in the population? Four rules, applied together:
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
#   4. Recoverability check, exact. Every published number is a sum over the
#      respondents in some set, and a reader can recover the sum over any set
#      whose indicator is a linear combination of the published sets'
#      indicators. Work on atoms (the distinct combinations of the context
#      variables): every published group is a union of atoms, so any
#      recoverable set of 1 to k-1 respondents is a union of at most k-1 atoms
#      that each have under k. disclosure_small_recoverable() finds every such
#      set exactly (see its header). When one exists, the smallest published
#      group in its combination is hidden, and everything repeats until none
#      is. Past its work cap the engine refuses rather than passing silently.
#
# Rule 4 was added after an independent review on 24 Sep 2026: with rules 1
# to 3 only, 117 of 150 random studies leaked a count of 1 to 9. Its first
# version tested single levels and two-way cells only; a second review the
# same day recovered unions of small cells across rows and columns (23 of 150
# random studies) and three-way cells through nested levels (4 of 100), so
# the check was made exact (docs/v2_lift/REVIEW_WHATIF_DISCLOSURE_2026_09_24.md).
#
# The same engine serves the What if module's need counts and effects, where
# the atoms are refined by "needs the fix" or "changed by this move"
# (modules/whatif/R/11_island.R, whatif_safe_suppression).
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


#' Atoms: the Distinct Combinations of the Context Variables
#'
#' Every group a client-safe file publishes is a union of atoms, so the
#' recoverability check works on them. Optional yes/no attributes (needs the
#' fix, changed by a move) refine the atoms further.
#'
#' @param context Named list of list(label, values), one value per respondent
#' @param attributes Optional named list of logical vectors, one per respondent
#' @return List: index (atom of each respondent), n (respondents per atom), id
#'   (a readable "key=level|key=level" per atom), parts (character matrix,
#'   atoms by context keys), attributes (logical matrix, atoms by attributes)
#' @export
disclosure_atoms <- function(context, attributes = NULL) {
  keys <- names(context)
  cols <- lapply(keys, function(kk) as.character(context[[kk]]$values))
  n <- length(cols[[1]])
  if (is.null(attributes)) attributes <- list()
  attr_cols <- lapply(attributes, function(a) as.character(as.integer(as.logical(a))))
  combo <- do.call(paste, c(cols, attr_cols, sep = "\r"))
  atoms <- unique(combo)
  index <- match(combo, atoms)
  parts <- do.call(rbind, strsplit(atoms, "\r", fixed = TRUE))
  if (!is.matrix(parts)) parts <- matrix(parts, ncol = length(keys) + length(attr_cols))
  ctx_parts <- parts[, seq_along(keys), drop = FALSE]
  colnames(ctx_parts) <- keys
  attrs <- parts[, length(keys) + seq_along(attr_cols), drop = FALSE] == "1"
  colnames(attrs) <- names(attributes)
  id <- apply(ctx_parts, 1, function(r) paste0(keys, "=", r, collapse = "|"))
  if (length(attr_cols)) {
    id <- paste0(id, "|", apply(attrs, 1, function(r) paste0(colnames(attrs), "=", ifelse(r, "yes", "no"), collapse = "|")))
  }
  list(index = index, n = as.integer(tabulate(index, length(atoms))), id = id, parts = ctx_parts, attributes = attrs)
}


#' Indicator Matrix of Published Sets Over Atoms
#'
#' @param atoms From disclosure_atoms()
#' @param masks List of logical vectors (one per respondent), each a set whose
#'   size a file publishes; every set must be a union of atoms
#' @return Numeric 0/1 matrix, atoms by sets
#' @export
disclosure_atom_sets <- function(atoms, masks) {
  A <- vapply(masks, function(m) as.numeric(tabulate(atoms$index[m], length(atoms$n)) > 0), numeric(length(atoms$n)))
  if (!is.matrix(A)) A <- matrix(A, nrow = length(atoms$n))
  A
}


#' Subsets of Small Classes, Counted Before Anything Is Enumerated
#' @keywords internal
.disclosure_count_subsets <- function(cnt, k, max_size) {
  tab <- matrix(0, max_size + 1, k)
  tab[1, 1] <- 1
  for (c in cnt) {
    if (c > k - 1) next
    for (s in max_size:1) for (t in (k - 1):c) tab[s + 1, t + 1] <- tab[s + 1, t + 1] + tab[s, t + 1 - c]
  }
  rowSums(tab)[-1]
}


#' Small Sets a Reader Could Work Out From Published Sums
#'
#' The exact recoverability engine. Every published number is a sum over the
#' respondents in some set (a group's membership, a group's members who need
#' a fix, a group's members a move changes). A reader can recover the sum
#' over any set whose atom indicator is a linear combination of the published
#' sets' indicators. Such a set is constant across atoms with identical rows
#' of A, so atoms are first merged into those classes; a recoverable set of 1
#' to k-1 respondents is then a union of at most k-1 classes that each have
#' under k. With N a basis of the left null space of A, a union of classes is
#' recoverable when its rows of N sum to zero: singles are zero rows, pairs are
#' rows that cancel, and larger unions are found by meeting in the middle on
#' hashed partial sums (projected to four random directions to keep the keys
#' short; every hit is then verified against the full rows). Only minimal sets
#' are returned.
#'
#' The search is counted before it is run. Past \code{max_work} subsets on
#' either side it refuses (CALC_DISCLOSURE_RECOVERABLE): a check that did not
#' finish must never read as a check that passed.
#'
#' @param atom_n Integer respondents per atom
#' @param A Numeric 0/1 matrix, atoms by published sets
#' @param k Minimum group
#' @param max_work Cap on the subsets enumerated on either side of the search
#' @return List with
#'   \item{sets}{list of recoverable sets, each list(atoms, n, coef): atom
#'     indices, respondents, and the combination of published sets (one
#'     coefficient per column of A) that recovers it}
#'   \item{classes, small_classes}{how many classes the atoms merged into, and
#'     how many of those are under k}
#'   \item{work}{subsets enumerated}
#'   \item{exact}{TRUE: the search covered every candidate}
#' @export
disclosure_small_recoverable <- function(atom_n, A, k, max_work = 500000) {
  atom_n <- as.integer(atom_n)
  m <- length(atom_n)
  if (!is.matrix(A)) A <- matrix(A, nrow = m)
  out <- list(sets = list(), classes = 0L, small_classes = 0L, work = 0L, exact = TRUE)
  if (m == 0 || ncol(A) == 0) return(out)

  key <- do.call(paste, c(as.data.frame(A), sep = ""))
  cls <- match(key, unique(key))
  C <- max(cls)
  n_c <- as.integer(rowsum(atom_n, cls)[, 1])
  Ac <- A[!duplicated(cls), , drop = FALSE]
  out$classes <- C
  small <- which(n_c > 0 & n_c < k)
  out$small_classes <- length(small)
  if (!length(small)) return(out)

  q <- qr(Ac, tol = 1e-10)
  N <- if (q$rank < C) qr.Q(q, complete = TRUE)[, (q$rank + 1):C, drop = FALSE] else matrix(0, C, 0)
  Ns <- N[small, , drop = FALSE]
  cnt <- n_c[small]
  ms <- length(small)
  zero_row <- if (ncol(Ns)) apply(abs(Ns), 1, max) < 1e-8 else rep(TRUE, ms)
  found <- lapply(which(zero_row), function(i) i)
  cand <- which(!zero_row)

  if (length(cand) >= 2 && k > 2) {
    h <- max(1L, (k - 1L) %/% 2L)
    hs <- k - 1L - h
    per_size <- .disclosure_count_subsets(cnt[cand], k, max(h, hs))
    side_p <- sum(per_size[seq_len(h)])
    side_q <- sum(per_size[seq_len(hs)])
    if (side_p > max_work || side_q > max_work) {
      turas_refuse(
        code = "CALC_DISCLOSURE_RECOVERABLE",
        title = "The disclosure check is too large to run exactly",
        problem = sprintf(paste0("%d small groups of respondents (under %d) could combine in %s ways, more than the ",
                                 "%s the check allows."),
                          length(cand), k, format(max(side_p, side_q), big.mark = ","), format(max_work, big.mark = ",")),
        why_it_matters = "Without an exact check a client-safe file could let a group smaller than the minimum be worked out.",
        how_to_fix = c("Declare fewer crossings or fewer filter variables, or raise the minimum group.",
                       "Report this case."),
        module = "DISCLOSURE")
    }
    nc <- length(cand)
    # Four random directions for the hash keys, drawn from a fixed seed with
    # the caller's random stream put back afterwards, so this stays a pure
    # function. A collision only costs a verification; a true zero sum can
    # never be missed.
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    saved_seed <- if (had_seed) get(".Random.seed", envir = globalenv(), inherits = FALSE) else NULL
    set.seed(20260924L)
    G <- matrix(stats::rnorm(ncol(Ns) * 4L), ncol(Ns), 4L)
    if (had_seed) assign(".Random.seed", saved_seed, envir = globalenv()) else rm(".Random.seed", envir = globalenv())
    V <- Ns[cand, , drop = FALSE] %*% G
    cc <- cnt[cand]
    levels <- list(list(idx = matrix(seq_len(nc), ncol = 1), proj = V, tot = cc))
    grow <- function(prev) {
      s <- ncol(prev$idx)
      last <- prev$idx[, s]
      idx <- list(); proj <- list(); tot <- list()
      for (L in sort(unique(last))) {
        rows <- which(last == L)
        js <- which(seq_len(nc) > L)
        if (!length(js)) next
        ri <- rep(rows, each = length(js)); jj <- rep(js, times = length(rows))
        t2 <- prev$tot[ri] + cc[jj]
        ok <- t2 <= k - 1
        if (!any(ok)) next
        ri <- ri[ok]; jj <- jj[ok]
        idx[[length(idx) + 1]] <- cbind(prev$idx[ri, , drop = FALSE], jj)
        proj[[length(proj) + 1]] <- prev$proj[ri, , drop = FALSE] + V[jj, , drop = FALSE]
        tot[[length(tot) + 1]] <- t2[ok]
      }
      if (!length(idx)) return(NULL)
      list(idx = do.call(rbind, idx), proj = do.call(rbind, proj), tot = unlist(tot))
    }
    for (s in seq_len(max(h, hs) - 1L)) {
      nxt <- grow(levels[[s]])
      if (is.null(nxt)) break
      levels[[s + 1L]] <- nxt
    }
    key_of <- function(P) do.call(paste, c(as.data.frame(round(P, 6)), sep = "|"))
    p_size <- integer(0); p_row <- integer(0); p_key <- character(0)
    for (s in seq_len(min(h, length(levels)))) {
      lv <- levels[[s]]
      p_size <- c(p_size, rep(s, nrow(lv$idx))); p_row <- c(p_row, seq_len(nrow(lv$idx)))
      p_key <- c(p_key, key_of(lv$proj))
    }
    out$work <- length(p_key)
    hash <- split(seq_along(p_key), p_key)
    seen <- character(0)
    exact_zero <- function(pos) max(abs(colSums(Ns[cand[pos], , drop = FALSE]))) < 1e-8
    for (s in seq_len(min(hs, length(levels)))) {
      lv <- levels[[s]]
      out$work <- out$work + nrow(lv$idx)
      hits <- hash[key_of(-lv$proj)]
      for (qi in which(!vapply(hits, is.null, logical(1)))) {
        Q <- lv$idx[qi, ]
        for (g in hits[[qi]]) {
          P <- levels[[p_size[g]]]$idx[p_row[g], ]
          if (any(P %in% Q)) next
          if (sum(cc[P]) + sum(cc[Q]) > k - 1) next
          pos <- sort(c(P, Q))
          sk <- paste(pos, collapse = ",")
          if (sk %in% seen) next
          if (!exact_zero(pos)) next
          seen <- c(seen, sk)
          found[[length(found) + 1]] <- cand[pos]
          if (length(found) >= 5000L) break
        }
      }
    }
  }
  if (!length(found)) return(out)
  found <- unique(lapply(found, sort))
  minimal <- vapply(seq_along(found), function(i) {
    !any(vapply(seq_along(found), function(j) j != i && length(found[[j]]) < length(found[[i]]) &&
                  all(found[[j]] %in% found[[i]]), logical(1)))
  }, logical(1))
  found <- found[minimal]
  out$sets <- lapply(found, function(pos) {
    classes <- small[pos]
    s_c <- numeric(C); s_c[classes] <- 1
    coef <- qr.coef(q, s_c)
    coef[is.na(coef)] <- 0
    list(atoms = which(cls %in% classes), n = sum(n_c[classes]), coef = as.numeric(coef))
  })
  out
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
#' every cell of each declared two-way crossing, subject to the four rules in
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
#'     recoverable_failures, exact, small_atoms, nesting_hidden,
#'     recovery_hidden, rounds, k}
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

  atoms <- disclosure_atoms(context)
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
    rc <- disclosure_small_recoverable(atoms$n, disclosure_atom_sets(atoms, lapply(seq_len(ncol(members)),
                                                                                    function(j) members[, j])), k)
    if (!length(rc$sets)) break
    for (st in rc$sets) {
      used <- which(abs(st$coef) > 1e-8 & ids != "all" & !ids %in% forced)
      if (length(used)) new <- c(new, ids[used[which.min(sizes[used])]])
    }
    new <- setdiff(unique(new), forced)
    if (!length(new)) {
      stuck(sprintf("%d set(s) of under %d respondents can be worked out and nothing more can be hidden.",
                    length(rc$sets), k))
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
                 recoverable_failures = length(rc$sets), exact = isTRUE(rc$exact),
                 small_atoms = sum(atoms$n < k),
                 nesting_hidden = length(by_nesting), recovery_hidden = length(by_recovery),
                 rounds = rounds, k = k)
  )
}


#' Audit a Set of Published Groups
#'
#' Independent re-check of what disclosure_publish_groups() promises, for use
#' before a file is released: every group at or above k, no pair of groups that
#' differ by 1 to k-1 respondents with one inside the other, and, when the
#' context is given, no set of 1 to k-1 respondents recoverable from the
#' groups (the exact engine).
#'
#' @param members Logical matrix, respondents by groups
#' @param k Minimum group
#' @param context Optional named context list, for the recoverability check
#' @param defs Optional list of named character definitions, one per column of
#'   members (needed with context)
#' @return List ok (logical), small (group ids under k), pairs (differencing
#'   pairs), recoverable (readable descriptions of the sets that can be worked
#'   out, atoms joined by " + ")
#' @export
disclosure_audit_groups <- function(members, k, context = NULL, defs = NULL) {
  n <- colSums(members)
  pairs <- disclosure_differencing_pairs(members, k)
  recoverable <- character(0)
  if (!is.null(context) && !is.null(defs)) {
    atoms <- disclosure_atoms(context)
    rc <- disclosure_small_recoverable(atoms$n, disclosure_atom_sets(atoms, lapply(seq_len(ncol(members)),
                                                                                    function(j) members[, j])), k)
    recoverable <- vapply(rc$sets, function(s) paste(atoms$id[s$atoms], collapse = " + "), "")
  }
  list(ok = all(n >= k) && nrow(pairs) == 0 && !length(recoverable),
       small = colnames(members)[n < k],
       pairs = pairs,
       recoverable = recoverable)
}
