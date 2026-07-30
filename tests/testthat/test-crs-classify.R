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

# ---- levels ---------------------------------------------------------------

test_that("descend_one() returns a frontier, not a depth slice", {
  # The property that keeps every level a partition. `b` has children and `c`
  # does not, so descending once must expand `b` and carry `c` through
  # unchanged. A plain depth slice would drop `c` and the level would no
  # longer add up.
  tree <- tibble::tibble(
    parent_code = c("a", "a", "b", "b"),
    child_code  = c("b", "c", "d", "e")
  )
  expect_setequal(descend_one("a", tree), c("b", "c"))
  expect_setequal(descend_one(c("b", "c"), tree), c("d", "e", "c"))
  # A terminal set is a fixed point: descending further changes nothing, so
  # asking for a level deeper than the tree is safe.
  expect_setequal(descend_one(c("d", "e", "c"), tree), c("d", "e", "c"))
})

test_that("level accepts names and numbers, and rejects the rest", {
  x <- fake_crs(100)
  expect_equal(crs_classify(x, "geographic", level = 0)$member, "DPGC")
  expect_equal(crs_classify(x, "geographic", level = "total")$member, "DPGC")
  expect_equal(
    crs_classify(x, "geographic", level = 1)$level[1], "continent"
  )
  expect_equal(crs_classify(x, "dac_income", level = 1)$level[1], "tier")
  expect_equal(crs_classify(x, "wb_income", level = 1)$level[1], "group")

  # The income schemes are only two deep, so a geographic level name is not
  # valid for them — silently clamping would return a different cut than asked
  # for.
  expect_error(crs_classify(x, "dac_income", level = "subregion"), "must be one of")
  expect_error(crs_classify(x, "geographic", level = 9), "between 0 and 4")
  expect_error(crs_classify(x, "dac_income", level = 3), "between 0 and 2")
  expect_error(crs_classify(x, "geographic", level = -1), "between 0 and 4")
})

test_that("level 0 is the grand total itself", {
  x <- fake_crs(100)
  r <- crs_classify(x, "geographic", level = 0)
  expect_equal(nrow(r), 1L)
  expect_equal(r$value, 100)
  expect_equal(r$share, 1)
})

test_that("the INC_X -> DPGC_X repair is present in the tree", {
  # Without this edge, cutting an income scheme at country level descends
  # INC_X through the codelist and loses DPGC_X entirely — for the US in 2022
  # that is 32% of the donor's total, and the level silently fails to match
  # the tier level above it. The edge is a local correction to OECD's
  # codelist, so it is asserted rather than assumed.
  tr <- crs_recipient_tree
  expect_true(any(tr$parent_code == "INC_X" & tr$child_code == "DPGC_X"))
  # And it must not create a second route to DPGC_X from a geographic node,
  # which would double count it.
  expect_setequal(tr$parent_code[tr$child_code == "DPGC_X"],
                  c("DPGC", "INC_X"))
})

test_that("a scheme exceeding the total names double counting", {
  # The two failure directions have different causes and different fixes, so
  # the message must distinguish them rather than say only "does not sum".
  x <- fake_crs(100)
  x$value[x$recipient == "F"] <- 80          # geographic now sums to 120
  expect_error(crs_classify(x, "geographic"), "EXCEEDS the total")
  expect_error(crs_classify(x, "geographic"), "double counting")

  x2 <- fake_crs(100)
  x2$value[x2$recipient == "F"] <- 40        # now sums to 80
  expect_error(crs_classify(x2, "geographic"), "falls SHORT")
  expect_error(crs_classify(x2, "geographic"), "INC_X -> DPGC_X")
})

test_that("every scheme agrees with every other at the levels held here", {
  # The audit property, on the fixture: not merely that each combination
  # matches DPGC, but that all of them match EACH OTHER. Checked as a spread
  # so a single drifting combination is caught wherever it sits.
  #
  # Levels 0 and 1 only. The fixture holds continent- and tier-level codes, so
  # descending further finds nothing and crs_classify() rightly refuses —
  # asserting agreement at those depths would be asserting that the fixture is
  # complete, which it is not. Deeper levels are covered against live data in
  # test-oecd-live.R.
  x <- fake_crs(100)
  totals <- unlist(lapply(names(CRS_SCHEMES), function(s) {
    vapply(0:1, function(lv) sum(crs_classify(x, s, level = lv)$value),
           numeric(1))
  }))
  expect_length(totals, 6L)
  expect_equal(max(totals) - min(totals), 0, tolerance = 1e-9)
})

test_that("an incomplete input is refused rather than under-reported", {
  # The flip side: the fixture cannot support a country-level cut, and asking
  # for one must fail. This is the behaviour that makes the agreement test
  # above meaningful — silence here would mean a level can quietly return less
  # than the whole.
  x <- fake_crs(100)
  expect_error(crs_classify(x, "geographic", level = "country"),
               "falls SHORT|does not sum")
})

test_that("complete= fills unfunded members with zero without moving a total", {
  x <- fake_crs(100)
  a <- crs_classify(x, "geographic", level = 1)
  b <- crs_classify(x, "geographic", level = 1, complete = TRUE)

  # The fixture omits Europe and Oceania, so completing must add them at zero.
  expect_false(all(c("E", "O") %in% a$member))
  expect_true(all(c("E", "O") %in% b$member))
  expect_gt(nrow(b), nrow(a))
  expect_equal(sum(b$value), sum(a$value), tolerance = 1e-9)
  expect_true(all(b$value[b$member %in% c("E", "O")] == 0))

  # And a zero-filled row must still say which recipient it is, taken from the
  # bundled codelist since it is absent from the data.
  expect_false(anyNA(b$member_name))
  expect_equal(b$member_name[b$member == "E"], "Europe")
})

test_that("completing does not disturb the partition check", {
  # Zeros cannot change a sum, so a completed result must pass the same check.
  x <- fake_crs(100)
  for (s in names(CRS_SCHEMES)) {
    r <- crs_classify(x, s, level = 1, complete = TRUE)
    expect_equal(sum(r$value), attr(r, "grand_total"), tolerance = 1e-9)
  }
})

test_that("every recipient code carries a name", {
  # The property `complete = TRUE` depends on: a member absent from the data is
  # labelled from crs_recipients instead.
  expect_false(anyNA(crs_recipients$recipient_name))
  expect_equal(
    crs_recipients$recipient_name[crs_recipients$recipient_code == "KEN"],
    "Kenya"
  )
  expect_equal(
    crs_recipients$recipient_name[crs_recipients$recipient_code == "DPGC_X"],
    "Developing countries unspecified"
  )
})
