# Total a donor's disbursements by recipient classification

OECD classifies recipients several ways at once — geographically, by the
DAC List income tier, and by World Bank income group. Each is a
different cut of the same money, so each sums to the same total. This
returns one of those cuts.

## Usage

``` r
crs_classify(
  x,
  scheme = c("geographic", "dac_income", "wb_income"),
  level = 1L,
  by = c("donor", "year"),
  complete = FALSE,
  tolerance = 0.5
)
```

## Arguments

- x:

  A tibble from
  [`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
  with `recipients = "all"`.

- scheme:

  One of `"geographic"`, `"dac_income"`, `"wb_income"`.

- level:

  How far down the scheme to cut, either a level name or a number.
  `"geographic"` accepts `"total"`, `"continent"`, `"region"`,
  `"subregion"`, `"country"` (0 to 4); the income schemes accept
  `"total"`, `"tier"` or `"group"`, and `"country"` (0 to 2). Defaults
  to level 1, the scheme's own groups. See Levels.

- by:

  Additional columns to break the totals down by, e.g. `"purpose_code"`
  or `c("donor", "year")`. Defaults to `c("donor", "year")`.

- complete:

  Set `TRUE` to include every member of the level, filling those the
  donor did not fund with `0`. The default `FALSE` returns only members
  with data. See Completing a level.

- tolerance:

  Absolute tolerance, in millions, for the check that the scheme sums to
  OECD's reported grand total.

## Value

A tibble of one row per grouping variable and scheme member, with
`scheme`, `level`, `member`, `member_name`, `value`, `is_residual`,
`is_unallocated` and `share`. Carries a `grand_total` attribute.

## Details

Pass the result of
[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
called with `recipients = "all"`, since the aggregate rows are what this
reads. Calling it on a default (`"countries"`) result is an error rather
than a silently empty answer.

The figures are OECD's own published aggregates, not re-derived by
summing countries into groups. That is deliberate: OECD's hierarchical
codelist does not exactly describe its reported aggregates — `INC_X`
includes `DPGC_X` in the data but not in the codelist — so a scheme
built by walking the tree would not add up. Using the published
aggregates and checking the total instead means a disagreement surfaces
as an error rather than a wrong number.

## Schemes

- `"geographic"`:

  Africa, America, Asia, Europe, Oceania, plus `DPGC_X` for spending not
  attributable to any continent.

- `"dac_income"`:

  The DAC List of ODA Recipients tiers: least developed countries, other
  low income, lower-middle income, upper-middle income, more advanced
  developing countries, plus `INC_X` for spending not attributable to an
  income tier. Note that **LDC is a tier of this scheme**, not a
  separate universe: it is a cut of the same total, which is why it must
  not be added to a geographic figure.

- `"wb_income"`:

  The World Bank income classification, which is a genuinely different
  scheme from `"dac_income"`: it has no least- developed tier, adds a
  high-income group, and carries `INCWB_X` for countries the World Bank
  does not classify.

## Levels

Every level of every scheme sums to the same grand total, so a level is
a finer cut of the same money rather than a different quantity.

A level is a **frontier**, not a depth slice: branches that have already
ended stand in for themselves. This matters because the hierarchy is
ragged. Africa divides into regions and then subregions, while Europe
holds its countries directly, so the geographic `"region"` level
contains African regions *and* European countries side by side. Taking
"every node at depth 2" instead would drop every European country and
the level would not add up.

The same applies to unallocated spending, which enters at whatever level
it was reported. `DPGC_X` appears from `"continent"` downwards, while
`F6_X` ("Sub-Saharan Africa unspecified") only appears once the cut
reaches the level at which it sits. A country-level cut therefore still
contains regional residuals; they are marked by `is_unallocated`.

Groupings such as `HIPC`, `LLDC`, `SIDS` and `FSCAC` are **not**
schemes. They are overlapping flags — Ethiopia is in `F`, `F6`, `F3`,
`LDC`, `LLDC`, `OLICWB`, `HIPC` and `FSCAC` at once — and asking for one
is an error.

## Completing a level

By default a level lists only the members the donor actually funded, so
the rows differ between donors and between years. `complete = TRUE`
fills the rest with `0`, giving the same rows every time — for the
United States over 2021 to 2024, 151 recipients appear in the data out
of 207 in the hierarchy, so 56 are added as explicit zeros.

A zero and an absent row mean the same thing here, since OECD reports no
row for a recipient a donor did not fund. Completing therefore changes
the shape of the result but never a total.

Note that membership of the World Bank income groups is a **current
snapshot**, and countries move between groups over time: Hungary was
upper-middle income in the 1990s, high income from 2007, briefly
upper-middle again in 2012 and 2013, and high income since 2014. That
does not affect the figures here, because levels 0 and 1 use OECD's own
reported aggregates and the country level returns one row per country
rather than countries grouped by tier — all three schemes enumerate the
same country set. It would matter if this package ever reported which
countries belong to a tier in a given year, which would need the World
Bank's historical classification rather than a codelist snapshot.

## See also

[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md),
[crs_recipients](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md).

## Examples

``` r
if (FALSE) { # interactive()
d <- oecd_crs("USA", years = 2022, prices = "constant", base = 2023,
              recipients = "all")
crs_classify(d, "geographic")                      # continents
crs_classify(d, "geographic", level = "subregion")
crs_classify(d, "dac_income", level = "country")
}
```
