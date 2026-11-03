# The results table and how folds are combined.
#
# A results table has one column per feature selection method and
# 2 * length(stepsize) + 1 rows: the error rates for each subset size, one blank
# separator row, then the AUROC values for the same subset sizes. The separator
# is an artefact of the original layout and is kept so that the exported
# workbooks match the ones the paper was written from; auroc_rows() and
# error_rows() index past it rather than hard-coding row numbers.


#' An empty results table, laid out as described above.
init_cv_results <- function(stepsize, methods) {
  n <- length(stepsize)
  results <- data.frame(matrix(nrow = 2 * n + 1, ncol = length(methods)))
  colnames(results) <- methods
  rownames(results)[1:n] <- paste0(stepsize * 100, "%")
  rownames(results)[n + 1] <- " "
  rownames(results)[(n + 2):(2 * n + 1)] <- paste0(stepsize * 100, "% AUROC")
  results
}


#' Row indices of the error rate block.
error_rows <- function(stepsize) seq_along(stepsize)


#' Row indices of the AUROC block.
auroc_rows <- function(stepsize) {
  n <- length(stepsize)
  (n + 2):(2 * n + 1)
}


#' Mean of one results table per fold, cell by cell.
average_folds <- function(fold_results) {
  apply(abind::abind(fold_results, along = 3), 1:2, mean)
}


#' Rows of `test_data` whose factor levels all occur in `train_data`.
#'
#' Guards the model formulas against a factor level that is present only in the
#' held-out fold. After clean_dataset() every feature is numeric and the target
#' carries both levels, so in practice this keeps every row.
rows_with_seen_levels <- function(train_data, test_data) {
  keep <- sapply(seq_len(ncol(train_data)), function(k) {
    x_test <- test_data[, k]
    x_train <- train_data[, k]
    seen <- unique(x_test) %in% unique(x_train)
    if (is.factor(x_test) && any(!seen)) {
      levels_seen <- unique(x_test)[seen]
      apply(
        test_data[, k] == matrix(
          rep(levels_seen, each = nrow(test_data)),
          nrow = nrow(test_data)
        ),
        1, any
      )
    } else {
      rep(TRUE, nrow(test_data))
    }
  })
  apply(keep, 1, all)
}


#' AUROC of a score vector against a two-level truth vector.
auroc <- function(scores, truth) {
  prediction <- ROCR::prediction(scores, truth)
  ROCR::performance(prediction, measure = "auc")@y.values[[1]]
}


#' A model formula selecting `features` as predictors of `y`.
subset_formula <- function(features) {
  stats::as.formula(paste("y ~", paste(features, collapse = " + ")))
}
