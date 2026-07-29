#' Rescale a numeric vector to the unit interval
#'
#' Linearly maps `x` so that its minimum becomes 0 and its maximum becomes 1.
#'
#' This is an EXAMPLE function, present so the package is checkable, testable
#' and documented from the first commit. Delete it — along with
#' `tests/testthat/test-rescale01.R` and `man/rescale01.Rd` — once you have
#' real code, and remove `export(rescale01)` from NAMESPACE by re-running
#' `devtools::document()`.
#'
#' @param x A numeric vector.
#' @param na.rm Logical. Should `NA` values be ignored when finding the
#'   range? If `FALSE`, any `NA` in `x` makes the whole result `NA`.
#'
#' @return A numeric vector the same length as `x`, with values in `[0, 1]`.
#'   A constant `x` has no range to scale by and returns all zeroes.
#'
#' @export
#'
#' @examples
#' rescale01(c(2, 4, 6, 8))
#' rescale01(c(1, NA, 3))
rescale01 <- function(x, na.rm = TRUE) {
  if (!is.numeric(x)) {
    stop("`x` must be numeric, not ", class(x)[1], ".", call. = FALSE)
  }
  if (!is.logical(na.rm) || length(na.rm) != 1L || is.na(na.rm)) {
    stop("`na.rm` must be TRUE or FALSE.", call. = FALSE)
  }

  rng <- range(x, na.rm = na.rm, finite = FALSE)

  # A constant vector has zero range. Dividing by it would give NaN, which
  # is not obviously wrong to a caller and would propagate silently, so
  # return zeroes and say so in the documentation instead.
  if (!anyNA(rng) && rng[1] == rng[2]) {
    return(ifelse(is.na(x), NA_real_, 0))
  }

  (x - rng[1]) / (rng[2] - rng[1])
}
