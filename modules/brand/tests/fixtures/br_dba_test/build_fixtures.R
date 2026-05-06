# ==============================================================================
# Build BR_DBA_test fixtures from the canonical IPK synthetic config
# ==============================================================================
# Produces two parallel fixture folders for the feature/branded-reach-and-dba
# branch:
#
#   <SYNTH>/BR_DBA_test/placeholder/  — element flags Y, MR + DBA sheets
#                                       stripped to headers only. Verifies
#                                       "Data not yet collected" cards.
#
#   <SYNTH>/BR_DBA_test/populated/    — element flags Y, MR + DBA sheets
#                                       populated with synthetic asset
#                                       definitions, synthetic data
#                                       extended with required Reach + DBA
#                                       response columns. Verifies the
#                                       modern panels render with data.
#
# The canonical files at <SYNTH>/8822527_*.xlsx are read but NEVER written.
#
# Usage: Rscript modules/brand/tests/fixtures/br_dba_test/build_fixtures.R
#
# VERSION: 1.0
# ==============================================================================

stopifnot(requireNamespace("openxlsx", quietly = TRUE))

SYNTH_ROOT <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/Tabs/synthetic"
TEST_ROOT  <- file.path(SYNTH_ROOT, "BR_DBA_test")
PLACEHOLDER_DIR <- file.path(TEST_ROOT, "placeholder")
POPULATED_DIR   <- file.path(TEST_ROOT, "populated")

CANONICAL_FILES <- c(
  brand_config = "8822527_Brand_Config.xlsx",
  structure    = "8822527_Survey_Structure_Brand.xlsx",
  data         = "8822527_Synthetic_Data.xlsx"
)

# ------------------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------------------

dir.create(PLACEHOLDER_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(POPULATED_DIR,   recursive = TRUE, showWarnings = FALSE)

copy_canonical <- function(target_dir) {
  for (fn in CANONICAL_FILES) {
    src <- file.path(SYNTH_ROOT, fn)
    dst <- file.path(target_dir, fn)
    if (!file.exists(src)) stop(sprintf("Canonical file missing: %s", src))
    file.copy(src, dst, overwrite = TRUE)
  }
}

# ------------------------------------------------------------------------------
# Helpers — flip element flags in Brand_Config Settings
# ------------------------------------------------------------------------------

set_element_flags <- function(brand_config_path, flags) {
  wb <- openxlsx::loadWorkbook(brand_config_path)
  settings <- openxlsx::readWorkbook(wb, sheet = "Settings", colNames = FALSE)
  for (flag_name in names(flags)) {
    rn <- which(settings[[1]] == flag_name)
    if (length(rn) != 1L) {
      stop(sprintf("Flag '%s' not found exactly once in Settings", flag_name))
    }
    settings[rn, 2] <- flags[[flag_name]]
  }
  openxlsx::writeData(wb, sheet = "Settings", x = settings,
                      colNames = FALSE, startRow = 1, startCol = 1)
  openxlsx::saveWorkbook(wb, brand_config_path, overwrite = TRUE)
}

# ------------------------------------------------------------------------------
# Helpers — strip example data rows in a sheet (keep header + description rows)
# ------------------------------------------------------------------------------

# Sheets in this fixture follow the convention: row 1 = section title,
# row 2 = blank/desc, row 3 = column headers, row 4 = column descriptions,
# rows 5+ = data. To strip data, we keep rows 1-4 only.

strip_data_rows <- function(workbook_path, sheet_name) {
  wb <- openxlsx::loadWorkbook(workbook_path)
  current <- openxlsx::readWorkbook(wb, sheet = sheet_name, colNames = FALSE)
  if (nrow(current) <= 4L) return(invisible())
  openxlsx::removeWorksheet(wb, sheet_name)
  openxlsx::addWorksheet(wb, sheet_name)
  openxlsx::writeData(wb, sheet = sheet_name, x = current[1:4, , drop = FALSE],
                      colNames = FALSE, startRow = 1, startCol = 1)
  openxlsx::saveWorkbook(wb, workbook_path, overwrite = TRUE)
}

# ------------------------------------------------------------------------------
# Build PLACEHOLDER fixture
# ------------------------------------------------------------------------------

build_placeholder <- function() {
  cat("Building placeholder fixture...\n")
  copy_canonical(PLACEHOLDER_DIR)

  brand_config <- file.path(PLACEHOLDER_DIR, CANONICAL_FILES[["brand_config"]])
  structure    <- file.path(PLACEHOLDER_DIR, CANONICAL_FILES[["structure"]])

  set_element_flags(brand_config,
                    list(element_branded_reach = "Y", element_dba = "Y"))
  strip_data_rows(brand_config, "DBA_Assets")
  strip_data_rows(structure, "MarketingReach")
  strip_data_rows(structure, "DBA_Assets")
  cat("  placeholder/ ready\n")
}

# ------------------------------------------------------------------------------
# Helpers — populate MarketingReach + DBA + synthetic data
# ------------------------------------------------------------------------------

# Synthetic asset definitions for the populated fixture. Three reach ads:
# one DSS-only TV ad, one ALL-category OOH, one POS-only digital — all
# attributed to IPK. Four DBAs already defined in canonical Brand_Config.

POP_DBA_STRUCTURE <- data.frame(
  AssetCode          = c("LOGO",            "COLOUR",            "TAGLINE",            "CHARACTER"),
  AssetLabel         = c("Primary Logo",    "Brand Colour",      "Brand Tagline",      "Brand Character"),
  AssetType          = c("image",           "image",             "text",               "image"),
  FameQuestionCode   = c("DBA_FAME_LOGO",   "DBA_FAME_COLOUR",   "DBA_FAME_TAGLINE",   "DBA_FAME_CHARACTER"),
  UniqueQuestionCode = c("DBA_UNIQUE_LOGO", "DBA_UNIQUE_COLOUR", "DBA_UNIQUE_TAGLINE", "DBA_UNIQUE_CHARACTER"),
  stringsAsFactors   = FALSE
)

POP_REACH_ADS <- data.frame(
  AssetCode          = c("AD_TV_Q1",      "AD_OOH_Q1",     "AD_DIGITAL_Q1"),
  AssetLabel         = c("TV: Stew Spot", "OOH: Billboard", "Digital: Recipe Reels"),
  Category           = c("DSS",           "ALL",            "POS"),
  Brand              = c("IPK",           "IPK",            "IPK"),
  MediaType          = c("TV",            "OOH",            "Digital"),
  ImagePath          = c(NA_character_,   NA_character_,    NA_character_),
  SeenQuestionCode   = c("reach.seen.AD_TV_Q1",
                          "reach.seen.AD_OOH_Q1",
                          "reach.seen.AD_DIGITAL_Q1"),
  BrandQuestionCode  = c("reach.brand.AD_TV_Q1",
                          "reach.brand.AD_OOH_Q1",
                          "reach.brand.AD_DIGITAL_Q1"),
  MediaQuestionCode  = c("reach.media.AD_TV_Q1",
                          "reach.media.AD_OOH_Q1",
                          "reach.media.AD_DIGITAL_Q1"),
  stringsAsFactors   = FALSE
)

write_data_rows <- function(workbook_path, sheet_name, rows_df, header_row = 3L) {
  # Header row in canonical templates is row 3, descriptions row 4.
  # We append `rows_df` starting at row 5.
  # Column names of rows_df must match row 3 header values exactly (or we
  # rely on positional column order — we use positional here).
  wb <- openxlsx::loadWorkbook(workbook_path)
  current <- openxlsx::readWorkbook(wb, sheet = sheet_name, colNames = FALSE)
  # Trim canonical to first 4 rows (header + desc), drop any examples
  template <- current[1:4, , drop = FALSE]
  # Pad rows_df to template's column count
  ncol_template <- ncol(template)
  if (ncol(rows_df) < ncol_template) {
    for (i in seq_len(ncol_template - ncol(rows_df))) {
      rows_df[[paste0(".pad", i)]] <- NA
    }
  } else if (ncol(rows_df) > ncol_template) {
    rows_df <- rows_df[, seq_len(ncol_template), drop = FALSE]
  }
  names(rows_df) <- names(template)
  combined <- rbind(template, rows_df, stringsAsFactors = FALSE)
  openxlsx::removeWorksheet(wb, sheet_name)
  openxlsx::addWorksheet(wb, sheet_name)
  openxlsx::writeData(wb, sheet = sheet_name, x = combined,
                      colNames = FALSE, startRow = 1, startCol = 1)
  openxlsx::saveWorkbook(wb, workbook_path, overwrite = TRUE)
}

# Generate a deterministic random vector of integer responses
set.seed(42)
.gen_seen <- function(n, prob_seen = 0.4) {
  ifelse(runif(n) < prob_seen, 1L, 2L)
}
.gen_brand_attribution <- function(seen_vec, correct_brand, candidate_brands,
                                    prob_correct = 0.6, prob_dk = 0.15) {
  out <- rep(NA_character_, length(seen_vec))
  seen_idx <- which(seen_vec == 1L)
  if (length(seen_idx) == 0) return(out)
  rolls <- runif(length(seen_idx))
  for (i in seq_along(seen_idx)) {
    r <- rolls[[i]]
    out[seen_idx[[i]]] <- if (r < prob_correct) correct_brand
      else if (r < prob_correct + prob_dk) "DK"
      else sample(setdiff(candidate_brands, correct_brand), 1L)
  }
  out
}
.gen_media_mix <- function(seen_vec, media_codes,
                            mean_channels = 1.5) {
  out <- rep(NA_character_, length(seen_vec))
  seen_idx <- which(seen_vec == 1L)
  if (length(seen_idx) == 0) return(out)
  for (i in seen_idx) {
    n <- max(1L, rpois(1L, mean_channels))
    n <- min(n, length(media_codes))
    out[i] <- paste(sample(media_codes, n), collapse = ",")
  }
  out
}
.gen_dba_fame <- function(n, prob_yes = 0.55, prob_no = 0.30) {
  r <- runif(n)
  ifelse(r < prob_yes, 1L,
    ifelse(r < prob_yes + prob_no, 2L, 3L))
}
.gen_dba_unique <- function(fame_vec, focal_brand, competitor_brands,
                             prob_correct = 0.55, prob_dk = 0.10) {
  out <- rep(NA_character_, length(fame_vec))
  fame_idx <- which(fame_vec %in% c(1L, 3L))
  if (length(fame_idx) == 0) return(out)
  rolls <- runif(length(fame_idx))
  for (i in seq_along(fame_idx)) {
    r <- rolls[[i]]
    out[fame_idx[[i]]] <- if (r < prob_correct) focal_brand
      else if (r < prob_correct + prob_dk) "DK"
      else sample(competitor_brands, 1L)
  }
  out
}

extend_synthetic_data <- function(data_path, ads_df, media_codes,
                                  dba_assets, focal_brand,
                                  competitor_brands) {
  wb <- openxlsx::loadWorkbook(data_path)
  d <- openxlsx::readWorkbook(wb, sheet = 1)
  n <- nrow(d)
  cat(sprintf("  Extending data file (%d rows)...\n", n))

  # Reach columns
  for (i in seq_len(nrow(ads_df))) {
    ad <- ads_df[i, ]
    seen_col  <- ad$SeenQuestionCode
    brand_col <- ad$BrandQuestionCode
    media_col <- ad$MediaQuestionCode

    seen_vec  <- .gen_seen(n, prob_seen = 0.45)
    brand_vec <- .gen_brand_attribution(
      seen_vec, ad$Brand,
      candidate_brands = c(focal_brand, competitor_brands),
      prob_correct = if (ad$AssetCode == "AD_TV_Q1") 0.70 else 0.55,
      prob_dk = 0.12
    )
    media_vec <- .gen_media_mix(seen_vec, media_codes,
                                  mean_channels = 1.4)

    d[[seen_col]]  <- seen_vec
    d[[brand_col]] <- brand_vec
    d[[media_col]] <- media_vec
  }

  # DBA columns — varied mixed across quadrants
  asset_quadrants <- c(LOGO = "use_or_lose", COLOUR = "use_or_lose",
                       TAGLINE = "invest_to_build", CHARACTER = "avoid_alone")
  for (a in dba_assets$AssetCode) {
    quad <- asset_quadrants[[a]] %||% "use_or_lose"
    fame_col <- sprintf("DBA_FAME_%s", a)
    uniq_col <- sprintf("DBA_UNIQUE_%s", a)

    fame_p <- switch(quad,
                     use_or_lose     = 0.65,
                     avoid_alone     = 0.65,
                     invest_to_build = 0.30,
                     0.30)
    uniq_p <- switch(quad,
                     use_or_lose     = 0.65,
                     avoid_alone     = 0.20,
                     invest_to_build = 0.65,
                     0.20)

    fame_vec <- .gen_dba_fame(n, prob_yes = fame_p,
                                prob_no = 0.85 - fame_p)
    uniq_vec <- .gen_dba_unique(
      fame_vec, focal_brand, competitor_brands,
      prob_correct = uniq_p, prob_dk = 0.08
    )

    d[[fame_col]] <- fame_vec
    d[[uniq_col]] <- uniq_vec
  }

  openxlsx::removeWorksheet(wb, "Data")
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, sheet = "Data", x = d, colNames = TRUE)
  openxlsx::saveWorkbook(wb, data_path, overwrite = TRUE)
  cat(sprintf("  Data file now has %d cols (was reduced size)\n", ncol(d)))
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# ------------------------------------------------------------------------------
# Build POPULATED fixture
# ------------------------------------------------------------------------------

build_populated <- function() {
  cat("\nBuilding populated fixture...\n")
  copy_canonical(POPULATED_DIR)

  brand_config <- file.path(POPULATED_DIR, CANONICAL_FILES[["brand_config"]])
  structure    <- file.path(POPULATED_DIR, CANONICAL_FILES[["structure"]])
  data         <- file.path(POPULATED_DIR, CANONICAL_FILES[["data"]])

  set_element_flags(brand_config,
                    list(element_branded_reach = "Y", element_dba = "Y"))

  # Replace MarketingReach example rows with our synthetic ads
  write_data_rows(structure, "MarketingReach", POP_REACH_ADS)

  # Replace Structure DBA_Assets rows so all 4 Brand_Config assets have
  # question-code mappings — otherwise the engine will refuse for the
  # missing one.
  write_data_rows(structure, "DBA_Assets", POP_DBA_STRUCTURE)

  # Read the existing DBA_Assets from canonical Brand_Config (4 assets)
  dba_assets <- openxlsx::readWorkbook(brand_config, sheet = "DBA_Assets",
                                         colNames = FALSE,
                                         startRow = 5)
  names(dba_assets)[1:2] <- c("AssetCode", "AssetLabel")
  dba_assets <- dba_assets[!is.na(dba_assets$AssetCode), , drop = FALSE]
  cat("  DBA assets:", paste(dba_assets$AssetCode, collapse = ", "), "\n")

  # Read media codes from ReachMedia (TV, FACEBOOK, YOUTUBE, OOH...)
  media_sheet <- openxlsx::readWorkbook(structure, sheet = "ReachMedia",
                                          colNames = FALSE, startRow = 5)
  media_codes <- media_sheet[[1]]
  media_codes <- media_codes[!is.na(media_codes) & nzchar(media_codes)]
  cat("  Media codes:", paste(media_codes, collapse = ", "), "\n")

  # Read the brand list to identify focal + competitors. Brands sheet has
  # the canonical 4-row header (title / blank / column headers / column
  # descriptions); BrandCode lives in column 3, data starts row 5.
  brand_sheet <- openxlsx::readWorkbook(structure, sheet = "Brands",
                                          colNames = FALSE)
  brand_codes <- unique(brand_sheet[5:nrow(brand_sheet), 3])
  brand_codes <- brand_codes[!is.na(brand_codes) & nzchar(brand_codes)]
  cat("  Brand codes (", length(brand_codes), "total):",
      paste(utils::head(brand_codes, 10), collapse = ", "),
      if (length(brand_codes) > 10) "..." else "", "\n")
  focal_brand <- "IPK"
  competitor_brands <- setdiff(brand_codes, focal_brand)
  if (length(competitor_brands) == 0) competitor_brands <- c("ROB", "BLG")

  extend_synthetic_data(data, POP_REACH_ADS, media_codes,
                         dba_assets, focal_brand, competitor_brands)

  cat("  populated/ ready\n")
}

# ------------------------------------------------------------------------------
# Run
# ------------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0 || "all" %in% args) {
  build_placeholder()
  build_populated()
} else {
  if ("placeholder" %in% args) build_placeholder()
  if ("populated"   %in% args) build_populated()
}

cat("\n=== Fixtures built ===\n")
cat("placeholder:", PLACEHOLDER_DIR, "\n")
cat("populated:  ", POPULATED_DIR, "\n")
