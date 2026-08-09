# build_category_map.R
# Generate the category lookup table for the derived-variable calculation
# straight from the survey structure, so the aliases are real rather than typed.
# Output: vas_category_map.csv - one row per category x base, for Duncan to edit.

source("alchemer_survey_tools.R")
S <- jsonlite::fromJSON(tail(sort(Sys.glob("backups/survey_8912114_*.json")), 1), simplifyVector = FALSE)
idx <- read.csv(tail(sort(Sys.glob("backups/survey_8912114_*_index.csv")), 1), stringsAsFactors = FALSE)
idx <- idx[!is.na(idx$q_id), ]
AL <- idx$alias; names(AL) <- as.character(idx$q_id)
have <- function(a) a %in% AL

TITLE <- setNames(idx$q_title, idx$alias)

# amount basis, read off the question wording
basis_of <- function(alias) {
  if (!have(alias)) return(NA_character_)
  t <- tolower(TITLE[[alias]] %||% "")
  if (grepl("each month|per month|in a typical month|typical month", t)) return("monthly")
  if (grepl("each time|usually spend each|usually send each|usually receive each", t)) return("per_txn")
  if (grepl("last time|the last |last you time", t)) return("last_occasion")
  "unknown"
}

# category -> the Freq1..4 alias stem(s) and amount alias, per base
CATS <- list(
  list(cat="PrepaidElectricity", label="Prepaid electricity", bases=list(
    Own=list(freq="PPUOwnFreq",  amt="PPUOwnAmount"),
    Oth=list(freq="PPUOthFreq",  amt="PPUOthAmount"))),
  list(cat="Airtime", label="Prepaid airtime", bases=list(
    Own=list(freq="AirtimeOwnFreq", amt="AirtimeOwnAmount"),
    Oth=list(freq="AirtimeOthFreq", amt="AirtimeOthAmount"))),
  list(cat="Data", label="Prepaid data", bases=list(
    Own=list(freq="DataSelfFreq", amt="DataAmountSelf"),
    Oth=list(freq="DataOthFreq",  amt="DataOthAmount"))),
  list(cat="DigitalVouchers", label="Digital vouchers", bases=list(
    Own=list(freq="VoucherOwnFreq", amt="VoucherOwnAmount"),
    Oth=list(freq="VoucherOthFreq", amt="VoucherOthAmount"))),
  list(cat="ShortDistanceBus", label="Short distance bus", bases=list(
    Own=list(freq="SDBusOwnFreq", amt="SDBusOwnAmount"),
    Oth=list(freq="SDBusOthFreq", amt="SDBusOthAmount"))),
  list(cat="BillTraffic",   label="Traffic fines",        bases=list(Own=list(freq="BillTrafficOwnFreq",  amt="BillTrafficOwnAmount"),  Oth=list(freq="BillTrafficOthFreq",  amt="BillTrafficOthAmount"))),
  list(cat="BillClothing",  label="Clothing/fashion",     bases=list(Own=list(freq="BillClothingOwnFreq", amt="BillClothingOwnAmount"), Oth=list(freq="BillClothingOthFreq", amt="BillClothingOthAmount"))),
  list(cat="BillFurniture", label="Furniture",            bases=list(Own=list(freq="BillFurnitureOwnFreq",amt="BillFurnitureOwnAmount"),Oth=list(freq="BillFurnitureOthFreq",amt="BillFurnitureOthAmount"))),
  list(cat="BillEducation", label="Education",            bases=list(Own=list(freq="BillEducationOwnFreq",amt="BillEducationOwnAmount"),Oth=list(freq="BillEducationOthFreq",amt="BillEducationOthAmount"))),
  list(cat="BillHealth",    label="Health",               bases=list(Own=list(freq="BillHealthOwnFreq",   amt="BillHealthOwnAmount"),   Oth=list(freq="BillHealthOthFreq",   amt="BillHealthOthAmount"))),
  list(cat="BillRetail",    label="Retail credit",        bases=list(Own=list(freq="BillRetailOwnFreq",   amt="BillRetailOwnAmount"),   Oth=list(freq="BillRetailOthFreq",   amt="BillRetailOthAmount"))),
  list(cat="BillOther",     label="Other bills",          bases=list(Own=list(freq="BillOtherOwnFreq",    amt="BillOtherOwnAmount"),    Oth=list(freq="BillOtherOthFreq",    amt="BillOtherOthAmount"))),
  # no frequency question - assumed cadence, set in the config
  list(cat="BillDSTV",      label="DSTV / Multichoice",   bases=list(Own=list(freq=NA, amt="BillDSTVOwnAmount"),      Oth=list(freq=NA, amt="BillDSTVOthAmount"))),
  list(cat="BillMunicipal", label="Municipal account",    bases=list(Own=list(freq=NA, amt="BillMunicipalOwnAmount"), Oth=list(freq=NA, amt="BillMunicipalOthAmount"))),
  list(cat="BillTelkom",    label="Telkom / cellphone",   bases=list(Own=list(freq=NA, amt="BillTelkomOwnAmount"),    Oth=list(freq=NA, amt="BillTelkomOthAmount"))),
  list(cat="BillInsurance", label="Insurance / funeral",  bases=list(Own=list(freq=NA, amt="BillInsuranceOwnAmount"), Oth=list(freq=NA, amt="BillInsuranceOthAmount"))),
  list(cat="BillInternet",  label="Internet subscription",bases=list(Own=list(freq=NA, amt="BillInternetOwnAmount"),  Oth=list(freq=NA, amt="BillInternetOthAmount"))),
  list(cat="BillVehicle",   label="Vehicle licence",      bases=list(Own=list(freq=NA, amt="BillVehicleOwnAmount"),   Oth=list(freq=NA, amt="BillVehicleOthAmount"))),
  # TV licence has NO amount and NO frequency question in the survey - it is a
  # fixed annual fee, so presence comes off the bill-list selection and the
  # amount is imputed from the config (R265 p.a., Duncan 22 July).
  list(cat="BillTVLicence", label="TV licence", bases=list(
    Own=list(freq=NA, amt=NA, presence="BillOwnWhich", presence_opt="TV License"),
    Oth=list(freq=NA, amt=NA, presence="BillOthWhich", presence_opt="TV License"))),
  # single cascade - total only
  list(cat="Lotto",   label="LOTTO",                 bases=list(Total=list(freq="LottoFreq",   amt="LottoAmount"))),
  list(cat="Betting", label="Betting vouchers",      bases=list(Total=list(freq="BetFreq",     amt="BetAmount"))),
  list(cat="DomSend", label="Domestic transfer sent",bases=list(Total=list(freq="DomSendFreq", amt="DomSendAmount"))),
  list(cat="DomRcv",  label="Domestic transfer received", bases=list(Total=list(freq="DomRcvFreq", amt="DomRcvAmount"))),
  list(cat="IntlSend",label="International transfer",bases=list(Total=list(freq="IntlSendFreq",amt="IntlSendAmount"))),
  list(cat="EventSportWatch", label="Sport - watching",   bases=list(Total=list(freq="EventSportWatchFreq", amt="EventSportWatchAmount"))),
  list(cat="EventSportPlay",  label="Sport - participation", bases=list(Total=list(freq="EventSportPlayFreq", amt="EventSportPlayAmount"))),
  list(cat="EventConcert",    label="Concerts",           bases=list(Total=list(freq="EventConcertFreq",  amt="EventConcertAmount"))),
  list(cat="EventCultural",   label="Cultural events",    bases=list(Total=list(freq="EventCulturalFreq", amt="EventCulturalAmount"))),
  list(cat="EventTheatre",    label="Theatre",            bases=list(Total=list(freq="EventTheatreFreq",  amt="EventTheatreAmount"))),
  list(cat="EventOther",      label="Other events",       bases=list(Total=list(freq="EventOtherFreq",    amt="EventOtherAmount"))),
  # count-based, spend imputed from the config
  list(cat="FlightDomestic",   label="Domestic flights",      bases=list(Total=list(freq=NA, amt=NA, count="FlightDomCount",  legs="FlightDomReturn"))),
  list(cat="FlightInternational", label="International flights", bases=list(Total=list(freq=NA, amt=NA, count="FlightIntlCount", legs="FlightIntlReturn"))),
  list(cat="LongDistanceBus",  label="Long distance bus",     bases=list(Total=list(freq=NA, amt=NA, count="LDBusCount",       legs="LDBusReturn")))
)

rows <- list()
for (c in CATS) for (b in names(c$bases)) {
  s <- c$bases[[b]]
  fr <- if (is.na(s$freq)) rep(NA_character_, 4) else paste0(s$freq, 1:4)
  miss <- fr[!is.na(fr) & !vapply(fr, have, logical(1))]
  rows[[length(rows)+1L]] <- data.frame(
    category = c$cat, label = c$label, base = b,
    freq1 = fr[1], freq2 = fr[2], freq3 = fr[3], freq4 = fr[4],
    amount_alias = s$amt %||% NA_character_,
    amount_basis = if (is.null(s$amt) || is.na(s$amt)) "imputed" else basis_of(s$amt),
    count_alias  = s$count %||% NA_character_,
    legs_alias   = s$legs  %||% NA_character_,
    # for categories with no amount/frequency question of their own, presence is
    # read off an option selected in another question
    presence_alias  = s$presence     %||% NA_character_,
    presence_option = s$presence_opt %||% NA_character_,
    # filled from the config: monthly / annual for the no-frequency bills
    assumed_cadence = if (is.na(s$freq) && !is.null(s$amt) && !is.na(s$amt)) "SET_IN_CONFIG" else NA_character_,
    # value transacted vs consumption spend
    spend_class = dplyr_na <- NA_character_,
    aliases_missing = if (length(miss)) paste(miss, collapse=";") else "",
    stringsAsFactors = FALSE)
}
M <- do.call(rbind, rows)

# classify: transfers and bill obligations are value transacted, not consumption
M$spend_class <- ifelse(grepl("^Bill", M$category), "obligation",
                 ifelse(M$category %in% c("DomSend","IntlSend"), "transfer",
                 ifelse(M$category == "DomRcv", "received", "consumption")))
M$assumed_cadence[M$category %in% c("BillDSTV","BillMunicipal","BillTelkom","BillInsurance","BillInternet")] <- "monthly"
M$assumed_cadence[M$category %in% c("BillVehicle","BillTVLicence")] <- "annual"
M$amount_basis[M$category == "BillTVLicence"] <- "imputed"

utils::write.csv(M, "vas_category_map.csv", row.names = FALSE, na = "")
cat("wrote vas_category_map.csv:", nrow(M), "rows\n\n")

bad <- M[nzchar(M$aliases_missing), ]
if (nrow(bad)) { cat("!! aliases referenced but NOT present in the survey:\n"); print(bad[,c("category","base","aliases_missing")], row.names=FALSE) } else
  cat("every frequency alias referenced exists in the survey\n")

miss_amt <- M[!is.na(M$amount_alias) & !vapply(M$amount_alias, have, logical(1)), ]
if (nrow(miss_amt)) { cat("\n!! amount aliases not found:\n"); print(miss_amt[,c("category","base","amount_alias")], row.names=FALSE) }

cat("\n--- amount basis detected from question wording ---\n")
print(table(M$amount_basis, M$spend_class))
cat("\n--- rows per treatment ---\n")
print(table(M$base))
