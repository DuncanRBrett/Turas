# vas_retailer_use.R
# ------------------------------------------------------------------------------
# Total retailers used, and other retailers with the main one stripped out.
#
# The survey asks two questions about where people go for till point and money
# market counter transactions: the retailer used MOST OFTEN (single choice,
# with an "I don't use a retailer ..." answer for people who go nowhere), and
# WHAT OTHER retailers they have used in the last 12 months (multi, with a
# "No other retailers" answer). The second does not exclude the first, so the
# two asked tables overlap and cannot be added: on the 1,104-response dataset
# 186 people who use Shoprite most often ticked Shoprite again under "other",
# so reading the two side by side makes Shoprite 958 when the truth is 772.
#
#   RetailerEver  total used  - most often OR other, each retailer counted once
#   RetailerAlso  also used   - other, MINUS the retailer used most often
#
# Ever = Main + Also for every retailer, by construction.
#
# TWO RULES THIS FILE SETTLES, both checked against the live data first:
#
#   * The non-user answer is a row on the TOTAL table and nothing on the Also
#     table. The 93 people who answered "I don't use a retailer" ticked nothing
#     at all in the other question - they were not asked it - so they are out
#     of the Also base entirely. "No other retailers" then means "uses exactly
#     one retailer", which is what a reader takes it to mean, rather than
#     silently including 93 people who use none. All 71 who ticked "No other
#     retailers" name a real retailer as their main one; the two groups do not
#     overlap.
#   * "No other retailers" is RECOMPUTED, not carried over, the same way the
#     channel tables recompute "Nowhere else": someone whose only "other" tick
#     was their own main retailer uses one retailer, and the row should say so.
# ------------------------------------------------------------------------------

# This study's one pair. Named outright rather than found by a suffix
# convention: there is exactly one, and a convention that matched something
# else would build a table nobody asked for.
VAS_RETAILER_MAIN <- "RetailerMain"
VAS_RETAILER_OTHER <- "RetailerOther"
VAS_RETAILER_EVER <- "RetailerEver"
VAS_RETAILER_ALSO <- "RetailerAlso"

# The two answers that are not a retailer: the one on the "most often"
# question meaning the respondent uses none, and the one on the "what other"
# question meaning they use no second retailer.
VAS_RETAILER_NONUSER <- paste0("I don't use a retailer for till point or ",
                               "money market counter transactions")
VAS_RETAILER_NONE_OTHER <- "No other retailers"

#' Is this study's retailer pair present and the right shape?
#'
#' @param questions The Questions data frame.
#'
#' @return TRUE when both asked questions are there in the expected types.
has_retailer_pair <- function(questions) {
  main <- questions[questions$QuestionCode == VAS_RETAILER_MAIN, , drop = FALSE]
  other <- questions[questions$QuestionCode == VAS_RETAILER_OTHER, , drop = FALSE]
  return(nrow(main) == 1L && nrow(other) == 1L &&
           identical(main$Variable_Type[1], "Single_Response") &&
           identical(other$Variable_Type[1], "Multi_Mention"))
}

#' The retailers both questions offer, and the rows each derived table carries
#'
#' The "most often" question's order is the order both tables read in. Its
#' option list is checked against the partner's and a mismatch is refused
#' rather than used: a retailer offered by only one of the two would make Ever
#' = Main + Also false without anything saying so.
#'
#' @param options The Options data frame.
#' @param questions The Questions data frame, for the partner's column count.
#'
#' @return A list of \code{ever} and \code{also} data frames of \code{value}
#'   and \code{title}, and \code{other} - the partner's own option list, in the
#'   order its member columns sit in.
#'
#' @throws Stops with class "vas_retailer_options_differ".
retailer_option_lists <- function(options, questions) {
  columns <- as.integer(
    questions$Columns[match(VAS_RETAILER_OTHER, questions$QuestionCode)])
  main_opts <- channel_option_list(options, VAS_RETAILER_MAIN, 1L)
  other_opts <- channel_option_list(options, VAS_RETAILER_OTHER, columns)

  retailers <- main_opts[main_opts$value != VAS_RETAILER_NONUSER, , drop = FALSE]
  partners <- other_opts[other_opts$value != VAS_RETAILER_NONE_OTHER, , drop = FALSE]
  only_main <- setdiff(retailers$value, partners$value)
  only_other <- setdiff(partners$value, retailers$value)
  missing_sentinel <- c(
    if (!VAS_RETAILER_NONUSER %in% main_opts$value) VAS_RETAILER_NONUSER,
    if (!VAS_RETAILER_NONE_OTHER %in% other_opts$value) VAS_RETAILER_NONE_OTHER)
  if (length(only_main) || length(only_other) || length(missing_sentinel)) {
    stop(structure(class = c("vas_retailer_options_differ", "error", "condition"), list(
      message = sprintf(paste0(
        "%s and %s do not offer the same retailers.\n",
        "  only on the most-often question: %s\n",
        "  only on the what-other question: %s\n",
        "  expected answer(s) absent: %s\n\n",
        "The total-used and also-used tables are built by matching the two ",
        "option lists by\nVALUE, so they cannot be built until the lists ",
        "agree. Fix the option text, or\ntake the pair out of the %s / %s ",
        "naming."),
        VAS_RETAILER_MAIN, VAS_RETAILER_OTHER,
        paste(c(only_main, "-")[seq_len(max(1L, length(only_main)))], collapse = ", "),
        paste(c(only_other, "-")[seq_len(max(1L, length(only_other)))], collapse = ", "),
        paste(c(missing_sentinel, "-")[seq_len(max(1L, length(missing_sentinel)))],
              collapse = ", "),
        VAS_RETAILER_MAIN, VAS_RETAILER_OTHER), call = NULL)))
  }

  # The non-user answer leads the total table (it is the "most often" question's
  # own first option) and has no place on the also table. "No other retailers"
  # closes the also table, in the partner's own wording.
  none_row <- other_opts[other_opts$value == VAS_RETAILER_NONE_OTHER, , drop = FALSE]
  return(list(ever = main_opts,
              also = rbind(retailers, none_row),
              other = other_opts))
}

#' The total-used and also-used columns
#'
#' One member column per option, holding the option's value when it applies and
#' NA when it does not - the shape the export writes for a checkbox, so the
#' engine reads them exactly as it reads an asked question.
#'
#' @param data The assembled data frame.
#' @param lists The list from \code{retailer_option_lists()}.
#'
#' @return A named list of character vectors, one per new member column.
#'
#' @throws Stops with class "vas_retailer_nonuser_contradicted" when someone
#'   says they use no retailer and then names one.
retailer_use_columns <- function(data, lists) {
  main_values <- blank_as_na(data[[VAS_RETAILER_MAIN]])
  members <- lapply(seq_len(nrow(lists$other)), function(i) {
    blank_as_na(data[[sprintf("%s_%d", VAS_RETAILER_OTHER, i)]])
  })
  member_of <- function(option) {
    at <- match(option, lists$other$value)
    if (is.na(at)) return(rep(NA_character_, nrow(data)))
    return(members[[at]])
  }

  retailers <- lists$also$value[lists$also$value != VAS_RETAILER_NONE_OTHER]
  ticked_any <- Reduce(`|`, lapply(retailers, function(r) !is.na(member_of(r))))
  ticked_none <- !is.na(member_of(VAS_RETAILER_NONE_OTHER))

  # The two answers are mutually exclusive by the survey's own routing - a
  # non-user is never asked what other retailers they use - and on the
  # 1,104-response dataset not one respondent breaks it. If that ever stops
  # being true the routing has changed and both tables would be wrong, so say
  # so rather than pick a side.
  contradicted <- which(!is.na(main_values) & main_values == VAS_RETAILER_NONUSER &
                          ticked_any)
  if (length(contradicted)) {
    who <- if ("ResponseID" %in% names(data)) {
      paste(utils::head(data$ResponseID[contradicted], 8), collapse = ", ")
    } else {
      paste(utils::head(contradicted, 8), collapse = ", ")
    }
    stop(structure(class = c("vas_retailer_nonuser_contradicted", "error", "condition"), list(
      message = sprintf(paste0(
        "%d respondent(s) answered \"%s\" and then named a retailer under %s.\n",
        "  respondent(s): %s\n\n",
        "The survey routes a non-user past the what-other question, so this ",
        "means the routing\nhas changed. Decide which answer stands before the ",
        "total-used table is built from\nboth - as it stands they would be ",
        "counted as using no retailer AND as using one."),
        length(contradicted), VAS_RETAILER_NONUSER, VAS_RETAILER_OTHER, who),
      call = NULL)))
  }

  new <- list()
  # TOTAL USED, in the most-often question's own order. The non-user row can
  # only come from that question; every retailer row is most-often OR other.
  for (i in seq_len(nrow(lists$ever))) {
    option <- lists$ever$value[i]
    is_main <- !is.na(main_values) & main_values == option
    is_other <- if (identical(option, VAS_RETAILER_NONUSER)) {
      rep(FALSE, nrow(data))
    } else {
      !is.na(member_of(option))
    }
    new[[sprintf("%s_%d", VAS_RETAILER_EVER, i)]] <-
      ifelse(is_main | is_other, option, NA_character_)
  }

  # ALSO USED. The base is whoever ANSWERED the what-other question - which is
  # every user and no non-user - not everyone who answered either question.
  asked <- ticked_any | ticked_none
  also_any <- rep(FALSE, nrow(data))
  for (i in seq_len(nrow(lists$also))) {
    option <- lists$also$value[i]
    if (identical(option, VAS_RETAILER_NONE_OTHER)) next
    is_main <- !is.na(main_values) & main_values == option
    also <- !is.na(member_of(option)) & !is_main
    new[[sprintf("%s_%d", VAS_RETAILER_ALSO, i)]] <-
      ifelse(also, option, NA_character_)
    also_any <- also_any | also
  }
  new[[sprintf("%s_%d", VAS_RETAILER_ALSO, nrow(lists$also))]] <-
    ifelse(asked & !also_any, VAS_RETAILER_NONE_OTHER, NA_character_)

  return(new)
}

#' The Questions and Options rows for the two derived retailer questions
#'
#' @param lists The list from \code{retailer_option_lists()}.
#'
#' @return A list of \code{questions} and \code{options} data frames, each
#'   carrying \code{after} - the asked question they belong behind.
retailer_use_structure_rows <- function(lists) {
  questions <- data.frame(
    QuestionCode = c(VAS_RETAILER_EVER, VAS_RETAILER_ALSO),
    QuestionText = c(
      paste0("All retailers used for till point or money market counter ",
             "transactions"),
      paste0("Other retailers used for till point or money market counter ",
             "transactions - apart from the one used most often")),
    Variable_Type = "Multi_Mention",
    Columns = c(nrow(lists$ever), nrow(lists$also)),
    after = VAS_RETAILER_OTHER, stringsAsFactors = FALSE)

  option_rows <- list()
  for (code in c(VAS_RETAILER_EVER, VAS_RETAILER_ALSO)) {
    opts <- if (identical(code, VAS_RETAILER_EVER)) lists$ever else lists$also
    for (i in seq_len(nrow(opts))) {
      option_rows[[length(option_rows) + 1L]] <- data.frame(
        QuestionCode = sprintf("%s_%d", code, i),
        OptionText = opts$value[i], DisplayText = opts$title[i],
        DisplayOrder = i, after = VAS_RETAILER_OTHER, stringsAsFactors = FALSE)
    }
  }
  return(list(questions = questions, options = do.call(rbind, option_rows)))
}

#' Add the derived retailer questions to a structure and its data
#'
#' @param data The assembled data frame.
#' @param structure A list of \code{questions} and \code{options}.
#'
#' @return A list of \code{data}, \code{questions} and \code{options}.
add_retailer_use <- function(data, structure) {
  if (!has_retailer_pair(structure$questions)) {
    return(list(data = data, questions = structure$questions,
                options = structure$options))
  }

  # content_structure_rows() describes the asked survey only, so a derived
  # retailer question already sitting there means this ran twice.
  already <- intersect(c(VAS_RETAILER_EVER, VAS_RETAILER_ALSO),
                       structure$questions$QuestionCode)
  if (length(already)) {
    stop(structure(class = c("vas_retailer_already_added", "error", "condition"), list(
      message = sprintf(paste0(
        "The derived retailer question(s) %s are already in this structure.\n",
        "add_retailer_use() builds them from the asked questions and must run once."),
        paste(already, collapse = ", ")), call = NULL)))
  }

  lists <- retailer_option_lists(structure$options, structure$questions)
  columns <- retailer_use_columns(data, lists)
  for (name in names(columns)) {
    data[[name]] <- columns[[name]]
  }

  rows <- retailer_use_structure_rows(lists)
  questions <- splice_after(structure$questions, rows$questions,
                            function(base, a) match(a, base$QuestionCode))
  options <- splice_after(structure$options, rows$options, function(base, a) {
    hits <- grep(sprintf("^\\Q%s\\E_[0-9]+$", a), base$QuestionCode, perl = TRUE)
    if (length(hits)) max(hits) else nrow(base)
  })

  cat(sprintf(paste0("Retailer use: a total-used and an also-used table ",
                     "(%d columns, %d retailers)\n"),
              length(columns), nrow(lists$also) - 1L))
  return(list(data = data, questions = questions, options = options))
}
