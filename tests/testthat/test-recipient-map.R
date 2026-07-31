# recipient_map() joins the identity crosswalk to the imputation provenance.
# The join is the whole point: neither table alone answers "is this weight
# borrowed, and from where", which is the question a reader checking the
# method actually has.

test_that("the default returns one row per recipient with a column per code", {
  m <- recipient_map()
  expect_equal(nrow(m), nrow(recipient_crosswalk))
  expect_false(anyDuplicated(m$recipient_code) > 0L)
  codes <- sort(unique(rmnch_recipient_weights$purpose_code))
  expect_true(all(paste0("source_", codes) %in% names(m)))
  expect_false("source" %in% names(m))
})

test_that("naming one code collapses to a single source column", {
  m <- recipient_map("12262")
  expect_true("source" %in% names(m))
  expect_false(any(grepl("^source_", names(m))))
  expect_equal(nrow(m), nrow(recipient_crosswalk))
})

test_that("the source columns agree with the weights they describe", {
  # A crosswalk that drifted from the data would be worse than none, since it
  # is the artefact someone checks the method against.
  m <- recipient_map()
  w <- rmnch_recipient_weights
  for (pc in unique(w$purpose_code)) {
    d <- w[w$purpose_code == pc, ]
    expected <- tapply(d$source, d$recipient_code, function(x) unique(x)[1])
    got <- stats::setNames(m[[paste0("source_", pc)]], m$recipient_code)
    expect_equal(as.vector(got[names(expected)]), as.vector(expected),
                 label = paste("source for", pc))
  }
})

test_that("imputed_only keeps exactly the borrowed recipients", {
  all_m <- recipient_map("12262")
  imp <- recipient_map("12262", imputed_only = TRUE)
  expect_equal(nrow(imp), sum(all_m$source != "own"))
  expect_false(any(imp$source == "own"))
  expect_true(all(imp$recipient_code %in% all_m$recipient_code))

  # With no code named, "borrowed" means borrowed for at least one code.
  any_imp <- recipient_map(imputed_only = TRUE)
  expect_gte(nrow(any_imp), nrow(imp))
})

test_that("data-availability flags match the identifier columns", {
  m <- recipient_map()
  expect_equal(m$has_worldbank_data, !is.na(m$iso3))
  expect_equal(m$has_gbd_data, !is.na(m$gbd_location_name))
  # A recipient missing from both must be borrowing everywhere.
  both <- m[!m$has_worldbank_data & !m$has_gbd_data, ]
  if (nrow(both) > 0L) {
    src <- both[grep("^source_", names(both))]
    expect_true(all(unlist(src) != "own"))
  }
})

test_that("bad arguments fail with a message naming the valid codes", {
  expect_error(recipient_map("99999"), "must be one of")
  expect_error(recipient_map("12262"), NA)
  expect_error(recipient_map(c("12262", "13040")), "must be one of")
  expect_error(recipient_map(imputed_only = "yes"), "TRUE or FALSE")
})
