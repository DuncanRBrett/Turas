// ==============================================================================
// MAXDIFF HIERARCHICAL BAYES MODEL - TURAS V10.0
// ==============================================================================
// Stan model for individual-level utility estimation in MaxDiff
//
// MODEL:
// beta_n ~ MVN(mu, Sigma)           - Individual utilities for respondent n
// mu ~ Normal(0, sigma_mu)          - Population mean prior
// Sigma ~ LKJ(eta) * half-t(df, s)  - Covariance prior
//
// Uses non-centered parameterization for improved sampling geometry
// ==============================================================================

data {
  int<lower=1> N;                          // Number of choice observations
  int<lower=1> R;                          // Number of respondents
  int<lower=2> J;                          // Number of items
  int<lower=2> K;                          // Items per task

  array[N] int<lower=1, upper=R> resp;     // Respondent index for each obs
  array[N] int<lower=1, upper=K> choice;   // Index of chosen item (1 to K)
  array[N, K] int<lower=1, upper=J> shown; // Items shown in each task
  array[N] int<lower=0, upper=1> is_best;  // 1=best choice, 0=worst choice
}

parameters {
  // Population-level parameters
  vector[J-1] mu_raw;                      // Population mean (anchor item omitted)
  vector<lower=0>[J-1] sigma;              // Population standard deviations
  cholesky_factor_corr[J-1] L_corr;        // Correlation Cholesky factor

  // Individual-level (non-centered)
  matrix[R, J-1] z;                        // Standard normal deviates
}

transformed parameters {
  // Population mean (include anchor at 0)
  vector[J] mu;
  mu[1:(J-1)] = mu_raw;
  mu[J] = 0;                               // Anchor item fixed at 0

  // Individual utilities (non-centered parameterization)
  matrix[R, J] beta;

  {
    // Cholesky factor of covariance
    matrix[J-1, J-1] L_Sigma = diag_pre_multiply(sigma, L_corr);

    // Transform z to individual utilities
    for (r in 1:R) {
      beta[r, 1:(J-1)] = mu_raw' + (L_Sigma * z[r]')';
      beta[r, J] = 0;                      // Anchor item fixed at 0
    }
  }
}

model {
  // =========================================================================
  // PRIORS
  // =========================================================================

  // Population mean - weakly informative
  mu_raw ~ normal(0, 2);

  // Population SDs - weakly informative half-t
  sigma ~ student_t(3, 0, 1);

  // Correlation matrix - LKJ prior (regularizes toward identity)
  L_corr ~ lkj_corr_cholesky(2);

  // Standard normal for non-centered parameterization
  to_vector(z) ~ std_normal();

  // =========================================================================
  // LIKELIHOOD
  // =========================================================================

  for (n in 1:N) {
    // Get utilities for items shown in this task
    vector[K] task_utils;

    for (k in 1:K) {
      int item_idx = shown[n, k];
      real u = beta[resp[n], item_idx];

      // For worst choice, negate utilities (worst = lowest utility)
      if (is_best[n] == 0) {
        u = -u;
      }

      task_utils[k] = u;
    }

    // Multinomial logit likelihood
    target += task_utils[choice[n]] - log_sum_exp(task_utils);
  }
}

generated quantities {
  // Posterior predictive checks could be added here
  // Log-likelihood for model comparison
  vector[N] log_lik;

  for (n in 1:N) {
    vector[K] task_utils;

    for (k in 1:K) {
      int item_idx = shown[n, k];
      real u = beta[resp[n], item_idx];

      if (is_best[n] == 0) {
        u = -u;
      }

      task_utils[k] = u;
    }

    log_lik[n] = task_utils[choice[n]] - log_sum_exp(task_utils);
  }
}
