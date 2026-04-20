# ==============================================================================
# 3CAT SYNTHETIC EXAMPLE - CONSTANTS
# ==============================================================================
# Three-category CBM study: Ina Paarman's Kitchen (IPK) as focal brand across:
#   1. Dry Seasonings & Spices (DSS)
#   2. Pasta Sauces             (PAS)
#   3. Salad Dressings          (SLD)
#
# Used by:  02_config.R, 03_structure.R, 04_data.R
#
# Column-naming conventions (multi-category extensions of the 1brand pattern):
#   Awareness / Attitude / Penetration : BRANDAWARE_{CAT}_{BRAND}
#   CEP matrix        : {CEPCODE}_{BRAND}   — CEP codes are globally unique
#                         DSS = CEP01–CEP15
#                         PAS = CEP16–CEP30
#                         SLD = CEP31–CEP45
#   Attribute matrix  : {CAT}_{ATTRCODE}_{BRAND}  (same 5 attrs per cat)
#   WOM               : WOM_POS_REC_{BRAND}  etc.  — brand codes globally unique
#   DBA               : DBA_FAME_{ASSET}  /  DBA_UNIQUE_{ASSET}  (IPK only)
# ==============================================================================


# ==============================================================================
# STUDY METADATA
# ==============================================================================

cat3_study_meta <- function() {
  list(
    project_name   = "Ina Paarman's Kitchen - Brand Health Wave 1 (Multi-Category)",
    client_name    = "Ina Paarman's Kitchen",
    focal_brand    = "IPK",
    wave           = 1,
    sample_size    = 300,   # 100 per category
    study_type     = "cross-sectional",
    data_file_name = "ipk_3cat_wave1.xlsx",
    fieldwork      = "April 2026"
  )
}


# ==============================================================================
# CATEGORY DEFINITIONS
# ==============================================================================

cat3_categories <- function() {
  list(
    list(code = "DSS", name = "Dry Seasonings & Spices", type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         display_order = 1),
    list(code = "PAS", name = "Pasta Sauces",            type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         display_order = 2),
    list(code = "SLD", name = "Salad Dressings",         type = "transaction",
         timeframe_long = "12 months", timeframe_target = "3 months",
         display_order = 3)
  )
}

cat3_category <- function(cat_code) {
  cats <- cat3_categories()
  for (c in cats) if (c$code == cat_code) return(c)
  stop(sprintf("Unknown category code: %s", cat_code))
}


# ==============================================================================
# BRANDS  (IPK code globally unique and focal in every category)
# ==============================================================================
# Each brand: code, label, is_focal, strength (0..1), awareness_rate, quality_tier
# Brand codes are globally unique across categories so WOM columns don't clash.
# Codes shared across categories: IPK (all 3), KNORR (DSS+PAS), ALGLD (PAS+SLD)
# ==============================================================================

cat3_brands <- function(cat_code) {
  switch(cat_code,

    DSS = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen", is_focal = TRUE,
           strength = 0.72, awareness_rate = 0.85, quality_tier = "premium",    display_order = 1),
      list(code = "ROB",   label = "Robertsons",            is_focal = FALSE,
           strength = 0.95, awareness_rate = 0.94, quality_tier = "mainstream", display_order = 2),
      list(code = "KNORR", label = "Knorr",                 is_focal = FALSE,
           strength = 0.68, awareness_rate = 0.82, quality_tier = "mainstream", display_order = 3),
      list(code = "CART",  label = "Cartwright's",          is_focal = FALSE,
           strength = 0.40, awareness_rate = 0.55, quality_tier = "premium",    display_order = 4),
      list(code = "RAJAH", label = "Rajah",                 is_focal = FALSE,
           strength = 0.55, awareness_rate = 0.68, quality_tier = "mainstream", display_order = 5),
      list(code = "SFRI",  label = "Safari",                is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.48, quality_tier = "mainstream", display_order = 6),
      list(code = "SPMEC", label = "Spice Mecca",           is_focal = FALSE,
           strength = 0.30, awareness_rate = 0.38, quality_tier = "premium",    display_order = 7),
      list(code = "WWT",   label = "Woolworths Taste",      is_focal = FALSE,
           strength = 0.58, awareness_rate = 0.72, quality_tier = "premium",    display_order = 8),
      list(code = "PNPDSS",label = "PnP No Name",           is_focal = FALSE,
           strength = 0.45, awareness_rate = 0.62, quality_tier = "value",      display_order = 9),
      list(code = "CKRDSS",label = "Checkers House Brand",  is_focal = FALSE,
           strength = 0.42, awareness_rate = 0.58, quality_tier = "value",      display_order = 10)
    ),

    PAS = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen", is_focal = TRUE,
           strength = 0.70, awareness_rate = 0.83, quality_tier = "premium",    display_order = 1),
      list(code = "KNORR", label = "Knorr",                 is_focal = FALSE,
           strength = 0.65, awareness_rate = 0.80, quality_tier = "mainstream", display_order = 2),
      list(code = "DOLMIO",label = "Dolmio",                is_focal = FALSE,
           strength = 0.88, awareness_rate = 0.91, quality_tier = "mainstream", display_order = 3),
      list(code = "ALGLD", label = "All Gold",              is_focal = FALSE,
           strength = 0.72, awareness_rate = 0.86, quality_tier = "mainstream", display_order = 4),
      list(code = "FATTS", label = "Fatti's & Moni's",      is_focal = FALSE,
           strength = 0.55, awareness_rate = 0.70, quality_tier = "mainstream", display_order = 5),
      list(code = "BARLA", label = "Barilla",               is_focal = FALSE,
           strength = 0.45, awareness_rate = 0.58, quality_tier = "premium",    display_order = 6),
      list(code = "SDEL",  label = "Simply Delish",         is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.50, quality_tier = "mainstream", display_order = 7),
      list(code = "WWPAS", label = "Woolworths Pasta Range", is_focal = FALSE,
           strength = 0.52, awareness_rate = 0.65, quality_tier = "premium",    display_order = 8),
      list(code = "PNPPAS",label = "PnP Pasta Sauces",      is_focal = FALSE,
           strength = 0.40, awareness_rate = 0.55, quality_tier = "value",      display_order = 9),
      list(code = "CKRPAS",label = "Checkers Pasta Range",  is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.52, quality_tier = "value",      display_order = 10)
    ),

    SLD = list(
      list(code = "IPK",   label = "Ina Paarman's Kitchen", is_focal = TRUE,
           strength = 0.68, awareness_rate = 0.80, quality_tier = "premium",    display_order = 1),
      list(code = "ALGLD", label = "All Gold",              is_focal = FALSE,
           strength = 0.70, awareness_rate = 0.84, quality_tier = "mainstream", display_order = 2),
      list(code = "KRAFT", label = "Kraft",                 is_focal = FALSE,
           strength = 0.62, awareness_rate = 0.78, quality_tier = "mainstream", display_order = 3),
      list(code = "BULLS", label = "Bull Brand",            is_focal = FALSE,
           strength = 0.55, awareness_rate = 0.72, quality_tier = "mainstream", display_order = 4),
      list(code = "NEWMN", label = "Newman's Own",          is_focal = FALSE,
           strength = 0.42, awareness_rate = 0.55, quality_tier = "premium",    display_order = 5),
      list(code = "BALEA", label = "Baleia",                is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.45, quality_tier = "premium",    display_order = 6),
      list(code = "WWSLD", label = "Woolworths Dressings",  is_focal = FALSE,
           strength = 0.50, awareness_rate = 0.62, quality_tier = "premium",    display_order = 7),
      list(code = "PNPSLD",label = "PnP Dressings",         is_focal = FALSE,
           strength = 0.38, awareness_rate = 0.52, quality_tier = "value",      display_order = 8),
      list(code = "CKRSLD",label = "Checkers Dressings",    is_focal = FALSE,
           strength = 0.35, awareness_rate = 0.48, quality_tier = "value",      display_order = 9),
      list(code = "AMANU", label = "Amanzi Artisan",        is_focal = FALSE,
           strength = 0.25, awareness_rate = 0.32, quality_tier = "premium",    display_order = 10)
    ),

    stop(sprintf("Unknown category code: %s", cat_code))
  )
}

cat3_brand_codes <- function(cat_code) {
  vapply(cat3_brands(cat_code), function(b) b$code, character(1))
}

# All unique brand codes across all categories (for WOM column generation)
cat3_all_brand_codes <- function() {
  all_codes <- unlist(lapply(c("DSS", "PAS", "SLD"), cat3_brand_codes))
  unique(all_codes)
}


# ==============================================================================
# CATEGORY ENTRY POINTS (CEPs)
# ==============================================================================
# 15 per category, globally unique codes:
#   DSS: CEP01–CEP15
#   PAS: CEP16–CEP30
#   SLD: CEP31–CEP45
#
# Wording follows Romaniuk: simple, concrete, situation-based. No comparatives.
# ==============================================================================

cat3_ceps <- function(cat_code) {
  switch(cat_code,

    DSS = list(
      list(code = "CEP01", text = "When I'm seasoning a roast meat dish"),
      list(code = "CEP02", text = "When I'm making a hearty stew or potjie"),
      list(code = "CEP03", text = "When I'm adding flavour to a stir-fry"),
      list(code = "CEP04", text = "When I'm making a curry from scratch"),
      list(code = "CEP05", text = "When I'm seasoning grilled chicken"),
      list(code = "CEP06", text = "When I'm preparing a marinade for a braai"),
      list(code = "CEP07", text = "When I'm cooking a quick weeknight meal"),
      list(code = "CEP08", text = "When I'm making traditional South African dishes"),
      list(code = "CEP09", text = "When I'm seasoning vegetables or salads"),
      list(code = "CEP10", text = "When I'm adding flavour to soup"),
      list(code = "CEP11", text = "When I want to experiment with a new recipe"),
      list(code = "CEP12", text = "When I'm cooking for the whole family"),
      list(code = "CEP13", text = "When I'm entertaining guests at home"),
      list(code = "CEP14", text = "When I want an authentic, bold flavour"),
      list(code = "CEP15", text = "When I need a reliable, everyday seasoning")
    ),

    PAS = list(
      list(code = "CEP16", text = "When I need a quick weeknight dinner"),
      list(code = "CEP17", text = "When I'm cooking pasta for the whole family"),
      list(code = "CEP18", text = "When I want something hearty and filling for dinner"),
      list(code = "CEP19", text = "When I have unexpected guests arriving for dinner"),
      list(code = "CEP20", text = "When I want a warming, comforting meal on a cold evening"),
      list(code = "CEP21", text = "When I need to save time on dinner preparation"),
      list(code = "CEP22", text = "When I want to feed a crowd on a budget"),
      list(code = "CEP23", text = "When cooking for children who like familiar flavours"),
      list(code = "CEP24", text = "When I want something that tastes properly home-cooked"),
      list(code = "CEP25", text = "When I want to try a new pasta recipe for the family"),
      list(code = "CEP26", text = "When I fancy an Italian-style meal at home"),
      list(code = "CEP27", text = "When I want to make a healthier pasta dish"),
      list(code = "CEP28", text = "When I need a satisfying meal after a long day at work"),
      list(code = "CEP29", text = "When I'm cooking something a bit more special for dinner"),
      list(code = "CEP30", text = "When I want a sauce made with quality, natural ingredients")
    ),

    SLD = list(
      list(code = "CEP31", text = "When I'm making a green salad for the family"),
      list(code = "CEP32", text = "When I'm preparing food for entertaining guests"),
      list(code = "CEP33", text = "When I'm eating healthily during the week"),
      list(code = "CEP34", text = "When I want a lighter lunch option at home"),
      list(code = "CEP35", text = "When I'm making a side salad for a braai"),
      list(code = "CEP36", text = "When cooking for someone who watches what they eat"),
      list(code = "CEP37", text = "When I want to add flavour without adding too many calories"),
      list(code = "CEP38", text = "When I'm making a quick lunch salad at home"),
      list(code = "CEP39", text = "When I want a dipping sauce for fresh vegetables"),
      list(code = "CEP40", text = "When I'm making a cold pasta salad or grain bowl"),
      list(code = "CEP41", text = "When I want to make a simple salad feel special"),
      list(code = "CEP42", text = "When I'm making a hearty meal salad as a main course"),
      list(code = "CEP43", text = "When I'm making a coleslaw for a family gathering"),
      list(code = "CEP44", text = "When I want a premium dressing for a special occasion"),
      list(code = "CEP45", text = "When I'm looking for a versatile sauce across different dishes")
    ),

    stop(sprintf("Unknown category code: %s", cat_code))
  )
}

cat3_cep_codes <- function(cat_code) {
  vapply(cat3_ceps(cat_code), function(c) c$code, character(1))
}


# ==============================================================================
# BRAND IMAGE ATTRIBUTES  (5, same across all categories)
# ==============================================================================
# Perception items — not entry points. Reported separately from CEPs.
# Column names are CATEGORY-prefixed to keep multi-category columns distinct:
#   e.g. DSS_ATTR01_IPK  vs  PAS_ATTR01_IPK
# ==============================================================================

cat3_attributes <- function() {
  list(
    list(code = "ATTR01", text = "Good value for money"),
    list(code = "ATTR02", text = "High quality ingredients"),
    list(code = "ATTR03", text = "A brand I trust"),
    list(code = "ATTR04", text = "Consistent taste every time"),
    list(code = "ATTR05", text = "Easy to use in everyday cooking")
  )
}

# Returns attribute code prefixed with the category, as used in question/column names
# e.g. cat3_attr_question_code("DSS", "ATTR01") -> "DSS_ATTR01"
cat3_attr_question_code <- function(cat_code, attr_code) {
  sprintf("%s_%s", cat_code, attr_code)
}

cat3_attr_codes <- function() {
  vapply(cat3_attributes(), function(a) a$code, character(1))
}


# ==============================================================================
# DBA ASSETS  (Ina Paarman's Kitchen only — 5 distinctive brand assets)
# ==============================================================================
# DBA is brand-level: all respondents (across all 3 categories) see these
# assets. Column names: DBA_FAME_{ASSET}  and  DBA_UNIQUE_{ASSET}
# ==============================================================================

cat3_dba_assets <- function() {
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

cat3_dba_codes <- function() {
  vapply(cat3_dba_assets(), function(a) a$code, character(1))
}


# ==============================================================================
# BRAND COLOURS  (optional per-brand chart colours)
# ==============================================================================

.BRAND_COLOURS_3CAT <- list(
  IPK    = "#C8102E",   # IPK brand red (focal)
  ROB    = "#2E86C1",   # Robertsons blue
  DOLMIO = "#E67E22",   # Dolmio amber
  ALGLD  = "#27AE60"    # All Gold green
)

cat3_brand_colour <- function(brand_code) {
  .BRAND_COLOURS_3CAT[[brand_code]] %||% ""
}

# Safe %||% operator
`%||%` <- function(a, b) if (!is.null(a)) a else b
