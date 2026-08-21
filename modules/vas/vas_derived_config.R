# vas_derived_config.R
# ------------------------------------------------------------------------------
# All tunable assumptions for the VAS derived-variable calculation.
# Edit this file, not the calculation script.
#
# Companion: vas_category_map.csv - one row per category x base, listing the
# question aliases, the amount basis and the spend class. Generated from the
# survey by build_category_map.R; safe to hand-edit afterwards.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Written-in town spellings that are the SAME place
#
# When a respondent picks "Other" for their town they type it in themselves, so
# the same town arrives spelled several ways. Left alone each spelling becomes
# its own crosstab row and one real town fragments into four or five small
# ones - worse than the "Other" it replaced.
#
# The rule for adding a line here is strict: ONLY where the variant is
# unambiguously the same name. A place that might be somewhere else stays
# exactly as it was typed, because guessing would put a respondent in a town
# they did not name. Matching is case-insensitive and ignores extra spaces, so
# only genuine spelling differences need a line.
#
# Deliberately NOT folded on VAS 2026, and why:
#   "Brits Bethani" / "Brits Bettarny"  Bethanie is its own settlement near
#                                       Brits, not a spelling of it
#   "Blood river"                       a different place entirely
#   "Extinction 76" / "Dairing extinction"  almost certainly "extension", but
#                                       of which township is not recoverable
#   "Seshego zone 2", "Kwena moloto 3"  a zone within a named town; folding
#                                       them loses the detail the person gave
# ------------------------------------------------------------------------------
VAS_TOWN_ALIASES <- c(
  "Britz"     = "Brits",
  "Brits cbd" = "Brits"
)

VAS_CONFIG <- list(

  # ---- frequency conversion --------------------------------------------------
  # Freq1 "Once a week or more often" -> Freq2 (per week) x this factor
  weeks_per_month = 52 / 12,          # 4.3333; set to 4 for a flat month

  # Freq1 "Once per month" has no follow-up question by design
  once_per_month_value = 1,

  # Freq4 is a 12-month count -> divide by this
  months_per_year = 12,

  # What to do when Freq4 = "Don't know": "missing" or "impute_median"
  dont_know_rule = "missing",

  # A count question's top code ("12+") is read at its LOWER BOUND, so "12+"
  # counts as 12. Duncan, 18 August 2026: "lets assume 12 for the 12+ domestic
  # leg". The specify box beside it collects free text, so it cannot be relied
  # on for a number - the one respondent who used it typed "For work purposes".
  # Reading the top code as unusable dropped a real buyer out of every travel
  # figure while still counting them as a buyer.
  count_top_code_at_lower_bound = TRUE,

  # ---- imputed spend for the count-only categories ---------------------------
  # Duncan's values, 22 July 2026. NORMALISED TO PER LEG, because the survey
  # asks whether the respondent's count is of one-way or return trips
  # (FlightDomReturn / FlightIntlReturn / LDBusReturn):
  #
  #   domestic flight      R1,500 per leg      -> 1500 per leg
  #   international flight R15,000 return      -> 7500 per leg
  #   long distance bus    R750 per leg        ->  750 per leg
  #
  # A "Return" answer therefore counts 2 legs per trip, "One way" counts 1.
  imputed_spend_per_leg = list(
    FlightDomestic      = 1500,
    FlightInternational = 7500,
    LongDistanceBus     = 750
  ),
  legs_per_trip = list(`One way` = 1, `Return` = 2),
  # if the one-way/return question is blank, assume:
  legs_default = 1,

  # ---- fixed-fee categories with no amount question --------------------------
  # TV licence is a set annual fee and the survey deliberately does not ask for
  # an amount or a frequency, so presence is read off the bill-list selection
  # and the fee is imputed. R265 p.a. (Duncan, 22 July 2026).
  imputed_annual_fee = list(
    BillTVLicence = 265
  ),

  # ---- assumed cadence for bills with no frequency question ------------------
  # These questions ask for an amount but never a frequency. Transactions per
  # month are assumed. Overrides the assumed_cadence column in the category map.
  cadence_txn_per_month = list(
    monthly = 1,
    annual  = 1 / 12
  ),

  # ---- income bands, for share of wallet -------------------------------------
  # Two variants are produced: one on the band midpoint, one on the upper
  # boundary. The two open-ended bands have no natural value, so Duncan set
  # them explicitly (22 July): bottom band R3,500, top band R100,000 - used for
  # BOTH variants since neither has a defined bound on the open side.
  income_bands = data.frame(
    label    = c("Less than R3,500", "R3,500 to R7,999", "R8,000 to R21,999",
                 "R22,000 to R39,999", "R40,000 to R74,999", "More than R75,000",
                 "Decline to answer"),
    midpoint = c(3500, 5750, 15000, 31000, 57500, 100000, NA),
    upper    = c(3500, 7999, 21999, 39999, 74999, 100000, NA),
    stringsAsFactors = FALSE
  ),

  # ---- totals ----------------------------------------------------------------
  # Which spend classes roll into which headline total.
  #   consumption : airtime, data, vouchers, LOTTO, betting, tickets, travel
  #   obligation  : bill payments
  #   transfer    : money sent (domestic + international)
  #   received    : money IN - never added to a spend total, reported separately
  total_value_transacted   = c("consumption", "obligation", "transfer"),
  total_consumption_spend  = c("consumption"),
  total_bill_spend         = c("obligation"),
  total_transfer_sent      = c("transfer"),
  reported_separately      = c("received"),

  # The wallet: what the respondent SPENDS through these rails each month.
  # Money sent is an outflow but not spend, and money received is income, so
  # both transfer classes stay out (Duncan, 13 Aug 2026). The 2024 WALLET_OUT
  # included money sent - re-derive 2024 on this formula before any trend row.
  total_wallet_spend       = c("consumption", "obligation"),

  # "Of which gambling" under the wallet line. Named by CATEGORY rather than
  # spend class, because Lotto and Betting sit inside consumption.
  gambling_categories      = c("Lotto", "Betting"),

  # ---- amount parsing --------------------------------------------------------
  # The amount questions are free-text, so expect "R150", "150,00", "about 200".
  # Strip currency symbols, spaces and thousands separators, then coerce.
  # A value outside this range is treated as unparseable and flagged.
  amount_min = 0,
  amount_max = 200000,

  # Per-spend-class overrides of amount_max. Transfers legitimately reach
  # amounts that would be absurd for airtime - real R1,000,000 answers were
  # rejected by the global cap in the 8912114 test export (23 July 2026).
  # A class not listed here uses amount_max.
  amount_max_by_class = list(
    transfer = 1000000,
    received = 1000000
  ),

  # ---- outlier flags (flag, NEVER cap) ---------------------------------------
  # A category cell is FLAGGED when its transactions per month or its monthly
  # spend exceeds the ceiling for its spend class. A flag never changes a
  # number - it surfaces in the Audit sheet, the OutlierCells / OutlierFlag
  # columns and the sense check, so implausible answers can be reviewed and,
  # where needed, excluded in reporting. Ceilings are deliberately generous:
  # they catch the absurd (a "5x a week" store-card bill), not the unusual.
  # PROPOSED VALUES, 23 July 2026 - Duncan to review and edit.
  outlier_txn_per_month = list(
    consumption = 62,      # two transactions a day
    obligation  = 10,      # ten bill payments a month
    transfer    = 31,      # daily money sending
    received    = 31
  ),
  outlier_monthly_spend = list(
    consumption = 20000,
    obligation  = 100000,
    transfer    = 1000000,
    received    = 1000000
  ),
  # "150-200" style ranges: "midpoint", "lower", "upper" or "reject"
  range_rule = "midpoint",

  # ADDED 23 July - interviewers on this study are briefed to enter 0 in an
  # amount field when the respondent cannot put a figure on it, so a typed
  # zero is a don't-know, not a zero spend. TRUE reads it that way: the amount
  # becomes missing, the respondent still counts as a buyer at their measured
  # frequency, and the record is flagged incomplete like any other missing
  # amount. Set FALSE on a study where a typed 0 means the respondent really
  # spent nothing. This governs typed digits only - a word answer is still
  # decided by zero_words / unknown_words below.
  zero_amount_is_dont_know = TRUE,

  # ADDED AT BUILD (22 July) - the parser needs a vocabulary, and it belongs
  # here rather than inside the code. A word answer is only classified when the
  # response contains no digits at all, so "about 200" still parses as 200.
  #   zero_words    -> the respondent spent nothing. Value 0, counts as answered.
  #   unknown_words -> a refusal or a genuine don't-know. Value NA, flagged.
  # Anything else with no digits is "unparseable" and flagged. Move a word
  # between the two lists to change how it is treated; no code change needed.
  zero_words = c("none", "nothing", "nil", "zero", "no", "n a", "na",
                 "not applicable", "free", "no cost", "nought"),
  unknown_words = c("dont know", "don't know", "do not know", "dk", "dunno",
                    "not sure", "unsure", "no idea", "cant remember",
                    "can't remember", "cannot remember", "cant recall",
                    "can't recall", "refused", "refuse", "prefer not to say",
                    "decline to answer", "no comment", "varies", "it varies",
                    "depends", "it depends", "different", "unknown"),

  # ADDED AT BUILD (22 July) - answers on the travel COUNT questions that mean
  # "zero trips". The current survey offers a "0" option, but earlier data (and
  # the export in ~/Downloads) still carries the pre-relabel wordings, so all
  # three are accepted.
  count_zero_values = c("0", "None", "Have not bought any"),

  # ---- output ----------------------------------------------------------------
  # A respondent is marked incomplete if they reported buying a category but its
  # amount could not be parsed. Incomplete respondents still get a total; the
  # flag lets the reporting exclude them from share-of-wallet means.
  completeness_flag = TRUE
)
