# Reproducing the experiments

All commands are run from the repository root. Stage 1 must finish before stage 2, and stage 2
before stage 3; each stage reads the previous one's files from
`output/<dataset>/`.

Every stage reseeds from `seed:` in `configs/datasets.yml`, so a stage can be rerun on its own and
will give the same answer. Nothing depends on the state of an interactive session.

## 1. One dataset

```bash
Rscript scripts/rank_features.R        --dataset ionosphere
Rscript scripts/evaluate_classifiers.R --dataset ionosphere
Rscript scripts/make_figure.R          --dataset ionosphere
```

Writes, under `output/ionosphere/`:

```text
ranking/filter_scores.csv        # normalised strength, information gain, symmetric uncertainty
ranking/feature_rankings.csv     # one ranked feature column per method: Rb_St, IG, SU
evaluation/ionosphere_results.xlsx  # one sheet per classifier
evaluation/cv_results.rds        # the same tables, read by stage 3
figure/ionosphere_plot.pdf       # the four-panel AUROC figure
```

Each workbook sheet has one column per method and 21 rows: ten error rates for the retained-feature
fractions 100% down to 10%, a blank separator row, then the ten AUROC values for the same fractions.
The figures and the paper's tables use the AUROC block.

## 2. All eighteen datasets

```bash
for dataset in philippine optdigits satellite \
               image_desert image_mountains image_sea image_sunset \
               scene_beach scene_fallfoliage scene_field scene_mountain \
               scene_sunset scene_urban \
               musk ionosphere toxicity period_changer madelon; do
    Rscript scripts/rank_features.R        --dataset "$dataset" &&
    Rscript scripts/evaluate_classifiers.R --dataset "$dataset" &&
    Rscript scripts/make_figure.R          --dataset "$dataset"
done
```

Stage 1 dominates the runtime: the RBR filter draws 10,000 prior and 10,000 posterior values per
feature, so cost grows linearly in the number of features surviving the t-test screen. On the
machine the paper reports (Windows 10, 8 GB RAM, AMD Ryzen 5 4600H at 3.00 GHz) Ionosphere's 34
features take under a minute, while Toxicity's 1,203 and Madelon's 500 take hours. Lower
`rbr_draws` in the configuration for a quick check, but report only runs at 10,000.

## 3. Options

Data in a directory other than `data/`:

```bash
Rscript scripts/rank_features.R --dataset musk --data_dir /path/to/csvs
```

A configuration file other than `configs/datasets.yml`:

```bash
Rscript scripts/rank_features.R --dataset musk --config configs/my_datasets.yml
```

Which rows the filters rank on. The default, `train`, uses the training two-thirds, as the paper
describes; `all` scores on the whole cleaned dataset. The two give different rankings and therefore
different figures.

```bash
Rscript scripts/rank_features.R --dataset ionosphere --score_on all
```

### `--prior paper | solved`

Which set of Gamma hyperparameters the RBR filter uses. The default, `paper`, is the specification
the article states: `alpha0 = beta0 = 2`, held fixed. `solved` runs a Newton elicitation instead,
which lands at `alpha0 = 6.4546`, `beta0 = 26.8415`. Both give `mu0 = 1` and `lambda0 = 0.25`.

```bash
Rscript scripts/rank_features.R --dataset ionosphere --prior solved
```

## 4. Adding a dataset

Add an entry under `data:` in `configs/datasets.yml`:

```yaml
  my_dataset:
    file: "my_dataset.csv"
    target: "label"        # if the class column is not called `class`
    n_prefilter: 200       # if the t-test screen should keep fewer features
```

Everything in `defaults:` is inherited; anything named in the entry overrides it. The target must
have exactly two classes, and the features must be continuous: `clean_dataset()` drops every
categorical column other than the target.

## 5. Which command produces which result in the paper

| In the paper | Produced by |
|---|---|
| Table 2, dataset characteristics | `configs/datasets.yml` (the eighteen entries, with shapes in the comments) |
| Figures 5–22, AUROC against features retained, one per dataset | `make_figure.R`, from stage 2's AUROC block |
| Figure of Musk and Scene (Fallfoliage) KNN performance | the KNN panel of those two datasets' figures |
| Figure of Image (Mountains) and Ionosphere logistic regression | the logistic regression panel of those two datasets' figures |
| Table 3, maximum AUROC per dataset and classifier, with the winning method | the column-wise maximum of each workbook sheet's AUROC block; not scripted here |
| Section 4.1, Friedman and Mitra synthetic studies | not in this repository |

The last two rows are the gaps. Taking the per-dataset maximum across the ten thresholds and four
classifiers is a few lines over the saved `cv_results.rds` files, and is not scripted here.
