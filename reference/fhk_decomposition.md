# Compute a Robust Two-Period FHK Decomposition

Computes the standard five-term FHK endpoint decomposition with strict
input, turnover, share, grouping, and accounting audits.

## Usage

``` r
fhk_decomposition(
  df,
  firm_col,
  time_col,
  prod_col,
  weight_col,
  t0,
  t1,
  group_cols = NULL,
  weight_is_share = FALSE,
  share_scope = c("within_group", "global"),
  renormalize_input_shares = FALSE,
  first_active_col = NULL,
  last_active_col = NULL,
  turnover_validation = c("error", "warn", "none"),
  group_change_action = c("error", "warn", "allow"),
  incomplete_group_action = c("error", "warn", "drop"),
  zero_weight_action = c("keep", "drop", "error"),
  na_action = c("error", "drop"),
  require_t1_after_t0 = TRUE,
  tol = 1e-10,
  fail_on_identity_error = TRUE
)
```

## Arguments

- df:

  A data frame with one row per analytical unit and period.

- firm_col:

  Name of the unit identifier column. Use a plant identifier or a
  validated composite identifier if a firm has several establishments or
  products in one period.

- time_col:

  Name of an ordered period column. Numeric, `Date`, `POSIXct`, and
  sortable character periods are supported. Factor periods are rejected.

- prod_col:

  Name of a genuinely numeric productivity or outcome column.

- weight_col:

  Name of a genuinely numeric, non-negative raw size or share column.

- t0, t1:

  Scalar endpoint periods. By default `t1` must be later than `t0`.

- group_cols:

  Optional character vector of industry, market, region, or other
  grouping columns.

- weight_is_share:

  Set to `TRUE` when `weight_col` already contains shares; otherwise raw
  sizes are converted to period shares.

- share_scope:

  For grouped analyses, whether supplied shares sum to one within each
  group-period or globally within each period.

- renormalize_input_shares:

  Whether malformed supplied shares may be explicitly renormalized. The
  default is deliberately strict.

- first_active_col, last_active_col:

  Optional registry-derived first and last activity-period columns used
  to audit whether sample turnover is consistent with firm birth and
  death.

- turnover_validation:

  Action when sample turnover conflicts with supplied activity windows.

- group_change_action:

  Action when a continuing unit changes group. If allowed, it is an exit
  from the old group and entry into the new group, but not a firm death
  or birth.

- incomplete_group_action:

  Action for groups absent at one endpoint. Dropped groups are retained
  in the `"skipped_groups"` attribute.

- zero_weight_action:

  Whether zero-weight rows are kept, dropped with a warning, or
  rejected.

- na_action:

  Whether missing or non-finite required values are rejected or
  explicitly dropped. Dropping can change turnover classifications.

- require_t1_after_t0:

  Whether to require a forward-time comparison.

- tol:

  Finite non-negative scaled tolerance for share and accounting audits.

- fail_on_identity_error:

  Whether a failed accounting identity stops the calculation.

## Details

Let \\P_t = \sum_i s\_{it}p\_{it}\\. The implemented endpoint identity
is \$\$\Delta P = Within + Between + Cross + Entry + Exit,\$\$ where
\$\$Within = \sum\_{i \in C} s\_{i0}(p\_{i1}-p\_{i0}),\$\$ \$\$Between =
\sum\_{i \in C}(s\_{i1}-s\_{i0})(p\_{i0}-P_0),\$\$ \$\$Cross = \sum\_{i
\in C}(s\_{i1}-s\_{i0})(p\_{i1}-p\_{i0}),\$\$ \$\$Entry = \sum\_{i \in
E}s\_{i1}(p\_{i1}-P_0),\$\$ and \$\$Exit = -\sum\_{i \in
X}s\_{i0}(p\_{i0}-P_0).\$\$

The returned `exit` value already includes the leading minus sign and
can therefore be added directly to the other four components.

Without external activity-window information, entry and exit mean sample
entry and sample exit between the endpoints. An accounting identity can
be exact even when the underlying turnover interpretation is wrong, so
users should inspect the audit columns.

## Value

A one-row data frame, or one row per retained group, containing
aggregate productivity at both endpoints, the five components, their
signed percentage contributions, counts and weight shares of
continuers/entrants/exiters, weight and share audits, turnover audits,
and an accounting residual. Key columns are `aggregate_change`,
`within`, `between`, `cross`, `entry`, `exit`, `component_sum`,
`residual`, and `identity_ok`.

## References

Foster, L., Haltiwanger, J., and Krizan, C. J. (2001). Aggregate
productivity growth: Lessons from microeconomic evidence.
[doi:10.3386/w6803](https://doi.org/10.3386/w6803) .

## See also

[`fhk_adjacent`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_adjacent.md),
[`fhk_hierarchical`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_hierarchical.md),
[`fhk_multi_measure`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_multi_measure.md)

## Examples

``` r
data(fhk_example)

overall <- fhk_decomposition(
  fhk_example,
  firm_col = "firm_id",
  time_col = "year",
  prod_col = "productivity",
  weight_col = "employment",
  t0 = 2010,
  t1 = 2012,
  first_active_col = "first_active_year",
  last_active_col = "last_active_year"
)
overall[, c("aggregate_change", "within", "between", "cross", "entry", "exit")]
#>   aggregate_change within     between       cross      entry       exit
#> 1        0.3689423   0.25 0.009827724 -0.02269231 0.04691106 0.08489583

by_industry <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "employment", 2010, 2012,
  group_cols = "industry"
)
by_industry[, c("industry", "aggregate_change", "identity_ok")]
#>        industry aggregate_change identity_ok
#> 1 Manufacturing        0.2557471        TRUE
#> 2      Services        0.4241667        TRUE
```
