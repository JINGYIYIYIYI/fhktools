# FHK 生产率分解：中文完整教程

## 一、先明确分解对象

设企业（或工厂）$`i`$ 在时期 $`t`$ 的生产率为 $`p_{it}`$，权重份额为
$`s_{it}`$，则加权平均生产率为

``` math
P_t=\sum_i s_{it}p_{it}.
```

在两个端点之间，企业被划分为延续者 $`C`$、进入者 $`E`$ 和退出者 $`X`$。
本包实现的标准 FHK 恒等式为：

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

五行依次为企业内效应（within）、企业间配置效应（between）、交叉效应
（cross）、进入效应（entry）和退出效应（exit）。结果中的 `exit` 已经包含
公式前面的负号，所以五项可以直接相加。

需要牢记：恒等式闭合只能说明会计计算一致，不能证明生产率、权重、企业 ID
和进入退出定义在经济学上一定正确。

## 二、数据最低要求

每个端点期的数据应满足：

1.  每个“分析单位×时期”至多一行；
2.  企业、工厂或企业—产品 ID 跨期一致；
3.  生产率是真正的数值变量；
4.  原始规模或份额非负；
5.  时期变量可以可靠排序，而且不能是 factor。

包内的 `fhk_example` 是一份三年期、非平衡的合成企业面板：

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
head(fhk_example)
#>   firm_id year      industry productivity productivity_alt employment
#> 1       A 2010 Manufacturing          3.2             3.23        100
#> 2       B 2010 Manufacturing          2.8             2.78         80
#> 3       C 2010 Manufacturing          3.6             3.61         60
#> 4       D 2010      Services          2.5             2.53        120
#> 5       E 2010      Services          2.2             2.18         70
#> 6       F 2010      Services          2.9             2.91         50
#>   global_share within_industry_share first_active_year last_active_year
#> 1    0.2083333             0.4166667              2005             2015
#> 2    0.1666667             0.3333333              2004             2015
#> 3    0.1250000             0.2500000              2008             2015
#> 4    0.2500000             0.5000000              2002             2015
#> 5    0.1458333             0.2916667              2006             2011
#> 6    0.1041667             0.2083333              2007             2010
```

如果一家企业在同一年有多个工厂，而生产率也是工厂层面的，就必须使用工厂
ID；不能让 [`match()`](https://rdrr.io/r/base/match.html)
随意选择其中一行。本包会在分行业之前检查全局重复，
包括同一企业—时期被放在两个行业的情况。

## 三、建议优先传入原始权重

就业、销售额或产出等原始规模通常比外部预先计算的份额更稳妥，因为程序会
明确记录两个时期的权重总量，并在正确范围内计算份额。

``` r

result <- fhk_decomposition(
  df = fhk_example,
  firm_col = "firm_id",
  time_col = "year",
  prod_col = "productivity",
  weight_col = "employment",
  t0 = 2010,
  t1 = 2012
)

result[, c(
  "P0", "P1", "aggregate_change",
  "within", "between", "cross", "entry", "exit",
  "component_sum", "residual", "identity_ok"
)]
#>        P0       P1 aggregate_change within     between       cross      entry
#> 1 2.83125 3.200192        0.3689423   0.25 0.009827724 -0.02269231 0.04691106
#>         exit component_sum     residual identity_ok
#> 1 0.08489583     0.3689423 5.551115e-17        TRUE
```

其中：

- `aggregate_change` 是 $`P_1-P_0`$；
- `component_sum` 是五个分项之和；
- `residual` 是二者之差；
- `identity_ok` 表示残差是否通过缩放容差检验；
- `*_pct` 是各分项占有符号总变化的百分比；
- 如果总变化近似为零，百分比会返回 `NA`，避免不稳定的除法。

## 四、核对进入者、退出者和延续者

``` r

result[, c(
  "n_t0", "n_t1", "n_continuers", "n_entrants", "n_exiters",
  "share_continuers_t0", "share_continuers_t1",
  "share_entrants_t1", "share_exiters_t0"
)]
#>   n_t0 n_t1 n_continuers n_entrants n_exiters share_continuers_t0
#> 1    6    7            4          3         2                0.75
#>   share_continuers_t1 share_entrants_t1 share_exiters_t0
#> 1           0.6980769         0.3019231             0.25
```

只有两个端点时，程序直接识别的是“样本是否出现”。企业缺席可能来自真实
注销，也可能来自调查轮换、漏报或匹配失败。因此，没有外部生命周期信息时，
论文中应写“样本进入”和“样本退出”。

如果有工商登记式首次、末次经营年份，可以严格核验：

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
  "turnover_basis", "turnover_validated", "n_turnover_mismatches"
)]
#>                                 turnover_basis turnover_validated
#> 1 sample_presence_validated_by_activity_window               TRUE
#>   n_turnover_mismatches
#> 1                     0
```

检查规则是：

- 进入者首次经营期位于 $`(t_0,t_1]`$；
- 退出者末次经营期位于 $`[t_0,t_1)`$；
- 延续企业在 $`t_0`$ 前已经成立，而且至少经营到 $`t_1`$。

## 五、已经计算好的份额

示例数据同时包含全局份额和行业内份额。全局份额在每个年份对所有企业加总
为 1：

``` r

global_share_result <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "global_share",
  2010, 2012,
  weight_is_share = TRUE
)

fields <- c("aggregate_change", "within", "between", "cross", "entry", "exit")
rbind(
  raw_employment = unlist(result[fields]),
  supplied_global_share = unlist(global_share_result[fields])
)
#>                       aggregate_change within     between       cross
#> raw_employment               0.3689423   0.25 0.009827724 -0.02269231
#> supplied_global_share        0.3689423   0.25 0.009827724 -0.02269231
#>                            entry       exit
#> raw_employment        0.04691106 0.08489583
#> supplied_global_share 0.04691106 0.08489583
```

两种结果应当一致。做分行业分解时必须声明份额分母：

``` r

by_global_share <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "global_share",
  2010, 2012,
  group_cols = "industry",
  weight_is_share = TRUE,
  share_scope = "global"
)

by_within_share <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "within_industry_share",
  2010, 2012,
  group_cols = "industry",
  weight_is_share = TRUE,
  share_scope = "within_group"
)
```

份额默认必须在声明范围内加总为 1。程序不会静默重标准化错误的分母。
只有在确有经济学依据时才设置
`renormalize_input_shares = TRUE`，并保留结果中的
`input_share_sum_t0/t1` 和 `renormalized_t0/t1`。

## 六、分行业分解与全国分解

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

每个行业内部的权重会重新标准化。因此，行业分项描述的是“行业内部生产率
动态”，不能把所有行业的 `within`、`between` 等简单相加当成全国结果。

如果既要全国结果又要行业诊断，应使用：

``` r

both <- fhk_hierarchical(
  fhk_example,
  "firm_id", "year", "productivity", "employment",
  2010, 2012,
  group_cols = "industry"
)

both$overall
#>   period_start period_end      P0       P1 aggregate_change within     between
#> 1         2010       2012 2.83125 3.200192        0.3689423   0.25 0.009827724
#>         cross      entry       exit component_sum     residual identity_ok
#> 1 -0.02269231 0.04691106 0.08489583     0.3689423 5.551115e-17        TRUE
#>   within_pct between_pct cross_pct entry_pct exit_pct n_t0 n_t1 n_continuers
#> 1   67.76127    2.663756 -6.150639  12.71501  23.0106    6    7            4
#>   n_entrants n_exiters n_zero_weight_t0 n_zero_weight_t1 share_continuers_t0
#> 1          3         2                0                0                0.75
#>   share_continuers_t1 share_entrants_t1 share_exiters_t0 weight_total_t0
#> 1           0.6980769         0.3019231             0.25             480
#>   weight_total_t1 input_share_sum_t0 input_share_sum_t1 renormalized_t0
#> 1             520                 NA                 NA           FALSE
#>   renormalized_t1  turnover_basis turnover_validated n_turnover_mismatches
#> 1           FALSE sample_presence              FALSE                    NA
#>   n_group_movers
#> 1              0
both$by_group[, c("industry", "aggregate_change", "identity_ok")]
#>        industry aggregate_change identity_ok
#> 1 Manufacturing        0.2557471        TRUE
#> 2      Services        0.4241667        TRUE
```

如果只有行业内份额，就无法恢复行业在全国中的规模。层级分析需要原始权重或
全局份额。

## 七、行业迁移和端点缺失行业

`fhk_complex_example` 故意加入了现实数据中常见的问题：

- 企业 B 在 2012 年改变行业；
- Construction 只在 2010 年出现；
- 企业 C 在 2011 年权重为零；
- 企业 H 在 2011 年缺少另一种生产率指标。

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

默认分行业调用会因为企业迁移而停止。若行业迁移是真实经济行为，并且研究者
确实希望把它解释为“退出旧行业、进入新行业”，必须显式允许：

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
  "turnover_validated", "global_firm_turnover_validated", "identity_ok"
)]
#>        industry n_group_movers                            turnover_basis
#> 1 Manufacturing              1 group_membership_presence_includes_movers
#> 2      Services              1 group_membership_presence_includes_movers
#>   turnover_validated global_firm_turnover_validated identity_ok
#> 1              FALSE                           TRUE        TRUE
#> 2              FALSE                           TRUE        TRUE
```

行业迁移不是企业成立或注销。因此，有迁移时组内的 `turnover_validated`
会保持 为 `FALSE`，而 `global_firm_turnover_validated`
单独记录企业层面生命周期核验。

如果迁移只是行业分类标准调整，应当先建立跨期统一代码，而不是直接允许迁移。

## 八、缺失值和零权重

生产率、权重、ID、时期或组别缺失时，默认报错。设置 `na_action = "drop"`
可以显式删样，但程序会警告，因为删掉一行可能凭空创造一个“进入者”或
“退出者”。主回归建议使用严格口径；删样口径适合作为经过记录的稳健性检验。

零权重默认保留并报告。它不影响加权平均值，但仍影响基于“是否出现”的分类。
可改为：

``` r

zero_weight_action = "drop"   # 警告后删除
zero_weight_action = "error"  # 直接拒绝
```

任何时期或行业的权重总和为零时，都无法进行分解。

## 九、逐年分解

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

`expected_step = 1` 会阻止程序把缺失 2011 年后的 2010–2012
误称为“相邻年度”。
程序使用全样本共同的时期端点，所以不同产业会在同一对年份上比较。

长差分和逐年分解含义不同：一家企业可能在 2010 年后进入、2012 年前退出，
因而在长差分两个端点都不存在，却会出现在逐年分解中。

## 十、多个生产率指标使用共同样本

``` r

multiple <- fhk_multi_measure(
  fhk_example,
  "firm_id", "year",
  c("productivity", "productivity_alt"),
  "employment",
  2010, 2012,
  common_sample = TRUE
)

multiple[, c("measure", "aggregate_change", "within", "entry", "exit")]
#>            measure aggregate_change    within      entry       exit
#> 1     productivity        0.3689423 0.2500000 0.04691106 0.08489583
#> 2 productivity_alt        0.3582083 0.2345833 0.04668550 0.08921875
```

如果不同生产率指标的缺失情况不同，可同时设置
`common_sample = TRUE, na_action = "drop"`。程序会先按全部指标构造一次共同样本，
避免所谓“指标差异”其实来自企业样本不同。

## 十一、论文报告建议

至少应当说明或在复现材料中保存：

1.  分析单位是企业、工厂还是企业—产品，ID 如何构造；
2.  端点年份，以及使用长差分还是逐年转移；
3.  生产率是水平还是对数，采用哪一种估计方法；
4.  权重是就业、销售还是产出，份额分母范围是什么；
5.  行业代码是否跨期统一，如何处理迁移企业；
6.  进入退出是样本定义还是工商登记核验；
7.  缺失值、零权重、端点缺组的处理政策；
8.  延续者、进入者、退出者的数量和权重占比；
9.  五项分解、`residual` 和 `identity_ok`。

建议在筛选论文表格列之前，先保存程序返回的完整数据框。审计列是实证记录的一
部分，不应只保留五个分项。

## 十二、引用

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

方法参考文献为 Foster、Haltiwanger 和 Krizan（2001）， “Aggregate
Productivity Growth: Lessons from Microeconomic Evidence”，
<https://doi.org/10.3386/w6803>。
