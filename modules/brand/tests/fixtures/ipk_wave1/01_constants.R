# ==============================================================================
# IPK WAVE 1 FIXTURE — CONSTANTS
# ==============================================================================
# Synthetic universe for the IPK Wave 1 fixture. Every other fixture script
# (data generation + Survey_Structure + Brand_Config) derives from these
# constants so the whole bundle stays self-consistent.
#
# Categories follow the live IPK Alchemer build — 4 Core (DSS, POS, PAS, BAK)
# + 5 Adjacent (SLD, STO, PES, COO, ANT). Only DSS has the deep dive populated;
# Core categories POS/PAS/BAK are declared Active but have shell-only data so
# the partial-data placeholder path is exercised.
#
# Edit IPK_FIXTURE_SEED to regenerate with a different RNG seed. Keep N_RESP
# at 1200 to mirror the live IPK Wave 1 sample size.
# ==============================================================================

# ------------------------------------------------------------------------------
# Reproducibility + study size
# ------------------------------------------------------------------------------

IPK_FIXTURE_SEED <- 20260430L
IPK_N_RESPONDENTS <- 1200L
IPK_WAVE <- 1L
IPK_WOM_TIMEFRAME <- "3 months"

# ------------------------------------------------------------------------------
# Categories: 4 Core (full deep dive scope) + 5 Adjacent (awareness only)
# ------------------------------------------------------------------------------

IPK_CATEGORIES <- list(
  list(code = "DSS", label = "Dry Seasonings & Spices", role = "Core",
       active = "Y", analysis_depth = "full",
       timeframe_long = "12 months", timeframe_target = "3 months"),
  list(code = "POS", label = "Pour Over Sauces", role = "Core",
       active = "Y", analysis_depth = "full",
       timeframe_long = "12 months", timeframe_target = "3 months"),
  list(code = "PAS", label = "Pasta Sauces", role = "Core",
       active = "Y", analysis_depth = "full",
       timeframe_long = "12 months", timeframe_target = "3 months"),
  list(code = "BAK", label = "Baking Mixes", role = "Core",
       active = "Y", analysis_depth = "full",
       timeframe_long = "12 months", timeframe_target = "6 months"),
  list(code = "SLD", label = "Salad Dressings", role = "Adjacent",
       active = "Y", analysis_depth = "awareness_only",
       timeframe_long = "12 months", timeframe_target = NA_character_),
  list(code = "STO", label = "Stock Powder / Liquid", role = "Adjacent",
       active = "Y", analysis_depth = "awareness_only",
       timeframe_long = "12 months", timeframe_target = NA_character_),
  list(code = "PES", label = "Pestos", role = "Adjacent",
       active = "Y", analysis_depth = "awareness_only",
       timeframe_long = "12 months", timeframe_target = NA_character_),
  list(code = "COO", label = "Cook-in Sauces", role = "Adjacent",
       active = "Y", analysis_depth = "awareness_only",
       timeframe_long = "12 months", timeframe_target = NA_character_),
  list(code = "ANT", label = "Anti-pasta", role = "Adjacent",
       active = "Y", analysis_depth = "awareness_only",
       timeframe_long = "12 months", timeframe_target = NA_character_)
)

IPK_CORE_CATS <- vapply(
  Filter(function(c) c$role == "Core", IPK_CATEGORIES),
  function(c) c$code, character(1)
)

IPK_ADJACENT_CATS <- vapply(
  Filter(function(c) c$role == "Adjacent", IPK_CATEGORIES),
  function(c) c$code, character(1)
)

# Only DSS has populated deep-dive data in this fixture (matches live IPK build state)
IPK_DEEP_DIVE_CATS <- c("DSS")

# ------------------------------------------------------------------------------
# Brand lists per category. Slot count = length(brands) + 1 ("NONE")
# ------------------------------------------------------------------------------

IPK_BRANDS <- list(
  DSS = c("IPK", "ROB", "KNORR", "CART", "CHS", "FNF", "WWT", "PNP",
          "SSG", "RAJ", "SAF", "SPM", "CHK", "HND", "DEL"),
  POS = c("IPK", "KNORR", "ROY", "MAG", "WWT", "PNP", "CHK", "CRO",
          "RHG", "SPMP", "FNFP", "MAS", "BRG", "DEL", "MUTT", "CON"),
  PAS = c("IPK", "DOL", "KNORR", "BAR", "WWT", "PNP", "CHK", "FNF",
          "RIN", "RAG", "SPMS", "CRO", "MUT", "TIB", "MAR", "BAS",
          "GIA", "TRE", "DEL", "PRG", "CIR", "AMS"),
  BAK = c("IPK", "ROB", "GHL", "ANC", "WWT", "PNP", "CHK", "FNF",
          "BAK", "SNF", "MOI", "GAR", "CHF", "TAS", "MOR", "DEL"),
  SLD = c("IPK", "KFT", "MIR", "WWT", "PNP", "CHK", "HID", "FNF",
          "MED", "CAE", "RAN", "OVO"),
  STO = c("IPK", "KNORR", "ROY", "MAG", "WWT", "PNP", "CHK", "BIL",
          "BSO", "OXO", "FNF", "CON"),
  PES = c("IPK", "BAR", "WWT", "PNP", "CHK", "MUT", "GIA", "SACL",
          "TRE", "BAS", "FNF", "PIC", "DEL"),
  COO = c("IPK", "KNORR", "MAG", "WWT", "PNP", "CHK", "FNF", "MAS",
          "ROY", "CIR", "DEL", "PAT"),
  ANT = c("IPK", "BAR", "WWT", "PNP", "CHK", "FNF", "MUT", "DEL",
          "GIA", "TRE", "PRG", "BAS", "MED", "OLY")
)

# Focal brand per category (the client brand)
IPK_FOCAL_BRAND <- list(
  DSS = "IPK", POS = "IPK", PAS = "IPK", BAK = "IPK",
  SLD = "IPK", STO = "IPK", PES = "IPK", COO = "IPK", ANT = "IPK"
)

# Slot count for any Multi_Mention brand question = length(brands) + 1 (NONE)
ipk_brand_slot_count <- function(cat_code) {
  length(IPK_BRANDS[[cat_code]]) + 1L
}

# ------------------------------------------------------------------------------
# CEPs and Attributes (DSS only — other Core cats added later as Jess builds them)
# ------------------------------------------------------------------------------

IPK_CEPS_DSS <- list(
  list(code = "CEP01", text = "When I'm seasoning a roast meat dish"),
  list(code = "CEP02", text = "When I'm cooking on a busy weeknight"),
  list(code = "CEP03", text = "When I want bold authentic flavour"),
  list(code = "CEP04", text = "When I'm trying a new recipe"),
  list(code = "CEP05", text = "When I'm cooking for guests"),
  list(code = "CEP06", text = "When I'm making a stew or curry"),
  list(code = "CEP07", text = "When I'm grilling or braaiing"),
  list(code = "CEP08", text = "When I want to keep things simple"),
  list(code = "CEP09", text = "When I'm trying to eat healthy"),
  list(code = "CEP10", text = "When I'm cooking with chicken"),
  list(code = "CEP11", text = "When I'm cooking with beef or lamb"),
  list(code = "CEP12", text = "When I'm cooking with fish"),
  list(code = "CEP13", text = "When I'm cooking vegetarian"),
  list(code = "CEP14", text = "When I want a familiar trusted taste"),
  list(code = "CEP15", text = "When I'm cooking for kids")
)

IPK_ATTS_DSS <- list(
  list(code = "ATT01", text = "Good value for money"),
  list(code = "ATT02", text = "Trusted quality"),
  list(code = "ATT03", text = "Authentic"),
  list(code = "ATT04", text = "Premium"),
  list(code = "ATT05", text = "Convenient"),
  list(code = "ATT06", text = "Versatile"),
  list(code = "ATT07", text = "Healthy"),
  list(code = "ATT08", text = "Innovative"),
  list(code = "ATT09", text = "Made for South Africans"),
  list(code = "ATT10", text = "A brand I'd recommend"),
  list(code = "ATT11", text = "Family friendly"),
  list(code = "ATT12", text = "Distinctive flavour"),
  list(code = "ATT13", text = "Good for everyday cooking"),
  list(code = "ATT14", text = "Good for special occasions"),
  list(code = "ATT15", text = "A brand I'm proud to use")
)

# ------------------------------------------------------------------------------
# Scales (option codes for Single_Response questions)
# ------------------------------------------------------------------------------

# Attitude: 1 Love, 2 Prefer, 3 Ambivalent, 4 Reject, 5 No opinion
IPK_ATTITUDE_CODES <- c("1", "2", "3", "4", "5")
IPK_ATTITUDE_LABELS <- c(
  "1" = "Love it - my favourite",
  "2" = "Among the ones I prefer",
  "3" = "Wouldn't usually consider, but would if no other option",
  "4" = "Refuse to buy",
  "5" = "No opinion / don't know this brand"
)

# Cat buying: 1 Several/wk, 2 Once/wk, 3 Few/mo, 4 Monthly or less, 5 No longer
IPK_CATBUY_CODES <- c("1", "2", "3", "4", "5")
IPK_CATBUY_LABELS <- c(
  "1" = "Several times a week",
  "2" = "About once a week",
  "3" = "A few times a month",
  "4" = "Monthly or less",
  "5" = "I no longer buy this category"
)

# WOM count: 1 Once, 2 Twice, 3 Three, 4 Four, 5 Five+
IPK_WOM_COUNT_CODES <- c("1", "2", "3", "4", "5")
IPK_WOM_COUNT_LABELS <- c(
  "1" = "Once", "2" = "Twice", "3" = "3 times",
  "4" = "4 times", "5" = "5 or more times"
)

# ------------------------------------------------------------------------------
# Channels and pack sizes (DSS-style, 6 + 4)
# ------------------------------------------------------------------------------

IPK_CHANNELS <- list(
  list(code = "SPMKT",  label = "Supermarket"),
  list(code = "DISCNT", label = "Discount retailer"),
  list(code = "CORNER", label = "Corner shop / spaza"),
  list(code = "ONLINE", label = "Online"),
  list(code = "FARM",   label = "Farm stall / deli"),
  list(code = "OTHER",  label = "Other")
)

IPK_PACK_SIZES <- list(
  list(code = "SMALL",  label = "Small / single-serve"),
  list(code = "MEDIUM", label = "Medium / family pack"),
  list(code = "LARGE",  label = "Large / value pack"),
  list(code = "MULTI",  label = "Multi-pack / bulk")
)

# ------------------------------------------------------------------------------
# Demographics distributions (numeric codes, distribution probs)
# ------------------------------------------------------------------------------

IPK_DEMO_AGE <- list(
  codes = c("1", "2", "3", "4", "5", "6"),
  labels = c("18-24", "25-34", "35-44", "45-54", "55-64", "65+"),
  probs  = c(0.05, 0.30, 0.35, 0.20, 0.08, 0.02)
)
IPK_DEMO_GENDER <- list(
  codes = c("1", "2", "3", "99"),
  labels = c("Female", "Male", "Non-binary", "Prefer not to say"),
  probs  = c(0.92, 0.06, 0.01, 0.01)
)
IPK_DEMO_PROVINCE <- list(
  codes = c("1", "2", "3", "4", "5"),
  labels = c("Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape", "Other"),
  probs  = c(0.45, 0.25, 0.15, 0.10, 0.05)
)
IPK_DEMO_GROCERY_ROLE <- list(
  codes = c("1", "2", "3"),
  labels = c("All/most grocery shopping", "Share equally",
             "Someone else does most"),
  probs  = c(0.65, 0.25, 0.10)
)
IPK_DEMO_HH_SIZE <- list(
  codes = c("1", "2", "3", "4"),
  labels = c("Just me", "2 people", "3-4 people", "5+ people"),
  probs  = c(0.10, 0.20, 0.50, 0.20)
)
IPK_DEMO_EMPLOYMENT <- list(
  codes = c("1", "2", "3", "4", "5", "99"),
  labels = c("Full-time", "Part-time", "Self-employed",
             "Not employed", "Retired", "Prefer not to say"),
  probs  = c(0.50, 0.15, 0.15, 0.10, 0.07, 0.03)
)
IPK_DEMO_SEM <- list(
  codes = c("1", "2", "3", "4", "5", "99"),
  labels = c("Under R5,000", "R5,000-R14,999", "R15,000-R29,999",
             "R30,000-R49,999", "R50,000+", "Prefer not to say"),
  probs  = c(0.10, 0.25, 0.30, 0.20, 0.10, 0.05)
)

# Qualifying (asked at start; eligible only)
IPK_QUAL_GENDER_VALUES <- c("Female")  # IPK target
IPK_QUAL_AGE_VALUES <- c("30-34", "35-39", "40-44", "45-50")
IPK_QUAL_INDUSTRY_VALUES <- c("None")  # all eligible
IPK_QUAL_REGION_VALUES <- c("GAU", "WC", "KZN", "EC")
IPK_QUAL_REGION_PROBS <- c(0.45, 0.30, 0.18, 0.07)
