# Fixture standing in for oecd_crs(recipients = "all"): one row per recipient,
# with values chosen so every scheme sums to the same grand total. Built by
# hand rather than recorded, so the partition property is visible here rather
# than buried in a saved object.
fake_crs <- function(total = 100) {
  rows <- rbind(
    data.frame(recipient = "DPGC",    recipient_name = "Developing countries",             value = 100),
    # geographic: 60 + 25 + 10 + 5 = 100
    data.frame(recipient = "F",       recipient_name = "Africa",                           value = 60),
    data.frame(recipient = "S",       recipient_name = "Asia",                              value = 25),
    data.frame(recipient = "A",       recipient_name = "America",                           value = 10),
    data.frame(recipient = "DPGC_X",  recipient_name = "Developing countries unspecified",  value = 5),
    # dac_income: 70 + 20 + 10 = 100
    data.frame(recipient = "LDC",     recipient_name = "Least developed countries",         value = 70),
    data.frame(recipient = "LMIC",    recipient_name = "Lower-middle income countries",     value = 20),
    data.frame(recipient = "INC_X",   recipient_name = "Countries unallocated by income",   value = 10),
    # wb_income: 55 + 30 + 5 + 10 = 100
    data.frame(recipient = "OLICWB",  recipient_name = "Low income countries (World Bank)", value = 55),
    data.frame(recipient = "LMICWB",  recipient_name = "Lower-middle (World Bank)",         value = 30),
    data.frame(recipient = "INCWB_X", recipient_name = "Not classified by the World Bank",  value = 5),
    # an overlapping flag, which must never enter a scheme
    data.frame(recipient = "FSCAC",   recipient_name = "Fragile contexts",                  value = 47)
  )
  # Every value scales with `total`, so a fixture at any size keeps the
  # partition property. Scaling only DPGC would make the fixture itself
  # inconsistent — and crs_classify() would rightly reject it.
  rows$value <- rows$value * total / 100
  rows$donor <- "USA"
  rows$year <- 2022L
  tibble::as_tibble(rows)
}

test_that("every scheme sums to the same grand total", {
  # The property the whole function exists to provide: three different cuts of
  # one pot of money, each adding to that pot.
  x <- fake_crs(100)
  for (s in c("geographic", "dac_income", "wb_income")) {
    r <- crs_classify(x, s)
    expect_equal(sum(r$value), 100, tolerance = 1e-9)
    expect_equal(attr(r, "grand_total"), 100)
    expect_equal(sum(r$share), 1, tolerance = 1e-9)
  }
})

test_that("overlapping flags never enter a scheme", {
  # FSCAC is 47% of the fixture total and overlaps every scheme. If it leaked
  # into one, that scheme would exceed the grand total and the check below
  # would already have failed — this asserts it directly as well.
  x <- fake_crs(100)
  for (s in c("geographic", "dac_income", "wb_income")) {
    expect_false("FSCAC" %in% crs_classify(x, s)$member)
  }
})

test_that("each scheme marks exactly one residual member", {
  x <- fake_crs(100)
  expect_equal(crs_classify(x, "geographic")$member[
    crs_classify(x, "geographic")$is_residual], "DPGC_X")
  expect_equal(crs_classify(x, "dac_income")$member[
    crs_classify(x, "dac_income")$is_residual], "INC_X")
  expect_equal(crs_classify(x, "wb_income")$member[
    crs_classify(x, "wb_income")$is_residual], "INC_X")
})

test_that("a scheme that does not add up is an error, not a result", {
  # The guard that makes the published-aggregates approach safe. OECD's
  # codelist does not exactly describe its reported aggregates, so the parts
  # coming to less than the whole is a real possibility rather than a
  # hypothetical one, and it must not be returned as if it were fine.
  x <- fake_crs(100)
  x$value[x$recipient == "F"] <- 40   # was 60; geographic now sums to 80
  expect_error(crs_classify(x, "geographic"), "does not sum to OECD's reported total")
  # The other schemes are untouched and must still work.
  expect_equal(sum(crs_classify(x, "dac_income")$value), 100)
})

test_that("a result without aggregate rows is refused", {
  x <- fake_crs(100)
  expect_error(
    crs_classify(x[x$recipient != "DPGC", ], "geographic"),
    "no DPGC row"
  )
})

test_that("by= can break totals down further", {
  x <- rbind(fake_crs(100), transform(fake_crs(60), year = 2023L))
  r <- crs_classify(x, "geographic", by = c("donor", "year"))
  expect_setequal(r$year, c(2022L, 2023L))
  expect_equal(sum(r$value[r$year == 2022L]), 100)
  expect_equal(sum(r$value[r$year == 2023L]), 60)
  expect_error(crs_classify(x, "geographic", by = "nope"), "not in `x`")
})
