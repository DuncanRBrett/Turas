# ============================================================================
# TURAS CROSSTABS - INTERACTIVE GUI LAUNCHER (TCLTK VERSION)
# ============================================================================
# Simple cross-platform GUI for running Turas crosstabs analysis
# 
# FEATURES:
#   - Browse to select project directory
#   - Auto-detect available config files
#   - One-click execution
#   - Recent projects memory
#
# REQUIREMENTS:
#   - tcltk package (built into base R)
#   - On Mac: XQuartz may be required (https://www.xquartz.org)
#
# USAGE:
#   source("turas_launcher_tcltk.R")
# ============================================================================

# Check TclTk availability
if (!requireNamespace("tcltk", quietly = TRUE)) {
  stop("TclTk package not available. This should be built into R.\n",
       "On Mac, you may need to install XQuartz: https://www.xquartz.org",
       call. = FALSE)
}

# Try to load TclTk
tcltk_loaded <- tryCatch({
  library(tcltk)
  TRUE
}, error = function(e) {
  cat("\n")
  cat("ERROR: Could not load TclTk.\n")
  cat(e$message, "\n\n")
  
  if (Sys.info()["sysname"] == "Darwin") {
    cat("On Mac, TclTk requires XQuartz.\n")
    cat("1. Download from: https://www.xquartz.org\n")
    cat("2. Install XQuartz\n")
    cat("3. Restart R\n")
    cat("4. Try again\n\n")
    cat("Alternatively, use the Shiny version:\n")
    cat('  source("', file.path(dirname(sys.frame(1)$ofile), "turas_launcher_shiny.R"), '")\n\n', sep = "")
  }
  
  FALSE
})

if (!tcltk_loaded) {
  stop("TclTk not available", call. = FALSE)
}

# === CONFIGURATION ===
TURAS_HOME <- "/Users/duncan/Documents/Turas"
RECENT_PROJECTS_FILE <- file.path(TURAS_HOME, ".recent_projects.rds")
MAX_RECENT_PROJECTS <- 10

# === HELPER FUNCTIONS ===

#' Load recent projects from file
load_recent_projects <- function() {
  if (file.exists(RECENT_PROJECTS_FILE)) {
    tryCatch({
      readRDS(RECENT_PROJECTS_FILE)
    }, error = function(e) {
      character(0)
    })
  } else {
    character(0)
  }
}

#' Save recent projects to file
save_recent_projects <- function(recent_projects) {
  tryCatch({
    saveRDS(recent_projects, RECENT_PROJECTS_FILE)
  }, error = function(e) {
    warning("Could not save recent projects: ", e$message)
  })
}

#' Add project to recent list
add_to_recent <- function(project_dir, recent_projects) {
  # Remove if already exists (will add to front)
  recent_projects <- recent_projects[recent_projects != project_dir]
  
  # Add to front
  recent_projects <- c(project_dir, recent_projects)
  
  # Keep only MAX_RECENT_PROJECTS
  if (length(recent_projects) > MAX_RECENT_PROJECTS) {
    recent_projects <- recent_projects[1:MAX_RECENT_PROJECTS]
  }
  
  recent_projects
}

#' Detect available config files in project directory
detect_config_files <- function(project_dir) {
  if (!dir.exists(project_dir)) {
    return(character(0))
  }
  
  config_files <- c()
  
  # Check for standard config files
  if (file.exists(file.path(project_dir, "Crosstab_Config.xlsx"))) {
    config_files <- c(config_files, "Crosstab_Config.xlsx")
  }
  
  if (file.exists(file.path(project_dir, "Survey_Structure.xlsx"))) {
    config_files <- c(config_files, "Survey_Structure.xlsx")
  }
  
  # Also check for any other xlsx files that might be configs
  all_xlsx <- list.files(project_dir, pattern = "\\.xlsx$", full.names = FALSE)
  other_configs <- setdiff(all_xlsx, config_files)
  
  if (length(other_configs) > 0) {
    config_files <- c(config_files, other_configs)
  }
  
  config_files
}

#' Run the analysis
run_analysis <- function(project_dir, config_filename, gui_window = NULL) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("TURAS CROSSTABS ANALYSIS\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")
  
  cat("Project:", basename(project_dir), "\n")
  cat("Config:", config_filename, "\n")
  cat("Path:", project_dir, "\n\n")
  
  # Close GUI window if provided
  if (!is.null(gui_window)) {
    tryCatch(tkdestroy(gui_window), error = function(e) {})
  }
  
  # Set working directory
  setwd(project_dir)
  cat("Working directory:", getwd(), "\n\n")
  
  # CRITICAL: Set config_file in global env for run_crosstabs.R
  assign("config_file", config_filename, envir = .GlobalEnv)
  
  # Point to Turas installation
  toolkit_path <- file.path(TURAS_HOME, "modules/tabs/lib/run_crosstabs.R")
  
  if (!file.exists(toolkit_path)) {
    stop("Turas toolkit not found at: ", toolkit_path, 
         "\nPlease check TURAS_HOME in this script.")
  }
  
  # Run analysis
  cat("Starting analysis...\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  
  # CRITICAL: Assign toolkit_path to global env so run_crosstabs.R can find its dependencies
  assign("toolkit_path", toolkit_path, envir = .GlobalEnv)
  
  tryCatch({
    source(toolkit_path, local = FALSE)  # Source in global env
    cat("\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    cat("✓ ANALYSIS COMPLETE\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
  }, error = function(e) {
    cat("\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    cat("✗ ERROR:\n")
    cat(e$message, "\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
  }, finally = {
    # Clean up
    if (exists("toolkit_path", envir = .GlobalEnv)) {
      rm(toolkit_path, envir = .GlobalEnv)
    }
    if (exists("config_file", envir = .GlobalEnv)) {
      rm(config_file, envir = .GlobalEnv)
    }
  })
}

# === MAIN GUI ===

#' Launch the Turas Crosstabs GUI
launch_turas_gui <- function() {
  
  # Load recent projects
  recent_projects <- load_recent_projects()
  
  # Create main window
  tt <- tktoplevel()
  tkwm.title(tt, "Turas Crosstabs Launcher")
  tkwm.geometry(tt, "600x500")
  
  # Variables
  project_dir_var <- tclVar("")
  config_file_var <- tclVar("")
  available_configs <- tclVar("")
  
  # === HEADER ===
  header_frame <- tkframe(tt, borderwidth = 2, relief = "groove")
  tkpack(header_frame, fill = "x", padx = 10, pady = 10)
  
  title_label <- tklabel(header_frame, text = "TURAS CROSSTABS", 
                         font = tkfont.create(family = "Helvetica", size = 16, weight = "bold"))
  tkpack(title_label, pady = 5)
  
  subtitle_label <- tklabel(header_frame, text = "Interactive Analysis Launcher",
                           font = tkfont.create(family = "Helvetica", size = 10))
  tkpack(subtitle_label)
  
  # === PROJECT SELECTION ===
  project_frame <- tkframe(tt, borderwidth = 2, relief = "groove")
  tkpack(project_frame, fill = "both", expand = TRUE, padx = 10, pady = 10)
  
  project_label <- tklabel(project_frame, text = "1. Select Project Directory",
                          font = tkfont.create(family = "Helvetica", size = 11, weight = "bold"))
  tkpack(project_label, anchor = "w", padx = 5, pady = 5)
  
  # Browse button
  browse_frame <- tkframe(project_frame)
  tkpack(browse_frame, fill = "x", padx = 5, pady = 5)
  
  browse_button <- tkbutton(browse_frame, text = "Browse...", command = function() {
    dir_choice <- tk_choose.dir(default = tclvalue(project_dir_var), 
                                caption = "Select Project Directory")
    if (!is.na(dir_choice) && nchar(dir_choice) > 0) {
      tclvalue(project_dir_var) <- dir_choice
      
      # Update config options
      configs <- detect_config_files(dir_choice)
      if (length(configs) > 0) {
        tkconfigure(config_combo, values = configs)
        tclvalue(config_file_var) <- configs[1]
        tclvalue(available_configs) <- paste("Found", length(configs), "config file(s)")
      } else {
        tkconfigure(config_combo, values = "")
        tclvalue(config_file_var) <- ""
        tclvalue(available_configs) <- "No config files found"
      }
    }
  })
  tkpack(browse_button, side = "left", padx = 5)
  
  project_path_label <- tklabel(browse_frame, textvariable = project_dir_var,
                                foreground = "blue", anchor = "w")
  tkpack(project_path_label, side = "left", fill = "x", expand = TRUE, padx = 5)
  
  # Recent projects
  if (length(recent_projects) > 0) {
    recent_label <- tklabel(project_frame, text = "Recent Projects:",
                           font = tkfont.create(family = "Helvetica", size = 9))
    tkpack(recent_label, anchor = "w", padx = 5, pady = c(10, 2))
    
    recent_frame <- tkframe(project_frame, borderwidth = 1, relief = "sunken")
    tkpack(recent_frame, fill = "both", expand = TRUE, padx = 5, pady = 5)
    
    # Create scrollbar
    yscr <- tkscrollbar(recent_frame, orient = "vertical",
                       command = function(...) tkyview(recent_listbox, ...))
    
    recent_listbox <- tklistbox(recent_frame, height = 5, selectmode = "single",
                               yscrollcommand = function(...) tkset(yscr, ...),
                               exportselection = FALSE)
    
    tkpack(yscr, side = "right", fill = "y")
    tkpack(recent_listbox, side = "left", fill = "both", expand = TRUE)
    
    # Populate listbox
    for (proj in recent_projects) {
      tkinsert(recent_listbox, "end", basename(proj))
    }
    
    # Bind selection
    tkbind(recent_listbox, "<<ListboxSelect>>", function() {
      selection <- as.integer(tkcurselection(recent_listbox)) + 1
      if (length(selection) > 0) {
        selected_proj <- recent_projects[selection]
        tclvalue(project_dir_var) <- selected_proj
        
        # Update config options
        configs <- detect_config_files(selected_proj)
        if (length(configs) > 0) {
          tkconfigure(config_combo, values = configs)
          tclvalue(config_file_var) <- configs[1]
          tclvalue(available_configs) <- paste("Found", length(configs), "config file(s)")
        } else {
          tkconfigure(config_combo, values = "")
          tclvalue(config_file_var) <- ""
          tclvalue(available_configs) <- "No config files found"
        }
      }
    })
  }
  
  # === CONFIG SELECTION ===
  config_frame <- tkframe(tt, borderwidth = 2, relief = "groove")
  tkpack(config_frame, fill = "x", padx = 10, pady = 10)
  
  config_label <- tklabel(config_frame, text = "2. Select Configuration File",
                         font = tkfont.create(family = "Helvetica", size = 11, weight = "bold"))
  tkpack(config_label, anchor = "w", padx = 5, pady = 5)
  
  config_select_frame <- tkframe(config_frame)
  tkpack(config_select_frame, fill = "x", padx = 5, pady = 5)
  
  config_combo <- ttkcombobox(config_select_frame, textvariable = config_file_var,
                             values = "", state = "readonly", width = 40)
  tkpack(config_combo, side = "left", padx = 5)
  
  config_status_label <- tklabel(config_select_frame, textvariable = available_configs,
                                foreground = "gray", anchor = "w")
  tkpack(config_status_label, side = "left", padx = 5)
  
  # === RUN BUTTON ===
  run_frame <- tkframe(tt)
  tkpack(run_frame, pady = 10)
  
  run_button <- tkbutton(run_frame, text = "▶ RUN ANALYSIS", 
                        font = tkfont.create(family = "Helvetica", size = 12, weight = "bold"),
                        foreground = "white", background = "darkgreen",
                        padx = 20, pady = 10,
                        command = function() {
    proj_dir <- tclvalue(project_dir_var)
    config_file <- tclvalue(config_file_var)
    
    if (nchar(proj_dir) == 0) {
      tkmessageBox(title = "Error", message = "Please select a project directory",
                  icon = "error", type = "ok")
      return()
    }
    
    if (nchar(config_file) == 0) {
      tkmessageBox(title = "Error", message = "Please select a configuration file",
                  icon = "error", type = "ok")
      return()
    }
    
    # Add to recent projects
    recent_projects <- add_to_recent(proj_dir, recent_projects)
    save_recent_projects(recent_projects)
    
    # Run analysis
    run_analysis(proj_dir, config_file, tt)
  })
  tkpack(run_button)
  
  # === FOOTER ===
  footer_label <- tklabel(tt, text = paste("Turas Home:", TURAS_HOME),
                         font = tkfont.create(family = "Courier", size = 8),
                         foreground = "gray")
  tkpack(footer_label, side = "bottom", pady = 5)
  
  # Center window
  tkwm.deiconify(tt)
  tkfocus(tt)
}

# === LAUNCH ===
if (interactive()) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("LAUNCHING TURAS CROSSTABS GUI...\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")
  
  launch_turas_gui()
} else {
  cat("This script must be run interactively.\n")
  cat("Usage: source('turas_launcher_tcltk.R')\n")
}
