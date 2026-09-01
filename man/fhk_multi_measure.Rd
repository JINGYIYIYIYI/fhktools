\name{fhk_multi_measure}
\alias{fhk_multi_measure}
\title{Apply the Same FHK Design to Multiple Productivity Measures}
\description{
Runs comparable decompositions for several productivity measures, with an
optional common-sample rule.
}
\usage{
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
}
\arguments{
  \item{df, firm_col, time_col, weight_col, t0, t1, group_cols,
  weight_is_share, renormalize_input_shares, na_action, tol,
  fail_on_identity_error}{See \code{\link{fhk_decomposition}}.}
  \item{prod_cols}{Unique names of numeric productivity or outcome columns.}
  \item{common_sample}{When \code{TRUE} and \code{na_action = "drop"}, remove
  rows invalid for any requested measure once before running the decompositions.}
  \item{...}{Additional arguments passed to \code{fhk_decomposition()}.}
}
\value{A data frame with a \code{measure} column identifying each outcome.}
\examples{
data(fhk_example)
ans <- fhk_multi_measure(
  fhk_example, "firm_id", "year",
  c("productivity", "productivity_alt"), "employment",
  2010, 2012
)
ans[, c("measure", "aggregate_change", "identity_ok")]
}
