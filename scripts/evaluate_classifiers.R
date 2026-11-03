#!/usr/bin/env Rscript
# Stage 2: cross-validate the four classifiers over every ranking and every
# subset size, and export one workbook sheet per classifier.

source("R/utils/setup.R")
source_modules()


#' Read stage 1's rankings back as a character matrix.
load_rankings <- function(cfg) {
  path <- file.path(output_dir(cfg, "ranking"), "feature_rankings.csv")
  if (!file.exists(path)) {
    stop(
      "Rankings not found: ", path,
      "\nRun scripts/rank_features.R --dataset ", cfg$dataset, " first.",
      call. = FALSE
    )
  }
  as.matrix(utils::read.csv(path, colClasses = "character"))
}


#' Cross-validate every classifier and write the results.
evaluate_classifiers <- function(cfg) {
  split <- prepare_dataset(cfg)
  rankings <- load_rankings(cfg)

  n_features <- ncol(split$all) - 1
  if (nrow(rankings) != n_features) {
    stop(
      "Rankings hold ", nrow(rankings), " features but the prepared data has ",
      n_features, ". Rerun stage 1 with the current configuration.",
      call. = FALSE
    )
  }

  # The folds are cut from the held-out third, not from the training split.
  set_seed(cfg$cv_seed)
  folds <- caret::createFolds(factor(split$test$y), k = cfg$cv_folds)
  message(
    "==> ", cfg$cv_folds, "-fold cross-validation on ", nrow(split$test),
    " held-out rows, ", n_features, " features"
  )

  results <- list()
  for (name in names(CLASSIFIERS)) {
    message("==> ", name)
    results[[name]] <- cv_over_subsets(
      eval_set    = split$test,
      folds       = folds,
      rankings    = rankings,
      stepsize    = cfg$stepsize,
      n_features  = n_features,
      seed        = cfg$seed,
      fit_predict = CLASSIFIERS[[name]]
    )
  }

  out <- output_dir(cfg, "evaluation")
  workbook <- file.path(out, paste0(cfg$dataset, "_results.xlsx"))
  openxlsx::write.xlsx(
    lapply(results, as.data.frame),
    file = workbook,
    rowNames = TRUE
  )
  saveRDS(results, file.path(out, "cv_results.rds"))

  message("Results written to ", workbook)
  invisible(results)
}


main <- function() {
  args <- parse_args(list(
    dataset  = NULL,
    config   = "configs/datasets.yml",
    data_dir = NULL
  ))
  require_args(args, "dataset")

  load_packages()
  config <- load_config(args$config)
  cfg <- resolve_dataset(args$dataset, config, args$data_dir)

  evaluate_classifiers(cfg)
}


if (sys.nframe() == 0) main()
