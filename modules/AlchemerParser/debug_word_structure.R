# Diagnostic script to see raw Word document structure
# This will show all paragraphs and table cells to help debug bracket detection

# Load officer package
if (!requireNamespace("officer", quietly = TRUE)) {
  stop("Install officer package first")
}

# Read Word doc (use relative path from current working directory)
word_file <- file.path(getwd(), "modules/AlchemerParser/Questionnaire.docx")

if (file.exists(word_file)) {
  doc <- officer::read_docx(word_file)
  doc_content <- officer::docx_summary(doc)

  # Filter to text content
  text_content <- doc_content[doc_content$content_type %in% c("paragraph", "table cell"), ]

  cat("\n=== WORD DOCUMENT STRUCTURE ===\n")
  cat(sprintf("Total rows: %d\n\n", nrow(text_content)))

  # Look for Q2 specifically
  cat("Looking for Q2 content (showing 30 rows around Q2)...\n\n")

  for (i in seq_len(nrow(text_content))) {
    text <- as.character(text_content$text[i])

    # Check if this mentions Q2 or question 2
    if (grepl("^\\s*2[\\).:]|\\bQ2\\b|question 2", text, ignore.case = TRUE)) {
      # Show context (10 rows before and 20 after)
      start_row <- max(1, i - 10)
      end_row <- min(nrow(text_content), i + 20)

      for (j in start_row:end_row) {
        row_text <- as.character(text_content$text[j])
        row_type <- text_content$content_type[j]

        # Highlight if it contains brackets
        has_parens <- grepl("\\(.*\\)", row_text)
        has_squares <- grepl("\\[.*\\]", row_text)

        marker <- ""
        if (j == i) marker <- " <<< Q2 FOUND HERE"
        if (has_parens) marker <- paste(marker, "[HAS ()]")
        if (has_squares) marker <- paste(marker, "[HAS []]")

        cat(sprintf("Row %d [%s]: %s%s\n",
                   j,
                   row_type,
                   substr(row_text, 1, 80),
                   marker))
      }

      cat("\n")
      break
    }
  }

  # Also check what brackets appear in the whole document
  cat("\n=== ALL ROWS WITH BRACKETS ===\n")
  for (i in seq_len(min(100, nrow(text_content)))) {
    text <- as.character(text_content$text[i])
    if (grepl("\\(.*\\)|\\[.*\\]", text)) {
      cat(sprintf("Row %d [%s]: %s\n",
                 i,
                 text_content$content_type[i],
                 substr(text, 1, 80)))
    }
  }

} else {
  cat("Word file not found at:", word_file, "\n")
}
