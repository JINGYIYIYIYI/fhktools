# Rebuild the example data shipped with fhktools.
# Run from the package root with:
#   source("data-raw/generate_example_data.R")

fhk_example <- rbind(
  data.frame(
    firm_id = c("A", "B", "C", "D", "E", "F"),
    year = 2010L,
    productivity = c(3.20, 2.80, 3.60, 2.50, 2.20, 2.90),
    employment = c(100, 80, 60, 120, 70, 50)
  ),
  data.frame(
    firm_id = c("A", "B", "C", "D", "E", "G", "H"),
    year = 2011L,
    productivity = c(3.35, 3.00, 3.55, 2.75, 2.10, 2.40, 3.00),
    employment = c(105, 75, 62, 115, 60, 40, 55)
  ),
  data.frame(
    firm_id = c("A", "B", "C", "D", "G", "H", "I"),
    year = 2012L,
    productivity = c(3.50, 3.25, 3.70, 2.90, 2.70, 3.15, 3.10),
    employment = c(110, 70, 65, 118, 52, 60, 45)
  )
)

industry_map <- c(
  A = "Manufacturing", B = "Manufacturing", C = "Manufacturing",
  D = "Services", E = "Services", F = "Services",
  G = "Services", H = "Services", I = "Manufacturing"
)
first_map <- c(
  A = 2005L, B = 2004L, C = 2008L, D = 2002L, E = 2006L,
  F = 2007L, G = 2011L, H = 2011L, I = 2012L
)
last_map <- c(
  A = 2015L, B = 2015L, C = 2015L, D = 2015L, E = 2011L,
  F = 2010L, G = 2015L, H = 2015L, I = 2015L
)

fhk_example$industry <- unname(industry_map[fhk_example$firm_id])
fhk_example$first_active_year <- unname(first_map[fhk_example$firm_id])
fhk_example$last_active_year <- unname(last_map[fhk_example$firm_id])
fhk_example$productivity_alt <-
  fhk_example$productivity + rep(c(0.03, -0.02, 0.01), length.out = nrow(fhk_example))
fhk_example$global_share <- ave(
  fhk_example$employment,
  fhk_example$year,
  FUN = function(x) x / sum(x)
)
fhk_example$within_industry_share <- ave(
  fhk_example$employment,
  interaction(fhk_example$year, fhk_example$industry, drop = TRUE),
  FUN = function(x) x / sum(x)
)
fhk_example <- fhk_example[
  order(fhk_example$year, fhk_example$firm_id),
  c(
    "firm_id", "year", "industry", "productivity", "productivity_alt",
    "employment", "global_share", "within_industry_share",
    "first_active_year", "last_active_year"
  )
]
rownames(fhk_example) <- NULL


# A deliberately awkward panel for teaching defensive workflows. Compared with
# fhk_example, firm B moves industry in 2012, firm C has a zero employment
# weight in 2011, one alternate productivity value is missing, and firm J forms
# a group observed at the first endpoint only.
fhk_complex_example <- fhk_example
fhk_complex_example$industry[
  fhk_complex_example$firm_id == "B" & fhk_complex_example$year == 2012L
] <- "Services"
fhk_complex_example$employment[
  fhk_complex_example$firm_id == "C" & fhk_complex_example$year == 2011L
] <- 0
fhk_complex_example$productivity_alt[
  fhk_complex_example$firm_id == "H" & fhk_complex_example$year == 2011L
] <- NA_real_

firm_j <- data.frame(
  firm_id = "J",
  year = 2010L,
  industry = "Construction",
  productivity = 2.65,
  productivity_alt = 2.68,
  employment = 35,
  global_share = NA_real_,
  within_industry_share = NA_real_,
  first_active_year = 2001L,
  last_active_year = 2010L,
  stringsAsFactors = FALSE
)
fhk_complex_example <- rbind(fhk_complex_example, firm_j)
fhk_complex_example$global_share <- ave(
  fhk_complex_example$employment,
  fhk_complex_example$year,
  FUN = function(x) x / sum(x)
)
fhk_complex_example$within_industry_share <- ave(
  fhk_complex_example$employment,
  interaction(
    fhk_complex_example$year,
    fhk_complex_example$industry,
    drop = TRUE
  ),
  FUN = function(x) if (sum(x) > 0) x / sum(x) else rep(0, length(x))
)
fhk_complex_example <- fhk_complex_example[
  order(fhk_complex_example$year, fhk_complex_example$firm_id),
]
rownames(fhk_complex_example) <- NULL

dir.create("data", showWarnings = FALSE)
save(fhk_example, file = "data/fhk_example.rda", compress = "xz")
save(
  fhk_complex_example,
  file = "data/fhk_complex_example.rda",
  compress = "xz"
)

