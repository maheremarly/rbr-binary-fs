# Reads configs/datasets.yml and resolves one dataset's settings.
#
# No path, dataset name or filter size appears anywhere in the code: everything
# that varies between the paper's eighteen datasets lives in the YAML file.


#' Load the configuration file.
load_config <- function(path = "configs/datasets.yml") {
  if (!file.exists(path)) {
    stop("Configuration file not found: ", path, call. = FALSE)
  }
  yaml::yaml.load_file(path)
}


#' Resolve one dataset entry into a complete, validated run configuration.
#'
#' Per-dataset values override the `defaults:` block of the YAML file.
#'
#' @param dataset Key under `data:` in the configuration file.
#' @param config Output of load_config().
#' @param data_dir Overrides `data_dir` from the configuration file.
#' @return A list with file, target, n_prefilter, and every default setting.
resolve_dataset <- function(dataset, config, data_dir = NULL) {
  if (is.null(config$data[[dataset]])) {
    stop(
      "Unknown dataset '", dataset, "'. Available: ",
      paste(names(config$data), collapse = ", "),
      call. = FALSE
    )
  }

  cfg <- utils::modifyList(config$defaults, config$data[[dataset]])
  cfg$dataset <- dataset

  root <- if (!is.null(data_dir)) data_dir else config$data_dir
  if (is.null(root)) {
    stop(
      "No data directory. Set `data_dir` in the configuration file ",
      "or pass --data_dir.",
      call. = FALSE
    )
  }
  cfg$path <- file.path(root, cfg$file)

  stopifnot(is.character(cfg$target), length(cfg$target) == 1)
  stopifnot(is.numeric(cfg$n_prefilter), cfg$n_prefilter >= 1)
  stopifnot(is.numeric(cfg$seed))
  stopifnot(is.numeric(cfg$cv_folds), cfg$cv_folds >= 2)
  stopifnot(all(cfg$stepsize > 0), all(cfg$stepsize <= 1))
  stopifnot(cfg$train_numerator < cfg$train_denominator)

  # The split fraction is stored as two integers and divided here rather than
  # written out as a decimal: floor(2 / 3 * 351) is 234, but floor of the
  # rounded decimal 0.6666666666666666 * 351 is 233, which would move one row
  # between the training and held-out sets and change every published score.
  cfg$train_fraction <- cfg$train_numerator / cfg$train_denominator

  cfg$stepsize <- as.numeric(cfg$stepsize)
  cfg
}


#' Directory this dataset's outputs are written to, created if absent.
output_dir <- function(cfg, stage, root = "output") {
  path <- file.path(root, cfg$dataset, stage)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}
