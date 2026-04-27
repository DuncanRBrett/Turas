# ==============================================================================
# 9CAT SYNTHETIC EXAMPLE - DATA GENERATOR
# ==============================================================================
# Generates realistic synthetic respondent data for the IPK 9-category study.
# 400 respondents: 100 per full category (DSS, POS, PAS, BAK).
#
# Each respondent fills:
#   - Their focal category's full CBM battery (funnel + CEPs + attributes)
#   - Brand awareness for all 5 awareness-only categories (SLD, STO, PES, COO, ANT)
#   - WOM only for brands in their focal category
#   - DBA for all 5 IPK assets (all respondents)
#   - All other full-category columns remain NA
#
# Depends on: 01_constants.R
# ==============================================================================


# ==============================================================================
# HELPERS
# ==============================================================================

.rbern <- function(n, p) as.integer(runif(n) < p)

.rcat9 <- function(n, probs) {
  sample(seq_along(probs), n, replace = TRUE, prob = probs)
}

.rtrunc9 <- function(n, mean, sd, lo, hi) {
  pmin(pmax(rnorm(n, mean, sd), lo), hi)
}

.awareness_prob9 <- function(brand, cat_buy_val) {
  base  <- brand$awareness_rate
  boost <- 1.0 + 0.18 * (3 - cat_buy_val) / 2
  pmin(base * boost, 0.98)
}

.cep_link_prob9 <- function(brand) {
  pmin(0.08 + brand$strength * 0.35, 0.90)
}

.attr_link_prob9 <- function(brand, attr_code) {
  base  <- brand$strength * 0.50
  boost <- switch(brand$quality_tier,
    premium    = c(ATTR01 = 0.05, ATTR02 = 0.20, ATTR03 = 0.18, ATTR04 = 0.15, ATTR05 = 0.10),
    mainstream = c(ATTR01 = 0.15, ATTR02 = 0.05, ATTR03 = 0.10, ATTR04 = 0.10, ATTR05 = 0.15),
    value      = c(ATTR01 = 0.25, ATTR02 = -0.05, ATTR03 = 0.00, ATTR04 = 0.05, ATTR05 = 0.20),
    rep(0, 5)
  )
  pmin(pmax(base + (boost[[attr_code]] %||% 0), 0.02), 0.92)
}

.wom_pos_rec_prob9   <- function(b) pmin(0.05 + b$strength * 0.20, 0.40)
.wom_neg_rec_prob9   <- function(b) pmin(0.02 + (1 - b$strength) * 0.08, 0.15)
.wom_pos_share_prob9 <- function(b) pmin(0.03 + b$strength * 0.12, 0.25)
.wom_neg_share_prob9 <- function(b) pmin(0.01 + (1 - b$strength) * 0.05, 0.10)


# ==============================================================================
# BUILD FULL CATEGORY BLOCK (per focal category)
# ==============================================================================

.build_9cat_cat_block <- function(n, cat_code) {

  brands <- cat9_brands(cat_code)
  ceps   <- cat9_ceps(cat_code)
  attrs  <- cat9_attributes()

  df <- data.frame(row.names = seq_len(n), stringsAsFactors = FALSE)

  # Category buying — ordinal frequency (CATBUY) + numeric count (CATCOUNT)
  catbuy_col   <- sprintf("CATBUY_%s",   cat_code)
  catcount_col <- sprintf("CATCOUNT_%s", cat_code)
  cat_buy      <- .rcat9(n, c(0.13, 0.37, 0.34, 0.14, 0.02))
  # Numeric count: rough mapping from ordinal (rounded, with noise)
  count_means  <- c(10, 4, 2, 1, 0)
  cat_count    <- pmax(0L, round(count_means[cat_buy] + rnorm(n, 0, 0.8)))
  df[[catbuy_col]]   <- cat_buy
  df[[catcount_col]] <- as.integer(cat_count)

  # Awareness
  aware_mat <- matrix(0L, n, length(brands))
  colnames(aware_mat) <- vapply(brands, function(b) sprintf("BRANDAWARE_%s_%s", cat_code, b$code), character(1))
  for (j in seq_along(brands)) {
    p <- mapply(.awareness_prob9, list(brands[[j]]), cat_buy)
    aware_mat[, j] <- .rbern(n, p)
  }
  df <- cbind(df, aware_mat)

  # Attitude (single response per brand, conditional on awareness)
  rejection_reasons <- c("Too expensive", "Don't like the flavour", "Prefer other brands",
                         "Never tried it", "Bad experience in the past", "Don't trust it")
  for (b in brands) {
    att_col   <- sprintf("BRANDATT1_%s_%s", cat_code, b$code)
    oe_col    <- sprintf("BRANDATT2_%s_%s", cat_code, b$code)
    aware_col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    aware     <- df[[aware_col]] == 1L

    s        <- b$strength
    p_love   <- s * 0.28
    p_prefer <- s * 0.38
    p_ambiv  <- 0.12
    p_reject <- (1 - s) * 0.10
    p_nopin  <- 1 - p_love - p_prefer - p_ambiv - p_reject
    probs    <- pmax(c(p_love, p_prefer, p_ambiv, p_reject, p_nopin), 0.01)

    att             <- rep(NA_integer_, n)
    att[aware]      <- .rcat9(sum(aware), probs)
    att[!aware]     <- 5L

    oe              <- rep(NA_character_, n)
    rejecters       <- which(att == 4L)
    if (length(rejecters) > 0)
      oe[rejecters] <- sample(rejection_reasons, length(rejecters), replace = TRUE)

    df[[att_col]] <- att
    df[[oe_col]]  <- oe
  }

  # Penetration long (conditional on awareness)
  for (b in brands) {
    col       <- sprintf("BRANDPEN1_%s_%s", cat_code, b$code)
    aware_col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    aware     <- df[[aware_col]] == 1L
    vals      <- .rbern(n, pmin(b$strength * 0.65, 0.90))
    vals[!aware] <- 0L
    df[[col]] <- vals
  }

  # Penetration target (conditional on pen long)
  for (b in brands) {
    col      <- sprintf("BRANDPEN2_%s_%s", cat_code, b$code)
    pen1_col <- sprintf("BRANDPEN1_%s_%s", cat_code, b$code)
    pen1     <- df[[pen1_col]] == 1L
    vals     <- .rbern(n, pmin(b$strength * 0.55, 0.85))
    vals[!pen1] <- 0L
    df[[col]] <- vals
  }

  # Purchase frequency (conditional on pen target)
  for (b in brands) {
    col      <- sprintf("BRANDPEN3_%s_%s", cat_code, b$code)
    pen2_col <- sprintf("BRANDPEN2_%s_%s", cat_code, b$code)
    pen2     <- df[[pen2_col]] == 1L
    freq     <- rep(NA_integer_, n)
    s        <- b$strength
    if (sum(pen2) > 0)
      freq[pen2] <- .rcat9(sum(pen2), c(s * 0.20, s * 0.30, 0.20, (1-s) * 0.20, (1-s) * 0.10))
    df[[col]] <- freq
  }

  # CEP x brand matrix
  engagement <- .rtrunc9(n, mean = 1.0, sd = 0.22, lo = 0.35, hi = 1.55)
  for (b in brands) {
    aware_col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    aware     <- df[[aware_col]] == 1L
    p_base    <- .cep_link_prob9(b)
    for (cep in ceps) {
      col    <- sprintf("%s_%s", cep$code, b$code)
      p_row  <- pmin(pmax(p_base * engagement, 0), 0.95)
      vals   <- .rbern(n, p_row)
      vals[!aware] <- 0L
      df[[col]] <- vals
    }
  }

  # Attribute x brand matrix (category-prefixed codes)
  eng_attr <- .rtrunc9(n, mean = 1.0, sd = 0.15, lo = 0.55, hi = 1.45)
  for (b in brands) {
    aware_col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    aware     <- df[[aware_col]] == 1L
    for (attr in attrs) {
      col    <- sprintf("%s_%s_%s", cat_code, attr$code, b$code)  # e.g. DSS_ATTR01_IPK
      p_base <- .attr_link_prob9(b, attr$code)
      p_row  <- pmin(pmax(p_base * eng_attr, 0), 0.93)
      vals   <- .rbern(n, p_row)
      vals[!aware] <- 0L
      df[[col]] <- vals
    }
  }

  # Purchase channels (conditional on buying in category)
  # CHANNEL_{CAT}_{CHANNELCODE} — multi-mention, buyers only
  bought <- df[[catbuy_col]] < 5L  # anyone who buys at all
  channel_probs <- c(SUPMKT=0.88, SPECIA=0.18, ONLINE=0.22,
                     CONVEN=0.12, WHOLES=0.15, MARKET=0.08, OTHER=0.04)
  for (ch in cat9_channels()) {
    col      <- sprintf("CHANNEL_%s_%s", cat_code, ch$code)
    vals     <- .rbern(n, channel_probs[[ch$code]])
    vals[!bought] <- 0L
    df[[col]] <- vals
  }

  # Pack sizes (conditional on buying in category)
  # PACKSIZE_{CAT}_{PACKSIZECODE} — multi-mention, buyers only.
  # Synthetic prevalences are tuned so MEDIUM / LARGE dominate (typical for
  # food staples), SMALL is moderate, and MULTI is a minority "bulk-buy"
  # signal. Real surveys would calibrate these from observed shares.
  packsize_probs <- c(SMALL = 0.32, MEDIUM = 0.62,
                      LARGE = 0.41, MULTI = 0.18)
  for (p in cat9_packsizes()) {
    col      <- sprintf("PACKSIZE_%s_%s", cat_code, p$code)
    vals     <- .rbern(n, packsize_probs[[p$code]])
    vals[!bought] <- 0L
    df[[col]] <- vals
  }

  df
}


# ==============================================================================
# BUILD AWARENESS-ONLY BLOCK  (all 5 awareness-only categories, all respondents)
# ==============================================================================

.build_9cat_aware_only_block <- function(n_total) {

  aware_cats <- Filter(function(c) c$analysis_depth == "awareness_only", cat9_categories())
  df <- data.frame(row.names = seq_len(n_total), stringsAsFactors = FALSE)

  for (cat in aware_cats) {
    brands <- cat9_brands(cat$code)
    for (b in brands) {
      col <- sprintf("BRANDAWARE_%s_%s", cat$code, b$code)
      df[[col]] <- .rbern(n_total, b$awareness_rate)
    }
  }

  df
}


# ==============================================================================
# BUILD WOM BLOCK  (full-category brands, focal respondents only)
# ==============================================================================

.build_9cat_wom_block <- function(n_total, focal_cats) {

  full_codes <- vapply(Filter(function(c) c$analysis_depth == "full", cat9_categories()),
                       function(c) c$code, character(1))

  wom_df <- data.frame(row.names = seq_len(n_total), stringsAsFactors = FALSE)

  for (cat_code in full_codes) {
    brands   <- cat9_brands(cat_code)
    is_focal <- focal_cats == cat_code

    for (b in brands) {
      pos_rec_col   <- sprintf("WOM_POS_REC_%s",   b$code)
      neg_rec_col   <- sprintf("WOM_NEG_REC_%s",   b$code)
      pos_share_col <- sprintf("WOM_POS_SHARE_%s", b$code)
      pos_count_col <- sprintf("WOM_POS_COUNT_%s", b$code)
      neg_share_col <- sprintf("WOM_NEG_SHARE_%s", b$code)
      neg_count_col <- sprintf("WOM_NEG_COUNT_%s", b$code)

      # Add columns only once (shared brands like IPK, KNORR appear in multiple cats)
      if (!pos_rec_col %in% names(wom_df)) {
        wom_df[[pos_rec_col]]   <- NA_integer_
        wom_df[[neg_rec_col]]   <- NA_integer_
        wom_df[[pos_share_col]] <- NA_integer_
        wom_df[[pos_count_col]] <- NA_integer_
        wom_df[[neg_share_col]] <- NA_integer_
        wom_df[[neg_count_col]] <- NA_integer_
      }

      rows <- which(is_focal)
      if (length(rows) == 0) next
      nr <- length(rows)

      pos_rec   <- .rbern(nr, .wom_pos_rec_prob9(b))
      neg_rec   <- .rbern(nr, .wom_neg_rec_prob9(b))
      pos_share <- .rbern(nr, .wom_pos_share_prob9(b))
      neg_share <- .rbern(nr, .wom_neg_share_prob9(b))

      pos_count              <- rep(NA_integer_, nr)
      pos_count[pos_share==1L] <- .rcat9(sum(pos_share), c(0.40, 0.28, 0.17, 0.09, 0.06))

      neg_count              <- rep(NA_integer_, nr)
      neg_count[neg_share==1L] <- .rcat9(sum(neg_share), c(0.55, 0.25, 0.12, 0.05, 0.03))

      wom_df[rows, pos_rec_col]   <- pos_rec
      wom_df[rows, neg_rec_col]   <- neg_rec
      wom_df[rows, pos_share_col] <- pos_share
      wom_df[rows, pos_count_col] <- pos_count
      wom_df[rows, neg_share_col] <- neg_share
      wom_df[rows, neg_count_col] <- neg_count
    }
  }

  wom_df
}


# ==============================================================================
# BUILD MARKETING REACH BLOCK  (Q013–Q015 per asset)
# ==============================================================================

.build_9cat_reach_block <- function(n_total, focal_cats) {

  reach_df  <- data.frame(row.names = seq_len(n_total), stringsAsFactors = FALSE)
  media_codes <- vapply(cat9_reach_media(), function(m) m$code, character(1))

  for (a in cat9_reach_assets()) {
    # Determine which respondents were shown this asset
    if (a$category == "ALL") {
      eligible <- rep(TRUE, n_total)
    } else {
      eligible <- focal_cats == a$category
    }

    seen_col  <- sprintf("REACH_SEEN_%s",  a$code)
    brand_col <- sprintf("REACH_BRAND_%s", a$code)
    media_col <- sprintf("REACH_MEDIA_%s", a$code)

    # REACH_SEEN: 1=yes, 2=no  (roughly 35–55% recognition for an average ad)
    seen_vals           <- rep(NA_integer_, n_total)
    seen_vals[eligible] <- ifelse(.rbern(sum(eligible), 0.42) == 1L, 1L, 2L)
    reach_df[[seen_col]] <- seen_vals

    # REACH_BRAND: prompted single-select brand attribution. Cell value is a
    # brand code (must match Brands sheet), 'DK' (don't know) or 'OTHER'.
    # ~62% correctly attribute to the focal brand, ~24% misattribute to a
    # competitor, ~14% pick DK / OTHER.
    brand_vals <- rep(NA_character_, n_total)
    recognised <- !is.na(seen_vals) & seen_vals == 1L
    nr         <- sum(recognised)
    if (nr > 0) {
      # Build a per-asset attribution pool: the asset's correct brand,
      # competitor brand codes, and DK / OTHER.
      competitor_codes <- if (!is.null(a$category) && a$category != "ALL") {
        setdiff(vapply(cat9_brands(a$category), function(b) b$code, character(1)),
                a$brand)
      } else {
        # ALL ads: synthesise a generic competitor pool from the focal-brand cats
        unique(unlist(lapply(c("DSS", "POS", "PAS", "BAK"), function(cc)
          setdiff(vapply(cat9_brands(cc), function(b) b$code, character(1)),
                  a$brand))))
      }
      pool   <- c(a$brand, competitor_codes, "DK", "OTHER")
      probs  <- c(0.62,
                  rep((1 - 0.62 - 0.10 - 0.04) / max(length(competitor_codes), 1),
                      length(competitor_codes)),
                  0.10, 0.04)
      probs  <- probs / sum(probs)
      brand_vals[recognised] <- sample(pool, nr, replace = TRUE, prob = probs)
    }
    reach_df[[brand_col]] <- brand_vals

    # REACH_MEDIA: comma-separated media codes (only if seen; multi-mention).
    media_probs <- c(TV=0.45, SOCIAL=0.38, ONLINE=0.32, PRINT=0.20,
                     OUTDOOR=0.12, RADIO=0.08, INSTORE=0.18, OTHER=0.03)
    media_vals  <- rep(NA_character_, n_total)
    if (nr > 0) {
      rows_seen <- which(recognised)
      media_vals[rows_seen] <- vapply(rows_seen, function(i) {
        selected <- media_codes[vapply(media_codes, function(m)
          .rbern(1, media_probs[[m]]) == 1L, logical(1))]
        if (length(selected) == 0) selected <- sample(media_codes, 1)
        paste(selected, collapse = ",")
      }, character(1))
    }
    reach_df[[media_col]] <- media_vals
  }

  reach_df
}


# ==============================================================================
# BUILD DBA BLOCK  (all respondents, IPK assets only)
# ==============================================================================

.build_9cat_dba_block <- function(n) {
  dba_df <- data.frame(row.names = seq_len(n), stringsAsFactors = FALSE)

  correct_brands <- c("Ina Paarman", "Ina Paarman's Kitchen", "IPK")
  noise_brands   <- c("Robertsons", "Woolworths", "Don't know", "Knorr")

  for (a in cat9_dba_assets()) {
    fame_col   <- sprintf("DBA_FAME_%s",   a$code)
    unique_col <- sprintf("DBA_UNIQUE_%s", a$code)

    fame <- ifelse(.rbern(n, a$fame_rate) == 1L, 1L, 2L)
    dba_df[[fame_col]] <- fame

    attr_text  <- rep(NA_character_, n)
    recognised <- fame == 1L
    nr         <- sum(recognised)
    if (nr > 0) {
      picks <- character(nr)
      for (i in seq_len(nr)) {
        if (runif(1) < a$unique_attribution_rate) {
          picks[i] <- sample(correct_brands, 1)
        } else {
          picks[i] <- sample(noise_brands, 1)
        }
      }
      attr_text[recognised] <- picks
    }
    dba_df[[unique_col]] <- attr_text
  }

  dba_df
}


# ==============================================================================
# MAIN DATA GENERATOR
# ==============================================================================

#' Generate the synthetic data file for the IPK 9-category example
#'
#' @param output_path Character. Destination path (.xlsx or .csv).
#' @param n           Integer. Total respondents; split equally across 4 full categories.
#' @param seed        Integer. RNG seed (default: 42).
#' @param overwrite   Logical. Overwrite if file exists (default: TRUE).
#' @return Invisibly returns the output_path.
#' @export
generate_9cat_data <- function(output_path, n = 400, seed = 42, overwrite = TRUE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) stop("Package 'openxlsx' is required")
  if (file.exists(output_path) && !overwrite) {
    cat(sprintf("  ! Data file already exists (skipped): %s\n", output_path))
    return(invisible(output_path))
  }

  set.seed(seed)

  full_codes  <- c("DSS", "POS", "PAS", "BAK")
  aware_codes <- c("SLD", "STO", "PES", "COO", "ANT")
  all_codes   <- c(full_codes, aware_codes)
  n_per_cat   <- floor(n / 4)
  n_total     <- n_per_cat * 4
  focal_cats  <- rep(full_codes, each = n_per_cat)

  # Screener columns: SQ1_{catcode} and SQ2_{catcode} for all 9 categories
  # Focal category = always 1 for both screeners (respondent qualified).
  # Other full categories = probabilistic multi-category buying.
  # Awareness-only categories = probabilistic based on category prevalence.
  sq1_df <- data.frame(row.names = seq_len(n_total), stringsAsFactors = FALSE)
  sq2_df <- data.frame(row.names = seq_len(n_total), stringsAsFactors = FALSE)

  cat_long_buy_prev  <- c(DSS=0.72, POS=0.60, PAS=0.65, BAK=0.55,
                          SLD=0.58, STO=0.68, PES=0.38, COO=0.55, ANT=0.28)
  cat_target_buy_prev <- c(DSS=0.52, POS=0.42, PAS=0.48, BAK=0.38,
                           SLD=0.40, STO=0.50, PES=0.25, COO=0.40, ANT=0.18)

  for (cc in all_codes) {
    sq1_col <- sprintf("SQ1_%s", cc)
    sq2_col <- sprintf("SQ2_%s", cc)
    focal_mask <- focal_cats == cc

    sq1_vals <- .rbern(n_total, cat_long_buy_prev[[cc]])
    sq2_vals <- .rbern(n_total, cat_target_buy_prev[[cc]])

    # Focal category respondents always pass both screeners
    sq1_vals[focal_mask] <- 1L
    sq2_vals[focal_mask] <- 1L
    # SQ2 cannot be 1 if SQ1 is 0
    sq2_vals[sq1_vals == 0L] <- 0L

    sq1_df[[sq1_col]] <- sq1_vals
    sq2_df[[sq2_col]] <- sq2_vals
  }

  # System columns
  sys_df <- data.frame(
    Respondent_ID  = sprintf("R%04d", seq_len(n_total)),
    Weight         = round(.rtrunc9(n_total, mean = 1.0, sd = 0.15, lo = 0.55, hi = 1.55), 3),
    Focal_Category = focal_cats,
    stringsAsFactors = FALSE
  )

  # Full-category blocks (one per focal category; padded with NA for other respondents)
  cat_blocks <- lapply(full_codes, function(cc) {
    n_cat  <- sum(focal_cats == cc)
    block  <- .build_9cat_cat_block(n_cat, cc)
    full   <- as.data.frame(matrix(NA, nrow = n_total, ncol = ncol(block)))
    colnames(full) <- colnames(block)
    rows   <- which(focal_cats == cc)
    full[rows, ] <- block
    full
  })

  # Awareness-only block (all 400 respondents × 5 × 10 brands = 50 columns)
  aware_only_df <- .build_9cat_aware_only_block(n_total)

  # WOM block (full-category brands, focal respondents only)
  wom_df <- .build_9cat_wom_block(n_total, focal_cats)

  # Marketing reach block (per asset; ALL = all respondents, category = focal only)
  reach_df <- .build_9cat_reach_block(n_total, focal_cats)

  # DBA block (all respondents)
  dba_df <- .build_9cat_dba_block(n_total)

  # Demographics (coded values matching Options sheet)
  dem_df <- data.frame(
    AGE       = .rcat9(n_total, c(0.18, 0.32, 0.28, 0.16, 0.06)),
    GENDER    = .rcat9(n_total, c(0.52, 0.46, 0.02)),
    PROVINCE  = .rcat9(n_total, c(0.34, 0.22, 0.24, 0.10, 0.03, 0.03, 0.02, 0.01, 0.01)),
    LSM       = .rcat9(n_total, c(0.12, 0.28, 0.35, 0.18, 0.07)),
    RACE      = .rcat9(n_total, c(0.52, 0.20, 0.10, 0.16, 0.02)),
    HH_INCOME = .rcat9(n_total, c(0.10, 0.22, 0.30, 0.24, 0.14)),
    stringsAsFactors = FALSE
  )

  # Combine all blocks (screeners first, then system, then category batteries)
  all_blocks <- c(list(sq1_df, sq2_df, sys_df), cat_blocks,
                  list(aware_only_df, wom_df, reach_df, dba_df, dem_df))
  full_df    <- do.call(cbind, all_blocks)

  # Write output
  ext <- tolower(tools::file_ext(output_path))
  if (ext == "xlsx") {
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Data")
    openxlsx::writeData(wb, "Data", full_df, rowNames = FALSE)
    openxlsx::freezePane(wb, "Data", firstRow = TRUE)

    hdr_style <- openxlsx::createStyle(
      fontName = "Calibri", fontSize = 10, textDecoration = "bold",
      fgFill = "#1B3A5C", fontColour = "#FFFFFF", halign = "center",
      border = "Bottom", borderColour = "#FFFFFF"
    )
    openxlsx::addStyle(wb, "Data", hdr_style,
                       rows = 1, cols = seq_along(full_df), gridExpand = TRUE)

    dat_style <- openxlsx::createStyle(fontName = "Calibri", fontSize = 9)
    openxlsx::addStyle(wb, "Data", dat_style,
                       rows = seq(2, nrow(full_df) + 1), cols = seq_along(full_df),
                       gridExpand = TRUE)

    openxlsx::setColWidths(wb, "Data", cols = seq_along(full_df), widths = "auto")
    openxlsx::saveWorkbook(wb, output_path, overwrite = overwrite)

  } else {
    data.table::fwrite(full_df, output_path)
  }

  cat(sprintf("  + Data file (%d rows x %d cols) -> %s\n",
              nrow(full_df), ncol(full_df), output_path))
  invisible(output_path)
}
