# ==============================================================================
# BRAND MODULE - COMPETITIVE CONSTELLATION (§4.2)
# ==============================================================================
# Produces the co-awareness network:
#   nodes: one per brand, sized by total aware respondents
#   edges: Jaccard similarity on any-category co-awareness, weighted
#   layout: Fruchterman-Reingold pure-R (or igraph if present)
#
# SIZE-EXCEPTION: sequential FR + Jaccard pipeline; decomposing into smaller
# functions would fragment the coherent compute → layout → output flow.
# Active line count is driven by the FR inner loop, not incidental complexity.
# Denominator: build_portfolio_base() per §3.1 — never inline SQ1_/SQ2_.
# ==============================================================================

CONSTELLATION_MIN_BRANDS <- 3L

CONSTELLATION_LAYOUT_TURAS <- "Turas pure-R Fruchterman-Reingold"
CONSTELLATION_LAYOUT_IGRAPH <- "igraph Fruchterman-Reingold"


# ==============================================================================
# Per-category co-awareness constellation
# ==============================================================================

#' Compute co-awareness constellation for ONE category
#'
#' Builds a Jaccard co-awareness network restricted to the brands in a single
#' category, with Jaccard computed across that category's buyers (the screener-
#' qualified base). This is the analytic shape Duncan needs to answer
#' "who do my buyers compete with in THIS category?" — pooling across the
#' entire brand universe (as the cross-category constellation does) buries
#' the answer because private-label brand codes from different categories
#' end up as separate nodes that share no co-awareness with anything.
#'
#' @param data Data frame. Full survey data.
#' @param cat_code Character. Category code (e.g. "DSS").
#' @param cat_brands Data frame. Brands declared for this category (must
#'   include BrandCode; BrandLabel optional).
#' @param base_idx Logical vector. Category-buyer mask from
#'   build_portfolio_base().
#' @param weights Numeric vector. Survey weights aligned to data rows.
#' @param focal_brand Character. Focal brand code.
#' @param cooccur_min Integer. Minimum unweighted co-occurrence count to
#'   keep an edge.
#' @param edge_top_n Integer. Cap on number of edges retained.
#' @return List with status, nodes, edges, layout, layout_engine.
#'   status="REFUSED" with TRS-style code when fewer than
#'   CONSTELLATION_MIN_BRANDS brands have aware buyers.
#' @keywords internal
.compute_constellation_for_cat <- function(data, cat_code, cat_brands,
                                            base_idx, weights,
                                            focal_brand,
                                            cooccur_min, edge_top_n) {
  brand_codes <- as.character(cat_brands$BrandCode)
  brand_lbls  <- if ("BrandLabel" %in% names(cat_brands))
                   as.character(cat_brands$BrandLabel)
                 else if ("BrandName" %in% names(cat_brands))
                   as.character(cat_brands$BrandName)
                 else brand_codes
  names(brand_lbls) <- brand_codes

  # Build per-buyer awareness matrix for the brands in this category.
  n     <- nrow(data)
  am    <- matrix(0L, n, length(brand_codes))
  colnames(am) <- brand_codes
  for (bc in brand_codes) {
    col <- paste0("BRANDAWARE_", cat_code, "_", bc)
    if (!col %in% names(data)) next
    am[, bc] <- as.integer(!is.na(data[[col]]) & data[[col]] == 1L)
  }

  # Restrict to category buyers. Co-awareness Jaccard is meaningful only
  # over the set of people who could plausibly be aware of these brands.
  am_buyers <- am[base_idx, , drop = FALSE]
  w_buyers  <- weights[base_idx]

  n_aware_w <- vapply(brand_codes, function(bc) {
    sum(w_buyers * am_buyers[, bc], na.rm = TRUE)
  }, numeric(1))
  present <- brand_codes[n_aware_w > 0]

  if (length(present) < CONSTELLATION_MIN_BRANDS) {
    return(list(
      status     = "REFUSED",
      code       = "CALC_CONSTELLATION_TOO_SPARSE",
      message    = sprintf(
        "Category '%s' has only %d brand(s) with aware buyers — need at least %d for a constellation.",
        cat_code, length(present), CONSTELLATION_MIN_BRANDS),
      n_aware    = setNames(as.numeric(n_aware_w), brand_codes)
    ))
  }

  pres_am <- am_buyers[, present, drop = FALSE]
  nb      <- length(present)

  edge_rows <- list()
  adj_mat   <- matrix(0.0, nb, nb)
  for (i in seq_len(nb - 1L)) {
    for (j in (i + 1L):nb) {
      both    <- pres_am[, i] * pres_am[, j]
      either  <- pmax(pres_am[, i], pres_am[, j])
      w_both  <- sum(w_buyers * both,   na.rm = TRUE)
      w_eith  <- sum(w_buyers * either, na.rm = TRUE)
      n_co    <- sum(both)
      if (n_co < cooccur_min || w_eith <= 0) next
      jac <- w_both / w_eith
      edge_rows[[length(edge_rows) + 1L]] <- list(
        b1 = present[i], b2 = present[j],
        jaccard = jac, cooccur_n = as.integer(n_co)
      )
      adj_mat[i, j] <- jac
      adj_mat[j, i] <- jac
    }
  }

  edges_df <- if (length(edge_rows) > 0) {
    df <- do.call(rbind, lapply(edge_rows, as.data.frame, stringsAsFactors = FALSE))
    df <- df[order(df$jaccard, decreasing = TRUE), ]
    head(df, edge_top_n)
  } else {
    data.frame(b1 = character(0), b2 = character(0),
               jaccard = numeric(0), cooccur_n = integer(0),
               stringsAsFactors = FALSE)
  }

  adj_top <- matrix(0.0, nb, nb)
  if (nrow(edges_df) > 0) {
    for (k in seq_len(nrow(edges_df))) {
      i <- which(present == edges_df$b1[k])
      j <- which(present == edges_df$b2[k])
      adj_top[i, j] <- edges_df$jaccard[k]
      adj_top[j, i] <- edges_df$jaccard[k]
    }
  }

  layout_engine <- CONSTELLATION_LAYOUT_TURAS
  pos <- if (requireNamespace("igraph", quietly = TRUE)) {
    tryCatch({
      g   <- igraph::graph_from_adjacency_matrix(adj_top, mode = "undirected",
                                                 weighted = TRUE)
      lyt <- igraph::layout_with_fr(g)
      layout_engine <- CONSTELLATION_LAYOUT_IGRAPH
      lyt
    }, error = function(e) .fr_layout_r(nb, adj_top))
  } else {
    .fr_layout_r(nb, adj_top)
  }

  nodes_df <- data.frame(
    brand     = present,
    brand_lbl = brand_lbls[present],
    n_aware_w = n_aware_w[present],
    is_focal  = present == focal_brand,
    stringsAsFactors = FALSE
  )
  layout_df <- data.frame(
    brand = present,
    x     = pos[, 1],
    y     = pos[, 2],
    stringsAsFactors = FALSE
  )

  list(
    status        = "PASS",
    nodes         = nodes_df,
    edges         = edges_df,
    layout        = layout_df,
    layout_engine = layout_engine
  )
}


#' Compute per-category constellations for the whole portfolio.
#'
#' Iterates every category in the config, builds a category buyer base,
#' computes the brand-vs-brand Jaccard network among those buyers, and
#' returns one entry per category. Categories that fail the screener
#' resolution, base-size threshold, or sparsity check are recorded in
#' `suppressed_cats` (with the reason) instead of being silently dropped.
#'
#' @param data Data frame. Full survey data.
#' @param categories Data frame. Categories sheet from config.
#' @param structure List. Loaded survey structure.
#' @param config List. Loaded brand config.
#' @param weights Numeric vector or NULL. Survey weights.
#'
#' @return List with:
#'   \item{status}{"PASS"}
#'   \item{by_cat}{Named list cat_code -> constellation result.}
#'   \item{cat_order}{Character. Ordered category codes (by buyer base size).}
#'   \item{cat_names}{Named character vector. cat_code -> display name.}
#'   \item{suppressed_cats}{Data frame: cat, reason.}
#' @export
compute_constellations_per_cat <- function(data, categories, structure,
                                            config, weights = NULL) {
  focal_brand <- config$focal_brand %||% ""
  timeframe   <- config$portfolio_timeframe %||% "3m"
  min_base    <- config$portfolio_min_base  %||% 30L
  cooccur_min <- config$portfolio_cooccur_min_pairs %||% 20L
  edge_top_n  <- config$portfolio_edge_top_n %||% PORTFOLIO_EDGE_TOP_N_DEFAULT
  n_total     <- nrow(data)
  w           <- if (!is.null(weights)) weights else rep(1.0, n_total)

  by_cat        <- list()
  cat_codes     <- character(0)
  cat_n         <- integer(0)
  cat_name_map  <- list()
  suppressed    <- list()

  for (i in seq_len(nrow(categories))) {
    cat_name   <- categories$Category[i]
    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name),
      error = function(e) data.frame(BrandCode = character(0))
    )
    if (nrow(cat_brands) == 0) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_name, reason = "no brand list defined")
      next
    }

    detector <- if (exists(".po_detect_cat_code", mode = "function"))
                  .po_detect_cat_code else .detect_category_code
    cat_code <- if (!is.null(structure$questionmap) &&
                    nrow(structure$questionmap) > 0)
                  detector(structure$questionmap, cat_brands, data) else NULL
    if (is.null(cat_code)) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_name, reason = "no awareness columns in data")
      next
    }

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_code, reason = base$message %||% "screener missing")
      next
    }
    if (base$n_uw < min_base) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_code, reason = sprintf("low base (n=%d < %d)", base$n_uw, min_base))
      next
    }

    cn <- .compute_constellation_for_cat(
      data         = data,
      cat_code     = cat_code,
      cat_brands   = cat_brands,
      base_idx     = base$idx,
      weights      = w,
      focal_brand  = focal_brand,
      cooccur_min  = cooccur_min,
      edge_top_n   = edge_top_n
    )

    if (identical(cn$status, "REFUSED")) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_code, reason = cn$message %||% "too sparse")
      next
    }

    by_cat[[cat_code]]       <- cn
    cat_codes                <- c(cat_codes, cat_code)
    cat_n                    <- c(cat_n, base$n_uw)
    cat_name_map[[cat_code]] <- as.character(cat_name)
  }

  suppressed_df <- if (length(suppressed) > 0) {
    do.call(rbind, lapply(suppressed, as.data.frame, stringsAsFactors = FALSE))
  } else {
    data.frame(cat = character(0), reason = character(0), stringsAsFactors = FALSE)
  }

  ord <- order(cat_n, decreasing = TRUE)

  list(
    status          = "PASS",
    by_cat          = by_cat[cat_codes[ord]],
    cat_order       = cat_codes[ord],
    cat_names       = cat_name_map[cat_codes[ord]],
    suppressed_cats = suppressed_df
  )
}


# ==============================================================================
# Pure-R Fruchterman-Reingold layout (seeded, deterministic)
# ==============================================================================

#' Pure-R Fruchterman-Reingold layout
#'
#' Deterministic force-directed layout for small node sets (n ≤ 60).
#' Uses \code{set.seed(42L)} for reproducibility.
#'
#' @param n Integer. Number of nodes.
#' @param adj Numeric matrix n × n. Adjacency weights (0 = no edge).
#' @param n_iter Integer. Iteration count. Default 80.
#' @param seed Integer. RNG seed for reproducibility.
#' @return Numeric matrix n × 2 of (x, y) positions.
#' @keywords internal
.fr_layout_r <- function(n, adj, n_iter = 80L, seed = 42L) {
  set.seed(seed)
  theta <- seq(0, 2 * pi * (1 - 1 / n), length.out = n)
  pos   <- cbind(cos(theta), sin(theta)) +
    matrix(rnorm(n * 2L, 0, 0.05), n, 2L)
  k   <- sqrt(1.0 / n)
  tmp <- 1.0

  for (iter in seq_len(n_iter)) {
    disp <- matrix(0.0, n, 2L)

    # Repulsive: every pair (vectorised inner loop)
    for (i in seq_len(n)) {
      diffs    <- sweep(pos, 2L, pos[i, ], FUN = "-")
      dists    <- pmax(sqrt(rowSums(diffs^2)), 1e-6)
      dists[i] <- Inf
      disp[i, ] <- disp[i, ] - colSums(diffs * (k^2 / dists^2))
    }

    # Attractive: weighted edges only
    for (i in seq_len(n - 1L)) {
      for (j in (i + 1L):n) {
        w_ij <- adj[i, j]
        if (w_ij == 0) next
        diff <- pos[j, ] - pos[i, ]
        d    <- max(sqrt(sum(diff^2)), 1e-6)
        fa   <- w_ij * d / k
        unit <- diff / d
        disp[i, ] <- disp[i, ] + unit * fa
        disp[j, ] <- disp[j, ] - unit * fa
      }
    }

    # Apply displacement, capped by temperature
    d_norms <- pmax(sqrt(rowSums(disp^2)), 1e-6)
    pos     <- pos + disp / d_norms * pmin(d_norms, tmp)
    tmp     <- tmp * (1 - iter / n_iter)
  }
  pos
}


# ==============================================================================
# Jaccard co-awareness
# ==============================================================================

#' Build brand-level any-awareness vectors
#'
#' For each brand code, collapses all BRANDAWARE_{cat}_{brand} columns into a
#' single binary "aware in any category" vector. Brands whose columns are all
#' absent return a zero vector (not counted as aware).
#'
#' @param data Data frame. Full survey data.
#' @param all_brands Character vector. All brand codes to include.
#' @return Integer matrix nrow(data) × length(all_brands) of 0/1.
#' @keywords internal
.build_aware_any_mat <- function(data, all_brands) {
  n <- nrow(data)
  mat <- matrix(0L, n, length(all_brands))
  colnames(mat) <- all_brands
  for (bc in all_brands) {
    pat  <- paste0("^BRANDAWARE_[^_]+_", bc, "$")
    cols <- grep(pat, names(data), value = TRUE)
    if (length(cols) == 0) next
    any_aware <- rowSums(
      do.call(cbind, lapply(cols, function(cc) {
        as.integer(!is.na(data[[cc]]) & data[[cc]] == 1L)
      }))
    ) > 0L
    mat[, bc] <- as.integer(any_aware)
  }
  mat
}


# ==============================================================================
# Main orchestrator
# ==============================================================================

#' Compute competitive constellation data
#'
#' Produces the co-awareness network for §4.2 of the portfolio spec. Jaccard
#' similarity is computed across each brand pair using weighted counts of
#' co-awareness across ALL categories (aware-in-any, not within a single
#' category).
#'
#' @param data Data frame. Full survey data.
#' @param categories Data frame. Categories sheet.
#' @param structure List. Loaded survey structure.
#' @param config List. Loaded brand config.
#' @param weights Numeric vector or NULL. Survey weights.
#'
#' @return List:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{nodes}{Data frame: brand, n_aware_w, is_focal.}
#'   \item{edges}{Data frame: b1, b2, jaccard, cooccur_n. Top-N edges only.}
#'   \item{layout}{Data frame: brand, x, y.}
#'   \item{layout_engine}{Character. Which FR implementation was used.}
#'   \item{suppressed_cats}{Character. Categories below min_base.}
#'
#' @export
compute_constellation <- function(data, categories, structure,
                                  config, weights = NULL) {
  focal_brand     <- config$focal_brand %||% ""
  timeframe       <- config$portfolio_timeframe %||% "3m"
  min_base        <- config$portfolio_min_base  %||% 30L
  cooccur_min     <- config$portfolio_cooccur_min_pairs %||% 20L
  edge_top_n      <- config$portfolio_edge_top_n %||% PORTFOLIO_EDGE_TOP_N_DEFAULT
  n_total         <- nrow(data)
  w               <- if (!is.null(weights)) weights else rep(1.0, n_total)

  # --- Collect all brands from all qualifying categories ---
  all_brands  <- character(0)
  suppressed  <- character(0)

  for (i in seq_len(nrow(categories))) {
    cat_name   <- categories$Category[i]
    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name),
      error = function(e) data.frame(BrandCode = character(0))
    )
    if (nrow(cat_brands) == 0) next

    cat_code <- if (!is.null(structure$questionmap) &&
                    nrow(structure$questionmap) > 0)
      .detect_category_code(structure$questionmap, cat_brands, data)
    else NULL
    if (is.null(cat_code)) next

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next
    if (base$n_uw < min_base) { suppressed <- c(suppressed, cat_code); next }

    all_brands <- unique(c(all_brands, as.character(cat_brands$BrandCode)))
  }

  # --- Any-awareness matrix ---
  aware_mat <- .build_aware_any_mat(data, all_brands)

  # Filter to brands with at least 1 aware respondent
  n_aware_w <- vapply(all_brands, function(bc) {
    sum(w * aware_mat[, bc], na.rm = TRUE)
  }, numeric(1))
  present_brands <- all_brands[n_aware_w > 0]

  if (length(present_brands) < CONSTELLATION_MIN_BRANDS) {
    cat("\n┌─── TURAS BRAND ERROR ──────────────────────────────────────────┐\n")
    cat("│ Context: compute_constellation()\n")
    cat("│ Code: CALC_CONSTELLATION_TOO_SPARSE\n")
    cat(sprintf("│ Message: Only %d brands with aware respondents (need ≥%d)\n",
                length(present_brands), CONSTELLATION_MIN_BRANDS))
    cat("└────────────────────────────────────────────────────────────────┘\n\n")
    return(list(
      status     = "REFUSED",
      code       = "CALC_CONSTELLATION_TOO_SPARSE",
      message    = sprintf(
        "Only %d brands with aware respondents — need at least %d for constellation.",
        length(present_brands), CONSTELLATION_MIN_BRANDS),
      how_to_fix = "Ensure at least 3 brands have non-zero awareness in the data"
    ))
  }

  nb <- length(present_brands)
  am <- aware_mat[, present_brands, drop = FALSE]

  # --- Weighted Jaccard for all pairs ---
  edge_rows  <- list()
  adj_mat    <- matrix(0.0, nb, nb)

  for (i in seq_len(nb - 1L)) {
    for (j in (i + 1L):nb) {
      both_vec  <- am[, i] * am[, j]
      either_vec <- pmax(am[, i], am[, j])
      w_both    <- sum(w * both_vec,   na.rm = TRUE)
      w_either  <- sum(w * either_vec, na.rm = TRUE)
      n_cooccur <- sum(both_vec)

      if (n_cooccur < cooccur_min || w_either <= 0) next
      jac <- w_both / w_either
      edge_rows[[length(edge_rows) + 1L]] <- list(
        b1 = present_brands[i], b2 = present_brands[j],
        jaccard = jac, cooccur_n = as.integer(n_cooccur)
      )
      adj_mat[i, j] <- jac
      adj_mat[j, i] <- jac
    }
  }

  edges_df <- if (length(edge_rows) > 0) {
    df <- do.call(rbind, lapply(edge_rows, as.data.frame, stringsAsFactors = FALSE))
    df <- df[order(df$jaccard, decreasing = TRUE), ]
    head(df, edge_top_n)
  } else {
    data.frame(b1 = character(0), b2 = character(0),
               jaccard = numeric(0), cooccur_n = integer(0),
               stringsAsFactors = FALSE)
  }

  # Rebuild adj for layout using only top-N edges
  adj_top <- matrix(0.0, nb, nb)
  if (nrow(edges_df) > 0) {
    for (k in seq_len(nrow(edges_df))) {
      i <- which(present_brands == edges_df$b1[k])
      j <- which(present_brands == edges_df$b2[k])
      adj_top[i, j] <- edges_df$jaccard[k]
      adj_top[j, i] <- edges_df$jaccard[k]
    }
  }

  # --- Layout ---
  layout_engine <- CONSTELLATION_LAYOUT_TURAS
  pos <- if (requireNamespace("igraph", quietly = TRUE)) {
    tryCatch({
      g   <- igraph::graph_from_adjacency_matrix(adj_top, mode = "undirected",
                                                 weighted = TRUE)
      lyt <- igraph::layout_with_fr(g)
      layout_engine <- CONSTELLATION_LAYOUT_IGRAPH
      lyt
    }, error = function(e) .fr_layout_r(nb, adj_top))
  } else {
    .fr_layout_r(nb, adj_top)
  }

  nodes_df <- data.frame(
    brand    = present_brands,
    n_aware_w = n_aware_w[present_brands],
    is_focal  = present_brands == focal_brand,
    stringsAsFactors = FALSE
  )
  layout_df <- data.frame(
    brand = present_brands,
    x     = pos[, 1],
    y     = pos[, 2],
    stringsAsFactors = FALSE
  )

  list(
    status        = "PASS",
    nodes         = nodes_df,
    edges         = edges_df,
    layout        = layout_df,
    layout_engine = layout_engine,
    suppressed_cats = suppressed
  )
}
