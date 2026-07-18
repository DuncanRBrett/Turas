# ==============================================================================
# PATTERNS CONFIG ECHO (V13)
# ==============================================================================
# Validates the Patterns-tab levers against what the built data layer actually
# contains, so a silent opt-in can never masquerade as "the feature doesn't
# work". Every declaration is echoed with its outcome — a misspelt banner name,
# a KeyShare label that matches no option, an AreaSummary on an untagged
# question — in the console (Shiny-visible) and as a section on the report's
# statistical-diagnostics panel (it rides inside saved copies).
#
# The matching rules here deliberately MIRROR the JS engine, so the echo tells
# the truth about what the report will do:
#   - label normalisation  = 27fa normLabel (NBSP -> space, trim, lower)
#   - KeyShare resolution  = 27fa resolveRow (NETs first, minus score-diff NETs,
#                            then category rows; rated / classification skipped)
#   - rated detection      = 27_views indexQuestions (mean row + scale/nps, or a
#                            numeric scale_max on a non-numeric type)
#   - classification       = 27d CLASSIFICATION_RE + insight_exclude_categories
#
# Pure functions; never refuses. attach_patterns_echo() is wrapped in tryCatch
# at the call site so the echo can never break a report build.
# ==============================================================================

#' Normalise a label for matching (mirror of the JS normLabel)
#' @param s Character scalar (or NULL/NA)
#' @return Lower-cased, trimmed string with NBSP as space
.pe_norm <- function(s) {
  if (is.null(s) || length(s) == 0 || is.na(s[1])) return("")
  tolower(trimws(gsub(intToUtf8(160), " ", as.character(s[1]), fixed = TRUE)))
}

#' Is this data-layer question a rated touchpoint? (mirror of indexQuestions)
.pe_is_rated <- function(q) {
  rows <- q$rows %||% list()
  has_mean <- any(vapply(rows, function(r) identical(r$kind, "mean"), logical(1)))
  if (!has_mean) return(FALSE)
  type <- q$type %||% ""
  if (type %in% c("scale", "nps")) return(TRUE)
  sm <- q$scale_max
  type != "numeric" && !is.null(sm) && length(sm) == 1 && is.finite(as.numeric(sm)) &&
    as.numeric(sm) > 0
}

#' Is this question a classification cut? (mirror of 27d isClassification)
.pe_is_classification <- function(q, extra = character(0)) {
  cat_val <- as.character(q$category %||% "")
  if (!nzchar(cat_val)) return(FALSE)
  if (grepl("demograph|corpograph|firmograph|classif", cat_val, ignore.case = TRUE)) return(TRUE)
  tolower(cat_val) %in% tolower(as.character(extra))
}

#' Resolve a KeyShare label to a row index (mirror of 27fa resolveRow)
#' @return 1-based row index, or 0 when nothing matches
.pe_share_row <- function(q) {
  want <- .pe_norm(q$key_share)
  if (!nzchar(want)) return(0)
  rows <- q$rows %||% list()
  diff_keys <- names(q$net_diffs %||% list())
  for (i in seq_along(rows)) {
    if (!identical(rows[[i]]$kind, "net")) next
    if (as.character(i - 1) %in% diff_keys) next     # score-difference NETs never a share
    if (.pe_norm(rows[[i]]$label) == want) return(i)
  }
  for (i in seq_along(rows)) {
    if (identical(rows[[i]]$kind, "category") && .pe_norm(rows[[i]]$label) == want) return(i)
  }
  0
}

#' Clip a title for display
.pe_clip <- function(s, n = 44) {
  s <- as.character(s %||% "")
  if (nchar(s) > n) paste0(substr(s, 1, n - 1), "…") else s
}

#' Audit the Patterns configuration against the built data layer
#'
#' @param dl The built data layer (from build_data_layer)
#' @return A list:
#'   \item{active}{TRUE when any Patterns lever is declared}
#'   \item{rows}{list of c(label, value) display pairs (✓ ok, ⚠ check, · info)}
#'   \item{n_check}{how many rows carry a ⚠}
#' @export
audit_patterns_config <- function(dl) {
  proj <- dl$project %||% list()
  questions <- dl$questions %||% list()
  banners <- dl$banner_groups %||% list()
  extra_class <- as.character(proj$insight_exclude_categories %||% character(0))
  rows <- list()
  add <- function(label, value) rows[[length(rows) + 1]] <<- c(label, value)

  shares_declared <- Filter(function(q) nzchar(as.character(q$key_share %||% "")), questions)
  summaries_declared <- Filter(function(q) isTRUE(q$area_summary), questions)
  excl <- as.character(proj$patterns_exclude_banners %||% character(0))
  head_codes <- as.character(proj$takeout_headline %||% character(0))
  active <- length(excl) > 0 || length(head_codes) > 0 ||
    length(shares_declared) > 0 || length(summaries_declared) > 0
  if (!active) return(list(active = FALSE, rows = list(), n_check = 0L))

  # -- excluded banners ---------------------------------------------------------
  b_names <- vapply(banners, function(b) as.character(b$name %||% ""), character(1))
  b_ids   <- vapply(banners, function(b) as.character(b$id %||% ""), character(1))
  for (e in excl) {
    hit <- which(vapply(b_names, .pe_norm, character(1)) == .pe_norm(e) |
                 vapply(b_ids, .pe_norm, character(1)) == .pe_norm(e))
    if (length(hit) > 0) {
      add("Banner excluded", sprintf("✓ '%s' (%s) — out of the Patterns scan",
                                     e, b_ids[hit[1]]))
    } else {
      add("Banner excluded", sprintf(
        "⚠ '%s' matches no banner — check spelling (banners: %s)",
        e, paste(b_names, collapse = ", ")))
    }
  }

  # -- headline KPIs ------------------------------------------------------------
  q_by_code <- stats::setNames(questions,
    vapply(questions, function(q) as.character(q$code %||% ""), character(1)))
  for (code in head_codes) {
    q <- q_by_code[[code]]
    if (is.null(q)) {
      add("Headline KPI", sprintf("⚠ '%s' matches no question code", code))
    } else if (!.pe_is_rated(q)) {
      add("Headline KPI", sprintf(
        "⚠ %s is not a rated question — the apex shows rated KPIs only", code))
    } else {
      add("Headline KPI", sprintf("✓ %s — %s", code, .pe_clip(q$title)))
    }
  }

  # -- KeyShare declarations ----------------------------------------------------
  for (q in shares_declared) {
    code <- as.character(q$code %||% "")
    if (.pe_is_rated(q)) {
      add(paste("KeyShare", code), sprintf(
        "⚠ ignored — rated question; its index already scans"))
    } else if (.pe_is_classification(q, extra_class)) {
      add(paste("KeyShare", code), sprintf(
        "⚠ ignored — classification category '%s' (cuts, not outcomes)",
        as.character(q$category %||% "")))
    } else {
      ri <- .pe_share_row(q)
      if (ri > 0) {
        add(paste("KeyShare", code), sprintf("✓ '%s' (%s row)",
          as.character(q$rows[[ri]]$label %||% ""), as.character(q$rows[[ri]]$kind %||% "")))
      } else {
        add(paste("KeyShare", code), sprintf(
          "⚠ '%s' matches no option, box or NET label on %s — check the exact text",
          as.character(q$key_share), code))
      }
    }
  }

  # -- areas / AreaSummary ------------------------------------------------------
  rated <- Filter(.pe_is_rated, questions)
  theme_of <- function(q) {
    t <- as.character(q$theme %||% "")
    if (nzchar(t)) t else as.character(q$category %||% "")
  }
  for (q in summaries_declared) {
    code <- as.character(q$code %||% "")
    if (!.pe_is_rated(q)) {
      add(paste("AreaSummary", code),
          "⚠ ignored — areas read rated questions only")
    } else if (!nzchar(theme_of(q))) {
      add(paste("AreaSummary", code),
          "⚠ ignored — no Category/Theme tag, so it belongs to no area")
    }
  }
  themes <- unique(vapply(rated, theme_of, character(1)))
  themes <- themes[nzchar(themes)]
  for (t in themes) {
    members <- Filter(function(q) theme_of(q) == t, rated)
    if (length(members) < 2) next                    # a single question scores on itself
    flags <- Filter(function(q) isTRUE(q$area_summary), members)
    scales <- unique(vapply(members, function(q) as.numeric(q$scale_max %||% 0), numeric(1)))
    if (length(scales) > 1) {
      add(paste0("Area '", t, "'"),
          "⚠ mixed scales — sits out of the strongest/weakest race")
    } else if (length(flags) > 1) {
      add(paste0("Area '", t, "'"), sprintf(
        "⚠ %d questions marked AreaSummary — the first in question order wins",
        length(flags)))
    } else if (length(flags) == 1) {
      add(paste0("Area '", t, "'"), sprintf("✓ scores on its overall, %s",
        as.character(flags[[1]]$code %||% "")))
    } else {
      add(paste0("Area '", t, "'"), sprintf(
        "· flat average of %d questions — no overall declared (AreaSummary)",
        length(members)))
    }
  }

  n_check <- sum(vapply(rows, function(r) grepl("^⚠", r[2]), logical(1)))
  list(active = TRUE, rows = rows, n_check = as.integer(n_check))
}

#' Print the echo to the console and attach it to the report diagnostics
#'
#' Console output is mandatory (Turas runs in Shiny); the diagnostics section
#' reuses the existing Report-tab panel renderer, so no JS changes are needed.
#' Inactive configs (no Patterns lever declared) pass through untouched.
#'
#' @param dl The built data layer
#' @return The data layer, with the echo section attached when active
#' @export
attach_patterns_echo <- function(dl) {
  audit <- audit_patterns_config(dl)
  if (!isTRUE(audit$active)) return(dl)

  cat("\n┌─── PATTERNS CONFIG ─────────────────────────────────────┐\n")
  for (r in audit$rows) cat("│ ", r[1], ": ", r[2], "\n", sep = "")
  if (audit$n_check > 0) {
    cat(sprintf("│ %d declaration%s to check — marked ⚠ above\n",
                audit$n_check, if (audit$n_check == 1) "" else "s"))
  } else {
    cat("│ all declarations resolved ✓\n")
  }
  cat("└───────────────────────────────────────────────────────┘\n\n")

  section <- list(title = "Patterns configuration", rows = audit$rows)
  if (is.null(dl$project$diagnostics)) {
    # No diagnostics panel this run (its build failed) — carry the echo alone so
    # the config record still travels inside the report and its saved copies.
    dl$project$diagnostics <- list(sections = list(section))
  } else {
    dl$project$diagnostics$sections <-
      c(dl$project$diagnostics$sections %||% list(), list(section))
  }
  dl
}
