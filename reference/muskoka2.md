# Estimate a provider's RMNCH, SRHR or family-planning funding

Applies the revised Muskoka method to a provider's OECD data: bilateral
CRS disbursements weighted by purpose code, plus core contributions to
multilateral agencies weighted by agency. Returns one row per provider
and year.

## Usage

``` r
muskoka2(
  donor,
  years,
  universe = c("rmnch", "srhr", "fp"),
  prices = c("constant", "current"),
  base = NULL,
  report_edition = 2026,
  ida = c(0, 1),
  detail = FALSE,
  quiet = FALSE
)
```

## Arguments

- donor:

  OECD donor code, e.g. `"USA"`. One or more.

- years:

  Integer vector of years.

- universe:

  One of `"rmnch"`, `"srhr"`, `"fp"`.

- prices:

  `"constant"` (needs `base`) or `"current"`. Passed to both fetchers,
  so the two halves are always on the same basis.

- base:

  Base year for `prices = "constant"`.

- report_edition:

  Which edition's coefficients to apply: `2023`, `2024`, `2025` or
  `2026`. Selects both halves — sector weights and agency weights — so
  an estimate never mixes editions. Defaults to the most recent.
  [`muskoka_weights()`](https://meltemod.github.io/rmnchfunding/reference/muskoka_weights.md)
  shows what a given edition applies.

- ida:

  Only meaningful for `universe = "fp"`. `0` (default) applies the
  published Donors Delivering treatment, which does not count IDA
  contributions to family planning; `1` applies the revised Muskoka 1%
  instead. See
  [agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md).

- detail:

  Set `TRUE` to return the weighted rows rather than the provider-year
  totals, for checking where an estimate comes from.

- quiet:

  Set `TRUE` to suppress the summary message.

## Value

With `detail = FALSE` (default), a tibble of one row per provider and
year:

- donor, donor_name:

  Provider.

- year:

  Calendar year.

- universe:

  Which universe was estimated.

- bilateral:

  Weighted CRS disbursements, millions of USD.

- multilateral:

  Weighted core contributions, millions of USD.

- total:

  The two summed.

with attributes `prices`, `base_year`, `report_edition`, `ida` and
`fetched_on`.

With `detail = TRUE`, the underlying rows: every disbursement or
contribution with the weight applied to it, its `weight_source`, and the
weighted value.

## Details

Two halves are fetched and weighted separately.

**Bilateral.**
[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
returns disbursements by recipient, purpose code and year. Twenty-nine
of the thirty-three purpose codes carry a single global weight from
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md).
The other four — 12262 malaria, 12263 tuberculosis, 13040 STD including
HIV/AIDS and 51010 general budget support — have an RMNCH weight that
varies by recipient and year, taken from
[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md)
and joined on the disbursement's own recipient and year. For SRHR and
family planning those four have global weights like any other code, so
the join applies only to `universe = "rmnch"`.

**Multilateral.**
[`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md)
returns core contributions by agency and year, weighted by
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
for the matching agency, spending year and report edition.

## The three universes do not add up

RMNCH, SRHR and family planning overlap by construction — the same
disbursement contributes to more than one. Adding two results together
double counts, and the source reports say so explicitly. Estimate and
report them separately.

## Choosing an edition and a price base

`report_edition` selects the coefficient vintage for both halves. Each
edition recomputes its agency weights for every year it covers, and the
revisions are large: the Asian Development Bank's 2023 RMNCH weight is
5.18% in the 2025 edition and 13.42% in the 2026 edition. Reproducing a
published figure means matching its edition, and matching its price base
too — 2022 constant prices for the 2025 edition, 2023 for the 2026.

Sector weights barely move between editions; the nine values the 2025
and 2026 editions misprint are corrected here in every edition, because
they are errata rather than revisions and each edition's own published
totals are reproduced by the corrected figure. See
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md).

## See also

[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
and
[`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md)
for the inputs,
[`muskoka_weights()`](https://meltemod.github.io/rmnchfunding/reference/muskoka_weights.md)
to read the coefficients an edition applies,
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md),
[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md)
and
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
for the tables themselves.

## Examples

``` r
if (FALSE) { # interactive()
# United States RMNCH, on the 2026 edition's basis
muskoka2("USA", years = 2022:2024, prices = "constant", base = 2023)

# Family planning with the revised Muskoka treatment of IDA
muskoka2("USA", years = 2022, prices = "current", universe = "fp", ida = 1)

# Where an estimate comes from
muskoka2("USA", years = 2022, prices = "current", detail = TRUE)
}
```
