# SIZE-EXCEPTION: Stage plan + per-stage builders + nesting validator form a
# coherent sequential pipeline; splitting them across files would fragment
# the funnel derivation flow without improving readability.
#
# ==============================================================================
# BRAND MODULE - FUNNEL STAGE DERIVATION
# ==============================================================================
# Builds per-respondent × per-brand logical matrices for every funnel stage
# declared by the category type (transactional / durable / service). Each
# stage's derivation ANDs the previous stage's matrix, so nesting is
# guaranteed by construction. validate_nesting() then verifies the
# invariant and refuses loud on violation (§3.4 of FUNNEL_SPEC v2).
#
# This file is sourced by modules/brand/R/03_funnel.R alongside
# 03b_funnel_metrics.R. All three together implement run_funnel().
#
# VERSION: 2.0
# ==============================================================================

BRAND_FUNNEL_DERIVE_VERSION <- "2.0"

# Consider-stage definition (IPK 2026 v2, 2026-05-21):
#
#   The funnel models the buyer journey as a classical brand funnel:
#     Aware (recognise the brand)
#     -> Consider (Love or Prefer attitude, top-2 of the 6-level scale)
#     -> Bought 12 months (long-period physical penetration)
#     -> Bought 3 months  (target-window physical penetration)
#
#   Choice of top-2 attitude codes (Love + Prefer) over the legacy top-4
#   (Love + Prefer + Ambivalent + Price-conditional):
#     - Top-4 produced "everyone aware considers" collapse, for popular
#       brands in IPK 2026, top-4 let 85-97% of aware respondents through
#       so the consideration stage barely narrowed the funnel.
#     - Top-2 produces meaningful narrowing across all 51 brand-cats
#       (51/51 monotonic) and gives the strongest cross-brand predictor
#       of past-3-month purchase (Pearson avg 0.97 vs purchase, beating
#       awareness and CEP-based Mental Penetration).
#
#   Mental Availability (CEP-based MPen, MMS, Network Size, etc.) lives
#   on the Mental Availability tab in full Romaniuk-canonical form. The
#   funnel and the MA tab measure DIFFERENT constructs by design and so
#   carry different numbers, the funnel tracks loyalty-style buyer
#   conversion, the MA tab tracks growth-potential memory presence.
#
# Membership is named by ROLE, never by raw code (2026-09-06). See
# .FUNNEL_CONSIDERATION_ROLES and .funnel_resolve_consideration() below for
# why, and for what happens to a config that still carries raw codes.


# ==============================================================================
# CONSTANTS
# ==============================================================================

# Category type -> ordered stage list. Transactional funnels are 4 stages
# (Aware → Consider → Long Period → Target Period). Heavy-buyer / frequency
# analysis lives in the Repertoire / Frequency element, not here, the
# funnel is a leakage story with unambiguous binary stages (FUNNEL_SPEC_v2 §3).
.FUNNEL_STAGE_PLAN <- list(
  transactional = c("aware", "consideration",
                    "bought_long", "bought_target"),
  durable       = c("aware", "consideration",
                    "current_owner_d", "long_tenured_d"),
  service       = c("aware", "consideration",
                    "current_customer_s", "long_tenured_s")
)

# Default stage labels shown in the report. Operator can override at
# runtime via config$funnel.stage_labels_override.
.FUNNEL_DEFAULT_LABELS <- list(
  aware              = "Aware",
  consideration      = "Prefer",
  bought_long        = "Long Period",
  bought_target      = "Target Period",
  current_owner_d    = "Current owner",
  long_tenured_d     = "Long-tenured owner",
  current_customer_s = "Current customer",
  long_tenured_s     = "Long-tenured customer"
)

# Stage definitions: shown as clickable ? popovers in the HTML report
# and exported to the About drawer / Excel metadata sheet. Operator can
# override per project via config$funnel.stage_definitions.
#
# Each definition describes ONE stage's own survey response, because that
# is the only thing true in every view of the table. The stages are
# derived independently (see derive_funnel_stages below: the aggregate
# funnel does not AND a stage into the next), and the base toggle above
# the table is what decides whether the stages are combined and how. Text
# that claimed a stage was gated on an earlier one described the nested
# view only, and contradicted the figures the absolute view puts beside
# it. Corrected 2026-09-06.
#
# Keep these strings free of digits: the reachability gate compares the
# numeric content of every JSON island, and a definition rides in the
# funnel payload.
.FUNNEL_DEFAULT_DEFINITIONS <- list(
  aware              = "Respondents who recognise the brand (stated aided awareness).",
  consideration      = "Respondents who actively prefer the brand on the attitude question: Love (it's my favourite / I always pick it) or Prefer (I prefer it but don't always get it). Ambivalent, Price-conditional, Avoid, and No-opinion respondents are excluded. The attitude question is asked about every brand, whether or not the respondent named it as known, so this stage is measured on its own and is not gated on awareness. The base toggle above the table sets whether the stages are combined. Mental Availability (CEP-based memory presence) is reported separately on the Mental Availability tab.",
  bought_long        = "Respondents who say they bought the brand in the longer timeframe asked on the survey. The purchase question is asked about every brand, so this stage is measured on its own and is not gated on awareness or preference. The base toggle above the table sets whether the stages are combined.",
  bought_target      = "Respondents who say they bought the brand in the target (shorter) timeframe asked on the survey. Measured on its own, and not gated on awareness, on preference, or on the longer timeframe. The base toggle above the table sets whether the stages are combined.",
  current_owner_d    = "Respondents who name the brand as the one they currently own in the category. Measured on its own, and not gated on awareness or preference. The base toggle above the table sets whether the stages are combined.",
  long_tenured_d     = "Current owners of the brand whose tenure meets or exceeds the configured tenure threshold. This stage is gated on current ownership of the brand, and not on awareness or preference. The base toggle above the table sets whether the stages are combined.",
  current_customer_s = "Respondents who name the brand as the one they are currently a customer of. Measured on its own, and not gated on awareness or preference. The base toggle above the table sets whether the stages are combined.",
  long_tenured_s     = "Current customers of the brand whose tenure meets or exceeds the configured tenure threshold. This stage is gated on being a current customer of the brand, and not on awareness or preference. The base toggle above the table sets whether the stages are combined."
)

# ==============================================================================
# CONSIDERATION SET
# ==============================================================================
#
# The Consider stage's membership is named by ROLE, not by raw response code.
# A role is a position on the attitude scale ("attitude.love"); a code is
# whatever this particular survey happened to export for it ("1", or "Love",
# or "I love it. it's my favourite"). Naming roles means one definition
# survives a survey that exports some attitude columns as numbers and others
# as labels, which Alchemer does routinely.
#
# Until 2026-09-06 the config knob took raw codes, and an override silently
# changed the MECHANISM as well as the membership: codes equal to the built-in
# pair were resolved through the OptionMap by role, and anything else was
# matched literally against the data. Overriding a label-encoded category
# therefore returned an empty stage rather than refusing. The resolver below
# is the single path; raw codes are resolved to roles first and then expanded
# the same way.
#
# Default set. A role in this set that the survey's scale does not carry is
# dropped and reported, not refused, because scales of different lengths are
# legitimately in the field. A role the OPERATOR names and the scale does not
# carry is a refusal.
.FUNNEL_CONSIDERATION_ROLES <- c(
  "attitude.love", "attitude.prefer"
)

# Spellings an operator may reasonably type in the Settings sheet, mapped to
# the canonical role. "reject" to "avoid" is handled separately by
# .funnel_canonical_attitude_role() in 03b_funnel_metrics.R.
.FUNNEL_CONSIDERATION_ROLE_SYNONYMS <- c(
  "attitude.price_only"        = "attitude.price",
  "attitude.priceonly"         = "attitude.price",
  "attitude.price_conditional" = "attitude.price",
  "attitude.conditional"       = "attitude.price",
  "attitude.noopinion"         = "attitude.no_opinion",
  "attitude.none"              = "attitude.no_opinion",
  "attitude.dont_know"         = "attitude.no_opinion",
  "attitude.do_not_know"       = "attitude.no_opinion"
)


#' Normalise operator-supplied consideration role names
#'
#' Accepts a character vector or a single comma / semicolon separated string,
#' short names ("love, prefer, price") or full ones ("attitude.love"), in any
#' case, with spaces or hyphens where the canonical name has an underscore.
#'
#' @param roles Character vector or string.
#' @return Character vector of canonical role names, deduplicated.
#' @keywords internal
.funnel_normalise_consideration_roles <- function(roles) {
  r <- as.character(unlist(roles, use.names = FALSE))
  r <- unlist(strsplit(r, "[,;]"), use.names = FALSE)
  r <- tolower(trimws(r))
  r <- r[!is.na(r) & nzchar(r)]
  if (length(r) == 0L) return(character(0))
  bare <- !grepl("^attitude\\.", r)
  r[bare] <- paste0("attitude.", r[bare])
  r <- gsub("[ \\-]+", "_", r)
  hit <- r %in% names(.FUNNEL_CONSIDERATION_ROLE_SYNONYMS)
  r[hit] <- unname(.FUNNEL_CONSIDERATION_ROLE_SYNONYMS[r[hit]])
  unique(.funnel_canonical_attitude_role(r))
}


#' Resolve the Consider stage's accepted response values
#'
#' One path for every caller. The attitude scale is resolved to a role to
#' codes map by \code{.resolve_attitude_role_codes()} (operator override,
#' then OptionMap, then the built-in five-level convention), and the named
#' roles are looked up in it. A role the operator named that the scale does
#' not carry is a TRS refusal, not an empty stage. A role in the BUILT-IN
#' default set that the scale does not carry is dropped and reported, because
#' a five-level scale legitimately has no price-conditional level.
#'
#' @param attitude_entry Role-map entry for funnel.attitude.
#' @param roles Character vector of role names (already normalised).
#' @param roles_are_default TRUE when \code{roles} is the built-in set rather
#'   than an operator choice.
#' @param codes Optional character vector of legacy raw response codes. When
#'   supplied it REPLACES \code{roles}: each code is resolved back to the role
#'   whose accepted set contains it and expanded to that role's full set.
#' @param cat_code Category code, for the refusal message only.
#'
#' @return List with \code{values} (lowercase accepted response values),
#'   \code{roles_used}, \code{roles_dropped}, \code{unmatched_codes},
#'   \code{source} ("roles" or "codes"), \code{notes} (character vector).
#' @keywords internal
.funnel_resolve_consideration <- function(attitude_entry, roles,
                                          roles_are_default = TRUE,
                                          codes = NULL, cat_code = NULL) {
  role_to_codes <- .resolve_attitude_role_codes(attitude_entry)
  if (!is.list(role_to_codes)) role_to_codes <- list()

  .accepted <- function(role) {
    v <- role_to_codes[[role]]
    v <- tolower(trimws(as.character(v %||% character(0))))
    unique(v[!is.na(v) & nzchar(v)])
  }

  notes <- character(0)

  if (!is.null(codes) && length(codes) > 0) {
    raw <- tolower(trimws(as.character(unlist(codes, use.names = FALSE))))
    raw <- raw[!is.na(raw) & nzchar(raw)]
    declared      <- .funnel_declared_scale_roles(attitude_entry)
    matched_roles <- character(0)
    unmatched     <- character(0)
    for (code in raw) {
      owner <- Filter(function(r) code %in% .accepted(r), declared)
      if (length(owner) > 0) {
        matched_roles <- c(matched_roles, unlist(owner, use.names = FALSE))
      } else {
        unmatched <- c(unmatched, code)
      }
    }
    matched_roles <- unique(matched_roles)
    values <- unique(c(unlist(lapply(matched_roles, .accepted),
                              use.names = FALSE),
                       unmatched))
    notes <- c(notes, sprintf(
      paste("funnel.positive_attitude_codes is deprecated. Codes %s resolved",
            "to roles %s. Set funnel_consideration_roles to the role names",
            "instead, so the definition survives a survey that exports",
            "labels rather than numbers."),
      paste(raw, collapse = ", "),
      if (length(matched_roles) > 0) paste(matched_roles, collapse = ", ")
      else "(none)"))
    if (length(unmatched) > 0) {
      notes <- c(notes, sprintf(
        paste("Codes %s match no position on the attitude scale and are",
              "matched literally against the data. Check the OptionMap."),
        paste(unmatched, collapse = ", ")))
    }
    return(list(values = values, roles_used = matched_roles,
                roles_dropped = character(0), unmatched_codes = unmatched,
                source = "codes", notes = notes))
  }

  known <- roles %in% .FUNNEL_ATTITUDE_POSITIONS
  if (any(!known)) {
    .funnel_refuse_unknown_roles(roles[!known])
  }
  declared <- .funnel_declared_scale_roles(attitude_entry)
  present  <- roles %in% declared &
                vapply(roles, function(r) length(.accepted(r)) > 0, logical(1))
  if (any(!present) && !isTRUE(roles_are_default)) {
    .funnel_refuse_absent_roles(roles[!present], declared, cat_code)
  }
  dropped <- roles[!present]
  used    <- roles[present]
  if (length(dropped) > 0) {
    notes <- c(notes, sprintf(
      paste("The attitude scale carries no %s level, so the Consider stage",
            "is %s on this survey."),
      paste(sub("^attitude\\.", "", dropped), collapse = " or "),
      paste(sub("^attitude\\.", "", used), collapse = " plus ")))
  }
  values <- unique(unlist(lapply(used, .accepted), use.names = FALSE))
  list(values = values, roles_used = used, roles_dropped = dropped,
       unmatched_codes = character(0), source = "roles", notes = notes)
}


#' Which positions the survey's attitude scale actually declares
#'
#' Not the same question as "what values would match this role".
#' \code{.option_map_by_role()} folds a set of hardcoded label aliases into
#' every role, so its result is never empty and cannot answer whether the
#' scale carries a level. This reads the declaration itself: the operator's
#' \code{attitude_role_codes} override, else the OptionMap's Role column,
#' else the built-in five-level convention.
#'
#' @param attitude_entry Role-map entry for funnel.attitude.
#' @return Character vector of canonical role names.
#' @keywords internal
.funnel_declared_scale_roles <- function(attitude_entry) {
  if (!is.null(attitude_entry$attitude_role_codes)) {
    src <- attitude_entry$attitude_role_codes
    keep <- vapply(src, function(v) length(v) > 0, logical(1))
    return(.funnel_canonical_attitude_role(names(src)[keep]))
  }
  om <- attitude_entry$option_map
  if (!is.null(om) && is.data.frame(om) && "Role" %in% names(om)) {
    r <- tolower(trimws(as.character(om$Role)))
    r <- r[!is.na(r) & nzchar(r)]
    r <- sub("^attitude_scale\\.", "attitude.", r)
    return(unique(.funnel_canonical_attitude_role(r)))
  }
  keep <- vapply(.FUNNEL_DEFAULT_ATTITUDE_ROLE_CODES,
                 function(v) length(v) > 0, logical(1))
  .funnel_canonical_attitude_role(
    names(.FUNNEL_DEFAULT_ATTITUDE_ROLE_CODES)[keep])
}


#' @keywords internal
.funnel_refuse_unknown_roles <- function(bad) {
  brand_refuse(
    code = "CFG_CONSIDERATION_ROLE_UNKNOWN",
    title = "Unrecognised Consideration Role",
    problem = sprintf(
      "funnel_consideration_roles names %s, which is not a position on the attitude scale.",
      paste(bad, collapse = ", ")),
    why_it_matters = paste(
      "The Consider stage is defined by naming positions on the attitude",
      "scale. A name Turas does not recognise would silently contribute no",
      "respondents, and the stage would read lower than it should."
    ),
    how_to_fix = c(
      sprintf("Use one or more of: %s.",
              paste(sub("^attitude\\.", "", .FUNNEL_ATTITUDE_POSITIONS),
                    collapse = ", ")),
      "Short names are accepted, so 'love, prefer, price' is enough.",
      "See modules/brand/docs/FUNNEL_SPEC_v2.md."
    ),
    expected = paste(.FUNNEL_ATTITUDE_POSITIONS, collapse = ", "),
    observed = paste(bad, collapse = ", ")
  )
}


#' @keywords internal
.funnel_refuse_absent_roles <- function(bad, declared, cat_code) {
  have <- declared
  brand_refuse(
    code = "CFG_CONSIDERATION_ROLE_ABSENT",
    title = "Consideration Role Not On This Scale",
    problem = sprintf(
      "funnel_consideration_roles names %s, which the attitude scale for %s does not carry.",
      paste(bad, collapse = ", "), cat_code %||% "this category"),
    why_it_matters = paste(
      "Turas would have to compute the Consider stage without the level you",
      "asked for. That returns a stage that looks computed but is missing",
      "respondents you meant to include, which is worse than refusing."
    ),
    how_to_fix = c(
      sprintf("Levels declared on this scale: %s.",
              if (length(have) > 0) paste(have, collapse = ", ") else "(none)"),
      "Add the missing level to the OptionMap sheet (Scale = attitude_scale) with its Role, or",
      "drop it from funnel_consideration_roles in Brand_Config.xlsx Settings."
    ),
    expected = paste(have, collapse = ", "),
    missing = paste(bad, collapse = ", ")
  )
}


# ==============================================================================
# PUBLIC: derive_funnel_stages
# ==============================================================================

#' Derive per-respondent × per-brand logical matrices for every funnel stage
#'
#' Walks the ordered stage list for the category type, computing a matrix
#' (rows = respondents, cols = brands) for each stage. Each stage carries
#' its own survey response and is NOT ANDed into the next: the aggregate
#' funnel reports non-monotonic answers as recorded (see the comment in the
#' loop below, and validate_nesting()). The cumulative chain that the
#' nested views read is computed downstream in calculate_stage_metrics().
#' Stages whose required role is absent from the role map are dropped
#' silently with a warning recorded in the return value.
#'
#' @param data Data frame. Survey data (one row per respondent).
#' @param role_map Named list from load_role_map().
#' @param category_type Character. One of "transactional", "durable",
#'   "service".
#' @param brand_list Data frame with BrandCode column.
#' @param tenure_threshold Character. Value from the tenure OptionMap at or
#'   above which "long-tenured" is TRUE. NULL disables the tenure stage.
#' @param consideration_roles Character vector of attitude role names that
#'   make up the Consider stage. Defaults to
#'   \code{.FUNNEL_CONSIDERATION_ROLES}.
#' @param positive_attitude_codes Deprecated. Raw response codes, kept so a
#'   config written before 2026-09-06 keeps working. When supplied it
#'   replaces \code{consideration_roles} and is resolved through the same
#'   OptionMap path.
#'
#' @return List with:
#'   \item{stages}{Named list of stage entries, each a list with \code{key},
#'     \code{label}, \code{matrix} (logical, respondents × brands).}
#'   \item{warnings}{Character vector. Reasons for dropped stages.}
#'   \item{consideration}{Resolution record from
#'     \code{.funnel_resolve_consideration()}.}
#'   \item{category_type}{Echoed.}
#'
#' @export
derive_funnel_stages <- function(data, role_map, category_type,
                                 brand_list, tenure_threshold = NULL,
                                 cat_code = NULL,
                                 consideration_roles = NULL,
                                 positive_attitude_codes = NULL) {

  .check_category_type(category_type)
  .require_role_lookup(role_map, "funnel.awareness", cat_code)
  .require_role_lookup(role_map, "funnel.attitude", cat_code)

  # One resolution, one refusal point. Both the stage matrix below and the
  # meta the panel reports are built from this record.
  roles_are_default <- is.null(consideration_roles) ||
                        length(consideration_roles) == 0L
  roles <- if (roles_are_default) .FUNNEL_CONSIDERATION_ROLES else
             .funnel_normalise_consideration_roles(consideration_roles)
  consideration <- .funnel_resolve_consideration(
    attitude_entry    = .lookup_role(role_map, "funnel.attitude", cat_code),
    roles             = roles,
    roles_are_default = roles_are_default,
    codes             = positive_attitude_codes,
    cat_code          = cat_code)
  .funnel_report_consideration(consideration, cat_code)

  plan    <- .FUNNEL_STAGE_PLAN[[category_type]]
  brands  <- as.character(brand_list$BrandCode)
  n_resp  <- nrow(data)
  # See BrandCodeAlias in BRAND_CONFIG_GUIDE.md: opt-in fallback for
  # surveys where the per-brand column suffix or slot option value differs
  # from the canonical brand code.
  brand_aliases <- .brand_aliases_from_list(brand_list)

  stages_out <- list()
  warns      <- character(0)

  # AGGREGATE FUNNEL: each stage uses its own raw survey response matrix
  # (no AND with prior stages). The funnel narrows in aggregate because most
  # respondents are coherent (aware → positive → bought past 12m → bought past
  # 3m forms a nesting hierarchy for the majority), but non-monotonic answers
  # (e.g. respondent ticks "bought past 3m" but didn't tick the brand in the
  # awareness battery) are reported as recorded rather than forced into the
  # prior stage's intersection. This matches the explainer text in the panel
  # ("each stage is asked independently … the funnel narrows in aggregate, but
  # it is not a respondent journey") and the Romaniuk / Ehrenberg-Bass treatment
  # of aggregate-ratio funnels.
  #
  # Cumulative-AND behaviour (matrix & prev_mat) was removed 2026-05-24 after
  # it was found to silently drop ~11pp of IPK POS past-3m buyers vs the raw
  # BRANDPEN2 count. See validate_nesting() below, it now functions as a
  # genuine post-hoc check on the data rather than a tautology guaranteed by
  # the AND. Brands whose aggregate counts violate nesting are surfaced via
  # a PARTIAL warning in stage rendering rather than forcibly clamped.
  for (key in plan) {
    mat <- .derive_stage_matrix(
      key, data, role_map, brands, n_resp, category_type,
      tenure_threshold, cat_code, consideration$values,
      brand_aliases = brand_aliases)
    if (is.null(mat$matrix)) {
      warns <- c(warns, mat$warning)
      next
    }
    stages_out[[key]] <- list(
      key    = key,
      label  = .FUNNEL_DEFAULT_LABELS[[key]],
      matrix = mat$matrix
    )
  }

  list(stages = stages_out, warnings = warns,
       consideration = consideration, category_type = category_type)
}


#' Print the consideration resolution to the console
#'
#' Turas runs inside a Shiny app, so anything the operator has to act on is
#' written to the console as well as carried in the result (CLAUDE.md,
#' Deployment Context). A dropped default role and a deprecated code list are
#' both operator-visible facts, and neither degrades the run to PARTIAL.
#' @keywords internal
.funnel_report_consideration <- function(consideration, cat_code) {
  if (length(consideration$notes) == 0) return(invisible(FALSE))
  cat("\n=== TURAS BRAND: FUNNEL CONSIDER STAGE ===\n")
  cat("Category:", cat_code %||% "(single category)", "\n")
  for (n in consideration$notes) cat(" *", n, "\n")
  cat("Consider set:",
      if (length(consideration$roles_used) > 0)
        paste(consideration$roles_used, collapse = ", ") else "(empty)", "\n")
  cat("==========================================\n\n")
  invisible(TRUE)
}


#' Look up an entry in a role map, preferring per-category keys
#'
#' For v2 role maps, awareness for DSS lives at \code{funnel.awareness.DSS}.
#' This helper accepts the base role (\code{funnel.awareness}) plus a
#' category code and returns the per-category entry if present, else the
#' base entry (legacy compatibility), else NULL.
#'
#' @keywords internal
.lookup_role <- function(role_map, base_role, cat_code) {
  if (!is.null(cat_code) && nzchar(cat_code)) {
    keyed <- paste0(base_role, ".", cat_code)
    if (!is.null(role_map[[keyed]])) return(role_map[[keyed]])
  }
  role_map[[base_role]]
}


# ==============================================================================
# PUBLIC: validate_nesting
# ==============================================================================

#' Check whether each stage's aggregate count sits inside the previous one
#'
#' The stages are derived independently, so this is a genuine post-hoc
#' check on the data rather than a tautology: a brand whose count rises
#' between two stages has non-monotonic survey answers, which is an
#' operator-visible data fact, not a logic bug. It is reported as a
#' warning; nothing is clamped and nothing refuses (see the v3 note in the
#' body).
#'
#' @param stages Named list from derive_funnel_stages()$stages.
#' @param weights Numeric vector of respondent weights, or NULL.
#'
#' @return Invisibly, a list with \code{ok} (logical) and \code{warnings}
#'   (character vector, one line per non-monotonic brand and stage).
#'
#' @export
validate_nesting <- function(stages, weights = NULL) {
  if (length(stages) < 2) return(invisible(list(ok = TRUE, warnings = character(0))))
  w <- weights %||% rep(1, nrow(stages[[1]]$matrix))

  warnings_out <- character(0)
  keys <- names(stages)
  for (i in seq(2, length(keys))) {
    prev_mat <- stages[[keys[i - 1]]]$matrix
    curr_mat <- stages[[keys[i]]]$matrix
    prev_counts <- colSums(prev_mat * w, na.rm = TRUE)
    curr_counts <- colSums(curr_mat * w, na.rm = TRUE)
    # Skip brands where either stage is entirely NA (missing data column
    # for that brand-stage combination, e.g. retailer brand in awareness
    # battery has no matching per-brand attitude column). Such brands carry
    # NA through the pipeline rather than zero, so the nesting check
    # doesn't apply to them.
    prev_all_na <- colSums(!is.na(prev_mat)) == 0
    curr_all_na <- colSums(!is.na(curr_mat)) == 0
    skip <- prev_all_na | curr_all_na
    violations <- curr_counts > prev_counts + 1e-9 & !skip
    if (any(violations)) {
      bad <- which(violations)
      for (bi in bad) {
        warnings_out <- c(warnings_out, sprintf(
          "Brand %s: stage '%s' count (%.0f) exceeds stage '%s' count (%.0f), non-monotonic survey responses reported as recorded.",
          names(curr_counts)[bi], keys[i], curr_counts[bi],
          keys[i - 1], prev_counts[bi]))
      }
    }
  }
  # v3 (2026-05-24): aggregate funnel, non-monotonic stages no longer
  # refuse. Returns a structured result so callers can attach warnings to
  # the funnel result's $warnings field. Old loud-refusal behaviour was
  # removed alongside the cumulative-AND in derive_funnel_stages(), both
  # contradicted the panel's own explainer text ("each stage is asked
  # independently"; "the funnel narrows in aggregate, but it is not a
  # respondent journey"; non-monotonic answers should be reported, not
  # silently dropped).
  invisible(list(ok = length(warnings_out) == 0, warnings = warnings_out))
}


# ==============================================================================
# INTERNAL: ARG CHECKS
# ==============================================================================

.check_category_type <- function(category_type) {
  if (!(category_type %in% names(.FUNNEL_STAGE_PLAN))) {
    brand_refuse(
      code = "CFG_CATEGORY_TYPE_INVALID",
      title = "Unrecognised category.type",
      problem = sprintf("category.type = '%s' is not valid.", category_type),
      why_it_matters = paste(
        "The funnel's stage shape is determined by category type. Only",
        "transactional, durable, and service are defined."
      ),
      how_to_fix = paste(
        "Set category.type in Brand_Config.xlsx Settings to one of:",
        paste(names(.FUNNEL_STAGE_PLAN), collapse = ", ")
      ),
      expected = paste(names(.FUNNEL_STAGE_PLAN), collapse = ", "),
      observed = category_type
    )
  }
}


.require_role <- function(role_map, role_name) {
  if (!is.null(role_map[[role_name]])) return(invisible(TRUE))
  brand_refuse(
    code = "CFG_ROLE_MISSING",
    title = sprintf("Funnel Needs Role '%s'", role_name),
    problem = sprintf(
      "The funnel derivation requires role '%s', which is not declared in QuestionMap.",
      role_name),
    why_it_matters = paste(
      "Every funnel stage begins with awareness and attitude. Without these",
      "two roles, no stage can be derived."
    ),
    how_to_fix = c(
      sprintf("Add a QuestionMap row for role '%s'.", role_name),
      "See modules/brand/docs/ROLE_REGISTRY.md §4."
    ),
    missing = role_name
  )
}


#' Refuse if neither base role nor per-category role is present
#' @keywords internal
.require_role_lookup <- function(role_map, base_role, cat_code) {
  if (!is.null(.lookup_role(role_map, base_role, cat_code))) {
    return(invisible(TRUE))
  }
  keyed <- if (!is.null(cat_code) && nzchar(cat_code)) {
    paste0(base_role, ".", cat_code)
  } else base_role
  brand_refuse(
    code = "CFG_ROLE_MISSING",
    title = sprintf("Funnel Needs Role '%s'", keyed),
    problem = sprintf(
      "The funnel derivation requires role '%s', not present in role map.",
      keyed),
    why_it_matters = paste(
      "Every funnel stage begins with awareness and attitude. Without these",
      "two roles, no stage can be derived."
    ),
    how_to_fix = c(
      sprintf("Confirm '%s' question root is registered in Survey_Structure.",
              gsub("\\.", "_", keyed)),
      "Convention-first inference resolves this automatically when the",
      "Questions sheet contains the canonical naming.",
      "See modules/brand/templates/README.md for the convention table."
    ),
    missing = keyed
  )
}


# ==============================================================================
# INTERNAL: PER-STAGE DERIVATION
# ==============================================================================

#' Derive a single stage's per-respondent × per-brand matrix
#'
#' Returns either \code{list(matrix = <logical matrix>)} or
#' \code{list(matrix = NULL, warning = "...")} when the stage's required
#' role is absent. Callers decide what to do (the public entry drops the
#' stage and keeps going).
#'
#' @keywords internal
.derive_stage_matrix <- function(key, data, role_map, brands, n_resp,
                                 category_type, tenure_threshold,
                                 cat_code, consideration_values,
                                 brand_aliases = NULL) {

  switch(key,
    aware = list(matrix = .stage_awareness(
      role_map, data, brands, n_resp, cat_code, brand_aliases)),
    consideration = list(matrix = .stage_consideration(
      role_map, data, brands, n_resp, cat_code, consideration_values,
      brand_aliases)),

    bought_long = .stage_penetration_long(
      role_map, data, brands, n_resp, cat_code, brand_aliases),
    bought_target = .stage_penetration_target(
      role_map, data, brands, n_resp, cat_code, brand_aliases),

    current_owner_d = .single_response_brand_match_stage(
      role_map, "funnel.durable.current_owner",
      data, brands, n_resp, "Current owner", cat_code, brand_aliases),
    long_tenured_d = .tenure_stage(
      role_map, "funnel.durable.tenure", data, brands, n_resp,
      tenure_threshold, "Long-tenured (durable)", cat_code, brand_aliases,
      owner_role = "funnel.durable.current_owner"),

    current_customer_s = .single_response_brand_match_stage(
      role_map, "funnel.service.current_customer",
      data, brands, n_resp, "Current customer", cat_code, brand_aliases),
    long_tenured_s = .tenure_stage(
      role_map, "funnel.service.tenure", data, brands, n_resp,
      tenure_threshold, "Long-tenured (service)", cat_code, brand_aliases,
      owner_role = "funnel.service.current_customer"),

    {
      # Programming-error sentinel: an unrecognised stage key has reached
      # this dispatcher despite the upstream plan validation. Should never
      # fire in normal operation, listed in PRODUCTION_REVIEW_BRAND.md I1
      # as an acceptable TRS-FALLBACK because the boxed brand_refuse path
      # is preferred and the stop() is the last-resort guard.
      msg <- sprintf("BUG_UNKNOWN_STAGE: Unknown funnel stage key '%s'. File a bug. This should not occur with valid config.", key)
      if (exists("brand_refuse", mode = "function")) {
        brand_refuse(code = "BUG_UNKNOWN_STAGE", title = "Unknown Funnel Stage Key",
                     problem = sprintf("Stage key '%s' has no handler in .derive_stage_matrix()", key),
                     why_it_matters = "An unrecognised key in the execution plan means no stage data will be produced.",
                     how_to_fix = "This is an internal error. File a bug report. The key should never reach this function unless the plan was corrupted.")
      } else {
        stop(msg, call. = FALSE)  # TRS-FALLBACK: bootstrap path only
      }
    }
  )
}


# ==============================================================================
# STAGE BUILDERS: V2 (use 00_data_access.R helpers)
# ==============================================================================

#' Awareness stage: slot-indexed Multi_Mention root
#' @keywords internal
.stage_awareness <- function(role_map, data, brands, n_resp, cat_code,
                             brand_aliases = NULL) {
  entry <- .lookup_role(role_map, "funnel.awareness", cat_code)
  .multi_mention_or_empty(entry, data, brands, n_resp, brand_aliases)
}

#' Consideration stage: the resolved consideration set
#'
#' A respondent passes the Consider stage for a brand when their answer to
#' the per-brand attitude question sits at one of the scale positions named
#' by the consideration set. The set arrives already resolved, by
#' \code{.funnel_resolve_consideration()} in this file, so this function has
#' one matching path and no fallback: it matches lowercased, trimmed response
#' values against \code{consideration_values}.
#'
#' The resolution is alias-aware via \code{.option_map_by_role()} in
#' 03b_funnel_metrics.R, so a survey that exports some attitude columns as
#' numeric codes ("1", "2") and others as text labels ("love", "prefer")
#' resolves the same way. Before 2026-09-06 that resolution ran only when the
#' config had not overridden the set, and an override was matched literally,
#' which returned an empty stage on a label-encoded category.
#'
#' Mental Penetration (≥1 CEP linkage, per Romaniuk Better Brand Health)
#' is reported separately on the Mental Availability tab, not in the
#' funnel.
#' @keywords internal
.stage_consideration <- function(role_map, data, brands, n_resp, cat_code,
                                 consideration_values, brand_aliases = NULL) {
  entry <- .lookup_role(role_map, "funnel.attitude", cat_code)
  if (is.null(entry)) return(.empty_brand_matrix(brands, n_resp))
  if (isTRUE(entry$per_brand)) {
    mat <- single_response_brand_matrix(data, entry$client_code,
                                        entry$category, brands,
                                        brand_aliases = brand_aliases)
    out <- matrix(FALSE, n_resp, length(brands),
                  dimnames = list(NULL, brands))

    positive_vals <- tolower(trimws(as.character(
      consideration_values %||% character(0))))
    positive_vals <- unique(positive_vals[!is.na(positive_vals) &
                                            nzchar(positive_vals)])

    # When a brand has NO per-brand attitude column (column-name mismatch
    # between awareness and attitude, e.g. PAS list contains WWT but data
    # exports BRANDATT1_PAS_WWPS only), single_response_brand_matrix returns
    # an all-NA column for that brand. Treating that as FALSE silently
    # collapses every downstream stage to 0% AND trips the nesting check
    # against bought_long. Mark these columns NA on the consideration
    # matrix so the metrics layer reports NA (not 0) and nesting skips them.
    for (b in brands) {
      raw_b <- mat[, b]
      if (all(is.na(raw_b))) {
        out[, b] <- NA
        next
      }
      vals <- tolower(trimws(as.character(raw_b)))
      out[, b] <- !is.na(vals) & vals %in% positive_vals
    }
    out
  } else {
    .empty_brand_matrix(brands, n_resp)
  }
}

#' Penetration long-window: slot-indexed Multi_Mention
#' @keywords internal
.stage_penetration_long <- function(role_map, data, brands, n_resp, cat_code,
                                    brand_aliases = NULL) {
  entry <- .lookup_role(role_map, "funnel.penetration_long", cat_code)
  if (is.null(entry)) {
    return(list(matrix = NULL,
                warning = sprintf(
                  "Stage 'Long Period' dropped: penetration_long role for %s absent.",
                  cat_code %||% "(no cat)")))
  }
  list(matrix = .multi_mention_or_empty(entry, data, brands, n_resp,
                                         brand_aliases))
}

#' Penetration target window: slot-indexed Multi_Mention
#' @keywords internal
.stage_penetration_target <- function(role_map, data, brands, n_resp,
                                      cat_code, brand_aliases = NULL) {
  entry <- .lookup_role(role_map, "funnel.penetration_target", cat_code)
  if (is.null(entry)) {
    return(list(matrix = NULL,
                warning = sprintf(
                  "Stage 'Target Period' dropped: penetration_target role for %s absent.",
                  cat_code %||% "(no cat)")))
  }
  list(matrix = .multi_mention_or_empty(entry, data, brands, n_resp,
                                         brand_aliases))
}

#' Resolve a Multi_Mention entry to a respondent × brand logical matrix
#' @keywords internal
.multi_mention_or_empty <- function(entry, data, brands, n_resp,
                                     brand_aliases = NULL) {
  if (is.null(entry) || is.null(entry$column_root)) {
    return(.empty_brand_matrix(brands, n_resp))
  }
  multi_mention_brand_matrix(data, entry$column_root, brands,
                              brand_aliases = brand_aliases)
}

.empty_brand_matrix <- function(brands, n_resp) {
  matrix(FALSE, nrow = n_resp, ncol = length(brands),
         dimnames = list(NULL, brands))
}


#' Single-response respondent-level role where value is a brand code
#'
#' Used for durable / service "current owner / customer" stages where a single
#' column holds the respondent's chosen brand. Reads entry$columns[1] for v2
#' entries (column_root for per-category single-response) or falls back to
#' the legacy entry$columns[1] semantics.
#'
#' @keywords internal
.single_response_brand_match_stage <- function(role_map, role_name,
                                               data, brands, n_resp, label,
                                               cat_code = NULL,
                                               brand_aliases = NULL) {
  entry <- .lookup_role(role_map, role_name, cat_code)
  if (is.null(entry)) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: role '%s' absent.",
                                  label, role_name)))
  }
  col <- if (length(entry$columns) > 0) entry$columns[1] else entry$column_root
  if (is.null(col) || !(col %in% names(data))) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: column '%s' not in data.",
                                  label, col %||% "(NULL)")))
  }
  vals <- as.character(data[[col]])
  mat <- matrix(FALSE, nrow = n_resp, ncol = length(brands),
                dimnames = list(NULL, brands))
  for (b in brands) {
    targets <- b
    if (!is.null(brand_aliases) && b %in% names(brand_aliases)) {
      alias <- as.character(brand_aliases[[b]])
      if (!is.na(alias) && nzchar(trimws(alias)) && !identical(alias, b))
        targets <- c(b, alias)
    }
    mat[, b] <- !is.na(vals) & vals %in% targets
  }
  list(matrix = mat)
}


#' Tenure stage (durable/service): respondent's tenure ≥ threshold,
#' coupled to current-owner / current-customer for brand specificity
#'
#' Tenure is a single numeric column with no brand information of its own.
#' it's the answer to "how long have you owned/used your current brand?".
#' Brand specificity comes from the paired current_owner_d (durable) /
#' current_customer_s (service) column, which says WHICH brand the
#' respondent uses. The two columns together define this stage:
#'   mat[i, b] = (current_owner[i] == b) AND (tenure[i] >= threshold)
#'
#' This is a definitional coupling at the stage level, composing the
#' two source questions to derive the stage's brand×respondent matrix,
#' not a cumulative-AND across funnel stages. See the AGGREGATE FUNNEL
#' note in derive_funnel_stages() for the distinction.
#'
#' @keywords internal
.tenure_stage <- function(role_map, role_name, data, brands, n_resp,
                          tenure_threshold, label, cat_code = NULL,
                          brand_aliases = NULL,
                          owner_role = NULL) {
  entry <- .lookup_role(role_map, role_name, cat_code)
  if (is.null(entry) || is.null(tenure_threshold) ||
      !nzchar(trimws(as.character(tenure_threshold)))) {
    return(list(matrix = NULL,
                warning = sprintf(
                  "Stage '%s' dropped: role '%s' or tenure_threshold absent.",
                  label, role_name)))
  }
  col <- if (length(entry$columns) > 0) entry$columns[1] else entry$column_root
  if (is.null(col) || !(col %in% names(data))) {
    return(list(matrix = NULL,
                warning = sprintf("Stage '%s' dropped: column '%s' not in data.",
                                  label, col %||% "(NULL)")))
  }

  vals <- suppressWarnings(as.numeric(data[[col]]))
  thr <- suppressWarnings(as.numeric(tenure_threshold))
  long <- !is.na(vals) & !is.na(thr) & vals >= thr

  # Look up the paired owner / customer role for brand specificity.
  # Without it, tenure has no per-brand meaning (every brand would
  # receive the same flag for every long-tenured respondent).
  owner_entry <- if (!is.null(owner_role))
    .lookup_role(role_map, owner_role, cat_code) else NULL
  if (is.null(owner_entry)) {
    # No paired owner role: fall back to brand-agnostic (every brand gets
    # the same long-tenured flag). Surfaces a warning so the operator
    # notices.
    mat <- matrix(FALSE, nrow = n_resp, ncol = length(brands),
                  dimnames = list(NULL, brands))
    for (b in brands) mat[, b] <- long
    return(list(matrix = mat,
                warning = sprintf(
                  "Stage '%s': paired owner/customer role absent, tenure flag applied to every brand identically.",
                  label)))
  }

  owner_col <- if (length(owner_entry$columns) > 0) owner_entry$columns[1]
               else owner_entry$column_root
  if (is.null(owner_col) || !(owner_col %in% names(data))) {
    mat <- matrix(FALSE, nrow = n_resp, ncol = length(brands),
                  dimnames = list(NULL, brands))
    for (b in brands) mat[, b] <- long
    return(list(matrix = mat,
                warning = sprintf(
                  "Stage '%s': owner column '%s' not in data, tenure flag applied to every brand identically.",
                  label, owner_col %||% "(NULL)")))
  }

  owner_vals <- as.character(data[[owner_col]])
  mat <- matrix(FALSE, nrow = n_resp, ncol = length(brands),
                dimnames = list(NULL, brands))
  for (b in brands) {
    targets <- b
    if (!is.null(brand_aliases) && b %in% names(brand_aliases)) {
      alias <- as.character(brand_aliases[[b]])
      if (!is.na(alias) && nzchar(trimws(alias)) && !identical(alias, b))
        targets <- c(b, alias)
    }
    mat[, b] <- long & !is.na(owner_vals) & owner_vals %in% targets
  }
  list(matrix = mat)
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand funnel derive loaded (v%s)",
                  BRAND_FUNNEL_DERIVE_VERSION))
}
