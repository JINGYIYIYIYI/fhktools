# Contributing to fhktools

Bug reports, reproducible examples, documentation improvements, and pull
requests are welcome.

Before opening a pull request:

1.  Create a branch from `main`.
2.  Add or update a test under `tests/testthat/`.
3.  Run `devtools::test()`.
4.  Run `devtools::check()` and resolve all errors, warnings, and notes
    caused by the change.
5.  Explain any change in empirical interpretation, especially changes
    involving shares, group movers, or entry and exit.

Please do not include confidential firm-level data. Use a synthetic,
anonymized, or minimal reproducible dataset instead.
