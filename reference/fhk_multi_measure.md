# Apply the Same FHK Design to Multiple Productivity Measures

Runs comparable decompositions for several productivity measures, with
an optional common-sample rule.

## Usage

``` r
fhk_multi_measure(
  df,
  firm_col,
  time_col,
  prod_cols,
  weight_col,
  t0,
  t1,
  group_cols = NULL,
  weight_is_share = FALSE,
  renormalize_input_shares = FALSE,
  na_action = c("error", "drop"),
  tol = 1e-10,
  fail_on_identity_error = TRUE,
  common_sample = TRUE,
  ...
)
```

## Arguments

- df, firm_col, time_col, weight_col, t0, t1, group_cols,
  weight_is_share, renormalize_input_shares, na_action, tol,
  fail_on_identity_error:

  See
  [`fhk_decomposition`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_decomposition.md).

- prod_cols:

  Unique names of numeric productivity or outcome columns.

- common_sample:

  When `TRUE` and `na_action = "drop"`, remove rows invalid for any
  requested measure once before running the decompositions.

- ...:

  Additional arguments passed to
  [`fhk_decomposition()`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_decomposition.md).

## Value

A data frame with a `measure` column identifying each outcome.

## Examples

``` r
data(fhk_example)
ans <- fhk_multi_measure(
  fhk_example, "firm_id", "year",
  c("productivity", "productivity_alt"), "employment",
  2010, 2012
)
ans[, c("measure", "aggregate_change", "identity_ok")]
#>            measure aggregate_change identity_ok
#> 1     productivity        0.3689423        TRUE
#> 2 productivity_alt        0.3582083        TRUE
```
