# Diagnostic script to check Word doc hint detection
# Run this to see what brackets are being detected for each question

# Get current working directory (should already be in Turas folder)
source("modules/AlchemerParser/R/03_parse_word_doc.R")

# Parse the Word doc (it's directly in the AlchemerParser folder)
word_file <- file.path(getwd(), "modules/AlchemerParser/Questionnaire.docx")

if (file.exists(word_file)) {
  hints <- parse_word_questionnaire(word_file, verbose = TRUE)

  cat("\n=== WORD DOC HINTS ===\n")
  for (q_num in names(hints)) {
    hint <- hints[[q_num]]
    cat(sprintf("\nQ%s:\n", q_num))
    cat(sprintf("  Brackets: '%s'\n", hint$brackets))
    cat(sprintf("  Type: '%s'\n", hint$type))
    cat(sprintf("  Has rank keyword: %s\n", hint$has_rank_keyword))
    cat(sprintf("  Question text: %s\n", substr(hint$question_text, 1, 60)))
  }
} else {
  cat("Word file not found at:", word_file, "\n")
}
