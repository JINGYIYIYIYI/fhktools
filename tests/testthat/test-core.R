test_that("canonical FHK identity matches a hand-checkable example", {
  toy <- data.frame(
    firm = c("A", "B", "C", "B", "C", "D"),
    year = c(2010, 2010, 2010, 2014, 2014, 2014),
    productivity = c(5, 4, 3, 4.5, 6, 5.5),
    share = c(0.5, 0.3, 0.2, 0.4, 0.15, 0.45)
  )

  z <- fhk_decomposition(
    toy, "firm", "year", "productivity", "share", 2010, 2014,
    weight_is_share = TRUE
  )

  expect_true(z$identity_ok)
  expect_equal(z$aggregate_change, 0.875, tolerance = 1e-12)
  expect_equal(z$within, 0.75, tolerance = 1e-12)
  expect_equal(z$between, 0.035, tolerance = 1e-12)
  expect_equal(z$cross, -0.1, tolerance = 1e-12)
  expect_equal(z$entry, 0.54, tolerance = 1e-12)
  expect_equal(z$exit, -0.35, tolerance = 1e-12)
})


test_that("raw weights and correctly formed shares are equivalent", {
  data(fhk_example)
  raw <- fhk_decomposition(
    fhk_example, "firm_id", "year", "productivity", "employment",
    2010, 2012
  )
  shares <- fhk_decomposition(
    fhk_example, "firm_id", "year", "productivity", "global_share",
    2010, 2012, weight_is_share = TRUE
  )
  fields <- c("aggregate_change", "within", "between", "cross", "entry", "exit")
  expect_equal(raw[fields], shares[fields], tolerance = 1e-12)
})


test_that("random endpoint panels close the accounting identity", {
  set.seed(5001)
  max_residual <- 0
  for (rep in seq_len(50)) {
    universe <- sprintf("F%03d", seq_len(80))
    ids0 <- sample(universe, sample(50:75, 1))
    ids1 <- sample(universe, sample(50:75, 1))
    d <- rbind(
      data.frame(id = ids0, year = 1, p = rnorm(length(ids0)), w = rexp(length(ids0))),
      data.frame(id = ids1, year = 2, p = rnorm(length(ids1)), w = rexp(length(ids1)))
    )
    z <- fhk_decomposition(d, "id", "year", "p", "w", 1, 2)
    expect_true(z$identity_ok)
    max_residual <- max(max_residual, abs(z$residual))
  }
  expect_lt(max_residual, 1e-10)
})


test_that("activity windows validate genuine endpoint turnover", {
  data(fhk_example)
  z <- fhk_decomposition(
    fhk_example, "firm_id", "year", "productivity", "employment",
    2010, 2012,
    first_active_col = "first_active_year",
    last_active_col = "last_active_year"
  )
  expect_true(z$turnover_validated)
  expect_equal(z$n_turnover_mismatches, 0)
  expect_equal(z$n_entrants, 3)
  expect_equal(z$n_exiters, 2)
})

