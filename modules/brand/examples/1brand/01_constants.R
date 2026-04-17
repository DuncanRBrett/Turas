# ==============================================================================
# 1BRAND SYNTHETIC EXAMPLE - CONSTANTS
# ==============================================================================
# Single source of truth for the Ina Paarman's Kitchen (IPK) Dry Seasonings &
# Spices single-category synthetic study.
#
# Used by:
#   - 02_config.R        (Brand_Config.xlsx generation)
#   - 03_structure.R     (Survey_Structure.xlsx generation)
#   - 04_data.R          (synthetic respondent data generation)
#
# Changing a brand / CEP / attribute here flows through all three artefacts.
#
# NOTE: Brand list represents a realistic competitive set for the South African
# Dry Seasonings & Spices category. Values below (strength, awareness_rate,
# specialty) are synthetic-data parameters, NOT real-world shares.
# ==============================================================================


# ==============================================================================
# CATEGORY
# ==============================================================================

ipk_category <- function() {
  list(
    code            = "DSS",
    name            = "Dry Seasonings & Spices",
    type            = "transaction",
    timeframe_long  = "12 months",
    timeframe_target = "3 months"
  )
}


# ==============================================================================
# STUDY METADATA
# ==============================================================================

ipk_study_meta <- function() {
  list(
    project_name   = "Ina Paarman's Kitchen - Brand Health Wave 1",
    client_name    = "Ina Paarman's Kitchen",
    focal_brand    = "IPK",
    wave           = 1,
    sample_size    = 300,
    study_type     = "cross-sectional",
    data_file_name = "ipk_dryspices_wave1.csv",
    fieldwork      = "February 2026"
  )
}


# ==============================================================================
# BRANDS
# ==============================================================================
# Each brand has:
#   code            — short identifier used in column names (e.g. CEP01_IPK)
#   label           — display label for charts and tables
#   is_focal        — TRUE for exactly one brand
#   strength        — 0..1; drives overall linkage rate in synthetic data
#   awareness_rate  — probability a respondent is aware of this brand
#   specialty       — NULL or one of: curry / traditional / exotic / value
#   quality_tier    — one of: premium / mainstream / value
# ==============================================================================

ipk_brands <- function() {
  list(
    list(code = "IPK",    label = "Ina Paarman's Kitchen", is_focal = TRUE,
         strength = 0.72, awareness_rate = 0.85,
         specialty = NULL,          quality_tier = "premium",    display_order = 1),
    list(code = "ROB",    label = "Robertsons",            is_focal = FALSE,
         strength = 0.95, awareness_rate = 0.94,
         specialty = NULL,          quality_tier = "mainstream", display_order = 2),
    list(code = "KNORR",  label = "Knorr",                 is_focal = FALSE,
         strength = 0.68, awareness_rate = 0.82,
         specialty = NULL,          quality_tier = "mainstream", display_order = 3),
    list(code = "CART",   label = "Cartwright's",          is_focal = FALSE,
         strength = 0.40, awareness_rate = 0.55,
         specialty = "traditional", quality_tier = "premium",    display_order = 4),
    list(code = "RAJAH",  label = "Rajah",                 is_focal = FALSE,
         strength = 0.55, awareness_rate = 0.68,
         specialty = "curry",       quality_tier = "mainstream", display_order = 5),
    list(code = "SAFARI", label = "Safari",                is_focal = FALSE,
         strength = 0.38, awareness_rate = 0.48,
         specialty = NULL,          quality_tier = "mainstream", display_order = 6),
    list(code = "SPMEC",  label = "Spice Mecca",           is_focal = FALSE,
         strength = 0.30, awareness_rate = 0.38,
         specialty = "exotic",      quality_tier = "premium",    display_order = 7),
    list(code = "WWT",    label = "Woolworths Taste",      is_focal = FALSE,
         strength = 0.58, awareness_rate = 0.72,
         specialty = NULL,          quality_tier = "premium",    display_order = 8),
    list(code = "PNP",    label = "PnP No Name",           is_focal = FALSE,
         strength = 0.45, awareness_rate = 0.62,
         specialty = "value",       quality_tier = "value",      display_order = 9),
    list(code = "CHECK",  label = "Checkers Simple Truth", is_focal = FALSE,
         strength = 0.42, awareness_rate = 0.58,
         specialty = "value",       quality_tier = "value",      display_order = 10)
  )
}


# ==============================================================================
# CATEGORY ENTRY POINTS (CEPs)
# ==============================================================================
# 15 CEPs covering the situations in which South African cooks buy spices.
# Wording follows Romaniuk's guidance: simple, concrete, situation-based. No
# comparatives, no superlatives, no double-barrelled statements.
#
# Each CEP has an optional `specialty_match` that boosts linkage probability
# for brands with that specialty in the synthetic data (creates realistic
# brand-CEP concentration patterns — e.g. Rajah strong on curry CEP).
# ==============================================================================

ipk_ceps <- function() {
  list(
    list(code = "CEP01", text = "When I'm seasoning a roast meat dish",
         specialty_match = NULL),
    list(code = "CEP02", text = "When I'm making a hearty stew or potjie",
         specialty_match = "traditional"),
    list(code = "CEP03", text = "When I'm adding flavour to a stir-fry",
         specialty_match = NULL),
    list(code = "CEP04", text = "When I'm making a curry from scratch",
         specialty_match = "curry"),
    list(code = "CEP05", text = "When I'm seasoning grilled chicken",
         specialty_match = NULL),
    list(code = "CEP06", text = "When I'm preparing a marinade for a braai",
         specialty_match = "traditional"),
    list(code = "CEP07", text = "When I'm cooking a quick weeknight meal",
         specialty_match = NULL),
    list(code = "CEP08", text = "When I'm making traditional South African dishes",
         specialty_match = "traditional"),
    list(code = "CEP09", text = "When I'm seasoning vegetables or salads",
         specialty_match = NULL),
    list(code = "CEP10", text = "When I'm adding flavour to soup",
         specialty_match = NULL),
    list(code = "CEP11", text = "When I want to experiment with a new recipe",
         specialty_match = "exotic"),
    list(code = "CEP12", text = "When I'm cooking for the whole family",
         specialty_match = NULL),
    list(code = "CEP13", text = "When I'm entertaining guests",
         specialty_match = "exotic"),
    list(code = "CEP14", text = "When I want an authentic, bold flavour",
         specialty_match = "exotic"),
    list(code = "CEP15", text = "When I need a reliable, everyday option",
         specialty_match = "value")
  )
}


# ==============================================================================
# BRAND IMAGE ATTRIBUTES
# ==============================================================================
# Non-CEP attributes. These are perception items, not entry points. They
# answer "what do people think about us?" rather than "when do people think
# of us?". Reported separately from CEPs in the brand module.
# ==============================================================================

ipk_attributes <- function() {
  list(
    list(code = "ATTR01", text = "Good value for money"),
    list(code = "ATTR02", text = "High quality ingredients"),
    list(code = "ATTR03", text = "A brand I trust"),
    list(code = "ATTR04", text = "Consistent taste every time"),
    list(code = "ATTR05", text = "Easy to use in everyday cooking")
  )
}


# ==============================================================================
# DBA ASSETS
# ==============================================================================
# Distinctive Brand Assets for Ina Paarman's Kitchen. In a real study these
# would be test stimuli (images of logo, packaging, colour swatch) with
# Fame × Uniqueness testing. For the synthetic example we enumerate five
# realistic assets; the data generator simulates recognition and attribution
# rates that position IPK's assets in different quadrants of the DBA grid.
# ==============================================================================

ipk_dba_assets <- function() {
  list(
    list(code = "LOGO",    label = "Script logo",          asset_type = "image",
         file_path = "assets/ipk_logo_unbranded.png",
         fame_rate = 0.72, unique_attribution_rate = 0.68),
    list(code = "COLOUR",  label = "Red packaging",        asset_type = "image",
         file_path = "assets/ipk_colour_swatch.png",
         fame_rate = 0.55, unique_attribution_rate = 0.38),
    list(code = "JAR",     label = "Glass jar shape",      asset_type = "image",
         file_path = "assets/ipk_jar_silhouette.png",
         fame_rate = 0.62, unique_attribution_rate = 0.55),
    list(code = "CHEF",    label = "Ina Paarman character", asset_type = "image",
         file_path = "assets/ipk_character.png",
         fame_rate = 0.78, unique_attribution_rate = 0.82),
    list(code = "TAGLINE", label = "\"Seasoned to perfection\" tagline",
         asset_type = "text", file_path = "",
         fame_rate = 0.28, unique_attribution_rate = 0.22)
  )
}


# ==============================================================================
# HELPER ACCESSORS
# ==============================================================================

#' Get focal brand code from brand list
#' @keywords internal
ipk_focal_brand_code <- function() {
  brands <- ipk_brands()
  focal_codes <- vapply(brands, function(b) if (isTRUE(b$is_focal)) b$code else NA_character_,
                        character(1))
  focal_codes <- focal_codes[!is.na(focal_codes)]
  if (length(focal_codes) != 1) {
    rlang::abort("Exactly one brand must have is_focal = TRUE in ipk_brands()",
                 class = "brand_example_config")
  }
  focal_codes[[1]]
}

#' Get brand codes as a character vector
#' @keywords internal
ipk_brand_codes <- function() {
  vapply(ipk_brands(), function(b) b$code, character(1))
}

#' Get CEP codes as a character vector
#' @keywords internal
ipk_cep_codes <- function() {
  vapply(ipk_ceps(), function(c) c$code, character(1))
}

#' Get attribute codes as a character vector
#' @keywords internal
ipk_attribute_codes <- function() {
  vapply(ipk_attributes(), function(a) a$code, character(1))
}

#' Get DBA asset codes as a character vector
#' @keywords internal
ipk_dba_codes <- function() {
  vapply(ipk_dba_assets(), function(a) a$code, character(1))
}
