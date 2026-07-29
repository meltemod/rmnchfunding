# The weight tables ARE the method, so these tests are not box-ticking: a
# coefficient that changes silently changes every published estimate. Each
# test states a property the data must hold, so that a future edit to
# data-raw/ that breaks one fails here rather than in someone's results.

test_that("weights are proportions, not percentages", {
  for (d in list(sector_weights, agency_weights)) {
    expect_true(all(d$weight >= 0 & d$weight <= 1, na.rm = TRUE))
  }
  # A percentage left unconverted would almost certainly exceed 1 somewhere:
  # both tables contain 100% cells.
  expect_equal(
    max(sector_weights$weight, na.rm = TRUE), 1
  )
})

test_that("every purpose code appears once per universe", {
  expect_equal(nrow(sector_weights), 33L * 3L)
  expect_true(all(table(sector_weights$purpose_code) == 3L))
  expect_true(all(grepl("^[0-9]{5}$", sector_weights$purpose_code)))
  expect_type(sector_weights$purpose_code, "character")
})

test_that("every agency appears in every year of every edition", {
  expect_equal(nrow(agency_weights), 11L * 3L * 3L * 2L)
  expect_setequal(agency_weights$data_year, 2021:2024)
  expect_setequal(agency_weights$report_edition, c(2025L, 2026L))

  # A missing agency-year would silently drop an agency from a total when a
  # caller switched edition.
  counts <- table(agency_weights$agency, agency_weights$data_year,
                  agency_weights$report_edition)
  expect_true(all(counts %in% c(0L, 3L)))

  # Each edition covers exactly three consecutive spending years.
  for (ed in unique(agency_weights$report_edition)) {
    yrs <- sort(unique(agency_weights$data_year[
      agency_weights$report_edition == ed
    ]))
    expect_length(yrs, 3L)
    expect_true(all(diff(yrs) == 1L))
  }
})

test_that("the two editions together span four consecutive spending years", {
  # This is what makes the four per-donor RMNCH weights recoverable: four
  # unknowns need four independent published years, and neither edition alone
  # provides them.
  expect_equal(sort(unique(agency_weights$data_year)), 2021:2024)
})

test_that("editions disagree about years they both publish", {
  # Not a defect — each edition recomputes earlier years as the underlying
  # multilateral data is revised. Asserted because it is the reason
  # report_edition exists: were these identical, the column would be
  # redundant and callers could mix editions freely. They cannot.
  both <- merge(
    agency_weights[agency_weights$report_edition == 2025L, ],
    agency_weights[agency_weights$report_edition == 2026L, ],
    by = c("agency", "data_year", "universe")
  )
  expect_equal(nrow(both), 66L)
  expect_gt(sum(both$weight.x != both$weight.y), 0L)

  # The single largest revision, kept as a concrete anchor.
  adb <- both[both$agency == "Asian Development Bank" &
                both$data_year == 2023L & both$universe == "rmnch", ]
  expect_equal(adb$weight.x, 0.0518)
  expect_equal(adb$weight.y, 0.1342)
})

test_that("universe is the same factor in both tables", {
  expect_identical(levels(sector_weights$universe), c("rmnch", "srhr", "fp"))
  expect_identical(levels(agency_weights$universe), levels(sector_weights$universe))
})

# ---- the unresolved cells ------------------------------------------------
# These tests pin the KNOWN GAPS in place. They are expected to be edited
# when the gaps are resolved — that edit is the signal that a real weight
# arrived, and it should be deliberate rather than incidental.

test_that("sectors whose RMNCH weight varies by donor are NA, not zero", {
  # These four carry a per-donor RMNCH share that this table cannot hold.
  # They stay NA until the donor-level weights are derived, so that
  # muskoka(universe = "rmnch") refuses rather than understates.
  varies <- c("12262", "12263", "13040", "51010")
  w <- sector_weights$weight[
    sector_weights$universe == "rmnch" & sector_weights$purpose_code %in% varies
  ]
  expect_length(w, length(varies))
  expect_true(all(is.na(w)))
})

test_that("the SRHR universe is fully specified", {
  # SRHR carries a weight for every purpose code. This is worth asserting
  # because eight of those values repeat the column's own first eight, which
  # reads as a spreadsheet fill; it was queried and confirmed correct. The
  # test stops a future reader from "fixing" them back to NA.
  srhr <- sector_weights[sector_weights$universe == "srhr", ]
  expect_false(anyNA(srhr$weight))
  expect_equal(
    srhr$weight[srhr$purpose_code %in% c("15170", "15180", "16064", "51010",
                                         "72010", "72040", "72050", "73010")],
    c(0.044, 0.094, 0.154, 0.161, 0.000, 0.175, 0.100, 0.136)
  )
})

test_that("IDA's FP weight is a published zero in every year and edition", {
  # The Donors Delivering method does not count IDA contributions to FP, so
  # this zero is a methodological choice rather than a missing value. The 1%
  # revised-Muskoka alternative is applied by muskoka(ida = 1) at call time
  # and must NOT appear as a weight here.
  w <- agency_weights$weight[
    agency_weights$agency == "IDA" & agency_weights$universe == "fp"
  ]
  # Six cells: three spending years in each of two editions.
  expect_length(w, 6L)
  expect_true(all(w == 0))
})

test_that("unresolved weights are confined to the documented cells", {
  # Guards against an NA appearing somewhere undocumented — which would mean
  # a weight was lost in an edit rather than deliberately withheld.
  expect_equal(sum(is.na(sector_weights$weight)), 4L)
  expect_false(anyNA(agency_weights$weight))
  # Every unresolved sector weight is an RMNCH one; the other two universes
  # are complete.
  expect_true(all(
    sector_weights$universe[is.na(sector_weights$weight)] == "rmnch"
  ))
})
