# Turning filter scores into one feature ranking per method.
#
# The three filters do not agree on direction. Information gain and symmetric
# uncertainty score a relevant feature HIGH, so they are sorted descending. The
# RBR strength is the posterior mass on discrepancies no more surprising than
# the observed one, so a relevant feature scores LOW and it is sorted ASCENDING.


#' Score every feature with all three filters and scale the scores to [0, 1].
#'
#' @param data Data frame of numeric features plus the target column `y`.
#' @param prior Output of rbr_prior().
#' @param cfg Resolved dataset configuration.
#' @return A data frame with columns strength, "Information Gain",
#'   "Symmetric Uncertainty" and names, one row per feature.
score_features <- function(data, prior, cfg) {
  message("==> Scoring ", ncol(data) - 1, " features with the RBR filter")
  scores <- rbr_filter(
    data, "y",
    prior = prior, B = cfg$rbr_draws, M = cfg$rbr_bins, i0 = cfg$rbr_i0
  )

  # Drop the Feature column: the row names carry the feature names from here on,
  # supplied by the baseline filters in the cbind below.
  scores <- scores[, -1]

  message("==> Scoring with information gain and symmetric uncertainty")
  scores <- cbind(scores, baseline_filters(data))

  normalised <- as.data.frame(apply(scores, 2, normalize))

  # RB_dist is reported by the filter but not used for ranking; the paper ranks
  # on the strength alone.
  normalised <- normalised[, -1]
  normalised$names <- as.character(rownames(normalised))
  normalised
}


#' One ranked feature vector per method, as the columns of a character matrix.
#'
#' @param scores Output of score_features().
#' @return A character matrix, features in rank order down each column.
build_rankings <- function(scores) {
  by_strength <- dplyr::arrange(scores, scores$strength)
  by_ig <- dplyr::arrange(scores, dplyr::desc(scores$`Information Gain`))
  by_su <- dplyr::arrange(scores, dplyr::desc(scores$`Symmetric Uncertainty`))

  cbind(
    Rb_St = by_strength$names,
    IG    = by_ig$names,
    SU    = by_su$names
  )
}


#' The feature selection methods a rankings matrix holds, in column order.
ranking_methods <- function(rankings) colnames(rankings)
