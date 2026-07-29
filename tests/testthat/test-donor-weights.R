# These tests work backwards from known weights: build disbursements, compute
# the totals those weights imply, then check the solver recovers them. That is
# the only way to test a recovery routine without trusting its own output, and
# it is why the fixtures below all state their true weights explicitly.

# Three years x four codes, with the disbursement pattern varying between
# years so the rows carry independent information.
disb <- function(cols = 4L, years = 3L) {
  m <- matrix(
    c(100, 200, 300, 400,
       50, 400, 150, 250,
      300, 100, 500,  75,
      220,  60, 180, 330)[seq_len(4L * years)],
    nrow = years, byrow = TRUE
  )[, seq_len(cols), drop = FALSE]
  colnames(m) <- c("12262", "12263", "13040", "51010")[seq_len(cols)]
  m
}

test_that("exactly determined weights are recovered", {
  # 3 codes, 3 years.
  truth <- c("12262" = 0.4, "12263" = 0.25, "13040" = 0.7)
  a <- disb(cols = 3L)
  res <- solve_donor_weights(a, as.vector(a %*% truth))

  expect_equal(res$weights, truth, tolerance = 1e-6)
  expect_equal(res$status, c("12262" = "identified", "12263" = "identified",
                             "13040" = "identified"))
  expect_equal(res$rank, 3L)
  expect_lt(res$rmse, 1e-6)
})

test_that("overdetermined weights are recovered and the fit is exact", {
  # 2 codes, 3 years: one spare equation. A consistent system should still
  # fit with no residual — a non-zero rmse here would mean the solver is
  # trading one equation off against another when it need not.
  truth <- c("12262" = 0.33, "12263" = 0.8)
  a <- disb(cols = 2L)
  res <- solve_donor_weights(a, as.vector(a %*% truth))

  expect_equal(res$weights, truth, tolerance = 1e-6)
  expect_lt(res$rmse, 1e-6)
  expect_equal(res$n_unknown, 2L)
})

test_that("four non-zero codes against three years is underdetermined", {
  # The case that actually bites. The solver must decline rather than pick a
  # point from the solution family.
  truth <- c("12262" = 0.4, "12263" = 0.25, "13040" = 0.7, "51010" = 0.1)
  a <- disb(cols = 4L)
  res <- solve_donor_weights(a, as.vector(a %*% truth))

  expect_true(all(is.na(res$weights)))
  expect_true(all(res$status == "underdetermined"))
  expect_equal(res$n_unknown, 4L)
  expect_equal(res$rank, 3L)
  expect_identical(res$condition, Inf)
})

test_that("a fourth year identifies all four codes", {
  # The stated remedy for underdetermined donors: one more published year.
  truth <- c("12262" = 0.4, "12263" = 0.25, "13040" = 0.7, "51010" = 0.1)
  a <- disb(cols = 4L, years = 4L)
  res <- solve_donor_weights(a, as.vector(a %*% truth))

  expect_equal(res$weights, truth, tolerance = 1e-6)
  expect_true(all(res$status == "identified"))
  expect_equal(res$n_years, 4L)
})

test_that("codes with no disbursement are reported, not solved", {
  # A donor that spends nothing on tuberculosis has no recoverable TB weight
  # — and does not need one. The other three must still be recovered, which
  # is the whole reason the zero column is dropped rather than treated as an
  # unknown.
  truth <- c("12262" = 0.4, "13040" = 0.7, "51010" = 0.1)
  a <- disb(cols = 4L)
  a[, "12263"] <- 0
  res <- solve_donor_weights(a, as.vector(a[, names(truth)] %*% truth))

  expect_equal(res$status[["12263"]], "no_disbursement")
  expect_true(is.na(res$weights[["12263"]]))
  expect_equal(res$weights[names(truth)], truth, tolerance = 1e-6)
  expect_equal(res$n_unknown, 3L)
})

test_that("collinear years are underdetermined despite enough equations", {
  # Four years, but each a multiple of the first: no new information. This is
  # the failure the rank check exists for — counting equations is not enough.
  a <- disb(cols = 3L, years = 3L)
  a[2, ] <- a[1, ] * 2
  a[3, ] <- a[1, ] * 3
  res <- solve_donor_weights(a, c(10, 20, 30))

  expect_true(all(res$status == "underdetermined"))
  expect_equal(res$rank, 1L)
})

test_that("a donor with no relevant spending needs no weights", {
  a <- disb(cols = 4L)
  a[] <- 0
  res <- solve_donor_weights(a, c(0, 0, 0))

  expect_true(all(is.na(res$weights)))
  expect_true(all(res$status == "no_disbursement"))
  expect_equal(res$n_unknown, 0L)
  expect_equal(res$rank, 0L)
})

test_that("recovered weights stay within bounds", {
  # Totals implying a share above 1 are not evidence of a weight above 1;
  # they are evidence of bad inputs. The result must remain a share.
  a <- disb(cols = 2L)
  res <- solve_donor_weights(a, as.vector(a %*% c(3, -2)))

  expect_true(all(res$weights >= 0 & res$weights <= 1))
  # ... and the misfit must be visible rather than hidden by the clamp.
  expect_gt(res$rmse, 1)
})

test_that("ill-conditioning is reported as an error bound on the weights", {
  # Two nearly-parallel years. The system solves, but the rounding in the
  # published totals is amplified, and the bound has to say so.
  a <- matrix(c(100, 100.001, 200, 200.001, 300, 300.002),
              nrow = 3, byrow = TRUE)
  colnames(a) <- c("12262", "12263")
  truth <- c(0.4, 0.2)
  res <- solve_donor_weights(a, as.vector(a %*% truth))

  expect_gt(res$condition, 1e4)
  expect_gt(res$rounding_error_bound, 0.01)
})

test_that("well-conditioned donors have a small rounding error bound", {
  a <- disb(cols = 3L)
  res <- solve_donor_weights(a, as.vector(a %*% c(0.4, 0.25, 0.7)))

  expect_lt(res$rounding_error_bound, 1e-3)
})

test_that("malformed input fails loudly", {
  a <- disb(cols = 3L)
  expect_error(solve_donor_weights(as.data.frame(a), c(1, 2, 3)),
               "must be a numeric matrix")
  expect_error(solve_donor_weights(a, c(1, 2)), "one row per published year")
  expect_error(solve_donor_weights(a, c(1, 2, NA)), "must not contain NA")
  expect_error(solve_donor_weights(a, c(1, 2, 3), lower = 1, upper = 0),
               "lower` < `upper|`lower < upper`")
})
