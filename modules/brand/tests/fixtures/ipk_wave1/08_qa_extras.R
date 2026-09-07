# ==============================================================================
# IPK WAVE 1 FIXTURE: QA EXTRAS (opt-in, never part of the committed fixture)
# ==============================================================================
# Four analyses have never rendered through the five-destination shell with
# real panel fragments: Branded Reach, Ad Hoc, Audience Lens and Shopper
# Behaviour. The committed fixture carries none of them and the three
# synthetic example projects cannot run. Stage 6 closes that gap by generating
# a SECOND fixture, into a scratch directory, that does carry all four.
#
# Everything here is behind `extras = TRUE`. Nothing in this file runs when
# the committed fixture is regenerated, and nothing here draws a random number
# before the last of the existing builders has finished, so the committed
# fixture is unchanged to the value.
#
# ------------------------------------------------------------------------------
# PROVENANCE, WHICH MATTERS MORE THAN THE COVERAGE
# ------------------------------------------------------------------------------
# The fixture is modelled on IPK_Brand_Health_Wave_1-2.doc, the Wave 1
# questionnaire. Two of the four extras are faithful to it and two are not,
# and the difference is recorded on the face of the data rather than in a
# comment nobody reads.
#
# FAITHFUL. The instrument asked these, and the extras only re-shape answers
# the fixture already generates. No new random number is drawn for either.
#
#   Shopper Behaviour   Q63 "Where have you bought dry seasonings and spices
#                       in the last 3 months?" and Q64, the pack sizes bought.
#                       The fixture already stores both as slot-indexed code
#                       columns (CHANNEL_DSS_1..6, PACK_DSS_1..4). The shopper
#                       engine wants one 0/1 column per option, so the extras
#                       transpose the slots. Same answers, another shape.
#   Audience Lens       Q66, the brands bought (BRANDPEN2_DSS_1..16). The
#                       audience is focal-brand buyer against non-buyer, which
#                       is a cut of an answer the instrument collected.
#
# BEYOND THE INSTRUMENT. IPK Wave 1 asked no advertising or asset recognition
# question and no study-specific extra question. There is nothing to re-shape,
# so these two are invented outright:
#
#   Branded Reach       needs a seen question, a brand attribution question
#                       and a media question per asset.
#   Ad Hoc              needs a study-specific question with an option list.
#
# They exist ONLY to make the render path run, they are written ONLY into the
# scratch QA fixture, and every label they carry says so: the asset is called
# "QA synthetic asset", the ad hoc question text opens "QA synthetic
# question". Read out of a report they are unmistakable. Nothing here is
# presented as an IPK answer, and the committed fixture never sees them.
# ==============================================================================

IPK_EXTRAS_ASSETS <- list(
  list(code = "QAA1",
       label = "QA synthetic asset A (not asked in IPK Wave 1)"),
  list(code = "QAA2",
       label = "QA synthetic asset B (not asked in IPK Wave 1)")
)

IPK_EXTRAS_MEDIA <- list(
  list(code = "TV",     label = "Television"),
  list(code = "SOCIAL", label = "Social media"),
  list(code = "INSTORE", label = "In store"),
  list(code = "PRINT",  label = "Print")
)

IPK_EXTRAS_ADHOC_OPTIONS <- list(
  list(code = "1", label = "More often than a year ago"),
  list(code = "2", label = "About the same"),
  list(code = "3", label = "Less often than a year ago")
)

IPK_EXTRAS_ADHOC_CODE <- "ADHOC_FREQ"

# ------------------------------------------------------------------------------
# Data columns
# ------------------------------------------------------------------------------

#' Re-shape one set of slot-indexed code columns into one 0/1 column per code
#'
#' The fixture stores a multi-select as up to N slots each holding an option
#' code. \code{.shopper_to_binary_matrix()} in R/08e_shopper_behaviour.R wants
#' one numeric column per option. This is that transform and nothing else: no
#' answer is added, removed or changed, and no random number is drawn.
#'
#' @param data The assembled fixture data frame.
#' @param slot_root Root of the slot columns, e.g. "CHANNEL_DSS".
#' @param out_root Root of the columns to write, e.g. "SHOPLOC_DSS".
#' @param codes Character vector of option codes.
#' @return A data frame of \code{length(codes)} numeric 0/1 columns.
#' @keywords internal
.ipk_extras_slots_to_binary <- function(data, slot_root, out_root, codes) {
  slot_cols <- grep(sprintf("^%s_[0-9]+$", slot_root), names(data), value = TRUE)
  if (length(slot_cols) == 0L) {
    stop("No slot columns found for ", slot_root)
  }
  n <- nrow(data)
  out <- list()
  for (cd in codes) {
    hit <- rep(FALSE, n)
    for (sc in slot_cols) {
      v <- as.character(data[[sc]])
      hit <- hit | (!is.na(v) & v == cd)
    }
    out[[paste0(out_root, "_", cd)]] <- as.numeric(hit)
  }
  as.data.frame(out, stringsAsFactors = FALSE)
}

#' A single 0/1 indicator: did this respondent name the focal brand at Q66
#'
#' NA, not 0, for a respondent with no answer at all in the category, so the
#' non-buyer audience is people who answered and did not name the brand rather
#' than everybody the category never reached.
#'
#' @keywords internal
.ipk_extras_focal_buyer_flag <- function(data, slot_root, brand_code) {
  slot_cols <- grep(sprintf("^%s_[0-9]+$", slot_root), names(data), value = TRUE)
  if (length(slot_cols) == 0L) stop("No slot columns found for ", slot_root)
  n <- nrow(data)
  answered <- rep(FALSE, n)
  hit <- rep(FALSE, n)
  for (sc in slot_cols) {
    v <- as.character(data[[sc]])
    answered <- answered | !is.na(v)
    hit <- hit | (!is.na(v) & v == brand_code)
  }
  out <- rep(NA_real_, n)
  out[answered] <- 0
  out[hit] <- 1
  out
}

#' The two extras that had to be invented, drawn last so nothing else moves
#'
#' Called after every existing builder has finished, so the random stream that
#' produces the committed fixture is untouched. Its own seed is set here as
#' well, so the extras are reproducible whatever ran before them.
#'
#' @keywords internal
.ipk_extras_invented_columns <- function(data) {
  set.seed(IPK_FIXTURE_SEED + 1L)
  n <- nrow(data)
  brands <- IPK_BRANDS[[CAT_DSS]]
  media  <- vapply(IPK_EXTRAS_MEDIA, function(m) m$code, character(1))
  # Only respondents the category reached are shown an asset, which is what
  # the seen column's NA means to the engine: not shown, not "said no".
  shown <- !is.na(data[[paste0("BRANDPEN2_", CAT_DSS, "_1")]])
  out <- list()
  for (a in IPK_EXTRAS_ASSETS) {
    seen <- rep(NA_real_, n)
    seen[shown] <- rbinom(sum(shown), 1, 0.45)
    out[[paste0("BRSEEN_", a$code)]] <- seen
    # Brand attribution is a closed list: a real BrandCode, "DK" or "OTHER".
    # Anything else makes the misattribution step refuse, by design.
    attr_v <- rep(NA_character_, n)
    idx <- which(!is.na(seen) & seen == 1)
    if (length(idx)) {
      pool <- c(IPK_FOCAL_BRAND[[CAT_DSS]], sample(setdiff(brands, IPK_FOCAL_BRAND[[CAT_DSS]]), 3),
                "DK", "OTHER")
      attr_v[idx] <- sample(pool, length(idx), replace = TRUE,
                            prob = c(0.42, 0.14, 0.12, 0.10, 0.12, 0.10))
    }
    out[[paste0("BRBRAND_", a$code)]] <- attr_v
    med <- rep(NA_character_, n)
    if (length(idx)) {
      med[idx] <- vapply(idx, function(i) {
        k <- sample(1:2, 1, prob = c(0.7, 0.3))
        paste(sample(media, k), collapse = ",")
      }, character(1))
    }
    out[[paste0("BRMEDIA_", a$code)]] <- med
  }
  # The ad hoc question, asked of everyone the category reached.
  codes <- vapply(IPK_EXTRAS_ADHOC_OPTIONS, function(o) o$code, character(1))
  ah <- rep(NA_character_, n)
  ah[shown] <- sample(codes, sum(shown), replace = TRUE,
                      prob = c(0.28, 0.52, 0.20))
  out[[paste0(IPK_EXTRAS_ADHOC_CODE, "_", CAT_DSS)]] <- ah
  as.data.frame(out, stringsAsFactors = FALSE)
}

#' Every extra data column, faithful ones first
#'
#' @param data The assembled fixture data frame.
#' @return A data frame of new columns, same row count.
ipk_extras_data_columns <- function(data) {
  ch <- vapply(IPK_CHANNELS,   function(x) x$code, character(1))
  pk <- vapply(IPK_PACK_SIZES, function(x) x$code, character(1))
  faithful <- cbind(
    .ipk_extras_slots_to_binary(data, paste0("CHANNEL_", CAT_DSS),
                                paste0("SHOPLOC_", CAT_DSS), ch),
    .ipk_extras_slots_to_binary(data, paste0("PACK_", CAT_DSS),
                                paste0("SHOPPACK_", CAT_DSS), pk)
  )
  faithful[[paste0("ALBUYER_", CAT_DSS)]] <-
    .ipk_extras_focal_buyer_flag(data, paste0("BRANDPEN2_", CAT_DSS),
                                 IPK_FOCAL_BRAND[[CAT_DSS]])
  cbind(faithful, .ipk_extras_invented_columns(data))
}

# ------------------------------------------------------------------------------
# Structure sheets
# ------------------------------------------------------------------------------

#' QuestionMap rows for the shopper engine
#'
#' resolve_shopper_role_columns() in R/08e_shopper_behaviour.R reads
#' structure$questionmap directly and never consults the inferred role map, so
#' a literal QuestionMap sheet is the only way to reach it. ColumnPattern
#' substitutes {code} with ClientCode first, then {channel_code} or
#' {packsize_code} with each option code.
#'
#' @keywords internal
.ipk_extras_questionmap_df <- function() {
  data.frame(
    Role = c(paste0("channel.purchase.", CAT_DSS),
             paste0("cat_buying.packsize.", CAT_DSS)),
    ClientCode = c(paste0("SHOPLOC_", CAT_DSS), paste0("SHOPPACK_", CAT_DSS)),
    ColumnPattern = c("{code}_{channel_code}", "{code}_{packsize_code}"),
    stringsAsFactors = FALSE
  )
}

#' PackSizes under the column names the shopper engine actually reads
#'
#' .shopper_code_list_spec() keys on PackSizeCode and PackSizeLabel
#' (R/08e_shopper_behaviour.R lines 432 to 433). The committed fixture writes
#' PackCode and PackLabel, so the packsize list resolves to NULL even once a
#' QuestionMap exists. Both pairs are written here, so the sheet reads the
#' same to anything that already used the old names.
#'
#' @keywords internal
.ipk_extras_packs_df <- function() {
  df <- .ipk_build_packs_df()
  df$PackSizeCode  <- df$PackCode
  df$PackSizeLabel <- df$PackLabel
  df
}

#' The two paired audiences: focal-brand buyer against non-buyer
#'
#' @keywords internal
.ipk_extras_audience_lens_df <- function() {
  col <- paste0("ALBUYER_", CAT_DSS)
  data.frame(
    Category      = c(CAT_DSS, CAT_DSS),
    AudienceID    = c("dss_focal_buyer", "dss_focal_nonbuyer"),
    AudienceLabel = c("Bought the focal brand", "Did not buy the focal brand"),
    PairID        = c("dss_focal_pair", "dss_focal_pair"),
    PairRole      = c("A", "B"),
    FilterColumn  = c(col, col),
    FilterOp      = c("==", "=="),
    FilterValue   = c("1", "0"),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
.ipk_extras_marketing_reach_df <- function() {
  do.call(rbind, lapply(IPK_EXTRAS_ASSETS, function(a) data.frame(
    AssetCode         = a$code,
    AssetLabel        = a$label,
    Brand             = IPK_FOCAL_BRAND[[CAT_DSS]],
    Category          = CAT_DSS,
    SeenQuestionCode  = paste0("BRSEEN_",  a$code),
    BrandQuestionCode = paste0("BRBRAND_", a$code),
    MediaQuestionCode = paste0("BRMEDIA_", a$code),
    stringsAsFactors  = FALSE
  )))
}

#' @keywords internal
.ipk_extras_reach_media_df <- function() {
  do.call(rbind, lapply(seq_along(IPK_EXTRAS_MEDIA), function(i) {
    m <- IPK_EXTRAS_MEDIA[[i]]
    data.frame(MediaCode = m$code, MediaLabel = m$label,
               DisplayOrder = i, stringsAsFactors = FALSE)
  }))
}

#' The Questions row the ad hoc role is inferred from
#'
#' infer_role_map() reads ADHOC_{KEY}_{CAT} off the QuestionCode column
#' (R/00_role_inference.R lines 303 to 319). The key must be A to Z and 0 to 9
#' only.
#'
#' @keywords internal
.ipk_extras_questions_df <- function() {
  data.frame(
    QuestionCode  = paste0(IPK_EXTRAS_ADHOC_CODE, "_", CAT_DSS),
    QuestionText  = paste("QA synthetic question, not asked in IPK Wave 1.",
                          "Compared with a year ago, how often do you buy",
                          "dry seasonings and spices?"),
    Variable_Type = "Single",
    Columns       = 1,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
.ipk_extras_options_df <- function() {
  qc <- paste0(IPK_EXTRAS_ADHOC_CODE, "_", CAT_DSS)
  do.call(rbind, lapply(seq_along(IPK_EXTRAS_ADHOC_OPTIONS), function(i) {
    o <- IPK_EXTRAS_ADHOC_OPTIONS[[i]]
    data.frame(QuestionCode = qc, OptionText = o$code, DisplayText = o$label,
               DisplayOrder = i, ShowInOutput = "Y", stringsAsFactors = FALSE)
  }))
}

# ------------------------------------------------------------------------------
# The ungated variant
# ------------------------------------------------------------------------------
# Duncan's ruling of 7 September: Turas draws a nested funnel only when the
# QUESTIONNAIRE gated the questions. detect_instrument_gating() in
# R/03a_funnel_derive.R decides that from the respondent rows, not from the
# totals: one respondent who is at a later stage without the earlier one is
# proof the instrument did not route, because skip logic makes that row
# impossible.
#
# The fixture builds its attitude and purchase answers only over brands the
# respondent named as known, so it reads as gated and draws the nested funnel.
# The real IPK instrument did not gate, and a real IPK report therefore shows
# four separate measures with conversion ratios and a statement of why there
# is no funnel. Both modes have to be exercised, so this makes the second one.
#
# What it does is the smallest thing that flips the detector: it removes the
# focal brand from the AWARENESS slots of respondents who consider or bought
# it, leaving every other answer where it was. That is precisely the row an
# ungated instrument produces and a gated one cannot. It is a QA variant and
# is named as one; it is never written into the committed fixture.

#' Make the fixture read as an ungated instrument
#'
#' @param data The assembled fixture data frame.
#' @param cat_code Category code, e.g. "DSS".
#' @param brand_code The brand to unset awareness for.
#' @param n_rows How many respondents to breach. A handful is enough: the
#'   detector needs one.
#' @return The data frame with awareness slots cleared on those rows.
ipk_extras_make_ungated <- function(data, cat_code = CAT_DSS,
                                    brand_code = NULL, n_rows = 25L) {
  if (is.null(brand_code)) brand_code <- IPK_FOCAL_BRAND[[cat_code]]
  aware_cols <- grep(sprintf("^BRANDAWARE_%s_[0-9]+$", cat_code),
                     names(data), value = TRUE)
  att_cols <- grep(sprintf("^BRANDATT1_%s_%s$", cat_code, brand_code),
                   names(data), value = TRUE)
  if (length(aware_cols) == 0L || length(att_cols) == 0L) {
    stop("Cannot build the ungated variant: no awareness or attitude column")
  }
  aware_of <- rep(FALSE, nrow(data))
  for (cl in aware_cols) {
    v <- as.character(data[[cl]])
    aware_of <- aware_of | (!is.na(v) & v == brand_code)
  }
  # Respondents who are aware AND hold an attitude worth keeping. Removing
  # awareness from them leaves a consideration answer with no awareness
  # behind it, which is the impossible row.
  att <- data[[att_cols[1]]]
  cand <- which(aware_of & !is.na(att))
  if (length(cand) == 0L) stop("No candidate row for the ungated variant")
  set.seed(IPK_FIXTURE_SEED + 2L)
  pick <- if (length(cand) <= n_rows) cand else sort(sample(cand, n_rows))
  for (cl in aware_cols) {
    v <- as.character(data[[cl]])
    hit <- pick[!is.na(v[pick]) & v[pick] == brand_code]
    if (length(hit)) {
      v[hit] <- NA_character_
      data[[cl]] <- v
    }
  }
  attr(data, "ungated_rows") <- length(pick)
  data
}
