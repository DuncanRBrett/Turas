# vas_amount_parser.R
# ------------------------------------------------------------------------------
# Free-text amount parser for the VAS derived-variable calculation.
#
# Every amount question in survey 8912114 is an open text box, so the answers
# arrive as typed strings: "R150", "150,00", "about 200", "150-200", "dont know".
# This file turns those into a number plus a status, and never guesses silently -
# anything it cannot read comes back as NA with a status saying why.
#
# Pure logic only: no I/O, no dependency on the survey or the config file beyond
# the config list passed in. Vocabulary (which words mean zero, which mean
# "don't know") lives in the config, not here.
# ------------------------------------------------------------------------------

# Statuses returned by the parser. A caller should treat anything other than
# "ok" or "range" as "no usable number".
VAS_AMOUNT_STATUS <- c(
  "ok",           # a single number was read
  "range",        # two numbers were read and collapsed per config$range_rule
  "zero_word",    # a word meaning nothing was spent, e.g. "none"
  "zero_dk",      # a typed 0, which this study's interviewers enter for
                  # "don't know" (config$zero_amount_is_dont_know)
  "blank",        # not answered / not asked
  "unknown_word", # a refusal or "don't know"
  "unparseable",  # text present but no number could be found
  "out_of_range"  # a number was read but it fell outside amount_min..amount_max
)

#' Apply a spend class's amount range to the config
#'
#' Transfers legitimately reach amounts that would be absurd for airtime, so
#' \code{config$amount_max_by_class} can widen the acceptance range per spend
#' class. A class with no override, or a missing table, leaves the config
#' unchanged.
#'
#' @param config The VAS_CONFIG list.
#' @param spend_class A single spend class, e.g. "transfer".
#'
#' @return The config, with \code{amount_max} overridden where applicable.
config_for_spend_class <- function(config, spend_class) {
  if (is.null(config$amount_max_by_class) || is.na(spend_class)) {
    return(config)
  }
  override <- config$amount_max_by_class[[spend_class]]
  if (!is.null(override)) {
    config$amount_max <- override
  }
  return(config)
}

#' Strip currency marks and padding from a raw amount answer
#'
#' Removes the rand symbol, ISO code, ordinary and non-breaking spaces, and
#' surrounding punctuation, leaving digits and separators for later steps.
#'
#' @param text A single character value (may be NA).
#'
#' @return A single lower-cased character value, whitespace collapsed.
normalise_amount_text <- function(text) {
  if (is.na(text)) {
    return(NA_character_)
  }
  cleaned <- tolower(as.character(text))
  cleaned <- gsub(" ", " ", cleaned, fixed = TRUE) # non-breaking space
  cleaned <- gsub("\\s+", " ", cleaned)
  cleaned <- trimws(cleaned)
  # currency marks: leading "r", "r.", "zar", and any stray currency symbols
  cleaned <- gsub("(^|\\s)(zar|rand[s]?)(\\s|$)", " ", cleaned)
  cleaned <- gsub("(^|\\s)r\\.?(?=\\s?[0-9])", " ", cleaned, perl = TRUE)
  cleaned <- gsub("[₨$£€]", " ", cleaned)
  cleaned <- trimws(gsub("\\s+", " ", cleaned))
  return(cleaned)
}

#' Decide whether an answer is a word rather than a number
#'
#' Matches the cleaned text against the zero vocabulary and the unknown
#' vocabulary held in the config. Matching is on the whole string only, so
#' "no idea" is an unknown but "no idea, maybe 200" is left for number
#' extraction.
#'
#' @param cleaned Output of \code{normalise_amount_text()}.
#' @param config The VAS_CONFIG list.
#'
#' @return "zero_word", "unknown_word", or NA_character_ if it is not a word
#'   answer.
classify_amount_word <- function(cleaned, config) {
  if (is.na(cleaned) || !nzchar(cleaned)) {
    return(NA_character_)
  }
  bare <- gsub("[^a-z' ]", "", cleaned)
  bare <- trimws(gsub("\\s+", " ", bare))
  if (!nzchar(bare)) {
    return(NA_character_)
  }
  # only classify as a word answer when NO digits are present, so that
  # "about 200" falls through to number extraction
  if (grepl("[0-9]", cleaned)) {
    return(NA_character_)
  }
  if (bare %in% config$zero_words) {
    return("zero_word")
  }
  if (bare %in% config$unknown_words) {
    return("unknown_word")
  }
  return("unparseable")
}

#' Resolve thousands and decimal separators in a numeric token
#'
#' South African survey answers mix conventions: "1 500", "1,500", "1.500" and
#' "150,00" all appear. The rule applied here, symmetric across both marks:
#'
#' \itemize{
#'   \item both marks present - the LAST one to occur is the decimal mark;
#'   \item one mark, occurring once, followed by exactly three digits - it is a
#'         thousands separator ("1.500" and "1,500" both read as 1500, because
#'         rand amounts carry two decimals, not three);
#'   \item one mark, occurring once, followed by one or two digits - it is a
#'         decimal mark ("150,00" reads as 150);
#'   \item one mark occurring more than once - thousands separators.
#' }
#'
#' @param token A character token of digits and separators, no spaces.
#'
#' @return A single numeric value, or NA_real_ if the token cannot be coerced.
resolve_amount_separators <- function(token) {
  if (is.na(token) || !nzchar(token)) {
    return(NA_real_)
  }
  n_comma <- lengths(regmatches(token, gregexpr(",", token, fixed = TRUE)))
  n_dot <- lengths(regmatches(token, gregexpr(".", token, fixed = TRUE)))

  decimal_mark <- ""
  if (n_comma > 0 && n_dot > 0) {
    last_comma <- max(gregexpr(",", token, fixed = TRUE)[[1]])
    last_dot <- max(gregexpr(".", token, fixed = TRUE)[[1]])
    decimal_mark <- if (last_comma > last_dot) "," else "."
  } else if (n_comma == 1 || n_dot == 1) {
    mark <- if (n_comma == 1) "," else "."
    trailing <- nchar(sub(paste0("^.*\\", mark), "", token))
    decimal_mark <- if (trailing == 3) "" else mark
  }

  plain <- token
  for (mark in c(",", ".")) {
    if (!identical(mark, decimal_mark)) {
      plain <- gsub(mark, "", plain, fixed = TRUE)
    }
  }
  if (nzchar(decimal_mark)) {
    plain <- sub(paste0("\\", decimal_mark), ".", plain)
  }
  return(suppressWarnings(as.numeric(plain)))
}

#' Pull every number out of a cleaned amount answer
#'
#' @param cleaned Output of \code{normalise_amount_text()}.
#'
#' @return A numeric vector, possibly empty, in the order the numbers appeared.
extract_amount_numbers <- function(cleaned) {
  if (is.na(cleaned) || !nzchar(cleaned)) {
    return(numeric(0))
  }
  spaceless <- gsub(" ", "", cleaned, fixed = TRUE)
  tokens <- regmatches(spaceless, gregexpr("[0-9]+(?:[.,][0-9]+)*", spaceless))[[1]]
  if (!length(tokens)) {
    return(numeric(0))
  }
  values <- vapply(tokens, resolve_amount_separators, numeric(1), USE.NAMES = FALSE)
  return(values[!is.na(values)])
}

#' Collapse a two-number range to a single value
#'
#' @param values A numeric vector of length 2 or more.
#' @param config The VAS_CONFIG list; \code{range_rule} selects the behaviour.
#'
#' @return A single numeric value, or NA_real_ when the rule is "reject".
collapse_amount_range <- function(values, config) {
  lower <- min(values[1:2])
  upper <- max(values[1:2])
  return(switch(config$range_rule,
    midpoint = (lower + upper) / 2,
    lower    = lower,
    upper    = upper,
    reject   = NA_real_,
    (lower + upper) / 2
  ))
}

#' Parse one free-text amount answer
#'
#' @param text A single raw answer (character, may be NA or empty).
#' @param config The VAS_CONFIG list.
#'
#' @return A list with \code{value} (numeric, NA when unusable) and
#'   \code{status} (one of \code{VAS_AMOUNT_STATUS}).
#'
#' @examples
#' \dontrun{
#'   parse_amount_scalar("R150", VAS_CONFIG)      # value 150,  status "ok"
#'   parse_amount_scalar("150-200", VAS_CONFIG)   # value 175,  status "range"
#'   parse_amount_scalar("dont know", VAS_CONFIG) # value NA,   status "unknown_word"
#'   parse_amount_scalar("0", VAS_CONFIG)         # value NA,   status "zero_dk"
#'   parse_amount_scalar("none", VAS_CONFIG)      # value 0,    status "zero_word"
#' }
parse_amount_scalar <- function(text, config) {
  cleaned <- normalise_amount_text(text)
  if (is.na(cleaned) || !nzchar(cleaned)) {
    return(list(value = NA_real_, status = "blank"))
  }

  word_status <- classify_amount_word(cleaned, config)
  if (!is.na(word_status)) {
    value <- if (identical(word_status, "zero_word")) 0 else NA_real_
    return(list(value = value, status = word_status))
  }

  values <- extract_amount_numbers(cleaned)
  if (!length(values)) {
    return(list(value = NA_real_, status = "unparseable"))
  }

  is_range <- length(values) >= 2 && grepl("[0-9]\\s*(?:-|to|–|—)\\s*[0-9]", cleaned)
  value <- if (is_range) collapse_amount_range(values, config) else values[1]
  status <- if (is_range) "range" else "ok"

  if (is.na(value)) {
    return(list(value = NA_real_, status = "unparseable"))
  }
  # A typed zero is this study's don't-know sentinel, not a zero spend. It
  # leaves the value missing so no mean or average uses it, while the
  # respondent's frequency - and so their incidence - is untouched.
  if (isTRUE(config$zero_amount_is_dont_know) && value == 0) {
    return(list(value = NA_real_, status = "zero_dk"))
  }
  if (value < config$amount_min || value > config$amount_max) {
    return(list(value = NA_real_, status = "out_of_range"))
  }
  return(list(value = value, status = status))
}

#' Parse a vector of free-text amount answers
#'
#' @param text A character vector of raw answers.
#' @param config The VAS_CONFIG list.
#'
#' @return A data frame with one row per input: \code{value} (numeric) and
#'   \code{status} (character).
parse_amount <- function(text, config) {
  if (!length(text)) {
    return(data.frame(value = numeric(0), status = character(0),
                      stringsAsFactors = FALSE))
  }
  parsed <- lapply(as.character(text), parse_amount_scalar, config = config)
  return(data.frame(
    value  = vapply(parsed, function(p) p$value, numeric(1)),
    status = vapply(parsed, function(p) p$status, character(1)),
    stringsAsFactors = FALSE
  ))
}
