# ==============================================================================
# 9CAT SYNTHETIC EXAMPLE - CONSTANTS
# ==============================================================================
# Nine-category CBM study matching the Better Brand Health questionnaire template
# (Prof. Jenni Romaniuk / Ehrenberg-Bass Institute).
#
# Focal brand: Ina Paarman's Kitchen (IPK) across all 9 categories.
#
# Category structure (matches questionnaire screener SQ1 / SQ2):
#   FULL CBM battery (4 categories):
#     DSS  - Dry Seasonings & Spices
#     POS  - Pour Over Sauces
#     PAS  - Pasta Sauces
#     BAK  - Baking Mixes
#   AWARENESS ONLY (5 categories):
#     SLD  - Salad Dressings
#     STO  - Stock Powder / Liquid
#     PES  - Pestos
#     COO  - Cook-in Sauces
#     ANT  - Anti-pasta
#
# Column-naming conventions:
#   Awareness    : BRANDAWARE_{CAT}_{BRAND}
#   Attitude     : BRANDATT1_{CAT}_{BRAND}
#   Penetration  : BRANDPEN1_{CAT}_{BRAND}
#   CEP matrix   : {CEPCODE}_{BRAND}  — globally unique codes
#                  DSS=CEP01-15, POS=CEP16-30, PAS=CEP31-45, BAK=CEP46-60
#   Attr matrix  : {CAT}_{ATTRCODE}_{BRAND}  (full categories only)
#   WOM          : WOM_POS_REC_{BRAND}  etc.  (full categories only)
#   DBA          : DBA_FAME_{ASSET} / DBA_UNIQUE_{ASSET}  (IPK only, all respondents)
# ==============================================================================


# ==============================================================================
# STUDY METADATA
# ==============================================================================

cat9_study_meta <- function() {
  list(
    project_name   = "Ina Paarman's Kitchen - Brand Health Wave 1 (9-Category CBM)",
    client_name    = "Ina Paarman's Kitchen",
    focal_brand    = "IPK",
    wave           = 1,
    sample_size    = 400,   # 100 per full category (DSS, POS, PAS, BAK)
    study_type     = "cross-sectional",
    data_file_name = "ipk_9cat_wave1.xlsx",
    fieldwork      = "April 2026"
  )
}


# ==============================================================================
# CATEGORY DEFINITIONS
# ==============================================================================

# Analysis depth: "full" = complete CBM battery;  "awareness_only" = brand awareness only
cat9_categories <- function() {
  list(
    list(code = "DSS", name = "Dry Seasonings & Spices", type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         analysis_depth = "full",           display_order = 1),
    list(code = "POS", name = "Pour Over Sauces",        type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         analysis_depth = "full",           display_order = 2),
    list(code = "PAS", name = "Pasta Sauces",            type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         analysis_depth = "full",           display_order = 3),
    list(code = "BAK", name = "Baking Mixes",            type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         analysis_depth = "full",           display_order = 4),
    list(code = "SLD", name = "Salad Dressings",         type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         analysis_depth = "awareness_only", display_order = 5),
    list(code = "STO", name = "Stock Powder / Liquid",   type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         analysis_depth = "awareness_only", display_order = 6),
    list(code = "PES", name = "Pestos",                  type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         analysis_depth = "awareness_only", display_order = 7),
    list(code = "COO", name = "Cook-in Sauces",          type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         analysis_depth = "awareness_only", display_order = 8),
    list(code = "ANT", name = "Anti-pasta",              type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         analysis_depth = "awareness_only", display_order = 9)
  )
}

cat9_category    <- function(cc) { for (c in cat9_categories()) if (c$code == cc) return(c); stop(cc) }
cat9_full_codes  <- function() Filter(function(c) c$analysis_depth == "full",           cat9_categories())
cat9_aware_codes <- function() Filter(function(c) c$analysis_depth == "awareness_only", cat9_categories())


# ==============================================================================
# BRANDS  (IPK focal, 9 others per category; some brands span categories)
# ==============================================================================

cat9_brands <- function(cat_code) {
  switch(cat_code,

    DSS = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen",    is_focal = TRUE,
           strength = 0.72, awareness_rate = 0.85, quality_tier = "premium",    display_order = 1),
      list(code = "ROB",   label = "Robertsons",               is_focal = FALSE,
           strength = 0.95, awareness_rate = 0.94, quality_tier = "mainstream", display_order = 2),
      list(code = "KNORR", label = "Knorr",                    is_focal = FALSE,
           strength = 0.68, awareness_rate = 0.82, quality_tier = "mainstream", display_order = 3),
      list(code = "CART",  label = "Cartwright's",             is_focal = FALSE,
           strength = 0.40, awareness_rate = 0.55, quality_tier = "premium",    display_order = 4),
      list(code = "RAJAH", label = "Rajah",                    is_focal = FALSE,
           strength = 0.55, awareness_rate = 0.68, quality_tier = "mainstream", display_order = 5),
      list(code = "SFRI",  label = "Safari",                   is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.48, quality_tier = "mainstream", display_order = 6),
      list(code = "SPMEC", label = "Spice Mecca",              is_focal = FALSE,
           strength = 0.30, awareness_rate = 0.38, quality_tier = "premium",    display_order = 7),
      list(code = "WWTDSS",label = "Woolworths Taste",         is_focal = FALSE,
           strength = 0.58, awareness_rate = 0.72, quality_tier = "premium",    display_order = 8),
      list(code = "PNPDSS",label = "PnP No Name",              is_focal = FALSE,
           strength = 0.45, awareness_rate = 0.62, quality_tier = "value",      display_order = 9),
      list(code = "CKRDSS",label = "Checkers House Brand",     is_focal = FALSE,
           strength = 0.42, awareness_rate = 0.58, quality_tier = "value",      display_order = 10)
    ),

    POS = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen",    is_focal = TRUE,
           strength = 0.68, awareness_rate = 0.80, quality_tier = "premium",    display_order = 1),
      list(code = "KNORR", label = "Knorr",                    is_focal = FALSE,
           strength = 0.88, awareness_rate = 0.92, quality_tier = "mainstream", display_order = 2),
      list(code = "ROYCO", label = "Royco",                    is_focal = FALSE,
           strength = 0.75, awareness_rate = 0.85, quality_tier = "mainstream", display_order = 3),
      list(code = "MAGGI", label = "Maggi",                    is_focal = FALSE,
           strength = 0.62, awareness_rate = 0.75, quality_tier = "mainstream", display_order = 4),
      list(code = "SWISS", label = "Nestlé Swiss",             is_focal = FALSE,
           strength = 0.58, awareness_rate = 0.70, quality_tier = "mainstream", display_order = 5),
      list(code = "BISTO", label = "Bisto",                    is_focal = FALSE,
           strength = 0.50, awareness_rate = 0.62, quality_tier = "mainstream", display_order = 6),
      list(code = "WWPOS", label = "Woolworths Pour Sauces",   is_focal = FALSE,
           strength = 0.48, awareness_rate = 0.60, quality_tier = "premium",    display_order = 7),
      list(code = "HOLLS", label = "Hollandia",                is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.45, quality_tier = "mainstream", display_order = 8),
      list(code = "PNPPOS",label = "PnP Pour Sauces",          is_focal = FALSE,
           strength = 0.40, awareness_rate = 0.55, quality_tier = "value",      display_order = 9),
      list(code = "CKRPOS",label = "Checkers Pour Sauces",     is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.52, quality_tier = "value",      display_order = 10)
    ),

    PAS = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen",    is_focal = TRUE,
           strength = 0.70, awareness_rate = 0.83, quality_tier = "premium",    display_order = 1),
      list(code = "KNORR", label = "Knorr",                    is_focal = FALSE,
           strength = 0.65, awareness_rate = 0.80, quality_tier = "mainstream", display_order = 2),
      list(code = "DOLMIO",label = "Dolmio",                   is_focal = FALSE,
           strength = 0.88, awareness_rate = 0.91, quality_tier = "mainstream", display_order = 3),
      list(code = "ALGLD", label = "All Gold",                 is_focal = FALSE,
           strength = 0.72, awareness_rate = 0.86, quality_tier = "mainstream", display_order = 4),
      list(code = "FATTS", label = "Fatti's & Moni's",         is_focal = FALSE,
           strength = 0.55, awareness_rate = 0.70, quality_tier = "mainstream", display_order = 5),
      list(code = "BARLA", label = "Barilla",                  is_focal = FALSE,
           strength = 0.45, awareness_rate = 0.58, quality_tier = "premium",    display_order = 6),
      list(code = "SDEL",  label = "Simply Delish",            is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.50, quality_tier = "mainstream", display_order = 7),
      list(code = "WWPAS", label = "Woolworths Pasta Range",   is_focal = FALSE,
           strength = 0.52, awareness_rate = 0.65, quality_tier = "premium",    display_order = 8),
      list(code = "PNPPAS",label = "PnP Pasta Sauces",         is_focal = FALSE,
           strength = 0.40, awareness_rate = 0.55, quality_tier = "value",      display_order = 9),
      list(code = "CKRPAS",label = "Checkers Pasta Range",     is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.52, quality_tier = "value",      display_order = 10)
    ),

    BAK = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen",    is_focal = TRUE,
           strength = 0.75, awareness_rate = 0.88, quality_tier = "premium",    display_order = 1),
      list(code = "INNAS", label = "Inna's SA",                is_focal = FALSE,
           strength = 0.60, awareness_rate = 0.72, quality_tier = "premium",    display_order = 2),
      list(code = "BAKELS",label = "Bakels",                   is_focal = FALSE,
           strength = 0.50, awareness_rate = 0.62, quality_tier = "mainstream", display_order = 3),
      list(code = "PILLSB",label = "Pillsbury",                is_focal = FALSE,
           strength = 0.68, awareness_rate = 0.80, quality_tier = "mainstream", display_order = 4),
      list(code = "MOLLY", label = "Molly Cake",               is_focal = FALSE,
           strength = 0.45, awareness_rate = 0.55, quality_tier = "mainstream", display_order = 5),
      list(code = "LANCL", label = "Lancewood",                is_focal = FALSE,
           strength = 0.55, awareness_rate = 0.68, quality_tier = "premium",    display_order = 6),
      list(code = "WWBAK", label = "Woolworths Baking",        is_focal = FALSE,
           strength = 0.50, awareness_rate = 0.62, quality_tier = "premium",    display_order = 7),
      list(code = "PNPBAK",label = "PnP Baking",               is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.50, quality_tier = "value",      display_order = 8),
      list(code = "CKRBAK",label = "Checkers Baking",          is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.48, quality_tier = "value",      display_order = 9),
      list(code = "SIMBOL",label = "Simply the Best",          is_focal = FALSE,
           strength = 0.32, awareness_rate = 0.42, quality_tier = "value",      display_order = 10)
    ),

    SLD = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen",    is_focal = FALSE,
           strength = 0.68, awareness_rate = 0.80, quality_tier = "premium",    display_order = 1),
      list(code = "ALGLD", label = "All Gold",                 is_focal = FALSE,
           strength = 0.70, awareness_rate = 0.84, quality_tier = "mainstream", display_order = 2),
      list(code = "KRAFT", label = "Kraft",                    is_focal = FALSE,
           strength = 0.62, awareness_rate = 0.78, quality_tier = "mainstream", display_order = 3),
      list(code = "BULLS", label = "Bull Brand",               is_focal = FALSE,
           strength = 0.55, awareness_rate = 0.72, quality_tier = "mainstream", display_order = 4),
      list(code = "NEWMN", label = "Newman's Own",             is_focal = FALSE,
           strength = 0.42, awareness_rate = 0.55, quality_tier = "premium",    display_order = 5),
      list(code = "BALEA", label = "Baleia",                   is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.45, quality_tier = "premium",    display_order = 6),
      list(code = "WWSLD", label = "Woolworths Dressings",     is_focal = FALSE,
           strength = 0.50, awareness_rate = 0.62, quality_tier = "premium",    display_order = 7),
      list(code = "PNPSLD",label = "PnP Dressings",            is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.52, quality_tier = "value",      display_order = 8),
      list(code = "CKRSLD",label = "Checkers Dressings",       is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.48, quality_tier = "value",      display_order = 9),
      list(code = "AMANU", label = "Amanzi Artisan",           is_focal = FALSE,
           strength = 0.25, awareness_rate = 0.32, quality_tier = "premium",    display_order = 10)
    ),

    STO = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen",    is_focal = FALSE,
           strength = 0.65, awareness_rate = 0.78, quality_tier = "premium",    display_order = 1),
      list(code = "KNORR", label = "Knorr",                    is_focal = FALSE,
           strength = 0.90, awareness_rate = 0.94, quality_tier = "mainstream", display_order = 2),
      list(code = "MAGGI", label = "Maggi",                    is_focal = FALSE,
           strength = 0.72, awareness_rate = 0.82, quality_tier = "mainstream", display_order = 3),
      list(code = "ROYCO", label = "Royco",                    is_focal = FALSE,
           strength = 0.68, awareness_rate = 0.78, quality_tier = "mainstream", display_order = 4),
      list(code = "SCHWTZ",label = "Schwartz",                 is_focal = FALSE,
           strength = 0.40, awareness_rate = 0.52, quality_tier = "mainstream", display_order = 5),
      list(code = "NATST", label = "Nature's Stock",           is_focal = FALSE,
           strength = 0.30, awareness_rate = 0.38, quality_tier = "premium",    display_order = 6),
      list(code = "WWSTO", label = "Woolworths Stock",         is_focal = FALSE,
           strength = 0.48, awareness_rate = 0.60, quality_tier = "premium",    display_order = 7),
      list(code = "PNPSTO",label = "PnP Stock",                is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.52, quality_tier = "value",      display_order = 8),
      list(code = "CKRSTO",label = "Checkers Stock",           is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.48, quality_tier = "value",      display_order = 9),
      list(code = "ARTSTO",label = "Artisan Stock",            is_focal = FALSE,
           strength = 0.22, awareness_rate = 0.28, quality_tier = "premium",    display_order = 10)
    ),

    PES = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen",    is_focal = FALSE,
           strength = 0.70, awareness_rate = 0.82, quality_tier = "premium",    display_order = 1),
      list(code = "BARLA", label = "Barilla",                  is_focal = FALSE,
           strength = 0.60, awareness_rate = 0.72, quality_tier = "premium",    display_order = 2),
      list(code = "SACLA", label = "Sacla",                    is_focal = FALSE,
           strength = 0.55, awareness_rate = 0.68, quality_tier = "premium",    display_order = 3),
      list(code = "BUONIT",label = "Buonitalia",               is_focal = FALSE,
           strength = 0.40, awareness_rate = 0.50, quality_tier = "premium",    display_order = 4),
      list(code = "NATFSH",label = "Nature Fresh",             is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.45, quality_tier = "mainstream", display_order = 5),
      list(code = "PONTI", label = "Ponti",                    is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.48, quality_tier = "premium",    display_order = 6),
      list(code = "WWPES", label = "Woolworths Pestos",        is_focal = FALSE,
           strength = 0.52, awareness_rate = 0.65, quality_tier = "premium",    display_order = 7),
      list(code = "PNPPES",label = "PnP Pestos",               is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.48, quality_tier = "value",      display_order = 8),
      list(code = "CKRPES",label = "Checkers Pestos",          is_focal = FALSE,
           strength = 0.32, awareness_rate = 0.44, quality_tier = "value",      display_order = 9),
      list(code = "ARTPST",label = "Artisan Pesto Co.",        is_focal = FALSE,
           strength = 0.22, awareness_rate = 0.28, quality_tier = "premium",    display_order = 10)
    ),

    COO = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen",    is_focal = FALSE,
           strength = 0.72, awareness_rate = 0.84, quality_tier = "premium",    display_order = 1),
      list(code = "KNORR", label = "Knorr",                    is_focal = FALSE,
           strength = 0.85, awareness_rate = 0.90, quality_tier = "mainstream", display_order = 2),
      list(code = "ROYCO", label = "Royco",                    is_focal = FALSE,
           strength = 0.78, awareness_rate = 0.86, quality_tier = "mainstream", display_order = 3),
      list(code = "DOLMIO",label = "Dolmio",                   is_focal = FALSE,
           strength = 0.70, awareness_rate = 0.80, quality_tier = "mainstream", display_order = 4),
      list(code = "NDOS",  label = "Nando's",                  is_focal = FALSE,
           strength = 0.65, awareness_rate = 0.78, quality_tier = "mainstream", display_order = 5),
      list(code = "SMAC",  label = "So Mac",                   is_focal = FALSE,
           strength = 0.30, awareness_rate = 0.40, quality_tier = "mainstream", display_order = 6),
      list(code = "WWCOO", label = "Woolworths Cook-in",       is_focal = FALSE,
           strength = 0.50, awareness_rate = 0.62, quality_tier = "premium",    display_order = 7),
      list(code = "PNPCOO",label = "PnP Cook-in",              is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.52, quality_tier = "value",      display_order = 8),
      list(code = "CKRCOO",label = "Checkers Cook-in",         is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.48, quality_tier = "value",      display_order = 9),
      list(code = "TASTY", label = "Tasty's Sauces",           is_focal = FALSE,
           strength = 0.28, awareness_rate = 0.36, quality_tier = "mainstream", display_order = 10)
    ),

    ANT = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen",    is_focal = FALSE,
           strength = 0.65, awareness_rate = 0.78, quality_tier = "premium",    display_order = 1),
      list(code = "BARLA", label = "Barilla",                  is_focal = FALSE,
           strength = 0.55, awareness_rate = 0.68, quality_tier = "premium",    display_order = 2),
      list(code = "SACLA", label = "Sacla",                    is_focal = FALSE,
           strength = 0.60, awareness_rate = 0.72, quality_tier = "premium",    display_order = 3),
      list(code = "PONTI", label = "Ponti",                    is_focal = FALSE,
           strength = 0.50, awareness_rate = 0.62, quality_tier = "premium",    display_order = 4),
      list(code = "BUONIT",label = "Buonitalia",               is_focal = FALSE,
           strength = 0.45, awareness_rate = 0.56, quality_tier = "premium",    display_order = 5),
      list(code = "DELLAS",label = "Della's Deli",             is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.44, quality_tier = "premium",    display_order = 6),
      list(code = "WWANT", label = "Woolworths Antipasto",     is_focal = FALSE,
           strength = 0.52, awareness_rate = 0.65, quality_tier = "premium",    display_order = 7),
      list(code = "PNPANT",label = "PnP Antipasto",            is_focal = FALSE,
           strength = 0.32, awareness_rate = 0.44, quality_tier = "value",      display_order = 8),
      list(code = "CKRANT",label = "Checkers Antipasto",       is_focal = FALSE,
           strength = 0.28, awareness_rate = 0.38, quality_tier = "value",      display_order = 9),
      list(code = "ARTANT",label = "Artisan Antipasto Co.",    is_focal = FALSE,
           strength = 0.20, awareness_rate = 0.26, quality_tier = "premium",    display_order = 10)
    ),

    stop(sprintf("Unknown category code: %s", cat_code))
  )
}

cat9_brand_codes     <- function(cc) vapply(cat9_brands(cc), function(b) b$code, character(1))
cat9_all_brand_codes <- function() unique(unlist(lapply(c("DSS","POS","PAS","BAK","SLD","STO","PES","COO","ANT"), cat9_brand_codes)))


# ==============================================================================
# CATEGORY ENTRY POINTS — full categories only (15 per cat, globally unique)
#   DSS: CEP01–CEP15
#   POS: CEP16–CEP30
#   PAS: CEP31–CEP45
#   BAK: CEP46–CEP60
# ==============================================================================

cat9_ceps <- function(cat_code) {
  switch(cat_code,

    DSS = list(
      list(code="CEP01", text="When I'm seasoning a roast meat dish"),
      list(code="CEP02", text="When I'm making a hearty stew or potjie"),
      list(code="CEP03", text="When I'm adding flavour to a stir-fry"),
      list(code="CEP04", text="When I'm making a curry from scratch"),
      list(code="CEP05", text="When I'm seasoning grilled chicken"),
      list(code="CEP06", text="When I'm preparing a marinade for a braai"),
      list(code="CEP07", text="When I'm cooking a quick weeknight meal"),
      list(code="CEP08", text="When I'm making traditional South African dishes"),
      list(code="CEP09", text="When I'm seasoning vegetables or a salad"),
      list(code="CEP10", text="When I'm adding flavour to a soup"),
      list(code="CEP11", text="When I want to experiment with a new recipe"),
      list(code="CEP12", text="When I'm cooking for the whole family"),
      list(code="CEP13", text="When I'm entertaining guests at home"),
      list(code="CEP14", text="When I want an authentic, bold flavour"),
      list(code="CEP15", text="When I need a reliable, everyday seasoning")
    ),

    POS = list(
      list(code="CEP16", text="When I need a quick sauce to finish off a dish"),
      list(code="CEP17", text="When I want to make a weeknight meal feel special"),
      list(code="CEP18", text="When I'm cooking grilled meat or chicken at home"),
      list(code="CEP19", text="When I want a creamy sauce for pasta or veg"),
      list(code="CEP20", text="When I'm making a mushroom dish for dinner"),
      list(code="CEP21", text="When I need to save time in the kitchen"),
      list(code="CEP22", text="When I want to impress guests without much effort"),
      list(code="CEP23", text="When cooking a comforting family dinner"),
      list(code="CEP24", text="When I want a sauce that pairs well with steak"),
      list(code="CEP25", text="When I'm making a peppercorn or pepper sauce"),
      list(code="CEP26", text="When I want to add a creamy element to a dish"),
      list(code="CEP27", text="When I'm making a Sunday roast lunch"),
      list(code="CEP28", text="When I want to elevate a simple mid-week dinner"),
      list(code="CEP29", text="When cooking for someone who loves rich flavours"),
      list(code="CEP30", text="When I want a sauce made with quality ingredients")
    ),

    PAS = list(
      list(code="CEP31", text="When I need a quick weeknight dinner"),
      list(code="CEP32", text="When I'm cooking pasta for the whole family"),
      list(code="CEP33", text="When I want something hearty and filling for dinner"),
      list(code="CEP34", text="When I have unexpected guests arriving for dinner"),
      list(code="CEP35", text="When I want a warming, comforting meal on a cold evening"),
      list(code="CEP36", text="When I need to save time on dinner preparation"),
      list(code="CEP37", text="When I want to feed a crowd on a budget"),
      list(code="CEP38", text="When cooking for children who like familiar flavours"),
      list(code="CEP39", text="When I want something that tastes properly home-cooked"),
      list(code="CEP40", text="When I want to try a new pasta recipe for the family"),
      list(code="CEP41", text="When I fancy an Italian-style meal at home"),
      list(code="CEP42", text="When I want to make a healthier pasta dish"),
      list(code="CEP43", text="When I need a satisfying meal after a long day at work"),
      list(code="CEP44", text="When I'm cooking something a bit more special for dinner"),
      list(code="CEP45", text="When I want a sauce made with quality, natural ingredients")
    ),

    BAK = list(
      list(code="CEP46", text="When I'm baking a birthday or celebration cake"),
      list(code="CEP47", text="When I need a quick bake for unexpected guests"),
      list(code="CEP48", text="When I'm baking with my children on a weekend"),
      list(code="CEP49", text="When I want a reliable, foolproof baking result"),
      list(code="CEP50", text="When I'm making cupcakes for a school event"),
      list(code="CEP51", text="When I want a homemade bake without all the effort"),
      list(code="CEP52", text="When I'm making muffins or scones for the family"),
      list(code="CEP53", text="When I want to impress with a baked treat at a gathering"),
      list(code="CEP54", text="When I'm on a tight budget and want a simple dessert"),
      list(code="CEP55", text="When I want to bake something I know everyone will enjoy"),
      list(code="CEP56", text="When I'm making a chocolate cake from scratch"),
      list(code="CEP57", text="When I want a baking mix with quality ingredients"),
      list(code="CEP58", text="When I'm making cookies or biscuits for school lunchboxes"),
      list(code="CEP59", text="When I want a bake that looks as good as it tastes"),
      list(code="CEP60", text="When I want to treat the family to something homemade")
    ),

    stop(sprintf("No CEPs for awareness-only category: %s", cat_code))
  )
}

cat9_cep_codes <- function(cc) vapply(cat9_ceps(cc), function(c) c$code, character(1))


# ==============================================================================
# BRAND IMAGE ATTRIBUTES  (5, same text across all FULL categories)
# Column names are CATEGORY-prefixed: DSS_ATTR01_IPK, POS_ATTR01_IPK, etc.
# ==============================================================================

cat9_attributes <- function() {
  list(
    list(code = "ATTR01", text = "Good value for money"),
    list(code = "ATTR02", text = "High quality ingredients"),
    list(code = "ATTR03", text = "A brand I trust"),
    list(code = "ATTR04", text = "Consistent taste every time"),
    list(code = "ATTR05", text = "Easy to use in everyday cooking")
  )
}

cat9_attr_codes <- function() vapply(cat9_attributes(), function(a) a$code, character(1))


# ==============================================================================
# DBA ASSETS  (Ina Paarman's Kitchen only — 5 distinctive brand assets)
# All respondents across all 9 categories see these assets.
# ==============================================================================

cat9_dba_assets <- function() {
  list(
    list(code = "LOGO",    label = "Script logo",               asset_type = "image",
         file_path = "assets/ipk_logo_unbranded.png",
         fame_rate = 0.72, unique_attribution_rate = 0.68),
    list(code = "COLOUR",  label = "Red packaging",             asset_type = "image",
         file_path = "assets/ipk_colour_swatch.png",
         fame_rate = 0.55, unique_attribution_rate = 0.38),
    list(code = "JAR",     label = "Glass jar shape",           asset_type = "image",
         file_path = "assets/ipk_jar_silhouette.png",
         fame_rate = 0.62, unique_attribution_rate = 0.55),
    list(code = "CHEF",    label = "Ina Paarman character",     asset_type = "image",
         file_path = "assets/ipk_character.png",
         fame_rate = 0.78, unique_attribution_rate = 0.82),
    list(code = "TAGLINE", label = '"Seasoned to perfection" tagline',
         asset_type = "text", file_path = "",
         fame_rate = 0.28, unique_attribution_rate = 0.22)
  )
}

cat9_dba_codes <- function() vapply(cat9_dba_assets(), function(a) a$code, character(1))


# ==============================================================================
# PURCHASE CHANNELS  (shared across all full categories)
# ==============================================================================

cat9_channels <- function() {
  list(
    list(code = "SUPMKT", label = "Supermarket (e.g. Pick n Pay, Checkers, Woolworths)"),
    list(code = "SPECIA", label = "Speciality food store"),
    list(code = "ONLINE", label = "Online / food delivery app"),
    list(code = "CONVEN", label = "Convenience store / garage forecourt"),
    list(code = "WHOLES", label = "Wholesale / bulk store (e.g. Makro, Costco)"),
    list(code = "MARKET", label = "Farmers market / fresh market"),
    list(code = "OTHER",  label = "Somewhere else")
  )
}

cat9_channel_codes <- function() vapply(cat9_channels(), function(c) c$code, character(1))


# ==============================================================================
# MARKETING REACH ASSETS  (Q013–Q015: ad recognition, brand recall, media)
# ==============================================================================
# Category = "ALL" means the ad was shown to all respondents.
# Category-specific codes restrict the asset to respondents in that focal category.

cat9_reach_assets <- function() {
  list(
    list(code = "ADTV01",   label = "IPK TV spot — 'Taste the difference'",
         category = "ALL", brand = "IPK",
         image_path = "assets/reach/ipk_tv_ad_01.jpg"),
    list(code = "ADDIG01",  label = "IPK digital banner — pasta range",
         category = "PAS", brand = "IPK",
         image_path = "assets/reach/ipk_digital_pas_01.jpg"),
    list(code = "ADDIG02",  label = "IPK digital banner — seasoning range",
         category = "DSS", brand = "IPK",
         image_path = "assets/reach/ipk_digital_dss_01.jpg"),
    list(code = "ADPR01",   label = "IPK print ad — Taste magazine",
         category = "ALL", brand = "IPK",
         image_path = "assets/reach/ipk_print_taste_01.jpg")
  )
}

cat9_reach_asset_codes <- function() vapply(cat9_reach_assets(), function(a) a$code, character(1))

# Media channels for Q015 (where seen)
cat9_reach_media <- function() {
  list(
    list(code = "TV",      label = "Television"),
    list(code = "SOCIAL",  label = "Social media (Facebook, Instagram, TikTok)"),
    list(code = "ONLINE",  label = "Online advertising (website banner, YouTube)"),
    list(code = "PRINT",   label = "Newspaper or magazine"),
    list(code = "OUTDOOR", label = "Outdoor (billboard, bus shelter)"),
    list(code = "RADIO",   label = "Radio"),
    list(code = "INSTORE", label = "In-store (shelf display, packaging)"),
    list(code = "OTHER",   label = "Somewhere else")
  )
}


# ==============================================================================
# STANDARD DEMOGRAPHICS  (South Africa; added to all respondents)
# ==============================================================================

cat9_demographics <- function() {
  list(
    list(code = "AGE",      label = "Age group",
         variable_type = "Single_Mention",
         options = list(
           list(val = "1", text = "18–24"),
           list(val = "2", text = "25–34"),
           list(val = "3", text = "35–49"),
           list(val = "4", text = "50–64"),
           list(val = "5", text = "65+")
         )),
    list(code = "GENDER",   label = "Gender",
         variable_type = "Single_Mention",
         options = list(
           list(val = "1", text = "Female"),
           list(val = "2", text = "Male"),
           list(val = "3", text = "Non-binary / prefer not to say")
         )),
    list(code = "PROVINCE", label = "Province",
         variable_type = "Single_Mention",
         options = list(
           list(val = "1",  text = "Gauteng"),
           list(val = "2",  text = "Western Cape"),
           list(val = "3",  text = "KwaZulu-Natal"),
           list(val = "4",  text = "Eastern Cape"),
           list(val = "5",  text = "Limpopo"),
           list(val = "6",  text = "Mpumalanga"),
           list(val = "7",  text = "North West"),
           list(val = "8",  text = "Free State"),
           list(val = "9",  text = "Northern Cape")
         )),
    list(code = "LSM",      label = "Living Standards Measure (LSM)",
         variable_type = "Single_Mention",
         options = list(
           list(val = "6",  text = "LSM 6"),
           list(val = "7",  text = "LSM 7"),
           list(val = "8",  text = "LSM 8"),
           list(val = "9",  text = "LSM 9"),
           list(val = "10", text = "LSM 10")
         )),
    list(code = "RACE",     label = "Population group",
         variable_type = "Single_Mention",
         options = list(
           list(val = "1", text = "Black African"),
           list(val = "2", text = "Coloured"),
           list(val = "3", text = "Indian / Asian"),
           list(val = "4", text = "White"),
           list(val = "5", text = "Prefer not to say")
         )),
    list(code = "HH_INCOME", label = "Monthly household income (ZAR)",
         variable_type = "Single_Mention",
         options = list(
           list(val = "1", text = "Under R5,000"),
           list(val = "2", text = "R5,000–R9,999"),
           list(val = "3", text = "R10,000–R19,999"),
           list(val = "4", text = "R20,000–R39,999"),
           list(val = "5", text = "R40,000 or more")
         ))
  )
}


# ==============================================================================
# BRAND COLOURS
# ==============================================================================

.BRAND_COLOURS_9CAT <- list(
  IPK    = "#C8102E",   # IPK brand red (focal)
  ROB    = "#2E86C1",   # Robertsons blue
  DOLMIO = "#E67E22",   # Dolmio amber
  ALGLD  = "#27AE60",   # All Gold green
  KNORR  = "#E74C3C"    # Knorr red
)

cat9_brand_colour <- function(bc) .BRAND_COLOURS_9CAT[[bc]] %||% ""

`%||%` <- function(a, b) if (!is.null(a)) a else b
