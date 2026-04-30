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
# During the IPK rebuild the file holds both v1 (column-per-brand) and v2
# (slot-indexed) variants side-by-side; v1 is scheduled for deletion at
# rebuild cutover (planning doc §9 step 5), bringing the file back inside
# the 300-active-line default.
# Denominator: build_portfolio_base() per §3.1 — never inline SQ1_/SQ2_.
# ==============================================================================

CONSTELLATION_MIN_BRANDS <- 3L

CONSTELLATION_LAYOUT_TURAS  <- "Turas pure-R Fruchterman-Reingold"
CONSTELLATION_LAYOUT_IGRAPH <- "igraph Fruchterman-Reingold"
CONSTELLATION_LAYOUT_KK     <- "Turas pure-R Kamada-Kawai (1 - Jaccard)"


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

  # Kamada-Kawai layout — separates brands by graph distance over
  # (1 - Jaccard) edge weights so high-co-awareness clusters stay tight
  # without collapsing on top of each other and disconnected outliers
  # sit at distance-meaningful gaps. Replaces Fruchterman-Reingold which
  # squashed dense Jaccard clusters into a single dot for IPK-shape data.
  layout_engine <- CONSTELLATION_LAYOUT_KK
  pos <- .kk_layout_r(nb, adj_top)

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
# Pure-R Kamada-Kawai layout (seeded, deterministic)
# ==============================================================================

#' Pure-R Kamada-Kawai layout for a weighted graph
#'
#' Energy-minimising layout that places every pair of nodes at a Euclidean
#' distance proportional to their graph-theoretic distance. For our use the
#' edge weights are \code{(1 - jaccard)} for every co-awareness edge, so two
#' brands with Jaccard 0.9 sit close (distance 0.1) and two brands with
#' Jaccard 0.1 sit far (distance 0.9). This is a deliberate replacement for
#' Fruchterman-Reingold, which collapses dense high-Jaccard clusters into a
#' single dot — see PORTFOLIO_SPEC notes on layout choice.
#'
#' Algorithm (Kamada & Kawai 1989, "An algorithm for drawing general
#' undirected graphs"): minimise
#'   \eqn{E = \sum_{i<j} k_{ij} (\|p_i - p_j\| - l_{ij})^2}
#' where \eqn{l_{ij}} = scaled graph distance, \eqn{k_{ij} = 1 / d_{ij}^2}.
#' Iteratively picks the node with the largest partial gradient and Newton-
#' steps it toward its local minimum. Falls back to gradient descent when
#' the 2x2 Hessian is singular.
#'
#' Disconnected pairs receive a sentinel distance of 1.5 \eqn{\times} the
#' largest finite distance so they sit far from the connected component
#' rather than blowing up to infinity.
#'
#' Deterministic for a given seed (uses \code{set.seed(seed)} for the
#' circular-init jitter).
#'
#' @param n Integer. Number of nodes.
#' @param adj Numeric matrix n x n. Adjacency Jaccard scores in
#'   \eqn{[0, 1]}; 0 means no edge.
#' @param n_iter_outer Integer. Maximum outer iterations
#'   (each picks the worst-fit node). Default 200.
#' @param n_iter_inner Integer. Maximum Newton steps per outer iteration.
#'   Default 30.
#' @param eps Numeric. Stop when the worst node's gradient norm < eps.
#'   Default 1e-3.
#' @param seed Integer. RNG seed. Default 42.
#' @return Numeric matrix n x 2 of (x, y) positions, roughly in
#'   \eqn{[-1, 1]} on each axis (no normalisation applied).
#' @keywords internal
.kk_layout_r <- function(n, adj, n_iter_outer = 200L, n_iter_inner = 30L,
                          eps = 1e-3, seed = 42L) {
  if (n <= 1L) return(matrix(0.0, max(n, 1L), 2L))
  if (n == 2L) {
    j_val <- if (adj[1L, 2L] > 0) adj[1L, 2L] else 0
    sep   <- max(0.1, 1 - j_val)
    return(matrix(c(-sep / 2, 0, sep / 2, 0), 2L, 2L, byrow = TRUE))
  }

  # Edge-weight matrix W: 1 - jaccard for connected pairs, NA otherwise.
  # Jaccard >= 1 produces zero-length edges, which break the Floyd-Warshall
  # division below; floor at a small positive epsilon so the spring still
  # has a finite target.
  W <- matrix(NA_real_, n, n)
  for (i in seq_len(n - 1L)) {
    for (j in (i + 1L):n) {
      jac <- adj[i, j]
      if (jac > 0) {
        d <- max(1 - jac, 1e-3)
        W[i, j] <- d
        W[j, i] <- d
      }
    }
  }

  # Floyd-Warshall shortest paths over the weighted graph.
  D <- W
  D[is.na(D)] <- Inf
  diag(D) <- 0
  for (kk in seq_len(n)) {
    dk_col <- D[, kk]
    dk_row <- D[kk, ]
    for (i in seq_len(n)) {
      D[i, ] <- pmin(D[i, ], dk_col[i] + dk_row)
    }
  }

  # Disconnected pairs: cap at 1.5x the max finite distance so the spring
  # still pulls them apart, but doesn't blow up to infinity.
  finite_vals <- D[is.finite(D) & D > 0]
  finite_max  <- if (length(finite_vals) > 0) max(finite_vals) else 1
  D[is.infinite(D)] <- finite_max * 1.5
  d_max <- max(D)
  if (d_max <= 0) d_max <- 1

  # Target Euclidean distances + spring stiffness (k_ii = 0)
  L_scale <- 1.0
  l_ij <- L_scale * D / d_max
  k_ij <- ifelse(D > 0, 1 / D^2, 0)

  # Initial positions on a circle with a tiny seeded jitter to break symmetry
  set.seed(seed)
  theta <- seq(0, 2 * pi * (1 - 1 / n), length.out = n)
  pos <- cbind(cos(theta), sin(theta)) +
         matrix(stats::rnorm(n * 2L, 0, 0.01), n, 2L)

  .grad_hess <- function(m, pos) {
    dx_vec <- pos[m, 1L] - pos[, 1L]
    dy_vec <- pos[m, 2L] - pos[, 2L]
    r2     <- dx_vec * dx_vec + dy_vec * dy_vec
    r      <- sqrt(r2)
    keep   <- seq_len(n) != m
    r[!keep] <- 1  # avoid /0; cancelled via mask below
    r3     <- r * r * r

    k_row <- k_ij[m, ]
    l_row <- l_ij[m, ]
    coef  <- k_row * (1 - l_row / r) * keep

    g_x <- sum(coef * dx_vec)
    g_y <- sum(coef * dy_vec)

    Hxx <- sum(k_row * (1 - l_row * dy_vec * dy_vec / r3) * keep)
    Hyy <- sum(k_row * (1 - l_row * dx_vec * dx_vec / r3) * keep)
    Hxy <- sum(k_row * l_row * dx_vec * dy_vec / r3 * keep)

    list(g = c(g_x, g_y),
         H = matrix(c(Hxx, Hxy, Hxy, Hyy), 2L, 2L))
  }

  .grad_norm <- function(m, pos) {
    dx_vec <- pos[m, 1L] - pos[, 1L]
    dy_vec <- pos[m, 2L] - pos[, 2L]
    r      <- sqrt(dx_vec * dx_vec + dy_vec * dy_vec)
    keep   <- seq_len(n) != m
    r[!keep] <- 1
    coef <- k_ij[m, ] * (1 - l_ij[m, ] / r) * keep
    sqrt(sum(coef * dx_vec)^2 + sum(coef * dy_vec)^2)
  }

  for (outer in seq_len(n_iter_outer)) {
    grads <- vapply(seq_len(n), .grad_norm, numeric(1), pos = pos)
    m_max <- which.max(grads)
    if (grads[m_max] < eps) break

    for (inner in seq_len(n_iter_inner)) {
      gh <- .grad_hess(m_max, pos)
      gn <- sqrt(sum(gh$g^2))
      if (gn < eps) break

      det_H <- gh$H[1L, 1L] * gh$H[2L, 2L] - gh$H[1L, 2L]^2
      step <- if (abs(det_H) < 1e-9) {
        -gh$g * 0.05
      } else {
        c(
          (-gh$g[1L] * gh$H[2L, 2L] + gh$g[2L] * gh$H[1L, 2L]) / det_H,
          ( gh$g[1L] * gh$H[1L, 2L] - gh$g[2L] * gh$H[1L, 1L]) / det_H
        )
      }

      step_norm <- sqrt(sum(step^2))
      if (step_norm > 0.5) step <- step * (0.5 / step_norm)

      pos[m_max, ] <- pos[m_max, ] + step
    }
  }

  pos
}


# ==============================================================================
# Pure-R Fruchterman-Reingold layout (seeded, deterministic)
# ==============================================================================
# Retained for backwards compatibility with legacy v1 constellation tests.
# Live constellations now use \code{.kk_layout_r}; this function is only
# reached by tests that pin its name. Scheduled for deletion at rebuild
# cutover (planning doc §9 step 5).

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
  # Kamada-Kawai layout — separates brands by graph distance over
  # (1 - Jaccard) edge weights so high-co-awareness clusters stay tight
  # without collapsing on top of each other and disconnected outliers
  # sit at distance-meaningful gaps. Replaces Fruchterman-Reingold which
  # squashed dense Jaccard clusters into a single dot for IPK-shape data.
  layout_engine <- CONSTELLATION_LAYOUT_KK
  pos <- .kk_layout_r(nb, adj_top)

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


# ==============================================================================
# V2: SLOT-INDEXED CONSTELLATIONS
# ==============================================================================

#' Compute the cross-category any-awareness matrix from the v2 helper
#'
#' For each category in the structure, builds a slot-indexed awareness
#' matrix and OR-aggregates per-brand awareness into a single
#' \code{nrow(data) x length(all_brands)} indicator matrix.  Brands without
#' awareness in any category produce an all-zero column.
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param brands_df Data frame from \code{structure$brands} (must have
#'   \code{CategoryCode}, \code{BrandCode}).
#' @return Integer matrix \code{[nrow(data) x n_unique_brands]}.
#' @keywords internal
.build_aware_any_mat_v2 <- function(data, role_map, brands_df) {
  all_brands <- unique(as.character(brands_df$BrandCode))
  n          <- nrow(data)
  if (length(all_brands) == 0L) {
    return(matrix(0L, n, 0L, dimnames = list(NULL, character(0))))
  }
  mat <- matrix(0L, n, length(all_brands),
                dimnames = list(NULL, all_brands))
  cat_codes <- unique(as.character(brands_df$CategoryCode))
  for (cc in cat_codes) {
    if (is.na(cc) || !nzchar(cc)) next
    cb <- as.character(brands_df$BrandCode[brands_df$CategoryCode == cc])
    cb <- cb[cb %in% all_brands]
    if (length(cb) == 0L) next
    aw <- .portfolio_aware_matrix_v2(data, role_map, cc, cb)
    for (b in cb) mat[, b] <- as.integer(mat[, b] | aw[, b])
  }
  mat
}


#' Compute competitive constellation (v2 — slot-indexed)
#'
#' v2 alternative to \code{compute_constellation()}.  Builds the cross-cat
#' any-awareness matrix from \code{structure$brands} and the slot-indexed
#' data-access layer, then runs the same Jaccard + Fruchterman-Reingold
#' pipeline as the legacy entry.  The brand universe is derived from the
#' Brands sheet (every declared brand) instead of a regex scan over data
#' column names.
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param categories Data frame with \code{Category} + \code{CategoryCode}.
#' @param structure List from a Survey_Structure loader (must contain
#'   \code{brands}).
#' @param config List with the portfolio settings.
#' @param weights Numeric vector or NULL.
#' @return Same list shape as \code{compute_constellation()}.
#' @export
compute_constellation_v2 <- function(data, role_map, categories, structure,
                                      config, weights = NULL) {
  focal_brand <- config$focal_brand %||% ""
  timeframe   <- config$portfolio_timeframe %||% "3m"
  min_base    <- config$portfolio_min_base  %||% 30L
  cooccur_min <- config$portfolio_cooccur_min_pairs %||% 20L
  edge_top_n  <- config$portfolio_edge_top_n %||% PORTFOLIO_EDGE_TOP_N_DEFAULT
  n_total     <- nrow(data)
  w           <- if (!is.null(weights)) weights else rep(1.0, n_total)

  if (!"CategoryCode" %in% names(categories)) {
    return(list(status = "REFUSED",
                code = "CFG_PORTFOLIO_NO_CATEGORY_CODE",
                message = "categories sheet must include a CategoryCode column for v2 portfolio analyses",
                how_to_fix = "Add CategoryCode column to Brand_Config Categories sheet"))
  }

  brands_df <- structure$brands
  if (is.null(brands_df) || nrow(brands_df) == 0L) {
    return(list(status = "REFUSED",
                code = "CFG_NO_BRAND_LIST",
                message = "structure$brands is empty — cannot build constellation",
                how_to_fix = "Populate the Brands sheet in Survey_Structure"))
  }

  # Restrict to active categories from the categories sheet (v2 contract)
  active_codes <- as.character(categories$CategoryCode)
  brands_active <- brands_df[
    as.character(brands_df$CategoryCode) %in% active_codes, , drop = FALSE]

  # Track suppressed cats (low base / no qualifiers) for transparency,
  # mirroring the legacy "suppressed_cats" return field.
  suppressed <- character(0)
  for (cc in unique(as.character(brands_active$CategoryCode))) {
    base <- build_portfolio_base_v2(data, cc, timeframe, weights)
    if (!is.null(base$status)) next
    if (base$n_uw == 0L || base$n_uw < min_base) {
      suppressed <- c(suppressed, cc)
    }
  }

  aware_mat <- .build_aware_any_mat_v2(data, role_map, brands_active)
  all_brands <- colnames(aware_mat)

  n_aware_w <- vapply(all_brands, function(bc) {
    sum(w * aware_mat[, bc], na.rm = TRUE)
  }, numeric(1))
  present_brands <- all_brands[n_aware_w > 0]

  if (length(present_brands) < CONSTELLATION_MIN_BRANDS) {
    cat("\n=== TURAS BRAND ERROR ===\n")
    cat("Context: compute_constellation_v2()\n")
    cat("Code: CALC_CONSTELLATION_TOO_SPARSE\n")
    cat(sprintf("Message: Only %d brands with aware respondents (need >= %d)\n",
                length(present_brands), CONSTELLATION_MIN_BRANDS))
    cat("=========================\n")
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

  edge_rows <- list()
  adj_mat   <- matrix(0.0, nb, nb)

  for (i in seq_len(nb - 1L)) {
    for (j in (i + 1L):nb) {
      both_vec   <- am[, i] * am[, j]
      either_vec <- pmax(am[, i], am[, j])
      w_both     <- sum(w * both_vec,   na.rm = TRUE)
      w_either   <- sum(w * either_vec, na.rm = TRUE)
      n_cooccur  <- sum(both_vec)

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

  edges_df <- if (length(edge_rows) > 0L) {
    df <- do.call(rbind, lapply(edge_rows, as.data.frame,
                                 stringsAsFactors = FALSE))
    df <- df[order(df$jaccard, decreasing = TRUE), ]
    head(df, edge_top_n)
  } else {
    data.frame(b1 = character(0), b2 = character(0),
               jaccard = numeric(0), cooccur_n = integer(0),
               stringsAsFactors = FALSE)
  }

  adj_top <- matrix(0.0, nb, nb)
  if (nrow(edges_df) > 0L) {
    for (k in seq_len(nrow(edges_df))) {
      i <- which(present_brands == edges_df$b1[k])
      j <- which(present_brands == edges_df$b2[k])
      adj_top[i, j] <- edges_df$jaccard[k]
      adj_top[j, i] <- edges_df$jaccard[k]
    }
  }

  # Kamada-Kawai layout (see compute_constellation for rationale).
  layout_engine <- CONSTELLATION_LAYOUT_KK
  pos <- .kk_layout_r(nb, adj_top)

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
    status          = "PASS",
    nodes           = nodes_df,
    edges           = edges_df,
    layout          = layout_df,
    layout_engine   = layout_engine,
    suppressed_cats = suppressed
  )
}


#' Compute per-category constellations (v2 — slot-indexed)
#'
#' v2 alternative to \code{compute_constellations_per_cat()}.  For each
#' category in \code{categories}, builds the brand x respondent awareness
#' matrix via the slot-indexed helper, restricts to category buyers, and
#' runs the existing per-cat Jaccard layout
#' (\code{.compute_constellation_for_cat_v2}).
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param categories Data frame with \code{Category} + \code{CategoryCode}.
#' @param structure List from a Survey_Structure loader.
#' @param config List with portfolio settings.
#' @param weights Numeric vector or NULL.
#' @return Same list shape as \code{compute_constellations_per_cat()}.
#' @export
compute_constellations_per_cat_v2 <- function(data, role_map, categories,
                                                structure, config,
                                                weights = NULL) {
  focal_brand <- config$focal_brand %||% ""
  timeframe   <- config$portfolio_timeframe %||% "3m"
  min_base    <- config$portfolio_min_base  %||% 30L
  cooccur_min <- config$portfolio_cooccur_min_pairs %||% 20L
  edge_top_n  <- config$portfolio_edge_top_n %||% PORTFOLIO_EDGE_TOP_N_DEFAULT
  n_total     <- nrow(data)
  w           <- if (!is.null(weights)) weights else rep(1.0, n_total)

  if (!"CategoryCode" %in% names(categories)) {
    return(list(status = "REFUSED",
                code = "CFG_PORTFOLIO_NO_CATEGORY_CODE",
                message = "categories sheet must include a CategoryCode column for v2 portfolio analyses",
                how_to_fix = "Add CategoryCode column to Brand_Config Categories sheet"))
  }

  by_cat       <- list()
  cat_codes_ok <- character(0)
  cat_n        <- integer(0)
  cat_name_map <- list()
  suppressed   <- list()

  for (i in seq_len(nrow(categories))) {
    cat_name <- as.character(categories$Category[i])
    cat_code <- as.character(categories$CategoryCode[i])
    if (is.na(cat_code) || !nzchar(cat_code)) next

    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name),
      error = function(e) data.frame(BrandCode = character(0))
    )
    if (nrow(cat_brands) == 0L) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_name, reason = "no brand list defined"); next
    }

    base <- build_portfolio_base_v2(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_code, reason = base$message %||% "screener missing"); next
    }
    if (base$n_uw == 0L) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_code, reason = "no qualifiers"); next
    }
    if (base$n_uw < min_base) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_code,
        reason = sprintf("low base (n=%d < %d)", base$n_uw, min_base))
      next
    }

    brand_codes <- as.character(cat_brands$BrandCode)
    brand_lbls  <- if ("BrandLabel" %in% names(cat_brands))
                     as.character(cat_brands$BrandLabel)
                   else if ("BrandName" %in% names(cat_brands))
                     as.character(cat_brands$BrandName)
                   else brand_codes
    names(brand_lbls) <- brand_codes

    am <- .portfolio_aware_matrix_v2(data, role_map, cat_code, brand_codes)
    cn <- .compute_constellation_for_cat_from_matrix(
      am             = am,
      brand_codes    = brand_codes,
      brand_lbls     = brand_lbls,
      base_idx       = base$idx,
      weights        = w,
      focal_brand    = focal_brand,
      cooccur_min    = cooccur_min,
      edge_top_n     = edge_top_n
    )

    if (identical(cn$status, "REFUSED")) {
      suppressed[[length(suppressed) + 1L]] <- list(
        cat = cat_code, reason = cn$message %||% "too sparse"); next
    }

    by_cat[[cat_code]]       <- cn
    cat_codes_ok             <- c(cat_codes_ok, cat_code)
    cat_n                    <- c(cat_n, base$n_uw)
    cat_name_map[[cat_code]] <- cat_name
  }

  suppressed_df <- if (length(suppressed) > 0L) {
    do.call(rbind, lapply(suppressed, as.data.frame, stringsAsFactors = FALSE))
  } else {
    data.frame(cat = character(0), reason = character(0),
               stringsAsFactors = FALSE)
  }

  ord <- order(cat_n, decreasing = TRUE)
  list(
    status          = "PASS",
    by_cat          = by_cat[cat_codes_ok[ord]],
    cat_order       = cat_codes_ok[ord],
    cat_names       = cat_name_map[cat_codes_ok[ord]],
    suppressed_cats = suppressed_df
  )
}


#' Per-cat constellation pipeline operating on a pre-built matrix (v2)
#'
#' Variant of \code{.compute_constellation_for_cat()} that takes the brand x
#' respondent awareness matrix as input rather than re-reading data columns.
#' Same Jaccard + FR pipeline; same return shape.
#'
#' @keywords internal
.compute_constellation_for_cat_from_matrix <- function(am, brand_codes,
                                                        brand_lbls, base_idx,
                                                        weights, focal_brand,
                                                        cooccur_min,
                                                        edge_top_n) {
  am_buyers <- am[base_idx, , drop = FALSE]
  w_buyers  <- weights[base_idx]

  n_aware_w <- vapply(brand_codes, function(bc) {
    sum(w_buyers * am_buyers[, bc], na.rm = TRUE)
  }, numeric(1))
  present <- brand_codes[n_aware_w > 0]

  if (length(present) < CONSTELLATION_MIN_BRANDS) {
    return(list(
      status  = "REFUSED",
      code    = "CALC_CONSTELLATION_TOO_SPARSE",
      message = sprintf(
        "Only %d brand(s) with aware buyers — need at least %d.",
        length(present), CONSTELLATION_MIN_BRANDS),
      n_aware = setNames(as.numeric(n_aware_w), brand_codes)
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

  edges_df <- if (length(edge_rows) > 0L) {
    df <- do.call(rbind, lapply(edge_rows, as.data.frame,
                                 stringsAsFactors = FALSE))
    df <- df[order(df$jaccard, decreasing = TRUE), ]
    head(df, edge_top_n)
  } else {
    data.frame(b1 = character(0), b2 = character(0),
               jaccard = numeric(0), cooccur_n = integer(0),
               stringsAsFactors = FALSE)
  }

  adj_top <- matrix(0.0, nb, nb)
  if (nrow(edges_df) > 0L) {
    for (k in seq_len(nrow(edges_df))) {
      i <- which(present == edges_df$b1[k])
      j <- which(present == edges_df$b2[k])
      adj_top[i, j] <- edges_df$jaccard[k]
      adj_top[j, i] <- edges_df$jaccard[k]
    }
  }

  # Kamada-Kawai layout (see compute_constellation for rationale).
  layout_engine <- CONSTELLATION_LAYOUT_KK
  pos <- .kk_layout_r(nb, adj_top)

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
