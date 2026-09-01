test_that("unsafe numeric and unit-period inputs are rejected", {
  data(fhk_example)

  factor_weight <- fhk_example
  factor_weight$employment <- factor(factor_weight$employment)
  expect_error(
    fhk_decomposition(
      factor_weight, "firm_id", "year", "productivity", "employment",
      2010, 2012
    ),
    "genuinely numeric"
  )

  duplicated_row <- rbind(fhk_example, fhk_example[1, ])
  expect_error(
    fhk_decomposition(
      duplicated_row, "firm_id", "year", "productivity", "employment",
      2010, 2012
    ),
    "Duplicate"
  )

  expect_error(
    fhk_decomposition(
      fhk_example, "firm_id", "year", "productivity", "employment",
      2012, 2010
    ),
    "later than"
  )
})


test_that("malformed shares are strict by default and auditable when repaired", {
  data(fhk_example)
  bad <- fhk_example
  bad$bad_share <- bad$global_share * 0.8

  expect_error(
    fhk_decomposition(
      bad, "firm_id", "year", "productivity", "bad_share", 2010, 2012,
      weight_is_share = TRUE
    ),
    "do not sum to one"
  )

  expect_warning(
    z <- fhk_decomposition(
      bad, "firm_id", "year", "productivity", "bad_share", 2010, 2012,
      weight_is_share = TRUE, renormalize_input_shares = TRUE
    ),
    "renormalized"
  )
  expect_true(z$renormalized_t0)
  expect_true(z$renormalized_t1)
  expect_true(z$identity_ok)
})


test_that("complex group policies are explicit and audited", {
  data(fhk_complex_example)

  expect_error(
    fhk_decomposition(
      fhk_complex_example, "firm_id", "year", "productivity", "employment",
      2010, 2012, group_cols = "industry"
    ),
    "change group"
  )

  z <- fhk_decomposition(
    fhk_complex_example, "firm_id", "year", "productivity", "employment",
    2010, 2012,
    group_cols = "industry",
    first_active_col = "first_active_year",
    last_active_col = "last_active_year",
    group_change_action = "allow",
    incomplete_group_action = "drop"
  )

  expect_true(all(z$identity_ok))
  expect_equal(unique(z$n_group_movers), 1)
  expect_true(all(z$global_firm_turnover_validated))
  expect_false(any(z$turnover_validated))
  expect_equal(nrow(attr(z, "skipped_groups")), 1)
})

