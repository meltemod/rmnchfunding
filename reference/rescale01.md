# Rescale a numeric vector to the unit interval

Linearly maps `x` so that its minimum becomes 0 and its maximum becomes
1.

## Usage

``` r
rescale01(x, na.rm = TRUE)
```

## Arguments

- x:

  A numeric vector.

- na.rm:

  Logical. Should `NA` values be ignored when finding the range? If
  `FALSE`, any `NA` in `x` makes the whole result `NA`.

## Value

A numeric vector the same length as `x`, with values in `[0, 1]`. A
constant `x` has no range to scale by and returns all zeroes.

## Details

This is an EXAMPLE function, present so the package is checkable,
testable and documented from the first commit. Delete it — along with
`tests/testthat/test-rescale01.R` and `man/rescale01.Rd` — once you have
real code, and remove `export(rescale01)` from NAMESPACE by re-running
`devtools::document()`.

## Examples

``` r
rescale01(c(2, 4, 6, 8))
#> [1] 0.0000000 0.3333333 0.6666667 1.0000000
rescale01(c(1, NA, 3))
#> [1]  0 NA  1
```
