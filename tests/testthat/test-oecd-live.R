# End-to-end tests against the live OECD API. Skipped on CRAN and when
# offline, because a package check must not fail because a third-party service
# is down or rate-limiting. They are kept because the properties they assert
# cannot be checked against a fixture: they are properties of OECD's data, not
# of this code, and the failure they guard against is OECD changing shape
# under us in a way that still returns plausible numbers.

skip_if_no_oecd <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_offline("sdmx.oecd.org")
}

# OECD rate-limits, and a run of these tests can trip it even with the
# throttling in oecd_fetch(). A 429 or a 5xx says nothing about whether this
# package is correct, so it skips rather than fails — a red suite should mean
# broken code, not a busy server.
oecd_or_skip <- function(expr) {
  withCallingHandlers(
    tryCatch(
      expr,
      httr2_http = function(cnd) {
        testthat::skip(paste("OECD API unavailable:", conditionMessage(cnd)))
      },
      httr2_failure = function(cnd) {
        testthat::skip(paste("OECD API unreachable:", conditionMessage(cnd)))
      }
    ),
    warning = function(w) invokeRestart("muffleWarning")
  )
}

test_that("leaf recipients sum exactly to OECD's reported total", {
  skip_if_no_oecd()

  # THE test for the de-duplication rule. If leaves were double counting the
  # sum would exceed DPGC; if the `_X` unallocated buckets were being dropped
  # as "not countries" it would fall short. Only the correct leaf set is
  # exactly additive, so this single equality pins both halves of the rule.
  #
  # One purpose code keeps the response small enough to be a quick check.
  d <- oecd_or_skip(oecd_crs(
    "USA", years = 2022, sectors = "13040", prices = "current",
    recipients = "all", quiet = TRUE
  ))

  total <- d$value[d$recipient == "DPGC"]
  expect_length(total, 1L)
  expect_equal(sum(d$value[!d$is_aggregate]), total, tolerance = 1e-8)

  # The unallocated buckets are a real and large part of that total, so a
  # future "tidy-up" that dropped them would be caught here as well as by the
  # equality above.
  expect_true(any(d$is_unallocated))
  expect_gt(sum(d$value[d$is_unallocated]) / total, 0.01)
})

test_that("one row per donor, recipient, purpose code and year", {
  skip_if_no_oecd()

  # Guards the hierarchical-dimension trap. CHANNEL and MODALITY each return a
  # `_T` total alongside their components at several levels, so leaving either
  # open turns one figure into dozens whose sum is a multiple of the truth.
  d <- oecd_or_skip(oecd_crs(
    "USA", years = 2022, sectors = c("13020", "13030"),
    prices = "current", quiet = TRUE
  ))
  key <- paste(d$donor, d$recipient, d$purpose_code, d$year)
  expect_false(anyDuplicated(key) > 0L)
})

test_that("multilateral core contributions are one row per agency-year", {
  skip_if_no_oecd()

  # The same trap on the other dataflow, where RECIPIENT and SECTOR are the
  # hierarchical ones: unpinned, a single donor-agency-year returned six times
  # and summed to roughly six times its true value.
  m <- oecd_or_skip(oecd_multi(
    "USA", years = 2022, agencies = "Global Fund",
    prices = "current", quiet = TRUE
  ))
  expect_equal(nrow(m), 1L)
  # Sanity band rather than an exact figure, which OECD revises: a US core
  # contribution to the Global Fund is billions, not tens of billions. The
  # unpinned bug produced 19,953.
  expect_gt(m$value, 1000)
  expect_lt(m$value, 10000)
})

test_that("locally deflated values match OECD's own constant series", {
  skip_if_no_oecd()

  # Values are fetched in current prices and deflated here, so that any base
  # year can be requested rather than only whichever one OECD's current release
  # publishes. This checks that arithmetic against OECD's own constant series,
  # which is only possible for the base they happen to be using.
  cur <- oecd_or_skip(oecd_crs(
    "USA", years = 2022, sectors = "13020", prices = "current", quiet = TRUE
  ))
  base_per <- 2024  # OECD's base at the time of writing; see below.
  ours <- oecd_or_skip(oecd_crs(
    "USA", years = 2022, sectors = "13020",
    prices = "constant", base = base_per, quiet = TRUE
  ))

  skip_if(nrow(cur) == 0L || nrow(ours) == 0L, "No data returned.")
  m <- merge(
    cur[c("recipient", "value")], ours[c("recipient", "value")],
    by = "recipient", suffixes = c("_cur", "_con")
  )
  # Same rows, and every constant value is the current one scaled by a single
  # per-donor deflator, so the ratio must be constant across recipients.
  ratio <- m$value_con / m$value_cur
  expect_equal(stats::sd(ratio), 0, tolerance = 1e-6)
})

test_that("OECD has not silently rebased its constant series", {
  skip_if_no_oecd()

  # A tripwire, not a correctness test. Nothing in this package depends on
  # OECD's base year — values are always fetched in current prices — but the
  # documentation, the README and the guidance about matching a report edition
  # all quote 2024 as the current base. When OECD rebases, this fails and says
  # what to update, rather than the docs quietly going stale.
  d <- oecd_or_skip(oecd_crs(
    "USA", years = 2022, sectors = "13020", prices = "current", quiet = TRUE
  ))
  skip_if(nrow(d) == 0L, "No data returned.")
  defl <- oecd_or_skip(oecd_deflators("USA", 2024))
  expect_true(2022L %in% defl$year,
              label = paste0(
                "OECD no longer publishes deflators with base 2024. ",
                "Update the base year quoted in ?oecd_crs and README.md."
              ))
})

test_that("every level of every scheme sums to the same grand total", {
  skip_if_no_oecd()

  # The claim the classification schemes exist to support: geography, DAC
  # income tier and World Bank income group are three cuts of one pot of
  # money, and each can be cut finer without the total changing. Checked
  # against live data because it depends on OECD's published aggregates
  # agreeing with their own hierarchy, which is not guaranteed — it already
  # failed once, for DPGC_X under INC_X.
  d <- oecd_or_skip(oecd_crs(
    "USA", years = 2022, sectors = "13040", prices = "current",
    recipients = "all", quiet = TRUE
  ))
  total <- sum(d$value[d$recipient == "DPGC"])

  for (s in c("geographic", "dac_income", "wb_income")) {
    for (lv in rmnchfunding:::CRS_SCHEME_LEVELS[[s]]) {
      r <- crs_classify(d, s, level = lv)
      expect_equal(sum(r$value), total, tolerance = 1e-6,
                   label = paste0(s, " at level '", lv, "'"))
    }
  }
})

test_that("all schemes and levels agree across several donors and years", {
  skip_if_no_oecd()

  # The full audit, narrowed to stay quick: three donors of very different
  # size and shape, four years, every scheme at every level. The property is
  # that all eleven combinations agree with each other, not just with DPGC,
  # since a shared error would satisfy the weaker claim.
  #
  # GRC is included deliberately: a small donor with sparse data, where scheme
  # members are absent rather than zero, which is the case most likely to make
  # a level fail to add up.
  for (donor in c("USA", "GRC", "4EU001")) {
    d <- suppressWarnings(oecd_or_skip(oecd_crs(
      donor, years = 2021:2024, sectors = c("13020", "13030", "13040"),
      prices = "current", recipients = "all", quiet = TRUE
    )))
    # A donor with no disbursements in these sectors has nothing to classify.
    # Greece is in the list precisely because it is sparse; that it returns
    # nothing for some sector sets is the point, not a failure.
    if (nrow(d) == 0L) next
    per_combo <- list()
    for (s in names(rmnchfunding:::CRS_SCHEMES)) {
      for (lv in rmnchfunding:::CRS_SCHEME_LEVELS[[s]]) {
        r <- crs_classify(d, s, level = lv)
        by_year <- stats::aggregate(r["value"], by = list(year = r$year),
                                    FUN = sum)
        per_combo[[paste(s, lv)]] <- stats::setNames(by_year$value,
                                                     by_year$year)
      }
    }
    m <- do.call(rbind, per_combo)
    spread <- apply(m, 2L, function(v) max(v) - min(v))
    expect_equal(max(spread), 0, tolerance = 1e-6,
                 label = paste0(donor, ": spread across scheme/level combos"))
  }
})

test_that("muskoka2() reproduces the published family-planning totals", {
  skip_if_no_oecd()

  # The strongest end-to-end check available. Donors Delivering 2026 Annex 3
  # publishes United States FP funding for 2022-2024 in 2023 constant prices,
  # and this pipeline reproduces all three EXACTLY — fetchers, deflation,
  # sector weights, agency weights and the multilateral half all together.
  # Family planning is the universe where every coefficient is a published
  # constant, so an exact match is achievable and anything else means
  # something upstream has moved.
  published <- c(`2022` = 924.92, `2023` = 834.99, `2024` = 979.42)
  r <- oecd_or_skip(muskoka2(
    "USA", years = 2022:2024, universe = "fp",
    prices = "constant", base = 2023, quiet = TRUE
  ))
  for (y in names(published)) {
    got <- r$total[r$year == as.integer(y)]
    expect_equal(got, published[[y]], tolerance = 1e-4,
                 label = paste("USA family planning", y))
  }
})

test_that("muskoka2() reproduces the published RMNCH totals within 1%", {
  skip_if_no_oecd()

  # RMNCH cannot match exactly: its four varying weights are recomputed from
  # GBD 2023 while the published figures used an earlier round. Within 1% is
  # what that difference costs, and a wider gap would mean something beyond
  # the data vintage had changed.
  published <- c(`2022` = 7521.99, `2023` = 5327.42, `2024` = 7662.28)
  r <- oecd_or_skip(muskoka2(
    "USA", years = 2022:2024, universe = "rmnch",
    prices = "constant", base = 2023, quiet = TRUE
  ))
  for (y in names(published)) {
    got <- r$total[r$year == as.integer(y)]
    expect_lt(abs(got - published[[y]]) / published[[y]], 0.01)
  }
})

test_that("muskoka2() weights every disbursement row", {
  skip_if_no_oecd()

  # muskoka2() errors rather than treat a missing weight as zero, so a
  # successful run already proves coverage. This pins the case that failed
  # first: the unallocated `_X` recipients, 48% of the value in the four
  # varying codes, which had no recipient-year weight until the crosswalk was
  # extended to cover them.
  d <- oecd_or_skip(muskoka2(
    "USA", years = 2022, prices = "current", detail = TRUE, quiet = TRUE
  ))
  expect_false(anyNA(d$weight))
  bil <- d[d$half == "bilateral", ]
  expect_true(any(grepl("_X$", bil$recipient)))
  expect_false(anyNA(bil$weight[grepl("_X$", bil$recipient)]))
})
