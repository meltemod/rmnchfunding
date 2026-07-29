# Getting started with rmnchfunding

``` r

library(rmnchfunding)
```

## Why this package exists

Replace this section with the problem the package solves — the situation
a reader is in *before* they install it. A vignette that opens with a
feature list assumes the reader already knows they need one.

## A worked example

``` r

x <- c(2, 4, 6, 8)
rescale01(x)
#> [1] 0.0000000 0.3333333 0.6666667 1.0000000
```

Every chunk here is executed when the package is built, so a vignette
that still knits is a second, coarser test suite: it catches interface
changes that unit tests written against internals would miss.

## What this vignette is not

Reference documentation. That is generated from the roxygen comments and
reached with
[`?rescale01`](https://meltemod.github.io/rmnchfunding/reference/rescale01.md).
A vignette explains *when and why*; the help page explains *what and
how*.
