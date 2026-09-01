\name{fhktools-package}
\alias{fhktools}
\alias{fhktools-package}
\docType{package}
\title{Robust Foster-Haltiwanger-Krizan Productivity Decompositions}
\description{
\pkg{fhktools} provides defensive implementations of the standard
Foster-Haltiwanger-Krizan (FHK) productivity decomposition. It emphasizes
auditable data choices, explicit turnover interpretation, and exact accounting
identity checks.
}
\details{
The main entry points are \code{fhk_decomposition()} for one endpoint pair,
\code{fhk_adjacent()} for consecutive observed periods,
\code{fhk_hierarchical()} for economy-wide plus within-group results, and
\code{fhk_multi_measure()} for comparable results across several productivity
measures.
}
\author{
Yu Li \email{ylxmu1019@163.com}
}
\references{
Foster, L., Haltiwanger, J., and Krizan, C. J. (2001). Aggregate productivity
growth: Lessons from microeconomic evidence. In \emph{New Developments in
Productivity Analysis}. \doi{10.3386/w6803}.
}

