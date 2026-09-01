# A Practical Guide to FHK Productivity Decomposition

## 1. What is being decomposed?

For a unit-level productivity measure $`p_{it}`$ and period-specific
weight share $`s_{it}`$, aggregate productivity is

``` math
P_t = \sum_i s_{it}p_{it}.
```

Between endpoints 0 and 1, units are classified as continuers ($`C`$),
entrants ($`E`$), or exiters ($`X`$). `fhktools` implements

``` math
\begin{aligned}
P_1-P_0 =
&\sum_{i\in C}s_{i0}(p_{i1}-p_{i0}) \\
&+\sum_{i\in C}(s_{i1}-s_{i0})(p_{i0}-P_0) \\
&+\sum_{i\in C}(s_{i1}-s_{i0})(p_{i1}-p_{i0}) \\
&+\sum_{i\in E}s_{i1}(p_{i1}-P_0) \\
&-\sum_{i\in X}s_{i0}(p_{i0}-P_0).
\end{aligned}
```

These lines correspond to within, between, cross, entry, and exit. The
returned `exit` column already contains the minus sign.

The identity is algebraic. A small residual verifies implementation and
input consistency, but does not prove that productivity, weights, unit
identifiers, or turnover are economically well defined.

## 2. The minimum data contract

Each endpoint panel should have:

1.  one row per analytical unit and period;
2.  a stable identifier across time;
3.  a numeric productivity measure;
4.  a non-negative raw size or share; and
5.  an ordered, non-factor period variable.

``` r

data(fhk_example)
str(fhk_example)
#> 'data.frame':    20 obs. of  10 variables:
#>  $ firm_id              : chr  "A" "B" "C" "D" ...
#>  $ year                 : int  2010 2010 2010 2010 2010 2010 2011 2011 2011 2011 ...
#>  $ industry             : chr  "Manufacturing" "Manufacturing" "Manufacturing" "Services" ...
#>  $ productivity         : num  3.2 2.8 3.6 2.5 2.2 2.9 3.35 3 3.55 2.75 ...
#>  $ productivity_alt     : num  3.23 2.78 3.61 2.53 2.18 2.91 3.38 2.98 3.56 2.78 ...
#>  $ employment           : num  100 80 60 120 70 50 105 75 62 115 ...
#>  $ global_share         : num  0.208 0.167 0.125 0.25 0.146 ...
#>  $ within_industry_share: num  0.417 0.333 0.25 0.5 0.292 ...
#>  $ first_active_year    : int  2005 2004 2008 2002 2006 2007 2005 2004 2008 2002 ...
#>  $ last_active_year     : int  2015 2015 2015 2015 2011 2010 2015 2015 2015 2015 ...
```

The analytical unit matters. If a firm can own several plants, a firm ID
cannot be used with plant-level productivity unless the plants are first
aggregated or a plant ID is used. The package checks duplicated
unit-period rows before any group split, including duplicates that occur
under different industry labels.

## 3. Start with raw weights

Using raw employment, sales, or output is generally safer than creating
shares outside the function. The denominator then remains explicit in
the result.

``` r

z <- fhk_decomposition(
  fhk_example,
  firm_col = "firm_id",
  time_col = "year",
  prod_col = "productivity",
  weight_col = "employment",
  t0 = 2010,
  t1 = 2012
)

z[, c(
  "P0", "P1", "aggregate_change",
  "within", "between", "cross", "entry", "exit",
  "component_sum", "residual", "identity_ok"
)]
#>        P0       P1 aggregate_change within     between       cross      entry
#> 1 2.83125 3.200192        0.3689423   0.25 0.009827724 -0.02269231 0.04691106
#>         exit component_sum     residual identity_ok
#> 1 0.08489583     0.3689423 5.551115e-17        TRUE
```

Important audit columns include:

- `weight_total_t0` and `weight_total_t1`;
- counts and weight shares of continuers, entrants, and exiters;
- `turnover_basis` and `turnover_validated`; and
- `residual` and `identity_ok`.

## 4. Raw weights versus pre-computed shares

The clean example includes global employment shares. They reproduce the
raw weight calculation:

``` r

from_share <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "global_share",
  2010, 2012,
  weight_is_share = TRUE
)

fields <- c("aggregate_change", "within", "between", "cross", "entry", "exit")
rbind(raw = unlist(z[fields]), supplied_share = unlist(from_share[fields]))
#>                aggregate_change within     between       cross      entry
#> raw                   0.3689423   0.25 0.009827724 -0.02269231 0.04691106
#> supplied_share        0.3689423   0.25 0.009827724 -0.02269231 0.04691106
#>                      exit
#> raw            0.08489583
#> supplied_share 0.08489583
```

When `weight_is_share = TRUE`, shares must sum to one at the declared
scope. Automatic renormalization is off by default because it can
conceal a wrong denominator. If renormalization is substantively
justified, set `renormalize_input_shares = TRUE` and retain the audit
fields in the archived results.

## 5. Sample turnover versus genuine birth and death

A two-endpoint panel identifies presence and absence. It does not
automatically identify business birth and death. Survey rotation,
intermittent reporting, and failed linkage can all mimic entry or exit.

The example supplies registry-style activity windows:

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
  "share_entrants_t1", "share_exiters_t0",
  "turnover_basis", "turnover_validated"
)]
#>   n_continuers n_entrants n_exiters share_entrants_t1 share_exiters_t0
#> 1            4          3         2         0.3019231             0.25
#>                                 turnover_basis turnover_validated
#> 1 sample_presence_validated_by_activity_window               TRUE
```

Entrants must have first activity in $`(t_0,t_1]`$; exiters must have
last activity in $`[t_0,t_1)`$. Continuers must be active by $`t_0`$ and
through $`t_1`$.

If no registry fields exist, report the terms as *sample entry* and
*sample exit*. Do not relabel them as business creation and destruction.

## 6. Grouped analysis

``` r

g <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "employment",
  2010, 2012,
  group_cols = "industry"
)

g[, c(
  "industry", "P0", "P1", "aggregate_change",
  "within", "between", "cross", "entry", "exit"
)]
#>        industry       P0       P1 aggregate_change within      between
#> 1 Manufacturing 3.166667 3.422414        0.2557471    0.3 2.126437e-02
#> 2      Services 2.495833 2.920000        0.4241667    0.2 5.434783e-05
#>          cross       entry        exit
#> 1 -0.055172414 -0.01034483 0.000000000
#> 2  0.005217391  0.21681159 0.002083333
```

Weights are normalized within every group-period. These components
describe within-industry productivity dynamics; they are not additive
across industries. Use
[`fhk_hierarchical()`](https://jingyiyiyiyi.github.io/fhktools/reference/fhk_hierarchical.md)
when both levels are needed:

``` r

h <- fhk_hierarchical(
  fhk_example,
  "firm_id", "year", "productivity", "employment",
  2010, 2012,
  group_cols = "industry"
)

h$overall[, c("aggregate_change", "identity_ok")]
#>   aggregate_change identity_ok
#> 1        0.3689423        TRUE
h$by_group[, c("industry", "aggregate_change", "identity_ok")]
#>        industry aggregate_change identity_ok
#> 1 Manufacturing        0.2557471        TRUE
#> 2      Services        0.4241667        TRUE
```

If only within-industry shares are available, industry weights in the
aggregate economy cannot be recovered. Raw weights or global shares are
needed for a hierarchical analysis.

## 7. Industry movers and endpoint-only groups

`fhk_complex_example` is designed to trigger safeguards:

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

Firm B changes industry, and Construction appears only at the first
endpoint. The default grouped analysis stops. If the industry movement
is genuine and the old-group exit/new-group entry interpretation is
intended, say so explicitly:

``` r

g_complex <- fhk_decomposition(
  fhk_complex_example,
  "firm_id", "year", "productivity", "employment",
  2010, 2012,
  group_cols = "industry",
  first_active_col = "first_active_year",
  last_active_col = "last_active_year",
  group_change_action = "allow",
  incomplete_group_action = "drop"
)

attr(g_complex, "skipped_groups")
#>       industry present_t0 present_t1 n_rows
#> 1 Construction       TRUE      FALSE      1
g_complex[, c(
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

The group-specific `turnover_validated` remains false when movers are
present, because firm activity windows cannot validate entry into or
exit from a group. The separate `global_firm_turnover_validated` field
records the firm birth/death audit.

When industry-code changes are administrative rather than economic,
harmonize codes before decomposition instead of allowing movers.

## 8. Missing values and zero weights

Missing or non-finite required values stop by default.
`na_action = "drop"` issues a warning because dropping a row can create
an apparent entrant or exiter. Archive the warning and compare sample
counts before and after any drop-based robustness specification.

Zero-weight rows are retained and counted by default. They do not affect
the weighted aggregate but do affect presence-based classifications.
Alternatives are `zero_weight_action = "drop"` and
`zero_weight_action = "error"`. A period or group with a zero total
weight cannot be decomposed.

## 9. Annual and other adjacent transitions

``` r

annual <- fhk_adjacent(
  fhk_example,
  "firm_id", "year", "productivity", "employment",
  expected_step = 1
)

annual[, c(
  "period_start", "period_end", "aggregate_change",
  "n_entrants", "n_exiters", "identity_ok"
)]
#>   period_start period_end aggregate_change n_entrants n_exiters identity_ok
#> 1         2010       2011       0.09863281          2         1        TRUE
#> 2         2011       2012       0.27030950          1         1        TRUE
```

The wrapper uses global observed periods, so groups share common
endpoints. `expected_step` protects against treating the next observed
year as the next calendar year when there is a gap.

Long differences and annual decompositions answer different questions. A
firm that enters after 2010 and exits before 2012 is absent from both
long-difference endpoints but can contribute to annual transitions.

## 10. Multiple productivity measures

``` r

m <- fhk_multi_measure(
  fhk_example,
  "firm_id", "year",
  c("productivity", "productivity_alt"),
  "employment",
  2010, 2012,
  common_sample = TRUE
)

m[, c("measure", "aggregate_change", "within", "entry", "exit")]
#>            measure aggregate_change    within      entry       exit
#> 1     productivity        0.3689423 0.2500000 0.04691106 0.08489583
#> 2 productivity_alt        0.3582083 0.2345833 0.04668550 0.08921875
```

For measures with different missingness, use `common_sample = TRUE` and
`na_action = "drop"` to remove rows invalid for any requested measure
once. Otherwise, apparently different decompositions may reflect
different samples.

## 11. Reporting checklist

A reproducible empirical table should report or archive:

1.  analytical unit and identifier construction;
2.  endpoint periods and whether the comparison is annual or a long
    difference;
3.  productivity level/log definition and estimation method;
4.  raw weighting variable and denominator scope;
5.  group classification and crosswalk policy;
6.  sample-entry/exit versus registry-validated birth/death
    interpretation;
7.  missing-value, zero-weight, mover, and incomplete-group policies;
8.  continuer, entrant, and exiter counts and shares; and
9.  the accounting residual and `identity_ok`.

Save the complete returned data frame before selecting columns for
publication. The audit fields are part of the empirical record.

## 12. Citation

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

The methodological reference is Foster, Haltiwanger, and Krizan (2001),
“Aggregate Productivity Growth: Lessons from Microeconomic Evidence,”
<https://doi.org/10.3386/w6803>.
