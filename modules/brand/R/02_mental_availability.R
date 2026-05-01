# SIZE-EXCEPTION: Main MA orchestrator. Holds five sequential sections
# (linkage construction, MMS/MPen/NS, CEP x brand matrix, CEP penetration,
# main entry point) that read as one analytical pipeline. Splitting would
# fragment a coherent flow and force callers to source many small files.
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

#' Build CEP (or attribute) linkage from v2 role registry + slot-indexed data
#'
#' v2 alternative to \code{build_cep_linkage()}. Reads the role map for
#' \code{mental_avail.{kind}.{cat_code}.{ITEM}} entries (where kind is "cep"
#' or "attr") and uses \code{multi_mention_brand_matrix()} from the
#' data-access layer to build the linkage tensor from slot-indexed columns.
#'
#' Returns the same list shape as \code{build_cep_linkage()} so
#' \code{run_mental_availability()} consumes either output identically.
#'
#' @param data Data frame. Survey data (one row per respondent).
#' @param role_map Named list from \code{build_brand_role_map()}.
#' @param cat_code Character. Category code (e.g. "DSS").
#' @param brands Data frame with BrandCode column. Order defines tensor
#'   column order.
#' @param item_kind Character. "cep" (default) for CEPs, "attr" for
#'   attribute statements. Determines which role-map entries are used:
#'   \code{mental_avail.cep.{CAT}.*} or \code{mental_avail.attr.{CAT}.*}.
#'
#' @return List with the same fields as \code{build_cep_linkage()}:
#'   linkage_tensor, respondent_cep_matrix (named cep_codes for both kinds
#'   for downstream compatibility), brand_codes, cep_codes, n_respondents.
#'
#' @export
build_cep_linkage <- function(data, role_map, cat_code, brands,
                                 item_kind = "cep") {
  if (!item_kind %in% c("cep", "attr")) {
    cat(sprintf(
      "\n=== TURAS BRAND ERROR ===\n[DATA_MA_INVALID_ITEM_KIND] build_cep_linkage: item_kind must be 'cep' or 'attr', got '%s'\nHow to fix: Pass item_kind = 'cep' for CEP linkage or item_kind = 'attr' for brand attribute linkage.\n=========================\n\n",
      item_kind
    ))
    return(NULL)
  }
  brand_codes <- as.character(brands$BrandCode)
  n_resp <- nrow(data)

  # Walk role map for matching items
  role_prefix <- paste0("mental_avail.", item_kind, ".", cat_code, ".")
  matching_roles <- grep(paste0("^", .ma_regex_escape(role_prefix)),
                         names(role_map), value = TRUE)
  item_codes <- sub(.ma_regex_escape(role_prefix), "", matching_roles)

  # Sort by trailing item-number suffix so CEP01 < CEP02 < ... in the output
  item_codes <- item_codes[order(item_codes)]
  matching_roles <- paste0(role_prefix, item_codes)

  # Build linkage tensor: one matrix per brand [resp x items]
  linkage_tensor <- list()
  for (b in brand_codes) {
    linkage_tensor[[b]] <- matrix(0L, nrow = n_resp, ncol = length(item_codes),
                                  dimnames = list(NULL, item_codes))
  }

  for (j in seq_along(item_codes)) {
    role <- matching_roles[j]
    entry <- role_map[[role]]
    if (is.null(entry) || is.null(entry$column_root)) next
    # multi_mention_brand_matrix returns logical; coerce to integer
    brand_mat <- multi_mention_brand_matrix(data, entry$column_root,
                                            brand_codes)
    for (b in brand_codes) {
      linkage_tensor[[b]][, j] <- as.integer(brand_mat[, b])
    }
  }

  # Respondent x item matrix: 1 if any brand linked
  resp_item_mat <- matrix(0L, nrow = n_resp, ncol = length(item_codes),
                          dimnames = list(NULL, item_codes))
  for (b in brand_codes) {
    resp_item_mat <- pmax(resp_item_mat, linkage_tensor[[b]])
  }

  list(
    linkage_tensor        = linkage_tensor,
    respondent_cep_matrix = resp_item_mat,
    brand_codes           = brand_codes,
    cep_codes             = item_codes,  # named cep_codes for back-compat
    n_respondents         = n_resp
  )
}


#' Regex-escape helper for build_cep_linkage
#' @keywords internal
.ma_regex_escape <- function(s) {
  gsub("([\\.\\+\\*\\?\\(\\)\\[\\]\\{\\}\\|\\^\\$])",
       "\\\\\\1", s, perl = TRUE)
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
#' @param attribute_linkage Optional list from
#'   \code{build_cep_linkage_from_matrix()} treating attribute codes as
#'   stimuli. When supplied, \code{run_mental_availability()} additionally
#'   computes an attribute x brand matrix (see §Brand Attributes).
#' @param attribute_labels Data frame with AttrCode + AttrText columns.
#'   Used to look up display text for attribute rows.
#'
#' @export
run_mental_availability <- function(linkage, cep_labels = NULL,
                                    focal_brand = NULL,
                                    weights = NULL,
                                    run_cep_turf = TRUE,
                                    turf_max_items = 10,
                                    attribute_linkage = NULL,
                                    attribute_labels = NULL) {

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

  # --- Brand image attribute matrix (optional) ---
  attr_matrix  <- NULL
  attr_labels_out <- NULL
  n_attrs <- 0L
  if (!is.null(attribute_linkage) &&
      length(attribute_linkage$linkage_tensor) > 0) {
    attr_codes <- attribute_linkage$cep_codes  # (reused field name)
    # Align tensor's brand order to the CEP brand order where possible so
    # both matrices share the same column layout.
    brand_order <- brand_codes
    if (!setequal(names(attribute_linkage$linkage_tensor), brand_order)) {
      warnings <- c(warnings,
        "Attribute matrix brand set differs from CEP matrix; rendering on intersection")
      brand_order <- intersect(brand_order,
                                names(attribute_linkage$linkage_tensor))
      attribute_linkage$linkage_tensor <-
        attribute_linkage$linkage_tensor[brand_order]
    } else {
      attribute_linkage$linkage_tensor <-
        attribute_linkage$linkage_tensor[brand_order]
    }
    attr_matrix <- calculate_cep_brand_matrix(
      attribute_linkage$linkage_tensor, attr_codes, weights
    )
    # Rename the first column from CEPCode to AttrCode for clarity
    names(attr_matrix)[1] <- "AttrCode"
    attr_labels_out <- if (!is.null(attribute_labels) &&
                           "AttrText" %in% names(attribute_labels)) {
      data.frame(
        AttrCode = attr_codes,
        AttrText = attribute_labels$AttrText[
          match(attr_codes, attribute_labels$AttrCode)],
        stringsAsFactors = FALSE
      )
    } else {
      data.frame(AttrCode = attr_codes, AttrText = attr_codes,
                 stringsAsFactors = FALSE)
    }
    n_attrs <- length(attr_codes)
  }

  # --- Mental Advantage (Romaniuk) — runs whenever calculate_mental_advantage
  # is loaded. Failures degrade to NULL so the rest of the panel survives.
  cep_advantage <- .ma_safe_advantage(
    linkage$linkage_tensor, cep_codes, weights, n_resp,
    label = "CEP", warnings_acc = function(msg) warnings <<- c(warnings, msg))

  attribute_advantage <- if (!is.null(attribute_linkage) &&
                              length(attribute_linkage$linkage_tensor) > 0) {
    .ma_safe_advantage(
      attribute_linkage$linkage_tensor,
      attribute_linkage$cep_codes,
      weights, n_resp,
      label = "attribute",
      warnings_acc = function(msg) warnings <<- c(warnings, msg))
  } else NULL

  status <- if (length(warnings) > 0) "PARTIAL" else "PASS"

  list(
    status = status,
    mms = mms,
    mpen = mpen,
    ns = ns,
    cep_brand_matrix = cep_matrix,
    cep_penetration = cep_pen,
    cep_turf = cep_turf,
    cep_advantage = cep_advantage,
    attribute_brand_matrix = attr_matrix,
    attribute_labels = attr_labels_out,
    attribute_advantage = attribute_advantage,
    metrics_summary = metrics_summary,
    warnings = warnings,
    n_respondents = n_resp,
    n_ceps = length(cep_codes),
    n_attrs = n_attrs,
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
