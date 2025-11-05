# ==============================================================================
# TURAS>PARSER - DOCX Reader
# ==============================================================================
# Purpose: Read and extract text from Word (.docx) documents
# ==============================================================================

#' Read DOCX Document Text
#' 
#' @description
#' Reads a Word document and extracts all paragraph text.
#' Uses the officer package to parse .docx files.
#' 
#' @param docx_path Character. Path to .docx file
#' 
#' @return Character vector. Extracted text with paragraphs separated by newlines
#' 
#' @examples
#' \dontrun{
#' text <- read_docx_text("questionnaire.docx")
#' lines <- split_docx_lines(text)
#' }
#' 
#' @export
read_docx_text <- function(docx_path) {
  
  # Validate file
  if (!file.exists(docx_path)) {
    stop("File not found: ", docx_path, call. = FALSE)
  }
  
  if (!grepl("\\.docx?$", docx_path, ignore.case = TRUE)) {
    stop("File must be .docx format", call. = FALSE)
  }
  
  # Read document
  doc <- officer::read_docx(docx_path)
  
  # Extract content
  content <- officer::docx_summary(doc)
  
  # Filter paragraphs
  para_content <- content[content$content_type == "paragraph", ]
  
  if (nrow(para_content) == 0) {
    stop("No text content found in document", call. = FALSE)
  }
  
  # Combine text
  text <- paste(para_content$text, collapse = "\n")
  
  return(text)
}

#' Split DOCX Text into Lines
#' 
#' @description
#' Splits document text into individual lines and cleans them.
#' Returns both raw and cleaned versions for different parsing strategies.
#' 
#' @param doc_text Character. Full document text from read_docx_text()
#' 
#' @return List with:
#'   - raw: Character vector of all lines (including blank)
#'   - clean: Character vector of non-blank lines (trimmed)
#' 
#' @export
split_docx_lines <- function(doc_text) {
  
  # Split on newlines
  all_lines <- strsplit(doc_text, "\n")[[1]]
  
  # Trim whitespace
  all_lines <- trimws(all_lines)
  
  # Create cleaned version (no blank lines)
  clean_lines <- all_lines[nchar(all_lines) > 0]
  
  return(list(
    raw = all_lines,
    clean = clean_lines
  ))
}

#' Validate DOCX File
#' 
#' @description
#' Validates a .docx file before parsing.
#' 
#' @param docx_path Character. Path to .docx file
#' 
#' @return Logical. TRUE if valid, stops with error if invalid
#' 
#' @export
validate_docx_file <- function(docx_path) {
  
  if (!file.exists(docx_path)) {
    stop("File not found: ", docx_path, call. = FALSE)
  }
  
  if (!grepl("\\.docx?$", docx_path, ignore.case = TRUE)) {
    stop("File must be .docx format, got: ", 
         tools::file_ext(docx_path), call. = FALSE)
  }
  
  # Try to read it
  tryCatch({
    doc <- officer::read_docx(docx_path)
    TRUE
  }, error = function(e) {
    stop("Cannot read .docx file: ", e$message, call. = FALSE)
  })
}
