# vas_channel_use.R
# ------------------------------------------------------------------------------
# Three tables off two questions: total used, most often, also used.
#
# Every occasion asks two channel questions - the one channel used MOST OFTEN
# (single choice) and the ones used WHERE ELSE in the past 12 months (multi).
# The second question does not exclude the first: 119 of the 477 people whose
# main electricity channel is the bank app ticked the bank app again under
# "where else", so reading the two tables side by side double-counts them
# (62.2% + 30.4% reads as 93% when the truth is 77.1%).
#
# So two derived questions per occasion, both built from the answers already
# given, neither asked:
#
#   <Occasion>ChannelEver  total used  - main OR also, each channel once
#   <Occasion>ChannelAlso  also used   - also, MINUS the main channel
#
# With the raw "where else" question set aside, the three tables that remain
# carry the same rows in the same order on the same base, and Ever = Main +
# Also for every channel, by construction.
#
# "Nowhere else" is RECOMPUTED on the Also table rather than carried over:
# someone whose only "where else" tick was their own main channel uses one
# channel, and the table should say so. On the current electricity data that
# moves the row from the 116 who ticked it to the 154 who mean it.
# ------------------------------------------------------------------------------

# The last option of every "where else" question, and the row the Also table
# rebuilds for itself.
VAS_CHANNEL_NOWHERE <- "Nowhere else"

# The naming convention the pairing works from. Thirteen occasions name the
# partner "<stem>ChannelOther"; prepaid electricity names it "PPUOthChannel".
# Both spellings are looked for, and the option lists are then checked - a
# partner that offers different channels is refused, not used.
VAS_CHANNEL_MAIN_SUFFIX <- "ChannelMain"
VAS_CHANNEL_PARTNER_SUFFIXES <- c("ChannelOther", "OthChannel", "ChannelOth")

#' Blank cells as missing
#'
#' An export writes an unticked checkbox as an empty string in some columns and
#' as NA in others. Both mean "not ticked" and must count the same, or a whole
#' channel reads as used by everyone.
#'
#' @param x A character vector.
#'
#' @return The vector with empty and whitespace-only elements as NA.
blank_as_na <- function(x) {
  x <- as.character(x)
  x[!is.na(x) & !nzchar(trimws(x))] <- NA_character_
  return(x)
}

#' The option values of one question, in display order
#'
#' Multi_Mention options are stored per member column (\code{Q_1}, \code{Q_2},
#' ...), one option each; a single-response question keeps them all under its
#' own code. This returns whichever applies, ordered.
#'
#' @param options The Options data frame.
#' @param code The question code.
#' @param columns The declared column count; 1 for a single-response question.
#'
#' @return A data frame of \code{value} and \code{title}, one row per option.
channel_option_list <- function(options, code, columns) {
  if (columns > 1L) {
    rows <- do.call(rbind, lapply(seq_len(columns), function(i) {
      member <- options[options$QuestionCode == sprintf("%s_%d", code, i), , drop = FALSE]
      if (!nrow(member)) {
        return(data.frame(value = NA_character_, title = NA_character_,
                          stringsAsFactors = FALSE))
      }
      data.frame(value = member$OptionText[1], title = member$DisplayText[1],
                 stringsAsFactors = FALSE)
    }))
    return(rows)
  }
  member <- options[options$QuestionCode == code, , drop = FALSE]
  member <- member[order(member$DisplayOrder), , drop = FALSE]
  return(data.frame(value = member$OptionText, title = member$DisplayText,
                    stringsAsFactors = FALSE))
}

#' Pair each "most often" question with its "where else" partner
#'
#' Found by name, then CHECKED against the option lists: the partner must offer
#' the same channels as the "most often" question, plus "Nowhere else". Order is
#' not required to match, and on this study it does not - Lotto asks LOTTO
#' Website before LOTTO App in one question and after it in the other, so the
#' member columns are looked up by option VALUE, never by position.
#'
#' @param questions The Questions data frame.
#' @param options The Options data frame.
#'
#' @return A data frame: main, other, ever, also, channels (option count of the
#'   Ever question), members (option count of the Also question).
#'
#' @throws Stops with class "vas_channel_unpaired" naming every "most often"
#'   question it could not pair and why, rather than quietly building fewer
#'   tables than the report expects.
find_channel_pairs <- function(questions, options) {
  mains <- questions$QuestionCode[
    questions$Variable_Type == "Single_Response" &
      endsWith(questions$QuestionCode, VAS_CHANNEL_MAIN_SUFFIX)]
  if (!length(mains)) {
    return(data.frame(main = character(0), other = character(0),
                      ever = character(0), also = character(0),
                      channels = integer(0), members = integer(0),
                      stringsAsFactors = FALSE))
  }

  multis <- questions[questions$Variable_Type == "Multi_Mention", , drop = FALSE]
  rows <- list()
  unpaired <- character(0)
  for (main in mains) {
    stem <- sub(sprintf("%s$", VAS_CHANNEL_MAIN_SUFFIX), "", main)
    partners <- intersect(paste0(stem, VAS_CHANNEL_PARTNER_SUFFIXES),
                          multis$QuestionCode)
    if (length(partners) != 1L) {
      unpaired <- c(unpaired, sprintf(
        "%s - %s multi-mention question named %s", main,
        if (length(partners)) "several" else "no",
        paste(paste0(stem, VAS_CHANNEL_PARTNER_SUFFIXES), collapse = " / ")))
      next
    }

    columns <- as.integer(multis$Columns[match(partners, multis$QuestionCode)])
    main_opts <- channel_option_list(options, main, 1L)
    other_opts <- channel_option_list(options, partners, columns)
    wanted <- c(main_opts$value, VAS_CHANNEL_NOWHERE)
    if (length(other_opts$value) != length(wanted) ||
        !setequal(other_opts$value, wanted)) {
      unpaired <- c(unpaired, sprintf(
        "%s - %s offers different channels (only here: %s; only there: %s)",
        main, partners,
        paste(c(setdiff(wanted, other_opts$value), "-")[1], collapse = ", "),
        paste(c(setdiff(other_opts$value, wanted), "-")[1], collapse = ", ")))
      next
    }

    rows[[length(rows) + 1L]] <- data.frame(
      main = main, other = partners,
      ever = paste0(stem, "ChannelEver"), also = paste0(stem, "ChannelAlso"),
      channels = nrow(main_opts), members = length(wanted),
      stringsAsFactors = FALSE)
  }

  if (length(unpaired)) {
    stop(structure(class = c("vas_channel_unpaired", "error", "condition"), list(
      message = sprintf(paste0(
        "%d 'most often' channel question(s) could not be paired:\n  %s\n\n",
        "A partner is the multi-mention question offering the same channels ",
        "as the 'most often'\nquestion, with \"%s\" appended. Without one, the ",
        "total-used and also-used tables\ncannot be built for that occasion - ",
        "fix the option lists, or take the question out of\nthe '%s' naming."),
        length(unpaired), paste(unpaired, collapse = "\n  "),
        VAS_CHANNEL_NOWHERE, VAS_CHANNEL_MAIN_SUFFIX), call = NULL)))
  }

  pairs <- do.call(rbind, rows)

  # A code we would generate that already exists is a clash only when it is
  # something ELSE. A structure that has already been migrated declares these
  # questions exactly as they are built here, and re-reading it must be quiet -
  # the migration script reads the kept structure and runs this.
  wanted <- rbind(
    data.frame(code = pairs$ever, columns = pairs$channels, stringsAsFactors = FALSE),
    data.frame(code = pairs$also, columns = pairs$members, stringsAsFactors = FALSE))
  at <- match(wanted$code, questions$QuestionCode)
  present <- !is.na(at)
  ours <- rep(TRUE, nrow(wanted))
  ours[present] <- questions$Variable_Type[at[present]] == "Multi_Mention" &
    as.integer(questions$Columns[at[present]]) == wanted$columns[present]
  clash <- wanted$code[present & !ours]
  if (length(clash)) {
    stop(structure(class = c("vas_channel_code_clash", "error", "condition"), list(
      message = sprintf(paste0(
        "The derived channel question code(s) %s already exist in this study as ",
        "something else.\nRename the asked question, or these tables would ",
        "overwrite it."),
        paste(clash, collapse = ", ")), call = NULL)))
  }

  return(pairs)
}

#' The total-used and also-used columns for every paired occasion
#'
#' One member column per option, holding the option's value when it applies and
#' NA when it does not - the same shape the export writes for a checkbox, so
#' the engine reads them exactly as it reads an asked question.
#'
#' @param data The assembled data frame.
#' @param pairs The data frame from \code{find_channel_pairs()}.
#' @param options The Options data frame.
#'
#' @return A named list of character vectors, one per new member column.
channel_use_columns <- function(data, pairs, options) {
  new <- list()
  for (p in seq_len(nrow(pairs))) {
    pair <- pairs[p, ]
    # the "most often" question's order is the order all three tables use
    channels <- channel_option_list(options, pair$main, 1L)$value
    other_opts <- channel_option_list(options, pair$other, pair$members)

    main_values <- blank_as_na(data[[pair$main]])
    members <- lapply(seq_len(pair$members), function(i) {
      blank_as_na(data[[sprintf("%s_%d", pair$other, i)]])
    })
    # by option VALUE, because the two questions do not always list the
    # channels in the same order
    member_of <- function(option) members[[match(option, other_opts$value)]]

    answered <- !is.na(main_values) |
      Reduce(`|`, lapply(members, function(m) !is.na(m)))
    also_any <- rep(FALSE, nrow(data))

    for (i in seq_along(channels)) {
      option <- channels[i]
      is_main <- !is.na(main_values) & main_values == option
      is_other <- !is.na(member_of(option))
      # a channel used most often is a channel used, whether or not the
      # respondent listed it again
      new[[sprintf("%s_%d", pair$ever, i)]] <-
        ifelse(is_main | is_other, option, NA_character_)
      # ... and it is not an ADDITIONAL channel, which is what this table means
      also <- is_other & !is_main
      new[[sprintf("%s_%d", pair$also, i)]] <-
        ifelse(also, option, NA_character_)
      also_any <- also_any | also
    }

    # Recomputed, not carried over: whoever is left with no channel beyond the
    # one they use most often uses one channel, and the row says so.
    new[[sprintf("%s_%d", pair$also, pair$members)]] <-
      ifelse(answered & !also_any, VAS_CHANNEL_NOWHERE, NA_character_)
  }
  return(new)
}

#' The Questions and Options rows for the derived channel questions
#'
#' Both tables carry the "most often" question's own option text and display
#' order, so the three tables of an occasion read as one set of rows. The Also
#' table adds "Nowhere else" at the end.
#'
#' @param pairs The data frame from \code{find_channel_pairs()}.
#' @param questions The Questions data frame, for the asked wording.
#' @param options The Options data frame.
#'
#' @return A list of \code{questions} and \code{options} data frames, plus
#'   \code{after}, the question each block belongs behind.
channel_use_structure_rows <- function(pairs, questions, options) {
  question_rows <- list()
  option_rows <- list()
  for (p in seq_len(nrow(pairs))) {
    pair <- pairs[p, ]
    asked <- questions$QuestionText[match(pair$main, questions$QuestionCode)]
    # the "most often" question's own options and order, with "Nowhere else"
    # taken from the partner so its wording is the survey's
    opts <- channel_option_list(options, pair$main, 1L)
    other_opts <- channel_option_list(options, pair$other, pair$members)
    nowhere <- other_opts[match(VAS_CHANNEL_NOWHERE, other_opts$value), , drop = FALSE]
    opts <- rbind(opts, nowhere)

    question_rows[[length(question_rows) + 1L]] <- data.frame(
      QuestionCode = c(pair$ever, pair$also),
      QuestionText = c(channel_question_text(asked, "ever"),
                       channel_question_text(asked, "also")),
      Variable_Type = "Multi_Mention",
      Columns = c(pair$channels, pair$members),
      after = pair$other, stringsAsFactors = FALSE)

    for (i in seq_len(pair$channels)) {
      option_rows[[length(option_rows) + 1L]] <- data.frame(
        QuestionCode = sprintf("%s_%d", pair$ever, i),
        OptionText = opts$value[i], DisplayText = opts$title[i],
        DisplayOrder = i, after = pair$other, stringsAsFactors = FALSE)
    }
    for (i in seq_len(pair$members)) {
      option_rows[[length(option_rows) + 1L]] <- data.frame(
        QuestionCode = sprintf("%s_%d", pair$also, i),
        OptionText = opts$value[i], DisplayText = opts$title[i],
        DisplayOrder = i, after = pair$other, stringsAsFactors = FALSE)
    }
  }
  return(list(questions = do.call(rbind, question_rows),
              options = do.call(rbind, option_rows)))
}

#' Word a derived channel question from the asked one
#'
#' The generated text is a placeholder with the right meaning;
#' vas_report_labels.xlsx has the last word on what a reader sees.
#'
#' @param asked The "most often" question's text.
#' @param kind "ever" or "also".
#'
#' @return A single string.
channel_question_text <- function(asked, kind) {
  tail <- if (identical(kind, "ever")) {
    " at all? (used most often, or also used)"
  } else {
    " as well? (apart from the one used most often)"
  }
  reworded <- sub("\\s*most often\\s*\\?\\s*$", tail, asked)
  if (identical(reworded, asked)) {
    return(paste0(asked, tail))
  }
  return(reworded)
}

#' Splice blocks of rows in behind the question they belong to
#'
#' Keeps each occasion's tables together in a freshly generated structure, so
#' a report built from scratch reads total / most often / also in that order
#' rather than with the derived tables stranded at the end.
#'
#' @param base The rows to splice into.
#' @param block The rows to splice in, carrying an \code{after} column.
#' @param anchor A function taking the base data frame and one \code{after}
#'   value, returning the base row index to insert behind.
#'
#' @return The combined data frame, \code{after} dropped.
splice_after <- function(base, block, anchor) {
  if (is.null(block) || !nrow(block)) {
    return(base)
  }
  positions <- vapply(block$after, function(a) {
    at <- suppressWarnings(as.integer(anchor(base, a)))
    if (length(at) != 1L || is.na(at)) nrow(base) else at
  }, integer(1))
  block$.position <- positions
  block$.order <- seq_len(nrow(block))
  block <- block[order(block$.position, block$.order), , drop = FALSE]
  keep <- setdiff(names(block), c("after", ".position", ".order"))

  out <- list()
  cursor <- 0L
  for (at in unique(block$.position)) {
    if (at > cursor) {
      out[[length(out) + 1L]] <- base[(cursor + 1L):at, , drop = FALSE]
    }
    out[[length(out) + 1L]] <- block[block$.position == at, keep, drop = FALSE]
    cursor <- at
  }
  if (cursor < nrow(base)) {
    out[[length(out) + 1L]] <- base[(cursor + 1L):nrow(base), , drop = FALSE]
  }
  combined <- do.call(rbind, out)
  rownames(combined) <- NULL
  return(combined)
}

#' Add the derived channel questions to a structure and its data
#'
#' @param data The assembled data frame.
#' @param structure A list of \code{questions} and \code{options}.
#'
#' @return A list of \code{data}, \code{questions}, \code{options} and
#'   \code{pairs}.
add_channel_use <- function(data, structure) {
  pairs <- find_channel_pairs(structure$questions, structure$options)
  if (!nrow(pairs)) {
    return(list(data = data, questions = structure$questions,
                options = structure$options, pairs = pairs))
  }

  # content_structure_rows() describes the asked survey only, so a derived
  # channel question already sitting there means this ran twice - which would
  # overwrite the columns rather than add them.
  already <- intersect(c(pairs$ever, pairs$also), structure$questions$QuestionCode)
  if (length(already)) {
    stop(structure(class = c("vas_channel_already_added", "error", "condition"), list(
      message = sprintf(paste0(
        "The derived channel question(s) %s are already in this structure.\n",
        "add_channel_use() builds them from the asked questions and must run once."),
        paste(utils::head(already, 4), collapse = ", ")), call = NULL)))
  }

  columns <- channel_use_columns(data, pairs, structure$options)
  for (name in names(columns)) {
    data[[name]] <- columns[[name]]
  }

  rows <- channel_use_structure_rows(pairs, structure$questions, structure$options)
  questions <- splice_after(structure$questions, rows$questions,
                            function(base, a) match(a, base$QuestionCode))
  options <- splice_after(structure$options, rows$options, function(base, a) {
    hits <- grep(sprintf("^\\Q%s\\E_[0-9]+$", a), base$QuestionCode, perl = TRUE)
    if (length(hits)) max(hits) else nrow(base)
  })

  cat(sprintf("Channel use: %d occasion(s) gained a total-used and an also-used table (%d columns)\n",
              nrow(pairs), length(columns)))
  return(list(data = data, questions = questions, options = options, pairs = pairs))
}
