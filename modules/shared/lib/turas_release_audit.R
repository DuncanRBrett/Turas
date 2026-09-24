# ==============================================================================
# TURAS RELEASE AUDIT (what is in the finished file, checked rather than assumed)
# ==============================================================================
#
# run_minify_verification() answers "did minification break anything?". This
# answers the other question, which nothing asked until now: "what is in the file
# I am about to send?".
#
# It reads the finished HTML and reports two kinds of thing.
#
#   Disclosure. Whether a per-respondent island is present, how many respondents
#   it covers, whether row-level weights ride with it, and whether any island
#   carries a field that looks like a direct identifier. When the caller declares
#   the build client-safe, a populated island is a refusal, not a note. That is
#   the only way a declaration means anything.
#
#   IP. Engineering commentary, internal review references, R and Python
#   filenames, source maps, test hooks. These are notes, never refusals: a dev
#   build is supposed to have them, and the audit runs on both.
#
# Pure given the HTML string, so it is testable without a build:
#   testthat::test_file("modules/shared/tests/testthat/test_release_audit.R")
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Strings that should not reach a client build. Each is a regex, matched against
# the whole file. Kept deliberately short: a list nobody reads is a list nobody
# maintains, and the minifier already removes comments wholesale.
.RELEASE_IP_PATTERNS <- c(
  "TODO / FIXME notes"          = "\\bTODO\\b|\\bFIXME\\b",
  "source map reference"        = "sourceMappingURL",
  "R or Python source filename" = "[A-Za-z0-9_]+\\.(?:R|py)\\b",
  "internal review reference"   = "review 20[0-9][0-9]|production review|\\breview_[a-z]+",
  "test-harness hook"           = "node-testable|node gate|unit-tested",
  "JSDoc block comment"         = "/\\*\\*"
)

# JSON keys that would be a direct identifier if they appeared in a RESPONDENT
# island. Matched as quoted keys with a non-empty value, so a verbatim mentioning
# the word "email" is not a hit and neither is an unfilled field.
.RELEASE_IDENTIFIER_KEYS <- c(
  "ResponseID", "response_id", "respondent_id", "contact_id",
  "email", "Email", "phone", "Phone", "msisdn", "id_number", "ip_address"
)

# Only these islands hold per-respondent records. data-agg deliberately carries
# report_meta.email and report_meta.phone, which are the ANALYST's contact
# details for the About page, and flagging those taught the audit to cry wolf on
# every single build. An audit that fires on a correct file gets skipped, and a
# skipped audit is the same as no audit.
.RELEASE_RESPONDENT_ISLANDS <- c("data-micro", "data-qual")

# Islands that hold AGGREGATES, never records. data-cube is the interesting one:
# it exists to be the computed source of a file that carries no respondents, so
# it is audited on its OWN terms (every cell at or above k, no partial block, no
# array as long as the study) rather than treated as a respondent island.
.RELEASE_AGGREGATE_ISLANDS <- c("data-agg", "data-cube")


#' Audit a WHAT IF island against a client-safe build's promises
#'
#' The What if contribution file (modules/whatif) carries an open part, one row
#' per respondent, and a client-safe part, results for published groups only.
#' The tabs build keeps the open part only for a full report
#' (.read_whatif_contribution). This checks the file that was actually built:
#'   1. no open block, and no open profile model (its level counts can be under k);
#'   2. no list as long as the study, or nearly (n - k or more), outside the
#'      model's refits (the fits, ctx_offset, the profile's fits, and any list
#'      exactly as long as the fits);
#'   3. every published group at or above the island's own minimum, which is 2 or more;
#'   4. the island's own audit reports no nesting or recoverability failure,
#'      says the recoverability check was exact, and records that need counts
#'      and effects were checked too;
#'   5. no named list of refused or hidden groups, and no count of small cells
#'      in the shipped audit;
#'   6. arithmetic a reader can do from the island itself: the whole sample
#'      minus a variable's published levels, and a published level minus its
#'      published cells in a crossing, is 0 or at least k; and two groups
#'      whose definitions nest do not differ by 1 to k-1 in a shown need count
#'      or its complement (a backstop: the full test needs the respondents);
#'   7. fields that describe fewer than k people: no context-baseline
#'      coefficient (it names a level and estimates it), no per-level counts
#'      in Build a ..., no need count or its complement under k, no symptom
#'      whose flagged or unflagged side is under k, no outcome count under k,
#'      no per-lever "Don't know" count, and no whole number from 1 to k-1 in
#'      the warnings or notes.
#'
#' @param body The data-wi island body, already extracted.
#' @return list(present, mode, groups, violations)
#' @keywords internal
release_audit_whatif <- function(body) {
  out <- list(present = FALSE, mode = NA_character_, groups = 0L, violations = character(0))
  if (is.na(body) || !nzchar(trimws(body)) || identical(trimws(body), "null")) return(out)
  out$present <- TRUE
  wi <- tryCatch(jsonlite::fromJSON(body, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(wi)) {
    out$violations <- "the What if island cannot be read, so it cannot be checked"
    return(out)
  }
  out$mode <- as.character(wi$meta$mode %||% NA_character_)
  n <- suppressWarnings(as.integer(wi$meta$n %||% NA))
  if (!is.null(wi$open)) out$violations <- c(out$violations, "the What if island carries one row per respondent (its open part)")
  if (!is.null(wi$profile)) out$violations <- c(out$violations, "the What if island carries the open Build a ... model")
  # Every unnamed list's length, except the refit lists (one value per fit,
  # 101 by default, more than a small study's respondents) and the published
  # groups (checked on their own below). A list within k of the study's size
  # is one value per respondent, or nearly.
  n_fits <- length((wi$model %||% list())$fits %||% list())
  refit_paths <- c("model$fits", "model$ctx_offset", "profile$fits", "safe$profile$fits", "safe$groups")
  lengths_of <- function(o, path = "") {
    if (!is.list(o)) return(integer(0))
    here <- if (is.null(names(o)) && !path %in% refit_paths && !(n_fits > 1 && length(o) == n_fits)) length(o) else integer(0)
    kids <- if (is.null(names(o))) lapply(o, lengths_of, path = paste0(path, "[]"))
            else lapply(names(o), function(nm) lengths_of(o[[nm]], if (nzchar(path)) paste0(path, "$", nm) else nm))
    c(here, unlist(kids))
  }
  safe <- wi$safe
  k <- suppressWarnings(as.numeric((safe %||% list())$min_group %||% NA))
  if (!is.na(n) && !is.na(k) && any(lengths_of(wi) >= n - k)) {
    out$violations <- c(out$violations, sprintf("the What if island holds a list about as long as the study (%d)", n))
  }
  if (is.null(safe)) {
    out$violations <- c(out$violations, "the What if island has no client-safe part")
    return(out)
  }
  if (is.na(k) || k < 2) out$violations <- c(out$violations, "the What if island states no minimum group above 1")
  groups <- safe$groups %||% list()
  ns <- vapply(groups, function(g) as.numeric(g$n %||% NA), numeric(1))
  out$groups <- length(ns)
  if (!is.na(k) && any(is.na(ns) | ns < k)) {
    out$violations <- c(out$violations, sprintf("%d What if group(s) under the minimum of %s", sum(is.na(ns) | ns < k), k))
  }
  a <- safe$audit %||% list()
  if (!identical(as.numeric(a$differencing_failures %||% NA), 0) ||
      !identical(as.numeric(a$recoverable_failures %||% NA), 0) || !isTRUE(a$exact)) {
    out$violations <- c(out$violations, "the What if island's own audit reports groups that could be worked out by subtraction, or did not check exactly")
  }
  if (!isTRUE(a$need_checked) || !isTRUE(a$effects_checked)) {
    out$violations <- c(out$violations, "the What if island does not record that its need counts and effects were checked for differencing")
  }
  if (any(c("candidates_checked", "nesting_hidden", "recovery_hidden", "small_atoms") %in% names(a))) {
    out$violations <- c(out$violations, "the What if island's audit counts the small cells it hid")
  }
  if (!is.null(safe$refused) || !is.null(safe$hidden)) {
    out$violations <- c(out$violations, "the What if island names the groups it refused or hid")
  }
  if (is.na(k)) return(out)
  small <- function(x) !is.na(x) & x > 0 & x < k
  # 6. subtraction a reader can do with the island alone
  defs <- lapply(groups, function(g) unlist(g$def %||% list()))
  all_n <- ns[vapply(defs, length, 0) == 0][1]
  singles <- list(); cells <- list()
  for (i in seq_along(defs)) {
    d <- defs[[i]]
    if (length(d) == 1) singles[[names(d)]][[d[[1]]]] <- ns[i]
    if (length(d) == 2) {
      ks <- sort(names(d)); fam <- paste(ks, collapse = "|")
      cells[[fam]] <- rbind(cells[[fam]], data.frame(l1 = d[[ks[1]]], l2 = d[[ks[2]]], n = ns[i], stringsAsFactors = FALSE))
    }
  }
  if (!is.na(all_n)) for (key in names(singles)) {
    if (small(all_n - sum(unlist(singles[[key]])))) {
      out$violations <- c(out$violations, sprintf("the whole sample minus the published %s levels leaves fewer than %s", key, k))
    }
  }
  for (fam in names(cells)) {
    ks <- strsplit(fam, "|", fixed = TRUE)[[1]]; tab <- cells[[fam]]
    for (side in 1:2) {
      key <- ks[side]; col <- if (side == 1) "l1" else "l2"
      for (lv in names(singles[[key]] %||% list())) {
        rest <- singles[[key]][[lv]] - sum(tab$n[tab[[col]] == lv])
        if (small(rest)) {
          out$violations <- c(out$violations, sprintf("%s = %s minus its published cells in %s leaves fewer than %s",
                                                      key, lv, gsub("|", " by ", fam, fixed = TRUE), k))
        }
      }
    }
  }
  # Need counts across nested definitions: outer minus inner, on the count
  # and on its complement. Nesting by definition is what the island shows;
  # nesting by membership needs the respondents, which the build checks.
  need_of <- function(g) vapply(g$need %||% list(), function(v) if (is.null(v)) NA_real_ else as.numeric(v), 0)
  nested_need <- 0L
  for (i in seq_along(defs)) for (j in seq_along(defs)) {
    if (i == j || length(defs[[j]]) <= length(defs[[i]])) next
    if (!all(names(defs[[i]]) %in% names(defs[[j]])) || !all(defs[[i]] == defs[[j]][names(defs[[i]])])) next
    ni <- need_of(groups[[i]]); nj <- need_of(groups[[j]])
    if (!length(ni) || length(ni) != length(nj)) next
    both <- !is.na(ni) & !is.na(nj)
    d_need <- ni[both] - nj[both]
    d_not <- (ns[i] - ni[both]) - (ns[j] - nj[both])
    nested_need <- nested_need + sum(small(d_need) | small(d_not))
  }
  if (nested_need) {
    out$violations <- c(out$violations, sprintf("%d What if need count(s) differ between nested groups by fewer than %s", nested_need, k))
  }
  # 7. fields that describe fewer than k people
  mdl <- wi$model %||% list()
  if (any(vapply(mdl$design %||% list(), function(c) isTRUE(c$context), logical(1)))) {
    out$violations <- c(out$violations, "the What if model carries context-baseline coefficients (one per level, named)")
  }
  if (any(vapply((safe$profile %||% list())$keys %||% list(), function(kk) !is.null(kk$n), logical(1)))) {
    out$violations <- c(out$violations, "the What if Build a ... model carries per-level counts")
  }
  bad_need <- sum(vapply(seq_along(groups), function(i) {
    nd <- need_of(groups[[i]])
    sum(small(nd) | small(ns[i] - nd))
  }, numeric(1)))
  if (bad_need) out$violations <- c(out$violations, sprintf("%d What if need count(s) describe fewer than %s people", bad_need, k))
  sym_n <- vapply(mdl$symptoms %||% list(), function(sm) as.numeric(sm$n %||% NA), 0)
  if (!is.na(n) && any(small(sym_n) | small(n - sym_n))) {
    out$violations <- c(out$violations, sprintf("a What if symptom effect rests on fewer than %s respondents", k))
  }
  by_outcome <- vapply(wi$meta$n_by_outcome %||% list(), function(v) if (is.null(v)) NA_real_ else as.numeric(v), 0)
  if (any(small(by_outcome))) {
    out$violations <- c(out$violations, sprintf("a What if outcome category has fewer than %s respondents", k))
  }
  if (any(vapply(mdl$levers %||% list(), function(lv) !is.null(lv$missing), logical(1)))) {
    out$violations <- c(out$violations, "the What if model carries per-lever \"Don't know\" counts")
  }
  txt <- c(unlist(wi$meta$warnings), unlist(mdl$notes))
  if (length(txt)) {
    # A count stands on its own: start or a space before it, a space, full
    # stop, comma, semicolon, colon or bracket after it. "Q3", "0-6", "(100)"
    # and "12%" are labels, ranges, penalties and shares, not counts.
    plain <- gsub("[0-9]+(\\.[0-9]+)?%", "", txt)
    plain <- gsub("[0-9]+\\.[0-9]+", "", plain)
    nums <- suppressWarnings(as.numeric(unlist(regmatches(plain, gregexpr("(?<![^\\s])[0-9]+(?=[\\s.,;:)]|$)", plain, perl = TRUE)))))
    if (any(small(nums))) {
      out$violations <- c(out$violations, sprintf("a What if warning or note carries a count from 1 to %s", k - 1))
    }
  }
  out
}


#' Audit a COMMENT island against a client-safe build's promises
#'
#' The cube audit above asks whether the quantitative payload keeps its word.
#' This asks the same of the qualitative one, which is where the SACS 2025
#' client-safe build turned out to be naming individuals while its crosstabs
#' refused any group under ten.
#'
#' Five checks, each a thing a client-safe comment island claims:
#'   1. It declares question-local comment keys. A person's comments must not be
#'      joinable across questions: one comment can be anonymous while six are a
#'      profile.
#'   2. It carries no reader token. That is the field that used to do the
#'      joining, and its absence is checked separately from the declaration so a
#'      build whose declaration and payload disagree is caught.
#'   3. Its demographic tags are k-anonymised or absent, never "allow".
#'   4. Its verbatim text is not the raw `full` mode.
#'   5. Every demographic cut a comment carries names a group the CUBE says is at
#'      least k people. This is the one check that does not take the island's word
#'      for anything: it reads the tags actually shipped and prices them against
#'      the published cell bases. A cut the cube does not publish, because it
#'      names more variables than the cube's order or because that crossing was
#'      refused, cannot be priced from the file at all. Those are counted and
#'      reported, never treated as violations: an unpublished crossing is not a
#'      small group, and reading it as one accused nine safe tags on SACS 2025.
#'
#' @param body The data-qual island body, already extracted.
#' @param cube_body The data-cube island body, for check 5. NA when there is none.
#' @return list(present, comment_key, cuts, text_mode, records, unverifiable,
#'   violations); violations is empty when the island keeps its promises.
#' @keywords internal
release_audit_qual <- function(body, cube_body = NA_character_) {
  out <- list(present = FALSE, comment_key = NA_character_, cuts = NA_character_,
              text_mode = NA_character_, records = 0L, unverifiable = 0L,
              violations = character(0))
  if (is.na(body) || !nzchar(body) || identical(body, "null")) return(out)
  out$present <- TRUE
  isl <- tryCatch(jsonlite::fromJSON(body, simplifyVector = FALSE),
                  error = function(e) NULL)
  if (is.null(isl)) {
    out$violations <- "the data-qual island did not parse"
    return(out)
  }
  out$comment_key <- as.character(isl$commentKey %||% "respondent")
  out$cuts <- as.character(isl$demographicCuts %||% "allow")
  out$text_mode <- as.character(isl$textMode %||% "hidden")

  # 1. the declaration
  if (!identical(out$comment_key, "question")) {
    out$violations <- c(out$violations, sprintf(
      paste0("the comments are keyed one per respondent, so a reader can join ",
             "the same person's comments across questions (commentKey = '%s')"),
      out$comment_key))
  }

  # 2. the token, checked in the payload rather than in the declaration
  has_rid <- FALSE
  records <- 0L
  cuts_seen <- list()
  for (q in (isl$questions %||% list())) {
    for (rec in (q$records %||% list())) {
      records <- records + 1L
      rid <- rec$rid
      if (!is.null(rid) && length(rid) == 1L && !is.na(rid) && nzchar(as.character(rid))) {
        has_rid <- TRUE
      }
      cut <- rec$cut
      if (!is.null(cut) && length(cut)) {
        key <- paste(names(cut), unlist(cut), sep = "=", collapse = "|")
        cuts_seen[[key]] <- cut
      }
    }
  }
  out$records <- records
  if (has_rid) {
    out$violations <- c(out$violations,
      "a comment carries a reader token, which is the same value in every question")
  }

  # 3 and 4. the two dials
  if (identical(out$cuts, "allow")) {
    out$violations <- c(out$violations,
      "every demographic tag ships against every comment (demographicCuts = 'allow')")
  }
  if (identical(out$text_mode, "full")) {
    out$violations <- c(out$violations,
      "verbatim text ships raw, with no direct-identifier scrub (textMode = 'full')")
  }

  # 5. the tags actually shipped, priced against the cube's own cell bases
  cube <- NULL
  if (!is.na(cube_body) && nzchar(cube_body) && !identical(cube_body, "null")) {
    cube <- tryCatch(jsonlite::fromJSON(cube_body, simplifyVector = FALSE),
                     error = function(e) NULL)
  }
  if (!is.null(cube) && length(cuts_seen)) {
    k <- suppressWarnings(as.numeric(cube$k %||% NA_real_))
    order <- suppressWarnings(as.integer(cube$order %||% NA_integer_))
    var_order <- names(cube$vars %||% list())
    small <- character(0)
    for (key in names(cuts_seen)) {
      cut <- cuts_seen[[key]]
      names_in <- names(cut)
      if (is.na(order) || length(names_in) > order || !all(names_in %in% var_order)) {
        out$unverifiable <- out$unverifiable + 1L
        next
      }
      ordered <- names_in[order(match(names_in, var_order))]
      skey <- paste(ordered, collapse = "*")
      slice <- cube$slices[[skey]]
      ckey <- paste(vapply(ordered, function(v) as.character(cut[[v]]), character(1)),
                    collapse = "|")
      cell <- if (is.null(slice)) NULL else slice$cells[[ckey]]
      # An ABSENT slice or cell is a crossing the cube did not publish, which is
      # not the same fact as a small group and must not be read as one. SACS 2025
      # refuses all three of its two-variable slices, and reading those as groups
      # of nobody accused nine perfectly safe tags. A check that cannot run is
      # counted as one that did not run.
      if (is.null(cell) || is.null(cell$a)) {
        out$unverifiable <- out$unverifiable + 1L
        next
      }
      base <- suppressWarnings(as.numeric(cell$a[[1]]))
      if (!is.na(k) && !is.na(base) && base < k) small <- c(small, key)
    }
    if (length(small)) {
      out$violations <- c(out$violations, sprintf(
        paste0("%d demographic tag combination(s) on comments name a group the ",
               "cube itself reports as smaller than k=%s, the first being %s"),
        length(small), format(k), small[1]))
    }
  }
  out
}


#' Audit an aggregate cube island against its own promises
#'
#' Three checks, each a thing the cube claims about itself:
#'   1. No array anywhere in it is as long as the study. An array of n values is
#'      respondent-level data whatever the island is called.
#'   2. No cell base is between 1 and k - 1. A cell nobody answered is 0 and
#'      discloses nothing; a cell of one to four people is the whole point of k.
#'   3. No slice ships a partial block. A block ships whole or not at all,
#'      because a cell withheld on its own is recovered by subtraction from the
#'      margin that remains.
#'
#' @param body The data-cube island body, already extracted.
#' @return list(present, k, n, order, blocks, violations) where violations is a
#'   character vector, empty when the cube keeps its promises.
#' @keywords internal
release_audit_cube <- function(body) {
  out <- list(present = FALSE, k = NA_real_, n = NA_integer_, order = NA_integer_,
              cells = 0L, violations = character(0))
  if (is.na(body) || !nzchar(body) || identical(body, "null")) return(out)
  out$present <- TRUE
  cube <- tryCatch(jsonlite::fromJSON(body, simplifyVector = FALSE),
                   error = function(e) NULL)
  if (is.null(cube)) {
    out$violations <- "the data-cube island did not parse"
    return(out)
  }
  out$k <- suppressWarnings(as.numeric(cube$k %||% NA_real_))
  out$n <- suppressWarnings(as.integer(cube$n %||% NA_integer_))
  out$order <- suppressWarnings(as.integer(cube$order %||% NA_integer_))
  k <- out$k
  if (is.na(k) || k <= 1) {
    out$violations <- c(out$violations,
      "the cube states no confidentiality threshold, so it protects nothing")
  }

  # 1. respondent-shaped arrays
  n <- out$n
  long <- FALSE
  scan_arrays <- function(node, depth) {
    if (long || depth > 8 || is.null(node)) return(invisible(NULL))
    if (is.list(node)) {
      if (is.null(names(node)) && length(node) == n && !is.na(n) && n > 5) {
        long <<- TRUE; return(invisible(NULL))
      }
      for (child in node) scan_arrays(child, depth + 1)
    }
    invisible(NULL)
  }
  scan_arrays(cube$slices, 0)
  if (long) {
    out$violations <- c(out$violations, sprintf(
      "the cube carries an array of %s values, which is one per respondent", format(n)))
  }

  # 2 and 3. cell bases, and whole blocks
  #
  # A PUBLISHED MARGIN is the exception, and it is the cube writer's own rule
  # rather than a loosening of this one. A one-variable slice on a banner
  # variable IS that banner, and the crosstab already prints it column by
  # column, base by base, with the sub-k columns blanked. So the cube suppresses
  # the CELL there rather than the cut: the base ships, the answers do not, and
  # nothing is disclosed that the workbook has not already published. Every other
  # slice is a crossing nobody published, and the whole-block rule stands.
  #
  # Without this the audit flagged 161 deliberately suppressed cells on SACS 2025
  # and would have refused any project with a small banner column. An audit that
  # fires on a correct file gets skipped, and a skipped audit is no audit.
  var_kind <- function(v) {
    d <- (cube$vars %||% list())[[v]]
    if (is.null(d)) "" else as.character(d$kind %||% "")
  }
  published_margin <- function(skey) {
    if (identical(skey, "*")) return(FALSE)
    parts <- strsplit(skey, "*", fixed = TRUE)[[1]]
    length(parts) == 1L && identical(var_kind(parts[[1]]), "banner")
  }

  sub_k <- 0L
  cells <- 0L
  for (skey in names(cube$slices %||% list())) {
    slice <- cube$slices[[skey]]
    if (is.null(slice)) next
    margin <- published_margin(skey)
    for (rec in (slice$cells %||% list())) {
      a <- rec$a
      if (is.null(a)) next
      cells <- cells + 1L
      v <- suppressWarnings(as.numeric(a[[1]]))
      # The base of a published banner column is in the workbook already.
      if (margin) next
      if (!is.na(v) && v > 0 && !is.na(k) && v < k) sub_k <- sub_k + 1L
    }
    for (qcode in names(slice$q %||% list())) {
      block <- slice$q[[qcode]]
      if (is.null(block)) next               # refused whole, which is the rule
      for (rec in block) {
        b <- rec$b
        if (is.null(b)) next
        cells <- cells + 1L
        v <- suppressWarnings(as.numeric(b[[1]]))
        # On a margin the sub-k cell must be SUPPRESSED: it ships its base and no
        # answers. One that is under k and not suppressed is a real violation,
        # margin or not, so the exemption is on the marker, never on the slice.
        if (margin && isTRUE(rec$sup)) next
        if (!is.na(v) && v > 0 && !is.na(k) && v < k) sub_k <- sub_k + 1L
      }
    }
  }
  out$cells <- cells
  if (sub_k > 0L) {
    out$violations <- c(out$violations, sprintf(
      "%d cell base(s) sit between 1 and k - 1, which the block rule forbids", sub_k))
  }
  out
}


#' Extract one JSON island's body from a finished report
#'
#' @param html The whole HTML file as a single string.
#' @param island_id The island's id attribute, e.g. "data-micro".
#' @return The island body as a trimmed string, or NA_character_ when absent.
#' @keywords internal
release_island_body <- function(html, island_id) {
  # (?s) so "." matches a NEWLINE. Without it this matched only an island whose
  # whole body sat on one line, which is true of the hand-built strings in the
  # gate and false of every report the template writes: template.html puts a
  # newline after the opening tag and before the closing one. So the audit read
  # NO island at all from a real deliverable, reported "Respondent-level island:
  # absent" on a file carrying every respondent, and passed a client-safe
  # declaration it should have refused. Found 4 September 2026 while building
  # the adversary gate against a real report rather than a fixture.
  pat <- paste0("(?s)<script[^>]*id=\"", island_id, "\"[^>]*>(.*?)</script>")
  m <- regmatches(html, regexpr(pat, html, perl = TRUE))
  if (length(m) == 0L) return(NA_character_)
  body <- sub(paste0("^<script[^>]*id=\"", island_id, "\"[^>]*>"), "", m[1], perl = TRUE)
  trimws(sub("</script>$", "", body))
}


#' Audit a finished Turas HTML report before it is delivered
#'
#' @param html Character. The finished report, read as a single string.
#' @param client_safe Logical. TRUE when the operator has declared this build
#'   carries no respondent-level data. A populated microdata island then refuses.
#' @param refuse Logical. Whether a client-safe violation raises a TRS refusal
#'   (TRUE, the delivery path) or is only reported (FALSE, for tests and dry runs).
#'
#' @return A list with structure:
#'   \item{status}{"PASS" when nothing was found, "FLAGGED" otherwise}
#'   \item{microdata}{list(present, n, weights)}
#'   \item{identifiers}{Character vector of identifier-looking keys found}
#'   \item{ip}{Named integer vector of IP-pattern hit counts (non-zero only)}
#'   \item{lines}{Character vector, the audit as printable lines}
#'   \item{client_safe_violation}{TRUE when client_safe was declared and broken}
#'
#' @keywords internal
turas_release_audit <- function(html, client_safe = FALSE, refuse = TRUE) {
  if (!is.character(html) || length(html) != 1L) {
    stop("turas_release_audit: html must be a single string", call. = FALSE)
  }

  cube_body <- release_island_body(html, "data-cube")
  cube_audit <- release_audit_cube(cube_body)
  qual_audit <- release_audit_qual(release_island_body(html, "data-qual"), cube_body)
  whatif_audit <- release_audit_whatif(release_island_body(html, "data-wi"))

  micro_body <- release_island_body(html, "data-micro")
  micro_present <- !is.na(micro_body) && nzchar(micro_body) &&
    !identical(micro_body, "null")
  micro_n <- NA_integer_
  micro_weights <- FALSE
  if (micro_present) {
    nm <- regmatches(micro_body, regexpr('"n"\\s*:\\s*([0-9]+)', micro_body, perl = TRUE))
    if (length(nm)) micro_n <- as.integer(gsub("\\D", "", nm[1]))
    micro_weights <- grepl('"weights"\\s*:\\s*\\[', micro_body, perl = TRUE)
  }

  # Identifier keys are looked for in the RESPONDENT islands only, and only when
  # they carry a value. Scanning the whole page hits the renderer's own code (a
  # mailto label); scanning data-agg hits the analyst's own contact block.
  respondent_json <- paste(
    vapply(.RELEASE_RESPONDENT_ISLANDS,
           function(id) { b <- release_island_body(html, id); if (is.na(b)) "" else b },
           character(1)),
    collapse = "\n")
  identifiers <- .RELEASE_IDENTIFIER_KEYS[vapply(.RELEASE_IDENTIFIER_KEYS, function(k) {
    # key: "value" with something in it, or key: <non-string, non-null> literal.
    filled <- paste0("\"", k, "\"\\s*:\\s*(?:\"[^\"]+\"|(?!null|\"\")[^,}\\s])")
    grepl(filled, respondent_json, perl = TRUE)
  }, logical(1))]
  identifiers <- unname(identifiers)

  ip_hits <- vapply(.RELEASE_IP_PATTERNS, function(p) {
    length(unlist(gregexpr(p, html, perl = TRUE))[
      unlist(gregexpr(p, html, perl = TRUE)) > 0])
  }, integer(1))
  ip_hits <- ip_hits[ip_hits > 0L]

  cube_violation <- isTRUE(client_safe) && length(cube_audit$violations) > 0
  qual_violation <- isTRUE(client_safe) && length(qual_audit$violations) > 0
  whatif_violation <- isTRUE(client_safe) && length(whatif_audit$violations) > 0
  violation <- isTRUE(client_safe) && (micro_present || cube_violation || qual_violation || whatif_violation)

  pad <- function(x) formatC(x, width = 32, flag = "-")
  lines <- c(
    "┌─── TURAS RELEASE AUDIT ──────────────────────────────────────┐",
    paste0("│ ", pad("Declared delivery mode"), ": ",
           if (isTRUE(client_safe)) "CLIENT SAFE" else "full (respondent data permitted)"),
    paste0("│ ", pad("Respondent-level island"), ": ",
           if (micro_present) sprintf("PRESENT (%s respondents)",
                                      if (is.na(micro_n)) "count unreadable" else micro_n)
           else "absent"),
    paste0("│ ", pad("Row-level weights"), ": ", if (micro_weights) "present" else "absent"),
    paste0("│ ", pad("Direct-identifier fields"), ": ",
           if (length(identifiers)) paste(identifiers, collapse = ", ") else "none found"),
    paste0("│ ", pad("Aggregate cube"), ": ",
           if (!cube_audit$present) "absent"
           else sprintf("present (k = %s, up to %s variables, %s cells)",
                        format(cube_audit$k), cube_audit$order, format(cube_audit$cells))),
    paste0("│ ", pad("Comment island"), ": ",
           if (!qual_audit$present) "absent"
           else sprintf("present (%s comments, keyed by %s, tags %s, text %s)",
                        format(qual_audit$records), qual_audit$comment_key,
                        qual_audit$cuts, qual_audit$text_mode)),
    paste0("│ ", pad("What if island"), ": ",
           if (!whatif_audit$present) "absent"
           else sprintf("present (%s, %d published groups)",
                        if (identical(whatif_audit$mode, "open")) "open: follows the filter" else "client-safe",
                        whatif_audit$groups)),
    # Said out loud, because a check that could not run is not a check that passed.
    if (qual_audit$present && qual_audit$unverifiable > 0)
      paste0("│ ", pad("Comment tags not priceable"), ": ",
             sprintf(paste0("%d combination(s): the cube does not publish that ",
                            "crossing, so its size cannot be read from this file"),
                     qual_audit$unverifiable))
  )

  if (length(cube_audit$violations)) {
    lines <- c(lines, "│", "│ The cube does not keep its own promises:")
    for (v in cube_audit$violations) lines <- c(lines, paste0("│   ", v))
  }

  if (length(qual_audit$violations)) {
    lines <- c(lines, "│", "│ The comment island does not keep its own promises:")
    for (v in qual_audit$violations) lines <- c(lines, paste0("│   ", v))
  }

  if (isTRUE(client_safe) && length(whatif_audit$violations)) {
    lines <- c(lines, "│", "│ The What if island does not keep a client-safe file's promises:")
    for (v in whatif_audit$violations) lines <- c(lines, paste0("│   ", v))
  }

  if (length(ip_hits)) {
    lines <- c(lines, "│", "│ Engineering detail still readable in this file:")
    for (nm in names(ip_hits)) {
      lines <- c(lines, sprintf("│   %s %s", pad(nm), format(ip_hits[[nm]])))
    }
    lines <- c(lines,
      "│ Expected in a dev build. In a deliverable it means the minify step",
      "│ did not run, or ran without the obfuscator.")
  } else {
    lines <- c(lines, paste0("│ ", pad("Engineering detail readable"), ": none found"))
  }

  lines <- c(lines, "└──────────────────────────────────────────────────────────────┘")

  out <- list(
    status = if (!micro_present && !length(identifiers) && !length(ip_hits) &&
                 !length(cube_audit$violations) &&
                 !length(qual_audit$violations) &&
                 !(isTRUE(client_safe) && length(whatif_audit$violations))) "PASS" else "FLAGGED",
    microdata = list(present = micro_present, n = micro_n, weights = micro_weights),
    cube = cube_audit,
    qual = qual_audit,
    whatif = whatif_audit,
    identifiers = identifiers,
    ip = ip_hits,
    lines = lines,
    client_safe_violation = violation
  )

  if (violation && isTRUE(refuse)) {
    if (exists("turas_refuse", mode = "function")) {
      turas_refuse(
        code = "CFG_CLIENT_SAFE_VIOLATED",
        title = if (micro_present) "Client-safe build still contains respondent-level data"
                else if (cube_violation)
                  "Client-safe build carries an aggregate cube that breaks its own rule"
                else if (whatif_violation)
                  "Client-safe build carries What if data it should not"
                else "Client-safe build carries comments that identify their authors",
        problem = if (micro_present) sprintf(
          "This build was declared client-safe, but the file carries a populated data-micro island (%s de-identified records).",
          if (is.na(micro_n)) "count unreadable" else micro_n)
        else if (cube_violation) paste0(
          "This build was declared client-safe, and its aggregate cube does not keep ",
          "its own promises: ", paste(cube_audit$violations, collapse = "; "), ".")
        else if (whatif_violation) paste0(
          "This build was declared client-safe, and its What if tab does not keep ",
          "a client-safe file's promises: ", paste(whatif_audit$violations, collapse = "; "), ".")
        else paste0(
          "This build was declared client-safe, and its comment island does not keep ",
          "its own promises: ", paste(qual_audit$violations, collapse = "; "), "."),
        why_it_matters = paste(
          "A client-safe file carries no respondent-level records, any",
          "aggregates in it keep their own k rule, and its comments neither name",
          "a group below that rule nor join one person's answers across",
          "questions. This build does not match the mode it was declared under."),
        how_to_fix = if (micro_present) c(
          "Choose 'Client safe' in the tabs GUI before running: the build then drops the island itself.",
          "Running outside the GUI: set html_report_v2_interactivity = none on the Settings sheet.",
          "The island is decided when the report is built, so it cannot be removed afterwards.",
          "Or build without declaring client-safe, if respondent data is acceptable for this recipient.")
        else if (cube_violation) c(
          "Raise min_reporting_base and rebuild: the cube then withholds the cuts that are too small.",
          "Or set html_report_v2_interactivity = none for published tables with no live views.",
          "The cube is decided when the report is built, so it cannot be repaired afterwards.")
        else if (whatif_violation) c(
          "Rebuild through the tabs GUI with the client-safe choice: the build keeps only the What if file's client-safe part.",
          "Run the What if module again if its file predates this check, then rebuild the report.",
          "Or clear whatif_island on the Settings sheet to build without the What if tab.")
        else c(
          "Choose a client-safe delivery mode in the tabs GUI and rebuild: it raises the comment dials itself.",
          "Running outside the GUI: set qual_comment_key = question and qual_demographic_cuts = safe on the Settings sheet.",
          "qual_demographic_cuts = safe needs min_reporting_base above 1 to mean anything.",
          "Or set qual_confidentiality_mode = hidden to ship themes and counts with no verbatim text.",
          "The comment island is decided when the report is built, so it cannot be repaired afterwards."),
        module = "RELEASE AUDIT"
      )
    } else {
      stop("Client-safe build still contains respondent-level data", call. = FALSE)
    }
  }

  out
}


#' Print a release audit to the console
#'
#' @inheritParams turas_release_audit
#' @return The audit list, invisibly.
#' @keywords internal
turas_print_release_audit <- function(html, client_safe = FALSE, refuse = TRUE) {
  a <- turas_release_audit(html, client_safe = client_safe, refuse = refuse)
  cat("\n"); cat(paste0(a$lines, collapse = "\n")); cat("\n\n")
  invisible(a)
}
