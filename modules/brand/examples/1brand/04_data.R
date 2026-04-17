# ==============================================================================
# 1BRAND SYNTHETIC EXAMPLE - DATA GENERATION ORCHESTRATOR
# ==============================================================================
# Assembles the full synthetic respondent-level CSV:
#   300 respondents x ~320 columns
#   Fully-reproducible via withr::with_seed()
#
# File sequencing (mandatory order — later steps depend on earlier columns):
#   1. Core: ID, weight, demographics, category buying
#   2. Awareness (per brand)
#   3. Attitude (conditional on awareness)
#   4. Penetration (conditional on attitude)
#   5. CEP matrix (conditional on awareness)
#   6. Attribute matrix (conditional on awareness)
#   7. WOM (brand-level; some elements conditional on attitude)
#   8. DBA (brand-level fame + uniqueness)
# ==============================================================================


# ==============================================================================
# MAIN GENERATOR
# ==============================================================================

#' Generate the synthetic respondent-level CSV
#'
#' Produces a fully-reproducible dataset matching the CBM data shape defined
#' by the Survey_Structure.xlsx written by generate_1brand_structure().
#'
#' @param output_path Character. Destination path for the CSV.
#' @param n Integer. Number of respondents (default 300).
#' @param seed Integer. RNG seed (default 42).
#' @return Invisibly returns the path to the written CSV.
#' @export
generate_1brand_data <- function(output_path, n = 300, seed = 42) {

  if (!requireNamespace("withr", quietly = TRUE)) {
    rlang::abort("Package 'withr' is required for reproducible RNG",
                 class = "pkg_missing")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  df <- withr::with_seed(seed, {
    d <- build_respondent_core(n)
    d <- add_demographics(d)
    d <- add_category_buying(d)
    d <- add_awareness(d)
    d <- add_attitude(d)
    d <- add_penetration(d)
    d <- add_cep_matrix(d)
    d <- add_attribute_matrix(d)
    d <- add_wom(d)
    d <- add_dba(d)
    d
  })

  # Order columns for readability
  df <- .order_columns(df)

  # Write with data.table for speed
  if (requireNamespace("data.table", quietly = TRUE)) {
    data.table::fwrite(df, output_path)
  } else {
    utils::write.csv(df, output_path, row.names = FALSE)
  }

  cat(sprintf("  + Data CSV -> %s (%d rows, %d cols)\n",
              output_path, nrow(df), ncol(df)))
  invisible(output_path)
}


# ==============================================================================
# COLUMN ORDERING
# ==============================================================================

#' Reorder columns into logical groups for readability
#'
#' Order:
#'   Identification / weight / category / qualifier / demographics / catbuy
#'   Awareness (one per brand)
#'   Attitude + rejection OE (one pair per brand)
#'   Penetration (3 questions x each brand)
#'   CEP matrix (15 CEPs x 10 brands)
#'   Attribute matrix (5 attrs x 10 brands)
#'   WOM (4 per-brand + 2 overall)
#'   DBA (fame + unique per asset)
#'
#' @keywords internal
.order_columns <- function(df) {

  cat_code <- ipk_category()$code
  brand_codes <- ipk_brand_codes()
  cep_codes   <- ipk_cep_codes()
  attr_codes  <- ipk_attribute_codes()
  dba_codes   <- ipk_dba_codes()

  # Group 1: core
  group_core <- c("Respondent_ID", "Weight", "Focal_Category", "Qualified_DSS",
                  "Age_Group", "Gender", "Income_Group", "LSM_Group", "Region",
                  sprintf("CATBUY_%s", cat_code))

  # Group 2: awareness (brand-ordered)
  group_aware <- sprintf("BRANDAWARE_%s_%s", cat_code, brand_codes)

  # Group 3: attitude (att1 then att2 for each brand)
  group_att <- as.vector(rbind(
    sprintf("BRANDATT1_%s_%s", cat_code, brand_codes),
    sprintf("BRANDATT2_%s_%s", cat_code, brand_codes)
  ))

  # Group 4: penetration
  group_pen <- c(
    sprintf("BRANDPEN1_%s_%s", cat_code, brand_codes),
    sprintf("BRANDPEN2_%s_%s", cat_code, brand_codes),
    sprintf("BRANDPEN3_%s_%s", cat_code, brand_codes)
  )

  # Group 5: CEP matrix (CEP-major: all brands for CEP01, then all for CEP02, ...)
  group_cep <- as.vector(outer(cep_codes, brand_codes,
                                FUN = function(c, b) paste0(c, "_", b)))

  # Group 6: Attribute matrix (same pattern)
  group_attr <- as.vector(outer(attr_codes, brand_codes,
                                 FUN = function(a, b) paste0(a, "_", b)))

  # Group 7: WOM
  group_wom <- c(
    sprintf("WOM_POS_REC_%s",   brand_codes),
    sprintf("WOM_NEG_REC_%s",   brand_codes),
    sprintf("WOM_POS_SHARE_%s", brand_codes),
    sprintf("WOM_NEG_SHARE_%s", brand_codes),
    "WOM_POS_FREQ", "WOM_NEG_FREQ"
  )

  # Group 8: DBA
  group_dba <- as.vector(rbind(
    sprintf("DBA_FAME_%s",   dba_codes),
    sprintf("DBA_UNIQUE_%s", dba_codes)
  ))

  ordered <- c(group_core, group_aware, group_att, group_pen,
               group_cep, group_attr, group_wom, group_dba)

  # Sanity check — every generated column should be in the ordered list
  missing_cols <- setdiff(names(df), ordered)
  if (length(missing_cols) > 0) {
    warning(sprintf("Columns not in ordering plan: %s",
                    paste(missing_cols, collapse = ", ")))
    ordered <- c(ordered, missing_cols)
  }
  extra_cols <- setdiff(ordered, names(df))
  if (length(extra_cols) > 0) {
    warning(sprintf("Ordering plan references non-existent columns: %s",
                    paste(extra_cols, collapse = ", ")))
    ordered <- intersect(ordered, names(df))
  }

  df[, ordered, drop = FALSE]
}
