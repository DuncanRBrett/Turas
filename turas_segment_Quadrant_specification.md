# turas Key Driver Analysis: Quadrant Chart Module

## Technical Specification v1.0

**Date:** December 2025  
**Module:** Key Driver Analysis - Importance-Performance Analysis (IPA)  
**Status:** Development Specification

---

## 1. Executive Summary

The Quadrant Chart module adds Importance-Performance Analysis (IPA) to turas, providing the actionable output that clients expect from key driver studies. This is the deliverable that drives business decisions.

**Core Capability:** Plot drivers on a 2×2 matrix showing:
- **X-axis:** Current performance (satisfaction scores)
- **Y-axis:** Derived importance (from KDA methods)

This reveals which drivers to prioritize for improvement, which to maintain, and which to deprioritize.

### 1.1 Why This Matters

Raw driver importance rankings tell you *what matters*. Quadrant charts tell you *what to do about it*:

| Quadrant | Importance | Performance | Action |
|----------|------------|-------------|--------|
| **Concentrate Here** | High | Low | Priority improvement |
| **Keep Up Good Work** | High | High | Maintain investment |
| **Low Priority** | Low | Low | Deprioritize |
| **Possible Overkill** | Low | High | Reduce investment |

---

## 2. Module Capabilities

### 2.1 Core Features

1. **Standard IPA Quadrant** — Derived importance vs. performance
2. **Dual Importance Quadrant** — Stated vs. derived importance comparison
3. **Gap Analysis** — Performance vs. importance gap scores
4. **Competitive IPA** — Your performance vs. competitor overlay
5. **Segment Comparison** — Multiple segment quadrants
6. **Dynamic Quadrant Lines** — Data-centered or fixed thresholds

### 2.2 Importance Sources

The module accepts importance from any KDA method:

| Source | Description |
|--------|-------------|
| `correlation` | Pearson/Spearman correlation with outcome |
| `regression` | Standardized beta coefficients |
| `relative_weights` | Johnson's relative weights |
| `shapley` | SHAP mean absolute values |
| `dominance` | General dominance statistics |
| `stated` | Direct respondent ratings |
| `custom` | User-provided importance scores |

---

## 3. R Package Dependencies

### 3.1 Core Packages

| Package | Purpose | Notes |
|---------|---------|-------|
| `ggplot2` | Primary plotting engine | Required |
| `ggrepel` | Non-overlapping labels | Essential for readability |
| `scales` | Axis formatting | Required |
| `ggforce` | Quadrant annotations | Optional enhancements |

### 3.2 Supporting Packages

| Package | Purpose |
|---------|---------|
| `dplyr` | Data manipulation |
| `tidyr` | Data reshaping |
| `purrr` | Functional programming |
| `cli` | User messages |

### 3.3 Installation

```r
install.packages(c(
    "ggplot2", "ggrepel", "scales", "ggforce",
    "dplyr", "tidyr", "purrr", "cli"
))
```

---

## 4. Architecture

### 4.1 Module Structure

```
turas/
└── R/
    └── kda_quadrant/
        ├── quadrant_main.R           # Main orchestration
        ├── quadrant_data_prep.R      # Data preparation
        ├── quadrant_calculate.R      # Importance/performance calculation
        ├── quadrant_plot.R           # Core plotting functions
        ├── quadrant_annotations.R    # Labels, zones, styling
        ├── quadrant_comparison.R     # Stated vs derived, segments
        ├── quadrant_gap.R            # Gap analysis
        └── quadrant_export.R         # Excel/PowerPoint output
```

### 4.2 Data Flow

```
┌─────────────────────────────┐
│  KDA Results                │
│  - Importance scores        │
│  - Method used              │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Performance Data           │
│  - Mean satisfaction scores │
│  - By driver                │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Quadrant Calculation       │
│  - Normalize scales         │
│  - Set thresholds           │
│  - Assign quadrants         │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Visualization              │
│  - Scatter plot             │
│  - Quadrant zones           │
│  - Labels & annotations     │
└─────────────────────────────┘
```

---

## 5. Excel Configuration Schema

### 5.1 QuadrantParameters Sheet

| Parameter | Value | Description |
|-----------|-------|-------------|
| `enable_quadrant` | TRUE | Enable quadrant analysis |
| `importance_source` | shap | Source: correlation, regression, relative_weights, shap, dominance, stated |
| `performance_variable` | mean_satisfaction | How to calculate performance |
| `threshold_method` | mean | Method: mean, median, midpoint, custom |
| `importance_threshold` | — | Custom threshold (if method = custom) |
| `performance_threshold` | — | Custom threshold (if method = custom) |
| `normalize_axes` | TRUE | Normalize to 0-100 scale |
| `show_diagonal` | FALSE | Show iso-priority diagonal line |
| `label_all_points` | TRUE | Label all drivers or top N only |
| `label_top_n` | 10 | If not labeling all, show top N |

### 5.2 QuadrantOutputs Sheet

| Output | Include | Options |
|--------|---------|---------|
| `standard_ipa` | TRUE | quadrant_colors=TRUE |
| `dual_importance` | TRUE | stated_variable="Q_importance" |
| `gap_analysis` | TRUE | sort_by="gap_desc" |
| `segment_comparison` | TRUE | facet=TRUE |
| `action_table` | TRUE | include_recommendations=TRUE |

### 5.3 QuadrantLabels Sheet (Optional Customization)

| Element | Default | Custom |
|---------|---------|--------|
| `quadrant_1_name` | Concentrate Here | Priority Actions |
| `quadrant_2_name` | Keep Up Good Work | Strengths |
| `quadrant_3_name` | Low Priority | Monitor |
| `quadrant_4_name` | Possible Overkill | Reassess |
| `x_axis_label` | Performance | Satisfaction Score |
| `y_axis_label` | Derived Importance | Impact on Loyalty |

### 5.4 StatedImportance Sheet (For Dual Importance Analysis)

| driver_variable | stated_importance_variable |
|-----------------|---------------------------|
| Q1_Price | Q1_Price_importance |
| Q2_Quality | Q2_Quality_importance |
| Q3_Service | Q3_Service_importance |

---

## 6. Function Specifications

### 6.1 Main Entry Point

```r
#' Create Quadrant Analysis
#'
#' Generates Importance-Performance Analysis quadrant charts
#'
#' @param kda_results Results from run_key_driver_analysis() or importance data frame
#' @param performance_data Data frame with performance scores by driver
#' @param config Quadrant configuration parameters
#' @param stated_importance Optional data frame with stated importance scores
#' @param segments Optional segment definitions for comparison
#'
#' @return quadrant_results S3 object containing:
#'   - data: Prepared data with quadrant assignments
#'   - plots: List of ggplot objects
#'   - action_table: Prioritized action recommendations
#'   - gap_analysis: Gap scores and rankings
#'
#' @export
create_quadrant_analysis <- function(
    kda_results,
    performance_data = NULL,
    config = list(),
    stated_importance = NULL,
    segments = NULL
) {
    
    # 1. Extract/validate importance scores
    importance <- extract_importance_scores(kda_results, config)
    
    # 2. Calculate performance scores
    performance <- calculate_performance_scores(
        kda_results, 
        performance_data, 
        config
    )
    
    # 3. Prepare quadrant data
    quad_data <- prepare_quadrant_data(importance, performance, config)
    
    # 4. Generate standard IPA plot
    plots <- list()
    plots$standard_ipa <- create_ipa_plot(quad_data, config)
    
    # 5. Dual importance analysis (if stated importance provided)
    if (!is.null(stated_importance)) {
        dual_data <- prepare_dual_importance(importance, stated_importance)
        plots$dual_importance <- create_dual_importance_plot(dual_data, config)
    }
    
    # 6. Gap analysis
    gap_data <- calculate_gap_analysis(quad_data)
    plots$gap_chart <- create_gap_chart(gap_data, config)
    
    # 7. Segment comparison (if segments provided)
    if (!is.null(segments)) {
        segment_results <- create_segment_quadrants(
            kda_results, performance_data, segments, config
        )
        plots$segment_comparison <- segment_results$plot
    }
    
    # 8. Create action table
    action_table <- create_action_table(quad_data, config)
    
    # Compile results
    results <- structure(
        list(
            data = quad_data,
            plots = plots,
            action_table = action_table,
            gap_analysis = gap_data,
            config = config
        ),
        class = "quadrant_results"
    )
    
    results
}
```

### 6.2 Importance Extraction

```r
#' Extract Importance Scores from KDA Results
#'
#' Normalizes importance scores from various KDA methods to comparable scale
#'
#' @param kda_results KDA results object or data frame
#' @param config Configuration with importance_source
#'
#' @return Data frame with driver and importance columns
#'
extract_importance_scores <- function(kda_results, config) {
    
    source <- config$importance_source %||% "auto"
    
    # If already a data frame with importance
    if (is.data.frame(kda_results) && "importance" %in% names(kda_results)) {
        imp <- kda_results[, c("driver", "importance")]
        return(normalize_importance(imp, config))
    }
    
    # Extract from KDA results object
    if (inherits(kda_results, "kda_results")) {
        
        imp <- switch(source,
            "correlation" = kda_results$correlation$importance,
            "regression" = kda_results$regression$importance,
            "relative_weights" = kda_results$relative_weights$importance,
            "shap" = kda_results$shap$importance,
            "dominance" = kda_results$dominance$importance,
            "auto" = select_best_importance(kda_results),
            stop_kda("Unknown importance source: {source}")
        )
        
        return(normalize_importance(imp, config))
    }
    
    stop_kda(
        "Cannot extract importance scores",
        "Provide kda_results object or data frame with 'driver' and 'importance' columns"
    )
}

#' Normalize Importance to 0-100 Scale
#'
#' Converts various importance metrics to common scale
#'
normalize_importance <- function(imp, config) {
    
    if (!isTRUE(config$normalize_axes)) {
        return(imp)
    }
    
    # Min-max normalization to 0-100
    min_val <- min(imp$importance, na.rm = TRUE)
    max_val <- max(imp$importance, na.rm = TRUE)
    
    if (max_val == min_val) {
        imp$importance_normalized <- 50
    } else {
        imp$importance_normalized <- 
            (imp$importance - min_val) / (max_val - min_val) * 100
    }
    
    imp
}

#' Auto-Select Best Importance Source
#'
#' Priority: SHAP > Relative Weights > Regression > Correlation
#'
select_best_importance <- function(kda_results) {
    
    if (!is.null(kda_results$shap)) {
        cli::cli_alert_info("Using SHAP importance (auto-selected)")
        return(kda_results$shap$importance)
    }
    
    if (!is.null(kda_results$relative_weights)) {
        cli::cli_alert_info("Using relative weights importance (auto-selected)")
        return(kda_results$relative_weights$importance)
    }
    
    if (!is.null(kda_results$regression)) {
        cli::cli_alert_info("Using regression importance (auto-selected)")
        return(kda_results$regression$importance)
    }
    
    if (!is.null(kda_results$correlation)) {
        cli::cli_alert_info("Using correlation importance (auto-selected)")
        return(kda_results$correlation$importance)
    }
    
    stop_kda("No importance scores found in KDA results")
}
```

### 6.3 Performance Calculation

```r
#' Calculate Performance Scores
#'
#' Computes mean satisfaction/performance for each driver
#'
#' @param kda_results KDA results containing original data
#' @param performance_data Optional pre-calculated performance
#' @param config Configuration parameters
#'
#' @return Data frame with driver and performance columns
#'
calculate_performance_scores <- function(kda_results, performance_data, config) {
    
    # If pre-calculated performance provided
    if (!is.null(performance_data)) {
        perf <- performance_data
        
        if (!all(c("driver", "performance") %in% names(perf))) {
            stop_kda(
                "performance_data must have 'driver' and 'performance' columns"
            )
        }
        
        return(normalize_performance(perf, config))
    }
    
    # Calculate from raw data
    if (!is.null(kda_results$data) && !is.null(kda_results$drivers)) {
        
        data <- kda_results$data
        drivers <- kda_results$drivers
        weights <- kda_results$weights
        
        perf <- calculate_weighted_means(data, drivers, weights)
        return(normalize_performance(perf, config))
    }
    
    stop_kda(
        "Cannot calculate performance scores",
        "Provide performance_data or ensure kda_results contains raw data"
    )
}

#' Calculate Weighted Mean Performance
#'
calculate_weighted_means <- function(data, drivers, weights = NULL) {
    
    if (is.null(weights)) {
        w <- rep(1, nrow(data))
    } else {
        w <- data[[weights]]
    }
    
    perf <- data.frame(
        driver = drivers,
        performance = sapply(drivers, function(d) {
            weighted.mean(data[[d]], w, na.rm = TRUE)
        }),
        stringsAsFactors = FALSE
    )
    
    perf
}

#' Normalize Performance to 0-100 Scale
#'
normalize_performance <- function(perf, config) {
    
    if (!isTRUE(config$normalize_axes)) {
        return(perf)
    }
    
    # If data is on known scale (e.g., 1-5, 1-10), convert appropriately
    scale_min <- config$performance_scale_min %||% min(perf$performance, na.rm = TRUE)
    scale_max <- config$performance_scale_max %||% max(perf$performance, na.rm = TRUE)
    
    perf$performance_normalized <- 
        (perf$performance - scale_min) / (scale_max - scale_min) * 100
    
    perf
}
```

### 6.4 Quadrant Data Preparation

```r
#' Prepare Quadrant Data
#'
#' Combines importance and performance, assigns quadrants
#'
#' @param importance Importance data frame
#' @param performance Performance data frame
#' @param config Configuration parameters
#'
#' @return Data frame with quadrant assignments
#'
prepare_quadrant_data <- function(importance, performance, config) {
    
    # Merge importance and performance
    quad_data <- merge(
        importance,
        performance,
        by = "driver",
        all = TRUE
    )
    
    # Use normalized values if available
    quad_data$x <- quad_data$performance_normalized %||% quad_data$performance
    quad_data$y <- quad_data$importance_normalized %||% quad_data$importance
    
    # Calculate thresholds
    thresholds <- calculate_thresholds(quad_data, config)
    quad_data$x_threshold <- thresholds$x
    quad_data$y_threshold <- thresholds$y
    
    # Assign quadrants
    quad_data$quadrant <- assign_quadrants(
        quad_data$x, 
        quad_data$y,
        thresholds$x,
        thresholds$y
    )
    
    # Add quadrant labels
    quad_data$quadrant_label <- factor(
        quad_data$quadrant,
        levels = 1:4,
        labels = c(
            config$quadrant_1_name %||% "Concentrate Here",
            config$quadrant_2_name %||% "Keep Up Good Work",
            config$quadrant_3_name %||% "Low Priority",
            config$quadrant_4_name %||% "Possible Overkill"
        )
    )
    
    # Calculate gap score (importance - performance)
    quad_data$gap <- quad_data$y - quad_data$x
    
    # Priority score (high importance + low performance = high priority)
    quad_data$priority_score <- quad_data$y * (100 - quad_data$x) / 100
    
    quad_data
}

#' Calculate Quadrant Thresholds
#'
#' Determines where to draw the quadrant lines
#'
calculate_thresholds <- function(quad_data, config) {
    
    method <- config$threshold_method %||% "mean"
    
    thresholds <- switch(method,
        
        "mean" = list(
            x = mean(quad_data$x, na.rm = TRUE),
            y = mean(quad_data$y, na.rm = TRUE)
        ),
        
        "median" = list(
            x = median(quad_data$x, na.rm = TRUE),
            y = median(quad_data$y, na.rm = TRUE)
        ),
        
        "midpoint" = list(
            x = (max(quad_data$x, na.rm = TRUE) + min(quad_data$x, na.rm = TRUE)) / 2,
            y = (max(quad_data$y, na.rm = TRUE) + min(quad_data$y, na.rm = TRUE)) / 2
        ),
        
        "custom" = list(
            x = config$performance_threshold %||% 50,
            y = config$importance_threshold %||% 50
        ),
        
        # Scale midpoint (e.g., 3 on 1-5 scale = 50 on 0-100)
        "scale_midpoint" = list(
            x = 50,
            y = 50
        ),
        
        stop_kda("Unknown threshold method: {method}")
    )
    
    thresholds
}

#' Assign Quadrant Numbers
#'
#' Quadrant numbering (standard IPA convention):
#'   2 (Keep Up) | 1 (Concentrate)
#'   -----------+-----------------
#'   4 (Overkill)| 3 (Low Priority)
#'
assign_quadrants <- function(x, y, x_thresh, y_thresh) {
    
    quadrant <- rep(NA_integer_, length(x))
    
    # Q1: High importance, Low performance (upper-left)
    quadrant[y >= y_thresh & x < x_thresh] <- 1
    
    # Q2: High importance, High performance (upper-right)
    quadrant[y >= y_thresh & x >= x_thresh] <- 2
    
    # Q3: Low importance, Low performance (lower-left)
    quadrant[y < y_thresh & x < x_thresh] <- 3
    
    # Q4: Low importance, High performance (lower-right)
    quadrant[y < y_thresh & x >= x_thresh] <- 4
    
    quadrant
}
```

### 6.5 Core IPA Plot

```r
#' Create Standard IPA Quadrant Plot
#'
#' The classic 2×2 importance-performance matrix
#'
#' @param quad_data Prepared quadrant data
#' @param config Configuration parameters
#'
#' @return ggplot object
#'
create_ipa_plot <- function(quad_data, config) {
    
    # Get thresholds
    x_thresh <- quad_data$x_threshold[1]
    y_thresh <- quad_data$y_threshold[1]
    
    # Axis labels
    x_label <- config$x_axis_label %||% "Performance"
    y_label <- config$y_axis_label %||% "Derived Importance"
    
    # Quadrant colors
    quad_colors <- config$quadrant_colors %||% c(
        "1" = "#E74C3C",  # Red - Concentrate Here
        "2" = "#27AE60",  # Green - Keep Up Good Work
        "3" = "#95A5A6",  # Gray - Low Priority
        "4" = "#F39C12"   # Orange - Possible Overkill
    )
    
    # Base plot
    p <- ggplot2::ggplot(
        quad_data,
        ggplot2::aes(x = x, y = y)
    )
    
    # Add quadrant background shading
    if (isTRUE(config$shade_quadrants)) {
        p <- p + add_quadrant_shading(quad_data, quad_colors, x_thresh, y_thresh)
    }
    
    # Add quadrant lines
    p <- p +
        ggplot2::geom_vline(
            xintercept = x_thresh,
            linetype = "dashed",
            color = "gray40",
            linewidth = 0.5
        ) +
        ggplot2::geom_hline(
            yintercept = y_thresh,
            linetype = "dashed",
            color = "gray40",
            linewidth = 0.5
        )
    
    # Add points
    p <- p +
        ggplot2::geom_point(
            ggplot2::aes(color = factor(quadrant)),
            size = 4,
            alpha = 0.8
        ) +
        ggplot2::scale_color_manual(
            values = quad_colors,
            labels = levels(quad_data$quadrant_label),
            name = "Action Zone"
        )
    
    # Add labels
    if (isTRUE(config$label_all_points)) {
        p <- p +
            ggrepel::geom_text_repel(
                ggplot2::aes(label = driver),
                size = 3,
                max.overlaps = 20,
                box.padding = 0.5,
                point.padding = 0.3,
                segment.color = "gray60",
                segment.size = 0.3
            )
    } else {
        # Label only top N by priority
        top_n <- config$label_top_n %||% 10
        top_drivers <- head(
            quad_data[order(-quad_data$priority_score), "driver"],
            top_n
        )
        
        p <- p +
            ggrepel::geom_text_repel(
                data = quad_data[quad_data$driver %in% top_drivers, ],
                ggplot2::aes(label = driver),
                size = 3,
                max.overlaps = 15,
                box.padding = 0.5
            )
    }
    
    # Add quadrant annotations
    p <- p + add_quadrant_annotations(quad_data, config, x_thresh, y_thresh)
    
    # Axis formatting
    p <- p +
        ggplot2::scale_x_continuous(
            limits = c(0, 100),
            breaks = seq(0, 100, 20),
            labels = scales::label_number()
        ) +
        ggplot2::scale_y_continuous(
            limits = c(0, 100),
            breaks = seq(0, 100, 20),
            labels = scales::label_number()
        )
    
    # Labels and theme
    p <- p +
        ggplot2::labs(
            title = "Key Driver Priority Matrix",
            subtitle = "Importance-Performance Analysis",
            x = x_label,
            y = y_label,
            caption = paste(
                "Threshold method:", config$threshold_method %||% "mean",
                "| n drivers:", nrow(quad_data)
            )
        ) +
        turas_theme() +
        ggplot2::theme(
            legend.position = "bottom",
            panel.grid.minor = ggplot2::element_blank()
        )
    
    # Add iso-priority diagonal if requested
    if (isTRUE(config$show_diagonal)) {
        p <- p +
            ggplot2::geom_abline(
                slope = 1,
                intercept = 0,
                linetype = "dotted",
                color = "gray60"
            )
    }
    
    p
}

#' Add Quadrant Background Shading
#'
add_quadrant_shading <- function(quad_data, colors, x_thresh, y_thresh) {
    
    # Create rectangles for each quadrant
    rects <- data.frame(
        quadrant = c(1, 2, 3, 4),
        xmin = c(0, x_thresh, 0, x_thresh),
        xmax = c(x_thresh, 100, x_thresh, 100),
        ymin = c(y_thresh, y_thresh, 0, 0),
        ymax = c(100, 100, y_thresh, y_thresh)
    )
    
    ggplot2::geom_rect(
        data = rects,
        ggplot2::aes(
            xmin = xmin, xmax = xmax,
            ymin = ymin, ymax = ymax,
            fill = factor(quadrant)
        ),
        alpha = 0.1,
        inherit.aes = FALSE
    ) +
        ggplot2::scale_fill_manual(
            values = colors,
            guide = "none"
        )
}

#' Add Quadrant Annotations
#'
#' Labels in corners of each quadrant
#'
add_quadrant_annotations <- function(quad_data, config, x_thresh, y_thresh) {
    
    labels <- data.frame(
        x = c(x_thresh/2, (x_thresh + 100)/2, x_thresh/2, (x_thresh + 100)/2),
        y = c((y_thresh + 100)/2, (y_thresh + 100)/2, y_thresh/2, y_thresh/2),
        label = c(
            config$quadrant_1_name %||% "CONCENTRATE\nHERE",
            config$quadrant_2_name %||% "KEEP UP\nGOOD WORK",
            config$quadrant_3_name %||% "LOW\nPRIORITY",
            config$quadrant_4_name %||% "POSSIBLE\nOVERKILL"
        ),
        quadrant = 1:4
    )
    
    # Position in corners
    labels$x <- c(5, 95, 5, 95)
    labels$y <- c(95, 95, 5, 5)
    labels$hjust <- c(0, 1, 0, 1)
    labels$vjust <- c(1, 1, 0, 0)
    
    ggplot2::geom_text(
        data = labels,
        ggplot2::aes(x = x, y = y, label = label),
        hjust = labels$hjust,
        vjust = labels$vjust,
        size = 3,
        fontface = "bold",
        color = "gray40",
        alpha = 0.7,
        inherit.aes = FALSE
    )
}
```

### 6.6 Dual Importance Plot

```r
#' Create Dual Importance Plot
#'
#' Compares stated (self-reported) vs. derived importance
#' Reveals "hidden gems" and "false priorities"
#'
#' @param dual_data Data with both stated and derived importance
#' @param config Configuration parameters
#'
#' @return ggplot object
#'
create_dual_importance_plot <- function(dual_data, config) {
    
    # Get thresholds (mean of each axis)
    x_thresh <- mean(dual_data$stated_importance, na.rm = TRUE)
    y_thresh <- mean(dual_data$derived_importance, na.rm = TRUE)
    
    # Assign interpretation zones
    dual_data$zone <- assign_dual_zones(
        dual_data$stated_importance,
        dual_data$derived_importance,
        x_thresh,
        y_thresh
    )
    
    zone_colors <- c(
        "Obvious Priority" = "#27AE60",     # High stated, high derived
        "Hidden Gem" = "#3498DB",           # Low stated, high derived
        "False Priority" = "#E74C3C",       # High stated, low derived
        "True Low Priority" = "#95A5A6"     # Low stated, low derived
    )
    
    p <- ggplot2::ggplot(
        dual_data,
        ggplot2::aes(x = stated_importance, y = derived_importance)
    ) +
        # Quadrant lines
        ggplot2::geom_vline(xintercept = x_thresh, linetype = "dashed", color = "gray40") +
        ggplot2::geom_hline(yintercept = y_thresh, linetype = "dashed", color = "gray40") +
        # Diagonal reference (stated = derived)
        ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dotted", color = "gray60") +
        # Points
        ggplot2::geom_point(
            ggplot2::aes(color = zone),
            size = 4,
            alpha = 0.8
        ) +
        ggplot2::scale_color_manual(values = zone_colors, name = "Interpretation") +
        # Labels
        ggrepel::geom_text_repel(
            ggplot2::aes(label = driver),
            size = 3,
            max.overlaps = 15
        ) +
        # Formatting
        ggplot2::labs(
            title = "Stated vs. Derived Importance",
            subtitle = "Points above diagonal: underestimated importance | Below: overestimated",
            x = "Stated Importance (self-reported)",
            y = "Derived Importance (statistical)",
            caption = "Hidden Gems = high derived, low stated | False Priorities = high stated, low derived"
        ) +
        turas_theme()
    
    p
}

#' Assign Dual Importance Zones
#'
assign_dual_zones <- function(stated, derived, x_thresh, y_thresh) {
    
    zone <- rep(NA_character_, length(stated))
    
    zone[stated >= x_thresh & derived >= y_thresh] <- "Obvious Priority"
    zone[stated < x_thresh & derived >= y_thresh] <- "Hidden Gem"
    zone[stated >= x_thresh & derived < y_thresh] <- "False Priority"
    zone[stated < x_thresh & derived < y_thresh] <- "True Low Priority"
    
    zone
}

#' Prepare Dual Importance Data
#'
prepare_dual_importance <- function(derived_importance, stated_importance) {
    
    # Merge derived and stated
    dual_data <- merge(
        derived_importance[, c("driver", "importance")],
        stated_importance,
        by = "driver",
        all = TRUE
    )
    
    names(dual_data)[names(dual_data) == "importance"] <- "derived_importance"
    
    # Normalize both to 0-100
    dual_data$derived_importance <- normalize_to_100(dual_data$derived_importance)
    dual_data$stated_importance <- normalize_to_100(dual_data$stated_importance)
    
    dual_data
}

normalize_to_100 <- function(x) {
    (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE)) * 100
}
```

### 6.7 Gap Analysis

```r
#' Calculate Gap Analysis
#'
#' Computes importance-performance gaps and ranks drivers
#'
#' @param quad_data Quadrant data
#'
#' @return Data frame with gap analysis
#'
calculate_gap_analysis <- function(quad_data) {
    
    gap_data <- quad_data[, c("driver", "x", "y", "quadrant", "quadrant_label")]
    names(gap_data)[names(gap_data) %in% c("x", "y")] <- c("performance", "importance")
    
    # Gap = Importance - Performance
    # Positive gap = underperforming relative to importance
    gap_data$gap <- gap_data$importance - gap_data$performance
    
    # Weighted gap (importance-weighted)
    gap_data$weighted_gap <- gap_data$gap * (gap_data$importance / 100)
    
    # Rank by gap (largest positive gap = highest priority)
    gap_data$gap_rank <- rank(-gap_data$gap, ties.method = "min")
    
    # Sort by gap descending
    gap_data <- gap_data[order(-gap_data$gap), ]
    
    gap_data
}

#' Create Gap Analysis Chart
#'
#' Horizontal bar chart showing performance gaps
#'
#' @param gap_data Gap analysis data
#' @param config Configuration
#'
#' @return ggplot object
#'
create_gap_chart <- function(gap_data, config) {
    
    # Color by gap direction
    gap_data$gap_direction <- ifelse(gap_data$gap >= 0, "Underperforming", "Overperforming")
    
    p <- ggplot2::ggplot(
        gap_data,
        ggplot2::aes(
            x = reorder(driver, gap),
            y = gap,
            fill = gap_direction
        )
    ) +
        ggplot2::geom_col(alpha = 0.8) +
        ggplot2::geom_hline(yintercept = 0, color = "gray40") +
        ggplot2::coord_flip() +
        ggplot2::scale_fill_manual(
            values = c(
                "Underperforming" = "#E74C3C",
                "Overperforming" = "#27AE60"
            ),
            name = NULL
        ) +
        ggplot2::labs(
            title = "Importance-Performance Gap Analysis",
            subtitle = "Positive gap = performance below importance level",
            x = NULL,
            y = "Gap (Importance − Performance)",
            caption = "Priority: Address largest positive gaps first"
        ) +
        turas_theme()
    
    p
}
```

### 6.8 Action Table Generation

```r
#' Create Action Table
#'
#' Prioritized list of drivers with recommended actions
#'
#' @param quad_data Quadrant data
#' @param config Configuration
#'
#' @return Data frame with actions
#'
create_action_table <- function(quad_data, config) {
    
    action_table <- quad_data[, c(
        "driver", 
        "quadrant", 
        "quadrant_label",
        "importance" = "y",
        "performance" = "x",
        "gap",
        "priority_score"
    )]
    
    # Add recommended actions
    action_table$action <- sapply(action_table$quadrant, function(q) {
        switch(as.character(q),
            "1" = "IMPROVE: High importance, low performance. Priority investment needed.",
            "2" = "MAINTAIN: High importance, high performance. Protect current investment.",
            "3" = "MONITOR: Low importance, low performance. Low priority unless trending.",
            "4" = "REASSESS: Low importance, high performance. Consider reallocating resources."
        )
    })
    
    # Sort by priority
    action_table <- action_table[order(-action_table$priority_score), ]
    
    # Add priority rank
    action_table$priority_rank <- seq_len(nrow(action_table))
    
    # Round numeric columns
    numeric_cols <- c("importance", "performance", "gap", "priority_score")
    action_table[numeric_cols] <- lapply(action_table[numeric_cols], round, 1)
    
    # Reorder columns
    action_table <- action_table[, c(
        "priority_rank",
        "driver",
        "quadrant_label",
        "importance",
        "performance",
        "gap",
        "action"
    )]
    
    names(action_table) <- c(
        "Priority",
        "Driver",
        "Zone",
        "Importance",
        "Performance",
        "Gap",
        "Recommended Action"
    )
    
    action_table
}
```

### 6.9 Segment Comparison

```r
#' Create Segment Quadrant Comparison
#'
#' Side-by-side or faceted quadrants for different segments
#'
#' @param kda_results KDA results
#' @param performance_data Performance data
#' @param segments Segment definitions
#' @param config Configuration
#'
#' @return List with segment quadrant data and plots
#'
create_segment_quadrants <- function(kda_results, performance_data, segments, config) {
    
    segment_results <- list()
    
    # Calculate quadrant data for each segment
    for (i in seq_len(nrow(segments))) {
        
        seg_name <- segments$segment_name[i]
        seg_var <- segments$segment_variable[i]
        seg_vals <- strsplit(segments$segment_values[i], ",\\s*")[[1]]
        
        # Filter data to segment
        seg_data <- kda_results$data[kda_results$data[[seg_var]] %in% seg_vals, ]
        
        # Recalculate importance for segment
        seg_kda <- recalculate_kda_for_segment(kda_results, seg_data, config)
        
        # Recalculate performance for segment
        seg_perf <- calculate_weighted_means(
            seg_data,
            kda_results$drivers,
            kda_results$weights
        )
        
        # Prepare quadrant data
        seg_quad <- prepare_quadrant_data(
            seg_kda$importance,
            seg_perf,
            config
        )
        seg_quad$segment <- seg_name
        
        segment_results[[seg_name]] <- seg_quad
    }
    
    # Combine all segments
    all_segments <- do.call(rbind, segment_results)
    
    # Create faceted comparison plot
    plot <- ggplot2::ggplot(
        all_segments,
        ggplot2::aes(x = x, y = y, color = factor(quadrant))
    ) +
        ggplot2::geom_vline(
            ggplot2::aes(xintercept = x_threshold),
            linetype = "dashed",
            color = "gray40"
        ) +
        ggplot2::geom_hline(
            ggplot2::aes(yintercept = y_threshold),
            linetype = "dashed",
            color = "gray40"
        ) +
        ggplot2::geom_point(size = 3, alpha = 0.8) +
        ggrepel::geom_text_repel(
            ggplot2::aes(label = driver),
            size = 2.5,
            max.overlaps = 10
        ) +
        ggplot2::facet_wrap(~ segment, ncol = 2) +
        ggplot2::scale_color_manual(
            values = c(
                "1" = "#E74C3C",
                "2" = "#27AE60",
                "3" = "#95A5A6",
                "4" = "#F39C12"
            ),
            guide = "none"
        ) +
        ggplot2::labs(
            title = "Driver Priority by Segment",
            subtitle = "Quadrant positions may shift across customer groups",
            x = "Performance",
            y = "Derived Importance"
        ) +
        turas_theme()
    
    list(
        data = all_segments,
        plot = plot,
        segment_data = segment_results
    )
}
```

---

## 7. Output Specifications

### 7.1 Excel Output

#### Sheet: Quadrant_Summary

| Driver | Importance | Performance | Gap | Quadrant | Action |
|--------|------------|-------------|-----|----------|--------|
| Q5_Quality | 85.2 | 62.3 | 22.9 | Concentrate Here | IMPROVE |
| Q3_Price | 78.4 | 81.2 | -2.8 | Keep Up Good Work | MAINTAIN |
| Q8_Speed | 45.2 | 38.7 | 6.5 | Low Priority | MONITOR |
| Q2_Support | 32.1 | 78.9 | -46.8 | Possible Overkill | REASSESS |

#### Sheet: Dual_Importance (if enabled)

| Driver | Stated_Importance | Derived_Importance | Zone | Insight |
|--------|-------------------|-------------------|------|---------|
| Q5_Quality | 45.0 | 85.2 | Hidden Gem | Undervalued by customers |
| Q3_Price | 92.0 | 35.4 | False Priority | Overemphasized |

#### Sheet: Gap_Analysis

| Rank | Driver | Importance | Performance | Gap | Weighted_Gap |
|------|--------|------------|-------------|-----|--------------|
| 1 | Q5_Quality | 85.2 | 62.3 | 22.9 | 19.5 |
| 2 | Q7_Reliability | 72.1 | 55.8 | 16.3 | 11.7 |

### 7.2 Chart Outputs

| Chart | Filename | Description |
|-------|----------|-------------|
| Standard IPA | `quadrant_ipa.png` | Main 2×2 matrix |
| Dual Importance | `quadrant_dual.png` | Stated vs derived |
| Gap Analysis | `quadrant_gap.png` | Horizontal bar chart |
| Segment Comparison | `quadrant_segments.png` | Faceted by segment |

---

## 8. Theme and Styling

```r
#' turas Quadrant Theme
#'
#' Extends base turas theme for quadrant charts
#'
turas_quadrant_theme <- function() {
    
    turas_theme() +
        ggplot2::theme(
            # Square aspect ratio for quadrant
            aspect.ratio = 1,
            
            # Panel styling
            panel.border = ggplot2::element_rect(
                color = "gray80",
                fill = NA,
                linewidth = 0.5
            ),
            
            # Legend at bottom
            legend.position = "bottom",
            legend.direction = "horizontal",
            
            # Axis styling
            axis.line = ggplot2::element_blank()
        )
}

#' Quadrant Color Palettes
#'
turas_quadrant_colors <- function(style = "default") {
    
    switch(style,
        "default" = c(
            "1" = "#E74C3C",  # Red - Concentrate
            "2" = "#27AE60",  # Green - Maintain
            "3" = "#95A5A6",  # Gray - Low Priority
            "4" = "#F39C12"   # Orange - Overkill
        ),
        "traffic_light" = c(
            "1" = "#DC3545",  # Red
            "2" = "#28A745",  # Green
            "3" = "#6C757D",  # Gray
            "4" = "#FFC107"   # Yellow
        ),
        "blue_scale" = c(
            "1" = "#08519C",  # Dark blue
            "2" = "#3182BD",  # Medium blue
            "3" = "#9ECAE1",  # Light blue
            "4" = "#DEEBF7"   # Very light blue
        )
    )
}
```

---

## 9. Usage Examples

### 9.1 Basic Usage

```r
# After running KDA
kda_results <- run_key_driver_analysis("config.xlsx")

# Create quadrant analysis
quadrant <- create_quadrant_analysis(
    kda_results = kda_results,
    config = list(
        importance_source = "shap",
        threshold_method = "mean",
        shade_quadrants = TRUE
    )
)

# View main plot
print(quadrant$plots$standard_ipa)

# View action table
print(quadrant$action_table)

# Export results
export_quadrant_results(quadrant, output_dir = "outputs/")
```

### 9.2 With Stated Importance

```r
# Load stated importance from survey
stated <- data.frame(
    driver = c("Q1_Price", "Q2_Quality", "Q3_Service"),
    stated_importance = c(4.2, 3.8, 4.5)  # Mean importance ratings
)

quadrant <- create_quadrant_analysis(
    kda_results = kda_results,
    stated_importance = stated,
    config = list(
        importance_source = "shap"
    )
)

# View dual importance plot
print(quadrant$plots$dual_importance)
```

### 9.3 With Segments

```r
segments <- data.frame(
    segment_name = c("Promoters", "Passives", "Detractors"),
    segment_variable = rep("nps_group", 3),
    segment_values = c("Promoter", "Passive", "Detractor")
)

quadrant <- create_quadrant_analysis(
    kda_results = kda_results,
    segments = segments
)

# View segment comparison
print(quadrant$plots$segment_comparison)
```

---

## 10. Integration with KDA Module

### 10.1 Configuration Integration

Add to OutputSpecification sheet:

| output_type | include | format_options |
|-------------|---------|----------------|
| quadrant_ipa | TRUE | shade=TRUE, labels=all |
| quadrant_dual | TRUE | — |
| quadrant_gap | TRUE | sort=desc |
| action_table | TRUE | include_actions=TRUE |

### 10.2 Automatic Execution

When `enable_quadrant = TRUE` in ProjectSetup, the quadrant analysis runs automatically after KDA methods complete:

```r
# In run_key_driver_analysis()
if (config$enable_quadrant) {
    results$quadrant <- create_quadrant_analysis(
        kda_results = results,
        config = config$quadrant_params
    )
}
```

---

## 11. Error Handling

```r
#' Validate Quadrant Inputs
#'
validate_quadrant_inputs <- function(importance, performance) {
    
    # Check drivers match
    imp_drivers <- importance$driver
    perf_drivers <- performance$driver
    
    missing_perf <- setdiff(imp_drivers, perf_drivers)
    if (length(missing_perf) > 0) {
        warn_kda(
            "Drivers missing from performance data",
            c(
                "Missing: {paste(missing_perf, collapse = ', ')}",
                "These will be excluded from quadrant analysis"
            )
        )
    }
    
    # Check for valid values
    if (any(is.na(importance$importance))) {
        warn_kda("NA values in importance scores - these drivers will be excluded")
    }
    
    if (any(is.na(performance$performance))) {
        warn_kda("NA values in performance scores - these drivers will be excluded")
    }
    
    # Check minimum drivers
    n_valid <- sum(
        !is.na(importance$importance) & 
        importance$driver %in% performance$driver
    )
    
    if (n_valid < 4) {
        stop_kda(
            "Insufficient drivers for quadrant analysis",
            c(
                "Found: {n_valid} valid drivers",
                "Required: >= 4 drivers"
            )
        )
    }
    
    invisible(TRUE)
}
```

---

## 12. Appendix: Interpretation Guide

### A. Reading the Standard IPA Chart

**Quadrant 1 - Concentrate Here (Upper Left)**
- High importance to customers
- Currently underperforming
- **Action:** Prioritize improvement investments

**Quadrant 2 - Keep Up Good Work (Upper Right)**
- High importance to customers
- Currently performing well
- **Action:** Maintain current resource levels

**Quadrant 3 - Low Priority (Lower Left)**
- Low importance to customers
- Currently underperforming
- **Action:** Do not prioritize; monitor for changes

**Quadrant 4 - Possible Overkill (Lower Right)**
- Low importance to customers
- Currently performing well
- **Action:** Consider reallocating resources to Q1

### B. Reading the Dual Importance Chart

**Above the diagonal:** Derived importance > Stated importance
- Customers undervalue this driver
- **Hidden gems** - addressing these creates unexpected delight

**Below the diagonal:** Stated importance > Derived importance
- Customers overvalue this driver
- **False priorities** - customers say it matters but behavior shows otherwise

### C. Reading the Gap Chart

- **Large positive gaps:** Performance significantly below importance level → Urgent improvement needed
- **Small gaps (near zero):** Performance matches importance → Balanced
- **Negative gaps:** Performance exceeds importance level → Possible over-investment

---

*End of Specification*
