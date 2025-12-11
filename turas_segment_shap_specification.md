# turas Key Driver Analysis: SHAP Visualization Module

## Technical Specification v1.0

**Date:** December 2025  
**Module:** Key Driver Analysis - SHAP Extension  
**Status:** Development Specification

---

## 1. Executive Summary

This specification extends the turas Key Driver Analysis (KDA) module with SHAP (SHapley Additive exPlanations) visualizations. SHAP provides:

- **Individual prediction explanations** — understand why a specific respondent gave a particular score
- **Global feature importance** — identify which drivers matter most across all respondents
- **Interaction detection** — discover which drivers work together
- **Segment-level insights** — compare driver importance across customer groups

This is now an industry standard capability offered by Kantar, Ipsos, and other major research firms.

---

## 2. R Package Dependencies

### 2.1 Core SHAP Packages

| Package | Purpose | CRAN | Notes |
|---------|---------|------|-------|
| `shapviz` | SHAP visualizations | ✅ | Primary visualization engine |
| `xgboost` | TreeSHAP calculation | ✅ | Fast, native SHAP support |
| `lightgbm` | Alternative TreeSHAP | ✅ | For comparison/validation |
| `kernelshap` | Model-agnostic SHAP | ✅ | For non-tree models |
| `fastshap` | Fast approximate SHAP | ✅ | Large dataset fallback |

### 2.2 Supporting Packages

| Package | Purpose |
|---------|---------|
| `ggplot2` | Plot customization |
| `patchwork` | Multi-plot layouts |
| `scales` | Axis formatting |
| `viridis` | Colorblind-friendly palettes |

### 2.3 Installation

```r
# Core SHAP stack
install.packages(c("shapviz", "xgboost", "lightgbm", "kernelshap", "fastshap"))

# Visualization support
install.packages(c("ggplot2", "patchwork", "scales", "viridis"))
```

---

## 3. Architecture

### 3.1 Module Structure

```
turas/
└── R/
    └── kda_methods/
        └── method_shap.R              # Main SHAP orchestration
    └── kda_shap/
        ├── shap_model.R               # Model fitting (XGBoost/LightGBM)
        ├── shap_calculate.R           # SHAP value computation
        ├── shap_visualize.R           # shapviz wrapper functions
        ├── shap_segment.R             # Segment-level SHAP analysis
        ├── shap_interaction.R         # Interaction analysis
        └── shap_export.R              # Export to Excel/PowerPoint
```

### 3.2 Data Flow

```
┌─────────────────┐
│  Survey Data    │
│  (with weights) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Data Prep      │
│  - Missing data │
│  - Encoding     │
│  - Weighting    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  XGBoost Model  │
│  (TreeSHAP)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  shapviz Object │
│  - SHAP matrix  │
│  - Feature vals │
│  - Baseline     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│              Visualizations                 │
├─────────────┬─────────────┬─────────────────┤
│ Importance  │ Dependence  │ Individual      │
│ - Bar       │ - Scatter   │ - Waterfall     │
│ - Beeswarm  │ - Colored   │ - Force         │
└─────────────┴─────────────┴─────────────────┘
```

---

## 4. Excel Configuration Schema

### 4.1 SHAPParameters Sheet

Add to the KDA configuration workbook:

| Parameter | Value | Description |
|-----------|-------|-------------|
| `enable_shap` | TRUE | Enable SHAP analysis |
| `shap_model` | xgboost | Model type: xgboost, lightgbm |
| `n_trees` | 100 | Number of trees (auto-tuned if "auto") |
| `max_depth` | 6 | Tree depth (auto-tuned if "auto") |
| `learning_rate` | 0.1 | Learning rate |
| `subsample` | 0.8 | Row subsampling |
| `colsample_bytree` | 0.8 | Column subsampling |
| `shap_sample_size` | 1000 | Max rows for SHAP calculation |
| `include_interactions` | FALSE | Calculate SHAP interactions |
| `interaction_top_n` | 5 | Top N interactions to display |

### 4.2 SHAPOutputs Sheet

| Output | Include | Options |
|--------|---------|---------|
| `importance_bar` | TRUE | top_n=15, show_numbers=TRUE |
| `importance_beeswarm` | TRUE | top_n=15 |
| `dependence_plots` | TRUE | top_n=10, auto_color=TRUE |
| `waterfall_examples` | TRUE | n_examples=5, selection="extreme" |
| `force_plots` | TRUE | n_examples=5 |
| `segment_comparison` | TRUE | — |
| `interaction_matrix` | FALSE | top_n=10 |

### 4.3 SHAPSegments Sheet (Optional)

| segment_name | segment_variable | segment_values | compare_drivers |
|--------------|------------------|----------------|-----------------|
| Promoters | nps_group | "Promoter" | TRUE |
| Detractors | nps_group | "Detractor" | TRUE |
| High_Value | customer_tier | "Gold, Platinum" | TRUE |

---

## 5. Function Specifications

### 5.1 Main Entry Point

```r
#' Run SHAP Analysis for Key Driver Analysis
#'
#' Fits a gradient boosting model and calculates SHAP values
#' for driver importance analysis.
#'
#' @param data Data frame with outcome and driver variables
#' @param outcome Character. Name of outcome variable
#' @param drivers Character vector. Names of driver variables
#' @param weights Character. Name of weight variable (optional)
#' @param config List. SHAP configuration parameters
#' @param segments Data frame. Segment definitions (optional
#'
#' @return shap_results S3 object containing:
#'   - model: Fitted XGBoost model
#'   - shap: shapviz object
#'   - importance: Data frame of driver importance
#'   - plots: List of ggplot objects
#'   - diagnostics: Model fit statistics
#'
#' @export
run_shap_analysis <- function(
    data,
    outcome,
    drivers,
    weights = NULL,
    config = list(),
    segments = NULL
) {

    # 1. Validate inputs
    validate_shap_inputs(data, outcome, drivers, weights)
    
    # 2. Prepare data for XGBoost
    prep <- prepare_shap_data(data, outcome, drivers, weights)
    
    # 3. Fit XGBoost model
    model <- fit_shap_model(prep, config)
    
    # 4. Calculate SHAP values
    shap <- calculate_shap_values(model, prep, config)
    
    # 5. Generate visualizations
    plots <- generate_shap_plots(shap, config)
    
    # 6. Segment analysis (if requested)
    if (!is.null(segments)) {
        segment_results <- run_segment_shap(shap, data, segments)
    }
    
    # 7. Compile results
    results <- structure(
        list(
            model = model,
            shap = shap,
            importance = extract_importance(shap),
            plots = plots,
            segments = segment_results,
            diagnostics = model_diagnostics(model, prep)
        ),
        class = "shap_results"
    )
    
    return(results)
}
```

### 5.2 Data Preparation

```r
#' Prepare Data for SHAP Analysis
#'
#' Handles missing data, encoding, and weight application
#'
#' @param data Raw survey data
#' @param outcome Outcome variable name
#' @param drivers Driver variable names
#' @param weights Weight variable name
#'
#' @return List with:
#'   - X: Feature matrix (numeric)
#'   - y: Outcome vector
#'   - w: Weight vector
#'   - X_display: Original features for display (can include factors)
#'   - feature_map: Mapping from encoded to original names
#'
prepare_shap_data <- function(data, outcome, drivers, weights = NULL) {
    
    # Extract outcome
    y <- data[[outcome]]
    
    # Handle weights
    w <- if (!is.null(weights)) data[[weights]] else rep(1, nrow(data))
    
    # Subset to drivers
    X_raw <- data[, drivers, drop = FALSE]
    
    # Store original for display (shapviz can handle factors)
    X_display <- X_raw
    
    # Convert to numeric matrix for XGBoost
    # Handle factors via one-hot or ordinal encoding
    X_numeric <- encode_features(X_raw)
    
    # Handle missing data
    # Option 1: Impute with median/mode
    # Option 2: XGBoost handles NA natively (preferred)
    
    # Create feature map for collapsing dummy variables later
    feature_map <- create_feature_map(X_raw, X_numeric)
    
    list(
        X = as.matrix(X_numeric),
        y = y,
        w = w,
        X_display = X_display,
        feature_map = feature_map
    )
}

#' Encode Features for XGBoost
#'
#' Convert factors to numeric. XGBoost requires numeric input.
#' We use ordinal encoding for ordered factors, one-hot for unordered.
#'
encode_features <- function(X) {
    
    X_encoded <- X
    
    for (col in names(X)) {
        if (is.factor(X[[col]]) || is.character(X[[col]])) {
            if (is.ordered(X[[col]])) {
                # Ordinal: convert to integer
                X_encoded[[col]] <- as.integer(X[[col]])
            } else {
                # Nominal: one-hot encode
                # Will be collapsed back via feature_map
                dummies <- model.matrix(~ . - 1, data = X[, col, drop = FALSE])
                X_encoded[[col]] <- NULL
                X_encoded <- cbind(X_encoded, as.data.frame(dummies))
            }
        }
    }
    
    X_encoded
}
```

### 5.3 Model Fitting

```r
#' Fit XGBoost Model for SHAP
#'
#' Fits gradient boosting model optimized for interpretability.
#' Uses early stopping to prevent overfitting.
#'
#' @param prep Prepared data from prepare_shap_data()
#' @param config Configuration parameters
#'
#' @return Fitted xgb.Booster object
#'
fit_shap_model <- function(prep, config) {
    
    # Set defaults
    params <- list(
        objective = detect_objective(prep$y),
        eval_metric = detect_metric(prep$y),
        eta = config$learning_rate %||% 0.1,
        max_depth = config$max_depth %||% 6,
        subsample = config$subsample %||% 0.8,
        colsample_bytree = config$colsample_bytree %||% 0.8,
        min_child_weight = 1,
        nthread = parallel::detectCores() - 1
    )
    
    # Create DMatrix with weights
    dtrain <- xgboost::xgb.DMatrix(
        data = prep$X,
        label = prep$y,
        weight = prep$w
    )
    
    # Cross-validation to find optimal nrounds
    cv_result <- xgboost::xgb.cv(
        params = params,
        data = dtrain,
        nrounds = config$n_trees %||% 500,
        nfold = 5,
        early_stopping_rounds = 20,
        verbose = FALSE
    )
    
    best_nrounds <- cv_result$best_iteration
    
    # Fit final model
    model <- xgboost::xgb.train(
        params = params,
        data = dtrain,
        nrounds = best_nrounds,
        verbose = FALSE
    )
    
    # Store metadata for later use
    attr(model, "prep") <- prep
    attr(model, "cv_result") <- cv_result
    
    model
}

#' Detect Objective Function
#'
#' Automatically select appropriate XGBoost objective based on outcome type
#'
detect_objective <- function(y) {
    if (is.factor(y)) {
        n_levels <- nlevels(y)
        if (n_levels == 2) {
            return("binary:logistic")
        } else {
            return("multi:softprob")
        }
    }
    
    # Continuous outcome
    "reg:squarederror"
}
```

### 5.4 SHAP Calculation

```r
#' Calculate SHAP Values
#'
#' Uses TreeSHAP for fast, exact SHAP value computation.
#' Creates shapviz object for visualization.
#'
#' @param model Fitted XGBoost model
#' @param prep Prepared data
#' @param config Configuration parameters
#'
#' @return shapviz object
#'
calculate_shap_values <- function(model, prep, config) {
    
    # Sample data if too large
    n <- nrow(prep$X)
    max_n <- config$shap_sample_size %||% 1000
    
    if (n > max_n) {
        idx <- sample(n, max_n)
        X_explain <- prep$X[idx, , drop = FALSE]
        X_display <- prep$X_display[idx, , drop = FALSE]
        cli::cli_alert_info(
            "Sampled {max_n} of {n} observations for SHAP calculation"
        )
    } else {
        X_explain <- prep$X
        X_display <- prep$X_display
    }
    
    # Create shapviz object
    # X_pred: numeric matrix for SHAP calculation
    # X: display data (can include factors for better plots)
    shp <- shapviz::shapviz(
        object = model,
        X_pred = X_explain,
        X = X_display,
        collapse = prep$feature_map  # Collapse dummy variables
    )
    
    # Calculate interactions if requested
    if (isTRUE(config$include_interactions)) {
        shp <- shapviz::shapviz(
            object = model,
            X_pred = X_explain,
            X = X_display,
            collapse = prep$feature_map,
            interactions = TRUE
        )
    }
    
    shp
}
```

### 5.5 Visualization Functions

```r
#' Generate All SHAP Plots
#'
#' Creates standard suite of SHAP visualizations
#'
#' @param shp shapviz object
#' @param config Configuration parameters
#'
#' @return Named list of ggplot objects
#'
generate_shap_plots <- function(shp, config) {
    
    plots <- list()
    
    # 1. Importance Bar Plot
    plots$importance_bar <- create_importance_bar(shp, config)
    
    # 2. Beeswarm Plot (SHAP summary)
    plots$importance_beeswarm <- create_beeswarm(shp, config)
    
    # 3. Combined Importance Plot
    plots$importance_combined <- create_importance_combined(shp, config)
    
    # 4. Dependence Plots (top drivers)
    plots$dependence <- create_dependence_plots(shp, config)
    
    # 5. Waterfall Plots (individual explanations)
    plots$waterfalls <- create_waterfall_plots(shp, config)
    
    # 6. Force Plots (alternative individual view)
    plots$force <- create_force_plots(shp, config)
    
    # 7. Interaction Plot (if enabled)
    if (!is.null(shapviz::get_shap_interactions(shp))) {
        plots$interactions <- create_interaction_plot(shp, config)
    }
    
    plots
}

#' Create Importance Bar Plot
#'
#' Bar chart showing mean |SHAP| for each driver
#'
create_importance_bar <- function(shp, config) {
    
    top_n <- config$importance_top_n %||% 15
    show_numbers <- config$show_numbers %||% TRUE
    
    p <- shapviz::sv_importance(
        shp,
        kind = "bar",
        max_display = top_n,
        show_numbers = show_numbers
    ) +
        ggplot2::labs(
            title = "Driver Importance (SHAP)",
            subtitle = "Mean absolute SHAP value",
            x = "Mean |SHAP|",
            y = NULL
        ) +
        turas_theme()
    
    p
}

#' Create Beeswarm Plot
#'
#' Summary plot showing SHAP value distribution for each driver
#'
create_beeswarm <- function(shp, config) {
    
    top_n <- config$importance_top_n %||% 15
    
    p <- shapviz::sv_importance(
        shp,
        kind = "beeswarm",
        max_display = top_n,
        viridis_args = list(option = "D")  # Colorblind-friendly
    ) +
        ggplot2::labs(
            title = "SHAP Summary Plot",
            subtitle = "Distribution of SHAP values by driver",
            x = "SHAP Value (impact on prediction)",
            y = NULL
        ) +
        turas_theme()
    
    p
}

#' Create Combined Importance Plot
#'
#' Bar + beeswarm overlay for maximum information
#'
create_importance_combined <- function(shp, config) {
    
    top_n <- config$importance_top_n %||% 15
    
    p <- shapviz::sv_importance(
        shp,
        kind = "both",
        max_display = top_n,
        show_numbers = TRUE,
        viridis_args = list(option = "D")
    ) +
        ggplot2::labs(
            title = "Key Driver Importance (SHAP Analysis)",
            subtitle = "Bar = mean |SHAP|, points = individual SHAP values",
            x = "SHAP Value",
            y = NULL
        ) +
        turas_theme()
    
    p
}

#' Create Dependence Plots
#'
#' Scatter plots showing relationship between driver value and SHAP
#'
create_dependence_plots <- function(shp, config) {
    
    top_n <- config$dependence_top_n %||% 10
    
    # Get top drivers by importance
    imp <- shapviz::sv_importance(shp, kind = "bar")
    top_drivers <- head(imp$data$feature, top_n)
    
    # Create dependence plot for each
    plots <- lapply(top_drivers, function(driver) {
        
        shapviz::sv_dependence(
            shp,
            v = driver,
            color_var = "auto",  # Auto-detect best interaction
            alpha = 0.5
        ) +
            ggplot2::labs(
                title = paste("SHAP Dependence:", driver),
                x = driver,
                y = "SHAP Value"
            ) +
            turas_theme()
    })
    
    names(plots) <- top_drivers
    
    # Combine into grid
    combined <- patchwork::wrap_plots(plots, ncol = 2)
    
    list(
        individual = plots,
        combined = combined
    )
}

#' Create Waterfall Plots
#'
#' Individual prediction explanations showing driver contributions
#'
create_waterfall_plots <- function(shp, config) {
    
    n_examples <- config$n_waterfall_examples %||% 5
    selection <- config$waterfall_selection %||% "extreme"
    
    # Get row indices based on selection strategy
    shap_values <- shapviz::get_shap_values(shp)
    row_sums <- rowSums(shap_values)
    
    idx <- switch(selection,
        "extreme" = {
            # Highest and lowest predictions
            c(
                order(row_sums, decreasing = TRUE)[1:ceiling(n_examples/2)],
                order(row_sums, decreasing = FALSE)[1:floor(n_examples/2)]
            )
        },
        "random" = sample(nrow(shap_values), n_examples),
        "first" = 1:n_examples
    )
    
    # Create waterfall for each
    plots <- lapply(idx, function(i) {
        shapviz::sv_waterfall(shp, row_id = i) +
            ggplot2::labs(
                title = paste("Respondent", i),
                subtitle = paste(
                    "Prediction:",
                    round(shapviz::get_baseline(shp) + sum(shap_values[i,]), 2)
                )
            ) +
            turas_theme()
    })
    
    names(plots) <- paste0("respondent_", idx)
    plots
}

#' Create Force Plots
#'
#' Compact horizontal visualization of individual predictions
#'
create_force_plots <- function(shp, config) {
    
    n_examples <- config$n_force_examples %||% 5
    
    # Use same selection as waterfall
    shap_values <- shapviz::get_shap_values(shp)
    row_sums <- rowSums(shap_values)
    idx <- order(row_sums, decreasing = TRUE)[1:n_examples]
    
    plots <- lapply(idx, function(i) {
        shapviz::sv_force(shp, row_id = i) +
            turas_theme()
    })
    
    names(plots) <- paste0("respondent_", idx)
    plots
}
```

### 5.6 Segment Analysis

```r
#' Run SHAP Analysis by Segment
#'
#' Calculates and compares SHAP importance across segments
#'
#' @param shp shapviz object
#' @param data Original data with segment variables
#' @param segments Segment definition data frame
#'
#' @return List with segment-level results
#'
run_segment_shap <- function(shp, data, segments) {
    
    results <- list()
    
    for (i in seq_len(nrow(segments))) {
        
        seg_name <- segments$segment_name[i]
        seg_var <- segments$segment_variable[i]
        seg_vals <- strsplit(segments$segment_values[i], ",\\s*")[[1]]
        
        # Create segment filter
        seg_idx <- data[[seg_var]] %in% seg_vals
        
        # Split shapviz object
        shp_segment <- shp[seg_idx, ]
        
        # Calculate importance for segment
        results[[seg_name]] <- list(
            n = sum(seg_idx),
            importance = calculate_segment_importance(shp_segment),
            plots = list(
                importance = shapviz::sv_importance(shp_segment, kind = "both") +
                    ggplot2::labs(title = paste("Driver Importance:", seg_name))
            )
        )
    }
    
    # Create comparison plot
    results$comparison <- create_segment_comparison(results, segments)
    
    results
}

#' Create Segment Comparison Plot
#'
#' Side-by-side comparison of driver rankings across segments
#'
create_segment_comparison <- function(segment_results, segments) {
    
    # Extract importance from each segment
    importance_list <- lapply(names(segment_results), function(seg) {
        if (seg == "comparison") return(NULL)
        
        imp <- segment_results[[seg]]$importance
        imp$segment <- seg
        imp
    })
    
    importance_df <- do.call(rbind, importance_list[!sapply(importance_list, is.null)])
    
    # Create comparison plot
    ggplot2::ggplot(
        importance_df,
        ggplot2::aes(x = reorder(feature, importance), y = importance, fill = segment)
    ) +
        ggplot2::geom_col(position = "dodge") +
        ggplot2::coord_flip() +
        ggplot2::labs(
            title = "Driver Importance by Segment",
            subtitle = "SHAP-based importance comparison",
            x = NULL,
            y = "Mean |SHAP|",
            fill = "Segment"
        ) +
        ggplot2::scale_fill_viridis_d() +
        turas_theme()
}
```

### 5.7 Interaction Analysis

```r
#' Analyze SHAP Interactions
#'
#' Identifies and visualizes driver interactions
#'
#' @param shp shapviz object with interactions
#' @param config Configuration parameters
#'
#' @return List with interaction results
#'
analyze_shap_interactions <- function(shp, config) {
    
    # Check if interactions were calculated
    interactions <- shapviz::get_shap_interactions(shp)
    if (is.null(interactions)) {
        cli::cli_alert_warning("SHAP interactions not calculated. Set include_interactions = TRUE")
        return(NULL)
    }
    
    top_n <- config$interaction_top_n %||% 10
    
    # Get potential interactions (H-statistic approximation)
    features <- colnames(shapviz::get_shap_values(shp))
    
    potential <- shapviz::potential_interactions(shp, v = features[1])
    
    # Create interaction plots for top pairs
    plots <- list()
    
    for (v in head(features, 5)) {
        plots[[v]] <- shapviz::sv_dependence(
            shp,
            v = v,
            color_var = "auto",
            interactions = TRUE  # Use interaction SHAP
        ) +
            ggplot2::labs(
                title = paste("Interaction:", v),
                subtitle = "Color indicates strongest interacting variable"
            ) +
            turas_theme()
    }
    
    # Interaction strength matrix
    interaction_matrix <- calculate_interaction_matrix(shp)
    
    list(
        plots = plots,
        matrix = interaction_matrix,
        top_pairs = get_top_interaction_pairs(interaction_matrix, top_n)
    )
}

#' Calculate Interaction Strength Matrix
#'
#' Computes pairwise interaction strengths
#'
calculate_interaction_matrix <- function(shp) {
    
    interactions <- shapviz::get_shap_interactions(shp)
    features <- dimnames(interactions)[[2]]
    n_features <- length(features)
    
    # Mean absolute interaction value for each pair
    mat <- matrix(0, n_features, n_features)
    rownames(mat) <- colnames(mat) <- features
    
    for (i in 1:n_features) {
        for (j in 1:n_features) {
            if (i != j) {
                mat[i, j] <- mean(abs(interactions[, i, j]))
            }
        }
    }
    
    mat
}
```

---

## 6. Output Specifications

### 6.1 Excel Output

The SHAP results should be exported to the KDA Excel workbook with:

#### Sheet: SHAP_Importance

| Driver | Mean_SHAP | Rank | Std_Dev | Min | Max |
|--------|-----------|------|---------|-----|-----|
| Q5_Quality | 0.847 | 1 | 0.423 | -0.21 | 2.34 |
| Q3_Price | 0.721 | 2 | 0.512 | -0.45 | 1.98 |
| ... | ... | ... | ... | ... | ... |

#### Sheet: SHAP_Segment_Comparison

| Driver | Overall_Rank | Promoters_Rank | Detractors_Rank | Delta |
|--------|--------------|----------------|-----------------|-------|
| Q5_Quality | 1 | 1 | 3 | -2 |
| Q3_Price | 2 | 4 | 1 | +3 |
| ... | ... | ... | ... | ... |

#### Sheet: SHAP_Model_Diagnostics

| Metric | Value |
|--------|-------|
| Model Type | XGBoost |
| Number of Trees | 87 |
| R-squared (CV) | 0.423 |
| RMSE (CV) | 1.234 |
| Sample Size | 1000 |

### 6.2 Chart Outputs

All plots should be saved as both:
- High-resolution PNG (300 DPI) for reports
- Vector PDF for presentations

```r
#' Export SHAP Plots
#'
export_shap_plots <- function(plots, output_dir, prefix = "shap") {
    
    for (name in names(plots)) {
        
        p <- plots[[name]]
        
        if (inherits(p, "list")) {
            # Nested list (e.g., dependence plots)
            for (subname in names(p)) {
                if (inherits(p[[subname]], "ggplot")) {
                    save_plot(
                        p[[subname]],
                        file.path(output_dir, paste0(prefix, "_", name, "_", subname))
                    )
                }
            }
        } else if (inherits(p, "ggplot") || inherits(p, "patchwork")) {
            save_plot(
                p,
                file.path(output_dir, paste0(prefix, "_", name))
            )
        }
    }
}

save_plot <- function(p, path_without_ext) {
    
    # PNG for reports
    ggplot2::ggsave(
        paste0(path_without_ext, ".png"),
        plot = p,
        width = 10,
        height = 8,
        dpi = 300
    )
    
    # PDF for presentations
    ggplot2::ggsave(
        paste0(path_without_ext, ".pdf"),
        plot = p,
        width = 10,
        height = 8
    )
}
```

---

## 7. turas Theme

Consistent visual styling across all SHAP outputs:

```r
#' turas ggplot2 Theme
#'
#' Consistent styling for all turas visualizations
#'
turas_theme <- function() {
    
    ggplot2::theme_minimal() +
        ggplot2::theme(
            # Text
            text = ggplot2::element_text(family = "sans"),
            plot.title = ggplot2::element_text(
                size = 14,
                face = "bold",
                hjust = 0
            ),
            plot.subtitle = ggplot2::element_text(
                size = 11,
                color = "gray40",
                hjust = 0
            ),
            axis.title = ggplot2::element_text(size = 10),
            axis.text = ggplot2::element_text(size = 9),
            
            # Legend
            legend.position = "bottom",
            legend.title = ggplot2::element_text(size = 10),
            legend.text = ggplot2::element_text(size = 9),
            
            # Grid
            panel.grid.minor = ggplot2::element_blank(),
            panel.grid.major = ggplot2::element_line(color = "gray90"),
            
            # Plot margins
            plot.margin = ggplot2::margin(10, 10, 10, 10)
        )
}

#' turas Color Palette
#'
#' Colorblind-friendly palette for categorical data
#'
turas_colors <- function(n = 8) {
    viridis::viridis(n, option = "D")
}

#' turas Diverging Color Palette
#'
#' For SHAP values (negative to positive)
#'
turas_diverging <- function() {
    c(
        negative = "#2166AC",  # Blue
        neutral = "#F7F7F7",   # White
        positive = "#B2182B"   # Red
    )
}
```

---

## 8. Error Handling

```r
#' Validate SHAP Inputs
#'
validate_shap_inputs <- function(data, outcome, drivers, weights) {
    
    # Check outcome exists
    if (!outcome %in% names(data)) {
        stop_kda(
            "Outcome variable not found",
            c(
                "Looking for: {outcome}",
                "Available: {paste(names(data), collapse = ', ')}"
            )
        )
    }
    
    # Check drivers exist
    missing_drivers <- setdiff(drivers, names(data))
    if (length(missing_drivers) > 0) {
        stop_kda(
            "Driver variables not found",
            c(
                "Missing: {paste(missing_drivers, collapse = ', ')}",
                "Check DataMapping sheet for typos"
            )
        )
    }
    
    # Check minimum sample size
    if (nrow(data) < 100) {
        warn_kda(
            "Small sample size for SHAP analysis",
            c(
                "Found: {nrow(data)} observations",
                "Recommended: >= 200 observations",
                "Results may be unstable"
            )
        )
    }
    
    # Check outcome variance
    if (is.numeric(data[[outcome]])) {
        if (sd(data[[outcome]], na.rm = TRUE) < 0.01) {
            stop_kda(
                "Outcome has near-zero variance",
                c(
                    "SD: {round(sd(data[[outcome]], na.rm = TRUE), 4)}",
                    "Cannot fit meaningful model"
                )
            )
        }
    }
    
    # Check for highly correlated drivers
    if (all(sapply(data[drivers], is.numeric))) {
        cor_mat <- cor(data[drivers], use = "pairwise.complete.obs")
        high_cor <- which(abs(cor_mat) > 0.9 & cor_mat < 1, arr.ind = TRUE)
        
        if (nrow(high_cor) > 0) {
            pairs <- apply(high_cor, 1, function(x) {
                paste(drivers[x[1]], "-", drivers[x[2]])
            })
            warn_kda(
                "Highly correlated drivers detected",
                c(
                    "Pairs with r > 0.9: {paste(unique(pairs), collapse = '; ')}",
                    "Consider removing redundant drivers",
                    "SHAP will still work but importance may be split"
                )
            )
        }
    }
    
    invisible(TRUE)
}
```

---

## 9. Usage Example

```r
# Load configuration
config <- load_kda_config("project_config.xlsx")

# Run standard KDA with SHAP
results <- run_key_driver_analysis(
    config_file = "project_config.xlsx"
)

# Or run SHAP standalone
shap_results <- run_shap_analysis(
    data = survey_data,
    outcome = "overall_satisfaction",
    drivers = c("Q1_Price", "Q2_Quality", "Q3_Service", "Q4_Value"),
    weights = "weight_var",
    config = list(
        n_trees = 100,
        max_depth = 6,
        shap_sample_size = 1000,
        include_interactions = FALSE
    ),
    segments = data.frame(
        segment_name = c("Promoters", "Detractors"),
        segment_variable = c("nps_group", "nps_group"),
        segment_values = c("Promoter", "Detractor")
    )
)

# Access results
shap_results$importance          # Driver importance table
shap_results$plots$importance_bar # Bar plot
shap_results$plots$beeswarm      # Summary beeswarm
shap_results$segments$comparison # Segment comparison plot

# Export all outputs
export_shap_results(shap_results, output_dir = "outputs/")
```

---

## 10. Integration with Existing KDA Module

The SHAP module integrates with the existing KDA specification:

### 10.1 Method Selection

In MethodParameters sheet, add:

| method | enabled | primary |
|--------|---------|---------|
| correlation | TRUE | FALSE |
| regression | TRUE | FALSE |
| relative_weights | TRUE | FALSE |
| shap | TRUE | TRUE |

### 10.2 Results Comparison

The KDA module should produce a comparison of all methods:

| Driver | Correlation | Std_Beta | Rel_Weights | SHAP | Consensus_Rank |
|--------|-------------|----------|-------------|------|----------------|
| Q5_Quality | 0.65 | 0.42 | 23.4% | 0.847 | 1 |
| Q3_Price | 0.58 | 0.38 | 19.2% | 0.721 | 2 |

### 10.3 Recommended Defaults

For most survey research applications:

```yaml
SHAP Defaults:
  model: xgboost
  n_trees: auto (use CV)
  max_depth: 6
  learning_rate: 0.1
  subsample: 0.8
  shap_sample_size: 1000
  include_interactions: FALSE  # Enable for deep-dive
```

---

## 11. Limitations and Caveats

Document these for users:

1. **SHAP requires sufficient sample size** — Minimum 100, recommended 500+
2. **Categorical drivers with many levels** — May split importance across dummies
3. **Highly correlated drivers** — Importance may be shared/split
4. **Interactions** — Computationally expensive, O(n × p²)
5. **Extrapolation** — XGBoost can't extrapolate beyond training data range
6. **Causation** — SHAP shows association, not causation

---

## 12. Future Enhancements

- **SHAP-based what-if analysis** — "What if we improved Q5 by 1 point?"
- **Cohort analysis** — Track SHAP importance over time (wave studies)
- **Automated narrative** — Generate text explanations from SHAP
- **Interactive dashboard** — Shiny app for SHAP exploration

---

## Appendix A: Complete Package Dependencies

```r
# Install all SHAP-related packages
install.packages(c(
    # Core SHAP
    "shapviz",
    "xgboost",
    "lightgbm",
    "kernelshap",
    "fastshap",
    
    # Visualization
    "ggplot2",
    "patchwork",
    "scales",
    "viridis",
    
    # Utilities
    "cli",
    "rlang",
    "parallel"
))
```

---

## Appendix B: Visual Gallery

### B.1 Importance Bar Plot
Shows ranked drivers by mean |SHAP| value.

### B.2 Beeswarm Plot
Each dot is one respondent. Color indicates feature value (low=blue, high=red). X-position shows SHAP contribution.

### B.3 Waterfall Plot
Explains single prediction. Shows baseline, each driver's contribution, and final prediction.

### B.4 Dependence Plot
X-axis: driver value. Y-axis: SHAP value. Color: interacting variable.

### B.5 Segment Comparison
Side-by-side importance bars for each segment.

---

*End of Specification*
