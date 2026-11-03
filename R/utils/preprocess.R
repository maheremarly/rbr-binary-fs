# Loading, pre-filtering, cleaning and splitting one dataset.
#
# The order of these steps is load-bearing: the univariate pre-filter runs on
# the raw columns, and the renaming to x1 ... xp happens last so that the model
# formulas built in R/models/classifiers.R are always syntactically valid.


#' Read one dataset and name its target column `Class`.
load_dataset <- function(path, target) {
  if (!file.exists(path)) {
    stop("Dataset not found: ", path, call. = FALSE)
  }
  raw <- utils::read.csv(path)

  if (!target %in% names(raw)) {
    stop(
      "Target column '", target, "' not in ", basename(path),
      ". Columns: ", paste(utils::head(names(raw), 20), collapse = ", "),
      call. = FALSE
    )
  }

  # Move the target to the last position under a fixed name, which the
  # pre-filter and the cleaning steps below both assume.
  raw$Class <- raw[[target]]
  if (target != "Class") raw[[target]] <- NULL
  raw
}


#' Keep the n_prefilter features with the smallest FDR-adjusted t-test p-value.
#'
#' A univariate screen run before the filters themselves, so that the
#' comparison is made on a feature set of tractable size.
prefilter_by_ttest <- function(data, n_prefilter) {
  features <- setdiff(names(data), "Class")

  p_values <- t(sapply(data[features], function(x) {
    unlist(stats::t.test(x ~ data$Class)[c("estimate", "p.value")])
  }))

  # Column 3 is p.value; columns 1 and 2 are the two class means.
  p_adjusted <- stats::p.adjust(p_values[, 3], method = "fdr")
  p_adjusted <- p_adjusted[order(p_adjusted), drop = FALSE]

  keep <- min(n_prefilter, length(p_adjusted))
  if (keep < n_prefilter) {
    message(
      "n_prefilter (", n_prefilter, ") exceeds the ", length(p_adjusted),
      " available features; keeping all of them."
    )
  }

  data[, c(names(p_adjusted)[seq_len(keep)], "Class")]
}


#' Drop uninformative columns and put the frame in modelling form.
#'
#' Removes incomplete rows, constant columns, every factor column except the
#' target, and near-zero-variance columns; makes the remaining features numeric;
#' then renames the features x1 ... xp and the target `y` with levels 1 and 2.
clean_dataset <- function(data) {
  data <- stats::na.omit(data)

  # Constant columns carry no signal and break the variance terms in the filter.
  data <- Filter(function(x) length(unique(x[!is.na(x)])) > 1, data)

  # Two-valued columns are categorical; only the target is kept as a factor.
  binary_cols <- names(Filter(function(x) length(unique(x[!is.na(x)])) == 2, data))
  data[binary_cols] <- lapply(data[binary_cols], factor)
  drop_factors <- setdiff(names(Filter(is.factor, data)), "Class")
  data <- data[, !names(data) %in% drop_factors]

  data$y <- data$Class
  data$Class <- NULL

  near_zero <- caret::nearZeroVar(data, freqCut = 99 / 1, names = TRUE)
  data[near_zero] <- NULL

  int_cols <- names(which(sapply(data, is.integer) & names(data) != "y"))
  data <- data %>% dplyr::mutate(dplyr::across(dplyr::all_of(int_cols), as.numeric))

  colnames(data) <- paste0("x", seq_len(ncol(data)))
  colnames(data)[ncol(data)] <- "y"
  levels(data$y) <- 1:2

  data
}


#' Shuffle, then split off the leading `train_fraction` of the rows.
#'
#' Seed the stream before calling this: the shuffle consumes random numbers that
#' the RBR filter's Monte Carlo then continues from.
split_dataset <- function(data, train_fraction = 2 / 3) {
  data <- data[sample(nrow(data)), ]
  n_train <- floor(train_fraction * nrow(data))
  list(
    train = data[1:n_train, ],
    test  = data[-(1:n_train), ],
    all   = data
  )
}


#' Load, pre-filter, clean and split one dataset in a single call.
prepare_dataset <- function(cfg) {
  message("==> Loading ", cfg$path)
  raw <- load_dataset(cfg$path, cfg$target)
  message("    ", nrow(raw), " rows, ", ncol(raw) - 1, " features")

  message("==> Pre-filtering to the top ", cfg$n_prefilter, " features by t-test")
  screened <- prefilter_by_ttest(raw, cfg$n_prefilter)

  message("==> Cleaning")
  clean <- clean_dataset(screened)
  message("    ", nrow(clean), " rows, ", ncol(clean) - 1, " features retained")

  set_seed(cfg$seed)
  split_dataset(clean, cfg$train_fraction)
}
