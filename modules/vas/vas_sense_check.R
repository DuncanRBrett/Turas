# vas_sense_check.R
# ------------------------------------------------------------------------------
# Presentation layer for the VAS derived-variable calculation: everything that
# prints. No calculation lives here beyond summarising what the engine produced.
#
# The point of this file is that the output can be judged without reading the
# code. It reports what was read, how the free-text amounts parsed, what each
# category produced, and whether the numbers are internally consistent.
# ------------------------------------------------------------------------------

# Tolerance for the arithmetic identity checks, in rand or transactions.
VAS_IDENTITY_TOLERANCE <- 1e-8

#' Compare two numeric vectors, treating missing as equal to missing
#'
#' @param left,right Numeric vectors of equal length.
#' @param tolerance Absolute tolerance.
#'
#' @return A logical vector: TRUE where the two agree.
agrees_within <- function(left, right, tolerance = VAS_IDENTITY_TOLERANCE) {
  both_missing <- is.na(left) & is.na(right)
  close <- !is.na(left) & !is.na(right) & abs(left - right) <= tolerance
  return(both_missing | close)
}

#' Print a heading
#'
#' @param text The heading text.
#'
#' @return Invisibly NULL.
print_heading <- function(text) {
  cat(sprintf("\n%s\n%s\n", text, strrep("-", nchar(text))))
  return(invisible(NULL))
}

#' Print a frequency table, naming the missing category rather than indexing it
#'
#' \code{table(useNA = "ifany")} gives the missing category a literal NA name,
#' which cannot be used as a subscript, so counts are read positionally.
#'
#' @param values A vector to tabulate.
#' @param missing_label What to call the missing category.
#' @param indent A format width for the label column.
#'
#' @return Invisibly NULL.
print_frequency_table <- function(values, missing_label = "(not answered)", indent = 22L) {
  counts <- table(values, useNA = "ifany")
  for (i in seq_along(counts)) {
    label <- names(counts)[i]
    cat(sprintf("  %-*s %d\n", indent,
                if (is.na(label)) missing_label else label, counts[i]))
  }
  return(invisible(NULL))
}

#' Report what was read from the source
#'
#' @param source A vas_source object.
#'
#' @return Invisibly NULL.
report_source_summary <- function(source) {
  print_heading(sprintf("1. Source: %s", source$origin))
  cat(sprintf("  respondents           %d\n", length(source$response_id)))
  cat(sprintf("  columns available     %d\n", ncol(source$data)))
  cat(sprintf("  response ids          %s\n",
              paste(range(suppressWarnings(as.integer(source$response_id))), collapse = " to ")))
  cat("  response status:\n")
  print_frequency_table(source$status, missing_label = "(none recorded)")
  return(invisible(NULL))
}

#' Report how the free-text amount answers parsed
#'
#' @param source A vas_source object.
#' @param category_map The category map data frame.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame of the raw answers that failed to parse.
report_amount_parsing <- function(source, category_map, config) {
  print_heading("2. Free-text amount parsing")
  amount_rows <- unique(category_map[!is.na(category_map$amount_alias) &
                                       category_map$amount_basis != "imputed",
                                     c("amount_alias", "spend_class")])
  amount_aliases <- amount_rows$amount_alias
  parsed <- do.call(rbind, lapply(seq_len(nrow(amount_rows)), function(i) {
    alias <- amount_rows$amount_alias[i]
    raw <- source_scalar(source, alias)
    cbind(data.frame(alias = alias, raw = raw, stringsAsFactors = FALSE),
          parse_amount(raw, config_for_spend_class(config, amount_rows$spend_class[i])))
  }))
  answered <- parsed[parsed$status != "blank", ]
  cat(sprintf("  amount questions      %d\n", length(amount_aliases)))
  cat(sprintf("  cells answered        %d of %d\n", nrow(answered), nrow(parsed)))
  print_frequency_table(answered$status, indent = 20L)
  usable <- answered$value[answered$status %in% c("ok", "range", "zero_word")]
  if (length(usable)) {
    cat(sprintf("  parsed values         min %.0f  median %.0f  max %.0f\n",
                min(usable), stats::median(usable), max(usable)))
  }
  failed <- answered[!answered$status %in% c("ok", "range", "zero_word"), ]
  if (nrow(failed)) {
    cat("  answers that did NOT parse:\n")
    for (i in seq_len(min(nrow(failed), 20L))) {
      cat(sprintf("    %-24s %-14s '%s'\n", failed$alias[i], failed$status[i], failed$raw[i]))
    }
  } else {
    cat("  every answered amount parsed to a number\n")
  }
  return(invisible(failed))
}

#' Report one line per category and base
#'
#' @param audit The audit table from \code{derive_vas()}.
#'
#' @return Invisibly NULL.
report_category_table <- function(audit) {
  print_heading("3. Per category and base (respondents who were asked)")
  cat(sprintf("  %-22s %-6s %5s %5s %10s %12s %12s\n",
              "category", "base", "askd", "incm", "txn/month", "spend/month", "spend/txn"))
  keys <- unique(audit[, c("Category", "Base")])
  for (i in seq_len(nrow(keys))) {
    rows <- audit[audit$Category == keys$Category[i] & audit$Base == keys$Base[i], ]
    asked <- rows[rows$Status != "not_asked", ]
    incomplete <- sum(rows$Status %in% c("freq_missing", "amount_missing", "partial"))
    median_of <- function(values) {
      values <- values[!is.na(values)]
      if (!length(values)) "-" else sprintf("%.2f", stats::median(values))
    }
    cat(sprintf("  %-22s %-6s %5d %5d %10s %12s %12s\n",
                keys$Category[i], keys$Base[i], nrow(asked), incomplete,
                median_of(asked$TxnPerMonth), median_of(asked$MonthlySpend),
                median_of(asked$SpendPerTxn)))
  }
  return(invisible(NULL))
}

#' Report the headline totals, income and share of wallet
#'
#' @param wide The wide table from \code{derive_vas()}.
#'
#' @return Invisibly NULL.
report_headlines <- function(wide) {
  print_heading("4. Headline totals (rand per month)")
  for (column in c("TotalTxnPerMonth", "TotalValueTransacted",
                   "TotalConsumptionSpend", "ValueReceived")) {
    values <- wide[[column]][!is.na(wide[[column]])]
    cat(sprintf("  %-24s n %2d  min %9.2f  median %9.2f  mean %9.2f  max %10.2f\n",
                column, length(values), min(values), stats::median(values),
                mean(values), max(values)))
  }

  categories_purchased <- wide$CategoriesPurchased
  cat(sprintf("\n  %-24s n %2d  min %5.0f  median %5.1f  max %5.0f\n",
              "CategoriesPurchased", length(categories_purchased),
              min(categories_purchased), stats::median(categories_purchased),
              max(categories_purchased)))

  print_heading("5. Income and share of wallet")
  print_frequency_table(wide$IncomeBand)
  cat("\n")
  for (column in grep("^ShareOfWallet", names(wide), value = TRUE)) {
    values <- wide[[column]][!is.na(wide[[column]])]
    if (!length(values)) {
      cat(sprintf("  %-38s no respondents with an income band\n", column))
      next
    }
    cat(sprintf("  %-38s n %2d  median %6.1f%%  max %8.1f%%  over 100%%: %d\n",
                column, length(values), 100 * stats::median(values),
                100 * max(values), sum(values > 1)))
  }
  return(invisible(NULL))
}

#' Report every cell flagged as an implausible outlier
#'
#' A flag never changes a number; this section exists so a "5x a week"
#' store-card bill is seen and judged rather than silently driving a mean.
#'
#' @param audit The audit table from \code{derive_vas()}.
#'
#' @return Invisibly NULL.
report_outliers <- function(audit) {
  print_heading("6. Outliers flagged for review (figures are NOT changed)")
  flagged <- audit[audit$Outlier & audit$Base != "Total", , drop = FALSE]
  if (!nrow(flagged)) {
    cat("  no collected cell breaches its spend class's plausibility ceiling\n")
    return(invisible(NULL))
  }
  cat(sprintf("  %d cell(s) across %d respondent(s):\n",
              nrow(flagged), length(unique(flagged$ResponseID))))
  for (i in seq_len(min(nrow(flagged), 30L))) {
    cat(sprintf("    respondent %-8s %-22s %-5s txn/month %8.2f  spend/month %10.2f\n",
                flagged$ResponseID[i], flagged$Category[i], flagged$Base[i],
                flagged$TxnPerMonth[i], flagged$MonthlySpend[i]))
  }
  if (nrow(flagged) > 30L) {
    cat(sprintf("    ... and %d more - see the Audit sheet\n", nrow(flagged) - 30L))
  }
  return(invisible(NULL))
}

#' Check the arithmetic identities the output must satisfy
#'
#' Two identities are checked for every category the survey splits:
#' Total transactions equal Own plus Oth, and Total spend equals Own plus Oth.
#' A third is checked everywhere: monthly spend equals transactions times spend
#' per transaction.
#'
#' @param wide The wide table from \code{derive_vas()}.
#' @param audit The audit table from \code{derive_vas()}.
#'
#' @return A character vector of failures, empty when everything agrees.
#' Check the identities the headline composites must satisfy
#'
#' @param wide The wide table from \code{derive_vas()}.
#'
#' @return A character vector of failures, empty when everything agrees.
check_headline_identities <- function(wide) {
  failures <- character(0)
  class_sum <- sum_available(cbind(wide$TotalConsumptionSpend, wide$TotalBillSpend,
                                   wide$TotalTransferSent))
  if (!all(agrees_within(wide$TotalValueTransacted, class_sum))) {
    failures <- c(failures,
                  "TotalValueTransacted does not equal Consumption + Bills + Transfers")
  }
  purchased_columns <- grep("_Purchased$", names(wide), value = TRUE)
  purchased_count <- rowSums(wide[, purchased_columns, drop = FALSE])
  if (!all(agrees_within(as.numeric(wide$CategoriesPurchased), purchased_count))) {
    failures <- c(failures,
                  "CategoriesPurchased does not equal the count of TRUE Purchased flags")
  }
  return(failures)
}

check_internal_consistency <- function(wide, audit) {
  print_heading("7. Internal consistency")
  failures <- check_headline_identities(wide)

  split_categories <- unique(audit$Category[audit$Base == "Own"])
  for (category in split_categories) {
    for (measure in c("TxnPerMonth", "MonthlySpend")) {
      own <- wide[[paste0(category, "_Own_", measure)]]
      oth <- wide[[paste0(category, "_Oth_", measure)]]
      total <- wide[[paste0(category, "_Total_", measure)]]
      expected <- sum_available(cbind(own, oth))
      agrees <- agrees_within(total, expected)
      if (identical(measure, "MonthlySpend")) {
        # The published Total spend is deliberately blank where a side's amount
        # is a don't-know: the respondent stays a buyer and keeps their
        # transactions, but the money leaves the means and medians. Own + Oth
        # would read that as a zero, so those rows cannot satisfy the identity
        # and are exempt - precisely, by the flag, not by "total is NA".
        unknown <- audit$AmountUnknown[audit$Category == category &
                                        audit$Base == "Total"]
        if (length(unknown) == length(agrees)) {
          agrees <- agrees | (unknown & is.na(total))
        }
      }
      if (!all(agrees)) {
        failures <- c(failures, sprintf("%s_Total_%s does not equal Own + Oth", category, measure))
      }
    }
  }

  spend_identity <- agrees_within(audit$MonthlySpend,
                                  audit$TxnPerMonth * audit$SpendPerTxn)
  # a zero-transaction row has no spend-per-transaction figure by design, and a
  # monthly-basis row derives spend per transaction from the identity itself
  exempt <- is.na(audit$SpendPerTxn) | audit$TxnPerMonth == 0
  broken <- sum(!spend_identity & !exempt & !is.na(audit$TxnPerMonth))
  if (broken) {
    failures <- c(failures, sprintf("%d rows where monthly spend does not equal transactions x spend per transaction", broken))
  }

  numeric_columns <- vapply(wide, is.numeric, logical(1))
  negative <- vapply(wide[, numeric_columns, drop = FALSE],
                     function(values) any(values < 0, na.rm = TRUE), logical(1))
  if (any(negative)) {
    failures <- c(failures, sprintf("negative values in: %s",
                                    paste(names(negative)[negative], collapse = ", ")))
  }

  if (!length(failures)) {
    cat("  Total = Own + Oth on every split category, both measures      OK\n")
    cat("  monthly spend = transactions x spend per transaction          OK\n")
    cat("  Transacted = Consumption + Bills + Transfers                  OK\n")
    cat("  CategoriesPurchased = count of TRUE Purchased flags           OK\n")
    cat("  no negative values anywhere in the output                     OK\n")
  } else {
    for (failure in failures) {
      cat(sprintf("  FAILED: %s\n", failure))
    }
  }
  return(invisible(failures))
}

#' Run the whole sense check
#'
#' @param source A vas_source object.
#' @param result The list returned by \code{derive_vas()}.
#' @param category_map The category map data frame.
#' @param config The VAS_CONFIG list.
#'
#' @return A character vector of consistency failures, empty when clean.
run_sense_check <- function(source, result, category_map, config) {
  report_source_summary(source)
  report_amount_parsing(source, category_map, config)
  report_category_table(result$audit)
  report_headlines(result$wide)
  report_outliers(result$audit)
  return(invisible(check_internal_consistency(result$wide, result$audit)))
}
