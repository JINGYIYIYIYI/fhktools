# Compute Economy-Wide and Within-Group FHK Results

Returns a direct economy-wide decomposition and correctly normalized
within-group decompositions from the same endpoint design.

## Usage

``` r
fhk_hierarchical(
  df,
  firm_col,
  time_col,
  prod_col,
  weight_col,
  t0,
  t1,
  group_cols,
  weight_is_share = FALSE,
  share_scope = c("global", "within_group"),
  ...
)
```

## Arguments

- df, firm_col, time_col, prod_col, weight_col, t0, t1:

  See
  [`fhk_decomposition`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_decomposition.md).

- group_cols:

  One or more grouping columns.

- weight_is_share:

  Whether the weight column contains shares.

- share_scope:

  Whether supplied shares are global or within-group. Global shares are
  required to recover economy-wide weights.

- ...:

  Additional arguments passed to
  [`fhk_decomposition()`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_decomposition.md).

## Details

Within-group FHK components use shares normalized inside each group.
They must not simply be summed to construct economy-wide FHK components.
This function returns a direct economy-wide decomposition alongside the
group diagnostics.

## Value

An object of class `fhk_hierarchical_result`: a list with `overall`,
`by_group`, and `skipped_groups`.

## Examples

``` r
data(fhk_example)
ans <- fhk_hierarchical(
  fhk_example, "firm_id", "year", "productivity", "employment",
  2010, 2012, group_cols = "industry"
)
ans$overall$identity_ok
#> [1] TRUE
ans$by_group[, c("industry", "aggregate_change")]
#>        industry aggregate_change
#> 1 Manufacturing        0.2557471
#> 2      Services        0.4241667
```
