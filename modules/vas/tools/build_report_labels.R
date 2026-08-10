# Rebuilds modules/vas/vas_report_labels.xlsx.
# Only the asked questions live here; the nine derived measures per category come
# from the dictionary templates in vas_data_dictionary.R.

L <- function(code, text, note = "") data.frame(question_code = code, question_text = text,
                                                note = note, stringsAsFactors = FALSE)

ASKED   <- "ASKED"
DERIVED <- "DERIVED from transactions above zero"
SELFOTH <- "ASKED - self / other / none"

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
  L("PPUChannelMain", "Where do you buy prepaid electricity most often?"),
  L("PPUOthChannel", "Where else have you bought prepaid electricity in the past 12 months?"),

  # ---- prepaid airtime ------------------------------------------------------
  L("Airtime_Purchased", "Buy airtime at all in last 12 months?", DERIVED),
  L("Airtime", "Who have you bought airtime for?", SELFOTH),
  L("AirtimeChannelMain", "Where do you buy prepaid airtime most often?"),
  L("AirtimeChannelOther", "Where else have you bought prepaid airtime in the past 12 months?"),

  # ---- prepaid data ---------------------------------------------------------
  L("Data_Purchased", "Buy data at all in last 12 months?", DERIVED),
  L("Data", "Who have you bought data for?", SELFOTH),
  L("DataChannelMain", "Where do you buy prepaid data most often?"),
  L("DataChannelOther", "Where else have you bought prepaid data in the past 12 months?"),

  # ---- LOTTO ----------------------------------------------------------------
  L("Lotto_Purchased", "Buy LOTTO at all in last 12 months?", DERIVED),
  L("Lotto", "Played LOTTO in last 12 months?", "ASKED yes/no - differs from the derived row on 2 respondents"),
  L("LottoChannelMain", "Where do you buy LOTTO most often?"),
  L("LottoChannelOther", "Where else have you bought LOTTO in the past 12 months?"),

  # ---- betting --------------------------------------------------------------
  L("Betting_Purchased", "Buy betting vouchers at all in last 12 months?", DERIVED),
  L("Bet", "Bought betting vouchers in last 12 months?", "ASKED yes/no - differs from the derived row on 2 respondents"),
  L("BetChannelMain", "Where do you buy betting vouchers most often?"),
  L("BetChannelOther", "Where else have you bought betting vouchers in the past 12 months?"),
  L("BetProviders", "Betting providers used", "no equivalent in the other categories"),
  L("BetProviderMain", "Main betting provider", "no equivalent in the other categories"),

  # ---- digital vouchers -----------------------------------------------------
  L("DigitalVouchers_Purchased", "Buy digital vouchers at all in last 12 months?", DERIVED),
  L("Voucher", "Who have you bought digital vouchers for?", "ASKED - self / other / none; agrees with the derived row exactly"),
  L("VoucherChannelMain", "Where do you buy digital vouchers most often?"),
  L("VoucherChannelOther", "Where else have you bought digital vouchers in the past 12 months?"),
  L("VoucherType", "Types of digital voucher bought", "no equivalent in the other categories"),

  # ---- domestic money transfers sent ----------------------------------------
  L("DomSend_Purchased", "Send domestic money transfers at all in last 12 months?", DERIVED),
  L("DomSend", "Sent a domestic money transfer in last 12 months?", ASKED),
  L("DomSendChannelMain", "Where do you send domestic money transfers from most often?"),
  L("DomSendChannelOther", "Where else have you sent domestic money transfers from in the past 12 months?"),

  # ---- domestic money transfers received ------------------------------------
  L("DomRcv_Purchased", "Receive domestic money transfers at all in last 12 months?", DERIVED),
  L("DomRcv", "Received a domestic money transfer in last 12 months?", ASKED),
  L("DomRcvChannelMain", "Where do you collect domestic money transfers most often?"),
  L("DomRcvChannelOther", "Where else have you collected domestic money transfers in the past 12 months?"),

  # ---- international money transfers ----------------------------------------
  L("IntlSend_Purchased", "Send international money transfers at all in last 12 months?", DERIVED),
  L("IntlSend", "Sent money outside South Africa in last 12 months?", ASKED),
  L("IntlSendPlatform", "Platform usually used to send", "no equivalent in the other categories"),
  L("IntlSendChannelMain", "Where do you pay for international money transfers most often?"),
  L("IntlSendChannelOther", "Where else have you paid for international money transfers in the past 12 months?"),

  # ---- flights --------------------------------------------------------------
  # One asked question covers both flight categories; domestic and international
  # are split apart only in the derived measures.
  L("FlightDomestic_Purchased", "Buy domestic flights at all in last 12 months?", DERIVED),
  L("FlightInternational_Purchased", "Buy international flights at all in last 12 months?", DERIVED),
  L("Flight", "Who have you bought flight tickets for?", "ASKED - covers domestic and international together"),
  L("FlightChannelMain", "Where do you buy flight tickets most often?"),
  L("FlightChannelOther", "Where else have you bought flight tickets in the past 12 months?"),

  # ---- long distance bus ----------------------------------------------------
  L("LongDistanceBus_Purchased", "Buy long distance bus tickets at all in last 12 months?", DERIVED),
  L("LDBus", "Who have you bought long distance bus tickets for?", SELFOTH),
  L("LDBusChannelMain", "Where do you buy long distance bus tickets most often?"),
  L("LDBusChannelOther", "Where else have you bought long distance bus tickets in the past 12 months?"),

  # ---- short distance bus ---------------------------------------------------
  L("ShortDistanceBus_Purchased", "Buy short distance bus tickets at all in last 12 months?", DERIVED),
  L("SDBus", "Who have you bought short distance bus tickets for?", SELFOTH),
  L("SDBusChannelMain", "Where do you buy short distance bus tickets most often?"),
  L("SDBusChannelOther", "Where else have you bought short distance bus tickets in the past 12 months?"),
  L("SDBusOwnFormat", "Ticket format usually bought (for self)", "no equivalent in the other categories"),
  L("SDBusOthBuy", "Ticket format usually bought (for others)", "no equivalent in the other categories")
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
