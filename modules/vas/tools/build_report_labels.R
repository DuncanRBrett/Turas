# Rebuilds modules/vas/vas_report_labels.xlsx.
# Only the asked questions live here; the nine derived measures per category come
# from the dictionary templates in vas_data_dictionary.R.

L <- function(code, text, note = "") data.frame(question_code = code, question_text = text,
                                                note = note, stringsAsFactors = FALSE)

ASKED   <- "ASKED"
DERIVED <- "DERIVED from transactions above zero"
SELFOTH <- "ASKED - self / other / none"
CHANNELS <- "DERIVED from the most-often and where-else questions"

# The three channel tables of one occasion, worded as a set. CHAN() takes the
# "most often" question's wording and builds the other two from it, so a reader
# moving down the three reads one question asked three ways.
#
#   stem   the question-code stem, e.g. "PPU" or "DomSend"
#   asked  the "most often" wording, ending "... most often?"
#   where  the raw where-else wording, unchanged
CHAN <- function(stem, asked, where) {
  subject <- sub("\\s*most often\\s*\\?\\s*$", "", asked)
  rbind(
    L(paste0(stem, "ChannelEver"),
      paste0(subject, " - all channels used, most often or also?"), CHANNELS),
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
  L("PrepaidElectricity_Purchased", "Buy electricity at all in last 12 months?", DERIVED),
  L("PPU", "Who have you bought electricity for?", SELFOTH),
  CHAN("PPU", "Where do you buy prepaid electricity most often?",
       "Where else have you bought prepaid electricity in the past 12 months?"),

  # ---- prepaid airtime ------------------------------------------------------
  L("Airtime_Purchased", "Buy airtime at all in last 12 months?", DERIVED),
  L("Airtime", "Who have you bought airtime for?", SELFOTH),
  CHAN("Airtime", "Where do you buy prepaid airtime most often?",
       "Where else have you bought prepaid airtime in the past 12 months?"),

  # ---- prepaid data ---------------------------------------------------------
  L("Data_Purchased", "Buy data at all in last 12 months?", DERIVED),
  L("Data", "Who have you bought data for?", SELFOTH),
  CHAN("Data", "Where do you buy prepaid data most often?",
       "Where else have you bought prepaid data in the past 12 months?"),

  # ---- LOTTO ----------------------------------------------------------------
  L("Lotto_Purchased", "Buy LOTTO at all in last 12 months?", DERIVED),
  L("Lotto", "Played LOTTO in last 12 months?", "ASKED yes/no - differs from the derived row on 2 respondents"),
  CHAN("Lotto", "Where do you buy LOTTO most often?",
       "Where else have you bought LOTTO in the past 12 months?"),

  # ---- betting --------------------------------------------------------------
  L("Betting_Purchased", "Buy betting vouchers at all in last 12 months?", DERIVED),
  L("Bet", "Bought betting vouchers in last 12 months?", "ASKED yes/no - differs from the derived row on 2 respondents"),
  CHAN("Bet", "Where do you buy betting vouchers most often?",
       "Where else have you bought betting vouchers in the past 12 months?"),
  L("BetProviders", "Betting providers used", "no equivalent in the other categories"),
  L("BetProviderMain", "Main betting provider", "no equivalent in the other categories"),

  # ---- digital vouchers -----------------------------------------------------
  L("DigitalVouchers_Purchased", "Buy digital vouchers at all in last 12 months?", DERIVED),
  L("Voucher", "Who have you bought digital vouchers for?", "ASKED - self / other / none; agrees with the derived row exactly"),
  CHAN("Voucher", "Where do you buy digital vouchers most often?",
       "Where else have you bought digital vouchers in the past 12 months?"),
  L("VoucherType", "Types of digital voucher bought", "no equivalent in the other categories"),

  # ---- domestic money transfers sent ----------------------------------------
  L("DomSend_Purchased", "Send domestic money transfers at all in last 12 months?", DERIVED),
  L("DomSend", "Sent a domestic money transfer in last 12 months?", ASKED),
  CHAN("DomSend", "Where do you send domestic money transfers from most often?",
       "Where else have you sent domestic money transfers from in the past 12 months?"),

  # ---- domestic money transfers received ------------------------------------
  L("DomRcv_Purchased", "Receive domestic money transfers at all in last 12 months?", DERIVED),
  L("DomRcv", "Received a domestic money transfer in last 12 months?", ASKED),
  CHAN("DomRcv", "Where do you collect domestic money transfers most often?",
       "Where else have you collected domestic money transfers in the past 12 months?"),

  # ---- international money transfers ----------------------------------------
  L("IntlSend_Purchased", "Send international money transfers at all in last 12 months?", DERIVED),
  L("IntlSend", "Sent money outside South Africa in last 12 months?", ASKED),
  L("IntlSendPlatform", "Platform usually used to send", "no equivalent in the other categories"),
  CHAN("IntlSend", "Where do you pay for international money transfers most often?",
       "Where else have you paid for international money transfers in the past 12 months?"),

  # ---- flights --------------------------------------------------------------
  # One asked question covers both flight categories; domestic and international
  # are split apart only in the derived measures.
  L("FlightDomestic_Purchased", "Buy domestic flights at all in last 12 months?", DERIVED),
  L("FlightInternational_Purchased", "Buy international flights at all in last 12 months?", DERIVED),
  L("Flight", "Who have you bought flight tickets for?", "ASKED - covers domestic and international together"),
  CHAN("Flight", "Where do you buy flight tickets most often?",
       "Where else have you bought flight tickets in the past 12 months?"),

  # ---- long distance bus ----------------------------------------------------
  L("LongDistanceBus_Purchased", "Buy long distance bus tickets at all in last 12 months?", DERIVED),
  L("LDBus", "Who have you bought long distance bus tickets for?", SELFOTH),
  CHAN("LDBus", "Where do you buy long distance bus tickets most often?",
       "Where else have you bought long distance bus tickets in the past 12 months?"),

  # ---- short distance bus ---------------------------------------------------
  L("ShortDistanceBus_Purchased", "Buy short distance bus tickets at all in last 12 months?", DERIVED),
  L("SDBus", "Who have you bought short distance bus tickets for?", SELFOTH),
  CHAN("SDBus", "Where do you buy short distance bus tickets most often?",
       "Where else have you bought short distance bus tickets in the past 12 months?"),
  L("SDBusOwnFormat", "Ticket format usually bought (for self)", "no equivalent in the other categories"),
  L("SDBusOthBuy", "Ticket format usually bought (for others)", "no equivalent in the other categories"),
  # ---- bills ----------------------------------------------------------------
  # One screener and one channel pair cover all fourteen bill categories; they
  # are told apart only in the derived measures.
  L("Bill", "Who have you paid bills for?", "ASKED - self / other / none; covers all 14 bill categories"),
  CHAN("Bill", "Where do you pay bills most often?",
       "Where else have you paid bills in the past 12 months?"),
  L("BillTraffic_Purchased", "Pay traffic fines at all in last 12 months?", DERIVED),
  L("BillClothing_Purchased", "Pay a clothing/fashion account at all in last 12 months?", DERIVED),
  L("BillFurniture_Purchased", "Pay a furniture account at all in last 12 months?", DERIVED),
  L("BillEducation_Purchased", "Pay education fees at all in last 12 months?", DERIVED),
  L("BillHealth_Purchased", "Pay health bills at all in last 12 months?", DERIVED),
  L("BillRetail_Purchased", "Pay a retail credit account at all in last 12 months?", DERIVED),
  L("BillOther_Purchased", "Pay other bills at all in last 12 months?", DERIVED),
  L("BillDSTV_Purchased", "Pay DSTV / Multichoice at all in last 12 months?", DERIVED),
  L("BillMunicipal_Purchased", "Pay a municipal account at all in last 12 months?", DERIVED),
  L("BillTelkom_Purchased", "Pay Telkom / cellphone at all in last 12 months?", DERIVED),
  L("BillInsurance_Purchased", "Pay insurance / funeral at all in last 12 months?", DERIVED),
  L("BillInternet_Purchased", "Pay an internet subscription at all in last 12 months?", DERIVED),
  L("BillVehicle_Purchased", "Pay a vehicle licence at all in last 12 months?", DERIVED),
  L("BillTVLicence_Purchased", "Pay a TV licence at all in last 12 months?", DERIVED),

  # ---- events ---------------------------------------------------------------
  # As with bills, one screener covers all six. Its options are Myself /
  # Someone else / For a group - the group option exists nowhere else, so the
  # for-others reading is not the same as it is in the other categories.
  L("Event", "Who have you bought event tickets for?", "ASKED - self / someone else / for a group"),
  L("EventType", "Types of event ticket bought", "no equivalent in the other categories"),
  CHAN("Event", "Where do you buy event tickets most often?",
       "Where else have you bought event tickets in the past 12 months?"),
  L("EventSportWatch_Purchased", "Buy tickets to watch sport at all in last 12 months?", DERIVED),
  L("EventSportPlay_Purchased", "Buy entry to play sport at all in last 12 months?", DERIVED),
  L("EventConcert_Purchased", "Buy concert tickets at all in last 12 months?", DERIVED),
  L("EventCultural_Purchased", "Buy cultural event tickets at all in last 12 months?", DERIVED),
  L("EventTheatre_Purchased", "Buy theatre tickets at all in last 12 months?", DERIVED),
  L("EventOther_Purchased", "Buy other event tickets at all in last 12 months?", DERIVED),

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
