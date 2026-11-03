# The four classifiers the feature rankings are evaluated with.
#
# cv_over_subsets() owns everything the four have in common: the fold loop, the
# descent through the subset sizes, the per-subset seed, and the layout of the
# results table. Each classifier contributes only a fit_predict() function that
# takes a training frame, an evaluation frame and a feature subset, and returns
# the error rate and the AUROC.
#
# fit_predict() also returns the evaluation frame it used. Logistic regression
# and SVM drop rows whose factor levels are unseen in training, and that reduced
# frame carries into the next subset size rather than the fold being cut again;
# returning it keeps that visible instead of hiding it in a mutated variable.


#' Cross-validate one classifier over every ranking and every subset size.
#'
#' @param eval_set The frame the folds are cut from.
#' @param folds List of held-out row index vectors, from caret::createFolds().
#' @param rankings Character matrix from build_rankings().
#' @param stepsize Decreasing fractions of the feature set to retain.
#' @param n_features Feature count the fractions are taken of.
#' @param seed Seed set before every single fit.
#' @param fit_predict Classifier function, as described above.
#' @return A results table averaged over the folds.
cv_over_subsets <- function(eval_set, folds, rankings, stepsize,
                            n_features, seed, fit_predict) {
  methods <- colnames(rankings)
  err_idx <- error_rows(stepsize)
  auc_idx <- auroc_rows(stepsize)

  fold_results <- lapply(folds, function(held_out_rows) {
    train_data <- eval_set[-held_out_rows, ]
    results <- init_cv_results(stepsize, methods)

    for (i in seq_along(methods)) {
      current <- rep(NA_real_, 2 * length(stepsize) + 1)
      test_data <- eval_set[held_out_rows, ]

      for (s in seq_along(stepsize)) {
        set_seed(seed)

        threshold <- floor(stepsize[s] * n_features)
        features <- as.character(rankings[seq_len(threshold), i])

        fit <- fit_predict(train_data, test_data, features)

        current[err_idx[s]] <- fit$error_rate
        current[auc_idx[s]] <- fit$auroc
        test_data <- fit$test_data
      }

      results[, i] <- current
      message("    ", methods[i])
    }

    results
  })

  average_folds(fold_results)
}


#' Bayesian logistic regression (arm::bayesglm, Student-t prior, 12 prior df).
fit_predict_lr <- function(train_data, test_data, features) {
  test_data <- test_data[rows_with_seen_levels(train_data, test_data), ]

  model <- arm::bayesglm(
    subset_formula(features),
    family = stats::binomial,
    data = train_data,
    prior.df = 12,
    drop.unused.levels = FALSE
  )

  predictors <- test_data[, !colnames(test_data) %in% "y"]
  probs <- stats::predict(model, predictors, type = "response")
  preds <- ifelse(probs > 0.5, 2, 1)

  list(
    error_rate = mean(preds != test_data$y),
    auroc      = auroc(probs, test_data$y),
    test_data  = test_data
  )
}


#' k-nearest neighbours.
#'
#' The AUROC is scored at k = 5 and the error rate at k = 2, both declared here
#' rather than buried in the body. The AUROC score is 1 - p, where p is the
#' winning class's vote share, which is the only score class::knn returns.
fit_predict_knn <- function(train_data, test_data, features,
                            k_auroc = 5, k_error = 2) {
  # knn needs an all-numeric design matrix.
  to_numeric <- function(df) {
    is_factor <- sapply(df, is.factor)
    df[is_factor] <- lapply(df[is_factor], function(x) as.numeric(as.character(x)))
    df
  }
  train_data <- to_numeric(train_data)
  test_data <- to_numeric(test_data)

  train_x <- train_data[, features, drop = FALSE]
  test_x <- test_data[, features, drop = FALSE]

  scored <- class::knn(
    train = train_x, test = test_x, cl = train_data$y,
    k = k_auroc, prob = TRUE
  )
  auroc_value <- auroc(1 - attributes(scored)$prob, test_data$y)

  predicted <- class::knn(
    train = train_x, test = test_x, cl = train_data$y,
    k = k_error
  )

  list(
    error_rate = mean(predicted != test_data$y),
    auroc      = auroc_value,
    test_data  = test_data
  )
}


#' Random forest, at randomForest's default 500 trees and mtry.
fit_predict_rf <- function(train_data, test_data, features) {
  model <- randomForest::randomForest(subset_formula(features), data = train_data)

  predictors <- test_data[, !colnames(test_data) %in% "y"]
  probs <- stats::predict(model, predictors, type = "prob")[, 2]
  preds <- stats::predict(model, predictors)

  list(
    error_rate = mean(preds != test_data$y),
    auroc      = auroc(probs, test_data$y),
    test_data  = test_data
  )
}


#' Support vector machine, at e1071's default radial kernel.
fit_predict_svm <- function(train_data, test_data, features) {
  test_data <- test_data[rows_with_seen_levels(train_data, test_data), ]

  model <- e1071::svm(
    subset_formula(features),
    data = train_data,
    probability = TRUE
  )

  predictors <- test_data[, !colnames(test_data) %in% "y"]
  probs <- attr(
    stats::predict(model, predictors, probability = TRUE),
    "probabilities"
  )[, 2]
  preds <- stats::predict(model, predictors)

  list(
    error_rate = mean(preds != test_data$y),
    auroc      = auroc(probs, test_data$y),
    test_data  = test_data
  )
}


#' The four classifiers, keyed by the sheet name used in the exported workbook.
CLASSIFIERS <- list(
  "logistic regression" = fit_predict_lr,
  "KNN"                 = fit_predict_knn,
  "random forest"       = fit_predict_rf,
  "SVM"                 = fit_predict_svm
)
