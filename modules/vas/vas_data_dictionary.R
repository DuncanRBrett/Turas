# vas_data_dictionary.R
# ------------------------------------------------------------------------------
# Generate the calculation documentation for every output column.
#
# This is built from the SAME category map and config the engine runs on, so it
# cannot drift from the code. Change the map or the config and the documentation
# changes with it - including the numbers, which are printed as the config
# actually holds them, not as they were when this was written.
#
# One row per output column: what it is, the exact arithmetic, which survey
# questions feed it, and how missing is distinguished from zero.
# ------------------------------------------------------------------------------

VAS_DICTIONARY_COLUMNS <- c("column", "group", "category", "base", "measure",
                            "unit", "description", "calculation",
                            "source_questions", "missing_rule")

#' Build one dictionary row
#'
#' @param column,group,category,base,measure,unit Identifying fields.
#' @param description Plain-English statement of what the column holds.
#' @param calculation The exact arithmetic, as text.
#' @param source_questions The survey aliases the column depends on.
#' @param missing_rule How blank, zero and missing are told apart.
#'
#' @return A one-row data frame.
dictionary_row <- function(column, group, category, base, measure, unit,
                           description, calculation, source_questions, missing_rule) {
  return(data.frame(
    column = column, group = group, category = category, base = base,
    measure = measure, unit = unit, description = description,
    calculation = calculation, source_questions = source_questions,
    missing_rule = missing_rule, stringsAsFactors = FALSE
  ))
}

#' Describe how transactions per month are derived for one map row
#'
#' @param row One row of the category map.
#' @param config The VAS_CONFIG list.
#'
#' @return A single character value, possibly multi-line.
describe_txn_calculation <- function(row, config) {
  if (!is.na(row$freq1)) {
    return(paste(
      sprintf('IF %s = "Once a week or more often"   THEN %s x %s',
              row$freq1, row$freq2, format(config$weeks_per_month, digits = 6)),
      sprintf('IF %s = "A few times in a month"      THEN %s', row$freq1, row$freq3),
      sprintf('IF %s = "Once per month"              THEN %s',
              row$freq1, config$once_per_month_value),
      sprintf('IF %s = "Less than once per month"    THEN %s / %s',
              row$freq1, row$freq4, config$months_per_year),
      sprintf('IF %s is blank                        THEN 0', row$freq1),
      sep = "\n"
    ))
  }
  cadence_rate <- config$cadence_txn_per_month[[row$assumed_cadence]]
  trigger <- if (!is.na(row$presence_alias)) {
    sprintf('"%s" is ticked on %s', row$presence_option, row$presence_alias)
  } else {
    sprintf("%s is answered", row$amount_alias)
  }
  if (!is.na(row$assumed_cadence)) {
    return(sprintf(
      "%s if %s, otherwise 0.\nThe survey asks no frequency here; the cadence is assumed %s.",
      format(cadence_rate, digits = 6), trigger, row$assumed_cadence))
  }
  return(sprintf("%s / %s\nThe count question asks how many were bought in the past 12 months.",
                 row$count_alias, config$months_per_year))
}

#' Describe how spend per transaction is derived for one map row
#'
#' @param row One row of the category map.
#' @param config The VAS_CONFIG list.
#' @param stem The output column stem, e.g. "Airtime_Own_".
#'
#' @return A single character value.
describe_per_txn_calculation <- function(row, config, stem) {
  if (identical(row$amount_basis, "imputed") && !is.na(row$count_alias)) {
    rate <- config$imputed_spend_per_leg[[row$category]]
    return(sprintf(
      'legs x R%s per leg, where legs = %s if %s = "Return" and %s if "One way".\nBlank %s is treated as %s leg.\nImputed: the survey collects no amount for this category.',
      format(rate, big.mark = ","), config$legs_per_trip$Return, row$legs_alias,
      config$legs_per_trip$`One way`, row$legs_alias, config$legs_default))
  }
  if (identical(row$amount_basis, "imputed")) {
    fee <- config$imputed_annual_fee[[row$category]]
    return(sprintf("R%s, the annual fee.\nImputed: the survey collects no amount and no frequency for this category.",
                   format(fee, big.mark = ",")))
  }
  if (identical(row$amount_basis, "monthly")) {
    return(sprintf("%sMonthlySpend / %sTxnPerMonth\nDERIVED, not reported: the respondent gave a monthly figure and was never asked a per-transaction one.",
                   stem, stem))
  }
  wording <- if (identical(row$amount_basis, "last_occasion")) {
    "The question asks what they paid LAST TIME, taken as the typical amount."
  } else {
    "The question asks what they usually spend each time."
  }
  return(sprintf("parse(%s)\n%s", row$amount_alias, wording))
}

#' Describe how monthly spend is derived for one map row
#'
#' @param row One row of the category map.
#' @param stem The output column stem.
#'
#' @return A single character value.
describe_spend_calculation <- function(row, stem) {
  if (identical(row$amount_basis, "monthly")) {
    return(sprintf("parse(%s)\nThe amount question already asks for a monthly figure, so it is taken as it stands.",
                   row$amount_alias))
  }
  if (identical(row$amount_basis, "imputed")) {
    return(sprintf("%sTxnPerMonth x %sSpendPerTxn", stem, stem))
  }
  return(sprintf("%sTxnPerMonth x parse(%s)", stem, row$amount_alias))
}

#' State how zero and missing are told apart for a transactions column
#'
#' The rule differs by how the frequency is established, so a category with no
#' frequency question is not described as though it had one.
#'
#' @param row One row of the category map.
#'
#' @return A single character value.
describe_txn_missing_rule <- function(row) {
  if (!is.na(row$freq1)) {
    return(sprintf('0 when %s is blank, meaning the respondent was routed past this category - a real zero, not a gap. Missing when the follow-up count is blank or "Don\'t know".',
                   row$freq1))
  }
  if (!is.na(row$assumed_cadence)) {
    return("0 when the respondent does not have this bill. NEVER missing: the cadence is assumed by the config, not asked, so anyone who has the bill gets a figure.")
  }
  return(sprintf("0 when %s is 0 or the question was not reached. Missing only if the count is not a number.",
                 row$count_alias))
}

#' State how zero and missing are told apart for a monthly spend column
#'
#' @param row One row of the category map.
#'
#' @return A single character value.
describe_spend_missing_rule <- function(row) {
  if (identical(row$amount_basis, "imputed")) {
    return("0 when the respondent does not have this category. NEVER missing: the amount is imputed from the config rather than collected, so it cannot fail to parse.")
  }
  return(sprintf("0 when the respondent was routed past this category. Missing when %s cannot be read, so an unreadable answer never counts as nothing spent.",
                 row$amount_alias))
}

#' State how zero and missing are told apart for a spend-per-transaction column
#'
#' @param row One row of the category map.
#'
#' @return A single character value.
describe_per_txn_missing_rule <- function(row) {
  if (identical(row$amount_basis, "imputed")) {
    return("Missing when there were no transactions. Otherwise always present, being an imputed rate rather than a reported amount.")
  }
  if (identical(row$amount_basis, "monthly")) {
    return("Missing when transactions per month is zero or missing, because there is then nothing to divide into.")
  }
  return(sprintf("Missing when %s cannot be read. Still reported when the FREQUENCY is unknown, because the respondent gave the amount even if they could not say how often.",
                 row$amount_alias))
}

#' Document the three measures of one collected category and base
#'
#' @param row One row of the category map.
#' @param config The VAS_CONFIG list.
#'
#' @return A three-row data frame.
dictionary_for_map_row <- function(row, config) {
  stem <- sprintf("%s_%s_", row$category, row$base)
  side <- switch(row$base, Own = "for themselves", Oth = "for someone else",
                 "combined, as the survey asks a single question")
  # The reader label's view marker. The prose above reads as a sentence ending;
  # a crosstab row needs a tag that survives being read on its own.
  view <- switch(row$base, Own = " (for self)", Oth = " (for others)",
                 " (for everyone)")
  sources <- paste(stats::na.omit(c(row$freq1, row$freq2, row$freq3, row$freq4,
                                    row$amount_alias, row$count_alias, row$legs_alias,
                                    row$presence_alias)), collapse = ", ")

  return(rbind(
    dictionary_row(paste0(stem, "TxnPerMonth"), "Category", row$category, row$base,
                   "TxnPerMonth", "transactions per month",
                   sprintf("%s transactions per month%s", row$label, view),
                   describe_txn_calculation(row, config), sources,
                   describe_txn_missing_rule(row)),
    dictionary_row(paste0(stem, "MonthlySpend"), "Category", row$category, row$base,
                   "MonthlySpend", "rand per month",
                   sprintf("%s spend per month%s", row$label, view),
                   describe_spend_calculation(row, stem), sources,
                   describe_spend_missing_rule(row)),
    dictionary_row(paste0(stem, "SpendPerTxn"), "Category", row$category, row$base,
                   "SpendPerTxn", "rand per transaction",
                   sprintf("Average %s value per transaction%s", row$label, view),
                   describe_per_txn_calculation(row, config, stem), sources,
                   describe_per_txn_missing_rule(row))
  ))
}

#' Document the derived Total of a category the survey splits
#'
#' @param category The category name.
#' @param label The category's display label.
#'
#' @return A three-row data frame.
dictionary_for_derived_total <- function(category, label) {
  stem <- sprintf("%s_Total_", category)
  return(rbind(
    dictionary_row(paste0(stem, "TxnPerMonth"), "Category", category, "Total",
                   "TxnPerMonth", "transactions per month",
                   sprintf("%s transactions per month (for everyone)", label),
                   sprintf("%s_Own_TxnPerMonth + %s_Oth_TxnPerMonth", category, category),
                   sprintf("%s_Own_TxnPerMonth, %s_Oth_TxnPerMonth", category, category),
                   "Summed over whichever side is present. Missing only when both sides are missing."),
    dictionary_row(paste0(stem, "MonthlySpend"), "Category", category, "Total",
                   "MonthlySpend", "rand per month",
                   sprintf("%s spend per month (for everyone)", label),
                   sprintf("%s_Own_MonthlySpend + %s_Oth_MonthlySpend", category, category),
                   sprintf("%s_Own_MonthlySpend, %s_Oth_MonthlySpend", category, category),
                   "Summed over whichever side is present. Missing only when both sides are missing."),
    dictionary_row(paste0(stem, "SpendPerTxn"), "Category", category, "Total",
                   "SpendPerTxn", "rand per transaction",
                   sprintf("Average %s value per transaction (for everyone)", label),
                   sprintf("%sMonthlySpend / %sTxnPerMonth\nA true weighted figure, NOT the mean of the Own and Oth rates.", stem, stem),
                   sprintf("%sMonthlySpend, %sTxnPerMonth", stem, stem),
                   "Missing when total transactions are zero or missing.")
  ))
}
