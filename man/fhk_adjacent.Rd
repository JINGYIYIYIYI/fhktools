\name{fhk_adjacent}
\alias{fhk_adjacent}
\title{Compute FHK Decompositions for Adjacent Observed Periods}
\description{
Applies the same FHK design to each globally adjacent observed period pair,
optionally enforcing the expected time step.
}
\usage{
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
}
\arguments{
  \item{df, firm_col, time_col, prod_col, weight_col, group_cols,
  weight_is_share, renormalize_input_shares, na_action, tol,
  fail_on_identity_error}{See \code{\link{fhk_decomposition}}.}
  \item{expected_step}{Optional required distance between all sorted observed
  periods, such as \code{1} for annual integer data.}
  \item{...}{Additional arguments passed to \code{fhk_decomposition()}.}
}
\details{
Period pairs are constructed from the globally observed periods, so all groups
use the same endpoints. Use \code{expected_step} to prevent gaps such as 2010 to
2012 from being mislabeled as an annual transition.
}
\value{A data frame containing one result per period pair and retained group.}
\examples{
data(fhk_example)
annual <- fhk_adjacent(
  fhk_example, "firm_id", "year", "productivity", "employment",
  expected_step = 1
)
annual[, c("period_start", "period_end", "aggregate_change", "identity_ok")]
}
