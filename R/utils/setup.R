# Packages, module loading and seeding.
#
# Scripts are run from the repository root (see docs/reproducing.md), so modules
# are sourced by their path relative to it.


REQUIRED_PACKAGES <- c(
  "yaml", "dplyr", "FSelector", "caret", "arm", "ROCR", "e1071",
  "class", "randomForest", "abind", "reshape2", "ggplot2",
  "gridExtra", "scales", "openxlsx"
)


#' Stop with one actionable message if any required package is missing.
check_packages <- function(packages = REQUIRED_PACKAGES) {
  missing <- packages[
    !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0) {
    stop(
      "Install the following package(s) before running: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}


#' Attach the packages whose functions are called unqualified.
load_packages <- function() {
  check_packages()
  suppressPackageStartupMessages({
    library(dplyr)
    library(FSelector)
    library(caret)
    library(arm)
    library(ROCR)
    library(e1071)
    library(ggplot2)
  })
  invisible(TRUE)
}


#' Source the project's modules, checking first that the cwd is the repo root.
source_modules <- function(root = ".") {
  if (!dir.exists(file.path(root, "R"))) {
    stop(
      "R/ not found. Run this script from the repository root, ",
      "for example: Rscript scripts/rank_features.R --dataset ionosphere",
      call. = FALSE
    )
  }
  modules <- c(
    "R/utils/args.R",
    "R/utils/config.R",
    "R/utils/preprocess.R",
    "R/utils/rankings.R",
    "R/utils/metrics.R",
    "R/utils/plots.R",
    "R/filters/prior.R",
    "R/filters/rbr.R",
    "R/filters/baselines.R",
    "R/models/classifiers.R"
  )
  for (module in modules) source(file.path(root, module))
  invisible(TRUE)
}


#' Set the random seed.
#'
#' Every stage of the pipeline seeds explicitly rather than relying on the
#' session state, so a script can be rerun on its own and give the same answer.
set_seed <- function(seed) {
  set.seed(seed)
  invisible(seed)
}


#' Scale a numeric vector to [0, 1].
normalize <- function(x) {
  (x - min(x)) / (max(x) - min(x))
}
