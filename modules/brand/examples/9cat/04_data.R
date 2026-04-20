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

  # Category buying
  catbuy_col <- sprintf("CATBUY_%s", cat_code)
  cat_buy    <- .rcat9(n, c(0.13, 0.37, 0.34, 0.14, 0.02))
  df[[catbuy_col]] <- cat_buy

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
  n_per_cat   <- floor(n / 4)
  n_total     <- n_per_cat * 4
  focal_cats  <- rep(full_codes, each = n_per_cat)

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

  # DBA block (all respondents)
  dba_df <- .build_9cat_dba_block(n_total)

  # Demographics
  dem_df <- data.frame(
    Age      = .rcat9(n_total, c(0.20, 0.38, 0.28, 0.14)),
    Province = .rcat9(n_total, c(0.34, 0.22, 0.24, 0.10, 0.05, 0.03, 0.02)),
    LSM      = .rcat9(n_total, c(0.12, 0.28, 0.35, 0.18, 0.07)),
    stringsAsFactors = FALSE
  )

  # Combine all blocks
  all_blocks <- c(list(sys_df), cat_blocks, list(aware_only_df, wom_df, dba_df, dem_df))
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
