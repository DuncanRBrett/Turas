# ==============================================================================
# BRAND MODULE - FUNNEL PANEL DATA CONTRACT (FUNNEL_SPEC_v2.md §6)
# ==============================================================================
# Pure transformation: run_funnel() result -> HTML panel data contract.
# Separated from run_funnel() so other consumers (Excel long-format
# exporter, tracker wave diffing, AI callouts) can read the same shape.
#
# The contract is the structure listed in FUNNEL_SPEC_v2.md §6:
#   meta, cards, table, shape_chart, consideration_detail, config, about.
#
# VERSION: 2.0
# ==============================================================================

BRAND_FUNNEL_PANEL_DATA_VERSION <- "2.0"


# ==============================================================================
# PUBLIC: build_funnel_panel_data
# ==============================================================================

#' Build the HTML panel data contract from a run_funnel() result
#'
#' @param result List returned by \code{run_funnel()}.
#' @param brand_list Data frame with columns BrandCode, BrandLabel (+
#'   optional DisplayOrder, IsFocal).
#' @param config List of funnel.* settings (same shape as run_funnel
#'   expects), plus optional category_label, wave_label, show_counts.
#'
#' @return Named list matching FUNNEL_SPEC_v2.md §6.
#'
#' @export
build_funnel_panel_data <- function(result, brand_list, config = list()) {
  if (is.null(result) || identical(result$status, "REFUSED")) {
    return(.empty_panel_data())
  }

  focal <- result$meta$focal_brand
  stage_keys <- result$meta$stage_keys %||%
                 unique(as.character(result$stages$stage_key))

  list(
    meta = .panel_meta(result, brand_list, config, stage_keys),
    cards = .panel_cards(result, focal, stage_keys),
    table = .panel_table(result, brand_list, stage_keys),
    shape_chart = .panel_shape_chart(result, brand_list, focal, stage_keys),
    consideration_detail = .panel_consideration_detail(result, brand_list),
    config = .panel_config(result, brand_list, focal, config),
    about = .panel_about(result, config)
  )
}


# ==============================================================================
# INTERNAL: META / CARDS / TABLE / SHAPE / CONSIDERATION / CONFIG / ABOUT
# ==============================================================================

.panel_meta <- function(result, brand_list, config, stage_keys) {
  focal <- result$meta$focal_brand
  focal_label <- .brand_label(brand_list, focal)
  list(
    category_type = result$meta$category_type,
    focal_brand_code = focal,
    focal_brand_name = focal_label,
    category_label = config$category_label %||% config[["category.label"]] %||% "",
    wave_label = config$wave_label %||% as.character(result$meta$wave %||% ""),
    n_weighted = result$meta$n_weighted,
    n_unweighted = result$meta$n_unweighted,
    stage_count = length(stage_keys),
    stage_keys = stage_keys,
    stage_labels = .stage_labels_for(stage_keys)
  )
}


.panel_cards <- function(result, focal, stage_keys) {
  stages <- result$stages
  if (is.null(stages) || nrow(stages) == 0) {
    return(list(funnel = list(), relationship = list()))
  }
  sig_df <- result$sig_results

  funnel_cards <- lapply(stage_keys, function(key) {
    .card_for_stage(stages, sig_df, key, focal)
  })
  funnel_cards <- Filter(Negate(is.null), funnel_cards)

  rel_cards <- .relationship_cards(result$attitude_decomposition, focal)

  list(funnel = funnel_cards, relationship = rel_cards)
}


#' Five relationship / attitude-position summary cards (focal % vs avg %)
#' @keywords internal
.relationship_cards <- function(att_df, focal) {
  if (is.null(att_df) || nrow(att_df) == 0) return(list())
  positions <- c("attitude.love", "attitude.prefer",
                 "attitude.ambivalent", "attitude.reject",
                 "attitude.no_opinion")
  cards <- lapply(positions, function(role) {
    focal_row <- att_df[att_df$brand_code == focal &
                          att_df$attitude_role == role, , drop = FALSE]
    if (nrow(focal_row) == 0) return(NULL)
    other <- att_df[att_df$brand_code != focal &
                      att_df$attitude_role == role, , drop = FALSE]
    cat_avg <- if (nrow(other) == 0) NA_real_
               else mean(other$pct, na.rm = TRUE)
    list(
      attitude_role = role,
      attitude_label = .attitude_label_short(role),
      focal_pct = focal_row$pct[1],
      focal_base = focal_row$base[1],
      cat_avg_pct = cat_avg
    )
  })
  Filter(Negate(is.null), cards)
}


.attitude_label_short <- function(role) {
  labels <- c(attitude.love = "Love",
              attitude.prefer = "Prefer",
              attitude.ambivalent = "Ambivalent",
              attitude.reject = "Reject",
              attitude.no_opinion = "No opinion")
  unname(labels[role]) %||% role
}


.card_for_stage <- function(stages, sig_df, key, focal) {
  focal_row <- stages[stages$stage_key == key & stages$brand_code == focal, ,
                      drop = FALSE]
  if (nrow(focal_row) == 0) return(NULL)
  other <- stages[stages$stage_key == key & stages$brand_code != focal, ,
                  drop = FALSE]
  cat_avg_pct <- if (nrow(other) == 0) NA_real_ else mean(other$pct_weighted,
                                                          na.rm = TRUE)
  cat_avg_base <- if (nrow(other) == 0) NA_real_ else sum(other$base_weighted,
                                                          na.rm = TRUE)
  list(
    stage_index = which(unique(stages$stage_key) == key),
    stage_key = key,
    stage_label = .stage_label(key),
    focal_pct = focal_row$pct_weighted,
    focal_base_weighted = focal_row$base_weighted,
    focal_base_unweighted = focal_row$base_unweighted,
    cat_avg_pct = cat_avg_pct,
    cat_avg_base = cat_avg_base,
    sig_vs_avg = .sig_vs_avg_for(sig_df, key),
    warning_flag = focal_row$warning_flag
  )
}


.panel_table <- function(result, brand_list, stage_keys) {
  stages <- result$stages
  if (is.null(stages) || nrow(stages) == 0) {
    return(list(stage_keys = character(0), stage_labels = character(0),
                brand_codes = character(0), brand_names = character(0),
                cells = list(), avg_all_brands = list()))
  }
  brand_codes <- as.character(brand_list$BrandCode)
  brand_names <- as.character(
    brand_list$BrandLabel %||% brand_list$BrandCode)
  stage_labels <- vapply(stage_keys, .stage_label, character(1))

  # Nested pct = stage pct / previous stage pct (category-wide). Stage 1
  # has no previous stage so nested = absolute. Precomputed per brand
  # so the JS toggle can switch view without extra computation.
  prev_pct <- list()
  cells <- list()
  for (key in stage_keys) {
    for (b in brand_codes) {
      row <- stages[stages$stage_key == key & stages$brand_code == b, ,
                    drop = FALSE]
      abs_pct <- if (nrow(row) == 0) NA_real_ else row$pct_weighted
      nested_pct <- if (is.null(prev_pct[[b]]) || !is.finite(prev_pct[[b]]) ||
                        prev_pct[[b]] <= 0 || !is.finite(abs_pct)) {
        abs_pct
      } else {
        abs_pct / prev_pct[[b]]
      }
      cells[[length(cells) + 1]] <- list(
        stage_key = key, brand_code = b,
        pct_absolute = abs_pct,
        pct_nested   = nested_pct,
        base_weighted   = if (nrow(row) == 0) NA_real_ else row$base_weighted,
        base_unweighted = if (nrow(row) == 0) NA_real_ else row$base_unweighted,
        sig_vs_focal = .sig_vs_focal_for(result$sig_results, key, b,
                                         result$meta$focal_brand),
        warning_flag = if (nrow(row) == 0) "na" else row$warning_flag
      )
      prev_pct[[b]] <- abs_pct
    }
  }

  avg_all <- .avg_all_brands_row(stages, stage_keys)

  list(stage_keys = stage_keys, stage_labels = stage_labels,
       brand_codes = brand_codes, brand_names = brand_names,
       cells = cells, avg_all_brands = avg_all)
}


#' Category-average row: mean pct across every brand per stage (absolute +
#' nested variants). Included as its own row in the rendered table.
#' @keywords internal
.avg_all_brands_row <- function(stages, stage_keys) {
  prev_avg <- NA_real_
  out <- list()
  for (key in stage_keys) {
    vals <- stages$pct_weighted[stages$stage_key == key]
    abs_mean <- if (length(vals) == 0) NA_real_ else mean(vals, na.rm = TRUE)
    nested_mean <- if (!is.finite(prev_avg) || prev_avg <= 0 ||
                       !is.finite(abs_mean)) {
      abs_mean
    } else {
      abs_mean / prev_avg
    }
    out[[length(out) + 1]] <- list(
      stage_key = key,
      pct_absolute = abs_mean,
      pct_nested = nested_mean
    )
    prev_avg <- abs_mean
  }
  out
}


.panel_shape_chart <- function(result, brand_list, focal, stage_keys) {
  stages <- result$stages
  if (is.null(stages) || nrow(stages) == 0) return(list())
  brand_codes <- as.character(brand_list$BrandCode)

  focal_series <- .series_for_brand(stages, focal, stage_keys)
  comp_codes <- setdiff(brand_codes, focal)
  competitor_series <- lapply(comp_codes, function(b) {
    s <- .series_for_brand(stages, b, stage_keys)
    s$brand_code <- b
    s
  })

  stage_all_pct <- unname(vapply(stage_keys, function(k) {
    mean(stages$pct_weighted[stages$stage_key == k], na.rm = TRUE)
  }, numeric(1)))

  # Envelope = min/max across all brands per stage. Used to render the
  # light-grey shaded band behind the focal line (spec outline).
  env_min <- unname(vapply(stage_keys, function(k) {
    suppressWarnings(min(stages$pct_weighted[stages$stage_key == k],
                         na.rm = TRUE))
  }, numeric(1)))
  env_max <- unname(vapply(stage_keys, function(k) {
    suppressWarnings(max(stages$pct_weighted[stages$stage_key == k],
                         na.rm = TRUE))
  }, numeric(1)))
  env_min[!is.finite(env_min)] <- NA_real_
  env_max[!is.finite(env_max)] <- NA_real_

  list(
    focal_series = focal_series,
    competitor_series = competitor_series,
    category_avg_series = list(stage_keys = stage_keys,
                               pct_values = stage_all_pct),
    envelope = list(stage_keys = stage_keys,
                    min_values = env_min,
                    max_values = env_max),
    stage_positions = seq_along(stage_keys),
    default_view = "slope"
  )
}


.series_for_brand <- function(stages, brand_code, stage_keys) {
  vals <- unname(vapply(stage_keys, function(k) {
    row <- stages[stages$stage_key == k & stages$brand_code == brand_code, ,
                  drop = FALSE]
    if (nrow(row) == 0) NA_real_ else row$pct_weighted
  }, numeric(1)))
  base <- unname(vapply(stage_keys, function(k) {
    row <- stages[stages$stage_key == k & stages$brand_code == brand_code, ,
                  drop = FALSE]
    if (nrow(row) == 0) NA_real_ else row$base_weighted
  }, numeric(1)))
  list(brand_code = brand_code, stage_keys = stage_keys,
       pct_values = vals, base_values = base)
}


.panel_consideration_detail <- function(result, brand_list) {
  att <- result$attitude_decomposition
  if (is.null(att) || nrow(att) == 0) return(list(brands = list()))
  brand_codes <- as.character(brand_list$BrandCode)
  brands <- lapply(brand_codes, function(b) {
    sub <- att[att$brand_code == b, , drop = FALSE]
    if (nrow(sub) == 0) return(NULL)
    list(
      brand_code = b,
      brand_name = .brand_label(brand_list, b),
      aware_base = sub$base[1],
      segments = stats::setNames(as.list(sub$pct), sub$attitude_role)
    )
  })
  list(brands = Filter(Negate(is.null), brands),
       emphasis_state = "all", sort_mode = "default")
}


.panel_config <- function(result, brand_list, focal, config) {
  list(
    chip_picker = list(
      default_selection = c(focal,
        head(setdiff(as.character(brand_list$BrandCode), focal), 3)),
      all_brands = as.character(brand_list$BrandCode),
      quick_select_modes = c("top_awareness", "top_buying", "clear", "all")
    ),
    conversion_metric = config$`funnel.conversion_metric` %||% "ratio",
    warn_base = config$`funnel.warn_base` %||% 75,
    suppress_base = config$`funnel.suppress_base` %||% 0,
    show_counts = isTRUE(config$show_counts)
  )
}


.panel_about <- function(result, config) {
  list(
    question_texts = .question_texts_from_warnings(result),
    methodology_note = paste(
      "Funnel stages are nested: each stage is a subset of the previous.",
      "Conversion ratios show proportional drop-off between stages."),
    base_note = sprintf(
      "Base: n = %d unweighted, %.1f weighted. Focal brand: %s.",
      result$meta$n_unweighted, result$meta$n_weighted,
      result$meta$focal_brand),
    significance_note = paste(
      "Significance tests use a two-proportion z-test. Panel sampling is",
      "non-probability; margin of error is not reported."),
    ties_note = paste(
      "Preferred counts include ties. Respondents with equal-highest",
      "purchase frequency across multiple brands are counted for each",
      "tied brand; brand-level Preferred percentages can therefore sum",
      "above 100%."),
    prior_brand_note = if ("funnel.service.prior_brand" %in% names(
      result$role_map_used %||% list())) {
      "Prior-brand data available in Repertoire switching analysis."
    } else ""
  )
}


# ==============================================================================
# INTERNAL: SMALL HELPERS
# ==============================================================================

.empty_panel_data <- function() {
  list(meta = list(), cards = list(), table = list(),
       shape_chart = list(), consideration_detail = list(),
       config = list(), about = list())
}


.brand_label <- function(brand_list, brand_code) {
  if (is.null(brand_list) || !("BrandLabel" %in% names(brand_list))) {
    return(brand_code)
  }
  row <- brand_list[brand_list$BrandCode == brand_code, , drop = FALSE]
  if (nrow(row) == 0) return(brand_code)
  as.character(row$BrandLabel[1])
}


.stage_label <- function(key) {
  labels <- c(
    aware              = "Aware",
    consideration      = "Consideration",
    bought_long        = "Bought",
    bought_target      = "Frequent",
    preferred          = "Preferred",
    current_owner_d    = "Current owner",
    long_tenured_d     = "Long-tenured owner",
    current_customer_s = "Current customer",
    long_tenured_s     = "Long-tenured customer"
  )
  unname(labels[key]) %||% key
}


.stage_labels_for <- function(stage_keys) {
  vapply(stage_keys, .stage_label, character(1))
}


.sig_vs_focal_for <- function(sig_df, stage_key, brand_code, focal) {
  if (brand_code == focal) return("focal")
  if (is.null(sig_df) || nrow(sig_df) == 0) return("na")
  row <- sig_df[sig_df$stage_key == stage_key &
                  sig_df$brand_code == brand_code &
                  sig_df$comparison == "focal_vs_competitor", , drop = FALSE]
  if (nrow(row) == 0) return("not_sig")
  if (!isTRUE(row$significant)) return("not_sig")
  row$direction[1]
}


.sig_vs_avg_for <- function(sig_df, stage_key) {
  if (is.null(sig_df) || nrow(sig_df) == 0) return("na")
  row <- sig_df[sig_df$stage_key == stage_key &
                  sig_df$comparison == "focal_vs_cat_avg", , drop = FALSE]
  if (nrow(row) == 0) return("not_sig")
  if (!isTRUE(row$significant)) return("not_sig")
  row$direction[1]
}


.question_texts_from_warnings <- function(result) {
  # Placeholder: wired into future panel that receives the role map
  # directly. For now an empty named list keeps the contract stable.
  list()
}



# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand funnel panel data loaded (v%s)",
                  BRAND_FUNNEL_PANEL_DATA_VERSION))
}
