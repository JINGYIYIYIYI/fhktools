# Compute FHK Decompositions for Adjacent Observed Periods

Applies the same FHK design to each globally adjacent observed period
pair, optionally enforcing the expected time step.

## Usage

``` r
fhk_adjacent(
  df,
  firm_col,
  time_col,
  prod_col,
  weight_col,
  group_cols = NULL,
  weight_is_share = FALSE,
  renormalize_input_shares = FALSE,
  na_action = c("error", "drop"),
  tol = 1e-10,
  fail_on_identity_error = TRUE,
  expected_step = NULL,
  ...
)
```

## Arguments

- df, firm_col, time_col, prod_col, weight_col, group_cols,
  weight_is_share, renormalize_input_shares, na_action, tol,
  fail_on_identity_error:

  See
  [`fhk_decomposition`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_decomposition.md).

- expected_step:

  Optional required distance between all sorted observed periods, such
  as `1` for annual integer data.

- ...:

  Additional arguments passed to
  [`fhk_decomposition()`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_decomposition.md).

## Details

Period pairs are constructed from the globally observed periods, so all
groups use the same endpoints. Use `expected_step` to prevent gaps such
as 2010 to 2012 from being mislabeled as an annual transition.

## Value

A data frame containing one result per period pair and retained group.

## Examples

``` r
data(fhk_example)
annual <- fhk_adjacent(
  fhk_example, "firm_id", "year", "productivity", "employment",
  expected_step = 1
)
annual[, c("period_start", "period_end", "aggregate_change", "identity_ok")]
#>   period_start period_end aggregate_change identity_ok
#> 1         2010       2011       0.09863281        TRUE
#> 2         2011       2012       0.27030950        TRUE
```
