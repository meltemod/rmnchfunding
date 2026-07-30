# Tests for the parts of the fetchers that do not touch the network. The key
# builder and the argument checks are where a silent error would do the most
# damage: an SDMX key is POSITIONAL, so a field in the wrong slot filters on
# the wrong dimension and still returns a plausible-looking number.

test_that("keys place each dimension in the right slot", {
  # Named arguments, positional output. Written out in full rather than
  # generated, so the test would fail if the field order were edited.
  expect_equal(
    sdmx_key(CRS_KEY_FIELDS, donor = "USA", sector = "13020"),
    "USA..13020........"
  )
  expect_equal(
    sdmx_key(CRS_KEY_FIELDS, donor = "USA", recipient = "KEN",
             sector = "13020", measure = "100", channel = "_T",
             modality = "_T", flow_type = "D", price_base = "V",
             md_dim = "_T", unit_measure = "USD"),
    "USA.KEN.13020.100._T._T.D.V._T..USD"
  )
})

test_that("keys have exactly one slot per dimension", {
  # OECD answers a wrong-length key with HTTP 422, so the count is the single
  # most important property of this function.
  expect_equal(
    lengths(gregexpr(".", sdmx_key(CRS_KEY_FIELDS), fixed = TRUE)),
    length(CRS_KEY_FIELDS) - 1L
  )
  expect_equal(
    lengths(gregexpr(".", sdmx_key(MULTI_KEY_FIELDS), fixed = TRUE)),
    length(MULTI_KEY_FIELDS) - 1L
  )
  # MULTI has no modality dimension; CRS does. Confusing them would shift
  # every field after it.
  expect_false("modality" %in% MULTI_KEY_FIELDS)
  expect_true("modality" %in% CRS_KEY_FIELDS)
  expect_equal(length(CRS_KEY_FIELDS), 11L)
  expect_equal(length(MULTI_KEY_FIELDS), 10L)
})

test_that("multiple values for one dimension become an SDMX OR", {
  expect_equal(
    sdmx_key(MULTI_KEY_FIELDS, donor = "USA", channel = c("41307", "41143")),
    "USA....41307+41143....."
  )
})

test_that("an unknown dimension name is an error, not a silent no-op", {
  # The failure this prevents: a typo like `sectors =` would otherwise be
  # dropped, quietly widening the query to every sector.
  expect_error(
    sdmx_key(CRS_KEY_FIELDS, donor = "USA", sectors = "13020"),
    "Not a dimension"
  )
  expect_error(
    sdmx_key(MULTI_KEY_FIELDS, modality = "_T"),
    "Not a dimension"
  )
})

test_that("constant prices require an explicit base year", {
  # The base is mandatory because OECD rebases its own series each release, so
  # any implicit default would change meaning underneath the caller.
  expect_error(check_prices("constant", NULL), "needs a `base` year")
  expect_equal(check_prices("constant", 2023)$base, 2023L)
  expect_equal(check_prices("constant", "2022")$base, 2022L)
  expect_error(check_prices("constant", c(2022, 2023)), "single year")
  expect_error(check_prices("constant", "not a year"), "single year")
})

test_that("current prices reject a base year", {
  expect_error(check_prices("current", 2023), "applies only to")
  expect_null(check_prices("current", NULL)$base)
  expect_equal(check_prices("current", NULL)$prices, "current")
})

test_that("the default sector list comes from sector_weights", {
  # Duplicating the codes would let the fetcher and the weights drift apart:
  # a code added to one and not the other would be fetched but unweighted, or
  # weighted but never fetched.
  codes <- muskoka_purpose_codes()
  expect_setequal(codes, unique(as.character(sector_weights$purpose_code)))
  expect_length(codes, 33L)
  expect_true(all(grepl("^[0-9]{5}$", codes)))
})

# ---- the de-duplication rule ---------------------------------------------

test_that("aggregate recipients are identified from the hierarchy", {
  expect_true(
    crs_recipients$is_aggregate[crs_recipients$recipient_code == "DPGC"]
  )
  expect_false(
    crs_recipients$is_aggregate[crs_recipients$recipient_code == "KEN"]
  )
  # Every aggregate has children and every leaf has none — the definition the
  # dedup depends on.
  expect_true(all(crs_recipients$n_children[crs_recipients$is_aggregate] > 0L))
  expect_true(all(crs_recipients$n_children[!crs_recipients$is_aggregate] == 0L))
})

test_that("recipient codes are unique despite overlapping groupings", {
  # The hierarchy is not a tree: DPGC, LLDC, SIDS, the World Bank income
  # groups and others all classify the same countries, so a naive walk emits
  # a code once per grouping it appears in. This dataset must be keyed by
  # distinct code or a join against it would multiply rows.
  expect_false(anyDuplicated(crs_recipients$recipient_code) > 0L)
  expect_true(any(crs_recipients$n_appearances > 1L))
})

test_that("unallocated buckets are marked but not treated as aggregates", {
  # `_X` codes hold spending OECD could not attribute to a country. They have
  # no members, so they do not overlap the countries beside them and must stay
  # in a total; but they are not countries either. Both halves matter.
  x <- crs_recipients[crs_recipients$is_unallocated, ]
  expect_gt(nrow(x), 20L)
  expect_true(crs_recipients$is_unallocated[
    crs_recipients$recipient_code == "DPGC_X"
  ])
  expect_false(crs_recipients$is_unallocated[
    crs_recipients$recipient_code == "KEN"
  ])

  # Independent of is_aggregate: INC_X and INCWB_X group income-unclassified
  # countries and so do have members. Pinned so a third such code is noticed.
  # Compared as a set: `sort()` on these two codes is locale-dependent, since
  # collation of "_" against letters differs between locales.
  expect_setequal(x$recipient_code[x$is_aggregate], c("INC_X", "INCWB_X"))
})

test_that("empty results have the full column schema, not zero columns", {
  # A donor that funded nothing must flow through the same downstream code as
  # one that did. A zero-row, zero-column tibble would fail on the first
  # column reference instead.
  pb <- list(prices = "constant", base = 2023L)
  e <- empty_crs(pb)
  expect_equal(nrow(e), 0L)
  expect_true(all(c("donor", "recipient", "purpose_code", "year", "value",
                    "is_aggregate", "is_unallocated") %in% names(e)))
  expect_identical(attr(e, "prices"), "constant")
  expect_identical(attr(e, "base_year"), 2023L)

  m <- empty_multi(pb, "10")
  expect_equal(nrow(m), 0L)
  expect_true(all(c("donor", "agency", "year", "value", "n_channels")
                  %in% names(m)))
  expect_identical(attr(m, "measure"), "10")

  # The empty shapes must match the populated ones, or code that works on one
  # breaks on the other.
  expect_setequal(
    names(e),
    c("donor", "donor_name", "recipient", "recipient_name", "purpose_code",
      "purpose_name", "year", "value", "is_aggregate", "is_unallocated")
  )
})
