# Rebuilds modules/vas/vas_report_labels.xlsx.
# Only the asked questions live here; the nine derived measures per category come
# from the dictionary templates in vas_data_dictionary.R.

L <- function(code, text, note = "") data.frame(question_code = code, question_text = text,
                                                note = note, stringsAsFactors = FALSE)

ASKED   <- "ASKED"
DERIVED <- "DERIVED from transactions above zero"
SELFOTH <- "ASKED - self / other / none"
CHANNELS <- "DERIVED from the most-often and where-else questions"
CROSSTAB <- "Crosstab planning, 14 Aug 2026"
# ---- one category's crosstab block, derived --------------------------------
# The wording Duncan set out in "Crosstab planning.docx" (14 Aug 2026), applied
# to every category by the OneDrive script relabel_categories.R. The rules are
# the same in both places and the two are diffed against each other.
#
# Everything except the verb comes from vas_category_map.csv - the display
# label, whether the category splits self from others, and the marker noun via
# spend_class. The verb is per category because bills are paid and transfers
# are sent, not bought.
#
# The three measure rows are STATEMENTS. "How much do you spend per month on
# X?" works for prepaid electricity and fails on "Traffic fines" - you do not
# spend on a fine - and on "Domestic transfer received", which is money IN and
# is never called spend anywhere in this study.
VAS_MAP <- utils::read.csv(file.path("modules", "vas", "vas_category_map.csv"),
                           stringsAsFactors = FALSE, na.strings = "")

MARKER <- c(consumption = "all purchases", obligation = "all spend",
            transfer = "all transfers", received = "all transfers")

VERB <- c(
  PrepaidElectricity     = "purchase prepaid electricity",
  Airtime                = "buy airtime",
  Data                   = "buy data",
  DigitalVouchers        = "buy digital vouchers",
  ShortDistanceBus       = "buy short distance bus tickets",
  BillTraffic            = "pay traffic fines",
  BillClothing           = "pay a clothing/fashion account",
  BillFurniture          = "pay a furniture account",
  BillEducation          = "pay education fees",
  BillHealth             = "pay health bills",
  BillRetail             = "pay a retail credit account",
  BillOther              = "pay other bills",
  BillDSTV               = "pay DSTV / Multichoice",
  BillMunicipal          = "pay a municipal account",
  BillTelkom             = "pay Telkom / cellphone",
  BillInsurance          = "pay insurance / funeral",
  BillInternet           = "pay an internet subscription",
  BillVehicle            = "pay a vehicle licence",
  BillTVLicence          = "pay a TV licence",
  Lotto                  = "buy LOTTO",
  Betting                = "buy betting vouchers",
  DomSend                = "send domestic money transfers",
  DomRcv                 = "receive domestic money transfers",
  IntlSend               = "send international money transfers",
  EventSportWatch        = "buy tickets to watch sport",
  EventSportPlay         = "buy entry to play sport",
  EventConcert           = "buy concert tickets",
  EventCultural          = "buy cultural event tickets",
  EventTheatre           = "buy theatre tickets",
  EventOther             = "buy other event tickets",
  FlightDomestic         = "buy domestic flights",
  FlightInternational    = "buy international flights",
  LongDistanceBus        = "buy long distance bus tickets"
)

BLOCK <- function(category) {
  rows <- VAS_MAP[VAS_MAP$category == category, , drop = FALSE]
  label <- rows$label[1]
  spend_class <- rows$spend_class[1]
  # a category the survey never split has a single Total row and no others;
  # naming an Own or Oth code that does not exist REFUSES the next build
  views <- if (any(rows$base %in% c("Own", "Oth"))) c("Total", "Own", "Oth") else "Total"
  money <- if (identical(spend_class, "received")) "value per month" else "spend per month"

  out <- L(paste0(category, "_Purchased"),
           sprintf("Did you %s in the past 12 months?", VERB[[category]]), CROSSTAB)
  for (v in views) {
    mark <- sprintf(" (%s)", if (v == "Total") MARKER[[spend_class]] else
                    if (v == "Own") "for self" else "for others")
    out <- rbind(out,
      L(sprintf("%s_%s_TxnPerMonth", category, v),
        sprintf("Number of %s transactions per month%s", label, mark), CROSSTAB),
      L(sprintf("%s_%s_MonthlySpend", category, v),
        sprintf("%s %s%s", label, money, mark), CROSSTAB),
      L(sprintf("%s_%s_SpendPerTxn", category, v),
        sprintf("Average %s value per transaction%s", label, mark), CROSSTAB))
  }
  out
}

#' Every category's block, in the map's order
ALL_BLOCKS <- function() {
  do.call(rbind, lapply(unique(VAS_MAP$category), BLOCK))
}


# The three channel tables of one occasion, worded as a set. CHAN() takes the
# "most often" question's wording and builds the other two from it, so a reader
# moving down the three reads one question asked three ways.
#
#   stem   the question-code stem, e.g. "PPU" or "DomSend"
#   asked  the "most often" wording, ending "... most often?"
#   where  the raw where-else wording, unchanged
CHAN <- function(stem, asked, where, noun = "all purchases") {
  subject <- sub("\\s*most often\\s*\\?\\s*$", "", asked)
  rbind(
    L(paste0(stem, "ChannelEver"),
      paste0(subject, " - ", noun), CHANNELS),
    L(paste0(stem, "ChannelMain"), asked),
    L(paste0(stem, "ChannelAlso"),
      paste0(sub("^Where ", "Where else ", subject),
             " - apart from the channel used most often?"), CHANNELS),
    L(paste0(stem, if (stem == "PPU") "OthChannel" else "ChannelOther"), where)
  )
}

labels <- rbind(
  # ---- demographics ---------------------------------------------------------
  L("Age", "Age", "was: What is your age?"),
  L("Gender", "Gender", "unchanged"),
  L("Race", "Race", "was: Which best describes your ethnic group?"),
  L("Province", "Province", "was: Which province do you currently live in?"),
  L("Town", "Town", "coalesced from the nine per-province questions"),
  L("AreaType", "Type of area lived in", "matches the reporting build"),
  L("Income", "Monthly household income", "was: Monthly household income category?"),
  L("BillPayer", "Role in paying household bills", "matches the reporting build"),

  # ---- prepaid electricity --------------------------------------------------
  ALL_BLOCKS(),
  # "multi-mentions possible" belongs in the wording, not in a note: a note in
  # the Formula column is what makes the report read a row as DERIVED, and this
  # one was genuinely asked.
  L("PPU", "Who have you bought electricity for? (multi-mentions possible)", SELFOTH),
  CHAN("PPU", "Where do you buy prepaid electricity most often?",
       "Where else have you bought prepaid electricity in the past 12 months?"),

  # ---- prepaid airtime ------------------------------------------------------
  L("Airtime", "Who have you bought airtime for? (multi-mentions possible)", SELFOTH),
  CHAN("Airtime", "Where do you buy prepaid airtime most often?",
       "Where else have you bought prepaid airtime in the past 12 months?"),

  # ---- prepaid data ---------------------------------------------------------
  L("Data", "Who have you bought data for? (multi-mentions possible)", SELFOTH),
  CHAN("Data", "Where do you buy prepaid data most often?",
       "Where else have you bought prepaid data in the past 12 months?"),

  # ---- LOTTO ----------------------------------------------------------------
  L("Lotto", "Played LOTTO in last 12 months?", "ASKED yes/no - differs from the derived row on 2 respondents"),
  CHAN("Lotto", "Where do you buy LOTTO most often?",
       "Where else have you bought LOTTO in the past 12 months?"),

  # ---- betting --------------------------------------------------------------
  L("Bet", "Bought betting vouchers in last 12 months?", "ASKED yes/no - differs from the derived row on 2 respondents"),
  CHAN("Bet", "Where do you buy betting vouchers most often?",
       "Where else have you bought betting vouchers in the past 12 months?"),
  L("BetProviders", "Betting providers used", "no equivalent in the other categories"),
  L("BetProviderMain", "Main betting provider", "no equivalent in the other categories"),

  # ---- digital vouchers -----------------------------------------------------
  L("Voucher", "Who have you bought digital vouchers for? (multi-mentions possible)", "ASKED - self / other / none; agrees with the derived row exactly"),
  CHAN("Voucher", "Where do you buy digital vouchers most often?",
       "Where else have you bought digital vouchers in the past 12 months?"),
  L("VoucherType", "Types of digital voucher bought", "no equivalent in the other categories"),

  # ---- domestic money transfers sent ----------------------------------------
  L("DomSend", "Sent a domestic money transfer in last 12 months?", ASKED),
  CHAN("DomSend", "Where do you send domestic money transfers from most often?",
       "Where else have you sent domestic money transfers from in the past 12 months?", "all transfers"),

  # ---- domestic money transfers received ------------------------------------
  L("DomRcv", "Received a domestic money transfer in last 12 months?", ASKED),
  CHAN("DomRcv", "Where do you collect domestic money transfers most often?",
       "Where else have you collected domestic money transfers in the past 12 months?", "all transfers"),

  # ---- international money transfers ----------------------------------------
  L("IntlSend", "Sent money outside South Africa in last 12 months?", ASKED),
  L("IntlSendPlatform", "Platform usually used to send", "no equivalent in the other categories"),
  CHAN("IntlSend", "Where do you pay for international money transfers most often?",
       "Where else have you paid for international money transfers in the past 12 months?", "all transfers"),

  # ---- flights --------------------------------------------------------------
  # One asked question covers both flight categories; domestic and international
  # are split apart only in the derived measures.
  L("Flight", "Who have you bought flight tickets for? (multi-mentions possible)", "ASKED - covers domestic and international together"),
  CHAN("Flight", "Where do you buy flight tickets most often?",
       "Where else have you bought flight tickets in the past 12 months?"),

  # ---- long distance bus ----------------------------------------------------
  L("LDBus", "Who have you bought long distance bus tickets for? (multi-mentions possible)", SELFOTH),
  CHAN("LDBus", "Where do you buy long distance bus tickets most often?",
       "Where else have you bought long distance bus tickets in the past 12 months?"),

  # ---- short distance bus ---------------------------------------------------
  L("SDBus", "Who have you bought short distance bus tickets for? (multi-mentions possible)", SELFOTH),
  CHAN("SDBus", "Where do you buy short distance bus tickets most often?",
       "Where else have you bought short distance bus tickets in the past 12 months?"),
  L("SDBusOwnFormat", "Ticket format usually bought (for self)", "no equivalent in the other categories"),
  L("SDBusOthBuy", "Ticket format usually bought (for others)", "no equivalent in the other categories"),
  # ---- bills ----------------------------------------------------------------
  # One screener and one channel pair cover all fourteen bill categories; they
  # are told apart only in the derived measures.
  L("Bill", "Who have you paid bills for? (multi-mentions possible)", "ASKED - self / other / none; covers all 14 bill categories"),
  CHAN("Bill", "Where do you pay bills most often?",
       "Where else have you paid bills in the past 12 months?", "all spend"),

  # ---- events ---------------------------------------------------------------
  # As with bills, one screener covers all six. Its options are Myself /
  # Someone else / For a group - the group option exists nowhere else, so the
  # for-others reading is not the same as it is in the other categories.
  L("Event", "Who have you bought event tickets for? (multi-mentions possible)", "ASKED - self / someone else / for a group"),
  L("EventType", "Types of event ticket bought", "no equivalent in the other categories"),
  CHAN("Event", "Where do you buy event tickets most often?",
       "Where else have you bought event tickets in the past 12 months?"),

  # ---- wallet totals --------------------------------------------------------
  # These carried developer notes as their question text - the definition of the
  # measure, not a label a reader can use.
  L("TotalBillSpend", "Total bill payments a month", "was an internal note about spend classes"),
  L("TotalConsumptionSpend", "Total spend on services a month", "was an internal note"),
  L("TotalTransferSent", "Total money sent a month", "was an internal note"),
  L("TotalValueTransacted", "Total value transacted a month", "was an internal note"),
  L("TotalTxnPerMonth", "Total transactions a month", "was an internal note"),

  # The wallet block, added to the workbook by hand on 13 Aug 2026 and missing
  # from this builder until now - the next rebuild would have dropped all six.
  # Same wording as add_wallet_questions.R writes into the kept config.
  L("TotalWalletSpend", "Wallet spend a month (money sent and received excluded)",
    "Wallet summary block - Duncan, 13 Aug 2026"),
  L("TotalWalletTxn", "Wallet transactions a month",
    "Wallet summary block - Duncan, 13 Aug 2026"),
  L("TotalWalletSpendSelf", "Wallet spend a month, for self",
    "Wallet summary block - Duncan, 13 Aug 2026"),
  L("TotalWalletTxnSelf", "Wallet transactions a month, for self",
    "Wallet summary block - Duncan, 13 Aug 2026"),
  L("TotalGamblingSpend", "Gambling spend a month (stakes)",
    "Wallet summary block - Duncan, 13 Aug 2026"),
  L("TotalGamblingTxn", "Gambling transactions a month",
    "Wallet summary block - Duncan, 13 Aug 2026")
)

wb <- openxlsx::createWorkbook()
openxlsx::addWorksheet(wb, "Labels")
openxlsx::writeData(wb, "Labels", labels)
openxlsx::addStyle(wb, "Labels", openxlsx::createStyle(textDecoration = "bold"),
                   rows = 1, cols = 1:3, gridExpand = TRUE)
openxlsx::setColWidths(wb, "Labels", cols = 1:3, widths = c(32, 72, 58))
openxlsx::freezePane(wb, "Labels", firstRow = TRUE)
openxlsx::saveWorkbook(wb, "modules/vas/vas_report_labels.xlsx", overwrite = TRUE)
cat("labels:", nrow(labels), "rows,", length(unique(labels$question_code)), "unique codes\n")
