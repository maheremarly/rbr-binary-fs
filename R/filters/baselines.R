# The two filters the paper compares the RBR against.
#
# Both come from FSelector and score a feature by the reduction in the entropy
# of the class label induced by its discretised values, so for both a LARGER
# score means a more relevant feature.


#' Information gain and symmetric uncertainty for every feature.
#'
#' @param data Data frame of numeric features plus the target column `y`.
#' @return A data frame with columns "Information Gain" and
#'   "Symmetric Uncertainty", one row per feature, row names the feature names.
baseline_filters <- function(data) {
  ig <- FSelector::information.gain(y ~ ., data)
  colnames(ig) <- "Information Gain"

  su <- FSelector::symmetrical.uncertainty(y ~ ., data)
  colnames(su) <- "Symmetric Uncertainty"

  cbind(ig, su)
}
