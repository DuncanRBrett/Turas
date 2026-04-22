# ==============================================================================
# 3CAT SYNTHETIC EXAMPLE - DATA GENERATOR
# ==============================================================================
# Generates realistic synthetic respondent data for the IPK 3-category study.
# 300 respondents: 100 DSS, 100 PAS, 100 SLD.
#
# Each respondent fills only their focal category's columns. All other
# category columns remain NA (as they would in a real multi-category export).
# DBA and demographics are answered by all respondents regardless of category.
#
# Depends on: 01_constants.R
# ==============================================================================


# ==============================================================================
# HELPERS
# ==============================================================================

.rbern <- function(n, p) as.integer(runif(n) < p)

.rcat <- function(n, probs) {
  sample(seq_along(probs), n, replace = TRUE, prob = probs)
}

.rtrunc <- function(n, mean, sd, lo, hi) {
  x <- rnorm(n, mean, sd)
  pmin(pmax(x, lo), hi)
}

# Awareness probability boosted by category buying frequency
.awareness_prob <- function(brand, cat_buy_val) {
  base <- brand$awareness_rate
  boost <- 1.0 + 0.18 * (3 - cat_buy_val) / 2
  pmin(base * boost, 0.98)
}

# CEP linkage probability (uniform base, scaled by brand strength)
.cep_link_prob <- function(brand) {
  pmin(0.08 + brand$strength * 0.35, 0.90)
}

# Attribute linkage probability (scaled by quality tier and brand strength)
.attr_link_prob <- function(brand, attr_code) {
  base <- brand$strength * 0.50
  boost <- switch(brand$quality_tier,
    premium    = c(ATTR01 = 0.05, ATTR02 = 0.20, ATTR03 = 0.18, ATTR04 = 0.15, ATTR05 = 0.10),
    mainstream = c(ATTR01 = 0.15, ATTR02 = 0.05, ATTR03 = 0.10, ATTR04 = 0.10, ATTR05 = 0.15),
    value      = c(ATTR01 = 0.25, ATTR02 = -0.05, ATTR03 = 0.00, ATTR04 = 0.05, ATTR05 = 0.20),
    rep(0, 5)
  )
  pmin(pmax(base + (boost[[attr_code]] %||% 0), 0.02), 0.92)
}

# WOM probability (positive and negative)
.wom_pos_rec_prob <- function(brand) pmin(0.05 + brand$strength * 0.20, 0.40)
.wom_neg_rec_prob <- function(brand) pmin(0.02 + (1 - brand$strength) * 0.08, 0.15)
.wom_pos_share_prob <- function(brand) pmin(0.03 + brand$strength * 0.12, 0.25)
.wom_neg_share_prob <- function(brand) pmin(0.01 + (1 - brand$strength) * 0.05, 0.10)


# ==============================================================================
# BUILD ONE RESPONDENT BLOCK (per focal category)
# ==============================================================================

.build_cat_block <- function(n, cat_code) {

  cat_def  <- cat3_category(cat_code)
  brands   <- cat3_brands(cat_code)
  ceps     <- cat3_ceps(cat_code)
  attrs    <- cat3_attributes()

  df <- data.frame(row.names = seq_len(n), stringsAsFactors = FALSE)

  # --- Category buying ---
  catbuy_col <- sprintf("CATBUY_%s", cat_code)
  cat_buy    <- .rcat(n, c(0.13, 0.37, 0.34, 0.14, 0.02))
  df[[catbuy_col]] <- cat_buy

  # --- Awareness ---
  aware_mat <- matrix(0L, n, length(brands))
  colnames(aware_mat) <- sapply(brands, function(b) sprintf("BRANDAWARE_%s_%s", cat_code, b$code))
  for (j in seq_along(brands)) {
    p <- mapply(.awareness_prob, list(brands[[j]]), cat_buy)
    aware_mat[, j] <- .rbern(n, p)
  }
  df <- cbind(df, aware_mat)

  # --- Attitude (single response per brand, conditional on awareness) ---
  # Codes: 1=love, 2=prefer, 3=ambivalent, 4=reject, 5=no opinion
  for (b in brands) {
    att_col <- sprintf("BRANDATT1_%s_%s", cat_code, b$code)
    oe_col  <- sprintf("BRANDATT2_%s_%s", cat_code, b$code)
    aware   <- df[[sprintf("BRANDAWARE_%s_%s", cat_code, b$code)]] == 1L

    att <- rep(NA_integer_, n)
    oe  <- rep(NA_character_, n)

    # Attitude probabilities depend on brand strength
    s  <- b$strength
    p_love   <- s * 0.28
    p_prefer <- s * 0.38
    p_ambiv  <- 0.12
    p_reject <- (1 - s) * 0.10
    p_nopin  <- 1 - p_love - p_prefer - p_ambiv - p_reject
    probs    <- pmax(c(p_love, p_prefer, p_ambiv, p_reject, p_nopin), 0.01)

    att[aware]  <- .rcat(sum(aware), probs)
    att[!aware] <- 5L   # not aware → no opinion

    # Open-ended rejection reason (code 4)
    rejecters <- which(att == 4L)
    if (length(rejecters) > 0) {
      reasons <- c("Too expensive", "Don't like the flavour", "Prefer other brands",
                   "Never tried it", "Bad experience in the past", "Don't trust it")
      oe[rejecters] <- sample(reasons, length(rejecters), replace = TRUE)
    }

    df[[att_col]] <- att
    df[[oe_col]]  <- oe
  }

  # --- Penetration long (conditional on awareness) ---
  for (b in brands) {
    col   <- sprintf("BRANDPEN1_%s_%s", cat_code, b$code)
    aware <- df[[sprintf("BRANDAWARE_%s_%s", cat_code, b$code)]] == 1L
    p_pen <- pmin(b$strength * 0.65, 0.90)
    vals  <- .rbern(n, p_pen)
    vals[!aware] <- 0L
    df[[col]] <- vals
  }

  # --- Penetration target (conditional on pen long) ---
  for (b in brands) {
    pen1_col <- sprintf("BRANDPEN1_%s_%s", cat_code, b$code)
    col      <- sprintf("BRANDPEN2_%s_%s", cat_code, b$code)
    pen1     <- df[[pen1_col]] == 1L
    p_pen    <- pmin(b$strength * 0.55, 0.85)
    vals     <- .rbern(n, p_pen)
    vals[!pen1] <- 0L
    df[[col]] <- vals
  }

  # --- Purchase frequency (conditional on pen target) ---
  for (b in brands) {
    pen2_col <- sprintf("BRANDPEN2_%s_%s", cat_code, b$code)
    col      <- sprintf("BRANDPEN3_%s_%s", cat_code, b$code)
    pen2     <- df[[pen2_col]] == 1L
    freq     <- rep(NA_integer_, n)
    s        <- b$strength
    freq[pen2] <- .rcat(sum(pen2), c(s * 0.20, s * 0.30, 0.20, (1-s) * 0.20, (1-s) * 0.10))
    df[[col]] <- freq
  }

  # --- CEP x brand matrix ---
  engagement <- .rtrunc(n, mean = 1.0, sd = 0.22, lo = 0.35, hi = 1.55)
  for (b in brands) {
    aware_col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    aware     <- df[[aware_col]] == 1L
    p_base    <- .cep_link_prob(b)
    for (cep in ceps) {
      col    <- sprintf("%s_%s", cep$code, b$code)
      p_row  <- pmin(pmax(p_base * engagement, 0), 0.95)
      vals   <- .rbern(n, p_row)
      vals[!aware] <- 0L
      df[[col]] <- vals
    }
  }

  # --- Attribute x brand matrix (category-prefixed) ---
  eng_attr <- .rtrunc(n, mean = 1.0, sd = 0.15, lo = 0.55, hi = 1.45)
  for (b in brands) {
    aware_col <- sprintf("BRANDAWARE_%s_%s", cat_code, b$code)
    aware     <- df[[aware_col]] == 1L
    for (attr in attrs) {
      col   <- sprintf("%s_%s_%s", cat_code, attr$code, b$code)  # e.g. DSS_ATTR01_IPK
      p_base <- .attr_link_prob(b, attr$code)
      p_row  <- pmin(pmax(p_base * eng_attr, 0), 0.93)
      vals   <- .rbern(n, p_row)
      vals[!aware] <- 0L
      df[[col]] <- vals
    }
  }

  df
}


# ==============================================================================
# BUILD WOM BLOCK  (all brands across all 3 categories)
# ==============================================================================

.build_wom_block <- function(n_total, focal_cats) {
  # focal_cats: character vector of length n_total, one of "DSS"/"PAS"/"SLD"

  wom_df <- data.frame(row.names = seq_len(n_total), stringsAsFactors = FALSE)

  # For each category's brands, fill WOM only for respondents in that category
  for (cat_code in c("DSS", "PAS", "SLD")) {
    brands   <- cat3_brands(cat_code)
    is_focal <- focal_cats == cat_code

    for (b in brands) {
      pos_rec_col   <- sprintf("WOM_POS_REC_%s",   b$code)
      neg_rec_col   <- sprintf("WOM_NEG_REC_%s",   b$code)
      pos_share_col <- sprintf("WOM_POS_SHARE_%s", b$code)
      pos_count_col <- sprintf("WOM_POS_COUNT_%s", b$code)
      neg_share_col <- sprintf("WOM_NEG_SHARE_%s", b$code)
      neg_count_col <- sprintf("WOM_NEG_COUNT_%s", b$code)

      # Only add column if not already present (shared brands like IPK, KNORR, ALGLD)
      if (!pos_rec_col %in% names(wom_df)) {
        wom_df[[pos_rec_col]]   <- NA_integer_
        wom_df[[neg_rec_col]]   <- NA_integer_
        wom_df[[pos_share_col]] <- NA_integer_
        wom_df[[pos_count_col]] <- NA_integer_
        wom_df[[neg_share_col]] <- NA_integer_
        wom_df[[neg_count_col]] <- NA_integer_
      }

      # For respondents in this category, simulate WOM
      rows <- which(is_focal)
      if (length(rows) == 0) next
      nr <- length(rows)

      pos_rec   <- .rbern(nr, .wom_pos_rec_prob(b))
      neg_rec   <- .rbern(nr, .wom_neg_rec_prob(b))
      pos_share <- .rbern(nr, .wom_pos_share_prob(b))
      neg_share <- .rbern(nr, .wom_neg_share_prob(b))

      pos_count <- rep(NA_integer_, nr)
      pos_count[pos_share == 1L] <- .rcat(sum(pos_share), c(0.40, 0.28, 0.17, 0.09, 0.06))

      neg_count <- rep(NA_integer_, nr)
      neg_count[neg_share == 1L] <- .rcat(sum(neg_share), c(0.55, 0.25, 0.12, 0.05, 0.03))

      # For brands shared across categories: if brand is ALSO in another category,
      # respondents in the OTHER category still get NA (they weren't asked about
      # this brand because their focal category may not include it — unless it does)
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

.build_dba_block <- function(n) {
  dba_df <- data.frame(row.names = seq_len(n), stringsAsFactors = FALSE)

  for (a in cat3_dba_assets()) {
    fame_col   <- sprintf("DBA_FAME_%s",   a$code)
    unique_col <- sprintf("DBA_UNIQUE_%s", a$code)

    # Fame: binary recognition (1=yes, 2=no)
    fame <- ifelse(.rbern(n, a$fame_rate) == 1L, 1L, 2L)
    dba_df[[fame_col]] <- fame

    # Uniqueness: open-ended attribution
    attr_text <- rep(NA_character_, n)
    recognised <- fame == 1L
    nr <- sum(recognised)
    if (nr > 0) {
      # Correct attribution + noise brands
      correct_brands <- c("Ina Paarman", "Ina Paarman's Kitchen", "IPK")
      noise_brands   <- c("Robertsons", "Woolworths", "Don't know", "Knorr")
      p_correct      <- a$unique_attribution_rate

      picks <- character(nr)
      for (i in seq_len(nr)) {
        if (runif(1) < p_correct) {
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

#' Generate the synthetic data file for the IPK 3-category example
#'
#' @param output_path Character. Destination path (.xlsx or .csv).
#' @param n           Integer. Total respondents (split evenly across 3 categories).
#' @param seed        Integer. RNG seed.
#' @param overwrite   Logical. Overwrite if file exists (default: TRUE).
#' @return Invisibly returns the output_path.
#' @export
generate_3cat_data <- function(output_path, n = 300, seed = 42, overwrite = TRUE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) stop("Package 'openxlsx' is required")
  if (file.exists(output_path) && !overwrite) {
    cat(sprintf("  ! Data file already exists (skipped): %s\n", output_path))
    return(invisible(output_path))
  }

  set.seed(seed)

  n_per_cat <- floor(n / 3)
  n_total   <- n_per_cat * 3   # may be slightly less than n

  cat_codes   <- c("DSS", "PAS", "SLD")
  focal_cats  <- rep(cat_codes, each = n_per_cat)

  # --- System columns ---
  sys_df <- data.frame(
    Respondent_ID  = sprintf("R%04d", seq_len(n_total)),
    Weight         = round(.rtrunc(n_total, mean = 1.0, sd = 0.15, lo = 0.55, hi = 1.55), 3),
    Focal_Category = focal_cats,
    stringsAsFactors = FALSE
  )

  # --- Build per-category blocks ---
  cat_blocks <- lapply(cat_codes, function(cc) {
    n_cat  <- sum(focal_cats == cc)
    block  <- .build_cat_block(n_cat, cc)
    # Pad to n_total with NA
    full   <- as.data.frame(matrix(NA, nrow = n_total, ncol = ncol(block)))
    colnames(full) <- colnames(block)
    rows   <- which(focal_cats == cc)
    full[rows, ] <- block
    full
  })

  # --- WOM block (all categories, shared brand columns) ---
  wom_df <- .build_wom_block(n_total, focal_cats)
  # Pad to n_total rows if wom_df is shorter
  if (nrow(wom_df) < n_total) {
    extra <- as.data.frame(matrix(NA, nrow = n_total - nrow(wom_df), ncol = ncol(wom_df)))
    colnames(extra) <- colnames(wom_df)
    wom_df <- rbind(wom_df, extra)
  }

  # --- DBA block (all respondents) ---
  dba_df <- .build_dba_block(n_total)

  # --- Demographics ---
  dem_df <- data.frame(
    Age      = .rcat(n_total, c(0.20, 0.38, 0.28, 0.14)),   # 18-24, 25-34, 35-49, 50+
    Province = .rcat(n_total, c(0.34, 0.22, 0.24, 0.10, 0.05, 0.03, 0.02)),  # GT,WC,KZN,...
    LSM      = .rcat(n_total, c(0.12, 0.28, 0.35, 0.18, 0.07)),              # LSM 6-10
    stringsAsFactors = FALSE
  )

  # --- Combine all blocks ---
  all_blocks <- c(list(sys_df), cat_blocks, list(wom_df, dba_df, dem_df))
  full_df    <- do.call(cbind, all_blocks)

  # --- Write output ---
  ext <- tolower(tools::file_ext(output_path))
  if (ext == "xlsx") {
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Data")
    openxlsx::writeData(wb, "Data", full_df, rowNames = FALSE)

    # Freeze header row
    openxlsx::freezePane(wb, "Data", firstRow = TRUE)

    # Header style
    hdr_style <- openxlsx::createStyle(
      fontName = "Calibri", fontSize = 10, textDecoration = "bold",
      fgFill = "#1B3A5C", fontColour = "#FFFFFF", halign = "center",
      border = "Bottom", borderColour = "#FFFFFF"
    )
    openxlsx::addStyle(wb, "Data", hdr_style,
                       rows = 1, cols = seq_along(full_df), gridExpand = TRUE)

    # Data style
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
