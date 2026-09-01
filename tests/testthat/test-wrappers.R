test_that("grouped global and within-group shares reproduce raw-weight results", {
  data(fhk_example)
  fields <- c("aggregate_change", "within", "between", "cross", "entry", "exit")

  raw <- fhk_decomposition(
    fhk_example, "firm_id", "year", "productivity", "employment",
    2010, 2012, group_cols = "industry"
  )
  global <- fhk_decomposition(
    fhk_example, "firm_id", "year", "productivity", "global_share",
    2010, 2012, group_cols = "industry",
    weight_is_share = TRUE, share_scope = "global"
  )
  within <- fhk_decomposition(
    fhk_example, "firm_id", "year", "productivity", "within_industry_share",
    2010, 2012, group_cols = "industry",
    weight_is_share = TRUE, share_scope = "within_group"
  )

  expect_equal(raw[fields], global[fields], tolerance = 1e-12)
  expect_equal(raw[fields], within[fields], tolerance = 1e-12)
  expect_true(all(is.na(within$group_weight_t0)))
})


test_that("hierarchical, adjacent, and multi-measure wrappers work", {
  data(fhk_example)

  h <- fhk_hierarchical(
    fhk_example, "firm_id", "year", "productivity", "employment",
    2010, 2012, group_cols = "industry"
  )
  expect_s3_class(h, "fhk_hierarchical_result")
  expect_true(h$overall$identity_ok)
  expect_true(all(h$by_group$identity_ok))

  a <- fhk_adjacent(
    fhk_example, "firm_id", "year", "productivity", "employment",
    expected_step = 1
  )
  expect_equal(nrow(a), 2)
  expect_true(all(a$identity_ok))

  m <- fhk_multi_measure(
    fhk_example, "firm_id", "year",
    c("productivity", "productivity_alt"), "employment",
    2010, 2012
  )
  expect_setequal(m$measure, c("productivity", "productivity_alt"))
  expect_true(all(m$identity_ok))
})


test_that("expected_step catches non-adjacent observed periods", {
  data(fhk_example)
  gap <- subset(fhk_example, year != 2011)
  expect_error(
    fhk_adjacent(
      gap, "firm_id", "year", "productivity", "employment",
      expected_step = 1
    ),
    "expected_step"
  )
})
