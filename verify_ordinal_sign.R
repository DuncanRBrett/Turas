#!/usr/bin/env Rscript
# Verify the correct sign convention for ordinal models

library(ordinal)
library(MASS)

cat("\n=== VERIFYING ORDINAL MODEL SIGN CONVENTION ===\n\n")

# Create clear test data
set.seed(42)
n <- 200
data <- data.frame(
  satisfaction = ordered(rep(1:5, each=n/5), levels=1:5),
  treatment = factor(rep(c("Control", "Treated"), each=n/2))
)

# Make Treated group have HIGHER satisfaction
# Control: mostly low (1-2), Treated: mostly high (4-5)
data$satisfaction[data$treatment=="Control"] <- ordered(
  sample(1:5, n/2, TRUE, prob=c(0.4, 0.3, 0.2, 0.05, 0.05)),
  levels=1:5
)
data$satisfaction[data$treatment=="Treated"] <- ordered(
  sample(1:5, n/2, TRUE, prob=c(0.05, 0.05, 0.2, 0.3, 0.4)),
  levels=1:5
)

# Verify raw data
cat("Raw Data:\n")
cat(sprintf("  Control mean satisfaction:  %.2f\n", mean(as.numeric(data$satisfaction[data$treatment=="Control"]))))
cat(sprintf("  Treated mean satisfaction:  %.2f\n", mean(as.numeric(data$satisfaction[data$treatment=="Treated"]))))
cat("\n")

# Fit ordinal models
cat("Testing ordinal::clm:\n")
model_clm <- clm(satisfaction ~ treatment, data=data)
coef_clm <- coef(model_clm)["treatmentTreated"]
cat(sprintf("  Coefficient for Treated: %.3f\n", coef_clm))
cat(sprintf("  Sign: %s\n", if(coef_clm > 0) "POSITIVE" else "NEGATIVE"))
cat(sprintf("  Interpretation: Treated → %s satisfaction\n",
            if(coef_clm > 0) "HIGHER" else "LOWER"))
cat(sprintf("  exp(β) = %.3f\n", exp(coef_clm)))
cat(sprintf("  exp(-β) = %.3f\n", exp(-coef_clm)))
cat("\n")

cat("Testing MASS::polr:\n")
model_polr <- polr(satisfaction ~ treatment, data=data, Hess=TRUE)
coef_polr <- coef(model_polr)["treatmentTreated"]
cat(sprintf("  Coefficient for Treated: %.3f\n", coef_polr))
cat(sprintf("  Sign: %s\n", if(coef_polr > 0) "POSITIVE" else "NEGATIVE"))
cat(sprintf("  Interpretation: Treated → %s satisfaction\n",
            if(coef_polr > 0) "HIGHER" else "LOWER"))
cat(sprintf("  exp(β) = %.3f\n", exp(coef_polr)))
cat(sprintf("  exp(-β) = %.3f\n", exp(-coef_polr)))
cat("\n")

cat("=== CONCLUSION ===\n")
if (coef_clm > 0 && coef_polr > 0) {
  cat("✅ BOTH models show POSITIVE coefficient for higher outcome\n")
  cat("✅ Correct OR calculation: exp(β), NOT exp(-β)\n")
  cat("✅ The 'empirical observation' claiming β < 0 is INCORRECT\n")
} else {
  cat("❌ Unexpected: coefficient signs don't match expected pattern\n")
}
cat("\n")
