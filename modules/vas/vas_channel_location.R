# vas_channel_location.R
# ------------------------------------------------------------------------------
# Two location tables per section, folded from the channel tables that section
# already carries.
#
# Duncan, 19 Aug 2026: "please look at adding location (all (with duplication
# stripped out), and most often) for each channel set in the sections."
#
#   <Occasion>LocationEver  all locations used, each counted once
#   <Occasion>LocationMain  the location of the channel used most often
#
# The six locations are the ones the wallet split uses (VAS_LOCATIONS in
# vas_wallet_location.R), so a location means the same thing on a section page
# as it does on the wallet.
#
# THE DUPLICATION IS STRIPPED TWICE OVER, and neither is done here. The first
# strip is vas_channel_use.R's: <Occasion>ChannelEver already counts a channel
# once whether it was named as the main one, as a where-else one, or as both.
# The second falls out of the fold: a bank ATM and a bank app are two channels
# and one location, so a respondent who uses both counts once under Bank. This
# file folds the ALREADY-DEDUPLICATED Ever table, never the raw where-else
# question, so it inherits work that has been verified rather than redoing it.
#
# EVERY SECTION CARRIES ALL SIX LOCATIONS, even where a section offers no
# channel at one of them. The tables then read the same way section to section,
# and a location that is never used shows as zero rather than as a missing row.
#
# A MISSING ANSWER IS NOT "OTHER" HERE. Someone who never answered the channel
# question has no location, so LocationMain is NA for them and they are out of
# its base. That is the opposite of the wallet split, where money was spent and
# has to be placed somewhere - see vas_location_of().
# ------------------------------------------------------------------------------

VAS_LOCATION_EVER_SUFFIX <- "LocationEver"
VAS_LOCATION_MAIN_SUFFIX <- "LocationMain"

#' The location questions one channel pair produces
#'
#' @param pairs The data frame from \code{find_channel_pairs()}.
#'
#' @return The same data frame with \code{stem}, \code{location_ever} and
#'   \code{location_main} added.
channel_location_pairs <- function(pairs) {
  if (!nrow(pairs)) {
    return(cbind(pairs, stem = character(0), location_ever = character(0),
                 location_main = character(0)))
  }
  stem <- sub(sprintf("%s$", VAS_CHANNEL_MAIN_SUFFIX), "", pairs$main)
  pairs$stem <- stem
  pairs$location_ever <- paste0(stem, VAS_LOCATION_EVER_SUFFIX)
  pairs$location_main <- paste0(stem, VAS_LOCATION_MAIN_SUFFIX)
  return(pairs)
}

#' The location columns for every paired occasion
#'
#' The Ever table is one member column per location, holding the location's
#' label when the respondent used any channel there and NA when they did not -
#' the shape the export writes for a checkbox. The Main table is one column
#' holding the label, or NA where the respondent named no channel.
#'
#' @param data The assembled data frame.
#' @param pairs The data frame from \code{channel_location_pairs()}.
#' @param options The Options data frame, for the Ever table's option order.
#'
#' @return A named list of character vectors, one per new column.
#'
#' @throws Stops with class "vas_channel_location_main_not_in_ever" when a
#'   respondent's most-often location is missing from their own Ever table.
channel_location_columns <- function(data, pairs, options) {
  new <- list()
  for (p in seq_len(nrow(pairs))) {
    pair <- pairs[p, ]
    channels <- channel_option_list(options, pair$ever, pair$channels)$value
    members <- lapply(seq_along(channels), function(i) {
      blank_as_na(data[[sprintf("%s_%d", pair$ever, i)]])
    })
    at <- vas_location_of(channels)   # each channel's location, in Ever's order

    for (k in seq_len(nrow(VAS_LOCATIONS))) {
      key <- VAS_LOCATIONS$key[k]
      mine <- which(at == key)
      used <- if (!length(mine)) {
        rep(FALSE, nrow(data))
      } else {
        # a location is used once, however many of its channels were named
        Reduce(`|`, lapply(members[mine], function(m) !is.na(m)))
      }
      new[[sprintf("%s_%d", pair$location_ever, k)]] <-
        ifelse(used, VAS_LOCATIONS$label[k], NA_character_)
    }

    main_key <- vas_location_of(data[[pair$main]], missing = NA_character_)
    new[[pair$location_main]] <-
      VAS_LOCATIONS$label[match(main_key, VAS_LOCATIONS$key)]

    # The most-often channel is always in the Ever table by construction, so
    # its location must be in the Ever fold. If it is not, one of the two was
    # built from the wrong thing and the tables would disagree on the page.
    known <- !is.na(main_key)
    in_ever <- vapply(seq_len(nrow(data)), function(i) {
      if (!known[i]) return(TRUE)
      k <- match(main_key[i], VAS_LOCATIONS$key)
      !is.na(new[[sprintf("%s_%d", pair$location_ever, k)]][i])
    }, logical(1))
    off <- which(!in_ever)
    if (length(off)) {
      who <- if ("ResponseID" %in% names(data)) {
        paste(utils::head(data$ResponseID[off], 6), collapse = ", ")
      } else {
        paste(utils::head(off, 6), collapse = ", ")
      }
      stop(structure(class = c("vas_channel_location_main_not_in_ever", "error", "condition"), list(
        message = sprintf(paste0(
          "%d respondent(s) have a most-often location that is not in their own ",
          "%s table.\n  occasion:      %s\n  respondent(s): %s\n\n",
          "The most-often channel is part of the total-used table by ",
          "construction, so this\nmeans one of the two was folded from the ",
          "wrong question."),
          length(off), pair$location_ever, pair$main, who), call = NULL)))
    }
  }
  return(new)
}

#' The Questions and Options rows for the location tables
#'
#' @param pairs The data frame from \code{channel_location_pairs()}.
#' @param questions The Questions data frame, for the asked wording.
#'
#' @return A list of \code{questions} and \code{options} data frames, each
#'   carrying \code{after} - the question the block belongs behind.
channel_location_structure_rows <- function(pairs, questions) {
  question_rows <- list()
  option_rows <- list()
  for (p in seq_len(nrow(pairs))) {
    pair <- pairs[p, ]
    asked <- questions$QuestionText[match(pair$main, questions$QuestionCode)]
    question_rows[[length(question_rows) + 1L]] <- data.frame(
      QuestionCode = c(pair$location_ever, pair$location_main),
      QuestionText = c(channel_location_text(asked, "ever"),
                       channel_location_text(asked, "main")),
      Variable_Type = c("Multi_Mention", "Single_Response"),
      Columns = c(nrow(VAS_LOCATIONS), 1L),
      after = pair$also, stringsAsFactors = FALSE)

    for (k in seq_len(nrow(VAS_LOCATIONS))) {
      option_rows[[length(option_rows) + 1L]] <- data.frame(
        QuestionCode = sprintf("%s_%d", pair$location_ever, k),
        OptionText = VAS_LOCATIONS$label[k], DisplayText = VAS_LOCATIONS$label[k],
        DisplayOrder = k, after = pair$also, stringsAsFactors = FALSE)
    }
    for (k in seq_len(nrow(VAS_LOCATIONS))) {
      option_rows[[length(option_rows) + 1L]] <- data.frame(
        QuestionCode = pair$location_main,
        OptionText = VAS_LOCATIONS$label[k], DisplayText = VAS_LOCATIONS$label[k],
        DisplayOrder = k, after = pair$also, stringsAsFactors = FALSE)
    }
  }
  return(list(questions = do.call(rbind, question_rows),
              options = do.call(rbind, option_rows)))
}

#' Word a location question from the asked channel one
#'
#' The generated text is a placeholder with the right meaning;
#' vas_report_labels.xlsx has the last word on what a reader sees.
#'
#' @param asked The "most often" channel question's text.
#' @param kind "ever" or "main".
#'
#' @return A single string.
channel_location_text <- function(asked, kind) {
  tail <- if (identical(kind, "ever")) {
    " - all locations used"
  } else {
    " - the location used most often"
  }
  base <- sub("\\s*most often\\s*\\?\\s*$", "", asked)
  base <- sub("\\s*\\?\\s*$", "", base)
  return(paste0(base, tail))
}

#' Add the location tables to a structure and its data
#'
#' @param data The assembled data frame.
#' @param structure A list of \code{questions} and \code{options}.
#'
#' @return A list of \code{data}, \code{questions}, \code{options} and
#'   \code{pairs}.
add_channel_location <- function(data, structure) {
  pairs <- channel_location_pairs(find_channel_pairs(structure$questions,
                                                     structure$options))
  # The fold reads the DERIVED total-used table, so it can only run after
  # add_channel_use() has built it.
  ready <- pairs$ever %in% structure$questions$QuestionCode
  pairs <- pairs[ready, , drop = FALSE]
  if (!nrow(pairs)) {
    return(list(data = data, questions = structure$questions,
                options = structure$options, pairs = pairs))
  }

  already <- intersect(c(pairs$location_ever, pairs$location_main),
                       structure$questions$QuestionCode)
  if (length(already)) {
    stop(structure(class = c("vas_channel_location_already_added", "error", "condition"), list(
      message = sprintf(paste0(
        "The location question(s) %s are already in this structure.\n",
        "add_channel_location() folds them from the channel tables and must run once."),
        paste(utils::head(already, 4), collapse = ", ")), call = NULL)))
  }

  columns <- channel_location_columns(data, pairs, structure$options)
  for (name in names(columns)) {
    data[[name]] <- columns[[name]]
  }

  rows <- channel_location_structure_rows(pairs, structure$questions)
  questions <- splice_after(structure$questions, rows$questions,
                            function(base, a) match(a, base$QuestionCode))
  options <- splice_after(structure$options, rows$options, function(base, a) {
    hits <- grep(sprintf("^\\Q%s\\E_[0-9]+$", a), base$QuestionCode, perl = TRUE)
    if (length(hits)) max(hits) else nrow(base)
  })

  cat(sprintf("Channel location: %d occasion(s) gained an all-locations and a most-often table (%d columns)\n",
              nrow(pairs), length(columns)))
  return(list(data = data, questions = questions, options = options, pairs = pairs))
}
