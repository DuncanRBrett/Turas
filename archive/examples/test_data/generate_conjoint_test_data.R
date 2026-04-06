# Generate orthogonal conjoint test data

set.seed(123)

# Define attributes
prices <- c("£449", "£599", "£699")
brands <- c("Apple", "Samsung", "Google")
storage <- c("128GB", "256GB", "512GB")
battery <- c("12 hours", "18 hours", "24 hours")

# Generate data
n_resp <- 10
n_tasks <- 3
n_alt <- 3

data <- data.frame()

for (resp in 1:n_resp) {
  for (task in 1:n_tasks) {
    for (alt in 1:n_alt) {
      # Randomize attributes independently
      row <- data.frame(
        resp_id = resp,
        choice_set_id = (resp - 1) * n_tasks + task,
        alternative_id = alt,
        Price = sample(prices, 1),
        Brand = sample(brands, 1),
        Storage = sample(storage, 1),
        Battery = sample(battery, 1),
        chosen = 0
      )
      data <- rbind(data, row)
    }
    # Randomly select one alternative as chosen
    choice_set_rows <- nrow(data) - (n_alt - 1):0
    data$chosen[sample(choice_set_rows, 1)] <- 1
  }
}

# Write to CSV
write.csv(data, "test_data/conjoint_test_data.csv", row.names = FALSE)

cat("Generated", nrow(data), "rows of test data\n")
cat("Respondents:", n_resp, "\n")
cat("Tasks per respondent:", n_tasks, "\n")
cat("Alternatives per task:", n_alt, "\n")
