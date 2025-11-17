# ==============================================================================
# GENERATE TEST QUESTION LABELS
# ==============================================================================
# Creates question labels file for testing label integration feature
# ==============================================================================

library(writexl)

# Create question labels data frame
question_labels <- data.frame(
  Variable = paste0("q", 1:20),
  Label = c(
    # Product Satisfaction (q1-q4)
    "Overall satisfaction with product quality",
    "Satisfaction with product features",
    "Satisfaction with product reliability",
    "Satisfaction with product value for money",

    # Service Satisfaction (q5-q8)
    "Overall satisfaction with customer service",
    "Satisfaction with service responsiveness",
    "Satisfaction with service professionalism",
    "Satisfaction with service availability",

    # Support Satisfaction (q9-q12)
    "Overall satisfaction with technical support",
    "Satisfaction with support response time",
    "Satisfaction with support knowledge",
    "Satisfaction with support resolution",

    # Value Satisfaction (q13-q16)
    "Overall satisfaction with pricing",
    "Satisfaction with pricing transparency",
    "Satisfaction with value compared to competitors",
    "Satisfaction with billing process",

    # Overall Experience (q17-q20)
    "Overall satisfaction with brand experience",
    "Likelihood to recommend to others",
    "Likelihood to continue using product",
    "Overall satisfaction rating"
  ),
  stringsAsFactors = FALSE
)

# Write to Excel with "Labels" sheet
write_xlsx(list(Labels = question_labels),
           "modules/segment/test_data/test_question_labels.xlsx")

cat("✓ Generated test question labels file\n")
cat(sprintf("  Variables: %d\n", nrow(question_labels)))
cat("  File: modules/segment/test_data/test_question_labels.xlsx\n")
