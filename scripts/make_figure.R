#!/usr/bin/env Rscript
# Stage 3: the paper's four-panel AUROC figure for one dataset.

source("R/utils/setup.R")
source_modules()


#' Draw the figure from stage 2's saved results.
make_dataset_figure <- function(cfg) {
  path <- file.path(output_dir(cfg, "evaluation"), "cv_results.rds")
  if (!file.exists(path)) {
    stop(
      "Results not found: ", path,
      "\nRun scripts/evaluate_classifiers.R --dataset ", cfg$dataset, " first.",
      call. = FALSE
    )
  }
  results <- readRDS(path)

  methods <- colnames(results[[1]])
  out <- output_dir(cfg, "figure")

  make_figure(
    results_list = results,
    stepsize     = cfg$stepsize,
    methods      = methods,
    path         = file.path(out, paste0(cfg$dataset, "_plot.pdf"))
  )
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

  make_dataset_figure(cfg)
}


if (sys.nframe() == 0) main()
