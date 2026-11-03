#!/usr/bin/env Rscript
# Stage 1: score one dataset's features with all three filters and rank them.

source("R/utils/setup.R")
source_modules()


#' Prepare the dataset, score its features, and write the scores and rankings.
rank_features <- function(cfg, args) {
  split <- prepare_dataset(cfg)

  # The paper fixes alpha0 and beta0; --prior solved instead reaches the
  # Newton elicitation route.
  prior <- switch(
    args$prior,
    paper  = rbr_prior(),
    solved = solve_prior_hyperparameters(),
    stop("--prior must be 'paper' or 'solved', not '", args$prior, "'.",
         call. = FALSE)
  )
  message(
    "==> Prior (", prior$source, "): ",
    sprintf(
      "alpha0 = %.4f, beta0 = %.4f, mu0 = %.4f, lambda0 = %.4f",
      prior$alpha0, prior$beta0, prior$mu0, prior$lambda0
    )
  )

  # The filters rank on the training split; --score_on all scores on the whole
  # cleaned dataset instead.
  scoring_set <- if (args$score_on == "train") split$train else split$all
  message("==> Scoring on the '", args$score_on, "' set (", nrow(scoring_set), " rows)")

  scores <- score_features(scoring_set, prior = prior, cfg = cfg)
  rankings <- build_rankings(scores)

  out <- output_dir(cfg, "ranking")
  utils::write.csv(scores, file.path(out, "filter_scores.csv"), row.names = TRUE)
  utils::write.csv(rankings, file.path(out, "feature_rankings.csv"), row.names = FALSE)

  message("Scores and rankings written to ", out)
  invisible(rankings)
}


main <- function() {
  args <- parse_args(list(
    dataset  = NULL,
    config   = "configs/datasets.yml",
    data_dir = NULL,
    score_on = "train",
    prior    = "paper"
  ))
  require_args(args, "dataset")

  load_packages()
  config <- load_config(args$config)
  cfg <- resolve_dataset(args$dataset, config, args$data_dir)

  rank_features(cfg, args)
}


if (sys.nframe() == 0) main()
