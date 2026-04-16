# ==============================================================================
# BRAND MODULE - MENTAL AVAILABILITY ELEMENT
# ==============================================================================
# Computes Romaniuk/EBI Mental Availability metrics:
#   - MMS (Mental Market Share): brand's share of all brand-CEP links
#   - MPen (Mental Penetration): % of category buyers linking brand to >= 1 CEP
#   - NS (Network Size): avg CEPs linked per buyer (among linkers)
#   - CEP x brand matrix: linkage percentages
#   - CEP TURF: optimal CEP combination for maximum mental reach
#   - Brand image attributes (non-CEP statements, separate sub-view)
#
# VERSION: 1.0
#
# REFERENCES:
#   Romaniuk, J. & Sharp, B. (2016). How Brands Grow Part 2.
#   Romaniuk, J. (2022). Better Brand Health. (CBM framework)
#
# DEPENDENCIES:
#   - modules/shared/lib/turf_engine.R (for CEP TURF)
# ==============================================================================

MENTAL_AVAIL_VERSION <- "1.0"


# ==============================================================================
# SECTION 1: CEP LINKAGE MATRIX CONSTRUCTION
# ==============================================================================

#' Build the CEP-brand linkage matrix from survey data
#'
#' Constructs a respondent x CEP x brand tensor from Multi_Mention survey
#' data. Each cell is 1 if the respondent linked the brand to the CEP,
#' 0 otherwise.
#'
#' @param data Data frame. Survey data.
#' @param ceps Data frame. CEP definitions with CEPCode column.
#' @param brands Data frame. Brand definitions with BrandCode column.
#' @param questions Data frame. Question definitions mapping CEP codes to
#'   column prefixes in the data.
#' @param category Character. Category name to filter.
#'
#' @return List with:
#'   \item{linkage_tensor}{Named list of matrices. One per brand.
#'     Each matrix is n_respondents x n_ceps (binary 0/1).}
#'   \item{respondent_cep_matrix}{Matrix n_respondents x n_ceps. Cell = 1
#'     if respondent linked ANY brand to this CEP.}
#'   \item{brand_codes}{Character vector of brand codes.}
#'   \item{cep_codes}{Character vector of CEP codes.}
#'   \item{n_respondents}{Integer.}
#'
#' @keywords internal
build_cep_linkage <- function(data, ceps, brands, questions, category) {

  cep_codes <- ceps$CEPCode
  brand_codes <- brands$BrandCode
  n_resp <- nrow(data)
  n_ceps <- length(cep_codes)
  n_brands <- length(brand_codes)

  # Build linkage tensor: list of brand matrices
  linkage_tensor <- list()
  for (brand in brand_codes) {
    brand_mat <- matrix(0L, nrow = n_resp, ncol = n_ceps)
    colnames(brand_mat) <- cep_codes

    for (j in seq_along(cep_codes)) {
      cep <- cep_codes[j]
      # Find the question code for this CEP
      q_row <- questions[questions$Battery == "cep_matrix" &
                         questions$Category == category, , drop = FALSE]
      if (nrow(q_row) == 0) next

      # Try column patterns: QCODE_BRAND or QCODE.BRAND
      for (qcode in q_row$QuestionCode) {
        col_candidates <- c(
          paste0(qcode, "_", brand),
          paste0(qcode, ".", brand),
          paste0(qcode, "_", brand_codes[match(brand, brand_codes)])
        )
        col_match <- intersect(col_candidates, names(data))
        if (length(col_match) > 0) {
          vals <- data[[col_match[1]]]
          brand_mat[, j] <- as.integer(!is.na(vals) & vals == 1)
          break
        }
      }
    }
    linkage_tensor[[brand]] <- brand_mat
  }

  # Respondent-level CEP reach matrix (any brand linked = 1)
  resp_cep_mat <- matrix(0L, nrow = n_resp, ncol = n_ceps)
  colnames(resp_cep_mat) <- cep_codes
  for (j in seq_len(n_ceps)) {
    any_linked <- rep(0L, n_resp)
    for (brand in brand_codes) {
      any_linked <- pmax(any_linked, linkage_tensor[[brand]][, j])
    }
    resp_cep_mat[, j] <- any_linked
  }

  list(
    linkage_tensor = linkage_tensor,
    respondent_cep_matrix = resp_cep_mat,
    brand_codes = brand_codes,
    cep_codes = cep_codes,
    n_respondents = n_resp
  )
}


#' Build CEP linkage from a pre-shaped matrix
#'
#' Alternative constructor when data is already in a clean
#' respondent x (brand-CEP) format. Each column is named
#' "CEPCode_BrandCode" with binary 0/1 values.
#'
#' @param data Data frame. Each column is CEPCode_BrandCode.
#' @param cep_codes Character vector. CEP codes.
#' @param brand_codes Character vector. Brand codes.
#'
#' @return Same structure as \code{build_cep_linkage()}.
#'
#' @keywords internal
build_cep_linkage_from_matrix <- function(data, cep_codes, brand_codes) {

  n_resp <- nrow(data)
  n_ceps <- length(cep_codes)

  linkage_tensor <- list()
  for (brand in brand_codes) {
    brand_mat <- matrix(0L, nrow = n_resp, ncol = n_ceps)
    colnames(brand_mat) <- cep_codes

    for (j in seq_along(cep_codes)) {
      col_name <- paste0(cep_codes[j], "_", brand)
      if (col_name %in% names(data)) {
        vals <- data[[col_name]]
        brand_mat[, j] <- as.integer(!is.na(vals) & vals > 0)
      }
    }
    linkage_tensor[[brand]] <- brand_mat
  }

  resp_cep_mat <- matrix(0L, nrow = n_resp, ncol = n_ceps)
  colnames(resp_cep_mat) <- cep_codes
  for (j in seq_len(n_ceps)) {
    any_linked <- rep(0L, n_resp)
    for (brand in brand_codes) {
      any_linked <- pmax(any_linked, linkage_tensor[[brand]][, j])
    }
    resp_cep_mat[, j] <- any_linked
  }

  list(
    linkage_tensor = linkage_tensor,
    respondent_cep_matrix = resp_cep_mat,
    brand_codes = brand_codes,
    cep_codes = cep_codes,
    n_respondents = n_resp
  )
}


# ==============================================================================
# SECTION 2: HEADLINE METRICS (MMS, MPen, NS)
# ==============================================================================

#' Calculate Mental Market Share for all brands
#'
#' MMS = brand's total CEP links / all brands' total CEP links.
#' The headline mental availability metric.
#'
#' @param linkage_tensor Named list of brand matrices from
#'   \code{build_cep_linkage()}.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return Data frame with BrandCode and MMS columns.
#'
#' @export
calculate_mms <- function(linkage_tensor, weights = NULL) {

  brand_codes <- names(linkage_tensor)
  n_brands <- length(brand_codes)

  # Total links per brand
  brand_totals <- numeric(n_brands)
  names(brand_totals) <- brand_codes

  for (i in seq_along(brand_codes)) {
    brand_mat <- linkage_tensor[[brand_codes[i]]]
    if (is.null(weights)) {
      brand_totals[i] <- sum(brand_mat, na.rm = TRUE)
    } else {
      # Weighted: sum of (weight * links per respondent)
      brand_totals[i] <- sum(weights * rowSums(brand_mat, na.rm = TRUE))
    }
  }

  total_links <- sum(brand_totals)
  mms <- if (total_links > 0) brand_totals / total_links else rep(0, n_brands)

  data.frame(
    BrandCode = brand_codes,
    MMS = round(mms, 4),
    Total_Links = brand_totals,
    stringsAsFactors = FALSE
  )
}


#' Calculate Mental Penetration for all brands
#'
#' MPen = % of category buyers who link the brand to at least one CEP.
#' Measures the brand's mental reach.
#'
#' @param linkage_tensor Named list of brand matrices.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return Data frame with BrandCode and MPen columns.
#'
#' @export
calculate_mpen <- function(linkage_tensor, weights = NULL) {

  brand_codes <- names(linkage_tensor)
  n_brands <- length(brand_codes)
  n_resp <- nrow(linkage_tensor[[1]])

  mpen <- numeric(n_brands)
  names(mpen) <- brand_codes

  for (i in seq_along(brand_codes)) {
    brand_mat <- linkage_tensor[[brand_codes[i]]]
    # Respondent links brand to >= 1 CEP
    linked_any <- rowSums(brand_mat, na.rm = TRUE) > 0

    if (is.null(weights)) {
      mpen[i] <- mean(linked_any)
    } else {
      mpen[i] <- sum(weights * linked_any) / sum(weights)
    }
  }

  data.frame(
    BrandCode = brand_codes,
    MPen = round(mpen, 4),
    stringsAsFactors = FALSE
  )
}


#' Calculate Network Size for all brands
#'
#' NS = average number of CEPs linked to the brand, among respondents
#' who link at least one CEP. Measures the brand's mental depth.
#'
#' @param linkage_tensor Named list of brand matrices.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return Data frame with BrandCode, NS (mean), and NS_Base (n linking >=1).
#'
#' @export
calculate_ns <- function(linkage_tensor, weights = NULL) {

  brand_codes <- names(linkage_tensor)
  n_brands <- length(brand_codes)

  ns <- numeric(n_brands)
  ns_base <- integer(n_brands)
  names(ns) <- brand_codes

  for (i in seq_along(brand_codes)) {
    brand_mat <- linkage_tensor[[brand_codes[i]]]
    links_per_resp <- rowSums(brand_mat, na.rm = TRUE)
    linkers <- links_per_resp > 0

    ns_base[i] <- sum(linkers)

    if (sum(linkers) == 0) {
      ns[i] <- 0
    } else if (is.null(weights)) {
      ns[i] <- mean(links_per_resp[linkers])
    } else {
      linker_weights <- weights[linkers]
      ns[i] <- sum(linker_weights * links_per_resp[linkers]) /
               sum(linker_weights)
    }
  }

  data.frame(
    BrandCode = brand_codes,
    NS = round(ns, 2),
    NS_Base = ns_base,
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# SECTION 3: CEP x BRAND MATRIX
# ==============================================================================

#' Calculate CEP x brand linkage percentages
#'
#' For each CEP, what percentage of category buyers link it to each brand.
#' This is the raw association data — the richest analytical asset.
#'
#' @param linkage_tensor Named list of brand matrices.
#' @param cep_codes Character vector. CEP codes.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return Data frame with CEPCode rows and BrandCode columns. Values are
#'   linkage percentages (0-100).
#'
#' @export
calculate_cep_brand_matrix <- function(linkage_tensor, cep_codes,
                                        weights = NULL) {

  brand_codes <- names(linkage_tensor)
  n_ceps <- length(cep_codes)
  n_brands <- length(brand_codes)
  n_resp <- nrow(linkage_tensor[[1]])

  result <- matrix(0, nrow = n_ceps, ncol = n_brands)
  colnames(result) <- brand_codes
  rownames(result) <- cep_codes

  for (b in seq_along(brand_codes)) {
    brand_mat <- linkage_tensor[[brand_codes[b]]]
    for (c in seq_len(n_ceps)) {
      linked <- brand_mat[, c]
      if (is.null(weights)) {
        result[c, b] <- mean(linked, na.rm = TRUE) * 100
      } else {
        result[c, b] <- sum(weights * linked, na.rm = TRUE) /
                         sum(weights) * 100
      }
    }
  }

  # Convert to data frame with CEPCode column
  result_df <- as.data.frame(round(result, 1))
  result_df$CEPCode <- cep_codes
  result_df <- result_df[, c("CEPCode", brand_codes), drop = FALSE]

  result_df
}


# ==============================================================================
# SECTION 4: CEP PENETRATION RANKING
# ==============================================================================

#' Calculate CEP penetration across all brands
#'
#' For each CEP, what percentage of category buyers link ANY brand to it.
#' Ranks CEPs by total category-level linkage.
#'
#' @param respondent_cep_matrix Matrix from \code{build_cep_linkage()}.
#' @param cep_codes Character vector.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return Data frame with CEPCode, Penetration_Pct, and Rank.
#'
#' @export
calculate_cep_penetration <- function(respondent_cep_matrix, cep_codes,
                                       weights = NULL) {

  n_ceps <- length(cep_codes)
  penetration <- numeric(n_ceps)

  for (j in seq_len(n_ceps)) {
    linked <- respondent_cep_matrix[, j]
    if (is.null(weights)) {
      penetration[j] <- mean(linked, na.rm = TRUE) * 100
    } else {
      penetration[j] <- sum(weights * linked, na.rm = TRUE) /
                         sum(weights) * 100
    }
  }

  result <- data.frame(
    CEPCode = cep_codes,
    Penetration_Pct = round(penetration, 1),
    stringsAsFactors = FALSE
  )

  result <- result[order(-result$Penetration_Pct), , drop = FALSE]
  result$Rank <- seq_len(nrow(result))
  rownames(result) <- NULL

  result
}


# ==============================================================================
# SECTION 5: MAIN ENTRY POINT
# ==============================================================================

#' Run Mental Availability analysis for a category
#'
#' Computes all Mental Availability metrics for a single category:
#' MMS, MPen, NS, CEP x brand matrix, CEP penetration, and optionally
#' CEP TURF.
#'
#' @param linkage Named list from \code{build_cep_linkage()} or
#'   \code{build_cep_linkage_from_matrix()}.
#' @param cep_labels Data frame with CEPCode and CEPText columns.
#' @param focal_brand Character. Focal brand code.
#' @param weights Numeric vector. Respondent weights (optional).
#' @param run_cep_turf Logical. Run CEP TURF analysis (default: TRUE).
#' @param turf_max_items Integer. Maximum CEPs for TURF (default: 10).
#'
#' @return List with:
#'   \item{status}{"PASS" or "PARTIAL"}
#'   \item{mms}{Data frame: BrandCode, MMS, Total_Links}
#'   \item{mpen}{Data frame: BrandCode, MPen}
#'   \item{ns}{Data frame: BrandCode, NS, NS_Base}
#'   \item{cep_brand_matrix}{Data frame: CEPCode x brands (linkage %)}
#'   \item{cep_penetration}{Data frame: CEPCode, Penetration_Pct, Rank}
#'   \item{cep_turf}{TURF result (if run_cep_turf = TRUE)}
#'   \item{metrics_summary}{Named list of key metrics for AI annotations}
#'   \item{n_respondents}{Integer}
#'   \item{n_ceps}{Integer}
#'   \item{n_brands}{Integer}
#'
#' @export
run_mental_availability <- function(linkage, cep_labels = NULL,
                                    focal_brand = NULL,
                                    weights = NULL,
                                    run_cep_turf = TRUE,
                                    turf_max_items = 10) {

  warnings <- character(0)

  # Validate inputs
  if (is.null(linkage) || length(linkage$linkage_tensor) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_NO_LINKAGE",
      message = "No CEP linkage data available for Mental Availability analysis"
    ))
  }

  brand_codes <- linkage$brand_codes
  cep_codes <- linkage$cep_codes
  n_resp <- linkage$n_respondents

  # Compute headline metrics
  mms <- calculate_mms(linkage$linkage_tensor, weights)
  mpen <- calculate_mpen(linkage$linkage_tensor, weights)
  ns <- calculate_ns(linkage$linkage_tensor, weights)

  # CEP x brand matrix
  cep_matrix <- calculate_cep_brand_matrix(
    linkage$linkage_tensor, cep_codes, weights
  )

  # CEP penetration ranking
  cep_pen <- calculate_cep_penetration(
    linkage$respondent_cep_matrix, cep_codes, weights
  )

  # CEP TURF
  cep_turf <- NULL
  if (isTRUE(run_cep_turf)) {
    # Prepare items data frame for TURF engine
    turf_items <- data.frame(
      Item_ID = cep_codes,
      Item_Label = if (!is.null(cep_labels) && "CEPText" %in% names(cep_labels)) {
        cep_labels$CEPText[match(cep_codes, cep_labels$CEPCode)]
      } else {
        cep_codes
      },
      stringsAsFactors = FALSE
    )

    # Source TURF engine if not loaded
    if (!exists("turf_from_binary", mode = "function")) {
      turf_path <- NULL
      if (exists("find_turas_root", mode = "function")) {
        turf_path <- file.path(find_turas_root(), "modules", "shared",
                               "lib", "turf_engine.R")
      }
      if (!is.null(turf_path) && file.exists(turf_path)) {
        source(turf_path, local = FALSE)
      }
    }

    if (exists("turf_from_binary", mode = "function")) {
      cep_turf <- tryCatch(
        turf_from_binary(
          binary_matrix = linkage$respondent_cep_matrix,
          items = turf_items,
          max_items = min(turf_max_items, length(cep_codes)),
          weights = weights,
          verbose = FALSE
        ),
        error = function(e) {
          warnings <<- c(warnings, sprintf("CEP TURF failed: %s", e$message))
          NULL
        }
      )
    } else {
      warnings <- c(warnings, "CEP TURF skipped: TURF engine not available")
    }
  }

  # Build metrics summary (for AI annotations and exec summary)
  focal_mms <- if (!is.null(focal_brand) && focal_brand %in% mms$BrandCode) {
    mms$MMS[mms$BrandCode == focal_brand]
  } else NA_real_

  focal_mpen <- if (!is.null(focal_brand) && focal_brand %in% mpen$BrandCode) {
    mpen$MPen[mpen$BrandCode == focal_brand]
  } else NA_real_

  focal_ns <- if (!is.null(focal_brand) && focal_brand %in% ns$BrandCode) {
    ns$NS[ns$BrandCode == focal_brand]
  } else NA_real_

  mms_leader <- mms$BrandCode[which.max(mms$MMS)]
  mms_leader_val <- max(mms$MMS)

  metrics_summary <- list(
    focal_brand = focal_brand,
    focal_mms = focal_mms,
    focal_mpen = focal_mpen,
    focal_ns = focal_ns,
    mms_leader = mms_leader,
    mms_leader_val = mms_leader_val,
    mms_rank = if (!is.na(focal_mms)) {
      which(order(-mms$MMS) == which(mms$BrandCode == focal_brand))
    } else NA_integer_,
    n_brands = length(brand_codes),
    n_ceps = length(cep_codes),
    n_respondents = n_resp,
    top_cep = cep_pen$CEPCode[1],
    top_cep_pen = cep_pen$Penetration_Pct[1],
    cep_turf_reach_5 = if (!is.null(cep_turf) && nrow(cep_turf$incremental_table) >= 5) {
      cep_turf$incremental_table$Reach_Pct[5]
    } else NA_real_
  )

  status <- if (length(warnings) > 0) "PARTIAL" else "PASS"

  list(
    status = status,
    mms = mms,
    mpen = mpen,
    ns = ns,
    cep_brand_matrix = cep_matrix,
    cep_penetration = cep_pen,
    cep_turf = cep_turf,
    metrics_summary = metrics_summary,
    warnings = warnings,
    n_respondents = n_resp,
    n_ceps = length(cep_codes),
    n_brands = length(brand_codes)
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Mental Availability element loaded (v%s)",
                  MENTAL_AVAIL_VERSION))
}
