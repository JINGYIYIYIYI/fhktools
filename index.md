# fhktools

[![R-CMD-check](https://github.com/JINGYIYIYIYI/fhktools/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/JINGYIYIYIYI/fhktools/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/JINGYIYIYIYI/fhktools/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/JINGYIYIYIYI/fhktools/actions/workflows/pkgdown.yaml)
[![MIT
license](https://img.shields.io/badge/license-MIT-blue.svg)](https://jingyiyiyiyi.github.io/fhktools/LICENSE.md)

`fhktools` is a defensive, dependency-free R implementation of the
standard Foster–Haltiwanger–Krizan (FHK) productivity decomposition. It
is designed for empirical panels where duplicated units, malformed
shares, industry-code changes, survey rotation, missing values, and
ambiguous entry/exit definitions are real concerns.

中文用户请参阅[中文完整教程](https://jingyiyiyiyi.github.io/fhktools/vignettes/fhk-zh.Rmd)。An
English step-by-step guide is available in the [introductory
vignette](https://jingyiyiyiyi.github.io/fhktools/vignettes/fhk-introduction.Rmd).

## Why this package?

Many short FHK scripts reproduce the five-term accounting formula but
silently make consequential data decisions. `fhktools` separates three
questions:

1.  **Does the accounting identity close?** Every result reports a
    scaled residual and `identity_ok`.
2.  **Are the input shares and panel keys valid?** Unsafe
    factor-to-numeric conversions, duplicated unit-period rows, negative
    weights, missing group labels, and malformed shares are rejected by
    default.
3.  **What does turnover mean?** Without registry information, entry and
    exit are explicitly labeled as sample presence. Firm birth/death,
    sample turnover, and movement between industries are kept
    conceptually separate.

The endpoint identity is

``` math
\Delta P = \text{Within} + \text{Between} + \text{Cross}
           + \text{Entry} + \text{Exit},
```

with

``` math
\begin{aligned}
\text{Within}  &= \sum_{i\in C}s_{i0}(p_{i1}-p_{i0}),\\
\text{Between} &= \sum_{i\in C}(s_{i1}-s_{i0})(p_{i0}-P_0),\\
\text{Cross}   &= \sum_{i\in C}(s_{i1}-s_{i0})(p_{i1}-p_{i0}),\\
\text{Entry}   &= \sum_{i\in E}s_{i1}(p_{i1}-P_0),\\
\text{Exit}    &= -\sum_{i\in X}s_{i0}(p_{i0}-P_0).
\end{aligned}
```

The returned `exit` component already contains the leading minus sign.

## Installation

Install the development version from GitHub:

``` r

install.packages("pak")
pak::pak("JINGYIYIYIYI/fhktools")

# Or:
install.packages("remotes")
remotes::install_github("JINGYIYIYIYI/fhktools")
```

## Quick start with raw weights

The package includes a synthetic, unbalanced firm panel with genuine
endpoint entry and exit, stable industry codes, raw employment, global
shares, within-industry shares, and registry-style activity windows.

``` r

library(fhktools)
data(fhk_example)
head(fhk_example[, c("firm_id", "year", "industry", "productivity", "employment")])
#>   firm_id year      industry productivity employment
#> 1       A 2010 Manufacturing          3.2        100
#> 2       B 2010 Manufacturing          2.8         80
#> 3       C 2010 Manufacturing          3.6         60
#> 4       D 2010      Services          2.5        120
#> 5       E 2010      Services          2.2         70
#> 6       F 2010      Services          2.9         50
```

Raw sales, employment, or output weights are usually safest because the
package can construct period-specific shares with a transparent
denominator.

``` r

overall <- fhk_decomposition(
  fhk_example,
  firm_col = "firm_id",
  time_col = "year",
  prod_col = "productivity",
  weight_col = "employment",
  t0 = 2010,
  t1 = 2012
)

round(overall[, c(
  "aggregate_change", "within", "between", "cross", "entry", "exit",
  "residual"
)], 6)
#>   aggregate_change within  between     cross    entry     exit residual
#> 1         0.368942   0.25 0.009828 -0.022692 0.046911 0.084896        0
```

`aggregate_change` equals the sum of the five components up to
floating-point rounding. Percentage columns are signed contributions
relative to the signed aggregate change. They are `NA` when the
aggregate change is too close to zero.

## Validate genuine firm entry and exit

Sample absence can reflect business closure, survey rotation, matching
failure, or a missing observation. If registry-style activity dates are
available, use them explicitly:

``` r

validated <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "employment",
  2010, 2012,
  first_active_col = "first_active_year",
  last_active_col = "last_active_year",
  turnover_validation = "error"
)

validated[, c(
  "n_continuers", "n_entrants", "n_exiters",
  "turnover_basis", "turnover_validated"
)]
#>   n_continuers n_entrants n_exiters
#> 1            4          3         2
#>                                 turnover_basis turnover_validated
#> 1 sample_presence_validated_by_activity_window               TRUE
```

Without those columns, `turnover_basis` is `"sample_presence"`. That is
an interpretation warning, not an accounting failure.

## Grouped decompositions

``` r

by_industry <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "employment",
  2010, 2012,
  group_cols = "industry"
)

by_industry[, c(
  "industry", "aggregate_change", "within", "between", "cross",
  "entry", "exit", "identity_ok"
)]
#>        industry aggregate_change within      between        cross       entry
#> 1 Manufacturing        0.2557471    0.3 2.126437e-02 -0.055172414 -0.01034483
#> 2      Services        0.4241667    0.2 5.434783e-05  0.005217391  0.21681159
#>          exit identity_ok
#> 1 0.000000000        TRUE
#> 2 0.002083333        TRUE
```

Within-group weights are normalized inside each group. Do **not** add
the industry components to construct an economy-wide decomposition. Use
[`fhk_hierarchical()`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_hierarchical.md)
to obtain both levels from correctly defined weights:

``` r

both_levels <- fhk_hierarchical(
  fhk_example,
  "firm_id", "year", "productivity", "employment",
  2010, 2012,
  group_cols = "industry"
)

both_levels$overall[, c("aggregate_change", "identity_ok")]
#>   aggregate_change identity_ok
#> 1        0.3689423        TRUE
both_levels$by_group[, c("industry", "aggregate_change", "identity_ok")]
#>        industry aggregate_change identity_ok
#> 1 Manufacturing        0.2557471        TRUE
#> 2      Services        0.4241667        TRUE
```

## Pre-computed shares

The package distinguishes shares that sum to one globally from shares
that sum to one inside every group-period:

``` r

from_global_shares <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "global_share",
  2010, 2012,
  group_cols = "industry",
  weight_is_share = TRUE,
  share_scope = "global"
)

from_within_group_shares <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "within_industry_share",
  2010, 2012,
  group_cols = "industry",
  weight_is_share = TRUE,
  share_scope = "within_group"
)
```

Malformed shares fail by default. Set `renormalize_input_shares = TRUE`
only when renormalization is substantively justified; the result records
which periods were renormalized.

## Complex panels: explicit policies

`fhk_complex_example` deliberately contains an industry mover, a group
present at only one endpoint, a zero-weight row, and a missing
alternative productivity value.

``` r

data(fhk_complex_example)
subset(
  fhk_complex_example,
  firm_id %in% c("B", "J") | employment == 0 | is.na(productivity_alt)
)[, c("firm_id", "year", "industry", "productivity_alt", "employment")]
#>    firm_id year      industry productivity_alt employment
#> 2        B 2010 Manufacturing             2.78         80
#> 7        J 2010  Construction             2.68         35
#> 9        B 2011 Manufacturing             2.98         75
#> 10       C 2011 Manufacturing             3.56          0
#> 14       H 2011      Services               NA         55
#> 16       B 2012      Services             3.26         70
```

The default grouped call stops because a continuing firm changes
industry. If the movement is real and the old/new industry
interpretation is intended, make that policy explicit. Endpoint-only
groups can likewise be dropped explicitly; they remain available in an
audit attribute.

``` r

complex_result <- fhk_decomposition(
  fhk_complex_example,
  "firm_id", "year", "productivity", "employment",
  2010, 2012,
  group_cols = "industry",
  first_active_col = "first_active_year",
  last_active_col = "last_active_year",
  group_change_action = "allow",
  incomplete_group_action = "drop"
)

attr(complex_result, "skipped_groups")
#>       industry present_t0 present_t1 n_rows
#> 1 Construction       TRUE      FALSE      1
complex_result[, c(
  "industry", "n_group_movers", "turnover_basis",
  "global_firm_turnover_validated", "identity_ok"
)]
#>        industry n_group_movers                            turnover_basis
#> 1 Manufacturing              1 group_membership_presence_includes_movers
#> 2      Services              1 group_membership_presence_includes_movers
#>   global_firm_turnover_validated identity_ok
#> 1                           TRUE        TRUE
#> 2                           TRUE        TRUE
```

An industry mover is an old-industry exit and a new-industry entrant,
but it is not a firm death or birth. The `global_firm_turnover_*`
columns preserve the separate firm-level activity audit.

## Adjacent periods

``` r

annual <- fhk_adjacent(
  fhk_example,
  "firm_id", "year", "productivity", "employment",
  expected_step = 1
)

annual[, c("period_start", "period_end", "aggregate_change", "identity_ok")]
#>   period_start period_end aggregate_change identity_ok
#> 1         2010       2011       0.09863281        TRUE
#> 2         2011       2012       0.27030950        TRUE
```

`expected_step = 1` prevents 2010–2012 from being silently treated as an
annual transition when 2011 is absent.

## Multiple productivity measures on a common sample

``` r

multiple <- fhk_multi_measure(
  fhk_example,
  "firm_id", "year",
  c("productivity", "productivity_alt"),
  "employment",
  2010, 2012,
  common_sample = TRUE
)

multiple[, c("measure", "aggregate_change", "identity_ok")]
#>            measure aggregate_change identity_ok
#> 1     productivity        0.3689423        TRUE
#> 2 productivity_alt        0.3582083        TRUE
```

With `common_sample = TRUE` and `na_action = "drop"`, a row missing any
requested measure is removed once for all measures. This avoids
comparing decompositions that use different firm samples.

## What the package checks

| Risk | Default behavior | Explicit alternative |
|----|----|----|
| Factor productivity or weights | Error | Convert and verify outside the function |
| Duplicate unit-period rows | Error | Aggregate or construct a valid unit ID |
| Missing/non-finite required values | Error | `na_action = "drop"` with warning |
| Negative weights | Error | None |
| Zero weights | Keep and report | `zero_weight_action = "drop"` or `"error"` |
| Shares do not sum to one | Error | `renormalize_input_shares = TRUE` |
| Continuing unit changes group | Error | `group_change_action = "warn"` or `"allow"` |
| Group absent at one endpoint | Error | `incomplete_group_action = "warn"` or `"drop"` |
| Reversed endpoints | Error | `require_t1_after_t0 = FALSE` |
| Accounting identity does not close | Error | Inspect with `fail_on_identity_error = FALSE` |

## Interpretation limits

Software cannot choose the empirical estimand for you. Before reporting
a decomposition, decide and document:

- whether the analytical unit is a firm, establishment, or firm-product;
- whether employment, sales, or output is the economically appropriate
  weight;
- whether productivity is in levels or logs;
- whether absence means true exit, sample rotation, or failed matching;
- whether industry classifications are harmonized across time; and
- whether a long difference or annual transitions match the research
  question.

A perfectly closing identity does not prove that these choices are
correct.

## Citation

``` r

citation("fhktools")
#> To cite package 'fhktools' in publications use:
#> 
#>   Li Y (2026). _fhktools: Robust Foster-Haltiwanger-Krizan Productivity
#>   Decompositions_. R package version 0.1.0,
#>   <https://github.com/JINGYIYIYIYI/fhktools>.
#> 
#> A BibTeX entry for LaTeX users is
#> 
#>   @Manual{,
#>     title = {fhktools: Robust Foster-Haltiwanger-Krizan Productivity Decompositions},
#>     author = {Yu Li},
#>     year = {2026},
#>     note = {R package version 0.1.0},
#>     url = {https://github.com/JINGYIYIYIYI/fhktools},
#>   }
```

The methodological reference is:

Foster, L., Haltiwanger, J., and Krizan, C. J. (2001). “Aggregate
Productivity Growth: Lessons from Microeconomic Evidence.” In *New
Developments in Productivity Analysis*. <https://doi.org/10.3386/w6803>.

## Development

``` r

devtools::test()
devtools::check()
pkgdown::build_site()
```

Contributions are welcome. Please read
[CONTRIBUTING.md](https://jingyiyiyiyi.github.io/fhktools/CONTRIBUTING.md)
and do not upload confidential firm-level data.
