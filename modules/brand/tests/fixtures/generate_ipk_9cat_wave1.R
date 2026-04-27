# ==============================================================================
# GENERATE SYNTHETIC IPK 9-CATEGORY SAMPLE DATA
# ==============================================================================
# Creates ipk_9cat_wave1.xlsx with 1,200 respondents:
#   300 focal DSS (Dry Seasonings & Spices)    — full CBM
#   300 focal POS (Pour Over Sauces)           — full CBM
#   300 focal PAS (Pasta Sauces)               — full CBM
#   300 focal BAK (Baking Mixes)               — full CBM
# All 1,200 also get screener + awareness data for awareness-only categories.
# ==============================================================================

set.seed(20260420)
library(openxlsx)

OUT_PATH <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Examples/IPK_9Category/ipk_9cat_wave1.xlsx"
N <- 1200
N_PER_CAT <- 300

# Timeframe constants — must match config defaults in §1.3 of CAT_BUYING_SPEC_v3.
# BRANDPEN3 = count of purchases in the last TARGET_TIMEFRAME_MONTHS months.
# Change these constants here and all BRANDPEN3 distributions rescale automatically.
TARGET_TIMEFRAME_MONTHS <- 3L   # BRANDPEN2 + BRANDPEN3 window
LONGER_TIMEFRAME_MONTHS <- 12L  # BRANDPEN1 window

# BRANDPEN3 generation parameters — tuned so category mean M ≈ 4–5 per buyer
# over TARGET_TIMEFRAME_MONTHS = 3, producing a realistic DJ gradient:
#   focal brand (IPK): negbin(mu=6, theta=2), clamped to [1, 10*TARGET_TIMEFRAME_MONTHS]
#   competitors:       negbin(mu=3, theta=1.5), clamped to [1, 10*TARGET_TIMEFRAME_MONTHS]
BRANDPEN3_IPK_MU    <- 6
BRANDPEN3_IPK_THETA <- 2
BRANDPEN3_COMP_MU   <- 3
BRANDPEN3_COMP_THETA <- 1.5

# ---- Brand lists per category ------------------------------------------------
brands <- list(
  DSS = c("IPK","ROB","KNORR","CART","RAJAH","SFRI","SPMEC","WWTDSS","PNPDSS","CKRDSS"),
  POS = c("IPK","KNORR","ROYCO","MAGGI","SWISS","BISTO","WWPOS","HOLLS","PNPPOS","CKRPOS"),
  PAS = c("IPK","KNORR","DOLMIO","ALGLD","FATTS","BARLA","SDEL","WWPAS","PNPPAS","CKRPAS"),
  BAK = c("IPK","INNAS","BAKELS","PILLSB","MOLLY","LANCL","WWBAK","PNPBAK","CKRBAK","SIMBOL"),
  SLD = c("IPK","ALGLD","KRAFT","BULLS","NEWMN","BALEA","WWSLD","PNPSLD","CKRSLD","AMANU"),
  STO = c("IPK","KNORR","MAGGI","ROYCO","SCHWTZ","NATST","WWSTO","PNPSTO","CKRSTO","ARTSTO"),
  PES = c("IPK","BARLA","SACLA","BUONIT","NATFSH","PONTI","WWPES","PNPPES","CKRPES","ARTPST"),
  COO = c("IPK","KNORR","ROYCO","DOLMIO","NDOS","SMAC","WWCOO","PNPCOO","CKRCOO","TASTY"),
  ANT = c("IPK","BARLA","SACLA","PONTI","BUONIT","DELLAS","WWANT","PNPANT","CKRANT","ARTANT")
)
full_cats   <- c("DSS","POS","PAS","BAK")
aware_cats  <- c("SLD","STO","PES","COO","ANT")
all_cats    <- c(full_cats, aware_cats)

# CEP ranges per full category (numbered sequentially across categories)
cep_ranges  <- list(DSS = 1:15, POS = 16:30, PAS = 31:45, BAK = 46:60)

# Attributes per full category (5 each, named {CAT}_ATTR01-05)
n_attrs <- 5

# Channel suffixes for full categories
channels  <- c("SUPMKT","SPECIA","ONLINE","CONVEN","WHOLES","MARKET","OTHER")
packsizes <- c("SMALL","MEDIUM","LARGE","MULTI")

# WOM brands — all brands across all 4 full categories (unique set)
wom_brands <- unique(unlist(brands[full_cats]))

# Reach assets
reach_assets <- c("ADTV01","ADDIG01","ADDIG02","ADPR01")

# DBA assets
dba_assets <- c("LOGO","COLOUR","JAR","CHEF","TAGLINE")

# Demographics
provinces <- c("GP","WC","KZN","EC","LP","MP","NW","FS","NC")
lsm_levels <- 1:10

# ---- Helper: weighted random choice -----------------------------------------
wsample <- function(x, size, prob) {
  sample(x, size, replace = TRUE, prob = prob)
}

# ---- Simulate one focal-category block of N_PER_CAT respondents -------------
make_focal_block <- function(cat, id_start) {
  n <- N_PER_CAT
  b <- brands[[cat]]
  nb <- length(b)
  ipk_idx <- which(b == "IPK")

  # Screeners: this block qualifies for the focal category
  sq1 <- setNames(as.list(rep(0L, length(all_cats))), paste0("SQ1_", all_cats))
  sq2 <- setNames(as.list(rep(0L, length(all_cats))), paste0("SQ2_", all_cats))
  sq1[[paste0("SQ1_", cat)]] <- rep(1L, n)
  sq2[[paste0("SQ2_", cat)]] <- rep(1L, n)

  # Some respondents also qualify for other full categories (30% chance each)
  for (oc in setdiff(full_cats, cat)) {
    sq1_oc <- rbinom(n, 1, 0.30)
    sq2_oc <- sq1_oc * rbinom(n, 1, 0.75)
    sq1[[paste0("SQ1_", oc)]] <- sq1_oc
    sq2[[paste0("SQ2_", oc)]] <- sq2_oc
  }
  # Awareness-only categories: ~50% qualify for each
  for (ac in aware_cats) {
    sq1[[paste0("SQ1_", ac)]] <- rbinom(n, 1, 0.50)
    sq2[[paste0("SQ2_", ac)]] <- sq1[[paste0("SQ1_", ac)]] * rbinom(n, 1, 0.60)
  }

  # System cols
  resp_id <- seq(id_start, id_start + n - 1)
  weight  <- rep(1.0, n)
  focal   <- rep(cat, n)

  # ---- Category buying (focal cat only) ------------------------------------
  catbuy  <- wsample(1:5, n, c(0.08, 0.15, 0.35, 0.30, 0.12))
  catcount <- pmax(0L, round(rnorm(n, 8, 4)))

  # ---- Funnel data -----------------------------------------------------------
  # Awareness: IPK ~85%, competitors ~25-70% depending on position
  aware_probs <- c(0.85, rev(seq(0.25, 0.70, length.out = nb - 1)))
  aware <- sapply(aware_probs, function(p) rbinom(n, 1, p))
  colnames(aware) <- paste0("BRANDAWARE_", cat, "_", b)

  # Attitude (1-5 scale): all respondents answer for all brands.
  # Aware respondents: realistic love/prefer/ambivalent spread.
  # Non-aware respondents: mostly "no opinion" (code 5), small % reject (4).
  att1  <- matrix(NA_integer_, n, nb)
  att2  <- matrix(NA_character_, n, nb)
  for (bi in seq_len(nb)) {
    aw <- aware[, bi]
    is_ipk <- (bi == ipk_idx)
    att_probs_aware   <- if (is_ipk) c(0.30, 0.35, 0.20, 0.05, 0.10)
                         else        c(0.15, 0.25, 0.30, 0.10, 0.20)
    att_probs_unaware <- c(0.00, 0.01, 0.02, 0.07, 0.90)
    att1[aw == 1, bi] <- wsample(1:5, sum(aw),      att_probs_aware)
    att1[aw == 0, bi] <- wsample(1:5, sum(aw == 0), att_probs_unaware)
  }
  colnames(att1) <- paste0("BRANDATT1_", cat, "_", b)
  colnames(att2) <- paste0("BRANDATT2_", cat, "_", b)

  # Penetration long (12m): if aware, ~60% chance for IPK, ~20-40% competitors
  # Penetration target (3m): subset of pen_long
  pen_long_probs <- c(0.65, rev(seq(0.18, 0.45, length.out = nb - 1)))
  pen_long  <- matrix(0L, n, nb)
  pen_tgt   <- matrix(0L, n, nb)
  pen_freq  <- matrix(NA_real_, n, nb)  # BRANDPEN3: count of purchases in TARGET window
  max_count <- as.integer(10L * TARGET_TIMEFRAME_MONTHS)
  for (bi in seq_len(nb)) {
    aw <- aware[, bi]
    buyers_long <- aw * rbinom(n, 1, pen_long_probs[bi])
    pen_long[, bi] <- buyers_long
    buyers_tgt <- buyers_long * rbinom(n, 1, 0.70)
    pen_tgt[, bi] <- buyers_tgt
    n_tgt <- sum(buyers_tgt)
    if (n_tgt > 0) {
      is_ipk <- (b[bi] == "IPK")
      mu    <- if (is_ipk) BRANDPEN3_IPK_MU    else BRANDPEN3_COMP_MU
      theta <- if (is_ipk) BRANDPEN3_IPK_THETA  else BRANDPEN3_COMP_THETA
      # rnegbin via MASS or base stats::rnbinom (size = theta, mu = mu)
      raw_counts <- stats::rnbinom(n_tgt, size = theta, mu = mu)
      # Clamp: floor at 1 (bought at least once), cap at 10×window
      raw_counts <- pmax(1L, pmin(max_count, as.integer(raw_counts)))
      pen_freq[buyers_tgt == 1, bi] <- raw_counts
    }
  }
  colnames(pen_long) <- paste0("BRANDPEN1_", cat, "_", b)
  colnames(pen_tgt)  <- paste0("BRANDPEN2_", cat, "_", b)
  colnames(pen_freq) <- paste0("BRANDPEN3_", cat, "_", b)

  # ---- CEPs (15 per category) -----------------------------------------------
  cep_nums <- cep_ranges[[cat]]
  n_cep <- length(cep_nums)
  cep_list <- list()
  for (bi in seq_len(nb)) {
    aw <- aware[, bi]
    # Each CEP: ~40% endorsement base, IPK slightly higher
    base_p <- ifelse(bi == ipk_idx, 0.45, 0.35)
    for (ci in seq_len(n_cep)) {
      cname <- sprintf("CEP%02d_%s", cep_nums[ci], b[bi])
      vals <- rep(0L, n)
      vals[aw == 1] <- rbinom(sum(aw), 1, base_p + rnorm(1, 0, 0.05))
      cep_list[[cname]] <- vals
    }
  }

  # ---- Attributes (5 per brand per category) --------------------------------
  attr_list <- list()
  for (bi in seq_len(nb)) {
    aw <- aware[, bi]
    for (ai in 1:n_attrs) {
      aname <- sprintf("%s_ATTR%02d_%s", cat, ai, b[bi])
      vals <- rep(0L, n)
      vals[aw == 1] <- rbinom(sum(aw), 1, 0.40)
      attr_list[[aname]] <- vals
    }
  }

  # ---- Channels (only for focal cat buyers) ---------------------------------
  chan_list <- list()
  is_buyer <- pen_tgt[, ipk_idx] == 1 | rowSums(pen_tgt) > 0
  for (ch in channels) {
    cname <- paste0("CHANNEL_", cat, "_", ch)
    vals <- rep(0L, n)
    vals[is_buyer] <- rbinom(sum(is_buyer), 1, runif(1, 0.10, 0.70))
    chan_list[[cname]] <- vals
  }

  # ---- Pack sizes (only for focal cat buyers) -------------------------------
  # Snapshot/restore RNG state so this newly added block does not shift the
  # main random stream — the portfolio-base tests assert specific counts
  # (DSS = 506, STO = 349, ...) that depend on the unaltered post-channel
  # sequence. A separate per-category seed gives reproducible pack data
  # without disturbing those magic numbers.
  .seed_save <- if (exists(".Random.seed", envir = globalenv()))
    get(".Random.seed", envir = globalenv()) else NULL
  set.seed(20260427L + sum(utf8ToInt(cat)))
  pack_probs <- c(SMALL = 0.32, MEDIUM = 0.62, LARGE = 0.41, MULTI = 0.18)
  pack_list <- list()
  for (ps in packsizes) {
    cname <- paste0("PACKSIZE_", cat, "_", ps)
    vals <- rep(0L, n)
    vals[is_buyer] <- rbinom(sum(is_buyer), 1, pack_probs[[ps]])
    pack_list[[cname]] <- vals
  }
  if (!is.null(.seed_save)) assign(".Random.seed", .seed_save, envir = globalenv())

  # ---- Awareness for ALL non-focal categories (full + awareness-only) --------
  # All respondents answer brand awareness for every category (not just focal).
  # For full categories: conditioned on SQ1 screener, ~IPK 75%, others 20-55%.
  # For awareness-only categories: same approach.
  # (Focal category awareness is already in the `aware` matrix above.)
  aware_cols <- list()
  for (oc in setdiff(all_cats, cat)) {
    ob  <- brands[[oc]]
    nb_oc <- length(ob)
    sq1_oc <- unlist(sq1[[paste0("SQ1_", oc)]])
    is_qual <- sq1_oc == 1
    ipk_pos <- which(ob == "IPK")
    aware_probs_oc <- c(0.75, rev(seq(0.20, 0.55, length.out = nb_oc - 1)))
    for (bi_oc in seq_along(ob)) {
      cname <- paste0("BRANDAWARE_", oc, "_", ob[bi_oc])
      vals  <- rep(0L, n)
      if (any(is_qual)) {
        vals[is_qual] <- rbinom(sum(is_qual), 1, aware_probs_oc[bi_oc])
      }
      aware_cols[[cname]] <- vals
    }
  }

  # ---- WOM (per brand across all focal cats) --------------------------------
  wom_list <- list()
  for (wbr in wom_brands) {
    aw_this <- if (wbr %in% b) aware[, which(b == wbr)]
               else rep(0L, n)
    for (wtype in c("POS_REC","NEG_REC","POS_SHARE","NEG_SHARE")) {
      p_wom <- if (grepl("POS", wtype)) 0.20 else 0.10
      vals <- rep(0L, n)
      vals[aw_this == 1] <- rbinom(sum(aw_this), 1, p_wom)
      wom_list[[paste0("WOM_", wtype, "_", wbr)]] <- vals
    }
    for (ctype in c("POS_COUNT","NEG_COUNT")) {
      base_col <- sub("COUNT", "SHARE", ctype)
      share_vals <- wom_list[[paste0("WOM_", base_col, "_", wbr)]]
      vals <- rep(NA_integer_, n)
      vals[share_vals == 1] <- wsample(1:5, sum(share_vals == 1), c(0.30,0.30,0.20,0.12,0.08))
      wom_list[[paste0("WOM_", ctype, "_", wbr)]] <- vals
    }
  }

  # ---- Reach ----------------------------------------------------------------
  reach_list <- list()
  for (ra in reach_assets) {
    seen <- rbinom(n, 1, 0.35)
    reach_list[[paste0("REACH_SEEN_", ra)]]  <- ifelse(seen == 1, 1L, 2L)
    reach_list[[paste0("REACH_BRAND_", ra)]] <- ifelse(seen == 1,
      sample(c("IPK","Ina Paarman","Knorr","Robertsons","Don't know",""),
             n, replace = TRUE, prob = c(0.30,0.15,0.20,0.10,0.15,0.10)), NA_character_)
    reach_list[[paste0("REACH_MEDIA_", ra)]] <- ifelse(seen == 1, "TV", NA_character_)
  }

  # ---- DBA ------------------------------------------------------------------
  dba_list <- list()
  for (da in dba_assets) {
    recognised <- rbinom(n, 1, 0.55)
    dba_list[[paste0("DBA_FAME_", da)]]   <- ifelse(recognised == 1, 1L, 2L)
    dba_list[[paste0("DBA_UNIQUE_", da)]] <- ifelse(recognised == 1,
      sample(c("Ina Paarman","IPK","Red jar","Chef","Tagline",""), n, replace = TRUE,
             prob = c(0.25,0.20,0.15,0.15,0.10,0.15)), NA_character_)
  }

  # ---- Demographics ---------------------------------------------------------
  demo <- data.frame(
    AGE       = sample(18:65, n, replace = TRUE),
    GENDER    = sample(c("Male","Female"), n, replace = TRUE, prob = c(0.42,0.58)),
    PROVINCE  = sample(provinces, n, replace = TRUE,
                       prob = c(0.30,0.18,0.20,0.09,0.05,0.05,0.04,0.05,0.04)),
    LSM       = wsample(lsm_levels, n, c(0.02,0.04,0.07,0.10,0.14,0.17,0.18,0.14,0.09,0.05)),
    RACE      = sample(c("Black","White","Coloured","Indian/Asian"), n, replace = TRUE,
                       prob = c(0.80,0.09,0.08,0.03)),
    HH_INCOME = wsample(c("<5k","5-10k","10-20k","20-40k","40k+"), n,
                        c(0.15,0.20,0.30,0.25,0.10)),
    stringsAsFactors = FALSE
  )

  # ---- Assemble data frame --------------------------------------------------
  df <- data.frame(
    stringsAsFactors = FALSE,
    as.data.frame(sq1),
    as.data.frame(sq2)
  )
  df$Respondent_ID    <- resp_id
  df$Weight           <- weight
  df$Focal_Category   <- focal
  df[[paste0("CATBUY_", cat)]]  <- catbuy
  df[[paste0("CATCOUNT_", cat)]] <- catcount
  df <- cbind(df, aware, att1, att2, pen_long, pen_tgt, pen_freq,
              as.data.frame(cep_list),
              as.data.frame(attr_list),
              as.data.frame(chan_list),
              as.data.frame(pack_list),
              stringsAsFactors = FALSE)
  df <- cbind(df, as.data.frame(aware_cols), stringsAsFactors = FALSE)
  df <- cbind(df, as.data.frame(wom_list),   stringsAsFactors = FALSE)
  df <- cbind(df, as.data.frame(reach_list), stringsAsFactors = FALSE)
  df <- cbind(df, as.data.frame(dba_list),   stringsAsFactors = FALSE)
  df <- cbind(df, demo, stringsAsFactors = FALSE)
  df
}

# ---- Generate all 4 focal blocks -------------------------------------------
cat("Generating 1,200 synthetic respondents...\n")
block_dss <- make_focal_block("DSS", 1)
block_pos <- make_focal_block("POS", N_PER_CAT + 1)
block_pas <- make_focal_block("PAS", N_PER_CAT * 2 + 1)
block_bak <- make_focal_block("BAK", N_PER_CAT * 3 + 1)

# ---- Align all blocks to same column set -----------------------------------
all_cols <- unique(c(names(block_dss), names(block_pos),
                     names(block_pas), names(block_bak)))

align_block <- function(df, all_cols) {
  missing_cols <- setdiff(all_cols, names(df))
  for (col in missing_cols) {
    df[[col]] <- NA
  }
  df[, all_cols]
}

block_dss <- align_block(block_dss, all_cols)
block_pos <- align_block(block_pos, all_cols)
block_pas <- align_block(block_pas, all_cols)
block_bak <- align_block(block_bak, all_cols)

dat <- rbind(block_dss, block_pos, block_pas, block_bak)
cat(sprintf("Final dataset: %d rows x %d columns\n", nrow(dat), ncol(dat)))

# ---- Reorder columns to match original file order --------------------------
original_path <- sub("ipk_9cat_wave1.xlsx", "ipk_9cat_wave1.xlsx", OUT_PATH)
if (file.exists(original_path)) {
  orig <- read.xlsx(original_path, sheet = 1, rows = 1)
  orig_cols <- names(orig)
  matched   <- intersect(orig_cols, names(dat))
  extra     <- setdiff(names(dat), orig_cols)
  dat <- dat[, c(matched, extra)]
  cat(sprintf("Columns matched to original: %d matched, %d new\n",
              length(matched), length(extra)))
}

# ---- Write to Excel --------------------------------------------------------
cat(sprintf("Writing to: %s\n", OUT_PATH))
wb <- createWorkbook()
addWorksheet(wb, "Data")
writeData(wb, "Data", dat)
saveWorkbook(wb, OUT_PATH, overwrite = TRUE)
cat("Done.\n")
