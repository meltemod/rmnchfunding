# Fetch a provider's core contributions to multilateral agencies

Pulls a provider's use of the multilateral system from the OECD table of
the same name, restricted to the agencies the Muskoka method weights.
The result is what `muskoka()` applies
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
to, giving the multilateral half of an estimate;
[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
gives the bilateral half.

## Usage

``` r
oecd_multi(
  donor,
  years,
  agencies = NULL,
  prices = c("constant", "current"),
  base = NULL,
  measure = "10",
  flow_type = "D",
  quiet = FALSE
)
```

## Arguments

- donor:

  OECD donor code(s), e.g. `"USA"`.

- years:

  Integer vector of years to fetch.

- agencies:

  Agency names as they appear in
  [agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md).
  Defaults to all eleven. Names are validated against
  [agency_channels](https://meltemod.github.io/rmnchfunding/reference/agency_channels.md);
  an unknown name is an error rather than an empty result.

- prices:

  Either `"constant"` (needs `base`) or `"current"`.

- base:

  Base year for `prices = "constant"`.

- measure:

  OECD measure code. Defaults to `"10"`, core contributions. Pass `"20"`
  for earmarked contributions through the agency, but see Details before
  combining them.

- flow_type:

  Defaults to `"D"`, disbursements.

- quiet:

  Set `TRUE` to suppress the summary message.

## Value

A tibble of one row per donor, agency and year:

- donor, donor_name:

  Provider code and label.

- agency:

  Agency name as used by
  [agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md),
  so the two join directly.

- year:

  Calendar year.

- value:

  Core contribution in millions of USD, in the prices given by the
  `prices` and `base_year` attributes.

- n_channels:

  How many OECD channel codes were summed into this row. `1` for every
  agency except the World Health Organisation, which can be `2` — it is
  `1` where a donor reported under only one of the WHO's two core
  channels in that year.

with attributes `prices`, `base_year`, `measure` and `fetched_on`.

As with
[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md),
a donor with no core contributions in the requested years returns 0 rows
with the same columns, and warns, rather than erroring.

## Details

Only **core** contributions are returned by default. OECD splits this
table into core contributions to an agency (`measure = "10"`) and
earmarked contributions channelled through it (`"20"`). The Muskoka
weights are defined against core contributions, and adding the earmarked
ones would double-count spending that CRS already reports bilaterally by
purpose code.

Agencies are identified by OECD channel code, never by name — see
[agency_channels](https://meltemod.github.io/rmnchfunding/reference/agency_channels.md)
for why, and for the World Health Organisation's two codes, which are
summed.

## Prices

As
[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md).
`prices = "current"` leaves each year in its own prices;
`prices = "constant"` requires an explicit `base` year and deflates with
OECD's per-donor deflators. Use the same setting for both fetchers, or
the bilateral and multilateral halves of an estimate will not be
comparable.

## See also

[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md),
[agency_channels](https://meltemod.github.io/rmnchfunding/reference/agency_channels.md),
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md).

## Examples

``` r
if (FALSE) { # interactive()
oecd_multi("USA", years = 2022:2024, prices = "constant", base = 2023)
}
```
