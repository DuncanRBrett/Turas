# ==============================================================================
# SEGMENT — DATA-CENTRIC REPORT v2 DATA-LAYER WRITER
# ==============================================================================
# Maps the segmentation analytics outputs onto the v2 report's `agg` contract
# (the same JSON shape the tabs renderer consumes; see
# modules/tabs/lib/data_layer_writer.R and assets/js/20_data.js d2.validate).
#
# Mapping (the segment profile IS a crosstab):
#   columns   = Total (the "Overall" column) + one per segment (the banner)
#   questions = one per profile variable, with a single mean row whose pct[]
#               holds the per-column means (Overall, Segment_1..k)
#
# Presentation only — NO statistics are recomputed here; this re-presents the
# already-computed profile means. See PLAN.md for the build plan.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

# Treat NULL / NA / "" / the loader's literal "NA" as blank (mirrors the tabs
# writer — no display field is ever legitimately "NA").
.seg_dl_blank <- function(x) {
  if (is.null(x) || length(x) == 0) return(TRUE)
  if (length(x) > 1) return(FALSE)
  if (is.na(x)) return(TRUE)
  s <- trimws(as.character(x))
  !nzchar(s) || s == "NA"
}

# Map identify_golden_questions() output to the v2 `golden` island: the smallest
# set of questions that type a respondent into a segment (RF importance +
# cumulative accuracy curve). Returns NULL when golden questions weren't computed.
.seg_dl_golden <- function(gq, qlab) {
  if (is.null(gq)) return(NULL)
  if (!(gq$status %||% "PASS") %in% c("PASS", "PARTIAL")) return(NULL)
  tq <- gq$top_questions
  if (is.null(tq) || !is.data.frame(tq) || nrow(tq) == 0) return(NULL)
  pct_col <- intersect(c("pct_of_total", "importance_pct"), names(tq))[1]
  has_cum <- "cumulative_accuracy" %in% names(tq)
  qs <- lapply(seq_len(nrow(tq)), function(i) {
    v <- as.character(tq$variable[i])
    list(
      code = v, title = qlab(v),
      importance_pct = if (!is.na(pct_col)) as.numeric(tq[[pct_col]][i]) else NA_real_,
      cumulative_accuracy = if (has_cum) as.numeric(tq$cumulative_accuracy[i]) else NA_real_,
      rank = as.integer(if ("rank" %in% names(tq)) tq$rank[i] else i)
    )
  })
  per_seg <- NULL
  psa <- gq$per_segment_accuracy
  if (!is.null(psa) && length(psa) > 0) {
    nm <- names(psa)
    per_seg <- lapply(seq_along(psa), function(i) {
      list(label = if (!is.null(nm)) as.character(nm[i]) else paste("Segment", i),
           accuracy = as.numeric(psa[i]))
    })
  }
  list(overall_accuracy = as.numeric(gq$accuracy %||% NA_real_),
       n_questions = nrow(tq), questions = qs, per_segment = per_seg)
}


#' Build the v2 data layer (agg) for a segmentation result
#'
#' @param results The segment results list (mode "final"): needs
#'   profile_result$clustering_profile, segment_names, cluster_result$clusters.
#' @param config The segment config list (colours, scale_max, dashboard
#'   thresholds, question_labels, title).
#' @return A list mirroring the data-agg JSON shape (schema_version 2), or NULL
#'   when no profile is available.
#' @export
build_segment_data_layer <- function(results, config) {
  pr <- results$profile_result
  cp <- if (!is.null(pr)) pr$clustering_profile else NULL
  if (is.null(cp) || !is.data.frame(cp) || nrow(cp) == 0) return(NULL)
  if (!"Variable" %in% names(cp) || !"Overall" %in% names(cp)) return(NULL)

  seg_cols <- grep("^Segment_", names(cp), value = TRUE)
  k <- length(seg_cols)
  if (k < 1) return(NULL)

  seg_names <- results$segment_names %||% paste("Segment", seq_len(k))
  if (length(seg_names) < k) seg_names <- paste("Segment", seq_len(k))

  clusters <- results$cluster_result$clusters
  seg_n <- vapply(seq_len(k), function(i) sum(clusters == i, na.rm = TRUE), integer(1))
  total_n <- sum(!is.na(clusters))
  low_base <- as.numeric(config$significance_min_base %||% 30)

  q_labels <- config$question_labels
  qlab <- function(v) {
    if (!is.null(q_labels) && v %in% names(q_labels)) as.character(q_labels[[v]]) else v
  }

  ncol_tot  <- 1L + k
  null_vec  <- function() as.list(rep(NA_real_, ncol_tot))  # serialises to [null,...]
  empty_sig <- function() as.list(rep("", ncol_tot))

  # ---- columns: Total first, then one per segment ------------------------
  cols <- c(
    list(list(key = "Total", group = "total", label = "Total", letter = "")),
    lapply(seq_len(k), function(i) {
      list(key = paste0("Segment_", i), group = "segment",
           label = as.character(seg_names[i]),
           letter = if (i <= 26L) LETTERS[i] else as.character(i))
    })
  )

  # ---- dashboard gauge scale + thresholds (raw value, like the classic
  #      report's dashboard_green/amber) so 0-10 means don't read as ~7% --
  scale_max   <- as.numeric(config$scale_max %||% config$dashboard_scale_mean %||% 10)
  gauge_green <- as.numeric(config$dashboard_green_mean %||% (scale_max * 0.7))
  gauge_amber <- as.numeric(config$dashboard_amber_mean %||% (scale_max * 0.5))

  # ---- bases: identical per question (profile uses all respondents/seg) ---
  bases <- c(
    list(list(n = total_n, low = total_n < low_base)),
    lapply(seq_len(k), function(i) list(n = seg_n[i], low = seg_n[i] < low_base))
  )

  # ---- questions: one per profile variable, a single mean row ------------
  # f_stat / p_value (ANOVA differentiation, when the profile carries them) are
  # attached as extra fields the segment-native Importance view reads; the
  # engine's d2.validate / model ignore unknown question fields.
  has_f <- "F_statistic" %in% names(cp)
  has_p <- "p_value" %in% names(cp)
  cat_label <- "Segment profile"
  questions <- lapply(seq_len(nrow(cp)), function(r) {
    v <- as.character(cp$Variable[r])
    means <- c(as.numeric(cp$Overall[r]),
               vapply(seg_cols, function(sc) as.numeric(cp[[sc]][r]), numeric(1)))
    q <- list(
      code = v, title = qlab(v), category = cat_label, type = "scale",
      bases = bases,
      rows = list(list(kind = "mean", label = "Mean",
                       pct = as.list(unname(means)),
                       n = null_vec(), sig = empty_sig())),
      scale_max = scale_max, gauge_green = gauge_green, gauge_amber = gauge_amber
    )
    if (has_f) q$f_stat  <- as.numeric(cp$F_statistic[r])
    if (has_p) q$p_value <- as.numeric(cp$p_value[r])
    q
  })

  # ---- project ------------------------------------------------------------
  blank <- .seg_dl_blank
  name <- if (!blank(config$report_title)) config$report_title
          else if (!blank(config$project_name)) config$project_name
          else "Segmentation"
  alpha <- as.numeric(config$alpha %||% 0.05)
  project <- list(
    name               = as.character(name),
    client             = if (blank(config$client_name)) "" else as.character(config$client_name),
    wave               = "",
    brand_colour       = as.character(config$brand_colour %||% "#323367"),
    accent_colour      = as.character(config$accent_colour %||% "#CC9900"),
    low_base_threshold = low_base,
    alpha              = alpha,
    sampling_method    = as.character(config$sampling_method %||% "Not_Specified"),
    sig_note           = sprintf(
      "Columns are the %d segments; the Total column is the overall sample. Cells show segment means.", k),
    tracking           = list(enabled = FALSE, default_scope = "all")
  )
  analyst <- if (blank(config$analyst_name)) "" else as.character(config$analyst_name)
  if (nzchar(analyst)) project$report_meta <- list(analyst = analyst)

  # Golden questions (RF typing model) — a top-level island the native Golden
  # Questions view reads; the engine ignores unknown top-level fields.
  golden <- .seg_dl_golden(results$golden_questions, qlab)
  # Vulnerability (boundary/switching) + overlap (centroid distinctiveness).
  vulnerability <- .seg_dl_vulnerability(results$vulnerability)
  overlap <- .seg_dl_overlap(results$cluster_result$centers, seg_names)

  dl <- list(
    schema_version = 2L,
    project        = project,
    columns        = cols,
    banner_groups  = list(list(id = "segment", name = "Segments")),
    categories     = list(cat_label),
    questions      = questions
  )
  if (!is.null(golden)) dl$golden <- golden
  if (!is.null(vulnerability)) dl$vulnerability <- vulnerability
  if (!is.null(overlap)) dl$overlap <- overlap
  dl
}


# Map calculate_vulnerability() output to the v2 `vulnerability` island:
# per-segment boundary risk (% vulnerable + mean confidence) and the switching
# matrix (where at-risk members would move). NULL when not computed.
.seg_dl_vulnerability <- function(vuln) {
  if (is.null(vuln)) return(NULL)
  ss <- vuln$segment_summary
  if (is.null(ss) || !is.data.frame(ss) || nrow(ss) == 0) return(NULL)
  segs <- lapply(seq_len(nrow(ss)), function(i) {
    list(label = as.character(ss$segment[i]),
         n = as.integer(ss$n[i]),
         pct_vulnerable = as.numeric(ss$pct_vulnerable[i]),
         avg_confidence = as.numeric(ss$avg_confidence[i]))
  })
  switching <- NULL
  sw <- vuln$switching_matrix
  if (!is.null(sw) && is.matrix(sw) && nrow(sw) >= 1) {
    labs <- rownames(sw)
    if (is.null(labs)) labs <- paste("Segment", seq_len(nrow(sw)))
    switching <- list(
      labels = as.list(as.character(labs)),
      matrix = lapply(seq_len(nrow(sw)), function(i) as.list(as.integer(sw[i, ]))))
  }
  list(overall_pct_vulnerable = as.numeric(vuln$overall_pct_vulnerable %||% NA_real_),
       overall_avg_confidence = as.numeric(vuln$overall_avg_confidence %||% NA_real_),
       threshold = as.numeric(vuln$threshold %||% NA_real_),
       segments = segs, switching = switching)
}


# Pairwise centroid distances from the cluster centres -> the v2 `overlap`
# island (segment distinctiveness: larger distance = more separated). NULL when
# fewer than two segments / no centres.
.seg_dl_overlap <- function(centers, seg_names) {
  if (is.null(centers)) return(NULL)
  centers <- tryCatch(as.matrix(centers), error = function(e) NULL)
  if (is.null(centers) || nrow(centers) < 2) return(NULL)
  d <- as.matrix(stats::dist(centers))
  k <- nrow(d)
  labs <- if (!is.null(seg_names) && length(seg_names) >= k) {
    seg_names[seq_len(k)]
  } else {
    paste("Segment", seq_len(k))
  }
  list(labels = as.list(as.character(labs)),
       distance = lapply(seq_len(k), function(i) as.list(round(as.numeric(d[i, ]), 3))))
}


#' Serialise a segment data layer to the JSON string the renderer reads
#'
#' Arrays preserved (never unboxed); NA -> JSON null. Mirrors the tabs writer.
#'
#' @param data_layer A list from build_segment_data_layer()
#' @return A single JSON string
#' @export
serialize_segment_data_layer <- function(data_layer) {
  jsonlite::toJSON(data_layer, auto_unbox = TRUE, na = "null",
                   null = "null", digits = 6, pretty = FALSE)
}
