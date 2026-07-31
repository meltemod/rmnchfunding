# Look up the coefficients a report edition applies

Returns the sector and agency weights for a given Donors Delivering
edition in one table, so that the numbers behind an estimate can be read
directly rather than assembled from
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
and
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
by hand.

## Usage

``` r
muskoka_weights(
  report_edition = 2026,
  universe = NULL,
  year = NULL,
  half = c("both", "bilateral", "multilateral")
)
```

## Arguments

- report_edition:

  Which edition's coefficients to return: `2023`, `2024`, `2025` or
  `2026`. Defaults to the most recent.

- universe:

  Optional filter: `"rmnch"`, `"srhr"` or `"fp"`. All three by default.

- year:

  Optional filter on the spending year, which applies to the
  multilateral half only. Bilateral rows have no year and are returned
  whatever this is set to, since their weight is the same in every year.

- half:

  Which half to return: `"both"` (default), `"bilateral"` or
  `"multilateral"`.

## Value

A tibble of one row per coefficient:

- half:

  `"bilateral"` or `"multilateral"`.

- item:

  CRS purpose code, or agency name.

- item_name:

  Purpose code description, or the agency name again.

- universe:

  `"rmnch"`, `"srhr"` or `"fp"`.

- report_edition:

  Edition the coefficient is taken from.

- data_year:

  Spending year for multilateral rows; `NA` for bilateral, whose weights
  do not vary by year.

- weight:

  The coefficient, as a proportion in `[0, 1]`. `NA` for the four RMNCH
  codes the source gives as `varies*`; see
  [rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md).

- weight_printed:

  What the edition's own table prints. Differs from `weight` only for
  the nine misprinted sector values.

- is_misprint:

  `TRUE` where the two differ.

## Details

A Muskoka estimate has two halves with two different coefficient tables:
bilateral CRS disbursements weighted by purpose code, and core
contributions weighted by agency. They are stored separately because
they are keyed differently — a sector weight is fixed across years, an
agency weight is not — and this function is the reader's view over both.

## Editions disagree, and it matters which you use

Every edition recomputes its agency weights for all three years it
covers, including years an earlier edition already published, and the
revisions are large: of the 66 agency-years published in both the 2025
and 2026 editions, 31 differ. Reproducing a published figure means
matching its edition, and its price base too — 2022 constant prices for
the 2025 edition, 2023 for the 2026.

Sector weights are stable across editions by comparison. The only
differences are the nine values the 2025 and 2026 editions misprint, and
those are corrections rather than revisions: `weight` holds the figure
that reproduces the edition's own published totals, `weight_printed`
what the edition's table actually shows. See
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md).

## See also

[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
and
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
for the underlying tables,
[`muskoka2()`](https://meltemod.github.io/rmnchfunding/reference/muskoka2.md)
to apply them.

## Examples

``` r
# Everything the 2026 edition applies to SRHR
muskoka_weights(2026, universe = "srhr")
#> # A tibble: 66 × 9
#>    half  item  item_name universe report_edition data_year weight weight_printed
#>    <chr> <chr> <chr>     <fct>             <int>     <int>  <dbl>          <dbl>
#>  1 bila… 11230 Basic li… srhr               2026        NA  0.044          0.044
#>  2 bila… 11231 Basic li… srhr               2026        NA  0.094          0.094
#>  3 bila… 12110 Health p… srhr               2026        NA  0.154          0.154
#>  4 bila… 12181 Medical … srhr               2026        NA  0.161          0.161
#>  5 bila… 12182 Medical … srhr               2026        NA  0              0    
#>  6 bila… 12191 Medical … srhr               2026        NA  0.175          0.175
#>  7 bila… 12220 Basic he… srhr               2026        NA  0.1            0.1  
#>  8 bila… 12230 Basic he… srhr               2026        NA  0.136          0.136
#>  9 bila… 12240 Basic nu… srhr               2026        NA  0.384          0.384
#> 10 bila… 12250 Infectio… srhr               2026        NA  0.02           0.02 
#> # ℹ 56 more rows
#> # ℹ 1 more variable: is_misprint <lgl>

# The nine values the 2026 table misprints
w <- muskoka_weights(2026)
w[w$is_misprint, c("item", "universe", "weight", "weight_printed")]
#> # A tibble: 9 × 4
#>   item  universe weight weight_printed
#>   <chr> <fct>     <dbl>          <dbl>
#> 1 12191 rmnch     0.4            1    
#> 2 15170 srhr      0.076          0.044
#> 3 15180 srhr      0.415          0.094
#> 4 16064 srhr      0.5            0.154
#> 5 51010 srhr      0              0.161
#> 6 72010 srhr      0.023          0    
#> 7 72040 srhr      0.001          0.175
#> 8 72050 srhr      0.007          0.1  
#> 9 73010 srhr      0.006          0.136

# How one agency's SRHR weight was revised across editions
do.call(rbind, lapply(2023:2026, function(e) {
  x <- muskoka_weights(e, universe = "srhr", half = "multilateral")
  x[x$item == "UNFPA", ]
}))
#> # A tibble: 12 × 9
#>    half  item  item_name universe report_edition data_year weight weight_printed
#>    <chr> <chr> <chr>     <fct>             <int>     <int>  <dbl>          <dbl>
#>  1 mult… UNFPA UNFPA     srhr               2023      2019  0.845          0.845
#>  2 mult… UNFPA UNFPA     srhr               2023      2020  0.857          0.857
#>  3 mult… UNFPA UNFPA     srhr               2023      2021  0.813          0.813
#>  4 mult… UNFPA UNFPA     srhr               2024      2020  0.857          0.857
#>  5 mult… UNFPA UNFPA     srhr               2024      2021  0.813          0.813
#>  6 mult… UNFPA UNFPA     srhr               2024      2022  0.397          0.397
#>  7 mult… UNFPA UNFPA     srhr               2025      2021  0.950          0.950
#>  8 mult… UNFPA UNFPA     srhr               2025      2022  0.982          0.982
#>  9 mult… UNFPA UNFPA     srhr               2025      2023  0.981          0.981
#> 10 mult… UNFPA UNFPA     srhr               2026      2022  0.913          0.913
#> 11 mult… UNFPA UNFPA     srhr               2026      2023  0.904          0.904
#> 12 mult… UNFPA UNFPA     srhr               2026      2024  0.905          0.905
#> # ℹ 1 more variable: is_misprint <lgl>
```
