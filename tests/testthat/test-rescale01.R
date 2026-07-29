# Tests for the example function. Delete this file when you delete
# R/rescale01.R. The shape is worth keeping: one behaviour per test_that(),
# named as a claim about the function rather than as "test 1".

test_that("endpoints map to 0 and 1", {
  expect_equal(rescale01(c(2, 4, 6, 8)), c(0, 1 / 3, 2 / 3, 1))
})

test_that("NA is propagated but does not break the range", {
  expect_equal(rescale01(c(1, NA, 3)), c(0, NA, 1))
  expect_true(all(is.na(rescale01(c(1, NA, 3), na.rm = FALSE))))
})

test_that("a constant vector returns zeroes rather than NaN", {
  expect_equal(rescale01(c(5, 5, 5)), c(0, 0, 0))
})

test_that("non-numeric input fails loudly", {
  expect_error(rescale01("a"), "must be numeric")
  expect_error(rescale01(1:3, na.rm = NA), "TRUE or FALSE")
})
