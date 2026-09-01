\name{fhk_decomposition}
\alias{fhk_decomposition}
\title{Compute a Robust Two-Period FHK Decomposition}
\description{
Computes the standard five-term FHK endpoint decomposition with strict input,
turnover, share, grouping, and accounting audits.
}
\usage{
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
}
\arguments{
  \item{df}{A data frame with one row per analytical unit and period.}
  \item{firm_col}{Name of the unit identifier column. Use a plant identifier
  or a validated composite identifier if a firm has several establishments or
  products in one period.}
  \item{time_col}{Name of an ordered period column. Numeric, \code{Date},
  \code{POSIXct}, and sortable character periods are supported. Factor periods
  are rejected.}
  \item{prod_col}{Name of a genuinely numeric productivity or outcome column.}
  \item{weight_col}{Name of a genuinely numeric, non-negative raw size or share
  column.}
  \item{t0, t1}{Scalar endpoint periods. By default \code{t1} must be later than
  \code{t0}.}
  \item{group_cols}{Optional character vector of industry, market, region, or
  other grouping columns.}
  \item{weight_is_share}{Set to \code{TRUE} when \code{weight_col} already
  contains shares; otherwise raw sizes are converted to period shares.}
  \item{share_scope}{For grouped analyses, whether supplied shares sum to one
  within each group-period or globally within each period.}
  \item{renormalize_input_shares}{Whether malformed supplied shares may be
  explicitly renormalized. The default is deliberately strict.}
  \item{first_active_col, last_active_col}{Optional registry-derived first and
  last activity-period columns used to audit whether sample turnover is
  consistent with firm birth and death.}
  \item{turnover_validation}{Action when sample turnover conflicts with supplied
  activity windows.}
  \item{group_change_action}{Action when a continuing unit changes group. If
  allowed, it is an exit from the old group and entry into the new group, but
  not a firm death or birth.}
  \item{incomplete_group_action}{Action for groups absent at one endpoint.
  Dropped groups are retained in the \code{"skipped_groups"} attribute.}
  \item{zero_weight_action}{Whether zero-weight rows are kept, dropped with a
  warning, or rejected.}
  \item{na_action}{Whether missing or non-finite required values are rejected or
  explicitly dropped. Dropping can change turnover classifications.}
  \item{require_t1_after_t0}{Whether to require a forward-time comparison.}
  \item{tol}{Finite non-negative scaled tolerance for share and accounting
  audits.}
  \item{fail_on_identity_error}{Whether a failed accounting identity stops the
  calculation.}
}
\details{
Let \eqn{P_t = \sum_i s_{it}p_{it}}. The implemented endpoint identity is
\deqn{\Delta P = Within + Between + Cross + Entry + Exit,}
where
\deqn{Within = \sum_{i \in C} s_{i0}(p_{i1}-p_{i0}),}
\deqn{Between = \sum_{i \in C}(s_{i1}-s_{i0})(p_{i0}-P_0),}
\deqn{Cross = \sum_{i \in C}(s_{i1}-s_{i0})(p_{i1}-p_{i0}),}
\deqn{Entry = \sum_{i \in E}s_{i1}(p_{i1}-P_0),}
and
\deqn{Exit = -\sum_{i \in X}s_{i0}(p_{i0}-P_0).}

The returned \code{exit} value already includes the leading minus sign and can
therefore be added directly to the other four components.

Without external activity-window information, entry and exit mean sample entry
and sample exit between the endpoints. An accounting identity can be exact even
when the underlying turnover interpretation is wrong, so users should inspect
the audit columns.
}
\value{
A one-row data frame, or one row per retained group, containing aggregate
productivity at both endpoints, the five components, their signed percentage
contributions, counts and weight shares of continuers/entrants/exiters, weight
and share audits, turnover audits, and an accounting residual. Key columns are
\code{aggregate_change}, \code{within}, \code{between}, \code{cross},
\code{entry}, \code{exit}, \code{component_sum}, \code{residual}, and
\code{identity_ok}.
}
\references{
Foster, L., Haltiwanger, J., and Krizan, C. J. (2001). Aggregate productivity
growth: Lessons from microeconomic evidence. \doi{10.3386/w6803}.
}
\seealso{\code{\link{fhk_adjacent}}, \code{\link{fhk_hierarchical}},
\code{\link{fhk_multi_measure}}}
\examples{
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

by_industry <- fhk_decomposition(
  fhk_example,
  "firm_id", "year", "productivity", "employment", 2010, 2012,
  group_cols = "industry"
)
by_industry[, c("industry", "aggregate_change", "identity_ok")]
}
