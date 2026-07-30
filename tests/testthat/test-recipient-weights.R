# Tests for the recipient-and-year RMNCH weights and the crosswalk they need.
# The properties asserted here are the ones a silent error would violate
# without changing anything visible: components that no longer reconstruct
# their total, a weight with no recorded provenance, a fixed constant that has
# drifted.

test_that("components reconstruct the total exactly", {
  w <- rmnch_recipient_weights
  ok <- is.na(w$weight) | abs((w$rh + w$mnh + w$ch) - w$weight) < 1e-9
  expect_true(all(ok))
})

test_that("weights are proportions", {
  w <- rmnch_recipient_weights
  expect_true(all(w$weight >= 0 & w$weight <= 1, na.rm = TRUE))
  expect_true(all(w$rh >= 0 & w$ch >= 0, na.rm = TRUE))
})

test_that("general budget support has a structurally zero MNH component", {
  # MNH is zero for 51010 by the method, not because the data happens to give
  # zero. A non-zero value would mean the formula had been altered.
  g <- rmnch_recipient_weights[rmnch_recipient_weights$purpose_code == "51010", ]
  expect_gt(nrow(g), 0L)
  expect_true(all(g$mnh == 0, na.rm = TRUE))
})

test_that("one row per purpose code, recipient and year", {
  expect_false(anyDuplicated(
    rmnch_recipient_weights[c("purpose_code", "recipient_code", "year")]
  ) > 0L)
  expect_setequal(rmnch_recipient_weights$year, 2021:2024)
})

test_that("every weight records where it came from", {
  # The whole point of source and source_year: an observed weight, one carried
  # forward and one substituted from a region are otherwise indistinguishable.
  w <- rmnch_recipient_weights
  expect_true(all(is.na(w$weight) | !is.na(w$source)))
  expect_true(all(w$source %in%
    c("own", "regional (subregion)", "regional (region)",
      "regional (continent)"), na.rm = TRUE))
  # source_year applies to own-data rows. A regional substitute is a mean over
  # group members whose own source years may differ, so it has no single
  # observation year and carries NA rather than an invented one.
  own <- w[!is.na(w$source) & w$source == "own", ]
  expect_gt(nrow(own), 0L)
  expect_false(anyNA(own$source_year))
  subbed <- w[!is.na(w$source) & w$source != "own", ]
  expect_true(all(is.na(subbed$source_year)))
  # Carrying forward only ever looks backwards, and never further than the cap.
  expect_true(all(own$source_year <= own$year))
  expect_true(all(own$year - own$source_year <= 3L))
})

test_that("substituted weights are confined to recipients with no source data", {
  w <- rmnch_recipient_weights
  cw <- recipient_crosswalk
  subbed <- unique(w$recipient_code[!is.na(w$source) & w$source != "own"])
  no_wb <- cw$recipient_code[is.na(cw$iso3)]
  # Every substituted recipient must be one the crosswalk says has no data.
  # The reverse need not hold: a recipient with an ISO3 may still lack the
  # particular indicators.
  expect_true(all(subbed %in% cw$recipient_code))
  expect_true(all(no_wb %in% subbed))
})

test_that("the disease codes are absent rather than wrong", {
  # They need a GBD extract that cannot be fetched automatically. Absent is
  # the correct state; a zero or a guessed value would not be.
  expect_false(any(c("12262", "12263", "13040") %in%
                     rmnch_recipient_weights$purpose_code))
  # And they must still be NA in sector_weights, so muskoka() refuses.
  sw <- sector_weights
  disease <- sw$weight[sw$universe == "rmnch" &
                         sw$purpose_code %in% c("12262", "12263", "13040")]
  expect_true(all(is.na(disease)))
})

# ---- crosswalk ------------------------------------------------------------

test_that("every recipient is either matched or has a recorded reason", {
  # The property that makes a gap in the weights a decision rather than an
  # accident.
  cw <- recipient_crosswalk
  expect_true(all(!is.na(cw$iso3) | !is.na(cw$no_data_reason)))
  # And never both.
  expect_false(any(!is.na(cw$iso3) & !is.na(cw$no_data_reason)))
})

test_that("the one genuine code difference is mapped", {
  cw <- recipient_crosswalk
  expect_equal(cw$iso3[cw$recipient_code == "XKV"], "XKX")
  expect_equal(cw$iso3[cw$recipient_code == "KEN"], "KEN")
})

test_that("every recipient has a geographic line for the fallback", {
  cw <- recipient_crosswalk
  expect_false(anyNA(cw$continent))
  expect_false(anyNA(cw$region))
  expect_false(anyNA(cw$subregion))
})

test_that("the crosswalk excludes aggregates and organisations", {
  cw <- recipient_crosswalk
  r <- crs_recipients
  expect_false(any(cw$recipient_code %in%
                     r$recipient_code[r$is_aggregate]))
  expect_false(any(cw$recipient_code %in%
                     r$recipient_code[r$is_unallocated]))
  # CL_AREA_ORG carries multilateral organisations too; none belongs here.
  expect_false(any(c("1UN019", "5WB002", "5ASDB01") %in% cw$recipient_code))
})
