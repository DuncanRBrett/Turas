# vas_bill_who_for.R
# ------------------------------------------------------------------------------
# One "who was this paid for?" table per bill type.
#
# The survey asks the question once for bills as a whole (`Bill`: myself /
# someone else / have not paid any), and the same shape exists for prepaid
# electricity (`PPU`), airtime and data. It is NOT asked per bill type - the
# survey instead asks two checkbox questions, BillOwnWhich and BillOthWhich,
# naming which bills the respondent pays for themselves and which for someone
# else. Those two feed the engine's per-category Own and Oth sides, so the
# answer is already in the data; it just has no table.
#
# This builds that table for every bill type, in the shape a checkbox question
# writes, so the crosstab engine reads it exactly as it reads an asked one:
#
#   <Category>_For_1   "Myself"             pays this bill for themselves
#   <Category>_For_2   "Someone else"       pays this bill for someone else
#   <Category>_For_3   "Have not paid any"  neither
#
# DERIVED FROM THE SIDES, NOT FROM A NEW READ OF THE CHECKBOXES. A respondent
# counts on a side when that side's derived transactions per month are above
# zero - the same test the config's own base filters use
# (`<Category>_Own_TxnPerMonth != 0`), so the who-for table and the for-self /
# for-others tables always agree on who is in them.
#
# The three options are mutually exhaustive by construction, so the table adds
# to more than 100% only where someone pays a bill on both sides, and never
# leaves a respondent out. On the 1,100-response August export the union of the
# two sides matched `<Category>_Purchased` exactly for all fourteen bill types
# - the check below reports it loudly on the console if that ever stops being
# true, because a reader comparing this table with the Yes/No one would see it.
# ------------------------------------------------------------------------------

# The three mentions, in display order. Worded as the asked `Bill` question
# words them, so the per-type tables and the overall one read as one set.
VAS_BILL_WHO_FOR_OPTIONS <- c("Myself", "Someone else", "Have not paid any")

# Appended to the category code. `BillMunicipal` -> `BillMunicipal_For`.
VAS_BILL_WHO_FOR_SUFFIX <- "_For"

# The per-side column the presence test reads, and the whole-category flag the
# consistency check compares against.
VAS_BILL_WHO_FOR_MEASURE <- "TxnPerMonth"

#' The bill categories that can carry a who-for table
#'
#' A category qualifies when the map collects both an Own and an Oth side for
#' it - without both there is nothing to tell apart - and the dataset carries
#' the three columns this reads. Bills are singled out by their category code
#' because they are the only occasions whose per-type breakdown is asked as a
#' checkbox list rather than as its own question set; electricity, airtime and
#' data each ask their own who-for question and already have a table.
#'
#' @param data The assembled data frame.
#' @param category_map The category map data frame.
#'
#' @return A data frame of \code{category} and \code{label}, in map order.
#'   Zero rows when nothing qualifies.
find_bill_who_for_categories <- function(data, category_map) {
  empty <- data.frame(category = character(0), label = character(0),
                      stringsAsFactors = FALSE)
  if (is.null(category_map) || !nrow(category_map)) {
    return(empty)
  }
  bills <- category_map[grepl("^Bill", category_map$category), , drop = FALSE]
  if (!nrow(bills)) {
    return(empty)
  }

  keep <- list()
  for (category in unique(bills$category)) {
    bases <- bills$base[bills$category == category]
    if (!all(c("Own", "Oth") %in% bases)) {
      next
    }
    needed <- c(bill_who_for_side_column(category, "Own"),
                bill_who_for_side_column(category, "Oth"),
                paste0(category, "_Purchased"))
    if (!all(needed %in% names(data))) {
      next
    }
    keep[[length(keep) + 1L]] <- data.frame(
      category = category,
      label = bills$label[bills$category == category][1],
      stringsAsFactors = FALSE)
  }
  if (!length(keep)) {
    return(empty)
  }
  out <- do.call(rbind, keep)
  rownames(out) <- NULL
  return(out)
}

#' The derived column one side of a category is read from
#'
#' @param category The category code.
#' @param base "Own" or "Oth".
#'
#' @return The column name.
bill_who_for_side_column <- function(category, base) {
  return(paste0(category, "_", base, "_", VAS_BILL_WHO_FOR_MEASURE))
}

#' Does this side transact at all?
#'
#' Above zero, and never NA: a respondent routed past the category has no
#' transactions, which is a genuine "no", not a missing answer.
#'
#' @param values The side's transactions-per-month column.
#'
#' @return A logical vector, one element per respondent, never NA.
bill_who_for_side_flag <- function(values) {
  numbers <- suppressWarnings(as.numeric(values))
  return(!is.na(numbers) & numbers > 0)
}

#' The member columns for every bill type's who-for table
#'
#' One column per option, holding the option's value where it applies and NA
#' where it does not - the shape an export writes for a checkbox, so nothing
#' downstream has to know these were derived.
#'
#' @param data The assembled data frame.
#' @param categories The data frame from \code{find_bill_who_for_categories()}.
#'
#' @return A named list of character vectors, one per new member column.
bill_who_for_columns <- function(data, categories) {
  columns <- list()
  for (i in seq_len(nrow(categories))) {
    category <- categories$category[i]
    own <- bill_who_for_side_flag(data[[bill_who_for_side_column(category, "Own")]])
    oth <- bill_who_for_side_flag(data[[bill_who_for_side_column(category, "Oth")]])
    mentions <- list(own, oth, !own & !oth)
    stem <- paste0(category, VAS_BILL_WHO_FOR_SUFFIX)
    for (member in seq_along(VAS_BILL_WHO_FOR_OPTIONS)) {
      columns[[sprintf("%s_%d", stem, member)]] <- ifelse(
        mentions[[member]], VAS_BILL_WHO_FOR_OPTIONS[member], NA_character_)
    }
  }
  return(columns)
}

#' Report any bill type whose two sides disagree with its Yes/No flag
#'
#' \code{<Category>_Purchased} is built from the category's Total and counts a
#' respondent whose figures are missing but who says they buy; the sides are
#' read from transactions alone. The two have matched exactly on every export
#' so far. If they ever stop matching, the who-for table would put someone in
#' "Have not paid any" whom the Yes/No table calls a payer - visible to any
#' reader holding the two tables side by side - so it is said out loud here
#' rather than left to be discovered in the report.
#'
#' @param data The assembled data frame.
#' @param categories The data frame from \code{find_bill_who_for_categories()}.
#'
#' @return The number of disagreeing respondents, invisibly.
report_bill_who_for_disagreement <- function(data, categories) {
  lines <- character(0)
  total <- 0L
  for (i in seq_len(nrow(categories))) {
    category <- categories$category[i]
    own <- bill_who_for_side_flag(data[[bill_who_for_side_column(category, "Own")]])
    oth <- bill_who_for_side_flag(data[[bill_who_for_side_column(category, "Oth")]])
    purchased <- as.character(data[[paste0(category, "_Purchased")]]) %in% "Yes"
    disagree <- sum((own | oth) != purchased)
    if (disagree > 0L) {
      total <- total + disagree
      lines <- c(lines, sprintf("│   %-16s %d respondent(s)", category, disagree))
    }
  }
  if (total > 0L) {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Context: VAS - who-for table per bill type\n")
    cat("│ Code: DATA_WHO_FOR_DISAGREES_WITH_PURCHASED\n")
    cat("│ Message: the two sides and the Yes/No flag do not agree:\n")
    cat(paste0(lines, "\n"), sep = "")
    cat("│ How to fix: the who-for table reads the sides, so it and the\n")
    cat("│          for-self / for-others tables agree. The Yes/No table will\n")
    cat("│          disagree with it for the respondents above - check whether\n")
    cat("│          their amount or frequency answers are incomplete before\n")
    cat("│          publishing the two side by side.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
  }
  return(invisible(total))
}

#' The Questions and Options rows for the derived who-for questions
#'
#' The generated wording is a placeholder with the right meaning;
#' vas_report_labels.xlsx has the last word on what a reader sees, exactly as
#' it does for the derived channel questions.
#'
#' @param categories The data frame from \code{find_bill_who_for_categories()}.
#'
#' @return A list of \code{questions} and \code{options} data frames, each
#'   carrying \code{after} - the question the block belongs behind.
bill_who_for_structure_rows <- function(categories) {
  question_rows <- list()
  option_rows <- list()
  for (i in seq_len(nrow(categories))) {
    category <- categories$category[i]
    code <- paste0(category, VAS_BILL_WHO_FOR_SUFFIX)
    after <- paste0(category, "_Purchased")

    question_rows[[length(question_rows) + 1L]] <- data.frame(
      QuestionCode = code,
      QuestionText = sprintf("Who %s was paid for?", tolower(categories$label[i])),
      Variable_Type = "Multi_Mention",
      Columns = length(VAS_BILL_WHO_FOR_OPTIONS),
      after = after, stringsAsFactors = FALSE)

    option_rows[[length(option_rows) + 1L]] <- data.frame(
      QuestionCode = sprintf("%s_%d", code, seq_along(VAS_BILL_WHO_FOR_OPTIONS)),
      OptionText = VAS_BILL_WHO_FOR_OPTIONS,
      DisplayText = VAS_BILL_WHO_FOR_OPTIONS,
      DisplayOrder = seq_along(VAS_BILL_WHO_FOR_OPTIONS),
      after = after, stringsAsFactors = FALSE)
  }
  if (!length(question_rows)) {
    return(NULL)
  }
  return(list(questions = do.call(rbind, question_rows),
              options = do.call(rbind, option_rows)))
}

#' Add the derived who-for questions to a structure and its data
#'
#' @param data The assembled data frame.
#' @param structure A list of \code{questions} and \code{options}.
#' @param category_map The category map data frame.
#'
#' @return A list of \code{data}, \code{questions}, \code{options} and
#'   \code{categories}.
#'
#' @throws Stops with class "vas_bill_who_for_already_added" when the structure
#'   already declares one of these questions - this builds them once, and a
#'   second run would overwrite the columns rather than add them.
add_bill_who_for <- function(data, structure, category_map) {
  categories <- find_bill_who_for_categories(data, category_map)
  if (!nrow(categories)) {
    return(list(data = data, questions = structure$questions,
                options = structure$options, categories = categories))
  }

  codes <- paste0(categories$category, VAS_BILL_WHO_FOR_SUFFIX)
  already <- intersect(codes, structure$questions$QuestionCode)
  if (length(already)) {
    stop(structure(class = c("vas_bill_who_for_already_added", "error", "condition"), list(
      message = sprintf(paste0(
        "The derived who-for question(s) %s are already in this structure.\n",
        "add_bill_who_for() builds them from the derived sides and must run once."),
        paste(utils::head(already, 4), collapse = ", ")), call = NULL)))
  }

  columns <- bill_who_for_columns(data, categories)
  for (name in names(columns)) {
    data[[name]] <- columns[[name]]
  }
  report_bill_who_for_disagreement(data, categories)

  rows <- bill_who_for_structure_rows(categories)
  questions <- splice_after(structure$questions, rows$questions,
                            function(base, a) match(a, base$QuestionCode))
  options <- splice_after(structure$options, rows$options, function(base, a) {
    hits <- which(base$QuestionCode == a)
    if (length(hits)) max(hits) else nrow(base)
  })

  cat(sprintf("Who for: %d bill type(s) gained a who-was-it-paid-for table (%d columns)\n",
              nrow(categories), length(columns)))
  return(list(data = data, questions = questions, options = options,
              categories = categories))
}
