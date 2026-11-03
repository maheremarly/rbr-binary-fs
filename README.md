# Feature Selection in Binary Classification Problems Using Relative Belief Ratio

Ayman Alzaatreh, Maher Emarly, Rohan Mitra, Luai Al-Labadi

Physica Scripta 100(8), 086010 (2025) · [doi:10.1088/1402-4896/adf517](https://doi.org/10.1088/1402-4896/adf517)

Most filter methods rank features by a score but never ask whether a feature matters at all. This
repository implements a filter that does: each continuous feature is scored by the relative belief
ratio, a Bayesian measure of the evidence against equality of its two class-conditional means. The
ratio comes with a *strength*, the posterior mass on discrepancies no more surprising than the one
observed, and that strength doubles as the feature's importance score. Features are ranked by it and
compared against information gain and symmetric uncertainty across eighteen datasets and four
classifiers.

**Scope.** This repository covers the paper's real-data experiments (Section 4.2): the eighteen
datasets, the three filters, the four classifiers, the ten retained-feature fractions and the AUROC
figures. The synthetic study in Section 4.1 is not included.

## Repository structure

```text
.
├── configs
│   └── datasets.yml                # CSV locations and run settings for all eighteen datasets
├── docs
│   └── reproducing.md              # Commands for every stage, for every dataset
├── R
│   ├── filters
│   │   ├── prior.R                 # The conjugate normal-gamma prior, fixed as the paper states
│   │   ├── rbr.R                   # Relative belief ratio filter and its Monte Carlo
│   │   └── baselines.R             # Information gain and symmetric uncertainty
│   ├── models
│   │   └── classifiers.R           # The four classifiers and the subset-size harness
│   └── utils
│       ├── setup.R                 # Packages, module loading, seeding
│       ├── args.R                  # Command line arguments for scripts/
│       ├── config.R                # configs/datasets.yml to a resolved run configuration
│       ├── preprocess.R            # Pre-filter, cleaning and the train / held-out split
│       ├── rankings.R              # Filter scores to one ranking per method
│       ├── metrics.R               # Results table layout, AUROC, fold averaging
│       └── plots.R                 # The four-panel figure
├── scripts
│   ├── rank_features.R             # Stage 1: filter scores and feature rankings
│   ├── evaluate_classifiers.R      # Stage 2: cross-validated classifier results
│   └── make_figure.R               # Stage 3: the paper's figure
├── .gitignore
├── DESCRIPTION
├── LICENSE
└── README.md
```

Running the pipeline adds `data/` (the CSV files you supply) and
`output/<dataset>/{ranking,evaluation,figure}/` (scores, rankings, workbooks and figures).

## Installation

Tested with R 4.6.1 on macOS and R 4.3 on Windows 10.

```r
install.packages(c(
  "yaml", "dplyr", "FSelector", "caret", "arm", "ROCR", "e1071",
  "class", "randomForest", "abind", "reshape2", "ggplot2",
  "gridExtra", "scales", "openxlsx"
))
```

One external requirement: **Java 8 or newer**, which `FSelector` needs through `RWeka` for the two
baseline filters. Without it `FSelector` will not load and only the RBR filter can be run. On macOS,
`brew install --cask temurin`; on Linux, your distribution's `default-jdk`; on Windows, a JDK plus
`JAVA_HOME` set to it. Run `R CMD javareconf` afterwards if `rJava` still fails to load.

## Data

The eighteen datasets are not redistributed here. They come from four public sources, listed with
their shapes in `configs/datasets.yml`:

| Source | Datasets |
|---|---|
| [automl.chalearn.org](https://automl.chalearn.org/) | Philippine |
| [openml.org](https://www.openml.org/) | Optdigits, Satellite, Image (Desert, Mountains, Sea, Sunset) |
| [mulan.sourceforge.net](https://mulan.sourceforge.net/datasets.html) | Scene (Beach, Fallfoliage, Field, Mountain, Sunset, Urban) |
| [archive.ics.uci.edu](https://archive.ics.uci.edu/) | Musk, Ionosphere, Toxicity, Period Changer, Madelon |

Place each as a CSV in `data/` under the `file:` name given in the configuration, with the class
column named `class` (or set `target:` for that dataset). The multi-label Scene and Image collections
give one dataset per label: keep the label of interest as `class` and drop the others.

## Usage

Run from the repository root. For each dataset, three stages:

1. Score and rank the features (`rank_features.R`). Pre-filters by t-test, cleans, splits
   two-thirds / one-third, elicits the prior, then scores every feature with the RBR filter,
   information gain and symmetric uncertainty.
2. Cross-validate the rankings (`evaluate_classifiers.R`). For each ranking and each of the ten
   retained-feature fractions, fits Bayesian logistic regression, k-nearest neighbours, a random
   forest and an SVM, and records the error rate and the AUROC.
3. Draw the figure (`make_figure.R`). AUROC against fraction of features retained, one panel per
   classifier.

```bash
Rscript scripts/rank_features.R        --dataset ionosphere
Rscript scripts/evaluate_classifiers.R --dataset ionosphere
Rscript scripts/make_figure.R          --dataset ionosphere
```

The RBR filter is the expensive stage: 10,000 prior and 10,000 posterior draws per feature, roughly
twenty times the cost of information gain or symmetric uncertainty. The full commands for all
eighteen datasets are in [docs/reproducing.md](docs/reproducing.md).

## Acknowledgements

This work was carried out at the Department of Mathematics and Statistics, American University of
Sharjah, with the Department of Mathematical and Computational Sciences, University of Toronto
Mississauga, and was supported by the Faculty Research Fund under grant FRG22-C-S58. The relative
belief ratio machinery follows Evans' work on Bayesian measures of evidence and the two-arm trial
formulation of Muthukumarana and Evans.

## License

MIT; see [LICENSE](LICENSE).

## Citation

```bibtex
@article{Alzaatreh_2025_PhysScr,
  author  = {Alzaatreh, Ayman and Emarly, Maher and Mitra, Rohan and Al-Labadi, Luai},
  title   = {Feature selection in binary classification problems using relative belief ratio},
  journal = {Physica Scripta},
  volume  = {100},
  number  = {8},
  pages   = {086010},
  year    = {2025},
  doi     = {10.1088/1402-4896/adf517}
}
```
