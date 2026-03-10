# ==============================================================================
# GENERATE SYNTHETIC CONJOINT TEST DATA
# ==============================================================================
#
# Purpose: Create reproducible synthetic data for conjoint module testing
# Version: 3.0.0
# Date: 2026-03-10
#
# Generates:
#   - Choice-based conjoint data with known utilities
#   - Rating-based conjoint data
#   - Best-worst scaling data
#   - Multi-segment (latent class) data
#
# ==============================================================================

#' Generate Synthetic CBC Data
#'
#' Creates choice-based conjoint data with known true utilities.
#' The data follows MNL assumptions (IID Gumbel errors).
#'
#' @param n_respondents Number of respondents
#' @param n_tasks Number of choice tasks per respondent
#' @param n_alts Number of alternatives per task
#' @param attributes Named list of attribute levels
#' @param true_utilities Named numeric vector of true part-worth utilities
#' @param seed Random seed for reproducibility
#' @return List with data (data frame), true_utilities, config
generate_synthetic_cbc <- function(n_respondents = 100,
                                    n_tasks = 8,
                                    n_alts = 3,
                                    attributes = NULL,
                                    true_utilities = NULL,
                                    seed = 42) {
  set.seed(seed)


  # Default attributes
  if (is.null(attributes)) {
    attributes <- list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Price = c("$10", "$20", "$30"),
      Size  = c("Small", "Medium", "Large"),
      Color = c("Red", "Blue")
    )
  }

  # Default true utilities (first level = baseline = 0)
  if (is.null(true_utilities)) {
    true_utilities <- c(
      # Brand: Alpha=0(base), Beta=0.8, Gamma=-0.3
      "BrandBeta"  = 0.8,
      "BrandGamma" = -0.3,
      # Price: $10=0(base), $20=-0.5, $30=-1.2
      "Price$20"   = -0.5,
      "Price$30"   = -1.2,
      # Size: Small=0(base), Medium=0.4, Large=0.6
      "SizeMedium" = 0.4,
      "SizeLarge"  = 0.6,
      # Color: Red=0(base), Blue=0.2
      "ColorBlue"  = 0.2
    )
  }

  # Generate design matrix
  n_rows <- n_respondents * n_tasks * n_alts
  rows <- vector("list", n_rows)
  idx <- 0

  for (r in seq_len(n_respondents)) {
    for (t in seq_len(n_tasks)) {
      for (a in seq_len(n_alts)) {
        idx <- idx + 1
        row <- list(
          resp_id = r,
          task_id = (r - 1) * n_tasks + t,
          alt_id  = a
        )
        # Random attribute levels
        for (attr_name in names(attributes)) {
          lvls <- attributes[[attr_name]]
          row[[attr_name]] <- sample(lvls, 1)
        }
        rows[[idx]] <- row
      }
    }
  }

  data <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))

  # Calculate deterministic utility per alternative
  data$V <- 0
  for (attr_name in names(attributes)) {
    lvls <- attributes[[attr_name]]
    baseline <- lvls[1]
    for (i in 2:length(lvls)) {
      coef_name <- paste0(attr_name, lvls[i])
      if (coef_name %in% names(true_utilities)) {
        data$V <- data$V + (data[[attr_name]] == lvls[i]) * true_utilities[coef_name]
      }
    }
  }

  # Add Gumbel error and simulate choice
  data$epsilon <- -log(-log(runif(n_rows)))
  data$U <- data$V + data$epsilon

  # Choose max utility within each task
  data$chosen <- 0
  tasks <- unique(data$task_id)
  for (tid in tasks) {
    task_rows <- which(data$task_id == tid)
    best <- task_rows[which.max(data$U[task_rows])]
    data$chosen[best] <- 1
  }

  # Remove internal columns
  data$V <- NULL
  data$epsilon <- NULL
  data$U <- NULL

  # Build config
  attr_df <- data.frame(
    AttributeName = names(attributes),
    NumLevels = sapply(attributes, length),
    LevelNames = sapply(attributes, paste, collapse = ","),
    stringsAsFactors = FALSE
  )

  config <- list(
    respondent_id_column = "resp_id",
    choice_set_column    = "task_id",
    alternative_id_column = "alt_id",
    chosen_column        = "chosen",
    estimation_method    = "auto",
    analysis_type        = "choice",
    attributes           = attr_df,
    attribute_levels     = attributes,
    confidence_level     = 0.95,
    n_alternatives       = n_alts
  )

  list(
    data = data,
    true_utilities = true_utilities,
    config = config,
    attributes = attributes,
    n_respondents = n_respondents,
    n_tasks = n_tasks,
    n_alts = n_alts
  )
}


#' Generate Two-Segment Synthetic Data (for LC testing)
#'
#' Creates data where ~50% of respondents value Brand highly and ~50% value Size.
#'
#' @param n_respondents Number of respondents
#' @param seed Random seed
#' @return List with data, segment_assignments, config
generate_two_segment_data <- function(n_respondents = 200, seed = 42) {
  set.seed(seed)

  attributes <- list(
    Brand = c("Alpha", "Beta", "Gamma"),
    Price = c("$10", "$20", "$30"),
    Size  = c("Small", "Medium", "Large")
  )

  n_tasks <- 8
  n_alts  <- 3
  segment <- sample(c(1, 2), n_respondents, replace = TRUE)

  # Segment 1: Brand-driven
  utils_seg1 <- c(BrandBeta = 1.5, BrandGamma = -0.5, `Price$20` = -0.3, `Price$30` = -0.6, SizeMedium = 0.1, SizeLarge = 0.2)
  # Segment 2: Size-driven
  utils_seg2 <- c(BrandBeta = 0.2, BrandGamma = -0.1, `Price$20` = -0.4, `Price$30` = -0.8, SizeMedium = 1.0, SizeLarge = 1.5)

  all_rows <- list()
  idx <- 0

  for (r in seq_len(n_respondents)) {
    seg_utils <- if (segment[r] == 1) utils_seg1 else utils_seg2
    for (t in seq_len(n_tasks)) {
      task_rows <- list()
      for (a in seq_len(n_alts)) {
        idx <- idx + 1
        row <- list(resp_id = r, task_id = (r - 1) * n_tasks + t, alt_id = a)
        V <- 0
        for (attr_name in names(attributes)) {
          lvls <- attributes[[attr_name]]
          row[[attr_name]] <- sample(lvls, 1)
          for (i in 2:length(lvls)) {
            coef_name <- paste0(attr_name, lvls[i])
            if (coef_name %in% names(seg_utils)) {
              V <- V + (row[[attr_name]] == lvls[i]) * seg_utils[coef_name]
            }
          }
        }
        row$V <- V
        task_rows[[a]] <- row
      }

      # Simulate choice with Gumbel error
      Vs <- sapply(task_rows, function(x) x$V)
      eps <- -log(-log(runif(n_alts)))
      Us <- Vs + eps
      winner <- which.max(Us)

      for (a in seq_len(n_alts)) {
        task_rows[[a]]$chosen <- as.integer(a == winner)
        task_rows[[a]]$V <- NULL
        all_rows[[length(all_rows) + 1]] <- as.data.frame(task_rows[[a]], stringsAsFactors = FALSE)
      }
    }
  }

  data <- do.call(rbind, all_rows)

  attr_df <- data.frame(
    AttributeName = names(attributes),
    NumLevels = sapply(attributes, length),
    LevelNames = sapply(attributes, paste, collapse = ","),
    stringsAsFactors = FALSE
  )

  config <- list(
    respondent_id_column  = "resp_id",
    choice_set_column     = "task_id",
    alternative_id_column = "alt_id",
    chosen_column         = "chosen",
    estimation_method     = "latent_class",
    analysis_type         = "choice",
    attributes            = attr_df,
    attribute_levels      = attributes,
    confidence_level      = 0.95,
    n_alternatives        = n_alts,
    latent_class_min      = 2,
    latent_class_max      = 4,
    hb_iterations         = 2000,
    hb_burnin             = 500,
    hb_thin               = 1
  )

  list(
    data = data,
    segment_assignments = segment,
    config = config,
    true_utils_seg1 = utils_seg1,
    true_utils_seg2 = utils_seg2
  )
}


#' Generate Best-Worst Data
#'
#' @param n_respondents Number of respondents
#' @param n_tasks Number of tasks per respondent
#' @param seed Random seed
#' @return List with data, config
generate_bws_data <- function(n_respondents = 50, n_tasks = 8, seed = 42) {
  set.seed(seed)

  attributes <- list(
    Brand = c("Alpha", "Beta", "Gamma"),
    Price = c("$10", "$20", "$30")
  )

  true_utils <- c(BrandBeta = 0.8, BrandGamma = -0.5, `Price$20` = -0.4, `Price$30` = -1.0)
  n_alts <- 3

  all_rows <- list()
  for (r in seq_len(n_respondents)) {
    for (t in seq_len(n_tasks)) {
      task_rows <- list()
      for (a in seq_len(n_alts)) {
        row <- list(
          resp_id = r,
          choice_set_id = (r - 1) * n_tasks + t,
          alt_id = a,
          best = 0L,
          worst = 0L
        )
        V <- 0
        for (attr_name in names(attributes)) {
          lvls <- attributes[[attr_name]]
          row[[attr_name]] <- sample(lvls, 1)
          for (i in 2:length(lvls)) {
            cn <- paste0(attr_name, lvls[i])
            if (cn %in% names(true_utils)) V <- V + (row[[attr_name]] == lvls[i]) * true_utils[cn]
          }
        }
        row$V <- V
        task_rows[[a]] <- row
      }

      Vs <- sapply(task_rows, function(x) x$V)
      eps <- -log(-log(runif(n_alts)))
      Us <- Vs + eps
      best_idx  <- which.max(Us)
      worst_idx <- which.min(Us)

      for (a in seq_len(n_alts)) {
        task_rows[[a]]$best  <- as.integer(a == best_idx)
        task_rows[[a]]$worst <- as.integer(a == worst_idx)
        task_rows[[a]]$V <- NULL
        all_rows[[length(all_rows) + 1]] <- as.data.frame(task_rows[[a]], stringsAsFactors = FALSE)
      }
    }
  }

  data <- do.call(rbind, all_rows)

  config <- list(
    respondent_id_column  = "resp_id",
    choice_set_column     = "choice_set_id",
    alternative_id_column = "alt_id",
    chosen_column         = "chosen",
    estimation_method     = "best_worst",
    analysis_type         = "choice",
    bw_method             = "sequential",
    attributes            = data.frame(
      AttributeName = names(attributes),
      NumLevels = sapply(attributes, length),
      LevelNames = sapply(attributes, paste, collapse = ","),
      stringsAsFactors = FALSE
    ),
    attribute_levels      = attributes,
    confidence_level      = 0.95,
    n_alternatives        = n_alts
  )

  list(
    data = data,
    true_utilities = true_utils,
    config = config
  )
}


#' Generate Utilities Data Frame (for simulator/WTP/optimizer tests)
#'
#' @param with_price Include a price attribute for WTP testing
#' @return Data frame with Attribute, Level, Utility, SE, is_baseline columns
generate_utilities_df <- function(with_price = TRUE) {

  rows <- list(
    data.frame(Attribute = "Brand", Level = "Alpha", Utility = 0,    SE = 0,    is_baseline = TRUE,  stringsAsFactors = FALSE),
    data.frame(Attribute = "Brand", Level = "Beta",  Utility = 0.8,  SE = 0.12, is_baseline = FALSE, stringsAsFactors = FALSE),
    data.frame(Attribute = "Brand", Level = "Gamma", Utility = -0.3, SE = 0.11, is_baseline = FALSE, stringsAsFactors = FALSE),
    data.frame(Attribute = "Size",  Level = "Small", Utility = 0,    SE = 0,    is_baseline = TRUE,  stringsAsFactors = FALSE),
    data.frame(Attribute = "Size",  Level = "Medium",Utility = 0.4,  SE = 0.10, is_baseline = FALSE, stringsAsFactors = FALSE),
    data.frame(Attribute = "Size",  Level = "Large", Utility = 0.6,  SE = 0.09, is_baseline = FALSE, stringsAsFactors = FALSE)
  )

  if (with_price) {
    rows <- c(rows, list(
      data.frame(Attribute = "Price", Level = "$10", Utility = 0,    SE = 0,    is_baseline = TRUE,  stringsAsFactors = FALSE),
      data.frame(Attribute = "Price", Level = "$20", Utility = -0.5, SE = 0.08, is_baseline = FALSE, stringsAsFactors = FALSE),
      data.frame(Attribute = "Price", Level = "$30", Utility = -1.2, SE = 0.10, is_baseline = FALSE, stringsAsFactors = FALSE)
    ))
  }

  do.call(rbind, rows)
}


#' Generate Importance Data Frame
#'
#' @param with_price Include price attribute
#' @return Data frame with Attribute, Importance columns
generate_importance_df <- function(with_price = TRUE) {
  attrs <- c("Brand", "Size")
  imps  <- c(40, 25)
  if (with_price) {
    attrs <- c(attrs, "Price")
    imps  <- c(imps, 35)
  }
  data.frame(Attribute = attrs, Importance = imps, stringsAsFactors = FALSE)
}


message("TURAS>Conjoint synthetic data generators loaded (v3.0.0)")
