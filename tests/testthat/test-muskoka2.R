# Offline tests: argument handling and the guarantees that do not need data.
# The end-to-end reproduction against published totals is in
# test-oecd-live.R, since it needs the OECD API.

test_that("universe, prices and edition are validated", {
  expect_error(muskoka2("USA", 2022, universe = "nope"), "'arg' should be one of")
  expect_error(muskoka2("USA", 2022, prices = "constant"), "needs a `base` year")
  expect_error(muskoka2("USA", 2022, prices = "current", report_edition = 1999),
               "must be one of")
})

test_that("ida is refused outside family planning", {
  # 0% and 1% are two live treatments of IDA's family-planning weight. Neither
  # means anything for RMNCH or SRHR, so passing it there is a mistake worth
  # naming rather than silently ignoring.
  expect_error(muskoka2("USA", 2022, prices = "current", ida = 1),
               "applies only to")
  expect_error(muskoka2("USA", 2022, prices = "current", universe = "srhr",
                        ida = 1), "applies only to")
  expect_error(muskoka2("USA", 2022, prices = "current", universe = "fp",
                        ida = 2), "must be 0 or 1")
})

test_that("every purpose code has a weight in every universe", {
  # muskoka2() refuses rather than treating a missing weight as zero, so this
  # is what stands between the package and an estimate that silently omits a
  # sector. Checked here rather than only at call time.
  sw <- sector_weights
  rw <- rmnch_recipient_weights
  varies <- unique(rw$purpose_code)
  for (u in c("srhr", "fp")) {
    w <- sw[as.character(sw$universe) == u, ]
    expect_false(anyNA(w$weight), label = paste("sector weights for", u))
  }
  # RMNCH is NA for exactly the four varying codes, which the recipient-year
  # table covers instead.
  rm_w <- sw[as.character(sw$universe) == "rmnch", ]
  expect_setequal(rm_w$purpose_code[is.na(rm_w$weight)], varies)
})

test_that("the recipient-year table covers every recipient oecd_crs returns", {
  # The join in muskoka2() must not miss a row. The unallocated `_X` buckets
  # are the case that matters: they are 48% of the value in the four varying
  # codes for the United States, and were absent from the table at first.
  rw <- rmnch_recipient_weights
  cw <- recipient_crosswalk
  expect_true(all(cw$recipient_code %in% rw$recipient_code))
  expect_true("DPGC_X" %in% rw$recipient_code)
  expect_true("F6_X" %in% rw$recipient_code)
  # Every code x recipient x year combination present exactly once.
  expect_false(anyDuplicated(
    rw[c("purpose_code", "recipient_code", "year")]
  ) > 0L)
})
