# Getting started with rmnchfunding

``` r

library(rmnchfunding)
```

## Why this package exists

No OECD dataset reports how much aid goes to reproductive, maternal,
newborn and child health. The CRS records disbursements against purpose
codes that are broader than RMNCH — “basic health care”, “basic
nutrition” — and a provider’s contribution to the WHO or the Global Fund
appears as a single core payment with no sectoral breakdown at all.

The Muskoka method closes both gaps with coefficients: a fixed share of
each purpose code is attributed to the universe of interest, and a fixed
share of each multilateral agency’s spending is attributed alongside it.
This package holds those coefficients, fetches the two OECD sources they
apply to, and does the arithmetic.

## Status

Under construction. The coefficient tables and both OECD fetchers are in
place. `muskoka()` itself is not written yet, and four per-donor RMNCH
weights are still to be derived, so the package does not produce a
Muskoka estimate — but
[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md),
[`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md)
and
[`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md)
are usable on their own.

The chunks that reach the OECD API are shown but not executed here, so
that building this vignette never depends on a network connection.
Figures quoted in the text are from the United States in 2022, in
constant 2023 prices.

## The three universes

Every coefficient is given for three nested-in-spirit but separately
estimated universes:

| Universe | Scope                                            |
|----------|--------------------------------------------------|
| `rmnch`  | Reproductive, maternal, newborn and child health |
| `srhr`   | Sexual and reproductive health and rights        |
| `fp`     | Family planning                                  |

`muskoka()` will take one of these as its `universe` argument.

## The coefficient tables

Bilateral flows are weighted by CRS purpose code:

``` r

head(sector_weights[sector_weights$universe == "rmnch", ], 8)
#>   purpose_code                                purpose_name universe weight
#> 1        11230                Basic life skills for adults    rmnch    0.0
#> 2        11231                 Basic life skills for youth    rmnch    0.0
#> 3        12110 Health policy and administrative management    rmnch    0.4
#> 4        12181                  Medical education/training    rmnch    0.4
#> 5        12182                            Medical research    rmnch    0.0
#> 6        12191                            Medical services    rmnch    1.0
#> 7        12220                           Basic health care    rmnch    0.4
#> 8        12230                 Basic health infrastructure    rmnch    0.4
```

Multilateral spending is weighted by agency, and needs two keys rather
than one:

``` r

agency_weights[
  agency_weights$agency == "Global Fund" & agency_weights$universe == "rmnch",
]
#>          agency data_year universe weight report_edition
#> 10  Global Fund      2021    rmnch 0.4378           2025
#> 11  Global Fund      2022    rmnch 0.4270           2025
#> 12  Global Fund      2023    rmnch 0.4268           2025
#> 109 Global Fund      2022    rmnch 0.4342           2026
#> 110 Global Fund      2023    rmnch 0.4411           2026
#> 111 Global Fund      2024    rmnch 0.4491           2026
```

`data_year` is the year of the *spending*: each weight is the proportion
of that agency’s own disbursements in that year benefiting the universe,
so it moves as the agency’s disbursement mix moves.

`report_edition` is the year of the *report*. Every edition recomputes
the weights for all the years it covers, including years an earlier
edition already published, as the underlying data is revised. Those
revisions are large enough to matter:

``` r

adb <- agency_weights[
  agency_weights$agency == "Asian Development Bank" &
    agency_weights$universe == "rmnch" &
    agency_weights$data_year %in% 2022:2023,
]
adb[order(adb$data_year, adb$report_edition), ]
#>                     agency data_year universe weight report_edition
#> 5   Asian Development Bank      2022    rmnch 0.0324           2025
#> 103 Asian Development Bank      2022    rmnch 0.0719           2026
#> 6   Asian Development Bank      2023    rmnch 0.0518           2025
#> 104 Asian Development Bank      2023    rmnch 0.1342           2026
```

The 2023 weight is 5.18% as first published and 13.42% a year later. So
**take the weights and the published totals from the same edition** —
mixing them reproduces neither report. The editions also differ in price
base: 2022 constant prices in 2025, 2023 constant prices in 2026.

Between them the two editions cover four spending years, 2021 to 2024,
which is what makes the four per-donor RMNCH weights recoverable — four
unknowns need four independent published years, and neither edition
alone has them.

## Weights that are missing on purpose

Some coefficients are `NA`, and that is not the same as zero:

``` r

na_cells <- sector_weights[is.na(sector_weights$weight), ]
table(na_cells$universe)
#> 
#> rmnch  srhr    fp 
#>     4     0     0
```

All four are RMNCH weights — malaria control, tuberculosis control, STD
control including HIV/AIDS, and general budget support. The source marks
these `varies*` because their RMNCH share is set **per donor country**,
and a table with one weight per code cannot hold a per-donor value. They
will move to their own donor-keyed table once derived. The SRHR and
family-planning universes are complete. See
[`?sector_weights`](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md).

## Where the coefficients come from

Both tables are transcribed from the Donors Delivering for SRHR Report
2026, pages 110–111. RMNCH follows the Muskoka 2 methodology developed
by the London School of Hygiene and Tropical Medicine, family planning
follows the revised Muskoka methodology agreed at the 2012 London
Summit, and SRHR follows the Donors Delivering methodology.

The three universes overlap by construction. Adding a donor’s RMNCH,
SRHR and FP figures together double-counts, and the report says so
explicitly — they are meant to be read separately.

Because a missing weight is unknown rather than zero, `muskoka()` will
refuse to compute a total that depends on one instead of quietly
treating it as nothing — a zero here would understate the result without
leaving a trace.

## Fetching the two OECD sources

[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
pulls a donor’s bilateral disbursements for the weighted purpose codes,
broken down by recipient and year:

``` r

crs <- oecd_crs("USA", years = 2022, prices = "constant", base = 2023)
```

[`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md)
pulls the other half — core contributions to the eleven weighted
multilateral agencies:

``` r

mul <- oecd_multi("USA", years = 2022, prices = "constant", base = 2023)
```

Two arguments deserve attention.

**`prices` is never implicit.** `"current"` leaves each year in its own
prices. `"constant"` requires a `base` year, because OECD rebases its
own constant series with each release — 2024 at the time of writing,
2023 a few months earlier — so a default would change meaning underneath
you between releases. Values are always fetched in current prices and
deflated here with OECD’s per-donor deflators, which is what allows any
base year to be requested. To reproduce a published Donors Delivering
figure, match its edition: base 2022 for the 2025 edition, base 2023 for
the 2026 edition.

**`recipients` controls de-duplication.** A CRS query with the recipient
dimension open returns aggregates and countries as sibling rows, so
“Developing countries”, “Africa” and “Kenya” all come back together.
Summing them counts Kenya four times. The default `"countries"` keeps
only non-aggregate rows and is the only setting whose rows can safely be
summed. `"all"` keeps everything, which is what
[`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md)
needs.

Note that de-duplicating is not the same as reducing to countries. OECD
reports the part of a donor’s spending it cannot attribute to any
country in `_X` buckets — “Developing countries unspecified”,
“Sub-Saharan Africa unspecified”. These have no members, so they are
correctly kept and summed alongside countries, but they are not
countries: for the United States in 2022 they are 42% of the total. They
carry `is_unallocated` so you can sum either way.

## Classifying recipients

OECD classifies recipients several ways at the same time, and this is
easy to get wrong: the recipient codelist has nineteen top-level
groupings that look comparable in a flat list but are not.
[`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md)
returns one *classification* at a time, each of which sums to the same
grand total.

``` r

d <- oecd_crs("USA", years = 2022, prices = "constant", base = 2023,
              recipients = "all")

crs_classify(d, "geographic")
crs_classify(d, "dac_income")
crs_classify(d, "wb_income")
```

For the United States in 2022, all three come to the same 24,281.9
million:

| Geographic    |         | DAC income       |          | World Bank income |          |
|---------------|--------:|------------------|---------:|-------------------|---------:|
| Africa        | 9,817.6 | *unallocated*    | 10,089.9 | *unallocated*     | 10,089.9 |
| *unspecified* | 7,766.8 | Least developed  |  8,759.5 | Low income        |  6,506.8 |
| Asia          | 4,164.2 | Lower-middle     |  3,018.9 | Lower-middle      |  4,352.9 |
| America       | 1,435.2 | Upper-middle     |  1,861.4 | Upper-middle      |  2,034.4 |
| Europe        |   890.0 | Other low income |    552.1 | Not classified    |  1,274.4 |
| Oceania       |   208.0 |                  |          | High income       |     23.5 |
| **24,281.9**  |         | **24,281.9**     |          | **24,281.9**      |          |

Three things follow that are worth knowing before using these figures.

**“Developing countries” is the total, and “least developed countries”
is not a separate universe.** `DPGC` is the grand total. `LDC` is a
*tier* of the DAC income classification — the same money cut a different
way — so adding it to a geographic figure double counts.

**The two income classifications are genuinely different.** The DAC List
of ODA Recipients has a least-developed tier and no high-income group;
the World Bank classification has the reverse, plus a group for
countries it does not classify at all.

**Some groupings are not classifications.** `HIPC`, `LLDC`, `SIDS`,
`FSCAC` and `ACP` are overlapping flags a country carries *in addition*
to its place in every classification above — Ethiopia is in Africa,
Sub-Saharan Africa, Eastern Africa, least developed, landlocked, World
Bank low income, heavily indebted and fragile simultaneously. They do
not partition anything (`FSCAC` alone is 47% of the United States
total), so `scheme` cannot name them.

## Levels

Each classification can be cut at a chosen depth, and every level still
sums to the same total:

``` r

crs_classify(d, "geographic", level = "continent")   # the default, level 1
crs_classify(d, "geographic", level = "subregion")
crs_classify(d, "dac_income", level = "country")
```

| Classification | Levels                                                 |
|----------------|--------------------------------------------------------|
| `geographic`   | `total`, `continent`, `region`, `subregion`, `country` |
| `dac_income`   | `total`, `tier`, `country`                             |
| `wb_income`    | `total`, `group`, `country`                            |

A level is a **frontier**, not a slice at a fixed depth. Branches that
have already ended stand in for themselves, because the hierarchy is
ragged: Africa divides into regions and then subregions, while Europe
holds its countries directly. So the geographic `"region"` level
contains African regions and European countries side by side. Taking
“every node at depth two” instead would drop every European country, and
the level would no longer add up.

The same applies to unallocated spending, which enters at whatever level
it was reported. A country-level cut therefore still contains regional
residuals such as “Sub-Saharan Africa unspecified”; those rows are
marked `is_unallocated`.

[`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md)
verifies on every call that the parts sum to OECD’s own reported total,
and fails rather than return parts that do not make a whole. That is not
defensiveness for its own sake: OECD’s published hierarchy does not
always describe its published aggregates. `INC_X` includes `DPGC_X` in
the data but does not list it as a child in the codelist, which cost
exactly 7,766.8 million — 32% of this donor’s total — the first time an
income classification was cut to country level.

## What this vignette is not

Reference documentation. That is generated from the roxygen comments and
reached with
[`?sector_weights`](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
and
[`?agency_weights`](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md).
A vignette explains *when and why*; the help page explains *what and
how*.
