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

test_that("every purpose code appears once per universe per edition", {
  eds <- sort(unique(sector_weights$report_edition))
  expect_setequal(eds, c(2023L, 2024L, 2025L, 2026L))
  expect_equal(nrow(sector_weights), 33L * 3L * length(eds))
  expect_true(all(table(sector_weights$purpose_code) == 3L * length(eds)))
  expect_true(all(table(sector_weights$report_edition) == 33L * 3L))
  expect_true(all(grepl("^[0-9]{5}$", sector_weights$purpose_code)))
  expect_type(sector_weights$purpose_code, "character")
})

test_that("every agency appears in every year of every edition", {
  expect_equal(nrow(agency_weights), 11L * 3L * 3L * 4L)
  expect_setequal(agency_weights$data_year, 2019:2024)
  expect_setequal(agency_weights$report_edition, c(2023L, 2024L, 2025L, 2026L))

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

test_that("the editions together span six consecutive spending years", {
  # Each edition covers three years and successive editions step forward by
  # one, so the four together cover 2019-2024 with no gap. A gap would mean a
  # spending year no edition can price.
  expect_equal(sort(unique(agency_weights$data_year)), 2019:2024)
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
  eds <- length(unique(sector_weights$report_edition))
  w <- sector_weights$weight[
    sector_weights$universe == "rmnch" & sector_weights$purpose_code %in% varies
  ]
  expect_length(w, length(varies) * eds)
  expect_true(all(is.na(w)))
})

test_that("the SRHR universe is fully specified", {
  # SRHR carries a weight for every purpose code, in every edition.
  srhr <- sector_weights[sector_weights$universe == "srhr", ]
  expect_false(anyNA(srhr$weight))
  expect_false(anyNA(srhr$weight_printed))
})

test_that("the nine misprinted values are corrected in every edition", {
  # `weight` is what to compute with and must be identical across editions:
  # the nine are errata, not revisions, so each edition's own published
  # totals are reproduced by the corrected figure rather than by its table.
  fix <- c("15170" = 0.076, "15180" = 0.415, "16064" = 0.500, "51010" = 0.000,
           "72010" = 0.023, "72040" = 0.001, "72050" = 0.007, "73010" = 0.006)
  for (ed in unique(sector_weights$report_edition)) {
    s <- sector_weights[sector_weights$universe == "srhr" &
                          sector_weights$report_edition == ed, ]
    expect_equal(s$weight[match(names(fix), s$purpose_code)], unname(fix),
                 label = paste("SRHR weights, edition", ed))
    r <- sector_weights[sector_weights$universe == "rmnch" &
                          sector_weights$report_edition == ed, ]
    expect_equal(r$weight[r$purpose_code == "12191"], 0.40)
  }

  # `weight_printed` must preserve what each edition actually prints, or the
  # erratum becomes invisible and unverifiable against the source.
  printed <- c("15170" = 0.044, "15180" = 0.094, "16064" = 0.154,
               "51010" = 0.161, "72010" = 0.000, "72040" = 0.175,
               "72050" = 0.100, "73010" = 0.136)
  for (ed in c(2025L, 2026L)) {
    s <- sector_weights[sector_weights$universe == "srhr" &
                          sector_weights$report_edition == ed, ]
    expect_equal(s$weight_printed[match(names(printed), s$purpose_code)],
                 unname(printed), label = paste("printed SRHR, edition", ed))
    r <- sector_weights[sector_weights$universe == "rmnch" &
                          sector_weights$report_edition == ed, ]
    expect_equal(r$weight_printed[r$purpose_code == "12191"], 1.00)
  }

  # The 2023 and 2024 editions print the correct figures, so nothing is
  # flagged there. Exactly nine cells differ in each of the other two.
  expect_equal(sum(sector_weights$is_misprint), 9L * 2L)
  expect_setequal(sector_weights$report_edition[sector_weights$is_misprint],
                  c(2025L, 2026L))
  expect_true(all(
    sector_weights$weight[!sector_weights$is_misprint] ==
      sector_weights$weight_printed[!sector_weights$is_misprint],
    na.rm = TRUE
  ))
})

test_that("IDA's FP weight is a published zero in every year and edition", {
  # The Donors Delivering method does not count IDA contributions to FP, so
  # this zero is a methodological choice rather than a missing value. The 1%
  # revised-Muskoka alternative is applied by muskoka(ida = 1) at call time
  # and must NOT appear as a weight here.
  w <- agency_weights$weight[
    agency_weights$agency == "IDA" & agency_weights$universe == "fp"
  ]
  # Three spending years in each of four editions.
  expect_length(w, 12L)
  expect_true(all(w == 0))
})

test_that("unresolved weights are confined to the documented cells", {
  # Guards against an NA appearing somewhere undocumented — which would mean
  # a weight was lost in an edit rather than deliberately withheld.
  eds <- length(unique(sector_weights$report_edition))
  expect_equal(sum(is.na(sector_weights$weight)), 4L * eds)
  expect_equal(sum(is.na(sector_weights$weight_printed)), 4L * eds)
  expect_false(anyNA(agency_weights$weight))
  # Every unresolved sector weight is an RMNCH one; the other two universes
  # are complete.
  expect_true(all(
    sector_weights$universe[is.na(sector_weights$weight)] == "rmnch"
  ))
})

test_that("muskoka_weights() returns both halves for an edition", {
  w <- muskoka_weights(2026)
  expect_setequal(w$half, c("bilateral", "multilateral"))
  expect_equal(sum(w$half == "bilateral"), 33L * 3L)
  expect_equal(sum(w$half == "multilateral"), 11L * 3L * 3L)
  expect_true(all(w$report_edition == 2026L))

  # Bilateral weights do not vary by year, so carrying a year would imply a
  # precision the source does not have.
  expect_true(all(is.na(w$data_year[w$half == "bilateral"])))
  expect_false(anyNA(w$data_year[w$half == "multilateral"]))
})

test_that("muskoka_weights() surfaces the misprints, and only where they are", {
  expect_equal(sum(muskoka_weights(2026)$is_misprint), 9L)
  expect_equal(sum(muskoka_weights(2025)$is_misprint), 9L)
  expect_equal(sum(muskoka_weights(2024)$is_misprint), 0L)
  expect_equal(sum(muskoka_weights(2023)$is_misprint), 0L)

  # Never on the multilateral half: no agency misprint has been established.
  w <- muskoka_weights(2026)
  expect_false(any(w$is_misprint[w$half == "multilateral"]))
})

test_that("muskoka_weights() rejects an edition or year it cannot serve", {
  expect_error(muskoka_weights(2019), "must be one of")
  expect_error(muskoka_weights(2026, year = 2019), "covers spending year")
  # The 2023 edition does cover 2019, so the same year is fine there. This is
  # the point of the error: the valid range depends on the edition.
  expect_silent(muskoka_weights(2023, year = 2019))
})

test_that("muskoka_weights() filters without changing the weights", {
  full <- muskoka_weights(2026)
  srhr <- muskoka_weights(2026, universe = "srhr")
  expect_true(all(srhr$universe == "srhr"))
  expect_equal(
    srhr$weight,
    full$weight[full$universe == "srhr"]
  )
})
