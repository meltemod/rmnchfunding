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

test_that("the four varies* codes stay NA in sector_weights", {
  # They are computed per recipient and year, so a table with one weight per
  # code cannot hold them. NA there is correct even now that the weights
  # exist: the value lives in rmnch_recipient_weights, and anything reading
  # sector_weights alone must not find a number that does not apply globally.
  sw <- sector_weights
  varies <- c("12262", "12263", "13040", "51010")
  expect_true(all(is.na(sw$weight[sw$universe == "rmnch" &
                                    sw$purpose_code %in% varies])))
  # And every one of them must now be resolvable from the recipient table.
  expect_setequal(unique(rmnch_recipient_weights$purpose_code), varies)
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

# ---- the disease codes ----------------------------------------------------

test_that("all four purpose codes are present", {
  expect_setequal(unique(rmnch_recipient_weights$purpose_code),
                  c("12262", "12263", "13040", "51010"))
  # Complete grid: every code, every recipient, every target year.
  expect_equal(nrow(rmnch_recipient_weights), 4L * 182L * 4L)
})

test_that("the fixed components of each disease formula are respected", {
  w <- rmnch_recipient_weights
  # Malaria carries a fixed MNH of 0.15 from the Countdown method, and no RH.
  mal <- w[w$purpose_code == "12262", ]
  expect_true(all(mal$mnh == 0.15, na.rm = TRUE))
  expect_true(all(mal$rh == 0, na.rm = TRUE))
  # Tuberculosis is child health only.
  tb <- w[w$purpose_code == "12263", ]
  expect_true(all(tb$rh == 0, na.rm = TRUE))
  expect_true(all(tb$mnh == 0, na.rm = TRUE))
  # HIV has no maternal-newborn component.
  hiv <- w[w$purpose_code == "13040", ]
  expect_true(all(hiv$mnh == 0, na.rm = TRUE))
  expect_true(any(hiv$rh > 0, na.rm = TRUE))
})

test_that("a malaria-free country gets the fixed MNH and nothing more", {
  # GBD reports zero malaria incidence for most of the world, which makes the
  # child share 0/0. Zero cases means zero child cases, so the weight reduces
  # to the MNH constant. This must NOT become a regional substitute: taking a
  # malarious neighbour's child share would invent burden that is not there.
  # All of Europe is malaria-free, so Albania is a clean test.
  alb <- rmnch_recipient_weights[
    rmnch_recipient_weights$purpose_code == "12262" &
      rmnch_recipient_weights$recipient_code == "ALB", ]
  expect_gt(nrow(alb), 0L)
  expect_true(all(alb$ch == 0))
  expect_true(all(alb$weight == 0.15))
  expect_true(all(alb$source == "own"))
})

test_that("a high-burden country has a substantial child share", {
  # The other side of the same test: where malaria is endemic, CH must be a
  # real number rather than the zero-burden default.
  nga <- rmnch_recipient_weights[
    rmnch_recipient_weights$purpose_code == "12262" &
      rmnch_recipient_weights$recipient_code == "NGA", ]
  expect_gt(nrow(nga), 0L)
  expect_true(all(nga$ch > 0.2))
  expect_true(all(nga$weight > 0.35))
})

test_that("regional substitutes keep components summing to their total", {
  # The bug this guards: the fallback originally hardcoded MNH to zero, which
  # is right for general budget support and tuberculosis but wrong for
  # malaria's fixed 0.15, leaving substituted malaria rows whose parts no
  # longer made their whole.
  sub <- rmnch_recipient_weights[
    !is.na(rmnch_recipient_weights$source) &
      rmnch_recipient_weights$source != "own", ]
  expect_gt(nrow(sub), 0L)
  expect_true(all(abs((sub$rh + sub$mnh + sub$ch) - sub$weight) < 1e-9))
  # And a substituted malaria row must still carry the constant.
  submal <- sub[sub$purpose_code == "12262", ]
  if (nrow(submal) > 0L) expect_true(all(abs(submal$mnh - 0.15) < 1e-9))
})

# ---- the exported crosswalk CSV -------------------------------------------

test_that("the crosswalk CSV ships and matches the dataset", {
  path <- system.file("extdata", "recipient_crosswalk.csv",
                      package = "rmnchfunding")
  expect_true(nzchar(path))
  csv <- utils::read.csv(path, stringsAsFactors = FALSE)

  # Same recipients as the dataset it documents; a CSV that drifted from the
  # data would be worse than no CSV, since it is the artefact a reader checks
  # the method against.
  expect_setequal(csv$recipient_code, recipient_crosswalk$recipient_code)
  expect_equal(nrow(csv), nrow(recipient_crosswalk))

  # One source column per purpose code, and every value accounted for.
  srccols <- grep("^source_", names(csv), value = TRUE)
  expect_setequal(sub("^source_", "", srccols),
                  unique(rmnch_recipient_weights$purpose_code))
  vals <- unlist(csv[srccols], use.names = FALSE)
  expect_false(anyNA(vals))
  expect_true(all(vals %in% c("own", "regional (subregion)",
                              "regional (region)", "regional (continent)")))
})

test_that("the CSV's imputation flags agree with the weights", {
  csv <- utils::read.csv(
    system.file("extdata", "recipient_crosswalk.csv",
                package = "rmnchfunding"), stringsAsFactors = FALSE)
  w <- rmnch_recipient_weights
  for (pc in unique(w$purpose_code)) {
    # as.vector(), not unname(): tapply returns a 1-d array, and the dim
    # attribute survives unname() and fails the comparison on structure even
    # when every value agrees.
    from_data <- tapply(w$source[w$purpose_code == pc],
                        w$recipient_code[w$purpose_code == pc],
                        function(x) unique(x)[1])
    from_csv <- stats::setNames(csv[[paste0("source_", pc)]],
                                csv$recipient_code)
    expect_equal(as.vector(from_csv[names(from_data)]), as.vector(from_data),
                 label = paste("source column for", pc))
  }
})

test_that("all three naming systems are recorded", {
  cw <- recipient_crosswalk
  expect_true(all(c("recipient_name", "wb_name", "gbd_location_name")
                  %in% names(cw)))
  # The case that motivated keeping all three: no two of these spellings are
  # equal, so no pair-wise string match would find it.
  civ <- cw[cw$recipient_code == "CIV", ]
  expect_equal(nrow(civ), 1L)
  expect_false(civ$recipient_name == civ$wb_name)
  expect_false(civ$recipient_name == civ$gbd_location_name)
  expect_false(civ$wb_name == civ$gbd_location_name)
  # And it must actually be resolved, not left NA.
  expect_false(is.na(civ$gbd_location_name))
})
