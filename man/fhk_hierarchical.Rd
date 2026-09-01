\name{fhk_hierarchical}
\alias{fhk_hierarchical}
\title{Compute Economy-Wide and Within-Group FHK Results}
\description{
Returns a direct economy-wide decomposition and correctly normalized
within-group decompositions from the same endpoint design.
}
\usage{
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
}
\arguments{
  \item{df, firm_col, time_col, prod_col, weight_col, t0, t1}{See
  \code{\link{fhk_decomposition}}.}
  \item{group_cols}{One or more grouping columns.}
  \item{weight_is_share}{Whether the weight column contains shares.}
  \item{share_scope}{Whether supplied shares are global or within-group. Global
  shares are required to recover economy-wide weights.}
  \item{...}{Additional arguments passed to \code{fhk_decomposition()}.}
}
\details{
Within-group FHK components use shares normalized inside each group. They must
not simply be summed to construct economy-wide FHK components. This function
returns a direct economy-wide decomposition alongside the group diagnostics.
}
\value{
An object of class \code{fhk_hierarchical_result}: a list with
\code{overall}, \code{by_group}, and \code{skipped_groups}.
}
\examples{
data(fhk_example)
ans <- fhk_hierarchical(
  fhk_example, "firm_id", "year", "productivity", "employment",
  2010, 2012, group_cols = "industry"
)
ans$overall$identity_ok
ans$by_group[, c("industry", "aggregate_change")]
}
