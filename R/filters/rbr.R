# The relative belief ratio (RBR) filter for two-class problems.
#
# Each feature is scored by the evidence against H0: mu1 = mu2, where mu1 and
# mu2 are its class-conditional means. The discrepancy psi is the symmetrised
# Kullback-Leibler distance between the two class-conditional normals and their
# precision-weighted pool. psi is sampled B times from the prior and B times
# from the posterior; the relative belief ratio at psi -> 0 is then the ratio of
# the two distribution functions at the 1/M prior quantile, and the strength is
# the posterior mass on discrepancies no more surprising than that ratio.
#
# A SMALL strength means strong evidence against equality of the means, so
# features are ranked by ASCENDING strength (see R/utils/rankings.R).


#' Relative belief ratio and strength for one feature, from its class summaries.
#'
#' @param xbar1,xbar2 Class-conditional sample means.
#' @param s_sqr1,s_sqr2 Class-conditional sample variances.
#' @param n1,n2 Class sample sizes.
#' @param prior Output of rbr_prior().
#' @param B Monte Carlo sample size for the prior and posterior discrepancies.
#' @param M Number of prior quantile bins used to discretise the ratio.
#' @return A one-row matrix with columns RB_dist and strength.
rbr_two_sample <- function(xbar1, xbar2, s_sqr1, s_sqr2, n1, n2,
                           prior, B = 10000, M = 100) {
  alpha0  <- prior$alpha0
  beta0   <- prior$beta0
  mu0     <- prior$mu0
  lambda0 <- prior$lambda0

  d_prior <- matrix(0, B, 1)
  d_post  <- matrix(0, B, 1)

  # Posterior hyperparameters are free of the Monte Carlo index, so they are
  # formed once outside the loop.
  alpha_post1 <- alpha0 + (n1 / 2)
  alpha_post2 <- alpha0 + (n2 / 2)
  beta_post1  <- beta0 + (n1 - 1) * s_sqr1 / 2 +
    n1 * (xbar1 - mu0)^2 / (2 * (n1 * lambda0^2 + 1))
  beta_post2  <- beta0 + (n2 - 1) * s_sqr2 / 2 +
    n2 * (xbar2 - mu0)^2 / (2 * (n2 * lambda0^2 + 1))
  mu_x_post1  <- ((mu0 / lambda0^2) + n1 * xbar1) / (n1 + 1 / lambda0^2)
  mu_x_post2  <- ((mu0 / lambda0^2) + n2 * xbar2) / (n2 + 1 / lambda0^2)

  # The draw order below (rgamma, rgamma, rnorm, rnorm for the prior, then the
  # same four for the posterior) fixes the random number stream. Do not
  # reorder or vectorise this loop: it would change every published score.
  for (i in 1:B) {
    var_prior1   <- 1 / rgamma(1, alpha0, rate = beta0)
    var_prior2   <- 1 / rgamma(1, alpha0, rate = beta0)
    sigma_prior1 <- var_prior1^0.5
    sigma_prior2 <- var_prior2^0.5

    mu_prior1 <- rnorm(1, mean = mu0, sd = lambda0 * sigma_prior1)
    mu_prior2 <- rnorm(1, mean = mu0, sd = lambda0 * sigma_prior2)

    # Precision-weighted pool of the two prior means, and the KL distance to it.
    sum_var_prior <- (1 / var_prior1) + (1 / var_prior2)
    mu_prior_pool <- ((mu_prior1 / var_prior1) + (mu_prior2 / var_prior2)) / sum_var_prior
    d_prior[i] <- (((mu_prior_pool - mu_prior1)^2 / var_prior1) +
                     ((mu_prior_pool - mu_prior2)^2 / var_prior2)) / 2

    var_post1 <- 1 / rgamma(1, alpha_post1, beta_post1)
    var_post2 <- 1 / rgamma(1, alpha_post2, beta_post2)

    var_x_post1 <- var_post1 / (n1 + 1 / lambda0^2)
    var_x_post2 <- var_post2 / (n2 + 1 / lambda0^2)

    mu_post1 <- rnorm(1, mean = mu_x_post1, sd = var_x_post1^0.5)
    mu_post2 <- rnorm(1, mean = mu_x_post2, sd = var_x_post2^0.5)

    sum_var_post <- (1 / var_post1) + (1 / var_post2)
    mu_post_pool <- ((mu_post1 / var_post1) + (mu_post2 / var_post2)) / sum_var_post
    d_post[i] <- (((mu_post_pool - mu_post1)^2 / var_post1) +
                    ((mu_post_pool - mu_post2)^2 / var_post2)) / 2
  }

  # Relative belief ratio at the smallest prior quantile bin.
  psi_prior <- matrix(0, M + 1, 1)
  for (i in 1:M) psi_prior[i + 1] <- quantile(d_prior, i / M)
  psi_star <- psi_prior[2]

  Fn_prior <- ecdf(d_prior)
  Fn_post  <- ecdf(d_post)
  RB_dist  <- Fn_post(psi_star) / Fn_prior(psi_star)

  # Strength: posterior mass on bins whose ratio does not exceed RB_dist.
  RBR_hat <- matrix(0, M, 1)
  for (i in 1:M) {
    RBR_hat[i] <- M * (Fn_post(psi_prior[i + 1]) - Fn_post(psi_prior[i]))
  }
  bin_mass <- matrix(0, M, 1)
  for (i in 1:M) {
    if (RBR_hat[i] <= RB_dist) {
      bin_mass[i] <- Fn_post(psi_prior[i + 1]) - Fn_post(psi_prior[i])
    }
  }

  cbind(RB_dist = RB_dist, strength = sum(bin_mass))
}


#' Score every feature of a data frame with the RBR filter.
#'
#' @param d Data frame of numeric features plus a two-level target.
#' @param target_variable Name of the target column.
#' @param prior Output of rbr_prior().
#' @param B,M Monte Carlo sample size and number of prior quantile bins.
#' @return A data frame with one row per feature: Feature, RB_dist, strength.
rbr_filter <- function(d, target_variable, prior, B = 10000, M = 100) {
  d[[target_variable]] <- as.factor(d[[target_variable]])

  features <- setdiff(names(d), target_variable)
  scores <- matrix(nrow = length(features), ncol = 3)
  colnames(scores) <- c("Feature", "RB_dist", "strength")

  for (j in seq_along(features)) {
    x <- d[[features[j]]]
    y <- d[[target_variable]]

    xbar <- tapply(x, y, mean)
    v    <- tapply(x, y, var)
    n    <- tapply(x, y, length)

    result <- rbr_two_sample(
      xbar[1], xbar[2], v[1], v[2], n[1], n[2],
      prior = prior, B = B, M = M
    )
    scores[j, ] <- c(features[j], result[1], result[2])
  }

  out <- as.data.frame(scores, stringsAsFactors = FALSE)
  out$RB_dist  <- as.numeric(out$RB_dist)
  out$strength <- as.numeric(out$strength)
  out
}
