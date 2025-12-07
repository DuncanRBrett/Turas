# TURAS File Inventory Generator
# Creates comprehensive CSV inventory of all project files

library(tools)

# Function to count R code lines
count_r_lines <- function(filepath) {
  if (!file.exists(filepath)) return(list(active=0, blank=0, comment=0, total=0))

  lines <- readLines(filepath, warn=FALSE)
  total <- length(lines)
  blank <- sum(grepl("^\\s*$", lines))
  comment <- sum(grepl("^\\s*#", lines))
  active <- total - blank - comment

  list(active=active, blank=blank, comment=comment, total=total)
}

# Function to determine file purpose
determine_purpose <- function(filepath, filename) {
  dir <- dirname(filepath)

  if (grepl("README", filename)) return("Documentation")
  if (grepl("USER_MANUAL|TECHNICAL_DOCS|TUTORIAL", filename)) return("User documentation")
  if (grepl("QUICK_START|QUICK_LAUNCH", filename)) return("Quick reference")
  if (grepl("test_", filename)) return("Unit/regression test")
  if (grepl("example|template", tolower(dir))) return("Example/template")
  if (grepl("/R/00_main\\.R$", filepath)) return("Main module entry")
  if (grepl("/R/[0-9]+_", filepath)) return("Module component")
  if (grepl("/shared/", filepath)) return("Shared utility")
  if (grepl("/tools/", filepath)) return("Development tool")
  if (grepl("config", tolower(filename))) return("Configuration")
  if (grepl("\\.csv$", filepath)) return("Data file")
  if (grepl("\\.xlsx$", filepath)) return("Excel workbook")
  if (grepl("/docs/", filepath)) return("Technical documentation")

  return("Other")
}

# Function to assess quality
assess_quality <- function(filepath, lines_info, purpose) {
  # Documentation files
  if (grepl("\\.md$", filepath)) {
    if (lines_info$total > 500) return("Excellent")
    if (lines_info$total > 200) return("Good")
    if (lines_info$total > 50) return("Adequate")
    return("Needs improvement")
  }

  # R scripts
  if (grepl("\\.R$", filepath)) {
    if (lines_info$active > 200 && lines_info$comment > 50) return("Excellent")
    if (lines_info$active > 100) return("Good")
    if (lines_info$active > 30) return("Adequate")
    return("Needs improvement")
  }

  # Other files
  if (file.exists(filepath) && file.size(filepath) > 1000) return("Good")
  return("Adequate")
}

# Function to determine status
determine_status <- function(filepath) {
  dir <- dirname(filepath)

  if (grepl("/archived/", filepath)) return("Archived")
  if (grepl("/examples/", filepath)) return("Supporting")
  if (grepl("/tests/", filepath)) return("Supporting")
  if (grepl("/tools/", filepath)) return("Supporting")
  if (grepl("/docs/", filepath)) return("Supporting")
  if (grepl("/R/", filepath)) return("Active")
  if (grepl("README|MANUAL", basename(filepath))) return("Active")
  if (grepl("/shared/", filepath)) return("Active")

  return("Inactive")
}

# Main inventory creation
create_inventory <- function(root_dir = ".") {
  # Find all relevant files
  files <- list.files(root_dir,
                      pattern = "\\.(R|md|xlsx|csv)$",
                      recursive = TRUE,
                      full.names = TRUE)

  # Exclude certain paths
  files <- files[!grepl("\\.git/", files)]
  files <- files[!grepl("\\.Rproj\\.user/", files)]

  # Create inventory data frame
  inventory <- data.frame(
    filepath = character(),
    filename = character(),
    purpose = character(),
    filetype = character(),
    total_lines = integer(),
    active_lines = integer(),
    blank_lines = integer(),
    comment_lines = integer(),
    quality = character(),
    directory = character(),
    status = character(),
    stringsAsFactors = FALSE
  )

  for (file in files) {
    filename <- basename(file)
    filetype <- tolower(file_ext(file))

    # Count lines
    if (filetype == "r") {
      lines_info <- count_r_lines(file)
    } else {
      total <- length(readLines(file, warn=FALSE))
      lines_info <- list(active=NA, blank=NA, comment=NA, total=total)
    }

    # Determine attributes
    purpose <- determine_purpose(file, filename)
    quality <- assess_quality(file, lines_info, purpose)
    status <- determine_status(file)
    directory <- dirname(file)

    # Add to inventory
    inventory <- rbind(inventory, data.frame(
      filepath = file,
      filename = filename,
      purpose = purpose,
      filetype = filetype,
      total_lines = lines_info$total,
      active_lines = if(is.na(lines_info$active)) NA else lines_info$active,
      blank_lines = if(is.na(lines_info$blank)) NA else lines_info$blank,
      comment_lines = if(is.na(lines_info$comment)) NA else lines_info$comment,
      quality = quality,
      directory = directory,
      status = status,
      stringsAsFactors = FALSE
    ))
  }

  # Sort by directory and filename
  inventory <- inventory[order(inventory$directory, inventory$filename), ]

  return(inventory)
}

# Run inventory
cat("Creating file inventory...\n")
inventory <- create_inventory()

# Save to CSV
output_file <- "FILE_INVENTORY.csv"
write.csv(inventory, output_file, row.names = FALSE)

cat("✓ Inventory created:", nrow(inventory), "files\n")
cat("✓ Saved to:", output_file, "\n")

# Print summary
cat("\nSummary by file type:\n")
print(table(inventory$filetype))

cat("\nSummary by status:\n")
print(table(inventory$status))

cat("\nSummary by quality:\n")
print(table(inventory$quality))
